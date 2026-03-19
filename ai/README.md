# Claude Code Plugin Marketplace

Personal Claude Code plugins for [Claude Code](https://claude.ai/claude-code).

## Structure

```
.claude-plugin/
└── marketplace.json   # marketplace manifest
plugins/
└── statusline/        # colored status line with model, context, cost, and more
```

## Installation

### From GitHub (normal use)

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

Then install individual plugins via Claude Code:

```
/plugin install statusline@jmeagher-dotfiles
```

### Live local development

For developing plugins without pushing to GitHub first, install directly from the local directory:

```
/plugin install --local /path/to/dotfiles/ai/plugins/statusline
```

This loads the plugin from the local path so edits to scripts and hooks take effect immediately on the next Claude Code session — no git push required.

To update after making changes, reinstall:

```
/plugin install --local /path/to/dotfiles/ai/plugins/statusline
```

## Plugins

### statusline

Colored status line showing model name, mode badges, context window bar, cost, tokens, and duration.

| Condition | Appearance |
|---|---|
| Model contains `opus` | Orange background, black text |
| Model contains `sonnet` | Green text |
| Model contains `haiku` | Yellow text |
| Max mode active | `[MAX]` badge — red background, black text |
| Thinking mode active | `THINK` badge — yellow text |

Example output:

```
Claude Sonnet 4.6  [MAX]  [████░░░░░░░░░░░░░░░░] 23% /200k  dotfiles (main)  $0.12  15k tok  15s
```

After installing, the plugin auto-configures `statusLine` in `settings.json` on first session start.

**Requirements:** `jq` (`apt install jq` or `brew install jq`)

---

## Adding more plugins

Each plugin lives in `plugins/<plugin-name>/` and must be registered in `.claude-plugin/marketplace.json`.

Plugin directory structure:

```
plugins/my-plugin/
├── .claude-plugin/
│   └── plugin.json   # required
├── commands/         # slash commands (optional)
├── skills/           # auto-activating skills (optional)
├── hooks/            # event hooks (optional)
└── scripts/          # helper scripts (optional)
```
