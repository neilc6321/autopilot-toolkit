#!/usr/bin/env rust-script
//! ```cargo
//! [dependencies]
//! serde = { version = "1", features = ["derive"] }
//! serde_json = "1"
//! anyhow = "1"
//! ```

use serde::Serialize;
use std::collections::BTreeMap;
use std::process::Command;
use anyhow::Context;
use std::env;
use std::os::unix::fs::symlink;
use std::path::{Path, PathBuf};

fn warn(msg: &str) {
    eprintln!("WARNING: {}", msg);
}

fn usage() -> ! {
    println!(
        "Usage: deploy.rs <subcommand> [args...] [--target reasonix|codex] [--shared] [--agent] (for pack only)"
    );
    println!();
    println!("Subcommands:");
    println!("  dev                     Symlink all skills from source tree into agent dirs");
    println!("  pack                    Build a self-contained tarball into dist/");
    println!("  release                 Pack + push to GitHub Releases");
    println!("  dev-clean               Remove all dev symlinks from agent dirs");
    println!("  link-principles <src>   Ensure ~/.agents/principles is a symlink to <src>");
    std::process::exit(1);
}

/// Parse flags (--target, --shared, --agent) from the positional args tail.
/// Returns (positional_args, target_value, shared_flag, agent_flag).
fn parse_flags(args: &[String]) -> (Vec<&str>, Option<String>, bool, bool) {
    let mut positional: Vec<&str> = Vec::new();
    let mut target: Option<String> = None;
    let mut shared = false;
    let mut agent = false;

    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--target" => {
                i += 1;
                if i < args.len() {
                    target = Some(args[i].clone());
                } else {
                    eprintln!("ERROR: --target requires a value (reasonix or codex)");
                    usage();
                }
            }
            "--shared" => {
                shared = true;
            }
            "--agent" => {
                agent = true;
            }
            other => {
                positional.push(other);
            }
        }
        i += 1;
    }

    (positional, target, shared, agent)
}

fn sync_skill(name: &str, src: &Path, skills_dir: &Path) -> Result<(), anyhow::Error> {
    let target = skills_dir.join(name);

    // Ensure the skills directory exists
    std::fs::create_dir_all(skills_dir)
        .with_context(|| format!("cannot create directory {}", skills_dir.display()))?;

    // If target exists as a real file/directory (not a symlink), refuse to overwrite
    if target.exists() && !target.is_symlink() {
        warn(&format!(
            "{} exists as a real directory (not a symlink) — refusing to overwrite",
            target.display()
        ));
        anyhow::bail!("real directory conflict at {}", target.display());
    }

    // If target is a symlink, inspect its current state
    if target.is_symlink() {
        let existing = std::fs::read_link(&target)
            .with_context(|| format!("cannot read symlink {}", target.display()))?;

        // Valid symlink pointing to the correct source — nothing to do
        if existing == src && src.is_dir() {
            return Ok(());
        }

        // Broken or pointing to the wrong target — remove it before rebuilding
        std::fs::remove_file(&target)
            .with_context(|| format!("cannot remove symlink {}", target.display()))?;
    }

    // Source directory must exist
    if !src.is_dir() {
        warn(&format!(
            "source directory does not exist: {}",
            src.display()
        ));
        return Ok(());
    }

    // Create the symlink
    symlink(src, &target).with_context(|| {
        format!(
            "cannot create symlink {} -> {}",
            target.display(),
            src.display()
        )
    })?;

    Ok(())
}


