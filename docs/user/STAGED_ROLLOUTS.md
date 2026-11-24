<!--
---
shelf: product-doctrine
status: current-with-review
audience: users
owner: pilot
portable: true
package: pilot-corpus
used_by:
  - docs/user/WHAT_CAN_I_DO_TODAY.md
  - scripts/pilot-operate-rings
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tools/audits/audit-md-corpus-shelves
  - tools/audits/audit-pilot-doc-reference-integrity
  - tests/test-pilot-operate-rings
retrieval_triggers:
  - staged rollout
  - rollout rings
  - roll this out safely across my clusters
  - patch this CVE across the fleet in stages
  - change workflow stages
---
-->

# Staged Rollouts

Sending one change to every cluster at once is how a small mistake becomes a
big one. A staged rollout sends it to a few places first, checks that they are
fine, and only then sends it to the rest.

Pilot calls each batch a **ring**. A ring is a set of targets that get the
change at the same time, and a check that has to pass before the next ring
starts. That is all a ring is. It is not a new kind of pipeline, and there is
only one of them in Pilot: a planned change and an urgent security fix go out
through the same rings.

## Ask for one in plain words

> roll this out safely across my clusters

> patch this CVE across the fleet in stages

Pilot answers with the door below. It plans; you run the commands.

## Match the plan to your ConfigHub version

For v0.6.1 the reviewed pair is cub 0.8.3 with ConfigHub server 0.8.3. Pass
`--compatibility-profile cub-v0.8.3-server-v0.8.3` to every plan. This applies
to both a planned promotion and a security fix. Pilot checks its proposed
commands against that version's captured help, including from an installed
package. Omitting the option still selects the older cub 0.6.2 command set; it
does not detect your installed version.

Selecting a profile does not inspect your client or server. Confirm both
identities before using a plan: cub 0.8.1 with server 0.8.0, for example, is a
different pair. The selected profile is part of the plan's approval scope, so
changing it requires a new plan and review. Older pairs stay selectable: cub
0.6.2, cub 0.6.8, and the cub 0.8.0 and server 0.8.0 pair
(`--compatibility-profile cub-v0.8.0-server-v0.8.0`).

Staged-rollout plans are not yet available for cub 0.8.30 or cub 0.9.1. Pilot
recognises those pairs (`cub-v0.8.30-server-v0.8.30`, and the server 0.8.29 it
runs the same code as; `cub-v0.9.1-server-v0.9.1`) as reviewed pairs and plans
their teardown, but the staged-rollout planner has no reviewed command list for
them, so use the 0.8.3 pair above for ring plans until it does.

On the 0.8.3 pair, from server 0.8.2, ConfigHub decides a Space is healthy from
the live status on the Space's newest published Release, not from the old
`confighub.com/live-status` Space annotation. Each ring prints a narrowed
`cub release list` read for every Space it releases, and Pilot judges the ring
from that Release's own status. A Release nothing has reported on is not
healthy, an older Release's status does not stand in for it, and the old
annotation is never used, not even as a fallback. Hand the reads back under
`release_reads`, and the `cub changeorder get` body under `change_order_read`.
The other pairs keep reading the annotation.

Give the controller a moment before you take that read. A Release read seconds
after the publish says the controller is still at work: not yet synced, an
operation running, or health progressing. Nothing has failed, so Pilot answers
`WATCH` (`RING_LIVE_STATUS_IN_PROGRESS`), not a failed ring, and asks you to
read the Releases again when it settles. A status that reports a failure is
still a `BLOCK`.

For the 0.8.0 and 0.8.3 pairs, each promotion proposal includes `--expected-plan`.
Pilot tells you to copy the `Plan` value from the second dry run and review
the completed command. ConfigHub checks that value before writing, but the
check and writes are not one atomic operation. Release publication still
resolves the Space's current membership and revisions when it runs. These
checks do not establish exact-artifact approval or prove delivery.

The proposed bare publication also carries no ChangeOrder identity. It does
not evaluate that ChangeOrder's release prerequisites. If the Component
requires a workflow, stop at the refusal. Publishing the ChangeOrder's tagged
revisions would change the selected content and needs a separate reviewed
plan; do not remove the policy or assume missing tags fall back to current
revisions.

After a reviewed operation, supply its observations to Pilot's stage check.
A useful plan is the starting point; controller and runtime evidence are
still needed before Pilot can report that the change arrived.

## What you give it

Two files.

**The change.** What is going out, and which exact reviewed revision it is.

```json
{
  "schema": "confighub-pilot.ring-change.v1",
  "kind": "REVIEWED_PROMOTION",
  "change_id": "app-one-timeout-raise-001",
  "objective": "Raise the request timeout on app-one from 5s to 15s.",
  "source_space": "app-one-base",
  "reviewed_revision": "app-one-base:12",
  "unit_slugs": ["app-one"]
}
```

