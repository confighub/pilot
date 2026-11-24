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
  - tests/test-pilot-manual-spine
  - tools/audits/audit-pilot-package-manifest
retrieval_triggers:
  - What is Pilot
  - Pilot intro
  - Pilot value
  - Pilot versus raw Claude
---

# What Is Pilot?

Pilot helps you run and operate cloud software from inside the assistant you
already use. It is a command-line tool plus thin adapters for Claude Code and
Codex. You ask in plain English, and Pilot turns the request into a known job
with steps, checks and stop rules instead of a fresh guess.

Pilot leans on ConfigHub, our system of record for configuration. That is where
your config lives as versioned data you can query, next to the facts an AI
needs to act on it safely.

Three doors into the product:

- **[Use it now](INSTALL_PILOT.md).** From nothing installed to a real
  answer about your own repo, in about a minute.
- **[What is a governed agent for configuration?](WHAT_IS_A_GOVERNED_AGENT.md)**
  The kind of tool this is, and why it asks before it changes anything.
- **[Try it on Kubernetes](PILOT_FIRST_LIVE_WIN.md).** Plan a throwaway local
  kind cluster proof. Pilot switched on inside a team agent service on
  Kubernetes is planned, not built.

**Planning a PoC, onboarding an existing fleet, or comparing options?**
- **Design and analyze your estate:** [`PLAN_YOUR_ESTATE_LAYOUT.md`](PLAN_YOUR_ESTATE_LAYOUT.md),
  [`DEEP_ANALYSIS.md`](DEEP_ANALYSIS.md), and [`WORK_PLAN_COMPARE.md`](WORK_PLAN_COMPARE.md).
- **Onboard existing GitOps estates and roll out in rings:** [`ARGO_ONBOARDING.md`](ARGO_ONBOARDING.md),
  [`FLUX_ONBOARDING.md`](FLUX_ONBOARDING.md), [`SVELTOS_ONBOARDING.md`](SVELTOS_ONBOARDING.md),
  and [`STAGED_ROLLOUTS.md`](STAGED_ROLLOUTS.md).
- **Explore ConfigHub functions, signed corpus updates, other AI models, and honest limits:**
  [`PILOT_FUNCTIONS.md`](PILOT_FUNCTIONS.md),
  [`CORPUS_UPDATES.md`](CORPUS_UPDATES.md),
  [`PILOT_WITH_OTHER_MODELS.md`](PILOT_WITH_OTHER_MODELS.md), and
  [`WHAT_CAN_I_DO_TODAY.md`](WHAT_CAN_I_DO_TODAY.md).

The idea is one installation with an explicit session doorway: you install
Pilot once, and it is on only in the Claude session where you switch it on
(`/confighub-pilot:on`, or start the session with `pilot claude launch`).
Other sessions are left alone: Pilot works inside the assistant you already
use without becoming a machine-wide policy layer.

Three rules hold everywhere Pilot works:

- **Nothing changes until you say yes.** Pilot classifies each step as
  read-only, a proposal you can review, one exact command the host can allow or
  deny, or blocked. It never edits a cluster or ConfigHub on its own.
- **Permission is not proof.** Being allowed to try is not the same as it
  having worked, so Pilot reads back what actually happened.
- **Every run leaves a receipt.** A saved record of what was checked, what
  happened, and what is still unproven, so someone who was not in the room can
  check it.

Ask Pilot for help and it starts with one of eight journeys: TEACH, ONBOARD,
SET UP & ORGANISE, DISCOVER, BUILD, OPERATE, FIX, or AUTOMATE. Underneath,
every one of them follows the same loop:

```text
Doorway -> Intake -> Route -> Gate -> Run -> Prove -> Learn
```

What comes back is written for people. A common failure of AI tooling is being
technically right and humanly useless. A Progress Card is the fix: here is the
goal, here is what is done, here is what is actually proven, here is what is
not, and here is the one next thing to do. All the engineering detail is still
underneath for anyone who wants it.

The quickest way to understand the product is to ask the product:

```text
Pilot, explain yourself to me.
```

## What Pilot Does

