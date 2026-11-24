---
shelf: product-doctrine
status: current
audience: users
owner: pilot
portable: true
package: pilot-corpus
used_by:
  - docs/user/HOW_PILOT_WORKS.md
  - docs/user/PILOT_MANUAL.md
  - docs/user/README.md
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tests/test-pilot-manual-spine
  - tests/test-pilot-startup-surface
  - tests/test-pilot-doc-reference-integrity
  - tools/audits/audit-md-corpus-shelves
retrieval_triggers:
  - what users see
  - cockpit
  - Pilot UI
  - Pilot UX
  - activity lanes
---

# What You Will See

Status: current user-facing UI and UX guide

Pilot should feel like an operating cockpit, not a pile of commands. The user
can speak in ordinary language, and Pilot should show the route, risk, proof,
and next action before asking the user to trust a result.

Pilot includes OPERATE, FIX, and AUTOMATE routes; it is not only a discovery
tool. It inspects first and previews the exact scope. One literal context-bound
command in the reviewed ConfigHub subset may then go to host review, followed by
read-only verification and a receipt. Host allow authorizes only the attempt.
Exact-artifact, unattended, delegated, destructive, bulk, credential,
Kubernetes, and executable effects retain their stronger typed stops; a
read-only first step is the beginning of the loop, not a false claim that the
write already ran.

Every Pilot screen renders from the same state, but it has three human-facing
forms:

- **Short Card:** quick route, gate, blocker, or status moment.
- **Progress Card:** default closeout for meaningful work;
  shows progress, proof, uncertainty, next action, and a shareable summary in a
  rich cockpit card or a plain-text fallback.
- **Engineer And Automation Detail:** full cockpit and JSON detail for agents,
  maintainers, CI, receipts, lanes, and rerun commands.

Short cards, Progress Cards, and engineer detail should never invent
separate truth. They are different views over the same route, proof, receipt,
and next gate.

### Quiet mode

QUIET is a presentation density across those same views, not a fourth truth or
a weaker safety mode. It begins with one concise acknowledgement, then speaks
only when the route needs a decision, exact approval, blocker, material state
change, proof summary, review or receipt locator, or final next action.

Use `pilot --quiet <command>` for one invocation, or set
`PILOT_UI_DENSITY=quiet` for a session. QUIET does not alter JSON, engineer
detail, receipts, durable traces, exit semantics, approval scope, stop rules,
or proof requirements. `ASK`, `BLOCK`, stale approval, changed scope, and
missing proof must remain visible. Asking for the full cockpit or engineer
detail reprojects the retained state; it does not rerun the operation.
An explicit full-cockpit request, including `--density full` on the shared
renderer, overrides a session-level quiet preference.

Content that you explicitly request, such as a manual chapter, catalog,
report, or JSON document, is still shown in full; QUIET removes incidental UI
noise rather than deleting the answer.

The human does not need to remember flags or tier names. Calm cards end with
two ordinary-language affordances:

```text
Want a deeper view?
- Say: "Pilot, show me the full cockpit."
- Say: "Pilot, show engineer details."
```

Pilot maps those phrases to the long cockpit and structured machine view for
the current project. The exact `--render-cockpit` and `--json` commands remain
in the underlying state for agents and automation.

## Scope-Aware Absence

A missing live surface is a proof gap only when that surface is relevant to
the current claim. During an empty-folder or local-only first step, the human
screen says **not checked** or **not needed yet**. It must not show
`GUI_URL_UNVERIFIED`, `UNKNOWN_NO_REVISION`, helper names, absolute local paths,
or other machine sentinels as if something failed. Those details remain in the
JSON or engineer view.

This distinction is load-bearing:

- **not applicable:** no live object is in scope yet;
- **not checked:** a live object may matter later, but this step only read
  local files;
- **proof gap:** the current claim requires that surface and its evidence is
  missing.

Default local screens should stay short enough to scan, name what Pilot did,
say what it deliberately did not inspect, give one next action, and offer the
two spoken drill-down choices above.

## ASCII And Colour

Status: Active / Contract

ASCII structure and restrained ANSI colour are part of Pilot's identity. They
are not optional polish on top of an otherwise complete wall of text. The
terminal surface should make route, authority, approval, progress, and proof
relationships visible before the user has to parse the words line by line.

The design rule is:

> ASCII carries the structure. Colour carries emphasis. Text carries the
> claim.

That gives Pilot a memorable terminal voice without making safety depend on a
particular terminal, theme, or escape sequence.

### The visual vocabulary

