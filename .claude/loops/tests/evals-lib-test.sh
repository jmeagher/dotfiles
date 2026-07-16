#!/usr/bin/env bash
# Unit tests for the code-loop eval harness: the evals/ scaffold and the pure
# scoring helpers in evals/lib.sh. Deterministic — makes NO `claude` calls.
# This is the loop's Verify command (SPEC.md ## Verification).
set -u

here=$(cd "$(dirname "$0")" && pwd)
loops_dir=$(dirname "$here")
evals="$loops_dir/evals"

# Library under test. Guarded so the scaffold-existence assertions below still
# run (and report a clean FAIL) if lib.sh is somehow absent.
[ -f "$evals/lib.sh" ] && . "$evals/lib.sh"

pass=0
fail=0

assert_file() { # path desc
  if [ -f "$1" ]; then
    pass=$((pass + 1)); printf 'ok   - %s\n' "$2"
  else
    fail=$((fail + 1)); printf 'FAIL - %s (missing: %s)\n' "$2" "$1"
  fi
}

assert_grep() { # pattern file desc
  if [ -f "$2" ] && grep -Eq "$1" "$2"; then
    pass=$((pass + 1)); printf 'ok   - %s\n' "$3"
  else
    fail=$((fail + 1)); printf 'FAIL - %s (no /%s/ in %s)\n' "$3" "$1" "$2"
  fi
}

assert_eq() { # expected actual desc
  if [ "$1" = "$2" ]; then
    pass=$((pass + 1)); printf 'ok   - %s\n' "$3"
  else
    fail=$((fail + 1)); printf 'FAIL - %s (want [%s] got [%s])\n' "$3" "$1" "$2"
  fi
}

sources_clean() { # path desc — file sources under a fresh bash with no error
  if bash -c '. "$1"' _ "$1" >/dev/null 2>&1; then
    pass=$((pass + 1)); printf 'ok   - %s\n' "$2"
  else
    fail=$((fail + 1)); printf 'FAIL - %s (source error in %s)\n' "$2" "$1"
  fi
}

# --- TODO 1: evals/ scaffold ------------------------------------------------
assert_file "$evals/models.txt" "models.txt exists"
assert_grep '^claude-opus-4-8$'  "$evals/models.txt" "models.txt lists opus"
assert_grep '^claude-sonnet-5$'  "$evals/models.txt" "models.txt lists sonnet"
assert_eq "claude-opus-4-8" "$(head -n1 "$evals/models.txt" 2>/dev/null)" \
  "opus is the default (first) model"
assert_file "$evals/run.sh"  "run.sh exists"
assert_file "$evals/lib.sh"  "lib.sh exists"
sources_clean "$evals/lib.sh" "lib.sh sources cleanly"

# --- TODO 2: parse `claude --output-format json` ---------------------------
ok_json='{"type":"result","subtype":"success","is_error":false,"result":"done","num_turns":4,"session_id":"abc"}'
err_json='{"type":"result","subtype":"error_max_turns","is_error":true,"result":"","num_turns":12}'
no_result_json='{"type":"result","is_error":false,"num_turns":1}'
bad_json='this is not json'

assert_eq "done" "$(printf '%s' "$ok_json"        | eval_result_text)" "result text: success run"
assert_eq ""     "$(printf '%s' "$err_json"       | eval_result_text)" "result text: empty on error run"
assert_eq ""     "$(printf '%s' "$no_result_json" | eval_result_text)" "result text: empty when field absent"
assert_eq ""     "$(printf '%s' "$bad_json"       | eval_result_text)" "result text: empty on non-JSON"

assert_eq "4"  "$(printf '%s' "$ok_json"  | eval_num_turns)" "num_turns: parsed"
assert_eq "12" "$(printf '%s' "$err_json" | eval_num_turns)" "num_turns: parsed on error run"
assert_eq "0"  "$(printf '%s' "$bad_json" | eval_num_turns)" "num_turns: 0 on non-JSON"

assert_eq "false" "$(printf '%s' "$ok_json"  | eval_is_error)" "is_error: false NOT inverted by jq //"
assert_eq "true"  "$(printf '%s' "$err_json" | eval_is_error)" "is_error: true on error run"
assert_eq "true"  "$(printf '%s' "$bad_json" | eval_is_error)" "is_error: true (fail-safe) on non-JSON"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
