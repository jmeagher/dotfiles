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
        "opencode": {"read": "allow", "bash": "allow", "edit": "deny"},
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
    # Verify that tools list is present and contains the expected tools
    # (yaml.safe_dump may format as multi-line array, which is valid YAML)
    assert "tools:" in content
    assert "- Read" in content
    assert "- Bash" in content


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
    assert "\n  read: allow" in content
    assert "\n  bash: allow" in content
    assert "\n  edit: deny" in content


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
    # For full access (["*"]), the tools field should be omitted entirely,
    # following the same omit-for-full-access convention as Claude Code.
    # Omitting the field means unrestricted tool access in Cursor.
    assert "tools" not in data["modes"][0]


def test_write_cursor_includes_tools_for_restricted_agent(tmp_path):
    agents_dir = tmp_path / "agents"
    agents_dir.mkdir()
    (agents_dir / "reviewer.yaml").write_text(yaml.safe_dump(FIXTURE_RESTRICTED_AGENT))
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
    assert data["modes"][0]["name"] == "reviewer"
    # For restricted agents, tools should be included in the output
    assert "tools" in data["modes"][0]
    assert data["modes"][0]["tools"] == ["read", "terminal"]


def test_render_markdown_agent_escapes_colon_in_description(tmp_path):
    agent = {**FIXTURE_AGENT, "description": "Does: things, and stuff #important"}
    rendered = generate.render_markdown_agent(agent, "claude-code", "test-model")
    # Parse the frontmatter back to ensure it's valid YAML
    lines = rendered.split("\n")
    yaml_lines = []
    for line in lines[1:]:
        if line == "---":
            break
        yaml_lines.append(line)
    yaml_text = "\n".join(yaml_lines)
    parsed = yaml.safe_load(yaml_text)
    # Verify the colon and special chars are preserved
    assert parsed["description"] == "Does: things, and stuff #important"
    assert parsed["name"] == "worker"


def test_load_agents_detects_duplicate_names(tmp_path):
    agents_dir = tmp_path / "agents"
    agents_dir.mkdir()
    dup_agent = {**FIXTURE_AGENT, "name": "duplicate"}
    (agents_dir / "first.yaml").write_text(yaml.safe_dump(dup_agent))
    (agents_dir / "second.yaml").write_text(yaml.safe_dump(dup_agent))
    with pytest.raises(generate.GenerateError, match="duplicate agent name"):
        generate.load_agents(agents_dir)


def test_render_markdown_agent_rejects_mixed_wildcard_tools(tmp_path):
    agent = {**FIXTURE_AGENT, "tools": {"claude-code": ["*", "Read"]}}
    with pytest.raises(generate.GenerateError, match="wildcard '\\*' cannot be mixed"):
        generate.render_markdown_agent(agent, "claude-code", "test-model")


def test_render_cursor_rejects_mixed_wildcard_tools(tmp_path):
    agent = {**FIXTURE_AGENT, "tools": {"cursor": ["*", "read"]}}
    models = {
        "tiers": {
            **FIXTURE_MODELS["tiers"],
            "cursor": {"high": "x", "medium": "y", "low": "cursor-low-model"},
        }
    }
    with pytest.raises(generate.GenerateError, match="wildcard '\\*' cannot be mixed"):
        generate.render_cursor({"agent": agent}, models)


def test_resolve_model_handles_malformed_models_yaml(tmp_path):
    # Test with non-dict value at harness level (malformed)
    malformed_models = {"tiers": {"claude-code": "not-a-dict"}}
    agent = {**FIXTURE_AGENT, "tier": "low"}
    with pytest.raises(generate.GenerateError, match="no models.tiers"):
        generate.resolve_model(agent, "claude-code", malformed_models)


