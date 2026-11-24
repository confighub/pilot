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
  - What can I do with Pilot
  - Pilot today
  - first day with Pilot
  - day 2 operations
  - Pilot gallery
  - safe next action
---

# What Can I Do With Pilot Today?

Status: current intent-grouped gallery of shipped, runnable actions

This page groups what Pilot can do **by what you want**, not by command name,
and by how far into Pilot you are: Day 0 (first hour), Day 1 (first repo),
Day 2 (running estate). Every entry names the command, what you will see, and
the proof you get. For the sequential learning path use
the Pilot manual (`pilot manual --explain`); for what the screens look like use
[`WHAT_YOU_WILL_SEE.md`](WHAT_YOU_WILL_SEE.md).

## How to read this page

- **Posture: read, prepare, ask, run, verify.** Pilot starts read-only so it can
  identify the ConfigHub context, org, Variant, target, object, controller,
  runtime, and risk. For a normal bounded ConfigHub change it shows one exact
  literal command. A Pilot-active Claude session forces that attempt through
  Claude's host permission decision; Codex uses its ordinary tool permission
  path because this release has no equivalent Pilot hook there. A preauthorized
  Codex tool call is not proof of a separate human click. In either host,
  permission authorizes only the attempt: Pilot reads the resulting object or
  Release and records that observation before claiming success. Destructive,
  dynamic, unbounded, credential, executable, cluster-lifecycle, and direct
  Kubernetes commands ask first: in Claude, the host shows the exact command and you allow
  or decline that one attempt. Reads run without a prompt. Four things stay
  stopped: `cub space delete` with `--recursive` or `--recursive-force`,
  `cub organization delete`, `cub cluster down --delete-config` (or `detach
  --delete-config` on newer cub), and a
  credential typed into a command. The separately authenticated
  `execute-approved` lane remains optional for stronger delegated authority.
- **Cockpit** means the command supports `--render-cockpit`: a full task screen
  with Rail State, ConfigHub lanes, URL area, GUI sibling area, proof area, and
  next gate. Add `--plain` to disable ANSI styling.
- **Progress Widget** is the human closeout for meaningful work: goal, plain
  progress, proven items, not-yet-proven items, failed or blocked items, one
  next action, and a shareable summary. The detailed ledger and JSON stay in
  the engineer/automation tier.
- **Proof** names the artifact you actually get: a cockpit proof area, a status
  ledger, or a durable JSON receipt (`--json`) carrying PASS / WATCH / BLOCK /
  ASK outcomes and explicit non-claims.
- This page names which scenarios have live evidence in its last section, and
  which do not. The live-proof receipt contract ships with fixture templates;
  which scenarios still need live proof is the business of
  `pilot scenario-catalog --bucket needs-live-proof`, listed under Day 2.

## Day 0 — first hour

You have installed Pilot (or are checking an install) and want your first
screens.

| I want to... | Run | You will see | Proof | Cockpit |
|---|---|---|---|---|
| See the first screen | `pilot start --render-cockpit` | first-minute cockpit, Today Actions, lanes, proof gaps, and next gate | cockpit proof area | yes |
| Choose a journey in ordinary language | Ask `Pilot, what can I do next?` or run `pilot catalog --jobs` | a fast human chooser for eight journeys, what each produces, which inherited jobs they preserve, and where a governed write needs approval; `ORGANISE` remains available beneath SET UP & ORGANISE and commands remain hidden | user-job catalog (`--jobs --json` for engineer detail) | short card |
| See the first proof route | `pilot quickstart --progress-card` | first-run Progress Card with the safe route, proof gaps, next action, and shareable summary | Progress Card plus quickstart receipt (`--json`) | yes |
| Read the manual in the terminal | `pilot manual --render-cockpit` | the product spine: features, flows, scenarios, commands, skills, and the current maturity boundary | doc + cockpit render | yes |
| Be guided rather than choose | `pilot concierge --intent '<what you want to achieve>'` | a carried first engagement: Pilot picks the route, names the scope, and stops at each decision that is yours | engagement receipt (`--json`) | yes |
| Take one bounded lesson | `pilot tutorial smallest --through 5` | a short lesson that ends with something proven rather than described; `whole`, `confighub-first-look`, `first-project`, and `incident` are the other lessons | tutorial receipt (`--json`) | yes |
| Practise a real operational job locally | `pilot tutorial promote-change`, `pilot tutorial cve-rollout`, `pilot tutorial reduce-access`, or `pilot tutorial argo-adoption` | one synthetic walkthrough using the existing analysis or planning helper, what ConfigHub contributes, and the boundary before using your own system | local lesson receipt; no live operation or live proof | yes |
| Check which Pilot this session is talking to | `pilot doorway` | which surface answered, so you can trust the answers that follow | doorway receipt (`--json`) | yes |
| Browse shipped powers | `pilot catalog --render-cockpit` | feature families, command examples, scenario buckets, proof gaps, and next routes | generated catalog | yes |

