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
FIXTURES = ROOT / "tests/fixtures/agent-work-allocation"


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
            if rule["if"]["properties"].get("work_kind", {}).get("const") == work_kind:
                return set(rule["then"]["required"])
        self.fail(f"missing conditional requirements for {work_kind}")

    def _resource_match_rules(self) -> dict[str, str]:
        rules: dict[str, str] = {}
        for rule in self.allocation["allOf"]:
            resource = rule.get("if", {}).get("properties", {}).get("additional_resource", {}).get("const")
            if resource is None:
                continue
            selected = (
                rule["then"]["properties"]["escalation_record"]["properties"]["selected_resource"]["const"]
            )
            rules[resource] = selected
        return rules

    def _escalation_record_errors(self, record: object) -> list[str]:
        """Apply the published escalation contract without a JSON Schema engine."""
        if not isinstance(record, dict):
            return ["escalation_record must be an object"]
        errors: list[str] = []
        allowed = set(self.escalation["properties"])
        extra = set(record) - allowed
        if extra:
            errors.append(f"unexpected properties: {sorted(extra)}")
        for name in self.escalation["required"]:
            if name not in record:
                errors.append(f"missing required property {name!r}")
        selected = record.get("selected_resource")
        resources = self.escalation["properties"]["selected_resource"]["enum"]
        if selected not in resources:
            errors.append(f"selected_resource {selected!r} is not allowed")
        approved = record.get("approved_resource")
        if selected == "maintainer_approved":
            if not isinstance(approved, str) or not approved.strip():
                errors.append("maintainer_approved requires approved_resource")
        elif "approved_resource" in record:
            errors.append("approved_resource is only valid for maintainer_approved")
        return errors

    def _allocation_errors(self, record: dict) -> list[str]:
        """Apply the published allocation contract without a JSON Schema engine."""
        errors: list[str] = []
        allowed = set(self.allocation["properties"])
        extra = set(record) - allowed
        if extra:
            errors.append(f"unexpected properties: {sorted(extra)}")
        for name in self.allocation["required"]:
            if name not in record:
                errors.append(f"missing required property {name!r}")
        work_kind = record.get("work_kind")
        kinds = self.allocation["properties"]["work_kind"]["enum"]
        if work_kind in kinds:
            for name in self._requirements_for(work_kind):
                if name not in record:
                    errors.append(f"missing required property {name!r}")
        additional = record.get("additional_resource")
        if "escalation_record" in record:
            nested = record["escalation_record"]
            errors.extend(self._escalation_record_errors(nested))
            if isinstance(nested, dict) and nested.get("selected_resource") != additional:
                errors.append("additional_resource must match escalation_record.selected_resource")
        return errors

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

    def test_escalation_record_references_escalation_schema(self) -> None:
        ref = self.allocation["properties"]["escalation_record"]["$ref"]
        self.assertTrue(ref.endswith("agent-escalation-record.schema.json"))
        self.assertNotEqual(self.allocation["properties"]["escalation_record"].get("type"), "object")

    def test_additional_resource_must_match_escalation_selected_resource(self) -> None:
        resources = self.allocation["properties"]["additional_resource"]["enum"]
        rules = self._resource_match_rules()
        self.assertEqual(set(rules), set(resources))
        for resource, selected in rules.items():
            self.assertEqual(resource, selected)

    def test_valid_allocation_fixture_passes(self) -> None:
        record = json.loads((FIXTURES / "v1-implementation.json").read_text(encoding="utf-8"))
        self.assertEqual(self._allocation_errors(record), [])

    def test_empty_escalation_record_is_rejected(self) -> None:
        record = json.loads((FIXTURES / "v1-implementation.json").read_text(encoding="utf-8"))
        record["escalation_record"] = {}
        errors = self._allocation_errors(record)
        self.assertIn("missing required property 'unresolved_gap'", errors)
        self.assertIn("missing required property 'selected_resource'", errors)
        self.assertIn("missing required property 'scope'", errors)
        self.assertIn("missing required property 'completion_criterion'", errors)
        self.assertIn("missing required property 'stop_condition'", errors)
        self.assertIn(
            "additional_resource must match escalation_record.selected_resource",
            errors,
        )

    def test_mismatched_allocated_resource_is_rejected(self) -> None:
        record = json.loads((FIXTURES / "v1-implementation.json").read_text(encoding="utf-8"))
        record["additional_resource"] = "codex"
        self.assertIn(
            "additional_resource must match escalation_record.selected_resource",
            self._allocation_errors(record),
        )

    def test_policy_preserves_authority_boundaries(self) -> None:
        text = POLICY.read_text(encoding="utf-8")
        self.assertIn("`AGENTS.md` is authoritative", text)
        self.assertIn("Routine duplicate implementation is prohibited", text)
        self.assertIn("Independent review is not duplicate implementation", text)
        self.assertIn("CODEOWNER-assigned second look", text)
        self.assertIn("`independent_review` and/or specialist work", text)
        self.assertIn("final advisory specialist pass", text)
        self.assertIn("not duplicate routine implementation", text)
        self.assertIn("Parallel multi-agent analysis is exceptional", text)
        self.assertIn("does not confer authorization", text)
        self.assertIn("does not invoke agents", text)
        self.assertIn("human PR governance remains final authority", text)
        self.assertIn("An empty `escalation_record` object is not valid", text)
        self.assertIn("`additional_resource` must equal `escalation_record.selected_resource`", text)

    def test_agents_policy_contains_required_duplicate_controls(self) -> None:
        text = AGENTS.read_text(encoding="utf-8")
        for phrase in (
            "Do not spend paid or metered agent capacity on work that Cursor, existing",
            "Do not invoke multiple paid or cloud agents for the same routine task",
            "reuse prior agent findings, logs, issue/PR",
            "Parallel multi-agent analysis requires an explicit reason",
            "Connecting multiple agents to GitHub MCP does not mean every agent should",
            "MCP availability is capability, not an",
        ):
            self.assertIn(phrase, text)


if __name__ == "__main__":
    unittest.main()
