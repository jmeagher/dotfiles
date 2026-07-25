# Multi-Harness Orchestrator Framework — Design

**Date:** 2026-07-25
**Status:** Approved for planning

## Purpose

A reusable, portable framework of four cooperating agents — Orchestrator,
Worker, Reviewer, Consultant — that work together across at least three
coding harnesses (Claude Code, OpenCode, Cursor). Authored once in this repo
under `ai/orchestrator-framework/`, installed user-wide via this repo's
existing symlink-based `setup.sh` convention (same pattern as
`~/.claude/CLAUDE.md`), so the agents are available in every project the
user opens, not scoped to one repo.

## Non-goals

- Not a Claude Code plugin package (it must also work in OpenCode and
  Cursor, which have no plugin marketplace concept in common with Claude
  Code's).
- Not a fully-automated Cursor experience — Cursor's hand-off is manual by
  design (see "Known limitations").
- No file-locking / concurrency control for simultaneous multi-session use
  of one project's task queue — single active orchestrating session per
  project is the assumed use case.

## 1. Repository layout & install model

```
ai/orchestrator-framework/
  agents/
    orchestrator.yaml       # role, prompt, tool policy, default model tier
    worker.yaml
    reviewer.yaml
    consultant.yaml
  models.yaml                # tier -> concrete model id, per harness (checked in defaults)
  models.local.yaml.example  # override template; user copies to models.local.yaml (gitignored)
  queue.py                   # shared CLI: append/status/next-task against tasks.jsonl
  generate.py                # reads agents/*.yaml + models.yaml(+local) -> writes dist/
  dist/
    claude-code/.claude/agents/{orchestrator,worker,reviewer,consultant}.md
    opencode/.config/opencode/agent/{orchestrator,worker,reviewer,consultant}.md
    cursor/modes.json         # best-effort output, see "Known limitations"
  setup.sh                    # symlinks dist/ outputs into the harnesses' global config locations
  tests/
    test_queue.py
    test_generate.py
  README.md
```

This repo's root `setup.sh` gains a call to `ai/orchestrator-framework/setup.sh`,
mirroring the existing call to `claude/setup.sh`.

Runtime state is never symlinked — it's created fresh, per project, on first
use:

```
<any-project>/.orchestrator/tasks.jsonl   # gitignored
```

## 2. Task queue protocol (the cross-harness bridge)

`.orchestrator/tasks.jsonl` is an **append-only event log**. Every hand-off
appends one line; nothing is ever rewritten or deleted. A task's current
state is derived by folding: the last line with a given `id` wins.

Event shape (one JSON object per line):

```json
{"id":"t1","event":"created","desc":"...","assigned_to":"worker","parent_id":null,"created_by":"orchestrator"}
{"id":"t1","event":"in_progress"}
{"id":"t1","event":"completed","result":"...","spawned":["t2","t3"]}
{"id":"t2","event":"created","desc":"...","assigned_to":"reviewer","parent_id":"t1","created_by":"worker"}
```

Event types: `created`, `in_progress`, `completed`, `blocked` (needs
orchestrator/human input to unblock). `spawned` is not a separate event —
it's a field on a `completed` event listing new task ids that must also have
their own `created` events appended (with `parent_id` set to the task that
spawned them).

`queue.py` is the only thing that ever touches `tasks.jsonl` — no agent
hand-writes raw JSON lines. Subcommands:

- `queue.py append <event-json>` — validates the event against the schema
  above (known `event` value, required fields for that event type), appends
  one line, refuses malformed input.
- `queue.py status` — folds the whole log, prints current state per task
  (id, status, assigned_to, and its parent chain).
- `queue.py next --for <role>` — returns the oldest task that is `created`
  but not yet `in_progress` and assigned to `<role>`, or nothing if none.

Each harness's Orchestrator agent gets Bash access **scoped to `queue.py`
only** (e.g., Claude Code's `Bash(python3 .orchestrator/queue.py *)` tool
permission pattern) — never general Bash, and no direct Read/Write on
`tasks.jsonl` either, since `queue.py status`/`next` already surface
everything the Orchestrator needs via stdout. This is the entirety of the
Orchestrator's tool access — organizing the other agents through the queue
is all it can do. Worker has unrestricted Bash regardless, so `queue.py` is
just one more command it can run. Reviewer keeps its own general Bash
(needed for tests/linters/build) which likewise already covers `queue.py`.
Consultant has no *general* Bash, but does get Bash scoped to `queue.py`
only — the same restricted grant as the Orchestrator — so it can report
its plan back without gaining the ability to run arbitrary commands.

For Cursor: the human switches Custom Mode and manually runs
`queue.py next --for <role>` / `queue.py append ...` in a terminal between
mode switches. Same file, same schema, same script — only the hand-off
mechanism differs (manual vs. programmatic).

## 3. The four agents

| Agent | Tools | Default tier | Job |
|---|---|---|---|
| **Orchestrator** | `Bash` scoped to `queue.py` only, plus the harness's subagent-invocation tool (Task in Claude Code, its equivalent in OpenCode; manual in Cursor) — no Read/Write/Edit, no general Bash | high | Talks to the end user, breaks their problem into tasks, calls `queue.py next --for <role>` to pick the next task for whichever agent should run it, invokes that agent, reads back its `completed` event (including any `spawned` children), and decides what's next. Never reads/writes project source directly. |
| **Worker** | Unrestricted (all tools) | low | The only agent that edits code. Picks up one task at a time, does the read/write implementation work, appends a `completed` event with a `result` summary and any follow-up tasks it thinks are needed via `spawned`. |
| **Reviewer** | Read, Grep, Glob, general `Bash` (tests/linters/build, which also covers `queue.py`) — no Edit/Write to source | medium | Invoked at the Orchestrator's judgment (not automatically on every task). Inspects a completed task's diff/output, runs relevant checks, and reports findings as new `created` tasks assigned back to `worker` rather than fixing anything itself. |
| **Consultant** | Read, Grep, Glob, web search/fetch, `Bash` scoped to `queue.py` only — no general Bash, no Edit/Write | high | Invoked for architecture/planning decisions. Produces a plan or decision as its `completed` result — typically a set of ordered `spawned` tasks assigned to `worker` — but never touches code itself. |

Review is **not** an automatic gate after every Worker task — the
Orchestrator (running at the `high` tier) decides case-by-case whether a
given task's output warrants a Reviewer pass.

## 4. Model tier configuration

`models.yaml` maps `tier -> harness -> model id`. Only Claude Code ships
with confident defaults — OpenCode and Cursor model availability depends on
the user's own provider/plan configuration there, so those start as `null`
placeholders filled in once via `models.local.yaml` (gitignored, same
override convention as `CLAUDE.local.md`).

```yaml
# models.yaml (checked in — shipped defaults)
tiers:
  claude-code:
    high: claude-opus-4-8
    medium: claude-sonnet-5
    low: claude-haiku-4-5-20251001
  opencode:
    high: null
    medium: null
    low: null
  cursor:
    high: null
    medium: null
    low: null
```

```yaml
# models.local.yaml (gitignored, user-provided example)
tiers:
  opencode:
    high: anthropic/claude-opus-4-8
    medium: anthropic/claude-sonnet-5
    low: anthropic/claude-haiku-4-5
  cursor:
    high: claude-4.8-opus
    medium: claude-4.8-sonnet
    low: claude-4.5-haiku
```

`generate.py` deep-merges `models.local.yaml` over `models.yaml` (local
wins per key), resolves each agent's declared tier (from `agents/*.yaml`) to
a concrete model id per harness, and **fails loudly** at generation time —
non-zero exit, explicit message naming the missing harness/tier — if a
required combination is still `null`, rather than silently shipping an
agent with no model set.

## 5. Harness adapters & known limitations

`generate.py` has one adapter function per harness, translating the neutral
`agents/*.yaml` fields (`name`, `description`, `prompt`, `tools`,
resolved `model`) into that harness's native shape:

- **Claude Code** → `.claude/agents/<name>.md`, YAML frontmatter (`name`,
  `description`, `tools`, `model`) + prompt body. Well-documented format,
  high confidence.
- **OpenCode** → equivalent markdown-with-frontmatter agent file under
  `.config/opencode/agent/`. Close enough to Claude Code's convention that
  the adapter is structurally near-identical.
- **Cursor** → `modes.json` following Cursor's custom-mode schema (name,
  prompt, tool restrictions, model).