Installing from scratch instead? Start at
[`PORTABLE_FIRST_RUN_WALKTHROUGH.md`](PORTABLE_FIRST_RUN_WALKTHROUGH.md).

## Day 1 — first repo

You point Pilot at a repo, folder, or estate and want orientation, routing,
and one safe next step.

| I want to... | Run | You will see | Proof | Cockpit |
|---|---|---|---|---|
| Understand this repo or folder | `pilot ask "map this repo and tell me the safe next step" --progress-card` | human Progress Card with the route, safe next step, proof gaps, and shareable summary | Progress Card plus automation receipt | yes |
| Find a safer way to change something | `pilot ask "scale this app" --progress-card` | human Progress Card that maps the plain request to a Safe Action, direct fallback, proof gaps, action plan, and shareable summary | Progress Card and Safe Actions receipt (`pilot safe-actions --query "scale this app" --json`); optional engineer detail (`pilot safe-actions --query "scale this app" --engineer`) | yes |
| Map without phrasing a question | `pilot map --render-cockpit` | the same task screen driven straight from the source: Rail State, lanes, proof area, next gate | cockpit proof area | yes |
| See exactly what ConfigHub would create from this app | `pilot import . --plan` | a plain-language plan: what was found, what would be created (Space, Units, Component/Base, Variant, Target, Release), what was excluded and why, and one next action — zero writes | import plan receipt (`pilot import . --plan --json`) | no |
| Hand an app Argo already runs over to ConfigHub | `pilot import . --plan --cluster-space <cluster-space> --cub-context <context>` | for an Argo app of apps: read what Argo runs first, import each environment, bring each child Application under ConfigHub unchanged, retire the hand-applied root without deleting what it made, switch one child's source in one reversible change, check it, and the way back | every step is printed and nothing runs; the plan says what it does not cover (an ApplicationSet root, the Git repository itself) | no |
| Preview whether a change would be allowed | `pilot gate --command '<exact command>' --progress-card` | a human approval card that says whether the command is read-only, blocked, or needs scoped approval — without running anything | Progress Card plus gate receipt; use `--json` for machine detail | yes |
| See the estate view packet | `pilot view --render-cockpit` | the view packet rendered as a task screen | cockpit proof area | yes |
| Measure this repo against thirteen questions | `pilot map --deep .` | drift, sprawl, reach and stalled rollouts, each a number with the files that produced it; three more (fleet-wide, with `--fleet-reads`) name which clusters carry an in-flight change, which Spaces are degraded, and which rollout has stalled | every number names the files it came from, and what could not be resolved is counted, not guessed | `--json` |
| See which team can reach past its own namespaces | `pilot access-plan .` | per team: what it reaches, what it needs, what is excess, and what could not be resolved | the removals as a diff for review, plus a check that nothing needed was lost | `--json` |
| Check whether a cut actually took access away | `pilot access-proof --plan <plan.json> --subject <system:serviceaccount:ns:name> --before <can-i-before.txt> --after <can-i-after.txt>` | PASS, FAIL, or UNKNOWN for the plan's removed and kept grants, checked against two `kubectl auth can-i` captures you already ran | reads no cluster and runs no command; checks only the plan and the two files you name | `--json` |
| Get a realistic repo to practise on | `pilot scenario-repo --tool argo --shape app-of-apps --out <empty folder>` | a complete Argo or Flux repo with a ground-truth file, the same every time | the ground-truth file states the true shape, so an answer can be checked against it | `--list-shapes` |
| Judge a repo before acting on it | `pilot assess . --render-cockpit` | what the repo is, what is missing, and what would have to be true before a change is safe | assessment receipt (`--json`) | yes |
| See which route a request belongs to | `pilot route` | the named route Pilot would take, so the answer is not improvised | route decision (`--json`) | no |
| Get your bearings in one screen | `pilot orient` | the short orientation: where you are, what Pilot sees, and the route it would take | orientation output (`--json` where offered) | no |
| See Pilot's own table of contents | `pilot contents` | every documentation door and job family in one boxed list | printed contents (`--json` for machine detail) | no |
| Decide how your whole estate should be laid out | `pilot layout --plain` | a decision path to one of five shapes (one app, many apps in one team, a platform team plus app teams, a fleet of clusters, a stack of layered components), then that shape in full: Space names, the label scheme, base and deployment variants, Targets and workers, where Triggers and gates live, approvals, and the exact `cub` commands. Add `--policy` for how a bad change is stopped, and `--tools` for the integration tools and how far along each one is. It proposes and reads; it runs nothing. See [`PLAN_YOUR_ESTATE_LAYOUT.md`](PLAN_YOUR_ESTATE_LAYOUT.md) | layout proposal (`--json`) | no |
| Decide how work should be grouped | `pilot organise [--probe-confighub]` | proposed ConfigHub spaces, units, and naming for this work, before anything is written | organise output (`--json`); `--probe-confighub` adds live read-only context | no |
| Bind this work to a project | `pilot project` | the project record Pilot is working inside, so scope is a fact rather than an assumption | project JSON | no |
| Check whether a target may be touched at all | `pilot target-access-gate --space <space> --target <target> --access-unit <unit>` | an access verdict for the intended target before any change is planned | gate receipt (`--json`); `--full-cockpit` for the task screen | yes |
| Open the exact ConfigHub screens | `pilot gui-urls --space <space> [--unit <unit>]` | the GUI links for what was just discussed, so you can check the claim yourself | printed URLs bound to named objects | no |

