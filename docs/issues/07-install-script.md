## Parent

Parent PRD: `docs/prd/0001-autopilot-toolkit.md`

## What to build

Write `install.sh` at the project root. The script creates symbolic links from `~/.agents/skills/` to each skill directory in the project.

### Behavior

1. Ensure `~/.agents/skills/` exists (create if not)
2. For each skill directory under `skills/upstream/` and `skills/autopilot/`, create a symlink: `~/.agents/skills/<skill-name> -> <project-root>/skills/<source>/<skill-name>`
3. The script is idempotent — re-running it replaces broken symlinks but skips valid ones
4. Report summary: how many links created, skipped, or replaced

### Discovery

Skills are discovered by scanning for `SKILL.md` files:
- `skills/upstream/*/SKILL.md` → symlink each parent dir
- `skills/autopilot/*/SKILL.md` → symlink each parent dir

## Acceptance criteria

- [ ] `install.sh` exists at project root and is executable (`chmod +x`)
- [ ] Running `bash install.sh` creates symlinks in `~/.agents/skills/` for all 18 skills
- [ ] Each symlink points to the correct directory in the project
- [ ] Re-running `install.sh` is idempotent (no duplicate or broken links)
- [ ] Output includes summary: N created, M skipped, K replaced
- [ ] `~/.agents/skills/` is created if it does not exist
- [ ] Script handles edge cases gracefully: missing source dirs, existing broken symlinks, permission issues

## Blocked by

- #02-upstream-skills-migration (needs upstream skill dirs)
- #03-audit-autopilot-conversion (needs audit-autopilot dir)
- #04-autopilot-orchestrator-conversion (needs orchestrator dir)
- #05-autopilot-implementer-conversion (needs implementer dir)
- #06-autopilot-reviewer-conversion (needs reviewer dir)
