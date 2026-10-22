---
description: Ask Pilot to route one request, choose one safe next move, and optionally run the selected read-only helper.
argument-hint: "<intent, repo, symptom, session, URL, or proposed command>"
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
  - /pilot-ask
  - Pilot slash command
  - Claude Pilot adapter
---

# /confighub-pilot:pilot-ask

Ask Pilot to route, help, verify, or prepare learning from one request.

## What this command does

Run:

```bash
pilot ask "$ARGUMENTS" --force-color
```

If the user supplied a repo, session file, ConfigHub URL, cluster context, or
proposed command in surrounding context, pass it explicitly:

```bash
pilot ask "$ARGUMENTS" \
  --repo <path> \
  --session <path> \
  --config-url <url> \
  --cluster-context <context> \
  --command "<proposed command>" \
  --force-color
```

Supported explicit controls include `--phase`, repeatable `--evidence-file`,
`--space`, `--spaces-receipt`, `--expected-org`, `--target`, `--access-unit`,
`--target-scope-digest`, `--namespace`, `--session-id`, `--out-dir`,
`--run-read-only`, `--timeout`, `--json`, `--progress-card`,
`--progress-card-json`, `--force-color`, and `--plain`. Pass only controls
supported by `pilot ask`; the retired `pilot automate`-only route is not a
separate slash command.

Use `--json` only when you need machine-readable fields. The visible user path
is the human rendering: route, context, memory match, next move, stop signals,
proof owed, and artifact paths.

## What the user will see

- The route decision: `ALLOW`, `BLOCK`, `ASK`, or `READ_MORE`.
- A short explanation of what each section means.
- One recommended next command.
- Solution-card matches that influenced the route.
- Stop signals before live mutation, issue filing, activation, or upload.
- A durable session at `reports/pilot-automations/<session>/automation.json`.

## Rules

- Treat this command as the conversational product doorway, not as the brain
  itself. The brain lives in the shared Pilot ask implementation.
- No live mutation from this command.
- If the next move mutates, gate it first with
  `pilot gate --command "<exact next command>" --contract <contract.yaml> --json`
  (or `pilot route "<intent>" --json` for the pre-risk decision)
  before any write.
- Do not claim Pilot learned the lesson until it is promoted into a solution
  card, product gap, or one-off log entry.
- Recommend one next move, not a menu.
- Pass the person's words to `pilot ask` unchanged. Rewording them can match a
  different solution card.
- Put the person's words inside single quotes, not double quotes. Inside
  double quotes the shell runs anything written in backticks or `$(...)`.
- When the card says Pilot matched a known situation, follow the steps it
  lists, in order, and say they are Pilot's known steps for that situation.
- Preserve the terminal rendering. Let the command's colored human output be
  visible before summarizing it; do not hide the product surface behind raw
  JSON.
- Do not end with "Want me to do X or Y?" unless the decision is `ASK` and the
  exact approval choice is the product output. If the next move is read-only,
  name it as **Next move** and stop.
- Do not invent auth state. This command does not check ConfigHub auth unless
  the command output or a separate `cub` check proves it. If auth matters,
  say "auth was not checked by this Pilot ask pass" rather than contradicting
  the status line.
- Keep the closeout compact: route, object/context, one solution match, next
  move, proof still owed, artifact path.
- If the user explicitly said to continue or run the read-only helper, rerun
  with `--run-read-only`; otherwise stop after the route pass.
