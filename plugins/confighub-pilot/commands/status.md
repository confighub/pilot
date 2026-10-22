---
description: Show whether Pilot is on for this Claude session.
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
  - is pilot on in this session
---

# /confighub-pilot:status

A hook, not you, carries out this command when a person types it. Look in your context for a line that starts with "Pilot session switch result:" from this turn.

- If it is there, repeat the text after the colon to the person in one sentence and stop.
- If it is not there, say in one sentence that only the person using this session can check whether Pilot is on, by typing /confighub-pilot:status themselves. Do not try to check whether Pilot is on any other way.
