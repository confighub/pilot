#!/usr/bin/env bash
#
# PreToolUse hook for the confighub-ai plugin.
#
# Intercepts every Bash tool call Claude is about to run, classifies the
# command into a lane using scripts/cub-trace-classify from the Pilot repo,
# and emits a lane-tagged trace event via scripts/cub-trace-emit.
#
# The hook reads the tool input JSON on stdin (per the Claude Code hook
# protocol), extracts .tool_input.command, classifies it, and emits two
# outputs:
#
# 1. A trace event (stdout lane-tagged line + EVENTS.jsonl append)
# 2. A hookSpecificOutput.additionalContext JSON object that injects a
#    short "you just classified this as LANE X" reminder back into
#    Claude's context, so Claude's next output can reference the lane
#    meaningfully.
#
# The script is conservative: if the command doesn't classify cleanly,
# it emits nothing and returns 0. If cub-trace-classify or cub-trace-emit
# is missing or broken, the hook silently fails. A hook failure MUST NEVER
# block the tool call.

set -euo pipefail

# Session-scoped activation (#764): presence hooks stay dormant unless the
# session was launched through Pilot (`pilot claude launch` sets PILOT_ACTIVE=1).
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
#
# CLAUDE_PLUGIN_ROOT is set by Claude Code for plugins and expands to the
# plugin's root directory. The plugin ships from plugins/confighub-ai/ inside
# the Pilot repo, so the scripts dir is two levels up.
#
# When the plugin is installed standalone (not inside a clone of the Pilot
# repo), CLAUDE_PLUGIN_ROOT points at the plugin cache dir. In that case
# we fall back to PILOT_ROOT if set, otherwise silently no-op.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [[ -z "$PLUGIN_ROOT" ]]; then
    # Direct source-checkout invocation: derive PLUGIN_ROOT from the script's
    # own location so the path resolution below still works:
    # trace_on_bash.sh is at plugins/confighub-ai/hooks/, so
    # dirname/.. → plugins/confighub-ai, and ../../scripts → scripts/.
    PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" || exit 0
fi

# Try to find the Pilot repo's scripts directory. Two ordered candidates:
# 1. PILOT_ROOT — the documented env var, set per the plugin
#    README install instructions. This is the load-bearing path for normal
#    installs (where CLAUDE_PLUGIN_ROOT is the cache dir, not the repo).
# 2. PLUGIN_ROOT relative — works only when the plugin is loaded directly
#    from a clone of the Pilot repo (plugin root plugins/confighub-ai/ in the
#    repo). This is rare in practice but kept for development setups.
PILOT_SCRIPTS=""
for candidate in \
    "${PILOT_ROOT:-}/scripts" \
    "$PLUGIN_ROOT/../../scripts"; do
    if [[ -n "$candidate" ]] && [[ -x "$candidate/cub-trace-emit" ]]; then
        PILOT_SCRIPTS="$candidate"
        break
    fi
done

if [[ -z "$PILOT_SCRIPTS" ]]; then
    # No trace scripts available — emit a one-time stderr diagnostic so the
    # user knows why the activity trace is missing, then exit silently. The
    # diagnostic must NEVER block the host bash call (the hook still exits 0).
    #
    # The marker is keyed on PPID (the parent of every hook bash invocation
    # is the same Claude Code process), so the diagnostic fires once per
    # Claude session and not once per tool call.
    DIAG_MARKER="${TMPDIR:-/tmp}/confighub-ai-hook-diag-${PPID:-unknown}"
    if [[ ! -f "$DIAG_MARKER" ]]; then
        touch "$DIAG_MARKER" 2>/dev/null || true
        cat >&2 <<'DIAG'
[confighub-ai hook] activity trace disabled — could not find scripts/cub-trace-emit.
[confighub-ai hook] To enable: clone https://github.com/confighubai/pilot
[confighub-ai hook] then export PILOT_ROOT=/path/to/pilot
[confighub-ai hook] in your shell rc and restart Claude Code. See plugin README §Install.
DIAG
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# Read the hook input JSON from stdin and extract the bash command
# ---------------------------------------------------------------------------

