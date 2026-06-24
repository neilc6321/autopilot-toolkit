---
name: toolkit-setup
description: Orchestrates end-to-end autopilot-toolkit installation and update. Discovers expected skill set, diagnoses current state, executes minimal sync/unlink/link-principles operations, and verifies. Use when setting up the toolkit for the first time, after pulling updates, or when skill symlinks may be broken.
runAs: inline
---

# Toolkit Setup

Orchestrate the end-to-end install-or-update workflow for autopilot-toolkit. Runs inside the project repo; requires `PROJECT_ROOT` set to the repo root.

## Scope

This setup manages **only** autopilot-toolkit's own skills — derived from `.skill-lock.json` (upstream) and `skills/autopilot/*/SKILL.md` (autopilot). It does not inspect or modify other projects' skills that may coexist in `~/.agents/skills/`.

## Step 1: Discover Expected Set

Derive the authoritative expected set from two sources — no hardcoded list.

### Upstream skills (from `.skill-lock.json`)

Read `$PROJECT_ROOT/.skill-lock.json`, parse the `skills` object keys. Each key is an upstream skill name. Extract the `skillPath` for each — it gives the relative path (e.g. `skills/engineering/tdd/SKILL.md`). Construct the expected source dir as:

```
$PROJECT_ROOT/skills/upstream/<skillPath directory>
```

(install.sh uses the same pattern: `$PROJECT_ROOT/skills/upstream/$skill_path` then `dirname`.)

Use python3 for JSON parsing if available:

```bash
python3 -c "
import json, os
with open('$PROJECT_ROOT/.skill-lock.json') as f:
    data = json.load(f)
for name, info in data.get('skills', {}).items():
    skill_path = info['skillPath']
    src_dir = os.path.join('$PROJECT_ROOT', 'skills/upstream', os.path.dirname(skill_path))
    print(f'{name}|{src_dir}')
"
```

If python3 is not available, fall back to grep-based extraction (less reliable but functional).

### Autopilot skills (from filesystem)

Scan `$PROJECT_ROOT/skills/autopilot/*/SKILL.md`. Each parent directory name is an autopilot skill name, and the directory itself is its source dir:

```bash
for skill_dir in "$PROJECT_ROOT"/skills/autopilot/*/; do
  if [ -f "$skill_dir/SKILL.md" ]; then
    name="$(basename "$skill_dir")"
    abs_dir="$(cd "$skill_dir" && pwd)"
    echo "$name|$abs_dir"
  fi
done
```

### Combined

Union these into a single expected set: `{name → expected_source_dir}`. The expected count is derived dynamically — do not hardcode a number.

## Step 2: Diagnose

### 2a. Check skills directory

```bash
ls -d ~/.agents/skills/ 2>/dev/null
```

If `~/.agents/skills/` does not exist, it will be created by `install.sh sync` on first use. Proceed — do not stop.

### 2b. Diagnose each expected skill

For each name in the expected set, check `~/.agents/skills/<name>` and classify:

```bash
check_skill_state() {
  local name="$1" expected_src="$2" skills_dir="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
  local target="$skills_dir/$name"

  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    echo "missing"
    return
  fi

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "real_dir"
    return
  fi

  # It's a symlink
  local link_target
  link_target="$(readlink "$target" 2>/dev/null || true)"

  if [ "$link_target" != "$expected_src" ]; then
    echo "wrong_target"
    return
  fi

  if [ ! -d "$target" ]; then
    echo "broken"
    return
  fi

  echo "correct"
}
```

States:
- **correct** — symlink exists, target matches expected, target is a valid directory
- **missing** — no entry at the name
- **wrong_target** — symlink points to a different path than expected
- **broken** — symlink exists but its target is not a valid directory (dangling)
- **real_dir** — a real (non-symlink) directory occupies the name

### 2c. Find orphaned symlinks

