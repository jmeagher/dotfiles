#!/usr/bin/env python3
"""Shared task-queue CLI for the orchestrator framework's agents.

Reads and writes an append-only JSON-Lines event log at
<queue-dir>/tasks.jsonl. Every hand-off between agents is one appended
line; nothing is ever rewritten or deleted. A task's current state is
whatever its most recent event says.
"""
import argparse
import fcntl
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
    for line_num, line in enumerate(path.read_text().splitlines(), 1):
        line = line.strip()
        if line:
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError as e:
                raise QueueError(f"malformed JSON in {path}:{line_num}: {e}")
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
        # Validate assigned_to is a string before membership check
        if not isinstance(event["assigned_to"], str):
            raise QueueError(f"assigned_to must be a string, got {type(event['assigned_to']).__name__}")
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
        # Validate result is a string
        if not isinstance(event["result"], str):
            raise QueueError(f"result must be a string, got {type(event['result']).__name__}")
        event.setdefault("spawned", [])
        # Validate spawned is a list before iterating
        if not isinstance(event["spawned"], list):
            raise QueueError(f"spawned must be a list, got {type(event['spawned']).__name__}")
        for spawned_id in event["spawned"]:
            if spawned_id not in tasks:
                raise QueueError(
                    f"spawned id {spawned_id!r} must already have its own "
                    f"'created' event before being referenced here"
                )
    elif kind == "blocked":
        if not event.get("reason"):
            raise QueueError("blocked event requires non-empty 'reason'")
        # Validate reason is a string
        if not isinstance(event["reason"], str):
            raise QueueError(f"reason must be a string, got {type(event['reason']).__name__}")

    return event


def append_event(queue_dir, event):
    path = queue_path(queue_dir)
    path.parent.mkdir(parents=True, exist_ok=True)
    gitignore = path.parent / ".gitignore"
    if not gitignore.exists():
        gitignore.write_text("*\n")

    # Open the file in append mode and hold an exclusive lock across the
    # load-validate-write sequence to serialize concurrent appends and
    # prevent duplicate auto-assigned task ids.
    with path.open("a") as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            events = load_events(queue_dir)
            event = validate_and_prepare(dict(event), events)
            f.write(json.dumps(event, sort_keys=True) + "\n")
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)
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
    try:
        tasks = fold(load_events(args.queue_dir))
    except QueueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
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
    try:
        tasks = fold(load_events(args.queue_dir))
    except QueueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    for t in tasks.values():
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
