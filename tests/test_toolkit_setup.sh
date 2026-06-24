#!/usr/bin/env bash
set -euo pipefail

# Test suite for toolkit-setup orchestration flow
# Usage: bash tests/test_toolkit_setup.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SCRIPT="$PROJECT_ROOT/install.sh"

PASS=0
FAIL=0
ERRORS=""

assert() {
  local desc="$1"
  local condition="$2"
  if eval "$condition"; then
    echo "  ✓ $desc"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $desc"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: $desc"
  fi
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✓ $desc"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $desc (expected: '$expected', got: '$actual')"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: $desc (expected: '$expected', got: '$actual')"
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  ✓ $desc"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $desc (expected to contain: '$needle')"
    echo "    got: $haystack"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: $desc"
  fi
}

# ── Helper: derive expected set from mock project ──
# Outputs lines: "name|source_dir"
derive_expected_set() {
  local mock_root="$1"

  # Upstream skills from .skill-lock.json
  if [ -f "$mock_root/.skill-lock.json" ]; then
    # Use python3 to parse JSON if available, otherwise grep
    if command -v python3 >/dev/null 2>&1; then
      python3 -c "
import json, sys, os
with open('$mock_root/.skill-lock.json') as f:
    data = json.load(f)
for name, info in data.get('skills', {}).items():
    skill_path = info['skillPath']
    # skillPath like 'skills/engineering/tdd/SKILL.md'
    src_dir = os.path.join('$mock_root', 'skills/upstream', os.path.dirname(skill_path))
    print(f'{name}|{src_dir}')
"
    else
      # Fallback: grep-based extraction (simplified)
      echo "WARNING: python3 not available, upstream skill detection limited" >&2
    fi
  fi

  # Autopilot skills from filesystem
  for skill_dir in "$mock_root"/skills/autopilot/*/; do
    if [ -f "$skill_dir/SKILL.md" ]; then
      local name
      name="$(basename "$skill_dir")"
      local abs_dir
      abs_dir="$(cd "$skill_dir" && pwd)"
      echo "$name|$abs_dir"
    fi
  done
}

# ── Helper: check symlink state ──
# Returns one of: correct missing wrong_target broken real_dir
check_skill_state() {
  local name="$1"
  local expected_src="$2"
  local skills_dir="$3"
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

# ── Helper: find orphaned symlinks ──
# Outputs skill names that are symlinks pointing under PROJECT_ROOT but not in expected set
find_orphaned() {
  local skills_dir="$1"
  local project_root="$2"
  local expected_names="$3"  # space-separated list

  if [ ! -d "$skills_dir" ]; then
    return
  fi

  for entry in "$skills_dir"/*/; do
    [ -d "$entry" ] || continue
    local name
    name="$(basename "$entry")"

    # Only look at symlinks
    if [ ! -L "$skills_dir/$name" ]; then
      continue
    fi

    # Check if in expected set
    local found=0
    for ename in $expected_names; do
      if [ "$ename" = "$name" ]; then
        found=1
        break
      fi
    done

    if [ "$found" -eq 0 ]; then
      local link_target
      link_target="$(readlink "$skills_dir/$name" 2>/dev/null || true)"
      case "$link_target" in
        "$project_root"|"$project_root/"*)
          echo "$name"
          ;;
      esac
    fi
  done
}