fn link_principles(src: &Path, principles_dir: &Path) -> Result<(), anyhow::Error> {
    let target = principles_dir;

    // If target exists as a real file/directory (not a symlink), refuse to overwrite
    if target.exists() && !target.is_symlink() {
        warn(&format!(
            "{} exists as a real directory (not a symlink) — refusing to overwrite",
            target.display()
        ));
        anyhow::bail!("real directory conflict at {}", target.display());
    }

    // If target is a symlink, inspect its current state
    if target.is_symlink() {
        let existing = std::fs::read_link(target)
            .with_context(|| format!("cannot read symlink {}", target.display()))?;

        // Valid symlink pointing to the correct source — nothing to do
        if existing == src && src.is_dir() {
            return Ok(());
        }

        // Broken or pointing to the wrong target — remove it before rebuilding
        std::fs::remove_file(target)
            .with_context(|| format!("cannot remove symlink {}", target.display()))?;
    }

    // Source directory must exist
    if !src.is_dir() {
        warn(&format!(
            "source directory does not exist: {}",
            src.display()
        ));
        return Ok(());
    }

    // Ensure parent directory exists (e.g. ~/.agents/)
    if let Some(parent) = target.parent() {
        std::fs::create_dir_all(parent)
            .with_context(|| format!("cannot create directory {}", parent.display()))?;
    }

    // Create the symlink
    symlink(src, target).with_context(|| {
        format!(
            "cannot create symlink {} -> {}",
            target.display(),
            src.display()
        )
    })?;

    Ok(())
}

fn sync_agent(name: &str, src: &Path, codex_agents_dir: &Path) -> Result<(), anyhow::Error> {
    // Source file must exist
    if !src.is_file() {
        anyhow::bail!("agent source file does not exist: {}", src.display());
    }

    // Ensure agents directory exists
    std::fs::create_dir_all(codex_agents_dir)
        .with_context(|| format!("cannot create directory {}", codex_agents_dir.display()))?;

    let target = codex_agents_dir.join(format!("{}.toml", name));

    // If target exists as a real file (not a symlink), refuse to overwrite
    if target.exists() && !target.is_symlink() {
        warn(&format!(
            "{} exists as a real file (not a symlink) — refusing to overwrite",
            target.display()
        ));
        anyhow::bail!("real file conflict at {}", target.display());
    }

    // If target is a symlink, inspect its current state
    if target.is_symlink() {
        let existing = std::fs::read_link(&target)
            .with_context(|| format!("cannot read symlink {}", target.display()))?;

        // Valid symlink pointing to the correct source — nothing to do
        if existing == src && src.is_file() {
            return Ok(());
        }

        // Broken or pointing to the wrong target — remove it before rebuilding
        std::fs::remove_file(&target)
            .with_context(|| format!("cannot remove symlink {}", target.display()))?;
    }

    // Create the file symlink
    symlink(src, &target).with_context(|| {
        format!(
            "cannot create symlink {} -> {}",
            target.display(),
            src.display()
        )
    })?;

    Ok(())
}

// ── Build ────────────────────────────────────────────────────────────────

#[derive(Serialize)]
struct ManifestSkill {
    #[serde(rename = "type")]
    skill_type: String,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    variants: Vec<String>,
    #[serde(default)]
    codex_agent: bool,
}

#[derive(Serialize)]
struct Manifest {
    version: String,
    skills: BTreeMap<String, ManifestSkill>,
}

fn get_version(project_root: &Path) -> Result<String, anyhow::Error> {
    let output = Command::new("git")
        .args(&["-C", &project_root.to_string_lossy(), "rev-parse", "HEAD"])
        .output()
        .context("git rev-parse HEAD failed — are you in a git repository?")?;
    if !output.status.success() {
        anyhow::bail!("git rev-parse HEAD exited with error");
    }
    Ok(String::from_utf8(output.stdout)
        .context("git output not valid UTF-8")?
        .trim()
        .to_string())
}

