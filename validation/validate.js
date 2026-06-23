/**
 * Parse YAML-like frontmatter between --- delimiters.
 * Supports simple key: value pairs and folded scalars (>) but not full YAML.
 */
function parseFrontmatter(content) {
  const lines = content.split('\n');
  if (lines[0]?.trim() !== '---') return { fields: null, issues: ['Missing opening --- delimiter'] };

  let endIndex = -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i].trim() === '---') {
      endIndex = i;
      break;
    }
  }

  if (endIndex === -1) return { fields: null, issues: ['Missing closing --- delimiter'] };

  const fmLines = lines.slice(1, endIndex);
  const fields = {};
  const issues = [];

  for (let i = 0; i < fmLines.length; i++) {
    const line = fmLines[i];
    const match = line.match(/^(\w[\w-]*)\s*:\s*(.*)$/);
    if (match) {
      const key = match[1];
      let value = match[2].trim();

      // Handle folded block scalar (>)
      if (value === '>' || value === '>-') {
        value = '';
        i++;
        while (i < fmLines.length && /^\s{2,}/.test(fmLines[i])) {
          value += (value ? ' ' : '') + fmLines[i].trim();
          i++;
        }
        i--; // step back since loop increments
      }

      // Handle | literal block scalar
      if (value === '|' || value === '|-') {
        value = '';
        i++;
        while (i < fmLines.length && /^\s{2,}/.test(fmLines[i])) {
          value += (value ? '\n' : '') + fmLines[i].trim();
          i++;
        }
        i--;
      }

      fields[key] = value;
    }
  }

  return { fields, issues: [] };
}

const OPENCODE_FIELDS = [
  'compatibility',
  'mode',
  'disable-model-invocation',
  'permission',
  'hidden',
  'arguments',
];

const NAME_REGEX = /^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$/;

/**
 * Validate a SKILL.md file's frontmatter against reasonix compatibility rules.
 *
 * @param {string} content - Full file content
 * @returns {{ passed: boolean, issues: string[] }}
 */
export function validateSkill(content) {
  const issues = [];

  // Check 6: Frontmatter well-formed
  const parseResult = parseFrontmatter(content);
  if (parseResult.issues.length > 0) {
    return { passed: false, issues: parseResult.issues };
  }

  const fm = parseResult.fields;

  // Check 1: Required fields present
  if (!fm.name || fm.name.trim() === '') {
    issues.push('Missing required field: name');
  }
  if (!fm.description || fm.description.trim() === '') {
    issues.push('Missing required field: description');
  }

  // Check 2: Name format
  if (fm.name && !NAME_REGEX.test(fm.name)) {
    issues.push(`Name "${fm.name}" does not match pattern ^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$`);
  }

  // Check 3: No opencode fields
  for (const field of OPENCODE_FIELDS) {
    if (field in fm) {
      issues.push(`OpenCode-specific field present: ${field}`);
    }
  }

  // Check 4: runAs valid
  if ('runAs' in fm) {
    if (fm.runAs !== 'inline' && fm.runAs !== 'subagent') {
      issues.push(`Invalid runAs value "${fm.runAs}" — must be "inline" or "subagent"`);
    }
  }

  // Check 5: allowed-tools present for subagents
  if (fm.runAs === 'subagent') {
    if (!('allowed-tools' in fm)) {
      issues.push('runAs is "subagent" but allowed-tools is not defined');
    }
  }

  return { passed: issues.length === 0, issues };
}
