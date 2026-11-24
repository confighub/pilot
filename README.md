# ConfigHub Pilot

Pilot is a safety layer for AI-assisted ConfigHub work. It sits inside a Claude
session, shows what it is about to do and why, stops and asks before it
changes anything, and checks the result afterwards.

This repository holds only what you need to install Pilot: the Claude plugin,
the `cub` plugin and the release files. The version here is 0.7.2.

## Pick the route you already use

| You use | You type | What happens |
|---|---|---|
| `cub` | `cub plugin install confighub/pilot`, then `cub pilot install` | Installs Pilot into its own Python environment after checking the download against a published checksum. Adds the Claude plugin if Claude Code is on the machine, sets up the status line, then checks the result. |
| Claude Code in a terminal | `/plugin marketplace add confighub/pilot`, then `/plugin install confighub-pilot@confighub-pilot` | Adds the plugin. If the `pilot` command is missing, the plugin shows one line telling you how to install it. It installs nothing by itself. |
| Claude Desktop, Code tab | **+**, then Add plugins, then marketplace `confighub/pilot` | The same plugin as the terminal route. |
| Plain Python | `pipx install https://github.com/confighub/pilot/releases/download/v0.7.2/confighub_pilot-0.7.2-py3-none-any.whl`, then `pilot claude install --global --session-scoped` | The fallback if you use neither `cub` nor the plugin routes. Check the file against `SHA256SUMS` on the release page first. |

Not supported: the Claude Desktop **chat** window. It does not run plugin hooks,
and Pilot's approval guard is a hook, so Pilot cannot protect you there. Use the
Code tab. Pilot does not support Claude Desktop **Cowork** yet; support is
planned for a later release. For now, use the Code tab or the terminal.

If you have no GitHub SSH key and Claude cannot add the marketplace, run
`export CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1` and try again.

Every route, what each one does and how to remove Pilot are in
[docs/user/INSTALL_PILOT.md](docs/user/INSTALL_PILOT.md). Browse the complete
[user guide index](docs/user/README.md) or jump straight in by role below.

## Start by role

Pick the path that matches what you came here to do:

- **New to Pilot or ConfigHub?**
  [What is Pilot](docs/user/WHAT_IS_PILOT.md),
  [What is a governed agent for configuration](docs/user/WHAT_IS_A_GOVERNED_AGENT.md),
  [What's new in v0.7.2](docs/user/WHATS_NEW_v0.7.2.md),
  [First-run walkthrough](docs/user/PORTABLE_FIRST_RUN_WALKTHROUGH.md), or
  [What you will see](docs/user/WHAT_YOU_WILL_SEE.md).
- **Evaluating how Pilot works and its safety boundaries?**
  [How Pilot works](docs/user/HOW_PILOT_WORKS.md),
  [How Pilot talks to you](docs/user/HOW_PILOT_TALKS_TO_YOU.md),
  [Safe actions](docs/user/PILOT_SAFE_ACTIONS.md),
  [First live win](docs/user/PILOT_FIRST_LIVE_WIN.md), or
  [Troubleshooting & FAQ](docs/user/TROUBLESHOOTING.md).
- **New to Argo CD or Flux?** Start read-only without a ConfigHub account:
  [Argo first look](docs/user/ARGO_FIRST_LOOK.md),
  [Flux first look](docs/user/FLUX_FIRST_LOOK.md),
  [Practice repos](docs/user/PRACTICE_REPOS.md), or
  [Test environments and sandboxes](docs/user/TEST_ENVIRONMENTS_AND_SANDBOXES.md).
- **Planning an enterprise PoC or fleet adoption?**
  [Plan your estate layout](docs/user/PLAN_YOUR_ESTATE_LAYOUT.md),
  [Deep analysis](docs/user/DEEP_ANALYSIS.md),
  [Staged rollouts](docs/user/STAGED_ROLLOUTS.md),
  [Work plan compare](docs/user/WORK_PLAN_COMPARE.md),
  [Argo onboarding](docs/user/ARGO_ONBOARDING.md),
  [Flux onboarding](docs/user/FLUX_ONBOARDING.md), and
  [Sveltos onboarding](docs/user/SVELTOS_ONBOARDING.md).
- **Staying current, power layers, and honest limits:**
  [Corpus updates](docs/user/CORPUS_UPDATES.md),
  [ConfigHub functions](docs/user/PILOT_FUNCTIONS.md),
  [Using Pilot with other models](docs/user/PILOT_WITH_OTHER_MODELS.md), and
  [What can I do today](docs/user/WHAT_CAN_I_DO_TODAY.md).

## Check that it worked

```bash
pilot --version
pilot quickstart --progress-card
```

Neither command touches a live cluster or ConfigHub. You should see `pilot 0.7.2`
and a calm Progress Card like this:

```text
Pilot progress - First run                          Safe first step selected

Proven
+ Pilot is installed and can choose a first route.
+ No ConfigHub, Git, Kubernetes, controller, or external write was allowed.

Do this next
> Move to the repo or folder you want Pilot to inspect. Then run: pilot map .
```

Then, in Claude Code, type `/confighub-pilot:on`. Pilot stays quiet in every
session until you do. The status line shows that Pilot is on. If anything gets
stuck, see [docs/user/TROUBLESHOOTING.md](docs/user/TROUBLESHOOTING.md).

## Upgrade and uninstall

```text
cub plugin upgrade pilot
cub pilot upgrade
cub pilot uninstall
```

## Licence

Pilot is distributed under the ConfigHub Evaluation License. See
[EVALUATION-LICENSE.txt](EVALUATION-LICENSE.txt).