fn pack_command(project_root: &Path) -> Result<(), anyhow::Error> {
    let version = get_version(project_root)?;
    let dist_dir = project_root.join("dist");
    std::fs::create_dir_all(&dist_dir)
        .with_context(|| format!("cannot create dist directory {}", dist_dir.display()))?;

    // Create staging directory for tarball contents
    let staging = dist_dir.join("staging");
    if staging.exists() {
        std::fs::remove_dir_all(&staging)?;
    }
    std::fs::create_dir_all(&staging)?;

    let skills_staging = staging.join("skills");
    std::fs::create_dir_all(&skills_staging)?;

    let autopilot_staging = staging.join(".autopilot");
    std::fs::create_dir_all(&autopilot_staging)?;

    let mut manifest = Manifest {
        version: version.clone(),
        skills: BTreeMap::new(),
    };

    // ── scan autopilot skills ──
    let autopilot_dir = project_root.join("skills").join("autopilot");
    if autopilot_dir.is_dir() {
        for entry in std::fs::read_dir(&autopilot_dir)? {
            let entry = entry?;
            if !entry.file_type()?.is_dir() {
                continue;
            }
            let skill_name = entry.file_name();
            let skill_name_str = skill_name.to_string_lossy().to_string();
            let src_dir = entry.path();

            // Determine type: agnostic (just SKILL.md) vs coupled (variant subdirs)
            let has_variants = has_variant_dirs(&src_dir);

            if has_variants {
                let variants = list_variants(&src_dir);
                let codex_agent = src_dir.join("codex").join("agent.toml").is_file();
                manifest.skills.insert(skill_name_str.clone(), ManifestSkill {
                    skill_type: "coupled".to_string(),
                    variants,
                    codex_agent,
                });
            } else {
                manifest.skills.insert(skill_name_str.clone(), ManifestSkill {
                    skill_type: "agnostic".to_string(),
                    variants: vec![],
                    codex_agent: false,
                });
            }

            // Copy skill directory into staging
            copy_dir_all(&src_dir, &skills_staging.join(&skill_name_str))?;
        }
    }

    // ── scan upstream skills from .skill-lock.json ──
    let lock_path = project_root.join(".skill-lock.json");
    if lock_path.is_file() {
        let lock_bytes = std::fs::read_to_string(&lock_path)?;
        let lock: serde_json::Value = serde_json::from_str(&lock_bytes)
            .context("failed to parse .skill-lock.json")?;

        if let Some(skills_map) = lock.get("skills").and_then(|s| s.as_object()) {
            for (skill_name, skill_entry) in skills_map {
                // Extract skillPath to locate the source directory
                if let Some(skill_path) = skill_entry.get("skillPath").and_then(|s| s.as_str()) {
                    // skillPath is like "skills/engineering/diagnosing-bugs/SKILL.md"
                    // The source dir is the parent of SKILL.md, relative to skills/upstream/
                    let src_parent = Path::new(skill_path).parent().unwrap_or(Path::new(""));
                    let src_dir = project_root.join("skills").join("upstream").join(src_parent);

                    if src_dir.is_dir() {
                        // Copy upstream skill dir (flat name) into staging
                        copy_dir_all(&src_dir, &skills_staging.join(skill_name))?;
                        manifest.skills.insert(skill_name.clone(), ManifestSkill {
                            skill_type: "upstream".to_string(),
                            variants: vec![],
                            codex_agent: false,
                        });
                    } else {
                        eprintln!("WARNING: upstream skill '{}' source dir missing ({}), skipping", skill_name, src_dir.display());
                    }
                }
            }
        }
    }

    // ── write manifest.json ──
    let manifest_json = serde_json::to_string_pretty(&manifest)?;
    std::fs::write(autopilot_staging.join("manifest.json"), &manifest_json)?;

    // ── write .version ──
    std::fs::write(autopilot_staging.join(".version"), &version)?;

    // ── copy .skill-lock.json ──
    if lock_path.is_file() {
        std::fs::copy(&lock_path, autopilot_staging.join(".skill-lock.json"))?;
    }

    // ── generate install.sh from template ──
    let template_path = project_root.join("templates").join("install.sh.in");
    let template_content = std::fs::read_to_string(&template_path)
        .with_context(|| format!("template not found at {}", template_path.display()))?;
    let install_content = template_content.replace("__VERSION__", &version);
    let install_dest = autopilot_staging.join("install.sh");
    std::fs::write(&install_dest, &install_content)?;
    // Make executable
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = std::fs::metadata(&install_dest)?.permissions();
        perms.set_mode(0o755);
        std::fs::set_permissions(&install_dest, perms)?;
    }

    // ── copy bootstrap.sh ──
    let bootstrap_src = project_root.join("bootstrap.sh");
    if bootstrap_src.is_file() {
        std::fs::copy(&bootstrap_src, autopilot_staging.join("bootstrap.sh"))?;
        // Ensure executable
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = std::fs::metadata(autopilot_staging.join("bootstrap.sh"))?.permissions();
            perms.set_mode(0o755);
            std::fs::set_permissions(autopilot_staging.join("bootstrap.sh"), perms)?;
        }
    }

    // ── copy principles/ ──
    let principles_src = project_root.join("principles");
    if principles_src.is_dir() {
        copy_dir_all(&principles_src, &staging.join("principles"))?;
    }

    // ── create tarball ──
    let tarball_name = format!("autopilot-toolkit-{}.tar.gz", version);
    let tarball_path = dist_dir.join(&tarball_name);

    let status = Command::new("tar")
        .args(&["-czf", &tarball_path.to_string_lossy(), "-C", &staging.to_string_lossy(), "."])
        .status()
        .context("tar command failed — is tar installed?")?;

    if !status.success() {
        anyhow::bail!("tar exited with error");
    }

    // Also save install.sh as standalone file in dist/ for curl | bash
    let install_sh_path = dist_dir.join("install.sh");
    std::fs::write(&install_sh_path, &install_content)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = std::fs::metadata(&install_sh_path)?.permissions();
        perms.set_mode(0o755);
        std::fs::set_permissions(&install_sh_path, perms)?;
    }

    // Clean up staging
    std::fs::remove_dir_all(&staging)?;

    println!("Built: {}", tarball_path.display());
    println!("Install script: {}", install_sh_path.display());
    Ok(())
}

