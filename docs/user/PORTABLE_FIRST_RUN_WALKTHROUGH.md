---
shelf: product-doctrine
status: current
audience: users
owner: pilot
portable: true
package: pilot-core
used_by:
  - README.md
  - docs/user/HOW_PILOT_WORKS.md
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tests/test-pilot-first-run-install-docs
  - tools/audits/audit-md-corpus-shelves
retrieval_triggers:
  - first run
  - installed Pilot
  - portable Pilot
---

# Portable First Run Walkthrough

Audience: evaluators and new users who want one coherent view of Pilot, plus
installers who need the exact setup path.

This is Pilot's canonical whole-product walkthrough for a user starting from
an installed package. The user operates from the repo or folder they want Pilot
to inspect, not from the Pilot package checkout. It is the compact 5/20/45
projection of Pilot's checked canonical eight-journey engagement; its
typed inventory preserves the ownership and provenance needed by maintainers. It
does not create another journey list, scenario catalog, command catalog, or
execution engine.

If you want the absolute shortest version, use
[`INSTALL_PILOT.md`](INSTALL_PILOT.md). It says exactly what to install, how to
check it worked, what to type first in Claude, and what to do if blocked.

## The Whole Product In 5 / 20 / 45 Minutes

After installation, point Pilot at a real project:

```bash
pilot whole-walkthrough --through 5 --repo /path/to/your/project --render-cockpit
```

Use `--json` for the typed receipt. The same checked inventory supplies both
views.

The walkthrough has three cumulative lanes:

1. **Five minutes — orient.** Verify Pilot is present, show its safety posture,
   and make all eight jobs independently visible: TEACH, ONBOARD, SET UP &
   ORGANISE, DISCOVER, BUILD, OPERATE, FIX, and AUTOMATE. Choosing a job grants
   no authority.
2. **Twenty minutes — earn real-project value.** Quickstart, map the supplied
   project, separate source facts from ConfigHub/controller/runtime gaps, and
   route the user's words to one safe next step. These steps are read-only;
   only local walkthrough receipts may be written.
3. **Forty-five minutes — inspect the governed operational path.** Bind a
   proposal, show the exact approval, enumerated execution, independent proof,
   recovery, and closeout contracts, then stop. The current build has no
   trusted external approval verifier, so this lane performs zero live mutation
   and returns `AUTHENTICATED_APPROVAL_ATTESTATION_REQUIRED` before execution.

That stop is part of the walkthrough's product truth, not a simulated success.
When external approval authority and T2/T3 evidence exist, this same lane can
advance without changing the journey model or replacing its preserved steps.

The remaining sections provide the exact installation and individual doorway
commands. They remain supported entry points and are inputs to the whole
walkthrough, not deprecated alternatives.

## 1. Install

Pilot requires **Python 3.11 or newer**. `pipx` is optional. The installer
honors `PILOT_PYTHON` and otherwise probes `python3`, `python3.13`,
`python3.12`, and `python3.11` for a supported interpreter. Apple's system
`python3` may be 3.9; on macOS use `brew install python@3.13` and rerun with
`PILOT_PYTHON=python3.13` if needed.

Install Pilot from the public channel at <https://github.com/confighub/pilot>.
[`INSTALL_PILOT.md`](INSTALL_PILOT.md) lists every route (`cub`, Claude Code,
Claude Desktop, plain Python) and says what each one does. If you use `cub`,
Route 1 there is two commands. In YOUR terminal, run the first one below, then
run the second command that Route 1 gives you:

```bash
cub plugin install confighub/pilot
```

That second command downloads one Pilot file, checks it against a checksum (a
fingerprint of the file) before it installs anything, and puts Pilot in its own
folder under your user home. It does not write into the project you operate.
It leaves the independently governed companion decision for the separate
guarded Claude step below. This internal prerelease, an internal preview, does not prove live customer,
Promotion, or CVE behavior, and it is not a PyPI or Homebrew publication path.
To remove Pilot, see the Uninstall section of `INSTALL_PILOT.md`.

Then check the install and look at your first project:

```bash
pilot --version
pilot quickstart --progress-card
cd /path/to/the-repo-you-want-to-operate
pilot map . --json
pilot ask "map this repo and tell me the safe next step" --progress-card
pilot ask "scale this app" --progress-card
```

The repo card is the first real aha moment. It should inspect the folder you
are standing in, name what kind of repo or source it appears to be, give one
next action, and say what still has not been proven. It should not look like a
generic sample card. This ordinary local-path command performs zero `cub`,
`kubectl`, delivery-trace, ConfigHub, or Kubernetes-provider reads. An explicit live follow-up
must name both `--space <exact-space>` and `--cub-context <exact-context>`; it
composes one capped exact-Space proposal but blocks before launching Cub until
a sealed read executor exists. Unit, Link, and Target collections also remain
blocked before launch.

