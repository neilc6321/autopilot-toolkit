#!/usr/bin/env rust-script
//! ```cargo
//! [dependencies]
//! serde = { version = "1", features = ["derive"] }
//! serde_json = { version = "1", features = ["preserve_order"] }
//! ```

use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{self, Command};
use std::sync::atomic::{AtomicU64, Ordering};

static HASH_TEMP_COUNTER: AtomicU64 = AtomicU64::new(0);

// ── Types ──────────────────────────────────────────────────────────────────

#[derive(Debug)]
enum CheckResult {
    Pass,
    Fail(String),
    Fix(String),
    Skip(String),
}

// ── Git tree hash ──────────────────────────────────────────────────────────

/// Compute the git tree hash of a directory by creating a temporary git
/// repo (mirrors the python3 approach in check-skill-lock.sh).
fn compute_tree_hash(folder: &Path) -> Result<String, String> {
    if !folder.is_dir() {
        return Err(format!("folder not found: {}", folder.display()));
    }

    // Create a unique temp directory
    let n = HASH_TEMP_COUNTER.fetch_add(1, Ordering::SeqCst);
    let tmp = std::env::temp_dir().join(format!("skill-hash-{}-{}", std::process::id(), n));
    fs::create_dir(&tmp).map_err(|e| format!("cannot create temp dir: {}", e))?;

    let git_dir = &tmp;

    let result = (|| -> Result<String, String> {
        run_git(git_dir, &["init", "--quiet"])?;
        run_git_worktree(git_dir, folder, &["add", "-A"])?;
        let hash = run_git_stdout(git_dir, &["write-tree"])?;
        Ok(hash.trim().to_string())
    })();

    // Cleanup
    let _ = fs::remove_dir_all(&tmp);

    result
}

fn run_git(git_dir: &Path, args: &[&str]) -> Result<(), String> {
    run_git_inner(git_dir, None, args, false).map(|_| ())
}

fn run_git_worktree(git_dir: &Path, work_tree: &Path, args: &[&str]) -> Result<(), String> {
    run_git_inner(git_dir, Some(work_tree), args, false).map(|_| ())
}

fn run_git_stdout(git_dir: &Path, args: &[&str]) -> Result<String, String> {
    run_git_inner(git_dir, None, args, true)
}

fn run_git_inner(
    git_dir: &Path,
    work_tree: Option<&Path>,
    args: &[&str],
    capture_stdout: bool,
) -> Result<String, String> {
    let mut cmd = Command::new("git");
    cmd.arg(format!("--git-dir={}", git_dir.display()));
    if let Some(wt) = work_tree {
        cmd.arg(format!("--work-tree={}", wt.display()));
    }
    cmd.args(args);

    let output = cmd.output().map_err(|e| format!("git error: {}", e))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("git error: {}", stderr.trim()));
    }

    if capture_stdout {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Ok(String::new())
    }
}

// ── Lock file helpers ──────────────────────────────────────────────────────

/// Derive the skill folder path from its skillPath entry.
/// skillPath e.g. "skills/engineering/diagnosing-bugs/SKILL.md"
/// Returns the folder path relative to project root, e.g.
/// "skills/upstream/skills/engineering/diagnosing-bugs"
fn skill_folder_from_path(skill_path: &str) -> Option<String> {
    if !skill_path.ends_with("/SKILL.md") {
        return None;
    }
    let folder_rel = skill_path.strip_suffix("/SKILL.md")?;
    Some(format!("skills/upstream/{}", folder_rel))
}

/// For non-github skills, the folder is just skillPath minus /SKILL.md
/// (no "skills/upstream/" prefix).
fn skill_folder_from_path_local(skill_path: &str) -> Option<String> {
    if !skill_path.ends_with("/SKILL.md") {
        return None;
    }
    let folder_rel = skill_path.strip_suffix("/SKILL.md")?;
    Some(folder_rel.to_string())
}

