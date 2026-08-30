#!/usr/bin/env python3
"""Audit architecture invariants for explicit validation evidence."""

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROLES_PATH = ROOT / "config/agent-roles.json"
COVERAGE_PATH = ROOT / "config/agent-architecture-coverage.json"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


class AgentArchitectureCoverageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.roles = load(ROLES_PATH)
        cls.coverage = load(COVERAGE_PATH)

    def test_coverage_manifest_is_evidence_not_policy_authority(self):
        self.assertEqual(self.coverage["authority"], "AGENTS.md")
        self.assertIn("does not define policy", self.coverage["purpose"])

    def test_every_declared_role_invariant_has_coverage_entry(self):
        self.assertEqual(
            set(self.coverage["coverage"]),
            set(self.roles["invariants"]),
        )

    def test_required_evidence_types_are_present_for_every_invariant(self):
        required = self.coverage["requirements"]["minimum_evidence_types"]
        gaps = []
        for invariant, evidence in self.coverage["coverage"].items():
            for evidence_type in required:
                paths = evidence.get(evidence_type, [])
                if not paths:
                    gaps.append(f"{invariant}:{evidence_type}")
                    continue
                for relative_path in paths:
                    if not (ROOT / relative_path).is_file():
                        gaps.append(f"{invariant}:{evidence_type}:{relative_path}:missing")
        self.assertEqual(gaps, [], "architecture coverage gaps: " + ", ".join(gaps))

    def test_coverage_paths_are_test_surfaces(self):
        for invariant, evidence in self.coverage["coverage"].items():
            for evidence_type, paths in evidence.items():
                for relative_path in paths:
                    with self.subTest(invariant=invariant, evidence=evidence_type, path=relative_path):
                        self.assertTrue(relative_path.startswith("tests/test_"))
                        self.assertTrue(relative_path.endswith(".py"))


if __name__ == "__main__":
    unittest.main()
