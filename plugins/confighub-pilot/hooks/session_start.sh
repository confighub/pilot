#!/usr/bin/env bash
#
# SessionStart hook — loads ConfigHub startup facts and trust URL context
# without requiring the user to type a trigger prompt.
#
# What it does:
#   1. Runs the project surface audit
#   2. Reads only the local ConfigHub context; live identity checks happen after
#      the assistant has acknowledged the user
#   3. Gets the current session ID
#   4. Names the organization, but leaves object URL selection to the journey
#   5. Emits one compact native hello plus richer additionalContext. Claude Code
#      renders systemMessage through native hook chrome, so the visible line must
#      stay short and human. The green status line remains the branded cockpit,
#      and surface_restore.sh restores first-response behavior after `/login`,
#      resume, or compaction.
#
# Plain `claude` also shows the project status line immediately, so the user can
# see that the surface loaded before the first response. If auth fails, the
# welcome becomes an auth-limited readiness block: live ConfigHub work is blocked,
# but read-only repo analysis can proceed.

set -euo pipefail

# Missing command-line tool (#1268): a plugin added from a marketplace can be
# loaded before the `pilot` command is installed. Say so once, in one visible
# line, and do nothing else: this hook never installs anything. Pilot counts as
# present when `pilot` is on PATH, or when a Pilot checkout/installed root is
# named by PILOT_ROOT or sits two levels above this plugin (source checkout).
pilot_cli_present=0
if command -v pilot >/dev/null 2>&1; then
    pilot_cli_present=1
else
    pilot_plugin_here="${CLAUDE_PLUGIN_ROOT:-}"
    if [[ -z "$pilot_plugin_here" ]]; then
        pilot_plugin_here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" || pilot_plugin_here=""
    fi
    for pilot_candidate in "${PILOT_ROOT:-}" "${pilot_plugin_here:+$pilot_plugin_here/../..}"; do
        if [[ -n "$pilot_candidate" && -d "$pilot_candidate/scripts" && -f "$pilot_candidate/AGENTS.md" ]]; then
            pilot_cli_present=1
            break
        fi
    done
fi
if [[ "$pilot_cli_present" != "1" ]]; then
    printf '%s\n' '{"systemMessage": "Pilot'"'"'s command-line tool is not installed. Install it with `cub plugin install confighub/pilot` then `cub pilot install`, or `pipx install <wheel URL>`."}'
    exit 0
fi

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

CUB_AVAILABLE="0"
if command -v cub >/dev/null 2>&1; then
    CUB_AVAILABLE="1"
fi

# Startup must never wait on the network. The local cub context is orientation,
# not proof of live authentication or permission to write. Pilot performs the
# bounded live organization check only after acknowledging the user's request.
CUB_CONTEXT_JSON=""
if [[ "$CUB_AVAILABLE" == "1" ]]; then
    CUB_CONTEXT_JSON="$(python3 <<'PYEOF' 2>/dev/null || true
import subprocess
import sys

try:
    proc = subprocess.run(
        ["cub", "context", "get", "-o", "json"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        timeout=0.25,
    )
except Exception:
    sys.exit(0)

if proc.returncode == 0:
    sys.stdout.write(proc.stdout)
PYEOF
)"
fi

# Session id
SESSION_ID=""
if [[ -x "$PILOT_ROOT_DIR/scripts/cub-trace-session" ]]; then
    SESSION_ID="$("$PILOT_ROOT_DIR/scripts/cub-trace-session" start --run-id-only 2>/dev/null || echo "")"
fi

export CUB_CONTEXT_JSON SESSION_ID PILOT_ROOT_DIR
export CUB_AVAILABLE

python3 <<'PYEOF' 2>/dev/null || true
import json, os, sys
import subprocess
from pathlib import Path

cub_context_json = os.environ.get("CUB_CONTEXT_JSON", "").strip()
try:
    cub_context = json.loads(cub_context_json) if cub_context_json else {}
except json.JSONDecodeError:
    cub_context = {}
