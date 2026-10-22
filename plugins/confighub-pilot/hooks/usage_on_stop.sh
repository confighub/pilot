#!/usr/bin/env bash
#
# Stop / SessionEnd hook — record model token spend into the activity trace.
#
# The trace event stream (EVENTS.jsonl) records what happened on which lane,
# but until this hook it recorded nothing about what the reasoning cost, so
# token spend could not be attributed to Rail State routing modes
# (docs/engineering/NOOA_ADOPTED.md §12.v). This hook closes that gap on the
# Claude Code adapter: at every Stop (end of an assistant turn) and at
# SessionEnd it reads the session transcript the harness names in the hook
# input, sums per-message usage (deduplicated by message id + request id, so
# streamed content blocks are not double-counted), diffs against a per-session
# cursor stored next to EVENTS.jsonl, and appends the delta as a
# pilot-trace-event.v1 usage event via `cub-trace-emit usage`:
#
#   usage.source       = claude-code-transcript  (measured, not asserted)
#   usage.route_source = model-reasoning         (harness spend is model spend;
#                        deterministic script paths record their own explicit
#                        zeros with route_source=script-helper)
#
# The cursor advances only after the event is appended, so a failed append is
# retried at the next Stop instead of losing spend. If the transcript shrinks
# (rotation/compaction), the cursor re-baselines silently rather than
# recording a negative or inflated delta. The hook emits nothing to stdout
# (CUB_TRACE_QUIET=1): usage rows are bookkeeping for `cub-trace-session
# usage`, not a trust moment for the human. A usage row is spend attribution,
# never proof that the paid-for work succeeded.
#
# A hook failure MUST NEVER block the turn or the session end.

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

if ! command -v python3 >/dev/null 2>&1; then
    exit 0
fi

default_trace_dir() {
    local root
    if [[ -n "${PILOT_USER_HOME:-}" ]]; then
        root="$PILOT_USER_HOME"
    elif [[ -n "${PILOT_DATA_HOME:-}" ]]; then
        root="$PILOT_DATA_HOME"
    elif [[ -n "${PILOT_PROJECT_HOME:-}" ]]; then
        root="${PILOT_PROJECT_HOME%/}/.pilot"
    else
        root="${HOME:?HOME is required}/.pilot"
    fi
    case "$root" in
        "~") root="$HOME" ;;
        "~/"*) root="$HOME/${root#\~/}" ;;
    esac
    printf '%s/traces' "${root%/}"
}

TRACE_DIR="${CUB_TRACE_RUN_DIR:-$(default_trace_dir)}"

# The python program below arrives on stdin via the heredoc, so the hook input
# JSON must be captured first and passed through the environment.
HOOK_INPUT="$(cat 2>/dev/null || true)"
export TRACE_DIR PILOT_SCRIPTS HOOK_INPUT

python3 <<'PYEOF' 2>/dev/null || true
import json
import os
import re
import subprocess
import sys
from pathlib import Path

try:
    hook_input = json.loads(os.environ.get("HOOK_INPUT") or "")
except Exception:
    sys.exit(0)
if not isinstance(hook_input, dict):
    sys.exit(0)

transcript_path = hook_input.get("transcript_path") or ""
session_id = str(hook_input.get("session_id") or "unknown")
hook_event = str(hook_input.get("hook_event_name") or "Stop")
if not transcript_path:
    sys.exit(0)
transcript = Path(transcript_path)
if not transcript.is_file():
    sys.exit(0)

# ---------------------------------------------------------------------------
# Cumulative usage from the transcript. Streamed responses repeat the same
# API result across several transcript lines (one per content block) with the
# same message id and usage, so keep the last-seen usage per
# (request id, message id) instead of summing every line.
# ---------------------------------------------------------------------------
FIELD_MAP = {
    "input_tokens": "input_tokens",
    "output_tokens": "output_tokens",
    "cache_creation_input_tokens": "cache_creation_tokens",
    "cache_read_input_tokens": "cache_read_tokens",
}
per_message: dict[tuple[str, str], dict] = {}
model = ""
try:
    with transcript.open(encoding="utf-8") as handle:
        for index, line in enumerate(handle):
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            message = entry.get("message")
            if not isinstance(message, dict):
                continue
            usage = message.get("usage")
            if not isinstance(usage, dict):
                continue
            key = (
                str(entry.get("requestId") or ""),
                str(message.get("id") or entry.get("uuid") or index),
            )
            per_message[key] = usage
            entry_model = message.get("model")
            if isinstance(entry_model, str) and entry_model and not entry_model.startswith("<"):
                model = entry_model
