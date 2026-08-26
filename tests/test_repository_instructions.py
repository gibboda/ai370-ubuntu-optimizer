#!/usr/bin/env python3
"""Contract tests for repository implementation instructions."""

import json
import re
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

_MILESTONE_ID = re.compile(r"^S[1-5]-M\d+$")
_MILESTONE_STATUS = frozenset({"Implemented", "In progress", "Planned"})
_README_S2_IN_PROGRESS_GROUP = re.compile(
    r"(S2-M\d+(?:/S2-M\d+)*)(?: are\s+\*\*In progress\*\*| In progress)"
)
_README_S2_IMPLEMENTED = re.compile(
    r"(S2-M\d+)(?: is \*\*Implemented\*\*|\nImplemented| Implemented)"
)


def parse_roadmap_milestone_statuses(roadmap: str) -> dict[str, str]:
    """Parse ROADMAP canonical-deliverable table rows into ID -> status."""
    statuses: dict[str, str] = {}
    for line in roadmap.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if len(cells) != 5:
            continue
        milestone_id, _deliverable, _outputs, _evidence, status = cells
        if _MILESTONE_ID.fullmatch(milestone_id) and status in _MILESTONE_STATUS:
            statuses[milestone_id] = status
    return statuses


def _milestone_sort_key(milestone_id: str) -> tuple[int, int]:
    stage, mile = milestone_id.split("-M")
    return int(stage[1:]), int(mile)


class RepositoryInstructionsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.agent_instructions = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
        cls.contributing = (ROOT / "CONTRIBUTING.md").read_text(encoding="utf-8")
        cls.pull_request_template = (
            ROOT / ".github/PULL_REQUEST_TEMPLATE.md"
        ).read_text(encoding="utf-8")
        cls.copilot_pointer = (
            ROOT / ".github/copilot-instructions.md"
        ).read_text(encoding="utf-8")
        cls.copilot_instructions = (
            ROOT / ".github/instructions/copilot.instructions.md"
        ).read_text(encoding="utf-8")
        cls.codex_instructions = (
            ROOT / ".github/instructions/codex.instructions.md"
        ).read_text(encoding="utf-8")
        cls.cursor_rules = (
            ROOT / ".cursor/rules/cursor.mdc"
        ).read_text(encoding="utf-8")

    def test_instruction_hierarchy_files_exist(self) -> None:
        for path in (
            ROOT / "AGENTS.md",
            ROOT / ".github/copilot-instructions.md",
            ROOT / ".github/instructions/copilot.instructions.md",
            ROOT / ".github/instructions/codex.instructions.md",
            ROOT / ".cursor/rules/cursor.mdc",
        ):
            with self.subTest(path=path):
                self.assertTrue(path.is_file(), path)

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
        self.assertIn(
            "bash scripts/validate-pr-title.sh", self.agent_instructions
        )
        self.assertIn(
            "Do not open the PR unless the title validation command passes",
            self.agent_instructions,
        )

    def test_agent_specific_files_point_to_shared_policy(self) -> None:
        self.assertIn("[`../AGENTS.md`](../AGENTS.md)", self.copilot_pointer)
        self.assertIn(
            "compatibility pointer, not a second policy surface",
            self.copilot_pointer,
        )
        self.assertIn(
            "[`../../AGENTS.md`](../../AGENTS.md)", self.copilot_instructions
        )
        self.assertIn(
            "[`../../AGENTS.md`](../../AGENTS.md)", self.codex_instructions
        )
        self.assertIn("[`AGENTS.md`](../../AGENTS.md)", self.cursor_rules)
        self.assertIn(
            "[`AGENTS.md`](AGENTS.md)",
            self.contributing,
        )

    def test_shared_policy_names_authoritative_documents(self) -> None:
        self.assertIn("`docs/ROADMAP.md`", self.agent_instructions)
        self.assertIn(
            "HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md", self.agent_instructions
        )
        self.assertIn(
            "RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md", self.agent_instructions
        )
        self.assertIn(
            "configs/schemas/system-profile.schema.json", self.agent_instructions
        )
        self.assertIn("Before changing code", self.agent_instructions)
        self.assertIn("reading order in `AGENTS.md`", self.copilot_instructions)

    def test_shared_policy_preserves_stage_1_boundary(self) -> None:
        self.assertIn("Stage 1 is read-only", self.agent_instructions)
        self.assertNotIn("Stage 1 is read-only", self.copilot_instructions)
        self.assertNotIn("Stage 1 is read-only", self.codex_instructions)
        self.assertNotIn("Stage 1 is read-only", self.cursor_rules)

    def test_shared_policy_prohibits_new_tier_names(self) -> None:
        self.assertIn("do not introduce new tier", self.agent_instructions.casefold())
        self.assertNotIn(
            "do not introduce new tier", self.copilot_instructions.casefold()
        )
        self.assertNotIn(
            "do not introduce new tier", self.codex_instructions.casefold()
        )

    def test_shared_policy_defines_elitemini_as_reference_only(self) -> None:
        self.assertIn("EliteMini AI370 is", self.agent_instructions)
        self.assertIn("not a universal hardware assumption", self.agent_instructions)
        self.assertNotIn("EliteMini AI370 is", self.copilot_instructions)
        self.assertNotIn("EliteMini AI370 is", self.codex_instructions)

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
        self.assertIn(
            "README high-level status must match `docs/ROADMAP.md` milestone rows",
            self.agent_instructions,
        )
        self.assertNotIn(
            "README high-level status must match",
            self.copilot_instructions,
        )
        self.assertNotIn(
            "README high-level status must match",
            self.codex_instructions,
        )
        self.assertIn(
            "Do not add public `stage6` through `stage11` commands",
            self.agent_instructions,
        )

    def test_agent_instructions_define_cost_efficient_multi_agent_policy(
        self,
    ) -> None:
        self.assertIn(
            "Cursor Agent is the primary/default implementation agent",
            self.agent_instructions,
        )
        self.assertIn(
            "Grok Build is the preferred secondary agent when available",
            self.agent_instructions,
        )
        self.assertIn(
            "If Grok Build is unavailable",
            self.agent_instructions,
        )
        self.assertIn(
            "use an available specialist agent such as",
            self.agent_instructions,
        )
        self.assertIn(
            "another explicitly approved agent",
            self.agent_instructions,
        )
        self.assertIn(
            "GitHub remains the source of truth and control plane",
            self.agent_instructions,
        )
        self.assertIn(
            "specialist/escalation resources", self.agent_instructions
        )
        self.assertIn(
            "must not be invoked automatically for",
            self.agent_instructions,
        )
        self.assertIn(
            "Do not treat this repository as Cursor-exclusive",
            self.agent_instructions,
        )
        self.assertIn(
            "Keep routine work with Cursor whenever practical",
            self.agent_instructions,
        )
        self.assertIn(
            "Do not invoke multiple paid or cloud agents for the same routine task",
            self.agent_instructions,
        )
        self.assertIn(
            "Minimize duplicate paid-agent analysis",
            self.agent_instructions,
        )
        self.assertIn(
            "reuse prior agent findings, logs, issue/PR",
            self.agent_instructions,
        )
        self.assertIn(
            "CI results, tests, and local validation output",
            self.agent_instructions,
        )
        self.assertIn("independent-developer budget", self.agent_instructions)
        self.assertIn(
            "Prefer deterministic validation over AI review",
            self.agent_instructions,
        )
        self.assertIn("AI reviews are advisory", self.agent_instructions)
        self.assertIn("not required merge gates", self.agent_instructions)
        self.assertIn("GitHub Copilot, Codex, Claude", self.agent_instructions)

    def test_cursor_cloud_notes_live_in_cursor_rules(self) -> None:
        self.assertIn(
            "These notes apply when the agent is running in Cursor Cloud",
            self.cursor_rules,
        )
        self.assertNotIn(
            "These notes apply when the agent is running in Cursor Cloud",
            self.agent_instructions,
        )
        self.assertIn("alwaysApply: true", self.cursor_rules)
        self.assertIn("startup update script", self.cursor_rules)
        self.assertIn("markdownlint-cli2", self.cursor_rules)

    def test_cursor_hybrid_orchestration_stays_cursor_specific(self) -> None:
        self.assertIn("Hybrid orchestration boundary", self.cursor_rules)
        self.assertIn("If the task produces repository changes", self.cursor_rules)
        self.assertIn("automated orchestration boundary", self.cursor_rules)
        self.assertIn("XAI_API_KEY", self.cursor_rules)
        self.assertIn(
            "Follow the shared escalation, cost, and default-implementation policy",
            self.cursor_rules,
        )
        self.assertNotIn(
            "Do not invoke a secondary AI agent merely because it is available",
            self.cursor_rules,
        )
        self.assertNotIn(
            "Cursor remains responsible for the default implementation path",
            self.cursor_rules,
        )
        self.assertNotIn("If the task produces repository changes", self.agent_instructions)

    def test_cursor_github_projects_mcp_has_no_secrets(self) -> None:
        mcp_path = ROOT / ".cursor/mcp.json"
        self.assertTrue(mcp_path.is_file(), mcp_path)
        raw = mcp_path.read_text(encoding="utf-8")
        self.assertNotRegex(
            raw,
            r"gh[pousr]_[A-Za-z0-9_]+|github_pat_[A-Za-z0-9_]+|YOUR_GITHUB_PAT",
        )
        config = json.loads(raw)
        server = config["mcpServers"]["github-projects"]
        self.assertEqual(
            server["url"],
            "https://api.githubcopilot.com/mcp/x/projects",
        )
        self.assertIn("${env:GITHUB_MCP_PAT}", server["headers"]["Authorization"])
        self.assertIn("https://api.githubcopilot.com/mcp/x/projects", self.cursor_rules)
        self.assertIn("mcpServerAllowlist", self.cursor_rules)
        self.assertIn("Do not commit `.cursor/environment.json`", self.cursor_rules)
        self.assertFalse(
            (ROOT / ".cursor/environment.json").exists(),
            "A committed environment.json would override the dashboard Cloud Agent environment",
        )

    def test_codex_pr_title_requirements_live_in_codex_instructions(self) -> None:
        self.assertIn(
            "Codex is a specialist/escalation agent", self.codex_instructions
        )
        self.assertIn(
            "[`../../CONTRIBUTING.md`](../../CONTRIBUTING.md)",
            self.codex_instructions,
        )
        self.assertIn(
            "bash scripts/validate-pr-title.sh", self.codex_instructions
        )
        self.assertIn(
            "Do not open the PR unless the title validation command passes",
            self.codex_instructions,
        )
        self.assertNotIn("## Codex PR creation policy", self.agent_instructions)
        self.assertNotIn("- `feat`", self.agent_instructions)
        self.assertNotIn("- `audit`", self.agent_instructions)


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
            "scripts/s2-m7-publish-platform-validation.py",
            "scripts/s2-m5-publish-optimization-plan.py",
            "scripts/s2-m6-publish-optimization-application.py",
            "scripts/lib/optimization_plan.py",
            "scripts/s2-m1-publish-firmware-validation.py",
            "scripts/s2-m2-publish-kernel-driver-validation.py",
            "scripts/lib/kernel_validation.py",
            "tests/test_capability_ladder.py",
            "tests/test_s2_visibility_schemas.py",
            "tests/test_s2_m3_gpu_visibility.py",
            "tests/test_s2_m4_npu_visibility.py",
            "tests/test_s2_m7_platform_validation.py",
            "tests/test_s2_m7_gate.py",
            "tests/test_s2_m1_firmware.py",
            "tests/test_s2_m2_kernel_driver.py",
            "tests/test_s2_optimize_profile.py",
            "tests/test_s2_m5_optimization_plan.py",
            "tests/test_s2_m6_optimization_apply.py",
            "tests/smoke_stage2_platform.sh",
        ):
            with self.subTest(path=path):
                self.assertIn(path, self.plan)
        self.assertIn("tests.test_capability_ladder", self.plan)
        self.assertIn("tests.test_s2_visibility_schemas", self.plan)
        self.assertIn("tests.test_s2_m3_gpu_visibility", self.plan)
        self.assertIn("tests.test_s2_m4_npu_visibility", self.plan)
        self.assertIn("tests.test_s2_m7_platform_validation", self.plan)
        self.assertIn("tests.test_s2_m7_gate", self.plan)
        self.assertIn("tests.test_s2_m1_firmware", self.plan)
        self.assertIn("tests.test_s2_m2_kernel_driver", self.plan)
        self.assertIn("tests.test_s2_optimize_profile", self.plan)
        self.assertIn("tests.test_s2_m5_optimization_plan", self.plan)
        self.assertIn("tests.test_s2_m6_optimization_apply", self.plan)
        self.assertIn("issues/168", self.plan)
        self.assertIn("issues/169", self.plan)
        self.assertIn("target_gpu_arch", self.plan)
        self.assertIn("0.20.0", self.plan)
        self.assertIn("0.21.0", self.plan)
        self.assertIn("#176", self.plan)
        self.assertIn("#180", self.plan)
        self.assertIn("tests/test_s2_m4_npu_visibility.py", self.roadmap)
        self.assertIn("tests/test_s2_m7_platform_validation.py", self.roadmap)
        self.assertIn("tests/test_s2_m7_gate.py", self.roadmap)
        self.assertIn("tests/test_s2_m5_optimization_plan.py", self.roadmap)
        self.assertIn("tests/test_s2_m6_optimization_apply.py", self.roadmap)
        self.assertIn("tests/test_s2_m2_kernel_driver.py", self.roadmap)
        self.assertNotIn("S2-M4 publisher tests remain issue #168", self.roadmap)
        self.assertNotIn(
            "JSON still hardcodes `target_gpu_arch=gfx1150`",
            self.plan,
        )
        self.assertNotIn("no publisher CLI yet", self.plan)
        self.assertNotIn("NPU publisher remains", self.plan)
        self.assertNotIn("NPU publisher CLI remains issue #168", self.plan)

    def test_migration_plan_defines_documentation_sync_contract(self) -> None:
        self.assertIn("## Documentation sync", self.plan)
        self.assertIn("README follows ROADMAP", self.plan)
        self.assertIn("Same commit as the code", self.plan)
        self.assertIn("Not a sequence 4–11 issue", self.plan)
        self.assertIn("Do not file GitHub issues\n4–11 for documentation sync", self.plan)
        self.assertIn("| 3-docs Documentation sync | **done** (this change)", self.plan)
        self.assertNotIn(
            "S2-M1/S2-M2/S2-M3/S2-M4/S2-M5/S2-M6/S2-M7 In progress",
            self.plan,
        )
        self.assertNotIn(
            "Reports canonical Planned milestones as implemented",
            self.plan,
        )
        self.assertIn(
            "User-facing `README.md` status must match this",
            self.roadmap,
        )

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
        self.assertIn("#183", issue169)
        self.assertIn("#184", issue169)
        self.assertIn("#197", issue169)
        self.assertIn("#199", issue169)
        self.assertIn("#201", issue169)
        self.assertIn("#203", issue169)
        self.assertIn("This issue's PR 3 workstreams are **complete**", issue169)
        self.assertIn(
            "- [x] Make `stage1` / `tier1` call `run_stage1_profile` only",
            issue169,
        )
        self.assertIn(
            "- [x] Fix `full-stack` / `all` sequence: profile → platform validate → runtime",
            issue169,
        )
        self.assertIn(
            "- [x] Legacy commands (`kernel-amd`, `tune`, `firmware`) warn toward `stage2-*`",
            issue169,
        )
        self.assertIn(
            "- [x] Keep compat `tier1-platform-tuning.json` until R1",
            issue169,
        )
        self.assertIn(
            "- [x] Remove tuning from all Stage 1 / `full-stack` Stage 1 paths",
            issue169,
        )
        self.assertIn(
            "- [x] PR title passes `bash scripts/validate-pr-title.sh`",
            issue169,
        )
        self.assertIn("- [x] Add `scripts/s2-m7-publish-platform-validation.py`", issue169)
        self.assertIn(
            "- [x] Add `configs/schemas/s2-m7-platform-validation.schema.json`",
            issue169,
        )
        self.assertIn(
            "- [x] Publish `reports/latest/s2-m7-platform-validation.json`",
            issue169,
        )
        self.assertIn(
            "- [x] Slim `90-validate.sh` to compat shim writing `tier1-validation.json`",
            issue169,
        )
        self.assertIn(
            "- [x] Remove inline gfx1150/NPU re-detection from `90-validate.sh`",
            issue169,
        )
        self.assertIn(
            "- [x] Split plan vs apply in `40-platform-tuning.sh`; apply requires `--approve`",
            issue169,
        )
        self.assertIn(
            "- [x] Canonical outputs: `s2-m5-optimization-plan.json`, `s2-m6-optimization-application.json`",
            issue169,
        )
        self.assertIn(
            "- [x] `s2-m1-firmware-validation.json` from `20-check-bios.sh`; keep `tier1-firmware.json` compat",
            issue169,
        )
        self.assertIn("- [x] Split BIOS facts vs policy in `20-check-bios.sh`", issue169)
        self.assertIn(
            "- [x] `s2-m2-kernel-driver-validation.json` from `30-validate-kernel.sh`",
            issue169,
        )
        self.assertIn(
            "- [x] `require_tier123_pass` prefers `s2-m7-platform-validation.json`; fallback `tier1-validation.json`",
            issue169,
        )
        self.assertIn(
            "- [x] Switch `10-detect-hardware.sh` callers to `stage1-probe` + `stage1-profile`",
            issue169,
        )
        self.assertIn(
            "- [x] `tests/test_s2_m7_platform_validation.py` — aggregate from fixture milestone JSONs",
            issue169,
        )
        self.assertIn(
            "- [x] `tests/test_s2_m7_gate.py` — `require_tier123_pass` prefers S2-M7",
            issue169,
        )
        self.assertIn(
            "- [x] `tests/test_s2_m5_optimization_plan.py` — plan-only, no mutation",
            issue169,
        )
        self.assertIn(
            "- [x] `tests/test_s2_m6_optimization_apply.py` — apply requires `--approve`",
            issue169,
        )
        self.assertIn(
            "- [x] `tests/test_s2_m2_kernel_driver.py` — canonical S2-M2 JSON",
            issue169,
        )
        self.assertIn("- [x] Mark migration plan step 3 done", issue169)
        self.assertIn("- [x] Deprecate `TASK_PROPOSALS.md` Tier language", issue169)
        self.assertIn("- [x] Update ROADMAP milestone status for S2-M1/M2/M5/M7 only when exit evidence exists", issue169)
        proposals = (ROOT / "TASK_PROPOSALS.md").read_text(encoding="utf-8")
        self.assertIn("compatibility backlog", proposals.casefold())
        self.assertIn("Do not add new Tier-named tasks", proposals)
        self.assertIn("| 3 Stop Stage 1 mutation | **done**", self.plan)
        self.assertIn(
            "- [x] `s2-m7-platform-validation.json` validates against schema",
            issue169,
        )
        self.assertIn(
            "- [x] `tier1-validation.json` compat shim preserves `require_tier123_pass`",
            issue169,
        )
        self.assertNotIn(
            "- [ ] `stage2-validate` alias for platform validate until S3 gates split",
            issue169,
        )
        self.assertIn(
            "The original alias-to-platform-validate item is **superseded**",
            issue169,
        )
        self.assertIn(
            "Aliasing `stage2-validate` to platform validate (PR 3a kept it as the runtime/NPU cheap gate)",
            issue169,
        )

    def test_orchestrator_help_mentions_visibility_only_npu_path(self) -> None:
        orchestrator = (ROOT / "ai370-optimize.sh").read_text(encoding="utf-8")
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("stage2-npu-validate is visibility-only (S2-M4)", orchestrator)
        self.assertIn("s2-m4-validate-npu-stack", orchestrator)
        self.assertIn("always refreshes tier3-validation.json", orchestrator)
        self.assertIn("stage2-platform-validate", orchestrator)
        self.assertIn("stage2-optimize-apply --approve", orchestrator)
        self.assertIn("s2-m7-platform-validation.json", orchestrator)
        inventory_fn = orchestrator.split("run_stage2_platform_inventory()", 1)[1].split(
            "run_stage2_platform_validate()", 1
        )[0]
        validate_fn = orchestrator.split("run_stage2_platform_validate()", 1)[1].split(
            "run_stage2_optimize_plan()", 1
        )[0]
        self.assertNotIn("10-detect-hardware.sh", inventory_fn)
        self.assertNotIn("10-detect-hardware.sh", validate_fn)
        self.assertIn("ensure_stage1_profile", inventory_fn)
        self.assertIn("ensure_stage1_profile", validate_fn)
        gate_fn = orchestrator.split("require_tier123_pass()", 1)[1].split(
            "load_runtime_config()", 1
        )[0]
        self.assertLess(
            gate_fn.find("s2-m7-platform-validation.json"),
            gate_fn.find("tier1-validation.json"),
        )
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
        firmware_case = orchestrator.split("stage2-firmware-validate)", 1)[1].split(
            "stage2-kernel-validate)", 1
        )[0]
        self.assertIn("ensure_stage1_profile", firmware_case)
        kernel_case = orchestrator.split("stage2-kernel-validate)", 1)[1].split(
            "stage2-optimize-plan)", 1
        )[0]
        self.assertIn("ensure_stage1_profile", kernel_case)
        plan_fn = orchestrator.split("run_stage2_optimize_plan()", 1)[1].split(
            "run_stage2_optimize_apply()", 1
        )[0]
        self.assertIn("ensure_stage1_profile", plan_fn)
        apply_fn = orchestrator.split("run_stage2_optimize_apply()", 1)[1].split(
            "run_stage2_runtime_core()", 1
        )[0]
        self.assertIn("ensure_stage1_profile", apply_fn)
        self.assertIn("Optional pack: lemonade (S3-M5)", orchestrator)
        self.assertIn("Optional pack: digest (S3-M4 diagnostics)", orchestrator)
        self.assertIn("Optional pack: rag (S4-M3)", orchestrator)
        self.assertNotIn("Optional pack: lemonade (S2-M6)", orchestrator)
        self.assertNotIn("Optional pack: digest (S2-M7)", orchestrator)

    def test_readme_stage2_status_matches_roadmap(self) -> None:
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        issue169 = (ROOT / ".github/issues/pr3-read-only-stage1.md").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("scope is **implemented** (S2-M1–S2-M7)", readme)
        self.assertIn("stage2-platform-validate", readme)
        statuses = parse_roadmap_milestone_statuses(self.roadmap)
        s2 = {
            milestone_id: status
            for milestone_id, status in statuses.items()
            if milestone_id.startswith("S2-")
        }
        self.assertGreaterEqual(len(s2), 7, "ROADMAP Stage 2 table missing rows")
        self.assertEqual(
            set(s2),
            {f"S2-M{index}" for index in range(1, 8)},
            "ROADMAP Stage 2 table must list S2-M1 through S2-M7",
        )
        in_progress = sorted(
            (
                milestone_id
                for milestone_id, status in s2.items()
                if status == "In progress"
            ),
            key=_milestone_sort_key,
        )
        implemented = sorted(
            (
                milestone_id
                for milestone_id, status in s2.items()
                if status == "Implemented"
            ),
            key=_milestone_sort_key,
        )
        progress_groups = _README_S2_IN_PROGRESS_GROUP.findall(readme)
        if in_progress:
            self.assertTrue(
                progress_groups,
                "README must list Stage 2 In progress milestones",
            )
            for group in progress_groups:
                self.assertEqual(
                    group.split("/"),
                    in_progress,
                    "README In progress group must match ROADMAP Stage 2 rows",
                )
        else:
            self.assertEqual(progress_groups, [])
        mentioned_implemented = set(_README_S2_IMPLEMENTED.findall(readme))
        self.assertEqual(
            mentioned_implemented,
            set(implemented),
            "README Implemented S2 labels must match ROADMAP Stage 2 rows",
        )
        self.assertNotIn("Next implementation steps", readme)
        self.assertIn("S3-M5", readme)
        self.assertIn("does not label Planned Stage 2 milestones as implemented", issue169)
        self.assertNotIn(
            "firmware                               -> Stage 1",
            readme,
        )
        self.assertIn(
            "firmware                               -> Stage 2 platform BIOS check",
            readme,
        )
        self.assertIn(
            "| S2-M7 | Platform validation aggregate | `stage2-platform-validate`",
            self.roadmap,
        )
        validate = (ROOT / "scripts/90-validate.sh").read_text(encoding="utf-8")
        self.assertNotIn("stage1 --with-ai-smoke", validate)
        self.assertIn("stage2-platform-validate", validate)
        self.assertIn("stage2-platform-inventory", validate)
        self.assertNotIn("--inventory for the inventory alias", validate)
        tuning = (ROOT / "scripts/40-platform-tuning.sh").read_text(encoding="utf-8")
        self.assertNotIn("Stage 1:", tuning)
        self.assertIn("Stage 2 / 40-platform-tuning.sh", tuning)
        self.assertIn("s1-m5-system-profile.json", tuning)
        self.assertNotIn(
            "accel-validate | gpu | npu             -> Stage 2 GPU/NPU visibility",
            readme,
        )
        self.assertIn(
            "npu                                    -> mixed: Stage 2 NPU visibility (210/220) + S3-M6 benchmark (230)",
            readme,
        )

    def test_compatibility_docs_use_roadmap_owners(self) -> None:
        contributing = (ROOT / "CONTRIBUTING.md").read_text(encoding="utf-8")
        proposals = (ROOT / "TASK_PROPOSALS.md").read_text(encoding="utf-8")
        npu_status = (ROOT / "docs/npu-status.md").read_text(encoding="utf-8")
        reports = (ROOT / "reports/README.md").read_text(encoding="utf-8")
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("scripts/legacy/01-hardware-audit.sh", contributing)
        self.assertIn("scripts/legacy/10-amd-baseline.sh", contributing)
        self.assertIn("scripts/420-benchmark-comfyui.sh", proposals)
        self.assertNotIn("scripts/comfyui-benchmark.sh", proposals)
        self.assertIn("S2-M2 is kernel and driver validation", npu_status)
        self.assertIn("stage2-platform-validate", reports)
        self.assertIn("deprecated alias", reports.casefold())
        self.assertNotIn("Implemented offline lifecycle (S2-M3)", readme)
        self.assertIn("**Stage gate policy.**", self.roadmap)
        self.assertIn("0.25.0", self.plan)
        firmware = (ROOT / "scripts/25-check-firmware.sh").read_text(encoding="utf-8")
        self.assertIn("is deprecated", firmware)

    def test_readme_stage2_status_detects_roadmap_drift(self) -> None:
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        drifted_roadmap = self.roadmap.replace(
            "| Deterministic policy fixtures and remediation docs | In progress |",
            "| Deterministic policy fixtures and remediation docs | Implemented |",
            1,
        )
        statuses = parse_roadmap_milestone_statuses(drifted_roadmap)
        self.assertEqual(statuses.get("S2-M1"), "Implemented")
        in_progress = sorted(
            (
                milestone_id
                for milestone_id, status in statuses.items()
                if milestone_id.startswith("S2-") and status == "In progress"
            ),
            key=_milestone_sort_key,
        )
        progress_groups = _README_S2_IN_PROGRESS_GROUP.findall(readme)
        self.assertTrue(progress_groups)
        self.assertNotEqual(progress_groups[0].split("/"), in_progress)
        mentioned_implemented = set(_README_S2_IMPLEMENTED.findall(readme))
        implemented = {
            milestone_id
            for milestone_id, status in statuses.items()
            if milestone_id.startswith("S2-") and status == "Implemented"
        }
        self.assertNotEqual(mentioned_implemented, implemented)


