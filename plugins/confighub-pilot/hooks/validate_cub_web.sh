#!/usr/bin/env bash
#
# PreToolUse hook: warn (non-blocking) when the retired `cub <noun> ... --web`
# form is reached for from a Bash invocation.
#
# Context: issue pilot#468. Customer-reported P1 from a live BYO kubara
# session, 2026-05-12. The former command also dropped `?org=<id>` from the
# produced URL. cub v0.2.9 no longer exposes `get/list --web`; the URL helpers
# (`confighub-gui-urls`, `cub-view-explorer-url`, `confighub-review-surface`)
# resolve `OrganizationID` from a real `cub` read and attach `?org=` so the
# URL lands in the correct org.
#
# AGENTS.md Hard Rules 5 and 9 forbid this; the original rule was prose-only
# until this hook was added.
#
# Behaviour:
#   - Detects `cub <subcommand> ... --web` in PreToolUse Bash input
#   - Emits a warning to stderr naming the doctrine doc + the helper to use
#   - DOES NOT block (exit 0 always) — preserves the debugging escape hatch
#   - Whitelists the helper scripts and this validator so quoted legacy
#     doctrine inside their own commands is not mistaken for execution:
#       - cub-view-explorer-url
#       - confighub-gui-urls
#       - confighub-review-surface
#       - validate_cub_web (this hook)
#       - validate_cub_flags
#
# To suppress the warning for a specific debugging session:
#   CONFIGHUB_AI_SKIP_CUB_WEB_WARN=1
#
# Reference: docs/user/HOW_PILOT_WORKS.md

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

# Escape hatch for scripted bulk-debugging runs.
if [[ "${CONFIGHUB_AI_SKIP_CUB_WEB_WARN:-0}" == "1" ]]; then
    exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
    exit 0
fi

COMMAND="$(python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
tool_input = data.get("tool_input", {}) or {}
cmd = tool_input.get("command", "") or ""
print(cmd.replace("\n", " "))
' 2>/dev/null || true)"

if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# Strip leading env-var assignments and timeout/perl wrappers, mirroring
# validate_cub_flags.sh so the hook fires on the same shape of input.
COMMAND="$(printf '%s' "$COMMAND" | sed -E 's#^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)+##')"
COMMAND="$(printf '%s' "$COMMAND" | sed -E "s#^(/usr/bin/env[[:space:]]+)?([^[:space:]]*/)?perl[[:space:]]+-e[[:space:]]+['\"]alarm shift; exec @ARGV['\"][[:space:]]+[0-9]+[[:space:]]+##")"
COMMAND="$(printf '%s' "$COMMAND" | sed -E 's#^(g?timeout)[[:space:]]+(-[A-Za-z0-9]+[[:space:]]+|--[A-Za-z-]+(=[^[:space:]]+)?[[:space:]]+)*[0-9]+[smhd]?[[:space:]]+##')"

# Only act when `cub <subcommand>` is the actual command the shell would run,
# not when it merely appears as literal text inside a quoted argument. Mirrors
# the matcher in validate_cub_flags.sh.
if ! echo "$COMMAND" | grep -qE '(^|[ ]*\||[ ]*&&|[ ]*;)[ ]*([A-Z_][A-Za-z0-9_]*=[^ ]+ +)*cub (run|unit|revision|space|component|worker|target|filter|function|changeset|cluster|k8s|resource|link|info|auth|gitops|organization|view)\b'; then
    exit 0
fi

# Skip --help / -h (read-only introspection)
if echo "$COMMAND" | grep -qE '(^|[ ])(--help|-h)($|[ ])'; then
    exit 0
fi

# Skip git/echo/cat/printf/tee/gh that may contain --web inside quoted args
if echo "$COMMAND" | grep -qE '^[ ]*(git[ ]+commit|echo|cat|printf|tee|gh[ ]+issue|gh[ ]+pr)'; then
    exit 0
fi

# Helper-script whitelist: quoted doctrine is not an attempted cub invocation.
if echo "$COMMAND" | grep -qE '(cub-view-explorer-url|confighub-gui-urls|confighub-review-surface|validate_cub_web|validate_cub_flags)'; then
    exit 0
fi

# Detect `--web` flag presence. Matches `--web` followed by space, end of
# string, or `=` (defensive — current cub does not use --web=value).
if ! echo "$COMMAND" | grep -qE -- '--web([= ]|$)'; then
    exit 0
fi

# Emit the warning to stderr. Non-blocking — exit 0 below.
cat >&2 <<'WARN'
WARN: retired 'cub get/list --web' form detected. It is absent from cub v0.2.9,
and its former URL shape did not preserve Pilot's verified object/org scope.
Use the canonical URL helper instead:

  - Space or unit URL:  pilot review-surface --space <space> [--unit <unit> ...]
  - View Explorer URL:  pilot review-surface --space <space> --view <view>
  - Review surface:     pilot review-surface --space <space> --view <view>

The helpers read `cub` JSON for real IDs, attach `?org=<id>`, and surface a
structured `GUI_URL_UNVERIFIED` failure when the org/object cannot be
resolved.

Current cub convenience siblings (not substitutes for Pilot URL proof):

  cub space open <space> --print-url
  cub unit open <unit> --space <space> --print-url
  cub component open <component> --print-url
  cub cluster open <cluster> --print-url

See AGENTS.md Hard Rules 5 and 9 for the full doctrine. This is a non-blocking
warning; current cub will still reject the retired form. Suppress
with CONFIGHUB_AI_SKIP_CUB_WEB_WARN=1 for scripted debugging.
WARN

# Best-effort trace event (cub-web-anti-pattern). Silent on any failure so the
# hook itself never breaks the Bash call. The trace status records that the
# warning hook completed; its metadata carries the truthful WATCH/non-enforced
# outcome so receipt consumers do not infer a block that never happened.
TRACE_EMIT="${PILOT_ROOT:-}/scripts/cub-trace-emit"
if [[ -x "$TRACE_EMIT" ]]; then
    "$TRACE_EMIT" event CH-READ guard cub-url \
        --status completed \
        --kind cub-web-anti-pattern \
        --message "retired cub get/list --web reach intercepted" \
        --meta '{"ref":"AGENTS.md#hard-rules-5-and-9","legacy":"VERSIONED_LEGACY","verdict":"WATCH","enforced":false,"hook":"validate_cub_web.sh"}' \
        >/dev/null 2>&1 || true
fi

# Never block — exit 0 unconditionally.
exit 0