fn has_variant_dirs(dir: &Path) -> bool {
    for variant in &["codex", "kimi", "reasonix"] {
        if dir.join(variant).is_dir() {
            return true;
        }
    }
    false
}

fn list_variants(dir: &Path) -> Vec<String> {
    let mut variants = Vec::new();
    for variant in &["codex", "kimi", "reasonix"] {
        if dir.join(variant).is_dir() {
            variants.push(variant.to_string());
        }
    }
    variants
}

fn copy_dir_all(src: &Path, dst: &Path) -> Result<(), anyhow::Error> {
    std::fs::create_dir_all(dst)?;
    for entry in std::fs::read_dir(src)? {
        let entry = entry?;
        let ty = entry.file_type()?;
        let dest = dst.join(entry.file_name());
        if ty.is_dir() {
            copy_dir_all(&entry.path(), &dest)?;
        } else {
            std::fs::copy(entry.path(), &dest)?;
        }
    }
    Ok(())
}

fn dev_all(
    project_root: &Path,
    shared_skills_dir: &Path,
    reasonix_skills_dir: &Path,
    codex_skills_dir: &Path,
    codex_agents_dir: &Path,
) -> Result<(), anyhow::Error> {
    println!("==> Syncing all skills from source tree...");

    // ── Autopilot skills ──
    let autopilot_dir = project_root.join("skills").join("autopilot");
    let mut count = 0u32;
    if autopilot_dir.is_dir() {
        for entry in std::fs::read_dir(&autopilot_dir)? {
            let entry = entry?;
            if !entry.file_type()?.is_dir() {
                continue;
            }
            let name = entry.file_name().to_string_lossy().to_string();
            let src_dir = entry.path();

            if has_variant_dirs(&src_dir) {
                // Coupled skill: symlink variant for each detected runtime
                let variants = list_variants(&src_dir);
                for variant in &variants {
                    let target_dir = match variant.as_str() {
                        "reasonix" => reasonix_skills_dir,
                        "codex" => codex_skills_dir,
                        "kimi" => shared_skills_dir,
                        _ => continue,
                    };
                    // Only symlink if the runtime directory exists on this machine
                    let runtime_home = match variant.as_str() {
                        "reasonix" => std::env::var("HOME").ok().map(|h| PathBuf::from(h).join(".reasonix")),
                        "codex" => std::env::var("HOME").ok().map(|h| PathBuf::from(h).join(".codex")),
                        "kimi" => Some(PathBuf::from("/")), // always assume kimi
                        _ => None,
                    };
                    if let Some(ref home) = runtime_home {
                        if !home.exists() && variant.as_str() != "kimi" {
                            continue;
                        }
                    }
                    let variant_src = src_dir.join(variant);
                    if variant_src.is_dir() {
                        sync_skill(&name, &variant_src, target_dir)?;
                        count += 1;
                    }
                }
                // Codex agent.toml
                let agent_src = src_dir.join("codex").join("agent.toml");
                if agent_src.is_file() {
                    sync_agent(&name, &agent_src, codex_agents_dir)?;
                    count += 1;
                }
            } else {
                // Agnostic skill
                sync_skill(&name, &src_dir, shared_skills_dir)?;
                count += 1;
            }
        }
    }

    // ── Upstream skills ──
    let lock_path = project_root.join(".skill-lock.json");
    if lock_path.is_file() {
        let lock_bytes = std::fs::read_to_string(&lock_path)?;
        let lock: serde_json::Value = serde_json::from_str(&lock_bytes)
            .context("failed to parse .skill-lock.json")?;
        if let Some(skills_map) = lock.get("skills").and_then(|s| s.as_object()) {
            for (skill_name, skill_entry) in skills_map {
                if let Some(skill_path) = skill_entry.get("skillPath").and_then(|s| s.as_str()) {
                    let src_parent = Path::new(skill_path).parent().unwrap_or(Path::new(""));
                    let src_dir = project_root.join("skills").join("upstream").join(src_parent);
                    if src_dir.is_dir() {
                        sync_skill(skill_name, &src_dir, shared_skills_dir)?;
                        count += 1;
                    } else {
                        eprintln!("WARNING: upstream skill '{}' source dir missing, skipping", skill_name);
                    }
                }
            }
        }
    }

    println!("==> Done: {} symlinks created/verified.", count);
    Ok(())
}

