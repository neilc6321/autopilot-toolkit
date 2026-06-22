## Parent

Parent PRD: `docs/prd/0001-autopilot-toolkit.md`

## What to build

Convert `opencode-toolbox/commands/autopilot.md` (a slash command) into a reasonix inline skill at `skills/autopilot/autopilot-orchestrator/SKILL.md`.

### Conversion rules (structural only)

1. **Frontmatter**: Set `name: autopilot-orchestrator`, carry over the existing `description`. Remove opencode command frontmatter fields (`arguments`, slash-command syntax). Do NOT set `runAs` (defaults to `inline`).

2. **Remove command syntax**: Strip `arguments: [{ name: "target", ... }]` and all `$1`/`$2` shell-expansion references. The orchestrator now receives its target as part of the natural language invocation via reasonix's `run_skill` arguments parameter.

3. **Preserve workflow logic**: Keep the full orchestration workflow — Phase 1 dispatch loop, issue source identification, state management, retry logic, Phase 2 meta-review, FINAL_ACCEPTANCE_REPORT. This is the core value.

4. **Mark opencode dispatch with TODO**: All `task` tool dispatches (`task subagent_type: "implementer"`) are replaced with:
   ```
   TODO: reasonix dispatch — use run_skill(name: "autopilot-implementer", arguments: "<task>") 
   ```
   Same for reviewer dispatches.

5. **Mark status tracking with TODO**: All `edit`/`gh issue edit`/`gh issue comment` operations are preserved but wrapped with:
   ```
   TODO: reasonix file/issue API — adapt to reasonix tool equivalents
   ```

6. **Preserve skill references**: References to loading `tdd`, `diagnose`, `zoom-out` skills are kept (these exist in the upstream skills set).

## Acceptance criteria

- [ ] `skills/autopilot/autopilot-orchestrator/SKILL.md` exists
- [ ] Frontmatter has `name: autopilot-orchestrator` and `description`; no `arguments` field
- [ ] No `$1`/`$2` shell-expansion syntax remains
- [ ] Phase 1 dispatch loop logic is preserved in full
- [ ] Phase 2 meta-review logic is preserved in full
- [ ] All opencode-specific tool calls marked with `TODO: reasonix dispatch — ...` or `TODO: reasonix file/issue API — ...`
- [ ] References to `tdd`/`diagnose`/`zoom-out` skills are intact
- [ ] The original `opencode-toolbox/commands/autopilot.md` remains unchanged

## Blocked by

- #01-project-bootstrap (needs directory structure)
