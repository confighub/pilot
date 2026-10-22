---
shelf: product-doctrine
status: current
audience: users
owner: pilot
portable: true
package: pilot-corpus
used_by:
  - pilot/inventories/pilot-learning-sources.json
  - docs/user/FLUX_ONBOARDING.md
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tests/test-pilot-learning-sources
retrieval_triggers:
  - first look at my Flux repository with Pilot
  - I run Flux and I am new to ConfigHub
  - what would ConfigHub do with my Flux Kustomizations
---

# Your Flux repository, a first look with Pilot

**Level: Beginner.** For you if you run Flux and are new to ConfigHub.
**You need nothing:** no ConfigHub account, no cluster, no `cub` tool. You need
Pilot installed and a terminal open in the folder of your Flux repository.

Every command here only reads files on your computer. None contacts Flux, a
cluster or ConfigHub, and none changes your repository. Flux keeps delivering
the whole time. The outputs below come from Pilot's public example
[`gitops/flux/beginner`](https://github.com/confighub/examples/tree/main/gitops/flux/beginner),
which deploys one app, `apptique`, to `dev` and `prod`, with shared
infrastructure kept apart. You will see your own names and folders where it
shows the example's.

## Step 1: see what Pilot recognises

```bash
pilot map
```

```text
Pilot map: The delivery tool here is Flux.
This repo deploys apptique to dev and prod.
It sends them to the namespaces apptique-dev and apptique-prod.
```

It then lists each Flux Kustomization and the folder it points at, and adds a
warning that matters:

```text
Their source artifacts and requested revisions are unverified, so local paths do not prove what Flux will reconcile.
```

A folder that exists in your checkout is a candidate, not proof of what Flux
applies.

## Step 2: see what is and is not proven

```bash
pilot assess . --plain
```

The card has a "What is proven" section (Pilot read your folder on this computer,
and nothing was changed) and a "What is not proven" section (nothing about ConfigHub, a
controller or a cluster, because none was contacted). Read "not proven" as
unknown, not as fine.

## Step 3: see what ConfigHub would hold

```bash
pilot import . --plan
```

This prints a plan and says: "Nothing was created. This is a plan you can
review." Where your repository already groups its configuration, the plan keeps
that shape: for the example it says "Flux already groups this configuration as
apps, infrastructure", and lists 2 Components and 4 Spaces, one for each group
and environment. A Space is ConfigHub's versioned folder for one deployable
thing's configuration. The names start with your repository's folder name, and
the plan warns it has not checked whether they are free in your organisation.

It also says what stays with Flux. Each Flux Kustomization under `clusters/` is
"applied by hand and points Flux at the rest of the repo; it stays with Flux",
and the GitRepository that says where content comes from stays with Flux too. If
your layers depend on each other, the plan says what it can and cannot tell: "Flux
controller order is unknown from this checkout; Pilot will not infer it." Whether
an object you stop sending is removed depends on your Kustomization's `spec.prune`
setting, which the plan says it has not read: "This local plan has not read those
live policies or proved removal."

The plan ends with commands that would load your files into ConfigHub. Pilot has
not run them. The plan says: "Reading this plan needs no ConfigHub
account. The load commands in it do: they write to ConfigHub, so they need a
ConfigHub login". And: "Nothing will be created in ConfigHub
until a person approves it."

## Step 4: pick what to read next

```bash
pilot teach
```

Pilot looks at your folder again and prints links that fit it, each with who it
is for and whether it needs an account or a cluster. In a small Flux folder like
this one, this guide is the first item under "WHERE TO LEARN THIS". It downloads
nothing.

## What this does not prove

These steps show what Pilot can read from files. They do not show what Flux has
reconciled, whether your cluster matches Git, or whether ConfigHub would accept
the files. Those need a ConfigHub login and a live check, each with your
approval.

## Where to go next

When you are ready to move toward ConfigHub, read
[Bring your Flux repository under ConfigHub](FLUX_ONBOARDING.md). It is written
for people who run a Flux fleet in production, and its later steps need the `cub`
tool and a ConfigHub account. For the general picture first, read the
[ConfigHub first look](PORTABLE_FIRST_RUN_WALKTHROUGH.md). To see more of any
result, say "Pilot, show me the full cockpit" or "Pilot, show engineer details".
