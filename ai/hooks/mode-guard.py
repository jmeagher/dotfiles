#!/usr/bin/env python3
"""
Mode guard hook for Claude Code.

Fires on UserPromptSubmit and PreToolUse (Agent calls).
Blocks execution with an interactive /dev/tty confirmation whenever any of:
  - The active model name contains "opus"
  - The active model name contains "max"  (Max mode)
  - settings.json has thinking mode enabled

Every prompt requires explicit confirmation — there is NO session-level bypass.
This script is intended to replace opus-guard.py (see ai/README.md).
"""

import json
import os
import sys

SETTINGS_PATH = os.path.expanduser("~/.claude/settings.json")


# ── Settings helpers ──────────────────────────────────────────────────────────


def read_settings() -> dict:
    try:
        with open(SETTINGS_PATH) as f:
            return json.load(f)
    except Exception:
        return {}


def get_effective_model() -> str:
    """Resolve the active model, preferring env var over settings alias."""
    env_model = os.environ.get("ANTHROPIC_MODEL", "")
    if env_model:
        return env_model

    settings = read_settings()
    alias = settings.get("model", "")
    if alias == "opus":
        return os.environ.get("ANTHROPIC_DEFAULT_OPUS_MODEL", "claude-opus-4-6")
    if alias == "sonnet":
        return os.environ.get("ANTHROPIC_DEFAULT_SONNET_MODEL", "claude-sonnet-4-6")
    if alias == "haiku":
        return os.environ.get("ANTHROPIC_DEFAULT_HAIKU_MODEL", "claude-haiku-4-5")
    return alias


def is_thinking_enabled(settings: dict) -> bool:
    # Claude Code may store thinking mode under different keys depending on version.
    # Add or remove keys here if your setup uses a different field name.
    return bool(
        settings.get("thinking")
        or settings.get("extendedThinking")
        or settings.get("enableThinking")
    )


# ── Interactive confirmation ──────────────────────────────────────────────────


def confirm_via_tty(title: str, details: list) -> bool:
    """
    Opens /dev/tty to warn the user and read yes/no.
    Returns True if confirmed; fails closed (blocks) if tty is unavailable.
    """
    try:
        with open("/dev/tty", "r+") as tty:
            border = "=" * 60
            tty.write(f"\n{border}\n")
            tty.write(f"  ⚠️  {title}\n")
            tty.write(f"{border}\n")
            for line in details:
                tty.write(f"  {line}\n")
            tty.write(f"{border}\n")
            tty.write("\n  Send this prompt anyway? [yes/no]: ")
            tty.flush()
            response = tty.readline().strip().lower()
        return response in ("yes", "y")
    except Exception as e:
        print(
            f"MODE GUARD: Cannot open terminal for confirmation ({e}). Blocking.",
            file=sys.stderr,
        )
        return False


def block(reason: str) -> None:
    print(f"\n🚫 Prompt blocked — {reason}.", file=sys.stderr)
    sys.exit(2)


# ── Event handlers ────────────────────────────────────────────────────────────


def check_model_and_modes(model: str, settings: dict) -> None:
    """Run all three checks. Each prompts independently; any denial blocks."""
    model_lower = model.lower()

    if "opus" in model_lower:
        confirmed = confirm_via_tty(
            "OPUS MODEL ACTIVE",
            [
                f"Model : {model}",
                "Opus is significantly more expensive than Sonnet.",
                "Confirmation required for every prompt — no session bypass.",
            ],
        )
        if not confirmed:
            block("Opus not confirmed. Switch with /model sonnet")

    if "max" in model_lower:
        confirmed = confirm_via_tty(
            "MAX MODE ACTIVE",
            [
                f"Model : {model}",
                "Max mode uses higher-cost rate limits.",
                "Confirmation required for every prompt — no session bypass.",
            ],
        )
        if not confirmed:
            block("Max mode not confirmed")

    if is_thinking_enabled(settings):
        confirmed = confirm_via_tty(
            "THINKING MODE ACTIVE",
            [
                f"Model : {model}",
                "Extended thinking consumes additional tokens.",
                "Confirmation required for every prompt — no session bypass.",
            ],
        )
        if not confirmed:
            block("Thinking mode not confirmed")


def handle_user_prompt_submit(data: dict) -> None:
    model = get_effective_model()
    settings = read_settings()
    check_model_and_modes(model, settings)


def handle_pre_tool_use_agent(data: dict) -> None:
    """Also guards Agent subagent calls, which may override the session model."""
    tool_input = data.get("tool_input", {})
    explicit_model = tool_input.get("model", "")
    session_model = get_effective_model()
    agent_model = explicit_model if explicit_model else session_model

    settings = read_settings()
    check_model_and_modes(agent_model, settings)


# ── Entry point ───────────────────────────────────────────────────────────────


def main() -> None:
    try:
        data = json.loads(sys.stdin.read())
    except Exception:
        sys.exit(0)

    event = data.get("hook_event_name", "")
    tool_name = data.get("tool_name", "")

    if event == "UserPromptSubmit":
        handle_user_prompt_submit(data)
    elif event == "PreToolUse" and tool_name == "Agent":
        handle_pre_tool_use_agent(data)

    sys.exit(0)


if __name__ == "__main__":
    main()
