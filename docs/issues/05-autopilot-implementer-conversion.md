## Parent

Parent PRD: `docs/prd/0001-autopilot-toolkit.md`

## What to build

Convert `opencode-toolbox/agents/implementer.md` (an opencode subagent definition) into a reasonix subagent skill at `skills/autopilot/autopilot-implementer/SKILL.md`.

### Conversion rules (structural only)

1. **Frontmatter**: Replace opencode agent frontmatter with reasonix skill frontmatter:
   - `name: autopilot-implementer`
   - `description`: Autopilot task implementer. Reads AGENT-BRIEF, follows TDD discipline, auto-diagnoses errors.
   - `runAs: subagent`
   - `allowed-tools: TODO — define from reasonix tool registry`
   - Remove: `mode`, `hidden`, `permission`/`edit`/`bash` fields

2. **Remove opencode tool references**: The mandatory `skill` tool loading preamble ("在开始任何操作之前，必须使用 `skill` 工具加载...") is replaced with:
   > When invoked, you have access to the `tdd`, `diagnose`, and `zoom-out` skills. Reference their methodologies as needed.
   
   This reflects that reasonix loads skill bodies on-demand via `run_skill` rather than via a dedicated `skill` tool.

3. **Preserve implementer logic**: Keep the full workflow — task understanding, TDD loop, self-review, reporting, retry mode, toolchain detection, REFACTORING mode. All status values (`DONE`, `UNVERIFIED`, `BLOCKED`, `NEEDS_CONTEXT`) and report format (`IMPLEMENTER_REPORT:`) remain unchanged.

4. **Mark tool references with TODO**: References to specific tools (bash, edit, gh, grep, glob) are kept but noted that tool names need mapping to reasonix equivalents. Don't change tool names yet — just mark the section with `NOTE: Tool names below reference opencode registry. Map to reasonix equivalents before production use.`

5. **Contract passing**: The `ROUND`/`PREV_REVIEW`/`TOOLCHAIN`/`REFACTORING`/`CROSS_ISSUE_SUGGESTIONS` variables are now passed via reasonix's `run_skill` arguments parameter. Update the "识别当前模式" section to note this.

## Acceptance criteria

- [ ] `skills/autopilot/autopilot-implementer/SKILL.md` exists
- [ ] Frontmatter: `name`, `description`, `runAs: subagent`, `allowed-tools: TODO` — no opencode fields
- [ ] `skill` tool loading preamble replaced with reasonix-compatible phrasing
- [ ] Full TDD workflow (RED → GREEN → REFACTOR) preserved
- [ ] Self-review section preserved
- [ ] IMPLEMENTER_REPORT format preserved
- [ ] Retry mode logic preserved
- [ ] Variable passing mechanism updated from opencode injection to run_skill arguments
- [ ] The original `opencode-toolbox/agents/implementer.md` remains unchanged

## Blocked by

- #01-project-bootstrap (needs directory structure)
