#!/usr/bin/env bash
#
# PreToolUse hook: per-tool-group skill attribution (issue #495 Layer 1).
#
# When the agent runs a Bash command whose shape matches a known ConfigHub
# skill body, emit one line to stderr naming the skill:
#
#   → Using: cub-query    (cub unit list / cub unit get)
#   → Using: cub-mutate   (cub function do / cub unit update / cub run)
#   → Using: cub-apply    (cub unit apply / cub unit approve)
#   → Using: worker-bootstrap   (cub worker install)
#   → Using: target-bind        (cub target create / cub target update)
#   → Using: import      (cub helm install/upgrade/template — since cub
#                          v0.1.99 these come from the confighub/cub-helm
#                          plugin, still invoked as `cub helm`)
#   → Using: ingest-iac-to-confighub   (cub gitops discover/import)
#
# This makes the kubara-style "50 Bash blocks with no skill name visible"
# regression visible — the user can finally see which skill is firing right
# now (the explicit ask in the customer signal that opened #495).
#
# Behaviour:
#   - Always exits 0 — this hook never blocks a command.
#   - kubectl, git, gh, plain cub --help, and quoted/heredoc cub references
#     are ignored (same heuristic as validate_cub_flags.sh).
#   - Output is one stderr line per matching command; never stdout.
#   - Disable with CONFIGHUB_AI_SKIP_SKILL_ATTRIBUTION=1.
#
# Wired into:
#   - plugins/confighub-ai/hooks/hooks.json PreToolUse Bash (plugin packaging)

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

if [[ "${CONFIGHUB_AI_SKIP_SKILL_ATTRIBUTION:-0}" == "1" ]]; then
    exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
    exit 0
fi

COMMAND="$(python3 -c '
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
tool_input = data.get("tool_input", {}) or {}
cmd = tool_input.get("command", "") or ""
if target_access_content_policy(cmd) != "unrelated":
    sys.exit(0)
print(cmd.replace("\n", " "))
' 2>/dev/null || true)"

[[ -z "$COMMAND" ]] && exit 0

# Strip leading env-var assignments and timeout wrappers so the actual
# command word lands at the start. Same approach as validate_cub_flags.sh.
COMMAND="$(printf '%s' "$COMMAND" | sed -E 's#^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)+##')"
COMMAND="$(printf '%s' "$COMMAND" | sed -E 's#^(g?timeout)[[:space:]]+(-[A-Za-z0-9]+[[:space:]]+|--[A-Za-z-]+(=[^[:space:]]+)?[[:space:]]+)*[0-9]+[smhd]?[[:space:]]+##')"

# Skip quoted / heredoc / commit-message contexts: we only want to attribute
# when cub is the actual command word the shell will run.
if echo "$COMMAND" | grep -qE '^[ ]*(git[ ]+commit|echo|cat|printf|tee|gh[ ]+issue|gh[ ]+pr)'; then
    exit 0
fi

# Skip read-only --help / -h invocations.
if echo "$COMMAND" | grep -qE '(^|[ ])(--help|-h)($|[ ])'; then
    exit 0
fi

# Only act when `cub <subcommand>` is the first real command word, optionally
# preceded by env-var assignments or pipeline connectors. Mirrors the gate in
# validate_cub_flags.sh — keeps quoted cub references from triggering.
if ! echo "$COMMAND" | grep -qE '(^|[ ]*\||[ ]*&&|[ ]*;)[ ]*([A-Z_][A-Za-z0-9_]*=[^ ]+ +)*cub (run|unit|revision|space|worker|target|filter|function|changeset|cluster|k8s|resource|link|info|auth|helm|gitops|invocation|organization|org|orgs|organisation|organisations)\b'; then
    exit 0
fi

SKILL=""

# Lookup table — order matters: more specific shapes first so cub-mutate's
# `cub run` match beats nothing, and `cub unit apply/approve` beats
# `cub unit get/list`.
if echo "$COMMAND" | grep -qE 'cub (unit )?apply\b'; then
    SKILL="cub-apply"
elif echo "$COMMAND" | grep -qE 'cub unit (approve|reject|unapprove)\b'; then
    SKILL="cub-apply"
elif echo "$COMMAND" | grep -qE 'cub function do\b'; then
    SKILL="cub-mutate"
elif echo "$COMMAND" | grep -qE 'cub run set-[A-Za-z0-9-]+'; then
    SKILL="cub-mutate"
elif echo "$COMMAND" | grep -qE 'cub unit (update|create)\b'; then
    SKILL="cub-mutate"
elif echo "$COMMAND" | grep -qE 'cub worker (install|delete|uninstall|create)\b'; then
    SKILL="worker-bootstrap"
elif echo "$COMMAND" | grep -qE 'cub target (create|update|delete)\b'; then
    SKILL="target-bind"
elif echo "$COMMAND" | grep -qE 'cub helm (install|upgrade|template)\b'; then
    SKILL="import"
elif echo "$COMMAND" | grep -qE 'cub gitops (discover|import)\b'; then
    SKILL="ingest-iac-to-confighub"
elif echo "$COMMAND" | grep -qE 'cub invocation create\b'; then
    SKILL="app-config"
elif echo "$COMMAND" | grep -qE 'cub (unit (list|get|tree|data)|revision list|space list|target list|worker list|filter list|function list)\b'; then
    SKILL="cub-query"
fi

if [[ -n "$SKILL" ]]; then
    # One-line stderr emission. Never stdout (would interleave with tool
    # output the user is reading). Never blocks (exit 0 below).
    printf '→ Using: %s\n' "$SKILL" >&2
fi

exit 0
