#!/usr/bin/env bash
set -euo pipefail

# Test suite for install.rs subcommands (sync, unlink, link-principles)
# Usage: bash tests/test_install_rs.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SCRIPT="$PROJECT_ROOT/install.rs"

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

assert_symlink_target() {
  local desc="$1" link="$2" expected_target="$3"
  if [ -L "$link" ]; then
    actual="$(readlink "$link")"
    assert_eq "$desc" "$expected_target" "$actual"
  else
    echo "  ✗ $desc (not a symlink)"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: $desc (not a symlink)"
  fi
}

cleanup() {
  for d in "${TMPDIR:-}" "${TMPDIR2:-}" "${TMPDIR3:-}" "${TMPDIR4:-}" "${TMPDIR5:-}" "${TMPDIR6:-}"; do
    if [ -n "$d" ] && [ -d "$d" ]; then
      chmod -R 755 "$d" 2>/dev/null || true
      rm -rf "$d"
    fi
  done
}
trap cleanup EXIT

echo "=== install.rs sync test suite ==="
echo ""

# ── Test 1: No args prints usage and exits non-zero ──
echo "Test 1: No args → usage"
TMPDIR="$(mktemp -d /tmp/install-sync-test-XXXXX)"

exit_code=0
"$INSTALL_SCRIPT" 2>&1 | tee "$TMPDIR/output1.txt" || exit_code=$?

assert "no-args exits non-zero" "[ '$exit_code' -ne 0 ]"
output1="$(cat "$TMPDIR/output1.txt")"
assert "no-args prints usage mentioning sync" "echo '$output1' | grep -q 'Usage:' || echo '$output1' | grep -qi 'sync'"

echo ""

# ── Test 1b: sync with 0 args (after subcommand) ──
echo "Test 1b: sync with 0 args"
exit_code=0
"$INSTALL_SCRIPT" sync 2>&1 | tee "$TMPDIR/output1b.txt" || exit_code=$?

assert "sync-0-args exits non-zero" "[ '$exit_code' -ne 0 ]"
output1b="$(cat "$TMPDIR/output1b.txt")"
assert "sync-0-args prints error about arguments" "echo '$output1b' | grep -qi 'requires exactly two'"

echo ""

# ── Test 1c: sync with 1 arg ──
echo "Test 1c: sync with 1 arg"
exit_code=0
"$INSTALL_SCRIPT" sync onlyname 2>&1 | tee "$TMPDIR/output1c.txt" || exit_code=$?

assert "sync-1-arg exits non-zero" "[ '$exit_code' -ne 0 ]"
output1c="$(cat "$TMPDIR/output1c.txt")"
assert "sync-1-arg prints error about arguments" "echo '$output1c' | grep -qi 'requires exactly two'"

echo ""

# ── Test 1d: sync with 3+ args ──
echo "Test 1d: sync with 3 args"
exit_code=0
"$INSTALL_SCRIPT" sync a b c 2>&1 | tee "$TMPDIR/output1d.txt" || exit_code=$?

assert "sync-3-args exits non-zero" "[ '$exit_code' -ne 0 ]"
output1d="$(cat "$TMPDIR/output1d.txt")"
assert "sync-3-args prints error about arguments" "echo '$output1d' | grep -qi 'requires exactly two'"

echo ""

# ── Test 2: Fresh sync (target does not exist) ──
echo "Test 2: Fresh sync"
TMPDIR2="$(mktemp -d /tmp/install-sync-test2-XXXXX)"
MOCK_HOME="$TMPDIR2/home"
MOCK_SKILLS="$MOCK_HOME/.agents/skills"
MOCK_SRC="$TMPDIR2/source-skills/my-skill"

mkdir -p "$MOCK_SRC"
echo "# My Skill" > "$MOCK_SRC/SKILL.md"

exit_code=0
HOME="$MOCK_HOME" AGENTS_SKILLS_DIR="$MOCK_SKILLS" \
  "$INSTALL_SCRIPT" sync my-skill "$MOCK_SRC" 2>&1 | tee "$TMPDIR2/output2.txt" || exit_code=$?

