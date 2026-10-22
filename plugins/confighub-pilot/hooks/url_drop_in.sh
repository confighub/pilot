#!/usr/bin/env bash
#
# UserPromptSubmit hook: detect URLs in user input and route to the right skill.
#
# Implements the "URL drop-in as pillar" behavior (Issue #12 Path 1) and the
# extension to GitHub repo URLs (lab BYO quickstart spec §6.5.5, not extracted here).
#
# When the user pastes any of the supported URL patterns into the chat, this
# hook parses the URL, identifies the pattern, and injects additionalContext
# telling Claude which skill to activate and what context to load. The user
# doesn't have to type "run the cub-repo-classify skill on this" or "load this unit";
# the URL itself is the intent signal.
#
# Supported patterns (spec §6.5):
#   hub.confighub.com/spaces/<slug>                     → space context
#   hub.confighub.com/spaces/<slug>/units/<unit>        → unit context
#   hub.confighub.com/campaigns/<view-id>               → initiative context
#   hub.confighub.com/sessions/<session-id>             → session fork/resume
#   github.com/<org>/<repo>                             → cub-repo-classify activation
#   <any-host>/applications/<app>                       → Argo app context
#
# The hook never blocks the prompt. Graceful degradation throughout.

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

# ---------------------------------------------------------------------------
# Read hook input JSON and extract the prompt + detect URL pattern
# ---------------------------------------------------------------------------

HOOK_URL_DATA="$(python3 -c '
import json, os, sys, re
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
    from pilot_common import prompt_without_quoted_data, target_access_content_policy
except ImportError:
    def prompt_without_quoted_data(_prompt):
        return ""

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

prompt = data.get("prompt", "") or ""
if not prompt:
    sys.exit(0)
if target_access_content_policy(prompt) != "unrelated":
    # journey_drop_in owns the fixed, non-reflecting target-access handoff.
    # A URL in the same prompt must not create a competing route or echo a
    # caller-controlled URL/path into generic model context.
    sys.exit(0)

prompt = prompt_without_quoted_data(prompt)
if not prompt.strip():
    sys.exit(0)

# URL patterns in priority order — most specific first.
# Session / campaign / unit patterns are all under hub.confighub.com so they
# must be tried before the generic space pattern to avoid over-matching.
patterns = [
    ("confighub-session",  r"https?://hub\.confighub\.com/sessions/([A-Za-z0-9._-]+)"),
    ("confighub-campaign", r"https?://hub\.confighub\.com/campaigns/([A-Za-z0-9._-]+)"),
    ("confighub-unit",     r"https?://hub\.confighub\.com/spaces/([A-Za-z0-9._-]+)/units/([A-Za-z0-9._-]+)"),
    ("confighub-space",    r"https?://hub\.confighub\.com/spaces/([A-Za-z0-9._-]+)"),
    ("github-repo",        r"https?://github\.com/([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+?)(?:\.git)?(?:/|\s|$)"),
    ("argocd-app",         r"https?://[^/\s]+/applications/([A-Za-z0-9._-]+)"),
]

# Self-reference guard (issue #460): the hook fires on any github.com/<org>/<repo>
# URL, including references to this repo itself in conversation (triage docs,
# status reports, planning chats). Those are references, not intent signals —
# we should NOT inject "activate cub-sandbox/cub-repo-classify" for them.
# If the auto-detected origin matches, we add it to this set; the hardcoded
# entries are belt-and-braces in case `git config` is unavailable.
LEGACY_REPO_NAME = "source" + "-" + "archive"
SELF_REPO_PAIRS = {
    ("confighubai", LEGACY_REPO_NAME),
    ("confighub", LEGACY_REPO_NAME),  # in case of org rename history
}

for name, pat in patterns:
    m = re.search(pat, prompt)
    if m:
        groups = list(m.groups()) if m.groups() else []
        matched_url = m.group(0).strip()
        if name == "github-repo":
            matched_url = matched_url.rstrip("/")
            # Skip directives for references to our own repo. The user
            # mentioning the demo repo URL is conversational context, not
            # an ask to sandbox our own development repo into itself.
            org, repo = (groups[0] if len(groups) > 0 else "",
                         groups[1] if len(groups) > 1 else "")
            if (org, repo) in SELF_REPO_PAIRS:
                sys.exit(0)
        print(json.dumps({"match": name, "url": matched_url, "groups": groups, "prompt": prompt}))
        sys.exit(0)
' 2>/dev/null || true)"

if [[ -z "$HOOK_URL_DATA" ]]; then
    # No URL detected — silent no-op.
    exit 0
fi

# ---------------------------------------------------------------------------
# Build the routing directive and emit via additionalContext
# ---------------------------------------------------------------------------

export HOOK_URL_DATA

python3 <<'PYEOF' 2>/dev/null || true
import json, os, sys

try:
    data = json.loads(os.environ.get("HOOK_URL_DATA", "{}"))
except Exception:
    sys.exit(0)

match = data.get("match", "")
url = data.get("url", "")
groups = data.get("groups", [])
prompt = (data.get("prompt", "") or "").lower()

