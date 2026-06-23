import { describe, it } from 'node:test';
import assert from 'node:assert';
import { validateSkill } from './validate.js';

describe('validateSkill', () => {
  it('fails when name is missing', () => {
    const content = `---
description: A test skill
---
# Test`;
    const result = validateSkill(content);
    assert.strictEqual(result.passed, false);
    assert.ok(result.issues.some((i) => i.includes('name')));
  });

  it('fails when description is missing', () => {
    const content = `---
name: test-skill
---
# Test`;
    const result = validateSkill(content);
    assert.strictEqual(result.passed, false);
    assert.ok(result.issues.some((i) => i.includes('description')));
  });

  it('passes with valid minimal frontmatter', () => {
    const content = `---
name: my-skill
description: Does something useful.
---
# My Skill`;
    const result = validateSkill(content);
    assert.strictEqual(result.passed, true);
    assert.deepStrictEqual(result.issues, []);
  });

  // Check 2: Name format
  it('fails when name starts with non-alphanumeric', () => {
    const content = `---
name: _bad-name
description: A test
---
# Test`;
    const result = validateSkill(content);
    assert.strictEqual(result.passed, false);
    assert.ok(result.issues.some((i) => i.includes('Name')));
  });

  it('fails when name exceeds 64 characters', () => {
    const content = `---
name: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
description: A test
---
# Test`;
    const result = validateSkill(content);
    assert.strictEqual(result.passed, false);
    assert.ok(result.issues.some((i) => i.includes('Name')));
  });

  it('accepts valid name with dots and hyphens', () => {
    const content = `---
name: my-skill.v2_test
description: A test
---
# Test`;
    const result = validateSkill(content);
    assert.strictEqual(result.passed, true);
  });

  // Check 3: No opencode fields
  it('fails when disable-model-invocation is present', () => {
    const content = `---
name: test-skill
description: A test
disable-model-invocation: true
---
# Test`;
    const result = validateSkill(content);
    assert.strictEqual(result.passed, false);
    assert.ok(result.issues.some((i) => i.includes('disable-model-invocation')));
  });

  it('fails when compatibility is present', () => {
    const content = `---
name: test-skill
description: A test
compatibility: ">=1.0"
---
# Test`;
    const result = validateSkill(content);
    assert.strictEqual(result.passed, false);
    assert.ok(result.issues.some((i) => i.includes('compatibility')));
  });

  it('fails when multiple opencode fields are present', () => {
    const content = `---
name: test-skill
description: A test
mode: chat
hidden: true
---
# Test`;
    const result = validateSkill(content);
    assert.strictEqual(result.passed, false);
    assert.ok(result.issues.some((i) => i.includes('mode')));
    assert.ok(result.issues.some((i) => i.includes('hidden')));
  });

  // Check 4: runAs valid
  it('accepts runAs: inline', () => {
    const content = `---
name: test-skill
description: A test
runAs: inline
---
# Test`;
    const result = validateSkill(content);
    assert.strictEqual(result.passed, true);
  });

  it('accepts runAs: subagent with allowed-tools', () => {
    const content = `---
name: test-skill
description: A test
runAs: subagent
allowed-tools: read, write
---
# Test`;
    const result = validateSkill(content);
    assert.strictEqual(result.passed, true);
  });

  it('fails when runAs has invalid value', () => {
    const content = `---
name: test-skill
description: A test
runAs: agent
---
# Test`;
    const result = validateSkill(content);
    assert.strictEqual(result.passed, false);
    assert.ok(result.issues.some((i) => i.includes('runAs')));
  });

  // Check 5: allowed-tools present for subagents
  it('fails when runAs is subagent but allowed-tools missing', () => {
    const content = `---
name: test-skill
description: A test
runAs: subagent
---
# Test`;
    const result = validateSkill(content);
    assert.strictEqual(result.passed, false);
    assert.ok(result.issues.some((i) => i.includes('allowed-tools')));
  });

  it('accepts subagent with TODO allowed-tools', () => {
    const content = `---
name: test-skill
description: A test
runAs: subagent
allowed-tools: TODO
---
# Test`;
    const result = validateSkill(content);
    assert.strictEqual(result.passed, true);
  });

  // Check 6: Frontmatter well-formed
  it('fails when no opening --- delimiter', () => {
    const content = `name: test-skill
description: A test
---
# Test`;
    const result = validateSkill(content);
    assert.strictEqual(result.passed, false);
    assert.ok(result.issues.some((i) => i.includes('opening')));
  });

  it('fails when no closing --- delimiter', () => {
    const content = `---
name: test-skill
description: A test
# Test`;
    const result = validateSkill(content);
    assert.strictEqual(result.passed, false);
    assert.ok(result.issues.some((i) => i.includes('closing')));
  });

  // Complex cases
  it('reports multiple issues at once', () => {
    const content = `---
name: _bad-name
compatibility: ">1.0"
runAs: agent
---
# Test`;
    const result = validateSkill(content);
    assert.strictEqual(result.passed, false);
    // Missing description, bad name, opencode field, invalid runAs
    assert.strictEqual(result.issues.length >= 4, true);
  });
});
