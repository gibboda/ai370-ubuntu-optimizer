#!/usr/bin/env python3
"""Architecture contract-version and repository-release compatibility tests."""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPATIBILITY_PATH = ROOT / "config/agent-contract-compatibility.json"
VERSION_PATH = ROOT / "VERSION"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def schema_version(contract):
    if "schema_version" in contract:
        return contract["schema_version"]
    properties = contract.get("properties", {})
    schema_property = properties.get("schema_version", {})
    return schema_property.get("const")


def semver(value):
    match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)", value)
    if not match:
        raise AssertionError(f"Expected SemVer x.y.z, got {value!r}")
    return tuple(int(part) for part in match.groups())


class AgentContractCompatibilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.compatibility = load(COMPATIBILITY_PATH)

    def test_compatibility_contract_defers_to_agents_md(self):
        self.assertEqual(self.compatibility["authority"], "AGENTS.md")
        self.assertTrue(
            self.compatibility["invariants"]["agents_md_remains_authoritative"]
        )
        self.assertGreaterEqual(self.compatibility["architecture_contract_version"], 1)

    def test_all_declared_contracts_exist_and_match_exact_schema_versions(self):
        contracts = self.compatibility["contracts"]
        self.assertEqual(
            set(contracts),
            {
                "roles",
                "escalation",
                "work_allocation",
                "credential_capabilities",
                "mcp",
                "pr_governance",
            },
        )
        for name, declaration in contracts.items():
            path = ROOT / declaration["path"]
            with self.subTest(contract=name):
                self.assertTrue(path.is_file())
                self.assertEqual(schema_version(load(path)), declaration["schema_version"])

    def test_release_change_classes_are_monotonic(self):
        classes = self.compatibility["change_classes"]
        self.assertEqual(classes["documentation_only"]["minimum_repository_release"], "patch")
        self.assertEqual(classes["backward_compatible"]["minimum_repository_release"], "minor")
        self.assertEqual(classes["breaking"]["minimum_repository_release"], "major")
        self.assertEqual(
            classes["breaking"]["architecture_contract_version_change"], "increment"
        )
        self.assertEqual(
            classes["backward_compatible"]["architecture_contract_version_change"], "none"
        )

    def test_breaking_and_compatible_change_classes_are_explicit(self):
        breaking = set(self.compatibility["breaking_changes"])
        compatible = set(self.compatibility["backward_compatible_changes"])
        self.assertTrue(breaking)
        self.assertTrue(compatible)
        self.assertTrue(breaking.isdisjoint(compatible))
        self.assertIn("weakening_security_or_governance_invariants", breaking)
        self.assertIn("changing_canonical_role_ownership_or_merge_authority", breaking)
        self.assertIn("adding_optional_contract_fields_with_safe_defaults", compatible)

    def test_release_policy_invariants_are_fail_closed(self):
        invariants = self.compatibility["invariants"]
        for key in (
            "listed_contract_versions_are_exact",
            "breaking_change_requires_architecture_version_increment",
            "breaking_change_requires_repository_major_release",
            "compatible_contract_change_requires_repository_minor_release",
            "documentation_only_change_may_use_repository_patch_release",
        ):
            with self.subTest(invariant=key):
                self.assertTrue(invariants[key])

    def test_repository_version_is_not_older_than_contract_introduction(self):
        current = VERSION_PATH.read_text(encoding="utf-8").split()[0]
        introduced = self.compatibility["introduced_repository_version"]
        self.assertGreaterEqual(semver(current), semver(introduced))


if __name__ == "__main__":
    unittest.main()
