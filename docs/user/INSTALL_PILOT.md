---
shelf: product-doctrine
status: current
audience: users
owner: pilot
portable: true
package: pilot-corpus
used_by:
  - docs/user/README.md
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tools/audits/audit-pilot-package-manifest
  - tests/test-pilot-doc-reference-integrity
  - tools/audits/audit-md-corpus-shelves
  - tests/test-pilot-public-channel
retrieval_triggers:
  - install Pilot
  - how do I install Pilot
  - cub plugin install
  - claude plugin marketplace
  - pipx install
  - Claude Desktop
  - Cowork
---

# Install Pilot

Pilot is a safety layer for AI-assisted ConfigHub work. It runs inside a Claude
session, shows what it is about to do, stops and asks before it changes
anything, and checks the result afterwards.

## Pick the route you already use

| You use | You type | Where |
|---|---|---|
| `cub` | `cub plugin install confighub/pilot`, then `cub pilot install` | Your terminal |
| Claude Code in a terminal | `/plugin marketplace add confighub/pilot`, then `/plugin install confighub-pilot@confighub-pilot` | Inside Claude Code |
| Claude Desktop, Code tab | **+**, then Add plugins, then the marketplace `confighub/pilot` | The Claude Desktop app |
| Plain Python | `pipx install <wheel URL>`, then `pilot claude install` | Your terminal |

Not supported: the Claude Desktop **chat** window. Cowork is not confirmed yet.
Both are explained [below](#where-pilot-does-not-work-yet).

Every route installs the same Pilot. You can switch routes later.

## Route 1: you use `cub`

Run each command in your own terminal.

```text
cub plugin install confighub/pilot
cub pilot install
```

What this sets up:

1. `cub plugin install` adds a small launcher so that `cub pilot ...` works.
   `cub` does not check what it downloads, so the launcher does that part
   itself in the next step.
2. `cub pilot install` needs Python 3.10 or newer. It looks for `python3.13`,
   `python3.12`, `python3.11`, `python3.10`, then `python3`, and uses the first
   one that is new enough. On a Mac the built-in `python3` is often 3.9, which
   is too old; install a newer one (`brew install python`, or from
   [python.org](https://www.python.org/downloads/)) and run it again. To pick
   one yourself, set `PILOT_PYTHON=/path/to/python3`. Then it downloads one
   Pilot file (a `.whl` file) from the
   release page, and checks it against a checksum (a fingerprint of the file)
   that was written into the launcher when it was built. If they differ, it
   stops and installs nothing. Then it installs Pilot into its own folder at
   `~/.confighub/pilot`, so it cannot disturb your other Python tools.
3. It puts a `pilot` shortcut in `~/.local/bin`. If that folder is not on your
   PATH, the installer says so and shows the line to add.
4. If Claude Code is on your machine, it adds the Pilot plugin
   (`claude plugin marketplace add confighub/pilot` and
   `claude plugin install confighub-pilot@confighub-pilot`) and adds Pilot's
   status line to `~/.claude/settings.json` (or the folder named by
   `CLAUDE_CONFIG_DIR`). The status line shows only in sessions where you type
   `/confighub-pilot:on`. If you already have a status line of your own, it is
   left as it is and the installer prints the one line to add Pilot's. If
   Claude Code is not found, it prints the two `/plugin` commands for you to
   type later.
5. It runs `pilot --version` (or `pilot doctor` when your Pilot has it) so you
   see that it worked.

It does not use `sudo`, does not ask for a password or a key, and downloads
only that one Pilot file.

## Route 2: Claude Code in a terminal

Inside Claude Code, type:

```text
/plugin marketplace add confighub/pilot
/plugin install confighub-pilot@confighub-pilot
```

A marketplace is Claude's name for a list of plugins. This adds the Pilot list,
then installs the Pilot plugin from it.

The plugin does not install the `pilot` command by itself. If the command is
missing, the next Claude Code session shows one line:

> Pilot's command-line tool is not installed. Install it with
> `cub plugin install confighub/pilot` then `cub pilot install`, or
> `pipx install <wheel URL>`.

Follow it with Route 1 or Route 4. Nothing is installed for you.

If you have no GitHub SSH key and the marketplace cannot be added, run this in
your terminal first, then start Claude Code again:

```text
export CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1
```

## Route 3: Claude Desktop, Code tab

In the Claude Desktop app, open the Code tab, choose **+**, then **Add
plugins**, and add the marketplace `confighub/pilot`. Then install the
`confighub-pilot` plugin from it. This is the same plugin and the same hooks as
Route 2.

You also need the `pilot` command on your machine. Use Route 1 or Route 4 in a
terminal for that.

This route is checked by hand in the app, not by an automatic test.

## Route 4: plain Python

If you use neither `cub` nor a plugin route, install the Pilot file with
`pipx`. Take the file address from the latest release on
[the release page](https://github.com/confighub/pilot/releases), for example:

```text
pipx install https://github.com/confighub/pilot/releases/download/v0.7.0/confighub_pilot-0.7.0-py3-none-any.whl
pilot claude install --global --session-scoped
```

Compare the file with `SHA256SUMS` on the release page before you install it.
This route does not check the file for you.

## Check that it worked

```text
pilot --version
```

It prints the Pilot version. Then open Claude Code and type:

```text
/confighub-pilot:on
```

Pilot stays quiet in every session until you do this. When it is on, the status
line at the bottom of Claude Code shows Pilot. `/confighub-pilot:off` switches
it off again for that session. If you used Route 1, `cub pilot doctor` also
lists what is in place and what is missing.

## Upgrade

```text
cub plugin upgrade pilot
cub pilot upgrade
```

The first command fetches the newest launcher. The second installs the Pilot
version that launcher is built for, and checks it the same way as before. If
you used Route 4, run `pipx install --force <new wheel URL>`.

## Uninstall

```text
cub pilot uninstall
```

This removes Pilot's status line (only Pilot's; a status line of your own stays), the Pilot folder, the `pilot` shortcut and the Claude plugin. It
keeps your Pilot notes and history in `~/.pilot`; delete that folder yourself
if you want them gone. Then run `cub plugin uninstall pilot` to remove the
launcher. If you used Route 4, run `pipx uninstall confighub-pilot`.

## Where Pilot does not work yet

- **Claude Desktop chat.** The chat window ignores plugin hooks, and Pilot's
  approval guard is a hook. Without it Pilot cannot stop a change before it
  happens, so we do not support chat. Use the Code tab.
- **Claude Desktop Cowork.** Cowork loads plugin hooks, but it is not stated
  whether they run on your machine. We are checking, and this page will say
  "supported" or name the gap when we know.

## Licence

Pilot is distributed under the ConfigHub Evaluation License. The text is in
`EVALUATION-LICENSE.txt` in the Pilot repository and in the Pilot download.
