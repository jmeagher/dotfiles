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


def test_append_creates_self_ignoring_gitignore(tmp_path):
    append(tmp_path, {
        "event": "created", "desc": "a",
        "assigned_to": "worker", "created_by": "orchestrator",
    })
    gitignore = tmp_path / ".gitignore"
    assert gitignore.read_text() == "*\n"


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
    first_reviewer_task = append(
        tmp_path,
        {
            "event": "created",
            "desc": "earlier reviewer task",
            "assigned_to": "reviewer",
            "created_by": "orchestrator",
        },
    )
    append(
        tmp_path,
        {
            "event": "created",
            "desc": "later reviewer task",
            "assigned_to": "reviewer",
            "created_by": "orchestrator",
        },
    )
    result = run_queue(tmp_path, "next", "--for", "reviewer")
    assert result.returncode == 0
    assert json.loads(result.stdout)["id"] == first_reviewer_task["id"]


def test_next_returns_nonzero_when_none_pending(tmp_path):
    result = run_queue(tmp_path, "next", "--for", "consultant")
    assert result.returncode == 1


def test_concurrent_appends_have_unique_ids(tmp_path):
    """Test that concurrent appends with auto-assigned ids don't collide."""
    import subprocess
    import threading

    results = []

    def spawn_create_task(num):
        """Spawn a subprocess to create a task without an explicit id."""
        result = run_queue(
            tmp_path,
            "append",
            json.dumps(
                {
                    "event": "created",
                    "desc": f"concurrent task {num}",
                    "assigned_to": "worker",
                    "created_by": "orchestrator",
                }
            ),
        )
        results.append((num, result))

    # Spawn 10 concurrent threads, each running queue.py in a subprocess.
    threads = []
    for i in range(10):
        t = threading.Thread(target=spawn_create_task, args=(i,))
        threads.append(t)
        t.start()

    # Wait for all to complete.
    for t in threads:
        t.join()

    # All should succeed.
    for num, result in results:
        assert result.returncode == 0, f"Task {num} failed: {result.stderr}"

    # Collect all assigned ids.
    ids = []
    for num, result in results:
        saved = json.loads(result.stdout)
        ids.append(saved["id"])

    # All ids must be unique (no duplicates).
    assert len(ids) == len(set(ids)), f"Duplicate ids found: {ids}"
    # All ids should follow the expected pattern.
    for task_id in ids:
        assert task_id.startswith("task-"), f"Unexpected task id: {task_id}"


def test_append_rejects_non_string_assigned_to(tmp_path):
    """Test that assigned_to must be a string, not a list or other type."""
    result = run_queue(
        tmp_path,
        "append",
        json.dumps(
            {
                "event": "created",
                "desc": "test",
                "assigned_to": ["worker"],  # Wrong: array instead of string
                "created_by": "orchestrator",
            }
        ),
    )
    assert result.returncode == 1
    assert "assigned_to must be a string" in result.stderr


def test_append_rejects_non_list_spawned(tmp_path):
    """Test that spawned must be a list, not a string or other type."""
    parent = append(
        tmp_path,
        {
            "event": "created",
            "desc": "parent",
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
                "spawned": "task-002",  # Wrong: string instead of list
            }
        ),
    )
    assert result.returncode == 1
    assert "spawned must be a list" in result.stderr


def test_load_malformed_json_line_reports_line_number(tmp_path):
    """Test that a malformed JSON line in tasks.jsonl is reported with line number."""
    # Create a queue directory and manually add a malformed line.
    queue_file = tmp_path / "tasks.jsonl"
    queue_file.write_text(
        json.dumps(
            {
                "event": "created",
                "id": "task-001",
                "desc": "good",
                "assigned_to": "worker",
                "created_by": "orchestrator",
            }
        )
        + "\n"
        + "this is not valid json\n"  # Line 2: malformed
        + json.dumps({"event": "in_progress", "id": "task-001"})
        + "\n"
    )

    # Try to run status, which loads events.
    result = run_queue(tmp_path, "status")
    assert result.returncode == 1
    # Should mention the file path and line number 2.
    assert "malformed JSON" in result.stderr
    assert ":2:" in result.stderr or "line 2" in result.stderr.lower()


def test_append_rejects_non_string_result(tmp_path):
    """Test that result must be a string in completed events."""
    parent = append(
        tmp_path,
        {
            "event": "created",
            "desc": "parent",
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
                "result": 123,  # Wrong: number instead of string
            }
        ),
    )
    assert result.returncode == 1
    assert "result must be a string" in result.stderr


def test_append_rejects_non_string_reason(tmp_path):
    """Test that reason must be a string in blocked events."""
    parent = append(
        tmp_path,
        {
            "event": "created",
            "desc": "parent",
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
                "event": "blocked",
                "id": parent["id"],
                "reason": {"error": "something"},  # Wrong: dict instead of string
            }
        ),
    )
    assert result.returncode == 1
    assert "reason must be a string" in result.stderr
