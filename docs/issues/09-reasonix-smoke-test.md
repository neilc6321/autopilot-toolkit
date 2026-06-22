## Parent

Parent PRD: `docs/prd/0001-autopilot-toolkit.md`

## What to build

End-to-end smoke test: install the toolkit, launch reasonix, verify skills are discoverable.

### Test steps

1. Run `bash install.sh` to deploy symlinks to `~/.agents/skills/`
2. Launch reasonix in a test project
3. Verify skills appear in the skill index (`/skills list` or equivalent)
4. Invoke one upstream skill (e.g., `/diagnose` or `/caveman`) and verify it loads
5. Invoke one autopilot inline skill (e.g., `/audit-autopilot`) and verify description matches
6. Verify autopilot subagent skills (`autopilot-implementer`, `autopilot-reviewer`) appear with the `[subagent]` tag in the skill index
7. Document any discovery or invocation failures with exact error messages

### Expected result

All 18 skills are listed in the reasonix skill index. Inline skills are invocable. Subagent skills show the `[subagent]` tag and have `allowed-tools` defined.

## Acceptance criteria

- [ ] `bash install.sh` completes without errors
- [ ] All 18 skills appear in reasonix skill list
- [ ] At least 1 upstream inline skill successfully loads on invocation
- [ ] `audit-autopilot` skill successfully loads on invocation
- [ ] `autopilot-implementer` and `autopilot-reviewer` show `[subagent]` tag
- [ ] Any failures are documented with exact error messages and diagnosis

## Blocked by

- #07-install-script (needs symlinks deployed)
