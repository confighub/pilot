#!/usr/bin/env bash
#
# UserPromptSubmit hook — product-wide startup-context restore guard.
#
# This hook restores startup and fast-response context when a prompt arrives
# after `/login`, resume, or context reset. SessionStart owns the one compact
# native hello, so this hook stays context-only to avoid repeating it on the
# first ordinary prompt. The assistant still must acknowledge the user before
# loading heavier Pilot routes.
#
# It is intentionally generic: this is the product surface for any use case,
# not a mini-platform-stack or demo-specific prompt patch.

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

if ! command -v python3 >/dev/null 2>&1; then
    exit 0
fi

HOOK_INPUT="$(cat || true)"
export HOOK_INPUT

python3 <<'PYEOF' 2>/dev/null || true
import json
import os
from pathlib import Path
import sys
import hashlib

try:
    data = json.loads(os.environ.get("HOOK_INPUT", "") or "{}")
except Exception:
    data = {}

marker = "CONFIGHUB SURFACE CONTEXT RESTORED"
transcript_path = data.get("transcript_path") or ""
tail = ""
generic_restored = False

if transcript_path:
    try:
        p = Path(transcript_path)
        if p.exists():
            # Read the tail only. SessionStart may contain hidden
            # `PILOT | Welcome` context; this hook only suppresses
            # the generic restore after its own visible RESTORE marker is
            # present. Prompt-specific route nudges below still fire because
            # they prevent later drift such as numeric onboarding replies.
            with p.open("rb") as fh:
                size = p.stat().st_size
                fh.seek(max(0, size - 500_000))
                tail = fh.read().decode("utf-8", errors="ignore")
            if marker in tail:
                generic_restored = True
    except Exception:
        pass
    try:
        digest = hashlib.sha256(transcript_path.encode("utf-8")).hexdigest()[:24]
        state_file = Path("/tmp") / f"confighub-ai-surface-restore-{digest}.marker"
        if state_file.exists():
            generic_restored = True
        elif not generic_restored:
            state_file.write_text(marker + "\n", encoding="utf-8")
    except Exception:
        pass

parts = []

if not generic_restored:
    parts.append(f"""{marker}

The product-wide UserPromptSubmit hook restored startup context after `/login`, resume, or context reset without repeating the native startup hello. The green status line remains visible.

Before calling any tool, answer the user immediately with a compact branded Pilot Short Card. Do not wait for scripts, skills, repo scans, ConfigHub reads, or cluster checks. If their intent is clear, use `PILOT COCKPIT | STARTING` with three short rows in plain sentences, `Goal`, `Found`, and `Next`; do not force a menu. If their intent is unclear, use `PILOT COCKPIT | START` and offer exactly: 1. TEACH -> understand a document or concept, then choose a tutorial, demo, or showcase. 2. ONBOARD -> choose ConfigHub Cloud or CHE, try cub, and reach a first useful result. 3. SET UP & ORGANISE -> connect or import the user's system, or review shared knowledge, contexts, users, roles, and work. 4. DISCOVER -> map what is running, its configuration, and what needs attention. 5. BUILD / OPERATE / FIX / AUTOMATE -> create or run a governed operational job. Say that \"show me more\" opens the full eight-journey Pilot chooser with `pilot catalog --jobs`, while \"show me the full cockpit\" or \"show engineer details\" opens the deeper route, proof, and receipt view. Pilot draws the coloured cockpit and the activity lanes under your reply, so do not draw your own lanes, boxes, or colour.

After the first quick check, render `PILOT COCKPIT | NEXT` with three short rows in plain sentences, `Goal`, `Found`, and `Next`. Show at most three context-specific choices, recommend one in the `Next` row, and state what each will produce. Pilot draws the coloured cockpit and the activity lanes under your reply, so do not draw your own lanes or boxes. Keep internal route IDs, JSON, hashes, commands, and test vocabulary out of the human response unless the user asks for engineer detail. Write results in plain sentences. Do not use banners such as 'CONFIGHUB SAYS: ...'. Use 'proven' only when you compared separate readings from ConfigHub, the controller and the cluster and they agree.

When the person describes a problem, or asks how to do something with ConfigHub, a cluster, Argo CD, Flux or Helm, your first quick check is `pilot ask '<their exact words>'`. Put their words inside single quotes, so the shell runs nothing that is inside them. Pass their words unchanged; do not reword or shorten them. When the result says Pilot matched a known situation, follow the steps it lists, in order, and tell the person these are Pilot's known steps for that situation. Say plainly when you add something from your own knowledge.

For any delete or cleanup request, run `pilot teardown-plan` for the named Spaces and show its plan; do not compose a delete command yourself. Plan only the Spaces the person named; if more seem involved, say which and ask before adding them.

When the person asks what a repository or folder is, or what bringing it into ConfigHub would create, run `pilot map .` and then `pilot import . --plan` first and report what they print. Add your own reading of the files only afterwards, and say so plainly when it differs from Pilot's plan. To check whether a release is running, use `pilot delivery-trace`. For a staged rollout, use `pilot operate rings`. Prefer a Pilot command over working it out by hand whenever one covers the question."""
)

prompt = (
    data.get("prompt")
    or data.get("user_prompt")
    or data.get("message")
    or data.get("input")
    or ""
)
prompt_norm = " ".join(str(prompt).strip().lower().split())

org_question = (
    "what org" in prompt_norm
    or "which org" in prompt_norm
    or "what organization" in prompt_norm
    or "which organization" in prompt_norm
)

if org_question:
    parts.append(
        "PILOT ROUTE NUDGE: The user is asking which ConfigHub org this is in. "
        "Look up `cub organization --help` (the `confighub-lookup` skill says how) and use "
        "`pilot org-check --json` or `cub organization ...`. "
        "Do not use the non-existent `cub org` alias."
    )

if not parts:
    sys.exit(0)

context = "\n\n".join(parts)

out = {
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": context,
    }
}
json.dump(out, sys.stdout)
PYEOF

exit 0