- **Reads your estate and tells you what you have.** Point it at a repo, a
  cluster context, a ConfigHub URL or a session log and it maps it: what is
  deployed, what owns what, what looks wrong, what to do next.
- **Routes your request to a known job.** "Set up GitOps", "automate
  promotions", "why is this broken" each land on a worked-out scenario with
  steps, checks and stop rules, not a fresh improvisation.
- **Gates anything dangerous.** It classifies a step as read-only, a reviewable
  proposal, eligible for an exact host decision, or blocked. In a Pilot-active
  Claude session one reviewed bounded ConfigHub command forces a host allow or
  deny; Codex uses its ordinary tool permission path. Permission authorizes an
  attempt, not a successful outcome, so Pilot verifies the resulting revision
  or Release read-only and receipts that observation. Reads run; changes ask.
  Destructive, unbounded, dynamic, credential-bearing, executable-lifecycle,
  cluster-lifecycle, and direct Kubernetes commands ask first: the host shows
  the exact command and you allow or decline that one attempt. Four things stay
  stopped: a recursive Space delete, an organization delete,
  `cub cluster down --delete-config` (or `detach --delete-config` on newer cub),
  and a credential typed into a command.
- **Defines and checks the governed end-to-end proof contract.** The complete
  path binds ConfigHub intent, OCI/controller delivery, the exact runtime field,
  and a receipt. Historical disposable-cluster evidence shows that delivery
  chain once worked, but the current public path does not rerun it until a
  trusted external approval verifier is integrated.
- **Shows you where you stand in plain English.** A Progress Card: done,
  proven, not yet proven, one next action.
- **Turns a workflow you like into a standalone app.** Browser UI, CLI, tests,
  proof gates.
- **Keeps the lesson.** A solved problem can be promoted into the corpus,
  review-first, so the next person routes straight to it.

## The Corpus

At Pilot's heart is the corpus. Give an AI no real knowledge and it will
happily drift across a pile of .md files and sound confident while it does.
Pilot's corpus is three things: a jobs catalog of proper scenarios, meaning
the jobs people actually need doing; the execution rails, meaning patterns to
recognize each job and checks to keep the AI honest while doing it; and the
cross-references to the scripts, skills and UI pieces that carry the work out.

Worked examples belong in the corpus as teaching material, and users may well
install one to learn from. The rule is directional: example knowledge flows
into the corpus, but example code never delivers Pilot functionality itself.

Pilot can learn, review-first. When we solve something new, even if a human
had to steer the answer, that lesson can be staged for the corpus and reused.
Promotion is deliberate: maintainers review each lesson before it lands,
negative results allowed, rather than the AI marking its own homework. The
clever bit is still Claude. What Pilot adds is the knowledge, the rails and
the memory. That is what turns "we solved it once" into "we can solve it
every time".

## When Not To Act

Pilot is controllable and knows when not to act. Ask it to run something risky
and it tells you, before anything changes, whether that command is read-only,
eligible for the bounded interactive path, or blocked outright. The normal
interactive path binds one named ConfigHub context, one literal command, exact
scope, the host's permission result, and a read-only postcondition receipt.
Claude's Pilot hook forces the host decision. Codex has no equivalent shipped
hook in this release; it uses Codex's normal permission policy and Pilot says
when that policy did not prove a separate human click. This is the difference
between an AI you show off and an AI you let near production: permission and
an exit code are never presented as proof that the requested state exists.

That matters because most of the time we do not really know what to do next,
or how to automate it, or whether we did the right thing. Or the awkward one:
how anyone else is meant to verify it afterwards. People already throw Claude
at the problem, and honestly that often works. But a normal user cannot always
tell whether they followed the correct, repeatable, enterprise-sharable path
or just got lucky. And once you have solved it, how does the rest of the team
run the same thing tomorrow? Pilot's answer: the solution becomes a scenario
anyone can route to, and the receipt, structured data a colleague can verify
rather than a chat transcript, lets someone who was not in the room check what
happened. ConfigHub is the receipt's intended long-term home, so the proof
ends up living next to the config it proves.

