#!/usr/bin/env bash
#
# UserPromptSubmit hook: route Pilot journey phrases to their
# deterministic Pilot commands.
#
# The human journeys and first-run chooser each have a tested path underneath an ordinary
# sentence ("what can I do here", "make this app deployable", "make a cost
# app"). Skill prose alone does not reliably survive a model that already has
# a generic plan: the v0.2.5 installed trial showed sessions routing to
# generic manifest authoring with the journey command never run. Like
# url_drop_in.sh, this hook treats the phrase itself as the intent signal and
# injects the exact first command as additionalContext.
#
# The hook never blocks the prompt and adds nothing on non-journey prompts.

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

PILOT_JOURNEY_PYTHON=python3
# Installed hooks can run outside the venv's PATH. Use the interpreter beside
# the declared, physical installed data root so lazy runtime imports resolve
# to that installation. Source checkouts keep their ordinary interpreter.
PILOT_JOURNEY_ROOT="${PILOT_HOME:-${PILOT_ROOT:-}}"
PILOT_JOURNEY_ROOT="${PILOT_JOURNEY_ROOT%/}"
case "$PILOT_JOURNEY_ROOT" in
    /*/share/confighub-pilot)
        if [[ -d "$PILOT_JOURNEY_ROOT" && ! -L "$PILOT_JOURNEY_ROOT" ]] &&
           [[ "$(cd -- "$PILOT_JOURNEY_ROOT" && pwd -P)" == "$PILOT_JOURNEY_ROOT" ]]; then
            PILOT_JOURNEY_PREFIX="${PILOT_JOURNEY_ROOT%/share/confighub-pilot}"
            if [[ -f "$PILOT_JOURNEY_PREFIX/pyvenv.cfg" &&
                  -f "$PILOT_JOURNEY_ROOT/pilot/package-manifest.json" &&
                  -x "$PILOT_JOURNEY_PREFIX/bin/python3" ]]; then
                # Standard venv interpreters are symlinks to the base Python.
                PILOT_JOURNEY_PYTHON="$PILOT_JOURNEY_PREFIX/bin/python3"
            fi
        fi
        ;;
esac

if ! command -v "$PILOT_JOURNEY_PYTHON" >/dev/null 2>&1; then
    exit 0
fi

# Keep the hook event on fd 3 while the heredoc supplies the Python program
# on stdin (same pattern as validate_execution_approval.sh).
"$PILOT_JOURNEY_PYTHON" - 3<&0 <<'PYEOF'
import json
import os
import re
import shlex
import sys
from pathlib import Path

pilot_root = os.environ.get("PILOT_HOME") or os.environ.get("PILOT_ROOT")
scripts_candidates = []
if pilot_root:
    scripts_candidates.append(Path(pilot_root).expanduser() / "scripts")
plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT")
if plugin_root:
    scripts_candidates.append(Path(plugin_root).expanduser() / ".." / ".." / "scripts")
for scripts_candidate in scripts_candidates:
    try:
        resolved_scripts = scripts_candidate.resolve()
    except OSError:
        continue
    if (resolved_scripts / "pilot_common.py").is_file():
        sys.path.insert(0, str(resolved_scripts))
        break

try:
    from pilot_onboarding_intent import (
        CONCEPT_SYNONYMS,
        concept_teach_subject,
        confighub_onboarding_lane,
        confighub_prerequisite_followup,
        fast_teach_intent,
        named_confighub_lane,
    )
except ImportError:
    CONCEPT_SYNONYMS = {}

    def concept_teach_subject(_intent: str) -> None:
        return None

    def confighub_onboarding_lane(_intent: str) -> None:
        return None

    def fast_teach_intent(_intent: str) -> None:
        return None

    def confighub_prerequisite_followup(_intent: str) -> bool:
        return False

    def named_confighub_lane(_intent: str) -> None:
        return None

try:
    from pilot_common import (
        PILOT_JOURNEYS,
        guided_engagement_action,
        looks_like_organise_request,
    )
except ImportError:
    PILOT_JOURNEYS = []

    def guided_engagement_action(_intent: str) -> None:
        return None

    def looks_like_organise_request(_intent: str) -> bool:
        return False

try:
    from pilot_common import (
        canonical_target_access_intent,
        prompt_without_quoted_data,
        legacy_cub_target_access_execution_requested,
        target_access_content_policy,
        target_access_request_policy,
        text_contains_high_confidence_credential,
    )
    security_classifier_loaded = True
except ImportError:
    security_classifier_loaded = False

    def target_access_content_policy(intent: str) -> str:
        normalized = " ".join(str(intent or "").lower().split())
        if re.search(r"\b(?:confighub|config\s+hub)\b", normalized) and re.search(
            r"\btarget(?:-|\s)+access\b", normalized
        ):
            return "write"
        if re.search(r"\bcub\b.{0,160}\btarget\s+access\b", normalized):
            return "legacy-provider-command"
        return "unrelated"

    def canonical_target_access_intent(_intent: str, policy=None) -> str:
        if policy == "proof":
            return "prove read-only ConfigHub target access"
        if policy == "artifact":
            return "explain ConfigHub target access"
        if policy == "destructive":
            return "revoke ConfigHub target access"
        return "change ConfigHub target access"

    def target_access_request_policy(intent: str) -> str:
        normalized = " ".join(str(intent or "").lower().split())
        if re.search(r"\b(?:confighub|config\s+hub)\b", normalized) and re.search(
            r"\btarget(?:-|\s)+access\b", normalized
        ) and (
            re.match(r"^(?:please\s+)?(?:what|how|why|explain|teach|document|summari[sz]e|review)\b", normalized)
            or normalized.endswith("?")
        ):
            return "artifact"
        return "unrelated"

    def legacy_cub_target_access_execution_requested(intent: str) -> bool:
        normalized = " ".join(str(intent or "").lower().split())
        if not re.search(r"\bcub\b.{0,160}\btarget\s+access\b", normalized):
            return False
        return not bool(
            re.search(
                r"\b(?:explain|teach|document|summari[sz]e|review|history|historical|retired|incident\s+report)\b",
                normalized,
            )
            or normalized.endswith("?")
        )

    def text_contains_high_confidence_credential(_intent: str) -> bool:
        # The security owner is unavailable. The hook must not make a weaker
        # claim by routing and quoting arbitrary caller bytes.
        return True

try:
    with os.fdopen(3, encoding="utf-8") as event_stream:
        data = json.load(event_stream)
except Exception:
    sys.exit(0)

prompt = data.get("prompt", "") or ""
if not prompt:
    sys.exit(0)

if not security_classifier_loaded:
    # Degraded hooks add no routing context. Generic journey convenience is
    # less important than ensuring unclassified bytes are never reflected.
    sys.exit(0)
if text_contains_high_confidence_credential(prompt):
    directive = (
        "JOURNEY ROUTE (Pilot): this prompt contains credential-shaped content. "
        "Pilot did not quote, route, summarize, or persist its original bytes. "
        "Remove the credential from the prompt and retry through the ordinary "
        "Pilot doorway. This hook grants no execution or mutation authority."
    )
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": directive,
            }
        },
        sys.stdout,
    )
    sys.exit(0)

# Target-access prompts are partitioned before the general journey router can
# quote them into a command or inject their bytes into model context.  The
# shared classifier owns the exact grammar. If it is unavailable, the hook
# above emits no context at all rather than weakening or reflecting the prompt.
target_access_request = target_access_request_policy(prompt)
target_access_policy = target_access_content_policy(prompt)
historical_legacy_artifact = (
    target_access_policy == "legacy-provider-command"
    and not legacy_cub_target_access_execution_requested(prompt)
)
if target_access_request == "artifact" or historical_legacy_artifact:
    canonical_intent = canonical_target_access_intent(
        "explain ConfigHub target access", "artifact"
    )
    command = shlex.join(["pilot", "teach", canonical_intent, "--json"])
    directive = (
        "JOURNEY ROUTE (Pilot): this is a read-only target-access teaching "
        "request, not an execution request. Its original bytes are partitioned "
        "from generic journey context. Do not quote, summarize, persist, or "
        f"execute the original text. Run `{command}` and present the reviewed "
        "TEACH artifact, including why the retired Cub command is not an "
        "executable fallback. This hook grants no provider, ConfigHub, "
        "controller, or cluster authority."
    )
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": directive,
            }
        },
        sys.stdout,
    )
    sys.exit(0)
elif target_access_policy != "unrelated":
    canonical_intent = canonical_target_access_intent(prompt, target_access_policy)
    if target_access_policy in {"credential-bearing-content", "legacy-provider-command"}:
        canonical_intent = "change ConfigHub target access"
    command = shlex.join(["pilot", "ask", canonical_intent, "--json"])
    directive = (
        "JOURNEY ROUTE (Pilot): this prompt concerns ConfigHub target access, "
        "so its original bytes are partitioned from generic journey context. "
        "Do not quote, summarize, persist, or execute the original text. Run "
        f"`{command}` and follow its typed proposal-only boundary. This hook "
        "does not grant provider, ConfigHub, controller, or cluster authority."
    )
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": directive,
            }
        },
        sys.stdout,
    )
    sys.exit(0)

prompt = prompt_without_quoted_data(prompt).strip()
if not prompt:
    sys.exit(0)

lowered = prompt.lower()
normalized_prompt = " ".join(lowered.split())


def content_text(value: object) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        parts = []
        for item in value:
            if isinstance(item, dict) and item.get("type") == "text":
                parts.append(str(item.get("text") or ""))
            elif isinstance(item, str):
                parts.append(item)
        return "\n".join(part for part in parts if part)
    return ""


def last_assistant_text(transcript_path: object) -> str:
    if not isinstance(transcript_path, str) or not transcript_path:
        return ""
    try:
        path = Path(transcript_path)
        if not path.is_file():
            return ""
        with path.open("rb") as stream:
            size = path.stat().st_size
            stream.seek(max(0, size - 250_000))
            lines = stream.read().decode("utf-8", errors="ignore").splitlines()
    except OSError:
        return ""
    for line in reversed(lines):
        try:
            record = json.loads(line)
        except (TypeError, json.JSONDecodeError):
            continue
        message = record.get("message") if isinstance(record.get("message"), dict) else record
        role = str(message.get("role") or record.get("role") or record.get("type") or "").lower()
        if role != "assistant":
            continue
        text = content_text(message.get("content")) or content_text(record.get("content"))
        if text:
            return text
    return ""


def compact(text: str, limit: int = 200) -> str:
    text = " ".join(text.split())
    if len(text) > limit:
        text = text[:limit].rstrip() + "..."
    return text


def normalized_route_phrase(text: object) -> str:
    normalized = " ".join(str(text or "").lower().split()).rstrip(".!?")
    return re.sub(r"^pilot[,:]?\s+", "", normalized)


def canonical_journey_phrases(journey: dict[str, object]) -> set[str]:
    phrases = {
        normalized_route_phrase(journey.get("job_id")),
        normalized_route_phrase(journey.get("label")),
        normalized_route_phrase(journey.get("user_words")),
        normalized_route_phrase(journey.get("door_phrase")),
    }
    # Rich aliases often already own a more specific deterministic handoff
    # below (for example "make this app deployable"). Preserve those routes.
    # "Roll this back" is the compatibility-safe chooser alias required by the
    # OPERATE catalog promise: selecting it opens OPERATE, never executes it.
    if journey.get("job_id") == "operate":
        phrases.add("roll this back")
    return {phrase for phrase in phrases if phrase}


def canonical_journey_command(journey: dict[str, object]) -> str:
    command = str(journey.get("starter_command") or "").replace("pilot", "pilot")
    problem = shlex.quote(prompt)
    return command.replace("'<problem>'", problem).replace("<problem>", problem)


DEPLOYABLE = re.compile(
    r"\b(make|prepare|get)\s+(this|the|my)\s+(app|application|service|repo(?:sitory)?)\s+"
    r"(deployable|ready\s+for\s+deployment|for\s+deployment)\b"
)
APP_REQUEST = re.compile(r"\bmake\s+(?:me\s+)?an?\s+([a-z0-9][a-z0-9 _-]{0,40}?)\s+app\b")
REPEATABLE_APP = re.compile(
    r"^(?:pilot[,:]?\s+)?(?:please\s+)?make\s+this\s+repeatable\s+as\s+an?\s+app"
    r"(?:\s+please)?[.!?]*$"
)
ORIENTATION = re.compile(r"\bwhat\s+can\s+(i|we|you|pilot)\s+do\s+here\b")
SHOW_JOBS = re.compile(
    r"^(?:pilot[,:]?\s+)?(?:show\s+me\s+more|"
    r"show\s+(?:me\s+)?(?:the\s+)?(?:pilot\s+)?(?:jobs|scenarios|catalog)|"
    r"what\s+can\s+(?:i|we)\s+do\s+next|"
    r"what\s+can\s+pilot\s+do|"
    r"what\s+(?:jobs|scenarios)\s+(?:can\s+pilot\s+run|are\s+available)|"
    r"(?:help\s+me\s+)?choose\s+(?:a\s+)?job(?:\s+to\s+be\s+done|\s+or\s+(?:a\s+)?workflow)?|"
    r"show\s+me\s+(?:the\s+)?main\s+things\s+(?:you|pilot)\s+can\s+do(?:\s+.*)?)[.!?]*$"
)
SHOW_SCENARIO_WORKFLOWS = re.compile(
    r"^(?:pilot[,:]?\s+)?(?:show\s+me\s+)?(?:workflow\s+and\s+scenario|scenario\s+and\s+workflow)\s+examples[.!?]*$"
)
PILOT_RUNTIME_STATUS = re.compile(
    r"^(?:pilot[,:]?\s+)?(?:"
    r"are\s+we\s+(?:running|using)\s+pilot|"
    r"is\s+pilot\s+(?:running|loaded|active|enabled|up)|"
    r"did\s+pilot\s+(?:load|start|activate)|"
    r"has\s+pilot\s+loaded"
    r")(?:\s+(?:here|in\s+(?:this|the)\s+(?:claude\s+)?session))?[.!?]*$"
)
GUIDED_TOUR = re.compile(
    r"\b(guided\s+(?:pilot\s+)?tour|pilot\s+tutorial|tour\s+of\s+pilot|"
    r"demo\s+pilot)\b"
)
# Routing only. pilot teach owns orientation, one-step execution, and all-scope denial.
TUTORIAL_TEACH_ROUTE = re.compile(
    r"^(?:pilot[,:]?\s+)?(?:"
    r"(?:please\s+)?(?:do|run|start|try)\s+(?:(?:all|every)\s+)?(?:the\s+|a\s+)?(?:pilot\s+)?tutorials?|"
    r"(?:please\s+)?(?:take|walk)\s+me\s+through\s+(?:(?:all|every)\s+)?(?:the\s+|a\s+)?(?:pilot\s+)?tutorials?|"
    r"(?:let'?s|let\s+us)\s+(?:do|run|start|try)\s+(?:(?:all|every)\s+)?(?:the\s+|a\s+)?(?:pilot\s+)?tutorials?|"
    r"(?:can|could)\s+(?:i|we)\s+(?:please\s+)?(?:do|run|start|try)\s+(?:(?:all|every)\s+)?(?:the\s+|a\s+)?(?:pilot\s+)?tutorials?|"
    r"teach\s+me\s+by\s+doing|"
    r"what\s+tutorial\s+should\s+(?:i|we)\s+(?:run|start|try)|"
    r"how\s+(?:do|can)\s+(?:i|we)\s+learn\s+what\s+confighub\s+can\s+do\s+for\s+(?:me|us)"
    r")(?:\s+please)?[.!?]*$"
)
# The explain / what-is arms of TEACH match only the shipped persona concepts,
# built from the shared synonym table so "explain promotions" / "what is a
# promotion" route to the concept explainer while "explain AWS networking" (not
# a shipped concept) still falls through to silence. Longest terms first so a
# multi-word synonym ("apply gates") wins over its prefix; the sentinel keeps
# the pattern inert if the shared table could not be imported.
_CONCEPT_ALTERNATION = "|".join(
    r"\s+".join(re.escape(word) for word in term.split())
    for term in sorted(CONCEPT_SYNONYMS, key=len, reverse=True)
) or r"(?!x)x"
TEACH = re.compile(
    r"\b(?:pilot[,:]?\s+)?(?:"
    r"teach\s+me(?:\s+(?:about\s+)?[^.!?]{0,100})?|"
    r"(?:help\s+me\s+understand|explain|read)\s+(?:this|the|a)\s+(?:doc(?:ument)?|page|guide|tutorial|article)|"
    rf"explain\s+(?:a\s+|an\s+|the\s+)?(?:{_CONCEPT_ALTERNATION})|"
    rf"what\s+(?:is|are)\s+(?:a\s+|an\s+|the\s+)?(?:{_CONCEPT_ALTERNATION})|"
    r"what\s+(?:demo|guide|showcase)s?\s+should\s+(?:i|we)\s+(?:run|start|try)|"
    r"show\s+me\s+(?:the\s+)?smallest\s+runnable\s+tutorial|"
    r"show\s+me\s+(?:a\s+)?pilot\s+(?:tutorial|demo|showcase)|"
    r"how\s+does\s+this\s+(?:connect|relate)\s+to\s+confighub"
    r")\b"
)
EXPLAIN_PILOT = re.compile(
    r"\bpilot[,:]?\s+(?:please\s+)?(?:"
    r"explain\s+(?:yourself(?:\s+to\s+me)?|(?:your\s+)?(?:architecture|router|routing|scenarios?|approvals?|execution|proof|receipts?|memory|learning\s+loop|surfaces?|ui|gui\s+siblings?|roadmap|(?:confighub\s+)?expertise))|"
    r"help\s+me\s+understand\s+(?:yourself|pilot)|"
    r"what\s+are\s+you|how\s+do\s+you\s+work|"
    r"how\s+do\s+you\s+(?:route|execute|prove|learn)|"
    r"show\s+me\s+what\s+is\s+real\s+today|"
    r"show\s+me\s+how\s+to\s+add\s+(?:a\s+)?(?:scenario|app)"
    r")\b|\b(?:help\s+me\s+understand|teach\s+me\s+about)\s+pilot\b"
)

directive = ""
onboarding_lane = confighub_onboarding_lane(prompt)
teach_intent = fast_teach_intent(prompt)

choice_match = re.fullmatch(
    r"(?:pilot[,:]?\s+)?(?:(?:option|choice|number)\s+)?([1-8])[.!?]*",
    lowered,
)
previous_assistant = last_assistant_text(data.get("transcript_path"))
onboarding_context_is_current = bool(
    re.search(
        r"(?im)^(?:PILOT COCKPIT \| ONBOARD|"
        r"(?:Lane|Route|Journey) \| .*\b(?:ConfigHub|CHE|pilot onboard)\b)",
        previous_assistant,
    )
    or "confighub-pilot.onboarding-readiness" in previous_assistant
)
previous_lane_match = re.search(r"(?im)^Lane\s*\|\s*(.+)$", previous_assistant)
previous_onboarding_lane = (
    named_confighub_lane(previous_lane_match.group(1))
    if previous_lane_match is not None
    else None
)
if (
    onboarding_lane is None
    and onboarding_context_is_current
    and confighub_prerequisite_followup(prompt)
):
    onboarding_lane = previous_onboarding_lane or ""
full_catalog_is_current = bool(
    re.search(r"(?m)^PILOT COCKPIT \| CHOOSE A JOURNEY\s*$", previous_assistant)
)
startup_catalog_is_current = bool(
    re.search(r"(?m)^PILOT COCKPIT \| START\s*$", previous_assistant)
)
canonical_journey = next(
    (
        journey
        for journey in PILOT_JOURNEYS
        if normalized_route_phrase(prompt) in canonical_journey_phrases(journey)
    ),
    None,
)

if PILOT_RUNTIME_STATUS.fullmatch(normalized_prompt):
    directive = (
        "JOURNEY ROUTE (Pilot): the user asked whether Pilot loaded in Claude, "
        "not whether a doorway command can be executed. Run `pilot claude status "
        "--global --json`. Report plugin registry enablement, configured presence "
        "mode, current-process activation, installed/source surface alignment, "
        "and `running_claude_session_loaded` separately. A selected Pilot skill "
        "proves only selection for this prompt; neither `PILOT_DOORWAY_READY` nor "
        "an enabled registry entry proves always-on startup presence or an active "
        "job. Do not substitute `pilot doorway` and do not say Pilot is running "
        "or idle."
    )
elif choice_match and full_catalog_is_current:
    choice = choice_match.group(1)
    directive = (
        "JOURNEY ROUTE (Pilot): the user selected a numbered job from the "
        "immediately preceding full Pilot chooser. Acknowledge the selection "
        "immediately, then run "
        f"`pilot catalog --jobs --select {choice} --json`. Follow only the "
        "returned selection and its starter command; preserve its stated "
        "write, approval, and proof boundary. Do not reinterpret the number "
        "from an older menu or an improvised list."
    )
elif choice_match and choice_match.group(1) in "12345" and startup_catalog_is_current:
    choice = choice_match.group(1)
    directive = (
        "JOURNEY ROUTE (Pilot): the user selected a numbered group from the "
        "immediately preceding compact Pilot startup chooser. Acknowledge the "
        "selection immediately, then run "
        f"`pilot catalog --startup --select {choice} --json`. Follow only the "
        "returned selection and its starter command; preserve its stated "
        "write, approval, and proof boundary. The immediately preceding cockpit "
        "header decides whether a number belongs to the compact 1-5 groups or "
        "the expanded 1-8 journeys."
    )
elif canonical_journey is not None:
    journey_id = str(canonical_journey.get("job_id") or "unknown")
    journey_label = str(canonical_journey.get("label") or journey_id)
    journey_command = canonical_journey_command(canonical_journey)
    write_posture = str(canonical_journey.get("write_posture") or "")
    directive = (
        "JOURNEY ROUTE (Pilot): the user selected one canonical Pilot journey. "
        f"Before calling a tool, answer immediately with: `PILOT COCKPIT | {journey_id.upper()}`, "
        f"`Journey | {journey_id}`, `Goal | {journey_label}`. Then run "
        f"`{journey_command}` and follow the returned route. The command comes from "
        "the same eight-journey catalog used by Codex and the installed CLI. Preserve "
        f"this boundary exactly: {write_posture} A journey selection never grants "
        "ConfigHub, controller, cluster, or Git mutation authority by itself."
    )
elif REPEATABLE_APP.fullmatch(normalized_prompt):
    directive = (
        "JOURNEY ROUTE (Pilot): the user asked to make their current app or "
        "workflow repeatable — the BUILD journey. Before calling a tool, answer "
        "immediately with: `PILOT COCKPIT | BUILD`, `Journey | build`. Run the existing natural-language "
        "owner from the user's current project root: `pilot ask \"make this "
        "repeatable as an app\" --repo . --render-cockpit`. The word `this` means "
        "the user's current app, workflow, or project represented by the current "
        "working directory and conversation. It never means Pilot itself, Pilot's "
        "doorway, the startup cockpit, this hook, or the most recent assistant "
        "message. This exact `pilot ask` selection takes precedence over generic "
        "Pilot activation: do not substitute `pilot doorway`, `pilot automate`, "
        "`pilot route`, generic application authoring, or a generic Kubernetes "
        "skill. Follow the typed next command returned by `pilot ask`; the existing "
        "`operational-app-pack` route remains the only app-pack owner. Preserve its "
        "review, approval, output-directory, and proof gates."
    )
elif EXPLAIN_PILOT.search(lowered) or teach_intent == "purpose":
    topic = "overview"
    if "architect" in lowered or "how do you work" in lowered:
        topic = "architecture"
    elif "add a scenario" in lowered or "add an app" in lowered or "contribut" in lowered:
        topic = "contribute"
    elif "router" in lowered or "routing" in lowered or "how do you route" in lowered:
        topic = "router"
    elif "scenario" in lowered:
        topic = "scenarios"
    elif "approval" in lowered:
        topic = "approvals"
    elif "execution" in lowered or "execute" in lowered or "real changes" in lowered:
        topic = "execution"
    elif "proof" in lowered or "receipt" in lowered or "how do you prove" in lowered:
        topic = "proof"
    elif "memory" in lowered or "learning loop" in lowered:
        topic = "memory"
    elif "surface" in lowered or "gui" in lowered or re.search(r"\bui\b", lowered):
        topic = "surfaces"
    elif "roadmap" in lowered or "real today" in lowered:
        topic = "roadmap"
    elif "demo" in lowered or "tutorial" in lowered:
        topic = "demos"
    elif teach_intent != "purpose" and ("expert" in lowered or "confighub" in lowered):
        topic = "expertise"
    cockpit_topics = {
        "architecture",
        "router",
        "scenarios",
        "approvals",
        "execution",
        "proof",
        "memory",
        "surfaces",
        "roadmap",
    }
    cockpit_flag = " --render-cockpit" if topic in cockpit_topics else ""
    directive = (
        "JOURNEY ROUTE (Pilot): the user asked Pilot to explain itself. Before "
        "calling a tool, answer immediately with: `PILOT COCKPIT | EXPLAINING "
        "PILOT`, `Journey | teach`, `Goal | Understand Pilot and try a real job`, `Now | Loading "
        "the smallest useful explanation`. Then run "
        f"`pilot manual --explain --topic {topic}{cockpit_flag}` and present that source-backed "
        "explanation in Pilot's helpful, candid companion voice. Keep its "
        "read/write boundary, current gaps, and next ordinary-language prompts. "
        "The selected manual helper takes precedence over generic Pilot activation; "
        "execute it directly and do not substitute `pilot doorway`, `pilot teach`, "
        "or an improvised file-reading route. "
        "Do not replace it with improvised marketing copy or turn a listed "
        "capability into a live-proof claim. This explanation route is read-only."
    )
elif SHOW_SCENARIO_WORKFLOWS.search(lowered):
    directive = (
        "JOURNEY ROUTE (Pilot): the user asked for named workflow and scenario examples, "
        "not the top-level journey chooser. Run `pilot catalog --scenarios` and present "
        "its human rows with each route's read/write boundary. Do not hide the handoff "
        "behind flags or replace it with an improvised command list."
    )
elif SHOW_JOBS.search(lowered):
    directive = (
        "JOURNEY ROUTE (Pilot): the user asked to browse Pilot's jobs and "
        "scenarios. Before calling a tool, answer immediately with this compact "
        "acknowledgement: `PILOT COCKPIT | LOADING JOBS`, `Goal | Choose a job "
        "to be done`, `Now | Opening Pilot's human scenario catalog`. Then run "
        "`pilot catalog --jobs` and present its human chooser without replacing "
        "it with command names or an improvised list. Ask the user to choose a "
        "number or job name. The chooser states which paths can write and where "
        "approval is required."
    )
elif guided_engagement_action(prompt) is not None:
    engagement_action = guided_engagement_action(prompt)
    if engagement_action == "status":
        engagement_command = "pilot engagement status --json"
        goal = "Resume the customer's progress across Pilot's eight journeys"
        now = "Opening the latest caller-owned local engagement record"
    else:
        engagement_command = shlex.join(
            ["pilot", "engagement", "start", "--objective", prompt, "--json"]
        )
        goal = "Guide one customer from learning to a proved next step"
        now = "Starting one resumable record over Pilot's eight journeys"
    directive = (
        "JOURNEY ROUTE (Pilot): the user asked for the existing guided customer "
        "engagement. Before calling a tool, answer immediately with: `PILOT "
        f"COCKPIT | GUIDED ENGAGEMENT`, `Goal | {goal}`, `Now | {now}`. Then run "
        f"`{engagement_command}` and follow its canonical current chapter and next "
        "action. When the engagement starts, state in one plain line who "
        "executes commands: the user, in their own terminal (you explain and "
        "verify), or Pilot, here. For an ordinary bounded ConfigHub write, Pilot "
        "shows one literal context-bound command, lets the host decide whether "
        "the exact attempt runs, then verifies the resulting revision or Release "
        "read-only. Permission is not success proof. Keep that statement current "
        "if the mode changes. At each checkpoint that creates an entity, "
        "define new terms in one plain line, then render the compact "
        "entity-created state card with `scripts/confighub-ux-cockpit "
        "--trigger entity-created --space <slug> --unit <unit> --entity-state "
        "stored|deployed --next <one next step>` (the real cockpit renderer, "
        "not a hand-written summary): what now exists, stored/NotLive versus "
        "deployed, one next step. Offer the verified GUI link — when you "
        "produce it yourself, generate it with `scripts/confighub-gui-urls "
        "--space <slug>`, name a "
        "`GUI_URL_UNVERIFIED` gap instead of guessing, and hand the user "
        "the current visual sibling: `cub space open <slug>` or `cub unit "
        "open <unit> --space <space>`; add `--print-url` to print rather than "
        "open it. The former `get/list --web` forms are versioned legacy and "
        "must not be coached. Include the login step — a UI link without its access step is "
        "incomplete. "
        "Prefer carded Pilot reads over raw cub or kubectl for evidence, "
        "stating any coverage gap in one line before a raw command. Verify "
        "delete or destroy flags with `cub <verb> --help` before composing "
        "them; teardown starts from the dependency web via the read-only "
        "`pilot teardown-plan` handoff — never compose recursive lifecycle "
        "flags yourself; the person runs composed commands in their terminal. "
        "This is a composed field engagement over TEACH, ONBOARD, SET UP & "
        "ORGANISE, DISCOVER, BUILD, OPERATE, FIX, and AUTOMATE; it is not a ninth "
        "journey or a second catalog. The record is local and resumable. It does "
        "not grant ConfigHub authority, approve writes, or turn recorded progress "
        "into live proof."
    )
elif looks_like_organise_request(prompt):
    directive = (
        "JOURNEY ROUTE (Pilot): the user selected ORGANISE beneath SET UP & "
        "ORGANISE. Before calling a tool, answer immediately with: `PILOT "
        "COCKPIT | ORGANISE`, `Journey | set-up`, `Goal | See the knowledge, evidence, context, and "
        "shared-work owners in scope`, `Now | Inventorying existing owners; "
        "nothing will change`. Then run `pilot organise --plain`. Present its "
        "inspection scope, honest gaps, and one next action. Do not turn this "
        "into a ninth journey, generic file cleanup, automatic corpus promotion, "
        "or ConfigHub administration. Any later write keeps its existing preview, "
        "host decision or dedicated higher-risk authority, execution, verification, and receipt owner."
    )
elif onboarding_lane is not None:
    lane_arg = f" {onboarding_lane}" if onboarding_lane else ""
    command = f"pilot onboard{lane_arg} --intent {shlex.quote(prompt)} --json"
    directive = (
        "JOURNEY ROUTE (Pilot): the user wants to enter ConfigHub. Preserve the "
        "existing path TEACH -> ONBOARD -> SET UP & ORGANISE. Before calling a "
        "tool, answer immediately with: `PILOT COCKPIT | ONBOARD`, `Journey | onboard`, `Goal | Reach "
        "a first useful ConfigHub result`, `Now | Choosing the Cloud or CHE lane "
        "without waiting for login or installation`. Then run "
        f"`{command}`. Present its evidence-ranked lane recommendation, at most "
        "one meaningful alternative with its tradeoff, and one next action. A "
        "bare packet normally recommends Cloud as the fastest evaluation lane; "
        "self-hosted, on-premises, private-cloud, air-gapped, or CHE constraints "
        "select CHE. Follow the packet's exact receipt and runnable resume command. "
        "Use the packet's authoritative links and typed checkpoint; do not copy "
        "CHE install commands, treat login as proof, or skip ONBOARD by jumping "
        "straight to setup. Cloud context verification and CHE operator work are "
        "resumable follow-on checkpoints."
    )
elif (
    teach_intent is not None
    or TUTORIAL_TEACH_ROUTE.fullmatch(normalized_prompt)
    or TEACH.search(lowered)
    or concept_teach_subject(prompt) is not None
):
    url_match = re.search(r"https?://[^\s)>]+", prompt)
    concept_slug = None if url_match else concept_teach_subject(prompt)
    subject = compact(url_match.group(0) if url_match else (concept_slug or prompt))
    teach_command = shlex.join(["pilot", "teach", subject, "--json"])
    directive = (
        "JOURNEY ROUTE (Pilot): the user wants Pilot to teach, explain a "
        "source, or recommend what to try next. Before calling a tool, answer "
        "immediately with: `PILOT COCKPIT | TEACH`, `Journey | teach`, `Goal | Understand this "
        "and try something useful`, `Now | Finding the smallest source-backed "
        "learning path`, `First useful result | A plain-English explanation "
        "and one smallest runnable next step`. Then run "
        f"`{teach_command}`. If the packet says "
        "`HOST_DOCUMENT_READER_REQUIRED`, read the exact URL, attachment, or "
        "document with the host reader before explaining it. Follow the "
        "packet's teaching brief: explain the important ideas in plain English, "
        "cross-reference current Pilot and ConfigHub behavior, distinguish "
        "proof from aspiration, and recommend one smallest useful tutorial, "
        "demo, showcase, or scenario. Offer to stay with the user while they "
        "try it. When the user does the typing, give one command per fenced "
        "block (never semicolon-chained), say it runs in the user's own "
        "terminal, and ask them to paste the output back unless the host runs "
        "the block for them; if they type a bare command as a chat message, "
        "first say that nothing has run yet, then hand back the runnable "
        "block. Define each ConfigHub term of art in one plain line at first "
        "use (a Space is ConfigHub's versioned folder for one deployable "
        "thing's config). After any step that creates an entity, render the "
        "compact entity-created state card with `scripts/confighub-ux-cockpit "
        "--trigger entity-created --space <slug> --unit <unit> --entity-state "
        "stored|deployed --next <one next step>` (the real cockpit renderer, "
        "not a hand-written summary) — what now exists by name and count, "
        "whether it is stored (NotLive) or deployed, and the single next "
        "step — and offer the verified GUI link: when you produce it "
        "yourself, generate it with `scripts/confighub-gui-urls --space "
        "<slug>` and name a `GUI_URL_UNVERIFIED` "
        "gap instead of guessing; hand the user `cub space open <slug>` "
        "or `cub unit open <unit> --space <space>`, adding `--print-url` when "
        "the URL should be printed. The former `get/list --web` forms are "
        "versioned legacy and must not be coached. Include the current command's "
        "login step; any UI link without its access step is an incomplete "
        "checkpoint (the local Argo UI has no SSO by design; its admin "
        "credentials are in the cluster env file the setup wrote). When "
        "coaching get-started stage 3, immediately after the user's first "
        "`cub release publish <component>-dev` and before any pod watch or "
        "raw cub/kubectl fallback, explain that a delivery trace is Pilot's "
        "read-only six-link check from a ConfigHub Release through Argo to "
        "the workload. In the user's own terminal run `pilot delivery-trace "
        "--space <component>-dev --cluster-space dev --namespace <ns> "
        "--cub-context <context> --out-dir <receipt-dir>` after replacing "
        "every placeholder with the exact created values. It needs the same "
        "authenticated cub login and named ConfigHub context; its Kubernetes "
        "reads separately use the current kubeconfig context for the dev "
        "practice cluster, and those two contexts do not prove each other. "
        "Keep the ordinary compact card and both saved receipt files. An "
        "Application Unit is the small ConfigHub record that tells Argo which "
        "Release to run. Stop before pod watch/raw fallback on the first FAIL "
        "or on UNKNOWN; UNKNOWN is never PASS. Only PASS permits an optional "
        "later `kubectl get pods -n <ns>` read. This read-only trace is a "
        "point-in-time, Argo-only T0/T1 observation, not proof of an Argobot "
        "event or causal path, a sync request, guaranteed freshness, an "
        "under-one-minute result, or live T2/T3 delivery. When "
        "evidence is needed, prefer carded Pilot reads over raw cub or "
        "kubectl, and if no Pilot surface covers the read, say that gap in "
        "one line before running the raw command. Before any delete or "
        "destroy command, verify its flags with `cub <verb> --help` in this "
        "session; never compose a destructive command from memory. "
        "Do not answer with a search-result list, and do not call "
        "`pilot learn`; that is the separate reviewed product-memory path. "
        "TEACH itself is read-only; a selected scenario keeps its own approval "
        "and proof boundary. The returned `tutorial_intent` is the only owner of "
        "whether this prompt is orientation, authorization to start one tutorial, "
        "or an unsupported request for all tutorials. Present `tutorial_run` only "
        "when the packet contains it; otherwise explain or recommend and wait. "
        "Never start a second tutorial from the hook, broaden one into all, or "
        "invent a fallback when `tutorial_route_error` is present."
    )
elif GUIDED_TOUR.search(lowered):
    directive = (
        "JOURNEY ROUTE (Pilot): the user asked for the guided tour. Before "
        "calling a tool, answer immediately with: `PILOT COCKPIT | STARTING "
        "TOUR`, `Journey | teach`, `Goal | See Pilot do useful work`, `Now | Loading the safe first "
        "route`. Then run `pilot quickstart --progress-card`. Offer three "
        "runnable starter examples in order: understand and onboard a project; "
        "generate governed configuration; find and fix an operational problem "
        "with the cost app. Start read-only. Do not create a sandbox or mutate "
        "ConfigHub until the user explicitly chooses and approves that step."
    )
elif DEPLOYABLE.search(lowered):
    request = compact(prompt)
    ask_command = shlex.join(["pilot", "ask", request, "--progress-card"])
    directive = (
        "JOURNEY ROUTE (Pilot): the user asked to make this app deployable — "
        "the SET UP journey, which has a deterministic evidence-backed path. "
        "Before calling a tool, answer immediately with: `PILOT COCKPIT | SET UP`, "
        "`Journey | set-up`. "
        "BEFORE any generic Kubernetes authoring or hand-written manifests, "
        "run from the project root: "
        f"`{ask_command}`. "
        "This selected helper remains the owner even when `pilot doorway` already "
        "ran; the doorway is context, not the app named by `this`. "
        "It derives a small reviewable Base (Namespace, Deployment, Service) from "
        "repository evidence, saves the files OUTSIDE the application repository, "
        "marks unverified facts (such as an unchecked image digest) honestly, and "
        "stops before anything live. Keep any container image reference the user "
        "supplied verbatim inside the quoted request. Present the Progress Card and "
        "follow its 'Do this next' step. Fall back to companion skills only if the "
        "`pilot` command is unavailable on this machine."
    )
elif ORIENTATION.search(lowered) and "pilot" in lowered:
    directive = (
        "JOURNEY ROUTE (Pilot): the user asked what they can do here — open the "
        "job chooser, not a single guessed journey. Before calling a tool, answer "
        "immediately with this compact acknowledgement: `PILOT COCKPIT | LOADING "
        "JOBS`, `Goal | Choose a job to be done`, `Now | Opening Pilot's human "
        "scenario catalog`. Then run `pilot catalog --jobs` and present its human "
        "chooser without replacing it with command names or an improvised list. "
        "Ask the user to choose a number or job name. The chooser states which "
        "paths can write and where approval is required."
    )
else:
    app_match = APP_REQUEST.search(lowered)
    if app_match and not DEPLOYABLE.search(lowered):
        phrase = compact(app_match.group(0))
        app_command = shlex.join(
            ["pilot", "operational-app-pack", "--query", phrase, "--render-cockpit"]
        )
        directive = (
            f"JOURNEY ROUTE (Pilot): the user asked for an operational app "
            f"('{phrase}') — the BUILD journey. Before calling a tool, answer "
            f"immediately with: `PILOT COCKPIT | BUILD`, `Journey | build`. BEFORE writing any "
            f"application code by hand, run: "
            f"`{app_command}` "
            f"(add `--out-dir <dir>` when the pack files are needed). "
            f"Catalog-matched requests produce a tested app pack and generation "
            f"plan; unmatched requests stop with typed gaps instead of forcing "
            f"the nearest catalog entry. Build only from the produced plan and "
            f"keep its stated dependency versions and completion gates."
        )

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
