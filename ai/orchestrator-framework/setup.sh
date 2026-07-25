#!/bin/sh
# Orchestrator framework setup — run from the main setup.sh or standalone.

FRAMEWORK_DIR="$(cd "$(dirname "$0")" && pwd)"

# Runtime dependency check (PyYAML) — warn and continue, don't hard-fail
# the whole dotfiles setup, matching claude/setup.sh's jq check.
if ! python3 -c "import yaml" > /dev/null 2>&1; then
    echo "WARNING: PyYAML not found for python3 — orchestrator agent files won't be generated"
    echo "  Install it with: python3 -m pip install --user pyyaml (or use a venv)"
    exit 0
fi

if [ ! -e "$FRAMEWORK_DIR/models.local.yaml" ]; then
    echo "NOTE: $FRAMEWORK_DIR/models.local.yaml not found — OpenCode/Cursor model"
    echo "  tiers will stay unset. Copy models.local.yaml.example to models.local.yaml"
    echo "  and fill in your own model ids to enable those harnesses."
fi

mkdir -p "$HOME/.claude/agents" "$HOME/.config/opencode/agent" "$HOME/bin"

# Agent prompts invoke the queue CLI as a bare `orchestrator-queue` command
# (it must resolve on PATH from inside any project being orchestrated, not
# just from this dotfiles checkout) — symlink it into ~/bin like this repo's
# other bin/ scripts.
echo "Linking ~/bin/orchestrator-queue"
[ -h "$HOME/bin/orchestrator-queue" ] && rm "$HOME/bin/orchestrator-queue"
ln -s "$FRAMEWORK_DIR/queue.py" "$HOME/bin/orchestrator-queue"

echo "Generating orchestrator framework agents"
python3 "$FRAMEWORK_DIR/generate.py" \
    --models-local "$FRAMEWORK_DIR/models.local.yaml" \
    --claude-code-out "$HOME/.claude/agents" \
    --opencode-out "$HOME/.config/opencode/agent" \
    --cursor-out "$HOME/.orchestrator-cursor-modes.json"