For a security fix, set `"kind": "VULNERABILITY_FIX"` and add an `image_bump`
saying which tag it moves from and to. You do not have to write that file at
all: the vulnerability engine already produces it. Save its answer and hand
that in instead.

**The targets.** Where it is going, and what is deliberately left out.

```json
{
  "schema": "confighub-pilot.ring-targets.v1",
  "targets": [
    {
      "target_id": "cluster-001/app-one",
      "space": "app-one-dev",
      "unit_slug": "app-one",
      "blast_size": 1,
      "labels": {"Environment": "dev", "Region": "eu-west", "cluster": "cluster-001"}
    }
  ],
  "excluded": [
    {"target_id": "cluster-006/app-two", "reason": "app-two does not run the reviewed Unit."}
  ]
}
```

`blast_size` is your own number for how much a target matters. Anything will
do, as long as a bigger number means more people notice. There are worked
examples of both files in `tests/fixtures/operate-rings/` in the Pilot source
checkout.

**A target that keeps its own image.** On a rollout that runs a saved function
in each Space (see below), a target can say it keeps its own value at the image
path the function writes:

```json
{
  "target_id": "cluster-007/app-one",
  "space": "app-one-dev-pinned",
  "unit_slug": "app-one",
  "blast_size": 1,
  "labels": {"Environment": "dev"},
  "keeps_own_value": {
    "resource_type": "apps/v1/Deployment",
    "resource_name": "app-one/app-one",
    "path": "spec.template.spec.containers.?name=app-one.image",
    "why": "cluster-007 runs a pinned build for a load test this week"
  }
}
```

The resource type, resource name and path are written the way cub prints them.
The path has to be a container image path, because that is the only path the
saved function writes. Pilot then guards that path before the ring, as the
next sections explain. `why` is optional and goes on the card.

**When a base sits between the source and the targets.** A change travels one
hop at a time. If your targets were cloned from a class base (a `prod` base,
say) that was cloned from the Space the change is made in, the class base has
to take the change first, and ConfigHub refuses a change order that skips it.
Pilot cannot see those hops by itself, so add a `lineage` snapshot to the
targets file: the ids you read back from ConfigHub, for the source Space, every
base on the way, and every target Space. Give each target its `space_id` and
`unit_id` too.

```json
{
  "schema": "confighub-pilot.ring-targets.v1",
  "component_id": "<ComponentID>",
  "lineage": {
    "source": {"space_id": "<SpaceID of the Space the change is made in>"},
    "spaces": [
      {
        "space_id": "<SpaceID>",
        "slug": "app-one-prod",
        "component_id": "<ComponentID>",
        "units": [{"unit_id": "<UnitID>", "slug": "app-one"}],
        "links": [{"update_type": "UpgradeUnit", "SpaceID": "<SpaceID>", "FromUnitID": "<UnitID>",
                   "ToSpaceID": "<upstream SpaceID>", "ToUnitID": "<upstream UnitID>"}]
      }
    ]
  },
  "targets": ["... as above, each with space_id and unit_id ..."]
}
```

You do not have to assemble it by hand. Save what the reads print into one
folder and let Pilot build it:

```
pilot operate rings --lineage-reads <folder> --change <change.json> \
  --targets <targets.json> --out <targets-with-lineage.json>
```

On cub v0.6 a full `-o json` read of a Unit prints the Unit's Target and
that Target's worker record, the worker's secret included, and so does the same
read with `--select`. So the Unit reads Pilot prints ask cub for only the
fields Pilot reads, with a `jq` projection, and leave the worker record out.
From cub v0.8 a Target carries no worker record; the narrowed read is still
used. This is the Unit list for one Space:

```
cub unit list --space <space> --quiet -o 'jq=[.[]|{Unit:{UnitID:.Unit.UnitID,Slug:.Unit.Slug,SpaceID:.Unit.SpaceID,SpaceSlug:.Unit.SpaceSlug,HeadRevisionNum:.Unit.HeadRevisionNum,UpstreamRevisionNum:.Unit.UpstreamRevisionNum,UpstreamUnitID:.Unit.UpstreamUnitID}}]'
```

Copy the command from the card rather than from here: the card fills in the
Space. The single quotes hand the expression to cub untouched in zsh and bash.
If you hand back a full `-o json` read anyway, for example one an older Pilot
printed, Pilot still keeps no copy of the secret and says which saved file
carries one. The file on your disk still does, so keep that folder private and
delete it when the plan is built.

