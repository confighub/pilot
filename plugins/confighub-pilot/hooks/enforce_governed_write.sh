#!/usr/bin/env bash
#
# PostToolUse hook: verification guidance after a ConfigHub write attempt.
#
# Fires AFTER every Bash tool call completes, before Claude's next turn.
# If a CH-WRITE just happened, this hook makes the distinction between host
# permission, command completion, and proved outcome explicit. It injects the
# read-only verification and receipt obligation plus any missing proof
# artifacts (session URL, trust URL, rendered session).
#
# Output policy follows the shared SHELL_REQUEST_ENTRYPOINTS list: Pilot or
# provider output remains a policy input, including through a copying pipeline.
# Descriptive output from data reads is ignored here; recognized credentials
# still partition. Unknown shell syntax retains the previous full-input rule.
#
# This is the "one hard guard for the most important governance moment"
# from Chunk 1 of the implementation proposal (v2.1). Full scoring and
# phase-marker enforcement come in Chunk 4.
#
# The hook is read-only — it NEVER writes to EVENTS.jsonl, approval stubs,
# or session state. It only reads state and injects additionalContext.
#
set -euo pipefail

# Strict session boundary: an installed Pilot plugin must be inert in every
# Claude session that was not explicitly launched with Pilot active.
# Pilot activation (#764, #1146): active only when PILOT_ACTIVE is exactly 1, or
# when the person using this Claude session typed /confighub-pilot:on. The
# session ID comes from the hook input's top-level JSON field, never from text
# matching, so command text cannot name a different session. A plugin added
# from a marketplace has no installer-supplied PILOT_ROOT, so the switch file
# carries the installed Pilot root that /confighub-pilot:on verified.
if [[ "${PILOT_ACTIVE:-0}" != "1" ]]; then
    pilot_switch_dir="${PILOT_USER_HOME:-${HOME:-}/.pilot}/claude/active-sessions"
    compgen -G "${pilot_switch_dir}/*" >/dev/null 2>&1 || exit 0
    pilot_hook_input="$(cat)"
    pilot_session_state="$(printf '%s' "$pilot_hook_input" | PYTHONDONTWRITEBYTECODE=1 python3 -c 'import json, os, re, sys
try:
    value = json.load(sys.stdin).get("session_id")
except Exception:
    value = None
if not (isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9-]{8,128}", value)):
    raise SystemExit(0)
marker = os.path.join(sys.argv[1], value)
if not os.path.isfile(marker):
    raise SystemExit(0)
root = ""
try:
    recorded = json.load(open(marker, encoding="utf-8")).get("pilot_root")
    if isinstance(recorded, str) and os.path.isfile(os.path.join(recorded, "scripts", "pilot")) and os.path.isfile(os.path.join(recorded, "pilot", "package-manifest.json")):
        root = recorded
except Exception:
    root = ""
print("active:" + root)' "$pilot_switch_dir" 2>/dev/null || true)"
    [[ "$pilot_session_state" == active:* ]] || exit 0
    export PILOT_ACTIVE=1
    pilot_marker_root="${pilot_session_state#active:}"
    if [[ -z "${PILOT_ROOT:-}" && -n "$pilot_marker_root" ]]; then
        export PILOT_ROOT="$pilot_marker_root"
        export PILOT_HOME="$pilot_marker_root"
    fi
    exec 0<<<"$pilot_hook_input"
fi

# ---------------------------------------------------------------------------
# Locate the Pilot repo scripts
# ---------------------------------------------------------------------------

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [[ -z "$PLUGIN_ROOT" ]]; then
    PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" || exit 0
fi

PILOT_SCRIPTS=""
for candidate in \
    "${PILOT_ROOT:-}/scripts" \
    "$PLUGIN_ROOT/../../scripts"; do
    if [[ -n "$candidate" ]] && [[ -x "$candidate/cub-trace-classify" ]]; then
        PILOT_SCRIPTS="$candidate"
        break
    fi
done

if [[ -z "$PILOT_SCRIPTS" ]]; then
    exit 0
fi

default_trace_dir() {
    local root
    if [[ -n "${PILOT_USER_HOME:-}" ]]; then
        root="$PILOT_USER_HOME"
    elif [[ -n "${PILOT_DATA_HOME:-}" ]]; then
        root="$PILOT_DATA_HOME"
    elif [[ -n "${PILOT_PROJECT_HOME:-}" ]]; then
        root="${PILOT_PROJECT_HOME%/}/.pilot"
    else
        root="${HOME:?HOME is required}/.pilot"
    fi
    case "$root" in
        "~") root="$HOME" ;;
        "~/"*) root="$HOME/${root#\~/}" ;;
    esac
    printf '%s/traces' "${root%/}"
}

