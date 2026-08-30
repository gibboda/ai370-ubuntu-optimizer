#!/usr/bin/env python3
"""Validate cross-repository multi-agent distribution boundaries."""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DISTRIBUTION_PATH = ROOT / "config/agent-distribution.json"
LOCK_PATH = ROOT / "config/agent-distribution-lock.json"
COMPATIBILITY_PATH = ROOT / "config/agent-contract-compatibility.json"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


class AgentDistributionContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.distribution = load(DISTRIBUTION_PATH)
        cls.lock = load(LOCK_PATH)
        cls.compatibility = load(COMPATIBILITY_PATH)

    def test_distribution_is_metadata_not_policy_authority(self):
        self.assertEqual(self.distribution["authority"], "AGENTS.md")
        self.assertIn("does not define policy", self.distribution["purpose"])

    def test_portable_and_repository_local_surfaces_do_not_overlap(self):
        portable = set(self.distribution["portable"])
        local = set(self.distribution["repository_local"])
        self.assertTrue(portable)
        self.assertTrue(local)
        self.assertFalse(portable & local)
        self.assertIn("AGENTS.md", local)
        self.assertIn("config/pr-governance.json", local)

    def test_portable_files_exist_and_are_machine_readable_contracts(self):
        for relative_path in self.distribution["portable"]:
            with self.subTest(path=relative_path):
                self.assertTrue((ROOT / relative_path).is_file())
                self.assertTrue(relative_path.startswith("config/"))
                self.assertTrue(relative_path.endswith(".json"))

    def test_distribution_covers_compatible_portable_contracts(self):
        compatibility_paths = {
            entry["path"] for name, entry in self.compatibility["contracts"].items()
            if name != "pr_governance"
        }
        portable = set(self.distribution["portable"])
        self.assertTrue(compatibility_paths <= portable)
        self.assertIn("config/agent-contract-compatibility.json", portable)

    def test_sync_is_reviewed_fail_closed_and_never_overwrites_local_policy(self):
        sync = self.distribution["sync"]
        self.assertEqual(sync["mode"], "pull_request_only")
        self.assertFalse(sync["automatic_merge"])
        self.assertFalse(sync["overwrite_repository_local"])
        self.assertTrue(sync["require_clean_base_for_managed_files"])
        self.assertTrue(sync["require_source_version_pin"])
        self.assertEqual(sync["drift_policy"], "fail_and_review")

    def test_lock_matches_distribution_package_and_managed_files(self):
        package = self.distribution["package"]
        self.assertEqual(self.lock["package"], package["name"])
        self.assertEqual(self.lock["package_version"], package["version"])
        self.assertEqual(self.lock["source_repository"], package["source_repository"])
        self.assertEqual(self.lock["managed_files"], self.distribution["portable"])

    def test_source_lock_is_immutable_commit_pin(self):
        self.assertEqual(self.lock["role"], "source")
        self.assertRegex(self.lock["source_ref"], re.compile(r"^[0-9a-f]{40}$"))

    def test_distribution_invariants_preserve_consumer_governance(self):
        invariants = self.distribution["invariants"]
        self.assertTrue(invariants["agents_md_remains_consumer_authority"])
        self.assertTrue(invariants["portable_contracts_may_not_override_local_governance"])
        self.assertTrue(invariants["synchronization_requires_human_review"])
        self.assertTrue(invariants["source_must_be_immutably_pinned"])


if __name__ == "__main__":
    unittest.main()
