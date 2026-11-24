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
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tests/test-pilot-map-deep
  - tests/test-pilot-feature-completeness
  - tools/audits/audit-md-corpus-shelves
  - tools/audits/audit-pilot-doc-reference-integrity
retrieval_triggers:
  - deep analysis
  - estate analysis
  - how much duplicated config
  - biggest delivery risks
  - executive summary of this estate
  - blast radius
---
-->

# The deep analysis

## Read a whole estate, not one repo

Run it on the folder that holds your delivery configuration:

```bash
pilot map . --deep
```

That is one command. It reads files, answers ten questions about them, and says
plainly which ones it could not answer and what it would have needed. It changes
nothing, sends nothing, runs no other program, and opens no network connection.

Add `--json` for the typed answer, `--out <file>` to save it, and `--question Q6`
to run one question on its own.

Three more questions (Q11-Q13) answer a different scale: which clusters carry
an in-flight change, which Spaces have recorded degraded delivery, and which rollout has
stalled, across a whole fleet rather than one folder. Answering that from raw
per-object reads costs hundreds of thousands of tokens of context; three
question-specific, bounded ConfigHub list reads supply the facts those answers
need. See "Fleet-scale questions" below.

## What it measures

Configuration as code mixes up two separate decisions: how you write
configuration down, and where you keep it. Code is a fine way to write it down.
A folder of files is a poor place to keep it, because a folder cannot answer
questions about itself. The deep analysis measures how much that costs you.

It groups what it finds under four ways a store can be wrong without telling
you. Each one is the failure of something you actually want, so none of them is
an accusation:

- **Drift.** You want somebody to be able to fix production at three in the
  morning. Drift is the fix nobody wrote back, and files that never say whether
  a target is allowed to differ or is just differing.
- **Sprawl.** You want targets that legitimately differ, because regions differ
  and tenants differ. Sprawl is difference nobody declared, so a new value can
  appear and nothing notices.
- **Blast.** You want one definition to serve many targets. That is the whole
  point of templating. Blast is reach nobody could see, because the rendered
  result lives on every target and nowhere you can look at before you merge.
- **Limbo.** You want changes to arrive in waves. Limbo is a wave nobody
  finished, with nothing recording whether the pause was somebody's decision.

There is a fifth section, the defence. It is the collection of checks, limits
and freeze windows an estate builds when it cannot see reach, and it is worth
looking at because most of those limits cap how often you can change things
rather than how much one change can touch.

## The ten questions, in plain words

1. For every definition: is it syncing by itself, does it put back what somebody
   changed by hand, does it delete what you removed, and did anyone decide?
2. Is there a folder here holding facts about the running system rather than
   what you intended, and what stops somebody editing it by hand?
3. Is your primary key a filename? If you renamed one thing, how many files
   would you have to touch?
4. For a label like environment, region or team: how many values are in use, how
   many are written down anywhere, and do those two agree? And how many of your
   values layers point at a file that is not there?
5. How many templated sources are in here, and how many finished, rendered
   manifests are stored anywhere you can look at?
6. Change one line in the most widely shared values file. How many targets have
   to be worked out again? Now do the same for one target's own file.
7. Do the charts pin what they depend on? Is there a lock file, and is it
   committed?
8. For every check, bot limit and freeze window: does it limit what one change
   can reach, or only how often changes can happen?
9. In one definition, how many times is the same version string repeated?
10. Which definitions hold two or more different versions right now, and does
    anything here say whether that is a hold or a stall?

## Fleet-scale questions (Q11-Q13)

These three use bounded ConfigHub list reads you save ahead of time, never a
live `cub` call from Pilot itself. Q11 needs Spaces and ChangeOrders, Q12 needs
Releases, and Q13 needs ChangeOrders. Save each required read scoped by your own
`--where` expression, never an unscoped, organization-wide read:

```bash
cub space list --where "<your scope>" -o json > spaces.json
cub changeorder list --space "*" --where "<your scope>" -o json > changeorders.json
cub release list --space "*" --where "<your scope>" -o json > releases.json
```

An older saved folder may also contain `targets.json`. Pilot still accepts that
optional legacy file and redacts `BridgeWorker.Secret` in its parsed copy, but
Q11-Q13 do not use Target data. Pilot does not know which command produced an
old file, and does not edit or delete it; the saved file itself may still hold
the secret. Keep it private and remove it under your own data-handling policy.

Put the required files in one folder, named exactly as above, and add
`--fleet-reads`:

```bash
pilot map . --deep --fleet-reads ./fleet-reads --json
```

11. For every change order that has not finished: how many of its in-scope
    Spaces have released it, and which cluster and component is each one?
12. Which Spaces' recorded delivery reading is not Synced, Healthy and Succeeded, and what does each one say and when was it last observed?
13. Which change orders have not finished and have not moved in longer than the
    stalled threshold (`--stalled-after-hours`, default 24)? What stage are they
    at, and how many of their in-scope Spaces are still not released?

Without `--fleet-reads`, all three appear under "what could not be answered"
and name only their required reads, the same as any other missing input. A
folder missing one required file degrades only the questions that need that
file; the others still run. An absent optional `targets.json` does not degrade
any of them.

