---
shelf: product-doctrine
status: current-with-review
audience: users
owner: pilot
portable: true
package: pilot-corpus
used_by:
  - README.md
  - docs/user/PILOT_MANUAL.md
  - docs/user/PILOT_CATALOG.md
  - scripts/pilot-safe-actions
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tests/test-pilot-safe-actions
  - tests/test-pilot-catalog-spine
  - tools/audits/audit-pilot-package-manifest
retrieval_triggers:
  - safe actions
  - ConfigHub functions
  - typed operations
  - safe change
---

# Pilot Safe Actions

Safe Actions help you review narrow operations and the evidence that supports them.
Some use a typed ConfigHub function: a named operation with defined inputs.
Others prepare local review artifacts before ConfigHub exists, including an application Base.
A Base contains initial definitions of Kubernetes resources for review. The direct edit path remains available.

When application source proves a port but not an immutable image, Pilot asks
only for the missing image. The user can continue in ordinary language with
`Pilot, make this app deployable using <image>@sha256:<digest>`. Pilot treats
that digest as supplied input and keeps registry verification visibly open.

The user should not need to know the function library first. Pilot should say
what it can do in plain language:

```text
Pilot can make this as a safe ConfigHub change.

It will change only the replica count, show the diff, and check the result
before rollout.
```

Engineer detail can still show the exact operation:

```text
cub function set --space <space> --unit <unit> set-replicas <count>
cub function vet --space <space> --unit <unit> vet-schemas
```

Those two lines are the shape of the call, with the parts in angle brackets
standing in for your own names. Every command that works on one Space names
that Space, so copy the shape and fill it in rather than pasting it as it is.

That detail is useful for automation, review, and debugging. It is not the
default human experience.

If you came here specifically looking for ConfigHub functions, read
[`PILOT_FUNCTIONS.md`](PILOT_FUNCTIONS.md). Safe Actions are the human-facing
door; functions are an optional implementation and validation path behind that
door.

## What This Solves

Raw AI can write plausible YAML. That is powerful, but it is also easy to get
wrong in ways that are hard to see.

Safe Actions give Pilot a better path:

1. understand the user's intent;
2. recommend a narrow ConfigHub action when one fits;
3. keep a direct edit path for users who prefer it;
4. show the diff and checks before rollout;
5. refuse live claims until controller, runtime, GUI, and receipt proof exist.

This is one of the clearest differences between Pilot plus ConfigHub and a
fresh AI session plus documentation. Pilot can use a known operation, keep the
change in ConfigHub history, and explain what still has not been proven.

## Where Functions Fit

Pilot can use ConfigHub functions when they make the change narrower, more
repeatable, or easier to validate.

That does not mean the user should choose from a function list. Pilot should
match the user's words to an outcome, then show the function only when the
engineer asks for detail.

Good default:

```text
Change replica count
```

Engineer detail:

```text
typed path: set-replicas
validation: vet-schemas
```

The direct ConfigHub edit path must remain visible, because some resources are
unusual and some teams prefer explicit field editing.

## User Rule

Use outcome words first:

| Say This | Engineer Detail |
|---|---|
| Change replica count | `set-replicas` |
| Change container image | `set-container-image` |
| Change runtime configuration | `set-env-var`, `set-label`, `set-annotation` |
| Harden a workload | resource defaults, probe defaults, security defaults |
| Check before promotion | schema, placeholder, format, immutable-field checks |
| Create a Kubernetes resource | ConfigHub Unit plus optional defaults and validation |
| Prepare an application baseline | repository facts, three-resource Base, assumptions, and optional outcome recommendations |

Do not make the beginner choose between function names. Show one recommended
safe action and one direct alternative.

## How To Use It

From any project:

```bash
pilot ask "scale this app" --progress-card
```

For an application repo that has code and a container build but no deployment
configuration, start Claude or a terminal in that project folder and say:

```bash
pilot ask "make this app deployable" --progress-card
```

Pilot inspects bounded repository evidence and prepares one Namespace, one
Deployment, and one Service under its user-owned run directory. It does not
write into the application repo. The human card shows what came from evidence,
which image and environment choices remain open, and one next action. The
engineer JSON retains hashes, source paths, generated objects, recommendations,
and non-claims.

That is the normal user path. Pilot maps the plain request to this Safe Actions
surface and keeps the function names hidden.

If you want the direct Safe Actions reference, run:

```bash
pilot safe-actions --query "scale this app" --progress-card
```

This is the same normal human view. It shows what Pilot matched, what it has
checked so far, what still needs live proof, one recommended next step, and a
short status that can be pasted into a review or chat.

For the fuller cockpit view with lanes, proof rows, fallback, and engineer
signals:

```bash
pilot safe-actions --query "scale this app" --render-cockpit
```

For automation:

```bash
pilot safe-actions --query "scale this app" --json
```

For the typed Progress Card:

```bash
pilot safe-actions --query "scale this app" --progress-card-json
```

For a machine score of the human surface:

```bash
pilot safe-actions --query "scale this app" --human-outcome-json
```

For engineer detail:

```bash
pilot safe-actions --query "scale this app" --engineer
```

The engineer view is where operation names and re-check commands belong. The
normal card should not make a beginner read them.

## Proof Boundary

Safe Actions do not mutate live systems by themselves. They are a route and
proof surface.

A Safe Action can show which action Pilot matched. It can show whether a typed function is available.
The function is optional. A direct edit path remains available.
Pilot can list the checks needed before rollout.
A local application Base can show the expected resource identities and deterministic object hashes.

A Safe Action cannot prove:

- ConfigHub approval;
- controller delivery;
- runtime state;
- GUI review;
- customer-sendable closeout.

Those require the normal Pilot proof chain and a receipt.
