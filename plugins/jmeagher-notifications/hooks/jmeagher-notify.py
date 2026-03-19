#!/usr/bin/env python3
"""
Idle notification hook for Claude Code.

Registered for events via hooks/hooks.json:
  UserPromptSubmit  — records timestamp; sets tmux window to "⚙ processing"
  Stop              — sets tmux window to "✓ done"; plays sound + macOS banner;
                      if idle longer than IDLE_THRESHOLD_SECONDS, speaks a notification
  Notification      — sets tmux window to "⏳ waiting"; plays sound + macOS banner
  SubagentStop      — speaks a notification with tmux context

Platform behavior:
  macOS   : runs `say "<message>"`, `afplay <sound>`, and `osascript` notifications
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

# Message spoken (macOS) or beeped (other) when the Stop event fires idle.
# Common alternatives: "waiting for input", "Claude is done", "your turn"
NOTIFY_MSG = "all done"

SOUND_FILE = "/System/Library/Sounds/Ping.aiff"

# ── tmux helpers ──────────────────────────────────────────────────────────────


def in_tmux() -> bool:
    return bool(os.environ.get("TMUX"))


def get_tmux_info() -> str:
    """Return 'session:window' if inside tmux, else 'unknown'."""
    if not in_tmux():
        return "unknown"
    result = subprocess.run(
        ["tmux", "display-message", "-p", "#S:#W"],
        capture_output=True, text=True, check=False,
    )
    return result.stdout.strip() if result.returncode == 0 else "unknown"


def set_tmux_window_name(name: str) -> None:
    """Rename the current tmux window if inside tmux."""
    if not in_tmux():
        return
    subprocess.run(["tmux", "rename-window", name], check=False)


# ── Platform notification ─────────────────────────────────────────────────────


def macos_sound_notify(title: str, message: str) -> None:
    """Play a sound and show a macOS notification banner."""
    subprocess.Popen(["afplay", SOUND_FILE])
    subprocess.run(
        ["osascript", "-e", f'display notification "{message}" with title "{title}"'],
        check=False,
    )


def platform_say(message: str) -> None:
    """Speak a message (macOS) or beep (other platforms)."""
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
        set_tmux_window_name("⚙ processing")

    elif event == "Stop":
        tmux_info = get_tmux_info()
        set_tmux_window_name("✓ done")
        if sys.platform == "darwin":
            macos_sound_notify("Claude: Task finished", tmux_info)
        if elapsed_seconds() >= IDLE_THRESHOLD_SECONDS:
            platform_say(NOTIFY_MSG)

    elif event == "Notification":
        tmux_info = get_tmux_info()
        set_tmux_window_name("⏳ waiting")
        if sys.platform == "darwin":
            macos_sound_notify("Claude: Attention needed", tmux_info)

    elif event == "SubagentStop":
        tmux_info = get_tmux_info()
        platform_say(f"Subagent finished in {tmux_info}")

    sys.exit(0)


if __name__ == "__main__":
    main()