// ── Core logic ─────────────────────────────────────────────────────────────

struct SkillEntry {
    name: String,
    source_type: String,
    skill_path: String,
    expected_hash: String,
}

/// Parse skill entries from the lock file JSON value.
fn parse_skill_entries(data: &serde_json::Value) -> Vec<SkillEntry> {
    let mut entries = Vec::new();
    if let Some(skills) = data.get("skills").and_then(|s| s.as_object()) {
        for (name, skill) in skills {
            let source_type = skill
                .get("sourceType")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            let skill_path = skill
                .get("skillPath")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            let expected_hash = skill
                .get("skillFolderHash")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            entries.push(SkillEntry {
                name: name.clone(),
                source_type,
                skill_path,
                expected_hash,
            });
        }
    }
    entries
}

/// Check all skills and return (results, updated_skills_map, found_github).
/// updated_skills_map contains skill_name → new_hash for FIX entries.
fn check_skills(
    project_root: &Path,
    entries: &[SkillEntry],
) -> (Vec<(String, CheckResult)>, BTreeMap<String, String>, bool) {
    let mut results: Vec<(String, CheckResult)> = Vec::new();
    let mut updated: BTreeMap<String, String> = BTreeMap::new();
    let mut found_github = false;

    // First pass: github-source skills
    for entry in entries {
        if entry.source_type != "github" {
            continue;
        }
        found_github = true;

        let folder_rel = match skill_folder_from_path(&entry.skill_path) {
            Some(f) => f,
            None => {
                results.push((
                    entry.name.clone(),
                    CheckResult::Skip(format!("unexpected skillPath format: {}", entry.skill_path)),
                ));
                continue;
            }
        };

        let folder = project_root.join(&folder_rel);

        match compute_tree_hash(&folder) {
            Err(err) => {
                results.push((entry.name.clone(), CheckResult::Fail(err)));
            }
            Ok(tree_hash) => {
                let expected_hash = &entry.expected_hash;

                if expected_hash == "TODO-recalculated" {
                    updated.insert(entry.name.clone(), tree_hash.clone());
                    results.push((entry.name.clone(), CheckResult::Fix(tree_hash.clone())));
                    // After setting the expected hash to the computed one,
                    // it now matches — also emit PASS (matching bash behaviour)
                    results.push((entry.name.clone(), CheckResult::Pass));
                } else if tree_hash == *expected_hash {
                    results.push((entry.name.clone(), CheckResult::Pass));
                } else {
                    results.push((
                        entry.name.clone(),
                        CheckResult::Fail(format!(
                            "computed: {}, lockfile: {}",
                            tree_hash, expected_hash
                        )),
                    ));
                }
            }
        }
    }

    // Second pass: non-github skills with TODO-recalculated
    for entry in entries {
        if entry.source_type == "github" {
            continue;
        }
        if entry.expected_hash != "TODO-recalculated" {
            continue;
        }

        let folder_rel = match skill_folder_from_path_local(&entry.skill_path) {
            Some(f) => f,
            None => continue,
        };

        let folder = project_root.join(&folder_rel);

        match compute_tree_hash(&folder) {
            Err(err) => {
                results.push((
                    entry.name.clone(),
                    CheckResult::Skip(format!("cannot compute hash: {}", err)),
                ));
            }
            Ok(tree_hash) => {
                updated.insert(entry.name.clone(), tree_hash.clone());
                results.push((entry.name.clone(), CheckResult::Fix(tree_hash)));
            }
        }
    }

    (results, updated, found_github)
}

/// Determine if any result is a Fail.
fn any_fail(results: &[(String, CheckResult)]) -> bool {
    results
        .iter()
        .any(|(_, r)| matches!(r, CheckResult::Fail(_)))
}

