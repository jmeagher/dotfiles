#!/usr/bin/env bash
# lib.sh — pure scoring/parsing helpers for the code-loop eval harness.
# Sourced by run.sh, judge.sh, and the unit tests. Contains NO top-level
# side effects and makes NO `claude` calls, so it is safe to source anywhere
# and its functions are unit-testable with synthetic inputs.
#
# Functions are added here per TODO item (result parsing, hack detection,
# scoring). This header stub exists so the scaffold is sourceable from the
# first iteration.

LIB_EVALS_VERSION="0.1.0"

# --- Parsing `claude --output-format json` ---------------------------------
# Each reads one JSON object on stdin. All fail safe on malformed input: a run
# we cannot parse is treated as a non-completing error, never as a silent pass.

# Final assistant text (.result), empty string if absent or unparseable.
eval_result_text() {
  jq -r '.result // ""' 2>/dev/null || true
}

# Turn count (.num_turns) as a non-negative integer; 0 if absent/unparseable.
eval_num_turns() {
  local n
  n=$(jq -r '.num_turns // 0' 2>/dev/null) || n=0
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  printf '%s\n' "$n"
}

# "true"/"false" for whether the run errored. Guards the jq `//` pitfall
# (false // true == true) by testing presence, and fails safe to "true" when
# is_error is absent or the input is not valid JSON.
eval_is_error() {
  local v
  v=$(jq -r 'if has("is_error") then (.is_error | tostring) else "true" end' 2>/dev/null) \
    || v="true"
  [ -n "$v" ] || v="true"
  printf '%s\n' "$v"
}
