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
# Context window: progress bar + percentage + size, e.g.  [████░░░░░░░░░░░░░░░░] 23% /200k
#
# Additional info (when available, shown after location):
#   agent name, worktree name, cost ($0.12), token breakdown, duration (15s)
#
# Token breakdown (per-turn from current_usage):
#   o:1.2k  output tokens        red    (50× cost — most expensive)
#   i:8.5k  uncached input       grey   (10× cost)
#   rc:2k   cache reads          green  (1× cost — the savings)
#   wc:5k   cache writes         orange (written this turn for future reads)
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
ctx_size=$(printf '%s' "$input" | jq -r '.context_window.context_window_size // empty')
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // ""')
[ -z "$cwd" ] && cwd="$PWD"

# Cost / tokens / duration
cost_usd=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // empty')
# Per-turn token breakdown (current_usage)
cur_input=$(printf '%s' "$input" | jq -r '.context_window.current_usage.input_tokens // empty')
cur_output=$(printf '%s' "$input" | jq -r '.context_window.current_usage.output_tokens // empty')
cur_cache_read=$(printf '%s' "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // empty')
cur_cache_write=$(printf '%s' "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // empty')
duration_ms=$(printf '%s' "$input" | jq -r '.cost.total_duration_ms // empty')

# Worktree / agent
worktree_name=$(printf '%s' "$input" | jq -r '.worktree.name // empty')
agent_name=$(printf '%s' "$input" | jq -r '.agent.name // empty')

model_lower=$(printf '%s' "$model" | tr '[:upper:]' '[:lower:]')  # lowercased for case-insensitive matching below

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
    case "$thinking_val" in
        true|1|yes|enabled) is_thinking=1 ;;
    esac
fi

# Also treat "max" in the stdin model name as Max mode
case "$model_lower" in
    *max*) is_max=1 ;;
esac

# ── Working directory and git branch ─────────────────────────────────────────

folder=$(basename "$cwd")
git_branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)

location_out=$(printf '\033[36m%s\033[0m' "$folder")
if [ -n "$git_branch" ]; then
    location_out="${location_out}$(printf ' \033[90m(%s)\033[0m' "$git_branch")"
fi

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

# ── Context window size suffix (e.g. " /200k") ───────────────────────────────

ctx_size_out=""
if [ -n "$ctx_size" ]; then
    ctx_size_k=$(printf '%s' "$ctx_size" | awk '{printf "%dk", int($1/1000 + 0.5)}')
    ctx_size_out=$(printf ' \033[90m/%s\033[0m' "$ctx_size_k")
fi

# ── Agent / worktree badges ───────────────────────────────────────────────────

extra_badges=""
if [ -n "$agent_name" ]; then
    extra_badges="${extra_badges}$(printf ' \033[36m[%s]\033[0m' "$agent_name")"
fi
if [ -n "$worktree_name" ]; then
    extra_badges="${extra_badges}$(printf ' \033[90m[wt:%s]\033[0m' "$worktree_name")"
fi

# ── Cost / tokens / duration ──────────────────────────────────────────────────

cost_out=""
if [ -n "$cost_usd" ]; then
    cost_fmt=$(printf '%s' "$cost_usd" | awk '{printf "$%.2f", $1}')
    cost_out=$(printf '  \033[90m%s\033[0m' "$cost_fmt")
fi

tokens_out=""
if [ -n "$cur_output" ] || [ -n "$cur_input" ]; then
    # Helper: format as X.Xk if >= 1000, else plain number
    _k() { printf '%s' "${1:-0}" | awk '{
        if ($1>=1000) {
            v=$1/1000; r=int(v*10+0.5)/10
            if (r==int(r)) printf "%dk",int(r); else printf "%.1fk",r
        } else printf "%d",$1
    }'; }

    out_fmt=$(_k "$cur_output")
    in_fmt=$(_k "$cur_input")

    # Output: red (50× cost) | Uncached input: grey (10× cost)
    tokens_out=$(printf '  \033[31mo:%s\033[0m \033[90mi:%s\033[0m' "$out_fmt" "$in_fmt")

    # Cache reads: green (1× cost — the savings show here)
    if [ -n "$cur_cache_read" ] && [ "$cur_cache_read" -gt 0 ] 2>/dev/null; then
        read_fmt=$(_k "$cur_cache_read")
        tokens_out="${tokens_out}$(printf ' \033[32mrc:%s\033[0m' "$read_fmt")"
    fi

    # Cache writes: orange (pay now, save later)
    if [ -n "$cur_cache_write" ] && [ "$cur_cache_write" -gt 0 ] 2>/dev/null; then
        write_fmt=$(_k "$cur_cache_write")
        tokens_out="${tokens_out}$(printf ' \033[38;5;208mwc:%s\033[0m' "$write_fmt")"
    fi
fi

duration_out=""
if [ -n "$duration_ms" ]; then
    duration_fmt=$(printf '%s' "$duration_ms" | awk '{
        s = int($1/1000)
        m = int(s/60)
        s = s % 60
        if (m > 0) printf "%dm %ds", m, s
        else printf "%ds", s
    }')
    duration_out=$(printf '  \033[90m%s\033[0m' "$duration_fmt")
fi

# ── Context window bar ────────────────────────────────────────────────────────

if [ -z "$used" ]; then
    printf '%b%b  %b%b%b%b%b' "$model_out" "$badges" "$location_out" "$extra_badges" "$cost_out" "$tokens_out" "$duration_out"
else
    filled=$(printf '%s' "$used" | awk '{printf "%d", int($1 * 20 / 100 + 0.5)}')
    [ "$filled" -gt 20 ] && filled=20
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

    printf '%b%b  [%s%s] %b%s%%%b%b  %b%b%b%b%b' \
        "$model_out" "$badges" \
        "$filled_bar" "$empty_bar" \
        "$ctx_color" "$used_int" "$RST" "$ctx_size_out" \
        "$location_out" "$extra_badges" \
        "$cost_out" "$tokens_out" "$duration_out"
fi
