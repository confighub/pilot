---
description: Ask Pilot's step router to classify a symptom, intent, or mid-run decision before acting.
argument-hint: "<intent or evidence>"
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
  - /pilot-route
  - Pilot slash command
  - Claude Pilot adapter
---

# /confighub-pilot:pilot-route

Route before classifying or acting.

## What this command does

Run the step router with the user's evidence:

```bash
pilot route \
  --intent "<intent>" \
  --phase decide \
  --text "<symptom or evidence>" \
  --json
```

If the phase is obvious, use the exact phase:

```text
understand | decide | act | verify | close | harvest
```

## What the user will see

- Decision: `ALLOW`, `BLOCK`, `ASK`, or `READ_MORE`.
- Scenario and best place to start.
- First route and blocked actions.
- Solution matches when available.

## Rules

- Use this before controller/source failure classification, fallback action,
  approval scope changes, or closeout.
- Current operating truth and failure-class routers outrank old reports.
- A route decision is not proof and not approval.