assert "fresh sync exits 0" "[ '$exit_code' -eq 0 ]"
assert "creates skills dir" "[ -d '$MOCK_SKILLS' ]"
assert "symlink exists" "[ -L '$MOCK_SKILLS/my-skill' ]"
assert "symlink is valid (target exists)" "[ -d '$MOCK_SKILLS/my-skill' ]"
assert_symlink_target "symlink points to correct source" \
  "$MOCK_SKILLS/my-skill" "$MOCK_SRC"

echo ""

# ── Test 3: Idempotent re-sync (correct symlink already exists) ──
echo "Test 3: Idempotent re-sync"
# Re-run sync with same args
exit_code=0
HOME="$MOCK_HOME" AGENTS_SKILLS_DIR="$MOCK_SKILLS" \
  "$INSTALL_SCRIPT" sync my-skill "$MOCK_SRC" 2>&1 | tee "$TMPDIR2/output3.txt" || exit_code=$?

assert "idempotent re-sync exits 0" "[ '$exit_code' -eq 0 ]"
assert "symlink still exists" "[ -L '$MOCK_SKILLS/my-skill' ]"
assert "symlink still valid" "[ -d '$MOCK_SKILLS/my-skill' ]"
assert_symlink_target "symlink still points to correct source" \
  "$MOCK_SKILLS/my-skill" "$MOCK_SRC"

echo ""

# ── Test 4: Broken symlink repair ──
echo "Test 4: Broken symlink repair"
rm -rf "$MOCK_SRC"  # Remove source to break the symlink
assert "symlink is now broken" "[ -L '$MOCK_SKILLS/my-skill' ] && [ ! -d '$MOCK_SKILLS/my-skill' ]"

# Recreate source and run sync
mkdir -p "$MOCK_SRC"
echo "# My Skill Restored" > "$MOCK_SRC/SKILL.md"

exit_code=0
HOME="$MOCK_HOME" AGENTS_SKILLS_DIR="$MOCK_SKILLS" \
  "$INSTALL_SCRIPT" sync my-skill "$MOCK_SRC" 2>&1 | tee "$TMPDIR2/output4.txt" || exit_code=$?

assert "broken symlink repair exits 0" "[ '$exit_code' -eq 0 ]"
assert "symlink is valid after repair" "[ -L '$MOCK_SKILLS/my-skill' ] && [ -d '$MOCK_SKILLS/my-skill' ]"
assert_symlink_target "repaired symlink points to correct source" \
  "$MOCK_SKILLS/my-skill" "$MOCK_SRC"

echo ""

# ── Test 5: Wrong-target symlink replacement ──
echo "Test 5: Wrong-target symlink replacement"
MOCK_SRC2="$TMPDIR2/source-skills/other-skill"
mkdir -p "$MOCK_SRC2"
echo "# Other Skill" > "$MOCK_SRC2/SKILL.md"

# Create a symlink pointing to a different target
rm -f "$MOCK_SKILLS/my-skill"
ln -sfn "$MOCK_SRC2" "$MOCK_SKILLS/my-skill"

# Now sync to the original src — should replace
exit_code=0
HOME="$MOCK_HOME" AGENTS_SKILLS_DIR="$MOCK_SKILLS" \
  "$INSTALL_SCRIPT" sync my-skill "$MOCK_SRC" 2>&1 | tee "$TMPDIR2/output5.txt" || exit_code=$?

assert "wrong-target replacement exits 0" "[ '$exit_code' -eq 0 ]"
assert "symlink exists after replacement" "[ -L '$MOCK_SKILLS/my-skill' ]"
assert_symlink_target "symlink now points to correct source" \
  "$MOCK_SKILLS/my-skill" "$MOCK_SRC"

echo ""

# ── Test 6: Real directory conflict (warn + exit ≠ 0) ──
echo "Test 6: Real directory conflict"
TMPDIR3="$(mktemp -d /tmp/install-sync-test3-XXXXX)"
MOCK_HOME3="$TMPDIR3/home"
MOCK_SKILLS3="$MOCK_HOME3/.agents/skills"
MOCK_SRC3="$TMPDIR3/source-skills/conflict-skill"

mkdir -p "$MOCK_SRC3"
echo "# Conflict Skill" > "$MOCK_SRC3/SKILL.md"

# Create a real directory at the target location
mkdir -p "$MOCK_SKILLS3/conflict-skill"
echo "precious data" > "$MOCK_SKILLS3/conflict-skill/important.txt"