## Day 2 — running estate

You operate something real and want proof, scoring, and repeatability.

| I want to... | Run | You will see | Proof | Cockpit |
|---|---|---|---|---|
| Check product proof before trusting | `pilot review-packet --render-cockpit` | human-readable proof status, remaining gaps, non-claims, and engineer detail | durable receipt (`--json`) | yes |
| Review benchmark evidence | `pilot review-packet --render-cockpit` | recorded benchmark evidence, caveats, and what Pilot is allowed to claim; maintainer scoring remains separate | review packet and typed proof inputs | yes |
| Review a real receipt | `pilot review-packet --from-receipt <receipt> --render-cockpit` | receipt-derived Progress Card, proof gaps, and engineer detail without changing the underlying proof state | review packet | no |
| Operate a repo and live ConfigHub system | `pilot ask "I have a repo and live system with jobs to do" --repo . --run-read-only --json` | the OPERATE cockpit, then an exact-ID snapshot, plain-English job composition, and one scoped host-reviewed attempt | snapshot/state/output contracts; host permission is not success, so readback and lane proof remain explicit | plain + JSON |
| Read benchmark methodology | `pilot manual` | the public benchmark boundaries and claim caveats; maintainer checks remain source-checkout work | product manual | no |
| Read a promotion you just ran | `pilot promotion-proof --promote-json <dry-run.json> --promote-json <apply.json>` | what the promotion did to each piece of configuration, in plain words, from the JSON `cub variant promote -o json` printed; the two plan digests compared, so you can see that what you were shown is what was done; and "nothing to promote" reported as its own outcome rather than as success | plain-language reading, or the same record as JSON with `--json`; save the promotion's own output with `-o json` first | no, Pilot reads the file and runs nothing |
| Resolve and prove a planned promotion | `pilot promotion-proof --outcome <promotion-outcome.json> --progress-card` | one human card carrying competing proposals, the selected reviewed revision, an inert declarative pipeline, exact approval, one receipt per Promotion step, included and excluded targets, per-Unit outcomes, and the next missing proof | promotion-proof receipt, Progress Card, full cockpit, engineer JSON, and a browser sibling generated from the same record; use the legacy fixture id `--fixture flow-pass` for the T1 contract example | yes |
| See every Promotion checkpoint before acting | take exact source and destination `pilot operate snapshot` receipts, then `pilot operate compose --snapshot <source> --destination-snapshot <destination> --intent "promote stage to prod" --out <state>`; after the attempt, refresh the destination and compose `--intent "publish prod and go live"` | exact Unit/head comparison, affected and excluded scope, host-reviewed Promotion, a separately host-reviewed whole-Space publication, proof, and recovery gaps | no organization-wide list; the publication card shows the reviewed Space, Target, and Unit heads while explicitly naming dynamic execution semantics | plain + JSON |
| Review the CVE-remediation showcase | `pilot promotion-proof --fixture cve-rings --progress-card` | the same Promotion machinery applied to urgent change: advisory awareness, revision-bound authority, human approval, declarative canary/stage/production order, independent health gates, exclusions, and one receipt per target | T1 Progress Card, cockpit, engineer JSON, and browser sibling; supply a real `--outcome` packet for live proof | no, the built-in showcase is read-only |
| Stage a lesson for review | `pilot learn` | a human Progress Card showing the review-first learning boundary, the safe next step, and the shareable "not learned yet" status | Progress Card plus corpus-promotion receipts (`--json` for machine detail) | yes |
| Make a workflow repeatable | `pilot ask "make this repeatable as an app" --render-cockpit` | app intake verdict, preserved raw intent, app-pack, or honest blocker | cockpit proof area | yes |
| Find repeatable app seeds | `pilot operational-app-inventory --render-cockpit` | app-ready ideas, triage candidates, proof gaps, lanes, and next pack route | cockpit proof area | yes |
| Check generated-app fleet hygiene | `pilot operational-app-inventory --fleet-hygiene` | owner and on-call, complete forward lifecycle and OAuth histories, generated and proof age, retained malformed rows, stable drift or unhealthy diagnosis, and one truthful recommendation. The fleet record owns app, environment, target, exact revision, Variant lineage, and runtime digest; evidence can confirm but cannot redefine them. Complete file evidence remains `WATCH` until an authenticated observer adapter or verified signed-and-bound receipt validates it. Explicit controller or workload failures remain the primary reason and recommend fixing the known failure. Mutation availability remains `WATCH` while provider atomic expected-revision support is unavailable. | existing fleet records and attached evidence; engineer JSON with `--json`; each proof dimension requires its own typed reference, image digests require a full SHA-256, local/private/placeholder or mixed recursive encodings fail closed, valid `%25` literal data stays valid, and accepted HTTPS syntax is not a reachability claim | yes; read-only |
| Package a workflow as an app | `pilot operational-app-pack --query '<workflow>' --out-dir <dir> --progress-card` | a repeatable workflow/app handoff with a human Progress Card, live blockers, and next gate | progress-card JSON plus app-pack artifacts | yes |
| Export the standalone app | `pilot operational-app-export --query '<workflow>' --destination-repo <repo> --destination-mode existing --destination-org <org> --destination-visibility private --destination-license <license> --destination-ci <ci> --destination-deploy-target <target> --owner <team> --on-call <rotation> --app-dir <dir> --progress-card` | app files written in the destination repo, generated app checks, self-management material, live proof gaps, one next action, and a shareable summary | human Progress Card plus export manifest; live proof still needs browser sign-in, ConfigHub bindings, approval, receipt, and runtime evidence. The generated app's fleet record cannot move from WATCH to LIVE until `npm run binding:check` reports real live bindings. | yes |
| Find scenario candidates and live-proof gaps | `pilot scenario-catalog --progress-card` | a human card naming the next scenario to prepare, what is proven, why it is not customer-sendable yet, and what can be safely shared | Progress Card plus scenario ledger (`--json`) | yes |
| Inspect the governed compatibility gate | `pilot local-kind-live-proof --governed --execution-approval-window 300 --progress-card` | a read-only organization binding followed by `AUTHENTICATED_APPROVAL_ATTESTATION_REQUIRED` before any cluster or ConfigHub setup; the retained Component -> Variant -> tagged Space Release proof obligations remain visible | no-mutation receipt plus human Progress Card; use `--progress-card-json` for automation | yes; it is read-only and blocked before setup today |
| Follow one change down the delivery chain | `pilot delivery-trace --space <space>` | where the change actually stopped: ConfigHub, controller, cluster, or runtime. For a space that delivers no workloads, such as permissions only, the workload link reports a failure; read the other five links. | delivery-trace receipt (`--json`) | yes |
| Have the way back written down first | `pilot recover-plan --space <space> [--from-trace <delivery-trace-receipt.json>]` | the recovery route for the change you are about to make | recover-plan receipt (`--json`) | yes |
| Make a throwaway copy to try a change in | `pilot operate sandbox --from <space> --name <short-name> --owner <who>` | the new Space, its owner, the date it should be gone by, the labels, and the teardown plan that removes it | operate-sandbox plan (`--json`); nothing is created until you run the commands yourself | no |
| Stand up a test environment the team keeps | `pilot operate test-env --from <space> --name <short-name> --owner <who>` | a long lived copy with a delete gate so it is not removed by accident, plus the way back out | operate-sandbox plan (`--json`); see [`TEST_ENVIRONMENTS_AND_SANDBOXES.md`](TEST_ENVIRONMENTS_AND_SANDBOXES.md) | no |
| Send one change out in stages, safest first | `pilot operate rings --change <change.json> --targets <targets.json>` | the rings in order, the exact cub commands for each one, what ConfigHub checks before the next ring, and what you are approving | ring plan (`--json`); see [`STAGED_ROLLOUTS.md`](STAGED_ROLLOUTS.md); nothing runs until you run it | no |
| Say whether the ring that just ran really landed | `pilot operate rings --step --plan <plan.json> --health <observation.json>` | PASS and the next ring's commands, or WATCH or BLOCK with the reason; a target that quietly did not change is never a pass | ring plan with its step result (`--json`) | no |
| Check for drift before you promote | `pilot operate drift-check --observation <observation.json>` | whether the cluster still matches what was released, field by field, and either a clear way forward or the exact read that is missing | promotion-drift-precheck card (`--json`); nothing is read live and nothing is promoted | no |
| See the way back out of a change | `pilot operate undo --receipt <receipt.json>` | which way back applies to that change, the exact commands in order, and what putting it back does not cover | change-undo card (`--json`); nothing is restored until you run the commands yourself | no |
| Plan a dependency-aware teardown | `pilot teardown-plan --space <space>` | what must be removed, in what order, and what would be left behind | teardown-plan receipt (`--json`) | yes |
| See what a promotion would move | `pilot promotion-analyse --fixture compatibility` | the promotion's scope and gates before anyone approves it; use `--snapshot <typed.json>` for your own snapshot | promotion-analyse receipt (`--json`) | no |
| Analyse your own promotion path from saved reads | `pilot promotion-analyse --print-reads --component <name>`, then `pilot promotion-analyse --reads <folder>` | the read-only cub commands to run and where to save each; then which Space is behind the one it takes from, what is unreleased, which workflows and approvals exist, the next promotion to consider, and every missing read named as a gap | the same promotion-analyse record (`--json`); Pilot runs none of the reads | no |
| Compare a promotion path before and after a change | `pilot promotion-analyse --before <folder> --after <folder>` | which findings cleared, which appeared, which measured facts changed, and whether the earlier recommendation fits the later state; `--preview 1` with `--reads` prints the recommended promotion as a cub dry run instead | promotion before/after receipt (`--json`); it never claims the change caused the difference | no |
| Work one job with another person or agent | `pilot pair-relay start` | a shared governed session where steering, approvals, and receipts stay visible to both sides; `join`, `send`, `poll`, and `end` follow | relay transcript and receipts | no |
| Test an app idea before building it | `pilot app-idea-scenarios --query '<workflow>'` | the scenarios that would have to hold for the idea to be real | scenario list (`--json`) | yes |
| Act on an existing GitOps app | `pilot gitops-app-actions --evidence-packet <packet.json>` | the actions that app supports without taking ownership from its controller | actions receipt | no |
| List the Spaces in one scope | `pilot spaces --component <component> --select Slug,Labels` | the Spaces that match one component or owner scope, so you can pick which to review or trace | spaces receipt (`--json`) | no |
| Choose a Space from saved results | `pilot ask "help me choose a Space" --spaces-receipt <receipt.json> --expected-org <org>` | Space names Pilot read earlier for the same organization, so you can choose which to review | a saved answer (`--json`); no live read to suggest names | no |
| Name a failure from what you saw go wrong | `pilot classify-failure "<what happened, in your own words>"` | which named failure class matches, how serious it is, and the safe next move — or an honest "no match yet" | classifier output (`--json`) | no |
| Check an evidence bundle really supports its claim | `pilot evidence-bundle-validate <bundle-directory> --json` | whether the bundle's contents actually back the claim attached to it | validation receipt | no |
| Run only what a human approved | `pilot execute-approved --approval <record.json>` | execution bound to the exact approved record, through the separately authenticated lane; anything else is refused | execution receipt (`--json`) | yes |

