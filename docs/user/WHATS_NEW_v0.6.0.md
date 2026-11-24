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
  - v0.6.0
  - v0.6.0-alpha.9
  - v0.6.0-alpha.10
  - v0.6.0-rc.1
  - autonomy and scenarios
  - alpha preview
---

# What's New In v0.6.0

v0.6.0 brings together ten internal alpha previews, one theme at a time:
reading a repository honestly before offering to import it, rollouts that go
out ring by ring with a real stop and resume, fixing a real vulnerability from
a real scan, cutting excess access and proving the cut on the cluster, and
undoing a promotion cleanly. Each of the three rollout stories (a planned
promotion, a vulnerability fix across rings, and an access cut) was run end to
end against a live ConfigHub organisation and real clusters before release.

## Reading a repository honestly before offering to import it

Before Pilot offers to bring anything into ConfigHub, it decides what kind of
repository it is looking at, and names the file that told it so. A repository
a person actually authors and deploys is treated differently from a knowledge
or catalogue repository, from output a pipeline already rendered, from an
export a generator wrote, from a description of an estate that really lives
on a server, and from a repository that mixes several of these. For a
catalogue, Pilot says the product is documentation, not configuration. For
rendered or generated output, it says plainly that the real source lives in
the pipeline or generator that made it, and that importing the output only
means the next run overwrites your work. A mixed repository still gets a plan
for the part that is real configuration, and Pilot says what it left out and
why. "I cannot tell" is a real answer Pilot can give, not a guess dressed up
as one.

Inside a repository Pilot does import, it keeps the details honest too. It
preserves the order of your Helm values files, names any values it could not
resolve, and keeps vendored subcharts with the application they belong to. It
names the custom resources and matching type definitions a repository
expects, along with sealed-secret and external-secret declarations, without
claiming any of that proves a controller is installed or a secret was ever
decrypted. For Flux, every dependency declaration stays visible: a missing
input, an unclear or malformed declaration, a dependency cycle, or a
reference that crosses clusters are all named as gaps rather than smoothed
over.

## Imports that respect each environment

An import plan gives Argo CD, Flux, Helm, Kustomize, and mixed repositories
their own app, environment, source, and missing-input detail, and keeps a
shared base separate from the applications built on it. When one
environment's configuration genuinely differs from the rest, such as a
different image running in production, Pilot loads that environment's own
configuration instead of a copy of the shared base, and says exactly what
differs. A fleet with no shared base to merge from binds each environment to
its own cluster and prints the publish step for each one. Every import and
sandbox command now takes your ConfigHub context directly, and prints it back
to you in the commands it hands you.

## Staged rollouts you can stop and pick back up

`pilot operate rings` plans a change going out across a fleet a few
environments at a time, on ConfigHub's own ChangeWorkflow rather than
anything Pilot invents: ordered stages, health gates the server itself
enforces, and one change order per change. If you stop partway, the stop
names exactly which rings already went out, when, and which Spaces they
reached; a resume only asks for the rings that have not gone yet, using the
same receipt. A stopped rollout now leads with the fact that it stopped, an
expected block is no longer reported as an error, and a plain refusal from
ConfigHub is read for what it is instead of being called a broken file.

## Fixing a real vulnerability from a real scan

Give Pilot the scan of the images you are running today and a scan of a
candidate replacement, and it works out which candidate actually clears the
critical findings, pins it by its digest rather than a tag that can move, and
rolls it out one environment at a time, saying what each move clears and what
it still leaves open. Pilot no longer mistakes a library's fixed version
number for an image tag.

## Proving an access cut, not just proposing one

`pilot access-plan` reads what a team's configuration actually reaches in
Kubernetes and Flux, works out what it needs against what it has, and writes
the smallest removal as a diff you can review. What it cannot resolve is
counted, never guessed. Once you run that cut, `pilot access-proof` reads
your before and after `kubectl auth can-i` checks and tells you plainly
whether the excess access is really gone and the access you still need is
still there. The access plan itself now prints the route a cut takes through
ConfigHub.

## Undoing a promotion cleanly

`pilot operate undo` works from a Pilot receipt, a promotion result, or a
named change set or change order, and proposes the real way back: demoting
under a change order, or restoring to before the change set and then making a
separate release. It says plainly what undo does not cover, including that an
undone promotion cannot simply be promoted again. Printed promotions are now
wrapped in a ChangeSet so undo has something real to reverse, receipts land
in your own working folder, and a restore is only reported as done once
Pilot has checked that the Units actually moved.

## Test environments and sandboxes, with their own teardown

`pilot operate test-env` and `pilot operate sandbox` plan a labelled copy of
a variant, with an owner and, for a sandbox, an expiry. The approval card
shows the teardown plan up front, before you say yes, and the teardown
planner itself refuses to touch anything that is not labelled as a test
environment or a sandbox.

## Fewer needless refusals

Reads through cub-scout now run and count as real evidence of what is on the
cluster, while Scout commands that would change something still ask first.
Pilot now asks instead of refusing outright before running `cub unit blame`,
listing something organization-wide, or creating or deleting a local practice
cluster. It also keeps reading a ConfigHub server newer than the versions it
has formally reviewed, and says so honestly instead of stopping cold. Deletes,
credential links, and unchecked overwrites still stop, every time.

## Links that go to what Pilot is describing

Where Pilot names a Space, a Unit, or a change order, it now tries to hand
you the matching ConfigHub web page too, built from the identifier it
actually read, not guessed. Where cub can print a link but Pilot has not read
the identifier itself, it gives you the command that prints one. Where no web
page exists yet for that kind of object, such as a change order or a change
workflow, it says so plainly instead of pretending one is there. If a link
opens blank, that is usually your browser sitting in a different
organization, and Pilot's cards now say so.

## Known limits

v0.6.0 is an internal team preview. These are the limits to know about.

- A plan or a receipt describes what Pilot read. On its own, that is not
  proof that a live outcome actually happened on your cluster or your
  ConfigHub organization.
- A few of Pilot's status lines still state a result without re-checking it
  at the moment they say it. Making every status line check itself first is
  planned for the next release. Addressed in v0.6.1: see
  [`WHATS_NEW_v0.6.1.md`](WHATS_NEW_v0.6.1.md).
- A staged rollout across a fleet with no shared base runs a saved function
  in each environment instead of merging configuration. That kind of rollout
  does not currently respect fields you asked ConfigHub to protect, so leave
  an environment like that out of a rollout's scope for now. Addressed in
  v0.6.1: see [`WHATS_NEW_v0.6.1.md`](WHATS_NEW_v0.6.1.md).
- A Space you brought in with a direct upload, rather than through
  `cub variant create --target`, does not automatically get an Argo
  Application. Pilot tells you when this is the case and prints the command
  that adds one.
- Removing a piece of configuration only leaves the cluster once Argo is
  allowed to prune it. Pilot explains this and shows how to turn pruning on;
  it cannot turn pruning on for you.
- The first-five-minutes trials behind several of these fixes were run with
  simulated personas built to stand in for real usage, not with outside
  users trying Pilot for the first time.
