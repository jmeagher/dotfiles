#!/usr/bin/env bash
# SessionStart hook: a fresh session is never legitimately mid-gate, so clear
# stale per-project gate state (.loop/<project>/{active,blocks}) left by a
# crashed or abandoned /code-loop run.
# (Sessions spawned by bin/code-loop re-arm via /code-loop after this fires.)
set -u
input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] && [ -d "$cwd/.loop" ] || exit 0
find "$cwd/.loop" -mindepth 2 -maxdepth 2 \( -name active -o -name blocks \) -type f -delete 2>/dev/null
exit 0
