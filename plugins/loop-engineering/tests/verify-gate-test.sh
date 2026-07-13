#!/usr/bin/env bash
# Tests for verify-gate.sh and session-cleanup.sh. Each case runs in its own temp dir.
set -u
HOOKS_DIR="$(cd "$(dirname "$0")/../hooks" && pwd)"
GATE="$HOOKS_DIR/verify-gate.sh"
CLEANUP="$HOOKS_DIR/session-cleanup.sh"
fails=0

run_gate() { # $1=tmpdir — feeds Stop-hook JSON on stdin, stderr captured
  printf '{"hook_event_name":"Stop","cwd":"%s","stop_hook_active":false}' "$1" \
    | "$GATE" >/dev/null 2>"$1/stderr.txt"
}

new_case() { # $1=setup commands, run inside a fresh temp dir; echoes the dir
  local tmp; tmp=$(mktemp -d)
  ( cd "$tmp" && eval "$1" )
  echo "$tmp"
}

check() { # $1=name $2=expected $3=actual
  if [ "$2" = "$3" ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 — expected $2, got $3"
    fails=$((fails + 1))
  fi
}

# 1. Gate not armed → allow stop immediately.
t=$(new_case "true")
run_gate "$t"; check "disarmed gate allows stop" 0 $?

# 2. Armed, verify passes → allow stop and disarm.
t=$(new_case "mkdir .loop && touch .loop/active && echo 'true' > .loop/verify")
run_gate "$t"; check "passing verify allows stop" 0 $?
[ ! -f "$t/.loop/active" ]; check "passing verify disarms gate" 0 $?

# 3. Verify-before-escalate: passing verify with a stale maxed counter still allows stop.
t=$(new_case "mkdir .loop && touch .loop/active && echo 'true' > .loop/verify && echo 3 > .loop/blocks")
run_gate "$t"; check "stale counter with passing verify allows stop" 0 $?

# 4. Armed, verify fails → block (exit 2), counter incremented to 1.
t=$(new_case "mkdir .loop && touch .loop/active && echo 'false' > .loop/verify")
run_gate "$t"; check "failing verify blocks stop" 2 $?
check "blocks counter incremented" "1" "$(cat "$t/.loop/blocks")"

# 5. Third consecutive failure → final block that disarms and demands a FAILURE report.
t=$(new_case "mkdir .loop && touch .loop/active && echo 'false' > .loop/verify && echo 2 > .loop/blocks")
run_gate "$t"; check "third failure still blocks" 2 $?
[ ! -f "$t/.loop/active" ]; check "third failure disarms gate" 0 $?
grep -q "FAILURE report" "$t/stderr.txt"; check "third failure demands FAILURE report" 0 $?

# 6. Malformed/missing verify file while armed → fail safe: allow stop (never trap the user).
t=$(new_case "mkdir .loop && touch .loop/active")
run_gate "$t"; check "missing verify file allows stop" 0 $?

# 7. Backtick residue from sloppy extraction is stripped, not treated as command substitution.
t=$(new_case "mkdir .loop && touch .loop/active && printf '%s\n' '\`true\`' > .loop/verify")
run_gate "$t"; check "backtick-wrapped verify still runs" 0 $?

# 8. SessionStart cleanup clears stale gate state.
t=$(new_case "mkdir .loop && touch .loop/active && echo 2 > .loop/blocks")
printf '{"hook_event_name":"SessionStart","cwd":"%s"}' "$t" | "$CLEANUP" >/dev/null 2>&1
check "session cleanup exits 0" 0 $?
[ ! -f "$t/.loop/active" ] && [ ! -f "$t/.loop/blocks" ]; check "session cleanup removes gate state" 0 $?

[ "$fails" -eq 0 ] && echo "ALL PASS" || { echo "$fails FAILURES"; exit 1; }