Pilot runs nothing. The first time, it names the three reads the change's own
Space and every target Space need, and the file to save each one as. Each
round, a Link that points at a Space not read yet adds that Space, by its id,
to the next round. When every hop is read, it writes the targets file with the
ids, the Component and the lineage block, and you plan with that file as usual.

Each piece comes from a read-only command, one Space at a time:
`cub space get <space> -o json` gives `SpaceID` and `ComponentID`;
the narrowed Unit list above gives each `UnitID` and `Slug`;
`cub link list --space <space> -o json` gives each Link's `UpdateType`,
`SpaceID`, `FromUnitID`, `ToSpaceID` and `ToUnitID`. In a Link, `SpaceID` and
`FromUnitID` are the downstream side, the one that takes the change, and
`ToSpaceID` and `ToUnitID` are the upstream it takes it from.

With the snapshot, Pilot joins everything by id, never by name, and checks
that every target reaches the change's own Units through exactly one upstream
Link per hop. A missing, ambiguous or looping hop, a Space from another
Component, or an id that does not match stops the plan before it prints any
command. Without a snapshot, Pilot assumes each target takes the change
straight from the source Space and says so in the plan (`LINEAGE_NOT_CHECKED`).
A snapshot is what you read when you read it: a plan built from it proves its
shape, not that ConfigHub still looks the same.

Each Unit in the snapshot may also carry `head_revision_num` and
`upstream_revision_num`, which the narrowed Unit list prints as
`HeadRevisionNum` and `UpstreamRevisionNum`. With them, Pilot checks that
every Unit below the source has already taken everything its own upstream
holds. A Unit that last took an earlier revision is named in the plan
(`TARGET_BEHIND_UPSTREAM`) before anything is written: ConfigHub refuses to
merge a new change into it until an earlier change catches it up, so the stage
that reaches it would stop. The plan still prints; finish the earlier change
first.

## One cluster per environment, from the start

A staged rollout is one cluster per environment. `pilot import` is where those
bindings are decided, so give it one Target per environment:

```
pilot import <repo> --plan --space-prefix <prefix> \
  --cluster-space dev=<dev cluster space> \
  --cluster-space staging=<staging cluster space> \
  --cluster-space prod=<prod cluster space>
```

`--target <environment>=<space>/<name>` does the same thing when the Target was
not made by `cub cluster up`. A bare `--cluster-space <space>` or `--target
<space>/<name>` with no environment in front of it is still the default for
every environment you did not name, and when that is the only thing given, the
plan says out loud that all your environments would land on one cluster and
prints the exact `cub variant create` lines to change.

## Plan the rollout

```
pilot operate rings --change <change.json> --targets <targets.json>
```

Pilot puts the targets into rings, safest first:

1. environments in order, dev before staging before production;
2. inside one environment, the smallest blast size first;
3. two targets that are otherwise equal go in target id order, so the plan
   never changes between runs;
4. no ring is bigger than the limit, and one ring never mixes environments.

If you would rather say the rings yourself, write a policy file with
`"mode": "EXPLICIT"` and list them. Pilot still checks that every target is in
exactly one ring and that the order runs 1, 2, 3 with no gaps.

The card shows, for each ring: which targets it reaches, the exact commands,
what ConfigHub checks before it, and what has to be true before the next ring.
Then it gives you one next step: approve ring 1.

## What ConfigHub does, and what Pilot does

Most of this is ConfigHub's, not Pilot's, and that matters: a gate ConfigHub
enforces holds for everybody, including a person typing `cub` by hand.

**ConfigHub holds the rollout.** The ring definition is a **ChangeWorkflow**:
ordered stages, a rule per stage saying which Spaces it covers, and the gates
that have to pass before a change enters one. The gates it can check itself are
`Validated` (nothing failed validation), `Released` (a release carrying the
change was published) and `Healthy` (synced, succeeded and healthy). The change
itself is a **ChangeOrder**: it fixes its own range when it is created, so a
later change upstream cannot ride along with it. `cub variant promote
--change-order <order> --target-stage <stage>` moves the change into one stage,
and ConfigHub reports what it did to every single Unit. It also returns a digest
of the promotion it planned, so an apply can be checked against the dry run that
was previewed.

**Pilot works out the shape and guards the edges.** It decides which targets go
together and in what order, and writes the workflow document for you. It writes
the approval envelope. It calls a target that quietly did not change a WATCH,
because a promotion that promotes nothing still exits zero. It compares each
Unit's recorded upstream revision with the upstream Unit's own head, which is
the comparison that is usually got wrong. It checks how old the live reading is,
because that annotation is best effort. It binds the whole thing to a budget you
can stop. And it prints one card with one next step.

Pilot keeps no record of which ring you are on. Where the change has got to is
ConfigHub's answer, read from the change order, so there is nothing of Pilot's
to go stale.

