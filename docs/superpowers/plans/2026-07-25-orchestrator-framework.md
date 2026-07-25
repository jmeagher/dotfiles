# Multi-Harness Orchestrator Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reusable framework of four cooperating agents (Orchestrator, Worker, Reviewer, Consultant) authored once as neutral YAML and generated into native Claude Code, OpenCode, and Cursor agent files, coordinating through a shared append-only JSONL task queue.

**Architecture:** A dependency-free `queue.py` CLI implements the append-only task-queue protocol (`created` → `in_progress` → `completed`/`blocked`, folded to current state on read). A `generate.py` script (PyYAML dependency) loads `agents/*.yaml` + `models.yaml`(+local override), resolves each agent's model tier per harness, and writes harness-native agent files directly into place — no committed build output. `setup.sh` wires this into the repo's existing install flow.

**Tech Stack:** Python 3 stdlib (`queue.py`, zero dependencies) + PyYAML (`generate.py` only), `pytest` for tests, POSIX shell for `setup.sh`, spec at `docs/superpowers/specs/2026-07-25-orchestrator-framework-design.md`.

## Global Constraints

- Root directory: `ai/orchestrator-framework/`.
- No `dist/` directory is ever committed — `generate.py` writes agent files directly to whatever `--claude-code-out` / `--opencode-out` / `--cursor-out` paths are passed.
- Runtime task queue lives at `<project>/.orchestrator/tasks.jsonl` in whatever project is being orchestrated (not this repo, unless this repo itself is the target under test) — always gitignored, never symlinked.
- `tasks.jsonl` is an **append-only event log** — lines are never rewritten or deleted; a task's current state is the last line matching its `id`.
- Four agents, each with a fixed default model tier: **Orchestrator = high**, **Worker = low**, **Reviewer = medium**, **Consultant = high**.
- Tool policy per agent (exact, from spec §3):
  - **Orchestrator:** `Bash` scoped to `queue.py` only, plus the harness's subagent-invocation tool. No Read/Write/Edit, no general Bash.
  - **Worker:** unrestricted (all tools).
  - **Reviewer:** Read, Grep, Glob, general Bash (tests/linters/build). No Edit/Write to source.
  - **Consultant:** Read, Grep, Glob, web search/fetch, `Bash` scoped to `queue.py` only. No general Bash, no Edit/Write.
- Reviewer is invoked at the Orchestrator's judgment, never automatically after every Worker task.
- `models.yaml` ships confident defaults only for Claude Code (`claude-opus-4-8` / `claude-sonnet-5` / `claude-haiku-4-5-20251001`); OpenCode and Cursor tiers start `null` and are filled in via gitignored `models.local.yaml`.
- `generate.py` fails loudly (non-zero exit, explicit message) on: an unresolved model tier/harness combination (still `null`), or an `agents/*.yaml` file missing a required field. It does **not** validate tool-name spelling against a harness's tool vocabulary (spec §6 — that list is harness-owned and would go stale).
- No file locking on `tasks.jsonl` — single active orchestrating session per project is the assumed use case.

---

### Task 1: Task-queue core (`queue.py`)

**Files:**
- Create: `ai/orchestrator-framework/queue.py`
- Create: `ai/orchestrator-framework/tests/test_queue.py`
- Create: `ai/orchestrator-framework/.gitignore`

**Interfaces:**
- Consumes: nothing (foundational, stdlib only).
- Produces (consumed by later tasks' README smoke test and by every generated agent's prompt):
  - CLI: `python3 queue.py --queue-dir DIR append '<event-json>'` → exit 0 + prints the saved event as JSON on success, exit 1 + message on stderr on validation failure.
  - CLI: `python3 queue.py --queue-dir DIR status [--json]` → prints current per-task state.
  - CLI: `python3 queue.py --queue-dir DIR next --for <role>` → exit 0 + prints the oldest pending task JSON for that role, or exit 1 if none.
  - Event schema: `{"event": "created", "desc": str, "assigned_to": one of orchestrator/worker/reviewer/consultant, "created_by": str, "parent_id": str|null (optional, defaults null), "id": str (optional, auto-assigned as "task-NNN" if omitted)}`, `{"event": "in_progress", "id": str}`, `{"event": "completed", "id": str, "result": str, "spawned": [str] (optional, defaults [])}`, `{"event": "blocked", "id": str, "reason": str}`.

- [ ] **Step 1: Create the framework directory and a venv for running tests**

```bash
mkdir -p ai/orchestrator-framework/tests
python3 -m venv ai/orchestrator-framework/.venv
ai/orchestrator-framework/.venv/bin/pip install -q pyyaml pytest
```

Expected: no errors; `ai/orchestrator-framework/.venv/bin/pytest --version` prints a version.

- [ ] **Step 2: Add `.gitignore` for the framework directory**

Create `ai/orchestrator-framework/.gitignore`:

```
.venv/
models.local.yaml
```

- [ ] **Step 3: Write the failing tests for `queue.py`**

Create `ai/orchestrator-framework/tests/test_queue.py`:

```python
import json
import subprocess
import sys
from pathlib import Path

QUEUE_PY = Path(__file__).parent.parent / "queue.py"


def run_queue(tmp_path, *args):
    return subprocess.run(
        [sys.executable, str(QUEUE_PY), "--queue-dir", str(tmp_path), *args],
        capture_output=True,
        text=True,
    )


def append(tmp_path, event):
    result = run_queue(tmp_path, "append", json.dumps(event))
    assert result.returncode == 0, result.stderr
    return json.loads(result.stdout)


def test_append_created_auto_assigns_id(tmp_path):
    saved = append(
        tmp_path,
        {
            "event": "created",
            "desc": "do the thing",
            "assigned_to": "worker",
            "created_by": "orchestrator",
        },
    )
    assert saved["id"] == "task-001"
    assert saved["parent_id"] is None


def test_append_created_rejects_duplicate_id(tmp_path):
    append(
        tmp_path,
        {
            "event": "created",
            "id": "task-001",
            "desc": "a",
            "assigned_to": "worker",
            "created_by": "orchestrator",
        },
    )
    result = run_queue(
        tmp_path,
        "append",
        json.dumps(
            {
                "event": "created",
                "id": "task-001",
                "desc": "b",
                "assigned_to": "worker",
                "created_by": "orchestrator",
            }
        ),
    )
    assert result.returncode == 1
    assert "already exists" in result.stderr


def test_append_rejects_unknown_task_id(tmp_path):
    result = run_queue(tmp_path, "append", json.dumps({"event": "in_progress", "id": "task-999"}))
    assert result.returncode == 1
    assert "unknown task id" in result.stderr


def test_append_rejects_bad_transition(tmp_path):
    saved = append(
        tmp_path,
        {
            "event": "created",
            "desc": "a",
            "assigned_to": "worker",
            "created_by": "orchestrator",
        },
    )
    result = run_queue(
        tmp_path,
        "append",
        json.dumps({"event": "completed", "id": saved["id"], "result": "done"}),
    )
    assert result.returncode == 1
    assert "cannot append 'completed'" in result.stderr


def test_full_lifecycle_and_spawned_reference(tmp_path):
    parent = append(
        tmp_path,
        {
            "event": "created",
            "desc": "parent task",
            "assigned_to": "worker",
            "created_by": "orchestrator",
        },
    )
    append(tmp_path, {"event": "in_progress", "id": parent["id"]})
    child = append(
        tmp_path,
        {
            "event": "created",
            "desc": "follow-up",
            "assigned_to": "reviewer",
            "created_by": "worker",
            "parent_id": parent["id"],
        },
    )
    append(
        tmp_path,
        {
            "event": "completed",
            "id": parent["id"],
            "result": "did it",
            "spawned": [child["id"]],
        },
    )

    status = run_queue(tmp_path, "status", "--json")
    assert status.returncode == 0
    tasks = {t["id"]: t for t in json.loads(status.stdout)}
    assert tasks[parent["id"]]["status"] == "completed"
    assert tasks[parent["id"]]["spawned"] == [child["id"]]
    assert tasks[child["id"]]["status"] == "pending"
    assert tasks[child["id"]]["parent_id"] == parent["id"]


def test_completed_rejects_unreferenced_spawned_id(tmp_path):
    parent = append(
        tmp_path,
        {
            "event": "created",
            "desc": "a",
            "assigned_to": "worker",
            "created_by": "orchestrator",
        },
    )
    append(tmp_path, {"event": "in_progress", "id": parent["id"]})
    result = run_queue(
        tmp_path,
        "append",
        json.dumps(
            {
                "event": "completed",
                "id": parent["id"],
                "result": "done",
                "spawned": ["task-999"],
            }
        ),
    )
    assert result.returncode == 1
    assert "must already have its own" in result.stderr


def test_next_returns_oldest_pending_for_role(tmp_path):
    append(
        tmp_path,
        {
            "event": "created",
            "desc": "for worker",
            "assigned_to": "worker",
            "created_by": "orchestrator",
        },
    )
    reviewer_task = append(
        tmp_path,
        {
            "event": "created",
            "desc": "for reviewer",
            "assigned_to": "reviewer",
            "created_by": "orchestrator",
        },
    )
    result = run_queue(tmp_path, "next", "--for", "reviewer")
    assert result.returncode == 0
    assert json.loads(result.stdout)["id"] == reviewer_task["id"]


def test_next_returns_nonzero_when_none_pending(tmp_path):
    result = run_queue(tmp_path, "next", "--for", "consultant")
    assert result.returncode == 1
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `ai/orchestrator-framework/.venv/bin/pytest ai/orchestrator-framework/tests/test_queue.py -v`
Expected: FAIL — `queue.py` does not exist yet (collection error / `FileNotFoundError` when `subprocess.run` tries to exec it).

- [ ] **Step 5: Implement `queue.py`**

Create `ai/orchestrator-framework/queue.py`:

```python
#!/usr/bin/env python3
"""Shared task-queue CLI for the orchestrator framework's agents.

Reads and writes an append-only JSON-Lines event log at
<queue-dir>/tasks.jsonl. Every hand-off between agents is one appended
line; nothing is ever rewritten or deleted. A task's current state is
whatever its most recent event says.
"""
import argparse
import json
import sys
from pathlib import Path

VALID_ROLES = {"orchestrator", "worker", "reviewer", "consultant"}
VALID_EVENTS = {"created", "in_progress", "completed", "blocked"}

STATUS_AFTER_EVENT = {
    "created": "pending",
    "in_progress": "in_progress",
    "completed": "completed",
    "blocked": "blocked",
}

ALLOWED_NEXT_EVENTS = {
    "pending": {"in_progress"},
    "in_progress": {"completed", "blocked"},
    "blocked": {"in_progress"},
    "completed": set(),
}


class QueueError(ValueError):
    pass


def queue_path(queue_dir):
    return Path(queue_dir) / "tasks.jsonl"


def load_events(queue_dir):
    path = queue_path(queue_dir)
    if not path.exists():
        return []
    events = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if line:
            events.append(json.loads(line))
    return events


def fold(events):
    """Fold events in order into {task_id: current-state-dict}."""
    tasks = {}
    for ev in events:
        state = tasks.setdefault(ev["id"], {"id": ev["id"]})
        state["status"] = STATUS_AFTER_EVENT[ev["event"]]
        if ev["event"] == "created":
            state["desc"] = ev["desc"]
            state["assigned_to"] = ev["assigned_to"]
            state["parent_id"] = ev.get("parent_id")
            state["created_by"] = ev["created_by"]
        elif ev["event"] == "completed":
            state["result"] = ev["result"]
            state["spawned"] = ev.get("spawned", [])
        elif ev["event"] == "blocked":
            state["reason"] = ev["reason"]
    return tasks


