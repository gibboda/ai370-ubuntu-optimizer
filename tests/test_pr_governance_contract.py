#!/usr/bin/env python3
"""Deterministic tests for pull-request governance and advisory AI review."""

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "config/pr-governance.json"
AGENT_ROLES = ROOT / "config/agent-roles.json"
AGENTS_POLICY = ROOT / "AGENTS.md"
MCP_POLICY = ROOT / ".github/github-mcp.md"


class PullRequestGovernanceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
        cls.roles = json.loads(AGENT_ROLES.read_text(encoding="utf-8"))

    def test_contract_defers_to_agents_md(self) -> None:
        self.assertEqual(self.contract["schema_version"], 1)
        self.assertEqual(self.contract["authority"], "AGENTS.md")
        self.assertEqual(self.contract["target_branch"], "main")

    def test_expected_main_governance_is_explicit(self) -> None:
        ruleset = self.contract["ruleset"]
        self.assertEqual(ruleset["name"], "Protect main")
        self.assertEqual(ruleset["enforcement"], "active")
        self.assertTrue(ruleset["require_pull_request"])
        self.assertGreaterEqual(ruleset["minimum_approving_reviews"], 1)
        self.assertTrue(ruleset["require_review_thread_resolution"])
        self.assertEqual(ruleset["required_status_checks"], ["ShellCheck"])

    def test_required_checks_do_not_include_advisory_ai(self) -> None:
        advisory = self.contract["advisory_ai_review"]
        self.assertFalse(advisory["merge_gate"])
        self.assertFalse(advisory["required_status_check"])
        required = [name.casefold() for name in self.contract["ruleset"]["required_status_checks"]]
        for term in advisory["forbidden_required_check_terms"]:
            with self.subTest(term=term):
                self.assertFalse(
                    any(term.casefold() in check for check in required),
                    f"Advisory AI term {term!r} must not appear in a required merge check.",
                )

    def test_independent_reviewer_remains_advisory(self) -> None:
        reviewer = self.roles["roles"]["independent_reviewer"]
        advisory = self.contract["advisory_ai_review"]
        self.assertIn(reviewer["provider"], advisory["providers"])
        self.assertTrue(reviewer["advisory"])
        self.assertFalse(reviewer["merge_gate"])
        self.assertFalse(reviewer["automatic"])

    def test_governance_invariants_match_agent_policy(self) -> None:
        invariants = self.contract["invariants"]
        self.assertTrue(invariants["human_final_authority"])
        self.assertTrue(invariants["deterministic_checks_authoritative_for_machine_verifiable_facts"])
        self.assertTrue(invariants["optional_ai_unavailability_must_not_block_merge"])
        self.assertTrue(invariants["mcp_access_does_not_bypass_governance"])

        agents = AGENTS_POLICY.read_text(encoding="utf-8")
        self.assertIn("human maintainer retains final decision authority", agents)
        self.assertIn("AI reviews are advisory", agents)
        self.assertIn("They are not required merge gates", agents)
        self.assertIn("MCP access cannot bypass protected branches", agents)

    def test_mcp_document_preserves_governance_boundary(self) -> None:
        text = " ".join(MCP_POLICY.read_text(encoding="utf-8").split())
        self.assertIn(
            "GitHub rulesets and branch protection remain the final merge authority",
            text,
        )
        self.assertIn("MCP credentials must not bypass those controls", text)


if __name__ == "__main__":
    unittest.main()
