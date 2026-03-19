# dotfiles

My dotfiles. Not meant for others, but you might find something useful here.

## Claude Code Plugin Marketplace

This repo is a Claude Code plugin marketplace. Register it with Claude Code to install plugins from it.

### Local setup

```
/plugin marketplace add /path/to/dotfiles
/plugin install statusline@jmeagher-dotfiles
```

Changes to plugin files take effect on the next Claude Code session without needing to push to git.

### From GitHub

```
/plugin marketplace add jmeagher/dotfiles
/plugin install statusline@jmeagher-dotfiles
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
