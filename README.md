# autopilot-toolkit

19 skills for reasonix — upstream engineering/productivity skills plus autopilot workflow (orchestrator → implementer → reviewer). Deployed via symlinks to `~/.agents/skills/`.

## Prerequisites

The Rust-based installer (`install.rs`) requires [rust-script](https://github.com/fornwall/rust-script):

```bash
brew install rust-script
# or: cargo install rust-script
```

## Installation

First-time setup — clone the repository and run toolkit setup:

```bash
git clone git@github.com:matthewye/autopilot-toolkit.git && cd autopilot-toolkit && /toolkit-setup
```

## Commands

Manage skill symlinks with `install.rs`:

```bash
./deploy.rs dev <name> <src>       # symlink ~/.agents/skills/<name> → <src>
./deploy.rs unlink <name>           # remove a toolkit-owned symlink
./deploy.rs link-principles <src>   # symlink ~/.agents/principles → <src>
```

## Updating

Pull the latest changes and re-run toolkit setup to sync skills:

```bash
cd autopilot-toolkit && git pull && /toolkit-setup
```

Full skill inventory and project details: [`docs/prd/0001-autopilot-toolkit.md`](docs/prd/0001-autopilot-toolkit.md).
