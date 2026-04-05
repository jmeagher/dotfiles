#!/usr/bin/env python3
"""
Idle notification hook for Claude Code.

Registered for events via hooks/hooks.json:
  UserPromptSubmit  — records timestamp; sets tmux window to "⚙ processing"
  Stop              — sets tmux window to "✓ done"; plays sound + desktop banner;
                      if idle longer than IDLE_THRESHOLD_SECONDS, speaks a notification
  Notification      — sets tmux window to "⏳ waiting"; plays sound + desktop banner

Platform behavior:
  macOS   : runs `say "<message>"`, `afplay <sound>`, and `osascript` notifications
  Linux   : runs `espeak "<message>"` (if available), `paplay`/`aplay` for sound,
            and `notify-send` for desktop banners; falls back to terminal bell
  Others  : tries `beep`, then falls back to a terminal bell via /dev/tty
"""

import json
import os
import subprocess
import sys
import time
import urllib.request

# ── Configuration ─────────────────────────────────────────────────────────────

# Seconds of inactivity before a notification fires on Stop.
IDLE_THRESHOLD_SECONDS = 60

# File used to share the "last prompt" timestamp across all Claude sessions.
TIMESTAMP_FILE = "/tmp/claude_last_prompt_time"

# Message spoken (macOS) or beeped (other) when the Stop event fires idle.
# Common alternatives: "waiting for input", "Claude is done", "your turn"
NOTIFY_MSG = "all done"

# ntfy topic for push notifications. If unset or empty, ntfy notifications are skipped.
# Set to a topic name to receive push notifications via https://ntfy.sh/<topic>.
# CLAUDE_NTFY_TOPIC=

# Controls whether `say`/`espeak` speech is used. Set to "0" or "false" to disable.
# Default (unset or any other value): speech is enabled.
# CLAUDE_SAY_ENABLED=

MACOS_SOUND_FILE = "/System/Library/Sounds/Ping.aiff"

# Candidate Linux sound files (freedesktop standard paths); first existing one is used.
LINUX_SOUND_FILES = [
    "/usr/share/sounds/freedesktop/stereo/complete.oga",
    "/usr/share/sounds/freedesktop/stereo/bell.oga",
    "/usr/share/sounds/ubuntu/stereo/bell.ogg",
]

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


def _cmd_exists(cmd: str) -> bool:
    """Return True if cmd is found on PATH."""
    return subprocess.run(["which", cmd], capture_output=True).returncode == 0


def sound_notify(title: str, message: str) -> None:
    """Play a sound and show a desktop notification banner."""
    if sys.platform == "darwin":
        subprocess.Popen(["afplay", MACOS_SOUND_FILE])
        subprocess.run(
            ["osascript", "-e", f'display notification "{message}" with title "{title}"'],
            check=False,
        )
        return

    # Linux: play first available sound file with paplay or aplay
    sound_file = next((f for f in LINUX_SOUND_FILES if os.path.exists(f)), None)
    if sound_file:
        for player in ("paplay", "aplay"):
            if _cmd_exists(player):
                subprocess.Popen([player, sound_file])
                break

    # Linux: desktop banner via notify-send
    if _cmd_exists("notify-send"):
        subprocess.run(["notify-send", title, message], check=False)


def ntfy_notify(title: str, message: str) -> None:
    """Send a push notification via ntfy.sh if CLAUDE_NTFY_TOPIC is set."""
    topic = os.environ.get("CLAUDE_NTFY_TOPIC", "")
    if not topic:
        return
    try:
        url = f"https://ntfy.sh/{topic}"
        req = urllib.request.Request(
            url,
            data=message.encode("utf-8"),
            headers={"Title": title},
            method="POST",
        )
        urllib.request.urlopen(req, timeout=5)
    except Exception:
        pass


def platform_say(message: str) -> None:
    """Speak a message (macOS/Linux) or beep (other platforms)."""
    if sys.platform == "darwin":
        subprocess.run(["say", message], check=False)
        return

    # Linux: use espeak if available
    if _cmd_exists("espeak"):
        subprocess.run(["espeak", message], check=False)
        return

    # Fallback: try `beep`, then terminal bell
    try:
        if _cmd_exists("beep"):
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


def _say_if_enabled(message: str) -> None:
    """Call platform_say unless CLAUDE_SAY_ENABLED is set to '0' or 'false'."""
    val = os.environ.get("CLAUDE_SAY_ENABLED", "")
    if val.lower() in ("0", "false"):
        return
    platform_say(message)


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
        sound_notify("Claude: Task finished", tmux_info)
        ntfy_notify("Claude: Task finished", tmux_info)
        if elapsed_seconds() >= IDLE_THRESHOLD_SECONDS:
            _say_if_enabled(NOTIFY_MSG)

    elif event == "Notification":
        tmux_info = get_tmux_info()
        set_tmux_window_name("⏳ waiting")
        sound_notify("Claude: Attention needed", tmux_info)
        ntfy_notify("Claude: Attention needed", tmux_info)

    sys.exit(0)


if __name__ == "__main__":
    main()
