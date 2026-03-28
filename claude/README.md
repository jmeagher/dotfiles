# Claude Code Setup

## Plugin Marketplace

This repo is a Claude Code plugin marketplace. Register it with Claude Code to install plugins from it.

### Local setup

```
/plugin marketplace add /path/to/dotfiles
```

Changes to plugin files take effect on the next Claude Code session without needing to push to git.

### From GitHub

```
/plugin marketplace add jmeagher/dotfiles
```

Run `setup.sh` from the repo root to configure everything automatically.