def test_write_markdown_agents_removes_orphaned_files(tmp_path):
    # Create agents directory with two agents
    agents_dir = tmp_path / "agents"
    agents_dir.mkdir()
    agent1 = {**FIXTURE_AGENT, "name": "agent1"}
    agent2 = {**FIXTURE_AGENT, "name": "agent2"}
    (agents_dir / "agent1.yaml").write_text(yaml.safe_dump(agent1))
    (agents_dir / "agent2.yaml").write_text(yaml.safe_dump(agent2))
    agents = generate.load_agents(agents_dir)

    # First write: should create both .md files
    out_dir = tmp_path / "output"
    generate.write_markdown_agents(agents, FIXTURE_MODELS, "claude-code", out_dir)
    assert (out_dir / "agent1.md").exists()
    assert (out_dir / "agent2.md").exists()

    # Now remove agent2 from agents dict
    del agents["agent2"]

    # Second write: should delete orphaned agent2.md
    generate.write_markdown_agents(agents, FIXTURE_MODELS, "claude-code", out_dir)
    assert (out_dir / "agent1.md").exists()
    assert not (out_dir / "agent2.md").exists()


def test_write_markdown_agents_preserves_foreign_files(tmp_path):
    """Test that unrelated, user-installed agent files are never deleted."""
    # Create agents directory with one agent
    agents_dir = tmp_path / "agents"
    agents_dir.mkdir()
    agent1 = {**FIXTURE_AGENT, "name": "agent1"}
    (agents_dir / "agent1.yaml").write_text(yaml.safe_dump(agent1))
    agents = generate.load_agents(agents_dir)

    # First write: should create agent1.md
    out_dir = tmp_path / "output"
    generate.write_markdown_agents(agents, FIXTURE_MODELS, "claude-code", out_dir)
    assert (out_dir / "agent1.md").exists()

    # Manually create a foreign agent file (user-installed, not from this generator)
    foreign_file = out_dir / "my-personal-note-taker.md"
    foreign_file.write_text("---\nname: my-personal-note-taker\n---\nMy custom prompt\n")
    assert foreign_file.exists()

    # Second write: should NOT delete the foreign file
    # (since manifest only lists agent1, my-personal-note-taker won't be in it)
    generate.write_markdown_agents(agents, FIXTURE_MODELS, "claude-code", out_dir)
    assert (out_dir / "agent1.md").exists()
    assert foreign_file.exists(), "Foreign file should not be deleted"


def test_write_markdown_agents_creates_and_uses_manifest(tmp_path):
    """Test that the generator creates a manifest and uses it for cleanup."""
    # Create agents directory with two agents
    agents_dir = tmp_path / "agents"
    agents_dir.mkdir()
    agent1 = {**FIXTURE_AGENT, "name": "agent1"}
    agent2 = {**FIXTURE_AGENT, "name": "agent2"}
    (agents_dir / "agent1.yaml").write_text(yaml.safe_dump(agent1))
    (agents_dir / "agent2.yaml").write_text(yaml.safe_dump(agent2))
    agents = generate.load_agents(agents_dir)

    out_dir = tmp_path / "output"
    manifest_path = out_dir / ".orchestrator-generated.json"

    # First write: should create manifest
    generate.write_markdown_agents(agents, FIXTURE_MODELS, "claude-code", out_dir)
    assert manifest_path.exists()
    manifest = json.loads(manifest_path.read_text())
    assert set(manifest["agents"]) == {"agent1", "agent2"}

    # Remove agent2, write again
    del agents["agent2"]
    generate.write_markdown_agents(agents, FIXTURE_MODELS, "claude-code", out_dir)

    # Manifest should now only list agent1
    manifest = json.loads(manifest_path.read_text())
    assert manifest["agents"] == ["agent1"]
    assert not (out_dir / "agent2.md").exists()