metadata = cub_context.get("metadata") if isinstance(cub_context.get("metadata"), dict) else {}
context_name = str(cub_context.get("name") or "").strip()
org_name = str(metadata.get("organizationName") or "").strip()
session_id = os.environ.get("SESSION_ID", "").strip()
# Kubernetes context is optional local orientation. Keep this in the existing
# renderer and discard partial/failed output rather than delaying the welcome.
k8s_context = ""
try:
    kube = subprocess.run(
        ["kubectl", "config", "current-context"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        timeout=0.25,
    )
    if kube.returncode == 0:
        k8s_context = kube.stdout.strip()
except (OSError, subprocess.SubprocessError, UnicodeError):
    pass
project_dir = os.environ.get("CLAUDE_PROJECT_DIR", "").strip() or os.getcwd()
project_name = os.path.basename(project_dir.rstrip(os.sep)) or project_dir
# Run the bounded read in this renderer instead of starting another Python
# process and serializing its result through the shell environment.
helper = os.path.join(os.environ["PILOT_ROOT_DIR"], "scripts", "audit-plugin-surface")
surface_result = {"status": "unknown", "output": ""}
if os.path.isfile(helper) and os.access(helper, os.X_OK):
    try:
        proc = subprocess.run(
            [helper],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=0.4,
        )
        surface_result = {"status": "pass" if proc.returncode == 0 else "fail", "output": proc.stdout[-4000:]}
    except subprocess.TimeoutExpired:
        surface_result = {"status": "deferred", "output": "Startup surface audit exceeded its 400 ms budget and was deferred."}
    except (OSError, UnicodeError):
        # The former shell wrapper also left the result unknown on probe error.
        # An unavailable audit must not suppress the startup card or imply PASS.
        pass
surface_status = str(surface_result.get("status") or "unknown").strip()
surface_out = str(surface_result.get("output") or "").strip()
cub_available = os.environ.get("CUB_AVAILABLE", "0").strip() == "1"
learning_active = bool(os.environ.get("PILOT_LEARNING", "").strip())
learning_objective = os.environ.get("PILOT_LEARNING_OBJECTIVE", "").strip() or "Capture reusable Pilot lessons from this Claude session."
learning_session = os.environ.get("PILOT_LEARNING_SESSION", "").strip()

contract_path = Path(os.environ["PILOT_ROOT_DIR"]) / "pilot" / "contracts" / "pilot-first-screen-contract.v1.json"
try:
    first_screen = json.loads(contract_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError):
    first_screen = {}
compact_choices = first_screen.get("navigation", {}).get("compact_choices") or [
    "TEACH",
    "ONBOARD",
    "SET UP & ORGANISE",
    "DISCOVER",
    "BUILD / OPERATE / FIX / AUTOMATE",
]
doors = first_screen.get("navigation", {}).get("doors") or [
    {"door_phrase": "understand this repo", "job_id": "discover"},
    {"door_phrase": "make something deployable", "job_id": "set-up"},
    {"door_phrase": "check before I ship", "job_id": "operate"},
    {"door_phrase": "fix what is broken", "job_id": "fix"},
]
door_welcome_lines = [
    "New here? Say one of these:",
    *[f'- "{door["door_phrase"]}"' for door in doors],
    "Or type what you want in your own words.",
    "",
]
door_contract_lines = "\n".join(f'- "{door["door_phrase"]}"' for door in doors)
choice_results = {
    "TEACH": "understand a document or concept, then choose a tutorial, demo, or showcase",
    "ONBOARD": "choose ConfigHub Cloud or CHE, try cub, and reach a first useful result",
    "SET UP & ORGANISE": "connect or import your system, or review shared knowledge, contexts, users, roles, and work",
    "DISCOVER": "map what is running, its configuration, and what needs attention",
    "BUILD / OPERATE / FIX / AUTOMATE": "create or run a governed operational job",
}
choice_lines = "\n".join(
    f"{index}. {choice}. -> {choice_results.get(choice, 'open this journey')}"
    for index, choice in enumerate(compact_choices, start=1)
)
required_fields = first_screen.get("shared_ui_state", {}).get("required_fields") or []
required_field_line = ", ".join(required_fields)

first_response_contract = f"""PILOT FAST FIRST-RESPONSE CONTRACT

Before calling any tool, answer the user immediately with a compact branded Pilot Short Card. Do not wait for Pilot scripts, repository scans, skills, ConfigHub reads, or cluster checks.
The canonical Short Card fields are: {required_field_line}.

If their intent is clear, do not force a menu. Use this shape, with three short rows in plain sentences:
PILOT COCKPIT | STARTING
Goal | <their goal in ordinary language>
Found | <what you have already seen, or what they will see first>
Next | <one useful next action>

Pilot draws the coloured cockpit and the activity lanes under your reply, so do not draw your own lanes, boxes, or colour. The Short Card fields above are what Pilot tracks; you write only the three rows.

If their intent is unclear, use this shape:
PILOT COCKPIT | START
Goal | work out what they want to do
New here? Say one of these:
{door_contract_lines}
Or type what you want in your own words.
Choose a journey:
{choice_lines}
All journeys | Say \"show me more\" to open the full Pilot journey chooser.
More detail | Say \"show me the full cockpit\" or \"show engineer details.\"

Keep the same stable labels in plain text.

When a second choice is genuinely needed after the first quick check, render another branded Short Card. Keep it specific to the chosen goal and recommend one path:
- Teach: explain the source, try the smallest tutorial, or run a richer demo or showcase.
- Onboard: choose ConfigHub Cloud or CHE, verify the intended context, and reach a first useful result.
- Set up & Organise: connect or import the user's system, or inventory shared knowledge and context before one bounded cleanup or administration change.
- Discover: map source and live state, inspect configuration/CVE/policy evidence, or produce a report.
- Build / Operate / Fix / Automate: choose a known scenario, use an earned engine when available, and stop at a typed gap otherwise.
Use this shape:
PILOT COCKPIT | NEXT
Goal | <current goal>
Found | <first useful finding>
Next | <the one recommended choice and why, and what it will produce; if you offer others, at most two more in a plain sentence below, each with its result>

Pilot draws the coloured cockpit and the activity lanes under your reply, so do not draw your own lanes or boxes.

Do not expose route IDs, JSON, hashes, commands, or internal test vocabulary unless the user asks for engineer detail.

HOW TO WRITE RESULTS
Write results in plain sentences. Do not use banners such as 'CONFIGHUB SAYS: ...'. Say 'read', 'shows', 'checked' for a single reading. Use 'proven' only when you compared separate readings from ConfigHub, the controller and the cluster and they agree. Never tell the person to switch Pilot off to get past a stop. For any delete or cleanup request, run `pilot teardown-plan` for the named Spaces and show its plan; do not compose a delete command yourself. Plan only the Spaces the person named; if more seem involved, say which and ask before adding them.

HOW TO ANSWER WHAT A FOLDER IS
When the person asks what a repository or folder is, or what bringing it into ConfigHub would create, run `pilot map .` and then `pilot import . --plan` first and report what they print. Add your own reading of the files only afterwards, and say so plainly when it differs from Pilot's plan. To check whether a release is running, use `pilot delivery-trace`. For a staged rollout, use `pilot operate rings`. Prefer a Pilot command over working it out by hand whenever one covers the question.

HOW TO HANDLE A PROBLEM OR A HOW-DO-I QUESTION
When the person describes a problem, or asks how to do something with ConfigHub, a cluster, Argo CD, Flux or Helm, run `pilot ask '<their exact words>'` before you answer and before you run other commands. Put their words inside single quotes, so the shell runs nothing that is inside them. Pass their words unchanged; do not reword or shorten them. When the result says Pilot matched a known situation, follow the steps it lists, in order, and tell the person these are Pilot's known steps for that situation. Say plainly when you add something from your own knowledge. When it matches nothing, say so and continue as you normally would."""

lines = []
surface_warning = ""
if surface_status == "pass":
    surface_label = "ready"
elif surface_status == "fail":
    surface_label = "needs attention"
elif surface_status == "deferred":
    surface_label = "checking after startup"
else:
    surface_label = "unknown"

if surface_status == "fail":
    interesting = []
    for line in surface_out.splitlines():
        if "✗" in line or "FAIL" in line or "missing" in line.lower():
            interesting.append(line)
        if len(interesting) >= 8:
            break
    body = "\n".join(interesting) if interesting else "scripts/audit-plugin-surface failed."
    surface_warning = (
        "\n\nClaude+ConfigHub surface check failed. Do not start live ConfigHub work "
        "until this is fixed. Run `pilot claude status --global`.\n"
        f"{body}"
    )

learning_lines = []
learning_context = ""
if learning_active:
    learning_lines = [
        f"- Pilot Learning Mode: active ({learning_objective}).",
        "- Learning closeout: use `/confighub-pilot:pilot-learn from-closeout <closeout.json> --out <packet.json> --progress-card`; the closeout records a lesson candidate or explicit `NO_NEW_LESSONS`.",
    ]
    if learning_session:
        learning_lines.insert(1, f"- Learning session: `{learning_session}`.")
    learning_context = (
        "\n\nPILOT LEARNING MODE is active from the environment. "
        "Preserve relevant redacted evidence and close with "
        "`/confighub-pilot:pilot-learn from-closeout <closeout.json> --out <packet.json> --progress-card`. "
        "A lesson candidate continues through `/confighub-pilot:pilot-learn stage`, human review and merge, "
        "`/confighub-pilot:pilot-learn recheck`, and `/confighub-pilot:pilot-learn measure-rerun` against the originating route. "
        "An explicit `NO_NEW_LESSONS` packet stays with the run closeout and does not enter promotion."
    )

if not cub_available:
    welcome_lines = [
        "PILOT | Welcome",
        "",
        "`cub` is not installed or is not in PATH.",
        "",
        "Status checks:",
        f"- AI surface: {surface_label}.",
        "- ConfigHub auth: unavailable because `cub` is unavailable.",
        *learning_lines,
        "",
        *door_welcome_lines,
        "Start:",
        "1. TEACH - understand a source and choose a tutorial, demo, or showcase.",
        "2. ONBOARD - choose ConfigHub Cloud or CHE and reach a first useful result.",
        "3. SET UP & ORGANISE - bring your system or review shared knowledge, contexts, users, and work.",
        "4. DISCOVER - map what is running and what needs attention.",
        "5. BUILD / OPERATE / FIX / AUTOMATE - create or run a governed job.",
        "Install `cub` and run `cub auth login` before live ConfigHub operations.",
        "",
        "I can still do read-only repo analysis and explain what ConfigHub would add.",
    ]
    welcome = "\n".join(welcome_lines)
    context = (
        "SESSION-START (ConfigHub): cub is unavailable. "
        "A compact native hello and the green startup cockpit are already visible. "
        "Follow the fast first-response contract before using tools.\n\n"
        f"{welcome}{surface_warning}\n\n{first_response_contract}\n\n"
        "Do not run live ConfigHub commands or claim live ConfigHub proof until cub is available and the user authenticates."
        f"{learning_context}"
    )
elif not context_name:
    welcome_lines = [
        "PILOT | Welcome",
        "",
        "No local ConfigHub context is selected yet.",
        "",
        "Status checks:",
        f"- AI surface: {surface_label}.",
        "- ConfigHub context: not selected.",
        *learning_lines,
        "",
        *door_welcome_lines,
        "Start:",
        "1. TEACH - understand a source and choose a tutorial, demo, or showcase.",
        "2. ONBOARD - choose ConfigHub Cloud or CHE and reach a first useful result.",
        "3. SET UP & ORGANISE - bring your system or review shared knowledge, contexts, users, and work.",
        "4. DISCOVER - map what is running and what needs attention.",
        "5. BUILD / OPERATE / FIX / AUTOMATE - create or run a governed job.",
        "Sign in or select a ConfigHub context before live ConfigHub operations.",
        "",
        "I can still do read-only repo analysis and explain what ConfigHub would add.",
    ]
    welcome = "\n".join(welcome_lines)
    context = (
        "SESSION-START (ConfigHub): no local ConfigHub context is selected. "
        "A compact native hello and the green startup cockpit are already visible. "
        "Follow the fast first-response contract before using tools.\n\n"
        f"{welcome}{surface_warning}\n\n{first_response_contract}\n\n"
        "Do not run live ConfigHub commands or claim live ConfigHub proof until the user authenticates and Pilot verifies the intended organization. "
        "If the user asks for read-only repo analysis, repo classification, docs planning, or a repo-owner-style concierge first pass, proceed without auth and state that the result is analysis-only."
        f"{learning_context}"
    )
else:
    context_label = org_name or context_name
    welcome_lines = [
        "PILOT | Welcome",
        "",
        "Status checks:",
        f"- AI surface: {surface_label}.",
        f"- ConfigHub context: {context_label} (`{context_name}`).",
        "- Live ConfigHub auth and organization identity: deliberately deferred until the first ConfigHub operation.",
        *learning_lines,
    ]
    if k8s_context:
        welcome_lines.append(f"- Kubernetes context: `{k8s_context}`.")
    welcome_lines.extend([
        "",
        *door_welcome_lines,
        "Start:",
        "1. TEACH - understand a source and choose a tutorial, demo, or showcase.",
        "2. ONBOARD - choose ConfigHub Cloud or CHE and reach a first useful result.",
        "3. SET UP & ORGANISE - bring your system or review shared knowledge, contexts, users, and work.",
        "4. DISCOVER - map what is running and what needs attention.",
        "5. BUILD / OPERATE / FIX / AUTOMATE - create or run a governed job.",
        "Say \"show me more\" to open the full Pilot journey chooser.",
        "Say \"show me the full cockpit\" or \"show engineer details\" for the deeper route, proof, and receipt view.",
        "",
    ])
    if session_id:
        welcome_lines.append(f"Session: `{session_id}` — type /cub-share to share this session with a colleague.")
        welcome_lines.append("")
    welcome_lines.append("ConfigHub object: none selected yet. Pilot will show the exact Space or Unit URL when this journey selects or creates it.")
    welcome_lines.append("")
    welcome = "\n".join(welcome_lines)
    context = (
        "SESSION-START (ConfigHub): fresh pilot session. "
        "A compact native hello and the green startup cockpit are already visible. "
        "Follow the fast first-response contract before using tools. The user should not have to name ConfigHub or Pilot internals.\n\n"
        f"---BEGIN WELCOME---\n{welcome}{surface_warning}\n---END WELCOME---\n\n{first_response_contract}{learning_context}"
        "\n\nThe local ConfigHub context is orientation, not proof of live authentication and not permission to mutate it. "
        "Before the first live ConfigHub read or write, run the bounded organization check. For an ordinary write, bind one explicit named context and exact scope, show one literal Cub command, submit it through the host permission path, then verify the resulting revision or Release read-only before claiming success. This Claude adapter forces a host decision for a change; its permission authorizes an attempt, not an outcome. Reads run and changes ask. Destructive, dynamic, unbounded, credential, executable, cluster-lifecycle, and direct Kubernetes operations ask too: the host shows the exact command and the person allows or declines that one attempt. Only four things are stopped: cub space delete with --recursive or --recursive-force, cub organization delete, cub cluster down --delete-config, and a credential typed into a command. "
        "Do not use an arbitrary listed Space as the current journey object or proof URL."
    )

# Honest greeting: only claim the live status line when Pilot actually
# installed one. `pilot claude install --global` merges a statusLine whose
# command contains "pilot claude statusline" (see scripts/pilot-claude-adapter
# configured_statusline_state). On --no-merge-settings, a conflict-preserved
# user statusLine, or a bare plugin copy, no Pilot status line exists, so the
# greeting must not point at a live context surface that is not there.
try:
    _statusline_home = (
        Path(os.environ["CLAUDE_HOME"]).expanduser()
        if os.environ.get("CLAUDE_HOME")
        else Path.home() / ".claude"
    )
    _statusline_settings = json.loads((_statusline_home / "settings.json").read_text(encoding="utf-8"))
    _statusline_cfg = _statusline_settings.get("statusLine") if isinstance(_statusline_settings, dict) else None
    _statusline_cmd = _statusline_cfg.get("command") if isinstance(_statusline_cfg, dict) else None
    pilot_statusline_live = isinstance(_statusline_cmd, str) and "pilot claude statusline" in _statusline_cmd
except Exception:
    pilot_statusline_live = False

if not cub_available:
    visible = f"Hello - Pilot is ready in {project_name}. ConfigHub setup is still needed."
elif not context_name:
    visible = f"Hello - Pilot is ready in {project_name}. Choose a ConfigHub context before live work."
elif pilot_statusline_live:
    visible = f"Hello - Pilot is ready in {project_name}. ConfigHub org {org_name or context_name}; live context in the status line."
else:
    visible = f"Hello - Pilot is ready in {project_name}. ConfigHub org {org_name or context_name} at session start."

out = {
    "systemMessage": visible,
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context,
    }
}
json.dump(out, sys.stdout)
PYEOF

exit 0