TRACE_DIR="${CUB_TRACE_RUN_DIR:-$(default_trace_dir)}"

# ---------------------------------------------------------------------------
# Read the hook input JSON and extract the bash command
# ---------------------------------------------------------------------------

if ! command -v python3 >/dev/null 2>&1; then
    exit 0
fi

export PILOT_HOOK_SCRIPTS="$PILOT_SCRIPTS"

# Read BOTH tool_input.command AND tool_response.* on a single python3 pass.
# tool_response is PostToolUse-only and carries the bash exit_code + output.
# The hook never hard-fails on a missing field — silent degradation only.
# Output format: three lines (command, exit_code or empty, first 400 chars of
# stdout+stderr concatenated). Empty fields are preserved as blank lines so
# the shell reader sees a stable 3-row schema.
PARSE="$(python3 -c '
import json, os, re, sys
from pathlib import Path

scripts = os.environ.get("PILOT_HOOK_SCRIPTS", "")
if scripts:
    sys.path.insert(0, str(Path(scripts)))

try:
    from pilot_common import (
        shell_output_requires_content_policy,
        split_shell_data_text,
        target_access_content_policy,
        text_contains_high_confidence_credential,
    )
except ImportError:
    def split_shell_data_text(command):
        return command, ""

    def shell_output_requires_content_policy(_command):
        return True

    def text_contains_high_confidence_credential(_text):
        return False

    def target_access_content_policy(text):
        normalized = " ".join(str(text or "").lower().split())
        if re.search(r"\b(?:confighub|config\s+hub)\b", normalized) and re.search(
            r"\btarget(?:-|\s)+access\b", normalized
        ):
            return "write"
        if re.search(r"\bcub\b.{0,160}\btarget\s+access\b", normalized):
            return "legacy-provider-command"
        return "unrelated"

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
tool_name = data.get("tool_name", "")
if tool_name != "Bash":
    sys.exit(0)
tool_input = data.get("tool_input", {}) or {}
command = tool_input.get("command", "") or ""
if not command:
    sys.exit(0)
# tool_response shape varies across Claude Code versions; probe defensively.
resp = data.get("tool_response") or {}
ec = ""
for key in ("exit_code", "exitCode", "returncode", "returnCode"):
    if key in resp:
        ec = str(resp.get(key, ""))
        break
out = ""
for key in ("stdout", "output", "stderr"):
    v = resp.get(key)
    if v:
        out += str(v)
executed, data = split_shell_data_text(command)
policy_input = executed
if shell_output_requires_content_policy(command):
    policy_input += "\n" + out
target_policy = target_access_content_policy(policy_input)
if any(text_contains_high_confidence_credential(text) for text in (command, data, out)) or target_access_content_policy(out) == "credential-bearing-content":
    target_policy = "credential-bearing-content"
if target_policy != "unrelated":
    print("__PILOT_TARGET_ACCESS_PARTITIONED__")
    print(target_policy)
    sys.exit(0)
print(command.replace("\n", " "))
print(ec)
print(out[:400].replace("\n", " "))
' 2>/dev/null || true)"

if [[ -z "$PARSE" ]]; then
    exit 0
fi

if [[ "$(printf '%s' "$PARSE" | sed -n '1p')" == "__PILOT_TARGET_ACCESS_PARTITIONED__" ]]; then
    export PILOT_HOOK_TARGET_ACCESS_POLICY="$(printf '%s' "$PARSE" | sed -n '2p')"
    python3 <<'PYEOF' 2>/dev/null || true
import json
import os
import sys

policy = os.environ.get("PILOT_HOOK_TARGET_ACCESS_POLICY", "")
canonical = {
    "proof": "prove read-only ConfigHub target access",
    "artifact": "explain ConfigHub target access",
    "destructive": "revoke ConfigHub target access",
}.get(policy, "change ConfigHub target access")
context = (
    "TARGET-ACCESS PARTITION (Pilot): a target-access Bash call reached the "
    "post-tool hook, but this generic governance hook did not quote, summarize, "
    "or persist its command or tool output. Do not treat the hook as approval "
    "or proof. Route follow-up through `pilot ask \""
    + canonical
    + "\" --json` and follow its typed proposal-only boundary."
)
json.dump(
    {
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": context,
        }
    },
    sys.stdout,
)
PYEOF
    exit 0
fi