| Element | Default treatment | Plain / narrow fallback |
|---|---|---|
| Pilot surface chrome | ice blue frame | the same box and title labels |
| Startup readiness | phosphor green | `PILOT CORE/ADAPTER READY` or verified `PILOT READY`, plus the three stable lines |
| Numbered section | warm yellow headline rule | the uncoloured heading and rule |
| `PASS` / proven | green plus the verdict word | `PASS`, `OK`, or `Proven` |
| `WATCH` / incomplete | amber plus the verdict word | `WATCH` or `Not yet proven` |
| `ASK` / approval | cyan or amber plus the approval question | `ASK` and exact scope |
| `BLOCK` / unsafe | muted red plus the stop reason | `BLOCK` and exact reason |
| ConfigHub or live-system lane | stable lane label and lane colour | `CH-READ`, `CH-WRITE`, `LIVE-READ`, and so on |
| URL | cyan, underlined, clickable when supported | full copyable URL plus `Shows` / `Does not prove` |

Use one restrained structural accent colour in a screen, then add semantic
outcome colours only where they answer a different question. Outcome colour
wins over decoration: a red `BLOCK` must never look successful because it sits
inside green or blue chrome.

### The ASCII grammar

Use a small, stable set of forms:

```text
+------------------------------------------------------------------------------+
| PILOT COCKPIT // APPROVAL                                                    |
+------------------------------------------------------------------------------+
| Scope    one Unit, one reviewed revision                                     |
| Next     approve this exact change or stop                                   |
+------------------------------------------------------------------------------+

-- 01 :: ROUTE ---------------------------------------------------------------
pilot
  |-- intake
  |-- scenario: promote a proven change
  |-- approval: exact revision
  `-- proof: ConfigHub -> controller -> runtime