def test_write_markdown_agents_handles_corrupted_manifest(tmp_path, capsys):
    """Test that corrupted/malformed manifest is handled gracefully without crashing."""
    # Create agents directory with one agent
    agents_dir = tmp_path / "agents"
    agents_dir.mkdir()
    agent1 = {**FIXTURE_AGENT, "name": "agent1"}
    (agents_dir / "agent1.yaml").write_text(yaml.safe_dump(agent1))
    agents = generate.load_agents(agents_dir)

    out_dir = tmp_path / "output"
    manifest_path = out_dir / ".orchestrator-generated.json"

    # First write: create agent1.md and manifest
    generate.write_markdown_agents(agents, FIXTURE_MODELS, "claude-code", out_dir)
    assert (out_dir / "agent1.md").exists()
    assert manifest_path.exists()

    # Corrupt the manifest with garbage JSON
    manifest_path.write_text("{ this is not valid json }")

    # Second write: should NOT crash, should treat manifest as empty
    # (do not delete agent1.md, do not crash on JSONDecodeError)
    generate.write_markdown_agents(agents, FIXTURE_MODELS, "claude-code", out_dir)

    # Verify: agent1.md still exists (was not deleted)
    assert (out_dir / "agent1.md").exists(), "Agent file should not be deleted on corrupted manifest"

    # Verify: warning was printed to stderr
    captured = capsys.readouterr()
    assert "warning" in captured.err
    assert "corrupted manifest" in captured.err


def test_write_markdown_agents_handles_manifest_wrong_structure(tmp_path, capsys):
    """Test that manifest with wrong structure (non-dict, non-list agents) is handled gracefully."""
    # Create agents directory with one agent
    agents_dir = tmp_path / "agents"
    agents_dir.mkdir()
    agent1 = {**FIXTURE_AGENT, "name": "agent1"}
    (agents_dir / "agent1.yaml").write_text(yaml.safe_dump(agent1))
    agents = generate.load_agents(agents_dir)

    out_dir = tmp_path / "output"
    manifest_path = out_dir / ".orchestrator-generated.json"

    # First write: create agent1.md
    generate.write_markdown_agents(agents, FIXTURE_MODELS, "claude-code", out_dir)
    assert (out_dir / "agent1.md").exists()

    # Write a malformed manifest: top-level is an array instead of dict
    manifest_path.write_text(json.dumps(["agent1", "agent2"]))

    # Second write: should NOT crash, should treat manifest as empty
    generate.write_markdown_agents(agents, FIXTURE_MODELS, "claude-code", out_dir)

    # Verify: agent1.md still exists
    assert (out_dir / "agent1.md").exists(), "Agent file should not be deleted on malformed manifest structure"

    # Verify: warning was printed
    captured = capsys.readouterr()
    assert "warning" in captured.err
    assert "corrupted manifest" in captured.err


def test_write_markdown_agents_handles_manifest_non_list_agents(tmp_path, capsys):
    """Test that manifest with non-list agents field is handled gracefully."""
    # Create agents directory with one agent
    agents_dir = tmp_path / "agents"
    agents_dir.mkdir()
    agent1 = {**FIXTURE_AGENT, "name": "agent1"}
    (agents_dir / "agent1.yaml").write_text(yaml.safe_dump(agent1))
    agents = generate.load_agents(agents_dir)

    out_dir = tmp_path / "output"
    manifest_path = out_dir / ".orchestrator-generated.json"

    # First write: create agent1.md
    generate.write_markdown_agents(agents, FIXTURE_MODELS, "claude-code", out_dir)
    assert (out_dir / "agent1.md").exists()

    # Write a malformed manifest: agents field is a dict instead of list
    manifest_path.write_text(json.dumps({"agents": {"agent1": True}}))

    # Second write: should NOT crash, should treat manifest as empty
    generate.write_markdown_agents(agents, FIXTURE_MODELS, "claude-code", out_dir)

    # Verify: agent1.md still exists
    assert (out_dir / "agent1.md").exists(), "Agent file should not be deleted on malformed agents field"

    # Verify: warning was printed
    captured = capsys.readouterr()
    assert "warning" in captured.err
    assert "corrupted manifest" in captured.err
