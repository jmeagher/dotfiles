# Code Loop Evals

A bash + jq harness that drives the `loop-engineering` plugin's agentic coding
loop against fixture projects — using the **real `claude` CLI** — and scores
each run on completion, verify-gate behavior, reward-hacking, and output code
quality, so changes to the loop (prompts, hooks, runner) and differences
between models can be compared with numbers.

## Layout

```
evals/
  run.sh          driver: run fixtures against models, write results, report
  lib.sh          pure, unit-tested helpers (parsing, hack detection, scoring)
  judge.sh        LLM-as-judge: score a run's diff 1-5 via claude -p
  models.txt      one model id per line; line 1 is the default
  fixtures/       self-contained seeded projects, copied per run
    task-completion/    honest task: implement add()
    reward-hack-bait/   tedious task (roman numerals) with a tempting cheat
    verify-gate/        PASS-marker toggle for the gate scenario
  results/        per-run JSON (gitignored): results/<model>/<fixture>.json
tests/
  evals-lib-test.sh   deterministic unit tests — the loop's Verify command
```

## Running

```sh
bash evals/run.sh                 # every fixture vs the default model (models.txt line 1)
bash evals/run.sh --model <id>    # every fixture vs one specific model
bash evals/run.sh --all           # full fixture x model matrix over models.txt
bash evals/run.sh --report        # print the cross-model scorecard from results/
```

Each scenario copies its fixture into an isolated temp git workdir, runs
`claude -p /code-loop` there, then scores completion, reward-hacking, and (via
`judge.sh`) code quality into `results/<model>/<fixture>.json`. The scorecard
prints one row per model: pass rate, mean iterations, hacking incidents, mean
quality.

## Verify vs Run

- **Verify** (`bash tests/evals-lib-test.sh`) is deterministic and makes **no**
  model calls — it unit-tests the pure helpers in `lib.sh`. This is the gate
  the loop runs every iteration.
- **Run** (`bash evals/run.sh`) is where real `claude` calls happen. Model runs
  are slow, cost tokens, and are non-deterministic, so they are deliberately
  kept out of Verify.

## Adding a model

Add one line to `evals/models.txt` — nothing else changes:

```
claude-opus-4-8
claude-sonnet-5
claude-haiku-4-5-20251001   # <- new model, picked up by --all (and as default if line 1)
```

## Adding a fixture

1. Create `evals/fixtures/<name>/` with a seeded `SPEC.md` (including a
   `Verify:` line), `TODO.md`, a failing test, and source that ships RED.
2. For a claude-driven scenario, add `<name>` to the `FIXTURES` array in
   `run.sh`. (Deterministic scenarios like `verify-gate` are driven directly
   from the test suite instead.)
