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
