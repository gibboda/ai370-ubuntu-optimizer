#!/usr/bin/env python3
"""S2-M6 optimization apply publisher: --approve is required."""

from __future__ import annotations

import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROFILE_FIXTURE = ROOT / "tests/fixtures/system-profile/v3/valid-reference.json"
TUNING_SCRIPT = ROOT / "scripts/40-platform-tuning.sh"

sys.path.insert(0, str(ROOT / "scripts/lib"))
import optimization_plan  # noqa: E402
import system_profile  # noqa: E402


class Stage2OptimizationApplyTests(unittest.TestCase):
    def seed_profile(self, latest: Path) -> None:
        (latest / "s1-m5-system-profile.json").write_text(
            PROFILE_FIXTURE.read_text(encoding="utf-8"), encoding="utf-8"
        )

    def test_apply_without_approve_exits_and_does_not_mutate(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            self.seed_profile(latest)
            fake_bin = latest / "bin"
            fake_bin.mkdir()
            marker = latest / "powerprofilesctl.called"
            stub = fake_bin / "powerprofilesctl"
            stub.write_text("#!/bin/sh\necho called > \"$MARKER\"\n", encoding="utf-8")
            stub.chmod(stub.stat().st_mode | stat.S_IEXEC)
            env = {
                **os.environ,
                "LATEST_DIR": str(latest),
                "PATH": f"{fake_bin}:{os.environ.get('PATH', '')}",
                "MARKER": str(marker),
                "AI370_APPLY_TUNING": "true",
            }
            completed = subprocess.run(
                [
                    "bash",
                    str(TUNING_SCRIPT),
                    "generic-ryzen-ai",
                    "safe",
                    "runtime",
                    "apply",
                ],
                check=False,
                capture_output=True,
                text=True,
                env=env,
            )
            combined = completed.stderr + completed.stdout
            self.assertEqual(completed.returncode, 2, combined)
            self.assertIn("--approve", combined)
            self.assertFalse(marker.exists())
            self.assertFalse((latest / "s2-m6-optimization-application.json").exists())

    def test_apply_tuning_env_without_approve_stays_plan_only(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            self.seed_profile(latest)
            completed = subprocess.run(
                ["bash", str(TUNING_SCRIPT), "generic-ryzen-ai", "safe", "runtime"],
                check=False,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "LATEST_DIR": str(latest),
                    "AI370_APPLY_TUNING": "true",
                },
            )
            self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
            self.assertTrue((latest / "s2-m5-optimization-plan.json").is_file())
            self.assertFalse((latest / "s2-m6-optimization-application.json").exists())
            compat = json.loads((latest / "tier1-platform-tuning.json").read_text(encoding="utf-8"))
            self.assertNotIn("runtime_apply", compat)

    def test_approve_dry_run_records_apply_without_running_commands(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            self.seed_profile(latest)
            fake_bin = latest / "bin"
            fake_bin.mkdir()
            marker = latest / "powerprofilesctl.called"
            stub = fake_bin / "powerprofilesctl"
            stub.write_text("#!/bin/sh\necho called > \"$MARKER\"\n", encoding="utf-8")
            stub.chmod(stub.stat().st_mode | stat.S_IEXEC)
            completed = subprocess.run(
                [
                    "bash",
                    str(TUNING_SCRIPT),
                    "generic-ryzen-ai",
                    "safe",
                    "runtime",
                    "apply",
                    "--approve",
                ],
                check=False,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "LATEST_DIR": str(latest),
                    "PATH": f"{fake_bin}:{os.environ.get('PATH', '')}",
                    "MARKER": str(marker),
                    "DRY_RUN": "true",
                },
            )
            self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
            self.assertFalse(marker.exists())
            report_path = latest / "s2-m6-optimization-application.json"
            self.assertTrue(report_path.is_file())
            report = json.loads(report_path.read_text(encoding="utf-8"))
            system_profile.validate_document(
                report, optimization_plan.S2_M6_SCHEMA, "S2-M6"
            )
            self.assertEqual(report["milestone"], "S2-M6")
            self.assertTrue(report["approved"])
            self.assertTrue(report["dry_run"])
            self.assertFalse(report["applied"])
            self.assertEqual(report["backup"]["status"], "not-implemented")
            compat = json.loads((latest / "tier1-platform-tuning.json").read_text(encoding="utf-8"))
            self.assertTrue(compat["runtime_apply"]["requested"])
            self.assertTrue(compat["runtime_apply"]["dry_run"])
            self.assertFalse(compat["runtime_apply"]["applied"])

    def test_approve_without_dry_run_runs_generated_commands(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            self.seed_profile(latest)
            fake_bin = latest / "bin"
            fake_bin.mkdir()
            marker = latest / "powerprofilesctl.called"
            stub = fake_bin / "powerprofilesctl"
            stub.write_text("#!/bin/sh\necho called > \"$MARKER\"\n", encoding="utf-8")
            stub.chmod(stub.stat().st_mode | stat.S_IEXEC)
            completed = subprocess.run(
                [
                    "bash",
                    str(TUNING_SCRIPT),
                    "generic-ryzen-ai",
                    "safe",
                    "runtime",
                    "apply",
                    "--approve",
                ],
                check=False,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "LATEST_DIR": str(latest),
                    "PATH": f"{fake_bin}:{os.environ.get('PATH', '')}",
                    "MARKER": str(marker),
                    "DRY_RUN": "false",
                },
            )
            self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
            self.assertTrue(marker.is_file())
            report = json.loads(
                (latest / "s2-m6-optimization-application.json").read_text(encoding="utf-8")
            )
            self.assertTrue(report["approved"])
            self.assertFalse(report["dry_run"])
            self.assertTrue(report["applied"])
            self.assertTrue(report["runtime_apply"]["applied"])

    def test_orchestrator_apply_without_approve_is_rejected(self) -> None:
        completed = subprocess.run(
            [str(ROOT / "ai370-optimize.sh"), "stage2-optimize-apply"],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("--approve", completed.stderr + completed.stdout)


if __name__ == "__main__":
    unittest.main()
