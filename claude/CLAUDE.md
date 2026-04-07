## Git
- Never commit to main/master directly; always use a feature branch.
- PRs: verify scope with `git log main..HEAD --oneline` before pushing.
- Before any remote git op, run `git remote -v`: use `gh` for github.com, `glab` for gitlab.com. If asked for "GitHub PR" but remote is GitLab, use `glab` silently.
- Never `cd` into a directory you may need to delete; operate from its parent.

## Worktrees
Place worktrees in `~/.worktrees/<repo>-<branch>`, never inside or alongside the project.

## Debugging
State your hypothesis (root cause + evidence) before any fix. If the fix fails, re-analyze from scratch — don't iterate blindly.

## Agents
Sub-agents need the same tool permissions as the parent. On permission failure, redo the work in the main session instead of retrying the agent.

## Code Quality
- Correct and complete over minimal.
- Fix root causes, not symptoms.
- Use proper data structures/algorithms.
- Include error handling/validation needed for reliability without asking.

@~/CLAUDE.local.md

