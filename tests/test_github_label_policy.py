#!/usr/bin/env python3
"""Deterministic tests for S5-M6 GitHub label policy."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

import sys

sys.path.insert(0, str(ROOT / "scripts"))
import github_label_policy as policy_mod  # noqa: E402


class LabelPolicyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.policy = policy_mod.load_policy()
        cls.forms = {
            path.stem: path.read_text(encoding="utf-8")
            for path in (ROOT / ".github/ISSUE_TEMPLATE").glob("*.yml")
            if path.name != "config.yml"
        }

    def compute(self, event: dict) -> dict:
        return policy_mod.compute_mutations(event, self.policy)

    def test_issue_open_applies_triage_type_and_area(self) -> None:
        body = "### Area\n\nNPU\n\n### What happened\n\nAcceld not detected.\n"
        result = self.compute(
            {
                "action": "opened",
                "kind": "issue",
                "title": "[Bug]: NPU missing after stage1-profile",
                "body": body,
                "current_labels": [],
            }
        )
        self.assertEqual(
            result["apply"],
            ["area:npu", "bug", "needs-triage"],
        )
        self.assertEqual(result["remove"], [])
        self.assertFalse(result["skip"])

    def test_issue_open_without_form_only_applies_triage(self) -> None:
        result = self.compute(
            {
                "action": "opened",
                "kind": "issue",
                "title": "Something is wrong",
                "body": "plain text",
                "current_labels": [],
            }
        )
        self.assertEqual(result["apply"], ["needs-triage"])

    def test_issue_close_completed_drops_queue_labels_only(self) -> None:
        result = self.compute(
            {
                "action": "closed",
                "kind": "issue",
                "title": "[Bug]: NPU missing",
                "state_reason": "completed",
                "current_labels": [
                    "bug",
                    "area:npu",
                    "needs-triage",
                    "needs-info",
                    "needs-reproduction",
                ],
            }
        )
        self.assertEqual(result["apply"], [])
        self.assertEqual(
            result["remove"],
            ["needs-info", "needs-reproduction", "needs-triage"],
        )

    def test_issue_close_not_planned_applies_wontfix(self) -> None:
        result = self.compute(
            {
                "action": "closed",
                "kind": "issue",
                "state_reason": "not_planned",
                "current_labels": ["needs-triage", "enhancement"],
            }
        )
        self.assertEqual(result["apply"], ["wontfix"])
        self.assertEqual(result["remove"], ["needs-triage"])

    def test_issue_close_duplicate_applies_duplicate(self) -> None:
        result = self.compute(
            {
                "action": "closed",
                "kind": "issue",
                "state_reason": "duplicate",
                "current_labels": ["bug"],
            }
        )
        self.assertEqual(result["apply"], ["duplicate"])
        self.assertEqual(result["remove"], [])

    def test_issue_reopen_restores_triage_and_clears_outcome_labels(self) -> None:
        result = self.compute(
            {
                "action": "reopened",
                "kind": "issue",
                "title": "[Bug]: NPU missing",
                "body": "### Area\n\nNPU\n",
                "current_labels": ["bug", "wontfix", "duplicate"],
            }
        )
        self.assertIn("needs-triage", result["apply"])
        self.assertIn("area:npu", result["apply"])
        self.assertEqual(sorted(result["remove"]), ["duplicate", "wontfix"])

    def test_pr_open_from_feat_title_and_npu_paths(self) -> None:
        result = self.compute(
            {
                "action": "opened",
                "kind": "pull_request",
                "title": "feat(npu): Add XRT visibility fixture",
                "files": [
                    "scripts/s2-m4-validate-npu-stack.sh",
                    "tests/test_s2_m4_npu_visibility.py",
                ],
                "current_labels": [],
            }
        )
        self.assertEqual(
            result["apply"],
            ["area:npu", "bump:minor", "enhancement", "validation"],
        )
        self.assertEqual(result["remove"], [])

    def test_pr_breaking_change_uses_major_bump(self) -> None:
        result = self.compute(
            {
                "action": "opened",
                "kind": "pull_request",
                "title": "feat(stage1)!: Replace system-profile schema",
                "files": ["configs/schemas/s1-m5-system-profile.schema.json"],
                "current_labels": [],
            }
        )
        self.assertIn("bump:major", result["apply"])
        self.assertNotIn("bump:minor", result["apply"])
        self.assertIn("area:hardware", result["apply"])

    def test_pr_deps_scope_applies_dependencies(self) -> None:
        result = self.compute(
            {
                "action": "opened",
                "kind": "pull_request",
                "title": "chore(deps): Bump onnx in configs/ai-runtime",
                "files": ["configs/ai-runtime/requirements.txt"],
                "current_labels": [],
            }
        )
        self.assertEqual(result["apply"], ["bump:patch", "dependencies"])

    def test_pr_contract_scope_applies_dev_environment(self) -> None:
        result = self.compute(
            {
                "action": "opened",
                "kind": "pull_request",
                "title": "fix(contract): Align PR governance specialist pass keys",
                "files": ["config/pr-governance.json"],
                "current_labels": [],
            }
        )
        self.assertIn("area:dev-environment", result["apply"])
        self.assertIn("bump:patch", result["apply"])

    def test_pr_agents_scope_applies_dev_environment(self) -> None:
        result = self.compute(
            {
                "action": "opened",
                "kind": "pull_request",
                "title": "chore(agents): Define Cursor hybrid orchestration boundary",
                "files": ["AGENTS.md"],
                "current_labels": [],
            }
        )
        self.assertIn("area:dev-environment", result["apply"])
        self.assertIn("area:docs", result["apply"])
        self.assertIn("bump:patch", result["apply"])

    def test_pr_title_edit_replaces_exclusive_bump_and_type(self) -> None:
        result = self.compute(
            {
                "action": "edited",
                "kind": "pull_request",
                "title": "fix(rocm): Correct iGPU device path detection",
                "files": ["scripts/s2-m3-validate-gpu-stack.sh"],
                "current_labels": ["enhancement", "bump:minor"],
            }
        )
        self.assertIn("bug", result["apply"])
        self.assertIn("bump:patch", result["apply"])
        self.assertIn("area:gpu", result["apply"])
        self.assertEqual(sorted(result["remove"]), ["bump:minor", "enhancement"])

    def test_pr_docs_title_drops_feature_type_labels(self) -> None:
        result = self.compute(
            {
                "action": "edited",
                "kind": "pull_request",
                "title": "docs: Clarify safe-mode defaults in README",
                "files": ["README.md"],
                "current_labels": ["enhancement", "bump:minor"],
            }
        )
        self.assertIn("bump:patch", result["apply"])
        self.assertIn("area:docs", result["apply"])
        self.assertEqual(sorted(result["remove"]), ["bump:minor", "enhancement"])

    def test_pr_close_drops_queue_labels_and_keeps_identity(self) -> None:
        result = self.compute(
            {
                "action": "closed",
                "kind": "pull_request",
                "merged": True,
                "current_labels": [
                    "bump:minor",
                    "area:npu",
                    "enhancement",
                    "needs-triage",
                    "needs-info",
                ],
            }
        )
        self.assertEqual(result["apply"], [])
        self.assertEqual(result["remove"], ["needs-info", "needs-triage"])

    def test_release_please_prs_are_skipped(self) -> None:
        result = self.compute(
            {
                "action": "opened",
                "kind": "pull_request",
                "title": "chore(release): 0.26.0",
                "files": ["CHANGELOG.md", "VERSION"],
                "current_labels": ["autorelease: pending"],
            }
        )
        self.assertTrue(result["skip"])
        self.assertEqual(result["apply"], [])
        self.assertEqual(result["remove"], [])

    def test_path_globs_match_nested_and_basename_patterns(self) -> None:
        self.assertTrue(
            policy_mod.path_matches("docs/ROADMAP.md", "docs/**")
        )
        self.assertTrue(policy_mod.path_matches("README.md", "*.md"))
        self.assertFalse(policy_mod.path_matches("docs/ROADMAP.md", "*.md"))
        self.assertTrue(
            policy_mod.path_matches(
                "scripts/s1-m1-probe-system.sh", "scripts/s1-*"
            )
        )
        self.assertTrue(
            policy_mod.path_matches(
                "workflows/comfyui/sdxl.json", "workflows/comfyui/**"
            )
        )

    def test_issue_form_area_options_match_policy(self) -> None:
        expected = set(self.policy["issue_area_choices"])
        for name, text in self.forms.items():
            with self.subTest(form=name):
                start = text.index("label: Area")
                options_block = text[start:]
                options = []
                in_options = False
                for line in options_block.splitlines():
                    if line.strip() == "options:":
                        in_options = True
                        continue
                    if in_options:
                        if line.startswith("        - "):
                            options.append(line.strip()[2:].strip())
                        elif line.strip() and not line.startswith(" "):
                            break
                        elif line.strip() and not line.startswith("        "):
                            break
                self.assertEqual(set(options), expected, name)

    def test_issue_forms_declare_triage_and_type_labels(self) -> None:
        expected = {
            "bug": ["bug", "needs-triage"],
            "feature": ["enhancement", "needs-triage"],
            "question": ["question", "needs-triage"],
            "security": ["area:security", "needs-triage"],
        }
        for stem, labels in expected.items():
            text = self.forms[stem]
            for label in labels:
                self.assertIn(f"- {label}", text)

    def test_cli_emits_json_for_issue_open(self) -> None:
        payload = {
            "action": "opened",
            "kind": "issue",
            "title": "[Question]: How does stage1 stay read-only?",
            "body": "### Area\n\nDocs\n",
            "current_labels": [],
        }
        import subprocess

        completed = subprocess.run(
            [
                sys.executable,
                str(ROOT / "scripts/github_label_policy.py"),
                "--input",
                "-",
            ],
            check=False,
            capture_output=True,
            text=True,
            input=json.dumps(payload),
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        result = json.loads(completed.stdout)
        self.assertEqual(
            result["apply"],
            ["area:docs", "needs-triage", "question"],
        )


if __name__ == "__main__":
    unittest.main()