except OSError:
    sys.exit(0)

cumulative = {name: 0 for name in FIELD_MAP.values()}
for usage in per_message.values():
    for transcript_field, event_field in FIELD_MAP.items():
        value = usage.get(transcript_field)
        if isinstance(value, int) and not isinstance(value, bool) and value > 0:
            cumulative[event_field] += value

# ---------------------------------------------------------------------------
# Diff against the per-session cursor stored next to EVENTS.jsonl.
# ---------------------------------------------------------------------------
trace_dir = Path(os.environ["TRACE_DIR"])
safe_session = re.sub(r"[^A-Za-z0-9._-]", "_", session_id) or "unknown"
cursor_path = trace_dir / f"USAGE_CURSOR-{safe_session}.json"

recorded = {name: 0 for name in FIELD_MAP.values()}
if cursor_path.is_file():
    try:
        cursor = json.loads(cursor_path.read_text(encoding="utf-8"))
        for name in recorded:
            value = (cursor.get("cumulative") or {}).get(name)
            if isinstance(value, int) and not isinstance(value, bool) and value > 0:
                recorded[name] = value
    except (OSError, json.JSONDecodeError):
        pass


def write_cursor() -> None:
    trace_dir.mkdir(parents=True, exist_ok=True)
    pending = cursor_path.with_name(cursor_path.name + f".{os.getpid()}")
    pending.write_text(
        json.dumps(
            {
                "schema": "confighub-pilot.trace-usage-cursor.v1",
                "session_id": session_id,
                "transcript_path": str(transcript),
                "cumulative": cumulative,
            },
            separators=(",", ":"),
        )
        + "\n",
        encoding="utf-8",
    )
    pending.replace(cursor_path)


delta = {name: cumulative[name] - recorded[name] for name in cumulative}
if any(value < 0 for value in delta.values()):
    # Transcript shrank (rotation/compaction): re-baseline without recording
    # a wrong delta.
    write_cursor()
    sys.exit(0)
if all(value == 0 for value in delta.values()):
    sys.exit(0)

command = [
    os.path.join(os.environ["PILOT_SCRIPTS"], "cub-trace-emit"),
    "usage",
    "--input-tokens", str(delta["input_tokens"]),
    "--output-tokens", str(delta["output_tokens"]),
    "--cache-creation-tokens", str(delta["cache_creation_tokens"]),
    "--cache-read-tokens", str(delta["cache_read_tokens"]),
    "--source", "claude-code-transcript",
    "--route-source", "model-reasoning",
    "--meta", json.dumps({"session_id": session_id, "hook_event": hook_event}, separators=(",", ":")),
]
if model:
    command.extend(["--model", model])

env = dict(os.environ)
env["CUB_TRACE_QUIET"] = "1"
result = subprocess.run(
    command,
    env=env,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    check=False,
)
if result.returncode == 0:
    # Advance the cursor only after the event landed, so a failed append is
    # retried at the next Stop instead of dropping spend.
    write_cursor()
PYEOF

# ---------------------------------------------------------------------------
# Pilot cockpit card (Stop only). When Pilot is switched on and something ran
# this turn, draw a small coloured card under the reply. Pilot draws it, not
# the model, so Pilot's voice stays visibly separate from Claude's.
#
# What it reads:
#   - the hook input (session id, transcript path, and on newer Claude Code
#     builds the last reply text);
#   - this turn's tool calls and their results from the session transcript
#     (a turn starts at the last real user message);
#   - lanes: each Bash command this turn is sorted into an activity lane with
#     scripts/cub-trace-classify. The trace file (EVENTS.jsonl) is not used for
#     this: its rows carry no session id or turn, so they cannot be tied to
#     one reply, and a command that was declined still has a row there.
#
# It prints one JSON line {"systemMessage": "..."} and nothing else. Any
# error prints nothing. SessionEnd never draws.
# ---------------------------------------------------------------------------
python3 <<'CARDEOF' 2>/dev/null || true
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