def next_task_id(events):
    existing = {ev["id"] for ev in events if ev["event"] == "created"}
    n = len(existing) + 1
    while f"task-{n:03d}" in existing:
        n += 1
    return f"task-{n:03d}"


def validate_and_prepare(event, events):
    if "event" not in event or event["event"] not in VALID_EVENTS:
        raise QueueError(f"event must be one of {sorted(VALID_EVENTS)}")

    kind = event["event"]
    tasks = fold(events)

    if kind == "created":
        for field in ("desc", "assigned_to", "created_by"):
            if not event.get(field):
                raise QueueError(f"created event requires non-empty '{field}'")
        if event["assigned_to"] not in VALID_ROLES:
            raise QueueError(f"assigned_to must be one of {sorted(VALID_ROLES)}")
        event.setdefault("parent_id", None)
        if event.get("id"):
            if event["id"] in tasks:
                raise QueueError(f"task id {event['id']!r} already exists")
        else:
            event["id"] = next_task_id(events)
        if event["parent_id"] is not None and event["parent_id"] not in tasks:
            raise QueueError(f"parent_id {event['parent_id']!r} does not exist")
        return event

    task_id = event.get("id")
    if not task_id:
        raise QueueError(f"{kind} event requires 'id'")
    if task_id not in tasks:
        raise QueueError(f"unknown task id {task_id!r}")

    current_status = tasks[task_id]["status"]
    if kind not in ALLOWED_NEXT_EVENTS[current_status]:
        raise QueueError(
            f"cannot append {kind!r} to task {task_id!r} in status {current_status!r}"
        )

    if kind == "completed":
        if not event.get("result"):
            raise QueueError("completed event requires non-empty 'result'")
        event.setdefault("spawned", [])
        for spawned_id in event["spawned"]:
            if spawned_id not in tasks:
                raise QueueError(
                    f"spawned id {spawned_id!r} must already have its own "
                    f"'created' event before being referenced here"
                )
    elif kind == "blocked":
        if not event.get("reason"):
            raise QueueError("blocked event requires non-empty 'reason'")

    return event


def append_event(queue_dir, event):
    events = load_events(queue_dir)
    event = validate_and_prepare(dict(event), events)
    path = queue_path(queue_dir)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a") as f:
        f.write(json.dumps(event, sort_keys=True) + "\n")
    return event


def cmd_append(args):
    try:
        event = json.loads(args.event_json)
    except json.JSONDecodeError as e:
        print(f"error: invalid JSON: {e}", file=sys.stderr)
        return 1
    try:
        saved = append_event(args.queue_dir, event)
    except QueueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    print(json.dumps(saved, sort_keys=True))
    return 0


def cmd_status(args):
    tasks = fold(load_events(args.queue_dir))
    ordered = list(tasks.values())
    if args.json:
        print(json.dumps(ordered, sort_keys=True))
    else:
        if not ordered:
            print("(no tasks)")
        for t in ordered:
            print(f"{t['id']:<10} {t['status']:<12} {t.get('assigned_to', '-'):<12} {t.get('desc', '')}")
    return 0


def cmd_next(args):
    for t in fold(load_events(args.queue_dir)).values():
        if t["status"] == "pending" and t.get("assigned_to") == args.for_role:
            print(json.dumps(t, sort_keys=True))
            return 0
    return 1


def main(argv=None):
    parser = argparse.ArgumentParser(prog="queue.py")
    parser.add_argument("--queue-dir", default=".orchestrator")
    sub = parser.add_subparsers(dest="command", required=True)

    p_append = sub.add_parser("append")
    p_append.add_argument("event_json")
    p_append.set_defaults(func=cmd_append)

    p_status = sub.add_parser("status")
    p_status.add_argument("--json", action="store_true")
    p_status.set_defaults(func=cmd_status)

    p_next = sub.add_parser("next")
    p_next.add_argument("--for", dest="for_role", required=True, choices=sorted(VALID_ROLES))
    p_next.set_defaults(func=cmd_next)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 6: Make it executable and run the tests to verify they pass**

```bash
chmod +x ai/orchestrator-framework/queue.py
ai/orchestrator-framework/.venv/bin/pytest ai/orchestrator-framework/tests/test_queue.py -v
```

Expected: all 8 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add ai/orchestrator-framework/queue.py ai/orchestrator-framework/tests/test_queue.py ai/orchestrator-framework/.gitignore
git commit -m "Add append-only task-queue CLI (queue.py)"
```

---

### Task 2: Agent source data + `generate.py` loader

**Files:**
- Create: `ai/orchestrator-framework/agents/orchestrator.yaml`
- Create: `ai/orchestrator-framework/agents/worker.yaml`
- Create: `ai/orchestrator-framework/agents/reviewer.yaml`
- Create: `ai/orchestrator-framework/agents/consultant.yaml`
- Create: `ai/orchestrator-framework/models.yaml`
- Create: `ai/orchestrator-framework/models.local.yaml.example`
- Create: `ai/orchestrator-framework/generate.py`
- Create: `ai/orchestrator-framework/tests/test_generate.py`

**Interfaces:**
- Consumes: nothing new (PyYAML, already installed into `.venv` in Task 1).
- Produces (consumed by Tasks 3-6): `generate.GenerateError`, `generate.load_agents(agents_dir) -> dict[name, agent_dict]`, `generate.deep_merge(base, override) -> dict`, `generate.load_models(models_path, models_local_path=None) -> dict`, `generate.resolve_model(agent, harness, models) -> str`. Each `agent_dict` has keys `name`, `description`, `tier`, `tools` (dict keyed by harness name), `prompt`.

- [ ] **Step 1: Write the four agent source files**

Create `ai/orchestrator-framework/agents/orchestrator.yaml`:

```yaml
name: orchestrator
description: >-
  Talks to the end user, breaks problems into tasks, and routes each task to
  worker, reviewer, or consultant via the shared .orchestrator/tasks.jsonl
  queue. Never edits project files directly.