Pilot never runs any of it. It never calls `cub` and never reads a cluster from
this door.

## The one-time setup

Before any ring runs, three things get created once. Pilot prints the workflow
document in full, in the card, so you can copy it straight into the file the
first command names. Then it prints the commands; you run them.

```
cub space create <change-id>-workflow
cub changeworkflow create <workflow> --space <change-id>-workflow --filename <workflow.json>
cub changeorder create <change-id> --space <base-space> --description "<the exact change>" \
  --change-workflow <change-id>-workflow/<workflow> --in-scope-space <space>,<space>,<space>
cub changeorder get <change-id> --space <base-space> -o json
```

A ChangeWorkflow lives in a Space like everything else, so the Space that holds
it is made by the first command. It is named after the change, so it never
collides with a Space someone else already made. If you work inside a name
prefix, pass your own Space in the ring policy file under `workflow_space` and
every command above uses it.

The in-scope list is exactly the targets you named, plus any base the lineage
snapshot found between them and the source, and nothing else.

When the snapshot found bases, the setup goes one step further. The workflow
starts with a stage per distance from the source (`pilot-base-1` nearest it,
then `pilot-base-2`), each selecting its bases by exact `SpaceID`, and every
deployment stage selects its targets by exact `SpaceID` too, so a base that
carries an Environment label is never mistaken for a deployment. The setup
promotes each base stage in turn and reads the change order back after each.
A base has no Target, so it is never released and can never report health:
the stage after a base is only checked for `Validated` and any approval you
asked for, never `Released` or `Healthy`. From the second deployment stage on,
the gates are the usual ones.

Some fleets have no shared base to merge from: every environment sets the image
tag for itself. There, the change is not a merge, it is one saved function run
in each Space. Pilot spots that from the vulnerability engine's own reading of
where the tag is written, and the change order gains `--update-type Invoke
--invocation <space>/<slug> --param tag=:<new tag>`. If it cannot find the saved
function reference is missing, it says so and stops rather than guessing. Supplying
that reference does not prove the function exists; the printed setup still needs
to succeed against ConfigHub.

The environments may start on different tags. Pilot records each starting tag
and names the move in each ring; changing a starting tag changes the approval
scope. One rollout still carries one image to one destination tag.

For a vulnerability plan, pass `--source-space <existing-space>` to name the
Space that will hold the change order. With `--invocation <space>/<slug>`, Pilot
uses that invocation's Space unless you explicitly name another. It never
infers a Space from the image name. This input names the destination for setup;
it does not prove that the Space exists or bind a reviewed revision.

If no invocation is supplied, repeat the plan with `--source-space` first.
When the affected workloads use one container name, Pilot prints the complete
`cub invocation create` command with the image repository and container filled
in. Review that command before running it: it stores a function definition in
ConfigHub but does not change the workloads. Then repeat the plan with the
printed `--invocation` reference. If container names differ, Pilot stops for a
reviewed function instead of guessing which container to change.

**Protection guards a merge. It does not stop an Invoke. A guard does.** `cub
unit set-protection` marks a path so an upstream merge cannot touch it, and an
`UPGRADE` ring that tries anyway is refused with a conflict. An `Invoke` ring
runs a saved function directly in each Space instead, which is not a merge,
and a live run proved ConfigHub applies it to a protected path anyway and
reports no conflict at all. A guard is different. It is a recorded reason a
path holds its value, and ConfigHub checks it on every change to the Unit, a
function run included: a change that is not cleared for that reason is
withheld at that path and listed as a `Guarded` conflict.

So when a target has to keep its own image, say so with `keeps_own_value` in
the targets file. Before the ring that reaches that target, Pilot proposes one
guard on exactly that path, after a read of the target's conflicts:

```
cub unit conflicts <unit> --space <space>
cub unit set-guard <unit> --space <space> --guard "<resource type>:<resource name>:<path>=owner=<space>" -o mutations
```

The reason is always `owner=<the target's own Space>`: the key `owner` says
"this Space owns this value", and the value says which Space. The ring's
saved function carries no clearance, so it is never cleared for it. The
`-o mutations` output lists the path with its `Guard`, which is the record that
the guard is set. If the path already carries a guard, cub asks for
`--clearance` for it: stop and review that guard rather than adding one. The
guard stays after the rollout until somebody removes it with
`cub unit set-guard <unit> --space <space> --remove-guard "<resource type>:<resource name>:<path>=owner" --clearance owner=<space>`.

