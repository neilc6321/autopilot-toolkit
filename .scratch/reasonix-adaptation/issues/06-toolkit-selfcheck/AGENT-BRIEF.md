## What to build

The `toolkit-selfcheck` skill already exists in the codebase. This issue is to verify and finalize it:

1. Verify the skill is picked up by `install.sh` (auto-discovered via `skills/autopilot/*/SKILL.md` glob)
2. Verify the expected skill count (19: 14 upstream + 5 autopilot) matches reality
3. Run `bash install.sh` and confirm the symlink appears in `~/.agents/skills/toolkit-selfcheck/`
4. Verify `validation/run.js` includes `toolkit-selfcheck` in its check list
5. Spot-check the SKILL.md for reasonix compatibility (no opencode-specific fields, valid frontmatter)

If any counts or names are wrong, fix them in the SKILL.md body.

## Acceptance criteria

- [ ] `bash install.sh` creates `~/.agents/skills/toolkit-selfcheck/` symlink
- [ ] The symlink points to `skills/autopilot/toolkit-selfcheck/` in the project
- [ ] `validation/run.js` passes toolkit-selfcheck (name + description present, no opencode fields)
- [ ] The skill body correctly lists 14 upstream + 5 autopilot = 19 expected skills
- [ ] The excluded items list is complete (skill-creator, backtest, quant, quant-scheduled, proxy-subscription-parser, rust-artisan, rust-artisan-v2, rust-coder, surge-cli, python-uv, argus, zoom-out)
- [ ] `node validation/run.js` reports 19/19 PASS

## Blocked by

None — skill file already exists, just needs verification