COMMAND="$(printf '%s' "$PARSE" | sed -n '1p')"
EXIT_CODE="$(printf '%s' "$PARSE" | sed -n '2p')"
TOOL_OUT="$(printf '%s' "$PARSE" | sed -n '3p')"

if [[ -z "$COMMAND" ]]; then
    exit 0
fi

COMMAND="$(printf '%s' "$COMMAND" | sed -E 's#^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)+##')"
COMMAND="$(printf '%s' "$COMMAND" | sed -E "s#^(/usr/bin/env[[:space:]]+)?([^[:space:]]*/)?perl[[:space:]]+-e[[:space:]]+['\"]alarm shift; exec @ARGV['\"][[:space:]]+[0-9]+[[:space:]]+##")"
COMMAND="$(printf '%s' "$COMMAND" | sed -E 's#^(g?timeout)[[:space:]]+(-[A-Za-z0-9]+[[:space:]]+|--[A-Za-z-]+(=[^[:space:]]+)?[[:space:]]+)*[0-9]+[smhd]?[[:space:]]+##')"

# ---------------------------------------------------------------------------
# Classify — we need the kind for Block A (validation-result upgrade) AND
# the lane for the CH-WRITE gate below.
# ---------------------------------------------------------------------------

CLASSIFY_JSON="$("$PILOT_SCRIPTS/cub-trace-classify" --json "$COMMAND" 2>/dev/null || true)"
LANE=""
KIND=""
if [[ -n "$CLASSIFY_JSON" ]]; then
    LANE="$(printf '%s' "$CLASSIFY_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("lane",""))' 2>/dev/null || true)"
    KIND="$(printf '%s' "$CLASSIFY_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("kind",""))' 2>/dev/null || true)"
fi

# ---------------------------------------------------------------------------
# Block A — validation outcome upgrade.
#
# PreToolUse emitted a `kind=validation-result, status=started` event for
# this command. Now that it has completed, upgrade it: emit a second event
# with status=passed (on exit 0) or status=failed (non-zero). The gate in
# Block B below looks for status=passed specifically, so without this
# upgrade the gate would never unblock.
#
# Defensive: skip if we couldn't determine the exit code (e.g. tool_response
# shape differs on an older Claude Code version). The started event stays.
# ---------------------------------------------------------------------------

if [[ "$KIND" == "validation-result" ]] && [[ -n "$EXIT_CODE" ]]; then
    VALIDATOR="$(echo "$COMMAND" | awk '{print $3}')"    # e.g. "vet-celexpr"
    [[ -z "$VALIDATOR" ]] && VALIDATOR="unknown-validator"
    TARGET_UNIT="$(echo "$COMMAND" | sed -n 's/.*--unit[= ]\([A-Za-z0-9._-]\{1,\}\).*/\1/p' | head -1)"
    TARGET_SPACE="$(echo "$COMMAND" | sed -n 's/.*--space[= ]\([A-Za-z0-9._-]\{1,\}\).*/\1/p' | head -1)"
    OBJECT="${TARGET_SPACE:+$TARGET_SPACE/}${TARGET_UNIT:-unknown}"
    if [[ "$EXIT_CODE" == "0" ]]; then
        "$PILOT_SCRIPTS/cub-trace-emit" validation-result "$VALIDATOR" passed \
            --object "$OBJECT" >/dev/null 2>&1 || true
    else
        DETAIL="exit_code=$EXIT_CODE"
        [[ -n "$TOOL_OUT" ]] && DETAIL="$DETAIL: $TOOL_OUT"
        "$PILOT_SCRIPTS/cub-trace-emit" validation-result "$VALIDATOR" failed \
            --object "$OBJECT" --detail "$DETAIL" >/dev/null 2>&1 || true
    fi
fi

# ---------------------------------------------------------------------------
# Remaining logic in this hook fires only on completed CH-WRITE commands.
# Non-CH-WRITE commands (including the validation-result events just
# handled in Block A) have nothing more to enforce here.
# ---------------------------------------------------------------------------

if [[ "$LANE" != "CH-WRITE" ]]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# Read session state (read-only — never mutate from this hook)
# ---------------------------------------------------------------------------

RUN_ID=""
if [[ -f "$TRACE_DIR/CURRENT_RUN_ID" ]]; then
    RUN_ID="$(cat "$TRACE_DIR/CURRENT_RUN_ID" 2>/dev/null || true)"
fi

# Check three conditions for the governance moment
MISSING=""

