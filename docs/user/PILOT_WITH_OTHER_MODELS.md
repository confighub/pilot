---
shelf: product-doctrine
status: current
audience: users
owner: pilot
portable: true
package: pilot-corpus
retrieval_triggers:
  - other models
  - multi-model
  - local model
  - model scoring
used_by:
  - docs/user/README.md
  - docs/engineering/LOCAL_MODEL_PROOF.md
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
retrieval_triggers:
  - other models
  - multi-model
  - use Pilot with another model
  - local model
  - Pi
---

# Pilot With Other Models

Pilot works with more than one AI model. This page says what that means
today, what it does not mean, and gives you the exact commands.

## What this is, in one paragraph

Pilot itself never talks to a model vendor. When a model is involved, Pilot
runs a command you supply, or a bounded lane a maintainer supplies, and it
records what happened. That keeps three things true at once: your credential
never enters Pilot's code, a different model never changes what Pilot is
allowed to do, and every model interaction leaves a receipt.

## What you can do today

### 1. Score Pilot's own surfaces with any model you have

`pilot ux-sim` walks every canonical journey and scores what a first-time
user would see. With `--with-model` it adds a second, advisory layer: one
model invocation plays a first-time user reacting to the surface, and a
separate invocation judges that reaction. The judge never scores its own run.

```
pilot ux-sim --with-model --model-cmd "claude -p" --json
```

`--model-cmd` is any command that reads a prompt on stdin and writes its
reply on stdout. `claude -p` works. A local runner works. A shell script
that calls your own endpoint works. Pilot does not know or care which vendor
is behind it.

Model scores are advisory. They never gate a release, and they never turn a
WATCH or BLOCK into a PASS. Raw model output is never written to disk --
only digests, scores, and a one-line justification.

### 2. Prove a specific model lane end to end (maintainers)

The model adapter lab proves that a real model, on a real transport, can
drive one bounded, read-only Pilot tool call and produce a schema-valid
receipt. Three lanes exist:

| Lane | What it proves | Needs |
|---|---|---|
| Fixture | The adapter boundary itself, offline | nothing |
| Local | A local model through Ollama | Ollama running |
| Hosted | A credentialed hosted model through Pi | an API key |

The hosted lane accepts exactly two upstream profiles -- `moonshot`
(`KIMI_API_KEY`) or `openrouter` (`OPENROUTER_API_KEY`). Free-form upstream
URLs are refused by design.

```
./tools/maintainer/pilot-model-adapter-compatibility-lab \
  --pi-rpc-kimi-model <pi-command> \
  --kimi-upstream openrouter \
  --json
```

### 3. How the credential is handled

The model process never sees your key. It talks to a validating loopback
guard that holds a non-secret sentinel. The guard alone reads the real
credential from the environment, attaches it upstream, and never records it.
Before any receipt is returned, a redaction check runs over the serialized
receipt. If your key ever appeared in output, that run would fail rather
than ship the receipt.

### 4. Work from Codex instead of Claude

Pilot ships a Codex adapter as well as a Claude one. Both reach the same core.
Run `pilot codex` to print the Codex contract for this repository: the
entrypoints Codex should use, the cold-start rule it must follow, the Claude
surfaces that are deliberately not portable to Codex, and the actions that stay
blocked in either host. Read it before you drive Pilot from Codex, because the
slash commands, hooks, and status line of the Claude companion have no Codex
equivalent, and Pilot will not pretend otherwise.

## What this is not

- **Not model routing.** Pilot does not pick a model for you, and no Pilot
  decision changes because a different model is attached. Routing, approval,
  and proof stay Pilot's, whatever the model.
- **Not a certification.** A model lane receipt proves that lane worked at
  that moment on that machine. It does not make model output trusted: model
  answers stay advisory, and typed outcomes still come only from Pilot.
- **Not activation.** Attaching a model grants no new authority. The
  approval boundary is the same one every Pilot action already passes
  through.

## Where results land

Lab receipts and ux-sim scorecards are written under your Pilot reports
directory, each validating against its published contract, so a run made
with one model can be compared byte-for-byte with a run made with another.

For the maintainer-level proof chain -- exact Pi version, dependency-closure
digest, Node digest, model manifest bracket -- see
`LOCAL_MODEL_PROOF.md`.