# ── Helper: run toolkit-setup step 3 (execute) ──
# Takes expected set as "name|src" lines, diagnoses, and executes fixes
run_toolkit_setup_execute() {
  local mock_root="$1"
  local skills_dir="$2"
  local expected_set="$3"  # "name|src" lines

  local output=""
  local warnings=""
  local actions=0
  local NL=$'\n'

  # Collect expected names for orphan detection
  local expected_names=""
  while IFS='|' read -r name src; do
    expected_names="$expected_names $name"
  done <<< "$expected_set"

  # Process each expected skill
  while IFS='|' read -r name src; do
    local state
    state="$(check_skill_state "$name" "$src" "$skills_dir")"

    case "$state" in
      missing|broken|wrong_target)
        local sync_out
        sync_out="$(HOME="$(dirname "$skills_dir")/.." \
          AGENTS_SKILLS_DIR="$skills_dir" \
          PROJECT_ROOT="$mock_root" \
          bash "$INSTALL_SCRIPT" sync "$name" "$src" 2>&1 || true)"
        output="${output}${NL}  SYNC $name → $src"
        actions=$((actions + 1))
        ;;
      real_dir)
        warnings="${warnings}${NL}  WARN: $name is a real directory at $skills_dir/$name — skipping"
        ;;
      correct)
        # No-op
        ;;
    esac
  done <<< "$expected_set"

  # Handle orphaned symlinks
  local orphans
  orphans="$(find_orphaned "$skills_dir" "$mock_root" "$expected_names")"
  for oname in $orphans; do
    HOME="$(dirname "$skills_dir")/.." \
      AGENTS_SKILLS_DIR="$skills_dir" \
      PROJECT_ROOT="$mock_root" \
      bash "$INSTALL_SCRIPT" unlink "$oname" 2>&1 || true
    output="${output}${NL}  UNLINK $oname (orphaned)"
    actions=$((actions + 1))
  done

  # Handle link-principles
  local principles_src="$mock_root/principles"
  if [ -d "$principles_src" ]; then
    local lp_out
    lp_out="$(HOME="$(dirname "$skills_dir")/.." \
      AGENTS_PRINCIPLES_DIR="$(dirname "$skills_dir")/../.agents/principles" \
      bash "$INSTALL_SCRIPT" link-principles "$principles_src" 2>&1 || true)"
    output="${output}${NL}  LINK-PRINCIPLES → $principles_src"
    actions=$((actions + 1))
  fi

  echo "actions=$actions"
  echo "$output"
  echo "$warnings"
}

# ── Helper: run toolkit-setup step 4 (verify) ──
run_toolkit_setup_verify() {
  local mock_root="$1"
  local skills_dir="$2"
  local expected_set="$3"

  local all_pass=true
  local report=""
  local missing_count=0
  local damaged_count=0
  local total=0
  local NL=$'\n'

  while IFS='|' read -r name src; do
    total=$((total + 1))
    local state
    state="$(check_skill_state "$name" "$src" "$skills_dir")"

    case "$state" in
      correct)
        report="${report}${NL}  [PASS] $name"
        ;;
      missing)
        report="${report}${NL}  [FAIL] $name — missing"
        missing_count=$((missing_count + 1))
        all_pass=false
        ;;
      wrong_target)
        local actual
        actual="$(readlink "$skills_dir/$name" 2>/dev/null || echo '?')"
        report="${report}${NL}  [FAIL] $name → $actual (expected $src)"
        damaged_count=$((damaged_count + 1))
        all_pass=false
        ;;
      broken)
        report="${report}${NL}  [FAIL] $name — broken symlink"
        damaged_count=$((damaged_count + 1))
        all_pass=false
        ;;
      real_dir)
        report="${report}${NL}  [WARN] $name — real directory (not a symlink)"
        damaged_count=$((damaged_count + 1))
        all_pass=false
        ;;
    esac
  done <<< "$expected_set"

  report="${report}${NL}  Total: $total expected, $missing_count missing, $damaged_count damaged"

  if [ "$all_pass" = true ]; then
    report="${report}${NL}  ALL PASS"
  else
    report="${report}${NL}  FIXES NEEDED"
  fi

  echo "$report"
}

# ═══════════════════════════════════════════════════
# Setup: Create mock project structure for tests
# ═══════════════════════════════════════════════════

