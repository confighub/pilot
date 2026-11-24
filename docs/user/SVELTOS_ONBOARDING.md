---
shelf: product-doctrine
status: current
audience: users
owner: pilot
portable: true
package: pilot-corpus
used_by:
  - scripts/pilot-automate
  - docs/user/HOW_TO_USE_PILOT.md
  - docs/user/README.md
enforced_by:
  - tests/test-pilot-gitops-plugin-knowledge
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tools/audits/audit-md-corpus-shelves
retrieval_triggers:
  - sveltos onboarding
  - adopt sveltos
---

# Bring a Sveltos fleet into ConfigHub

Pilot starts with your existing fleet export and the `cub sveltos` offline plan.
It helps you review the proposed configuration before any upload or handover.
It does not install the plugin or execute its generated scripts for you.

A ClusterProfile tells Sveltos what to deliver. Your existing profiles may
select clusters by label. The plugin resolves those selections into shared
bases and per-cluster variants. A base holds shared configuration; a variant
holds one cluster's departures from it. Generated delivery profiles each name
one cluster. The repository's `examples/onboard` selector files are sample
inputs, not evidence of your deployed fleet.

## Plan from your own export

Before collecting the export, confirm the active Kubernetes context is the
Sveltos management cluster. In YOUR terminal, run this read-only check:

```bash
kubectl config current-context
```

Read the installed plugin's version and help first. This guide reviews
[sveltos-confighub v0.11.0](https://github.com/confighub/sveltos-confighub/blob/65a14ecb2943b0d177932f2f0c601dbe22d1a436/cmd/root.go).
If the installed version differs, check its commands before using these examples.

Your export needs ClusterProfiles, SveltosClusters and the ConfigMaps referenced
by `policyRefs`. Confirm that it contains the intended selector matches. Treat
exports as sensitive: keep Secret values and credentials out of review files,
and do not commit unredacted exports. The following is an example for an export named
`my-fleet.yaml`, with an `env` label and `staging` and `prod` stages. Replace these
with your reviewed file and labels. You run the command in your own terminal.

```bash
cub sveltos plan my-fleet.yaml --stage-label env --stages staging,prod
```

Planning changes no ConfigHub or cluster objects and needs no ConfigHub account.
Chart rendering can require `cub-helm` and chart repository access: offline
planning does not mean network-free rendering. Review the rendered configuration,
matched clusters, stage order, and printed Space and Link counts. A Space is
ConfigHub's versioned folder for configuration. A Unit is one versioned piece
of configuration; a Link connects related Units.

## Review the generated work

After reviewing the plan, the plugin's `apply` command generates files. It does
not execute them. This example writes to a local `onboard` directory:

```bash
cub sveltos apply my-fleet.yaml --stage-label env --stages staging,prod --out onboard
```

Review manifests and scripts before running anything. Generated `apply.sh`
creates ConfigHub objects, promotes and publishes configuration, and installs
management-cluster profiles and health checks. Plugin installation and script
execution need their own review and approval. A single operator's generated
approval flow does not establish an independent reviewer.

For existing live profiles, separately review `handover.sh`, which changes
ownership. Do not use the historical `takeover.sh` name. Stop on unresolved
render differences, field ownership, Secret values or recovery gaps. Keep the
ConfigHub context separate from the management and workload Kubernetes contexts.
This guide grants no live mutation permission and supplies no teardown commands.

When a cluster joins later, refresh the export and review a new plan and apply
output. Previous planning is not evidence that the new cluster is covered.

## Check health without overstating delivery

The plugin can install a ClusterHealthCheck (CHC), a Kubernetes resource type
for continuous post-apply health checks on Deployments, StatefulSets and
DaemonSets. The check type matters: `Addons` reports the ClusterProfile's own
`Provisioned` or `Failed` status; it does not show whether a named workload
remains healthy. Use the `HealthCheck` liveness type with a script that names
the workloads to check their health. This behavior is described in the
[source-pinned Sveltos known-behaviours guide](https://github.com/confighub/sveltos-confighub/blob/b7c6ee074bf84e19fbec45b3c217cde7e2e676e1/docs/user/known-behaviours.md)
(main snapshot; a documentation clarification, not a new runtime release). If
the CHC resource type or a workload-aware `HealthCheck` is absent,
the reporter may still say `Healthy` from apply-time validation plus Sveltos
`Provisioned` state; that is not continuous workload-health evidence.
`cub sveltos status` is not a read-only inspection by default: it writes live
status into ConfigHub; `--dry-run` opts out. The reporter
infers Release identity by comparing Release `CreatedAt` with Sveltos
`lastAppliedTime`; it does not observe the fetched OCI digest. A matching
inferred digest can move the ConfigHub ChangeOrder, so this is a consequential
association, but it does not establish that the exact published bytes are
running.

Keep ConfigHub intent, controller state, runtime state and missing proof separate.
Pilot's `delivery-trace` currently checks Argo only; it is not a Sveltos verifier.
The [reviewed reporter source](https://github.com/confighub/sveltos-confighub/blob/65a14ecb2943b0d177932f2f0c601dbe22d1a436/internal/onboard/status.go)
and [upstream guide](https://github.com/confighub/sveltos-confighub/blob/65a14ecb2943b0d177932f2f0c601dbe22d1a436/docs/user/onboard-your-sveltos-fleet.md)
explain these limits. This is source-based guidance, not a new live rehearsal.

## Gaps to review before handover

At the 2026-09-30 review, upstream follow-ups remain open for
[field attribution](https://github.com/confighub/sveltos-confighub/issues/88),
[rollback](https://github.com/confighub/sveltos-confighub/issues/89),
[keeping Secret values out of ConfigHub](https://github.com/confighub/sveltos-confighub/issues/90),
the proposed [variant-create flow](https://github.com/confighub/sveltos-confighub/issues/91),
and the [handover transition](https://github.com/confighub/sveltos-confighub/issues/92).
Continuous health work in [issue #71](https://github.com/confighub/sveltos-confighub/issues/71)
is shipped; other proposed fixes are not shipped behavior.

Kubara has a different onboarding path. Kubara v0.2.3 fixed
[issue #25](https://github.com/confighub/kubara-confighub/issues/25): a policy
Pass no longer masks Argo Degraded or Missing health; Progressing is treated as
not yet complete and is not recorded. It also fixed
[issue #26](https://github.com/confighub/kubara-confighub/issues/26) by
installing argobot during handover to write live status. A remaining
[argobot #13](https://github.com/confighub/argobot/issues/13) name mismatch
prevents release-triggered refresh from finding Kubara's Applications; Argo's
own polling remains the fallback. Kubara v0.2.4 makes separate stage approvals
opt-in with `--approve-stages`; by default the runner approves every stage.
Running `kubara bootstrap` after handover restores Git sources and hands
delivery back to Git; documented recovery is to rerun handover. Keep policy
results, controller health and this release-refresh limitation distinct.
