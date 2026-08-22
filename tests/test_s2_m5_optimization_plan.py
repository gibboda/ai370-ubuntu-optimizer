#!/usr/bin/env python3
"""S2-M5 optimization plan publisher: plan-only, no mutation."""

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


def load_reference_profile() -> dict:
    return json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))


class Stage2OptimizationPlanTests(unittest.TestCase):
    def test_plan_only_does_not_run_mutating_commands(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            (latest / "s1-m5-system-profile.json").write_text(
                PROFILE_FIXTURE.read_text(encoding="utf-8"), encoding="utf-8"
            )
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
                ["bash", str(TUNING_SCRIPT), "generic-ryzen-ai", "safe", "runtime"],
                check=False,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
            self.assertFalse(marker.exists())
            plan_path = latest / "s2-m5-optimization-plan.json"
            self.assertTrue(plan_path.is_file())
            self.assertFalse((latest / "s2-m6-optimization-application.json").exists())
            plan = json.loads(plan_path.read_text(encoding="utf-8"))
            system_profile.validate_document(
                plan, optimization_plan.S2_M5_SCHEMA, "S2-M5"
            )
            self.assertEqual(plan["milestone"], "S2-M5")
            self.assertTrue(plan["plan_only"])
            self.assertFalse(plan["approved"])
            self.assertEqual(plan["classified_platform_id"], "ai370")
            fixture = load_reference_profile()
            self.assertEqual(
                plan["consumed_profile"]["fingerprint"]["value"],
                fixture["fingerprint"]["value"],
            )
            self.assertTrue(any(item["mutating"] for item in plan["proposed_actions"]))
            compat = json.loads((latest / "tier1-platform-tuning.json").read_text(encoding="utf-8"))
            self.assertNotIn("runtime_apply", compat)
            self.assertEqual(
                compat["canonical_artifact"],
                "reports/latest/s2-m5-optimization-plan.json",
            )

    def test_publisher_requires_stage1_profile(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "plan.json"
            facts = Path(directory) / "facts.json"
            facts.write_text(
                json.dumps(
                    {
                        "cpu_model": "x",
                        "target_power": "balanced",
                        "governor": "",
                        "cpu_source": "s1-m5-system-profile",
                        "mem_total": "32Gi",
                        "zram_active": "inactive",
                        "mem_source": "s1-m5-system-profile",
                    }
                ),
                encoding="utf-8",
            )
            completed = subprocess.run(
                [
                    "python3",
                    str(ROOT / "scripts/s2-m5-publish-optimization-plan.py"),
                    "--profile",
                    str(Path(directory) / "missing.json"),
                    "--facts",
                    str(facts),
                    "--output",
                    str(output),
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(completed.returncode, 2, completed.stderr + completed.stdout)
            self.assertFalse(output.exists())

    def test_invalid_plan_does_not_replace_last_valid_publication(self) -> None:
        profile = load_reference_profile()
        facts = {
            "cpu_model": "AMD Ryzen AI 9 HX 370",
            "target_power": "balanced",
            "governor": "schedutil",
            "cpu_source": "s1-m5-system-profile",
            "mem_total": "32Gi",
            "zram_active": "inactive",
            "mem_source": "s1-m5-system-profile",
        }
        valid = optimization_plan.build_s2_m5_optimization_plan(profile, facts=facts)
        invalid = json.loads(json.dumps(valid))
        invalid["stage"] = 1
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "s2-m5-optimization-plan.json"
            system_profile.atomic_write_document(
                destination, valid, optimization_plan.S2_M5_SCHEMA, "S2-M5"
            )
            before = destination.read_bytes()
            with self.assertRaises(system_profile.ProfileValidationError):
                system_profile.atomic_write_document(
                    destination, invalid, optimization_plan.S2_M5_SCHEMA, "S2-M5"
                )
            self.assertEqual(destination.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
