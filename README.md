# dotfiles

My dotfiles. Not meant for others, but you might find something useful here.

## Claude Code Plugin

The `ai/` directory is a Claude Code plugin marketplace containing personal plugins.

### Setup

**Option 1: Register as a marketplace** (after pushing to GitHub)

Add to `~/.claude/plugins/known_marketplaces.json`:

```json
{
  "jmeagher-dotfiles": {
    "source": {
      "source": "github",
      "repo": "jmeagher/dotfiles",
      "path": "ai"
    }
  }
}
```

Then install plugins via Claude Code:

```
/plugin install statusline@jmeagher-dotfiles
```

**Option 2: Local install**

```
/plugin install --local /path/to/dotfiles/ai/plugins/statusline
```

### Plugins

- **statusline** — Colored Claude Code status line showing model, mode badges (MAX/THINK), context window bar, cost, tokens, and session duration. Auto-configures `settings.json` on first session start. Requires `jq`.

See [`ai/README.md`](ai/README.md) for full plugin marketplace documentation.
