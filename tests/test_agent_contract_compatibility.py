#!/usr/bin/env python3
"""Architecture contract-version and repository-release compatibility tests."""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPATIBILITY_PATH = ROOT / "config/agent-contract-compatibility.json"
VERSION_PATH = ROOT / "VERSION"
CHANGE_CLASSES = ("documentation_only", "backward_compatible", "breaking")
RELEASE_RANK = {"patch": 0, "minor": 1, "major": 2}


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


def next_release(value, release_class):
    major, minor, patch = semver(value)
    if release_class == "major":
        return (major + 1, 0, 0)
    if release_class == "minor":
        return (major, minor + 1, 0)
    if release_class == "patch":
        return (major, minor, patch + 1)
    raise AssertionError(f"Unknown release class {release_class!r}")


def repository_version():
    return VERSION_PATH.read_text(encoding="utf-8").split()[0]


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
        self.assertEqual(contracts["pr_governance"]["schema_version"], 2)
        compatibility_doc = (ROOT / "docs/AGENT-CONTRACT-COMPATIBILITY.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("schema 1 to schema 2", compatibility_doc)
        self.assertIn("cannot be read as always-on", compatibility_doc)

    def test_release_change_classes_are_monotonic(self):
        classes = self.compatibility["change_classes"]
        self.assertEqual(set(classes), set(CHANGE_CLASSES))
        self.assertEqual(classes["documentation_only"]["minimum_repository_release"], "patch")
        self.assertEqual(classes["backward_compatible"]["minimum_repository_release"], "minor")
        self.assertEqual(classes["breaking"]["minimum_repository_release"], "major")
        self.assertEqual(
            classes["breaking"]["architecture_contract_version_change"], "increment"
        )
        self.assertEqual(
            classes["backward_compatible"]["architecture_contract_version_change"], "none"
        )
        self.assertEqual(
            classes["documentation_only"]["architecture_contract_version_change"], "none"
        )
        self.assertLess(
            RELEASE_RANK[classes["documentation_only"]["minimum_repository_release"]],
            RELEASE_RANK[classes["backward_compatible"]["minimum_repository_release"]],
        )
        self.assertLess(
            RELEASE_RANK[classes["backward_compatible"]["minimum_repository_release"]],
            RELEASE_RANK[classes["breaking"]["minimum_repository_release"]],
        )

    def test_breaking_and_compatible_change_classes_are_explicit(self):
        breaking = set(self.compatibility["breaking_changes"])
        compatible = set(self.compatibility["backward_compatible_changes"])
        self.assertTrue(breaking)
        self.assertTrue(compatible)
        self.assertTrue(breaking.isdisjoint(compatible))
        self.assertIn("weakening_security_or_governance_invariants", breaking)
        self.assertIn("changing_canonical_role_ownership_or_merge_authority", breaking)
        self.assertIn("making_advisory_ai_review_a_required_merge_gate", breaking)
        self.assertIn("adding_optional_contract_fields_with_safe_defaults", compatible)
        self.assertIn(
            "adding_new_cross_contract_invariants_consistent_with_AGENTS_md",
            compatible,
        )
        self.assertIn(
            "tightening_validation_without_invalidating_valid_existing_records",
            compatible,
        )

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

    def test_current_change_class_is_declared(self):
        change_class = self.compatibility["current_change_class"]
        self.assertIn(change_class, self.compatibility["change_classes"])
        self.assertEqual(change_class, "breaking")

    def test_architecture_version_baseline_is_first_introduction(self):
        previous = self.compatibility["previous_architecture_contract_version"]
        current = self.compatibility["architecture_contract_version"]
        self.assertIsInstance(previous, int)
        self.assertIsInstance(current, int)
        self.assertGreaterEqual(previous, 0)
        self.assertGreaterEqual(current, previous)
        self.assertEqual(previous, 1)
        self.assertEqual(current, 2)

    def test_introduced_version_is_not_a_past_finalized_release(self):
        current = repository_version()
        previous = self.compatibility["previous_repository_version"]
        introduced = self.compatibility["introduced_repository_version"]
        current_sv = semver(current)
        previous_sv = semver(previous)
        introduced_sv = semver(introduced)

        self.assertEqual(previous, "0.31.0")
        self.assertGreaterEqual(introduced_sv, previous_sv)
        if current_sv == previous_sv:
            self.assertGreater(
                introduced_sv,
                previous_sv,
                "When VERSION still equals a finalized release that shipped "
                "without this contract, introduced_repository_version must be "
                "the next release that may first contain it.",
            )
        else:
            self.assertGreaterEqual(current_sv, introduced_sv)
        self.assertEqual(introduced, "1.0.0")

    def test_introduced_version_matches_declared_change_class(self):
        current = repository_version()
        previous = self.compatibility["previous_repository_version"]
        introduced = self.compatibility["introduced_repository_version"]
        previous_arch = self.compatibility["previous_architecture_contract_version"]
        current_arch = self.compatibility["architecture_contract_version"]
        change_class = self.compatibility["current_change_class"]
        classes = self.compatibility["change_classes"]
        minimum_release = classes[change_class]["minimum_repository_release"]
        introduced_sv = semver(introduced)

        self.assertGreaterEqual(
            introduced_sv,
            next_release(previous, minimum_release),
            f"{change_class} requires at least a {minimum_release} bump from "
            f"{previous}",
        )
        if introduced_sv > semver(current):
            self.assertGreaterEqual(
                introduced_sv,
                next_release(current, minimum_release),
                "introduced_repository_version may lead the in-tree VERSION "
                "only by the declared change class (release-please owns VERSION).",
            )

        if current_arch > previous_arch and previous_arch >= 1:
            self.assertEqual(change_class, "breaking")
            self.assertGreaterEqual(
                introduced_sv,
                next_release(previous, "major"),
                "Incrementing an existing architecture_contract_version "
                "requires a major repository release versus "
                "previous_repository_version.",
            )
        elif current_arch > previous_arch:
            self.assertEqual(previous_arch, 0)
            self.assertGreaterEqual(
                introduced_sv,
                next_release(previous, minimum_release),
            )
        elif change_class != "breaking":
            self.assertEqual(current_arch, previous_arch)

        if change_class == "breaking":
            self.assertGreater(current_arch, previous_arch)

    def test_major_floor_is_routed_through_release_please(self):
        contributing = (ROOT / "CONTRIBUTING.md").read_text(encoding="utf-8")
        compatibility_doc = (ROOT / "docs/AGENT-CONTRACT-COMPATIBILITY.md").read_text(
            encoding="utf-8"
        )

        self.assertIn("Do not hand-edit `VERSION`", contributing)
        self.assertIn(".release-please-manifest.json", contributing)
        self.assertIn("Release-As: x.y.z", contributing)
        self.assertIn("Release-As: 1.0.0", contributing)
        self.assertIn(
            "Do not substitute a hand-edited version bump for that generated Release PR.",
            contributing,
        )
        self.assertIn("Release Please must produce that `1.0.0` release", compatibility_doc)
        self.assertIn("Release-As: 1.0.0", compatibility_doc)
        self.assertEqual(self.compatibility["introduced_repository_version"], "1.0.0")


if __name__ == "__main__":
    unittest.main()
