<!--
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
  - tests/test-pilot-guidance-moments
  - tools/audits/audit-md-corpus-shelves
  - tools/audits/audit-pilot-package-manifest
retrieval_triggers:
  - How Pilot talks
  - Pilot voice
  - Pilot persona
  - why does Pilot say that
---
-->

# How Pilot Talks To You

Pilot writes the same way at the same moment, every time. The words are not
made up fresh by the model each run. They are held in one file,
`pilot/inventories/pilot-guidance-moments.json`, and every command reads its
opening and closing lines from there. That is why `pilot map` and
`pilot assess` cannot tell you two different things about the same folder.

This page explains the rules, so you can tell when Pilot is doing its job and
when it is not.

## Five rules Pilot follows

**Plain words.** Pilot writes for somebody who is new to this. If a piece of
jargon has to appear, Pilot explains it in one plain line the first time, or it
does not use the word at all. If Pilot ever hands you a sentence about delivery
boundaries when you asked what your repo deploys, that is a bug, and it is
worth reporting.

**One next step.** Under "Next" there is one thing to do. Below it there is one
short line telling you how to ask for the other options: say "show me more", or
add `--render-cockpit`. The options are still there, in the full cockpit and in
the JSON receipt, but a plain card never lists them. A menu where a step belongs
makes you choose before you have understood anything, so Pilot does not print
one.

**Checked and proven are different.** Pilot says what it looked at, and then,
separately, what is still not proven. An exit code is not proof. A permission
prompt is not proof. Being allowed to try something is not the same as it
having worked, and Pilot will not blur the two.

**Never more than it read.** Pilot only describes what it actually opened. If
it did not read your cluster, it says so rather than guessing. If the files are
in the folder it just read, it will not send you off to look somewhere else.

**Pilot does not approve its own work.** It can explain, propose and compare.
It cannot approve its own proposal, and it cannot certify its own result. That
is your decision and somebody else's evidence.

## The moments

Pilot recognises seven moments on a first visit. At each one it knows what it
must say, what it must not say, and what it may offer.

| Moment | What Pilot always says | What Pilot never says |
|---|---|---|
| You arrive with nothing named | The four kinds of thing it can look at, and one step that needs no account | Any tool, app or environment name, because it has read nothing |
| You arrive inside a project | The shape of the folder and the delivery tool it found, what ConfigHub would add here, and that no account is needed to see that | A tool it did not detect, or a second step under Next |
| After it reads the folder | What the project deploys, before any file count, and that nothing live was contacted | A finding about a repository it did not read |
| After it teaches you something | Whether an example is a fixture, a past receipt, or current live proof | That a fixture result is live proof |
| Before an upload | Where the plan came from, and every piece of configuration the upload would empty, by name | A count of emptied pieces without their names |
| After an approval | What it observed, and which layers it did not check | That an exit code proves the change landed |
| On a stop | That it did not run the command, which layer stopped it, and the smallest way forward | A stop dressed up as your mistake |

## What changes for you, and what does not

Pilot varies **what it offers** by the tool it found in your project: an Argo
CD repo gets Argo examples, a Flux repo gets Flux examples, and a folder with
no recognisable tool gets neither. It also tries to match the level of the
reading it points you at, and it always tells you the level rather than hiding
it. If the only matching example is a beginner one, Pilot says it is a beginner
one instead of pretending otherwise.

Pilot does **not** vary what it claims. What was checked, what is proven, what
is not proven, and what was refused read the same for everybody. Nothing about
who is reading changes whether something is true.

## Known gaps

- There is no expert-shaped Argo or Flux example yet. An expert is offered the
  beginner example, labelled as the beginner example. A beginner folder is
  offered a short first-look guide shipped with Pilot first.
- Pilot does not ask how experienced you are. It varies its offer by what it
  read in your project, not by anything it assumes about you.

## See also

- [`WHAT_IS_PILOT.md`](WHAT_IS_PILOT.md) for the three rules and the eight
  journeys.
- [`HOW_PILOT_WORKS.md`](HOW_PILOT_WORKS.md) for the architecture underneath.
- [`WHAT_YOU_WILL_SEE.md`](WHAT_YOU_WILL_SEE.md) for the Progress Card and the
  other surfaces these words appear on.
