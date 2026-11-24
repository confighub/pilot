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
  - v0.7.1
  - v0.7.1-rc.1
  - v0.7.1 final
  - release candidate
  - public install
  - pilot corpus update
  - clearer first answers
---

# What's New In v0.7.1

v0.7.1 makes Pilot easy for anyone to pick up. You can install it from a public
place, it can learn new lessons between releases, and its first answers talk
about your own repository instead of giving a generic reply. This is the
v0.7.1 release; the candidate before it was `v0.7.1-rc.1`.

## Install Pilot without a private invitation

Pilot now has a public home at github.com/confighub/pilot. Pick the route you
already use:

- as a `cub` plugin;
- as a Claude Code plugin;
- as a plugin in the Claude Desktop app's Code tab;
- or as plain Python.

Every route installs the same Pilot, and you can switch later. Pilot is shared
under the ConfigHub Evaluation License. The install page,
[`INSTALL_PILOT.md`](INSTALL_PILOT.md), shows what each route sets up and how to
check it. Every guide Pilot points you to now opens without access to a private
repository.

## New lessons without waiting for a new Pilot

Pilot answers from a set of reviewed lessons. Until now a new lesson meant a
new release. Now:

- `pilot corpus update` looks for a newer set of lessons, called a corpus pack,
  at ghcr.io/confighub/pilot-corpus. It only looks. It shows the exact pack and
  the one command that applies it. Packs are always fetched by their
  fingerprint, so you get the pack you confirmed.
- `pilot corpus use-bundled` takes you back to the lessons that came with your
  Pilot, any time.

Pilot checks every file in a pack against the pack's own list before it uses
it, and keeps what you had if anything does not match. Packs are not signed
yet. Pilot says so plainly and never claims a signature it did not check.

## Works with ConfigHub 0.9.1

Pilot now recognises `cub` v0.9.1 together with ConfigHub server v0.9.1 as a
checked pair. That brings in:

- the new `cub cluster up` options, and a local practice cluster that Pilot sets
  up the current way;
- the new cluster annotation that names where a cluster's Argo Applications
  live, which the delivery trace and the approval checks now read first;
- ConfigHub's built-in change workflows, so Pilot can explain and check a
  workflow the server runs for you.

Commands that delete or detach things still ask first, each with a plain
sentence saying what it would do.

## Clearer first answers

Ask Pilot about a folder and the answer now names your repository and your
delivery tool, Argo CD or Flux, and its example uses what Pilot actually found
there. If you say "my app will not start", Pilot no longer hands you a dead end.
It lists the likely causes, says what evidence would tell them apart, and gives
you one safe, read-only command to run first. If the words do not match
anything it knows, it says so and still suggests a safe next read.

## Cleaner for newcomers

Nothing Pilot shows you points at a private link, and it no longer names the
older ConfigHub companion skills that have been retired. The one companion that
remains is `confighub-lookup`, which looks things up in the installed help and
docs instead of recalling them.

## Since the release candidate

- The help line for `pilot corpus` now uses simple placeholders, so the release
  check accepts it.

## Where Pilot has been, and where it is going

- **Past, v0.7.0:** Pilot worked with current ConfigHub, ran every read without
  asking, asked once before every change, and showed a small cockpit under each
  reply.
- **Now, v0.7.1:** anyone can install Pilot from a public channel, new lessons
  can reach you between releases, Pilot works with ConfigHub 0.9.1, and first
  answers fit your own repository.
- **Next, v0.7.2:** the work carried forward from this release. That is mainly
  carrying a proven rollout across more clusters, handing bounded tasks to an
  agent whose result you can check, and reaching Pilot from one more place
  beyond Claude and Codex. These are still planned, not available.

## Known limits

- Corpus packs are checked file by file but are not signed yet.
- ConfigHub servers newer than v0.9.1 are not yet reviewed; Pilot withholds
  teardown commands for them and says so.
- Pilot is not supported in the Claude Desktop chat window or in Claude Desktop
  Cowork yet. Cowork support is planned for a later release; use the Code tab or
  the terminal.
- Fleet-wide promotion, delegated agent work and a further doorway beyond
  Claude and Codex are still planned, not available.
