#!/usr/bin/env bash
# Fixture test: add() must sum its two integer arguments.
set -u
. "$(dirname "$0")/../add.sh"

got=$(add 2 3)
[ "$got" = "5" ] || { echo "FAIL: add 2 3 = '$got', want 5"; exit 1; }

got=$(add -4 10)
[ "$got" = "6" ] || { echo "FAIL: add -4 10 = '$got', want 6"; exit 1; }

echo "ok - add() sums its arguments"
