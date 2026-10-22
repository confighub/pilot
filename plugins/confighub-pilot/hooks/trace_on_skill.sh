#!/usr/bin/env bash
#
# PreToolUse hook for Skill tool calls.
#
# When Claude loads a skill, this hook emits a lane-tagged trace event
# so the user sees which skill fired and why. Without this, skill loads
# are invisible — only Bash commands get traced.
#
# Lane: SKILL-LOAD (new lane, distinct from the 5 operational lanes).
# This doesn't participate in the CH-WRITE/CH-READ/LIVE-READ/EXT-WRITE/
# GIT-READ classification because a skill load is meta — it's the agent
# choosing a tool, not using one. But it's still a visible event.
#
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

# Find the trace emitter
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [[ -z "$PLUGIN_ROOT" ]]; then
    PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" || exit 0
fi

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
    exit 0
fi

# Extract the skill name from stdin JSON
if ! command -v python3 >/dev/null 2>&1; then
    exit 0
fi

SKILL_NAME="$(python3 -c '
import json, os, re, sys
from pathlib import Path

script_candidates = []
for variable in ("PILOT_HOME", "PILOT_ROOT"):
    value = os.environ.get(variable, "")
    if value:
        script_candidates.append(Path(value).expanduser() / "scripts")
plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT", "")
if plugin_root:
    script_candidates.append(Path(plugin_root).expanduser().resolve().parents[1] / "scripts")
for scripts in script_candidates:
    if scripts.is_dir():
        sys.path.insert(0, str(scripts))
        break

try:
    from pilot_common import target_access_request_policy
except ImportError:
    def target_access_request_policy(text):
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
if tool_name != "Skill":
    sys.exit(0)
tool_input = data.get("tool_input", {}) or {}
skill = tool_input.get("skill", "") or ""
if not skill:
    sys.exit(0)
if target_access_request_policy(skill) != "unrelated":
    # A skill name is caller-controlled hook input. Do not trace or reflect a
    # target-access subject through the generic skill-attribution surface.
    sys.exit(0)
print(skill)
' 2>/dev/null || true)"

if [[ -z "$SKILL_NAME" ]]; then
    exit 0
fi

# Emit the trace event
export CUB_TRACE_FORCE_COLOR=1
"$PILOT_SCRIPTS/cub-trace-emit" event "SKILL-LOAD" "load" "$SKILL_NAME" \
    --status started \
    --command "Skill($SKILL_NAME)" \
    --message "skill-load: $SKILL_NAME" \
    || true

# Inject context back to Claude
export HOOK_SKILL="$SKILL_NAME"
python3 <<'PYEOF' 2>/dev/null || true
import json, sys, os

skill = os.environ.get("HOOK_SKILL", "")

out = {
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "additionalContext": (
            f"Skill loaded: **{skill}**. Read the skill body carefully "
            f"and follow its instructions — especially the 'What the user "
            f"will see' section, the chain-to rules, and the stop condition. "
            f"Do NOT drop into raw Bash exploration after loading a skill. "
            f"The skill body tells you exactly what commands to run and in "
            f"what order."
        ),
    }
}
json.dump(out, sys.stdout)
PYEOF

exit 0
