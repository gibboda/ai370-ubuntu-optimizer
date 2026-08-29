#!/usr/bin/env python3
"""Contract tests for duplicate-agent work allocation."""

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROLES = ROOT / "config/agent-roles.json"
ESCALATION = ROOT / "config/agent-escalation-record.schema.json"
ALLOCATION = ROOT / "config/agent-work-allocation.schema.json"
POLICY = ROOT / "docs/AGENT-WORK-ALLOCATION.md"
AGENTS = ROOT / "AGENTS.md"


class AgentWorkAllocationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.roles = json.loads(ROLES.read_text(encoding="utf-8"))
        cls.escalation = json.loads(ESCALATION.read_text(encoding="utf-8"))
        cls.allocation = json.loads(ALLOCATION.read_text(encoding="utf-8"))

    def test_duplicate_work_invariant_is_enabled(self) -> None:
        self.assertTrue(self.roles["invariants"]["least_agent_principle"])
        self.assertTrue(self.roles["invariants"]["duplicate_routine_ai_work_prohibited"])
        self.assertTrue(self.roles["invariants"]["no_automatic_vendor_chaining"])

    def test_cursor_is_only_primary_resource(self) -> None:
        self.assertEqual(self.allocation["properties"]["primary_resource"]["const"], "cursor")
        self.assertEqual(self.roles["roles"]["primary_orchestrator"]["provider"], "cursor")

    def test_additional_resources_match_escalation_resources(self) -> None:
        allocation = set(self.allocation["properties"]["additional_resource"]["enum"])
        escalation = set(self.escalation["properties"]["selected_resource"]["enum"])
        self.assertEqual(allocation, escalation)
        self.assertNotIn("cursor", allocation)
        self.assertNotIn("github", allocation)

    def test_allocation_requires_reuse_evidence(self) -> None:
        self.assertIn("reuse_evidence", self.allocation["required"])
        evidence = self.allocation["properties"]["reuse_evidence"]
        self.assertGreaterEqual(evidence["minItems"], 1)
        allowed = set(evidence["items"]["enum"])
        self.assertTrue({"cursor_findings", "logs", "ci", "tests"}.issubset(allowed))
        self.assertTrue({"issue_discussion", "pr_discussion", "prior_agent_output"}.issubset(allowed))

    def _requirements_for(self, work_kind: str) -> set[str]:
        for rule in self.allocation["allOf"]:
            if rule["if"]["properties"]["work_kind"].get("const") == work_kind:
                return set(rule["then"]["required"])
        self.fail(f"missing conditional requirements for {work_kind}")

    def test_second_implementation_requires_escalation_record(self) -> None:
        self.assertIn("escalation_record", self._requirements_for("implementation"))

    def test_independent_review_is_distinct_and_justified(self) -> None:
        kinds = set(self.allocation["properties"]["work_kind"]["enum"])
        self.assertIn("implementation", kinds)
        self.assertIn("independent_review", kinds)
        requirements = self._requirements_for("independent_review")
        self.assertIn("escalation_record", requirements)
        self.assertIn("independent_review_reason", requirements)
        self.assertTrue(self.roles["invariants"]["ai_reviews_advisory"])
        self.assertFalse(self.roles["roles"]["independent_reviewer"]["merge_gate"])

    def test_parallel_analysis_requires_explicit_reason(self) -> None:
        requirements = self._requirements_for("parallel_analysis")
        self.assertIn("escalation_record", requirements)
        self.assertIn("parallel_reason", requirements)

    def test_policy_preserves_authority_boundaries(self) -> None:
        text = POLICY.read_text(encoding="utf-8")
        self.assertIn("`AGENTS.md` is authoritative", text)
        self.assertIn("Routine duplicate implementation is prohibited", text)
        self.assertIn("Independent review is not duplicate implementation", text)
        self.assertIn("Parallel multi-agent analysis is exceptional", text)
        self.assertIn("does not confer authorization", text)
        self.assertIn("does not invoke agents", text)
        self.assertIn("human PR governance remains final authority", text)

    def test_agents_policy_contains_required_duplicate_controls(self) -> None:
        text = AGENTS.read_text(encoding="utf-8")
        for phrase in (
            "Do not spend paid or metered capacity on work already answered",
            "Do not invoke multiple paid or cloud agents for the same routine task",
            "Reuse prior findings, logs, issue or PR discussion, CI results, and tests",
            "Parallel multi-agent analysis requires an explicit reason",
            "Multiple GitHub MCP connections are capability, not an instruction to use all agents simultaneously",
        ):
            self.assertIn(phrase, text)


if __name__ == "__main__":
    unittest.main()
