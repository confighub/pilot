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
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tests/test-pilot-gitops-plugin-knowledge
retrieval_triggers:
  - adopt an existing Flux fleet with ConfigHub
  - cub flux onboarding
  - move Flux layers from Git to ConfigHub
---

# Bring an existing Flux fleet under ConfigHub

Pilot can explain the reviewed Flux path. This guide reads no plugin, cluster,
or ConfigHub state. It does not install a plugin, create files, or perform a
handover. Flux remains the delivery controller; ConfigHub stores versioned
configuration and governs its releases.

New to ConfigHub? Start with [`FLUX_FIRST_LOOK.md`](FLUX_FIRST_LOOK.md).

## Check the installed plugin and your inputs

The published `cub-flux-v0.2.0` source is pinned to
[confighub/examples commit `59bfc5399f6f76825b115c56333b9bd654daa633`](https://github.com/confighub/examples/tree/59bfc5399f6f76825b115c56333b9bd654daa633/cub-flux).
The examples repository's current `main` is newer and is not this release.
This pin identifies reviewed source; it does not identify the binary installed
on your machine.

In your terminal, inspect `cub plugin list`, then read the installed
`cub flux plan --help` and `cub flux apply --help`. Check the reported plugin
version against v0.2.0 before relying on these examples. If you deliberately
choose to install the reviewed release, that is a separate local plugin
installation step requiring your decision:

```bash
cub plugin install confighub/examples@cub-flux-v0.2.0 --name flux
```

Start from the Git repository that defines the fleet: one cluster directory
per cluster and Flux Kustomizations/layers in their declared dependency order.
The planner works offline on that repository; it does not discover a live
cluster or export live Kustomizations. Keep the ConfigHub context separate from
the Flux cluster's Kubernetes context, and use the exact cluster context for
any later check or handover.

## Plan offline, then inspect local output

```bash
cub flux plan /path/to/fleet
```

Planning reads the repository only; it does not invoke Kustomize. It describes
the source shape Flux uses: a layer with `kustomization.yaml` is built by
kustomize-controller, while a plain layer is built from YAML files recursively
and a subdirectory with its own `kustomization.yaml` is built as a whole rather
than flattened into the parent. Non-YAML files in a plain layer are reported
because Flux would fail to build them. The generated apply and handover
scripts do render supported paths with Kustomize.

The v0.2.0 planner does not use a live cluster export, OCIRepository or Bucket
sources as layer inputs, `substituteFrom` values, or rendered Helm/Kustomize
output. It reads source files and does not promise the live controller's
result for those unsupported inputs. Stop if the fleet relies on one of those
shapes; do not treat a partial plan as coverage.

After reviewing a successful plan, `apply --out` writes local manifests,
workflow files, and scripts; it executes none of them:

```bash
cub flux apply /path/to/fleet --out onboard
```

Read the generated output and scripts before deciding on any next step. The
generated `onboard/apply.sh` fills ConfigHub with a parallel copy and one
layers Space per cluster. It needs the gateway host as each cluster reaches
it (`CONFIGHUB_OCI`); it does not change the cluster. This is a ConfigHub
mutation, not local planning, and this guide does not authorize it. A ConfigHub
context, the gateway address, and a Kubernetes context are separate bindings.

## Check before a separate handover decision

The plugin's `check` reads Flux's `status.inventory` and compares it with the
published Release. It is a live read; `--record` additionally writes a
`LiveCheck` attestation to ConfigHub. Keep that write separate from a plain
check. A check is not immutable artifact proof: the reviewed implementation
resolves Release contents through mutable TagID-to-revision membership, so a
tag reassignment can make a later comparison read different revision data.

Handover is a separate cluster-changing approval boundary. For a fleet already
running layers from Git, the script adds a ConfigHub root and changes the
layers' `sourceRef` and `path`. `flux-system` stays on Git as the bootstrap and
recovery path. If multiple Kustomizations own the layers, or the owner is not a
Git source, the script stops before changing ownership. When one Git-backed
Kustomization such as `flux-system` owns them, handover is already a cluster
mutation: the script suspends that owner, installs the root, and moves the
layers before it pauses for a reviewed Git commit that removes the layer files
and makes the root durable. Do not resume `flux-system` by hand before that
commit is what it reads; it could reapply the old Git layers. Rerun the script
only after the repository owner has made the specified commit and the script's
pause conditions are understood.

The generated way back is ordered: disable root pruning, restore both
`sourceRef` and `path` for each layer, then remove the root; remove the root's
OCIRepositories only after layers read Git again. For a bootstrapped fleet,
return the root/layers to the Git revision first, then resume the bootstrap
owner. Only after delivery is back on Git should an operator review the
generated cleanup for ConfigHub objects. This guide intentionally does not
compose cluster mutation or deletion commands. Stop on unknown ownership,
failed comparisons, or a missing commit/recovery path.

## Status is a separate write by default

After handover, `cub flux status` reads live Flux state and by default writes
`confighub.com/live-status` into ConfigHub. Source exposes `--dry-run`: it still
reads live state but skips that ConfigHub write. This is a source-level plugin
behavior, not an invocation Pilot currently offers. `cub flux check` remains a
separate comparison command; adding `--record` writes an attestation.

On ConfigHub server 0.8.2 and later the health gate reads the newest
Release's status, not the `confighub.com/live-status` annotation.

Keep ConfigHub intent, Flux controller state, Kubernetes runtime state, and
missing proof separate. A status report is not by itself fresh proof of every
resource's exact running bytes. This guide is source-pinned guidance, not an
installation check, a plan run, a live rehearsal, or evidence about your
fleet.
