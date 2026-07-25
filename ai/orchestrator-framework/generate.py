#!/usr/bin/env python3
"""Generate harness-native agent files from the neutral agents/*.yaml source."""
import argparse
import copy
import json
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


def write_opencode(agents, models, out_dir):
    write_markdown_agents(agents, models, "opencode", out_dir)


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
