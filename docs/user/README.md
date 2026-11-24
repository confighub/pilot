# ConfigHub Pilot User Guides

Welcome to the ConfigHub Pilot documentation for version `0.7.2`.
Every guide here is written for operators, platform engineers, and teams
evaluating or running Pilot.

Back to the [main README](../../README.md).

## Start here & install

- [Install Pilot](INSTALL_PILOT.md) — All four install routes (`cub` plugin, Claude Code terminal, Claude Desktop Code tab, plain `pipx`), verification, upgrade, and uninstall.
- [What is Pilot](WHAT_IS_PILOT.md) — Plain-English product promise, what Pilot does for ConfigHub, and its honest current boundary.
- [What is a governed agent for configuration](WHAT_IS_A_GOVERNED_AGENT.md) — Why configuration operations need an operational harness rather than a bare chat prompt.
- [First-run walkthrough](PORTABLE_FIRST_RUN_WALKTHROUGH.md) — One guided walkthrough (5, 20, or 45 minutes) across Pilot's journeys.
- [What you will see](WHAT_YOU_WILL_SEE.md) — Real examples of Pilot's progress cards, approval stops, and verification receipts.
- [Troubleshooting & FAQ](TROUBLESHOOTING.md) — Quick fixes for SSH/HTTPS marketplace errors, `pipx`/Python versions, Claude hooks, status line, and corpus rollbacks.

## How Pilot works & daily use

- [How Pilot works](HOW_PILOT_WORKS.md) — The six parts Pilot is built from, the route-gate-prove loop, and what breaks when any part is removed.
- [How Pilot talks to you](HOW_PILOT_TALKS_TO_YOU.md) — Calm progress cards vs full cockpit vs engineer details, and how to switch views in ordinary English.
- [Safe actions](PILOT_SAFE_ACTIONS.md) — Exact boundaries between automatic read-only inspection, asked mutations, and hard-stopped destructive commands.
- [First live win](PILOT_FIRST_LIVE_WIN.md) — End-to-end local Kubernetes walkthrough with ConfigHub, Argo CD, and verified delivery proof.
- [What can I do today](WHAT_CAN_I_DO_TODAY.md) — Honest inventory of what is proven today vs what is still in progress.

## New to Argo CD, Flux, or Sveltos

Start read-only — no ConfigHub account required for the first-look guides:

- [Argo first look](ARGO_FIRST_LOOK.md) — Inspect an existing Argo CD repo read-only and learn how Pilot maps it.
- [Flux first look](FLUX_FIRST_LOOK.md) — Inspect an existing Flux repo read-only and see the safe next step.
- [Practice repos](PRACTICE_REPOS.md) — Safe public example repositories you can run Pilot against right away.
- [Test environments and sandboxes](TEST_ENVIRONMENTS_AND_SANDBOXES.md) — Local `kind` clusters and disposable practice setups.
- [Argo onboarding](ARGO_ONBOARDING.md) — Moving an existing Argo CD estate onto ConfigHub step by step.
- [Flux onboarding](FLUX_ONBOARDING.md) — Moving an existing Flux estate onto ConfigHub step by step.
- [Sveltos onboarding](SVELTOS_ONBOARDING.md) — Working with Sveltos multi-cluster fleets alongside ConfigHub.

## Enterprise PoC & fleet planning

- [Plan your estate layout](PLAN_YOUR_ESTATE_LAYOUT.md) — Designing ConfigHub Spaces, Units, Targets, and environments for real teams.
- [Deep analysis](DEEP_ANALYSIS.md) — Structured read-only fleet and repo analysis before proposing changes.
- [Staged rollouts](STAGED_ROLLOUTS.md) — Ring-based promotions and vulnerability fixes with explicit gates and budgets.
- [Work plan compare](WORK_PLAN_COMPARE.md) — Weighing two or three alternative rollout or migration plans read-only before choosing one.

## Power layers & staying current

- [ConfigHub functions](PILOT_FUNCTIONS.md) — Using typed ConfigHub mutation and validation functions through Pilot.
- [Corpus updates](CORPUS_UPDATES.md) — Checking, updating, and rolling back signed Pilot lesson packs between binary releases.
- [Using Pilot with other models](PILOT_WITH_OTHER_MODELS.md) — Codex and alternative model support, and how safety boundaries differ by host.

## Release notes

- [What's new in v0.7.2](WHATS_NEW_v0.7.2.md)
- [What's new in v0.7.1](WHATS_NEW_v0.7.1.md)
- [What's new in v0.7.0](WHATS_NEW_v0.7.0.md)
- [What's new in v0.6.1](WHATS_NEW_v0.6.1.md)
- [What's new in v0.6.0](WHATS_NEW_v0.6.0.md)