Asking for a common change is the second aha moment. Pilot should map the plain
request to a narrow, checkable Safe Action, show the direct fallback, one next
action, and a shareable summary. It should not make a new user choose from
function names.

Use the install step above, then run
`pilot quickstart --progress-card` for the human status, remaining access gap,
and one next action. When a receipt exists, use
`pilot review-packet --from-receipt <receipt> --render-cockpit` to retain its
recorded proof context. The first human Progress Card states what Pilot
checked, what it did not touch, what is still unproven, and what to do next.
The full cockpit keeps the card derived from recorded proof layers, so its
claims stay tied to the receipt rather than to a fresh description of what
might have happened. Say **"Pilot, show me the full cockpit"** or
**"Pilot, show engineer details."** to open the deeper view with its receipt
context.
Use `pilot ask "map this repo and tell me the safe next step" --progress-card-json`
when a script needs the same human route card as structured data. Use
`pilot ask "map this repo and tell me the safe next step" --json` when it needs
the full automation receipt.

Pilot also accepts app-shaped requests:

```bash
pilot ask "make this repeatable as an app" --render-cockpit
```

Fallback path with a local virtualenv:

```bash
PILOT_PYTHON="${PILOT_PYTHON:-python3}"
"$PILOT_PYTHON" -c 'import sys; assert sys.version_info >= (3, 11)'
"$PILOT_PYTHON" -m venv /tmp/pilot-trial-venv
/tmp/pilot-trial-venv/bin/python -m pip install https://github.com/confighub/pilot/releases/download/v0.7.0/confighub_pilot-0.7.0-py3-none-any.whl
/tmp/pilot-trial-venv/bin/pilot start --render-cockpit
/tmp/pilot-trial-venv/bin/pilot quickstart --progress-card
cd /path/to/the-repo-you-want-to-operate
/tmp/pilot-trial-venv/bin/pilot ask "map this repo and tell me the safe next step" --progress-card
/tmp/pilot-trial-venv/bin/pilot review-packet
```

The release asset proof (maintainer/reviewer path, run from a source
checkout) is:

```bash
./scripts/pilot install-channels --json
./scripts/pilot release-asset-install-smoke --json
```

`pilot install-channels --json` includes a local preflight block for `gh`,
optional `pipx`, a verified Python 3.11+ interpreter, and `gh auth`. A present
but too-old `python3` is `WATCH` and includes the macOS/Homebrew recovery. The
preflight also marks unauthenticated direct GitHub URL install as `WATCH` while
the release asset is private, because that path can return a valid-looking 404
before authentication is considered.

The remaining examples use `pilot`. If you used the virtualenv fallback, replace
`pilot` with `/tmp/pilot-trial-venv/bin/pilot`.

## 2. Check The Doorway

```bash
pilot quickstart --progress-card
```

Expected shape (real output, reformatted and trimmed):

```text
Pilot progress - First run                          Safe first step selected

Proven
+ Pilot is installed and can choose a first route.
+ Pilot selected a read-only first step.
+ No ConfigHub, Git, Kubernetes, controller, or external write was allowed.

Not yet proven
o Pilot has not inspected your real project yet.

Do this next
> Move to the repo or folder you want Pilot to inspect. Then run: pilot map .

Want a deeper view?
Say "Pilot, show me the full cockpit." or "Pilot, show engineer details."
```

For the fuller cockpit view of the same first step, run
`pilot quickstart --render-cockpit`.

Inside Claude or Codex with Pilot on, you can then ask in plain words:

```text
Pilot, map this repo and tell me the safe next step.
Pilot, make this repeatable as an app.
Pilot, show me the evidence and receipt.
```

Use `pilot quickstart --json` when a script or release check needs the machine
receipt instead of the visible cockpit. Use `pilot quickstart --progress-card-json`
when a script needs the same first-run card as structured data.

The quickstart Progress Card states what Pilot checked, what it did not touch,
what is still missing, and what to do next.

Use `pilot review-packet --render-cockpit` for the human proof view. When a
real receipt exists, add `--from-receipt <receipt>` so the view is derived from
recorded proof layers.

## 3. Choose The ConfigHub Lane

Run `pilot onboard` inside your own repository and it opens with that
repository: the delivery tool it found, the apps, the environments, the
namespaces, what ConfigHub would add, and one next step, the read-only import
plan. Nothing is created and nothing leaves your machine.

Run it anywhere else and it opens with the Cloud or self-hosted choice below,
which is still there underneath either way.

Keep the first human response small. `pilot onboard` returns one local result
before credentials or network checks, then keeps ONBOARD visible between TEACH
and SET UP & ORGANISE:

