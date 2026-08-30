#!/usr/bin/env python3
"""Deterministic drift tests for GitHub MCP client configuration."""

import json
import re
import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "config/agent-mcp-contract.json"
CAPABILITIES = ROOT / "config/agent-credential-capabilities.json"
CURSOR = ROOT / ".cursor/mcp.json"
GROK = ROOT / ".grok/config.toml"
MCP_DOC = ROOT / ".github/github-mcp.md"
SECRET_VALUE = re.compile(r"github_pat_[A-Za-z0-9_]+|gh[pousr]_[A-Za-z0-9_]+|Bearer\s+(?!\$|<|PASTE_)[A-Za-z0-9_.-]{20,}")


def _markdown_section(text: str, heading: str) -> str:
    match = re.search(
        rf"^## {re.escape(heading)}\n(.*?)(?=^## |\Z)",
        text,
        re.MULTILINE | re.DOTALL,
    )
    if match is None:
        raise AssertionError(f"missing markdown section: {heading}")
    return match.group(1)


def _first_json_block(section: str) -> dict:
    match = re.search(r"```json\n(.*?)```", section, re.DOTALL)
    if match is None:
        raise AssertionError("missing json example in section")
    parsed = json.loads(match.group(1))
    if not isinstance(parsed, dict):
        raise AssertionError("json example must be an object")
    return parsed


class AgentMcpContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
        cls.capability_contract = json.loads(CAPABILITIES.read_text(encoding="utf-8"))
        cls.cursor = json.loads(CURSOR.read_text(encoding="utf-8"))["mcpServers"]["github"]
        cls.grok = tomllib.loads(GROK.read_text(encoding="utf-8"))["mcp_servers"]["github"]
        cls.doc = MCP_DOC.read_text(encoding="utf-8")
        cls.antigravity_example = _first_json_block(
            _markdown_section(cls.doc, "Antigravity")
        )
        cls.copilot_example = _first_json_block(
            _markdown_section(cls.doc, "GitHub Copilot / VS Code")
        )

    def test_contract_defers_to_policy_and_capability_contract(self) -> None:
        self.assertEqual(self.contract["authority"], "AGENTS.md")
        self.assertEqual(self.contract["capability_contract"], "config/agent-credential-capabilities.json")
        self.assertEqual(set(self.contract["clients"]), set(self.capability_contract["clients"]))

    def test_tracked_cursor_configuration_matches_contract(self) -> None:
        expected = self.contract["clients"]["cursor"]
        self.assertEqual(expected["path"], ".cursor/mcp.json")
        self.assertEqual(self.cursor[expected["endpoint_field"]], self.contract["endpoint"])
        self.assertEqual(self.cursor["headers"]["Authorization"], expected["credential_syntax"])
        self.assertEqual(self.cursor["headers"]["X-MCP-Toolsets"], ",".join(self.contract["toolsets"]))
        self.assertNotIn("X-MCP-Readonly", self.cursor["headers"])
        self.assertEqual(
            self.capability_contract["clients"]["cursor"]["github_auth"]["credential_variable"],
            "CURSOR_GH_PAT",
        )

    def test_tracked_grok_configuration_matches_contract_and_is_read_only(self) -> None:
        expected = self.contract["clients"]["grok_build"]
        self.assertEqual(expected["path"], ".grok/config.toml")
        self.assertEqual(self.grok[expected["endpoint_field"]], self.contract["endpoint"])
        self.assertEqual(self.grok["headers"]["Authorization"], expected["credential_syntax"])
        self.assertEqual(self.grok["headers"]["X-MCP-Toolsets"], ",".join(self.contract["toolsets"]))
        self.assertEqual(self.grok["headers"]["X-MCP-Readonly"], "true")
        self.assertEqual(self.capability_contract["clients"]["grok_build"]["default_posture"], "read_only")
        self.assertTrue(all(
            value == "read_only"
            for value in self.capability_contract["clients"]["grok_build"]["capabilities"].values()
        ))

    def test_documented_antigravity_expectation_matches_capability_contract(self) -> None:
        expected = self.contract["clients"]["antigravity"]
        capability = self.capability_contract["clients"]["antigravity"]
        self.assertEqual(expected["configuration"], "documented_untracked")
        self.assertEqual(expected["credential_variable"], capability["github_auth"]["credential_variable"])
        self.assertEqual(capability["capabilities"]["projects"], "read_only_by_default")
        for marker in (
            "~/.gemini/antigravity/mcp_config.json",
            '"serverUrl": "https://api.githubcopilot.com/mcp/"',
            "ANTIGRAVITY_GH_PAT",
            "Leave `X-MCP-Readonly` unset unless Antigravity should be GitHub-read-only.",
            "Keep the token at `read:project` unless Project mutation is explicitly",
        ):
            self.assertIn(marker, self.doc)
        headers = self.antigravity_example["mcpServers"]["github"]["headers"]
        self.assertEqual(
            self.antigravity_example["mcpServers"]["github"][expected["endpoint_field"]],
            self.contract["endpoint"],
        )
        self.assertEqual(headers.get("X-MCP-Toolsets"), ",".join(self.contract["toolsets"]))
        self.assertNotIn("all", headers.get("X-MCP-Toolsets", "").split(","))
        self.assertNotIn("X-MCP-Readonly", headers)

    def test_documented_copilot_expectation_matches_native_auth_contract(self) -> None:
        expected = self.contract["clients"]["github_copilot"]
        capability = self.capability_contract["clients"]["github_copilot"]
        self.assertEqual(expected["auth_mode"], capability["github_auth"]["mode"])
        self.assertIsNone(capability["github_auth"]["credential_variable"])
        self.assertIn("Prefer GitHub-native OAuth", self.doc)
        self.assertIn("OAuth configuration (no Authorization header):", self.doc)
        headers = self.copilot_example["servers"]["github"]["headers"]
        self.assertEqual(
            self.copilot_example["servers"]["github"][expected["endpoint_field"]],
            self.contract["endpoint"],
        )
        self.assertEqual(headers.get("X-MCP-Toolsets"), ",".join(self.contract["toolsets"]))
        self.assertNotIn("all", headers.get("X-MCP-Toolsets", "").split(","))
        self.assertNotIn("Authorization", headers)

    def test_toolset_and_endpoint_drift_is_rejected(self) -> None:
        expected = ",".join(self.contract["toolsets"])
        self.assertEqual(self.contract["toolsets"], ["default", "projects"])
        self.assertNotIn("all", self.contract["toolsets"])
        self.assertFalse(self.contract["endpoint"].endswith("/mcp/x/projects"))
        documented = {
            "cursor": self.cursor["headers"]["X-MCP-Toolsets"],
            "grok_build": self.grok["headers"]["X-MCP-Toolsets"],
            "antigravity": self.antigravity_example["mcpServers"]["github"]["headers"].get(
                "X-MCP-Toolsets"
            ),
            "github_copilot": self.copilot_example["servers"]["github"]["headers"].get(
                "X-MCP-Toolsets"
            ),
        }
        for client, toolsets in documented.items():
            with self.subTest(client=client):
                self.assertEqual(toolsets, expected)
                self.assertNotEqual(toolsets, "all")
                self.assertNotIn("all", (toolsets or "").split(","))

    def test_tracked_configs_are_secret_free_and_use_portable_names(self) -> None:
        for path in (CURSOR, GROK):
            text = path.read_text(encoding="utf-8")
            with self.subTest(path=str(path.relative_to(ROOT))):
                self.assertNotRegex(text, SECRET_VALUE)
        for variable in (
            self.capability_contract["clients"]["cursor"]["github_auth"]["credential_variable"],
            self.capability_contract["clients"]["grok_build"]["github_auth"]["credential_variable"],
            self.capability_contract["clients"]["antigravity"]["github_auth"]["credential_variable"],
        ):
            self.assertFalse(variable.startswith("GITHUB_"))
            self.assertFalse(variable.endswith("_API_KEY"))

    def test_clients_do_not_share_credentials(self) -> None:
        variables = [
            client["github_auth"]["credential_variable"]
            for client in self.capability_contract["clients"].values()
            if client["github_auth"]["credential_variable"] is not None
        ]
        self.assertEqual(len(variables), len(set(variables)))
        self.assertTrue(self.capability_contract["invariants"]["no_shared_unrestricted_pat"])

    def test_validation_is_static_and_never_requires_write_probe(self) -> None:
        invariants = self.contract["invariants"]
        self.assertTrue(invariants["no_live_write_probe"])
        self.assertTrue(invariants["capability_contract_is_upper_bound"])
        self.assertIn("Perform only harmless reads first.", self.doc)
        self.assertIn("Do not modify a Project merely to\nprove connectivity.", self.doc)
        self.assertIn("Do not weaken token permissions, rulesets, or branch protection to make\na test pass.", self.doc)


if __name__ == "__main__":
    unittest.main()