controller proof  [################....]  4/5
runtime proof     [########............]  2/5

fix   bind the missing runtime target before calling the change live
note  ConfigHub revision proof is already complete
```

- Light boxes are recurring content cards.
- Heavy or high-contrast trust moments are reserved for approval, mutation,
  blocker, and proof punctuation; they should not frame every paragraph.
- Numbered headline rules make a long screen read top to bottom.
- `|--` / ``--` trees show route, scenario, worker, and proof relationships.
- Fixed-width bars compare progress, cost, evidence, or coverage without
  resizing the surrounding layout.
- `fix`, `note`, `boundary`, and `next` lines turn telemetry into a conclusion.

Full cockpit output may use Unicode box characters when the terminal supports
them. `--ascii-fallback` and `CONFIGHUB_ASCII_FALLBACK=1` force `+|-` forms.
`--plain`, `NO_COLOR`, non-TTY output, and narrow captures must preserve every
label and verdict without ANSI escapes. `--force-color` is the explicit
show-and-tell override when output is captured by a colour-capable host.

### Motion and progressive disclosure

Pilot acknowledges the user before any long scan. During a long operation it
updates one stable progress region when the host supports it, rather than
printing a new dashboard on every poll. Logs and non-interactive output remain
append-only and plain. Animation never hides a wait, blocker, approval, or
final receipt.

The first screen shows the job and next proof. The Progress Card adds humane
proof and open work. The full cockpit adds numbered sections, trees, bars,
lanes, URLs, and engineer detail. This is progressive disclosure over one
state object, not three competing products.

### Recovery moments

The same renderer owns normal progress and recovery. A flat screen, silent
wait, resumed session, or interrupted run does not need a separate prompt
library or a second dashboard:

| Moment | Cockpit trigger | Required result |
|---|---|---|
| First contact | `welcome` | Full identity, five capabilities, current world, and first job. |
| New stage | `stage` | Compact route, current work, boundary, and next proof. |
| Human decision | `approval` | Full exact scope, reviewed revision, what changes, and one question. |
| Evidence check | `verify` | Full proof rows, omissions, GUI URL or named gap, and next gate. |
| Unsafe or impossible path | `blocker` | Full stop reason, what remains safe, and recovery action. |
| Completed run | `closeout` | Full outcome, receipt, reusable lesson status, and handoff. |
| Long or silent wait | `periodic` | Compact fresh facts and the condition Pilot is waiting for. |
| User asks where they are | `request` | Full current cockpit without restarting the route. |

In QUIET, the same moments collapse to one status line plus only the
decision-bearing rows. Approval and blocker moments still name exact scope and
one next action; verify and closeout still name the proof summary and available
review or receipt locator.

Recovery rehydrates typed route, approval, and proof state. It never infers
success from elapsed time, a previous chat message, or a process restart. If
the required state cannot be recovered, the cockpit says `WATCH` or `BLOCK`
and names the missing evidence.

## When A Pilot Claude Session Opens

Status: Active / Contract

After `pilot claude launch` starts an explicitly Pilot-bound session, Pilot
says hello before asking you to understand its commands. You should see two
immediate signs that the Pilot surface was presented. An ordinary `claude`
session does not receive this surface from the canonical Pilot core install.

First, Claude's status area shows a green three-line strip:

```text
PILOT CORE/ADAPTER READY | ConfigHub: helm-catalog | project: my-service
COCKPIT | hooks + GUI handoffs | ConfigHub skills enabled; selection not yet observed | K8s: local-cluster | Pilot <version>
START | 1 TEACH | 2 ONBOARD | 3 SET UP & ORGANISE | 4 DISCOVER | 5 BUILD / OPERATE / FIX / AUTOMATE
```

The names and version will match your machine. If Claude is loading an older
Pilot plugin, this area says **PILOT UPDATE NEEDED** and tells you how to
refresh it. It does not quietly run with a half-updated UI.

The default `CORE/ADAPTER READY` label means the exact Pilot core passed its
local launch checks; it does not prove model loading or selection. `ConfigHub
skills enabled; selection not yet observed` means the exact reviewed companion
passed installation and activation checks, but no runtime receipt yet proves
which skill Claude selected. Only that receipt upgrades the labels to `PILOT
READY` and `ConfigHub skills ready`; installation grants no command autoallow
or ConfigHub mutation authority.

The cockpit line means Pilot's hooks and its route to ConfigHub review links
are available. It does not claim that a specific ConfigHub page has already
been checked. Pilot shows the exact page when your chosen task selects or
creates a real object.

Second, Claude shows a short greeting such as:

```text
Hello - Pilot is ready in my-service. ConfigHub context: helm-catalog.
```

The greeting uses Claude's native message style. The strip carries Pilot's
green terminal styling.

When you make your first request, Pilot answers quickly with a compact branded
Short Card before it starts a longer scan. If your request is clear, it begins
that work directly and tells you what useful result will appear first:

```text
PILOT COCKPIT | STARTING
Journey | DISCOVER
Goal | Make this service deployable.
Mode | SINGLE USER
Model | host model - may reason and propose; cannot approve or certify.
Route | project intake and deployability map
Rail | deterministic - inspect local project shape
Lanes | GIT-READ, META
Boundary | READ_ONLY
First useful result | A map of the app and its configuration gaps.
Now | Reading the local project shape.
Approval | Not requested; this step is read-only.
Proof | Not checked yet.
Review URL | Not selected.
Next | Show the map and one safe next action.
```

If you have not chosen a task yet, Pilot offers five grouped starting points and says
what each one will produce:

1. **TEACH**: understand a document or concept, then choose a tutorial, demo, or showcase.
2. **ONBOARD**: choose ConfigHub Cloud or CHE, try `cub`, and reach a first useful result.
3. **SET UP & ORGANISE**: connect or import your system, or review shared knowledge, contexts, users, roles, and work.
4. **DISCOVER**: map what is running, its configuration, and what needs attention.
5. **BUILD / OPERATE / FIX / AUTOMATE**: create or run a governed operational job.

The useful jobs from the previous A-D chooser remain accounted for underneath
these journeys. Its literal letters and numeric aliases are retired; it is not
another active startup menu.

Say "show me more" to open Pilot's full human journey chooser. It includes
TEACH, ONBOARD, SET UP & ORGANISE, DISCOVER, BUILD, OPERATE, FIX, and AUTOMATE,
while preserving the older scenario-level jobs underneath. `ORGANISE` remains
a direct sub-job and alias of SET UP & ORGANISE, not a lost capability. Each choice says
what you will receive and whether it is read-only, writes local review artifacts,
or prepares one eligible host-reviewed ConfigHub attempt; higher-risk effects
ask first, and delegated effects retain their dedicated stop. Say "show me the full cockpit"
or "show engineer details" whenever you want the deeper route,
proof, and receipt view. Pilot may ask one more focused question after a quick
check. That second step is another branded
Short Card with the current goal, the first finding, one recommendation, at
most three relevant choices, and the next proof you should expect. It does not
make you choose from its internal catalog.

```text
PILOT COCKPIT | NEXT
Goal | Make this service deployable.
Found | The repo has a container build but no deployment configuration.
Recommended | Generate a reviewable Base first.
Choices | Generate the Base; connect ConfigHub; inspect relevant examples.
Next proof | A rendered diff and a plain account of what remains unverified.
```

The ConfigHub name in the startup strip comes from your local context. Pilot
checks live authentication and organization identity when your work first
needs ConfigHub. Seeing the startup strip does not approve a change.

### Teaching view

When you say "Pilot, teach me," ask for help understanding a document, or ask
which tutorial to try, Pilot shows a patient teaching card before suggesting
work:

```text
PILOT COCKPIT | TEACH
Subject | Promotions
Source  | READABLE_TEXT | <the source you supplied>
Journey | TEACH
Mode    | SINGLE USER
Model   | <the actual host model>

WHAT THIS SOURCE SAYS
<a plain, source-grounded explanation>

NEXT
Try the smallest matching tutorial
   You get | <the tutorial that matches this subject>
   Try | <the exact command>
   Boundary | Starts read-only

BOUNDARY | Teach is read-only. pilot learn is the reviewed product-memory loop.
Want the other options? Say: show me more, or add --render-cockpit.
```

Add `--render-cockpit` and the card lists every way to continue instead of
just the one.

The terminal card uses colored ASCII when supported and the same labels in
plain text otherwise. Claude or Codex adds the conversational explanation. A
future GUI sibling must use the same teaching packet, cross-references,
learning progression, and action boundary rather than a separate tutorial
database.

## Example Status Legend

The examples below are product UX contracts. They are intentionally concrete,
but they are not all claims that every current command emits the exact same
text today.

| Status | Meaning |
|---|---|
| Active | Current helpers or commands can emit this kind of signal now. |
| Contract | The shape is required by doctrine and tests, but live route coverage is still expanding. |
| Example | A readable illustration of the contract, not retained runtime evidence. |

If Pilot cannot render a promised cockpit, lane, URL, GUI sibling, or proof
row that is required by the current claim, the correct machine result is a
named gap such as `GUI_URL_UNVERIFIED`, `LANE_GAP`, or `WATCH`, not silent
fallback to prose. When the surface is outside the current scope, the human
result is "not needed yet," not a false warning.

## Front Door

Status: Active / Contract

The first screen should make the safe path obvious:

```text
ConfigHub Pilot local front door

Start here:
  First screen:   pilot start --render-cockpit
  Teach me:       pilot teach [<topic-or-document>]
  Product manual: pilot manual --render-cockpit
  First proof:    pilot quickstart --progress-card
  Machine proof:  pilot quickstart --json
  Product map:    pilot catalog --render-cockpit
  Ask Pilot:      pilot ask '<question>' [--progress-card|--json|--render-cockpit]

What you can do today:
  - map this repo and ask for the safe next step
  - turn a repeatable workflow into an app pack or honest blocker
  - inspect install, release, and proof status
  - render cockpit screens before trusting claims

Try asking:
  - Pilot, help me understand this document.
  - Pilot, what tutorial should I try next?
  - Pilot, map this repo and tell me the safe next step.
  - Pilot, is this app healthy? Keep it read-only first.
  - Pilot, make this repeatable as an app.
  - Pilot, show me the evidence and receipt.

Default path is read-only: start -> map -> gate -> proof or stop.
```

The user should not need to know skill names, script names, Rail State, lane
labels, or scenario IDs before getting value.

## Short Card

Status: Active / Contract

Short cards appear at route, approval, verification, closeout, and blocker
moments. They are compact enough for chat, but still show the control state:

```text
+ PILOT COCKPIT | STARTING --------------------------------
Journey | DISCOVER
Goal | Check this app's health.
Mode | SINGLE USER (ACTIVE)
Model | host model - reason and propose; cannot approve or certify its own result
Route | app health check (SELECTED)
Rail | deterministic - compare source, ConfigHub, controller, and runtime
Lanes | GIT-READ, CH-READ, LIVE-READ, PROOF
Boundary | READ_ONLY
Now | Read ConfigHub and controller state.
First useful result | The failing layer and its evidence gaps.
Approval | NOT_REQUESTED - no mutation is proposed.
Proof | WATCH - runtime proof still needs to be collected.
Review URL | RESOLVED - object known; browser verification still separate.
Next | Prove runtime health or name the gap.
```

Short cards answer:

- What is Pilot doing?
- Is the path active, uncertain, or blocked?
- Is this read-only or waiting for approval?
- What proof should the user expect next?

The deterministic renderer is `pilot start --short-card`; use
`pilot start --short-card-json` to inspect the typed
`confighub-pilot.short-card.v1` state. A Short Card is a projection, not a new
state store. Its journey, SINGLE USER / PAIR / TEAM mode, model role, route,
Rail State, activity lanes, action boundary, approval, proof, review surface,
and next action must agree with the Progress Card, cockpit, JSON, and GUI
sibling.

Review URL states are deliberately separate: `PROVIDED` means a user supplied
the URL, `GENERATED` means Pilot constructed a scoped shape, `RESOLVED` means
read-only evidence tied it to the intended ConfigHub object and organization,
and `VERIFIED` means the browser opened that same object. Earlier states never
inherit the claims of later ones.

## Progress Card

Status: Contract

Progress Cards are the default human closeout for meaningful work. They are
not just longer cards and not a raw audit screen. They turn proof rows into a
humane action plan the user can understand, act on, and share. In a terminal or
chat that can support it, the widget may look like a rich TUI-style card. In a
plain channel, it must degrade to the same words without losing meaning.

Pilot is not a GitOps-only product. GitOps/controller delivery is one important
lane, but the same Progress Card applies to operational app generation,
workflow scenarios, live proof receipts, benchmark closeouts, approvals,
onboarding, and other ConfigHub-governed operations.

Use a Progress Card when Pilot has done enough work that the user needs to
know:

- what the goal was;
- how far Pilot got;
- what is proven;
- what is not yet proven;
- what failed or blocked progress;
- what the one recommended next action is;
- what summary can be safely shared with another human.

Good Progress Cards use plain human status, not machine vocabulary:

| Machine state | Human status |
|---|---|
| `PASS` | Ready to share; Ready for review. |
| `WATCH` | Not ready for production; Partly proven; Needs more proof. |
| `ASK` | Needs your approval; Needs a scope decision. |
| `BLOCK` | Blocked by missing proof; Do not proceed yet. |

Friendly language is still accountable language. If the widget says Pilot made
the work faster, better, safer, immediate, live, or production-ready, the
engineer detail must contain the check or comparison that makes that true. If
that check does not exist, the human card should say the claim is not measured
or not proven yet.

The human surface itself is judged by the same standards as the underlying
proof: it must orient the person, separate proven work from open work, give one
next action, and keep a `WATCH` result incomplete.

Safe Actions use the same Progress Card shape before any live change. The
human sees the matched action, direct fallback, proof gaps, action plan, and
shareable summary. Function names and rerun commands stay in the engineer
detail:

```text
Pilot progress - Safe Actions - Change replica count    Safe action path selected

Find a narrow ConfigHub change path while keeping live proof gaps visible.

Pilot matched the request to a known action. Local planning is done; rollout
proof still needs real object, approval, controller, runtime, GUI, and receipt
evidence.

oooo...  4 of 7 safe-action checks done

Proven
+ The request matched Change replica count.
+ Pilot kept this as a planning surface; no live systems changed.
+ An optional typed operation path exists for this action.
+ A direct ConfigHub edit remains available.

Not yet proven
o The app and target environment have not been selected.
o The diff and validation checks have not run on a real object.
o Approval, controller delivery, runtime evidence, GUI URL, and receipt proof
  still need to be attached before a live claim.

Action plan
+ Match the request to a Safe Action
+ Keep live systems unchanged while planning
> Choose the app and target environment
o Preview the diff and validation checks
o Ask for approval before any rollout
o Prove controller delivery and runtime result

Share this
Pilot matched this request to a narrow ConfigHub change path. Nothing live
changed. The next step is to choose the app and target environment, preview the
diff and checks, then decide whether to approve rollout proof.
```

Reference rich-card shape:

```text
+------------------------------------------------------------------------------------------+
| Pilot progress - Governed change    Not ready for production                            |
|                                                                                          |
| Change staging replicas from 1 to 2, without touching production.                        |
|                                                                                          |
| The local render and blast-radius checks are done. The live rollout still needs to       |
| happen.                                                                                  |
|                                                                                          |
| oooo..  4 of 6 checks done                                                               |
|                                                                                          |
| Proven                                                                                   |
| + The chart rendered from the pinned version.                                            |
| + Exactly one object changed.                                                            |
| + The changed field is the replica count.                                                |
| + Pilot re-ran the check itself, and it held.                                            |
|                                                                                          |
| Not yet proven                                                                           |
| o Production scope - dev and prod have not been compared yet.                            |
| o Live rollout - Argo has not applied this to a cluster.                                 |
|                                                                                          |
| Action plan                                                                              |
| + Render pinned chart                                                                    |
| + Check blast radius                                                                     |
| + Re-run self-test                                                                       |
| > Compare staging and production renders                                                 |
| o Publish through ConfigHub                                                              |
| o Verify Argo or Flux rollout                                                            |
|                                                                                          |
| Do this next                                                                             |
| > Compare staging and production renders, then publish through ConfigHub if the scope is |
|   clean.                                                                                 |
|                                                                                          |
| Share this                                                                               |
| Pilot verified a narrow staging replica change locally: one field changed, nothing else  |
| moved, and the check re-ran cleanly. It is not ready to call live until production scope |
| and controller rollout are proven.                                                       |
|                                                                                          |
| Want a deeper view?                                                                       |
| Say: "Pilot, show me the full cockpit" or "Pilot, show engineer details."                 |
+------------------------------------------------------------------------------------------+
```

The action plan checklist is part of the feature:

```text
Action plan
+ Render pinned chart
+ Check blast radius
+ Re-run self-test
o Compare dev, stage, and prod
o Publish through ConfigHub
o Verify Argo or Flux rollout
o Capture runtime proof
```

The full doctrine and rollout plan live in
`PILOT_PROGRESS_WIDGET.md`.

## Long Screen

Status: Active / Contract

Long screens are the engineer and automation detail tier. They are for
orientation, complex approvals, multi-layer proof, app workflows, review,
audit, or replay. They should not just be a larger card; they should organize
the state into areas a user, reviewer, or agent can scan:

- numbered sections make the explanation grow in a deliberate order;
- simple trees show scenario, route, subagent, and proof relationships;
- fixed-width bars compare evidence, cost, or progress without shifting layout;
- one restrained structural accent colour marks active labels and decisions,
  while green, amber, cyan, and red retain their semantic outcome roles;
- explicit `fix`, `note`, and boundary lines turn the screen into a conclusion,
  not a wall of telemetry.

The plain-text form keeps the same hierarchy without relying on ANSI colour.
This richer visual grammar belongs in the full cockpit or a published
show-and-tell artifact; it must not delay the immediate short response.

To inspect the first-minute start cockpit without live mutation:

```bash
pilot start --render-cockpit
```

To inspect the current quickstart human card without live mutation:

```bash
pilot quickstart --progress-card
```

To inspect the current quickstart long screen:

```bash
pilot quickstart
```

To inspect the Day-0 map long screen for the current work repo:

```bash
pilot map . --render-cockpit
```

To inspect a route decision as a long screen:

```bash
pilot route "Can I promote staging to prod?" --render-cockpit
```

Proof-level coverage, statutory checks, corpus audits, and adapter routing are
maintainer surfaces. Their gallery and command examples live in the
the engineering cockpit audit
engineering guide; the user route remains the ordinary-language front door.

To inspect repeatable operational app seeds as a long screen:

```bash
pilot operational-app-inventory --render-cockpit
```

To inspect an operational app-pack handoff as a long screen:

```bash
pilot operational-app-pack \
  --query "nightly database backup restore verification drill with evidence receipts" \
  --out-dir /tmp/pilot-app-pack-cockpit \
  --render-cockpit
```

To inspect the standalone app export gate as a long screen:

```bash
pilot operational-app-export \
  --query "certificate expiry" \
  --destination-repo /path/to/repo \
  --app-dir certificate-expiry-app \
  --render-cockpit
```

To inspect the public review ledger as a long screen, use the user-facing
`pilot review-packet --render-cockpit` route. Portable install and publication
channel checks remain maintainer work; their examples are in the engineering
guide linked above.

To inspect the public review ledger as a long screen:

```text
PILOT COCKPIT // REVIEW PACKET: WATCH
Rail:      deterministic | review-packet | step 5/5
Progress:  manual -> proof-ledger -> watch-rows -> release-gate -> next-proof
Lanes:     META, PROOF, GUI, LIVE-READ
GUI:       Review packet cockpit - READY
Proof:     review packet READY, remaining WATCH rows named,
           channel publication NOT_SCORED and separated from product-health rows
Next:      use WATCH rows as the working queue; do not claim public PASS
           until the named proof row is green
```

To inspect scenario sendability as a long screen:

```bash
pilot scenario-catalog
```

Benchmark closeout is a maintainer check. Ordinary outcome review starts with
`pilot review-packet`; that command does not score benchmark results.

```text
PILOT COCKPIT SCREEN

Route
  need:       diagnose app health
  strategy:   ConfigHub-governed controller path, read-only first
  rail:       deterministic helper, step 3/5

Scope
  repo:       supplied by caller workdir
  ConfigHub:  URL pending or explicit GUI_URL_UNVERIFIED
  runtime:    controller/runtime proof not yet claimed

Activity Lanes
  LANE       SIGNAL                  RESULT   MEANING
  META       request classified       PASS     route and rail selected
  CH-READ    ConfigHub read planned   READY    safe to inspect governed state
  LIVE-READ  runtime read planned     WATCH    needs real context or receipt
  PROOF      proof rows required      READY    no success claim without rows

Proof Rows
  layer       status   evidence
  ConfigHub   WATCH    URL or object proof not attached yet
  controller  WATCH    source and revision not verified yet
  runtime     WATCH    exact field/resource not verified yet

Next Gate
  Run the read-only proof helper, or stop and ask for the missing object.
```

Color, if available, is an enhancement. The plain labels must remain stable so
logs, copied output, and non-color terminals still make sense.

## Activity Lanes

Status: Active / Contract

Activity lanes show which authority a step touched. Rail State says where the
run is; lanes say what worlds the run touched.

```text
LANE       SIGNAL                  RESULT   MEANING
META       intent classified        PASS     no external read yet
GIT-READ   repo inspected           PASS     source shape found
CH-READ    ConfigHub object read    PASS     governed state read only
CH-WRITE   proposed mutation        ASK      waits for scoped approval
EXT-WRITE  local/Git/OCI write      ASK      waits for scoped destination and approval
LIVE-READ  controller/runtime read  WATCH    proof missing or partial
PROOF      receipt written          PASS     evidence retained
LANE_GAP   lane source missing      WATCH    do not claim complete proof
```

`CH-WRITE` or `EXT-WRITE` lanes must not appear as completed work unless the
approval scope, destination, and proof path are explicit.

## Approval Gate

Status: Active / Contract

When a task could mutate state, Pilot should stop with one clear question:

To inspect the current mutation gate cockpit without executing the proposed
command:

```bash
pilot gate --command "kubectl apply -f app.yaml" --render-cockpit
```

For a contracted mutation, approval readiness also binds the exact object and
scope, expected and freshly observed revisions, current and reviewed change
digests, approval time and expiry, and an idempotency key. Missing evidence
stays `ASK`; complete matching evidence is still `ASK` with
`READY_FOR_EXACT_APPROVAL`, never terminal permission to mutate. A revision
race blocks with `EXPECTED_REVISION_MISMATCH`, a same-numbered revision that is
no longer the reviewed one blocks with `EXPECTED_REVISION_ID_MISMATCH`, a
changed reviewed digest blocks with `APPROVED_CHANGE_CHANGED`, and an expired
approval blocks with `STALE_APPROVAL`. In each case Pilot says plainly that it stopped before
applying and retains the compared values in machine detail.

```text
APPROVAL GATE | decision: ASK | mutation: blocked
scope: one governed object, one proposed field, one delivery path
risk: controller and runtime proof still required after apply
will change: proposed ConfigHub data only
will not change: Git, Kubernetes, or external systems without a later gate

Approve this exact scoped change? Y/N
```

If a fallback changes scope, resource, provider, target, or delivery path,
Pilot must ask again. The same applies when the object revision or change
digest changes, or when the approval window expires. A local receipt or local
artifact is never evidence that the requested live change was applied.

## Proof Receipt

Status: Active / Contract

Closeout should separate proof from non-claims:

```text
RECEIPT | result: WATCH | route: read-only app health

proved:
  - request classified
  - safe route selected
  - no mutation performed

not proved:
  - ConfigHub object URL
  - controller consumed the expected source
  - runtime field changed or stayed healthy

next:
  attach the missing ConfigHub URL or run the read-only proof helper
```

`PASS` requires the required proof layers to agree. A useful partial result is
`WATCH`, not a fake success.

## GUI Sibling

Status: Contract

A GUI sibling is an app-like projection over the same Pilot state. It must not
invent a separate truth.

The portable GUI-sibling gallery is a maintainer surface. Its command examples
and proof boundary live in the
the engineering cockpit audit
engineering guide.

```text
PILOT COCKPIT // GUI SIBLING GALLERY

Rail
  mode:      deterministic
  position:  step 4/4, render sibling gallery
  now:       core, capability, and pack siblings indexed
  next:      choose the sibling that needs live proof or richer cockpit coverage

Lanes
  META:      gallery record generated
  PROOF:     sibling rule checked
  GUI:       gallery projection visible
  LIVE-READ: live bindings not read by this command

GUI
  GUI sibling gallery: READY
  ConfigHub live GUI proof: WATCH

Action Boundary
  mode:      REVIEW-ONLY
  executes:  no
  handoff:   pilot execute-approved with the exact review envelope; currently BLOCK pending external approval authentication

Blocked Actions
  claim complete GUI product coverage from this repo-only gallery
  treat a GUI sibling as proof when URL, approval, receipt, or runtime evidence is missing
```

The GUI sibling should help the user see and do the workflow. Every sibling
must say either `REVIEW-ONLY` or name the exact governed handoff to the shared
`pilot execute-approved` path and its current authenticated-approval blocker. A
browser surface never gets a parallel mutation engine or independent authority.
The externally authenticated approval envelope, receipt, and proof rows remain
authoritative.

## App Intake Gate

Status: Active

When a user asks Pilot to make an operational app, the first visible result is
an app-pack gate, not a generated repo. This keeps app generation from turning
weak matches into polished but wrong output.

```text
OPERATIONAL APP PACK | result: PACK_DRAFT_UNSEEN_REVIEW_REQUIRED
intent: nightly database backup restore verification drill with evidence receipts
route:  unseen operational workflow
now:    draft scenario and proof shape captured
next:   review the generation plan before exporting app code

blocked:
  - do not force-match to a catalog app idea
  - do not export browser/CLI code until the plan is reviewed
  - do not call OAuth success live completion while LIVE_BINDINGS_MISSING remains
```

The human output should make the classifier decision inspectable, not just
store it in JSON:

```text
How Pilot classified this:
- Raw request: nightly database backup restore verification drill with evidence receipts
- Matched object: no strong catalog match
- Confidence: 0.213 / threshold 0.550
- Allowed fallback: DRAFT
- Evidence: app-idea-catalog -> app-idea:cost-management-opencost @ 0.050
- Evidence: customer-scenario-catalog -> scenario:ops-4290-tools-over-config-data @ 0.113
- Evidence: solution-corpus -> solution:proof-closeout-three-layer @ 0.631 (triggers=receipt)
- Missing questions:
  - What is the recurring operational job in one sentence: who runs it, how often, and what changes when it succeeds?
  - What ConfigHub object, view, filter, unit, revision, approval, action, and receipt should be authoritative for this workflow?
  - Which strategy applies: ConfigHub database app, ConfigHub OCI to Argo/Flux, Git to controller, read-only observe, or another governed path?
  - What exact scope must a human approve before mutation?
  - ... 3 more in the manifest
- Verdict rule: the classifier is evidence, not terminal READY; validators and proof gates decide PASS/WATCH/BLOCK.
```

For unrelated requests, the stop should be just as visible:

```text
OPERATIONAL APP PACK | result: PACK_REJECTED_NOT_OPERATIONAL
intent: water the office plants weekly and log it
reason: request is not a ConfigHub, Kubernetes, GitOps, approval, proof,
        or operational workflow
next:   ask for an operational workflow or stop
```

If the pack is ready but export lacks a destination repository, Pilot should
return `APP_EXPORT_BLOCKED` and avoid creating an app directory. A clean block
is better UX than a plausible wrong app.

When Pilot can write a reviewable pack, the long screen should also point to
the generated plan:

```text
GENERATION PLAN | status: PLAN_READY_FOR_BUILDER
domain: NetworkPolicy intent, namespace/workload map, policy impact preview
runtime: browser-oauth | npm run oauth:register | /callback SPA shell
standalone: no Pilot runtime, no lab dependency, no Python server
checks: npm test | npm run verify | npm run oauth:smoke | npm run binding:check
blocker: LIVE_BINDINGS_MISSING until ConfigHub object, Variant, approval,
         governed action, proof receipt, and runtime evidence are bound
```

That screen is still a handoff, not a success claim. The browser app is not
complete until OAuth sign-in, `/api/me`, visible ConfigHub object or verified
URL, Variant scope, approval binding, governed action binding, proof receipt,
and runtime evidence all exist.

The same state can render as a long cockpit screen:

```text
PILOT COCKPIT // OPERATIONAL APP PACK: PACK_DRAFT_UNSEEN_REVIEW_REQUIRED
Rail:      deterministic | operational-app-pack | step 3/6
Progress:  intake -> pack -> plan -> review -> export -> live-proof
Lanes:     META, CH-READ, PROOF, CH-WRITE, LIVE-READ
GUI:       Operational app pack cockpit - READY
Proof:     classifier confidence, missing questions, ConfigHub object spine,
           app code NOT_GENERATED, OAuth client NOT_REGISTERED,
           LIVE_BINDINGS_MISSING
Next:      review the scenario questions before export or live GUI work
```

After a pack is exportable, the export gate has its own long screen:

```text
PILOT COCKPIT // OPERATIONAL APP EXPORT: APP_EXPORT_READY_BROWSER_OAUTH
Rail:      deterministic | operational-app-export | step 5/6
Progress:  intake -> pack -> export -> verify -> live-proof
Lanes:     META, EXT-WRITE, PROOF, CH-READ, CH-WRITE, LIVE-READ
GUI:       Generated browser app - READY
Proof:     app files, npm run verify, GUI_URL_UNVERIFIED,
           LIVE_BINDINGS_MISSING
Next:      register OAuth, sign in, bind ConfigHub object, Variant, approval,
           governed action, proof receipt, and runtime evidence
```

Publication status has the same shape:

```text
PILOT COCKPIT // INSTALL CHANNELS: PILOT_INSTALL_CHANNELS_READY
Rail:      deterministic | release channels | step 1/3
Progress:  metadata -> release-asset -> install-guide -> external-publication -> proof
Lanes:     META, GIT-READ, PROOF, EXT-WRITE
GUI:       Install channel cockpit - READY
Proof:     GitHub Release asset PASS, release SHA256 PASS,
           direct URL install WATCH, external publication WATCH
Next:      use the GitHub Release install path today; keep PyPI,
           Homebrew tap, container, and direct URL claims at WATCH
```

Scenario catalog sendability also renders as a cockpit:

```text
PILOT COCKPIT // SCENARIO CATALOG: PILOT_SCENARIO_CATALOG_PASS
Rail:      deterministic | scenario-catalog | step 2/4
Progress:  structure -> curation -> sendability -> live-receipt -> customer-share
Lanes:     META, PROOF, CH-READ, LIVE-READ
GUI:       Scenario catalog cockpit - READY
Proof:     structure PASS, sendability WATCH, candidate proof gap WATCH
Next:      choose one candidate only after ConfigHub object URL, Variant,
           approval, controller/runtime evidence, GUI proof, receipt, and
           redaction path are known
```

Benchmark closeout makes the claim boundary visible:

```text
PILOT COCKPIT // BENCHMARK CLOSEOUT: FIXTURE BANK PASS (DETERMINISTIC FIXTURE; NOT LIVE OUTCOME)
Rail:      deterministic | scorecard | step 4/5
Progress:  scorecards -> outputs -> blind-scoring -> closeout -> release-claim
Lanes:     META, PROOF, GUI, LIVE-READ
GUI:       Benchmark closeout cockpit - READY
Proof:     fixture bank FIXTURE_BANK_PASS (deterministic; not live proof),
           receipt validity PASS, claim outcome SUPPORTED for fixtures,
           release packet ledger 1 supported / 2 not supported,
           broad product superiority WATCH
Next:      use fixture evidence for improvement; do not claim broad
           superiority without same-task release benchmark proof
```

This benchmark screen is maintainer evidence. It is not an ordinary user
command or proof that a user's own workload has succeeded.

## Good Interaction Shape

A good Pilot run feels like this:

```text
User:  Pilot, make this repeatable as an app.
Pilot: I will plan an operational app pack first. This is read-only.
Pilot: Short card: route active, step 2/5, next proof is app-pack manifest.
Pilot: Long screen: objects, controls, generation plan, proof tabs, blocked actions.
Pilot: Receipt: what was generated, what was not proven, next gate.
```

That is the product identity: plain-language request, visible route, stable
rails, authority lanes, explicit gates, proof rows, and reusable output.