# ---------------------------------------------------------------------------
# Block B — apply gate.
#
# `cub unit apply` is the moment where governed state crosses from the
# pending-revision world into the live cluster via the target. That crossing
# should be gated by a passing pre-publish validation on the same revision
# within this session. Without the gate, validation is just narration.
#
# Gate scope:
#   - Applies ONLY to `cub unit apply` (not `cub unit approve`, not run-set).
#   - Looks in this session (run_id match) for a validation-result event
#     with status=passed whose object/meta references the target unit.
#   - Honors CONFIGHUB_AI_SKIP_VALIDATION_GATE=1 as an auditable bypass.
#   - Soft gate: extends MISSING, which becomes additionalContext. Never
#     aborts the tool call.
# ---------------------------------------------------------------------------

if [[ "$COMMAND" =~ ^cub[[:space:]]+unit[[:space:]]+apply ]]; then
    if [[ "${CONFIGHUB_AI_SKIP_VALIDATION_GATE:-}" == "1" ]]; then
        MISSING="${MISSING}validation gate bypassed via CONFIGHUB_AI_SKIP_VALIDATION_GATE=1 (audit: apply ran without prior passing validation check in this session); "
    else
        # Extract target unit: --unit <slug> or the trailing positional token.
        TARGET_UNIT="$(echo "$COMMAND" | sed -n 's/.*--unit[= ]\([A-Za-z0-9._-]\{1,\}\).*/\1/p' | head -1)"
        [[ -z "$TARGET_UNIT" ]] && TARGET_UNIT="$(echo "$COMMAND" | awk '{for (i=NF; i>=1; i--) if ($i !~ /^-/) {print $i; exit}}')"

        VALIDATION_PRESENT=""
        if [[ -f "$TRACE_DIR/EVENTS.jsonl" ]] && [[ -n "$TARGET_UNIT" ]] && [[ -n "$RUN_ID" ]]; then
            export V_RUN_ID="$RUN_ID"
            export V_UNIT="$TARGET_UNIT"
            export V_TRACE="$TRACE_DIR/EVENTS.jsonl"
            VALIDATION_PRESENT="$(python3 -c '
import json, os
run_id = os.environ.get("V_RUN_ID", "")
unit = os.environ.get("V_UNIT", "")
path = os.environ.get("V_TRACE", "")
try:
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            try:
                e = json.loads(line)
            except Exception:
                continue
            if e.get("run_id") != run_id:
                continue
            if e.get("kind") != "validation-result":
                continue
            if e.get("status") != "passed":
                continue
            if unit in e.get("object", "") or unit in json.dumps(e.get("meta", {})):
                print("yes")
                break
except Exception:
    pass
' 2>/dev/null || true)"
        fi

        if [[ "$VALIDATION_PRESENT" != "yes" ]]; then
            MISSING="${MISSING}apply attempted without passing validation on revision (run 'cub run vet-celexpr --space <space> --unit ${TARGET_UNIT:-<unit>} -- <cel>' first, or set CONFIGHUB_AI_SKIP_VALIDATION_GATE=1 to bypass); "
        fi
    fi
fi

# 1. Session rendered? (SESSION.json exists in the session directory)
SESSION_DIR="$TRACE_DIR/sessions/$RUN_ID"
if [[ -z "$RUN_ID" ]] || [[ ! -f "$SESSION_DIR/SESSION.json" ]]; then
    MISSING="${MISSING}session not rendered (no SESSION.json); "
fi

# 2. Trust URL present in the last CH-WRITE event?
TRUST_URL=""
LAST_CH_WRITE=""
if [[ -f "$TRACE_DIR/EVENTS.jsonl" ]]; then
    LAST_CH_WRITE="$(grep '"CH-WRITE"' "$TRACE_DIR/EVENTS.jsonl" 2>/dev/null | tail -1 || true)"
    if [[ -n "$LAST_CH_WRITE" ]]; then
        TRUST_URL="$(echo "$LAST_CH_WRITE" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("url",""))' 2>/dev/null || true)"
    fi
fi
if [[ -z "$TRUST_URL" ]]; then
    MISSING="${MISSING}no trust URL on the CH-WRITE event; "
fi

# 3. Session README exists? (the human-readable session summary)
if [[ -z "$RUN_ID" ]] || [[ ! -f "$SESSION_DIR/README.md" ]]; then
    MISSING="${MISSING}session README not generated; "
fi

# ---------------------------------------------------------------------------
# Extract governed object details from the last CH-WRITE event
# ---------------------------------------------------------------------------

CH_OBJECT=""
CH_VERB=""
CH_STATUS=""
if [[ -n "$LAST_CH_WRITE" ]]; then
    CH_OBJECT="$(echo "$LAST_CH_WRITE" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("object",""))' 2>/dev/null || true)"
    CH_VERB="$(echo "$LAST_CH_WRITE" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("verb",""))' 2>/dev/null || true)"
    CH_STATUS="$(echo "$LAST_CH_WRITE" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))' 2>/dev/null || true)"
