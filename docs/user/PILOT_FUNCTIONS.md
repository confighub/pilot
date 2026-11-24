---
shelf: product-doctrine
status: current-with-review
audience: users
owner: pilot
portable: true
package: pilot-corpus
used_by:
  - README.md
  - docs/user/PILOT_SAFE_ACTIONS.md
  - docs/user/PILOT_CATALOG.md
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tests/test-pilot-safe-actions
  - tests/test-pilot-catalog-spine
  - tools/audits/audit-pilot-package-manifest
retrieval_triggers:
  - ConfigHub functions
  - Pilot functions
  - function library
  - typed operations
  - Safe Actions and functions
---

# ConfigHub Functions In Pilot

Pilot can use ConfigHub functions, but it should not make a normal user start
by choosing a function.

The human door is a Safe Action:

```bash
pilot ask "scale this app" --progress-card
```

That card should say the plain thing first:

```text
Pilot can change only the replica count, show the diff, and check the result
before rollout.
```

If a typed ConfigHub function fits, Pilot can show it in engineer detail:

```bash
pilot safe-actions --query "scale this app" --engineer
```

That is where names such as `set-replicas`, `set-container-image`, or
`vet-schemas` belong.

## The Product Rule

Use functions as an optional power layer, not as the beginner interface.
Safe Actions are the human door. Functions are the optional engineer and
automation path behind that door.

Pilot should:

1. understand the user's plain-language request;
2. map it to a Safe Action when a known operation fits;
3. keep a direct ConfigHub edit path available;
4. show the diff, checks, proof gaps, and approval scope before rollout;
5. show function names only in engineer, automation, or review detail.

This matters because many users do not want to learn a function library before
they can make a safe change. They want to know what Pilot can do, what it will
touch, what it checked, and what still needs proof.

## What Functions Add

Functions can make Pilot stronger when they are used behind the right human
surface.

They can provide:

- narrow repeatable changes, such as changing one replica field;
- reusable validation, such as schema, placeholder, or immutable-field checks;
- a better audit trail than a raw YAML edit;
- a stable operation that can be tested and reused across scenarios;
- an engineer-readable path for debugging and automation.

They do not replace approval, controller proof, runtime proof, GUI review, or
receipts.

## Discovery Paths

For users:

```bash
pilot ask "scale this app" --progress-card
pilot ask "create a namespace" --progress-card
pilot ask "check before promotion" --progress-card
```

For engineers and reviewers:

```bash
pilot confighub-surface --progress-card
pilot confighub-surface --engineer
pilot safe-actions --query "scale this app" --engineer
pilot safe-actions --query "scale this app" --json
pilot catalog --render-cockpit
```

The first group should stay friendly and outcome-led. The second group can show
function names, typed operation metadata, proof requirements, and machine
receipts.

Use `pilot confighub-surface --progress-card` when the question is broader
than one action: "What ConfigHub tools does Pilot know about here?" It checks
the local `cub` command surface, `cub-scout` binary presence, the digest-pinned
static Scout effect policy, the skill-set registry, the provider registry, Safe
Actions, and the Claude MCP declaration without mutating anything. Use
`--engineer` when you want the internal names.

The engineer view is intentionally more explicit. It reads local `cub --help`
output and groups the result into command families such as auth and context,
ConfigHub objects, governed change, functions, delivery, browser apps, GitOps
evidence, runtime observation, impact checks, receipts, and ConfigHub Views.
Because `cub-scout` is a mixed read/write binary, Pilot does not execute its
local help surface: it reports binary presence separately and discloses only
the exact advisory-WATCH rows in the digest-bound static Scout effect policy.
That helps maintainers compare the actual local `cub` surface with the
separately declared, pinned Scout policy. It does not present the policy rows as
an observed local Scout command surface; the human card stays focused on
outcomes and next steps.

## Current Boundary

Today, Pilot's function support is discoverable through Safe Actions. The
catalog records which actions have an optional typed operation path and which
also have a direct path.

Pilot should not claim that every ConfigHub function is wrapped as a Safe
Action. A function becomes product-ready when it has:

- a human outcome name;
- a direct fallback;
- proof requirements before rollout;
- tests for route selection and non-mutation;
- an engineer view that exposes the underlying operation.

That is the boundary that keeps functions powerful without making Pilot feel
like a function picker.
