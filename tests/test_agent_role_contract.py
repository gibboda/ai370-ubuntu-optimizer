#!/usr/bin/env python3
"""Semantic contract tests for the machine-readable multi-agent architecture."""

import json
import re
import unittest
from fnmatch import fnmatch
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "config/agent-roles.json"
V1_FIXTURE = ROOT / "tests/fixtures/agent-role-contract/v1.json"
SCHEMA_POLICY = ROOT / "docs/AGENT-ROLE-SCHEMA.md"
MAX_SUPPORTED_SCHEMA_VERSION = 2
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

    def _discover_overlay_paths(self) -> set[str]:
        discovery = self.overlay_contract["discovery"]
        discovered: set[str] = set()
        for root_spec in discovery["roots"]:
            root = ROOT / root_spec["path"]
            self.assertTrue(root.is_dir(), f"overlay discovery root does not exist: {root_spec['path']}")
            for pattern in root_spec["patterns"]:
                for path in root.glob(pattern):
                    if path.is_file():
                        discovered.add(path.relative_to(ROOT).as_posix())
        return discovered

    def test_contract_defers_to_agents_md(self) -> None:
        self.assertEqual(self.contract["authority"], "AGENTS.md")

    def test_schema_version_is_explicitly_supported(self) -> None:
        version = self.contract["schema_version"]
        self.assertIsInstance(version, int)
        self.assertGreater(version, 0)
        self.assertLessEqual(
            version,
            MAX_SUPPORTED_SCHEMA_VERSION,
            "Unknown future schema versions must fail closed until consumer support is added.",
        )
        self.assertEqual(version, MAX_SUPPORTED_SCHEMA_VERSION)

    def test_schema_compatibility_policy_is_documented(self) -> None:
        text = SCHEMA_POLICY.read_text(encoding="utf-8")
        self.assertIn("`AGENTS.md`", text)
        self.assertIn("fail closed", text)
        self.assertIn("schema version 2", text)
        self.assertIn("Version 1", text)
        self.assertIn("Migration procedure", text)

    def _assert_v1_semantics_preserved(self, actual, expected, path: str) -> None:
        """Require every v1 value to remain; allow safely ignorable additive fields."""
        if isinstance(expected, dict):
            self.assertIsInstance(
                actual,
                dict,
                f"v2 changed the type of {path}; incompatible changes require a new migration decision.",
            )
            for key, value in expected.items():
                child = f"{path}.{key}" if path else key
                self.assertIn(
                    key,
                    actual,
                    f"v2 is missing v1 field {child}; incompatible changes require a new migration decision.",
                )
                self._assert_v1_semantics_preserved(actual[key], value, child)
            return
        self.assertEqual(
            actual,
            expected,
            f"v2 must preserve v1 {path} semantics; incompatible changes require a new migration decision.",
        )

    def test_v1_fixture_preserves_v1_semantics_in_v2(self) -> None:
        v1 = json.loads(V1_FIXTURE.read_text(encoding="utf-8"))
        self.assertEqual(v1["schema_version"], 1)
        self.assertEqual(self.contract["schema_version"], 2)
        for key in ("authority", "policy_domains", "roles", "invariants"):
            with self.subTest(key=key):
                self._assert_v1_semantics_preserved(self.contract[key], v1[key], key)
        self.assertNotIn("overlay_contract", v1)
        self.assertIn("overlay_contract", self.contract)

    def test_compatible_additive_fields_do_not_require_migration(self) -> None:
        v1_roles = {"primary_orchestrator": {"provider": "cursor", "count": 1}}
        v2_roles = {
            "primary_orchestrator": {
                "provider": "cursor",
                "count": 1,
                "notes": "optional metadata",
            },
            "new_optional_role": {"provider": "example"},
        }
        self._assert_v1_semantics_preserved(v2_roles, v1_roles, "roles")

    def test_removed_or_changed_v1_fields_are_incompatible(self) -> None:
        v1_roles = {"primary_orchestrator": {"provider": "cursor", "count": 1}}
        missing_field = {"primary_orchestrator": {"provider": "cursor"}}
        changed_value = {"primary_orchestrator": {"provider": "other", "count": 1}}
        with self.assertRaises(self.failureException):
            self._assert_v1_semantics_preserved(missing_field, v1_roles, "roles")
        with self.assertRaises(self.failureException):
            self._assert_v1_semantics_preserved(changed_value, v1_roles, "roles")
        with self.assertRaises(self.failureException):
            self._assert_v1_semantics_preserved(["cursor"], v1_roles, "roles")

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

    def test_discovered_overlays_exactly_match_manifest_plus_exclusions(self) -> None:
        discovery = self.overlay_contract["discovery"]
        declared = {entry["path"] for entry in self.overlay_contract["overlays"]}
        exclusions = set(discovery["exclusions"])
        discovered = self._discover_overlay_paths()

        self.assertFalse(
            declared & exclusions,
            "an overlay cannot be both declared and excluded",
        )
        self.assertEqual(
            discovered,
            declared | exclusions,
            "Every discovered overlay must be declared or explicitly excluded, and stale manifest/exclusion paths are forbidden.",
        )

    def test_overlay_discovery_configuration_is_unique(self) -> None:
        discovery = self.overlay_contract["discovery"]
        roots = [entry["path"] for entry in discovery["roots"]]
        exclusions = discovery["exclusions"]
        self.assertEqual(len(roots), len(set(roots)))
        self.assertEqual(len(exclusions), len(set(exclusions)))

    def test_reviewer_policy_roots_discover_all_markdown(self) -> None:
        """Enumerated filenames let new reviewer policy Markdown bypass the contract."""
        reviewer_roots = {".github/grok", ".github/antigravity"}
        for root_spec in self.overlay_contract["discovery"]["roots"]:
            if root_spec["path"] not in reviewer_roots:
                continue
            reviewer_roots.remove(root_spec["path"])
            with self.subTest(path=root_spec["path"]):
                self.assertIn("*.md", root_spec["patterns"])
                self.assertTrue(
                    any(fnmatch("new-policy.md", pattern) for pattern in root_spec["patterns"]),
                    f"{root_spec['path']} must discover future Markdown, not only current filenames",
                )
        self.assertFalse(reviewer_roots, "reviewer-policy discovery roots are missing")

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
