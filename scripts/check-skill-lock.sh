#!/bin/bash
# check-skill-lock.sh — Verify skill folder hashes against .skill-lock.json
#
# Usage: ./scripts/check-skill-lock.sh
#
# Iterates .skill-lock.json entries with sourceType "github",
# computes the git tree hash of each skill folder under skills/upstream/,
# compares against the recorded skillFolderHash, and reports PASS/FAIL.
# Replaces any "TODO-recalculated" placeholder with the actual hash.
#
# Exit 0 if all match (ALL PASS), exit 1 if any mismatch.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCKFILE="$PROJECT_ROOT/.skill-lock.json"

if [ ! -f "$LOCKFILE" ]; then
    echo "ERROR: .skill-lock.json not found at $LOCKFILE"
    exit 1
fi

export LOCKFILE="$LOCKFILE"
export PROJECT_ROOT="$PROJECT_ROOT"

python3 << 'PYEOF'
import json, os, subprocess, sys, tempfile

LOCKFILE = os.environ['LOCKFILE']
PROJECT_ROOT = os.environ['PROJECT_ROOT']

def compute_tree_hash(folder):
    """Compute the git tree hash of a directory."""
    if not os.path.isdir(folder):
        return None, f"folder not found: {folder}"
    tmp_git = tempfile.mkdtemp()
    try:
        subprocess.run(
            ['git', '--git-dir=' + tmp_git, 'init', '--quiet'],
            check=True, capture_output=True)
        subprocess.run(
            ['git', '--git-dir=' + tmp_git, '--work-tree=' + folder, 'add', '-A'],
            check=True, capture_output=True)
        result = subprocess.run(
            ['git', '--git-dir=' + tmp_git, 'write-tree'],
            check=True, capture_output=True, text=True)
        return result.stdout.strip(), None
    except subprocess.CalledProcessError as e:
        return None, f"git error: {e.stderr.decode() if e.stderr else str(e)}"
    finally:
        subprocess.run(['rm', '-rf', tmp_git], capture_output=True)

with open(LOCKFILE) as f:
    data = json.load(f)

all_pass = True
updated = False
found_github = False

for name, skill in data['skills'].items():
    source_type = skill.get('sourceType', '')
    skill_path = skill.get('skillPath', '')
    expected_hash = skill.get('skillFolderHash', '')

    # Only process github-source skills for upstream hash check
    if source_type != 'github':
        continue

    found_github = True

    if not skill_path.endswith('/SKILL.md'):
        print(f'SKIP: {name} — unexpected skillPath format: {skill_path}')
        continue

    # Derive folder path: skills/upstream/<skillPath minus /SKILL.md>
    # skillPath e.g. "skills/engineering/diagnosing-bugs/SKILL.md"
    # folder e.g. "skills/upstream/skills/engineering/diagnosing-bugs"
    folder_rel = skill_path.rsplit('/SKILL.md', 1)[0]
    folder = os.path.join(PROJECT_ROOT, 'skills', 'upstream', folder_rel)

    tree_hash, err = compute_tree_hash(folder)
    if err:
        print(f'FAIL: {name} — {err}')
        all_pass = False
        continue

    if expected_hash == 'TODO-recalculated':
        skill['skillFolderHash'] = tree_hash
        updated = True
        print(f'FIX: {name} → {tree_hash}')
        expected_hash = tree_hash

    if tree_hash == expected_hash:
        print(f'PASS: {name}')
    else:
        print(f'FAIL: {name} (computed: {tree_hash}, lockfile: {expected_hash})')
        all_pass = False

# Also handle non-github skills that have TODO-recalculated (e.g. local skills)
for name, skill in data['skills'].items():
    if skill.get('sourceType') == 'github':
        continue
    if skill.get('skillFolderHash') != 'TODO-recalculated':
        continue

    skill_path = skill.get('skillPath', '')
    if not skill_path.endswith('/SKILL.md'):
        continue
    folder_rel = skill_path.rsplit('/SKILL.md', 1)[0]
    folder = os.path.join(PROJECT_ROOT, folder_rel)

    tree_hash, err = compute_tree_hash(folder)
    if err:
        print(f'WARN: {name} — cannot compute hash: {err}')
        continue

    skill['skillFolderHash'] = tree_hash
    updated = True
    print(f'FIX: {name} → {tree_hash}')

if updated:
    with open(LOCKFILE, 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')

if not found_github:
    print('ALL PASS (no github skills found)')
    sys.exit(0)

if all_pass:
    print()
    print('ALL PASS')
    sys.exit(0)
else:
    sys.exit(1)
PYEOF
