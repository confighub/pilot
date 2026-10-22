---
description: Gate a proposed Pilot mutation against a named scenario contract before execution. Read-only.
argument-hint: "--command \"<command>\" [--contract <contract.yaml>]"
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
  - /pilot-gate
  - Pilot slash command
  - Claude Pilot adapter
---

# /confighub-pilot:pilot-gate

Classify a proposed mutation against a scenario contract before anything runs.

## What this command does

```bash
pilot gate --command "<exact next command>" --contract <contract.yaml> --json
```

Without a contract, the gate still returns a read-only classification of the
proposed command. A reviewed literal, context-bound ConfigHub mutation returns
`ASK / INTERACTIVE_HOST_REVIEW`; it does not take the dead-end delegated
executor route:

```bash
pilot gate --command "<exact next command>" --json
```

For the pre-risk route decision (no contract) and the repository gate, use:

```bash
pilot route "<intent or symptom>" --json
pilot release-gate --json
```

## What the user will see

- Decision: `ALLOW_READ_ONLY`, `ASK`, or `BLOCK`.
- Whether the proposed command is read-only, mutating, or unknown.
- Whether a contract path exists.
- The next safe action and receipt paths.

## Rules

- No mutation.
- Missing contract means `BLOCK` for unknown, unbounded, dynamic, destructive,
  direct-Kubernetes, or otherwise ineligible mutations. The reviewed
  interactive ConfigHub subset may return `ASK` without a scenario contract
  because the gate reuses the installed hook's exact static classifier.
- `INTERACTIVE_HOST_REVIEW` means submit that one unchanged command through the
  host permission path. Pilot-active Claude forces an allow/deny decision.
  Codex uses its ordinary tool permission policy and Pilot must not claim a
  separate human click when policy preauthorizes the call.
- Host permission authorizes only the attempt. Verify the resulting ConfigHub
  revision or Release with a separate read-only command and receipt the
  observation before claiming success.
- Contract-present mutation means `ASK`; it is not approval.
- `ALLOW_READ_ONLY` is not approval for a later mutation.
- Do not reuse approval after scope, target, provider, delivery path, or
  resource set changes.