A Space is ConfigHub's versioned folder for one deployable thing's config.
Pilot can suggest Space names it read earlier from a receipt, a saved record
of that read. First collect the names for one component using your named
ConfigHub connection and the organization you want to work in:

```bash
pilot spaces --component <component> --select Slug,Labels --cub-context <context> --expected-org <org> --out-dir <receipt-directory>
```

Then give the selection command in the table the resulting `receipt.json`.
Pilot uses only a file you name, written for that same organization within
the last thirty minutes. If the file is missing, unreadable, from another
organization, or too old, it offers no names. Pilot never chooses for you,
and the saved names do not prove you can still access those Spaces. After
you choose one, review the proposed change before taking action. Choose
names in a new ordinary request before preparing a separate target-access
request; these selection flags are unavailable when reopening a saved answer.

For that governed diagnostic, choose the intended ConfigHub context first with
`cub context use <preview-context>`. Pilot then names the organization and asks
you to confirm it. Confirmation binds the destination; it does not approve a
write. The current path blocks before setup because no trusted external approval
verifier exists, so cleanup records `SKIP / NOT_CREATED`.

### Putting a change back, and checking before you move one

Two of the rows above go together, because they sit on either side of a
change. One asks whether it is safe to move a value. The other shows the way
back after you have.

**Before you promote: `pilot operate drift-check`.** A promotion copies a
reviewed value from one environment into another, and it overwrites whatever
is already there. If somebody changed that value by hand where the promotion
is going, the promotion takes their change away, and nobody finds out until
something breaks. The check compares what the cluster is running with the
revision ConfigHub actually gave it, and answers one of three ways:

