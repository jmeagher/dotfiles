import json
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
    "tools": {"claude-code": ["*"], "opencode": "*", "cursor": ["*"]},
    "prompt": "You are the test worker.\n",
}

FIXTURE_RESTRICTED_AGENT = {
    "name": "reviewer",
    "description": "Test reviewer agent.",
    "tier": "low",
    "tools": {
        "claude-code": ["Read", "Bash"],
        "opencode": {"read": "allow", "bash": "allow"},
        "cursor": ["read", "terminal"],
    },
    "prompt": "You are the test reviewer.\n",
}

FIXTURE_MODELS = {
    "tiers": {
        "claude-code": {
            "high": None,
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
    assert models["tiers"]["claude-code"]["high"] is None


def test_resolve_model_fails_loudly_on_null():
    agent = {**FIXTURE_AGENT, "tier": "high"}
    with pytest.raises(generate.GenerateError, match="is null"):
        generate.resolve_model(agent, "cursor", FIXTURE_MODELS)


def test_resolve_model_returns_concrete_id():
    agent = {**FIXTURE_AGENT, "tier": "low"}
    assert generate.resolve_model(agent, "claude-code", FIXTURE_MODELS) == "claude-haiku-4-5-20251001"


def test_write_claude_code_omits_tools_line_for_wildcard(tmp_path):
    agents_dir = write_fixture_agents(tmp_path)
    agents = generate.load_agents(agents_dir)
    out_dir = tmp_path / "claude-out"
    generate.write_claude_code(agents, FIXTURE_MODELS, out_dir)
    content = (out_dir / "worker.md").read_text()
    assert "name: worker" in content
    assert "model: claude-haiku-4-5-20251001" in content
    assert "tools:" not in content
    assert "You are the test worker." in content


def test_write_claude_code_renders_explicit_tools_list(tmp_path):
    agents_dir = tmp_path / "agents"
    agents_dir.mkdir()
    (agents_dir / "reviewer.yaml").write_text(yaml.safe_dump(FIXTURE_RESTRICTED_AGENT))
    agents = generate.load_agents(agents_dir)
    out_dir = tmp_path / "claude-out"
    generate.write_claude_code(agents, FIXTURE_MODELS, out_dir)
    content = (out_dir / "reviewer.md").read_text()
    assert "tools: Read, Bash" in content


def test_write_claude_code_fails_loudly_on_null_model(tmp_path):
    agents_dir = write_fixture_agents(tmp_path)
    agent = generate.load_agents(agents_dir)
    agent["worker"]["tier"] = "high"
    out_dir = tmp_path / "claude-out"
    with pytest.raises(generate.GenerateError, match="is null"):
        generate.write_claude_code(agent, FIXTURE_MODELS, out_dir)


def test_write_opencode_omits_permission_for_wildcard(tmp_path):
    agents_dir = write_fixture_agents(tmp_path)
    agents = generate.load_agents(agents_dir)
    out_dir = tmp_path / "opencode-out"
    generate.write_opencode(agents, FIXTURE_MODELS, out_dir)
    content = (out_dir / "worker.md").read_text()
    assert "name: worker" in content
    assert "model: opencode-low-model" in content
    assert "permission:" not in content
    assert "You are the test worker." in content


def test_write_opencode_renders_permission_map(tmp_path):
    agents_dir = tmp_path / "agents"
    agents_dir.mkdir()
    (agents_dir / "reviewer.yaml").write_text(yaml.safe_dump(FIXTURE_RESTRICTED_AGENT))
    agents = generate.load_agents(agents_dir)
    out_dir = tmp_path / "opencode-out"
    generate.write_opencode(agents, FIXTURE_MODELS, out_dir)
    content = (out_dir / "reviewer.md").read_text()
    assert "permission:" in content
    assert "read: allow" in content
    assert "bash: allow" in content


def test_write_cursor_raises_when_model_unset(tmp_path):
    agents_dir = write_fixture_agents(tmp_path)
    agents = generate.load_agents(agents_dir)
    agents["worker"]["tier"] = "high"
    out_path = tmp_path / "modes.json"
    with pytest.raises(generate.GenerateError, match="is null"):
        generate.write_cursor(agents, FIXTURE_MODELS, out_path)


def test_write_cursor_structure_when_model_set(tmp_path):
    agents_dir = write_fixture_agents(tmp_path)
    agents = generate.load_agents(agents_dir)
    models = {
        "tiers": {
            **FIXTURE_MODELS["tiers"],
            "cursor": {"high": "x", "medium": "y", "low": "cursor-low-model"},
        }
    }
    out_path = tmp_path / "modes.json"
    generate.write_cursor(agents, models, out_path)
    data = json.loads(out_path.read_text())
    assert data["modes"][0]["name"] == "worker"
    assert data["modes"][0]["model"] == "cursor-low-model"
    assert data["modes"][0]["tools"] == ["*"]
