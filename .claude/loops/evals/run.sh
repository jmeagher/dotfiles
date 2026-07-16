#!/usr/bin/env bash
# run.sh — driver for the code-loop eval harness.
#
# Runs each fixture scenario against a model by invoking the real `claude`
# CLI, scores the run via lib.sh helpers, and writes per-run result JSON to
# results/<model>/<fixture>.json. A cross-model scorecard is produced with
# --report.
#
# Usage:
#   run.sh [--model <id>]   run every fixture against ONE model
#                           (default: first line of models.txt)
#   run.sh --all            run the full fixture x model matrix over models.txt
#   run.sh --report         print the cross-model scorecard from results/
#
# NOTE: scenario execution and scorecard are implemented in later TODO items;
# this stub documents the interface and prints usage.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
. "$here/lib.sh"

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }

usage
