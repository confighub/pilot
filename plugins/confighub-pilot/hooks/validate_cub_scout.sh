#!/usr/bin/env bash
# PreToolUse enforcement for the mixed-capability cub-scout provider.
#
# Scout commands in a Claude Bash call share Pilot's effect gate. A reviewed
# read runs, also when piped, redirected, chained or prefixed. A write, an
# unreviewed argv, an MCP tool call, or a line the gate cannot resolve goes to
# the host's ordinary "ask" prompt. Scout named only inside text given to
# another program is not a Scout command. Only a forbidden token, such as a
# credential flag, is stopped (operator decisions 2026-09-23 and 2026-10-11).
# This is defense in depth, not an OS/process sandbox: indirect, renamed,
# encoded, or arbitrary interpreter execution can be outside detection, so
# admitted reads remain advisory WATCH and never establish
# authoritative/T2/T3 proof.

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

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [[ -z "$PLUGIN_ROOT" ]]; then
    PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" || exit 2
fi

GATE=""
for candidate in \
    "${PILOT_ROOT:-}/scripts/pilot-provider-freshness-audit" \
    "${PILOT_HOME:-}/scripts/pilot-provider-freshness-audit" \
    "$PLUGIN_ROOT/../../scripts/pilot-provider-freshness-audit"; do
    if [[ -f "$candidate" ]]; then
        GATE="$candidate"
        break
    fi
done

RAW_INPUT="$(cat)"

# Run the gate with the interpreter that belongs to the install that owns it.
# An installed gate lives at <venv>/share/confighub-pilot/scripts/, and only
# <venv>/bin/python3 can import the confighub_pilot package it needs; whatever
# python3 is first on PATH usually cannot. A source checkout has no interpreter
# three levels above its scripts directory and keeps using python3 from PATH.
GATE_PYTHON=""
if [[ -n "$GATE" ]]; then
    GATE_PYTHON="$(dirname "$GATE")/../../../bin/python3"
    if [[ ! -f "$GATE_PYTHON" || ! -x "$GATE_PYTHON" ]]; then
        GATE_PYTHON="$(command -v python3 2>/dev/null || true)"
    fi
fi

if [[ -n "$GATE" && -n "$GATE_PYTHON" ]]; then
    # The gate answers with status 0 (run, or an ask decision on stdout) or 2
    # (blocked). Any other status means the gate itself did not work, for
    # example a missing module. Hold its output until the status is known, so
    # a broken gate reaches the "gate unavailable" branch below instead of
    # showing its traceback as a hook error and silently skipping the check.
    # With pipefail a status of 0 can only mean the gate read its whole input
    # and answered 0.
    GATE_FRAME=$'\x1e'
    gate_capture="$(
        {
            gate_status=0
            gate_stdout="$(printf '%s' "$RAW_INPUT" | "$GATE_PYTHON" "$GATE" --claude-hook)" || gate_status=$?
            printf '%s%s%s%s' "$GATE_FRAME" "$gate_status" "$GATE_FRAME" "$gate_stdout"
        } 2>&1
    )" || gate_capture=""
    gate_stderr="${gate_capture%%"$GATE_FRAME"*}"
    gate_rest="${gate_capture#*"$GATE_FRAME"}"
    gate_status="${gate_rest%%"$GATE_FRAME"*}"
    gate_stdout="${gate_rest#*"$GATE_FRAME"}"
    if [[ "$gate_capture" == *"$GATE_FRAME"*"$GATE_FRAME"* && ( "$gate_status" == "0" || "$gate_status" == "2" ) ]]; then
        if [[ -n "$gate_stderr" ]]; then
            printf '%s\n' "$gate_stderr" >&2
        fi
        if [[ -n "$gate_stdout" ]]; then
            printf '%s\n' "$gate_stdout"
        fi
        exit "$gate_status"
    fi
fi

# The enforcement helper is itself load-bearing. If it is unavailable, block
# any apparent Scout path instead of silently allowing a mixed-effect binary.
# A command that does not mention Scout is not this hook's business and runs.
# The match is done by Bash itself, so it cannot be lost to a failed helper.
SCOUT_PATH_PATTERN='cub-scout|cub[[:space:]]+scout|mcp__cub-scout__'
if [[ "$RAW_INPUT" =~ $SCOUT_PATH_PATTERN ]]; then
    python3 - <<'PY' 2>/dev/null || printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","decision":"block","reason":"Pilot Scout effect gate unavailable; blocking mixed-capability provider execution."}}'
import json
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "decision": "block",
    "reason": "Pilot Scout effect gate unavailable; blocking mixed-capability provider execution.",
}}))
PY
    exit 2
fi

exit 0
