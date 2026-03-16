# Claude Code AI Scripts

Statusline script for [Claude Code](https://claude.ai/claude-code).

## Contents

| File | Purpose |
|---|---|
| `statusline/statusline.sh` | Colored status line showing model name, active modes, context window usage, cost, and more |

---

## Installation

### 1. Copy the script

```sh
cp statusline/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

### 2. Update `~/.claude/settings.json`

Add or replace the `statusLine` block:

```json
{
  "statusLine": {
    "type": "command",
    "command": "sh ~/.claude/statusline.sh"
  }
}
```

---

## Configuration

### statusline.sh

The statusline reads model info from the JSON piped by Claude Code and reads
`~/.claude/settings.json` for Max/Thinking mode flags. No configuration is
needed unless your `settings.json` uses non-standard key names for thinking
mode (see the `# Detect modes` section in the script).

**Color reference:**

| Condition | Appearance |
|---|---|
| Model contains `opus` | Orange background, black text |
| Model contains `sonnet` | Green text |
| Model contains `haiku` | Yellow text |
| Max mode active | `[MAX]` badge — red background, black text |
| Thinking mode active | `THINK` badge — yellow text |

**Additional info shown when available (in grey, after location):**

| Field | Example |
|---|---|
| Context window size | `23% /200k` |
| Agent name | `[planner]` |
| Worktree name | `[wt:feature-foo]` |
| Session cost | `$0.12` |
| Total tokens | `15k tok` |
| Session duration | `15s` |

Example output (Sonnet, Max mode on, 23% context used):

```
Claude Sonnet 4.6  [MAX]  [████░░░░░░░░░░░░░░░░] 23% /200k  dotfiles (main)  $0.12  15k tok  15s
```

---

## Requirements

- **jq** — for the statusline (`brew install jq` on macOS, `apt install jq` on Linux)
- **Claude Code** with statusline support