START = time.monotonic()
WIDTH = 78
LANE_ORDER = ["META", "GIT-READ", "CH-READ", "LIVE-READ", "CH-WRITE", "EXT-WRITE", "PROOF", "change"]
WRITE_LANES = {"CH-WRITE", "EXT-WRITE"}
FOOTER_TEXT = '"Pilot, show me the full cockpit"'

try:
    hook_input = json.loads(os.environ.get("HOOK_INPUT") or "")
except Exception:
    sys.exit(0)
if not isinstance(hook_input, dict) or hook_input.get("hook_event_name") != "Stop":
    sys.exit(0)
transcript_path = hook_input.get("transcript_path") or ""
if not transcript_path or not Path(transcript_path).is_file():
    sys.exit(0)

# --- colour switches: same rule as the Pilot status line ---------------------
use_color = not (
    os.environ.get("CONFIGHUB_STATUSLINE_COLOR", "1") == "0"
    or os.environ.get("CONFIGHUB_BRANDING", "1") == "0"
    or os.environ.get("NO_COLOR", "")
)
ICE, GREEN, AMBER, RED = "38;5;117", "38;5;46", "38;5;214", "38;5;167"


# --- read this turn from the transcript (tail first, so long sessions stay fast)
def is_real_user(entry):
    if entry.get("type") != "user" or entry.get("isMeta") or entry.get("isSidechain"):
        return False
    message = entry.get("message")
    if not isinstance(message, dict):
        return False
    content = message.get("content")
    if isinstance(content, str):
        return bool(content.strip()) and not content.lstrip().startswith("<system-reminder>")
    if isinstance(content, list):
        if any(isinstance(b, dict) and b.get("type") == "tool_result" for b in content):
            return False
        texts = [b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"]
        return any(t.strip() and not t.lstrip().startswith("<system-reminder>") for t in texts)
    return False


def read_turn(path):
    size = path.stat().st_size
    window = 1 << 20
    while True:
        start = max(0, size - window)
        with path.open("rb") as handle:
            handle.seek(start)
            raw = handle.read()
        lines = raw.split(b"\n")
        if start > 0:
            lines = lines[1:]
        entries = []
        for line in lines:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except Exception:
                continue
            if isinstance(entry, dict):
                entries.append(entry)
        found = None
        for index in range(len(entries) - 1, -1, -1):
            if is_real_user(entries[index]):
                found = index
                break
        if found is not None:
            TURN_PROMPT.append(entries[found])
            return entries[found + 1:]
        if start == 0:
            return entries
        if window >= (1 << 28):
            return None
        window <<= 2


TURN_PROMPT = []
turn = read_turn(Path(transcript_path))
if not turn:
    sys.exit(0)

tool_uses = []   # (id, name, input)
results = {}     # id -> (is_error, text)
assistant_texts = []  # (message id, text)
for entry in turn:
    if entry.get("isSidechain"):
        continue
    message = entry.get("message")
    if not isinstance(message, dict):
        continue
    content = message.get("content")
    if not isinstance(content, list):
        continue
    for block in content:
        if not isinstance(block, dict):
            continue
        kind = block.get("type")
        if entry.get("type") == "assistant" and kind == "tool_use":
            tool_uses.append((str(block.get("id") or ""), str(block.get("name") or ""), block.get("input") or {}))
        elif entry.get("type") == "assistant" and kind == "text":
            text = block.get("text")
            if isinstance(text, str) and text.strip():
                assistant_texts.append((str(message.get("id") or entry.get("uuid") or ""), text))
        elif entry.get("type") == "user" and kind == "tool_result":
            body = block.get("content")
            if isinstance(body, list):
                body = "\n".join(b.get("text", "") for b in body if isinstance(b, dict))
            results[str(block.get("tool_use_id") or "")] = (bool(block.get("is_error")), body if isinstance(body, str) else "")

last_text = hook_input.get("last_assistant_message")
if not (isinstance(last_text, str) and last_text.strip()):
    last_text = ""
    if assistant_texts:
        last_id = assistant_texts[-1][0]
        last_text = "\n".join(t for i, t in assistant_texts if i == last_id)

# --- headings and rows from the last reply ----------------------------------
phase = "NOW"
heading = None
for match in re.finditer(r"PILOT COCKPIT\s*(?:\||//)\s*([A-Z][A-Z]{1,15})", last_text):
    heading = match.group(1)
if heading:
    phase = heading


def clean(value):
    value = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", value)
    value = value.replace("**", "").replace("__", "")
    value = re.sub(r"[\x00-\x1f\x7f-\x9f]", " ", value)
    value = re.sub(r"\s+", " ", value).strip()
    value = value.strip("| ").strip()
    return value


def lift(label_pattern):
    found = ""
    for raw in last_text.splitlines():
        line = re.sub(r"^[\s|>*#\-]+", "", raw)
        match = re.match(
            r"(?:" + label_pattern + r")(?:\s*\([^)]*\))?\**\s*(?:\||:|—|–|-)\s*(.+)$",
            line,
            re.IGNORECASE,
        )
        if match:
            value = clean(match.group(1))
            if value:
                found = value
                break
    return found


goal = lift(r"Goal")
nxt = lift(r"Next") or lift(r"Recommended")


def after_heading(label_pattern):
    """The first line of text under a heading such as "Next step"."""
    lines = last_text.splitlines()
    for index, raw in enumerate(lines):
        line = clean(re.sub(r"^[\s>*#]+", "", raw)).rstrip(":")
        if re.fullmatch(label_pattern, line, re.IGNORECASE):
            for following in lines[index + 1:]:
                value = clean(re.sub(r"^[\s>*#\-]+", "", following))
                if value:
                    return value
    return ""


def prompt_text():
    """What the person asked this turn, in their own words."""
    if not TURN_PROMPT:
        return ""
    content = (TURN_PROMPT[0].get("message") or {}).get("content")
    if isinstance(content, list):
        content = " ".join(b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text")
    if not isinstance(content, str) or content.strip().startswith("/"):
        return ""
    return clean(content)


# When the reply has no Goal or Next row, the card still says what this turn
# was for (the person's own request) and what comes next (the paragraph under
# the reply's "Next step" heading), so it is never just a lanes line.
own_rows = bool(goal or nxt)
if not goal:
    goal = prompt_text()
if not nxt:
    nxt = after_heading(r"(?:next steps?|what next|what to do next|recommended next step)")

# --- lanes -------------------------------------------------------------------
scripts = os.environ.get("PILOT_SCRIPTS") or ""
classify = os.path.join(scripts, "cub-trace-classify")
cache = {}
# Only run the classifier on lines that name a tool it knows; `ls` or `cd` never match.
TOOL_WORDS = re.compile(r"\b(pilot|cub|cub-scan|confighub-scan|kubectl|argocd|flux|helm|kustomize|git|oras|docker|gh|receipt|proof|scout)\b")


def lanes_of(command):
    found = []
    for segment in re.split(r"\s*(?:&&|\|\||;|\||\n)\s*", command):
        segment = segment.strip()
        if not segment or segment.startswith("#") or not TOOL_WORDS.search(segment):
            continue
        if segment not in cache and re.match(r"(?:\S*/)?pilot\s", segment + " "):
            # Pilot's own commands: the trace classifier does not label them.
            # A delivery trace compares ConfigHub, the controller and the
            # cluster (PROOF); any other pilot command reads and routes (META).
            cache[segment] = "PROOF" if re.match(r"(?:\S*/)?pilot\s+delivery-trace\b", segment) else "META"
        if segment not in cache:
            lane = ""
            if len(cache) < 40 and time.monotonic() - START < 2.0 and os.access(classify, os.X_OK):
                try:
                    done = subprocess.run(
                        [classify, "--json", segment],
                        capture_output=True, text=True, timeout=1, check=False,
                    )
                    if done.returncode == 0 and done.stdout.strip():
                        lane = str(json.loads(done.stdout).get("lane") or "")
                except Exception:
                    lane = ""
            cache[segment] = lane
        if cache[segment]:
            found.append(cache[segment])
    return found


RANK = {"ran": 1, "asks": 2, "stopped": 3}
marks = {}
stopped_any = asked_any = changed_any = read_any = False
for tool_id, name, tool_input in tool_uses:
    if name != "Bash" or not isinstance(tool_input, dict):
        continue
    command = str(tool_input.get("command") or "")
    is_error, body = results.get(tool_id, (False, None))
    if body is not None and "Pilot stopped this command" in body:
        state = "stopped"
    elif body is None:
        state = "asks"
    elif is_error and re.search(r"doesn.t want to proceed|tool use was rejected|user rejected", body, re.IGNORECASE):
        state = "declined"
    elif is_error and "Pilot is asking before this command runs" in body:
        state = "declined"
    else:
        state = "ran"
    lanes = lanes_of(command)
    if state == "stopped":
        stopped_any = True
    elif state in ("asks", "declined"):
        # A person was asked about this command and it did not run. That is
        # what the status must say, whether or not the classifier labelled the
        # command in time (on a busy machine it may not have).
        asked_any = True
        if not any(l in WRITE_LANES for l in lanes):
            # Show it on the lanes line even when it could not be classified.
            lanes = lanes + ["change"]
    for lane in lanes:
        if state == "stopped":
            mark = "stopped"
        elif state in ("asks", "declined"):
            mark = "asks" if lane in WRITE_LANES or lane == "change" else None
        else:
            mark = "ran"
        if mark is None:
            continue
        if RANK[mark] > RANK.get(marks.get(lane), 0):
            marks[lane] = mark
        if mark == "ran":
            if lane in WRITE_LANES:
                changed_any = True
            else:
                read_any = True

if stopped_any:
    status, status_color = "Stopped", RED
elif asked_any:
    status, status_color = "Needs your approval", AMBER
elif changed_any:
    status, status_color = "Changed, reading back", None
elif read_any:
    status, status_color = "Read only", None
else:
    status, status_color = "", None

# --- when to draw ------------------------------------------------------------
if not tool_uses and not heading:
    sys.exit(0)
# Draw only when this turn touched a Pilot lane or the reply has its own
# cockpit heading or rows. The rows filled in above complete a card that is
# shown anyway; on their own (a turn that only ran `ls`) they are noise.
if not (marks or heading or own_rows):
    sys.exit(0)


# --- draw --------------------------------------------------------------------
def paint(text, code):
    if use_color and code and text:
        return "\x1b[" + code + "m" + text + "\x1b[0m"
    return text


def fit(segments, width):
    """segments: list of (text, colour). Cut to `width` visible columns with a trailing ellipsis."""
    total = sum(len(t) for t, _ in segments)
    if total <= width:
        return segments, total
    out, used = [], 0
    for text, code in segments:
        room = width - 1 - used
        if room <= 0:
            break
        if len(text) <= room:
            out.append((text, code))
            used += len(text)
        else:
            cut = text[:room]
            if cut.count("`") % 2:
                # The cut fell inside a `code span`: drop its opening mark so
                # no stray backtick is left before the ellipsis.
                mark = cut.rfind("`")
                cut = cut[:mark] + cut[mark + 1:]
            out.append((cut, code))
            used += len(cut)
            break
    out.append(("…", None))
    return out, used + 1


def row(label, value_segments):
    inner = WIDTH - 4
    value_width = inner - 7
    segments, used = fit(value_segments, value_width)
    body = paint(label.ljust(5), ICE) + "  " + "".join(paint(t, c) for t, c in segments)
    body += " " * (value_width - used)
    return paint("|", ICE) + " " + body + " " + paint("|", ICE)


left_plain = "+ PILOT | " + phase + " "
if status:
    right_plain = " " + status + " +"
else:
    right_plain = "+"
dashes = "-" * max(3, WIDTH - len(left_plain) - len(right_plain))
header = (
    paint("+ ", ICE) + paint("PILOT", GREEN) + paint(" | ", ICE) + paint(phase, GREEN) + paint(" " + dashes, ICE)
)
if status:
    header += paint(" ", ICE) + paint(status, status_color) + paint(" +", ICE)
else:
    header += paint("+", ICE)

tail = " " + FOOTER_TEXT + " --+"
footer = paint("+" + "-" * (WIDTH - 1 - len(tail)) + tail, ICE)

card = [header]
if goal:
    card.append(row("Goal", [(goal, None)]))
if marks:
    for gap in ("  ", " "):
        segments = []
        for lane in LANE_ORDER:
            mark = marks.get(lane)
            if not mark:
                continue
            if segments:
                segments.append((gap, None))
            segments.append((lane + " ", None))
            if mark == "ran":
                segments.append(("✓", GREEN))
            else:
                segments.append((mark, AMBER if mark == "asks" else RED))
        if sum(len(t) for t, _ in segments) <= WIDTH - 11:
            break
    card.append(row("Lanes", segments))
if nxt:
    card.append(row("Next", [(nxt, None)]))
card.append(footer)

sys.stdout.write(json.dumps({"systemMessage": "\n" + "\n".join(card)}))
CARDEOF

exit 0
