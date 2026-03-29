---
allowed-tools: Bash(git worktree list:*), Bash(ls:*), Bash(git branch:*)
description: List all active git worktrees for this repository
---

## Context

- Worktrees: !`git worktree list`

## Your task

List all active git worktrees. For each one show:

1. **Path** — full path to the worktree
2. **Branch** — the branch checked out there
3. **Type** — "main worktree" or "linked worktree"
4. **Location** — flag as "expected" if under `~/.worktrees/`, or "unusual location" if elsewhere (per project conventions, linked worktrees should live in `~/.worktrees/`)

If there is only the main worktree, say so clearly.

Do only this — no other actions.
