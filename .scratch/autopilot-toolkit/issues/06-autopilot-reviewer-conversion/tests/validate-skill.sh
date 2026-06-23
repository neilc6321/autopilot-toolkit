#!/usr/bin/env bash
# Test: validate autopilot-reviewer SKILL.md against ACs
set -uo pipefail

PASS=0
FAIL=0
SKILL_FILE="/Users/matthewye/Documents/WorkSpace/autopilot-toolkit/skills/autopilot/autopilot-reviewer/SKILL.md"
ORIGINAL_FILE="/Users/matthewye/Documents/WorkSpace/opencode-toolbox/agents/reviewer.md"

check() {
    local label="$1"
    local cmd="$2"
    if eval "$cmd"; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        FAIL=$((FAIL + 1))
    fi
}

check_not() {
    local label="$1"
    local cmd="$2"
    if ! eval "$cmd"; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== AC Check: SKILL.md exists ==="
check "AC-01: SKILL.md file exists" 'test -f "$SKILL_FILE"'

if [ -f "$SKILL_FILE" ]; then
    CONTENT=$(cat "$SKILL_FILE")
    FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$SKILL_FILE" | sed '1d;$d')

    echo ""
    echo "=== AC Check: Frontmatter ==="
    check "AC-02a: frontmatter has name: autopilot-reviewer" \
        'echo "$FRONTMATTER" | grep -q "name: autopilot-reviewer"'
    check "AC-02b: frontmatter has description" \
        'echo "$FRONTMATTER" | grep -q "description:"'
    check "AC-02c: frontmatter has runAs: subagent" \
        'echo "$FRONTMATTER" | grep -q "runAs: subagent"'
    check "AC-02d: frontmatter has allowed-tools" \
        'echo "$FRONTMATTER" | grep -q "allowed-tools:"'
    check_not "AC-02e: no mode field" \
        'echo "$FRONTMATTER" | grep -q "^mode:"'
    check_not "AC-02f: no hidden field" \
        'echo "$FRONTMATTER" | grep -q "^hidden:"'
    check_not "AC-02g: no permission field" \
        'echo "$FRONTMATTER" | grep -q "^permission:"'
    check_not "AC-02h: no edit: field" \
        'echo "$FRONTMATTER" | grep -q "edit:"'
    check_not "AC-02i: no bash: field" \
        'echo "$FRONTMATTER" | grep -q "bash:"'

    echo ""
    echo "=== AC Check: Preamble replaced ==="
    check "AC-03a: reasonix skill reference present" \
        'echo "$CONTENT" | grep -q "access to the .tdd. skill"'
    check_not "AC-03b: no opencode skill tool loading text" \
        'echo "$CONTENT" | grep -q "必须使用 .skill. 工具加载以下技能"'

    echo ""
    echo "=== AC Check: Reviewer logic preserved ==="
    check "AC-04: Four-axis review framework (维度一)" \
        'echo "$CONTENT" | grep -q "维度一"'
    check "AC-05: Grading standards table (Critical)" \
        'echo "$CONTENT" | grep -q "\*\*Critical\*\*"'
    check "AC-05b: Grading standards table (Important)" \
        'echo "$CONTENT" | grep -q "\*\*Important\*\*"'
    check "AC-05c: Grading standards table (Suggestion)" \
        'echo "$CONTENT" | grep -q "\*\*Suggestion\*\*"'
    check "AC-06a: MERGE verdict" \
        'echo "$CONTENT" | grep -q "MERGE"'
    check "AC-06b: RETRY verdict" \
        'echo "$CONTENT" | grep -q "RETRY"'
    check "AC-06c: BLOCKED verdict" \
        'echo "$CONTENT" | grep -q "BLOCKED"'
    check "AC-06d: VERIFY_NEEDED verdict" \
        'echo "$CONTENT" | grep -q "VERIFY_NEEDED"'
    check "AC-07: UNVERIFIED mode logic" \
        'echo "$CONTENT" | grep -q "UNVERIFIED 模式"'
    check "AC-08a: KEYWORDS annotation" \
        'echo "$CONTENT" | grep -q "KEYWORDS:"'
    check "AC-08b: FILES annotation" \
        'echo "$CONTENT" | grep -q "FILES:"'
    check "AC-09: REVIEWER_REPORT format" \
        'echo "$CONTENT" | grep -q "REVIEWER_REPORT:"'
    check "AC-10: Prohibited behaviors (禁止行为)" \
        'echo "$CONTENT" | grep -q "禁止行为"'
fi

echo ""
echo "=== AC Check: Original file unchanged ==="
check "AC-11: Original reviewer.md exists" 'test -f "$ORIGINAL_FILE"'
check "AC-11: Original still has mode: (proves unchanged)" \
    'grep -q "^mode:" "$ORIGINAL_FILE"'

echo ""
echo "=============================="
echo "Results: $PASS passed, $FAIL failed"
echo "=============================="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