- **NO_DRIFT.** Everything read still matches. Go ahead and propose the
  promotion. One thing to know before you run it: a promotion that moves
  nothing still succeeds. It prints a zero count and exits cleanly, and the
  only reliable sign of what it did is the structured output, where each Unit
  says whether it changed. Pilot reads that and tells you when there is
  nothing to promote, rather than letting a clean exit look like a result.
- **DRIFT_FOUND.** Something differs. The promotion stops, and you pick:
  write the live value back into ConfigHub first so the promotion carries it
  forward, or promote the reviewed value and accept that it replaces the live
  edit. Both come out as exact commands you run yourself.
- **CANNOT_TELL.** Nobody read the cluster, or the Unit has never been
  released so there is nothing for it to have drifted from. This is a stop,
  not a pass. The card names the read that is missing.

The comparison is ConfigHub's own, not Pilot's: `cub k8s refresh --dry-run`
reads one live resource and diffs it against the revision that Unit was last
given. That baseline matters. Comparing against the newest configuration
instead would report every change you have made since the last release as if
the cluster had drifted, which it has not.

**After you change something: `pilot operate undo`.** How you put a change
back depends on what it was wrapped in, and Pilot picks for you:

- A change recorded under a **ChangeOrder** comes out at Space level. You
  record why the change is not coming, preview, then demote.
