#!/usr/bin/env bash
# Stop-hook verification gate for the loop-engineering plugin.
# Allows the agent to stop only when the project's verify command passes,
# or after MAX_BLOCKS consecutive failures (then demands a FAILURE report).
# stop_hook_active is deliberately NOT checked: the docs' "exit 0 if true"
# pattern would defeat the gate; the blocks counter bounds re-blocking instead.
set -u
MAX_BLOCKS=3

input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
cd "$cwd" || exit 0

# Gate only applies while /code-loop has armed it in this project.
[ -f .loop/active ] || exit 0
# Strip backtick residue in case extraction from SPEC.md was sloppy.
verify_cmd=$(head -1 .loop/verify 2>/dev/null | tr -d '`')
[ -n "$verify_cmd" ] || exit 0   # fail safe: never trap a session on broken state

# Verify FIRST: a passing project always unblocks, even if a stale counter
# is left over from a crashed run.
if output=$(bash -c "$verify_cmd" 2>&1); then
  rm -f .loop/active .loop/blocks
  exit 0
fi

blocks=$(cat .loop/blocks 2>/dev/null || echo 0)
case "$blocks" in (*[!0-9]*|'') blocks=0;; esac
blocks=$((blocks + 1))

if [ "$blocks" -ge "$MAX_BLOCKS" ]; then
  rm -f .loop/active .loop/blocks
  echo "Verification has failed $MAX_BLOCKS consecutive times. The gate is now DISARMED. Append a FAILURE report to LOOP_LOG.md (what is broken, what you tried, what a human should look at), then stop." >&2
  exit 2
fi

echo "$blocks" > .loop/blocks
{
  echo "STOP BLOCKED: verify command failed ($blocks/$MAX_BLOCKS): $verify_cmd"
  echo "Fix the failure (do NOT weaken tests or the verifier), update LOOP_LOG.md, then try again. Output (last 2000 chars):"
  printf '%s' "$output" | tail -c 2000
} >&2
exit 2