setup_mock_project() {
  local base="$1"
  local mock_root="$base/mock-project"

  mkdir -p "$mock_root"/skills/upstream/skills/engineering/{skill-a,skill-b,skill-c}
  mkdir -p "$mock_root"/skills/autopilot/{auto-x,auto-y}
  mkdir -p "$mock_root"/principles

  # Create SKILL.md files for upstream skills
  for s in skill-a skill-b skill-c; do
    echo "---" > "$mock_root/skills/upstream/skills/engineering/$s/SKILL.md"
    echo "name: $s" >> "$mock_root/skills/upstream/skills/engineering/$s/SKILL.md"
    echo "description: Mock upstream skill $s" >> "$mock_root/skills/upstream/skills/engineering/$s/SKILL.md"
    echo "---" >> "$mock_root/skills/upstream/skills/engineering/$s/SKILL.md"
    echo "# $s" >> "$mock_root/skills/upstream/skills/engineering/$s/SKILL.md"
  done

  # Create SKILL.md files for autopilot skills
  for s in auto-x auto-y; do
    echo "---" > "$mock_root/skills/autopilot/$s/SKILL.md"
    echo "name: $s" >> "$mock_root/skills/autopilot/$s/SKILL.md"
    echo "description: Mock autopilot skill $s" >> "$mock_root/skills/autopilot/$s/SKILL.md"
    echo "---" >> "$mock_root/skills/autopilot/$s/SKILL.md"
    echo "# $s" >> "$mock_root/skills/autopilot/$s/SKILL.md"
  done

  # Create principles file
  echo "Be curious." > "$mock_root/principles/karpathy.md"

  # Create .skill-lock.json
  cat > "$mock_root/.skill-lock.json" << 'LOCKEOF'
{
  "version": 3,
  "skills": {
    "skill-a": {
      "source": "mock/skills",
      "sourceType": "github",
      "sourceUrl": "https://example.com/mock.git",
      "skillPath": "skills/engineering/skill-a/SKILL.md",
      "skillFolderHash": "aaa111",
      "pluginName": "mock-skills",
      "installedAt": "2026-01-01T00:00:00.000Z",
      "updatedAt": "2026-01-01T00:00:00.000Z"
    },
    "skill-b": {
      "source": "mock/skills",
      "sourceType": "github",
      "sourceUrl": "https://example.com/mock.git",
      "skillPath": "skills/engineering/skill-b/SKILL.md",
      "skillFolderHash": "bbb222",
      "pluginName": "mock-skills",
      "installedAt": "2026-01-01T00:00:00.000Z",
      "updatedAt": "2026-01-01T00:00:00.000Z"
    },
    "skill-c": {
      "source": "mock/skills",
      "sourceType": "github",
      "sourceUrl": "https://example.com/mock.git",
      "skillPath": "skills/engineering/skill-c/SKILL.md",
      "skillFolderHash": "ccc333",
      "pluginName": "mock-skills",
      "installedAt": "2026-01-01T00:00:00.000Z",
      "updatedAt": "2026-01-01T00:00:00.000Z"
    }
  },
  "dismissed": {}
}
LOCKEOF

  echo "$mock_root"
}

cleanup() {
  for d in "${TMPDIR1:-}" "${TMPDIR2:-}" "${TMPDIR3:-}" "${TMPDIR4:-}" "${TMPDIR5:-}"; do
    if [ -n "$d" ] && [ -d "$d" ]; then
      chmod -R 755 "$d" 2>/dev/null || true
      rm -rf "$d"
    fi
  done
}
trap cleanup EXIT

echo "=== toolkit-setup test suite ==="
echo ""

# ═══════════════════════════════════════════════════
# Test 1: First install — all skills missing, full sync + link-principles
# ═══════════════════════════════════════════════════
echo "Test 1: First install (all skills missing)"
TMPDIR1="$(mktemp -d /tmp/toolkit-setup-test1-XXXXX)"
MOCK_ROOT1="$(setup_mock_project "$TMPDIR1")"
MOCK_HOME1="$TMPDIR1/home"
MOCK_SKILLS1="$MOCK_HOME1/.agents/skills"

# Derive expected set
EXPECTED_SET1="$(derive_expected_set "$MOCK_ROOT1")"

# Verify expected set has 5 skills (3 upstream + 2 autopilot)
EXPECTED_COUNT1="$(echo "$EXPECTED_SET1" | grep -c '|' || echo 0)"
assert "expected set has 5 skills" "[ '$EXPECTED_COUNT1' -eq 5 ]"