fn dev_clean(
    project_root: &Path,
    shared_skills_dir: &Path,
    reasonix_skills_dir: &Path,
    codex_skills_dir: &Path,
    codex_agents_dir: &Path,
) -> Result<(), anyhow::Error> {
    println!("==> Removing all dev symlinks...");
    let mut removed = 0u32;

    for dir in &[shared_skills_dir, reasonix_skills_dir, codex_skills_dir] {
        if !dir.is_dir() {
            continue;
        }
        for entry in std::fs::read_dir(dir)? {
            let entry = entry?;
            let path = entry.path();
            if !path.is_symlink() {
                continue;
            }
            if let Ok(target) = std::fs::read_link(&path) {
                if target.starts_with(project_root) {
                    std::fs::remove_file(&path)?;
                    removed += 1;
                }
            }
        }
    }

    // Codex agents
    if codex_agents_dir.is_dir() {
        for entry in std::fs::read_dir(codex_agents_dir)? {
            let entry = entry?;
            let path = entry.path();
            if !path.is_symlink() {
                continue;
            }
            if let Ok(target) = std::fs::read_link(&path) {
                if target.starts_with(project_root) {
                    std::fs::remove_file(&path)?;
                    removed += 1;
                }
            }
        }
    }

    println!("==> Done: {} symlinks removed.", removed);
    Ok(())
}


