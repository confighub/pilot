---
shelf: product-doctrine
status: current
audience: users
owner: pilot
portable: true
package: pilot-corpus
used_by:
  - docs/user/PILOT_PROGRESS_WIDGET.md
  - docs/user/WHAT_CAN_I_DO_TODAY.md
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tests/test-pilot-local-kind-live-proof
retrieval_triggers:
  - first live win
  - cub cluster
  - cub lk
  - governed delivery proof
  - local kind live proof
  - one live first win
  - ConfigHub OCI Argo
---

# Pilot First Live Win

Status: release-blocked at the authenticated-approval boundary.

Pilot does not currently have an authoritative first-live-win execution path.
The ConfigHub -> OCI -> Argo -> Kubernetes delivery design and its deterministic
postchecks remain in the product, but the current repo has no trusted verifier
for an external human approval attestation.

## Why the lane is blocked

The generated Variant, Promotion, Unit, and Release review records are ordinary
same-user JSON files. A model or any process running as that user can write
`status: APPROVED`, a name, and a timestamp. A self-digest, a canonical local
path, existing ConfigHub IDs, or a host-local lock can show consistency and
provenance; none authenticates the person who supposedly approved the change.

Pilot therefore interprets a completed local record as:

- `WATCH / LOCAL_ACKNOWLEDGEMENT_SELF_ASSERTED` for review metadata; and
- `BLOCK / AUTHENTICATED_APPROVAL_ATTESTATION_REQUIRED` for mutation authority.

The governed executor returns that blocker before claiming an idempotency key,
claiming a disposable token, or invoking a mutating Cub command. A disposable
live-proof JSON bundle is also same-user local evidence and cannot bypass the
gate. Receipt signoff and GUI confirmation cannot upgrade it to `PASS`. It is
not customer-sendable.

## What the governed diagnostic does today

```bash
./scripts/pilot local-kind-live-proof \
  --governed \
  --execution-approval-window 300 \
  --progress-card
```

The first invocation performs a read-only organization check and asks you to
confirm the exact preview organization. The continuation then stops before
setup: invoking a wrapper (even with explicit flags) is not an authenticated
human approval event because a model can invoke the same wrapper and its
subprocesses do not cross the host approval hook. Pilot therefore:

1. verifies ConfigHub authentication and the selected organization read-only;
2. returns `AUTHENTICATED_APPROVAL_ATTESTATION_REQUIRED` for the disposable
   setup proposal;
3. does not run `cub cluster up` or any ConfigHub/Kubernetes write; and
4. records teardown as `SKIP / NOT_CREATED`.

This is a blocker demonstration, not a successful first live win. Do not use a
raw `cub variant create` or `cub release publish` to route around it in a
Pilot-active session.

## Expected outcome

The delivery authority row is `BLOCK`, even if the local record contains a
claimed name and time. The Progress Card must say that authenticated external
approval is unavailable. It must not say “Named people approved,” count local
acknowledgement as a completed authority step, or claim that a mutation ran.

Cleanup can independently be `PASS`. A successful cleanup row does not erase
the delivery blocker.

The existing 12-layer first-live-win proof contract remains a compatibility
receipt shape; the authority fix does not delete its Target-binding or GUI-
confirmation slots. The current diagnostic must not reuse the historical
ten-complete-layer success card: authenticated approval is `BLOCK`,
delivery layers that did not run remain `NOT_RUN` or `WATCH`, Target binding
remains a separate provider-atomicity obligation, and GUI confirmation remains
unproven.

The useful artifacts are:

- executor/live-proof JSON: the stable authentication blocker;
- `receipt.json`: split delivery and cleanup outcome;
- `teardown.json`: exact dependency-web cleanup evidence; and
- the human Progress Card and engineer detail.

## Historical evidence

A July 6, 2026 Pilot v0.1.6 run demonstrated the compatibility delivery chain on
a disposable cluster: ConfigHub held the Unit, OCI publication occurred, Argo
reported reconciliation, Kubernetes ran the workload, and teardown completed.
That evidence predates the current approval-authenticity analysis. It is useful
delivery-chain history, not proof that the present approval gate authenticates a
human or that the current release may repeat the mutation.

The retired exact-Unit-apply review and tests remain `VERSIONED_LEGACY`; current
profiles do not select or execute that mutation. The current intended topology
is base Component -> deployment Variant -> tagged Space Release.

You can still inspect any retained historical or blocked receipt read-only with
`pilot review-packet --from-receipt <receipt> --render-cockpit`, or by asking
Pilot to show the full cockpit or saying **"Pilot, show engineer details."**

Rendering changes presentation only; it does not upgrade the receipt's evidence
class, authority, or customer-sendability.

## What must exist before this can become a live win

A safe successor needs all of the following:

1. a trusted external approval provider and verifier, outside the model-writable
   local state boundary;
2. an authenticated approver identity and approval event;
3. an attestation that binds the complete canonical review-subject digest,
   including command, immutable object identities, scope, Target, all effects,
   compatibility/runtime policy, inputs, expiry, and non-claims;
4. replay protection and revocation/expiry handling enforced by the trusted
   verifier;
5. a new approval after any authority-relevant field changes; and
6. for authoritative Release publication, provider expected-manifest
   compare-and-swap support in addition to human approval authentication.

Only then may the retained mutation and postcheck machinery be made reachable.
The resulting receipt must keep approval authentication, provider atomicity,
ConfigHub intent, controller convergence, runtime state, GUI confirmation, and
cleanup as separate evidence rows.

## Where the implementation lives

- Proposal/readback runtime with a current model-side write stop:
  `scripts/pilot-execute-approved`
- Approval integrity and read-only binding helpers:
  `scripts/pilot_execution_approval_lib.py`,
  `confighub_pilot/runtime/promotion_execution.py`, and
  `scripts/pilot_release_approval_lib.py`
- Governed diagnostic and receipt renderer: `scripts/pilot-local-kind-live-proof`
- Deterministic coverage: `tests/test-pilot-execute-approved`,
  `tests/test-pilot-promotion-execution`, and
  `tests/test-pilot-local-kind-live-proof`
- Normative boundary: `docs/engineering/OPERATIONAL_INVARIANTS.md`
