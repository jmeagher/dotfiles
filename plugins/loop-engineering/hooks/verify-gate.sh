#!/usr/bin/env bash
# Stop-hook verification gate for the loop-engineering plugin.
# Gate state is per-project: .loop/<project>/{active,verify,blocks}. The hook
# checks EVERY armed project in the cwd: each passing project is disarmed, and
# any failing project blocks the stop — so concurrent sessions looping on
# different projects in the same repo cannot release each other's gates.
# A project unblocks when its verify command passes, or after MAX_BLOCKS
# consecutive failures (then the hook demands a FAILURE report).
# stop_hook_active is deliberately NOT checked: the docs' "exit 0 if true"
# pattern would defeat the gate; the blocks counter bounds re-blocking instead.
set -u
MAX_BLOCKS=3

input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
cd "$cwd" || exit 0

blocked=0
for active in .loop/*/active; do
  [ -f "$active" ] || continue   # unmatched glob or vanished file
  dir=${active%/active}
  project=${dir#.loop/}
  # Strip backtick residue (sloppy extraction) and CR (CRLF-authored SPEC.md).
  verify_cmd=$(head -1 "$dir/verify" 2>/dev/null | tr -d '`\r')
  [ -n "$verify_cmd" ] || continue   # fail safe: never trap a session on broken state

  # Verify FIRST: a passing project always unblocks, even if a stale counter
  # is left over from a crashed run.
  if output=$(bash -c "$verify_cmd" 2>&1); then
    rm -f "$dir/active" "$dir/blocks"
    continue
  fi

  blocks=$(cat "$dir/blocks" 2>/dev/null || echo 0)
  case "$blocks" in (*[!0-9]*|'') blocks=0;; esac
  blocks=$((blocks + 1))

  if [ "$blocks" -ge "$MAX_BLOCKS" ]; then
    rm -f "$dir/active" "$dir/blocks"
    echo "Verification for project '$project' has failed $MAX_BLOCKS consecutive times. Its gate is now DISARMED. Append a FAILURE report to loops/$project/LOOP_LOG.md (what is broken, what you tried, what a human should look at), then stop." >&2
    blocked=1
    continue
  fi

  echo "$blocks" > "$dir/blocks"
  {
    echo "STOP BLOCKED: verify command for project '$project' failed ($blocks/$MAX_BLOCKS): $verify_cmd"
    echo "Fix the failure (do NOT weaken tests or the verifier), update loops/$project/LOOP_LOG.md, then try again. Output (last 2000 chars):"
    printf '%s' "$output" | tail -c 2000
  } >&2
  blocked=1
done

[ "$blocked" -eq 0 ] || exit 2
exit 0
