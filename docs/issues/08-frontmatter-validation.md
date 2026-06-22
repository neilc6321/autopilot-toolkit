## Parent

Parent PRD: `docs/prd/0001-autopilot-toolkit.md`

## What to build

Validate all 18 SKILL.md files have reasonix-compatible frontmatter. Write a validation checklist (manual or script) that verifies:

### Checks

1. **Required fields present**: Every SKILL.md has `name` and `description` in its frontmatter
2. **Name format**: `name` matches `^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$` (reasonix name validation)
3. **No opencode fields**: No file contains `compatibility`, `mode`, `disable-model-invocation`, `permission`, `hidden`, `arguments` in its frontmatter
4. **runAs valid**: If present, `runAs` is either `inline` or `subagent`
5. **allowed-tools present for subagents**: Any skill with `runAs: subagent` has `allowed-tools` defined (even if the value is `TODO`)
6. **Frontmatter well-formed**: `---` delimiters are present and balanced

### Output

A validation report listing per-skill PASS/FAIL with specific issues found.

## Acceptance criteria

- [ ] Validation checklist exists (as a script or documented manual check list)
- [ ] All 14 upstream skills pass (no opencode fields in upstream source)
- [ ] All 4 autopilot skills pass (converted correctly)
- [ ] Any FAIL has a specific fix documented
- [ ] Report confirms 0 opencode-specific fields across all 18 skills
- [ ] Report confirms all subagent skills have `allowed-tools` (even if TODO)

## Blocked by

- #02-upstream-skills-migration (needs upstream skill files)
- #03-audit-autopilot-conversion
- #04-autopilot-orchestrator-conversion
- #05-autopilot-implementer-conversion
- #06-autopilot-reviewer-conversion
