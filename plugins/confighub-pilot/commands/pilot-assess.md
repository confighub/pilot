---
description: Use Pilot to assess a repo, session/report, ConfigHub URL, or named cluster context without mutation.
argument-hint: [repo|session|url|cluster context]
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
  - /pilot-assess
  - Pilot slash command
  - Claude Pilot adapter
---

# /confighub-pilot:pilot-assess

Assess an input and return the safest next action.

## What this command does

Choose the narrowest read-only helper:

```bash
pilot assess --repo <path> --json
pilot assess --session <file> --json
pilot assess --config-url <url> --json
pilot assess --cluster-context <context> --json
```

For repo-first work, continue with the Day-0 map front door:

```bash
pilot map <path-or-url> --json
```

If the person asks what bringing a repository into ConfigHub would create, also run `pilot import <path> --plan` and report its counts of Components, Spaces and Units. If the repository ships its own import script or contract and it differs from Pilot's plan, show both and say plainly that they differ. Do not present either as the one right answer.

For cluster health, use `/confighub-pilot:pilot-health` after the assessment if the user wants
live read-only evidence.

## What the user will see

- Input type and status classification.
- Likely ownership and proof gaps.
- One safe next action.
- Artifact path for the assessment or intake packet.

## Rules

- No import, package activation, AI-variant activation, approval, or live write.
- If the input is ambiguous, inspect read-only first and choose the least
  surprising interpretation.
- Do not claim live health from repo-only evidence.