exit_code=0
HOME="$MOCK_HOME3" AGENTS_SKILLS_DIR="$MOCK_SKILLS3" \
  "$INSTALL_SCRIPT" sync conflict-skill "$MOCK_SRC3" 2>&1 | tee "$TMPDIR3/output6.txt" || exit_code=$?

assert "real-dir conflict exits non-zero" "[ '$exit_code' -ne 0 ]"
output6="$(cat "$TMPDIR3/output6.txt")"
assert "real-dir conflict warns to stderr" "echo '$output6' | grep -qi 'real directory'"
assert "real directory still exists" "[ -d '$MOCK_SKILLS3/conflict-skill' ]"
assert "precious file preserved" "[ -f '$MOCK_SKILLS3/conflict-skill/important.txt' ]"
assert "no symlink created over real dir" "[ ! -L '$MOCK_SKILLS3/conflict-skill' ]"

echo ""

# ── Test 7: Source directory does not exist (warn + exit 0) ──
echo "Test 7: Missing source dir"
TMPDIR4="$(mktemp -d /tmp/install-sync-test4-XXXXX)"
MOCK_HOME4="$TMPDIR4/home"
MOCK_SKILLS4="$MOCK_HOME4/.agents/skills"
MOCK_SRC_NONEXISTENT="$TMPDIR4/nonexistent-src"

exit_code=0
HOME="$MOCK_HOME4" AGENTS_SKILLS_DIR="$MOCK_SKILLS4" \
  "$INSTALL_SCRIPT" sync ghost-skill "$MOCK_SRC_NONEXISTENT" 2>&1 | tee "$TMPDIR4/output7.txt" || exit_code=$?

assert "missing source exits 0" "[ '$exit_code' -eq 0 ]"
output7="$(cat "$TMPDIR4/output7.txt")"
assert "missing source warns to stderr" "echo '$output7' | grep -qi 'not exist'"
assert "no symlink created for missing source" "[ ! -e '$MOCK_SKILLS4/ghost-skill' ]"

echo ""

# ── Test 8: Unknown subcommand ──
echo "Test 8: Unknown subcommand"
exit_code=0
"$INSTALL_SCRIPT" bogus arg1 2>&1 | tee "$TMPDIR/output8.txt" || exit_code=$?

assert "unknown subcommand exits non-zero" "[ '$exit_code' -ne 0 ]"
output8="$(cat "$TMPDIR/output8.txt")"
assert "unknown subcommand prints error" "echo '$output8' | grep -qi 'unknown\|usage'"

echo ""

# ═══════════════════════════════════════════════════════
# ── unlink subcommand tests ──
# ═══════════════════════════════════════════════════════
echo "=== install.rs unlink test suite ==="
echo ""

# ── Test U0a: unlink with 0 args (after subcommand) ──
echo "Test U0a: unlink with 0 args"
exit_code=0
"$INSTALL_SCRIPT" unlink 2>&1 | tee "$TMPDIR/output_u0a.txt" || exit_code=$?

assert "unlink-0-args exits non-zero" "[ '$exit_code' -ne 0 ]"
output_u0a="$(cat "$TMPDIR/output_u0a.txt")"
assert "unlink-0-args prints error about arguments" "echo '$output_u0a' | grep -qi 'requires exactly one'"

echo ""

# ── Test U0b: unlink with 2 args ──
echo "Test U0b: unlink with 2 args"
exit_code=0
"$INSTALL_SCRIPT" unlink a b 2>&1 | tee "$TMPDIR/output_u0b.txt" || exit_code=$?

assert "unlink-2-args exits non-zero" "[ '$exit_code' -ne 0 ]"
output_u0b="$(cat "$TMPDIR/output_u0b.txt")"
assert "unlink-2-args prints error about arguments" "echo '$output_u0b' | grep -qi 'requires exactly one'"

echo ""

# ── Test U1: Unlink a PROJECT_ROOT symlink ──
echo "Test U1: Unlink PROJECT_ROOT symlink"
TMPDIR5="$(mktemp -d /tmp/install-unlink-test-XXXXX)"
MOCK_HOME5="$TMPDIR5/home"
MOCK_SKILLS5="$MOCK_HOME5/.agents/skills"
MOCK_SRC5="$TMPDIR5/source-skills/to-remove"