if ! command -v python3 >/dev/null 2>&1; then
    exit 0
fi

export PILOT_HOOK_SCRIPTS="$PILOT_SCRIPTS"

# Issue #159: preserve the full multiline command in a separate field so
# trace events do not silently flatten newlines into one line. The single-line
# COMMAND is still used for classifier regex/slug extraction (which expects a
# single-line shape), but COMMAND_FULL_JSON is a JSON-encoded string of the
# original command (newlines intact) that we attach to the event's :meta blob.
PYTHON_OUT="$(python3 -c '
import json
import os
import re
import sys
from pathlib import Path

scripts = os.environ.get("PILOT_HOOK_SCRIPTS", "")
if scripts:
    sys.path.insert(0, str(Path(scripts)))

try:
    from pilot_common import target_access_content_policy
except ImportError:
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

target_policy = target_access_content_policy(command)
if target_policy != "unrelated":
    print("__PILOT_TARGET_ACCESS_PARTITIONED__")
    print(target_policy)
    sys.exit(0)

# Line 1: command flattened to a single line (shell-consumable). Issue #159:
# the classifier/slug-extraction logic downstream relies on a single-line
# shape, so we keep this for backward-compatible behavior.
# Line 2: JSON-encoded full command (newlines preserved) for the cmd_full
# meta field, so downstream consumers can recover the full input.
print(command.replace("\n", " "))
print(json.dumps(command))
' 2>/dev/null || true)"

if [[ -z "$PYTHON_OUT" ]]; then
    exit 0
fi

if [[ "$(printf '%s' "$PYTHON_OUT" | sed -n '1p')" == "__PILOT_TARGET_ACCESS_PARTITIONED__" ]]; then
    export PILOT_HOOK_TARGET_ACCESS_POLICY="$(printf '%s' "$PYTHON_OUT" | sed -n '2p')"
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
    "TARGET-ACCESS PARTITION (Pilot): this Bash call concerns ConfigHub target "
    "access, so the generic activity hook did not quote or write its command "
    "to the activity trace. Do not present this hook as execution, approval, "
    "or proof. Route the request through `pilot ask \""
    + canonical
    + "\" --json` and follow its typed proposal-only boundary."
)
json.dump(
    {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "additionalContext": context,
        }
    },
    sys.stdout,
)
PYEOF
    exit 0
fi

COMMAND="$(printf '%s' "$PYTHON_OUT" | sed -n '1p')"
COMMAND_FULL_JSON="$(printf '%s' "$PYTHON_OUT" | sed -n '2p')"
INNER_COMMAND="$(printf '%s' "$COMMAND" | sed -E 's#^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)+##')"
INNER_COMMAND="$(printf '%s' "$INNER_COMMAND" | sed -E "s#^(/usr/bin/env[[:space:]]+)?([^[:space:]]*/)?perl[[:space:]]+-e[[:space:]]+['\"]alarm shift; exec @ARGV['\"][[:space:]]+[0-9]+[[:space:]]+##")"
INNER_COMMAND="$(printf '%s' "$INNER_COMMAND" | sed -E 's#^(g?timeout)[[:space:]]+(-[A-Za-z0-9]+[[:space:]]+|--[A-Za-z-]+(=[^[:space:]]+)?[[:space:]]+)*[0-9]+[smhd]?[[:space:]]+##')"
# Look through a leading `--context <name>` so the object label names the verb
# (`cub/release/publish`), not the flag.
INNER_COMMAND="$(printf '%s' "$INNER_COMMAND" | sed -E 's#^cub[[:space:]]+--context(=|[[:space:]]+)[^[:space:]]+[[:space:]]+#cub #')"

# ---------------------------------------------------------------------------
# Classify the command and emit a trace event
# ---------------------------------------------------------------------------

