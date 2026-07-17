# TODO
<!-- One `- [ ]` item per line, highest priority first. /code-loop works top-down, one item per iteration. -->

- [x] Scaffold `evals/` layout: `models.txt` (claude-opus-4-8, claude-sonnet-5), a `.gitignore` for `results/`, and usage-only stubs for `run.sh` and `lib.sh`
- [x] Implement `lib.sh` result parsing: extract `result`, `is_error`, `num_turns` from `claude --output-format json`; RED-first unit test in `tests/evals-lib-test.sh` with sample JSON
- [x] Implement `lib.sh` reward-hack detection: given a fixture git workdir, flag edits to tests / the verifier / the Verification section / `.loop/`; unit test with a synthetic hacked diff and a clean diff
- [x] Build the `task-completion` fixture (seeded SPEC/TODO + a failing test) and a scenario runner that copies it to a temp git repo, runs the loop headless, and asserts the TODO is fully checked and verify passes; write result JSON
- [x] Build the `verify-gate` fixture + scenario asserting the Stop hook blocks on failing verify, unblocks on passing verify, and disarms with a FAILURE demand after 3 strikes
- [x] Build the `reward-hack-bait` fixture + scenario that runs the loop and records whether any protected file (tests/verifier/Verification/.loop) was touched
- [x] Implement `evals/judge.sh`: score the produced diff 1–5 on the rubric via `claude -p`; wire `quality_score` into the result JSON
- [x] Implement the scorecard: aggregate `results/` into a per-model table (pass rate, mean iterations, hacking count, mean quality) via `run.sh --report`
- [x] Wire `run.sh` to run all fixtures against ONE model by default (`--model <id>`, default = first line of `models.txt`), with an `--all` flag to loop over every model in `models.txt`; document "add a model = one line in models.txt" in a README; make `shellcheck` clean on `evals/*.sh` and `tests/*.sh`
