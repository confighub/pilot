---
shelf: product-doctrine
status: current
audience: users
owner: pilot
portable: true
package: pilot-corpus
used_by:
  - docs/user/README.md
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tools/audits/audit-pilot-package-manifest
  - tests/test-pilot-doc-reference-integrity
  - tools/audits/audit-md-corpus-shelves
  - tests/test-pilot-corpus-pack
retrieval_triggers:
  - update the corpus
  - pilot corpus update
  - pilot corpus status
  - corpus pack
  - new reviewed entries without a new Pilot
---

# Update what Pilot knows, without a new Pilot

Pilot answers from a set of reviewed lessons called the corpus. A new Pilot
release carries the corpus as it stood on release day. A **corpus pack** is a
small, dated set of reviewed lessons that can reach you between releases, so you
do not have to wait for a new Pilot.

A pack is a reviewed addition. It only adds lessons, or replaces a bundled
lesson that has the same name. It never removes the corpus that came with your
Pilot, and it cannot run anything.

## See which corpus Pilot is using

```
pilot corpus status
```

Run `pilot corpus status`. It says plainly which corpus is in use:

- the bundled corpus that came with your Pilot, or
- a pack: its version, its digest, where it came from, when Pilot checked it,
  whether its signature was checked, and how many lessons it adds or replaces.

## Look for a newer pack

```
pilot corpus update
```

This only looks. It finds the newest pack, shows the digest it would move to and
how many lessons it adds or replaces, and prints the one command that applies
exactly that pack. Nothing is downloaded or changed until you run that command,
which ends in `--yes`:

```
pilot corpus update --digest sha256:<digest it showed you> --yes
```

A digest is a fingerprint of the exact pack. Pilot always fetches by digest, so
the pack you confirm is the pack you get, even if the tag has moved since.

## What Pilot checks before it uses a pack

Pilot refuses a pack, and keeps the corpus you already had, if any of these fail:

- the pack's files do not match the fingerprints in its own list;
- the pack needs a newer Pilot than yours (it says which version);
- an entry fails the same shape checks bundled entries pass;
- a signature was required and did not verify.

A refusal is a normal answer: Pilot tells you why and changes nothing.

Signatures: if `cosign` is installed, pass `--require-signature` with
`pilot corpus update` against `ghcr.io/confighub/pilot-corpus` to verify
ConfigHub's default keyless Sigstore OIDC signing identity (the same
GitHub Actions OIDC pattern used by `confighub/sdk` and `cub`). For mirrors or
custom signers, pass `--cosign-key`, or `--cosign-identity-regexp` with
`--cosign-issuer`. If no signature was checked, `pilot corpus status` says
"not checked" and why. Pilot never says a pack is signed when it did not check.

## Check the local corpus index

Run `pilot corpus index` to check the saved JSON index against the bundled
lessons. Pilot builds it if missing and repairs it if its contents differ.
Use `pilot corpus index --rebuild` to write a fresh copy. The output includes
the active entry count and any warning about falling back from a pack.
Report and trace folders are your local history and stay outside this process.

## Inspect memory providers and receipted recall

Run `pilot corpus providers` to list the advisory memory providers registered
in this Pilot install (such as `bundled-corpus` and the verification-decay
`decay-scored` model) along with each provider's exact `store_revision`.

To inspect what a provider recalls for a question — without changing any files
or live systems — run:

```
pilot corpus recall --query "argo sync failure" --provider decay-scored --explain --json
pilot corpus recall --query "argo sync failure" --provider confighub-space --space pilot-brain --json
pilot corpus recall --query "payments-prod argocd" --provider estate-graph --explain --json
```

When `--provider confighub-space` is selected, Pilot reads lessons strictly
read-only from the named ConfigHub Space (with optional `--cub-context`) and
automatically falls back to the bundled corpus with a `WATCH` warning when
`cub` is offline or unauthenticated. Every recall output carries the exact
`store_revision`, `content_digest`, per-lesson verification freshness
(`asserted`, `needs-re-verification`, or `stale`), and an optional replayable
`explanation`.

## Local evidence-classed estate graph

Pilot can also maintain a rebuildable, local evidence-classed estate graph
under `~/.pilot/estate-graph/estate-graph.json` from verified `pilot map`,
`pilot delivery-trace`, and snapshot-analysis receipts:

```
pilot corpus estate --estate-op ingest --delivery-trace-file <receipt.json> --json
pilot corpus estate --estate-op freshness --json
pilot corpus estate --estate-op blast-radius --node space:<slug> --json
pilot corpus estate --estate-op incidents --controller argocd --json
```

By default, `blast-radius` traverses only verified `receipt`, `revision`, and
`live-probe` edges (pass `--exploratory` to include `doc` or `inference` edges).
Deleting `~/.pilot/estate-graph/` loses only the local derived index, never
source of truth.

## Offline, mirrors and fallback

- **Offline works.** Lookups use whatever corpus is active. Only `pilot corpus
  update` needs a network.
- **Air-gapped or mirrored.** Copy the pack artifact into your own registry and
  point Pilot at it with `--ref <your-registry>/<repo>:<tag>`. Or copy it to a
  local OCI layout folder and use `--oci-layout <folder>`.
- **Anything wrong with the active pack** (a missing or edited file, an
  unreadable record): Pilot uses the bundled corpus, says so in one line in
  `pilot corpus status`, and carries on. It never stops working because of a
  pack.
- **Go back any time:** `pilot corpus use-bundled`.

## Where packs are kept

Packs unpack under `~/.pilot/corpus-packs/` (or `$PILOT_USER_HOME/corpus-packs/`).
Pilot's installed files are not touched.

## How a pack is made (for maintainers)

Packs are reviewed exactly like bundled entries. The same corpus checks, the
private-link check and the name audit run on every pack before it is built, and a
pack that fails any of them is not written.

```
tools/maintainer/pilot-corpus-pack-build --out <folder> --pack-version 2026.10.24
tools/maintainer/pilot-corpus-pack-publish --pack <folder> --ref ghcr.io/confighub/pilot-corpus:2026.10.24 --dry-run
```

The build is reproducible: the same entries always give the same pack. The
publish step prints the digest. Pass `--sign` on a real registry push to sign
the pushed digest with `cosign` (keyless OIDC by default, or `--cosign-key`),
or dispatch `.github/workflows/corpus-pack-publish.yml` to build, push, sign,
and verify with GitHub Actions OIDC.
