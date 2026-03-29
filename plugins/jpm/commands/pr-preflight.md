---
allowed-tools: Bash(git remote:*), Bash(git branch:*), Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(git symbolic-ref:*), Bash(grep:*), Bash(sed:*), Bash(tr:*), Bash(head:*), Bash(wc:*)
description: Pre-flight check before creating a PR/MR — validates branch, commit scope, platform, and working tree state
---

## Context

- Remote: !`git remote -v`
- Current branch: !`git branch --show-current`
- Default branch: !`git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed "s|refs/remotes/origin/||" || git branch -r | grep -E "origin/(main|master)" | head -1 | sed "s|.*origin/||" | tr -d " "`
- Uncommitted changes: !`git status --short`
- Commits to include: !`git log --oneline $(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed "s|refs/remotes/origin/||" || echo main)..HEAD 2>/dev/null || git log --oneline main..HEAD 2>/dev/null || echo "(could not determine)"`
- Files changed: !`git diff --stat $(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed "s|refs/remotes/origin/||" || echo main)..HEAD 2>/dev/null || echo "(could not determine)"`
- Remote tracking: !`git branch -vv --list "$(git branch --show-current)"`

## Your task

Run a pre-flight check and print a PASS / WARN / FAIL verdict for each item:

1. **Branch** — FAIL if on the default branch (never open a PR from main/master). PASS if on a feature branch.
2. **Uncommitted changes** — WARN if dirty working tree; those changes won't be in the PR.
3. **Commit scope** — List the commits included. WARN if zero commits. WARN if commit messages look unrelated to each other (mixed concerns).
4. **Platform** — Detect from remote URL and state the exact create command: `gh pr create` (GitHub) or `glab mr create` (GitLab).
5. **Remote sync** — WARN if the branch has not been pushed to origin yet (no upstream tracking branch).

Print a final verdict line:
- **READY** — all checks pass
- **NEEDS ATTENTION** — warnings only, can proceed with care
- **BLOCKED** — one or more failures, resolve before opening PR

Do only this — no other actions.
