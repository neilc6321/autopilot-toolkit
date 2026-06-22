## Parent

Parent PRD: `docs/prd/0001-autopilot-toolkit.md`

## What to build

Convert `opencode-toolbox/agents/reviewer.md` (an opencode subagent definition) into a reasonix subagent skill at `skills/autopilot/autopilot-reviewer/SKILL.md`.

### Conversion rules (structural only)

1. **Frontmatter**: Replace opencode agent frontmatter with reasonix skill frontmatter:
   - `name: autopilot-reviewer`
   - `description`: Autopilot task reviewer. Four-axis review: Behavior alignment, TDD discipline, code quality, plan fidelity. Read-only.
   - `runAs: subagent`
   - `allowed-tools: read_file, ls, glob, grep` (reasonix read-only tools — TODO: confirm exact names)
   - Remove: `mode`, `hidden`, `permission`/`edit`/`bash` fields

2. **Remove opencode tool references**: The mandatory `skill` tool loading preamble is replaced with:
   > When invoked, you have access to the `tdd` skill. Reference its test quality standards and mock discipline for the TDD review dimension.

3. **Preserve reviewer logic**: Keep the full review workflow — four-axis review (Behavior, TDD, Code Quality, Plan Fidelity), grading standards (Critical/Important/Suggestion), verdict system (MERGE/RETRY/BLOCKED/VERIFY_NEEDED), UNVERIFIED mode, and Suggestion extraction with KEYWORDS/FILES annotations.

4. **Mark tool references**: The reviewer is read-only. Its tool usage is limited to file reading and searching. Note that reasonix read-only tools (`read_file`, `ls`, `glob`, `grep`) may differ from opencode equivalents.

5. **Contract passing**: Input variables (issue_dir, contract, CHANGED_FILES, SIBLING_CONTEXT, UNVERIFIED flag) are now passed via reasonix's `run_skill` arguments parameter.

## Acceptance criteria

- [ ] `skills/autopilot/autopilot-reviewer/SKILL.md` exists
- [ ] Frontmatter: `name`, `description`, `runAs: subagent`, `allowed-tools` with read-only tool list — no opencode fields
- [ ] `skill` tool loading preamble replaced with reasonix-compatible phrasing
- [ ] Four-axis review framework preserved in full
- [ ] Critical/Important/Suggestion grading standards preserved
- [ ] VERDICT system (MERGE/RETRY/BLOCKED/VERIFY_NEEDED) preserved
- [ ] UNVERIFIED mode logic preserved
- [ ] Suggestion extraction with KEYWORDS/FILES annotations preserved
- [ ] REVIEWER_REPORT format preserved
- [ ] The original `opencode-toolbox/agents/reviewer.md` remains unchanged

## Blocked by

- #01-project-bootstrap (needs directory structure)
