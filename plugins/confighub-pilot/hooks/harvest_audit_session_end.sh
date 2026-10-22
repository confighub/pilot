#!/usr/bin/env bash
#
# SessionEnd hook — auto-run harvest discipline audits at session end.
#
# Per the harvest-discipline "Automated enforcement" rule + issue #82 + TODO P1.5:
# every session that touches ConfigHub should auto-run the two harvest audits at
# session end so harvest discipline drifts surface immediately, not at the next
# session start.
#
# What it does:
#   1. Runs package helper audit-session-recorded --advisory --json   (catches "Unrecorded")
#   2. Runs package helper audit-session-harvested --advisory --json  (catches "Unharvested")
#   3. Surfaces ANY violations as compact lines:
#        → HARVEST: <count> stuck notes
#        → RECORDING: <count> unindexed RESULTS.md
#   4. Stays silent on a clean session — no noise when both audits pass.
#
# Advisory mode (`--advisory`) is mandatory: this hook MUST NOT block session end.
# Opt-out for genuine one-off sessions: set CONFIGHUB_AI_SKIP_HARVEST_AUDIT=1.
#
# Hook contract: emits a hookSpecificOutput JSON blob with a systemMessage
# only when there are violations. Silence on clean.

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

if [[ "${CONFIGHUB_AI_SKIP_HARVEST_AUDIT:-0}" == "1" ]]; then
    exit 0
fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [[ -z "$PLUGIN_ROOT" ]]; then
    PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" || exit 0
fi

PILOT_ROOT_DIR=""
for candidate in \
    "${PILOT_ROOT:-}" \
    "$PLUGIN_ROOT/../.."; do
    if [[ -n "$candidate" ]] && [[ -d "$candidate/scripts" ]] && [[ -f "$candidate/AGENTS.md" ]]; then
        PILOT_ROOT_DIR="$(cd "$candidate" && pwd)"
        break
    fi
done

if [[ -z "$PILOT_ROOT_DIR" ]]; then
    exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
    exit 0
fi

RECORDED_JSON=""
HARVESTED_JSON=""

if [[ -x "$PILOT_ROOT_DIR/scripts/audit-session-recorded" ]]; then
    RECORDED_JSON="$("$PILOT_ROOT_DIR/scripts/audit-session-recorded" --advisory --json 2>/dev/null || true)"
fi

if [[ -x "$PILOT_ROOT_DIR/scripts/audit-session-harvested" ]]; then
    HARVESTED_JSON="$("$PILOT_ROOT_DIR/scripts/audit-session-harvested" --advisory --json 2>/dev/null || true)"
fi

export RECORDED_JSON HARVESTED_JSON

python3 <<'PYEOF' 2>/dev/null || true
import json
import os
import sys

def _safe_load(s: str) -> dict:
    if not s:
        return {}
    try:
        return json.loads(s)
    except Exception:
        return {}

recorded = _safe_load(os.environ.get("RECORDED_JSON", ""))
harvested = _safe_load(os.environ.get("HARVESTED_JSON", ""))

# audit-session-recorded violations: count unindexed RESULTS.md (kind=results_not_indexed)
recording_violations = 0
for v in recorded.get("violations", []) or []:
    if v.get("kind") == "results_not_indexed":
        recording_violations += 1

# audit-session-harvested violations: stuck_count = memory notes that didn't graduate
harvest_stuck = int(harvested.get("stuck_count", 0) or 0)

lines = []
if harvest_stuck > 0:
    lines.append(f"→ HARVEST: {harvest_stuck} stuck notes")
if recording_violations > 0:
    lines.append(f"→ RECORDING: {recording_violations} unindexed RESULTS.md")

if not lines:
    # Clean — silence.
    sys.exit(0)

message = "\n".join([
    "Harvest discipline audit (advisory) flagged violations:",
    *lines,
    "",
    "Run for detail:",
    "  package helper audit-session-harvested --advisory",
    "  package helper audit-session-recorded --advisory",
])

out = {
    "hookSpecificOutput": {
        "hookEventName": "SessionEnd",
        "additionalContext": message,
    },
    "systemMessage": message,
}
json.dump(out, sys.stdout)
PYEOF

exit 0