# Verify all skills are initially missing
while IFS='|' read -r name src; do
  state="$(check_skill_state "$name" "$src" "$MOCK_SKILLS1")"
  assert "skill $name initially missing" "[ '$state' = 'missing' ]"
done <<< "$EXPECTED_SET1"

# Execute toolkit-setup
EXEC_RESULT1="$(run_toolkit_setup_execute "$MOCK_ROOT1" "$MOCK_SKILLS1" "$EXPECTED_SET1")"

# Verify sync happened for all 5 skills
SYNC_COUNT1="$(echo "$EXEC_RESULT1" | grep -c 'SYNC' || echo 0)"
assert "first install syncs all 5 skills" "[ '$SYNC_COUNT1' -eq 5 ]"

# Verify link-principles was called
assert "link-principles called on first install" "echo '$EXEC_RESULT1' | grep -q 'LINK-PRINCIPLES'"

# Verify all skills are now correct
while IFS='|' read -r name src; do
  state="$(check_skill_state "$name" "$src" "$MOCK_SKILLS1")"
  assert "skill $name now correct after first install" "[ '$state' = 'correct' ]"
done <<< "$EXPECTED_SET1"

# Verify output contains specific skill names
for s in skill-a skill-b skill-c auto-x auto-y; do
  assert "output mentions $s" "echo '$EXEC_RESULT1' | grep -q '$s'"
done

echo ""

# ═══════════════════════════════════════════════════
# Test 2: Update scenario — only incremental changes
# ═══════════════════════════════════════════════════
echo "Test 2: Update (incremental changes only)"
TMPDIR2="$(mktemp -d /tmp/toolkit-setup-test2-XXXXX)"
MOCK_ROOT2="$(setup_mock_project "$TMPDIR2")"
MOCK_HOME2="$TMPDIR2/home"
MOCK_SKILLS2="$MOCK_HOME2/.agents/skills"
EXPECTED_SET2="$(derive_expected_set "$MOCK_ROOT2")"

# Pre-setup: install all skills correctly first
run_toolkit_setup_execute "$MOCK_ROOT2" "$MOCK_SKILLS2" "$EXPECTED_SET2" > /dev/null 2>&1

# Now simulate an update: break one symlink, add wrong target for another,
# and leave the rest correct
# Break skill-a: create a broken symlink (target does not exist)
rm -f "$MOCK_SKILLS2/skill-a"
ln -sfn "/tmp/nonexistent" "$MOCK_SKILLS2/skill-a"  # broken symlink

# Wrong target for skill-b
rm -f "$MOCK_SKILLS2/skill-b"
ln -sfn "$MOCK_ROOT2/skills/upstream/skills/engineering/skill-c" "$MOCK_SKILLS2/skill-b"

# Re-run toolkit-setup
EXEC_RESULT2="$(run_toolkit_setup_execute "$MOCK_ROOT2" "$MOCK_SKILLS2" "$EXPECTED_SET2")"

# Verify only broken/wrong-target skills were fixed (2 syncs)
SYNC_COUNT2="$(echo "$EXEC_RESULT2" | grep -c 'SYNC' || echo 0)"
assert "update only syncs 2 changed skills" "[ '$SYNC_COUNT2' -eq 2 ]"

# Verify skill-a and skill-b were mentioned in output
assert "output mentions skill-a fix" "echo '$EXEC_RESULT2' | grep -q 'skill-a'"
assert "output mentions skill-b fix" "echo '$EXEC_RESULT2' | grep -q 'skill-b'"

# Verify all skills are correct after update
while IFS='|' read -r name src; do
  state="$(check_skill_state "$name" "$src" "$MOCK_SKILLS2")"
  assert "skill $name correct after update" "[ '$state' = 'correct' ]"
done <<< "$EXPECTED_SET2"

echo ""