**The exit code does not show a withheld change.** A function run that a
guard withheld still exits 0 and still prints that it succeeded. The one place
the withheld change shows is `cub unit conflicts <unit> --space <space>`, and
`cub unit get -o mutations` does not show guards at all. A conflict also stays
listed until somebody dismisses it, so an old one says nothing about this
ring. That is why every `Invoke` ring reads each target's conflicts before the
ring and again after it, and `--step` counts only a `Guarded` conflict that is
new since the read before, at the guarded path, for this ring's image.

A target that does not keep its own value is checked as before: each `Invoke`
ring reads every target Unit's protected paths, and `--step` will not call a
ring a pass when the saved function writes a path that read shows protected,
or when that read is missing. Leaving a Space out of the target set still
works too; a guard is how you keep it in the rollout and still keep its value.

## Then one ring at a time

For each ring, Pilot proposes two previews, then the promotion, then the reads
that give the health gate something to judge. The first preview shows exactly
what would change, path by path. The second shows ConfigHub's own gate panel and
the digest of the promotion it planned; keep that output, because the step below
reads it:

```
cub variant promote --change-order <base>/<change-id> --target-stage <stage> --dry-run -o mutations
cub variant promote --change-order <base>/<change-id> --target-stage <stage> --dry-run -o json
cub variant promote --change-order <base>/<change-id> --target-stage <stage> -o json
cub release publish <space>
cub changeorder get <change-id> --space <base> -o json
cub unit get <unit> --space <space> -o json
cub unit get <unit> --space <space> -o mutations   # Invoke rings only
cub space get <space> -o json
```

An `Invoke` ring with an image bump adds three kinds of command: a
`cub unit conflicts <unit> --space <space>` read for every target before
anything else, a `cub unit set-guard` for each target that keeps its own value,
right after those reads and before the previews, and the same conflicts read
for every target again after the promotion.

**Send every one of those outputs to a file.** The promotion is the one that
matters. It cannot be run twice: ConfigHub answers `Unchanged` the second time,
because the change is already there, so the body that judges the ring is gone
for good. That is why the apply carries `-o json` like the dry runs do.

The last read is the live one. On the 0.8.3 pair it is the narrowed
`cub release list` for each Space, handed back under `release_reads`; the
newest Release's status is what ConfigHub's own `Healthy` gate is evaluated
over, and the step below cannot pass a ring without it. On older pairs it is
`cub space get <space> -o json`, which carries the `confighub.com/live-status`
annotation that the `Healthy` gate is evaluated over there. Either way, the
`cub space get` body also carries the Space's own id, which is what a web link
is built from.

**The release is part of the ring, not an afterthought.** A promotion moves
configuration inside ConfigHub and delivers nothing. `cub release publish` is
what hands the Space to the Target a cluster pulls. It is also what the next
ring's `Released` and `Healthy` gates are evaluated over, so a rollout that
skips it promotes ring 1, reaches no cluster, and is refused at ring 2 for ever
with no hint why. Every ring Pilot prints carries one release per Space.

When one environment is split into more than one ring, the promotion carries a
`--where-space` that picks out that ring, built from the labels you gave Pilot.
Pilot refuses to split an environment it cannot tell apart by label, rather
than guessing.

## Say what happened, and get the next ring

Pilot does not watch the rollout. It does not call `cub` and it does not read a
cluster. So when a ring has run, you record what ConfigHub itself said and hand
that back:

```
pilot operate rings --step --plan <plan.json> --health <observation.json>
```

The card prints this file for you, filled in as far as Pilot can fill it: the
`Ring N record |` lines hold the exact JSON, with `schema`, `ring_id` and
`plan_scope_digest` already written out and the rest named. Copy it and paste
the outputs in.

Two fields are required before Pilot reads anything else:

- **`schema`**: always the exact string
  `confighub-pilot.ring-health-observation.v1`. A file without it is refused.
- **`ring_id`**: the id of the ring this reading is about, which is the ring's
  own name in the plan, such as `dev`. A file without it is refused, and Pilot
  lists the ring names this plan has.

Three of the fields hold a whole cub output: `promote_result`, `unit_reads` and
`space_reads`. Each one can be handed over in either of two containers, and the
card says so:

- as the JSON object cub printed, pasted straight in; or
- as one quoted string holding exactly the text cub printed.

Pilot reads both. Nothing you hand over is ever quietly ignored: a body Pilot
cannot read is refused by name, saying which entry it was, which container it
came in, what was wanted and what to do, under a reason code such as
`RING_OBSERVATION_READ_NOT_JSON` or `RING_OBSERVATION_PLACEHOLDER_NOT_FILLED`.

The rest of the observation file carries ConfigHub's own words, not yours:

- **`plan_scope_digest`**: copy `approval_envelope.scope_digest` out of the plan
  file. It ties this reading to the plan that was approved. Leave it out and
  Pilot blocks with `RING_SCOPE_DIGEST_MISSING` and prints the digest to copy.