# Force cub-trace-emit to emit ANSI colors even though our stdout is a pipe
# (captured by Claude Code's hook handler, not a TTY). The hook handler's
# rendering path interprets ANSI when it surfaces the hook output to the
# user, so the lane tag will show in its phosphor palette color (green for
# CH-WRITE, amber for LIVE-READ, cyan for CH-READ, red-orange for EXT-WRITE,
# blue for GIT-READ, bright green for PROOF). A plain `[[ -t 1 ]]` TTY check
# would otherwise suppress colors here and the UVB promise would silently
# degrade to monochrome.
export CUB_TRACE_FORCE_COLOR=1

CLASSIFY_JSON="$("$PILOT_SCRIPTS/cub-trace-classify" --json "$INNER_COMMAND" 2>/dev/null || true)"
if [[ -z "$CLASSIFY_JSON" ]]; then
    # No classification — the command isn't one of the ConfigHub family tools
    # we care about. Silent no-op.
    exit 0
fi

# Parse {lane, verb, kind} from the classifier's JSON output. Use python3
# (already a hard requirement at line 90 of this file). On any parse failure,
# fall back to the lane-verb split so a broken JSON never blocks the tool call.
LANE=""
VERB=""
KIND=""
PARSE_OUT="$(printf '%s' "$CLASSIFY_JSON" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print(d.get("lane",""))
print(d.get("verb",""))
print(d.get("kind",""))
' 2>/dev/null || true)"
if [[ -n "$PARSE_OUT" ]]; then
    LANE="$(printf '%s' "$PARSE_OUT" | sed -n '1p')"
    VERB="$(printf '%s' "$PARSE_OUT" | sed -n '2p')"
    KIND="$(printf '%s' "$PARSE_OUT" | sed -n '3p')"
fi
if [[ -z "$LANE" ]]; then
    # JSON parse degraded — fall back to --verb mode so the hook still emits.
    LANE_VERB="$("$PILOT_SCRIPTS/cub-trace-classify" --verb "$INNER_COMMAND" 2>/dev/null || true)"
    [[ -z "$LANE_VERB" ]] && exit 0
    LANE="${LANE_VERB%% *}"
    VERB="${LANE_VERB#* }"
fi

# Extract a compact "object" for the trace event. For cub commands, the
# object is typically the unit/space; for kubectl it's the resource type.
# Keep it simple — the raw command is already in the event's `command` field.
OBJECT="$(echo "$INNER_COMMAND" | awk '{print $1, $2, $3}' | tr ' ' '/' | sed 's|/$||')"
if [[ -z "$OBJECT" ]]; then
    OBJECT="shell-command"
fi

# ---------------------------------------------------------------------------
# Construct a trust URL (hub.confighub.com) for CH-* lane events so the user
# gets a clickable GUI link inline in Claude's narration instead of only at
# the final ops-closeout footer.
#
# Issue #32 (2026-04-19): the previous implementation scraped slugs from raw
# bash command strings using a loose regex + "last non-flag token" heuristic.
# Shell-redirection tail tokens (`2>&1`, `head`, `-3`, etc.) leaked through
# as unit slugs, producing trust URLs like
# `https://hub.confighub.com/spaces/foo/units/2>&1`.
#
# This rewrite:
#   1. Strips pipeline / redirection tail before parsing — only the first
#      shell command fragment is considered.
#   2. Validates extracted slugs against a strict ConfigHub-slug regex
#      (lowercase ASCII letters, digits, `-`, `_`, `.`, length 1..200).
#   3. If any extracted slug fails validation, the URL falls back to the
#      space-only URL (or the org root) — never emits an invalid /units path.
#
# Env vars:
#   CUB_HUB_URL  — override the base URL (default https://hub.confighub.com)
# ---------------------------------------------------------------------------

