#!/usr/bin/env bash
#
# PreToolUse hook: validate cub CLI flag forms before the command runs.
#
# Catches hallucinated flags and subcommands confirmed in live sessions:
#
#   1. `cub revision list --limit <n>`          — no --limit flag exists
#      (fresh-session hallucination 2026-04-19, during BYO quickstart test)
#   2. `cub revision list --unit <slug>`        — unit is positional
#   3. `cub revision approve`                   — non-existent subcommand
#      (approval is a Space-level attestation now: `cub variant approve`)
#   4. `cub run set-container-image --container <name>` — wrong flag
#      (must be --container-name)
#   5. `cub org get <id>`                       — non-existent alias
#      (should be `cub organization get <id>`)
#
# Behaviour mirrors validate_cub_scout.sh:
#   - Non-cub commands: exit 0 silently
#   - cub with bad flags/verbs: output JSON block decision + exit 2
#   - cub with good flags: exit 0 silently

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

COMMAND="$(printf '%s' "$COMMAND" | sed -E 's#^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)+##')"
COMMAND="$(printf '%s' "$COMMAND" | sed -E "s#^(/usr/bin/env[[:space:]]+)?([^[:space:]]*/)?perl[[:space:]]+-e[[:space:]]+['\"]alarm shift; exec @ARGV['\"][[:space:]]+[0-9]+[[:space:]]+##")"
COMMAND="$(printf '%s' "$COMMAND" | sed -E 's#^(g?timeout)[[:space:]]+(-[A-Za-z0-9]+[[:space:]]+|--[A-Za-z-]+(=[^[:space:]]+)?[[:space:]]+)*[0-9]+[smhd]?[[:space:]]+##')"

# Only act when `cub <subcommand>` is the actual command the shell would run,
# not when it merely appears as literal text inside a quoted argument (e.g.,
# `git commit -m "...cub revision list --limit..."` or an echo/cat heredoc).
#
# Heuristic: cub must be the first real command word, optionally preceded by
# env-var assignments (FOO=bar KUBECONFIG=/path) or pipeline/logical
# connectors (|, &&, ;). We do NOT match when cub is inside a quoted string.
#
# Pattern: start-of-line (or after |/&/;) followed by zero-or-more VAR=val
# assignments, then literal `cub <subcommand>`.
if ! echo "$COMMAND" | grep -qE '(^|[ ]*\||[ ]*&&|[ ]*;)[ ]*([A-Z_][A-Za-z0-9_]*=[^ ]+ +)*cub (run|unit|revision|space|worker|target|filter|function|changeset|cluster|k8s|resource|link|info|auth|gitops|organization|org|orgs|organisation|organisations)\b'; then
    exit 0
fi

# Also skip any --help / -h invocation (read-only introspection)
if echo "$COMMAND" | grep -qE '(^|[ ])(--help|-h)($|[ ])'; then
    exit 0
fi

# Skip when the command is clearly git/echo/cat/printf/tee that may contain
# cub patterns inside their quoted args (belt + suspenders over the regex above)
if echo "$COMMAND" | grep -qE '^[ ]*(git[ ]+commit|echo|cat|printf|tee|gh[ ]+issue|gh[ ]+pr)'; then
    exit 0
fi

BLOCK_REASON=""

# Pattern 0: cub org/orgs/organisation  (non-existent aliases; use organization)
if echo "$COMMAND" | grep -qE 'cub (org|orgs|organisation|organisations)([ ]|$)'; then
    BLOCK_REASON="cub org: this subcommand does not exist.

Use the full organization noun:

  cub organization get <organization-id>
  cub organization list

For the current CLI context org and user, use:

  cub context get -o json

Remember: context is not authenticated proof. Prefer 'cub auth status' for
auth preflight because it calls the server /me endpoint; use 'pilot org-check --json'
when org identity also matters."
fi

# Pattern 1: cub revision list ... --limit
if [[ -z "$BLOCK_REASON" ]] && echo "$COMMAND" | grep -qE 'cub revision list[^|]*--limit'; then
    BLOCK_REASON="cub revision list: '--limit' is not a supported flag.

The cub CLI does not accept --limit on 'revision list'. To show only the first
N rows, pipe to 'head':

  cub revision list --space <space> <unit> | head -4

Or filter with --where (SQL-style):

  cub revision list --space <space> <unit> --where 'Num > 5'

See: cub revision list --help"
fi

# Pattern 2: cub revision list --unit <slug>  (unit is positional)
if [[ -z "$BLOCK_REASON" ]] && echo "$COMMAND" | grep -qE 'cub revision list.*--unit[= ]'; then
    BLOCK_REASON="cub revision list: the unit slug is positional, not passed via --unit.

Wrong form:
  cub revision list --space <space> --unit <slug>

Correct form:
  cub revision list --space <space> <slug>

See: cub revision list --help"
fi

# Pattern 3: cub revision approve  (non-existent; approval is now a
# Space-level attestation, not a unit or revision subcommand)
if [[ -z "$BLOCK_REASON" ]] && echo "$COMMAND" | grep -qE 'cub revision approve'; then
    BLOCK_REASON="cub revision approve: this subcommand does not exist.

ConfigHub v0.5.7 records approval as an Attestation, per Space, covering
specific revisions, rather than a per-unit ApprovedBy write. Use:

  cub variant approve <space> --context <name>