- **`promote_result`**: the whole body `cub variant promote ... -o json`
  printed, put in exactly as cub printed it. That carries the per-Space outcome
  (`Promote`, `Unchanged`, `Skipped`, `Blocked`, `Failed`), the per-Unit outcome
  (`Upgrade`, `Clone`, `Revive`, `Invoke`, `Mark`, `Empty`, `Skip`,
  `Unchanged`), and the gate panel under `Stages[].Gates[]`. On a refusal cub
  prints a bare `Failed: ...` line after the JSON, which is not parseable JSON;
  hand the whole output over as a string and Pilot reads the JSON and keeps the
  trailing line as the reason.
- **`gates`**: only needed when you copied the panel out by hand. The result of
  every prerequisite for every Space, exactly as the promotion returned them.
  Pilot reports these. It does not check them again, and it cannot overrule
  them.
- **`unit_reads`**: the body of each Unit read the ring prints, as cub printed
  it, as an object or as one quoted string. The promotion result does not carry
  the two revision numbers a promoter has to compare; ConfigHub keeps them on
  the Unit, as `Unit.UpstreamRevisionNum` and `UpstreamUnit.HeadRevisionNum`.
  Leave these out and Pilot does not make the comparison and does not claim to
  have made it. The read is narrowed the same way as the Unit list, so it
  prints those numbers and the ids and leaves the worker record and its secret
  out:

  ```
  cub unit get <unit> --space <space> -o 'jq={Unit:{UnitID:.Unit.UnitID,Slug:.Unit.Slug,SpaceID:.Unit.SpaceID,SpaceSlug:.Unit.SpaceSlug,HeadRevisionNum:.Unit.HeadRevisionNum,UpstreamRevisionNum:.Unit.UpstreamRevisionNum,UpstreamUnitID:.Unit.UpstreamUnitID},UpstreamUnit:(if .UpstreamUnit then {UnitID:.UpstreamUnit.UnitID,Slug:.UpstreamUnit.Slug,HeadRevisionNum:.UpstreamUnit.HeadRevisionNum} else null end),Space:{SpaceID:.Space.SpaceID,Slug:.Space.Slug}}'
  ```

  A full `cub unit get <unit> --space <space> -o json` body still reads the
  same, and Pilot scrubs the worker's secret from it and names the file on the
  card.
- **`space_reads`**: the body of each `cub space get <space> -o json`, as cub
  printed it, as an object or as one quoted string. On pairs before server
  0.8.2, Pilot finds the `confighub.com/live-status` annotation inside it,
  reads the JSON string ConfigHub stores there, and takes the Space's name from
  `Slug`. Nothing has to be pulled out or re-keyed by hand. On the 0.8.3 pair
  the annotation is never read: this body supplies only the Space's id and
  release Target, and health comes from `release_reads`.
- **`unit_mutation_reads`**: `Invoke` rings only. The body of each `cub unit
  get <unit> --space <space> -o mutations`, one per target, in the same order
  the plan named the targets. This is the one read that shows whether a path
  the saved function writes is protected; protection guards a merge, not a
  function run, so nothing else in this rollout will catch it. Leave one out
  or leave the plan's placeholder in place, and that target's ring cannot be
  called a pass. A target that keeps its own value is judged by its conflicts
  reads instead.
- **`unit_conflict_reads_before`** and **`unit_conflict_reads_after`**:
  `Invoke` rings only. What `cub unit conflicts <unit> --space <space>`
  printed for each target, before the ring and after it, one quoted string per
  target, in the same order the plan named the targets. Pilot reads the table
  as cub prints it (`REASON`, `RESOURCE`, `PATH`, `CHANGE`), and the one line
  cub prints when nothing is outstanding. For a target that keeps its own
  value, both are needed: without them Pilot cannot say whether the guard held.
- **`live_status`**: the older way of giving the same thing, one parsed reading
  per Space with a `space` key and `observedAt`. Still accepted. A whole
  `cub space get` body put in this list is read too, so either shape works.
- **`previewed_plan_digest`** and **`applied_plan_digest`**: the digest
  ConfigHub gave for the promotion it planned, on the dry run and on the apply.

Pilot answers one of three ways.

- **PASS.** Every gate ConfigHub returned held, every Unit took the change,
  every Unit whose revision numbers you recorded is level with its upstream, and
  every Space's live reading is current, synced, succeeded and healthy. Pilot
  proposes the next ring's exact commands. A ring with no gate results is not a
  ring whose gates held: the first ring has none by design, and on any other
  ring Pilot says the gates were not recorded rather than counting them as held.
  A target that keeps its own value passes as `WITHHELD_BY_GUARD` when the
  conflicts read after the ring lists a new `Guarded` conflict at the guarded
  path for this ring's image: the guard withheld the change, which is what it
  was set for. The card names it, and the ring still passes.
