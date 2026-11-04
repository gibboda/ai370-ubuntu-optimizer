#!/usr/bin/env python3
"""S2-M6 runtime backup and rollback (portable, stubbed powerprofilesctl)."""

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
RESTORE_CLI = ROOT / "scripts/s2-m6-restore-runtime-backup.py"

sys.path.insert(0, str(ROOT / "scripts/lib"))
import optimization_backup  # noqa: E402
import optimization_plan  # noqa: E402
import system_profile  # noqa: E402


def _powerprofilesctl_stub(
    bindir: Path,
    *,
    set_performance_fails: bool = False,
) -> None:
    lines = [
        "#!/bin/sh",
        'case "$1" in',
        "  get) cat \"$STATE\"; exit 0 ;;",
        "  list)",
        '    printf "%s\\n" "${PROFILES_LIST:-performance balanced power-saver}"; exit 0 ;;',
        "  set)",
    ]
    if set_performance_fails:
        lines.append('    if [ "$2" = "performance" ]; then exit 1; fi')
    lines.extend(
        [
            '    echo "$2" > "$STATE"; exit 0 ;;',
            "esac",
            "exit 1",
        ]
    )
    stub = bindir / "powerprofilesctl"
    stub.write_text("\n".join(lines) + "\n", encoding="utf-8")
    stub.chmod(stub.stat().st_mode | stat.S_IEXEC)


class OptimizationBackupTests(unittest.TestCase):
    def test_read_power_profile_missing_binary(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            bindir = Path(directory) / "bin"
            bindir.mkdir()
            env = os.environ.copy()
            env["PATH"] = str(bindir)
            power = optimization_backup.read_power_profile(
                runner=lambda command, **kwargs: subprocess.run(
                    command, env=env, **kwargs
                )
            )
        self.assertFalse(power["available"])
        self.assertIn("not available", power["error"])

    def test_capture_without_powerprofilesctl_does_not_raise(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            block = optimization_backup.capture_runtime_backup(
                latest,
                runner=lambda command, **kwargs: subprocess.run(
                    command, env={"PATH": ""}, **kwargs
                ),
            )
        self.assertEqual(block["status"], "failed")
        self.assertFalse(block["rollback_available"])

    def test_capture_and_restore_power_profile_with_stub(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            state = latest / "power.state"
            state.write_text("balanced\n", encoding="utf-8")
            bindir = latest / "bin"
            bindir.mkdir()
            _powerprofilesctl_stub(bindir)

            def runner(command: list[str], **kwargs):  # type: ignore[no-untyped-def]
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

    def test_merge_backup_restore_failed_status(self) -> None:
        block = {
            "status": "captured",
            "rollback_available": True,
            "manifest": "reports/latest/x/manifest.json",
            "items": ["power_profile"],
        }
        updated = optimization_backup.merge_backup_after_apply(
            block, apply_succeeded=False, restore_exit_code=1
        )
        self.assertEqual(updated["status"], "rollback_failed")
        self.assertTrue(updated["rollback_available"])

    def test_restore_script_exits_2_without_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            completed = subprocess.run(
                [
                    "python3",
                    str(RESTORE_CLI),
                    "--latest-dir",
                    directory,
                ],
                check=False,
                capture_output=True,
                text=True,
            )
        self.assertEqual(completed.returncode, 2)

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

    def test_apply_without_powerprofilesctl_still_publishes_s2_m6(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            (latest / "s1-m5-system-profile.json").write_text(
                PROFILE_FIXTURE.read_text(encoding="utf-8"), encoding="utf-8"
            )
            env = {
                **os.environ,
                "LATEST_DIR": str(latest),
                "PATH": f"{latest / 'empty-bin'}:/usr/bin:/bin",
                "DRY_RUN": "false",
            }
            (latest / "empty-bin").mkdir()
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
                env=env,
            )
            combined = completed.stderr + completed.stdout
            self.assertEqual(completed.returncode, 0, combined)
            self.assertTrue((latest / "s2-m6-optimization-application.json").is_file(), combined)
            report = json.loads(
                (latest / "s2-m6-optimization-application.json").read_text(encoding="utf-8")
            )
            system_profile.validate_document(report, optimization_plan.S2_M6_SCHEMA, "S2-M6")
            if report["applied"]:
                self.assertIn(report["backup"]["status"], {"captured", "failed", "skipped"})

    def test_latest_manifest_in_skips_directory_without_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            root = optimization_backup.backup_root(latest)
            root.mkdir(parents=True)
            (root / "20260101T120000-abc12345").mkdir()
            (root / "20260102T120000-def67890").mkdir()
            manifest_dir = root / "20260103T120000-ghiabcde"
            manifest_dir.mkdir()
            (manifest_dir / "manifest.json").write_text("{}", encoding="utf-8")
            resolved = optimization_backup.latest_manifest_in(latest)
            self.assertEqual(resolved, manifest_dir / "manifest.json")

    def test_aggressive_apply_degrades_when_performance_profile_missing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            (latest / "s1-m5-system-profile.json").write_text(
                PROFILE_FIXTURE.read_text(encoding="utf-8"), encoding="utf-8"
            )
            state = latest / "power.state"
            state.write_text("balanced\n", encoding="utf-8")
            bindir = latest / "bin"
            bindir.mkdir()
            _powerprofilesctl_stub(bindir)
            (bindir / "cpupower").write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            (bindir / "cpupower").chmod(0o755)
            env = {
                **os.environ,
                "LATEST_DIR": str(latest),
                "PATH": f"{bindir}:/bin:/usr/bin",
                "STATE": str(state),
                "PROFILES_LIST": "balanced power-saver",
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
            self.assertTrue(report["applied"])
            self.assertEqual(report["status"], "WARN")
            self.assertIn("power_profile: unsupported", report["warnings"])
            self.assertEqual(state.read_text(encoding="utf-8").strip(), "balanced")
            self.assertEqual(report["backup"]["status"], "captured")

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
            _powerprofilesctl_stub(bindir, set_performance_fails=True)
            (bindir / "cpupower").write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            (bindir / "cpupower").chmod(0o755)
            env = {
                **os.environ,
                "LATEST_DIR": str(latest),
                "PATH": f"{bindir}:/bin:/usr/bin",
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