mkdir -p "$MOCK_SRC5"
echo "# To Remove" > "$MOCK_SRC5/SKILL.md"

# Create a symlink whose target is under a mock PROJECT_ROOT.
mkdir -p "$MOCK_SKILLS5"
ln -sfn "$MOCK_SRC5" "$MOCK_SKILLS5/to-remove"

exit_code=0
HOME="$MOCK_HOME5" AGENTS_SKILLS_DIR="$MOCK_SKILLS5" PROJECT_ROOT="$TMPDIR5" \
  "$INSTALL_SCRIPT" unlink to-remove 2>&1 | tee "$TMPDIR5/output_u1.txt" || exit_code=$?

assert "unlink PROJECT_ROOT symlink exits 0" "[ '$exit_code' -eq 0 ]"
assert "symlink is removed" "[ ! -e '$MOCK_SKILLS5/to-remove' ]"
assert "source directory preserved" "[ -d '$MOCK_SRC5' ]"
assert "source file preserved" "[ -f '$MOCK_SRC5/SKILL.md' ]"

echo ""

# ── Test U2: Symlink target NOT under PROJECT_ROOT → no-op ──
echo "Test U2: Non-PROJECT_ROOT symlink no-op"
MOCK_SKILLS5_EXTERNAL="$TMPDIR5/external-target"
mkdir -p "$MOCK_SKILLS5_EXTERNAL"

# Create a symlink pointing outside PROJECT_ROOT (to /tmp area)
ln -sfn "$MOCK_SKILLS5_EXTERNAL" "$MOCK_SKILLS5/external-link"

exit_code=0
HOME="$MOCK_HOME5" AGENTS_SKILLS_DIR="$MOCK_SKILLS5" \
  "$INSTALL_SCRIPT" unlink external-link 2>&1 | tee "$TMPDIR5/output_u2.txt" || exit_code=$?

assert "unlink non-PROJECT_ROOT symlink exits 0" "[ '$exit_code' -eq 0 ]"
assert "non-PROJECT_ROOT symlink preserved" "[ -L '$MOCK_SKILLS5/external-link' ]"

echo ""

# ── Test U3: Target does not exist → no-op ──
echo "Test U3: Non-existent target no-op"
exit_code=0
HOME="$MOCK_HOME5" AGENTS_SKILLS_DIR="$MOCK_SKILLS5" \
  "$INSTALL_SCRIPT" unlink nothing-here 2>&1 | tee "$TMPDIR5/output_u3.txt" || exit_code=$?

assert "unlink non-existent target exits 0" "[ '$exit_code' -eq 0 ]"

echo ""

# ── Test U4: Real directory → no-op ──
echo "Test U4: Real directory no-op"
mkdir -p "$MOCK_SKILLS5/my-real-dir"
echo "keep me" > "$MOCK_SKILLS5/my-real-dir/data.txt"

exit_code=0
HOME="$MOCK_HOME5" AGENTS_SKILLS_DIR="$MOCK_SKILLS5" \
  "$INSTALL_SCRIPT" unlink my-real-dir 2>&1 | tee "$TMPDIR5/output_u4.txt" || exit_code=$?

assert "unlink real directory exits 0" "[ '$exit_code' -eq 0 ]"
assert "real directory preserved" "[ -d '$MOCK_SKILLS5/my-real-dir' ]"
assert "real directory file preserved" "[ -f '$MOCK_SKILLS5/my-real-dir/data.txt' ]"

echo ""

# ═══════════════════════════════════════════════════════
# ── link-principles subcommand tests ──
# ═══════════════════════════════════════════════════════
echo "=== install.rs link-principles test suite ==="
echo ""

# ── Test P0a: link-principles with 0 args (after subcommand) ──
echo "Test P0a: link-principles with 0 args"
exit_code=0
"$INSTALL_SCRIPT" link-principles 2>&1 | tee "$TMPDIR/output_p0a.txt" || exit_code=$?

assert "link-principles-0-args exits non-zero" "[ '$exit_code' -ne 0 ]"
output_p0a="$(cat "$TMPDIR/output_p0a.txt")"
assert "link-principles-0-args prints error about arguments" "echo '$output_p0a' | grep -qi 'requires exactly one'"

echo ""

