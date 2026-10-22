#!/usr/bin/env bash
#
# Switch Pilot on or off for one Claude session (#1146).
#
# UserPromptSubmit: acts only when the whole prompt, trimmed, is exactly one of
#   /confighub-pilot:on      switch Pilot on for this session
#   /confighub-pilot:off     switch Pilot off for this session
#   /confighub-pilot:status  report whether Pilot is on for this session
# The switch is a file named after the session ID under
# ${PILOT_USER_HOME:-$HOME/.pilot}/claude/active-sessions/. Every other Pilot
# hook treats a session with that file as active.
#
# Only a person can reach this path. When the model triggers a plugin command
# through its Skill tool, Claude Code runs the command without firing
# UserPromptSubmit, so the switch never changes (verified on Claude Code
# 2.1.227). Task notifications do fire UserPromptSubmit, but their text never
# equals a command exactly.
#
# PreToolUse(Bash): while Pilot is active for the session, refuse a Bash command
# that names the switch directory. This guards against accidentally switching
# Pilot off through the shell. It is not a sandbox: a program running as the
# same user can still reach the same files.
#
# Any other input: exit 0 with no output and no file changes.

set -euo pipefail

# Cheap shell-only filter so sessions that never use Pilot pay no Python start
# and write nothing. The Python below re-checks everything exactly; this only
# skips input that cannot matter.
pilot_hook_input="$(cat)"
case "$pilot_hook_input" in
    *'/confighub-pilot:'*) ;;
    *active-sessions*)
        if [[ "${PILOT_ACTIVE:-0}" != "1" ]]; then
            compgen -G "${PILOT_USER_HOME:-${HOME:-}/.pilot}/claude/active-sessions/*" >/dev/null 2>&1 || exit 0
        fi
        ;;
    *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || exit 0

PILOT_SESSION_SWITCH_PY='
import json
import os
import pathlib
import re
import shutil
import sys
import time

COMMANDS = {
    "/confighub-pilot:on": "on",
    "/confighub-pilot:off": "off",
    "/confighub-pilot:status": "status",
}
SESSION_ID = re.compile(r"[A-Za-z0-9-]{8,128}")
STALE_SECONDS = 14 * 24 * 60 * 60

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not isinstance(data, dict):
    sys.exit(0)

session_id = data.get("session_id")
if not isinstance(session_id, str) or not SESSION_ID.fullmatch(session_id):
    sys.exit(0)

user_home = os.environ.get("PILOT_USER_HOME") or os.path.join(os.path.expanduser("~"), ".pilot")
switch_dir = pathlib.Path(user_home) / "claude" / "active-sessions"
marker = switch_dir / session_id
event = data.get("hook_event_name")


def report(message):
    json.dump(
        {
            "systemMessage": message,
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": "Pilot session switch result: " + message,
            },
        },
        sys.stdout,
    )
    sys.stdout.write("\n")


def valid_core_root(candidate):
    try:
        path = pathlib.Path(candidate)
        if path.is_symlink():
            return None
        root = path.resolve(strict=True)
    except (OSError, TypeError, ValueError):
        return None
    if (root / "scripts" / "pilot").is_file() and (root / "pilot" / "package-manifest.json").is_file():
        return root
    return None


def resolve_core_root():
    # An installer-staged plugin receives PILOT_ROOT on every hook command. A
    # plugin added from a marketplace does not, so fall back to the installed
    # `pilot` console: its data root is <prefix>/share/confighub-pilot beside
    # the Python environment that installed it.
    for key in ("PILOT_ROOT", "PILOT_HOME"):
        value = os.environ.get(key)
        if value:
            root = valid_core_root(value)
            if root is not None:
                return root
    executable = shutil.which("pilot")
    if executable:
        try:
            console = pathlib.Path(executable).resolve(strict=True)
        except OSError:
            return None
        return valid_core_root(console.parent.parent / "share" / "confighub-pilot")
    return None


if event == "UserPromptSubmit":
    prompt = data.get("prompt")
    if not isinstance(prompt, str):
        sys.exit(0)
    action = COMMANDS.get(prompt.strip())
    if action is None:
        sys.exit(0)
    globally_on = os.environ.get("PILOT_ACTIVE") == "1"
    if action == "status":
        if globally_on:
            report("Pilot is on for every session on this machine, because PILOT_ACTIVE is 1 in the Claude settings.")
        elif marker.is_file():
            report("Pilot is on for this session. Type /confighub-pilot:off to switch it off.")
        else:
            report("Pilot is off for this session. Type /confighub-pilot:on to switch it on.")
        sys.exit(0)
    if action == "on":
        core_root = resolve_core_root()
        if core_root is None:
            report(
                "Pilot was not switched on: the Pilot command-line tool is not installed. "
                "Install it by following CLAUDE_START.md in the Pilot repository, then type /confighub-pilot:on again."
            )
            sys.exit(0)
        switch_dir.mkdir(parents=True, exist_ok=True)
        os.chmod(switch_dir, 0o700)
        now = time.time()
        for old in switch_dir.iterdir():
            try:
                if old.is_file() and now - old.stat().st_mtime > STALE_SECONDS:
                    old.unlink()
            except OSError:
                pass
        payload = {
            "session_id": session_id,
            "switched_on_at": int(now),
            "cwd": str(data.get("cwd") or ""),
            "pilot_root": str(core_root),
        }
        tmp = switch_dir / (session_id + ".tmp")
        tmp.write_text(json.dumps(payload) + "\n", encoding="utf-8")
        os.chmod(tmp, 0o600)
        os.replace(tmp, marker)
        if globally_on:
            report("Pilot is on for this session. It was already on for every session, because PILOT_ACTIVE is 1 in the Claude settings.")
        else:
            report("Pilot is on for this session only. Other sessions are not affected. Type /confighub-pilot:off to switch it off.")
        sys.exit(0)
    if action == "off":
        try:
            marker.unlink()
        except FileNotFoundError:
            pass
        if globally_on:
            report("Pilot stays on: it is on for every session, because PILOT_ACTIVE is 1 in the Claude settings. Remove that setting to use per-session switching.")
        else:
            report("Pilot is off for this session.")
        sys.exit(0)
    sys.exit(0)

if event == "PreToolUse":
    if data.get("tool_name") != "Bash":
        sys.exit(0)
    if not (os.environ.get("PILOT_ACTIVE") == "1" or marker.is_file()):
        sys.exit(0)
    tool_input = data.get("tool_input")
    command = tool_input.get("command") if isinstance(tool_input, dict) else None
    if not isinstance(command, str) or "active-sessions" not in command:
        sys.exit(0)
    reason = (
        "PILOT_SESSION_SWITCH_PROTECTED: this command names the Pilot session switch directory. "
        "Only the person using this session can switch Pilot, by typing /confighub-pilot:off."
    )
    json.dump(
        {"hookSpecificOutput": {"hookEventName": "PreToolUse", "decision": "block", "reason": reason}},
        sys.stdout,
    )
    sys.stdout.write("\n")
    sys.stderr.write(reason + "\n")
    sys.exit(2)

sys.exit(0)
'

printf '%s' "$pilot_hook_input" | PYTHONDONTWRITEBYTECODE=1 python3 -c "$PILOT_SESSION_SWITCH_PY"