fn release_command(project_root: &Path) -> Result<(), anyhow::Error> {
    // Check gh is available
    let gh_check = Command::new("which").arg("gh").output();
    if gh_check.is_err() || !gh_check.unwrap().status.success() {
        anyhow::bail!("gh CLI not found — install it from https://cli.github.com");
    }

    // Must be on a tag
    let tag = String::from_utf8(
        Command::new("git")
            .args(&["describe", "--tags", "--exact-match"])
            .current_dir(project_root)
            .output()
            .context("git describe failed")?
            .stdout,
    )
    .context("invalid UTF-8 from git describe")?
    .trim()
    .to_string();

    if tag.is_empty() {
        anyhow::bail!("not on a git tag — create and push a tag first, e.g.: git tag v1.0.0 && git push origin v1.0.0");
    }

    println!("==> Releasing {}", tag);

    // Build the tarball
    pack_command(project_root)?;

    let dist_dir = project_root.join("dist");
    let tarball = dist_dir.join(format!("autopilot-toolkit-{}.tar.gz", tag));
    let install_script = dist_dir.join("install.sh");

    if !tarball.is_file() {
        anyhow::bail!("tarball not found at {}", tarball.display());
    }

    // Create GitHub Release and upload assets
    let status = Command::new("gh")
        .args(&[
            "release", "create", &tag,
            tarball.to_str().unwrap(),
            install_script.to_str().unwrap(),
            "--title", &format!("autopilot-toolkit {}", tag),
            "--notes", &format!("autopilot-toolkit {} release.", tag),
        ])
        .current_dir(project_root)
        .status()
        .context("gh release create failed")?;

    if !status.success() {
        anyhow::bail!("gh release create exited with error");
    }

    println!("==> Released {} to GitHub", tag);
    println!("   Install: curl -sSL https://github.com/neilc6321/autopilot-toolkit/releases/download/{}/install.sh | bash", tag);
    Ok(())
}


fn main() -> anyhow::Result<()> {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        usage();
    }

    // Derive PROJECT_ROOT from script path (equivalent to bash's $(cd "$(dirname "$0")" && pwd))
    let script_path = PathBuf::from(&args[0]);
    let project_root = env::var("PROJECT_ROOT")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            script_path
                .canonicalize()
                .unwrap_or_else(|_| script_path.clone())
                .parent()
                .unwrap_or(Path::new("."))
                .to_path_buf()
        });

    let home = env::var("HOME").unwrap_or_default();

    // Skills directories (with env var overrides)
    let reasonix_skills_dir = env::var("REASONIX_SKILLS_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(&home).join(".reasonix/skills"));
    let codex_skills_dir = env::var("CODEX_SKILLS_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(&home).join(".codex/skills"));
    let shared_skills_dir = env::var("AGENTS_SKILLS_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(&home).join(".agents/skills"));

    let principles_dir = env::var("AGENTS_PRINCIPLES_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(&home).join(".agents/principles"));

    let codex_agents_dir = env::var("CODEX_AGENTS_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(&home).join(".codex/agents"));

    let subcommand = &args[1];
    let rest = &args[2..];

    // Parse flags from the positional tail
    let (positional, target_flag, shared_flag, agent_flag) = parse_flags(rest);

    match subcommand.as_str() {
        "pack" => {
            if target_flag.is_some() || shared_flag || agent_flag {
                eprintln!("ERROR: pack does not accept --target, --shared, or --agent flags");
                usage();
            }
            if !positional.is_empty() {
                warn(&format!("ignoring extra arguments: {:?}", positional));
            }
            pack_command(&project_root)?;
        }
        "release" => {
            if !positional.is_empty() {
                warn(&format!("ignoring extra arguments: {:?}", positional));
            }
            release_command(&project_root)?;
        }
        "dev" => {
            if !positional.is_empty() {
                warn(&format!("ignoring extra arguments: {:?}", positional));
            }
            dev_all(&project_root, &shared_skills_dir, &reasonix_skills_dir, &codex_skills_dir, &codex_agents_dir)?;
        }
        "dev-clean" => {
            if !positional.is_empty() {
                warn(&format!("ignoring extra arguments: {:?}", positional));
            }
            dev_clean(&project_root, &shared_skills_dir, &reasonix_skills_dir, &codex_skills_dir, &codex_agents_dir)?;
        }
        "link-principles" => {
            if positional.len() != 1 {
                eprintln!(
                    "ERROR: link-principles requires exactly one argument (<src>), but received {}",
                    positional.len()
                );
                usage();
            }
            let src = PathBuf::from(positional[0]);
            link_principles(&src, &principles_dir)?;
        }
        _ => {
            eprintln!(
                "ERROR: unknown subcommand '{}'. Available: dev, dev-clean, pack, release, link-principles",
                subcommand
            );
            usage();
        }
    }

    Ok(())
}