# ── Test P0b: link-principles with 2 args ──
echo "Test P0b: link-principles with 2 args"
exit_code=0
"$INSTALL_SCRIPT" link-principles a b 2>&1 | tee "$TMPDIR/output_p0b.txt" || exit_code=$?

assert "link-principles-2-args exits non-zero" "[ '$exit_code' -ne 0 ]"
output_p0b="$(cat "$TMPDIR/output_p0b.txt")"
assert "link-principles-2-args prints error about arguments" "echo '$output_p0b' | grep -qi 'requires exactly one'"

echo ""

# ── Test P1: Fresh creation (target does not exist) ──
echo "Test P1: Fresh link-principles"
TMPDIR6="$(mktemp -d /tmp/install-principles-test-XXXXX)"
MOCK_HOME6="$TMPDIR6/home"
MOCK_PRINCIPLES="$MOCK_HOME6/.agents/principles"
MOCK_SRC_PRINCIPLES="$TMPDIR6/my-principles"

mkdir -p "$MOCK_SRC_PRINCIPLES"
echo "Be curious." > "$MOCK_SRC_PRINCIPLES/karpathy.md"

exit_code=0
HOME="$MOCK_HOME6" AGENTS_PRINCIPLES_DIR="$MOCK_PRINCIPLES" \
  "$INSTALL_SCRIPT" link-principles "$MOCK_SRC_PRINCIPLES" 2>&1 | tee "$TMPDIR6/output_p1.txt" || exit_code=$?

assert "link-principles fresh exits 0" "[ '$exit_code' -eq 0 ]"
assert "principles symlink exists" "[ -L '$MOCK_PRINCIPLES' ]"
assert "principles symlink is valid" "[ -d '$MOCK_PRINCIPLES' ]"
assert_symlink_target "principles symlink points to source" \
  "$MOCK_PRINCIPLES" "$MOCK_SRC_PRINCIPLES"

echo ""

# ── Test P2: Idempotent (already correct symlink) ──
echo "Test P2: Idempotent link-principles"
exit_code=0
HOME="$MOCK_HOME6" AGENTS_PRINCIPLES_DIR="$MOCK_PRINCIPLES" \
  "$INSTALL_SCRIPT" link-principles "$MOCK_SRC_PRINCIPLES" 2>&1 | tee "$TMPDIR6/output_p2.txt" || exit_code=$?

assert "link-principles idempotent exits 0" "[ '$exit_code' -eq 0 ]"
assert "principles symlink still exists" "[ -L '$MOCK_PRINCIPLES' ]"
assert "principles symlink still valid" "[ -d '$MOCK_PRINCIPLES' ]"
assert_symlink_target "principles symlink still points to source" \
  "$MOCK_PRINCIPLES" "$MOCK_SRC_PRINCIPLES"

echo ""

# ── Test P3: Broken symlink repair ──
echo "Test P3: Broken symlink repair"
rm -rf "$MOCK_SRC_PRINCIPLES"
assert "principles symlink is now broken" "[ -L '$MOCK_PRINCIPLES' ] && [ ! -d '$MOCK_PRINCIPLES' ]"

# Call link-principles while source is still missing — should detect broken
# symlink (even though the path matches), remove it, and warn.
exit_code=0
HOME="$MOCK_HOME6" AGENTS_PRINCIPLES_DIR="$MOCK_PRINCIPLES" \
  "$INSTALL_SCRIPT" link-principles "$MOCK_SRC_PRINCIPLES" 2>&1 | tee "$TMPDIR6/output_p3.txt" || exit_code=$?

assert "link-principles broken repair exits 0" "[ '$exit_code' -eq 0 ]"
output_p3="$(cat "$TMPDIR6/output_p3.txt")"
assert "link-principles broken repair warns missing source" "echo '$output_p3' | grep -qi 'not exist'"
assert "broken symlink removed" "[ ! -e '$MOCK_PRINCIPLES' ]"

# Now recreate source and run link-principles — should create fresh symlink
mkdir -p "$MOCK_SRC_PRINCIPLES"
echo "Be curious. (restored)" > "$MOCK_SRC_PRINCIPLES/karpathy.md"

