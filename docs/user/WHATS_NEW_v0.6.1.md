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
  - v0.6.1
  - v0.6.1-alpha.4
  - v0.6.1-rc.1
  - scenario and workflow coverage
  - scenario and delivery coverage
  - release candidate
---

# What's New In v0.6.1

v0.6.1 brings together four internal alpha previews and one release candidate.
The theme is everyday operational work you can follow from start to finish:
bring an estate you already run into view, promote a change in ordered rings,
roll out a vulnerability fix while one environment deliberately keeps its own
image, take away access a team no longer needs, and clean up afterwards. It
runs against current ConfigHub (0.8.3), and the three rollout stories were run
end to end against a live ConfigHub organisation and a real cluster before
release.

## Works with current ConfigHub

Pilot recognises the current `cub` and ConfigHub server pair for reads, staged
rollout planning, delivery tracing and teardown planning. It still checks the
pair you actually have before it offers a plan, and an unknown or mixed pair is
refused by name instead of being guessed at.

Approvals follow ConfigHub's own model. Pilot no longer offers approval for one
piece of configuration at a time. It points you at an approval recorded for a
whole environment, which a change workflow can require before a stage.

## Staged rollouts that judge health from the release itself

A staged rollout sends one reviewed change to your environments in ordered
rings, with ConfigHub's own gates between them. On current ConfigHub each ring
is judged from the live status of the newest published release in each
environment, the same reading ConfigHub's health gate uses. A release nothing
has reported on is never counted as healthy, and an older release's status
never stands in for the new one.

If you check a ring seconds after publishing, Pilot now says the controller is
still at work and asks you to read again. It no longer tells you the ring
failed when nothing has. A reported failure still stops the rollout.

When your clusters take changes through shared bases, Pilot finds every step
between the change and each cluster, promotes the bases first, and stops before
printing anything if a step is missing or ambiguous.

## A vulnerability fix that can skip an environment on purpose

Give Pilot a scanner report and the repository that sets your image tags. It
says what is vulnerable where, and plans the fix as a move to a scanned
replacement image, pinned by digest, going out safest environment first.

Sometimes one environment has to keep its own image for a while. Say which one
and why. Pilot proposes a guard for exactly that value, the fix goes to the
others, and the report shows the held-back environment as held back: not as
failed, and not as fixed.

## Access reduction that is checked where it counts

Pilot reads a shared repository and says per team what it can reach, what its
own work needs, and which access goes further than that, with the file and
line for each. It writes the cut as a diff you read first.

After you make the cut, Pilot compares your own before and after permission
checks and says whether the access actually went. It tells you when a removal
was stored but is still live in the cluster, and names the setting that lets
the controller remove it.

## See and compare a promotion before you run it

Save the reads Pilot names and it shows which environment is behind its
source, what has not been released, and which workflows and approvals are
recorded. Take the same reading afterwards and Pilot compares the two: what
changed, what cleared, and what is still open. Missing evidence stays a named
gap.

When two or three plans are on the table for the same task, Pilot can compare
them using effort, time and cost figures you supply, and says whether those
figures support a clear choice.

## Bringing an estate you already run into view

Starting Pilot in a project shows how it classified that project first, and
one next step. For an Argo CD app of apps, Pilot prints the whole handover:
what to read first, how to retire the old root without deleting anything, how
to switch each app's source in one reversible change, how to check it, and how
to hand it back to Git. Packaged guides explain the same ground for Flux and
Sveltos, and what each planning path can and cannot read.

Fleet questions, such as which change has reached which clusters and which
rollout has stalled, can be answered from a few saved list reads instead of
reading the whole fleet.

## A clearer first answer

When Pilot has read your folder, the first line of `pilot start`, `pilot map`,
`pilot assess`, `pilot teach` and `pilot onboard` says what it found, not just
its own name. In a repository the start card gives one next step and one line
for more choices, not a menu. A question about promotion is answered with a
step about your own repository that you can run as printed. Teaching offers
the guide for the delivery tool you use, says who each guide is written for,
names the copy installed on your machine, and no longer offers a chart
demonstration to a repository that has no chart.

## Statuses come from evidence

A status on a card is worked out from the evidence Pilot has at the moment it
builds the card. It does not repeat what an earlier step said. When the
evidence is missing or too old, the card says not proven. Pilot does not read
your cluster again each time a card is shown; a fresh reading is still a
command you run.

## Cleaning up

A teardown plan inventories what depends on what, orders the steps, and adds a
stop-and-check before every delete. It never bundles deleting a cluster with
deleting its configuration, and it words the plan for the ConfigHub version
you have.

## Safer by default

Changes to components, edits to a space, moving configuration between spaces,
and commands Pilot has not reviewed now reach your approval prompt instead of
running. Printed reads ask only for the fields they need, which keeps worker
secrets out of saved output.

## Known limits

- The live checks used one local cluster with several namespaces standing in
  for environments, Argo CD only, and commands a person reviewed and ran. They
  do not show unattended or delegated execution, a multi-cluster fleet, or
  Flux delivery.
- The vulnerability fix that was checked live was a real but partial
  remediation: the newer image still carries known high-severity findings, and
  a scan is only as fresh as its database.
- A plan check before a promotion is not atomic with the writes that follow,
  and publishing a release selects the current contents at that moment.
- Delivery tracing reports a failed workload check for a space that delivers
  no workloads, such as permissions only.
- Plan comparison uses figures you supply. It does not look up prices, reserve
  a budget, or prove a plan will succeed.
- Fixed after this release, and arriving in the next preview: short
  first-look guides for Argo CD and Flux beginners, one resource count that
  agrees between the folder map and the import plan, and a next command that
  is never broken across lines on the progress card.
- Still ahead, and not part of this release: trials with people who did not
  build Pilot, proof that companion skills load and are chosen at run time,
  fleet-scale analysis on a large seeded estate, the remaining plain-language
  passes, and the split of Pilot's shared core into smaller parts.
- This is an internal team preview. It makes no PyPI or Homebrew publication
  claim.
