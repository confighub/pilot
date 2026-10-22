---
description: 'Choose the first safe Pilot quickstart path: read-first Pilot map or approval-gated cub cluster sandbox proof.'
argument-hint: "[intent | --mode scout-first|sandbox-proof]"
allowed-tools: [Bash, Read]
shelf: command-prompt
status: current
owner: pilot
portable: true
package: pilot-adapter
used_by:
  - scripts/pilot-claude-adapter
enforced_by:
  - scripts/pilot claude smoke --validate-claude --json
  - scripts/pilot release-gate --json
retrieval_triggers:
  - /pilot-quickstart
  - Pilot slash command
  - Claude Pilot adapter
---

# /confighub-pilot:pilot-quickstart

Choose the first safe Pilot quickstart path.

## What this command does

Run:

```bash
pilot quickstart "$ARGUMENTS"
```

Use explicit modes when the user's intent is already clear:

```bash
pilot quickstart --mode scout-first
pilot quickstart --mode sandbox-proof
```

## What the user will see

- Recommended path: read first with Pilot's typed `map` route.
- Alternative path: prove live behavior in a disposable `cub cluster` kind sandbox.
- A compact Cockpit row for both paths.
- The first read-only command or the approval question needed before sandbox setup.
- Stop signals that prevent import, apply, `cub cluster up`, or Kubernetes writes during route selection.

## Rules

- No mutation from this command.
- Default to the read-first Pilot map branch unless the user explicitly asks for sandbox proof.
- The sandbox branch must require explicit approval before `cub cluster up`.
- Do not claim ConfigHub, controller, Kubernetes, or GUI proof from this route packet.
- If the user approves sandbox setup, continue through the normal Pilot gate and receipt path, naming rig, space, kubeconfig path, teardown, proof obligations, and scope.
- Say where each command runs. When the user is doing the typing, direct `cub cluster up` and `cub cluster down` belong in the USER'S own terminal, one command per fenced block. In the assistant shell, one literal `cub cluster up` or `cub cluster down` goes to the host's ask prompt, which names the local cluster; `cub cluster down --delete-config` stays blocked and is planned with `pilot teardown-plan`. Pilot's stronger delegated route is `pilot local-kind-live-proof --governed`. Warn that a cluster command streams output for minutes in the user's terminal and that nothing appears in the chat until they paste it (or run the block themselves when the host offers a Run button).
