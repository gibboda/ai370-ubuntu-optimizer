#!/usr/bin/env python3
"""S2-M5/S2-M6 wrappers consume the Stage 1 system profile."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROFILE_FIXTURE = ROOT / "tests/fixtures/system-profile/v3/valid-reference.json"
TUNING_SCRIPT = ROOT / "scripts/40-platform-tuning.sh"


def load_reference_profile() -> dict:
    return json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))


class OptimizeScriptTests(unittest.TestCase):
    def test_script_requires_stage1_profile(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            completed = subprocess.run(
                ["bash", str(TUNING_SCRIPT), "ai370", "safe", "runtime"],
                check=False,
                capture_output=True,
                text=True,
                env={**os.environ, "LATEST_DIR": directory},
            )
        self.assertEqual(completed.returncode, 2)
        self.assertIn("s1-m5-system-profile.json", completed.stderr + completed.stdout)

    def test_script_records_classified_identity_and_fingerprint(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            (latest / "s1-m5-system-profile.json").write_text(
                PROFILE_FIXTURE.read_text(encoding="utf-8"),
                encoding="utf-8",
            )
            completed = subprocess.run(
                ["bash", str(TUNING_SCRIPT), "generic-ryzen-ai", "safe", "runtime"],
                check=False,
                capture_output=True,
                text=True,
                env={**os.environ, "LATEST_DIR": str(latest), "AI370_APPLY_TUNING": "false"},
            )
            self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
            report = json.loads((latest / "tier1-platform-tuning.json").read_text(encoding="utf-8"))
        fixture = load_reference_profile()
        self.assertEqual(report["profile"], "generic-ryzen-ai")
        self.assertEqual(report["classified_platform_id"], "ai370")
        self.assertEqual(report["cpu"]["model"], "AMD Ryzen AI 9 HX 370")
        self.assertEqual(report["cpu"]["identity_source"], "s1-m5-system-profile")
        self.assertEqual(report["memory"]["identity_source"], "s1-m5-system-profile")
        self.assertEqual(report["consumed_profile"]["schema"]["version"], 3)
        self.assertEqual(
            report["consumed_profile"]["fingerprint"]["value"],
            fixture["fingerprint"]["value"],
        )
        self.assertNotIn("runtime_apply", report)


if __name__ == "__main__":
    unittest.main()
