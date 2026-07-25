#!/usr/bin/env python3
"""Generate harness-native agent files from the neutral agents/*.yaml source."""
import copy
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


if __name__ == "__main__":
    sys.exit(1)  # CLI wiring added in Task 6
