## What to build

Convert the existing `audit-autopilot` skill from opencode format to reasonix-compatible format. Copy the skill directory from `~/Documents/WorkSpace/opencode-toolbox/skills/audit-autopilot/` to `skills/autopilot/audit-autopilot/`, then:

1. Strip opencode-specific frontmatter field (`compatibility: opencode`)
2. Keep `name: audit-autopilot` and `description`
3. Mark opencode CLI references (`opencode export`, `opencode session list`) with `TODO: reasonix session export — TBD` placeholders
4. Preserve all reference files (`references/questions.md`, `references/report-template.md`)
5. Preserve all eval data (`evals/`) — these are test fixtures, still useful for methodology reference

## Acceptance criteria

- [ ] `skills/autopilot/audit-autopilot/SKILL.md` exists
- [ ] Frontmatter has `name` and `description`; NO `compatibility` field
- [ ] All opencode CLI commands replaced with `TODO: reasonix session export — TBD`
- [ ] `references/questions.md` copied and unchanged
- [ ] `references/report-template.md` copied and unchanged
- [ ] `evals/` directory copied with all test fixtures
- [ ] The original `~/Documents/WorkSpace/opencode-toolbox/skills/audit-autopilot/` remains unchanged

## Blocked by

- #01-project-bootstrap (needs directory structure)