A delivery reading needs all three status fields and a valid observation time
with a timezone. Missing or malformed evidence counts as unresolved, never
healthy. These saved readings describe their recorded observation; their
timestamps do not prove freshness or current runtime health.

## Helm values that do nothing

A Helm value can have no effect when its name or path does not match what the
chart uses. A chart's optional `values.schema.json` can reject invalid input.
Passing validation or rendering successfully does not prove that every supplied
value changed an object. Compare the rendered objects before relying on that
value. See [Helm's schema documentation](https://helm.sh/docs/topics/charts/#schema-files).

Only a render can answer this, and the deep analysis will not render anything.
So the answer comes from a file you make first, with one command:

```bash
cub config values . --values values.yaml
```

The reviewed Workshop v0.6.56 implementation renders a baseline, repeats it to
identify unstable fields, then removes one supplied value at a time and compares
the result. Its default limit is 60 renders; values beyond the limit are NOT
CHECKED. A reported lack of effect applies to those render settings, not every
possible deployment. Add `--exit-code` to fail for ignored or ineffective values,
unchecked values, or invalid rendered resources:

```bash
cub config values . --values values.yaml --exit-code
```

`cub config values` comes from the cub workshop plugin, which you get with
`cub plugin install confighub/cub-workshop`. It is a plugin, not part of cub
itself, so it is not covered by the reviewed cub capture Pilot checks its other
commands against. This local check needs no ConfigHub account or cluster and
does not apply configuration to either. Fetching a remote chart uses the network;
optional `--out` and `--render-out` write local files, and rendered YAML can contain
Secrets. Pilot prints the command, filled in from your folder, and you run it.
These details are source-reviewed against
[Workshop v0.6.56](https://github.com/confighub/cub-workshop/blob/e6535d4740f5c7ecf673c16a7af3a14914cbb759/lib/config-values.mjs),
not proof of the plugin version installed on your machine.

`pilot import . --plan` prints that command for every values file your repo
renders with, before the render and the upload steps, so you can check each one
before anything is uploaded. `pilot ask "did my helm values actually do
anything"` prints the same command on its own.

To bring the answer into the deep report, save what the command prints and pass
it back:

```bash
cub config values . --values values.yaml --json > values-check.json
pilot map . --deep --values-check values-check.json
```

The report then carries one more finding under Sprawl: how many of the values
you set changed nothing, out of how many you set, with the values file and the
result file as evidence. The numbers are as old as the file you saved, and the
report says so. Without the file, the report says the question could not be
answered and names the command that answers it, which is the same thing it does
for every other input it did not get.

## What "could not resolve" means

Two different things, and the report keeps them apart.

A question that could not run at all appears under **what could not be
answered**, with the reason and the exact input it would have needed. It never
appears as a zero. A count of zero definitions in a posture would read like good
news, and a missing input is not good news.

An input inside a question that could not be read increments that question's
**could not work out** count. It contributes nothing to the answer. Nothing is
ever assumed to mean everything. If a selector cannot be interpreted, Pilot does
not guess that it matches the whole fleet, because that guess is how you get a
number that is several times too high and looks confident.

Question 6 is the one that needs most help. Targets are picked by label, and the
labels live in your delivery tool rather than in your files. From a folder alone
Pilot has to work out which directory describes your targets, so it says so: the
report records where the target list came from, and everything built on a guessed
list is marked as an estimate rather than as measured.

The most useful line the analysis can print is often this one: Pilot could not
work out what some of your definitions target. Neither can somebody reading the
change, and the change does not say so.

## A scan measures exposure, not cost

This is the part to be strict about, because it is where these exercises usually
go wrong.

Reach nobody can see is not an incident. A values layer that never resolves is
not an outage. A version stranded across several blocks is not a delayed
release. Each of those is a way your estate is exposed. None of them is a thing
that happened.

So the deep analysis prices nothing. The `cost` section of the report is always
empty, and the report lists the inputs a cost model would need from you: your
loaded hourly rate, how many change cycles a year you run today and how many you
are meant to run, the engineer-hours one fleet-wide change actually took, and
how many of last year's incidents started with a configuration change. Those are
your numbers. Pilot will not invent them, and it will not turn a count of
exposure into a figure in money.

## How to share a banded report

A report you want to send outside your own team carries counts that say how big
your estate is. Add `--banded`:

```bash
pilot map . --deep --banded --out estate-report.json
```

Banding does four things, all of them deterministic, so the same estate bands the
same way every time:

- **Ratios stay exact**, because ratios are the findings and they identify
  nobody. Every line leads with its ratio.
- **Absolute scale becomes a phrase** from a fixed ladder: "a few dozen",
  "several hundred", "tens of thousands".
- **File paths become opaque references** like `E1` and `E2`, because a path can
  carry a name. The key that maps them back is written next to your report and
  stays with you.
- **A total worked out from banded inputs is not printed.** Publishing it exactly
  would hand the banded inputs straight back. The report prints how the total was
  worked out instead.

Banding is not clearance. It makes a report less identifying; it does not make it
approved for sending. Those are two separate steps and you still need both.

## Where the findings go next

Every next step in the report names the finding that motivated it, and none of
them runs by itself. Pilot will never propose removing one of your existing
blast-radius controls, and it will never propose bulk-fixing every values layer
that failed to resolve. Both of those are earned later, one change at a time,
with a receipt behind them.
