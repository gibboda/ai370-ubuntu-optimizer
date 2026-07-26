#!/usr/bin/env python3
"""Contract tests for repository implementation instructions."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class RepositoryInstructionsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.agent_instructions = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
        cls.copilot_instructions = (
            ROOT / ".github/copilot-instructions.md"
        ).read_text(encoding="utf-8")

    def test_copilot_instructions_exist(self) -> None:
        self.assertTrue((ROOT / ".github/copilot-instructions.md").is_file())

    def test_copilot_instructions_link_to_authoritative_documents(self) -> None:
        self.assertIn("[`../AGENTS.md`](../AGENTS.md)", self.copilot_instructions)
        self.assertIn(
            "[`../docs/ROADMAP.md`](../docs/ROADMAP.md)", self.copilot_instructions
        )
        self.assertIn(
            "[`../configs/schemas/system-profile.schema.json`](../configs/schemas/system-profile.schema.json)",
            self.copilot_instructions,
        )
        self.assertIn(
            "[`/configs/schemas/system-profile.schema.json`]"
            "(/configs/schemas/system-profile.schema.json)",
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


if __name__ == "__main__":
    unittest.main()
