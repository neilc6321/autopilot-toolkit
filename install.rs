#!/usr/bin/env rust-script
//! ```cargo
//! [dependencies]
//! anyhow = "1"
//! ```

use anyhow::Context;
use std::env;
use std::os::unix::fs::symlink;
use std::path::{Path, PathBuf};

fn warn(msg: &str) {
    eprintln!("WARNING: {}", msg);
}

fn usage() -> ! {
    println!("Usage: install.rs <subcommand> [args...]");
    println!();
    println!("Subcommands:");
    println!("  sync <name> <src>       Ensure ~/.agents/skills/<name> is a symlink to <src>");
    println!("  unlink <name>           Remove a toolkit-owned symlink from ~/.agents/skills/");
    println!("  link-principles <src>   Ensure ~/.agents/principles is a symlink to <src>");
    std::process::exit(1);
}

fn sync_skill(name: &str, src: &Path, skills_dir: &Path) -> Result<(), anyhow::Error> {
    let target = skills_dir.join(name);

    // Ensure the skills directory exists
    std::fs::create_dir_all(skills_dir).with_context(|| {
        format!(
            "cannot create directory {}",
            skills_dir.display()
        )
    })?;

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
        warn(&format!("source directory does not exist: {}", src.display()));
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

fn unlink_skill(name: &str, skills_dir: &Path, project_root: &Path) -> Result<(), anyhow::Error> {
    let target = skills_dir.join(name);

    // Only operate on symlinks
    if !target.is_symlink() {
        return Ok(());
    }

    // Read symlink target
    let link_target = std::fs::read_link(&target)
        .with_context(|| format!("cannot read symlink {}", target.display()))?;

    // Remove only if the symlink target is under PROJECT_ROOT
    // Matches install.sh: case "$link_target" in "$PROJECT_ROOT"|"$PROJECT_ROOT/"*)
    if link_target.starts_with(project_root) {
        std::fs::remove_file(&target)
            .with_context(|| format!("cannot remove symlink {}", target.display()))?;
    }

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
        warn(&format!("source directory does not exist: {}", src.display()));
        return Ok(());
    }

    // Ensure parent directory exists (e.g. ~/.agents/)
    if let Some(parent) = target.parent() {
        std::fs::create_dir_all(parent).with_context(|| {
            format!(
                "cannot create directory {}",
                parent.display()
            )
        })?;
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
    let skills_dir = env::var("AGENTS_SKILLS_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(&home).join(".agents/skills"));

    let principles_dir = env::var("AGENTS_PRINCIPLES_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(&home).join(".agents/principles"));

    let subcommand = &args[1];
    let rest = &args[2..];

    match subcommand.as_str() {
        "sync" => {
            if rest.len() != 2 {
                eprintln!("ERROR: sync requires exactly two arguments (<name> <src>), but received {}", rest.len());
                usage();
            }
            let name = &rest[0];
            let src = PathBuf::from(&rest[1]);
            sync_skill(name, &src, &skills_dir)?;
        }
        "unlink" => {
            if rest.len() != 1 {
                eprintln!("ERROR: unlink requires exactly one argument (<name>), but received {}", rest.len());
                usage();
            }
            let name = &rest[0];
            unlink_skill(name, &skills_dir, &project_root)?;
        }
        "link-principles" => {
            if rest.len() != 1 {
                eprintln!("ERROR: link-principles requires exactly one argument (<src>), but received {}", rest.len());
                usage();
            }
            let src = PathBuf::from(&rest[0]);
            link_principles(&src, &principles_dir)?;
        }
        _ => {
            eprintln!("ERROR: unknown subcommand '{}'. Available: sync, unlink, link-principles", subcommand);
            usage();
        }
    }

    Ok(())
}
