#!/usr/bin/env python3
"""Semantic contract tests for the machine-readable multi-agent architecture."""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "config/agent-roles.json"
_CREDENTIAL = re.compile(
    r"gh[pousr]_[A-Za-z0-9_]+|github_pat_[A-Za-z0-9_]+|"
    r"AIza[0-9A-Za-z_-]+|xai-[A-Za-z0-9]+"
)


class AgentRoleContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
        cls.roles = cls.contract["roles"]
        cls.invariants = cls.contract["invariants"]
        cls.overlay_contract = cls.contract["overlay_contract"]

    def test_contract_defers_to_agents_md(self) -> None:
        self.assertEqual(self.contract["authority"], "AGENTS.md")

    def test_exactly_one_primary_orchestrator(self) -> None:
        primary = self.roles["primary_orchestrator"]
        self.assertEqual(primary["provider"], "cursor")
        self.assertEqual(primary["count"], 1)
        self.assertTrue(primary["default_task_owner"])

    def test_github_is_control_plane_not_implementation_agent(self) -> None:
        control_plane = self.roles["control_plane"]
        self.assertEqual(control_plane["provider"], "github")
        self.assertFalse(control_plane["implementation_agent"])

    def test_deterministic_validation_precedes_ai_escalation(self) -> None:
        validation = self.roles["deterministic_validation"]
        self.assertTrue(validation["before_ai_escalation"])
        self.assertTrue(validation["authoritative_for_machine_verifiable_facts"])

    def test_secondary_and_fallback_agents_are_not_automatic(self) -> None:
        self.assertEqual(self.roles["secondary_specialist"]["provider"], "antigravity")
        self.assertFalse(self.roles["secondary_specialist"]["automatic"])
        self.assertEqual(self.roles["github_native_fallback"]["provider"], "github_copilot")
        self.assertFalse(self.roles["github_native_fallback"]["automatic"])
        self.assertFalse(self.roles["specialist_pool"]["automatic"])

    def test_grok_is_advisory_and_not_a_merge_gate(self) -> None:
        reviewer = self.roles["independent_reviewer"]
        self.assertEqual(reviewer["provider"], "grok_build")
        self.assertTrue(reviewer["advisory"])
        self.assertFalse(reviewer["merge_gate"])
        self.assertFalse(reviewer["automatic"])

    def test_ai_cannot_be_merge_authority(self) -> None:
        authority = self.roles["merge_authority"]
        self.assertFalse(authority["ai_allowed"])
        self.assertTrue(authority["human_final"])

    def test_global_routing_invariants(self) -> None:
        self.assertTrue(self.invariants["no_automatic_vendor_chaining"])
        self.assertTrue(self.invariants["least_agent_principle"])
        self.assertTrue(self.invariants["duplicate_routine_ai_work_prohibited"])
        self.assertTrue(self.invariants["ai_reviews_advisory"])

    def test_overlay_contract_roles_exist_in_manifest(self) -> None:
        for overlay in self.overlay_contract["overlays"]:
            with self.subTest(path=overlay["path"]):
                self.assertIn(overlay["role"], self.roles)

    def test_overlay_contract_paths_are_unique_and_exist(self) -> None:
        paths = [entry["path"] for entry in self.overlay_contract["overlays"]]
        self.assertEqual(len(paths), len(set(paths)))
        for relative_path in paths:
            with self.subTest(path=relative_path):
                self.assertTrue((ROOT / relative_path).is_file(), relative_path)

    def test_overlays_reference_canonical_authority(self) -> None:
        self.assertTrue(self.overlay_contract["common"]["must_reference_authority"])
        for overlay in self.overlay_contract["overlays"]:
            text = (ROOT / overlay["path"]).read_text(encoding="utf-8")
            with self.subTest(path=overlay["path"]):
                self.assertIn("AGENTS.md", text)

    def test_overlays_do_not_redefine_hierarchy_or_contain_credentials(self) -> None:
        common = self.overlay_contract["common"]
        self.assertTrue(common["must_not_define_agent_hierarchy_heading"])
        self.assertTrue(common["must_not_contain_credentials"])
        for overlay in self.overlay_contract["overlays"]:
            text = (ROOT / overlay["path"]).read_text(encoding="utf-8")
            with self.subTest(path=overlay["path"]):
                self.assertNotIn("## Agent hierarchy", text)
                self.assertNotRegex(text, _CREDENTIAL)

    def test_overlays_match_declared_role_markers(self) -> None:
        for overlay in self.overlay_contract["overlays"]:
            text = (ROOT / overlay["path"]).read_text(encoding="utf-8")
            markers = overlay["required_any"]
            with self.subTest(path=overlay["path"], role=overlay["role"]):
                self.assertTrue(
                    any(marker in text for marker in markers),
                    f"{overlay['path']} does not express role {overlay['role']}",
                )

    def test_overlays_cannot_claim_merge_authority(self) -> None:
        self.assertTrue(self.overlay_contract["common"]["must_not_claim_merge_authority"])
        forbidden = (
            "final merge authority",
            "AI agent is merge authority",
            "AI agent is the merge authority",
        )
        for overlay in self.overlay_contract["overlays"]:
            text = (ROOT / overlay["path"]).read_text(encoding="utf-8")
            with self.subTest(path=overlay["path"]):
                for phrase in forbidden:
                    self.assertNotIn(phrase, text)


if __name__ == "__main__":
    unittest.main()
