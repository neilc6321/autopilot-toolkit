## What to build

Convert `~/Documents/WorkSpace/opencode-toolbox/agents/reviewer.md` (an opencode subagent definition) into a reasonix subagent skill at `skills/autopilot/autopilot-reviewer/SKILL.md`.

### Conversion rules (structural only)

1. **Frontmatter**: Replace opencode agent frontmatter with reasonix skill frontmatter:
   - `name: autopilot-reviewer`
   - `description`: Autopilot task reviewer. Four-axis review: Behavior alignment, TDD discipline, code quality, plan fidelity. Read-only.
   - `runAs: subagent`
   - `allowed-tools: read_file, ls, glob, grep` (reasonix read-only tools — TODO: confirm exact names)
   - Remove: `mode`, `hidden`, `permission`/`edit`/`bash` fields

2. **Remove opencode tool references**: The mandatory `skill` tool loading preamble replaced with:
   > When invoked, you have access to the `tdd` skill. Reference its test quality standards and mock discipline for the TDD review dimension.

3. **Preserve reviewer logic**: Keep the full review workflow — four-axis review, grading standards, verdict system, UNVERIFIED mode, Suggestion extraction.

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
- [ ] The original file remains unchanged

## Blocked by

- #01-project-bootstrap (needs directory structure)
