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
  - v0.7.2
  - v0.7.2-rc.1
  - release candidate
  - expert guidance
  - signed corpus packs
  - ConfigHub 0.11.11
  - memory recall
---

# What's New In v0.7.2

v0.7.2 sharpens Pilot for teams who already run Argo CD or Flux, signs corpus
updates so you can check they came from ConfigHub, adds ConfigHub 0.11.11
support, and widens how Pilot recalls configuration facts and explains approval
limits. This is the v0.7.2 release; the candidate before it was `v0.7.2-rc.1`.

## Expert answers for Argo CD and Flux teams

If you already know Argo CD or Flux, Pilot now meets you at your own level
instead of steering you back to the beginner tutorial.

- Ask what a Space is, or what ConfigHub would add to your setup, and get a
  direct answer grounded in your own repository instead of a generic intro.
- Run a deep repository map and see measured facts from your own files: version
  differences across environments, application dependencies, and sync-wave
  order.
- Ask whether you can promote staging to production and see the concrete
  blockers, with filled-in commands and plain-English explanations.

## Signed corpus updates

Corpus packs now carry a signature tied to ConfigHub's publishing identity.

- `pilot corpus update` still checks before it changes anything, and now checks
  that the pack was signed by ConfigHub in addition to checking every file in
  the pack.
- If a signature is missing or does not match, Pilot refuses the pack and keeps
  your existing lessons untouched.
- `pilot corpus use-bundled` remains available whenever you want to return to
  the lessons bundled with Pilot.

## Works with ConfigHub 0.11.11

Pilot now recognises `cub` v0.11.11 together with ConfigHub server v0.11.11 as a
checked pair. That keeps Pilot's read-only checks, approval cards, and solution
steps aligned with current ConfigHub commands while keeping destructive and
cluster-lifecycle actions behind an explicit prompt.

## Richer memory recall and fleet-scale checks

Pilot can now answer questions from more than its bundled YAML lessons, without
requiring a separate database:

- `pilot corpus providers` shows the available memory sources, including the
  bundled corpus, a live read-only ConfigHub Space view, and a local estate
  graph built from your repository and cluster inventory.
- `pilot corpus recall` searches across the chosen provider and names where each
  fact came from.
- Fleet-scale snapshot checks run in a bounded local summary step so large
  multi-space estates stay concise and readable instead of flooding your
  assistant window.

## Clearer approval boundaries and room for a third doorway

- Approval cards can now check a proposed command against an explicit allowed
  scope and show a plain-English counterexample when a command reaches outside
  that boundary.
- Pilot's assistant doorway registry now separates runtime detection from the
  Claude and Codex adapters, making it straightforward to add another doorway
  without duplicating safety or routing rules.

## Where Pilot has been, and where it is going

- **Past, v0.7.1:** anyone could install Pilot from a public channel, new
  lessons reached you between releases, Pilot worked with ConfigHub 0.9.1, and
  first answers named your own repository.
- **Now, v0.7.2:** expert Argo CD and Flux guidance, signed corpus packs,
  ConfigHub 0.11.11 support, pluggable read-only memory recall, bounded
  fleet-scale snapshot analysis, explicit scope counterexamples on approval
  cards, and role-based navigation across 21 public user guides.
- **Next, v0.7.3:** carrying a proven rollout across larger fleets, handing
  bounded tasks to an agent with independent verification, and reaching Pilot
  from Claude Desktop Cowork or a third assistant doorway once shown to work
  end to end. These remain planned, not available.

## Known limits

- Pilot is not supported in the Claude Desktop chat window or in Claude Desktop
  Cowork yet; use the Code tab or the terminal.
- Fleet-wide promotion, delegated unattended agent work, and a third live
  assistant doorway beyond Claude and Codex remain planned, not available.
- Live cluster verification for the v0.7.2 candidate has not yet been re-run
  against ConfigHub 0.11.11; earlier live scenario receipts remain explicitly
  dated and bound to their original server version.