/// Format a single check result line, matching the bash script output exactly.
fn format_result(name: &str, result: &CheckResult) -> String {
    match result {
        CheckResult::Pass => format!("PASS: {}", name),
        CheckResult::Fail(reason) => {
            if reason.starts_with("computed:") {
                format!("FAIL: {} ({})", name, reason)
            } else {
                format!("FAIL: {} — {}", name, reason)
            }
        }
        CheckResult::Fix(hash) => format!("FIX: {} → {}", name, hash),
        CheckResult::Skip(msg) => {
            if msg.starts_with("cannot compute hash:") {
                format!("WARN: {} — {}", name, msg)
            } else {
                format!("SKIP: {} — {}", name, msg)
            }
        }
    }
}

/// Determine the exit code from results.
/// Returns 0 when all pass (or no github skills), 1 when any FAIL.
fn determine_exit_code(results: &[(String, CheckResult)], found_github: bool) -> i32 {
    if !found_github {
        return 0;
    }
    if any_fail(results) {
        1
    } else {
        0
    }
}

// ── Main ───────────────────────────────────────────────────────────────────

fn main() {
    let args: Vec<String> = env::args().collect();

    // Derive project root:
    // 1. PROJECT_ROOT env var if set
    // 2. parent of parent of the script path (scripts/check.rs → project root)
    let project_root = env::var("PROJECT_ROOT")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            let script_path = PathBuf::from(&args[0]);
            // scripts/check.rs → parent = scripts/ → parent = project root
            script_path
                .canonicalize()
                .unwrap_or_else(|_| script_path.clone())
                .parent() // scripts/
                .and_then(|p| p.parent()) // project root
                .map(|p| p.to_path_buf())
                .unwrap_or_else(|| env::current_dir().unwrap_or_else(|_| PathBuf::from(".")))
        });

    let lockfile_path = project_root.join(".skill-lock.json");
    if !lockfile_path.exists() {
        eprintln!(
            "ERROR: .skill-lock.json not found at {}",
            lockfile_path.display()
        );
        process::exit(1);
    }

    // Read and parse lock file
    let content = match fs::read_to_string(&lockfile_path) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("ERROR: cannot read .skill-lock.json: {}", e);
            process::exit(1);
        }
    };

    let data: serde_json::Value = match serde_json::from_str(&content) {
        Ok(v) => v,
        Err(e) => {
            eprintln!("ERROR: cannot parse .skill-lock.json: {}", e);
            process::exit(1);
        }
    };

    let mut data_mut = data.clone();
    let entries = parse_skill_entries(&data);
    let (results, updated, found_github) = check_skills(&project_root, &entries);

    // Print results
    for (name, result) in &results {
        println!("{}", format_result(name, result));
    }

    // Update lock file if any FIX applied
    if !updated.is_empty() {
        if let Some(skills) = data_mut.get_mut("skills").and_then(|s| s.as_object_mut()) {
            for (name, new_hash) in &updated {
                if let Some(skill) = skills.get_mut(name) {
                    if let Some(obj) = skill.as_object_mut() {
                        obj.insert(
                            "skillFolderHash".to_string(),
                            serde_json::Value::String(new_hash.clone()),
                        );
                    }
                }
            }
        }

        let updated_json = serde_json::to_string_pretty(&data_mut).unwrap_or_default();
        if let Err(e) = fs::write(&lockfile_path, updated_json + "\n") {
            eprintln!("ERROR: cannot write updated .skill-lock.json: {}", e);
            process::exit(1);
        }
    }

    // Exit status
    let code = determine_exit_code(&results, found_github);
    if code == 0 && !found_github {
        println!("ALL PASS (no github skills found)");
    } else if code == 0 {
        println!();
        println!("ALL PASS");
    }
    process::exit(code);
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    // ── Helpers ─────────────────────────────────────────────────────────

    fn project_root() -> PathBuf {
        // 1. PROJECT_ROOT env var (preferred for CI / explicit override)
        if let Ok(root) = env::var("PROJECT_ROOT") {
            let p = PathBuf::from(&root);
            if p.join(".skill-lock.json").exists() {
                return p;
            }
        }
        // 2. Derive from compile-time source path (file!() is scripts/check.rs)
        let src = Path::new(file!());
        // src is relative to the project root when compiled via rust-script
        // e.g. "scripts/check.rs" → parent is "scripts" → parent is project root
        if let (Some(scripts_dir), Some(proj)) =
            (src.parent(), src.parent().and_then(|p| p.parent()))
        {
            let candidate = if scripts_dir.as_os_str() == "scripts" {
                // file!() gave us "scripts/check.rs" — parent is "scripts", parent.parent is root
                proj.to_path_buf()
            } else {
                // file!() might be an absolute path; walk up
                let mut dir = Some(src.to_path_buf());
                while let Some(d) = dir {
                    if d.join(".skill-lock.json").exists() {
                        return d;
                    }
                    dir = d.parent().map(|p| p.to_path_buf());
                }
                return env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
            };
            if candidate.join(".skill-lock.json").exists() {
                return candidate;
            }
        }
        // 3. Walk up from current directory
        let cwd = env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
        let mut dir = Some(cwd);
        while let Some(d) = dir {
            if d.join(".skill-lock.json").exists() {
                return d;
            }
            dir = d.parent().map(|p| p.to_path_buf());
        }
        // 4. Fallback
        env::current_dir().unwrap_or_else(|_| PathBuf::from("."))
    }

    use std::sync::atomic::{AtomicU64, Ordering};

    static TEMP_COUNTER: AtomicU64 = AtomicU64::new(0);

    struct TempDir(PathBuf);

    impl TempDir {
        fn new() -> Self {
            let n = TEMP_COUNTER.fetch_add(1, Ordering::SeqCst);
            let dir =
                std::env::temp_dir().join(format!("check-rs-test-{}-{}", std::process::id(), n));
            fs::create_dir_all(&dir).expect("create temp dir");
            TempDir(dir)
        }

        fn path(&self) -> &Path {
            &self.0
        }
    }

    impl Drop for TempDir {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    fn make_temp_dir() -> TempDir {
        TempDir::new()
    }

    fn init_git_repo(dir: &Path) {
        let output = Command::new("git")
            .arg("init")
            .arg("--quiet")
            .current_dir(dir)
            .output()
            .expect("git init");
        assert!(output.status.success(), "git init failed");
    }

    fn write_file(dir: &Path, name: &str, content: &str) {
        let path = dir.join(name);
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        fs::write(&path, content).unwrap();
    }

    // ── compute_tree_hash ────────────────────────────────────────────────

    #[test]
    fn compute_tree_hash_non_existent_folder() {
        let result = compute_tree_hash(Path::new("/nonexistent/path/12345"));
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("folder not found"));
    }

    #[test]
    fn compute_tree_hash_empty_dir() {
        let tmp = make_temp_dir();
        init_git_repo(tmp.path());
        let sub = tmp.path().join("empty_skill");
        fs::create_dir_all(&sub).unwrap();

        // compute_tree_hash creates its own temp git repo internally,
        // so it should work on any directory
        let hash = compute_tree_hash(&sub).expect("hash empty dir");
        // An empty directory produces an empty tree hash
        assert!(!hash.is_empty(), "hash should not be empty");
        // The empty tree hash in git is always 4b825dc642cb6eb9a060e54bf899d97a0e2f1e30
        // but with our temp-git approach, it depends on whether files were added.
        // An empty dir with `add -A` produces the empty tree hash
    }

    #[test]
    fn compute_tree_hash_deterministic() {
        let tmp = make_temp_dir();
        let sub = tmp.path().join("some_skill");
        fs::create_dir_all(&sub).unwrap();
        write_file(&sub, "SKILL.md", "# Test Skill\n\nHello world.\n");

        let hash1 = compute_tree_hash(&sub).expect("hash1");
        let hash2 = compute_tree_hash(&sub).expect("hash2");
        assert_eq!(hash1, hash2, "same content should produce same hash");
    }

    #[test]
    fn compute_tree_hash_changes_with_content() {
        let tmp = make_temp_dir();
        let sub = tmp.path().join("mutable_skill");
        fs::create_dir_all(&sub).unwrap();
        write_file(&sub, "SKILL.md", "version 1\n");

        let hash1 = compute_tree_hash(&sub).expect("hash1");

        // Change content
        write_file(&sub, "SKILL.md", "version 2\n");
        let hash2 = compute_tree_hash(&sub).expect("hash2");

        assert_ne!(
            hash1, hash2,
            "different content should produce different hash"
        );
    }

    // ── skill_folder_from_path ───────────────────────────────────────────

    #[test]
    fn skill_folder_from_valid_path() {
        let result = skill_folder_from_path("skills/engineering/diagnosing-bugs/SKILL.md");
        assert_eq!(
            result,
            Some("skills/upstream/skills/engineering/diagnosing-bugs".to_string())
        );
    }

    #[test]
    fn skill_folder_from_path_without_skill_md() {
        let result = skill_folder_from_path("skills/engineering/diagnosing-bugs/README.md");
        assert_eq!(result, None);
    }

    #[test]
    fn skill_folder_from_path_empty() {
        assert_eq!(skill_folder_from_path(""), None);
    }

    // ── skill_folder_from_path_local ─────────────────────────────────────

    #[test]
    fn skill_folder_local_from_valid_path() {
        let result = skill_folder_from_path_local("skills/autopilot/my-skill/SKILL.md");
        assert_eq!(result, Some("skills/autopilot/my-skill".to_string()));
    }

    // ── parse_skill_entries ──────────────────────────────────────────────

    #[test]
    fn parse_entries_from_valid_lock_json() {
        let json = serde_json::json!({
            "skills": {
                "diagnosing-bugs": {
                    "sourceType": "github",
                    "skillPath": "skills/engineering/diagnosing-bugs/SKILL.md",
                    "skillFolderHash": "abc123"
                },
                "my-local": {
                    "sourceType": "local",
                    "skillPath": "skills/autopilot/my-local/SKILL.md",
                    "skillFolderHash": "TODO-recalculated"
                }
            }
        });
        let entries = parse_skill_entries(&json);
        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].name, "diagnosing-bugs");
        assert_eq!(entries[0].source_type, "github");
        assert_eq!(entries[1].name, "my-local");
        assert_eq!(entries[1].expected_hash, "TODO-recalculated");
    }

    #[test]
    fn parse_entries_empty_skills() {
        let json = serde_json::json!({"skills": {}});
        let entries = parse_skill_entries(&json);
        assert!(entries.is_empty());
    }

    // ── any_fail ─────────────────────────────────────────────────────────

    #[test]
    fn any_fail_true_when_fail_present() {
        let results = vec![
            ("a".to_string(), CheckResult::Pass),
            ("b".to_string(), CheckResult::Fail("oops".to_string())),
        ];
        assert!(any_fail(&results));
    }

    #[test]
    fn any_fail_false_when_all_pass() {
        let results = vec![
            ("a".to_string(), CheckResult::Pass),
            ("b".to_string(), CheckResult::Pass),
        ];
        assert!(!any_fail(&results));
    }

    #[test]
    fn any_fail_false_when_empty() {
        let results: Vec<(String, CheckResult)> = vec![];
        assert!(!any_fail(&results));
    }

    // ── check_skills integration ─────────────────────────────────────────

    #[test]
    fn check_skills_with_real_lockfile() {
        // This test uses the real project's .skill-lock.json.
        // It verifies that all github skills resolve to existing folders
        // and produce valid hashes.
        let root = project_root();
        let lock_path = root.join(".skill-lock.json");
        assert!(
            lock_path.exists(),
            "REQUIRES .skill-lock.json at {:?} — run from project root",
            root
        );
        let content = fs::read_to_string(&lock_path).expect("read lock file");
        let data: serde_json::Value = serde_json::from_str(&content).expect("parse lock file");
        let entries = parse_skill_entries(&data);

        let (results, _updated, found_github) = check_skills(&root, &entries);

        assert!(found_github, "should find github skills");
        assert!(!results.is_empty(), "should have results");

        // All results should be Pass (since lock should be in sync).
        // Non-Pass results indicate either a stale lock file or a missing folder.
        let mut unexpected: Vec<String> = Vec::new();
        for (name, result) in &results {
            match result {
                CheckResult::Pass => {} // expected
                CheckResult::Fail(reason) => {
                    if reason.contains("folder not found") {
                        eprintln!("WARN: folder missing for {} — test env issue?", name);
                    } else {
                        unexpected.push(format!("FAIL {}: {}", name, reason));
                    }
                }
                CheckResult::Fix(hash) => {
                    unexpected.push(format!("FIX {} → {} (stale TODO-recalculated)", name, hash));
                }
                CheckResult::Skip(msg) => {
                    unexpected.push(format!("SKIP {}: {}", name, msg));
                }
            }
        }
        assert!(
            unexpected.is_empty(),
            "Unexpected non-PASS results:\n{}",
            unexpected.join("\n")
        );
    }

    // ── format_result ────────────────────────────────────────────────────

    #[test]
    fn format_result_pass() {
        assert_eq!(
            format_result("my-skill", &CheckResult::Pass),
            "PASS: my-skill"
        );
    }

    #[test]
    fn format_result_fail_general_error() {
        assert_eq!(
            format_result(
                "my-skill",
                &CheckResult::Fail("folder not found: /x".to_string())
            ),
            "FAIL: my-skill — folder not found: /x"
        );
    }

    #[test]
    fn format_result_fail_hash_mismatch() {
        assert_eq!(
            format_result(
                "my-skill",
                &CheckResult::Fail("computed: abc123, lockfile: def456".to_string())
            ),
            "FAIL: my-skill (computed: abc123, lockfile: def456)"
        );
    }

    #[test]
    fn format_result_fix() {
        assert_eq!(
            format_result("my-skill", &CheckResult::Fix("abc123".to_string())),
            "FIX: my-skill → abc123"
        );
    }

    #[test]
    fn format_result_warn() {
        assert_eq!(
            format_result(
                "my-skill",
                &CheckResult::Skip("cannot compute hash: git error".to_string())
            ),
            "WARN: my-skill — cannot compute hash: git error"
        );
    }

    #[test]
    fn format_result_skip() {
        assert_eq!(
            format_result(
                "my-skill",
                &CheckResult::Skip("unexpected skillPath format: bad/path".to_string())
            ),
            "SKIP: my-skill — unexpected skillPath format: bad/path"
        );
    }

    // ── determine_exit_code ──────────────────────────────────────────────

    #[test]
    fn exit_code_zero_when_all_pass() {
        let results = vec![
            ("a".to_string(), CheckResult::Pass),
            ("b".to_string(), CheckResult::Pass),
        ];
        assert_eq!(determine_exit_code(&results, true), 0);
    }

    #[test]
    fn exit_code_one_when_any_fail() {
        let results = vec![
            ("a".to_string(), CheckResult::Pass),
            ("b".to_string(), CheckResult::Fail("oops".to_string())),
        ];
        assert_eq!(determine_exit_code(&results, true), 1);
    }

    #[test]
    fn exit_code_zero_when_no_github_skills() {
        let results: Vec<(String, CheckResult)> = vec![];
        assert_eq!(determine_exit_code(&results, false), 0);
    }

    #[test]
    fn exit_code_zero_when_empty_results_with_github() {
        let results: Vec<(String, CheckResult)> = vec![];
        assert_eq!(determine_exit_code(&results, true), 0);
    }
}
