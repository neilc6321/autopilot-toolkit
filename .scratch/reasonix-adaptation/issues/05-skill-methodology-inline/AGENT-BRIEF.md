## What to build

reasonix subagents cannot invoke `run_skill` (it's excluded from subagent tool registry). Therefore, implementer and reviewer must embed the methodology they rely on directly in their skill bodies.

### implementer SKILL.md changes

Read `skills/upstream/skills/engineering/tdd/SKILL.md` and `skills/upstream/skills/engineering/diagnosing-bugs/SKILL.md`. Extract their core methodology (red-green-refactor cycle, test quality standards, mock discipline, diagnosis loop steps) and inline a concise summary into the implementer skill body. Place it in the "启动时" section, replacing:

```
When invoked, you have access to the `tdd`, `diagnose`, and `zoom-out` skills. Reference their methodologies as needed.
```

Remove the reference to `zoom-out` (dismissed from upstream).

### reviewer SKILL.md changes

Read `skills/upstream/skills/engineering/tdd/SKILL.md`. Extract test quality standards and mock discipline relevant to code review. Inline a concise summary into the reviewer skill body, replacing:

```
When invoked, you have access to the `tdd` skill. Reference its test quality standards and mock discipline for the TDD review dimension.
```

### orchestrator SKILL.md changes

Remove the `skill()` loading preamble from all 3 dispatch prompt templates (implementer dispatch, reviewer dispatch, Phase 2 reviewer dispatch). Remove the loading instructions (the `**在开始任何操作之前...**` blocks) but keep the task description sections intact.

## Acceptance criteria

- [ ] implementer body contains inline summary of tdd methodology (test-first, red-green-refactor, mock boundaries)
- [ ] implementer body contains inline summary of diagnose methodology (reproduce → minimise → hypothesise → instrument → fix)
- [ ] implementer body no longer references `zoom-out` skill
- [ ] implementer body no longer instructs to use `skill()` tool to load other skills
- [ ] reviewer body contains inline summary of tdd test quality standards
- [ ] reviewer body no longer instructs to use `skill()` tool
- [ ] orchestrator dispatch prompts no longer contain `skill(name: ...)` loading instructions
- [ ] orchestrator dispatch prompts still pass all contract fields (ROUND, PREV_REVIEW, TOOLCHAIN, REFACTORING, etc.)
- [ ] `node validation/run.js` reports 19/19 PASS
- [ ] No opencode-specific references introduced

## Blocked by

- #02-subagent-allowed-tools (need correct tool names established)
