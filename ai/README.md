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

### Local development (live edits, no git push needed)

Register this directory as a marketplace, then install plugins from it:

```
/plugin marketplace add /path/to/dotfiles/ai
/plugin install statusline@jmeagher-dotfiles
```

Changes to plugin files (scripts, hooks, skills) take effect on the next Claude Code session — no git push or reinstall required.

### From GitHub

Push this repo, then add the marketplace using the GitHub shorthand:

```
/plugin marketplace add jmeagher/dotfiles
/plugin install statusline@jmeagher-dotfiles
```

> **Note:** The marketplace manifest (`ai/.claude-plugin/marketplace.json`) must be at the repository root for this to work. If the dotfiles repo keeps `ai/` as a subdirectory, move the marketplace to its own repository first, or use the local path method above.

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
