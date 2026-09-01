#!/usr/bin/env python3
"""Semantic tests for AI client credential capability boundaries."""

import json
import re
import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAPABILITIES = ROOT / "config/agent-credential-capabilities.json"
ROLES = ROOT / "config/agent-roles.json"
MCP_DOC = ROOT / ".github/github-mcp.md"
POLICY = ROOT / "docs/AGENT-CREDENTIAL-CAPABILITIES.md"
ARCHITECTURE = ROOT / "docs/AI-AGENT-ARCHITECTURE.md"
CURSOR_MCP = ROOT / ".cursor/mcp.json"
GROK_MCP = ROOT / ".grok/config.toml"
SECRET_VALUE = re.compile(r"github_pat_[A-Za-z0-9_]+|gh[pousr]_[A-Za-z0-9_]+|xai-[A-Za-z0-9]+|AIza[0-9A-Za-z_-]+")


class AgentCredentialCapabilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = json.loads(CAPABILITIES.read_text(encoding="utf-8"))
        cls.roles = json.loads(ROLES.read_text(encoding="utf-8"))["roles"]
        cls.clients = cls.contract["clients"]

    def test_contract_defers_to_agents_md_and_contains_no_secret_values(self) -> None:
        self.assertEqual(self.contract["authority"], "AGENTS.md")
        self.assertTrue(self.contract["invariants"]["no_secret_values"])
        self.assertNotRegex(CAPABILITIES.read_text(encoding="utf-8"), SECRET_VALUE)

    def test_clients_map_to_existing_roles(self) -> None:
        expected = {
            "cursor": "primary_orchestrator",
            "grok_build": "independent_reviewer",
            "antigravity": "secondary_specialist",
            "github_copilot": "github_native_fallback",
        }
        self.assertEqual(set(self.clients), set(expected))
        for client, role in expected.items():
            with self.subTest(client=client):
                self.assertEqual(self.clients[client]["role"], role)
                self.assertIn(role, self.roles)

    def test_each_client_has_separate_github_authorization(self) -> None:
        variables = []
        for client in self.clients.values():
            auth = client["github_auth"]
            self.assertEqual(auth["credential_domain"], "github")
            self.assertFalse(auth["shared_credential_allowed"])
            if auth["credential_variable"] is not None:
                variables.append(auth["credential_variable"])
        self.assertEqual(len(variables), len(set(variables)))
        self.assertEqual(set(variables), {"CURSOR_GH_PAT", "GROK_GH_PAT", "ANTIGRAVITY_GH_PAT"})

    def test_repository_defined_names_avoid_reserved_patterns(self) -> None:
        variables = [
            client["github_auth"]["credential_variable"]
            for client in self.clients.values()
            if client["github_auth"]["credential_variable"] is not None
        ]
        for variable in variables:
            with self.subTest(variable=variable):
                self.assertFalse(variable.startswith("GITHUB_"))
                self.assertFalse(variable.endswith("_API_KEY"))
        self.assertEqual(self.contract["credential_domains"]["github"]["reserved_prefixes"], ["GITHUB_"])
        self.assertEqual(self.contract["credential_domains"]["github"]["forbidden_suffixes"], ["_API_KEY"])
        self.assertTrue(self.contract["invariants"]["portable_secret_names"])

    def test_grok_is_read_only(self) -> None:
        grok = self.clients["grok_build"]
        self.assertEqual(grok["default_posture"], "read_only")
        self.assertTrue(all(value == "read_only" for value in grok["capabilities"].values()))
        self.assertTrue(self.roles["independent_reviewer"]["advisory"])
        self.assertFalse(self.roles["independent_reviewer"]["merge_gate"])
        advice = grok["advice_record"]
        self.assertTrue(advice["required_when_assigned"])
        self.assertEqual(advice["github_review_state"], "comment_only")
        self.assertFalse(advice["mcp_write"])
        self.assertTrue(advice["out_of_band_comment_allowed"])
        self.assertEqual(set(advice["proxy_posters"]), {"cursor", "codeowner"})

    def test_antigravity_projects_are_read_only_by_default(self) -> None:
        antigravity = self.clients["antigravity"]
        self.assertEqual(antigravity["default_posture"], "read_by_default")
        self.assertEqual(antigravity["capabilities"]["projects"], "read_only_by_default")
        self.assertIn("explicit project permission", antigravity["mutation_condition"])
        advice = antigravity["advice_record"]
        self.assertTrue(advice["required_when_assigned"])
        self.assertEqual(advice["github_review_state"], "comment_only")
        self.assertFalse(advice["mcp_write"])

    def test_cursor_projects_require_authorization(self) -> None:
        cursor = self.clients["cursor"]
        self.assertEqual(cursor["capabilities"]["projects"], "read_write_when_authorized")
        self.assertEqual(cursor["github_auth"]["credential_variable"], "CURSOR_GH_PAT")

    def test_copilot_prefers_github_native_auth(self) -> None:
        copilot = self.clients["github_copilot"]
        self.assertEqual(copilot["github_auth"]["mode"], "oauth_or_session")
        self.assertIsNone(copilot["github_auth"]["credential_variable"])
        self.assertTrue(all(value == "authorization_dependent" for value in copilot["capabilities"].values()))

    def test_vendor_credentials_cannot_authorize_github(self) -> None:
        self.assertTrue(self.contract["credential_domains"]["vendor"]["must_not_be_used_for_github_authorization"])
        naming = self.contract["credential_domains"]["vendor"]["preferred_naming"]
        self.assertIn("do not start with GITHUB_", naming)
        self.assertIn("do not end in _API_KEY", naming)

    def test_least_privilege_and_governance_invariants(self) -> None:
        invariants = self.contract["invariants"]
        self.assertTrue(invariants["least_privilege"])
        self.assertTrue(invariants["separate_client_credentials"])
        self.assertTrue(invariants["no_shared_unrestricted_pat"])
        self.assertTrue(invariants["github_governance_not_bypassable"])

    def test_documentation_matches_client_contract(self) -> None:
        mcp = MCP_DOC.read_text(encoding="utf-8")
        policy = POLICY.read_text(encoding="utf-8")
        architecture = ARCHITECTURE.read_text(encoding="utf-8")
        for variable in ("CURSOR_GH_PAT", "GROK_GH_PAT", "ANTIGRAVITY_GH_PAT"):
            self.assertIn(variable, mcp)
            self.assertIn(variable, policy)
            self.assertIn(variable, architecture)
        for legacy in ("GITHUB_CURSOR_PAT", "GITHUB_GROK_PAT", "GITHUB_ANTIGRAVITY_PAT"):
            self.assertNotIn(legacy, mcp)
            self.assertNotIn(legacy, policy)
            self.assertNotIn(legacy, architecture)
        self.assertIn("`AGENTS.md` remains authoritative", policy)
        self.assertIn("does not grant permissions", policy)
        self.assertIn("upper bound, not an instruction to mutate", policy)
        self.assertIn("Consumers must fail closed", policy)

    def test_tracked_mcp_configs_use_declared_client_variables(self) -> None:
        cursor_var = self.clients["cursor"]["github_auth"]["credential_variable"]
        grok_var = self.clients["grok_build"]["github_auth"]["credential_variable"]
        cursor_auth = json.loads(CURSOR_MCP.read_text(encoding="utf-8"))[
            "mcpServers"
        ]["github"]["headers"]["Authorization"]
        grok_headers = tomllib.loads(GROK_MCP.read_text(encoding="utf-8"))[
            "mcp_servers"
        ]["github"]["headers"]
        grok_auth = grok_headers["Authorization"]
        self.assertIn(f"${{env:{cursor_var}}}", cursor_auth)
        self.assertEqual(grok_auth, f"Bearer ${{{grok_var}}}")
        self.assertNotIn(grok_var, cursor_auth)
        self.assertNotIn(cursor_var, grok_auth)
        for auth in (cursor_auth, grok_auth):
            self.assertNotIn("GITHUB_", auth)
            self.assertNotIn("_API_KEY", auth)
        self.assertEqual(grok_headers["X-MCP-Readonly"], "true")


if __name__ == "__main__":
    unittest.main()
