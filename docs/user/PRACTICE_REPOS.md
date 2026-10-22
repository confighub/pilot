---
shelf: product-doctrine
status: current
audience: users
owner: pilot
portable: true
package: pilot-corpus
used_by:
  - docs/user/README.md
  - docs/user/PILOT_MANUAL.md
  - scripts/pilot-scenario-repo
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tools/audits/audit-md-corpus-shelves
  - tools/audits/audit-pilot-package-manifest
  - tests/test-pilot-scenario-repo
retrieval_triggers:
  - practice repo
  - Argo practice repository
  - Flux sandbox repo
  - generate a test repo
  - scenario repo
---

# Practice Repos

## What this is for

The fastest way to learn a tool is to try it on something you cannot break.
`pilot scenario-repo` writes you a small Argo CD or Flux repo that looks like
a real one. Everything in it is made up. You can edit it, break it, throw it
away, and ask for another one.

It is useful in three ways:

- You are new to Argo CD or Flux and want something real-looking to read.
- You want to see what Pilot says about a repo shaped like yours, before you
  point Pilot at your own.
- You are writing a test and need a repo of a known shape that is the same
  every time.

Nothing here touches a cluster, and nothing is sent anywhere. The command
writes one folder on your own machine.

## Write your first one

```
pilot scenario-repo --tool argo --shape applicationset-git --out ./practice-repo
pilot map ./practice-repo
```

The first command writes the repo. The second one asks Pilot to read it back
and say what it sees.

To see everything you can ask for:

```
pilot scenario-repo --list-shapes
```

## The shapes

| Tool | Shape | What it models |
|---|---|---|
| argo | `app-of-apps` | One root Application that brings in one child Application per app and environment. |
| argo | `applicationset-list` | One ApplicationSet per app, with a list generator that names each environment by hand. |
| argo | `applicationset-git` | One ApplicationSet per app, with a git generator that finds the environments from the folders. |
| argo | `monorepo` | Several apps owned by several teams, fanned out to a list of clusters by one ApplicationSet. |
| flux | `kustomization-tree` | A clusters, infrastructure and apps split, with one shared base and one folder per environment. |
| flux | `helmrelease` | Each app is a HelmRelease that pulls its chart from one shared chart source. |
| flux | `monorepo` | Several apps owned by several teams, one folder per cluster, one Kustomization per team. |

Each shape is modelled on one of the canonical examples in the public
`confighub/examples` repo, under `gitops/`. Read those when you want the
real thing with real explanations. Use this command when you want a fresh
copy you can change.

## Practice problems you can plant

By default the repo is healthy. Add `--situation` once for each problem you
want planted. Each one is small and none of them depends on another.

| Situation | What it puts in the repo |
|---|---|
| `version-skew` | One app runs an older image version in the last environment than in the earlier ones. |
| `unpinned-chart` | One chart is asked for by a range instead of an exact version, and the lock file next to it is not read by anything. |
| `values-never-resolves` | One environment folder asks for a shared values layer that is not in the repo. |
| `stalled-promotion` | One app has an approved version recorded for the last environment that the environment folder never took. |
| `vulnerable-image-tag` | One app runs an image whose tag carries a made-up advisory marker, so a check has something to find. |

The advisory marker is invented. It is not a real security advisory, it names
no real software, and it must never be reported as one.

## How to check your answer

Every generated repo carries an `expected.json` file. It says what is true
about that repo: the tool, the shape, the apps, the environments, the
namespaces, the clusters, whether each generator can be followed without
leaving the repo, and every problem that was planted. Read it after you have
made up your own mind, not before.

## Settings

| Setting | What it does |
|---|---|
| `--tool` | `argo` or `flux`. |
| `--shape` | One of the shapes above. |
| `--out` | The folder to write into. It must be empty or must not exist yet. |
| `--apps` | How many apps, from 1 to 5. Default 2. |
| `--environments` | The environments in promotion order, separated by commas. Default `dev,staging,prod`. |
| `--seed` | Picks the versions and sizes. Same seed, same repo. Default 1. |
| `--situation` | Plant a practice problem. Give it once per problem. |
| `--dry-run` | Say what would be written, and write nothing. |
| `--list-shapes` | Print the shapes and problems, and stop. |

## Rules this command keeps

- **It writes one folder and nothing else.** If the folder already has
  anything in it, the command stops and tells you why. Nothing you already
  have can be lost.
- **The same settings always give the same repo.** There is no clock and no
  hidden randomness, so two people running the same command get the same
  bytes and can compare notes.
- **Every name is generic.** `app-one`, `team-a`, `dev`, `cluster-001`. No
  company and no person appears in a generated repo, so you can share one
  with anyone.
- **It reads nothing live.** No cluster, no network, no ConfigHub.

## What it does not do

It does not upload anything to ConfigHub and it does not apply anything to a
cluster. Those stay on the approval paths they are already on. A practice
repo is a folder of files, and that is all.