The enforcement is layered. Claude or Codex reasons about the request. Pilot's
deterministic helpers classify the route, scope, proof, and stop conditions.
ConfigHub remains the authority for governed state, approvals, revisions, and
delivery. A prompt is guidance and a Pilot gate is a checked decision. For the
small ordinary subset, the host may permit one exact context-bound attempt;
Pilot then verifies and receipts the observed result. Stronger delegated or
exact-artifact authority still requires a trusted external verifier bound to
the exact proposal, and that stronger verifier is not integrated today.

## Apps On ConfigHub

Pilot can turn scenarios and workflows into small standalone app packages, following
the model proposed by the team. Browser UI, CLI, tests, and the same proof
gates, generated and gated the same day rather than over a sprint, governed
through ConfigHub like everything else. This is one good "how does everyone
else use it" model. The fix you made once becomes a product the whole team
runs, not a story about a chat session. Generation proves that the package,
browser UI, CLI, and tests agree locally. It is not a live operational app
until OAuth, ConfigHub object and Variant bindings, approval, governed action,
controller delivery, runtime state, URL, and receipt are proven.

## Degrees Of Done

Pilot is straight about degrees of done. It will tell you a result is clear
enough to share with the team but not yet proven live, not just green because
something rendered green. Human-ready and machine-proven are different things,
and Pilot says which one you have. If you have ever had to ask "yes, but did
it actually deploy?", that sentence is for you. It is also one vanilla Claude
cannot honestly say.

The default interactive lane can make the bounded ConfigHub changes described
above. It does not make direct cluster lifecycle or the stronger delegated
executor available. You can inspect that separate fully governed path, but the
current build will not run it. `pilot local-kind-live-proof --governed --execution-approval-window 300`
verifies the selected ConfigHub organization read-only, then stops before
creating a cluster or ConfigHub object with
`AUTHENTICATED_APPROVAL_ATTESTATION_REQUIRED`. A model-writable local approval
record is useful review metadata, not proof that a human authorized mutation.
The retained Component -> Variant -> tagged Space Release machinery and its
controller/runtime postchecks become reachable only after Pilot integrates a
trusted external approval verifier.

A July 2026 disposable-cluster run remains valuable historical evidence that
the ConfigHub -> OCI -> Argo -> Kubernetes delivery chain worked. It predates
the approval-authenticity analysis and does not authorize or prove a current
live run, production, customer infrastructure, or promotion across
environments.

## Release path

Pilot's release path is one user story: it starts by helping you see and
explain work, moves through guided promotion, live proof, and walkthrough
regression, and heads toward bounded autonomy. Today, `v0.7.1` lets anyone
install Pilot from a public channel and brings reviewed lessons between
releases. The next release, `v0.7.2`, is about expert guidance for people who
already know Argo CD or Flux, a more accurate deep map and signed corpus packs.
The product loop stays stable:

```text
Doorway -> Intake -> Route -> Gate -> Run -> Prove -> Learn
```

