#!/usr/bin/env python3
"""S2-M6 runtime backup and rollback (portable, stubbed powerprofilesctl)."""

from __future__ import annotations

import json
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
import optimization_backup  # noqa: E402
import optimization_plan  # noqa: E402
import system_profile  # noqa: E402


class OptimizationBackupTests(unittest.TestCase):
    def test_capture_and_restore_power_profile_with_stub(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            state = latest / "power.state"
            state.write_text("balanced\n", encoding="utf-8")
            bindir = latest / "bin"
            bindir.mkdir()
            stub = bindir / "powerprofilesctl"
            stub.write_text(
                "#!/bin/sh\n"
                'case "$1" in\n'
                '  get) cat "$STATE"; exit 0 ;;\n'
                '  set) echo "$2" > "$STATE"; exit 0 ;;\n'
                "esac\n"
                "exit 1\n",
                encoding="utf-8",
            )
            stub.chmod(stub.stat().st_mode | stat.S_IEXEC)

            def runner(command: list[str], **kwargs):  # type: ignore[no-untyped-def]
                import os

                env = {**os.environ, **(kwargs.pop("env", None) or {}), "STATE": str(state)}
                env["PATH"] = f"{bindir}:{env.get('PATH', '')}"
                return subprocess.run(command, env=env, **kwargs)

            block = optimization_backup.capture_runtime_backup(latest, runner=runner)
            self.assertEqual(block["status"], "captured")
            self.assertTrue(block["rollback_available"])
            state.write_text("performance\n", encoding="utf-8")
            result = optimization_backup.restore_runtime_backup(
                block["manifest_path"], runner=runner
            )
            self.assertTrue(result["restored"])
            self.assertEqual(state.read_text(encoding="utf-8").strip(), "balanced")

    def test_build_s2_m6_requires_backup_for_applied_run(self) -> None:
        profile = json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))
        application = optimization_plan.build_s2_m6_optimization_application(
            profile,
            plan=None,
            applied=True,
            dry_run=False,
            backup={"status": "failed", "rollback_available": False},
        )
        self.assertEqual(application["status"], "WARN")
        self.assertIn("backup", " ".join(application["warnings"]).lower())

    def test_apply_failure_triggers_rollback_stub(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            (latest / "s1-m5-system-profile.json").write_text(
                PROFILE_FIXTURE.read_text(encoding="utf-8"), encoding="utf-8"
            )
            state = latest / "power.state"
            state.write_text("balanced\n", encoding="utf-8")
            bindir = latest / "bin"
            bindir.mkdir()
            stub = bindir / "powerprofilesctl"
            stub.write_text(
                "#!/bin/sh\n"
                'case "$1" in\n'
                '  get) cat "$STATE"; exit 0 ;;\n'
                "  set)\n"
                '    if [ "$2" = "performance" ]; then exit 1; fi\n'
                '    echo "$2" > "$STATE"; exit 0 ;;\n'
                "esac\n"
                "exit 1\n",
                encoding="utf-8",
            )
            stub.chmod(stub.stat().st_mode | stat.S_IEXEC)
            env = {
                **dict(__import__("os").environ),
                "LATEST_DIR": str(latest),
                "PATH": f"{bindir}:{__import__('os').environ.get('PATH', '')}",
                "STATE": str(state),
                "DRY_RUN": "false",
            }
            completed = subprocess.run(
                [
                    "bash",
                    str(TUNING_SCRIPT),
                    "generic-ryzen-ai",
                    "aggressive",
                    "runtime",
                    "apply",
                    "--approve",
                ],
                check=False,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
            report = json.loads(
                (latest / "s2-m6-optimization-application.json").read_text(encoding="utf-8")
            )
            system_profile.validate_document(report, optimization_plan.S2_M6_SCHEMA, "S2-M6")
            self.assertFalse(report["applied"])
            self.assertEqual(report["backup"]["status"], "restored")
            self.assertEqual(state.read_text(encoding="utf-8").strip(), "balanced")


if __name__ == "__main__":
    unittest.main()