fi

# ---------------------------------------------------------------------------
# Inject context — either corrective (missing proof) or approval preview (happy path)
# ---------------------------------------------------------------------------

export HOOK_MISSING="$MISSING"
export HOOK_COMMAND="$COMMAND"
export HOOK_TRUST_URL="$TRUST_URL"
export HOOK_SESSION_DIR="$SESSION_DIR"
export HOOK_SESSION_URL="$SESSION_DIR/README.md"
export HOOK_CH_OBJECT="$CH_OBJECT"
export HOOK_CH_VERB="$CH_VERB"
export HOOK_CH_STATUS="$CH_STATUS"
export HOOK_RUN_ID="$RUN_ID"
export HOOK_EXIT_CODE="$EXIT_CODE"

python3 <<'PYEOF' 2>/dev/null || true
import json, sys, os

missing = os.environ.get("HOOK_MISSING", "").strip("; ")
command = os.environ.get("HOOK_COMMAND", "")
trust_url = os.environ.get("HOOK_TRUST_URL", "")
session_dir = os.environ.get("HOOK_SESSION_DIR", "")
session_url = os.environ.get("HOOK_SESSION_URL", "")
ch_object = os.environ.get("HOOK_CH_OBJECT", "")
ch_verb = os.environ.get("HOOK_CH_VERB", "")
ch_status = os.environ.get("HOOK_CH_STATUS", "")
run_id = os.environ.get("HOOK_RUN_ID", "")
exit_code = os.environ.get("HOOK_EXIT_CODE", "")

parts = []

if exit_code and exit_code != "0":
    parts.append(
        f"PILOT WRITE ATTEMPT FAILED: the host-permitted command returned exit "
        f"code {exit_code}. Permission authorized the attempt; it did not prove "
        "the requested ConfigHub change. Do not claim success or silently change "
        "the command and retry. Explain the failure, then prepare a new exact "
        "command for a new host decision if remediation changes argv or scope."
    )
elif missing:
    # CORRECTIVE PATH: proof is incomplete
    parts.append(
        f"PILOT VERIFICATION REQUIRED: a host-permitted ConfigHub write attempt "
        f"returned exit 0 (`{command[:80]}...`), but exit status does not prove "
        f"the requested state and the session proof is incomplete. "
        f"Missing: {missing}."
    )
    if not trust_url:
        parts.append(
            "The CH-WRITE event has no trust URL. Before proceeding, "
            "emit a trust URL using `pilot review-surface --space "
            "<space> --unit <unit>` so the URL carries `?org=<id>` and lands "
            "in the correct org. Do NOT hand-build a `/spaces/<slug>/units/<slug>` "
            "URL and do NOT reach for the retired `get/list --web` forms — see AGENTS.md "
            "Hard Rule 5. The user needs a "
            "clickable link to verify the governed change in the GUI."
        )
    if "session not rendered" in missing or "README not generated" in missing:
        parts.append(
            "The session has not been rendered yet. This means the proof "
            "chain is not materialized as a reviewable artifact."
        )
    parts.append(
        "Run a separate, exact, read-only ConfigHub get/list command for the "
        "named object or Release, compare the observed revision or state with "
        "the requested effect, and put that observation in the receipt. Do not "
        "narrate success before that postcondition check."
    )
else:
    # The trace shell is complete, but a URL/session artifact is not itself a
    # postcondition read. Keep the closeout explicitly verification-first.
    parts.append(
        f"PILOT VERIFICATION REQUIRED: the host-permitted ConfigHub attempt "
        f"returned exit 0 for `{ch_object}` (verb: `{ch_verb}`, trace status: "
        f"`{ch_status}`). Host permission and exit 0 do not prove the requested "
        "state. Run a separate exact read-only check of the object revision or "
        "Release before closing the step."
    )
    parts.append(
        f"After that read, emit three lines: `ConfigHub attempt: {ch_verb} on "
        f"{ch_object}`; `Observed result: <verified state or explicit proof gap>`; "
        f"and `Receipt: {session_url or run_id} | Verify: {trust_url}`."
    )
    parts.append(
        "Record the read result, not the host decision, as outcome evidence. If "
        "the observed state differs, report the mismatch and ask again before "
        "changing command or scope."
    )

out = {
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": " ".join(parts),
    }
}
json.dump(out, sys.stdout)
PYEOF

exit 0
