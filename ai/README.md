# Claude Code AI Scripts

Reusable hooks and statusline script for [Claude Code](https://claude.ai/claude-code).

## Contents

| File | Purpose |
|---|---|
| `hooks/notify.py` | Speaks a notification when Claude finishes, if you've been idle for over a minute |
| `hooks/mode-guard.py` | Blocks every prompt that uses Opus, Max mode, or Thinking mode until you explicitly confirm |
| `statusline/statusline.sh` | Colored status line showing model name, active modes, and context window usage |

---

## Installation

### 1. Copy the scripts

```sh
cp hooks/notify.py      ~/.claude/hooks/notify.py
cp hooks/mode-guard.py  ~/.claude/hooks/mode-guard.py
cp statusline/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

### 2. Remove the old opus guard (if present)

`mode-guard.py` supersedes the older `opus-guard.py` with stricter per-prompt
blocking and adds Max/Thinking mode coverage. Remove the old file:

```sh
rm -f ~/.claude/hooks/opus-guard.py
```

### 3. Update `~/.claude/settings.json`

Add or replace the `hooks` and `statusLine` blocks:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/hooks/notify.py"
          },
          {
            "type": "command",
            "command": "python3 ~/.claude/hooks/mode-guard.py"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/hooks/mode-guard.py"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/hooks/notify.py"
          }
        ]
      }
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "sh ~/.claude/statusline.sh"
  }
}
```

> The `Stop` event requires Claude Code 1.x or later. If your version does not
> support it, omit the `Stop` block — notify.py handles the missing event
> gracefully.

---

## Configuration

### notify.py

Open `~/.claude/hooks/notify.py` and edit the constants at the top:

| Constant | Default | Description |
|---|---|---|
| `IDLE_THRESHOLD_SECONDS` | `60` | Seconds of inactivity before a notification fires |
| `TIMESTAMP_FILE` | `/tmp/claude_last_prompt_time` | Shared timestamp file (tracks activity across all sessions) |
| `NOTIFY_MSG` | `"all done"` | Phrase spoken on macOS (`say`), or beeped on other platforms. Change to `"waiting for input"` or any phrase you prefer. |

**Platform behavior:**
- **macOS**: runs `say "<NOTIFY_MSG>"` — spoken aloud by the system voice
- **Linux / other**: tries the `beep` command; if unavailable, sends a terminal bell (`\a`) to `/dev/tty`

### mode-guard.py

Blocking is triggered by three independent checks. Each check prompts you
separately; declining any one of them blocks the prompt.

| Trigger | Detection method |
|---|---|
| Opus model | model name contains `"opus"` |
| Max mode | model name contains `"max"` |
| Thinking mode | `settings.json` has `thinking`, `extendedThinking`, or `enableThinking` set to `true` |

If Claude Code stores thinking mode under a different key in your `settings.json`,
add it to the `is_thinking_enabled()` function in `mode-guard.py`.

Unlike the older `opus-guard.py`, there is **no session-level bypass** — every
prompt requires explicit `yes` confirmation when a guarded mode is active.

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

Example output (Sonnet, Max mode on, 23% context used):

```
Claude Sonnet 4.6  [MAX]  [████░░░░░░░░░░░░░░░░] 23%
```

---

## Requirements

- **Python 3** — for the hooks (standard on macOS and most Linux distros)
- **jq** — for the statusline (`brew install jq` on macOS, `apt install jq` on Linux)
- **Claude Code** with hook and statusline support
