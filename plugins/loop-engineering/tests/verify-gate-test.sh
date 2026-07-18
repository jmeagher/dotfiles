#!/usr/bin/env bash
# shellcheck disable=SC2319,SC2015
# SC2319: Intentional pattern — test harness deliberately captures $? from [ ... ] test to feed check().
# SC2015: Intentional pattern — final line uses [ ... ] && echo ... || { ...; exit 1; } for control flow.
# Tests for verify-gate.sh and session-cleanup.sh. Each case runs in its own temp dir.
# Gate state is per-project: .loop/<project>/{active,verify,blocks}.
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

arm() { # $1=project $2=verify command — helper used inside new_case setups
  mkdir -p ".loop/$1" && touch ".loop/$1/active" && printf '%s\n' "$2" > ".loop/$1/verify"
}

check() { # $1=name $2=expected $3=actual
  if [ "$2" = "$3" ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 — expected $2, got $3"
    fails=$((fails + 1))
  fi
}

# 1. No project armed → allow stop immediately.
t=$(new_case "true")
run_gate "$t"; check "disarmed gate allows stop" 0 $?

# 2. Armed project, verify passes → allow stop and disarm that project.
t=$(new_case "$(declare -f arm); arm alpha 'true'")
run_gate "$t"; check "passing verify allows stop" 0 $?
[ ! -f "$t/.loop/alpha/active" ]; check "passing verify disarms project" 0 $?

# 3. Verify-before-escalate: passing verify with a stale maxed counter still allows stop.
t=$(new_case "$(declare -f arm); arm alpha 'true' && echo 3 > .loop/alpha/blocks")
run_gate "$t"; check "stale counter with passing verify allows stop" 0 $?

# 4. Armed, verify fails → block (exit 2), counter incremented to 1, message names the project.
t=$(new_case "$(declare -f arm); arm alpha 'false'")
run_gate "$t"; check "failing verify blocks stop" 2 $?
check "blocks counter incremented" "1" "$(cat "$t/.loop/alpha/blocks")"
grep -q "alpha" "$t/stderr.txt"; check "block message names the project" 0 $?

# 5. Third consecutive failure → final block that disarms and demands a FAILURE report.
t=$(new_case "$(declare -f arm); arm alpha 'false' && echo 2 > .loop/alpha/blocks")
run_gate "$t"; check "third failure still blocks" 2 $?
[ ! -f "$t/.loop/alpha/active" ]; check "third failure disarms project" 0 $?
grep -q "FAILURE report" "$t/stderr.txt"; check "third failure demands FAILURE report" 0 $?

# 6. Malformed/missing verify file while armed → fail safe: allow stop (never trap the user).
t=$(new_case "mkdir -p .loop/alpha && touch .loop/alpha/active")
run_gate "$t"; check "missing verify file allows stop" 0 $?

# 7. Backtick residue from sloppy extraction is stripped, not treated as command substitution.
t=$(new_case "$(declare -f arm); arm alpha '\`true\`'")
run_gate "$t"; check "backtick-wrapped verify still runs" 0 $?

# 8. Two projects armed: passing one disarms, failing one blocks independently.
t=$(new_case "$(declare -f arm); arm alpha 'true' && arm beta 'false'")
run_gate "$t"; check "one failing project blocks stop" 2 $?
[ ! -f "$t/.loop/alpha/active" ]; check "passing project disarmed" 0 $?
[ -f "$t/.loop/beta/active" ]; check "failing project stays armed" 0 $?
check "failing project counter incremented" "1" "$(cat "$t/.loop/beta/blocks")"

# 9. Two projects armed, both pass → allow stop, both disarmed.
t=$(new_case "$(declare -f arm); arm alpha 'true' && arm beta 'true'")
run_gate "$t"; check "all projects passing allows stop" 0 $?
[ ! -f "$t/.loop/alpha/active" ] && [ ! -f "$t/.loop/beta/active" ]; check "all passing projects disarmed" 0 $?

# 10. SessionStart cleanup clears stale gate state for every project.
t=$(new_case "$(declare -f arm); arm alpha 'true' && echo 2 > .loop/alpha/blocks && arm beta 'false'")
printf '{"hook_event_name":"SessionStart","cwd":"%s"}' "$t" | "$CLEANUP" >/dev/null 2>&1
check "session cleanup exits 0" 0 $?
[ ! -f "$t/.loop/alpha/active" ] && [ ! -f "$t/.loop/alpha/blocks" ] && [ ! -f "$t/.loop/beta/active" ]
check "session cleanup removes all projects' gate state" 0 $?

[ "$fails" -eq 0 ] && echo "ALL PASS" || { echo "$fails FAILURES"; exit 1; }
