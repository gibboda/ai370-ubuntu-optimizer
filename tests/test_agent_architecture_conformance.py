#!/usr/bin/env python3
"""End-to-end conformance tests for the multi-agent architecture contract.

AGENTS.md is the policy authority. This suite verifies that the complete
machine-readable contract graph is connected, versioned, registered in CI,
and represented by the documented overlay surfaces without introducing a new
policy authority.
"""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROLES_PATH = ROOT / "config/agent-roles.json"
COMPATIBILITY_PATH = ROOT / "config/agent-contract-compatibility.json"
WORKFLOW_PATH = ROOT / ".github/workflows/portable-tests.yml"
TESTS_README_PATH = ROOT / "tests/README.md"
AGENTS_PATH = ROOT / "AGENTS.md"
ARCHITECTURE_PATH = ROOT / "docs/AI-AGENT-ARCHITECTURE.md"
SUITE = "tests.test_agent_architecture_conformance"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def schema_version(contract):
    if "schema_version" in contract:
        return contract["schema_version"]
    return contract.get("properties", {}).get("schema_version", {}).get("const")


def collapsed_yaml_comments(text):
    """Join YAML comment wraps so phrase checks survive line breaks."""
    comments = []
    for line in text.splitlines():
        stripped = line.lstrip()
        if stripped.startswith("#"):
            comments.append(stripped[1:].strip())
    return " ".join(comments)


class AgentArchitectureConformanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.roles = load(ROLES_PATH)
        cls.compatibility = load(COMPATIBILITY_PATH)
        cls.agents = AGENTS_PATH.read_text(encoding="utf-8")
        cls.architecture = ARCHITECTURE_PATH.read_text(encoding="utf-8")
        cls.workflow = WORKFLOW_PATH.read_text(encoding="utf-8")
        cls.tests_readme = TESTS_README_PATH.read_text(encoding="utf-8")

    def test_contract_graph_has_single_policy_authority(self):
        self.assertEqual(self.roles["authority"], "AGENTS.md")
        self.assertEqual(self.compatibility["authority"], "AGENTS.md")
        self.assertTrue(self.compatibility["invariants"]["agents_md_remains_authoritative"])
        self.assertIn("canonical", self.agents.lower())
        self.assertIn("authoritative", self.agents.lower())
        self.assertIn("AGENTS.md", self.architecture)
        self.assertIn("authoritative policy", self.architecture)

    def test_compatibility_manifest_covers_every_machine_readable_contract(self):
        declared_paths = {
            declaration["path"] for declaration in self.compatibility["contracts"].values()
        }
        expected_paths = {
            "config/agent-roles.json",
            "config/agent-escalation-record.schema.json",
            "config/agent-work-allocation.schema.json",
            "config/agent-credential-capabilities.json",
            "config/agent-mcp-contract.json",
            "config/pr-governance.json",
        }
        self.assertEqual(declared_paths, expected_paths)
        for name, declaration in self.compatibility["contracts"].items():
            path = ROOT / declaration["path"]
            with self.subTest(contract=name):
                self.assertTrue(path.is_file())
                self.assertEqual(schema_version(load(path)), declaration["schema_version"])

    def test_overlay_manifest_is_complete_for_discovered_policy_surfaces(self):
        overlay_contract = self.roles["overlay_contract"]
        declared = {entry["path"] for entry in overlay_contract["overlays"]}
        discovered = set()
        for root in overlay_contract["discovery"]["roots"]:
            base = ROOT / root["path"]
            for pattern in root["patterns"]:
                discovered.update(
                    path.relative_to(ROOT).as_posix()
                    for path in base.glob(pattern)
                    if path.is_file()
                )
        exclusions = set(overlay_contract["discovery"].get("exclusions", []))
        self.assertEqual(discovered - exclusions, declared)

    def test_declared_overlays_exist_and_reference_canonical_authority(self):
        for overlay in self.roles["overlay_contract"]["overlays"]:
            path = ROOT / overlay["path"]
            with self.subTest(path=overlay["path"]):
                self.assertTrue(path.is_file())
                text = path.read_text(encoding="utf-8")
                self.assertIn("AGENTS.md", text)
                self.assertNotRegex(text, r"(?im)^##?\s+Agent hierarchy\s*$")

    def test_architecture_documents_canonical_contract_map(self):
        for declaration in self.compatibility["contracts"].values():
            path = declaration["path"]
            with self.subTest(path=path):
                self.assertIn(path, self.architecture)
        self.assertIn("config/agent-contract-compatibility.json", self.architecture)

    def test_core_execution_and_governance_invariants_hold_end_to_end(self):
        roles = self.roles["roles"]
        self.assertEqual(roles["primary_orchestrator"]["provider"], "cursor")
        self.assertTrue(roles["primary_orchestrator"]["default_task_owner"])
        self.assertTrue(roles["deterministic_validation"]["before_ai_escalation"])
        self.assertFalse(roles["independent_reviewer"]["merge_gate"])
        self.assertFalse(roles["merge_authority"]["ai_allowed"])
        self.assertTrue(roles["merge_authority"]["human_final"])
        self.assertTrue(self.roles["invariants"]["no_automatic_vendor_chaining"])
        self.assertTrue(self.roles["invariants"]["duplicate_routine_ai_work_prohibited"])

    def test_conformance_suite_is_registered_in_portable_ci_and_docs(self):
        self.assertIn(SUITE, self.workflow)
        self.assertIn(SUITE, self.tests_readme)
        self.assertIn("test_agent_architecture_conformance.py", self.tests_readme)

    def test_portable_ci_remains_deterministic_and_secret_free(self):
        comments = collapsed_yaml_comments(self.workflow)
        self.assertIn("Deterministic validation only", comments)
        self.assertIn("does not need repository secrets", comments)
        self.assertNotRegex(self.workflow, r"(?i)\b(?:xai|gemini|openai|anthropic)_api_key\b")
        self.assertNotRegex(self.workflow, r"(?i)\b(?:grok|antigravity|cursor)_gh_pat\b")

    def test_collapsed_yaml_comments_join_wrapped_secret_free_phrase(self):
        wrapped = (
            "# Deterministic validation only. This workflow never calls an LLM and does\n"
            "# not need repository secrets.\n"
        )
        self.assertIn(
            "does not need repository secrets",
            collapsed_yaml_comments(wrapped),
        )


if __name__ == "__main__":
    unittest.main()