- A change recorded under a **ChangeSet** comes out with a restore that
  rewinds every Unit that change touched to the state it was in before. The
  restore names those Units, because freeing them from the ChangeSet is what
  closes it, and afterwards nothing carries the ChangeSet for a filter to find.
  Pilot puts that detach in the order when it is needed, and it reads the
  ChangeSet's state from what you recorded rather than assuming it.
- A change wrapped in **neither** has no one-step way back, and Pilot says so
  rather than guessing. This is the reason a promotion is worth wrapping
  before you run it: a promotion that walks its history writes several
  revisions per Unit, so afterwards there is no single "the one before" to
  point at.

**See the objects you would put back.** If you saved the promotion's own
JSON output, use `pilot operate undo --promote-json <apply.json> --changeset
<change-name> --cub-context <context>`. Pilot keeps the object IDs from that
file. To add web links, follow the read-only helper command on its card, then
the printed rerun with `--gui-urls-receipt <file>`. The helper reads the named
context and the exact objects; Pilot refuses a receipt for a different context,
Space or Unit. Sign in to the linked ConfigHub instance with an account that
can read that organisation. These links show where to inspect the objects,
not whether an undo ran. A recorded earlier revision is not proof of the
current revision; use the Unit's Revisions tab to inspect it.

The promotion reading accepts the same kind of helper receipt:
`pilot promotion-proof --promote-json <apply.json> --cub-context <context>
--gui-urls-receipt <file>`. Its lookup includes every Unit shown on the card,
including unchanged Units. Repeat the receipt flag for each Space in a
multi-Space result. Keep the named context when following its printed undo
command; each command selects just the Space it names. A missing recorded ID
is an evidence gap, not proof that an object does not exist.

