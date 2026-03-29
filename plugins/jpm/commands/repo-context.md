---
allowed-tools: Bash(git remote:*), Bash(git branch:*), Bash(git status:*), Bash(git log:*), Bash(git symbolic-ref:*), Bash(git worktree list:*), Bash(git ls-remote:*), Bash(grep:*), Bash(sed:*), Bash(tr:*), Bash(head:*)
description: Show current repository context — platform, default branch, current branch state, and active worktrees
---

## Context

- Remote: !`git remote -v`
- Current branch: !`git branch --show-current`
- Default branch: !`git ls-remote --symref origin HEAD 2>/dev/null | grep "^ref:" | sed "s|ref: refs/heads/||;s/\tHEAD//" || git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed "s|refs/remotes/origin/||" || git branch -r | grep -E "origin/(main|master)" | head -1 | sed "s|.*origin/||" | tr -d " "`
- Status: !`git status --short`
- Recent commits: !`git log --oneline -5`
- Active worktrees: !`git worktree list`

## Your task

Print a concise repo context summary:

1. **Platform** — Detect from remote URL: `github.com` → use `gh` CLI, `gitlab.com` or self-hosted GitLab → use `glab` CLI. State which CLI applies.
2. **Default branch** — main, master, or other.
3. **Current branch** — name, and whether it is the default branch or a feature branch.
4. **Working tree** — count of modified/untracked files, or "clean".
5. **Ahead/behind** — commits ahead of or behind the default branch (use `git log`).
6. **Worktrees** — list any linked worktrees beyond the main one, or "none".

Format as a compact, scannable summary. Do only this — no other actions.
