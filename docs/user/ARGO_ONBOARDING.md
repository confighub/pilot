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
  - adopt an existing Argo CD estate with ConfigHub
  - cub argo onboarding
  - move Argo Applications from Git to ConfigHub
---

# Bring an existing Argo CD estate under ConfigHub

Pilot can explain the reviewed Argo path. This guide reads no plugin, cluster,
or ConfigHub state. It does not install a plugin, create files, or perform a
handover. Argo CD remains the delivery controller; ConfigHub stores versioned
configuration and governs its releases.

New to ConfigHub? Start with [`ARGO_FIRST_LOOK.md`](ARGO_FIRST_LOOK.md).

## Check the installed plugin and your inputs

The published `cub-argo-v0.2.0` source is pinned to
[confighub/examples commit `59bfc5399f6f76825b115c56333b9bd654daa633`](https://github.com/confighub/examples/tree/59bfc5399f6f76825b115c56333b9bd654daa633/cub-argo).
The examples repository's current `main` is newer and is not this release.
This pin identifies reviewed source; it does not identify the binary installed
on your machine.

In your terminal, inspect `cub plugin list`, then read the installed
`cub argo plan --help` and `cub argo apply --help`. Check the reported plugin
version against v0.2.0 before relying on these examples. If you deliberately
choose to install the reviewed release, that is a separate local plugin
installation step requiring your decision:

```bash
cub plugin install confighub/examples@cub-argo-v0.2.0 --name argo
```

Start from the repository Argo CD actually syncs. The plan can read that
checkout offline. It can also consume an operator-made export of Applications,
ApplicationSets, AppProjects, and cluster names/servers/labels. Producing that
export is a separate Kubernetes read. Argo cluster Secrets may carry bearer
credentials in `.data.config` or in the
`kubectl.kubernetes.io/last-applied-configuration` annotation; do not save an
unredacted export. The plan needs names, servers, and labels, not credentials.
Keep the ConfigHub context, Argo management-cluster context, and each workload
destination context distinct.

## Plan offline, then inspect local output

For a repository with a `rollout-phase` cluster label:

```bash
cub argo plan /path/to/estate --stage-label rollout-phase --stages canary,secondary,primary
```

Planning reads the supplied repository/export and does not query ConfigHub or
a cluster. It expands the supported cluster, list, and matrix generators,
selected Go templates, label selectors, sync waves/windows, and image tags. The
offline planner does not invoke Kustomize or Helm chart rendering; generated
apply and handover scripts do use Kustomize for supported repository paths. A
nonzero plan result means stop and resolve the named input problem before
continuing. It does not inspect your live estate unless you separately create
and supply an export.

The v0.2.0 planner leaves out Git, SCM-provider, pull-request, merge, and plugin
generators; Sprig template functions; multi-source Application paths; Helm
chart sources; and plain-directory `include`, `exclude`, or jsonnet rules. It
does not invoke Kustomize or render Helm charts during planning. A plain directory is read recursively only
under the supported directory rules. The plan names unsupported shapes; do not
interpret a partial plan as coverage of the estate.

After reviewing a successful plan, `apply --out` writes manifests, plan output,
and scripts locally; it does not run them:

```bash
cub argo apply /path/to/estate --stage-label rollout-phase --stages canary,secondary,primary --out onboard
```

Read the generated files and scripts before deciding on any next step. In
particular, review what values they write and the exact ConfigHub context. The
generated `onboard/apply.sh` populates ConfigHub with a parallel copy while
Argo continues syncing Git. It is a ConfigHub mutation, not local planning, and
is not authorized by this Pilot guide. It does not change the cluster or
transfer delivery ownership. One operator running generated promotion,
approval, and publication steps is not independent approval.

## Check before a separate handover decision

The plugin's `check` compares a published Release with Argo's recorded
Application resources and destination objects. It is a live read. With
`--record`, it additionally writes a `LiveCheck` attestation to ConfigHub; keep
that write separate from a plain check. A clean check is scoped to what it
observed and is not immutable artifact proof: the reviewed implementation
resolves Release contents through mutable TagID-to-revision membership, so a
tag reassignment can make a later comparison read different revision data.

Handover is a separate cluster-changing approval boundary. Before it can
repoint anything, the Argo CD management cluster must be v3.1 or newer and each
AppProject must allow the gateway's `oci://` source in `sourceRepos`. If not,
stop and have the repository owner review and commit the AppProject change;
the script should stop rather than work around it with an unreviewed patch.
Use the exact Argo management context separately from every destination
context. The v0.2.0 scripts check release contents against Argo-owned objects,
preserve names/UIDs, and print a way back, but this source review is not proof
about your estate. Stop on a failed comparison, unexpected pruning, ownership
gap, or unclear recovery.

The way back starts by restoring every moved Application/ApplicationSet source
to Git and verifying that Argo reads Git again. Only then may an operator
review the generated cleanup procedure for removing the ConfigHub copy and
gateway credential. Cleanup is not rollback while any Application still reads
ConfigHub. This guide intentionally does not compose cleanup or deletion
commands.

## Status is a separate write by default

After handover, `cub argo status` reads Argo's live state and by default writes
`confighub.com/live-status` into ConfigHub. `--watch` repeats that reporting;
`--hard-refresh` additionally annotates Argo Applications to ask them to read a
new release. Source exposes `--dry-run`: it still reads live state, but skips
the ConfigHub write and does not initialize the hard-refresh writer. This is a
source-level plugin behavior, not an invocation Pilot currently offers. An
argobot installation is another cluster mutation and is not part of this
read-only route.

On ConfigHub server 0.8.2 and later the health gate reads the newest
Release's status, not the `confighub.com/live-status` annotation.

Keep ConfigHub intent, Argo's controller state, Kubernetes runtime state, and
missing proof separate. A status report is not a fresh receipt of every
resource's exact running bytes. This guide is source-pinned guidance, not an
installation check, a plan run, a live rehearsal, or evidence about your
estate.
