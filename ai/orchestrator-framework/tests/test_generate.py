import sys
from pathlib import Path

import pytest
import yaml

sys.path.insert(0, str(Path(__file__).parent.parent))
import generate  # noqa: E402

FIXTURE_AGENT = {
    "name": "worker",
    "description": "Test worker agent.",
    "tier": "low",
    "tools": {"claude-code": ["*"], "opencode": ["*"], "cursor": ["*"]},
    "prompt": "You are the test worker.\n",
}

FIXTURE_MODELS = {
    "tiers": {
        "claude-code": {
            "high": "claude-opus-4-8",
            "medium": "claude-sonnet-5",
            "low": "claude-haiku-4-5-20251001",
        },
        "opencode": {"high": None, "medium": None, "low": "opencode-low-model"},
        "cursor": {"high": None, "medium": None, "low": None},
    }
}


def write_fixture_agents(tmp_path):
    agents_dir = tmp_path / "agents"
    agents_dir.mkdir()
    (agents_dir / "worker.yaml").write_text(yaml.safe_dump(FIXTURE_AGENT))
    return agents_dir


def write_fixture_models(tmp_path):
    models_path = tmp_path / "models.yaml"
    models_path.write_text(yaml.safe_dump(FIXTURE_MODELS))
    return models_path


def test_load_agents_reads_all_required_fields(tmp_path):
    agents_dir = write_fixture_agents(tmp_path)
    agents = generate.load_agents(agents_dir)
    assert agents["worker"]["tier"] == "low"


def test_load_agents_rejects_missing_field(tmp_path):
    agents_dir = tmp_path / "agents"
    agents_dir.mkdir()
    (agents_dir / "broken.yaml").write_text(yaml.safe_dump({"name": "broken"}))
    with pytest.raises(generate.GenerateError, match="missing required field"):
        generate.load_agents(agents_dir)


def test_deep_merge_local_overrides_win(tmp_path):
    models_path = write_fixture_models(tmp_path)
    local_path = tmp_path / "models.local.yaml"
    local_path.write_text(yaml.safe_dump({"tiers": {"opencode": {"high": "custom-model"}}}))
    models = generate.load_models(models_path, local_path)
    assert models["tiers"]["opencode"]["high"] == "custom-model"
    assert models["tiers"]["opencode"]["low"] == "opencode-low-model"


def test_load_models_without_local_file_uses_base(tmp_path):
    models_path = write_fixture_models(tmp_path)
    models = generate.load_models(models_path, tmp_path / "does-not-exist.yaml")
    assert models["tiers"]["claude-code"]["high"] == "claude-opus-4-8"


def test_resolve_model_fails_loudly_on_null():
    agent = {**FIXTURE_AGENT, "tier": "high"}
    with pytest.raises(generate.GenerateError, match="is null"):
        generate.resolve_model(agent, "cursor", FIXTURE_MODELS)


def test_resolve_model_returns_concrete_id():
    agent = {**FIXTURE_AGENT, "tier": "low"}
    assert generate.resolve_model(agent, "claude-code", FIXTURE_MODELS) == "claude-haiku-4-5-20251001"
