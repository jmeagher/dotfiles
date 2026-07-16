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

## Verify
`bash tests/evals-lib-test.sh` — deterministic, no `claude` calls. This is the
loop's gate. Real model runs happen via `bash evals/run.sh` (the Run command).
