#!/bin/bash
# Configure Claude Code settings.json to use this plugin's statusline script.
# Runs on SessionStart; updates the statusLine setting if it points elsewhere.

SCRIPT_PATH="$CLAUDE_PLUGIN_ROOT/scripts/statusline.sh"
SETTINGS="$HOME/.claude/settings.json"
TARGET="sh $SCRIPT_PATH"

if [ ! -f "$SETTINGS" ]; then
    echo '{}' > "$SETTINGS"
fi

current=$(jq -r '.statusLine.command // ""' "$SETTINGS" 2>/dev/null)

if [ "$current" != "$TARGET" ]; then
    tmp=$(mktemp)
    jq --arg cmd "$TARGET" '.statusLine = {"type": "command", "command": $cmd}' "$SETTINGS" > "$tmp" \
        && mv "$tmp" "$SETTINGS"
fi
