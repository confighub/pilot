<!--
---
shelf: product-doctrine
status: current
audience: users
owner: pilot
portable: true
package: pilot-corpus
used_by:
  - README.md
  - docs/user/README.md
  - docs/user/WHAT_IS_PILOT.md
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tools/audits/audit-md-corpus-shelves
  - tools/audits/audit-pilot-package-manifest
retrieval_triggers:
  - what is a governed agent
  - governed agent for configuration
  - safe AI agent for infrastructure
  - AI agent that asks before it changes
  - category
---
-->

# What Is A Governed Agent For Configuration?

Pilot is a governed agent for configuration. This page explains what that kind
of tool is, so you can decide whether you want one before you install
anything.

## The problem

The settings that decide how your software runs are spread across repos, YAML
files, clusters and dashboards, and almost nobody can see the whole picture at
once. An AI assistant is very good at reading all of that and suggesting a
change, and it is also very good at sounding sure when it is wrong. So the
hard part is not getting a suggestion; the hard part is knowing whether the
change was allowed, whether it was the right one, and whether it actually
happened.

## What this kind of tool does

A governed agent for configuration sits between you and your systems and does
four things every time:

- **Looks first.** It reads the repo, the cluster or the config store and says
  what it found, before it proposes anything.
- **Picks a known job.** Your request in plain English is matched to a
  worked-out job with steps, checks and stop rules, instead of being answered
  by a fresh guess.
- **Asks before it changes anything.** It shows you the exact change and waits
  for a yes.
- **Checks afterwards and keeps the note.** It reads back what really
  happened and saves a record anyone can look at later.

## What makes it safe

- **Read-only by default.** Nothing is written until you choose a route that
  writes.
- **Approval, not permission-by-accident.** Every step is sorted into
  read-only, a proposal you can review, one exact command your assistant must
  allow or deny, or blocked outright. You see which one it is before it runs.
- **Deterministic guards.** The rules that decide read-only, proposal, ask or
  blocked are plain code with tests, not a paragraph of instructions the model
  is asked to please follow.
- **Receipts.** Every run saves what was checked, what happened and what is
  still unproven, so somebody who was not in the room can check the work.
- **Permission is not proof.** Being allowed to try is not the same as it
  having worked, so the result is read back rather than assumed.

## How this differs from a chat assistant with shell access

A chat assistant with shell access can already run commands for you, and often
that works. The differences are about what happens when it does not:

- A chat assistant asks you to approve a command. A governed agent tells you
  what that command is for, what it will touch, and what it will check
  afterwards.
- A chat assistant reports the exit code. A governed agent reads the system
  again and tells you whether the thing you wanted is actually true now.
- A chat assistant leaves a conversation. A governed agent leaves a record
  that is the same shape every time, so a colleague can verify it without
  reading the chat.
- A chat assistant improvises each time. A governed agent routes to a job that
  somebody already worked out and tested, and says so plainly when no job
  fits.

None of this makes the assistant less clever. The thinking is still the
model's. What is added is the knowledge of the jobs, the rails that keep the
work in bounds, and the memory of what was already solved.

## Where Pilot fits with ConfigHub, Argo CD and Flux

These are not competitors of each other, and Pilot does not replace any of
them:

- **ConfigHub** is the system of record for configuration. Your config lives
  there as versioned data you can query, and changes to it are governed.
  ConfigHub answers "what is the configuration, and who changed it".
- **Argo CD and Flux** are delivery controllers. They take what is in Git or
  an OCI registry and make the cluster match it. They answer "did the declared
  state reach the cluster".
- **Pilot** is the agent on top. It reads your estate, chooses the job, shows
  you the exact change, waits for your yes, and then checks the result and
  writes the receipt. It answers "what should I do next, and did it really
  work".

Pilot reads Argo CD and Flux repositories read-only today and can name their
shape. For an Argo CD app of apps it also prints a read-only plan to bring it
under ConfigHub. It does not take over delivery.

## What is not built yet

Pilot runs on your laptop, or inside a Claude Code or Codex session. Running
Pilot itself inside a cluster is planned, not shipped. The strongest governed
delivery path, where an outside verifier proves that a named human approved a
change, is not integrated yet, so Pilot stops at that boundary and says so
instead of pretending.

Next: [`WHAT_IS_PILOT.md`](WHAT_IS_PILOT.md) for the product itself, or
[`INSTALL_PILOT.md`](INSTALL_PILOT.md) to install it and try it.
