---
description: Switch Pilot off for this Claude session.
disable-model-invocation: true
shelf: command-prompt
status: current
owner: pilot
portable: true
package: pilot-adapter
used_by:
  - plugins/confighub-ai/hooks/session_switch.sh
enforced_by:
  - tests/test-pilot-session-switch
retrieval_triggers:
  - switch pilot off for this session
---

# /confighub-pilot:off

A hook, not you, carries out this command when a person types it. Look in your context for a line that starts with "Pilot session switch result:" from this turn.

- If it is there, repeat the text after the colon to the person in one sentence and stop.
- If it is not there, say in one sentence that only the person using this session can switch Pilot off, by typing /confighub-pilot:off themselves. Do not try to switch Pilot off any other way.
