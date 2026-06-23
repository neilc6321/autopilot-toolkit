---
name: toolkit-selfcheck
description: Validates autopilot-toolkit installation — checks symlink integrity, skill count, frontmatter validity, and excluded item absence in ~/.agents/skills/. Use when you want to verify the toolkit is correctly installed and reasonix-ready.
---

# Toolkit Selfcheck

Validate that the autopilot-toolkit is properly installed and all skills are discoverable by reasonix.

## Check List

Run the following verification steps. Report a **PASS** or **FAIL** for each, with details on any failure.

### 1. Directory exists

```bash
ls -d ~/.agents/skills/
```

FAIL if missing.

### 2. Expected skill count

Count symlinks in `~/.agents/skills/`:

```bash
ls -1 ~/.agents/skills/ | wc -l
```

Expected: **19** (14 upstream + 5 autopilot). Check each expected name exists:

Upstream (14):
`caveman`, `diagnose`, `grill-me`, `grill-with-docs`, `handoff`, `improve-codebase-architecture`, `prototype`, `setup-matt-pocock-skills`, `tdd`, `teach`, `to-issues`, `to-prd`, `triage`, `write-a-skill`

Autopilot (5):
`audit-autopilot`, `autopilot-implementer`, `autopilot-orchestrator`, `autopilot-reviewer`, `toolkit-selfcheck`

### 3. Symlink integrity

Every entry in `~/.agents/skills/` must be a symlink pointing to an existing directory that contains `SKILL.md`:

```bash
broken=0
for link in ~/.agents/skills/*/; do
  name=$(basename "$link")
  if [ ! -L "$link" ]; then
    echo "FAIL: $name is not a symlink"
    broken=$((broken + 1))
    continue
  fi
  target=$(readlink "$link")
  if [ ! -d "$target" ]; then
    echo "FAIL: $name -> $target (target missing)"
    broken=$((broken + 1))
    continue
  fi
  if [ ! -f "$target/SKILL.md" ]; then
    echo "FAIL: $name -> $target (SKILL.md missing)"
    broken=$((broken + 1))
    continue
  fi
  echo "OK: $name -> $target"
done
echo "Broken: $broken"
```

### 4. Frontmatter validity

Each `SKILL.md` must have `name` and `description` fields, and must NOT have opencode-specific fields (`compatibility`, `mode`, `disable-model-invocation`, `permission`, `hidden`, `arguments`):

```bash
fail=0
for skill_md in ~/.agents/skills/*/SKILL.md; do
  name=$(basename "$(dirname "$skill_md")")
  content=$(cat "$skill_md")
  fm_name=$(echo "$content" | sed -n '/^---$/,/^---$/p' | grep '^name:' | head -1)
  fm_desc=$(echo "$content" | sed -n '/^---$/,/^---$/p' | grep '^description:' | head -1)
  if [ -z "$fm_name" ]; then echo "FAIL: $name — missing 'name'"; fail=$((fail+1)); fi
  if [ -z "$fm_desc" ]; then echo "FAIL: $name — missing 'description'"; fail=$((fail+1)); fi
  for bad in compatibility mode disable-model-invocation permission hidden arguments; do
    if echo "$content" | sed -n '/^---$/,/^---$/p' | grep -q "^${bad}:"; then
      echo "FAIL: $name — has opencode field '$bad'"
      fail=$((fail+1))
    fi
  done
done
echo "Frontmatter failures: $fail"
```

### 5. Excluded items absent

These skills must NOT be present in `~/.agents/skills/`:

`skill-creator`, `backtest`, `quant`, `quant-scheduled`, `proxy-subscription-parser`, `rust-artisan`, `rust-artisan-v2`, `rust-coder`, `surge-cli`, `python-uv`, `argus`, `zoom-out`

```bash
present=0
for name in skill-creator backtest quant quant-scheduled proxy-subscription-parser rust-artisan rust-artisan-v2 rust-coder surge-cli python-uv argus zoom-out; do
  if [ -e "$HOME/.agents/skills/$name" ]; then
    echo "FAIL: excluded item '$name' is present"
    present=$((present + 1))
  fi
done
echo "Excluded items present: $present"
```

## Report Template

After all checks, output:

```
TOOLKIT_SELFCHECK_REPORT:

## Directory
  [PASS|FAIL] ~/.agents/skills/ exists

## Skill Count
  [PASS|FAIL] Found N skills (expected 19)
  Missing: <list if any>
  Extra: <list if any>

## Symlink Integrity
  [PASS|FAIL] N broken out of 19

## Frontmatter
  [PASS|FAIL] N failures

## Excluded Items
  [PASS|FAIL] N excluded items unexpectedly present

## Summary
  [ALL PASS] or [N checks FAILED]
```
