---
description: Assess a transcript, report, or session artifact read-only. Harvest-to-memory is deferred.
argument-hint: <transcript-or-report>
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
  - /pilot-harvest
  - Pilot slash command
  - Claude Pilot adapter
---

# /confighub-pilot:pilot-harvest

Read a session artifact and classify it read-only.

## What this command does

Use the shipped read-only assessment front door on a transcript or report:

```bash
pilot assess <transcript-or-report> --json
```

`assess` classifies the artifact and names the safe next step without writing
to any memory store or uploading anything.

If the assessment produces a typed lesson candidate, use the review-first
learning path:

```bash
pilot learn validate <packet.json> --progress-card
pilot learn stage <packet.json> --out-dir <dir> --progress-card
```

## What the user will see

- A read-only classification of the artifact.
- Proof gaps and the first safe next command.

## Rules

- Read-only. No memory write, no index build, no upload from this surface.

> Deferred: automatic harvest-into-memory is not shipped in this portable repo.
> The shipped path is assessment first, then `pilot learn` for typed,
> reviewable corpus-promotion packets.
