#!/usr/bin/env bash
# SessionStart hook: a fresh session is never legitimately mid-gate, so clear
# any stale gate state left by a crashed or abandoned /code-loop run.
# (Sessions spawned by bin/code-loop re-arm via /code-loop after this fires.)
set -u
input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] && [ -d "$cwd/.loop" ] || exit 0
rm -f "$cwd/.loop/active" "$cwd/.loop/blocks"
exit 0
