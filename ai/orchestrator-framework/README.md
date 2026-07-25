# Multi-Harness Orchestrator Framework

Four cooperating agents — Orchestrator, Worker, Reviewer, Consultant —
authored once and generated into native agent files for Claude Code,
OpenCode, and (best-effort) Cursor. Agents coordinate through a shared
append-only task queue instead of relying on any one harness's specific
subagent-invocation mechanism, so the same protocol works whether the
hand-off is programmatic (Claude Code, OpenCode) or manual (Cursor).

Full design rationale: `docs/superpowers/specs/2026-07-25-orchestrator-framework-design.md`.

## Install

Run from the repo root (this is already wired into the main `setup.sh`):

```bash
sh ai/orchestrator-framework/setup.sh
```

This always generates Claude Code agent files into `~/.claude/agents/` (it
ships real model defaults) and symlinks `queue.py` to `~/bin/orchestrator-queue`
— both available in every project you open afterward, not just this repo.

OpenCode and Cursor output (`~/.config/opencode/agent/`,
`~/.orchestrator-cursor-modes.json`) are **skipped** until you provide model
ids for them — `setup.sh` prints a NOTE and moves on rather than failing.
Copy the example override file, fill in the model ids your setup actually
exposes, then re-run `setup.sh` to generate those two as well:

```bash
cp ai/orchestrator-framework/models.local.yaml.example ai/orchestrator-framework/models.local.yaml
# edit models.local.yaml with your real opencode/cursor model ids
sh ai/orchestrator-framework/setup.sh
```

## Manual smoke test

This exercises the task-queue protocol directly, standing in for the
Orchestrator/Worker hand-off a live harness session would do automatically.
Requires `setup.sh` to have run at least once, so `orchestrator-queue`
resolves on `PATH` (it's a symlink to `queue.py` in `~/bin`). Run from any
project directory (creates `.orchestrator/tasks.jsonl` there):

```bash
# Orchestrator creates a task for the Worker
orchestrator-queue append '{"event":"created","desc":"add a hello-world script","assigned_to":"worker","created_by":"orchestrator"}'

# Worker picks it up
orchestrator-queue next --for worker

# Worker marks it in progress, does the work, then completes it
orchestrator-queue append '{"event":"in_progress","id":"task-001"}'
orchestrator-queue append '{"event":"completed","id":"task-001","result":"created hello.sh","spawned":[]}'

# Orchestrator checks status
orchestrator-queue status
```

Expected: `status` shows `task-001` as `completed`, assigned to `worker`.

If you haven't run `setup.sh` yet, every command above still works by
calling `python3 /path/to/ai/orchestrator-framework/queue.py` instead of
`orchestrator-queue` — the symlink is a convenience, not a requirement.

## Known limitation: Cursor

Cursor's on-disk Custom Mode storage format/path isn't confirmed against a
live install. `~/.orchestrator-cursor-modes.json` is generated in Cursor's
documented custom-mode schema, but importing it into a running Cursor may
require a manual step the first time. Once imported, the human-in-the-loop
workflow is: switch to the relevant Custom Mode, run
`orchestrator-queue next --for <role>` / `append ...` in a
terminal, same as any other harness — just without automatic hand-off.

## Layout

| Path | Role |
|---|---|
| `agents/*.yaml` | Neutral agent source: role, prompt, tool policy, default model tier |
| `models.yaml` | `harness -> tier -> model id`; Claude Code ships real defaults, OpenCode/Cursor start `null` |
| `models.local.yaml` | Gitignored per-machine override, filled in from `models.local.yaml.example` |
| `queue.py` | Dependency-free CLI implementing the task-queue protocol; symlinked to `~/bin/orchestrator-queue` by `setup.sh` so agent prompts can call it as a bare command from any project |
| `generate.py` | Reads `agents/*.yaml` + `models.yaml`(+local), writes harness-native agent files directly into place |
| `setup.sh` | Symlinks `queue.py` to `~/bin/orchestrator-queue` (always) and runs `generate.py` into `~/.claude/agents` (always) plus `~/.config/opencode/agent` and a Cursor modes file (only once `models.local.yaml` exists) |
