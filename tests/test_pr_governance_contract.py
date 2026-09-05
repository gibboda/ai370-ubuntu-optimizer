#!/usr/bin/env python3
"""Deterministic tests for pull-request governance and advisory AI review."""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "config/pr-governance.json"
V1_FIXTURE = ROOT / "tests/fixtures/pr-governance/v1.json"
AGENT_ROLES = ROOT / "config/agent-roles.json"
AGENTS_POLICY = ROOT / "AGENTS.md"
MCP_POLICY = ROOT / ".github/github-mcp.md"
BUGBOT_POLICY = ROOT / ".cursor/BUGBOT.md"
CODEOWNERS = ROOT / ".github/CODEOWNERS"
PR_TEMPLATE = ROOT / ".github/PULL_REQUEST_TEMPLATE.md"
COMPATIBILITY_DOC = ROOT / "docs/AGENT-CONTRACT-COMPATIBILITY.md"
MAX_SUPPORTED_PR_GOVERNANCE_SCHEMA = 2
_OWNER_TOKEN = re.compile(r"@[A-Za-z0-9][A-Za-z0-9_-]*(?:/[A-Za-z0-9][A-Za-z0-9_-]*)?")


def specialist_pass_is_process_required(final_pass: dict, risk_tier: str) -> bool:
    """Interpret whether the advisory specialist pass is process-required."""
    schema_version = final_pass.get("schema_version")
    if schema_version is not None and schema_version > MAX_SUPPORTED_PR_GOVERNANCE_SCHEMA:
        raise ValueError(f"Unsupported pr-governance schema_version {schema_version}")
    if final_pass.get("risk_tiered"):
        required_for = final_pass.get("process_required_for") or final_pass.get(
            "required_risk_tiers", []
        )
        return risk_tier in required_for
    return bool(final_pass.get("process_required"))


def resolve_risk_tier(matched_criteria: list[str], final_pass: dict) -> str:
    """Return the highest matching risk tier, or the default when none match."""
    if final_pass.get("risk_tier_precedence") != "highest_matching_wins":
        raise ValueError("Unsupported risk_tier_precedence")
    rank = list(final_pass["risk_tier_rank"])
    criteria = final_pass["risk_tier_criteria"]
    matched_tiers = [
        tier
        for tier, names in criteria.items()
        if any(criterion in names for criterion in matched_criteria)
    ]
    if not matched_tiers:
        return final_pass["default_risk_tier"]
    return min(matched_tiers, key=rank.index)


class PullRequestGovernanceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
        cls.roles = json.loads(AGENT_ROLES.read_text(encoding="utf-8"))

    def test_contract_defers_to_agents_md(self) -> None:
        self.assertEqual(self.contract["schema_version"], MAX_SUPPORTED_PR_GOVERNANCE_SCHEMA)
        self.assertEqual(self.contract["authority"], "AGENTS.md")
        self.assertEqual(self.contract["target_branch"], "main")
        self.assertLessEqual(
            self.contract["schema_version"],
            MAX_SUPPORTED_PR_GOVERNANCE_SCHEMA,
            "Unknown future schema versions must fail closed until consumer support is added.",
        )

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
                self.assertFalse(any(term.casefold() in check for check in required))

    def test_independent_reviewer_remains_advisory(self) -> None:
        reviewer = self.roles["roles"]["independent_reviewer"]
        advisory = self.contract["advisory_ai_review"]
        self.assertIn(reviewer["provider"], advisory["providers"])
        self.assertTrue(reviewer["advisory"])
        self.assertFalse(reviewer["merge_gate"])
        self.assertFalse(reviewer["automatic"])
        self.assertEqual(set(reviewer["providers"]), {"grok_build", "antigravity_cli"})
        self.assertTrue(reviewer["advice_record_required"])

    def test_bugbot_is_advisory_and_autofix_is_cost_first(self) -> None:
        bugbot = self.contract["review_pipeline"]["cursor_bugbot"]
        self.assertEqual(bugbot["role"], "cursor_native_pr_review")
        self.assertTrue(bugbot["advisory"])
        self.assertFalse(bugbot["merge_gate"])
        self.assertFalse(bugbot["required_status_check"])
        self.assertTrue(bugbot["default_effort_preferred"])
        autofix = bugbot["autofix"]
        self.assertTrue(autofix["preferred_first_remediation_for_bugbot_findings"])
        self.assertEqual(autofix["preferred_target"], "new_branch")
        self.assertFalse(autofix["automatic_downstream_vendor_escalation"])
        self.assertTrue(autofix["deterministic_revalidation_required"])
        policy = BUGBOT_POLICY.read_text(encoding="utf-8")
        self.assertIn("Default", policy)
        self.assertIn("Create New Branch", policy)
        self.assertIn("GitHub Copilot only as a GitHub-native fallback", policy)
        self.assertIn("Codex only as the final narrowly scoped", policy)
        self.assertIn("does not replace the risk-tiered", policy)
        self.assertIn("for high-risk pull requests", policy)
        self.assertIn("Do not automatically execute this list as a chain", policy)

    def test_governance_invariants_match_agent_policy(self) -> None:
        invariants = self.contract["invariants"]
        self.assertTrue(invariants["human_final_authority"])
        self.assertTrue(invariants["deterministic_checks_authoritative_for_machine_verifiable_facts"])
        self.assertTrue(invariants["optional_ai_unavailability_must_not_block_merge"])
        self.assertTrue(invariants["mcp_access_does_not_bypass_governance"])
        self.assertNotIn("copilot_and_codex_fallback_only", invariants)
        self.assertTrue(invariants["no_automatic_vendor_chaining"])
        agents = AGENTS_POLICY.read_text(encoding="utf-8")
        self.assertIn("Copilot and/or Codex must perform a final specialist pass", agents)
        self.assertIn("on high-risk pull requests (process-required, result-advisory)", agents)
        self.assertIn("Standard and low-risk pull requests skip this pass by default", agents)

    def test_mcp_document_preserves_governance_boundary(self) -> None:
        text = " ".join(MCP_POLICY.read_text(encoding="utf-8").split())
        self.assertIn("GitHub rulesets and branch protection remain the final merge authority", text)
        self.assertIn("MCP credentials must not bypass those controls", text)

    def test_review_pipeline_requires_codeowner_and_keeps_ai_advisory(self) -> None:
        pipeline = self.contract["review_pipeline"]
        advisory_providers = set(self.contract["advisory_ai_review"]["providers"])
        self.assertEqual(pipeline["required_github_reviewer"], "gibboda")
        self.assertTrue(pipeline["required_github_reviewer_is_codeowner"])
        second_look = pipeline["second_look"]
        fallback = second_look["independent_reviewer_fallback"]
        self.assertEqual(set(second_look["providers"]), {"grok_build", "antigravity"})
        self.assertEqual(fallback["provider"], "antigravity_cli")
        self.assertFalse(second_look["merge_gate"])
        self.assertFalse(second_look["required_status_check"])
        self.assertNotIn("last_resort_specialists", pipeline)
        final_pass = pipeline["final_advisory_specialist_pass"]
        self.assertFalse(final_pass["process_required"])
        self.assertEqual(final_pass["process_required_for"], ["high"])
        self.assertEqual(
            final_pass["process_required_semantics"],
            "required_only_when_recorded_risk_tier_is_in_process_required_for",
        )
        self.assertTrue(final_pass["risk_tiered"])
        self.assertEqual(final_pass["required_risk_tiers"], ["high"])
        self.assertEqual(final_pass["process_required_for"], final_pass["required_risk_tiers"])
        self.assertEqual(final_pass["optional_risk_tiers"], ["standard", "low"])
        self.assertEqual(final_pass["default_risk_tier"], "standard")
        self.assertEqual(final_pass["risk_tier_precedence"], "highest_matching_wins")
        self.assertEqual(final_pass["risk_tier_rank"], ["high", "standard", "low"])
        self.assertEqual(
            final_pass["risk_tier_criteria"]["high"],
            [
                "security",
                "credentials_or_secrets",
                "agent_hierarchy_or_merge_authority",
                "branch_protection_or_required_checks",
                "schema_or_contract",
                "stage_boundary_or_profile_contract",
                "apply_path_or_system_mutation",
            ],
        )
        self.assertTrue(final_pass["skip_record_required_when_not_run"])
        self.assertEqual(final_pass["template_risk_tier_field"], "Risk tier:")
        self.assertEqual(final_pass["template_specialist_pass_field"], "Specialist pass:")
        self.assertEqual(
            final_pass["specialist_pass_record_values"],
            ["completed", "skipped", "unavailable", "requested"],
        )
        self.assertTrue(final_pass["codeowner_may_request_on_optional_tiers"])
        self.assertEqual(final_pass["providers"], ["github_copilot", "codex"])
        self.assertEqual(final_pass["selection"], "any_or_both")
        self.assertEqual(final_pass["github_review_state"], "comment_only")
        self.assertFalse(final_pass["satisfies_branch_protection"])
        self.assertFalse(final_pass["merge_gate"])
        self.assertFalse(final_pass["required_status_check"])
        self.assertTrue(set(final_pass["providers"]).issubset(advisory_providers))
        agents = AGENTS_POLICY.read_text(encoding="utf-8")
        self.assertIn("Copilot and/or Codex must perform a final specialist pass", agents)
        self.assertIn("on high-risk pull requests (process-required, result-advisory)", agents)
        self.assertIn("**high** (process-required)", agents)
        self.assertIn("**standard** (optional)", agents)
        self.assertIn("**low** (optional)", agents)
        self.assertIn("highest matching", agents)
        self.assertIn("not an always-on signal", agents)
        self.assertIn("`Risk tier:`", agents)
        self.assertIn("`Specialist pass:`", agents)
        self.assertIn("A silent skip is not a valid record", agents)

    def test_process_required_is_not_readable_as_always_on(self) -> None:
        final_pass = self.contract["review_pipeline"]["final_advisory_specialist_pass"]
        self.assertFalse(
            final_pass["process_required"],
            "Object-global process_required must not advertise an unconditional pass.",
        )
        self.assertTrue(specialist_pass_is_process_required(final_pass, "high"))
        self.assertFalse(specialist_pass_is_process_required(final_pass, "standard"))
        self.assertFalse(specialist_pass_is_process_required(final_pass, "low"))

    def test_overlapping_risk_criteria_use_highest_matching_tier(self) -> None:
        final_pass = self.contract["review_pipeline"]["final_advisory_specialist_pass"]
        self.assertEqual(
            resolve_risk_tier(["security", "chore_or_dependency_bump"], final_pass),
            "high",
        )
        self.assertEqual(resolve_risk_tier(["runtime_behavior"], final_pass), "standard")
        self.assertEqual(resolve_risk_tier(["docs_only"], final_pass), "low")
        self.assertEqual(resolve_risk_tier([], final_pass), "standard")
        self.assertTrue(
            specialist_pass_is_process_required(
                final_pass,
                resolve_risk_tier(["security", "chore_or_dependency_bump"], final_pass),
            )
        )

    def test_unknown_future_schema_fails_closed(self) -> None:
        with self.assertRaises(ValueError):
            specialist_pass_is_process_required(
                {"schema_version": MAX_SUPPORTED_PR_GOVERNANCE_SCHEMA + 1},
                "high",
            )

    def test_schema_1_fixture_keeps_unconditional_process_required(self) -> None:
        v1 = json.loads(V1_FIXTURE.read_text(encoding="utf-8"))
        self.assertEqual(v1["schema_version"], 1)
        v1_pass = v1["review_pipeline"]["final_advisory_specialist_pass"]
        self.assertTrue(v1_pass["process_required"])
        self.assertNotIn("risk_tiered", v1_pass)
        self.assertTrue(specialist_pass_is_process_required(v1_pass, "high"))
        self.assertTrue(specialist_pass_is_process_required(v1_pass, "standard"))
        self.assertTrue(specialist_pass_is_process_required(v1_pass, "low"))
        self.assertNotEqual(v1["schema_version"], self.contract["schema_version"])
        migration = COMPATIBILITY_DOC.read_text(encoding="utf-8")
        self.assertIn("schema 1 to schema 2", migration)
        self.assertIn("cannot be read as always-on", migration)
        self.assertIn("highest_matching_wins", migration)

    def test_skip_record_is_a_template_value_field(self) -> None:
        final_pass = self.contract["review_pipeline"]["final_advisory_specialist_pass"]
        template = PR_TEMPLATE.read_text(encoding="utf-8")
        self.assertTrue(final_pass["skip_record_required_when_not_run"])
        self.assertIn(final_pass["template_risk_tier_field"], template)
        self.assertIn(final_pass["template_specialist_pass_field"], template)
        self.assertIn("high | standard | low", template)
        self.assertIn("completed | skipped | unavailable | requested", template)
        self.assertNotRegex(
            template,
            r"- \[[ x]\] Pull-request risk tier recorded",
        )
        self.assertNotRegex(
            template,
            r"- \[[ x]\] Copilot and/or Codex completed a final advisory specialist pass",
        )
        self.assertNotIn("N/A for `standard`/`low`", template)
        self.assertIn("blank value is not a valid skip record", template)

    def test_codeowners_contains_only_gibboda_owner_tokens(self) -> None:
        text = CODEOWNERS.read_text(encoding="utf-8")
        owners: list[str] = []
        for line in text.splitlines():
            uncommented = line.split("#", 1)[0].strip()
            if uncommented:
                owners.extend(_OWNER_TOKEN.findall(uncommented))
        self.assertTrue(owners)
        self.assertEqual(set(owners), {"@gibboda"})
        self.assertIn("Human CODEOWNER is @gibboda", text)
        self.assertIn("AI is never merge authority", text)
        self.assertIn("high-risk pull requests", text)
        self.assertIn("Standard and low-risk pull requests skip that pass by", text)


if __name__ == "__main__":
    unittest.main()
