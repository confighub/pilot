# ConfigHub Pilot

Pilot is a safety layer for AI-assisted ConfigHub work. It sits inside a Claude
session, shows what it is about to do and why, stops and asks before it
changes anything, and checks the result afterwards.

This repository holds only what you need to install Pilot: the Claude plugin,
the `cub` plugin and the release files. The version here is 0.7.0.

## Pick the route you already use

| You use | You type | What happens |
|---|---|---|
| `cub` | `cub plugin install confighub/pilot`, then `cub pilot install` | Installs Pilot into its own Python environment after checking the download against a published checksum. Adds the Claude plugin if Claude Code is on the machine, sets up the status line, then checks the result. |
| Claude Code in a terminal | `/plugin marketplace add confighub/pilot`, then `/plugin install confighub-pilot@confighub-pilot` | Adds the plugin. If the `pilot` command is missing, the plugin shows one line telling you how to install it. It installs nothing by itself. |
| Claude Desktop, Code tab | **+**, then Add plugins, then marketplace `confighub/pilot` | The same plugin as the terminal route. |
| Plain Python | `pipx install https://github.com/confighub/pilot/releases/download/v0.7.0/confighub_pilot-0.7.0-py3-none-any.whl`, then `pilot claude install --global --session-scoped` | The fallback if you use neither `cub` nor the plugin routes. Check the file against `SHA256SUMS` on the release page first. |

Not supported: the Claude Desktop **chat** window. It does not run plugin hooks,
and Pilot's approval guard is a hook, so Pilot cannot protect you there. Use the
Code tab. Claude Desktop **Cowork** is being checked; this page will say when it
is supported.

If you have no GitHub SSH key and Claude cannot add the marketplace, run
`export CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1` and try again.

Every route, what each one does and how to remove Pilot are in
[docs/user/INSTALL_PILOT.md](docs/user/INSTALL_PILOT.md). The guides that Pilot
points you to are in [docs/user/](docs/user/).

## Check that it worked

```text
pilot --version
```

Then, in Claude Code, type `/confighub-pilot:on`. Pilot stays quiet in every
session until you do. The status line shows that Pilot is on.

## Upgrade and uninstall

```text
cub plugin upgrade pilot
cub pilot upgrade
cub pilot uninstall
```

## Licence

Pilot is distributed under the ConfigHub Evaluation License. See
[EVALUATION-LICENSE.txt](EVALUATION-LICENSE.txt).
