---
shelf: product-doctrine
status: current
audience: users
owner: pilot
portable: true
package: pilot-corpus
used_by:
  - README.md
  - docs/user/README.md
  - docs/user/PILOT_MANUAL.md
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tools/audits/audit-pilot-doc-discipline
  - tools/audits/audit-md-corpus-shelves
retrieval_triggers:
  - how pilot works
  - fresh claude plus confighub
  - pilot onboarding
---

# How Pilot Works

Status: current reader-facing guide
Audience: new users, evaluators, operators, and colleagues

Read this when the question is:

> What is Pilot, what happens after I type `run pilot`, and how is this more
> than fresh Claude plus ConfigHub commands or just loading skills?

## Short Version

Pilot is an operational harness delivered through a command-line tool and thin
Claude and Codex adapters.

ConfigHub remains the system of record for state, policy, approvals, history,
targets, actions, events, and URLs. Claude or Codex remains the AI runtime.
`cub` remains the ConfigHub CLI. Pilot sits around the AI session and makes the
work repeatable:

```text
Doorway -> Intake -> Route -> Gate -> Run -> Prove -> Learn
```

That means Pilot opens a known runtime surface, reads the user's actual repo,
cluster, ConfigHub URL, or task, chooses a safe route, stops before risky
action, runs only the chosen path, proves the claim, and records what should be
reusable next time.

There are three different maps, and they answer different questions:

- The eight journeys describe **what the user wants to accomplish**.
- The seven-step loop describes **how one job progresses**.
- Six product bands describe **which modular part supplies the value**: jobs,
  trust kernel, providers and add-ons, adapters and UI, skills and reviewed
  knowledge, and proof and receipts.

They are projections over the same typed owners, not competing catalogs. Run
`pilot manual --explain --topic architecture` to see their current readiness
and authority boundary.

## How You Navigate It

The execution loop explains how Pilot does a job. The journey chooser explains
what a person can ask Pilot to help them accomplish:

```text
TEACH -> ONBOARD -> SET UP & ORGANISE -> DISCOVER -> BUILD / OPERATE / FIX / AUTOMATE
```

These are not eight new engines or replacements for old Pilot concepts.
`ORGANISE` remains a discoverable sub-job and alias of SET UP & ORGANISE; it
keeps its own administration, review, approval, and receipt boundary. They are
the human navigation layer over the five durable capabilities (Map,
Automate, Cockpit, Prove, and Concierge), the scenario catalog, Safe Actions,
operational apps, approvals, execution, proof, and reviewed memory. `map`
therefore remains a real capability used by ONBOARD and DISCOVER; it has not
been renamed away.

The two learning verbs are intentionally different:

- `pilot teach` helps a person understand a document or concept and choose a
  useful guide, tutorial, demo, showcase, or scenario. It is read-only.
- `pilot learn` stages a source-backed lesson for review before it can become
  durable Pilot knowledge. A helpful conversation cannot promote itself.

The intended ConfigHub adoption path is concrete: learn enough to choose
ConfigHub Cloud or ConfigHub Enterprise, try the `cub` client in the intended
context, bring in a real system, discover what is running, then build, operate,
fix, or automate a useful job. More reading alone is not a completed journey.

Execution mode is a separate coordinate: SINGLE USER is active; PAIR and TEAM
remain visible with honest proof gaps until their shared ConfigHub graph,
handoff, fork/merge, approval, and receipt paths have been demonstrated live.
PAIR means two people work on different parts of the same job at the same
time and then combine their work in one reviewed merge; approving something
together can happen inside that flow, but the heart of PAIR is fork, work in
parallel, merge. TEAM means several humans and software agents share goals in
one team and work toward them together; it is more than PAIR with extra
approvers. Neither is proven live yet.

Shared observation has a typed boundary. Channel-based agent tools now let a
whole room watch one agent work, and Pilot welcomes that pattern -- watching
is free. Steering is not: a suggestion from anyone in the room is a proposal,
approval still binds one named authority to the exact subject, and the run's
identity never gives its authority away. The shared work object is the
ConfigHub ChangeOrder, whose progress anyone may query; the record of what
happened is receipts bound to revisions, not a chat transcript. Prose you can
search; evidence you can verify. A channel-based agent tool supplies the
session and the observable terminal, and Pilot supplies this boundary on top.
Model identity is also separate. A model may reason and propose, but it never
becomes the approval authority or certifies its own result.

