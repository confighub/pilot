---
shelf: product-doctrine
status: current
audience: users
owner: pilot
portable: true
package: pilot-corpus
used_by:
  - docs/user/README.md
  - docs/user/INSTALL_PILOT.md
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tools/audits/audit-pilot-package-manifest
  - tests/test-pilot-doc-reference-integrity
  - tools/audits/audit-md-corpus-shelves
  - tests/test-pilot-public-channel
retrieval_triggers:
  - troubleshooting Pilot
  - Pilot FAQ
  - Pilot not working
  - Claude plugin SSH error
  - pipx PATH
  - status line missing
  - Claude Desktop chat vs Code tab
---

# Troubleshooting & FAQ

Common setup and day-to-day snags when installing or running Pilot, with the
exact fix for each.

## Installation & Marketplace

### `claude` fails to add `confighub/pilot` with an SSH or permission error

Claude defaults to SSH when cloning a plugin marketplace. If you do not have a
GitHub SSH key configured on this machine, force HTTPS and retry:

```bash
export CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1
```

Then run `/plugin marketplace add confighub/pilot` and
`/plugin install confighub-pilot@confighub-pilot` again.

### `pilot: command not found` after installing with `pipx`

`pipx` places shims in `~/.local/bin`, which may not be on your `PATH` yet:

```bash
pipx ensurepath
```

Open a new terminal (or reload your shell profile) and confirm with
`pilot --version`.

### Python version error during install

Pilot requires **Python 3.11 or newer**. Check which Python `pipx` or your
shell picks up:

```bash
python3 --version
```

If macOS or your OS defaults to an older Python, pass an explicit Python 3.11+
binary to `pipx`:

```bash
pipx install --python /opt/homebrew/bin/python3.12 <wheel-url-or-path>
```

### `cub: command not found` or `cub plugin install` fails

You can still install and run Pilot without `cub` (for read-only GitOps
inspection of Argo CD or Flux repos, or using the Claude plugin / `pipx`
routes in [INSTALL_PILOT.md](INSTALL_PILOT.md)). When you are ready to connect
to ConfigHub, install `cub` and sign in with `cub auth login`.

## Claude Code & Claude Desktop

### Pilot is installed, but nothing happens in Claude

By design, Pilot stays quiet in every session until you switch it on. Inside
Claude Code, type:

```text
/confighub-pilot:on
```

If you just installed or upgraded the plugin, **quit and reopen Claude once**
so Claude loads the plugin hooks, then run `/confighub-pilot:on`. Check
session state at any time with `/confighub-pilot:status`.

### The status line does not show Pilot

Run `pilot claude install --global --session-scoped` (or `cub pilot install`),
then restart Claude once. Inside a session where you typed
`/confighub-pilot:on`, the status line reports that Pilot is active.

### Pilot does not work in Claude Desktop's Chat window or Cowork

That is expected and deliberate:

- **Claude Desktop Chat window** does not run plugin hooks. Because Pilot's
  approval guard is a hook, Pilot cannot protect you there — use the **Code**
  tab or Claude Code in a terminal instead.
- **Claude Desktop Cowork** is not supported yet.

### Can I use Pilot with Codex or other models?

Yes. See [PILOT_WITH_OTHER_MODELS.md](PILOT_WITH_OTHER_MODELS.md) for the
Codex adapter, local/alternative model guidance, and exact safety boundaries.

## Runtime, Approvals & Corpus

### Why did Pilot stop and ask before running a command?

Pilot follows **reads run, changes ask**:

- Scoped read-only checks run automatically.
- Any change (ConfigHub mutation, unbounded read, cluster lifecycle, direct
  `kubectl` write, or unreviewed verb) pauses and shows you the exact command
  and scope so you can allow or decline that one attempt.
- Four destructive or credential-bearing patterns stay hard-stopped (for
  example `cub space delete --recursive`, `cub organization delete`,
  `cub cluster down --delete-config`, and literal credentials typed into a
  command).

See [PILOT_SAFE_ACTIONS.md](PILOT_SAFE_ACTIONS.md) and
[HOW_PILOT_WORKS.md](HOW_PILOT_WORKS.md) for the exact boundaries.

### How do I check what Pilot knows or roll back a corpus update?

Pilot separates its signed lesson corpus from the core binary so lessons can
update between releases without a full upgrade:

```bash
pilot corpus status
pilot corpus update
pilot corpus use-bundled
```

See [CORPUS_UPDATES.md](CORPUS_UPDATES.md) for signature verification and
pinning details.

### How do I verify my install without touching any live cluster or ConfigHub?

Run these two strictly read-only commands in a terminal:

```bash
pilot --version
pilot quickstart --progress-card
```

Neither command reads a live cluster or calls ConfigHub.

## Upgrading & Uninstalling

### Clean upgrade

If you installed via `cub`:

```bash
cub plugin upgrade pilot
cub pilot upgrade
```

If you installed via `pipx`, reinstall the latest wheel from the release page
after verifying `SHA256SUMS` and restart Claude once.

### Clean uninstall

```bash
cub pilot uninstall
```

Inside Claude Code, you can also run `/plugin` to disable or remove the
`confighub-pilot` plugin directly. See [INSTALL_PILOT.md](INSTALL_PILOT.md)
for every per-route uninstall step.