# ═══════════════════════════════════════════════════
# Test 3: Orphaned symlink cleanup
# ═══════════════════════════════════════════════════
echo "Test 3: Orphaned symlink cleanup"
TMPDIR3="$(mktemp -d /tmp/toolkit-setup-test3-XXXXX)"
MOCK_ROOT3="$(setup_mock_project "$TMPDIR3")"
MOCK_HOME3="$TMPDIR3/home"
MOCK_SKILLS3="$MOCK_HOME3/.agents/skills"
EXPECTED_SET3="$(derive_expected_set "$MOCK_ROOT3")"

# Pre-setup: install all skills correctly
run_toolkit_setup_execute "$MOCK_ROOT3" "$MOCK_SKILLS3" "$EXPECTED_SET3" > /dev/null 2>&1

# Create an orphaned symlink (pointing under PROJECT_ROOT, not in expected set)
mkdir -p "$MOCK_ROOT3/skills/upstream/skills/engineering/old-skill"
echo "# Old Skill" > "$MOCK_ROOT3/skills/upstream/skills/engineering/old-skill/SKILL.md"
ln -sfn "$MOCK_ROOT3/skills/upstream/skills/engineering/old-skill" "$MOCK_SKILLS3/old-skill"

# Verify orphan exists before execution
assert "orphan symlink exists before setup" "[ -L '$MOCK_SKILLS3/old-skill' ]"

# Re-run toolkit-setup
EXEC_RESULT3="$(run_toolkit_setup_execute "$MOCK_ROOT3" "$MOCK_SKILLS3" "$EXPECTED_SET3")"

# Verify orphan was unlinked
assert "orphan symlink is removed" "[ ! -e '$MOCK_SKILLS3/old-skill' ]"

# Verify UNLINK was reported with specific name
assert "output reports UNLINK with name" "echo '$EXEC_RESULT3' | grep -q 'UNLINK.*old-skill'"

# Verify all expected skills still correct
while IFS='|' read -r name src; do
  state="$(check_skill_state "$name" "$src" "$MOCK_SKILLS3")"
  assert "skill $name still correct after orphan cleanup" "[ '$state' = 'correct' ]"
done <<< "$EXPECTED_SET3"

echo ""

# ═══════════════════════════════════════════════════
# Test 4: Real-directory conflict is reported as WARN
# ═══════════════════════════════════════════════════
echo "Test 4: Real-directory conflict reported as WARN"
TMPDIR4="$(mktemp -d /tmp/toolkit-setup-test4-XXXXX)"
MOCK_ROOT4="$(setup_mock_project "$TMPDIR4")"
MOCK_HOME4="$TMPDIR4/home"
MOCK_SKILLS4="$MOCK_HOME4/.agents/skills"
EXPECTED_SET4="$(derive_expected_set "$MOCK_ROOT4")"

# Pre-setup: install skill-a, skill-b correctly
# But create a real directory for skill-c
mkdir -p "$MOCK_SKILLS4"
# Install skill-a and skill-b via sync
HOME="$MOCK_HOME4" AGENTS_SKILLS_DIR="$MOCK_SKILLS4" PROJECT_ROOT="$MOCK_ROOT4" \
  bash "$INSTALL_SCRIPT" sync skill-a "$MOCK_ROOT4/skills/upstream/skills/engineering/skill-a" 2>&1 > /dev/null || true
HOME="$MOCK_HOME4" AGENTS_SKILLS_DIR="$MOCK_SKILLS4" PROJECT_ROOT="$MOCK_ROOT4" \
  bash "$INSTALL_SCRIPT" sync skill-b "$MOCK_ROOT4/skills/upstream/skills/engineering/skill-b" 2>&1 > /dev/null || true

# Create a real directory at skill-c's location
mkdir -p "$MOCK_SKILLS4/skill-c"
echo "precious data" > "$MOCK_SKILLS4/skill-c/important.txt"

# Re-run toolkit-setup
EXEC_RESULT4="$(run_toolkit_setup_execute "$MOCK_ROOT4" "$MOCK_SKILLS4" "$EXPECTED_SET4")"

