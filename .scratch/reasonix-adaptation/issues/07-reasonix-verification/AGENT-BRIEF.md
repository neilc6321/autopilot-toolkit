## What to build

Manual verification on reasonix. This is a HITL (human-in-the-loop) issue — cannot be automated.

### Verification checklist

1. **Skill discovery**: Run `bash install.sh` in the reasonix workspace, confirm all 19 skills appear in reasonix skill index
2. **Inline skill**: Execute `/grill-with-docs` with a test prompt, confirm the skill body loads and the grilling workflow executes
3. **Selfcheck**: Execute `/toolkit-selfcheck`, confirm all 5 checks pass (directory, count, symlinks, frontmatter, excluded items)
4. **Orchestrator dispatch**: Execute `/autopilot-orchestrator` on a test `.scratch/` issue, confirm it dispatches implementer → reviewer → reports result
5. **audit-autopilot**: After an orchestrator run completes, execute `/audit-autopilot <session-id>`, confirm it reads sessions and produces an audit report

## Acceptance criteria

- [ ] 19/19 skills discovered by reasonix
- [ ] `/toolkit-selfcheck` returns ALL PASS
- [ ] `/grill-with-docs` executes correctly with a test prompt
- [ ] `/autopilot-orchestrator` successfully dispatches implementer and reviewer on a test issue
- [ ] `/audit-autopilot` successfully reads session data and produces an audit scorecard
- [ ] Any failures documented with specific error messages for follow-up

## Blocked by

- #01-github-repo-setup
- #02-subagent-allowed-tools
- #03-orchestrator-reasonix-protocol
- #04-audit-autopilot-session-tools
- #05-skill-methodology-inline
- #06-toolkit-selfcheck
