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

# generate.py needs PyYAML. Bare python3 often doesn't have it (e.g. a
# system/homebrew install with no site-packages access) -- bootstrap a
# local venv automatically rather than requiring the user to do it by hand.
PYTHON="python3"
if ! python3 -c "import yaml" > /dev/null 2>&1; then
    VENV_DIR="$FRAMEWORK_DIR/.venv"
    if [ ! -x "$VENV_DIR/bin/python3" ]; then
        echo "PyYAML not found for python3 -- bootstrapping a local venv at $VENV_DIR"
        if ! python3 -m venv "$VENV_DIR" 2>/dev/null; then
            echo "WARNING: couldn't create a venv -- orchestrator agent files won't be generated"
            echo "  Install PyYAML yourself (python3 -m pip install --user pyyaml) and re-run,"
            echo "  or create $VENV_DIR manually with pyyaml installed."
            exit 0
        fi
    fi
    if ! "$VENV_DIR/bin/python3" -c "import yaml" > /dev/null 2>&1; then
        echo "Installing PyYAML into $VENV_DIR"
        if ! "$VENV_DIR/bin/pip" install -q pyyaml; then
            echo "WARNING: couldn't install PyYAML -- orchestrator agent files won't be generated"
            echo "  Install it yourself: $VENV_DIR/bin/pip install pyyaml"
            exit 0
        fi
    fi
    PYTHON="$VENV_DIR/bin/python3"
fi

mkdir -p "$HOME/.claude/agents"

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
"$PYTHON" "$FRAMEWORK_DIR/generate.py" $GENERATE_ARGS
