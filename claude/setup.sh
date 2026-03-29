#!/bin/sh
# Claude Code setup — run from the main setup.sh or standalone.

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$HOME/.claude"

# CLAUDE.md: symlink base file (which @-imports ~/CLAUDE.local.md for machine-specific additions)
CLAUDE_MD_SRC="$DOTFILES_DIR/claude/CLAUDE.md"
CLAUDE_MD_TGT="$HOME/.claude/CLAUDE.md"
if [ -e "$CLAUDE_MD_TGT" ] && [ ! -h "$CLAUDE_MD_TGT" ]; then
    echo "~/.claude/CLAUDE.md exists and is not a symlink — move it first"
    exit 1
fi
[ -h "$CLAUDE_MD_TGT" ] && rm "$CLAUDE_MD_TGT"
echo "Linking ~/.claude/CLAUDE.md"
ln -s "$CLAUDE_MD_SRC" "$CLAUDE_MD_TGT"

# ~/CLAUDE.local.md: create a stub if not present (local/work repo may symlink a real one here)
if [ ! -e "$HOME/CLAUDE.local.md" ]; then
    echo "Creating stub ~/CLAUDE.local.md (replace with symlink from your local settings repo)"
    printf '# Local Claude settings\n\n# Add machine-specific instructions here.\n' > "$HOME/CLAUDE.local.md"
fi

# settings.json: generate from base template, injecting the dotfiles marketplace path
# and the statusline script path. Local overrides go in ~/.claude/settings.local.json.
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
SETTINGS_BASE="$DOTFILES_DIR/claude/settings.json"
STATUSLINE_PATH="$DOTFILES_DIR/claude/statusline.sh"
if command -v jq > /dev/null 2>&1; then
    echo "Generating ~/.claude/settings.json from dotfiles base"
    jq --arg mp_path "$DOTFILES_DIR" --arg sl_path "$STATUSLINE_PATH" \
        '.statusLine.command = $sl_path | .extraKnownMarketplaces["jmeagher-dotfiles"] = {"source": {"source": "directory", "path": $mp_path}, "autoUpdate": true}' \
        "$SETTINGS_BASE" > "$CLAUDE_SETTINGS"
else
    echo "WARNING: jq not found; copying settings.json without path injection"
    echo "  Install jq and re-run setup.sh, or manually set statusLine.command and marketplace path"
    cp "$SETTINGS_BASE" "$CLAUDE_SETTINGS"
fi