**Known limitation, flagged rather than guessed:** Cursor's current
on-disk storage path/format for Custom Modes is not confirmed, nor whether
Cursor reads custom modes from a plain project-relative file the way the
other two harnesses read agent definitions. `generate.py` produces
`modes.json` in Cursor's documented schema as a best-effort artifact;
wiring it into a live Cursor install may require a manual import step the
first time, until verified against a real Cursor instance. This is
consistent with the earlier decision that Cursor is the file-based-bridge,
human-mediated harness rather than a fully automated one.

## 6. Error handling & edge cases

- `queue.py append` validates the event against the schema (known `event`
  values, required fields per event type) and refuses malformed writes
  rather than corrupting the log.
- Orphaned tasks (assigned to a role, never picked up) are visible via
  `queue.py status`. There is no automatic timeout/retry — resolving a
  stuck task is the Orchestrator's judgment call, not framework logic.
- `generate.py` fails loudly on: unresolvable model tier/harness
  combination, unknown tool name in an `agents/*.yaml`, malformed YAML.
- Concurrent writers to `tasks.jsonl`: append-only, single-line writes mean
  the worst case under concurrent access is interleaved lines from two
  processes — each individually still valid JSON, no file corruption. No
  locking is implemented; the framework assumes one active orchestrating
  session per project at a time.

## 7. Testing plan

- Unit tests (`pytest`) for `queue.py`: append validation (rejects
  malformed events, accepts valid ones), status folding (last-event-wins
  per id), next-task selection (oldest unclaimed task for a role).
- Unit tests for `generate.py` adapters: given a fixed `agents/*.yaml` +
  `models.yaml` fixture, assert exact Claude Code/OpenCode output files;
  Cursor output checked structurally only (per the §5 caveat).
- No automated test for actual multi-agent hand-off behavior — that
  requires a live harness session. The README documents a manual
  smoke-test walkthrough instead, the same way loop-engineering's `tests/`
  cover hook/gate logic while the loop itself is exercised manually.
