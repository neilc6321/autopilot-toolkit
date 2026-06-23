## What to build

Replace 4 `TODO: reasonix session export — TBD` / `TODO: reasonix session list — TBD` placeholders in `skills/autopilot/audit-autopilot/SKILL.md` with actual reasonix tool instructions.

Mapping:
- Line 12 (finding session ID): Replace `TODO: reasonix session export — TBD` with instruction to use `list_sessions` tool to browse recent sessions, filter by autopilot-related titles
- Line 26 (listing sessions for user): Replace `TODO: reasonix session list — TBD` with instruction to use `list_sessions` tool
- Line 36 (export orchestrator session): Replace `TODO: reasonix session export — TBD` with instruction to use `read_session(session_id)` tool to read the full JSONL conversation
- Line 48 (export subagent sessions): Replace `TODO: reasonix session export — TBD` with instruction to use `read_session(subagent_session_id)` tool

The session ID discovery flow: use `list_sessions` to find orchestrator sessions → parse the returned metadata to locate subagent session IDs → use `read_session` to read each one.

## Acceptance criteria

- [ ] All 4 `TODO: reasonix session ... — TBD` placeholders replaced with `list_sessions` / `read_session` instructions
- [ ] Step 0 (Gather inputs): `list_sessions` instruction clearly explains how to filter for autopilot sessions
- [ ] Step 1 (Export and parse sessions): `read_session` instruction replaces the bash export block
- [ ] Subagent session discovery path documented: orchestrator session → subagent session IDs via tool call metadata
- [ ] No remaining `TODO` placeholders in audit-autopilot/SKILL.md
- [ ] `node validation/run.js` reports PASS for audit-autopilot
- [ ] Audit methodology (3 layers, 9 questions, spot-check strategy) preserved intact

## Blocked by

None — independent of other issues (disjoint file)