That records an Approval attestation covering each unit's head revision in
<space>. To approve a different revision, use --revision:

  cub variant approve <space> --context <name> --revision <N>

For a type other than Approval, or to attach a note or claim, use the
general form:

  cub attestation create --space <space> --context <name> --type <type>

Both need a v0.5.7 ConfigHub server: the /api/attest endpoint they use does
not exist on v0.5.4 through v0.5.6.

'cub unit approve' still exists in the client and server, unchanged, but is
refused by Pilot: it is versioned legacy, on its way out upstream.

See: cub variant approve --help"
fi

# Pattern 4: cub run set-container-image ... --container <name>  (should be --container-name)
# Match --container followed by a space AND a non-flag token — avoids matching --container-name.
if [[ -z "$BLOCK_REASON" ]] && echo "$COMMAND" | grep -qE 'cub run set-container-image.*--container[= ][^-]'; then
    # Extra guard: do not block if --container-name is present
    if ! echo "$COMMAND" | grep -qE '\-\-container-name'; then
        BLOCK_REASON="cub run set-container-image: '--container' is not recognized. The flag is '--container-name'.

Wrong form:
  cub run set-container-image --container <name> --image <img> ...

Correct form:
  cub run set-container-image --container-name <name> --image <img> ...

See: cub run explain set-container-image"
    fi
fi

if [[ -n "$BLOCK_REASON" ]]; then
    export BLOCK_REASON
    python3 <<'PYEOF'
import json, sys, os

reason = os.environ.get("BLOCK_REASON", "invalid cub flags")

out = {
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "decision": "block",
        "reason": reason,
    }
}
json.dump(out, sys.stdout)
sys.stdout.write("\n")
sys.stderr.write(reason + "\n")
PYEOF
    exit 2
fi

# ---------------------------------------------------------------------------
# Soft warning (NOT a block): #364 T3 — `--change-desc` on a governed
# `cub run set-*` write should carry diff direction, route classification,
# and field type so `cub revision list` is grep-able six months from now.
#
# The 2026-05-10 LOG_LEVEL run produced:
#
#   --change-desc "Set LOG_LEVEL to debug for verbose logging"
#
# A reviewer reading that string later cannot tell the before-value, cannot
# tell whether the change went through field-routing, and cannot tell what
# kind of field changed. The desired shape is:
#
#   --change-desc "LOG_LEVEL: info → debug (apply-here, env var, no source change)"
#
# This warning fires when ALL of:
#   - the command is `cub run set-*` (the semantic mutation surface)
#   - it carries a `--change-desc` value
#   - the value is missing BOTH the diff arrow (→ or `->`) AND the route
#     classification (`apply-here`, `lift-upstream`, or `block-escalate`).
#
# String parsing is fragile so the rule is intentionally narrow. We only
# warn when both signals are missing — partial conformance is allowed.
# Disable with CONFIGHUB_AI_SKIP_CHANGE_DESC_WARN=1 (escape hatch for
# scripted bulk-fix runs).
# ---------------------------------------------------------------------------
if [[ "${CONFIGHUB_AI_SKIP_CHANGE_DESC_WARN:-0}" != "1" ]] \
   && echo "$COMMAND" | grep -qE 'cub run set-[A-Za-z0-9-]+' \
   && echo "$COMMAND" | grep -qE -- '--change-desc[ =]'; then
    DESC_VALUE="$(printf '%s' "$COMMAND" | python3 -c '
import re, sys
cmd = sys.stdin.read()
# Match --change-desc "..." or --change-desc=... (greedy quoted, then bareword)
for pat in (
    r"--change-desc[ =]\"([^\"]*)\"",
    r"--change-desc[ =]\x27([^\x27]*)\x27",
    r"--change-desc[ =]([^\s]+)",
):
    m = re.search(pat, cmd)
    if m:
        print(m.group(1))
        break
' 2>/dev/null || true)"
    if [[ -n "$DESC_VALUE" ]]; then
        # Diff direction: literal arrow ("→") or ascii arrow ("->").
        has_arrow=0
        if printf '%s' "$DESC_VALUE" | grep -qE '(→|->)'; then
            has_arrow=1
        fi
        # Route classification.
        has_route=0
        if printf '%s' "$DESC_VALUE" | grep -qE '(apply-here|lift-upstream|block-escalate)'; then
            has_route=1
        fi
        if [[ "$has_arrow" -eq 0 && "$has_route" -eq 0 ]]; then
            cat >&2 <<EOF
[confighub-ai] --change-desc warning: the description on this 'cub run set-*'
write is missing both the diff direction (before → after) and the route
classification (apply-here / lift-upstream / block-escalate).

A reviewer reading 'cub revision list' six months from now will not be able
to tell what changed or why. Recommended shape:

  --change-desc "<FIELD>: <before> → <after> (<route>, <field-type>, <one-liner>)"

Example:
  --change-desc "LOG_LEVEL: info → debug (apply-here, env var, no source change)"

This is a soft warning. The command is NOT blocked — string parsing is
fragile and partial conformance is allowed.
Suppress with CONFIGHUB_AI_SKIP_CHANGE_DESC_WARN=1 for scripted bulk runs.
EOF
        fi
    fi
fi

exit 0
