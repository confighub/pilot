---
shelf: product-doctrine
status: current
audience: users
owner: pilot
portable: true
package: pilot-corpus
used_by:
  - docs/user/README.md
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tools/audits/audit-pilot-package-manifest
  - tests/test-pilot-doc-reference-integrity
  - tools/audits/audit-md-corpus-shelves
retrieval_triggers:
  - what's new
  - v0.7.0
  - v0.7.0-rc.1
  - v0.7.0 final
  - release candidate
  - pilot cockpit
  - reads run changes ask
---

# What's New In v0.7.0

v0.7.0 catches Pilot up with current ConfigHub and makes a Pilot session easier
to follow. Reads run without a prompt and every change asks you once, with the
exact command. A small coloured cockpit under each reply shows what Pilot is
doing, what it touched and what comes next. The first release candidate is
`v0.7.0-rc.1`.

## Works with current ConfigHub

Pilot recognises `cub` v0.8.30 with ConfigHub server v0.8.29 or v0.8.30. It
knows the newer `cub` nouns (service accounts, channels, commands, review
comments) and treats creating a token or adding a key as handling a secret. An
unknown or mixed pair is still named before any plan is offered.

Approval is now an attestation: ConfigHub removed `cub unit approve`, and Pilot
no longer suggests it. To approve, use `cub variant approve <space>`.

## Reads run, changes ask

Reading never needs your permission. Any change, however it is written, asks
once and shows the exact command. When several commands are joined on one
line, each part is judged and the most serious answer wins, so a change
cannot ride along behind a read. Only four things stop outright: deleting a
Space with everything in it, deleting an organisation, removing a cluster
together with its configuration, and a secret typed into a command.

## The Pilot cockpit

In a Pilot session each reply ends with a short coloured card in Pilot's own
colours, so you can tell Pilot's state apart from the assistant's prose. It
shows the goal, which systems the turn touched (ConfigHub, Git, the cluster,
proof), whether anything needs your approval, and the next step. Say "Pilot,
show me the full cockpit" for more.

The status line now also appears in sessions switched on with
`/confighub-pilot:on`.

## A smaller, sharper companion

The ConfigHub companion skills are now one skill, `confighub-lookup`, which
looks things up in the installed help and docs instead of recalling them. Pilot's
own knowledge covers October's ConfigHub, `cub`, plugins, docs and workshop.

## First use in your own folder

Asked what a folder is, a Pilot session runs `pilot map .` and then
`pilot import . --plan` before reading files by hand. Asked to clean up one
environment, it plans only the Spaces you named and asks before widening.

## Since the release candidate

- A question whose next step only reads, such as planning a fleet layout, now
  says it only reads instead of asking for approval.
- The progress card starts with one plain sentence before the box.
- In a repository Pilot sees as an expert Argo CD or Flux setup, teaching
  points you at the expert guide for your tool, not the beginner tutorial.

## Known limits

- Newer ConfigHub servers than v0.8.30 are not yet reviewed; Pilot withholds
  teardown commands for them and says so.
- Fleet-wide promotion, delegated agent work and a further doorway beyond
  Claude and Codex are still planned, not available.
