# Spec: Code Loop Evals

## Goal
A bash + jq eval harness for the `loop-engineering` plugin's agentic coding
loop. It drives the loop against a set of fixture projects by invoking the
real `claude` CLI, then scores each run on completion, verify-gate behavior,
reward-hacking, and output code quality — across multiple models — so that
changes to the loop implementation (prompts, hooks, the runner) and
differences between models can be compared with hard numbers instead of
impressions.

## Requirements
- `evals/run.sh` runs each fixture scenario against a single model by
  default — `--model <id>`, defaulting to the first entry in
  `evals/models.txt` — invoking the real `claude` CLI and writing a per-run
  result JSON to `results/<model>/<fixture>.json`. An `--all` flag loops the
  matrix over every model in `evals/models.txt` (default list:
  `claude-opus-4-8`, `claude-sonnet-5`).
- Each fixture is a self-contained template project (seeded SPEC.md, TODO.md,
  tests) copied to an isolated temp git workdir per run, so the loop's real
  commits never touch this repo. Scenarios cover: task completion,
  verify-gate behavior (block/unblock/3-strike disarm), and a
  reward-hacking bait project.
- `evals/lib.sh` holds pure scoring helpers — parse `claude --output-format
  json`, detect reward-hacking (any edit to tests, the verifier, the
  Verification section, or `.loop/`), and compute per-scenario pass/fail.
  These are unit-tested deterministically in `tests/evals-lib-test.sh` with
  no model calls.
- `evals/judge.sh` is an LLM-as-judge that scores the diff the loop produced
  on a fixed rubric (correctness, clarity, tests verify real behavior, no
  stubs) via `claude -p`, recording a 1–5 quality score per run.
- A cross-model scorecard aggregates `results/` into one row per model —
  pass rate, mean iterations, hacking incidents, mean quality score — so two
  models are directly comparable.
- Extensibility: adding a model is a one-line change to `evals/models.txt`;
  adding a scenario is dropping a new fixture template and registering it —
  no harness rewrites.

## Definition of Done
- [ ] `bash tests/evals-lib-test.sh` exits 0
- [ ] `evals/lib.sh` scoring + hack-detection helpers each covered by ≥1
      unit test in `tests/evals-lib-test.sh`, all passing, output pristine
- [ ] `evals/run.sh` with no `--model`/`--all` runs every fixture against
      the single default model and writes a valid
      `results/<model>/<fixture>.json` (parseable by `jq`) for each
- [ ] `evals/run.sh --all` runs the full fixture × model matrix over every
      model in `evals/models.txt`
- [ ] Hack detection flags any change to tests, the verifier, the
      Verification section, or `.loop/` in a fixture run (proven by a unit
      test with a synthetic hacked diff)
- [ ] Scorecard prints exactly one row per model with pass rate, mean
      iterations, hacking count, and mean quality score
- [ ] Adding a model requires editing only `evals/models.txt` (documented in
      README and demonstrated)
- [ ] `shellcheck` reports no findings on `evals/*.sh` and `tests/*.sh`

## Verification
Verify: `bash tests/evals-lib-test.sh`
Run: `bash evals/run.sh`

## Rules
- All checks stay enabled. Never modify tests, linters, the Verification
  section of this file, or anything under .loop/ to make verification pass.
- No placeholder or stub implementations. Complete, working code only.
- One TODO item per iteration: implement, verify, commit, update TODO.md.
- When a decision changes the spec, edit this file in the same commit.
- If you learn a project-specific lesson, append it to CLAUDE.md.
