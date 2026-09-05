#!/usr/bin/env python3
"""Cross-contract invariants for the repository multi-agent architecture.

AGENTS.md remains authoritative. This suite does not introduce a new manifest;
it proves that the existing machine-readable contracts agree with one another.
"""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROLES_PATH = ROOT / "config/agent-roles.json"
ESCALATION_PATH = ROOT / "config/agent-escalation-record.schema.json"
ALLOCATION_PATH = ROOT / "config/agent-work-allocation.schema.json"
CREDENTIALS_PATH = ROOT / "config/agent-credential-capabilities.json"
MCP_PATH = ROOT / "config/agent-mcp-contract.json"
GOVERNANCE_PATH = ROOT / "config/pr-governance.json"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def role_providers(roles):
    providers = {}
    for role_name, role in roles["roles"].items():
        if "provider" in role:
            providers[role["provider"]] = role_name
        for provider in role.get("providers", []):
            providers[provider] = role_name
    return providers


def bearer_variable(client):
    syntax = client.get("credential_syntax")
    if not syntax:
        return client.get("credential_variable")
    match = re.search(r"\$\{(?:env:)?([A-Z][A-Z0-9_]*)\}", syntax)
    return match.group(1) if match else None


class AgentCrossContractConsistencyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.roles = load(ROLES_PATH)
        cls.escalation = load(ESCALATION_PATH)
        cls.allocation = load(ALLOCATION_PATH)
        cls.credentials = load(CREDENTIALS_PATH)
        cls.mcp = load(MCP_PATH)
        cls.governance = load(GOVERNANCE_PATH)
        cls.providers = role_providers(cls.roles)

    def test_all_contracts_defer_to_agents_md(self):
        for name, contract in (
            ("roles", self.roles),
            ("credentials", self.credentials),
            ("mcp", self.mcp),
            ("governance", self.governance),
        ):
            with self.subTest(contract=name):
                self.assertEqual(contract["authority"], "AGENTS.md")
        self.assertIn("AGENTS.md", self.escalation["description"])
        self.assertIn("AGENTS.md", self.allocation["description"])

    def test_credential_client_roles_match_canonical_role_contract(self):
        for client_name, client in self.credentials["clients"].items():
            with self.subTest(client=client_name):
                self.assertIn(client_name, self.providers)
                self.assertEqual(client["role"], self.providers[client_name])

    def test_mcp_clients_are_credential_clients(self):
        self.assertEqual(
            set(self.mcp["clients"]),
            set(self.credentials["clients"]),
            "Every MCP client must have exactly one credential-capability definition.",
        )
        self.assertEqual(
            self.mcp["capability_contract"],
            "config/agent-credential-capabilities.json",
        )
        self.assertTrue(self.mcp["invariants"]["capability_contract_is_upper_bound"])

    def test_mcp_credentials_match_credential_contract(self):
        for client_name, mcp_client in self.mcp["clients"].items():
            credential = self.credentials["clients"][client_name]["github_auth"]
            expected = credential["credential_variable"]
            actual = bearer_variable(mcp_client)
            with self.subTest(client=client_name):
                self.assertEqual(actual, expected)

    def test_read_only_reviewer_is_read_only_across_contracts(self):
        reviewer = self.roles["roles"]["independent_reviewer"]
        provider = reviewer["provider"]
        credential = self.credentials["clients"][provider]
        mcp = self.mcp["clients"][provider]

        self.assertTrue(reviewer["advisory"])
        self.assertFalse(reviewer["merge_gate"])
        self.assertFalse(reviewer["automatic"])
        self.assertEqual(credential["role"], "independent_reviewer")
        self.assertEqual(credential["default_posture"], "read_only")
        self.assertTrue(
            all(value == "read_only" for value in credential["capabilities"].values())
        )
        self.assertEqual(mcp["readonly_header"], "true")
        self.assertFalse(credential["advice_record"]["mcp_write"])
        self.assertTrue(credential["advice_record"]["required_when_assigned"])
        advice_fc = credential["advice_record"]["form_constraints"]
        self.assertEqual(advice_fc["comment_review"]["github_review_state"], "comment_only")
        self.assertIsNone(advice_fc["pull_request_comment"]["github_review_state"])
        self.assertFalse(self.governance["advisory_ai_review"]["merge_gate"])
        self.assertFalse(self.governance["advisory_ai_review"]["required_status_check"])
        self.assertIn(provider, self.governance["advisory_ai_review"]["providers"])

    def test_primary_orchestrator_consistency(self):
        primary = self.roles["roles"]["primary_orchestrator"]
        provider = primary["provider"]
        credential = self.credentials["clients"][provider]

        self.assertEqual(primary["count"], 1)
        self.assertTrue(primary["default_task_owner"])
        self.assertEqual(provider, "cursor")
        self.assertEqual(self.allocation["properties"]["primary_resource"]["const"], provider)
        self.assertEqual(credential["role"], "primary_orchestrator")
        self.assertNotEqual(credential["default_posture"], "read_only")
        self.assertIn(provider, self.mcp["clients"])

    def test_escalation_and_allocation_resource_sets_match(self):
        escalation_resources = set(
            self.escalation["properties"]["selected_resource"]["enum"]
        )
        allocation_resources = set(
            self.allocation["properties"]["additional_resource"]["enum"]
        )
        self.assertEqual(escalation_resources, allocation_resources)
        self.assertNotIn("cursor", escalation_resources)
        self.assertNotIn("github", escalation_resources)

    def test_escalation_resources_resolve_to_canonical_roles_or_documented_alias(self):
        resources = set(self.escalation["properties"]["selected_resource"]["enum"])
        aliases = {"antigravity_cli": "antigravity"}
        for resource in resources:
            canonical = aliases.get(resource, resource)
            with self.subTest(resource=resource):
                self.assertIn(canonical, self.providers)
                self.assertNotEqual(self.providers[canonical], "primary_orchestrator")
                self.assertNotEqual(self.providers[canonical], "merge_authority")

    def test_governance_advisory_resources_cover_escalation_ai_resources(self):
        escalation_resources = set(
            self.escalation["properties"]["selected_resource"]["enum"]
        )
        advisory_resources = set(self.governance["advisory_ai_review"]["providers"])
        self.assertTrue(escalation_resources.issubset(advisory_resources))
        self.assertEqual(advisory_resources - escalation_resources, {"cursor_bugbot"})
        self.assertNotIn("cursor_bugbot", escalation_resources)

    def test_no_ai_role_can_be_merge_authority(self):
        merge_authority = self.roles["roles"]["merge_authority"]
        self.assertFalse(merge_authority["ai_allowed"])
        self.assertTrue(merge_authority["human_final"])
        self.assertTrue(self.governance["invariants"]["human_final_authority"])
        self.assertTrue(self.credentials["invariants"]["github_governance_not_bypassable"])
        self.assertTrue(self.governance["invariants"]["mcp_access_does_not_bypass_governance"])

    def test_review_pipeline_providers_remain_advisory_and_not_merge_gates(self):
        pipeline = self.governance["review_pipeline"]
        advisory = self.governance["advisory_ai_review"]
        advisory_providers = set(advisory["providers"])
        second_look = pipeline["second_look"]
        final_pass = pipeline["final_advisory_specialist_pass"]
        required_checks = self.governance["ruleset"]["required_status_checks"]

        self.assertEqual(pipeline["required_github_reviewer"], "gibboda")
        self.assertTrue(pipeline["required_github_reviewer_is_codeowner"])
        self.assertTrue(self.governance["ruleset"]["require_code_owner_reviews"])
        self.assertTrue(set(second_look["providers"]).issubset(advisory_providers))
        self.assertNotIn("antigravity_cli", second_look["providers"])
        fallback = second_look["independent_reviewer_fallback"]
        self.assertEqual(fallback["provider"], "antigravity_cli")
        self.assertEqual(fallback["when"], "grok_build_unavailable")
        self.assertEqual(fallback["replaces"], "grok_build")
        self.assertFalse(fallback["peer_of_grok_build"])
        self.assertTrue(fallback["may_be_assigned_when_grok_available"])
        self.assertEqual(
            second_look["advice_record"]["form_constraints"]["comment_review"]["github_review_state"],
            "comment_only",
        )
        self.assertTrue(second_look["advice_record"]["required_when_assigned"])
        self.assertFalse(second_look["advice_record"]["satisfies_branch_protection"])
        self.assertIn(fallback["provider"], advisory_providers)
        self.assertTrue(
            set(second_look["cli_advisory_reviewers"]).issubset(advisory_providers)
        )
        self.assertTrue(set(final_pass["providers"]).issubset(advisory_providers))
        self.assertFalse(final_pass["process_required"])
        self.assertEqual(final_pass["process_required_for"], ["high"])
        self.assertEqual(final_pass["process_required_for"], final_pass["required_risk_tiers"])
        self.assertTrue(final_pass["risk_tiered"])
        self.assertEqual(final_pass["required_risk_tiers"], ["high"])
        self.assertEqual(final_pass["risk_tier_precedence"], "highest_matching_wins")
        self.assertFalse(second_look["merge_gate"])
        self.assertFalse(second_look["required_status_check"])
        self.assertFalse(final_pass["satisfies_branch_protection"])
        self.assertFalse(final_pass["merge_gate"])
        self.assertFalse(final_pass["required_status_check"])
        self.assertFalse(advisory["merge_gate"])
        self.assertFalse(advisory["required_status_check"])
        for provider in set(second_look["providers"]) | {fallback["provider"]} | set(final_pass["providers"]):
            self.assertNotIn(provider, required_checks)

    def test_deterministic_validation_precedence_is_consistent(self):
        validation = self.roles["roles"]["deterministic_validation"]
        merge_validation = self.roles["roles"]["merge_validation"]
        governance = self.governance["invariants"]

        self.assertTrue(validation["before_ai_escalation"])
        self.assertTrue(validation["authoritative_for_machine_verifiable_facts"])
        self.assertTrue(merge_validation["deterministic"])
        self.assertTrue(
            governance["deterministic_checks_authoritative_for_machine_verifiable_facts"]
        )
        self.assertTrue(governance["optional_ai_unavailability_must_not_block_merge"])

    def test_credential_and_mcp_security_invariants_align(self):
        credentials = self.credentials["invariants"]
        mcp = self.mcp["invariants"]
        self.assertTrue(credentials["separate_client_credentials"])
        self.assertTrue(credentials["no_shared_unrestricted_pat"])
        self.assertTrue(mcp["no_shared_unrestricted_pat"])
        self.assertTrue(credentials["portable_secret_names"])
        self.assertTrue(mcp["no_reserved_credential_prefix"])
        self.assertTrue(mcp["no_api_key_suffix"])


if __name__ == "__main__":
    unittest.main()
