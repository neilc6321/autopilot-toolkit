## What to build

Create the `autopilot-toolkit` GitHub repository under the `matthewye` personal account and push the current local codebase. The repo should be public, with the existing git history preserved. After pushing, verify that `validation/run.js` passes all 19 skills.

## Acceptance criteria

- [ ] GitHub repo `matthewye/autopilot-toolkit` exists and is public
- [ ] All local commits are pushed to `origin/main`
- [ ] `README.md` is visible on the repo landing page
- [ ] `.gitignore` prevents `.DS_Store`, `node_modules/`, `.reasonix/` from being tracked
- [ ] `bash install.sh` creates 19 symlinks in `~/.agents/skills/` (idempotent)
- [ ] `node validation/run.js` reports 19/19 PASS
- [ ] `git remote -v` shows `origin git@github.com:matthewye/autopilot-toolkit.git`
- [ ] `.skill-lock.json` and `.scratch/` directory are included in the repo (not gitignored)

## Blocked by

None — can start immediately
