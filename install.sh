#!/usr/bin/env bash
set -euo pipefail

# install.sh — Pure-tool subcommand interface for agent skill management
#
# Subcommands:
#   sync <name> <src>       Ensure ~/.agents/skills/<name> is a symlink to <src>
#   unlink <name>           Remove a symlink under ~/.agents/skills/<name> if it
#                           points under PROJECT_ROOT (no-op otherwise)
#   link-principles <src>   Ensure ~/.agents/principles is a symlink to <src>
#
# Environment variables:
#   PROJECT_ROOT           Project root directory (used by some subcommands)
#   AGENTS_SKILLS_DIR      Override ~/.agents/skills/ path
#   AGENTS_PRINCIPLES_DIR  Override ~/.agents/principles path

# PROJECT_ROOT is computed here for use by unlink (to check symlink ownership)
# and by link-principles (to set the principles symlink target).
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
SKILLS_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
PRINCIPLES_DIR="${AGENTS_PRINCIPLES_DIR:-$HOME/.agents/principles}"

warn()  { echo "WARNING: $*" >&2; }

usage() {
  echo "Usage: install.sh <subcommand> [args...]"
  echo ""
  echo "Subcommands:"
  echo "  sync <name> <src>       Ensure ~/.agents/skills/<name> is a symlink to <src>"
  echo "  unlink <name>           Remove a toolkit-owned symlink from ~/.agents/skills/"
  echo "  link-principles <src>   Ensure ~/.agents/principles is a symlink to <src>"
  exit 1
}

# sync <name> <src>
# Ensures $SKILLS_DIR/<name> is a symlink pointing to <src>.
# See tests/test_install.sh for the full behavior table.
sync_skill() {
  local name="$1"
  local src="$2"
  local target="$SKILLS_DIR/$name"

  # Ensure the skills directory exists
  mkdir -p "$SKILLS_DIR" || {
    warn "cannot create $SKILLS_DIR — check permissions"
    exit 1
  }

  # If target exists as a real file/directory (not a symlink), refuse to overwrite
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    warn "$target exists as a real directory (not a symlink) — refusing to overwrite"
    return 1
  fi

  # If target is a symlink, inspect its current state
  if [ -L "$target" ]; then
    local existing
    existing="$(readlink "$target" 2>/dev/null || true)"

    # Valid symlink pointing to the correct source — nothing to do
    if [ "$existing" = "$src" ] && [ -d "$target" ]; then
      return 0
    fi

    # Broken or pointing to the wrong target — remove it before rebuilding
    rm -f "$target"
  fi

  # Source directory must exist
  if [ ! -d "$src" ]; then
    warn "source directory does not exist: $src"
    return 0
  fi

  # Create the symlink
  ln -sfn "$src" "$target" || {
    warn "failed to create symlink: $target -> $src"
    return 1
  }

  return 0
}

# unlink <name>
# Removes $SKILLS_DIR/<name> if it is a symlink whose target lies under
# PROJECT_ROOT.  Otherwise (non-existent, real directory, or symlink
# pointing outside PROJECT_ROOT) it is a silent no-op.
unlink_skill() {
  local name="$1"
  local target="$SKILLS_DIR/$name"

  # Only operate on symlinks
  if [ ! -L "$target" ]; then
    return 0
  fi

  local link_target
  link_target="$(readlink "$target" 2>/dev/null || true)"

  # Remove only if the symlink target is under PROJECT_ROOT
  case "$link_target" in
    "$PROJECT_ROOT"|"$PROJECT_ROOT/"*)
      rm -f "$target"
      ;;
  esac

  return 0
}

# link_principles <src>
# Ensures $PRINCIPLES_DIR is a symlink pointing to <src>.
# Behaviour mirrors sync: creates, skips if correct, replaces broken/wrong,
# warns and exits non-zero on real-directory conflict.
link_principles() {
  local src="$1"
  local target="$PRINCIPLES_DIR"

  # If target exists as a real file/directory (not a symlink), refuse to overwrite
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    warn "$target exists as a real directory (not a symlink) — refusing to overwrite"
    return 1
  fi

  # If target is a symlink, inspect its current state
  if [ -L "$target" ]; then
    local existing
    existing="$(readlink "$target" 2>/dev/null || true)"

    # Valid symlink pointing to the correct source — nothing to do
    if [ "$existing" = "$src" ] && [ -d "$target" ]; then
      return 0
    fi

    # Broken or pointing to the wrong target — remove it before rebuilding
    rm -f "$target"
  fi

  # Source directory must exist
  if [ ! -d "$src" ]; then
    warn "source directory does not exist: $src"
    return 0
  fi

  # Create the symlink
  # Ensure parent exists (e.g. ~/.agents/)
  mkdir -p "$(dirname "$target")" || {
    warn "cannot create $(dirname "$target") — check permissions"
    exit 1
  }

  ln -sfn "$src" "$target" || {
    warn "failed to create symlink: $target -> $src"
    return 1
  }

  return 0
}

# ── main ──

if [ $# -eq 0 ]; then
  usage
fi

subcommand="$1"
shift

case "$subcommand" in
  sync)
    if [ $# -ne 2 ]; then
      echo "ERROR: sync requires exactly two arguments: <name> <src>" >&2
      usage
    fi
    sync_skill "$1" "$2"
    ;;
  unlink)
    if [ $# -ne 1 ]; then
      echo "ERROR: unlink requires exactly one argument: <name>" >&2
      usage
    fi
    unlink_skill "$1"
    ;;
  link-principles)
    if [ $# -ne 1 ]; then
      echo "ERROR: link-principles requires exactly one argument: <src>" >&2
      usage
    fi
    link_principles "$1"
    ;;
  *)
    echo "ERROR: unknown subcommand: $subcommand" >&2
    usage
    ;;
esac
