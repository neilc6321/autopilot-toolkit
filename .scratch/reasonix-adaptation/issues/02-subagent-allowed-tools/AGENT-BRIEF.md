## What to build

Replace the TODO/placeholder `allowed-tools` in implementer and reviewer skill frontmatter with real reasonix tool names. Use the 宽松策略 agreed during planning.

**implementer** (全工具, excluding meta/background tools):
`read_file, write_file, edit_file, multi_edit, glob, grep, ls, bash, todo_write, web_fetch, code_index`

**reviewer** (read-only + bash for git diff):
`read_file, glob, grep, ls, code_index, bash`

The orchestrator is `runAs: inline` and does not need `allowed-tools`.

## Acceptance criteria

- [ ] `autopilot-implementer/SKILL.md` frontmatter has `allowed-tools: read_file, write_file, edit_file, multi_edit, glob, grep, ls, bash, todo_write, web_fetch, code_index`
- [ ] `autopilot-reviewer/SKILL.md` frontmatter has `allowed-tools: read_file, glob, grep, ls, code_index, bash`
- [ ] `autopilot-orchestrator/SKILL.md` does NOT gain an `allowed-tools` field (inline)
- [ ] `audit-autopilot/SKILL.md` does NOT gain an `allowed-tools` field (inline)
- [ ] `node validation/run.js` reports 19/19 PASS (all subagent skills have valid allowed-tools)
- [ ] No other field changes in any SKILL.md frontmatter

## Blocked by

- #01-github-repo-setup (need repo to exist for CI context, but can be implemented locally first)
