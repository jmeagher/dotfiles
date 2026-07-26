#!/bin/sh
# Orchestrator framework setup — run from the main setup.sh or standalone.

FRAMEWORK_DIR="$(cd "$(dirname "$0")" && pwd)"

# queue.py has no external dependencies, so link it unconditionally --
# agent prompts invoke it as a bare `orchestrator-queue` command regardless
# of whether agent-file generation below succeeds.
mkdir -p "$HOME/bin"
echo "Linking ~/bin/orchestrator-queue"
[ -h "$HOME/bin/orchestrator-queue" ] && rm "$HOME/bin/orchestrator-queue"
ln -s "$FRAMEWORK_DIR/queue.py" "$HOME/bin/orchestrator-queue"

# Runtime dependency check (PyYAML) — warn and continue, don't hard-fail
# the whole dotfiles setup, matching claude/setup.sh's jq check.
if ! python3 -c "import yaml" > /dev/null 2>&1; then
    echo "WARNING: PyYAML not found for python3 — orchestrator agent files won't be generated"
    echo "  Install it with: python3 -m pip install --user pyyaml (or use a venv)"
    exit 0
fi

mkdir -p "$HOME/.claude/agents"

# The Orchestrator agent is itself a subagent and needs to spawn a further
# layer of subagents (Worker/Reviewer/Consultant) -- Claude Code withholds
# subagent-spawning from subagents by default, so raise the allowed nesting
# depth. Only set this if the user hasn't already configured their own
# value -- never clobber an existing setting.
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [ -e "$CLAUDE_SETTINGS" ] && command -v jq > /dev/null 2>&1; then
    if ! jq -e '.env.CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH' "$CLAUDE_SETTINGS" > /dev/null 2>&1; then
        echo "Enabling subagent nesting (CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=2) in ~/.claude/settings.json"
        jq '.env.CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH = "2"' "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp" && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
    fi
elif [ -e "$CLAUDE_SETTINGS" ]; then
    echo "NOTE: jq not found -- couldn't verify/set CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH in ~/.claude/settings.json"
    echo "  The Orchestrator agent needs this set to at least 2 to spawn Worker/Reviewer/Consultant."
    echo "  Add \"env\": {\"CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH\": \"2\"} to that file manually if needed."
else
    echo "NOTE: ~/.claude/settings.json not found -- couldn't set CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH"
    echo "  The Orchestrator agent needs this set to at least 2 to spawn Worker/Reviewer/Consultant."
    echo "  Run this repo's root setup.sh (which creates settings.json first) or add"
    echo "  \"env\": {\"CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH\": \"2\"} to that file manually."
fi

GENERATE_ARGS="--models-local $FRAMEWORK_DIR/models.local.yaml --claude-code-out $HOME/.claude/agents"

if [ -e "$FRAMEWORK_DIR/models.local.yaml" ]; then
    mkdir -p "$HOME/.config/opencode/agent"
    GENERATE_ARGS="$GENERATE_ARGS --opencode-out $HOME/.config/opencode/agent --cursor-out $HOME/.orchestrator-cursor-modes.json"
else
    echo "NOTE: $FRAMEWORK_DIR/models.local.yaml not found -- only generating Claude Code"
    echo "  agents (it ships real defaults). Copy models.local.yaml.example to"
    echo "  models.local.yaml and fill in your OpenCode/Cursor model ids, then"
    echo "  re-run this script to generate those too."
fi

echo "Generating orchestrator framework agents"
python3 "$FRAMEWORK_DIR/generate.py" $GENERATE_ARGS