# A valid ConfigHub slug: lowercase letters, digits, dot, dash, underscore.
# Length 1..200. No shell metacharacters, no path separators.
_is_valid_slug() {
    local s="$1"
    [[ -z "$s" ]] && return 1
    [[ ${#s} -gt 200 ]] && return 1
    # Reject anything containing shell metacharacters or non-slug chars
    [[ "$s" =~ ^[A-Za-z0-9._-]+$ ]]
}

TRUST_URL=""
if [[ "$LANE" == CH-* ]]; then
    HUB_BASE="${CUB_HUB_URL:-https://hub.confighub.com}"

    # Strip pipeline / redirection tail: only consider the first command
    # fragment up to the first |, >, <, ;, &&, ||, 2>, 2>&1, etc.
    # This is conservative — we'd rather miss a slug than parse a redirection.
    CMD_HEAD="$(printf '%s' "$INNER_COMMAND" | sed -E 's/[[:space:]]*[|;].*$//; s/[[:space:]]*&&.*$//; s/[[:space:]]*\|\|.*$//; s/[[:space:]]*[12]?>.*$//')"

    # Extract --space <slug>
    SPACE_SLUG="$(printf '%s' "$CMD_HEAD" | sed -n 's/.*--space[= ]\([A-Za-z0-9._-]\{1,\}\).*/\1/p' | head -1)"
    if ! _is_valid_slug "$SPACE_SLUG"; then
        SPACE_SLUG=""
    fi

    # Extract --unit <slug>
    UNIT_SLUG="$(printf '%s' "$CMD_HEAD" | sed -n 's/.*--unit[= ]\([A-Za-z0-9._-]\{1,\}\).*/\1/p' | head -1)"

    # Positional unit slug for `cub (unit|revision) <verb> [flags...] <slug>`
    # — only consider this if we didn't get an explicit --unit. The slug is
    # the last bareword token that is not a flag and is not the verb itself.
    if [[ -z "$UNIT_SLUG" ]] && [[ "$CMD_HEAD" =~ ^cub[[:space:]]+(unit|revision)[[:space:]] ]]; then
        # awk: walk from end; first non-flag token; skip values that look like
        # they were the value of the preceding --flag (heuristic: previous
        # token starts with --). Reject anything that's not slug-shaped.
        UNIT_SLUG="$(printf '%s' "$CMD_HEAD" | awk '
            {
                for (i = NF; i >= 3; i--) {
                    tok = $i
                    if (tok ~ /^-/) continue
                    # Skip tokens that follow a --flag (likely flag values)
                    if (i > 1 && $(i-1) ~ /^--[A-Za-z0-9-]+$/) continue
                    # Reject tokens with shell metacharacters (defensive even
                    # though pipeline tail was stripped above)
                    if (tok ~ /[|<>&;()$`]/) continue
                    # Reject tokens that match the verb position
                    if (i == 3) continue
                    print tok
                    exit
                }
            }
        ')"
    fi

    if ! _is_valid_slug "$UNIT_SLUG"; then
        UNIT_SLUG=""
    fi

    # Build the URL. Strict layering: only emit /units when we have a
    # validated unit slug AND a validated space slug.
    if [[ -n "$SPACE_SLUG" ]] && [[ -n "$UNIT_SLUG" ]]; then
        TRUST_URL="$HUB_BASE/spaces/$SPACE_SLUG/units/$UNIT_SLUG"
    elif [[ -n "$SPACE_SLUG" ]]; then
        TRUST_URL="$HUB_BASE/spaces/$SPACE_SLUG"
    else
        TRUST_URL="$HUB_BASE"
    fi
fi

# Fire the trace event. Graceful degradation: || true.
# Pass --url only when we have one (avoids empty-url events for non-CH lanes).
# Pass --kind only when the classifier returned one (governance discrimination).
KIND_ARGS=()
if [[ -n "$KIND" ]]; then
    KIND_ARGS=(--kind "$KIND")
fi

# Issue #159: attach the full multiline command as cmd_full in :meta so the
# original input is preserved on disk. The existing `command` field stays
# single-line for backward compatibility with existing trace consumers.
META_ARGS=()
if [[ -n "$COMMAND_FULL_JSON" ]]; then
    META_ARGS=(--meta "{\"cmd_full\":$COMMAND_FULL_JSON}")
fi

if [[ -n "$TRUST_URL" ]]; then
    "$PILOT_SCRIPTS/cub-trace-emit" event "$LANE" "$VERB" "$OBJECT" \
        --status started \
        --command "$COMMAND" \
        --url "$TRUST_URL" \
        --message "pre-tool-use: $LANE $VERB $COMMAND" \
        "${KIND_ARGS[@]}" \
        "${META_ARGS[@]}" \
        || true
else
    "$PILOT_SCRIPTS/cub-trace-emit" event "$LANE" "$VERB" "$OBJECT" \
        --status started \
        --command "$COMMAND" \
        --message "pre-tool-use: $LANE $VERB $COMMAND" \
        "${KIND_ARGS[@]}" \
        "${META_ARGS[@]}" \
        || true
fi

SESSION_URL=""
if [[ -x "$PILOT_SCRIPTS/cub-trace-session" ]]; then
    SESSION_URL="$("$PILOT_SCRIPTS/cub-trace-session" current 2>/dev/null || true)"
fi

# ---------------------------------------------------------------------------
# Inject a lane-narration directive back into Claude's context via
# hookSpecificOutput.additionalContext. This is the load-bearing UVB
# delivery path in Claude Code sessions.
#
# Context on why this matters: Claude Code's Bash tool renders command
# output as a code block, which FLATTENS ANSI escape codes to literal
# text. That means cub-trace-emit's colored `[CH-WRITE ] pre-tool-use:`
# stdout line — which is meant to be the user's visible lane signal —
# never actually renders on screen in Claude Code. The hook fires, the
# event lands in EVENTS.jsonl (durable residue), but the user sees
# nothing. That violates the "No Hidden Value" UVB principle.
#
# Fix: the additionalContext below instructs Claude to emit a
# markdown-bold lane marker in its NEXT assistant response, BEFORE it
# narrates the command's result. Claude's assistant text IS rendered
# as markdown in the Claude Code UI, so **[CH-WRITE]** will appear
# bold on screen. That delivers the UVB promise via a surface Claude
# Code actually renders.
#
# Downstream rendering surfaces:
#   - Terminal.app (raw shell session): ANSI from cub-trace-emit
#     renders correctly with the phosphor-green profile.
#   - Claude Code UI: markdown bold from Claude's narration renders.
#   - EVENTS.jsonl: durable, machine-parseable, always on.
# ---------------------------------------------------------------------------

# Export LANE, VERB, TRUST_URL for the python3 block below so we read them
# via os.environ instead of via shell substitution into a python -c string.
# Shell substitution into python -c is unsafe when values contain single
# quotes, backticks, dollar signs, or arbitrary markdown characters — the
# bash layer would interpret them before python sees them. Env-based
# passing is the clean fix.
export HOOK_LANE="$LANE"
export HOOK_VERB="$VERB"
export HOOK_KIND="$KIND"
export HOOK_TRUST_URL="$TRUST_URL"
export HOOK_SESSION_URL="$SESSION_URL"

python3 <<'PYEOF' 2>/dev/null || true
import json, sys, os

lane = os.environ.get("HOOK_LANE", "")
verb = os.environ.get("HOOK_VERB", "")
kind = os.environ.get("HOOK_KIND", "")
trust_url = os.environ.get("HOOK_TRUST_URL", "")
session_url = os.environ.get("HOOK_SESSION_URL", "")

base = (
    f"UVB activity trace: this bash call has been classified as lane "
    f"**[{lane}]** ({verb}) and durably written to EVENTS.jsonl. "
    f"Before you narrate the result of this bash call in your next "
    f"response, you MUST emit the lane marker as markdown bold on its "
    f"own line so the user sees which world is being touched BEFORE "
    f"the output renders. The exact shape is: a single line "
    f"containing `**[{lane}]**` (with the square brackets and bold "
    f"markers), followed by one blank line, followed by your normal "
    f"narration. This is the No-Hidden-Value acceptance criterion "
    f"from the thesis — skipping it breaks the plugin UVB promise. "
    f"If the same lane has already been emitted for a consecutive "
    f"batch of related bash calls you may batch them under a single "
    f"leading marker line. If the user has asked for visible colors, "
    f"lanes, priorities, or screenshot-worthy trust moments, do not "
    f"rely on this white markdown lane marker alone: render the trust "
    f"moment through `pilot helper confighub-ux-cockpit --force-color` with "
    f"`--lane-row` fields before normal narration."
)

# A ConfigHub link counts as verified only when it is ID-based: a
# `/spaces/<uuid>` path that carries `?org=`. A link built from names is
# unverified, so the session must not print it.
import re
id_based_url = bool(
    re.search(
        r"/spaces/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}(?:[/?#]|$)",
        trust_url,
    )
    and re.search(r"[?&]org=[^&\s]+", trust_url)
)

if trust_url and id_based_url:
    base += (
        f" Also, a trust URL has been computed for this governed "
        f"object: {trust_url} — emit it as a separate line of the "
        f"form `🔗 Open in ConfigHub: {trust_url}` immediately after the lane "
        f"marker line so the user has a clickable link to the "
        f"ConfigHub GUI in your narration flow, not just at the "
        f"final closeout."
    )
elif trust_url:
    base += (
        " Do not print a ConfigHub link built from names; a link made "
        "from a Space or Unit name is unverified. If the person wants a "
        "link, run `pilot gui-urls --space <space> [--unit <unit>] "
        "--cub-context <context>` and show what it returns."
    )

if session_url:
    if lane == "CH-WRITE" or kind in {"route-decision", "validation-result", "consistency-check", "retraction"}:
        base += (
            f" Also, a governed session artifact exists for this run at "
            f"{session_url}. Emit it as a separate line of the form "
            f"`🔗 Session: {session_url}` immediately after the trust URL "
            f"line for this governance moment so the user can inspect the "
            f"full governed sequence, not just the single command result."
        )
    else:
        base += (
            f" Also, a governed session artifact exists for this run at "
            f"{session_url}. When you are surfacing proof, approvals, or "
            f"shareable receipts, you may emit it as `🔗 Session: {session_url}` "
            f"so the user can inspect the full governed sequence, not just the "
            f"single command result."
        )

out = {
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "additionalContext": base,
    }
}
json.dump(out, sys.stdout)
PYEOF

# ---------------------------------------------------------------------------
# Self-diagnostic heartbeat (issue #30 mitigation)
#
# Every 50th hook invocation (approximated via a counter in /tmp), write a
# health marker. This lets end-of-run checks detect if the hook went quiet:
#
#   Expected: the active Pilot overlay trace EVENTS.jsonl has grown proportionally.
#   Actual:   if HEALTH marker is fresh but event count stopped growing,
#             the hook is running but cub-trace-emit is silently failing.
#
# The counter uses a per-PPID file to stay session-scoped.
# ---------------------------------------------------------------------------
HEALTH_COUNTER_FILE="${TMPDIR:-/tmp}/confighub-ai-hook-counter-${PPID:-0}"
HEALTH_MARKER_FILE="${TMPDIR:-/tmp}/confighub-ai-hook-health-${PPID:-0}"
COUNTER=0
if [[ -f "$HEALTH_COUNTER_FILE" ]]; then
    COUNTER="$(cat "$HEALTH_COUNTER_FILE" 2>/dev/null || echo 0)"
fi
COUNTER=$(( COUNTER + 1 ))
echo "$COUNTER" > "$HEALTH_COUNTER_FILE" 2>/dev/null || true
if (( COUNTER % 50 == 0 )); then
    date -u "+%Y-%m-%dT%H:%M:%SZ hook-health count=$COUNTER ppid=${PPID:-0}" \
        > "$HEALTH_MARKER_FILE" 2>/dev/null || true
fi

exit 0
