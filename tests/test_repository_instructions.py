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

    def test_migration_plan_matches_current_stage1_and_ladder_inventory(self) -> None:
        self.assertNotIn("only S1-M1 is canonically Implemented", self.plan)
        self.assertIn(
            "S1-M1 through S1-M5 are Implemented; `stage1` is read-only profile publication",
            self.plan,
        )
        for path in (
            "scripts/lib/capability_ladder.py",
            "scripts/s2-m3-validate-gpu-stack.sh",
            "scripts/s2-m3-publish-gpu-visibility.py",
            "scripts/s2-m4-validate-npu-stack.sh",
            "scripts/s2-m4-publish-npu-visibility.py",
            "tests/test_capability_ladder.py",
            "tests/test_s2_visibility_schemas.py",
            "tests/test_s2_m3_gpu_visibility.py",
            "tests/test_s2_m4_npu_visibility.py",
            "tests/smoke_stage2_platform.sh",
        ):
            with self.subTest(path=path):
                self.assertIn(path, self.plan)
        self.assertIn("tests.test_capability_ladder", self.plan)
        self.assertIn("tests.test_s2_visibility_schemas", self.plan)
        self.assertIn("tests.test_s2_m3_gpu_visibility", self.plan)
        self.assertIn("tests.test_s2_m4_npu_visibility", self.plan)
        self.assertIn("issues/168", self.plan)
        self.assertIn("issues/169", self.plan)
        self.assertIn("target_gpu_arch", self.plan)
        self.assertIn("0.20.0", self.plan)
        self.assertIn("0.21.0", self.plan)
        self.assertIn("#176", self.plan)
        self.assertIn("#180", self.plan)
        self.assertIn("tests/test_s2_m4_npu_visibility.py", self.roadmap)
        self.assertNotIn("S2-M4 publisher tests remain issue #168", self.roadmap)
        self.assertNotIn(
            "JSON still hardcodes `target_gpu_arch=gfx1150`",
            self.plan,
        )
        self.assertNotIn("no publisher CLI yet", self.plan)
        self.assertNotIn("NPU publisher remains", self.plan)
        self.assertNotIn("NPU publisher CLI remains issue #168", self.plan)

    def test_open_issue_templates_match_remaining_publisher_work(self) -> None:
        issue168 = (ROOT / ".github/issues/pr2-capability-ladders.md").read_text(
            encoding="utf-8"
        )
        issue169 = (ROOT / ".github/issues/pr3-read-only-stage1.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("Workstream C GPU publisher", issue168)
        self.assertIn("Workstream D NPU publisher", issue168)
        self.assertIn("`#180`", issue168)
        self.assertIn("0.21.0", issue168)
        self.assertNotIn("command does not exist yet", issue168)
        self.assertIn("visibility-only NPU", issue168)
        self.assertIn("Remaining GitHub issue work is none", issue168)
        self.assertIn("NPU visibility-only publisher", issue169)
        self.assertIn("`#176`", issue169)
        self.assertIn("`#180`", issue169)
        self.assertIn("PR 3a", issue169)
        self.assertIn("do not recreate", issue169)
        self.assertIn("stage2-platform-validate", issue169)
        self.assertNotIn("landed with GPU publisher", issue169)

    def test_orchestrator_help_mentions_visibility_only_npu_path(self) -> None:
        orchestrator = (ROOT / "ai370-optimize.sh").read_text(encoding="utf-8")
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("stage2-npu-validate is visibility-only (S2-M4)", orchestrator)
        self.assertIn("s2-m4-validate-npu-stack", orchestrator)
        self.assertIn("always refreshes tier3-validation.json", orchestrator)
        self.assertIn("stage2-platform-validate", orchestrator)
        self.assertIn("stage2-optimize-apply --approve", orchestrator)
        self.assertIn("s2-m4-npu-runtime-validation.json", readme)
        self.assertIn("visibility-only", readme.casefold())
        self.assertIn("stage2-npu-validate", readme)
        self.assertIn("tier3-validation.json", readme)

    def test_stage1_orchestrator_is_read_only_profile(self) -> None:
        orchestrator = (ROOT / "ai370-optimize.sh").read_text(encoding="utf-8")
        self.assertIn("Stage 1 is read-only probe + profile", orchestrator)
        self.assertNotIn("export AI370_APPLY_TUNING=true", orchestrator.split("run_stage2_optimize_apply")[0])
        self.assertIn("run_stage1_profile", orchestrator)
        self.assertNotIn("\nrun_stage1()\n", orchestrator)
        self.assertIn("stage2-validate is a cheap runtime/NPU gate refresh", orchestrator)

    def test_readme_stage2_status_matches_roadmap(self) -> None:
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        issue169 = (ROOT / ".github/issues/pr3-read-only-stage1.md").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("scope is **implemented** (S2-M1–S2-M7)", readme)
        self.assertIn("stage2-platform-validate", readme)
        self.assertIn("S2-M3/S2-M4 In progress", readme)
        self.assertIn("S3-M5", readme)
        self.assertIn("does not label Planned Stage 2 milestones as implemented", issue169)


if __name__ == "__main__":
    unittest.main()
