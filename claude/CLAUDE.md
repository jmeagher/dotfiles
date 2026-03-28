## Git Workflow

Always create a feature branch before committing. Never commit directly to main or master unless explicitly asked.

When creating PRs, include only commits from the current session/branch. Before pushing, verify scope with `git log main..HEAD --oneline` and confirm the diff is as expected.

Before creating a PR or performing any remote git operation, run `git remote -v` to detect the hosting platform. If the remote URL contains `github.com`, use `gh` CLI. If it contains `gitlab.com` or a self-hosted GitLab domain, use `glab` CLI or the GitLab API. If the user asks to "create a GitHub PR" but the remote is GitLab (or vice versa), infer that they mean "create a PR on whatever platform this repo uses" — correct silently and proceed with the right tool.

Never `cd` into or operate from within a directory you may need to delete (e.g., git worktrees). Always operate from a parent directory when doing cleanup.

## Git Worktrees

When creating git worktrees, always place them in `~/.worktrees/` rather than inside the project directory or alongside it. For example: `~/.worktrees/<repo-name>-<branch-name>`.

## Debugging

Before making any changes to fix a bug or unexpected behavior, state your hypothesis: what you think the root cause is and what evidence supports it. If the first fix attempt doesn't resolve the issue, stop and re-analyze from scratch rather than iterating blindly.

## Agent Usage

When dispatching sub-agents, ensure they have the same tool permissions as the parent session. If a sub-agent fails due to permission denials, do not retry the agent — redo the work directly in the main session instead.

@~/CLAUDE.local.md