def g(i, default="unknown"):
    return groups[i] if i < len(groups) else default

github_live_sandbox = (
    "sandbox" in prompt
    or "kind" in prompt
    or "cluster" in prompt
    or "byo" in prompt
    or "working" in prompt
)

github_repo_directive = (
    f"URL drop-in detected: GitHub repository URL {url} "
    f"(org: {g(0)}, repo: {g(1)}). "
)
if github_live_sandbox:
    github_repo_directive += (
        f"The surrounding prompt asks for a live sandbox / kind / BYO-cluster "
        f"path, not repo-only evaluation. Activate the pilot skill. Start "
        f"with read-only repo classification if useful, but do not stop there "
        f"unless the repo shape blocks live delivery. The live handoff is "
        f"`pilot local-kind-live-proof --governed` after "
        f"ConfigHub auth, kubeconfig, target/controller path, and scope are "
        f"confirmed. If no kubeconfig exists and the user asked for kind, check "
        f"`kind`, `kubectl`, `docker`, and `cub`, then offer to create/export a "
        f"kind kubeconfig. If the repo is a chart library, still try the whole "
        f"repo first when that is the user's intent; ask for a consumer repo or "
        f"chart+values render only after the whole-repo path is blocked."
    )
else:
    github_repo_directive += (
        f"The user dropped a repo URL as their intent signal. This is the "
        f"repo-only map trigger. Activate the pilot skill: run "
        f"`pilot map {url} --json` which classifies the repo "
        f"read-only and reports the delivery shape and the safe next step. "
        f"Do not start cloning or scanning by hand — the map route encodes "
        f"the read-first flow. If the user then asks to run it in kind or a "
        f"cluster, switch to `pilot local-kind-live-proof --governed`."
    )

directives = {
    "confighub-session": (
        f"URL drop-in detected: ConfigHub session URL {url}. "
        f"The user dropped this URL as their intent signal. Treat this as "
        f"\"pick up this session.\" Resolve the current overlay with "
        f"`cub-trace-session render --run-id {g(0)}` and read its README.md, "
        f"SESSION.json, and events, "
        f"summarize the last few events and any pending approvals, then offer "
        f"to fork or resume. Do not start unrelated work — the URL IS the intent."
    ),
    "confighub-campaign": (
        f"URL drop-in detected: ConfigHub campaign/initiative URL {url}. "
        f"Load the initiative View (view-id: {g(0)}). Run "
        f"`cub view get {g(0)}` to read its state, then show progress and offer "
        f"to run or continue the campaign. Load the `confighub-ai:bulk-security-update` "
        f"or equivalent skill if the user wants to execute."
    ),
    "confighub-unit": (
        f"URL drop-in detected: ConfigHub unit URL {url} "
        f"(space: {g(0)}, unit: {g(1)}). "
        f"Start with `cub unit get --space {g(0)} {g(1)}` to read current state. "
        f"Then offer to diagnose, fix, verify, or promote. Do not mutate without "
        f"explicit user confirmation; do not ask 'what would you like to do?' — "
        f"show the status first, then suggest one recommended next move."
    ),
    "confighub-space": (
        f"URL drop-in detected: ConfigHub space URL {url} (space: {g(0)}). "
        f"DISCOVERY-FIRST RULE (per issue #451): you MUST read the space "
        f"with `cub unit list --space {g(0)} -o json` and then "
        f"`cub unit get -o json` for each unit BEFORE proposing any action. "
        f"Action proposals MUST come from the actual fields those reads "
        f"return, drawing generic action shapes from "
        f"`pilot/gitops-app-action-catalog.json`. "
        f"DO NOT match the space slug to known demo/substrate names "
        f"(e.g. `sc-oci-flux-deploy-cluster-a-flux` is the flux-operator "
        f"substrate slug, BUT the URL arriving here means a real user "
        f"asked about a real space — NOT a request for the demo). "
        f"DO NOT emit substrate-specific text like 'Change LOG_LEVEL', "
        f"'Live Flux D2 demo', or 'Prove Flux OCI delivery end-to-end' "
        f"unless the underlying unit's fields actually warrant it. "
        f"Scripted demos require explicit user invocation by name "
        f"(e.g. user types `pilot demo field-operator`), not URL slug match."
    ),
    "github-repo": github_repo_directive,
    "argocd-app": (
        f"URL drop-in detected: Argo CD application URL {url} (app: {g(0)}). "
        f"Read the Argo application with `kubectl get application {g(0)} -n argocd`. "
        f"Check whether a governed ConfigHub counterpart exists "
        f"(Argo app consuming a ConfigHub OCI Release with corresponding governed Units). "
        f"If yes, offer to operate through the governed write path. "
        f"If no, stay read-only: capture ordinary source/controller discovery and "
        f"an intake packet, then recommend the generic OCI Release path with a "
        f"workerless cluster delivery boundary. Do not "
        f"silently select an experimental or legacy worker-import route."
    ),
}

directive = directives.get(match, "")
if not directive:
    sys.exit(0)

out = {
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": directive,
    }
}
json.dump(out, sys.stdout)
PYEOF

exit 0
