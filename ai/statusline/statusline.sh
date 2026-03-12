#!/bin/sh
# Claude Code status line with ANSI color coding.
#
# Model name colors:
#   contains "opus"   → orange background, black text
#   contains "sonnet" → green text
#   contains "haiku"  → yellow text
#
# Mode badges (appended after the model name):
#   Max mode on     → [MAX]   red background, black text
#   Thinking mode on → [THINK] yellow text
#
# Context window: progress bar + percentage, e.g.  [████░░░░░░░░░░░░░░░░] 23%
#
# Max and thinking mode are read from ~/.claude/settings.json since the
# statusline JSON input does not reliably expose them.
# Adjust the jq key names in the "Detect modes" section if your settings
# use different field names.

SETTINGS="$HOME/.claude/settings.json"

# ANSI helpers
RST='\033[0m'

# Read stdin JSON
input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // "Claude"')
used=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')

model_lower=$(printf '%s' "$model" | tr '[:upper:]' '[:lower:]')

# ── Detect modes from settings.json ──────────────────────────────────────────

is_max=0
is_thinking=0

if [ -f "$SETTINGS" ]; then
    # Max mode: check if the settings model alias or value contains "max"
    settings_model=$(jq -r '.model // ""' "$SETTINGS" 2>/dev/null)
    settings_model_lower=$(printf '%s' "$settings_model" | tr '[:upper:]' '[:lower:]')
    case "$settings_model_lower" in
        *max*) is_max=1 ;;
    esac

    # Thinking mode: adjust key names below if your settings differ
    thinking_val=$(jq -r '.thinking // .extendedThinking // .enableThinking // "false"' "$SETTINGS" 2>/dev/null)
    [ "$thinking_val" = "true" ] && is_thinking=1
fi

# Also treat "max" in the stdin model name as Max mode
case "$model_lower" in
    *max*) is_max=1 ;;
esac

# ── Color the model name ──────────────────────────────────────────────────────

case "$model_lower" in
    *opus*)
        # Orange background (256-color 208), black text
        model_out=$(printf '\033[48;5;208m\033[30m %s \033[0m' "$model")
        ;;
    *sonnet*)
        model_out=$(printf '\033[32m%s\033[0m' "$model")
        ;;
    *haiku*)
        model_out=$(printf '\033[33m%s\033[0m' "$model")
        ;;
    *)
        model_out="$model"
        ;;
esac

# ── Mode badges ───────────────────────────────────────────────────────────────

badges=""
if [ "$is_max" = "1" ]; then
    # Red background, black text
    badges="${badges}$(printf ' \033[41m\033[30m MAX \033[0m')"
fi
if [ "$is_thinking" = "1" ]; then
    # Yellow text
    badges="${badges}$(printf ' \033[33mTHINK\033[0m')"
fi

# ── Context window bar ────────────────────────────────────────────────────────

if [ -z "$used" ]; then
    printf '%b%b' "$model_out" "$badges"
else
    filled=$(printf '%s' "$used" | awk '{printf "%d", int($1 * 20 / 100 + 0.5)}')
    empty=$((20 - filled))

    used_int=$(printf '%s' "$used" | awk '{printf "%d", int($1 + 0.5)}')

    if [ "$used_int" -lt 45 ]; then
        ctx_color='\033[38;5;28m'
    elif [ "$used_int" -lt 55 ]; then
        ctx_color='\033[33m'
    elif [ "$used_int" -lt 65 ]; then
        ctx_color='\033[38;5;208m'
    else
        ctx_color='\033[31m'
    fi

    grey='\033[90m'

    filled_bar=$(printf '%b' "$ctx_color")
    i=0
    while [ "$i" -lt "$filled" ]; do
        filled_bar="${filled_bar}█"
        i=$((i + 1))
    done
    filled_bar="${filled_bar}$(printf '%b' "$RST")"

    empty_bar=$(printf '%b' "$grey")
    i=0
    while [ "$i" -lt "$empty" ]; do
        empty_bar="${empty_bar}░"
        i=$((i + 1))
    done
    empty_bar="${empty_bar}$(printf '%b' "$RST")"

    printf '%b%b  [%s%s] %b%s%%%b' "$model_out" "$badges" "$filled_bar" "$empty_bar" "$ctx_color" "$used_int" "$RST"
fi
