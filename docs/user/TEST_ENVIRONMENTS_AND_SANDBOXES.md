<!--
---
shelf: product-doctrine
status: current-with-review
audience: users
owner: pilot
portable: true
package: pilot-corpus
used_by:
  - docs/user/WHAT_CAN_I_DO_TODAY.md
  - scripts/pilot-operate-sandbox
enforced_by:
  - tools/audits/audit-repo-layout-boundary
  - tests/test-repo-layout-boundary
  - tools/audits/audit-md-corpus-shelves
  - tools/audits/audit-pilot-doc-reference-integrity
  - tests/test-pilot-operate-sandbox
retrieval_triggers:
  - test environment
  - sandbox
  - somewhere safe to try a change
  - staging copy
---
-->

# Test Environments And Sandboxes

Nobody should try a change in production first. Before you promote anything,
you want somewhere to try it. Pilot plans two kinds of somewhere.

A **test environment** is a copy of an app that a team keeps. It is long
lived, it has a delete gate so nobody removes it by accident, and it is where
a change is tried before it goes to production.

A **sandbox** is a copy for one person or one agent. It is short lived, it has
an owner, and it has a date it should be gone by. You throw it away when you
are done.

Both are read-only plans. Pilot prints the commands; you run them.

## Ask for one in plain words

```text
pilot ask "set up a test environment for this app"
pilot ask "give me a sandbox"
pilot ask "I want to try this change somewhere safe"
pilot ask "make a staging copy"
pilot ask "clean up my sandbox"
```

Each of those lands on the same two doors.

## Make a place to try a change

Pilot needs to know what it can see before it plans anything. That is the
observation file: a small JSON file listing the Spaces and Targets you already
have access to, carrying the schema
`confighub-pilot.operate-sandbox-observation.v0`. There is a worked example in
`tests/fixtures/operate-sandbox/observation.json` in the Pilot source checkout.

Then ask for a sandbox:

```text
pilot operate sandbox \
  --observation <observation.json> \
  --from payments-base \
  --name ana \
  --owner ana
```

or a test environment:

```text
pilot operate test-env \
  --observation <observation.json> \
  --from payments-base \
  --name qa \
  --owner payments-team
```

## What the card shows you

The card shows the whole thing before anything happens:

- **The new Space and its name.** Names follow one convention so a Space list
  stays readable: the app, then `test` or `sbx`, then your short name. Copying
  `payments-base` for Ana gives `payments-sbx-ana`.
- **The labels it would set.** Component and Variant so ConfigHub groups the
  copy with the rest of the app; Environment so you can tell copies apart; an
  owner; the Space it came from; and, for a sandbox, the date it should be
  gone by, written as an absolute date such as `2026-09-24`.
- **The delete gates.** A test environment gets one, so a person has to clear
  it before the Space can go. A sandbox gets none, so cleaning up is one step.
- **The Target, if you asked for one.** Either an existing Target you name as
  `<target-space>/<target-slug>`, or an existing Target in a local kind cluster
  you created yourself.
- **The teardown plan, on the same card.** You see the way out at the same
  moment you see the way in.

Every cub command on the card has been checked against a reviewed capture of
the cub command line before it was printed. A command Pilot cannot check is
never printed and never guessed.

## Cleaning up

```text
pilot operate sandbox --clean-up --space payments-sbx-ana --observation <observation.json>
```

This door only removes what it made. It checks that the Space carries the
purpose label Pilot writes, and refuses anything else, including production.
If you really do mean to remove some other Space, use `pilot teardown-plan
--space <space>` and the normal review instead.

If the sandbox is past its date, the card says so. Pilot does not remove it.
Nothing expires itself; a person still approves the removal.

The same rule holds one level down. `pilot teardown-plan --purpose sandbox`
and `pilot teardown-plan --purpose test-env` refuse any Space without the
label, and withhold every command they would otherwise have proposed.

## What this does not do

- It does not create, bind, or delete anything. It plans.
- It does not approve anything. Approval stays where it already is.
- It does not check your server. The commands are checked against a reviewed
  capture of cub, not against the server you will run them on.
- It does not promise the copy will work. Running the commands is the first
  real step, and the read-back commands on the card are how you check.