**Check that the undo really undid it.** A restore that selects nothing still
exits without an error and reports that it updated 0 Units, which reads like it
worked. Save what the restore printed and hand it back:
`pilot operate undo --observation <what you recorded> --restore-result <that
file>`. Pilot compares it with the Units the change touched and calls a restore
that moved nothing a failure, not a success.

Five things an undo does not do, all of which Pilot prints every time:

1. **It does not reach your cluster.** Putting Units back changes ConfigHub.
   The cluster keeps running what it was last given until somebody publishes
   a release, which is always proposed as a separate, separately approved
   last step. That release carries every deployable Unit in the Space, not
   only the ones you put back, so read what else is in it.
2. **It does not delete.** A Unit the change created is rewound to empty, so
   it holds nothing, but it is still there. Removing it is a separate command
   Pilot lists on its own rather than folding into the steps, so nobody
   deletes a Unit by working down a list.
3. **It can take other people's work with it.** If somebody changed a Unit
   after the change you are undoing, putting that Unit back drops their
   change too. Pilot lists those changes and asks before proposing anything.
4. **It can un-protect a path.** Putting a Unit back also puts back the
   record of which of its paths were protected, so a path somebody protected
   after the change can come back unprotected.
5. **It does not let you simply promote again.** This one surprises people, so
   read it twice. Putting the content back does not move the marker ConfigHub
   keeps of how far this environment has taken the one above it. That
   environment still counts as level with where the change came from, so
   promoting again straight afterwards moves nothing and still reports
   success. An undone promotion cannot simply be re-promoted. There are two
   ways to put the change back on, and Pilot prints both: change the value
   upstream again so there is something newer to carry, or restore forward to
   the point where the change arrived. Upgrading from upstream does not help,
   because it compares the same two numbers. This was seen on a real
   organisation on 2026-09-17, and it applies to the restore route; undoing at
   the whole-environment level moves those markers itself.

Both doors read a typed file describing what was seen; neither contacts
ConfigHub or a cluster itself. Both stop at a proposal. Running a command
that writes to ConfigHub is your step, not Pilot's.

### Analysing your own promotion path, and comparing before and after

`pilot promotion-analyse --fixture compatibility` shows the analysis on a
made-up example. To analyse your own Component, Pilot needs to see it, and it
never reads ConfigHub by itself. You run a few read-only commands, save what
each one prints, and hand Pilot the folder.

**1. Ask for the reads.** `pilot promotion-analyse --print-reads --component
<name>` prints two commands: one reads the Component, one lists its Spaces
(each Space is one environment, such as base, dev or prod). Save each output
under the file name the card gives, in one folder. Then ask again with the
folder, `pilot promotion-analyse --print-reads --reads <folder>`, and Pilot
prints six more reads for every Space: its Units and their revision numbers,
its Links (which Space it takes changes from), its ChangeWorkflows, its
ChangeOrders, its latest approvals and other Attestations, and its latest
Releases. Add `--cub-context <name>` to have your context written into every
command.

Every read asks cub for only the fields Pilot uses. On cub v0.6 a full
`-o json` read of a Unit or a Target also printed the Target's worker record,
the worker's secret included, so Pilot never prints one. From cub v0.8 a Target
row carries no worker record, but Pilot still prints no Target read at all,
because no narrowed Target read has been reviewed yet, and the card says so.
If you hand back a full body anyway, Pilot keeps no copy of the secret
and names the file, but the file on your disk still holds it: keep that folder
private.

