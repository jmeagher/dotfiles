# dotfiles

My dotfiles. Not meant for others, but you might find something useful here.

## Claude Code Plugin Marketplace

The `ai/` directory is a Claude Code plugin marketplace. Register it with Claude Code to install plugins from it.

### Local setup

```
/plugin marketplace add /path/to/dotfiles/ai
/plugin install statusline@jmeagher-dotfiles
```

Changes to plugin files take effect on the next Claude Code session without needing to push to git.

### Plugins

- **statusline** — Colored Claude Code status line showing model, mode badges (MAX/THINK), context window bar, cost, tokens, and session duration. Auto-configures `settings.json` on first session start. Requires `jq`.

See [`ai/README.md`](ai/README.md) for full marketplace documentation.
