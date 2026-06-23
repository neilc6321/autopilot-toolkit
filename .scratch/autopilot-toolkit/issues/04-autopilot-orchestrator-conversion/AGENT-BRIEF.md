## What to build

Convert `~/Documents/WorkSpace/opencode-toolbox/commands/autopilot.md` (a slash command) into a reasonix inline skill at `skills/autopilot/autopilot-orchestrator/SKILL.md`.

### Conversion rules (structural only)

1. **Frontmatter**: Set `name: autopilot-orchestrator`, carry over the existing `description`. Remove opencode command frontmatter fields (`arguments`, slash-command syntax). Do NOT set `runAs` (defaults to `inline`).

2. **Remove command syntax**: Strip `arguments: [{ name: "target", ... }]` and all `$1`/`$2` shell-expansion references.

3. **Preserve workflow logic**: Keep the full orchestration workflow.

4. **Mark opencode dispatch with TODO**: All `task` tool dispatches replaced with:
   `TODO: reasonix dispatch — use run_skill(name: "autopilot-implementer", arguments: "<task>")`

5. **Mark status tracking with TODO**: All `edit`/`gh issue edit`/`gh issue comment` operations preserved but wrapped with:
   `TODO: reasonix file/issue API — adapt to reasonix tool equivalents`

6. **Preserve skill references**: References to loading `tdd`, `diagnose`, `zoom-out` skills are kept.

## Acceptance criteria

- [ ] `skills/autopilot/autopilot-orchestrator/SKILL.md` exists
- [ ] Frontmatter has `name: autopilot-orchestrator` and `description`; no `arguments` field
- [ ] No `$1`/`$2` shell-expansion syntax remains
- [ ] Phase 1 dispatch loop logic is preserved in full
- [ ] Phase 2 meta-review logic is preserved in full
- [ ] All opencode-specific tool calls marked with `TODO: reasonix dispatch — ...` or `TODO: reasonix file/issue API — ...`
- [ ] References to `tdd`/`diagnose`/`zoom-out` skills are intact
- [ ] The original file remains unchanged

## Blocked by

- #01-project-bootstrap (needs directory structure)
