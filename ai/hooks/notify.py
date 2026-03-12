#!/usr/bin/env python3
"""
Idle notification hook for Claude Code.

Registered for two events in settings.json:
  UserPromptSubmit  — records the current timestamp (shared across all sessions)
  Stop              — if idle longer than IDLE_THRESHOLD_SECONDS, speaks a notification

Platform behavior:
  macOS   : runs `say "<message>"`
  Others  : tries `beep`, then falls back to a terminal bell via /dev/tty
"""

import json
import os
import subprocess
import sys
import time

# ── Configuration ─────────────────────────────────────────────────────────────

# Seconds of inactivity before a notification fires on Stop.
IDLE_THRESHOLD_SECONDS = 60

# File used to share the "last prompt" timestamp across all Claude sessions.
TIMESTAMP_FILE = "/tmp/claude_last_prompt_time"

# Message spoken (macOS) or beeped (other) when the Stop event fires.
# Common alternatives: "waiting for input", "Claude is done", "your turn"
NOTIFY_MSG = "all done"

# ── Platform notification ─────────────────────────────────────────────────────


def platform_notify(message: str) -> None:
    if sys.platform == "darwin":
        subprocess.run(["say", message], check=False)
        return

    # Non-macOS: try `beep`, fall back to terminal bell
    try:
        result = subprocess.run(["which", "beep"], capture_output=True)
        if result.returncode == 0:
            subprocess.run(["beep"], check=False)
            return
    except Exception:
        pass

    try:
        with open("/dev/tty", "w") as tty:
            tty.write("\a")
            tty.flush()
    except Exception:
        pass


# ── Timestamp helpers ─────────────────────────────────────────────────────────


def update_timestamp() -> None:
    try:
        with open(TIMESTAMP_FILE, "w") as f:
            f.write(str(time.time()))
    except Exception:
        pass


def elapsed_seconds() -> float:
    """Seconds since the last recorded prompt, or 0 if no record exists."""
    try:
        with open(TIMESTAMP_FILE) as f:
            last = float(f.read().strip())
        return time.time() - last
    except Exception:
        return 0.0


# ── Entry point ───────────────────────────────────────────────────────────────


def main() -> None:
    try:
        data = json.loads(sys.stdin.read())
    except Exception:
        sys.exit(0)

    event = data.get("hook_event_name", "")

    if event == "UserPromptSubmit":
        update_timestamp()

    elif event == "Stop":
        if elapsed_seconds() >= IDLE_THRESHOLD_SECONDS:
            platform_notify(NOTIFY_MSG)

    sys.exit(0)


if __name__ == "__main__":
    main()
