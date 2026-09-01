#!/usr/bin/env python3
"""Deterministic tests for pull-request governance and advisory AI review."""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "config/pr-governance.json"
AGENT_ROLES = ROOT / "config/agent-roles.json"
AGENTS_POLICY = ROOT / "AGENTS.md"
MCP_POLICY = ROOT / ".github/github-mcp.md"
CODEOWNERS = ROOT / ".github/CODEOWNERS"
_OWNER_TOKEN = re.compile(r"@[A-Za-z0-9][A-Za-z0-9_-]*(?:/[A-Za-z0-9][A-Za-z0-9_-]*)?")


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
        self.assertTrue(ruleset["require_code_owner_reviews"])
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
        self.assertEqual(set(reviewer["providers"]), {"grok_build", "antigravity_cli"})
        self.assertEqual(reviewer["also_serves"], ["specialist_advisor"])
        self.assertEqual(reviewer["github_review_state"], "comment_only")
        self.assertTrue(reviewer["advice_record_required"])

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
        self.assertIn("COMMENT-only pull-request comment or COMMENT review", agents)

    def test_mcp_document_preserves_governance_boundary(self) -> None:
        text = " ".join(MCP_POLICY.read_text(encoding="utf-8").split())
        self.assertIn(
            "GitHub rulesets and branch protection remain the final merge authority",
            text,
        )
        self.assertIn("MCP credentials must not bypass those controls", text)

    def test_review_pipeline_requires_codeowner_and_keeps_ai_advisory(self) -> None:
        pipeline = self.contract["review_pipeline"]
        advisory = self.contract["advisory_ai_review"]
        advisory_providers = set(advisory["providers"])
        required_checks = self.contract["ruleset"]["required_status_checks"]
        required_folded = [name.casefold() for name in required_checks]

        self.assertEqual(pipeline["required_github_reviewer"], "gibboda")
        self.assertTrue(pipeline["required_github_reviewer_is_codeowner"])
        self.assertTrue(self.contract["ruleset"]["require_code_owner_reviews"])

        second_look = pipeline["second_look"]
        final_pass = pipeline["final_advisory_specialist_pass"]
        fallback = second_look["independent_reviewer_fallback"]
        self.assertEqual(set(second_look["providers"]), {"grok_build", "antigravity"})
        self.assertNotIn("antigravity_cli", second_look["providers"])
        self.assertTrue(set(second_look["providers"]).issubset(advisory_providers))
        self.assertTrue(set(final_pass["providers"]).issubset(advisory_providers))
        self.assertEqual(second_look["assignable_by"], "codeowner")
        self.assertEqual(second_look["selection"], "any_or_both")
        self.assertEqual(
            set(second_look["allowed_roles"]),
            {"independent_reviewer", "secondary_specialist", "specialist_advisor"},
        )
        self.assertEqual(
            set(second_look["cli_advisory_reviewers"]),
            {"grok_build", "antigravity_cli"},
        )
        self.assertEqual(second_look["github_review_state"], "comment_only")
        advice_record = second_look["advice_record"]
        self.assertTrue(advice_record["required_when_assigned"])
        self.assertEqual(
            set(advice_record["forms"]),
            {"pull_request_comment", "comment_review"},
        )
        self.assertTrue(advice_record["attribution_required"])
        self.assertEqual(
            set(advice_record["forbidden_states"]),
            {"approve", "request_changes"},
        )
        self.assertFalse(advice_record["satisfies_branch_protection"])
        self.assertFalse(advice_record["mcp_write"])
        self.assertEqual(set(advice_record["proxy_posters"]), {"cursor", "codeowner"})
        self.assertEqual(fallback["provider"], "antigravity_cli")
        self.assertEqual(fallback["when"], "grok_build_unavailable")
        self.assertEqual(fallback["replaces"], "grok_build")
        self.assertEqual(fallback["does_not_replace"], "antigravity")
        self.assertFalse(fallback["peer_of_grok_build"])
        self.assertTrue(fallback["may_be_assigned_when_grok_available"])
        self.assertIn(fallback["provider"], advisory_providers)
        self.assertFalse(second_look["github_codeowners_identity"])
        self.assertFalse(second_look["merge_gate"])
        self.assertFalse(second_look["required_status_check"])
        self.assertTrue(final_pass["process_required"])
        self.assertEqual(final_pass["selection"], "any_or_both")
        self.assertEqual(final_pass["github_review_state"], "comment_only")
        self.assertFalse(final_pass["satisfies_branch_protection"])
        self.assertFalse(final_pass["merge_gate"])
        self.assertFalse(final_pass["required_status_check"])
        self.assertFalse(advisory["merge_gate"])
        self.assertFalse(advisory["required_status_check"])

        pipeline_providers = (
            set(second_look["providers"])
            | set(second_look["cli_advisory_reviewers"])
            | {fallback["provider"]}
            | set(final_pass["providers"])
        )
        for provider in pipeline_providers:
            with self.subTest(provider=provider):
                self.assertNotIn(provider, required_checks)
                self.assertFalse(
                    any(provider.casefold() in check for check in required_folded),
                    f"Review-pipeline provider {provider!r} must not be a required status check.",
                )

    def test_codeowners_contains_only_gibboda_owner_tokens(self) -> None:
        text = CODEOWNERS.read_text(encoding="utf-8")
        owners: list[str] = []
        for line in text.splitlines():
            uncommented = line.split("#", 1)[0].strip()
            if not uncommented:
                continue
            owners.extend(_OWNER_TOKEN.findall(uncommented))
        self.assertTrue(owners)
        self.assertEqual(set(owners), {"@gibboda"})
        self.assertTrue(all(token == "@gibboda" for token in owners))
        self.assertIn("Human CODEOWNER is @gibboda", text)
        self.assertIn("GitHub CODEOWNERS cannot name AI products", text)
        self.assertIn("AI is never merge authority", text)
        agents = AGENTS_POLICY.read_text(encoding="utf-8")
        self.assertIn("### CODEOWNER review assignment", agents)
        self.assertIn("No AI agent is merge authority", agents)
        self.assertIn("AI unavailability must not block merge", agents)


if __name__ == "__main__":
    unittest.main()
