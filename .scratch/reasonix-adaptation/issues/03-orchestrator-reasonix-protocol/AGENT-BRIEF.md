## What to build

Adapt `skills/autopilot/autopilot-orchestrator/SKILL.md` in three areas:

### 1. Dispatch protocol (3 location points)

Replace all opencode `task` tool dispatch instructions with reasonix `run_skill`:

```
run_skill(name: "autopilot-implementer", arguments: "<task description>")
run_skill(name: "autopilot-reviewer", arguments: "<task description>")
```

Update the dispatch prompt templates accordingly. Keep the prompt body structure (ROUND, PREV_REVIEW, TOOLCHAIN, REFACTORING flags) — change only the tool invocation syntax. The 3 dispatch points are: implementer dispatch (line ~178), reviewer dispatch (line ~231), and Phase 2 meta-review reviewer dispatch (line ~381).

### 2. File/issue API adaptation

Replace opencode tool names with reasonix equivalents:
- `edit` tool → `edit_file` (same semantics: old_string, new_string replacement)
- `write` tool → `write_file`
- `read` tool → `read_file`

Update all references in the Status update abstraction, comment abstraction, and suggestions.json persistence sections.

### 3. GitHub integration adaptation

Replace `gh issue view/edit/comment/list` calls with MCP-priority pattern:
- At skill startup, detect if `mcp__github__*` tools are available (check tool registry)
- If MCP available: use `mcp__github__list_issues`, `mcp__github__update_issue`, `mcp__github__add_comment` etc.
- If MCP not available: fall back to `bash gh issue ...` (requires gh CLI installed and authenticated)
- Document the prerequisite in a note at the top of the GitHub Issue mode section

## Acceptance criteria

- [ ] All 3 dispatch points use `run_skill(name, arguments)` syntax instead of `task` tool
- [ ] No references to opencode `task` tool remain
- [ ] All `edit` tool references changed to `edit_file`
- [ ] All `write` tool references changed to `write_file`
- [ ] All `read` tool references changed to `read_file`
- [ ] GitHub section starts with MCP availability check, falls back to `bash gh`
- [ ] `node validation/run.js` reports PASS for orchestrator
- [ ] Orchestrator skill body still contains complete Phase 1 and Phase 2 workflow logic
- [ ] No behavior changes beyond tool name/API adaptations

## Blocked by

- #02-subagent-allowed-tools (implementer/reviewer must have valid allowed-tools before orchestrator can dispatch them)
