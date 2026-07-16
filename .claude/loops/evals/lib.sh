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