- **WATCH.** Something cannot be called a pass. The big one: **a promotion that
  promotes nothing still succeeds and still exits zero.** If ConfigHub reported
  `Skip`, `Mark`, `Empty` or `Unchanged` for a target this ring meant to reach,
  Pilot calls it `PROMOTE_SILENT_SKIP` and stops. It also stops when a Unit is
  still behind its upstream, when nobody recorded an outcome for a target, and
  when the live reading is missing or out of date. On an `Invoke` ring, it also
  stops when a target's protection read is missing (`RING_PROTECTION_NOT_RECORDED`)
  or shows the container-image path this rollout writes as protected
  (`RING_PROTECTED_PATH_OVERWRITTEN`), naming the path. For a target that
  keeps its own value, it stops when a conflicts read is missing or cannot be
  read (`RING_GUARD_READ_MISSING`, `RING_GUARD_READ_UNREADABLE`), or when the
  same `Guarded` conflict was already listed before the ring, so the two reads
  cannot tell whether this ring was withheld (`RING_GUARD_RESULT_UNCLEAR`).
  Those targets show as `CANNOT_JUDGE`, never as a pass. A target nobody asked
  to guard that gets a new `Guarded` conflict for this ring's image was held
  back by somebody else's guard and did not change
  (`RING_WITHHELD_BY_UNPLANNED_GUARD`). If Pilot cannot tell, the rollout
  stops.
- **BLOCK.** A gate did not hold, ConfigHub refused or failed the promotion, the
  live reading says unhealthy, the recorded result names a Space this ring was
  never approved to reach, or what was applied is not what the dry run
  previewed. A target that keeps its own value and took the change anyway is
  `FAIL` (`RING_GUARDED_TARGET_CHANGED`): ConfigHub reported a change for it
  and no new `Guarded` conflict for this ring's image is listed after the ring.

## Approving, and when you have to approve again

The card names the exact change, the scope, the targets it reaches, the targets
left out with their reasons, and one digest of all of it. Change any of those
and the digest changes, which means the old approval no longer covers it. You
approve again. That applies to adding or removing a target, moving a target
between rings, reordering the rings, changing the reviewed revision or image
tag, and changing any proposed command.

## Stopping and picking it back up

Give the rollout a budget and a name:

```
pilot operate rings --change <change.json> --targets <targets.json> --run <name> --start-run
```

Anyone can stop it between rings:

```
pilot operate revoke --run <name>
```

The next step then refuses, and says so plainly. To carry on, resume from that
run's own receipt:

```
pilot operate rings --resume --plan <plan.json> --run <name> --new-run <new-name> --receipt <receipt.json>
```

The new run keeps the same budget and the same scope, and the promotions the
first run already spent stay spent. It cannot buy them back.

## Where to look in the web interface

ConfigHub holds the truth and the web interface is where you check it, so every
card that names a ConfigHub object also says where to look at it. The `look`
lines on the ring plan, on each step card, on the revoke card and on the resume
card are that answer.

A link is built from the object's own id, read back from cub, or from an
address somebody has opened and confirmed. It is never built from a name a
person typed: a name can belong to somebody else's object in a shared
organisation, so a link made out of one is a guess. That gives four answers,
and a card gives exactly one of them per object:

- **The link.** Pilot has the identifier the page is addressed by, so the card
  carries the URL. The step card can do this for every Space and Unit it names,
  because the ring's own `cub unit get` and `cub space get` reads carry those
  ids. It can do it for the change order from the first card onwards, because
  that page is addressed by the slug the rollout already uses.
- **No id read yet.** The object kind does have a link and cub can print it.
  Pilot has not read the id, usually because the object does not exist when the
  plan is written, so the card prints `cub space open <space> --print-url` or
  `cub unit open <unit> --space <space> --print-url` instead.
- **No link Pilot can give you.** cub cannot print one and nobody has confirmed
  a page. The card says exactly that, and sends you to the nearest page that is
  confirmed. It does not tell you there is no page, because nobody has looked.
- **No page for one of these.** cub prints a list page for the kind and there is
  no page for a single one.

### The rollout has a page, and it is the one to open

The web interface calls a staged rollout a **Rollout** and gives this change
order a page of its own at `https://hub.confighub.com/rollouts/<change order
slug>`. No id is needed. The page shows the state, how many stages have taken
the change, the change itself at the source, and the promotion path with each
stage's gate counters.

`cub --print-url` cannot print this link, and it is not evidence about what the
web interface has.

One number reads differently between the two and both are right: the rollouts
page counts every Space the change order resolved, which includes the base, and
Pilot counts the Spaces the change is promoted into. The plan card says so.