## Three People-Shaped Stories

These stories connect the journey chooser, the eight architecture chapters,
and Pilot's helpful persona. They are product walkthroughs, not new engines or
named-person demos.

### A new user learns by doing

A new user opens Pilot with a document, a question, or no idea where to begin.
Pilot says hello immediately, explains the source in plain English, and
recommends one smallest runnable tutorial or concrete demo. It names what the
experience teaches, whether it uses ConfigHub Cloud or ConfigHub Enterprise,
which `cub` actions the user will see, what remains read-only, and what proof
will appear. Pilot then understands the user's actual need and looks for an
existing scenario, job, guide, or operational app that fits. It shows how that
object maps onto the customer's systems and ConfigHub objects, and adapts it
with the user. Only an honest catalog miss should produce a new inert,
reviewable scenario or app proposal.

For a starting recommendation, ask `pilot ask "what tutorial should I try?"`.
Pilot answers with the tutorial recommendation and explains what it teaches.
It does not start the tutorial; the answer says "No tutorial started."

That fit is an explicit decision, not conversational drift:
`USE_EXISTING`, `ADAPT_EXISTING`, or `PROPOSE_NEW`. In every case Pilot names
the selected scenario, job, guide, or app (or the precise catalog gap), the
first bounded action, and the approval and proof the customer should expect.

After the first experience, Pilot offers the next useful step: bring in one
real project and map what is running, or run the matched job through its next
safe gate. It does not mistake more reading for adoption. A prospective
customer should leave this path having seen something concrete, knowing which
job Pilot recommends, and understanding what ConfigHub will hold, what Pilot
will do, and what independent evidence will prove the result.

Architecture path: router selects TEACH or ONBOARD; the tutorial is a tested
scenario; approval remains absent until a real write is proposed; execution is
bounded; proof shows what the tutorial actually established; learning may
propose a reviewed documentation improvement; the same state renders in chat,
cockpit, and GUI siblings; the roadmap names any live gap.

### Two people fork and reconcile one app

Two people run Pilot in separate AI runtimes against the same governed app.
They share an objective and exact ConfigHub object references, but each keeps
their own authorship and proposal. One person creates a personal Variant and
changes the image; the other proposes a different image or configuration from
the same base revision. Pilot displays both forks, detects any field-level
collision, and asks the humans to choose or revise. It never silently picks a
winner. After review, one exact merge or Promotion is approved, executed
through the supported ConfigHub path, and verified per intended object. The
receipt records who proposed, reviewed, approved, and verified the result.
Today this story is proven only as a read-only contract and fixture proof; no
live two-person run backs it yet.

The merged v0 shared-session contract can already represent participants,
runtimes, roles, exact references, fork ancestry, proposals, collisions,
evidence, and offline fallback. Collision outcomes remain bound to one exact
field and participant-set digest; a later contender makes a prepared resolution
stale, and unrelated fields remain open until separately decided. A retained
PASS names each exact proposal field it selects, requires a verifier other than
that proposal author's retained authority identity, and retains at least one
available evidence item. BLOCKed proposal fields are terminal: they lose any
earlier selection, do not re-enter later collisions, and require a distinct
selected replacement before closeout. Each participant seat also requires a
unique retained authority identity, every later operation must preserve that
identity, and proposals may be published only from the participant's own fork
because v0 has no typed transfer operation. Its authenticated handshake reuses the same
browser surface as ConfigHub operational apps: each client signs in
independently through `@confighub/react-auth`, while `@confighub/api` calls
`/api/me`. A `participant.join` is accepted only when `actor_author_id` matches
the returned `UserID`, the returned `OrganizationID` matches the resolved
shared-session Unit, and the exact OrganizationID, SpaceID, and UnitID agree.
The browser-auth lane derives the participant as human; a caller cannot supply
that classification, and delegated agents use their separate identity route.
Signing in, joining, and becoming paired are separate: PAIR requires two
distinct accepted humans converged on one session version, revision, and digest. Presence
never implies approval. It is currently a read-only contract and fixture proof.
Live ConfigHub persistence and watch, role enforcement, fork/merge execution,
and two-person acceptance remain work for PAIR mode and must be labelled
as such.