| Release | User path | Status |
|---|---|---|
| `v0.4.2` — Operator Usability Preview | Users could understand the first bounded operational paths and see where Pilot had proof or an honest limit. | Past |
| `v0.4.3` — Walkthrough and Multi-Model Preview | Users can walk through the whole product and compare model choices without changing what counts as safe or proven. | Past |
| `v0.4.4` — Promotion Operator Experience | Operators can find the right journey in plain language, see the server's rollout state, and prepare a bounded promotion review without Pilot implying that execution or proof is complete. | Past |
| `v0.4.5` — Live Proofs | Users can see whether approved intent reached the controller and runtime, and whether the supporting evidence is fresh enough to trust. | Past |
| `v0.5.0` — Internal Team Preview | Internal teams can use the whole installed Pilot workbench with repeatable safety behavior and exact private-preview boundaries. | Past |
| `v0.5.1` — Internal Team Maintenance Preview | Internal teams can continue using the Pilot workbench with clearer evidence and more dependable startup and status displays. | Past |
| `v0.6.0` - Autonomy and Scenarios | Users can define bounded scenarios that make scope, authority, allowed actions, and required proof clear before autonomy is considered. | Past |
| `v0.6.1` - Scenario and Delivery Coverage | Users can trust that a status shown right now was checked right now, and can carry more of the rollout and promotion work all the way through to a proven, finished state. | Past |
| `v0.7.0` - First Use, Fleets and Doorways | Pilot works with current ConfigHub, reads without asking, asks once before any change, and shows what it is doing in a small cockpit under each reply, so a person new to Pilot can follow a session and trust it. | Past |
| `v0.7.1` - Public Install, Live Corpus Updates and ConfigHub 0.9.1 | Anyone can install Pilot from a public channel, reviewed lessons can reach you between releases, Pilot works with ConfigHub 0.9.1, and its first answers fit your own repository. | Current published |
| `v0.7.2` - Expert Guidance, Signed Updates and More Doorways | People who already know Argo CD or Flux get expert guidance instead of the beginner tutorial, Pilot's repository map states only what it can show from your own files, and reviewed lessons arrive signed so you can tell they came from ConfigHub. Ask what a Space is, or what ConfigHub would add, and get an answer pitched at an expert instead of the beginner tutorial. Get a deep map whose facts match your repository: the real version differences, which apps depend on which, and the order of sync waves. Ask whether you can promote staging to production and get the blockers, with every command filled in and every term explained. Update reviewed lessons knowing each pack was signed with ConfigHub's own identity. Planned: use Pilot in Claude desktop's Cowork, once it is shown to work there. Planned: carry a proven rollout across more clusters. Planned: hand a bounded task to an agent and verify its result independently. Planned: reach Pilot through one more doorway beyond Claude and Codex. | Next release |

For the current release explained in plain language, see
[`WHATS_NEW_v0.7.1.md`](WHATS_NEW_v0.7.1.md). For the v0.7.2 release,
see [`WHATS_NEW_v0.7.2.md`](WHATS_NEW_v0.7.2.md). For the v0.7.0 release,
see [`WHATS_NEW_v0.7.0.md`](WHATS_NEW_v0.7.0.md). Earlier releases have their own
pages: [`WHATS_NEW_v0.6.1.md`](WHATS_NEW_v0.6.1.md),
[`WHATS_NEW_v0.6.0.md`](WHATS_NEW_v0.6.0.md) and
v0.5.3.

Proof is part of the product. Validated evidence and the trust matrix are
primary; CLI commands and recipes support them. Missing, stale, or
`Evidence: pending` stays visibly unvalidated and `WATCH`.

A serial external Helm and GitOps evidence lab produces bounded, pinned
receipts. Pilot consumes those receipts and owns the route, freshness-aware
trust matrix, claim ceiling, and cockpit. Pilot does not duplicate Helm, kind,
Scout, or probe machinery.

## Where We Are

Straight answer. Real today: the rails, the corpus, the ConfigHub backing, the
Progress Cards, the fail-closed approval boundary, host-reviewed ordinary
ConfigHub changes, app generation, and a historical disposable-cluster
delivery-chain receipt. Pilot v0.6.1 also ran three rollout scenarios end to
end on current ConfigHub, on one local practice cluster with Argo CD, using
commands a person reviewed. Earlier releases ran a staged rollout across three
local clusters and undid a change; those runs have not been repeated on the
current ConfigHub version. Nothing has been run with Flux delivery or
unattended. Still ahead: stronger delegated authenticated approval authority,
the same chain against a real customer org, receipts living in ConfigHub
itself, and the factory learning from its own runs without us steering every
lesson by hand.

You can install and inspect Pilot without ConfigHub. ConfigHub authentication
becomes necessary when Pilot needs governed objects, approvals, revisions,
delivery, or live proof. Kubernetes and a controller are needed only for the
corresponding runtime proof paths.

For now this is mostly dogfood, something any of us can hack on and make
better: add your own corpus entries and repo-shape rules today, with fuller
scenario, skill, and app authoring on the roadmap. If
it turns out to be worth it, others can use it too, maybe even pay for it. If
you are already in Claude Code or Codex you can load Pilot in and have a go.