exit_code=0
HOME="$MOCK_HOME6" AGENTS_PRINCIPLES_DIR="$MOCK_PRINCIPLES" \
  "$INSTALL_SCRIPT" link-principles "$MOCK_SRC_PRINCIPLES" 2>&1 | tee "$TMPDIR6/output_p3b.txt" || exit_code=$?

assert "link-principles fresh after repair exits 0" "[ '$exit_code' -eq 0 ]"
assert "principles symlink is valid after repair" "[ -L '$MOCK_PRINCIPLES' ] && [ -d '$MOCK_PRINCIPLES' ]"
assert_symlink_target "repaired principles symlink points to source" \
  "$MOCK_PRINCIPLES" "$MOCK_SRC_PRINCIPLES"

echo ""

# ── Test P4: Wrong-target symlink replacement ──
echo "Test P4: Wrong-target symlink replacement"
MOCK_SRC_OTHER="$TMPDIR6/other-principles"
mkdir -p "$MOCK_SRC_OTHER"
echo "Other principles." > "$MOCK_SRC_OTHER/README.md"

# Replace with symlink to different target
rm -f "$MOCK_PRINCIPLES"
ln -sfn "$MOCK_SRC_OTHER" "$MOCK_PRINCIPLES"

exit_code=0
HOME="$MOCK_HOME6" AGENTS_PRINCIPLES_DIR="$MOCK_PRINCIPLES" \
  "$INSTALL_SCRIPT" link-principles "$MOCK_SRC_PRINCIPLES" 2>&1 | tee "$TMPDIR6/output_p4.txt" || exit_code=$?

assert "link-principles wrong-target exits 0" "[ '$exit_code' -eq 0 ]"
assert "principles symlink exists after replacement" "[ -L '$MOCK_PRINCIPLES' ]"
assert_symlink_target "principles symlink now points to correct source" \
  "$MOCK_PRINCIPLES" "$MOCK_SRC_PRINCIPLES"

echo ""

# ── Test P5: Real directory conflict (warn + exit ≠ 0) ──
echo "Test P5: Real directory conflict"
# Remove the symlink and create a real directory in its place
rm -f "$MOCK_PRINCIPLES"
mkdir -p "$MOCK_PRINCIPLES"
echo "precious principles" > "$MOCK_PRINCIPLES/personal.md"

exit_code=0
HOME="$MOCK_HOME6" AGENTS_PRINCIPLES_DIR="$MOCK_PRINCIPLES" \
  "$INSTALL_SCRIPT" link-principles "$MOCK_SRC_PRINCIPLES" 2>&1 | tee "$TMPDIR6/output_p5.txt" || exit_code=$?

assert "link-principles real-dir conflict exits non-zero" "[ '$exit_code' -ne 0 ]"
output_p5="$(cat "$TMPDIR6/output_p5.txt")"
assert "link-principles real-dir conflict warns to stderr" "echo '$output_p5' | grep -qi 'real directory'"
assert "real principles directory preserved" "[ -d '$MOCK_PRINCIPLES' ]"
assert "real principles file preserved" "[ -f '$MOCK_PRINCIPLES/personal.md' ]"
assert "no symlink created over real principles dir" "[ ! -L '$MOCK_PRINCIPLES' ]"

echo ""

# ── Test P6: Source directory does not exist (warn + exit 0) ──
echo "Test P6: Missing source dir for link-principles"
# Clean up the real directory left by P5 so we can test missing-source path
rm -rf "$MOCK_PRINCIPLES"
MOCK_SRC_NONEXISTENT="$TMPDIR6/nonexistent-principles"

exit_code=0
HOME="$MOCK_HOME6" AGENTS_PRINCIPLES_DIR="$MOCK_PRINCIPLES" \
  "$INSTALL_SCRIPT" link-principles "$MOCK_SRC_NONEXISTENT" 2>&1 | tee "$TMPDIR6/output_p6.txt" || exit_code=$?

assert "link-principles missing source exits 0" "[ '$exit_code' -eq 0 ]"
output_p6="$(cat "$TMPDIR6/output_p6.txt")"
assert "link-principles missing source warns to stderr" "echo '$output_p6' | grep -qi 'not exist'"
assert "no symlink created for missing source" "[ ! -e '$MOCK_PRINCIPLES' ]"

echo ""

# ═══════════════════════════════════════════════════════

# ── Summary ──
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