```bash
pilot onboard
pilot onboard cloud
pilot onboard che
```

The Cloud lane links the current ConfigHub docs and can later resume the
existing read-only organization check with `pilot onboard cloud
--verify-context`. Login alone is not proof. The CHE lane links the public
[`confighub/cub-che` README](https://github.com/confighub/cub-che/blob/main/README.md)
and resolves the current public release through the GitHub API when available;
otherwise the receipt labels its packaged release metadata as a bundled
observation, not a fresh response. When the selected plugin is installed,
Pilot also reads `cub che --help` so stale prose cannot override the release's
actual command surface or image-access policy. ONBOARD asks to install or
upgrade `cub` and the CHE plugin when needed. SET UP then runs or proposes the
profile-specific preflight and asks before installing ConfigHub itself.
ConfigHub and the platform operator still own the installation procedure;
Pilot links, explains, checkpoints, and resumes rather than becoming a second
installer.
The five-minute goal is time to a qualified readiness checkpoint. Pilot does
not estimate or promise CHE installation duration; the platform operator owns
that work and its completion evidence.

With no self-hosted constraint, bare `pilot onboard` recommends Cloud as the
fastest evaluation lane and shows CHE as the one operator-owned alternative.
Self-hosted, on-premises, private-cloud, air-gapped, or explicit CHE intent
reverses that recommendation. The command writes its JSON receipt under the
user Pilot home by default (or `--out-dir`) and prints the exact receipt path
and a directly runnable resume command.

Use `pilot onboard <cloud|che> --json` for all source provenance, timing fields,
typed gaps, and the proof ceiling. Cloud and CHE remain ONBOARD/setup lanes;
the product still has exactly eight top-level journeys.

### Before The First Preview Write

Read-only mapping stays frictionless. Preview writes belong in a dedicated
ConfigHub preview organization named by your team, not in a shared working
organization. When you are ready for the disposable governed preview, sign in
to that organization using a new context and verify it before write intent:

```bash
export PILOT_PREVIEW_ORG="<approved preview organization>"
cub auth login --new-context --organization "$PILOT_PREVIEW_ORG"
pilot org-check --expected-org "$PILOT_PREVIEW_ORG" --write-intent --plain
pilot local-kind-live-proof --governed --execution-approval-window 300 --progress-card
```

The login creates and selects an isolated context; `pilot org-check` stops
with the exact `cub context` fix if the CLI points somewhere unexpected. The Pilot command performs read-only
organization verification and shows the human organization name and verified
CLI identity. It returns a question without creating a Space, worker, target,
Unit, controller object, or Kubernetes object. Confirm the organization using
the exact next command in the Progress Card. The continuation currently stops
before setup with `AUTHENTICATED_APPROVAL_ATTESTATION_REQUIRED`: the selected
organization is binding evidence, not mutation approval, and Pilot has no
trusted external verifier for a human approval attestation. A local JSON record
remains `WATCH` and cannot authorize the write.

Because the current governed run creates nothing, teardown records
`SKIP / NOT_CREATED`. The retained future execution path must remove its
disposable cluster and prove the ConfigHub Space is absent.
A successful teardown command is not enough by itself. If the Space is
retained or its absence cannot be verified, the cleanup receipt stays
incomplete and names the remaining work.

## 4. Point Pilot At Work

Move to the repo or folder you want Pilot to inspect:

```bash
cd /path/to/work
pilot map . --json
pilot ask "map this repo and tell me the safe next step" --progress-card
pilot ask "scale this app" --progress-card
```

Expected behavior:

- Pilot names the route before proposing action.
- Pilot shows a human Progress Card with the route, proof gaps, one next action,
  and a shareable summary.
- Pilot can show a Safe Action for a common change without making the user
  learn function names.
- Use `--render-cockpit` when you want the fuller route screen with Rail State,
  authority lanes, proof rows, and engineer detail.
- For the bounded ordinary ConfigHub subset, Pilot prepares one literal command
  with an explicit context and the host decides whether the assistant may
  attempt it. Claude uses its PreToolUse `ask` result; Codex uses its ordinary
  permission path when one is available. A host ALLOW authorizes an attempt,
  not success. Stronger delegated or exact-artifact authority remains a
  separate boundary.
- Pilot writes proof gaps instead of pretending a live system was checked.

### Preview one OPERATE job and see the exact next integration gap

Acquire only the exact ConfigHub objects named by the operator, then turn the
plain-English job into typed state. No organization-wide list is used:

```bash
pilot operate snapshot --repo . --cub-context <context> --organization-id <uuid> --space <slug>=<uuid> --unit <slug>=<uuid>@<head-revision-uuid> --out /tmp/operate-snapshot.json --json
pilot operate compose --snapshot /tmp/operate-snapshot.json --intent "scale <unit> to 3 replicas" --out /tmp/operate-state.json --json
pilot operate --repo . --state /tmp/operate-state.json --json
pilot operate --repo . --state /path/to/operate-state.json --job <job-id> --json
```

The snapshot binds exact ConfigHub objects to the repo's resolved root, HEAD,
tree, and clean-state bit. The composer rejects a snapshot older than five
minutes and creates the requested job; the cockpit then shows and selects it.
A small structured scale proposal
binds the exact observed Unit ID, head revision, data digest, proposed replicas,
and a bounded-value policy that is explicitly not risk proof. OPERATE emits the
canonical read-only gate with the exact IDs, head, digest, and five-minute
expiry. The gate asks the host about one unchanged Cub attempt; permission is
not proof, so Pilot immediately reads back the Unit.

For Promotions, the same screen keeps preview, conflicts, protection, named
review, execution, publish, ConfigHub proof, controller proof, runtime proof,
and recovery visible. Source and destination exact-ID snapshots replace the
old wildcard Target lookup and derive the candidate Unit set. The host reviews
one exact destination-Space Promotion attempt. Publication remains a separate
review after a fresh destination snapshot because Promotion and publication
are not atomic. Compose that fresh snapshot directly instead of hand-authoring
another state file:

```bash
pilot operate snapshot --repo . --cub-context <context> --organization-id <uuid> --space <prod>=<uuid> --unit <slug>=<uuid>@<head-revision-uuid> --target <owner-space-id>/<slug>=<target-uuid> --out /tmp/post-promotion.json --json
pilot operate compose --snapshot /tmp/post-promotion.json --intent "publish prod and go live" --out /tmp/publication-state.json --json
pilot operate --repo . --state /tmp/publication-state.json --job publish-prod --json
```

The publication card shows the exact Space, configured Target, and reviewed
Unit heads, then opens one host-reviewed `release publish` attempt. It also says
plainly that ConfigHub resolves whole-Space membership and heads at execution;
the attempt is not proof. The next checkpoints remain the resulting Release,
controller convergence, runtime outcome, and forward recovery. This navigator
accepts no hand-written run receipt and never turns permission or command exit
into final proof.

Pilot deliberately does not perform an ambient organization scan to create the
state file. The installed exact-ID producer has fixed object, request, time,
and byte limits, and the composer joins it to a plain-English scale, Promotion,
or publication job. The examples
in `pilot/fixtures/operate/` demonstrate the contract only; they are not live
evidence and their placeholder repo binding must be regenerated.

## 5. Add Claude Adapter

After the package works, install the adapter once per machine:

```bash
pilot claude install --global --session-scoped
pilot claude companion status --global --json
pilot claude status --global --progress-card
```

This preserves the managed plugin and every companion skill identity while
keeping Pilot's own user-scope entry disabled and leaving no Pilot-owned global
status line. It preserves the companion's existing enabled/disabled/absent
stored state exactly and never injects it. A stored enabled, activation-ready
companion remains independently available; an enabled ineligible companion
blocks launch; and false/absent stored state is pinned false only in the
session overlay to prevent project/local activation. From the project where
you want Pilot, `pilot claude launch` loads the digest-checked Pilot core as one
exact `@inline` plugin.
Plain `--activate` is a compatibility alias for that session preparation. Only
an explicit `--always-on` request may globally enable Pilot.

An independently enabled but ineligible companion blocks Pilot launch instead
of being silently rewritten. The deterministic checks do not prove the absence
of a project or managed-policy plugin, eliminate every post-check/exec race, or
prove Claude model loading or skill selection.

For ConfigHub command skills, first inspect an exact local companion checkout:

```bash
pilot claude companion install \
  --source /path/to/confighub-skills \
  --dry-run \
  --json
```

For activation, Pilot requires the current inventory-selected exact reviewed
0.5.0 source, uses the
official Claude CLI to add or update the marketplace and install or enable the
plugin, then verifies the registry commit and protected installed bytes. The
pack ships one skill, `confighub-lookup`, that tells the agent to look up the
installed `cub` help and the current docs instead of recalling them. Static
identity and host-local activation eligibility are
`PASS`; behavioral/model-selection remain `WATCH`; authoritative and delegated
execution remain `BLOCK`. The pack grants no tool autoallow. Activation makes
the reviewed procedures available, but it does not prove Claude selected one.
A clear ordinary mutation request may submit one exact command to the host's
normal permission policy; permission is an attempt, and Pilot must verify the
result read-only.

After that, open Claude from the repo you want to operate and ask in plain
language:

```text
run pilot
```

Then ask:

```text
Pilot, map this repo and tell me the safe next step.
```

The user should not need to copy Pilot skills into each project.
