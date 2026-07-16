#!/usr/bin/env bash
# judge.sh — LLM-as-judge. Scores the diff a fixture run produced (baseline..HEAD)
# from 1-5 via a real `claude -p` call, and prints the integer score (or "null").
#
# Usage: judge.sh <workdir> <baseline_ref> [--model <id>]
#
# The model call lives here (Run path); the prompt builder and score parser it
# uses (eval_judge_prompt / eval_parse_score) are unit-tested in lib.sh.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
# shellcheck disable=SC1091
. "$here/lib.sh"

wd="${1:?judge.sh: workdir required}"
base="${2:?judge.sh: baseline ref required}"
shift 2
model=$(head -n1 "$here/models.txt")
[ "${1:-}" = "--model" ] && model="${2:?judge.sh: --model needs an id}"

command -v claude >/dev/null || { echo "null"; exit 0; }

diff=$(git -C "$wd" diff "$base" HEAD 2>/dev/null || true)
if [ -z "$diff" ]; then echo "null"; exit 0; fi

prompt=$(printf '%s' "$diff" | eval_judge_prompt)
printf '%s' "$prompt" \
  | claude -p --model "$model" --output-format json 2>/dev/null \
  | eval_result_text \
  | eval_parse_score