tier: high
tools:
  claude-code:
    - "Bash(orchestrator-queue *)"
    - "Task"
  opencode:
    - "bash(orchestrator-queue *)"
    - "task"
  cursor:
    - "terminal(orchestrator-queue *)"
prompt: |
  You are the Orchestrator agent in a multi-agent framework.

  Your only job is to break the user's problem into tasks and route them to
  the right agent through the shared task queue at
  `.orchestrator/tasks.jsonl`. You never read or write project source files
  yourself -- that is the Worker's job.

  Workflow:
  1. When the user describes a problem, decide what the first task is and
     which agent should do it (worker, reviewer, or consultant).
  2. Append a `created` event for that task:
     `orchestrator-queue append '{"event":"created","desc":"...","assigned_to":"worker","created_by":"orchestrator"}'`
  3. Invoke that agent (via your harness's subagent tool) and tell it which
     task id to work on.
  4. When it hands control back, run
     `orchestrator-queue status --json` to see its `completed`
     event, including any `spawned` follow-up task ids.
  5. Decide whether any follow-up task needs a Reviewer pass before you
     consider the parent task fully done -- Reviewer review is not
     automatic, it is your judgment call based on risk.
  6. Repeat until every task assigned so far is `completed`, then summarize
     the outcome for the user.
```

Create `ai/orchestrator-framework/agents/worker.yaml`:

```yaml
name: worker
description: >-
  The only agent that reads and writes project files. Picks up one task at a
  time from .orchestrator/tasks.jsonl, implements it, and reports completion
  plus any follow-up tasks it discovers.
tier: low
tools:
  claude-code:
    - "*"
  opencode:
    - "*"
  cursor:
    - "*"
prompt: |
  You are the Worker agent in a multi-agent framework. You have unrestricted
  tool access -- you are the only agent that edits code.

  Workflow:
  1. Find your assigned task:
     `orchestrator-queue next --for worker`
  2. Mark it in progress:
     `orchestrator-queue append '{"event":"in_progress","id":"<task-id>"}'`
  3. Do the actual implementation work for that task.
  4. If the work reveals follow-up tasks (bugs found, cleanup needed, a
     review that should happen), append a `created` event for each one
     first, noting the returned task id.
  5. Mark your task complete, listing any follow-up task ids you created:
     `orchestrator-queue append '{"event":"completed","id":"<task-id>","result":"<summary>","spawned":["<id>"]}'`
  6. Report back to the Orchestrator that just invoked you.
```

Create `ai/orchestrator-framework/agents/reviewer.yaml`:

```yaml
name: reviewer
description: >-
  Reviews completed Worker output at the Orchestrator's discretion. Runs
  tests/linters/build and reports findings as new tasks -- never fixes
  anything itself.
tier: medium
tools:
  claude-code:
    - "Read"
    - "Grep"
    - "Glob"
    - "Bash"
  opencode:
    - "read"
    - "grep"
    - "glob"
    - "bash"
  cursor:
    - "read"
    - "search"
    - "terminal"
prompt: |
  You are the Reviewer agent in a multi-agent framework. You can read files
  and run commands (tests, linters, builds), but you never edit source
  files -- you only report findings.

  Workflow:
  1. Find your assigned task:
     `orchestrator-queue next --for reviewer`
  2. Mark it in progress:
     `orchestrator-queue append '{"event":"in_progress","id":"<task-id>"}'`
  3. Inspect the relevant diff/output and run whatever checks are
     appropriate (tests, linters, a build).
  4. For every problem you find, append a new `created` task assigned back
     to `worker` describing exactly what to fix -- do not fix it yourself.
  5. Mark your review task complete, listing any tasks you created:
     `orchestrator-queue append '{"event":"completed","id":"<task-id>","result":"<summary of findings>","spawned":["<id>"]}'`
  6. Report back to the Orchestrator that just invoked you.
```

Create `ai/orchestrator-framework/agents/consultant.yaml`:

```yaml
name: consultant
description: >-
  Handles complex planning and architecture decisions at the Orchestrator's
  request. Produces a plan as ordered follow-up tasks for the Worker -- never
  touches code.
tier: high
tools:
  claude-code:
    - "Read"
    - "Grep"
    - "Glob"
    - "WebSearch"
    - "WebFetch"
    - "Bash(orchestrator-queue *)"
  opencode:
    - "read"
    - "grep"
    - "glob"
    - "websearch"
    - "bash(orchestrator-queue *)"
  cursor:
    - "read"
    - "search"
    - "web"
    - "terminal(orchestrator-queue *)"
prompt: |
  You are the Consultant agent in a multi-agent framework. You handle
  complex planning and architecture decisions. You can read the codebase
  and research online, but you have no general command execution and you
  never edit files -- your output is always a plan, never code.

  Workflow:
  1. Find your assigned task:
     `orchestrator-queue next --for consultant`
  2. Mark it in progress:
     `orchestrator-queue append '{"event":"in_progress","id":"<task-id>"}'`
  3. Investigate (read the codebase, research prior art) and produce a
     concrete plan: an ordered list of implementable tasks.
  4. Append a `created` event for each task in your plan, assigned to
     `worker`, in the order they should be done.
  5. Mark your planning task complete, listing every task id you created:
     `orchestrator-queue append '{"event":"completed","id":"<task-id>","result":"<summary of the plan/decision>","spawned":["<id>"]}'`
  6. Report back to the Orchestrator that just invoked you.
```

- [ ] **Step 2: Write `models.yaml` and the local-override example**

Create `ai/orchestrator-framework/models.yaml`:

```yaml
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

Create `ai/orchestrator-framework/models.local.yaml.example`:

```yaml
# Copy this file to models.local.yaml (gitignored) and fill in the model
# ids your OpenCode/Cursor setup actually exposes. Values here override the
# matching keys in models.yaml; anything you don't set falls back to
# models.yaml's default (which is `null` for opencode/cursor tiers until you
# fill them in).
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

- [ ] **Step 3: Write the failing tests for the `generate.py` loader**

Create `ai/orchestrator-framework/tests/test_generate.py`:

```python
import sys
from pathlib import Path

import pytest
import yaml

sys.path.insert(0, str(Path(__file__).parent.parent))
import generate  # noqa: E402

FIXTURE_AGENT = {
    "name": "worker",
    "description": "Test worker agent.",
    "tier": "low",
    "tools": {"claude-code": ["*"], "opencode": ["*"], "cursor": ["*"]},
    "prompt": "You are the test worker.\n",
}

FIXTURE_MODELS = {
    "tiers": {
        "claude-code": {
            "high": "claude-opus-4-8",
            "medium": "claude-sonnet-5",
            "low": "claude-haiku-4-5-20251001",
        },
        "opencode": {"high": None, "medium": None, "low": "opencode-low-model"},
        "cursor": {"high": None, "medium": None, "low": None},
    }
}


def write_fixture_agents(tmp_path):
    agents_dir = tmp_path / "agents"
    agents_dir.mkdir()
    (agents_dir / "worker.yaml").write_text(yaml.safe_dump(FIXTURE_AGENT))
    return agents_dir


def write_fixture_models(tmp_path):
    models_path = tmp_path / "models.yaml"
    models_path.write_text(yaml.safe_dump(FIXTURE_MODELS))
    return models_path


def test_load_agents_reads_all_required_fields(tmp_path):
    agents_dir = write_fixture_agents(tmp_path)
    agents = generate.load_agents(agents_dir)
    assert agents["worker"]["tier"] == "low"


def test_load_agents_rejects_missing_field(tmp_path):
    agents_dir = tmp_path / "agents"
    agents_dir.mkdir()
    (agents_dir / "broken.yaml").write_text(yaml.safe_dump({"name": "broken"}))
    with pytest.raises(generate.GenerateError, match="missing required field"):
        generate.load_agents(agents_dir)


def test_deep_merge_local_overrides_win(tmp_path):
    models_path = write_fixture_models(tmp_path)
    local_path = tmp_path / "models.local.yaml"
    local_path.write_text(yaml.safe_dump({"tiers": {"opencode": {"high": "custom-model"}}}))
    models = generate.load_models(models_path, local_path)
    assert models["tiers"]["opencode"]["high"] == "custom-model"
    assert models["tiers"]["opencode"]["low"] == "opencode-low-model"


def test_load_models_without_local_file_uses_base(tmp_path):
    models_path = write_fixture_models(tmp_path)
    models = generate.load_models(models_path, tmp_path / "does-not-exist.yaml")
    assert models["tiers"]["claude-code"]["high"] == "claude-opus-4-8"


def test_resolve_model_fails_loudly_on_null():
    agent = {**FIXTURE_AGENT, "tier": "high"}
    with pytest.raises(generate.GenerateError, match="is null"):
        generate.resolve_model(agent, "cursor", FIXTURE_MODELS)


def test_resolve_model_returns_concrete_id():
    agent = {**FIXTURE_AGENT, "tier": "low"}
    assert generate.resolve_model(agent, "claude-code", FIXTURE_MODELS) == "claude-haiku-4-5-20251001"
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `ai/orchestrator-framework/.venv/bin/pytest ai/orchestrator-framework/tests/test_generate.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'generate'` (file doesn't exist yet).

- [ ] **Step 5: Implement the `generate.py` loader (adapters come in later tasks)**

Create `ai/orchestrator-framework/generate.py`:

```python
#!/usr/bin/env python3
"""Generate harness-native agent files from the neutral agents/*.yaml source."""
import copy
import sys
from pathlib import Path

import yaml

FRAMEWORK_DIR = Path(__file__).parent
DEFAULT_AGENTS_DIR = FRAMEWORK_DIR / "agents"
DEFAULT_MODELS_PATH = FRAMEWORK_DIR / "models.yaml"

REQUIRED_AGENT_FIELDS = ("name", "description", "tier", "tools", "prompt")


class GenerateError(RuntimeError):
    pass


def load_agents(agents_dir):
    agents = {}
    for path in sorted(Path(agents_dir).glob("*.yaml")):
        data = yaml.safe_load(path.read_text())
        for field in REQUIRED_AGENT_FIELDS:
            if field not in data:
                raise GenerateError(f"{path}: missing required field '{field}'")
        agents[data["name"]] = data
    return agents


def deep_merge(base, override):
    result = copy.deepcopy(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


def load_models(models_path, models_local_path=None):
    models = yaml.safe_load(Path(models_path).read_text())
    if models_local_path and Path(models_local_path).exists():
        local = yaml.safe_load(Path(models_local_path).read_text())
        if local:
            models = deep_merge(models, local)
    return models


def resolve_model(agent, harness, models):
    tier = agent["tier"]
    try:
        model = models["tiers"][harness][tier]
    except KeyError:
        raise GenerateError(f"agent '{agent['name']}': no models.tiers.{harness}.{tier} entry")
    if model is None:
        raise GenerateError(
            f"agent '{agent['name']}': models.tiers.{harness}.{tier} is null -- "
            f"set it in models.local.yaml before generating for {harness}"
        )
    return model


if __name__ == "__main__":
    sys.exit(1)  # CLI wiring added in Task 6
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `ai/orchestrator-framework/.venv/bin/pytest ai/orchestrator-framework/tests/test_generate.py -v`
Expected: all 6 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add ai/orchestrator-framework/agents ai/orchestrator-framework/models.yaml \
        ai/orchestrator-framework/models.local.yaml.example \
        ai/orchestrator-framework/generate.py ai/orchestrator-framework/tests/test_generate.py
git commit -m "Add agent source YAML, models config, and generate.py loader"
```

---

### Task 3: Shared markdown-agent renderer + Claude Code adapter

**Files:**
- Modify: `ai/orchestrator-framework/generate.py`
- Modify: `ai/orchestrator-framework/tests/test_generate.py`

**Interfaces:**
- Consumes: `generate.load_agents`, `generate.resolve_model`, `generate.GenerateError` (Task 2).
- Produces (consumed by Task 4 and Task 6): `generate.render_markdown_agent(agent, harness, model) -> str` (shared by any harness whose agent format is YAML-frontmatter markdown — Claude Code and OpenCode both are, per spec §5, "structurally near-identical"), `generate.write_markdown_agents(agents, models, harness, out_dir) -> None`, `generate.write_claude_code(agents, models, out_dir) -> None` (thin wrapper: `write_markdown_agents(agents, models, "claude-code", out_dir)`).

- [ ] **Step 1: Add the failing tests**

Append to `ai/orchestrator-framework/tests/test_generate.py`:

```python
def test_write_claude_code_produces_expected_frontmatter(tmp_path):
    agents_dir = write_fixture_agents(tmp_path)
    agents = generate.load_agents(agents_dir)
    out_dir = tmp_path / "claude-out"
    generate.write_claude_code(agents, FIXTURE_MODELS, out_dir)
    content = (out_dir / "worker.md").read_text()
    assert "name: worker" in content
    assert "model: claude-haiku-4-5-20251001" in content
    assert "tools: *" in content
    assert "You are the test worker." in content


def test_write_claude_code_fails_loudly_on_null_model(tmp_path):
    agents_dir = write_fixture_agents(tmp_path)
    agent = generate.load_agents(agents_dir)
    agent["worker"]["tier"] = "high"
    out_dir = tmp_path / "claude-out"
    with pytest.raises(generate.GenerateError, match="is null"):
        generate.write_claude_code(agent, FIXTURE_MODELS, out_dir)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `ai/orchestrator-framework/.venv/bin/pytest ai/orchestrator-framework/tests/test_generate.py -k claude_code -v`
Expected: FAIL — `AttributeError: module 'generate' has no attribute 'write_claude_code'`.

- [ ] **Step 3: Implement the shared renderer and the Claude Code adapter**

In `ai/orchestrator-framework/generate.py`, add after `resolve_model`:

```python
def render_markdown_agent(agent, harness, model):
    tools = ", ".join(agent["tools"][harness])
    return (
        "---\n"
        f"name: {agent['name']}\n"
        f"description: {agent['description'].strip()}\n"
        f"tools: {tools}\n"
        f"model: {model}\n"
        "---\n\n"
        f"{agent['prompt'].strip()}\n"
    )


def write_markdown_agents(agents, models, harness, out_dir):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    for agent in agents.values():
        model = resolve_model(agent, harness, models)
        (out_dir / f"{agent['name']}.md").write_text(render_markdown_agent(agent, harness, model))


def write_claude_code(agents, models, out_dir):
    write_markdown_agents(agents, models, "claude-code", out_dir)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `ai/orchestrator-framework/.venv/bin/pytest ai/orchestrator-framework/tests/test_generate.py -v`
Expected: all tests PASS (8 total so far).

- [ ] **Step 5: Commit**

```bash
git add ai/orchestrator-framework/generate.py ai/orchestrator-framework/tests/test_generate.py
git commit -m "Add shared markdown-agent renderer and Claude Code adapter to generate.py"
```

---

### Task 4: OpenCode adapter

**Files:**
- Modify: `ai/orchestrator-framework/generate.py`
- Modify: `ai/orchestrator-framework/tests/test_generate.py`

**Interfaces:**
- Consumes: `generate.load_agents`, `generate.resolve_model`, `generate.GenerateError` (Task 2), `generate.write_markdown_agents` (Task 3 — reused as-is, no new rendering logic needed since Claude Code and OpenCode share one markdown-frontmatter format).
- Produces (consumed by Task 6): `generate.write_opencode(agents, models, out_dir) -> None`.

- [ ] **Step 1: Add the failing test**

Append to `ai/orchestrator-framework/tests/test_generate.py`:

```python
def test_write_opencode_produces_expected_frontmatter(tmp_path):
    agents_dir = write_fixture_agents(tmp_path)
    agents = generate.load_agents(agents_dir)
    out_dir = tmp_path / "opencode-out"
    generate.write_opencode(agents, FIXTURE_MODELS, out_dir)
    content = (out_dir / "worker.md").read_text()
    assert "name: worker" in content
    assert "model: opencode-low-model" in content
    assert "You are the test worker." in content
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `ai/orchestrator-framework/.venv/bin/pytest ai/orchestrator-framework/tests/test_generate.py -k opencode -v`
Expected: FAIL — `AttributeError: module 'generate' has no attribute 'write_opencode'`.

- [ ] **Step 3: Implement the OpenCode adapter**

In `ai/orchestrator-framework/generate.py`, add after `write_claude_code`:

```python
def write_opencode(agents, models, out_dir):
    write_markdown_agents(agents, models, "opencode", out_dir)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `ai/orchestrator-framework/.venv/bin/pytest ai/orchestrator-framework/tests/test_generate.py -v`
Expected: all tests PASS (9 total so far).

- [ ] **Step 5: Commit**

```bash
git add ai/orchestrator-framework/generate.py ai/orchestrator-framework/tests/test_generate.py
git commit -m "Add OpenCode adapter to generate.py"
```

---

### Task 5: Cursor adapter

**Files:**
- Modify: `ai/orchestrator-framework/generate.py`
- Modify: `ai/orchestrator-framework/tests/test_generate.py`

**Interfaces:**
- Consumes: `generate.load_agents`, `generate.resolve_model`, `generate.GenerateError` (Task 2).
- Produces (consumed by Task 6): `generate.render_cursor(agents, models) -> str` (single JSON document for all agents), `generate.write_cursor(agents, models, out_path) -> None`.

- [ ] **Step 1: Add the failing tests**

Append to `ai/orchestrator-framework/tests/test_generate.py`:

```python
import json


def test_write_cursor_raises_when_model_unset(tmp_path):
    agents_dir = write_fixture_agents(tmp_path)
    agents = generate.load_agents(agents_dir)
    agents["worker"]["tier"] = "high"
    out_path = tmp_path / "modes.json"
    with pytest.raises(generate.GenerateError, match="is null"):
        generate.write_cursor(agents, FIXTURE_MODELS, out_path)


def test_write_cursor_structure_when_model_set(tmp_path):
    agents_dir = write_fixture_agents(tmp_path)
    agents = generate.load_agents(agents_dir)
    models = {
        "tiers": {
            **FIXTURE_MODELS["tiers"],
            "cursor": {"high": "x", "medium": "y", "low": "cursor-low-model"},
        }
    }
    out_path = tmp_path / "modes.json"
    generate.write_cursor(agents, models, out_path)
    data = json.loads(out_path.read_text())
    assert data["modes"][0]["name"] == "worker"
    assert data["modes"][0]["model"] == "cursor-low-model"
    assert data["modes"][0]["tools"] == ["*"]
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `ai/orchestrator-framework/.venv/bin/pytest ai/orchestrator-framework/tests/test_generate.py -k cursor -v`
Expected: FAIL — `AttributeError: module 'generate' has no attribute 'write_cursor'`.

- [ ] **Step 3: Implement the Cursor adapter**

In `ai/orchestrator-framework/generate.py`, add near the top (`import json` alongside the existing imports) and after `write_opencode`:

```python
import json  # add to the existing import block at the top of the file
```

```python
def render_cursor(agents, models):
    modes = []
    for agent in agents.values():
        model = resolve_model(agent, "cursor", models)
        modes.append(
            {
                "name": agent["name"],
                "description": agent["description"].strip(),
                "tools": agent["tools"]["cursor"],
                "model": model,
                "prompt": agent["prompt"].strip(),
            }
        )
    return json.dumps({"modes": modes}, indent=2, sort_keys=True) + "\n"


def write_cursor(agents, models, out_path):
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(render_cursor(agents, models))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `ai/orchestrator-framework/.venv/bin/pytest ai/orchestrator-framework/tests/test_generate.py -v`
Expected: all tests PASS (11 total so far).

- [ ] **Step 5: Commit**

```bash
git add ai/orchestrator-framework/generate.py ai/orchestrator-framework/tests/test_generate.py
git commit -m "Add Cursor adapter to generate.py"
```

---

### Task 6: CLI wiring, `setup.sh`, and root install integration

**Files:**
- Modify: `ai/orchestrator-framework/generate.py`
- Create: `ai/orchestrator-framework/setup.sh`
- Modify: `setup.sh` (repo root)
- Modify: `.gitignore` (repo root)

**Interfaces:**
- Consumes: `generate.load_agents`, `generate.load_models`, `generate.write_claude_code`, `generate.write_opencode`, `generate.write_cursor`, `generate.GenerateError` (Tasks 2-5).
- Produces: `generate.py`'s `main(argv)` CLI entry point; `ai/orchestrator-framework/setup.sh` (framework-level installer); root `setup.sh` now calls it.

- [ ] **Step 1: Replace the placeholder CLI in `generate.py` with real argument parsing**

In `ai/orchestrator-framework/generate.py`, replace:

```python
if __name__ == "__main__":
    sys.exit(1)  # CLI wiring added in Task 6
```

with:

```python
import argparse


def main(argv=None):
    parser = argparse.ArgumentParser(prog="generate.py")
    parser.add_argument("--agents-dir", default=str(DEFAULT_AGENTS_DIR))
    parser.add_argument("--models", default=str(DEFAULT_MODELS_PATH))
    parser.add_argument("--models-local", default=None)
    parser.add_argument("--claude-code-out")
    parser.add_argument("--opencode-out")
    parser.add_argument("--cursor-out")
    args = parser.parse_args(argv)

    try:
        agents = load_agents(args.agents_dir)
        models = load_models(args.models, args.models_local)

        if args.claude_code_out:
            write_claude_code(agents, models, args.claude_code_out)
            print(f"Wrote Claude Code agents to {args.claude_code_out}")
        if args.opencode_out:
            write_opencode(agents, models, args.opencode_out)
            print(f"Wrote OpenCode agents to {args.opencode_out}")
        if args.cursor_out:
            write_cursor(agents, models, args.cursor_out)
            print(f"Wrote Cursor modes to {args.cursor_out}")
    except GenerateError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Also add `import argparse` to the top import block instead of inline (move the `import argparse` line up next to `import copy`).

- [ ] **Step 2: Manually verify the full CLI end-to-end**

```bash
cd ai/orchestrator-framework
cp models.local.yaml.example models.local.yaml
.venv/bin/python3 generate.py \
  --models-local models.local.yaml \
  --claude-code-out /tmp/orchestrator-cc-test \
  --opencode-out /tmp/orchestrator-oc-test \
  --cursor-out /tmp/orchestrator-cursor-test/modes.json
cat /tmp/orchestrator-cc-test/orchestrator.md
rm -rf /tmp/orchestrator-cc-test /tmp/orchestrator-oc-test /tmp/orchestrator-cursor-test models.local.yaml
cd -
```

Expected: three "Wrote ... to ..." lines print, and `orchestrator.md`'s `cat` output shows YAML frontmatter with `model: claude-opus-4-8` and the Orchestrator prompt body.

- [ ] **Step 3: Write `ai/orchestrator-framework/setup.sh`**

```bash
#!/bin/sh
# Orchestrator framework setup — run from the main setup.sh or standalone.

FRAMEWORK_DIR="$(cd "$(dirname "$0")" && pwd)"

# Runtime dependency check (PyYAML) — warn and continue, don't hard-fail
# the whole dotfiles setup, matching claude/setup.sh's jq check.
if ! python3 -c "import yaml" > /dev/null 2>&1; then
    echo "WARNING: PyYAML not found for python3 — orchestrator agent files won't be generated"
    echo "  Install it with: python3 -m pip install --user pyyaml (or use a venv)"
    exit 0
fi

if [ ! -e "$FRAMEWORK_DIR/models.local.yaml" ]; then
    echo "NOTE: $FRAMEWORK_DIR/models.local.yaml not found — OpenCode/Cursor model"
    echo "  tiers will stay unset. Copy models.local.yaml.example to models.local.yaml"
    echo "  and fill in your own model ids to enable those harnesses."
fi

mkdir -p "$HOME/.claude/agents" "$HOME/.config/opencode/agent" "$HOME/bin"

# Agent prompts invoke the queue CLI as a bare `orchestrator-queue` command
# (it must resolve on PATH from inside any project being orchestrated, not
# just from this dotfiles checkout) — symlink it into ~/bin like this repo's
# other bin/ scripts.
echo "Linking ~/bin/orchestrator-queue"
[ -h "$HOME/bin/orchestrator-queue" ] && rm "$HOME/bin/orchestrator-queue"
ln -s "$FRAMEWORK_DIR/queue.py" "$HOME/bin/orchestrator-queue"

echo "Generating orchestrator framework agents"
python3 "$FRAMEWORK_DIR/generate.py" \
    --models-local "$FRAMEWORK_DIR/models.local.yaml" \
    --claude-code-out "$HOME/.claude/agents" \
    --opencode-out "$HOME/.config/opencode/agent" \
    --cursor-out "$HOME/.orchestrator-cursor-modes.json"
```

- [ ] **Step 4: Make it executable and wire it into the root `setup.sh`**

```bash
chmod +x ai/orchestrator-framework/setup.sh
```

In `setup.sh` (repo root), change:

```sh
# Set up Claude Code configuration
sh "$(pwd)/claude/setup.sh"
```

to:

```sh
# Set up Claude Code configuration
sh "$(pwd)/claude/setup.sh"

# Set up the multi-harness orchestrator framework agents
sh "$(pwd)/ai/orchestrator-framework/setup.sh"
```

- [ ] **Step 5: Add root `.gitignore` entry for the global Cursor modes file reference (documentation only — no repo file to ignore) and verify the framework's own `.gitignore` already covers `models.local.yaml`**

No root `.gitignore` change is needed: `models.local.yaml` is covered by `ai/orchestrator-framework/.gitignore` (Task 1), and `~/.orchestrator-cursor-modes.json` lives outside the repo entirely. Confirm this instead of editing:

```bash
git check-ignore -v ai/orchestrator-framework/models.local.yaml || echo "NOT IGNORED — investigate"
```

Expected: prints the matching `ai/orchestrator-framework/.gitignore:2:models.local.yaml` rule (no "NOT IGNORED" message).

- [ ] **Step 6: Run the full test suite once more**

```bash
ai/orchestrator-framework/.venv/bin/pytest ai/orchestrator-framework/tests/ -v
```

Expected: all tests from Tasks 1-5 PASS.

- [ ] **Step 7: Commit**

```bash
git add ai/orchestrator-framework/generate.py ai/orchestrator-framework/setup.sh setup.sh
git commit -m "Wire up generate.py CLI and framework setup.sh into root install"
```

---

### Task 7: README and manual smoke test

**Files:**
- Create: `ai/orchestrator-framework/README.md`

**Interfaces:**
- Consumes: everything from Tasks 1-6 (documents and exercises the finished CLI surface).
- Produces: nothing new for later tasks — this is the terminal task.

- [ ] **Step 1: Write the README**

Create `ai/orchestrator-framework/README.md`:

```markdown
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

This generates agent files into `~/.claude/agents/`, `~/.config/opencode/agent/`,
and `~/.orchestrator-cursor-modes.json` — available in every project you open
afterward, not just this repo.

Before OpenCode/Cursor tiers will resolve, copy the example override file and
fill in the model ids your setup actually exposes:

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
| `models.yaml` | `tier -> harness -> model id`; Claude Code ships real defaults, OpenCode/Cursor start `null` |
| `models.local.yaml` | Gitignored per-machine override, filled in from `models.local.yaml.example` |
| `queue.py` | Dependency-free CLI implementing the task-queue protocol; symlinked to `~/bin/orchestrator-queue` by `setup.sh` so agent prompts can call it as a bare command from any project |
| `generate.py` | Reads `agents/*.yaml` + `models.yaml`(+local), writes harness-native agent files directly into place |
| `setup.sh` | Runs `generate.py` into `~/.claude/agents`, `~/.config/opencode/agent`, and a Cursor modes file; symlinks `queue.py` to `~/bin/orchestrator-queue` |
```

- [ ] **Step 2: Run the full test suite one final time**

Run: `ai/orchestrator-framework/.venv/bin/pytest ai/orchestrator-framework/tests/ -v`
Expected: all tests PASS (19 total — 8 in `test_queue.py`, 11 in `test_generate.py`).

- [ ] **Step 3: Walk through the README's manual smoke test by hand**

Since `setup.sh` hasn't necessarily been run in this working tree yet, use
the direct path form (equivalent to the installed `orchestrator-queue`):

```bash
cd /tmp && mkdir orchestrator-smoke-test && cd orchestrator-smoke-test
QUEUE=/Users/jmeagher/devel/dotfiles/ai/orchestrator-framework/queue.py
python3 "$QUEUE" append '{"event":"created","desc":"add a hello-world script","assigned_to":"worker","created_by":"orchestrator"}'
python3 "$QUEUE" next --for worker
python3 "$QUEUE" append '{"event":"in_progress","id":"task-001"}'
python3 "$QUEUE" append '{"event":"completed","id":"task-001","result":"created hello.sh","spawned":[]}'
python3 "$QUEUE" status
cd /tmp && rm -rf orchestrator-smoke-test
```

Expected: `status`'s last line reads `task-001   completed    worker       add a hello-world script`.

- [ ] **Step 4: Commit**

```bash
git add ai/orchestrator-framework/README.md
git commit -m "Add orchestrator framework README with manual smoke test"
```
