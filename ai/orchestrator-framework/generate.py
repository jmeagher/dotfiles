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
        agent_name = data["name"]
        if agent_name in agents:
            raise GenerateError(f"duplicate agent name '{agent_name}' in {path} and other file")
        agents[agent_name] = data
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
    except (KeyError, TypeError):
        raise GenerateError(f"agent '{agent['name']}': no models.tiers.{harness}.{tier} entry")
    if model is None:
        raise GenerateError(
            f"agent '{agent['name']}': models.tiers.{harness}.{tier} is null -- "
            f"set it in models.local.yaml before generating for {harness}"
        )
    return model


def render_markdown_agent(agent, harness, model):
    tools = agent["tools"][harness]
    frontmatter = {
        "name": agent["name"],
        "description": agent["description"].strip(),
    }

    if harness == "opencode":
        # OpenCode's tool permissions are a map (permission: {name: allow/ask/deny}),
        # not a comma-joined list. The "*" sentinel means "omit the field entirely",
        # matching Claude Code's own omit-for-all-tools convention below.
        if tools != "*":
            frontmatter["permission"] = tools
    else:
        # Claude Code (and any other list-based markdown harness): comma-joined
        # tool names. ["*"] means "omit tools: entirely" -- Claude Code has no
        # wildcard token; omitting the field is the documented way to grant all
        # tools to a subagent.
        if tools != ["*"]:
            # Validate that wildcard is not mixed with other tools
            if "*" in tools and len(tools) > 1:
                raise GenerateError(
                    f"agent '{agent['name']}': wildcard '*' cannot be mixed with other tool names in {harness}"
                )
            frontmatter["tools"] = tools

    frontmatter["model"] = model

    # Use yaml.safe_dump to properly escape special characters in frontmatter
    frontmatter_yaml = yaml.safe_dump(frontmatter, default_flow_style=False, sort_keys=False)
    frontmatter_lines = ["---"] + frontmatter_yaml.rstrip().split("\n") + ["---"]

    return "\n".join(frontmatter_lines) + "\n\n" + agent["prompt"].strip() + "\n"


def write_markdown_agents(agents, models, harness, out_dir):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    # Load manifest of previously generated files
    manifest_path = out_dir / ".orchestrator-generated.json"
    previous_generated = set()
    if manifest_path.exists():
        try:
            manifest_data = json.loads(manifest_path.read_text())
            # Validate structure: must be a dict with a list "agents" field
            if not isinstance(manifest_data, dict):
                raise ValueError("manifest top-level must be a dict")
            agents_list = manifest_data.get("agents", [])
            if not isinstance(agents_list, list):
                raise ValueError("manifest 'agents' field must be a list")
            previous_generated = set(agents_list)
        except (json.JSONDecodeError, ValueError) as e:
            # On any parse/shape failure, fail safe: treat as empty manifest
            # (do not crash, do not delete anything)
            print(f"warning: corrupted manifest {manifest_path}, treating as empty: {e}", file=sys.stderr)
            previous_generated = set()

    # Clean up orphaned agent .md files: only delete files we generated before
    # that are no longer in the current agent set
    current_agent_names = set(agent["name"] for agent in agents.values())
    for existing_md in out_dir.glob("*.md"):
        agent_name = existing_md.stem
        # Only delete if: (1) we generated it before, AND (2) it's not in current set
        if agent_name in previous_generated and agent_name not in current_agent_names:
            existing_md.unlink()

    # Write current agents
    for agent in agents.values():
        model = resolve_model(agent, harness, models)
        (out_dir / f"{agent['name']}.md").write_text(render_markdown_agent(agent, harness, model))

    # Write manifest of generated files for next run
    manifest_path.write_text(json.dumps({"agents": sorted(current_agent_names)}, indent=2) + "\n")


def write_claude_code(agents, models, out_dir):
    write_markdown_agents(agents, models, "claude-code", out_dir)


def write_opencode(agents, models, out_dir):
    write_markdown_agents(agents, models, "opencode", out_dir)


def render_cursor(agents, models):
    modes = []
    for agent in agents.values():
        model = resolve_model(agent, "cursor", models)
        cursor_tools = agent["tools"]["cursor"]

        # Validate that wildcard is not mixed with other tools
        if isinstance(cursor_tools, list) and "*" in cursor_tools and len(cursor_tools) > 1:
            raise GenerateError(
                f"agent '{agent['name']}': wildcard '*' cannot be mixed with other tool names in cursor"
            )

        mode = {
            "name": agent["name"],
            "description": agent["description"].strip(),
            "model": model,
            "prompt": agent["prompt"].strip(),
        }

        # For Cursor, ["*"] means full access (omit the tools field entirely),
        # following the same omit-for-full-access convention as Claude Code.
        # Otherwise, include the concrete tool list.
        if cursor_tools != ["*"]:
            mode["tools"] = cursor_tools

        modes.append(mode)
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