Architecture path: router selects PAIR plus the user's job; scenario and app
contracts define the repeatable work; approvals bind the chosen fork and exact
revision; execution performs only that decision; proof checks every intended
object and unchanged exclusion; reviewed learning may retain a reusable lesson;
all surfaces project the same authorship and collision state; the roadmap owns
the remaining live proof.

### A platform team coordinates people and agents

A platform operator uses SET UP & ORGANISE to add a team, select contexts,
assign roles, and define which humans and agents may inspect or propose work.
The team then runs DISCOVER, OPERATE, FIX, or AUTOMATE jobs against shared
ConfigHub configuration and context. Pilot can delegate a bounded read or
proposal to another runtime, record model identity, cost, evidence, omissions,
and checkpoints, and ask an independent verifier to examine the result. An
agent cannot inherit approval, approve itself, certify its own success, or
merge its own work.

ConfigHub owns governed configuration, relationships, revisions, identities,
approvals, durable shared records, and review URLs. Pilot uses those objects to
route the job, preserve context, explain collisions, obtain exact human
decisions, invoke supported operations, and assemble proof. Model runtimes do
the bounded reasoning or execution assigned to them; they are replaceable and
never become the authority.

Architecture path: router composes ORGANISE with the operational journey;
scenarios describe delegable jobs; approvals enforce role and scope; execution
adapters run bounded packets; proof comes from a separately observed verifier and
authoritative systems; memory retains only reviewed knowledge and durable
evidence references; team surfaces show owner and next gate; the roadmap keeps
shared storage and delegated execution behind tested module boundaries.

Across all three stories, Pilot uses one helpful persona. It responds quickly,
explains at the depth the user asks for, recommends one concrete next step,
states facts and unknowns separately, and offers learning or optimisation when
evidence supports it. The persona may teach, propose, compare, and improve. It
may not approve, mutate outside the normal gate, or certify its own result.
Its business job is to help a person move from curiosity to a useful ConfigHub
experience: show a relevant demo, understand the need, reuse or adapt a known
scenario/job/app, and make the next approval and proof easy to understand.

## Five Useful Jobs That Grow With The User

The eight journeys remain Pilot's navigation. The following five jobs are a
showcase and product-value ladder across those journeys and the existing five
capabilities; they are not five more menu items or five claims of completed
live proof.

| Customer job | What Pilot helps the user do |
|---|---|
| **Promotions** | Understand the requested change, explain destination-relative differences and collisions, identify the next eligible transition, and present the exact approval scope. |
| **Stacks** | Discover and author components and integrations, propose logical dependencies, and explain missing or inconsistent configuration. |
| **Fleet rollouts** | Recommend target groups, rings, exclusions, thresholds, and sequencing from topology, risk, and retained outcomes. |
| **Live Ops and CVE remediation** | Correlate findings with the configuration graph, compute the affected set, diagnose blockers, propose remediation, and guide a governed response. |
| **Compatible update delivery** | Infer candidate compatibility from configuration, changelogs, APIs, incidents, and retained outcomes; explain target-specific incompatibilities; and recommend the minimum prerequisite plan. |

The intelligence progression is simple:

> Pilot progresses from explaining, to authoring, to planning, to operating,
> to optimising.

The authority split does not change as the intelligence becomes more useful:

- **ConfigHub** holds governed configuration, relationships, revisions,
  accepted constraints, authority, approvals, and durable operational records.
- **Observer tools** independently report what materialised and what is healthy
  at the exact version and attempt.
- **Pilot** understands the job, reasons over the graph and evidence, proposes
  the next safe action, obtains approval, invokes supported ConfigHub
  operations, and explains the outcome.

The proposing model does not become the authority or certify its own success.
Each job should be labelled `SHIPPED`, `DESIGNED`, or `LIVE-PROVEN` at the
specific step being shown.

