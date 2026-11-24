<!--
---
shelf: product-doctrine
status: current
audience: users
owner: pilot
portable: true
package: pilot-corpus
used_by:
  - docs/user/README.md
  - docs/user/WHAT_CAN_I_DO_TODAY.md
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tests/test-pilot-journey-organise
  - tools/audits/audit-md-corpus-shelves
  - tools/audits/audit-pilot-package-manifest
retrieval_triggers:
  - how should I organise my spaces
  - how do I set up a fleet
  - platform team and app teams
  - what is a stack
  - ConfigHub layout
---
-->

# Plan Your Estate Layout

You have a ConfigHub organisation and nothing in it yet. The first question is
not which command to run. It is what shape your estate should be, because the
Space names and labels you choose on day one are what every later question has
to be asked through.

Run this:

```text
pilot layout
```

It is read-only. It proposes a layout and prints the commands. It runs none of
them.

## The decision path

Answer these in order and stop at the first yes.

1. Do you run more than a handful of clusters, and do you want one reviewed
   change to reach all of them? That is a **fleet**.
2. Is there a team that sets the rules for other teams, so the people writing
   app configuration are not the people who decide what is allowed? That is a
   **platform team plus app teams**.
3. Do your deployments stack in layers, where an app depends on shared services
   which depend on infrastructure, and each layer changes on its own schedule?
   That is a **stack of layered components**.
4. Do you look after more than one application? That is **many apps, one team**.
   Otherwise it is **one app**.

Read the one you landed on in full:

```text
pilot layout --shape cluster-fleet --plain
```

The five shapes are `single-app`, `many-apps-one-team`,
`platform-and-app-teams`, `cluster-fleet` and `layered-stack`.

## The parts that are the same in every shape

**Space names.** A Space is one variant of one component. The recommended name
is the component followed by the variant, for example `web-app-prod-us`. Names
may use lowercase letters, numbers, hyphens, underscores and dots, must start
with a letter or a number, and must be unique in your organisation.

**Labels.** The public ConfigHub guide recommends six keys: `Component`,
`Owner`, `Environment`, `Region`, `Layer` and `Variant`. Pilot proposes exactly
those six and nothing invented. A seventh key, `Stage`, is set by the CLI and
read by change workflows when a rollout moves in waves, so Pilot names it
separately rather than pretending it is part of the documented six.

**Base and deployment.** A base is a variant nobody deploys. It holds the
complete configuration with the per-place values left as placeholders, and it
exists to be cloned. A deployment is cloned from a base, has its placeholders
filled in, and has a Target. There is only one way to tell them apart: no
Target means base.

**Targets, controllers and workers.** A Target names the destination for a
deployment. A configured GitOps controller such as Argo CD or Flux pulls and
reconciles OCI Releases. ConfigHub's server-worker is an identity used for
pull access; it does not run a process in the cluster. External Workers host
custom functions. Check the exact installed compatibility profile before
describing how a Target binds to a Worker or grants pull access. The
[ConfigHub entity model](https://docs.confighub.com/background/entities/)
explains these roles; confirm version-specific setup against the installed
client and server.

**Where validation lives.** For one team, the checks can live in the Spaces
they check. As soon as a second team has to obey the same rule, move the checks
into one platform Space, select them with a Filter, and attach that Filter to
the app Spaces. After you change a check, refresh the Spaces that use it or
they keep the old list.

## Stopping a bad change

```text
pilot layout --policy --plain
```

There are six moments where a bad change can be stopped, and picking the right
one is most of the work.

- **When the data changes.** A validating Trigger runs a check. If it fails,
  a named entry is recorded against that revision. Add warn mode to make a new
  rule advisory while people get used to it.
- **When a release is published.** While a validation entry is outstanding,
  publishing a Release of that revision is refused. It is not final: fix the
  problem and publish again.
- **When somebody signs.** An approval is an attestation: a record that a person
  made a claim about specific revisions in one Space. A change workflow can
  require qualifying approvals before a change enters the next stage. The next
  change is a new revision, and is not covered by what was signed before.
- **When somebody deletes or destroys.** A delete gate or a destroy gate is a
  named reason stored on the entity, and the matching operation is refused while
  it is there. A gate on a Unit does not stop a recursive delete of its Space,
  so gate the Space too.

Guards are the fifth control and they work differently: a guard names a reason
one field must not be written, and a write without a matching clearance is
withheld and reported as a conflict instead of applied quietly.

Change workflows are the sixth control. A change workflow stops a change from
jumping a stage: it names the stages and what each one requires before a change
may enter it.

In the ConfigHub API those validation entries are `ValidationErrors` and
`ValidationWarnings`. The older names `ApplyGates` and `ApplyWarnings` are still
served as deprecated aliases, and the public guide still calls them Apply Gates,
so you will meet both spellings for one thing.

## What is planned and not available

Group and service-account ownership of components and variants, with per-variant
permissions and approvals gated against a named change group, is an open draft.
None of it exists in the reviewed server, so none of it can be set up today.
Pilot labels it planned wherever it appears. Until it lands, the Space is your
unit of access and the `Owner` label is how you record which team answers for it.

## The tools

```text
pilot layout --tools --plain
```

Each tool says what it does, when to choose it, and how far along it really is:
shipped means you can install or run it today, experimental means something it
needs is unfinished or no longer published, and planned means it is a design
with no code. The status is read from the tool's own repository, not from a
wish.

## Where this page stops

Pilot proposes a layout. It creates no Space, sets no label, writes no Trigger
and approves nothing. The names in every example are example names, so change
them before you run anything. A layout is a starting shape, and your estate will
need judgement the moment it stops matching one of the five.
