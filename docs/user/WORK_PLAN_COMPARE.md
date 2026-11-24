---
shelf: product-doctrine
status: current
owner: pilot
portable: true
audience: users
package: pilot-corpus
used_by:
  - Pilot offline work-plan comparison
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tests/test-pilot-work-plan-compare
retrieval_triggers:
  - compare agentic work plans
  - estimate worker cost and speed
  - bounded FinOps planning
---

# Compare offline work plans

Pilot can compare two or three proposed sequential plans for one current
solution. A sequential plan is an ordered list of work, including any allowed
retry, escalation, tool charge, and verification step. The comparison keeps
the current solution's required proof checks fixed while showing supplied cost
and elapsed-time ranges.

## What you bring

Bring the task's current solution ID and SHA-256 of that exact solution file,
acceptance criteria, and two or three explicit plans. The plan JSON also needs
its own raw-byte SHA-256 for the command below; this binds the complete supplied
input file. Each plan needs the declared worker alias and
rate profile for every step, explicit work-item attempt bounds, time ranges,
and separate usage ranges for input, output, and every other quantity priced
by that profile (such as cache reads or writes). These are distinct billable
quantities; Pilot does not infer them from cumulative provider counters. Include every allowed attempt. If a deterministic
or no-model step uses no tokens, say so with input and output usage rows whose
low and high are both `0`, each with a provenance reference. Missing usage or
rates stay unknown; Pilot does not treat an omitted field as free.

Supply a dated rate snapshot with one or more named profiles. Each profile
includes its currency, publisher/source, effective time, validity window, and
per-category prices and provenance references. This information is an input
from you; Pilot does not look up providers, verify a quote, convert currency,
or infer prices from a model name. Tool, app, and operations charges must be
explicit already-priced amounts with currency, coverage, provenance, and
validity. Ongoing or unbounded charges remain a gap.

## Compare now

In your terminal, run the direct read-only command with the exact plan file and
its raw-byte digest:

```text
pilot work-plan-compare --plan /path/to/plan.json --expected-sha256 <64-lowercase-hex-digest>
```

Pilot rejects oversized, duplicate-key, non-finite, floating-point, or
contract-invalid input. The command reads no live provider, ConfigHub, or
cluster state and executes no plan. An `ASK` or `WATCH` comparison is a
successful classification; malformed input returns an error.

The card names its supplied analysis timestamp, rate-profile IDs and validity,
cost and sequential-time envelopes, proof gaps, and uncertainty. Rates and
usage are caller-supplied estimates, not observed spend or a current provider
quote. The exact receipt retains the arithmetic used for eligibility and
ranking. Its human currency display rounds the lower bound down and upper
bound up at the selected display precision.

If more detail is needed, say **“Pilot, show me the full cockpit”** or **“Pilot,
show engineer details.”** Pilot follows the card's typed action, which carries
the same plan file, raw digest, and task context into the detail view.

## Synthetic illustration only

The repository fixture uses synthetic USD rates of $0.01 per 1,000 input
tokens and $0.03 per 1,000 output tokens. It compares a bounded worker with
one explicitly priced conditional retry and a verifier against a single-pass
worker with the same verifier. Its envelopes overlap, so it asks rather than
declaring a lowest-cost winner. These figures are test arithmetic only; they
are not market rates, product pricing, expected savings, or a forecast.

## What comes next

This first comparison is offline and considers only the supplied complete
plans. A later review can compare actual results with the estimates and
acceptance checks, if those observations are collected under a separate
contract. Until then, the comparison does not establish reliability, quality,
task success, a global optimum, or that a plan can meet its estimates.

Pilot does not dispatch work, approve a change, reserve or enforce a budget,
or prove that planned checks passed. A spend ceiling is only a conservative
estimate constraint. No billing integration, concurrency-safe reservation,
parallel scheduler, or provider lookup is included.
