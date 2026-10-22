---
description: Close a run, review its lesson, rerun the same job, and measure whether Pilot improved.
argument-hint: "[status|fixtures|from-closeout <closeout.json>|validate <packet.json>|stage <packet.json>|recheck <application.json>|measure-rerun ...] [--progress-card|--json]"
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
  - /pilot-learn
  - Pilot slash command
  - Claude Pilot adapter
---

# /confighub-pilot:pilot-learn

Learning is review-first in this portable repo.

## What this command does

Use the shipped learning front door:

```bash
pilot learn
pilot learn from-closeout <closeout.json> --out <packet.json> --progress-card
pilot learn validate <packet.json> --progress-card
pilot learn stage <packet.json> --out-dir <dir> --progress-card
pilot learn recheck <promotion-application.json> \
  --review-record <review.json> --entries-dir <dir> --progress-card
pilot learn measure-rerun --before <before-closeout.json> \
  --after <after-closeout.json> --retrieval <retrieval.json> \
  --out <rerun.json> --progress-card
```

`pilot learn` connects a completed run back to the job that produced it. It can
record a lesson candidate or `NO_NEW_LESSONS`, stage review material in a
directory the user names, prove a human accepted and merged the lesson, recheck
that the active corpus retrieves it, and compare a rerun of the same task and
proof criteria.

The closeout has two explicit branches:

- **Reusable lesson:** the closeout sets `lesson_disposition` to `candidate`.
  `from-closeout` creates the typed packet; `stage` prepares review material;
  after human review and merge, `recheck` proves active retrieval and
  `measure-rerun` compares the originating route again.
- **Nothing reusable:** the closeout sets `lesson_disposition` to
  `NO_NEW_LESSONS`. `from-closeout` creates a typed no-lesson packet with no
  promotion targets. Keep it with the run receipt; do not stage a corpus
  change.

Historical `on`, `harvest`, and `pr` subcommands are not part of this installed
front door. `from-closeout` replaces the old harvest step, and `stage` replaces
the old PR-preparation step without opening or approving a PR automatically.

Use the Progress Card for the human-facing route. Use `--json` or
`--progress-card-json` when another agent, test, or review script needs the
machine receipt.

For read-only assessment of a transcript or report before a lesson packet
exists, use:

```bash
pilot assess <transcript-or-report> --json
```

## Rules

- Review-first. `stage` writes only to the explicit output directory.
- Do not claim Pilot learned a lesson from validation alone.
- Do not claim Pilot learned a lesson from a staged bundle alone.
- A learned claim requires a human review record, reviewed merge, and `pilot
  learn recheck ...` against the active owner.
- An improvement claim requires `pilot learn measure-rerun ...` to confirm the
  same route, scenario, task, scope, inputs, and proof criteria.
- This surface does not upload memory, read private chat logs, or open a PR by
  itself.