## Explain One Architecture Chapter

You do not need to read the whole architecture at once. Ask Pilot to explain
one chapter in ordinary language:

```text
Pilot, explain your router.
Pilot, explain scenarios.
Pilot, explain approvals.
Pilot, explain execution.
Pilot, explain proof and receipts.
Pilot, explain your memory and learning loop.
Pilot, explain your surfaces and GUI siblings.
Pilot, show me what is real today and what is still on the roadmap.
```

Every chapter follows the same teaching shape: why it exists, what happens,
what worked while building Pilot, what failed, why the component matters, a
concrete example, the canonical owner, current status, the claim boundary, and
one prompt to try. `pilot manual --explain --topic architecture` shows the
chapter index; the user does not need to browse the repository layout.

## What We Learned Building Pilot

The biggest lesson was not that operations needs more scripts or a larger
prompt. It needs a connected control loop. The useful architecture is:

```text
real intent -> known scenario -> bounded route -> exact approval -> execution
            -> independent proof -> receipt -> reviewed lesson
```

Typed routes, exact-revision approvals, deterministic executors, layered proof,
and reviewed learning all worked because each has one job and a visible
boundary. The model remains valuable for interpretation and proposal, but does
not become the approval authority or certify its own result.

What repeatedly failed was connective tissue. Good UI was copied instead of
projected from shared state. Scenario names survived while their helper or test
did not. Plans and Markdown survived while package manifests, installed-root
tests, and retrieval routes drifted. A generated URL was allowed to look like a
verified browser surface. The lesson is therefore cumulative rather
than architectural novelty: every important promise must have a canonical
owner, typed contract, reachable route, honest UI projection, package entry,
installed test, and explicit successor or retirement decision.

### Why ConfigHub is the verification spine

