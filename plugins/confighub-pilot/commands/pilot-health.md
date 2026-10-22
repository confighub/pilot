---
description: 'Read-only Pilot health assessment for a repo, cluster URL, or session.'
argument-hint: "[cluster-context] [namespace]"
allowed-tools: [Bash, Read]
shelf: command-prompt
status: current
owner: pilot
portable: true
package: pilot-adapter
used_by:
  - scripts/pilot-claude-adapter
enforced_by:
  - scripts/pilot claude smoke --validate-claude --json
  - scripts/pilot release-gate --json
retrieval_triggers:
  - /pilot-health
  - Pilot slash command
  - Claude Pilot adapter
---

# /confighub-pilot:pilot-health

Assess health read-only. Never repair from a snapshot.

## What this command does

Use the shipped read-only assessment front doors:

```bash
pilot assess <repo-or-path> --json
pilot map <cluster-url> --json
```

`assess` classifies a repo, session, or named context read-only; `map` renders
the Day-0 cockpit for a repo, manifest, chart, controller file, or ConfigHub
URL, including proof gaps.

## What the user will see

- Local access classification, controller/workload signals where available.
- Ownership and ConfigHub proof gaps.
- The first safe next command; no mutation is proposed from a read-only pass.

## Rules

- Read-only only. Separate local-access failure from cluster health and app
  health.
- Do not repair from an assessment. Gather approval and proof before mutation.

> Deferred: the dedicated cluster health-snapshot helper
> (`pilot-health-snapshot`) is not shipped in this portable repo. This surface
> uses the read-only front doors above until a snapshot helper is reinstated.
