## Parent

Parent PRD: `docs/prd/0001-autopilot-toolkit.md`

## What to build

Set up git subtree tracking for `mattpocock/skills` at `skills/upstream/`. The subtree imports the entire upstream repo, but only the 14 skills listed in `.skill-lock.json` are considered "active." The `.skill-lock.json` file from `~/.agents/.skill-lock.json` is copied into the project root to record installed versions and hashes.

Copy the existing `.skill-lock.json` from `openencode-toolbox`'s tracked state as the baseline.

### 14 upstream skills to track

**Engineering (10):** diagnose, grill-with-docs, improve-codebase-architecture, prototype, setup-matt-pocock-skills, tdd, to-issues, to-prd, triage, zoom-out

**Productivity (4):** caveman, grill-me, handoff, write-a-skill

## Acceptance criteria

- [ ] `git remote` shows subtree remote for `mattpocock/skills` (git@github.com:mattpocock/skills.git)
- [ ] `skills/upstream/` contains the full upstream tree (engineering/, productivity/, deprecated/, in-progress/, misc/, personal/)
- [ ] `.skill-lock.json` exists at project root, copied from `~/.agents/.skill-lock.json`
- [ ] `.skill-lock.json` lists all 14 skills with source metadata and hashes
- [ ] Can run `git subtree pull --prefix skills/upstream mattpocock-skills main` to sync upstream updates
- [ ] No skills are excluded or filtered from the subtree — the full tree is present

## Blocked by

- #01-project-bootstrap (needs directory structure)