### What has been confirmed, and how

Everything below was checked by opening the page in a browser and writing down
what was on the screen.

| Object kind | cub can print a link | page opened and confirmed |
|---|---|---|
| Space | yes | **yes**: the Space's dashboard, settings, id and name |
| Unit | yes | **yes**: revisions with their tags, activity, settings |
| Change order | no | **yes**: the Rollouts page, keyed by the slug |
| Change workflow | no | not on its own. The rollout page names it |
| Release | no | not confirmed. The Space page shows unreleased Unit counts |
| Revision | no | not confirmed. The Unit page lists every revision |
| Target | list page only | no page for one Target |
| Worker | list page only | no page for one worker |

That `cub` has no `--print-url` for a change order, a change workflow or a
release is still a request upstream. It is a separate fact from whether a page
exists.

### The Unit's own revision number

The Unit page opens on its revisions, newest first, and the number at the top is
the revision the promotion made. The step card names that number, so the card
and the page can be matched without reading raw cub output. It is a different
number from the upstream revision the same card reports, and both matter: one
says where this Unit is, the other says whether it is level with what it was
copied from.

### If a link opens a blank page

You are signed in to a different organisation. The page renders its frame and
nothing else: no name, no dashboard, no error. Adding `org=` to the address does
not fix it. Pick the right organisation from ConfigHub's own chooser at
`https://hub.confighub.com`, then open the link again.

Two different organisation values are in play, and they are not the same: the
one `cub space open --print-url` puts on the end of a link, and the
`ORGANIZATION ID` the Space's own page shows. Neither made the page open in the
right organisation. Pilot prints neither rather than guessing, says on the card
what to do instead, and the question of which value the web interface wants is
open with ConfigHub.

## Three things to be honest about

**Workflow gates cover particular operations.** They constrain covered
promotion and release paths, but other Unit writes may not participate in
that ChangeOrder. They are not a universal authorization barrier. A
required-workflow refusal is a stop, not permission to choose another path.

**One stuck place holds up the next stage.** ConfigHub checks a stage's gates
over every Space of the stage before it. If one cluster never gets healthy, the
whole next stage waits. A permitted force override on an eligible ChangeOrder
promotion is recorded. It does not bypass required-workflow policy, and Pilot's
plan proposes no force override.

**The rules are frozen when the rollout starts.** The change order takes its own
copy of the workflow when it is created. Editing the workflow afterwards changes
later rollouts and nothing about this one. To see the rules this rollout is
actually under, read `cub changeorder get`, not the workflow.

## Before a ring, and after one: drift and undo

Every ring in the plan carries two commands of its own, one for each Space the
ring reaches. They are printed with the ring, and neither of them runs.

**Before the ring: has anything drifted?** A promotion writes over whatever is
already there, so the question worth asking first is whether somebody has
changed it by hand since the last release. Each ring names:

```
pilot operate drift-check --observation <observation.json> --space <space>
```

The answer is `NO_DRIFT`, `DRIFT_FOUND` or `CANNOT_TELL`. `DRIFT_FOUND` stops
the ring and offers both ways forward as exact commands. `CANNOT_TELL` also
stops it, and names the read that is missing, rather than guessing the targets
were clean.

**After the ring: the way back out.** A ring runs under one change order, and
ConfigHub takes a whole change order back out in one step. Each ring names:

```
pilot operate undo --space <space> --observation <observation.json>
```

which builds the native pair, in the order the server requires it:

```
cub changeorder update <order> --space <base> --patch \
  --aborted-reason "<one plain sentence saying why this change is not coming>"
cub variant demote <space> --change-order <base>/<order>
```

The abort comes first because the server refuses to demote a change order that
has no recorded reason. Read
[`WHAT_CAN_I_DO_TODAY.md`](WHAT_CAN_I_DO_TODAY.md) for the full undo card,
which also says what putting a change back does not cover.

## What this page does not cover

**Running either of them.** The ring plan names both commands exactly. It runs
neither, and it holds no result from either. A person runs them and reads the
answer, and that is the gap the plan records as
`UNDO_AND_DRIFT_ARE_NAMED_NOT_RUN`.

## Where else to look

- [`WHAT_CAN_I_DO_TODAY.md`](WHAT_CAN_I_DO_TODAY.md) for the day 0, 1 and 2 jobs.
- [`TEST_ENVIRONMENTS_AND_SANDBOXES.md`](TEST_ENVIRONMENTS_AND_SANDBOXES.md)
  for somewhere to try the change before any ring runs.
- [`PILOT_SAFE_ACTIONS.md`](PILOT_SAFE_ACTIONS.md) for the approval boundary
  every write in Pilot goes through.