Closed-loop AI is only as useful as its verifier. This is also the argument in
the published [GitOps in the age of AI series](https://confighub.com/blog):
prove changes before apply, retain a data substrate beneath the agent, and
reconcile desired and observed state rather than trusting generated output.

For Pilot, ConfigHub provides the durable part of that loop: the selected
configuration objects, graph scope, exact revisions, diff, approval, apply
history, and resulting governed state remain queryable after the model turn is
gone. Pilot then checks as far beyond ConfigHub as the bound delivery path
allows. A ConfigHub revision does not by itself prove that a controller
reconciled it or that runtime changed, so those remain separate receipt rows.
The result is a useful closed loop without letting either the model or one
green test certify the whole system.

## What Pilot Adds Beyond Fresh Claude Plus ConfigHub

A fresh Claude or Codex session with `cub` and ConfigHub can inspect and change
things quickly. Pilot is the product layer that makes that speed safe to use:

| Fresh Claude plus ConfigHub can... | Pilot adds... |
|---|---|
| Read docs, run `cub`, and propose a plausible next command. | A typed route through Strategy, capability, scenario, solution card, and provider selection. |
| Use ConfigHub as the governed control point. | Gates distinguish read-only work, scoped approval, missing information, and a hard stop before risk. Proof is scored separately as complete, incomplete, or contradicted. |
| Explain what it thinks happened. | Proof rows, URL or GUI gap, omissions, and Receipt objects that keep missing evidence from becoming `PASS`. |
| Give a plausible status update. | A Progress Card that says what is proven, what is not yet proven, what failed, the next safe action, and what can be shared. |
| Call skills or scripts. | Rail State and activity lanes, so the user can see whether the path is deterministic or improvised and which authority each step touched. |
| Learn during a chat. | Harvest into corpus entries, solution cards, fixtures, statutory tests, docs, and explicit `NO_NEW_LESSONS`. |

That is the ablation test: if a run would be just as clear, gated,
reviewable, portable, and reusable in a fresh AI chat with ad hoc commands,
Pilot did not add enough product value yet.

## What Happens After `run pilot`

After installing Pilot, start Claude from the project you want to operate and
type:

```text
run pilot
```

In Codex or a terminal, use the same installed doorway:

```bash
pilot start --render-cockpit
pilot quickstart
pilot start --json
```

Pilot distinguishes a proposed answer from a checked outcome. In the default
loop, a receipt refuses the proposed outcome when its required evidence has
no supported checker. Refusal means the answer has not been accepted; it is
not a measured uncertainty result. The first local check proves one reason to
stop: the packet declares a mutating step but the invocation supplied no
required Automation Contract. Other outcome checkers remain work in progress.
A visibility check can pass because the GUI link is present while the operation
remains unproved; these are separate results.

Once Pilot needs an object to inspect, the normal user command is:

```bash
pilot map <repo-or-url> --json
```

`map` is the Day-0 front door. `view` is the packet-level helper behind it:
useful for tests, gates, and maintainers who need the raw View Packet, but not
the product path a new user has to remember.

The ordinary map of an already-local repo performs zero `cub`, `kubectl`,
delivery-trace, ConfigHub, or Kubernetes-provider reads. (A repository URL is
still an explicit request to shallow-clone that exact Git URL.) To ask for live
ConfigHub discovery, bind one exact Space and one exact cub context explicitly:

```bash
pilot map <repo> --space <exact-space> --cub-context <exact-context> --json
```

That route composes one eight-second, 64 KiB-capped `cub space get` proposal,
then returns `BLOCK` without launching Cub. Structural read cost is not
execution authority: Pilot still lacks the digest-pinned executable, sealed
environment, credential partition, egress constraint, and effect receipt
needed for this provider read. It does not list Spaces, select a first Space,
use a wildcard or ambient context, inspect Kubernetes, or run delivery-trace.
The receipt records the requested scope, zero contact, structural decision,
executor-boundary blocker, and scope-preserving detail actions.

Most users should not need the command vocabulary first. They can ask in plain
language and let Pilot translate the request into a route, skill chain, gate,
screen, script, or receipt:

```text
Pilot, get me a list of what ConfigHub knows about this space.
Pilot, map this repo and tell me the safe next step.
Pilot, diagnose why this app is unhealthy. Keep it read-only first.
Pilot, can I promote staging to prod? Tell me what proof is missing.
Pilot, explain what you will do before you change anything.
Pilot, show me the receipt for what happened.
```

The important contract is that Pilot names the route and proof back to the
user. The user does not need to name skills, scripts, workflows, stages, rails,
cards, screens, or lanes to get the right cockpit.

Every screen uses one state at three levels of detail. A short card keeps a
routine turn brief. A Progress Card shows the goal, a plain progress line,
proven items, not-yet-proven items, failures or blockers, one recommended next
step, and a copyable summary. Engineer detail exposes machine vocabulary,
hashes, file paths, JSON, and rerun commands. The cockpit contains these views
and adds route, Rail State, and activity lanes; it is not a competing card.

QUIET changes only how often and how much those human views speak. Run
`pilot --quiet <command>` or set `PILOT_UI_DENSITY=quiet` to receive one concise
acknowledgement followed only by material choices, approvals, blockers, proof
or review locators, and the final next action. The retained state and every
machine/detail surface stay unchanged.

Pilot should then do seven things:

| Step | What you should see |
|---|---|
| Doorway | A ready Pilot surface in Claude or Codex, not a setup scavenger hunt. |
| Intake | Pilot asks for or reads the actual repo, cluster, ConfigHub URL, app, ticket, or task brief. |
| Route | Pilot says what it thinks the problem is and which route or skill/provider set fits. |
| Gate | Pilot says whether the next step is read-only, eligible for one exact host decision, needs information, or must stop; local classification never executes the command. |
| Run | Pilot performs selected reads and comparisons. One literal context-bound command in the reviewed ConfigHub subset may be submitted to host review; host allow authorizes only an attempt. Destructive, bulk, credential, Kubernetes, executable, unattended, and delegated effects keep their dedicated stop. |
| Prove | Pilot checks ConfigHub, artifact/controller, runtime, URL or GUI gap, omissions, and receipt evidence. |
| Learn | Pilot records reusable lessons as docs, fixtures, tests, solution cards, receipts, or explicit `NO_NEW_LESSONS`. |

The important user experience is not "a skill loaded." The important user
experience is:

```text
I understand what Pilot thinks this is.
I can see the next safe action.
I can see what will not change without approval.
I can see the proof needed before anyone claims success.
```

The control boundary has three layers. Claude or Codex reasons and proposes.
Pilot's deterministic helpers classify routes, scopes, proof, and stop rules.
ConfigHub owns authoritative governed state, approvals, revisions, and
delivery. For the ordinary reviewed subset, Claude forces a host decision on the
literal command; Codex uses its ordinary tool policy and cannot prove a
separate click when none is observed. In either host, post-write ConfigHub
verification is required. Ordinary interactive use does not require a separate
approval service. Enterprise approval workflows and unattended or delegated
execution are optional capabilities with their own readiness requirements;
they remain blocked until the stronger independently authenticated execution
path is configured and proven. A local file saying APPROVED is never permission.

An interactive permission decision does not make a changing object immutable.
Pilot must describe execution-time selection honestly; any exact-revision or
exact-artifact claim still requires the corresponding server-side protection.
Permission to attempt a command and evidence of its result remain separate.

## What The Markdown Corpus Is

The Markdown files in this repo are not all the same kind of thing. They are a
corpus: a collection of instructions, routes, examples, reports, and doctrine
that Pilot can use when a route points to them. Some are active entrypoints.
Most are reference material. A few are historical evidence.

That distinction matters because a `.md` file does not execute just because it
exists. It helps Pilot only when one of these paths reaches it:

| Shelf | Examples | How Pilot uses it |
|---|---|---|
| Startup instructions | `AGENTS.md` plus runtime-specific adapter instructions | Loaded by the agent runtime as operating instructions. This shapes behavior but does not run code. |
| Command prompts | Pilot command Markdown in `plugins/confighub-ai/commands/` | The installer stages these thin prompt templates in the managed user plugin while keeping Pilot's core entry disabled. `pilot claude launch` loads the exact staged core for the selected session. Claude may then show namespaced commands such as `/confighub-pilot:pilot`, but ordinary language such as `run pilot` is the normal doorway. |
| Skill prompts | `plugins/confighub-ai/skills/` and root `skills/` | The installer stages the Pilot skill; the explicit session launcher makes that exact core model-facing for the selected session. The model may select skills when the user's words match their description or route, but staged bytes and launcher arguments do not prove it loaded or selected them. They carry tool procedure, not final authority. |
| Product and engineering doctrine | `docs/product/`, `docs/engineering/`, `pilot/*.md` | Current canon for invariants, proof rules, UX, rebuild rules, and operating boundaries. Agents should cite or follow these when the route asks for them. |
| Scenario and fixture guides | Packaged scenario catalogs, solution cards, contracts, validators, and examples | Repeatable scenario and test substrate with typed maturity and proof boundaries. |
| Reports and receipts | `reports/**/*.md` | Evidence of prior runs. Useful for audit and harvest, but lower precedence than current typed routes, invariants, and solution cards. |
| Archive and superseded notes | `archive/`, dated snapshots, old reports | Historical context only unless a current route explicitly points there. |

So the Markdown files are a corpus. The useful translation is:

```text
Markdown stores operational knowledge at different maturity levels.
Pilot should know which shelf each file belongs to, when it is allowed to use
it, and what stronger typed object or test must exist before the lesson becomes
current operating truth.
```

"Better organized and used" means fewer undifferentiated docs and more
retrievable structure:

- each important `.md` file has a shelf, owner, freshness rule, and trigger;
- startup instructions stay small enough for the agent to follow;
- repeated lessons move from reports into solution cards, invariants,
  contracts, helpers, or tests;
- historical reports never outrank current typed routes;
- command and skill prompts point to the shared installed `pilot` core instead
  of becoming separate runtimes;
- indexes make the corpus queryable by a fresh agent instead of relying on
  whatever was already in chat.

## Where Skills Fit

Skills are still important. They are procedural context for a tool or workflow:
how to query `cub`, how to inspect Argo, how to read Flux state, how to work
with Helm, how to write Kubernetes resources, or how to collect proof.

Pilot is the harness around those skills. It decides which skill or provider
set is relevant, keeps ConfigHub as the governed write authority, blocks unsafe
action, and requires proof before closeout.

The reason a user should expect skills to load is simple: the AI runtime is
general, but the tools are not. A useful ConfigHub answer depends on current
command shapes, allowed verbs, read/write boundaries, controller behavior,
proof requirements, and known failure classes. Skills carry that procedural
knowledge. Pilot decides when the procedure is relevant and prevents the
procedure from becoming its own authority.

Rule of thumb:

```text
Skills know tool-specific "how".
Pilot owns route selection, safety gates, proof, receipts, and learning.
```

So Pilot can load `cub`, Scout, Argo, Flux, Helm, Kubernetes, ConfigHub, or
customer-specific procedural knowledge without letting any one skill bypass
the gate. Loading knowledge is not execution authorization: a reviewed Scout
read runs and its output counts as ordinary runtime-state evidence, the same
as a `kubectl` read; a Scout write, an unreviewed Scout command, or a Scout
MCP tool call goes to the host's ordinary ask permission prompt instead of
running unchecked.

## Which Skills Load When

The user does not have to ask for skill names. Pilot maps the problem to the
next useful skill or provider route and should show that route in the cockpit.
The external `confighub-skills` companion (0.5.0) carries one skill,
`confighub-lookup`. It holds no task knowledge: it tells the agent to look up the
installed `cub` help and the current docs instead of recalling them. Pilot's own
routes below do the rest.

| If the user says | The likely skill route is | Why |
|---|---|---|
| "I want to use ConfigHub", "what should I do first?", or no assets yet | `pilot` plus `confighub-onboarding` or `cub-quickstart` | Choose a safe first path before touching repos or clusters. |
| "Show/list/find/audit what ConfigHub knows" | `confighub-lookup`, then Pilot's read routes | Look up the installed `cub` read commands first, then read ConfigHub's governed model: spaces, units, revisions, labels, data, live data, and URLs. |
| "What is running?", "what is broken?", "who owns this?", or "is this Argo/Flux managed?" | `pilot cluster-slice`, often with a `cub` read and native controller reads | Compare live/controller evidence with ConfigHub's governed view, preserve missing ownership rows, and avoid guessing from one raw probe. |
| "Import my Argo apps" or "Import my Flux apps" | Pilot GitOps/controller route plus typed source/controller reads and `gitops-verify` as needed | Preserve the controller proof chain instead of treating Argo/Flux adoption as the consolidated Helm/Kustomize import primitive. |
| "Bring this Helm chart into ConfigHub" or "Bring this Kustomize overlay into ConfigHub" | Pilot's import route, with `confighub-lookup` for the current import commands | Render Helm/Kustomize source into ConfigHub Units and make later changes through ConfigHub. |
| "Create a StatefulSet/Ingress/NetworkPolicy/RBAC/CronJob" | Pilot's authoring route, with `confighub-lookup` for the current Unit commands | Author a concrete Kubernetes resource as a ConfigHub Unit with the right defaults and gates. |
| "Create app config" or "turn this file/config into data" | Pilot's authoring route, with `confighub-lookup` for the current commands | Pick the right authoring pattern instead of leading with raw YAML. |
| "Change the image, replicas, env var, annotation, or field" | Pilot's change route and approval gate, with `confighub-lookup` for the current function and update commands | Make a governed ConfigHub data change with a precise scope and change description. |
| "Apply/deploy/roll out this approved change" | Pilot's release route, then `gitops-verify` | Publish through the delivery path, then verify ConfigHub, controller, and runtime state. |
| "Promote staging to prod" | `promotion-preflight`, then Pilot's promotion route, with `confighub-lookup` for the current promote commands | Compare source/destination, check readiness, and stop before promotion if proof is missing. |
| "Prove it landed", "show evidence", or "what happened at revision N?" | `proof`, `three-way-consistency`, `confighub-receipts` | Build an honest proof packet with explicit omissions and retained evidence. |
| "Scan this", "is this safe?", or "fix this policy/security issue" | `confighub-scan`, `validate-configs`, or `security-remediation` | Use ConfigHub authority and validators rather than a generic lint story. |
| "Use Argo/Flux/Kubernetes/Helm external skills" | a reviewed skill set from `skills/skill-sets.json`, not a live download | External skills can add knowledge, but they cannot bypass Pilot gates or ConfigHub authority. |

Two points matter more than the exact skill name:

- **No skill may bypass Pilot.** A skill can recommend a command or workflow,
  but Pilot still owns route, approval scope, proof, URL handling, closeout,
  and learning.
- **No skill load is a success claim.** Success needs the visible route, safe
  next action, proof rows, URL or named GUI gap, and receipt.

## What ConfigHub Does

ConfigHub is the governed control point. In a normal GitOps/controller path,
the intended flow is:

```text
source -> ConfigHub -> artifact or OCI -> Argo/Flux/controller -> Kubernetes
```

Pilot should not call that successful just because one layer looks green.
For a serious claim it must say what happened in ConfigHub, what the controller
or artifact consumed, what changed or did not change at runtime, and which URL
or GUI surface a human can inspect.

If a proof layer is missing, the right result is a named gap, not a confident
story.

## What You Should Expect To See

A good Pilot interaction has compact visible state:

```text
PILOT COCKPIT
Need: promotion safety
Evidence: read-only source/controller/runtime
Route: inspect both variants
Next: collect proof
```

For examples of the actual front-door menu, cockpit rows, approval gates,
proof receipts, and chooser text, read
[`WHAT_YOU_WILL_SEE.md`](./WHAT_YOU_WILL_SEE.md).

## What Pilot Is Not

- It is not ConfigHub itself.
- It is not a replacement for Claude, Codex, or `cub`.
- It is not a pile of raw prompts.
- It is not proof just because a command exited successfully.
- It is not proof just because a skill loaded.
- It does not turn third-party skills into live authority without review.

Pilot is additive: it gives the AI session a route map, safety rails,
evidence obligations, and memory.

## Pilot And Workflow Engines

Pilot is also not a workflow engine, even though it has a workflow model of
its own, with named stages the Progress Card shows as you go and a fixed set
of jobs it knows how to run: deploy, adopt, change, promote, recover, scan,
verify, and map. The workflow contract reserves room for the thing that runs
the steps to become swappable: it names itself "the interface between human
intent, AI routing, replaceable execution tech, and ConfigHub proof", and its
provider list includes a `dynamic-workflow` value for an external workflow
engine. That value is reserved for later; no code reads it to choose an
executor today, and making it live is roadmap work.

Pilot decides which job to run and whether the result is allowed and proven.
The engine in the middle just runs the steps, and it does not get to mark its
own work done: Pilot owns closeout. That middle slot is where a dedicated
workflow engine fits. It runs inside Pilot rather than competing with it.
Pilot picks the job, hands the steps to the engine, gates what comes back
through ConfigHub, and gives you the receipt.

## Deeper Docs

| If you need | Read |
|---|---|
| The public product spine | `pilot manual --explain` |
| The generated feature, story, app, action, scenario, and command map | `pilot catalog` |
| The install and first-run path | [`PORTABLE_FIRST_RUN_WALKTHROUGH.md`](./PORTABLE_FIRST_RUN_WALKTHROUGH.md) |
| The sample UI text and menus users should expect | [`WHAT_YOU_WILL_SEE.md`](./WHAT_YOU_WILL_SEE.md) |
| The human Progress Card and action plan checklist | [`WHAT_YOU_WILL_SEE.md`](./WHAT_YOU_WILL_SEE.md) |
| Using Pilot with more than one AI model | [`PILOT_WITH_OTHER_MODELS.md`](./PILOT_WITH_OTHER_MODELS.md) |
| The maintainer-facing core build map | `pilot manual --explain --topic roadmap` |
| The system-owner rebuild guide | the maintainer reimplementation guide (in the source repository) |
| The package and portability boundary | [`INSTALL_PILOT.md`](./INSTALL_PILOT.md) |
| The internal architecture map, after the current docs above | `pilot manual --explain --topic architecture` |