Orphaned symlinks: entries in `~/.agents/skills/` that are symlinks pointing under `PROJECT_ROOT` but whose names are NOT in the expected set. These are leftovers from removed skills.

```bash
for entry in "$SKILLS_DIR"/*/; do
  [ -d "$entry" ] || continue
  name="$(basename "$entry")"
  [ -L "$SKILLS_DIR/$name" ] || continue

  # Check if name is in expected set
  in_expected=false
  for ename in $EXPECTED_NAMES; do
    [ "$ename" = "$name" ] && in_expected=true && break
  done
  if [ "$in_expected" = true ]; then continue; fi

  link_target="$(readlink "$SKILLS_DIR/$name" 2>/dev/null || true)"
  case "$link_target" in
    "$PROJECT_ROOT"|"$PROJECT_ROOT/"*)
      echo "$name"  # orphaned
      ;;
  esac
done
```

## Step 3: Execute

For each diagnosis result, take the appropriate action. Use `install.sh` subcommands (see `install.sh --help`).

### Actions by state

| State | Action | Command |
|-------|--------|---------|
| missing | Create symlink | `install.sh sync <name> <src>` |
| broken | Remove broken + recreate | `install.sh sync <name> <src>` |
| wrong_target | Replace with correct target | `install.sh sync <name> <src>` |
| real_dir | **WARN** — do NOT touch | Report conflict, skip |
| correct | No-op | — |

### Orphaned symlinks

For each orphaned symlink found in Step 2c:

```bash
install.sh unlink <name>
```

This removes the symlink only if its target lies under PROJECT_ROOT (safe).

### Link principles

Ensure principles symlink:

```bash
install.sh link-principles "$PROJECT_ROOT/principles"
```

This creates/repairs `~/.agents/principles` → `$PROJECT_ROOT/principles`. Behaviour mirrors sync: creates if missing, replaces if broken/wrong, warns on real-dir conflict.

### Execution order

1. Process all expected skills (sync missing/broken/wrong_target)
2. Clean up orphaned symlinks (unlink)
3. Ensure principles symlink (link-principles)

Track each action taken — the report must list specific skill names and operations.

## Step 4: Verify

Re-run Step 2 diagnosis on all expected skills. Every skill should now be `correct`.

Also verify principles symlink:

```bash
[ -L "$PRINCIPLES_DIR" ] && [ "$(readlink "$PRINCIPLES_DIR")" = "$PROJECT_ROOT/principles" ] && [ -d "$PRINCIPLES_DIR" ]
```

## Report Template

Output a structured report — list specific skill names and operations, not just counts.

```
TOOLKIT_SETUP_REPORT:

## Expected Set
  N skills (K upstream + A autopilot)

## Actions Taken
  SYNC <name> → <src>
  SYNC <name> → <src>
  UNLINK <name> (orphaned)
  LINK-PRINCIPLES → <src>
  — or —
  (none — all skills already correct)

## Warnings
  WARN: <name> is a real directory at ~/.agents/skills/<name> — skipping
  — or —
  (none)

## Verification
  [PASS] <name>
  [PASS] <name>
  ...
  [PASS] principles
  Total: N expected, 0 missing, 0 damaged
  ALL PASS
```

If any skill remains missing/broken/wrong_target after execute, report as FAIL and do NOT output ALL PASS.

## Edge Cases

- **Skills directory missing**: Created automatically by `install.sh sync` on first use.
- **Source directory missing**: `install.sh sync` warns and skips (exit 0). Report as WARN, do not treat as failure — upstream may be mid-update.
- **Real directory conflict**: Reported as WARN. install.sh refuses to overwrite real directories. User must resolve manually.
- **No changes needed**: Report "all skills already correct", ALL PASS.
- **python3 unavailable**: Fall back to grep-based parsing of `.skill-lock.json`. Less robust but functional for standard JSON layouts.
- **Empty .skill-lock.json skills**: Only autopilot skills in expected set. Valid scenario for minimal installs.
