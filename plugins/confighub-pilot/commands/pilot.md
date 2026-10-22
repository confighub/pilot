---
description: 'Open the ConfigHub Pilot doorway: current status, first safe use cases, stop signals, and runtime adapter notes. Read-only.'
argument-hint: "(no args)"
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
  - /pilot
  - Pilot slash command
  - Claude Pilot adapter
---

# /confighub-pilot:pilot

Open the compact Pilot doorway.

Natural-language equivalent: ask Claude to `run pilot`. That phrase should load
the Pilot skill and then route to this same doorway unless the surrounding
request names a more specific Pilot helper.

## What this command does

Run:

```bash
pilot doorway
```

Then summarize the result in the default operator shape:

```text
Status: <one-line Pilot readiness>
Safe first move: <one recommended Pilot action>
Stop signals: <what Pilot will not do yet>
Artifact: <doorway.md path>
```

`PILOT_DOORWAY_READY` means this read-only doorway command completed. It is not
a daemon or job-state claim. Say "the doorway command is reachable," not
"Pilot is running" or "Pilot is idle."

## What the user will see

- Current local Pilot memory and test-run counts.
- First use cases: next, assess, route, health, learn, harvest, gate, test.
- Explicit stop signals for activation, issue filing, and live mutation.
- A durable doorway receipt under `reports/pilot-doorway/<run>/`.

## Rules

- No mutation.
- Scope all catalog/count claims to this command's resolved installed-package
  or source-checkout data root; do not blend the two surfaces.
- Do not claim Claude/Codex behavioral parity without a current
  `pilot runtime-parity --json` receipt.
- `/confighub-pilot:pilot-gate` classifies an applicable proposal; it does not universally
  enforce writes or prove an outcome. For a normal bounded ConfigHub change,
  continue through the Pilot skill's interactive path: one named context, one
  literal exact command, the host permission path, then a separate read-only
  verification and receipt. Claude's installed Pilot hook forces `ask`; Codex
  uses its ordinary tool policy and must not claim a separate human click when
  that policy preauthorizes the call. Stronger external attestation remains an
  optional delegated-execution lane, not a prerequisite for ordinary use.
- Do not turn this into a long docs menu.
- Recommend one next Pilot action based on the user's surrounding intent.
- If the user asks for quickstart, read-first exploration, or sandbox proof,
  continue into `/confighub-pilot:pilot-quickstart`.
- If the user asked for a specific repo, cluster, session, or symptom, continue
  into `/confighub-pilot:pilot-ask`, `/confighub-pilot:pilot-assess`, `/confighub-pilot:pilot-health`, `/confighub-pilot:pilot-learn`,
  `/confighub-pilot:pilot-harvest`, or `/confighub-pilot:pilot-route`.
- If the user asks to apply, activate, approve, create, delete, patch, promote,
  or otherwise mutate, continue into `/confighub-pilot:pilot-gate` first.
