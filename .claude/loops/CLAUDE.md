# Code Loop Evals — Project Notes

## Lessons

- **`.loop/` is gitignored, so git-diff cannot detect `.loop/` tampering.**
  The loop writes `.loop/.gitignore` = `*`, and this machine's global
  gitignore also drops all dotfiles. Reward-hack detection therefore splits
  in two: `eval_hack_reasons` (git diff) covers tracked protected paths
  (tests, verifier, the SPEC `## Verification` section); `eval_verify_tampered`
  compares a **before/after snapshot** of the armed verify command for the
  untracked `.loop/verify` case. Scenario runners MUST snapshot `.loop/verify`
  before the run to use it.
- **Committing dotfiles needs `git add -f`.** The global `.*` ignore rule
  silently skips `evals/.gitignore` and similar; force-add them.
- **Headless `claude -p` does not load plugin slash commands or plugin hooks.**
  A fresh `claude -p` subprocess only loads project-local `.claude/` config and
  plain prompts — `/code-loop` returns "Unknown command", and the Stop-hook
  gate never fires. So `run_scenario` drives the loop with an inline prompt
  (`eval_loop_prompt`), not the slash command. Consequence: the claude-driven
  scenarios measure the model's own loop-following (completion, reward-hacking,
  quality); real Stop-gate enforcement is covered separately by the
  deterministic verify-gate scenario, which drives the hook script directly.
  (The plugin's own `bin/code-loop` uses `claude -p "/code-loop 1"` and has the
  same headless limitation — worth fixing there too.)

## Verify
`bash tests/evals-lib-test.sh` — deterministic, no `claude` calls. This is the
loop's gate. Real model runs happen via `bash evals/run.sh` (the Run command).
