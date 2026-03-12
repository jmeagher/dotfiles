#!/usr/bin/env python3
"""
Idle notification hook for Claude Code.

Registered for two events in settings.json:
  UserPromptSubmit  — records when the user last sent a prompt
  Stop              — records when Claude last finished; notifies if the user
                      has not sent a new prompt since the previous Stop and
                      that was more than IDLE_THRESHOLD_SECONDS ago

How the idle check works:
  Two timestamp files track state across all sessions:
    STOP_FILE   — written at every Stop (when Claude finishes and hands off)
    PROMPT_FILE — written at every UserPromptSubmit (when user is active)

  On Stop, a notification fires only when ALL of:
    1. A previous Stop exists (not the very first response)
    2. The user has NOT sent a prompt since that previous Stop
       (last_prompt <= last_stop  →  user is away)
    3. It has been >= IDLE_THRESHOLD_SECONDS since that previous Stop

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

# Seconds since Claude last finished before a notification fires.
IDLE_THRESHOLD_SECONDS = 60

# Shared timestamp files (visible to all Claude sessions via /tmp).
STOP_FILE = "/tmp/claude_last_stop_time"
PROMPT_FILE = "/tmp/claude_last_prompt_time"

# Message spoken (macOS) or beeped (other) when the notification fires.
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


def read_timestamp(path: str) -> float | None:
    """Return the float timestamp from a file, or None if missing/unreadable."""
    try:
        with open(path) as f:
            return float(f.read().strip())
    except Exception:
        return None


def write_timestamp(path: str) -> None:
    try:
        with open(path, "w") as f:
            f.write(str(time.time()))
    except Exception:
        pass


# ── Entry point ───────────────────────────────────────────────────────────────


def main() -> None:
    try:
        data = json.loads(sys.stdin.read())
    except Exception:
        sys.exit(0)

    event = data.get("hook_event_name", "")

    if event == "UserPromptSubmit":
        write_timestamp(PROMPT_FILE)

    elif event == "Stop":
        now = time.time()
        last_stop = read_timestamp(STOP_FILE)
        last_prompt = read_timestamp(PROMPT_FILE)

        if (
            last_stop is not None                        # not the very first response
            and (last_prompt is None or last_prompt <= last_stop)  # no new prompt since last Stop
            and (now - last_stop) >= IDLE_THRESHOLD_SECONDS
        ):
            platform_notify(NOTIFY_MSG)

        write_timestamp(STOP_FILE)

    sys.exit(0)


if __name__ == "__main__":
    main()
