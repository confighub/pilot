---
shelf: product-doctrine
status: current
audience: users
owner: pilot
portable: true
package: pilot-corpus
used_by:
  - pilot/inventories/pilot-learning-sources.json
  - docs/user/ARGO_ONBOARDING.md
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tests/test-pilot-learning-sources
retrieval_triggers:
  - first look at my Argo CD repository with Pilot
  - I run Argo CD and I am new to ConfigHub
  - what would ConfigHub do with my ApplicationSet
---

# Your Argo CD repository, a first look with Pilot

**Level: Beginner.** For you if you run Argo CD and are new to ConfigHub.
**You need nothing:** no ConfigHub account, no cluster, no `cub` tool. You need
Pilot installed and a terminal open in the folder of your Argo CD repository.

Every command here only reads files on your computer. None contacts Argo CD, a
cluster or ConfigHub, and none changes your repository. Argo CD keeps
delivering the whole time. The outputs below come from Pilot's public example
[`gitops/argo/beginner-applicationset`](https://github.com/confighub/examples/tree/main/gitops/argo/beginner-applicationset),
which deploys one app, `apptique`, to `dev` and `prod`. You will see your own
names and folders where it shows the example's.

## Step 1: see what Pilot recognises

```bash
pilot map
```

```text
Pilot map: The delivery tool here is Argo CD.
This repo deploys apptique to dev and prod.
It sends them to the namespaces apptique-dev and apptique-prod.
```

If your ApplicationSet uses a Git generator, which builds apps from folders or
files in a Git repository, the map says:

```text
ApplicationSet `apptique` uses a git directory generator. Pilot found matching local folder candidates in this checkout. The manifest's Git repository and requested revision have not been verified against these local candidates, so the exact generated apps are unknown.
```

So Pilot names the folders in your checkout that the generator could match. It
does not claim those are the apps Argo CD really builds.

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
review." For the example it lists 1 Component (one per app) and 3 Spaces. A
Space is ConfigHub's versioned folder for one deployable thing's configuration.
There is a shared `-base` Space plus `-dev` and `-prod` made from it, so a change
can later be promoted from one to the next. The names start with your
repository's folder name, and the plan warns it has not checked whether they are
free in your organisation.

The plan also says what stays put: "Stays in Argo: The Argo ApplicationSet
`apptique` stays in Argo", because you apply it by hand and it is not proposed
as ConfigHub configuration. For a Git generator it repeats the folders it
matched ("It matches 2 folders in this checkout") and goes no further.

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
is for and whether it needs an account or a cluster. In a small Argo CD folder
like this one, this guide is the first item under "WHERE TO LEARN THIS". It
downloads nothing.

## What this does not prove

These steps show what Pilot can read from files. They do not show what Argo CD
has synced, whether your cluster matches Git, or whether ConfigHub would accept
the files. Those need a ConfigHub login and a live check, each with your
approval.

## Where to go next

When you are ready to move toward ConfigHub, read
[Bring your Argo CD repository under ConfigHub](ARGO_ONBOARDING.md). It is
written for people who run Argo CD in production, and its later steps need the
`cub` tool and a ConfigHub account. For the general picture first, read the
[ConfigHub first look](PORTABLE_FIRST_RUN_WALKTHROUGH.md). To see more of any
result, say "Pilot, show me the full cockpit" or "Pilot, show engineer details".