# Verify WARN is reported for the real directory conflict
assert "output reports WARN for real dir" "echo '$EXEC_RESULT4' | grep -q 'WARN.*real directory'"
assert "WARN mentions specific skill name" "echo '$EXEC_RESULT4' | grep -q 'skill-c'"

# Verify real directory is preserved
assert "real directory still exists" "[ -d '$MOCK_SKILLS4/skill-c' ]"
assert "precious file preserved" "[ -f '$MOCK_SKILLS4/skill-c/important.txt' ]"
assert "real dir not replaced by symlink" "[ ! -L '$MOCK_SKILLS4/skill-c' ]"

echo ""

# ═══════════════════════════════════════════════════
# Test 5: ALL PASS when final verification succeeds
# ═══════════════════════════════════════════════════
echo "Test 5: ALL PASS on successful verification"
TMPDIR5="$(mktemp -d /tmp/toolkit-setup-test5-XXXXX)"
MOCK_ROOT5="$(setup_mock_project "$TMPDIR5")"
MOCK_HOME5="$TMPDIR5/home"
MOCK_SKILLS5="$MOCK_HOME5/.agents/skills"
EXPECTED_SET5="$(derive_expected_set "$MOCK_ROOT5")"

# Pre-setup: install all skills correctly
run_toolkit_setup_execute "$MOCK_ROOT5" "$MOCK_SKILLS5" "$EXPECTED_SET5" > /dev/null 2>&1

# Run verification
VERIFY_RESULT5="$(run_toolkit_setup_verify "$MOCK_ROOT5" "$MOCK_SKILLS5" "$EXPECTED_SET5")"

# Verify ALL PASS is in output
assert "verification output contains ALL PASS" "echo '$VERIFY_RESULT5' | grep -q 'ALL PASS'"

# Verify each skill is listed as PASS
for s in skill-a skill-b skill-c auto-x auto-y; do
  assert "verification lists $s as PASS" "echo '$VERIFY_RESULT5' | grep -q 'PASS.*$s'"
done

echo ""

# ═══════════════════════════════════════════════════
# Test 6: Verification reports failures correctly
# ═══════════════════════════════════════════════════
echo "Test 6: Verification reports failures (not ALL PASS when broken)"
TMPDIR6="$(mktemp -d /tmp/toolkit-setup-test6-XXXXX)"
MOCK_ROOT6="$(setup_mock_project "$TMPDIR6")"
MOCK_HOME6="$TMPDIR6/home"
MOCK_SKILLS6="$MOCK_HOME6/.agents/skills"
EXPECTED_SET6="$(derive_expected_set "$MOCK_ROOT6")"

# Install only some skills, leave others missing
mkdir -p "$MOCK_SKILLS6"
HOME="$MOCK_HOME6" AGENTS_SKILLS_DIR="$MOCK_SKILLS6" PROJECT_ROOT="$MOCK_ROOT6" \
  bash "$INSTALL_SCRIPT" sync skill-a "$MOCK_ROOT6/skills/upstream/skills/engineering/skill-a" 2>&1 > /dev/null || true

# Run verification
VERIFY_RESULT6="$(run_toolkit_setup_verify "$MOCK_ROOT6" "$MOCK_SKILLS6" "$EXPECTED_SET6")"

# Verify it does NOT say ALL PASS (some skills missing)
assert "verification does NOT say ALL PASS when broken" "! echo '$VERIFY_RESULT6' | grep -q 'ALL PASS'"
assert "verification says FIXES NEEDED" "echo '$VERIFY_RESULT6' | grep -q 'FIXES NEEDED'"

# Verify PASS for the installed skill
assert "verification lists skill-a as PASS" "echo '$VERIFY_RESULT6' | grep -q 'PASS.*skill-a'"

# Verify FAIL for missing skills
assert "verification lists missing skills as FAIL" "echo '$VERIFY_RESULT6' | grep -q 'FAIL.*missing'"

echo ""

# ═══════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [ -n "$ERRORS" ]; then
  echo -e "Failures:$ERRORS"
fi

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
