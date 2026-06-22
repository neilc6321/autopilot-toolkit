## Parent

Parent PRD: `docs/prd/0001-autopilot-toolkit.md`

## What to build

Scaffold the `autopilot-toolkit` project with the agreed directory structure, README, and `.gitignore`. The project root is `~/Documents/WorkSpace/autopilot-toolkit`. No skills are migrated yet — just empty directory scaffolding and project metadata files.

## Acceptance criteria

- [ ] Project root directory exists at `~/Documents/WorkSpace/autopilot-toolkit`
- [ ] `skills/upstream/` directory exists (empty, ready for git subtree)
- [ ] `skills/autopilot/` directory exists (empty, ready for skill dirs)
- [ ] `docs/prd/` and `docs/issues/` directories exist
- [ ] `README.md` exists with project overview:
  - Name: autopilot-toolkit
  - Purpose: upstream skills + autopilot workflow skills, deployed to `~/.agents/skills/`
  - Target: reasonix/codex compatible
  - Install: `bash install.sh`
- [ ] `.gitignore` exists with reasonable entries (`.DS_Store`, `node_modules/`, `.reasonix/`, etc.)
- [ ] Git repository is initialized (`git init`) in the project root

## Blocked by

None - can start immediately
