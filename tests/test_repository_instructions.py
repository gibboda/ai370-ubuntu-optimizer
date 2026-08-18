#!/usr/bin/env python3
"""Contract tests for repository implementation instructions."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class RepositoryInstructionsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.agent_instructions = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
        cls.contributing = (ROOT / "CONTRIBUTING.md").read_text(encoding="utf-8")
        cls.pull_request_template = (
            ROOT / ".github/PULL_REQUEST_TEMPLATE.md"
        ).read_text(encoding="utf-8")
        cls.copilot_instructions = (
            ROOT / ".github/copilot-instructions.md"
        ).read_text(encoding="utf-8")

    def test_copilot_instructions_exist(self) -> None:
        self.assertTrue((ROOT / ".github/copilot-instructions.md").is_file())

    def test_all_contributors_must_follow_commit_policy(self) -> None:
        for policy in (
            self.agent_instructions,
            self.contributing,
            self.pull_request_template,
        ):
            with self.subTest(policy=policy[:20]):
                self.assertIn("contributors and co-contributors", policy)
                self.assertIn("Conventional Commit", policy)

        self.assertIn("must follow this policy", self.contributing)
        self.assertIn("Co-authored-by", self.agent_instructions)
        self.assertIn("Co-authored-by", self.contributing)

    def test_copilot_instructions_link_to_authoritative_documents(self) -> None:
        self.assertIn("[`../AGENTS.md`](../AGENTS.md)", self.copilot_instructions)
        self.assertIn(
            "[`../docs/ROADMAP.md`](../docs/ROADMAP.md)", self.copilot_instructions
        )
        self.assertIn(
            "[`../docs/HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md`](../docs/HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md)",
            self.copilot_instructions,
        )
        self.assertIn(
            "[`../docs/RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md`](../docs/RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md)",
            self.copilot_instructions,
        )
        self.assertIn(
            "[`../configs/schemas/system-profile.schema.json`](../configs/schemas/system-profile.schema.json)",
            self.copilot_instructions,
        )

    def test_both_instruction_files_preserve_stage_1_boundary(self) -> None:
        for instructions in (self.agent_instructions, self.copilot_instructions):
            with self.subTest(instructions=instructions[:20]):
                self.assertIn("Stage 1 is read-only", instructions)

    def test_both_instruction_files_prohibit_new_tier_names(self) -> None:
        for instructions in (self.agent_instructions, self.copilot_instructions):
            with self.subTest(instructions=instructions[:20]):
                self.assertIn("do not introduce new tier", instructions.casefold())

    def test_both_instruction_files_define_elitemini_as_reference_only(self) -> None:
        for instructions in (self.agent_instructions, self.copilot_instructions):
            with self.subTest(instructions=instructions[:20]):
                self.assertIn("EliteMini AI370 is", instructions)
                self.assertIn("not a universal hardware assumption", instructions)

    def test_agent_instructions_preserve_roadmap_authority_and_plan_docs(self) -> None:
        self.assertIn("`docs/ROADMAP.md` is authoritative", self.agent_instructions)
        self.assertIn(
            "HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md", self.agent_instructions
        )
        self.assertIn(
            "RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md", self.agent_instructions
        )
        self.assertIn("not public command names", self.agent_instructions)
        self.assertIn(
            "Never label planned functionality as implemented", self.agent_instructions
        )


class MigrationPlanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.plan = (
            ROOT / "docs/RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md"
        ).read_text(encoding="utf-8")
        cls.architecture = (
            ROOT / "docs/HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md"
        ).read_text(encoding="utf-8")
        cls.roadmap = (ROOT / "docs/ROADMAP.md").read_text(encoding="utf-8")

    def test_migration_plan_exists(self) -> None:
        self.assertTrue(
            (ROOT / "docs/RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md").is_file()
        )

    def test_migration_plan_names_current_and_future_repository(self) -> None:
        self.assertIn("gibboda/ai370-ubuntu-optimizer", self.plan)
        self.assertIn("gibboda/ryzen-ai-linux-platform", self.plan)
        self.assertNotIn("gibboda/ryzen-ai-linux\n", self.plan)
        self.assertIn("Do not rename", self.plan)

    def test_migration_plan_preserves_roadmap_authority(self) -> None:
        self.assertIn("`docs/ROADMAP.md` remains the implementation authority", self.plan)
        self.assertIn("not public command names", self.plan)
        self.assertIn("Do not add `stage6` through", self.plan)
        self.assertIn("RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md", self.roadmap)

    def test_migration_plan_defines_status_and_capability_terms(self) -> None:
        for token in (
            "IMPLEMENTED",
            "PARTIAL",
            "PLANNED",
            "DEPRECATED",
            "PASS",
            "WARN",
            "FAIL",
            "UNSUPPORTED",
            "SKIPPED",
            "SUPPORTED",
            "TESTED",
            "EXPERIMENTAL",
            "DETECTED",
            "DRIVER_READY",
            "APPLICATION_READY",
            "KEEP",
            "REFACTOR",
            "MOVE",
            "SPLIT",
            "MERGE",
            "DEPRECATE",
            "REMOVE",
            "REFERENCE_PLATFORM_FACT",
            "CAPABILITY_DETECTION_RULE",
            "TEMPORARY_COMPATIBILITY_RULE",
            "UNNECESSARY_HARDCODE",
        ):
            with self.subTest(token=token):
                self.assertIn(token, self.plan)

    def test_migration_plan_does_not_claim_planned_work_implemented(self) -> None:
        self.assertIn("FastFlowLM is PLANNED", self.plan)
        self.assertIn("`desktop/macos-like/`", self.plan)
        self.assertIn("| `desktop/macos-like/` | PLANNED |", self.plan)
        self.assertIn("VS Code / Continue / Aider local coding AI | PLANNED", self.plan)
        self.assertIn("Never describe `PLANNED` functionality as implemented", self.plan)
        self.assertIn("mark any ROADMAP milestone Implemented", self.plan)

    def test_architecture_document_remains_the_target_source(self) -> None:
        self.assertIn("gibboda/ryzen-ai-linux-platform", self.architecture)
        self.assertIn("Task 24", self.architecture)
        self.assertIn("HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md", self.plan)

    def test_migration_plan_inventories_tracked_runtime_pins(self) -> None:
        for path in (
            ".ai370-ai/ryzen-ai/source/install_ryzen_ai.sh",
            "configs/ai-runtime/requirements-offline.txt",
            ".ai370-ai/tools/llama.cpp",
        ):
            with self.subTest(path=path):
                self.assertIn(path, self.plan)
        self.assertIn("python3.12", self.plan)
        self.assertIn("ryzen-ai>=1.7.0.dev0,<1.8.0.dev0", self.plan)
        self.assertIn("onnxruntime==1.22.0", self.plan)
        self.assertIn("160000", self.plan)
        self.assertIn("86b94708f22478f900b76ca02e316f4f3418faff", self.plan)


if __name__ == "__main__":
    unittest.main()