**2. Analyse the folder.** `pilot promotion-analyse --reads <folder>` builds
the analysis from what you saved. It shows the promotion path from the Links,
which Space is behind the one it takes from and by which Units, what has
changed since the last release, whether a ChangeWorkflow applies, and the one
next promotion to consider. A file that is missing or cannot be read becomes a
named gap on the card, never a guess. On this card PROVEN means a Space holds
what the Space above it holds now, in ConfigHub. It is not a release, a sync,
or a health check.

**3. Preview one recommendation.** `pilot promotion-analyse --reads <folder>
--preview 1` prints the recommended promotion three ways: the dry run you can
run to see what would change (`cub variant promote <space> --dry-run -o
mutations`), the approval route (`pilot execute-approved --prepare-promotion`),
and the change itself for reference. Pilot runs none of them. The change goes
only through named approval.

**4. Compare before and after.** Save a fresh set of reads in a new folder
after the change, then run `pilot promotion-analyse --before <old folder>
--after <new folder>`. Either side can also be a typed snapshot or a saved
`--json` analysis record. The receipt lists the findings that cleared, the
ones that appeared, the measured facts that changed, and whether the earlier
recommendation fits the new state. If later evidence is missing, a finding
stays unresolved rather than being counted as cleared. A recommendation does
not match when its source has changed since the earlier reading.
It does not prove the change caused the
difference: somebody else, or something else, may have changed the same
Spaces in between.

## What has been proven live, and what has not

This section is written from real runs against a real ConfigHub server and real
Kubernetes clusters, not from intent. Each claim names what was done.

**Proven live, in a trial organisation and on local clusters created and deleted
by the run:**

- A repository read, an import plan followed as printed, and the Spaces and
  Units it promised created: three Spaces and nine Units, matching the plan.
- A change promoted to one environment only, with the preview and the apply
  carrying the same plan identifier, and the other environment untouched.
- A promoted change reaching a running cluster and moving a live object, with
  ConfigHub recording the Space as released and its live reading as healthy.
- The same change undone, with the object back to its earlier value, and Pilot
  checking the restore from the restore's own output rather than assuming it.
- A staged rollout across three clusters under ConfigHub's own change workflow:
  each ring promoted, released and read back, with the server's entry gates
  opening for the later rings and refusing one when a cluster was unhealthy.
- Stopping a rollout part way and picking it up again on the same receipt, and
  a changed scope refusing the approval that no longer covers it.
- An Argo app of apps that Argo already ran from Git, handed over to ConfigHub:
  the hand-applied root retired without deleting its children, both child
  Applications brought under ConfigHub unchanged, and one child switched to
  ConfigHub's release with the same pod running before and after, while the
  other child stayed on Git. A later upstream update then reached it with a
  locally protected setting kept, the withheld change recorded as a conflict,
  and an approval recorded. The update was then undone through Pilot's own undo
  step, with the protected setting still in place, and the child was handed
  back to Git in one step, running from Git again afterwards.

**Proven live in v0.6.1, with limits.** The runs above used the ConfigHub
version current at the time. For v0.6.1, three scenarios were run end to end on
current ConfigHub, on one local practice cluster with several namespaces
standing in for environments, Argo CD only, and commands a person reviewed and
ran:

- A promotion in ordered rings.
- A vulnerability fix pinned by image digest, with one environment held back by
  a guard. This was a real but partial remediation: the newer image still
  carries known high-severity findings, and the scan is only as fresh as its
  database.
- An access reduction, checked with before and after permission reads.

**Not proven, and said so wherever it matters:**

- The handoff was proven on the children of an app of apps. A single
  Application with no root, and an ApplicationSet root, were not run live; the
  plan says it does not cover an ApplicationSet root.

- On current ConfigHub, a rollout across more than one cluster and an undo
  have not been run again. Flux delivery and unattended or delegated execution
  have not been run live at all.
- Approval is the ordinary interactive kind: Pilot shows one exact command and a
  person approves it where they already approve commands. Pilot's own delegated
  execution still stops, because a delegated approval would have to be
  authenticated outside anything a model can write, and that is deliberately not
  part of this release.
- A drift reading tells you what a person changed and what the Kubernetes API
  server filled in, separately. It is a reading, not a guarantee, and it says
  when it cannot tell.
- Scoring claims come from receipts and the release ledger, never from this
  page.
