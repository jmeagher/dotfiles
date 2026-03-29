---
allowed-tools: Bash(git branch:*), Bash(git switch:*), Bash(git checkout:*), Bash(git pull:*), Bash(git symbolic-ref:*)
description: Switch to the default branch (main or master) and pull the latest changes
---

## Context

- Current branch: !`git branch --show-current`
- Default branch: !`git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || git branch -r | grep -E 'origin/(main|master)$' | head -1 | sed 's|.*origin/||' | tr -d ' '`

## Your task

Switch to the default branch and pull the latest changes.

1. If already on the default branch, skip the switch and just pull.
2. Use `git switch <branch>` to change branches (fall back to `git checkout <branch>` if git is older than 2.23).
3. Run `git pull` to fetch and merge the latest remote changes.
4. Report what branch you switched from (if any) and confirm the pull completed.

Do only these steps — no other actions.