class ConventionalCommitScopeTests(unittest.TestCase):
    """Keep Conventional Commit allowlists aligned, including Dependabot `deps`."""

    ALLOWED_SCOPES = (
        "audit",
        "baseline",
        "amd",
        "ai-stack",
        "rocm",
        "npu",
        "acceleration",
        "comfyui",
        "config",
        "architecture",
        "agents",
        "workflows",
        "vscode",
        "release",
        "deps",
        "stage",
        "stage1",
        "stage2",
        "stage3",
        "stage4",
        "stage5",
        "tier",
        "tier1",
        "tier2",
    )

    def test_validate_pr_title_accepts_dependabot_deps_scope(self) -> None:
        result = subprocess.run(
            [
                "bash",
                str(ROOT / "scripts/validate-pr-title.sh"),
                "chore(deps): bump setuptools from 80.9.0 to 83.0.0 in /configs/ai-runtime",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Conventional Commit compliant", result.stdout)

    def test_validate_commit_subject_accepts_dependabot_deps_scope(self) -> None:
        result = subprocess.run(
            [
                "bash",
                str(ROOT / "scripts/validate-commit-subject.sh"),
                "chore(deps): bump pillow from 11.2.1 to 12.3.0 in /configs/ai-runtime",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Conventional Commit compliant", result.stdout)

    def test_validate_pr_title_accepts_agents_scope(self) -> None:
        result = subprocess.run(
            [
                "bash",
                str(ROOT / "scripts/validate-pr-title.sh"),
                "chore(agents): Define hybrid orchestration boundary",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Conventional Commit compliant", result.stdout)

    def test_validate_commit_subject_accepts_agents_scope(self) -> None:
        result = subprocess.run(
            [
                "bash",
                str(ROOT / "scripts/validate-commit-subject.sh"),
                "chore(agents): Define Cursor hybrid orchestration boundary",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Conventional Commit compliant", result.stdout)

    def test_validate_pr_title_rejects_unknown_scope(self) -> None:
        result = subprocess.run(
            [
                "bash",
                str(ROOT / "scripts/validate-pr-title.sh"),
                "chore(unknown): Bump a package",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("Allowed scopes:", result.stderr)
        self.assertIn("deps", result.stderr)

    def test_policy_and_validators_list_the_same_scopes(self) -> None:
        pr_title = (ROOT / "scripts/validate-pr-title.sh").read_text(encoding="utf-8")
        commit_subject = (ROOT / "scripts/validate-commit-subject.sh").read_text(
            encoding="utf-8"
        )
        workflow = (ROOT / ".github/workflows/pr-title-lint.yml").read_text(
            encoding="utf-8"
        )
        agents = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
        contributing = (ROOT / "CONTRIBUTING.md").read_text(encoding="utf-8")
        template = (ROOT / ".github/PULL_REQUEST_TEMPLATE.md").read_text(
            encoding="utf-8"
        )
        codex = (ROOT / ".github/instructions/codex.instructions.md").read_text(
            encoding="utf-8"
        )

        pr_scopes = re.search(r"allowed_scopes='([^']+)'", pr_title)
        commit_scopes = re.search(r"allowed_scopes='([^']+)'", commit_subject)
        self.assertIsNotNone(pr_scopes)
        self.assertIsNotNone(commit_scopes)
        self.assertEqual(tuple(pr_scopes.group(1).split("|")), self.ALLOWED_SCOPES)
        self.assertEqual(tuple(commit_scopes.group(1).split("|")), self.ALLOWED_SCOPES)

        self.assertIn("[`CONTRIBUTING.md`](CONTRIBUTING.md)", agents)
        self.assertIn("authoritative for allowed types", agents)
        self.assertIn("CONTRIBUTING.md", codex)

        for scope in self.ALLOWED_SCOPES:
            with self.subTest(scope=scope):
                self.assertIn(f"`{scope}`", contributing)
                self.assertRegex(workflow, rf"(?m)^\s+{re.escape(scope)}$")
                self.assertIn(scope, template)


if __name__ == "__main__":
    unittest.main()
