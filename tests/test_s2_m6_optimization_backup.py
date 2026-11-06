#!/usr/bin/env python3
"""S2-M6 runtime backup and rollback (portable, stubbed powerprofilesctl)."""

from __future__ import annotations

import contextlib
import importlib.util
import json
import os
import pwd
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from collections.abc import Iterator
from pathlib import Path
from unittest import mock
ROOT = Path(__file__).resolve().parents[1]
PROFILE_FIXTURE = ROOT / "tests/fixtures/system-profile/v3/valid-reference.json"
TUNING_SCRIPT = ROOT / "scripts/40-platform-tuning.sh"
RESTORE_CLI = ROOT / "scripts/s2-m6-restore-runtime-backup.py"
BACKUP_BLOCK_CLI = ROOT / "scripts/s2-m6-backup-block.py"
MAIN_ERA_S2_M6 = ROOT / "tests/fixtures/s2-m6/v1-main-era-not-implemented.json"

sys.path.insert(0, str(ROOT / "scripts/lib"))
import optimization_backup  # noqa: E402
import optimization_plan  # noqa: E402
import system_profile  # noqa: E402


def _powerprofilesctl_stub(
    bindir: Path,
    *,
    set_performance_fails: bool = False,
    set_always_fails: bool = False,
    get_fails: bool = False,
) -> None:
    lines = [
        "#!/bin/sh",
        'case "$1" in',
    ]
    if get_fails:
        lines.append("  get) exit 1 ;;")
    else:
        lines.append('  get) cat "$STATE"; exit 0 ;;')
    lines.extend([
        "  list)",
        '    printf "%s\\n" "${PROFILES_LIST:-performance balanced power-saver}"; exit 0 ;;',
        "  set)",
        '    [ -n "${SET_LOG:-}" ] && echo "set $2" >> "$SET_LOG"',
    ])
    if set_always_fails:
        lines.append("    exit 1 ;;")
    elif set_performance_fails:
        lines.append('    if [ "$2" = "performance" ]; then exit 1; fi')
        lines.extend(['    echo "$2" > "$STATE"; exit 0 ;;'])
    else:
        lines.extend(['    echo "$2" > "$STATE"; exit 0 ;;'])
    lines.extend(["esac", "exit 1"])
    stub = bindir / "powerprofilesctl"
    stub.write_text("\n".join(lines) + "\n", encoding="utf-8")
    stub.chmod(stub.stat().st_mode | stat.S_IEXEC)


def _profile_document(platform_id: str) -> dict:
    profile = json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))
    classification = dict(profile.get("classification") or {})
    classification["platform_id"] = platform_id
    profile["classification"] = classification
    return profile


def _write_profile(latest: Path, platform_id: str) -> Path:
    path = latest / "s1-m5-system-profile.json"
    path.write_text(json.dumps(_profile_document(platform_id), indent=2) + "\n", encoding="utf-8")
    return path


def _write_unclassified_profile(latest: Path) -> Path:
    profile = json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))
    classification = dict(profile.get("classification") or {})
    classification["platform_id"] = None
    profile["classification"] = classification
    path = latest / "s1-m5-system-profile.json"
    path.write_text(json.dumps(profile, indent=2) + "\n", encoding="utf-8")
    return path


def _stub_env(bindir: Path, state: Path, *, set_log: Path | None = None) -> dict[str, str]:
    env = {
        **os.environ,
        "PATH": f"{bindir}:/bin:/usr/bin",
        "STATE": str(state),
    }
    if set_log is not None:
        env["SET_LOG"] = str(set_log)
    return env


def _seed_manifest(
    latest: Path,
    *,
    platform_id: str | None = "ai370",
    include_platform_id: bool = True,
    observed: str = "balanced",
    backup_id: str = "20260101T120000-test0001",
) -> Path:
    root = optimization_backup.backup_root(latest)
    directory = root / backup_id
    directory.mkdir(parents=True, exist_ok=True)
    manifest_path = directory / optimization_backup.MANIFEST_NAME
    manifest: dict = {
        "schema": {"name": "s2-m6-runtime-backup", "version": 1},
        "backup_id": backup_id,
        "items": [
            {
                "id": "power_profile",
                "observed": observed,
            }
        ],
    }
    if include_platform_id:
        manifest["platform_id"] = platform_id
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    optimization_backup.write_apply_backup_pointer(
        latest,
        {
            "manifest": f"reports/latest/s2-m6-runtime-backups/{backup_id}/manifest.json",
            "backup_id": backup_id,
            "manifest_path": manifest_path,
        },
    )
    return manifest_path


def _seed_s2_m6_application(latest: Path, profile_path: Path) -> Path:
    profile = json.loads(profile_path.read_text(encoding="utf-8"))
    application = optimization_plan.build_s2_m6_optimization_application(
        profile,
        plan=None,
        applied=True,
        dry_run=False,
        backup={"status": "captured", "rollback_available": True},
    )
    report_path = latest / "s2-m6-optimization-application.json"
    optimization_plan.publish_s2_m6_optimization_application(
        report_path, application, plan=None
    )
    return report_path


def _chattr_immutable(path: Path, *, immutable: bool) -> bool:
    flag = "+i" if immutable else "-i"
    try:
        completed = subprocess.run(
            ["chattr", flag, str(path)],
            check=False,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        return False
    return completed.returncode == 0


def _chown_tree(path: Path, uid: int, gid: int) -> None:
    """Give ``path`` and its children to ``uid``/``gid``.

    Linux rejects ``chown`` on an immutable inode even for root. Callers that
    already used ``chattr +i`` must not pass that tree here.
    """
    os.chown(path, uid, gid)
    for child in path.rglob("*"):
        os.chown(child, uid, gid)


def _run_restore_subprocess(
    argv: list[str],
    *,
    env: dict[str, str],
    latest: Path,
    drop_privileges: bool,
) -> subprocess.CompletedProcess[str]:
    """Run restore. Privilege drop is only the non-immutable root fallback.

    ``chown`` on a ``chattr +i`` report raises ``PermissionError`` before
    restore runs, so that strategy stays root and relies on the immutable
    inode. ``runuser`` is invoked by absolute path: ``shutil.which`` uses the
    parent PATH (where Ubuntu keeps it in ``/usr/sbin``), while ``env`` is the
    stub PATH ``bindir:/bin:/usr/bin``.
    """
    if drop_privileges:
        try:
            nobody = pwd.getpwnam("nobody")
        except KeyError as exc:
            raise unittest.SkipTest("root: nobody user unavailable for publish-failure tests") from exc
        runuser = shutil.which("runuser")
        if not runuser:
            raise unittest.SkipTest("root: runuser unavailable for publish-failure tests")
        _chown_tree(latest, nobody.pw_uid, nobody.pw_gid)
        latest.chmod(stat.S_IRUSR | stat.S_IXUSR)
        argv = [runuser, "-u", "nobody", "--", *argv]
    return subprocess.run(
        argv, check=False, capture_output=True, text=True, env=env
    )


@contextlib.contextmanager
def _block_s2_m6_report_publish(latest: Path, profile_path: Path) -> Iterator[str]:
    """Force a real publish OSError (not mocks).

    Yields the block mode. Non-root removes directory write permission
    (``readonly_dir``). Root ignores that mode. ``chattr`` marks the report
    immutable when the attribute sticks. ``nobody_runuser`` means ``chattr``
    was unavailable and the caller must drop to ``nobody`` instead. Those root
    strategies are alternatives: chowning an immutable report fails with
    ``EPERM``.
    """
    report_path = _seed_s2_m6_application(latest, profile_path)
    mode = "readonly_dir"
    if os.geteuid() == 0:
        if _chattr_immutable(report_path, immutable=True):
            mode = "chattr"
        else:
            mode = "nobody_runuser"
    else:
        latest.chmod(stat.S_IRUSR | stat.S_IXUSR | stat.S_IRGRP | stat.S_IXGRP)
    try:
        yield mode
    finally:
        if mode == "chattr":
            _chattr_immutable(report_path, immutable=False)
        elif mode == "readonly_dir":
            latest.chmod(stat.S_IRWXU)


def _assert_no_false_restore_success_claims(stderr: str, stdout: str) -> None:
    stderr_lower = stderr.lower()
    stdout_lower = stdout.lower()
    for text in (stderr, stdout):
        assert "rollback succeeded" not in text.lower(), text
    assert "restored" not in stderr_lower, stderr
    assert "[info] restored runtime backup" not in stdout_lower, stdout
    if stdout.strip():
        payload = json.loads(stdout)
        assert payload.get("restored") is not True, stdout
        tail = stdout[stdout.rfind("}") + 1 :]
        assert "restored" not in tail.lower(), stdout
    else:
        assert "restored" not in stdout_lower, stdout


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
                classified_platform_id="ai370",
                runner=lambda command, **kwargs: subprocess.run(
                    command, env={"PATH": ""}, **kwargs
                ),
            )
        self.assertEqual(block["status"], "failed")
        self.assertFalse(block["rollback_available"])
        self.assertFalse((latest / optimization_backup.APPLY_POINTER_NAME).exists())

    def test_failed_capture_clears_stale_apply_pointer(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            _seed_manifest(latest, platform_id="ai370", observed="balanced")
            pointer_path = latest / optimization_backup.APPLY_POINTER_NAME
            self.assertTrue(pointer_path.is_file())
            optimization_backup.capture_runtime_backup(
                latest,
                classified_platform_id="ai370",
                runner=lambda command, **kwargs: subprocess.run(
                    command, env={"PATH": ""}, **kwargs
                ),
            )
            self.assertFalse(pointer_path.exists())

    def test_capture_records_platform_id(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            profile_path = _write_profile(latest, "ai370")
            state = latest / "power.state"
            state.write_text("balanced\n", encoding="utf-8")
            bindir = latest / "bin"
            bindir.mkdir()
            _powerprofilesctl_stub(bindir)

            def runner(command: list[str], **kwargs):  # type: ignore[no-untyped-def]
                env = {**os.environ, **(kwargs.pop("env", None) or {}), "STATE": str(state)}
                env["PATH"] = f"{bindir}:{env.get('PATH', '')}"
                return subprocess.run(command, env=env, **kwargs)

            block = optimization_backup.capture_runtime_backup(
                latest, classified_platform_id="ai370", runner=runner
            )
            manifest = json.loads(block["manifest_path"].read_text(encoding="utf-8"))
            self.assertEqual(manifest["platform_id"], "ai370")
            completed = subprocess.run(
                [
                    "python3",
                    str(BACKUP_BLOCK_CLI),
                    "--output",
                    str(latest / "block.json"),
                    "capture",
                    "--latest-dir",
                    str(latest),
                    "--profile",
                    str(profile_path),
                ],
                check=True,
                capture_output=True,
                text=True,
                env={**os.environ, "PATH": f"{bindir}:{os.environ.get('PATH', '')}", "STATE": str(state)},
            )
            self.assertEqual(completed.returncode, 0)
            json.loads((latest / "block.json").read_text(encoding="utf-8"))
            manifest_path = optimization_backup.manifest_from_apply_pointer(latest)
            assert manifest_path is not None
            manifest2 = json.loads(manifest_path.read_text(encoding="utf-8"))
            self.assertEqual(manifest2["platform_id"], "ai370")

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

            block = optimization_backup.capture_runtime_backup(
                latest, classified_platform_id="ai370", runner=runner
            )
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
            block,
            apply_succeeded=False,
            restore_exit_code=1,
            restore_result={"errors": ["failed to restore power_profile: powerprofilesctl not available"]},
        )
        self.assertEqual(updated["status"], "rollback_failed")
        self.assertFalse(updated["rollback_available"])
        self.assertIn("powerprofilesctl", updated["restore_errors"][0])

    def test_finalize_loads_restore_result_with_trailing_info(self) -> None:
        """Apply-time capture must still parse JSON if a legacy INFO trailed stdout."""
        finalize = ROOT / "scripts/s2-m6-finalize-apply-backup.py"
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            backup_json = latest / "backup.json"
            backup_json.write_text(
                json.dumps(
                    {
                        "status": "captured",
                        "rollback_available": True,
                        "manifest": "reports/latest/x/manifest.json",
                        "items": ["power_profile"],
                    },
                    indent=2,
                )
                + "\n",
                encoding="utf-8",
            )
            restore_result = latest / "restore.json"
            restore_error = "failed to restore power_profile: powerprofilesctl not available"
            restore_result.write_text(
                json.dumps(
                    {
                        "restored": False,
                        "dry_run": False,
                        "restored_items": [],
                        "errors": [restore_error],
                    },
                    indent=2,
                )
                + "\n[INFO] Restored runtime backup from /tmp/manifest.json\n",
                encoding="utf-8",
            )
            completed = subprocess.run(
                [
                    "python3",
                    str(finalize),
                    "--backup-json",
                    str(backup_json),
                    "--apply-succeeded",
                    "false",
                    "--restore-exit-code",
                    "1",
                    "--restore-result-json",
                    str(restore_result),
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
            updated = json.loads(backup_json.read_text(encoding="utf-8"))
            self.assertEqual(updated["status"], "rollback_failed")
            self.assertEqual(updated["restore_errors"], [restore_error])

    def test_restore_success_keeps_info_off_stdout(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            profile_path = _write_profile(latest, "ai370")
            state = latest / "power.state"
            state.write_text("performance\n", encoding="utf-8")
            bindir = latest / "bin"
            bindir.mkdir()
            _powerprofilesctl_stub(bindir)
            _seed_manifest(latest, platform_id="ai370", observed="balanced")
            completed = subprocess.run(
                [
                    "python3",
                    str(RESTORE_CLI),
                    "--latest-dir",
                    str(latest),
                    "--profile",
                    str(profile_path),
                    "--no-publish",
                    "true",
                ],
                check=False,
                capture_output=True,
                text=True,
                env=_stub_env(bindir, state),
            )
            self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
            payload = json.loads(completed.stdout)
            self.assertTrue(payload.get("restored"))
            self.assertIn("[INFO] Restored runtime backup", completed.stderr)
            self.assertNotIn("[INFO]", completed.stdout)

    def test_merge_skipped_apply_note_when_backup_capture_failed(self) -> None:
        block = {
            "status": "failed",
            "rollback_available": False,
            "note": "Backup unavailable: powerprofilesctl missing or power profile state unreadable.",
        }
        updated = optimization_backup.merge_backup_after_apply(
            block,
            apply_succeeded=True,
            restore_exit_code=None,
            runtime_apply_skipped=True,
        )
        self.assertEqual(updated["status"], "failed")
        self.assertIn("skipped", updated["note"].lower())
        self.assertNotIn("Apply completed", updated["note"])

    def test_merge_keeps_failed_backup_on_successful_apply(self) -> None:
        block = {
            "status": "failed",
            "rollback_available": False,
            "note": "Backup unavailable: powerprofilesctl missing or power profile state unreadable.",
        }
        updated = optimization_backup.merge_backup_after_apply(
            block,
            apply_succeeded=True,
            restore_exit_code=None,
        )
        self.assertEqual(updated["status"], "failed")
        self.assertFalse(updated["rollback_available"])

    def test_applied_run_warns_when_backup_capture_failed(self) -> None:
        profile = json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))
        application = optimization_plan.build_s2_m6_optimization_application(
            profile,
            plan=None,
            applied=True,
            dry_run=False,
            backup={"status": "failed", "rollback_available": False},
        )
        self.assertEqual(application["backup"]["status"], "failed")
        self.assertEqual(application["status"], "WARN")
        self.assertTrue(
            any("backup" in warning.lower() for warning in application["warnings"]),
            application["warnings"],
        )

    def test_apply_time_restore_no_publish_leaves_s2_m6_unchanged(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            profile_path = _write_profile(latest, "ai370")
            profile = json.loads(profile_path.read_text(encoding="utf-8"))
            application = optimization_plan.build_s2_m6_optimization_application(
                profile,
                plan=None,
                applied=True,
                dry_run=False,
                backup={"status": "captured", "rollback_available": True},
            )
            report_path = latest / "s2-m6-optimization-application.json"
            optimization_plan.publish_s2_m6_optimization_application(
                report_path, application, plan=None
            )
            before = report_path.read_text(encoding="utf-8")
            state = latest / "power.state"
            state.write_text("performance\n", encoding="utf-8")
            set_log = latest / "set.log"
            bindir = latest / "bin"
            bindir.mkdir()
            _powerprofilesctl_stub(bindir)
            _seed_manifest(latest, platform_id="ai370", observed="balanced")
            completed = subprocess.run(
                [
                    "python3",
                    str(RESTORE_CLI),
                    "--latest-dir",
                    str(latest),
                    "--profile",
                    str(profile_path),
                    "--no-publish",
                    "true",
                ],
                check=False,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "PATH": f"{bindir}:/bin:/usr/bin",
                    "STATE": str(state),
                    "SET_LOG": str(set_log),
                },
            )
            self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
            self.assertEqual(report_path.read_text(encoding="utf-8"), before)
            self.assertNotIn("runtime_rollback", before)

    def test_restore_success_wording_when_publish_fails_on_disk(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            profile_path = _write_profile(latest, "ai370")
            state = latest / "power.state"
            state.write_text("performance\n", encoding="utf-8")
            bindir = latest / "bin"
            bindir.mkdir()
            _powerprofilesctl_stub(bindir)
            _seed_manifest(latest, platform_id="ai370", observed="balanced")
            with _block_s2_m6_report_publish(latest, profile_path) as block_mode:
                argv = [
                    "python3",
                    str(RESTORE_CLI),
                    "--latest-dir",
                    str(latest),
                    "--profile",
                    str(profile_path),
                ]
                completed = _run_restore_subprocess(
                    argv,
                    env=_stub_env(bindir, state),
                    latest=latest,
                    drop_privileges=block_mode == "nobody_runuser",
                )
            self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
            self.assertEqual(state.read_text(encoding="utf-8").strip(), "balanced")
            stderr = completed.stderr
            self.assertIn("restored runtime settings", stderr.lower())
            self.assertIn("failed to update", stderr.lower())
            self.assertIn("rollback succeeded", stderr.lower())

    def test_restore_publish_failure_warning_matches_outcome(self) -> None:
        cases: list[tuple[str, dict, int]] = [
            (
                "restore_set_fails",
                {
                    "platform_id": "ai370",
                    "stub_set_always_fails": True,
                    "extra_argv": [],
                },
                1,
            ),
            (
                "platform_mismatch",
                {
                    "manifest_platform_id": "ai370",
                    "profile_platform_id": "ai470",
                    "extra_argv": [],
                },
                2,
            ),
            (
                "dry_run",
                {
                    "platform_id": "ai370",
                    "extra_argv": ["--dry-run", "true"],
                },
                0,
            ),
        ]
        for case_name, options, expected_rc in cases:
            with self.subTest(case=case_name):
                with tempfile.TemporaryDirectory() as directory:
                    latest = Path(directory)
                    state = latest / "power.state"
                    state.write_text("performance\n", encoding="utf-8")
                    state_before = state.read_text(encoding="utf-8")
                    set_log = latest / "set.log"
                    bindir = latest / "bin"
                    bindir.mkdir()
                    if options.get("stub_set_always_fails"):
                        _powerprofilesctl_stub(bindir, set_always_fails=True)
                    else:
                        _powerprofilesctl_stub(bindir)
                    manifest_platform = options.get("manifest_platform_id", options.get("platform_id", "ai370"))
                    profile_platform = options.get("profile_platform_id", options.get("platform_id", "ai370"))
                    manifest_path = _seed_manifest(
                        latest, platform_id=manifest_platform, observed="balanced"
                    )
                    manifest_before = manifest_path.read_text(encoding="utf-8")
                    profile_path = _write_profile(latest, profile_platform)
                    argv = [
                        "python3",
                        str(RESTORE_CLI),
                        "--latest-dir",
                        str(latest),
                        "--profile",
                        str(profile_path),
                        *options.get("extra_argv", []),
                    ]
                    with _block_s2_m6_report_publish(latest, profile_path) as block_mode:
                        completed = _run_restore_subprocess(
                            argv,
                            env=_stub_env(bindir, state, set_log=set_log),
                            latest=latest,
                            drop_privileges=block_mode == "nobody_runuser",
                        )
                    self.assertEqual(
                        completed.returncode,
                        expected_rc,
                        completed.stderr + completed.stdout,
                    )
                    _assert_no_false_restore_success_claims(completed.stderr, completed.stdout)
                    self.assertIn("failed to update", completed.stderr.lower())
                    if case_name in ("platform_mismatch", "dry_run"):
                        self.assertEqual(state.read_text(encoding="utf-8"), state_before)
                        self.assertFalse(set_log.exists())
                        self.assertEqual(manifest_path.read_text(encoding="utf-8"), manifest_before)

    def test_restore_null_platform_round_trip(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            profile_path = _write_unclassified_profile(latest)
            state = latest / "power.state"
            state.write_text("balanced\n", encoding="utf-8")
            bindir = latest / "bin"
            bindir.mkdir()
            _powerprofilesctl_stub(bindir)
            block_json = latest / "block.json"
            completed = subprocess.run(
                [
                    "python3",
                    str(BACKUP_BLOCK_CLI),
                    "--output",
                    str(block_json),
                    "capture",
                    "--latest-dir",
                    str(latest),
                    "--profile",
                    str(profile_path),
                ],
                check=False,
                capture_output=True,
                text=True,
                env=_stub_env(bindir, state),
            )
            self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
            manifest_path = optimization_backup.manifest_from_apply_pointer(latest)
            assert manifest_path is not None
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            self.assertIn("platform_id", manifest)
            self.assertIsNone(manifest["platform_id"])
            state.write_text("performance\n", encoding="utf-8")
            restore = subprocess.run(
                [
                    "python3",
                    str(RESTORE_CLI),
                    "--latest-dir",
                    str(latest),
                    "--profile",
                    str(profile_path),
                ],
                check=False,
                capture_output=True,
                text=True,
                env=_stub_env(bindir, state),
            )
            self.assertEqual(restore.returncode, 0, restore.stderr + restore.stdout)
            self.assertEqual(state.read_text(encoding="utf-8").strip(), "balanced")

    def test_restore_null_manifest_refused_on_classified_host(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            state = latest / "power.state"
            state.write_text("performance\n", encoding="utf-8")
            set_log = latest / "set.log"
            bindir = latest / "bin"
            bindir.mkdir()
            _powerprofilesctl_stub(bindir)
            manifest_path = _seed_manifest(
                latest, platform_id=None, include_platform_id=True, observed="balanced"
            )
            manifest_before = manifest_path.read_text(encoding="utf-8")
            profile_path = _write_profile(latest, "ai370")
            completed = subprocess.run(
                [
                    "python3",
                    str(RESTORE_CLI),
                    "--latest-dir",
                    str(latest),
                    "--profile",
                    str(profile_path),
                ],
                check=False,
                capture_output=True,
                text=True,
                env=_stub_env(bindir, state, set_log=set_log),
            )
            combined = completed.stderr + completed.stdout
            self.assertEqual(completed.returncode, 2, combined)
            self.assertIn("ai370", combined)
            self.assertEqual(state.read_text(encoding="utf-8").strip(), "performance")
            self.assertEqual(manifest_path.read_text(encoding="utf-8"), manifest_before)
            self.assertFalse(set_log.exists())

    def test_restore_missing_platform_id_key_refused(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            state = latest / "power.state"
            state.write_text("performance\n", encoding="utf-8")
            set_log = latest / "set.log"
            bindir = latest / "bin"
            bindir.mkdir()
            _powerprofilesctl_stub(bindir)
            manifest_path = _seed_manifest(
                latest, include_platform_id=False, observed="balanced"
            )
            manifest_before = manifest_path.read_text(encoding="utf-8")
            profile_path = _write_profile(latest, "ai370")
            completed = subprocess.run(
                [
                    "python3",
                    str(RESTORE_CLI),
                    "--latest-dir",
                    str(latest),
                    "--profile",
                    str(profile_path),
                ],
                check=False,
                capture_output=True,
                text=True,
                env=_stub_env(bindir, state, set_log=set_log),
            )
            combined = completed.stderr + completed.stdout
            self.assertEqual(completed.returncode, 2, combined)
            self.assertIn("missing platform_id", combined.lower())
            self.assertEqual(state.read_text(encoding="utf-8").strip(), "performance")
            self.assertEqual(manifest_path.read_text(encoding="utf-8"), manifest_before)
            self.assertFalse(set_log.exists())

    def _apply_failure_with_rollback_env(self, latest: Path) -> dict[str, str]:
        state = latest / "power.state"
        state.write_text("balanced\n", encoding="utf-8")
        bindir = latest / "bin"
        bindir.mkdir()
        _powerprofilesctl_stub(bindir, set_performance_fails=True)
        (bindir / "cpupower").write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        (bindir / "cpupower").chmod(0o755)
        return {
            **os.environ,
            "LATEST_DIR": str(latest),
            "PATH": f"{bindir}:/bin:/usr/bin",
            "STATE": str(state),
            "DRY_RUN": "false",
        }

    def test_apply_failure_restore_no_publish_preserves_s2_m6_report(self) -> None:
        tuning = TUNING_SCRIPT.read_text(encoding="utf-8")
        self.assertIn(
            "--no-publish true",
            tuning,
            "40-platform-tuning.sh must pass --no-publish true during apply-time rollback",
        )
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            (latest / "s1-m5-system-profile.json").write_text(
                PROFILE_FIXTURE.read_text(encoding="utf-8"), encoding="utf-8"
            )
            profile = json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))
            prior = optimization_plan.build_s2_m6_optimization_application(
                profile,
                plan=None,
                applied=False,
                dry_run=False,
                backup={"status": "not-implemented", "rollback_available": False},
            )
            prior["notes"] = [
                "QA sentinel: prior S2-M6 report must survive apply-time rollback publish.",
            ]
            report_path = latest / "s2-m6-optimization-application.json"
            optimization_plan.publish_s2_m6_optimization_application(
                report_path, prior, plan=None
            )
            before = report_path.read_bytes()
            env = self._apply_failure_with_rollback_env(latest)
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
            self.assertEqual(completed.returncode, 1, completed.stderr + completed.stdout)
            self.assertEqual(report_path.read_bytes(), before)
            self.assertNotIn(b"runtime_rollback", report_path.read_bytes())
            self.assertIn(b"QA sentinel", report_path.read_bytes())

    def test_restore_script_exits_2_without_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            profile_path = _write_profile(latest, "ai370")
            completed = subprocess.run(
                [
                    "python3",
                    str(RESTORE_CLI),
                    "--latest-dir",
                    str(latest),
                    "--profile",
                    str(profile_path),
                ],
                check=False,
                capture_output=True,
                text=True,
            )
        payload = json.loads(completed.stdout)
        self.assertFalse(payload["restored"])
        self.assertEqual(completed.returncode, 2)
        self.assertIn("No S2-M6 runtime backup manifest", payload["errors"][0])

    def test_restore_fails_without_system_profile(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            state = latest / "power.state"
            state.write_text("balanced\n", encoding="utf-8")
            set_log = latest / "set.log"
            bindir = latest / "bin"
            bindir.mkdir()
            _powerprofilesctl_stub(bindir)
            _seed_manifest(latest, platform_id="ai370", observed="balanced")
            profile_path = latest / "s1-m5-system-profile.json"
            completed = subprocess.run(
                [
                    "python3",
                    str(RESTORE_CLI),
                    "--latest-dir",
                    str(latest),
                    "--profile",
                    str(profile_path),
                ],
                check=False,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "PATH": f"{bindir}:/bin:/usr/bin",
                    "STATE": str(state),
                    "SET_LOG": str(set_log),
                },
            )
            combined = completed.stderr + completed.stdout
            self.assertEqual(completed.returncode, 2, combined)
            payload = json.loads(completed.stdout)
            self.assertFalse(payload["restored"])
            self.assertIn("s1-m5-system-profile.json", payload["errors"][0])
            self.assertIn("s1-m5-system-profile.json", combined)
            self.assertFalse(set_log.exists())

    def test_restore_refuses_platform_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            state = latest / "power.state"
            state.write_text("performance\n", encoding="utf-8")
            set_log = latest / "set.log"
            bindir = latest / "bin"
            bindir.mkdir()
            _powerprofilesctl_stub(bindir)
            manifest_path = _seed_manifest(latest, platform_id="ai370", observed="balanced")
            manifest_before = manifest_path.read_text(encoding="utf-8")
            profile_path = _write_profile(latest, "ai470")
            completed = subprocess.run(
                [
                    "python3",
                    str(RESTORE_CLI),
                    "--latest-dir",
                    str(latest),
                    "--profile",
                    str(profile_path),
                ],
                check=False,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "PATH": f"{bindir}:/bin:/usr/bin",
                    "STATE": str(state),
                    "SET_LOG": str(set_log),
                },
            )
            combined = completed.stderr + completed.stdout
            self.assertEqual(completed.returncode, 2, combined)
            self.assertIn("ai370", combined)
            self.assertIn("ai470", combined)
            self.assertEqual(state.read_text(encoding="utf-8").strip(), "performance")
            self.assertEqual(manifest_path.read_text(encoding="utf-8"), manifest_before)
            self.assertFalse(set_log.exists())

    def test_restore_dry_run_reports_platform_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            state = latest / "power.state"
            state.write_text("performance\n", encoding="utf-8")
            set_log = latest / "set.log"
            bindir = latest / "bin"
            bindir.mkdir()
            _powerprofilesctl_stub(bindir)
            _seed_manifest(latest, platform_id="ai370", observed="balanced")
            profile_path = _write_profile(latest, "ai470")
            completed = subprocess.run(
                [
                    "python3",
                    str(RESTORE_CLI),
                    "--latest-dir",
                    str(latest),
                    "--profile",
                    str(profile_path),
                    "--dry-run",
                    "true",
                ],
                check=False,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "PATH": f"{bindir}:/bin:/usr/bin",
                    "STATE": str(state),
                    "SET_LOG": str(set_log),
                },
            )
            combined = completed.stderr + completed.stdout
            self.assertEqual(completed.returncode, 0, combined)
            payload = json.loads(completed.stdout)
            self.assertTrue(payload.get("platform_mismatch"))
            self.assertEqual(payload.get("manifest_platform_id"), "ai370")
            self.assertEqual(payload.get("profile_platform_id"), "ai470")
            self.assertIn("ai370", payload["errors"][0])
            self.assertIn("ai470", payload["errors"][0])
            self.assertEqual(state.read_text(encoding="utf-8").strip(), "performance")
            self.assertFalse(set_log.exists())

    def test_main_era_s2_m6_report_validates_against_schema(self) -> None:
        report = json.loads(MAIN_ERA_S2_M6.read_text(encoding="utf-8"))
        system_profile.validate_document(report, optimization_plan.S2_M6_SCHEMA, "S2-M6")

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

    def test_build_s2_m6_fail_when_apply_failed_and_rollback_failed(self) -> None:
        profile = json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))
        application = optimization_plan.build_s2_m6_optimization_application(
            profile,
            plan=None,
            applied=False,
            dry_run=False,
            backup={
                "status": "rollback_failed",
                "rollback_available": False,
                "restore_errors": ["failed to restore power_profile"],
            },
        )
        self.assertEqual(application["status"], "FAIL")

    def test_build_s2_m6_warn_when_apply_failed_and_backup_restored(self) -> None:
        profile = json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))
        application = optimization_plan.build_s2_m6_optimization_application(
            profile,
            plan=None,
            applied=False,
            dry_run=False,
            backup={
                "status": "restored",
                "rollback_available": True,
                "note": "Apply failed; rollback restored pre-apply backup.",
            },
        )
        self.assertEqual(application["status"], "WARN")
        self.assertTrue(
            any("pre-apply backup was restored" in w for w in application["warnings"]),
            application["warnings"],
        )

    def test_merge_manual_mismatch_preserves_backup_block(self) -> None:
        profile = json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))
        application = optimization_plan.build_s2_m6_optimization_application(
            profile,
            plan=None,
            applied=True,
            dry_run=False,
            backup={
                "status": "captured",
                "rollback_available": True,
                "note": "Recorded pre-apply power profile for rollback.",
            },
        )
        backup_before = dict(application["backup"])
        merged = optimization_plan.merge_manual_runtime_rollback(
            application,
            dry_run=False,
            result={
                "restored": False,
                "platform_mismatch": True,
                "errors": ["platform mismatch: manifest ai370 vs profile ai470"],
                "manifest": "/tmp/manifest.json",
            },
        )
        self.assertEqual(merged["backup"], backup_before)
        self.assertTrue(merged["runtime_rollback"]["errors"])
        self.assertEqual(merged["status"], "WARN")
        self.assertTrue(
            any("platform mismatch" in warning.lower() for warning in merged["warnings"]),
            merged["warnings"],
        )

    @unittest.skipUnless(os.geteuid() == 0, "requires root for chattr publish-failure block")
    def test_root_chattr_publish_block_does_not_chown_tree(self) -> None:
        with tempfile.TemporaryDirectory() as probe_directory:
            probe_path = Path(probe_directory) / "chattr-probe"
            probe_path.touch()
            if not _chattr_immutable(probe_path, immutable=True):
                self.skipTest("chattr +i unavailable on this filesystem")
            try:
                with tempfile.TemporaryDirectory() as directory:
                    latest = Path(directory)
                    profile_path = _write_profile(latest, "ai370")
                    with mock.patch(
                        "tests.test_s2_m6_optimization_backup._chown_tree"
                    ) as chown_mock:
                        with _block_s2_m6_report_publish(
                            latest, profile_path
                        ) as block_mode:
                            self.assertEqual(block_mode, "chattr")
                    chown_mock.assert_not_called()
            finally:
                self.assertTrue(_chattr_immutable(probe_path, immutable=False))

    @unittest.skipUnless(os.geteuid() == 0, "requires root for runuser privilege drop")
    def test_run_restore_subprocess_uses_runuser_from_default_path(self) -> None:
        runuser = shutil.which("runuser")
        if not runuser:
            self.skipTest("runuser not available")
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            argv = ["python3", "-c", "import sys; sys.exit(0)"]
            env = dict(os.environ)
            with mock.patch(
                "tests.test_s2_m6_optimization_backup.subprocess.run"
            ) as run_mock:
                run_mock.return_value = subprocess.CompletedProcess(argv, 0, "", "")
                _run_restore_subprocess(
                    argv, env=env, latest=latest, drop_privileges=True
                )
            cmd = run_mock.call_args[0][0]
            self.assertEqual(cmd[0], runuser)

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
            self.assertFalse(report["applied"])
            self.assertFalse(report["runtime_apply"]["applied"])
            self.assertEqual(report["status"], "WARN")
            self.assertIn("powerprofilesctl not available", report["warnings"])
            self.assertEqual(report["backup"]["status"], "failed")
            self.assertFalse(report["backup"]["rollback_available"])

    def test_restore_runtime_backup_reports_missing_powerprofilesctl(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            manifest_path = _seed_manifest(latest, platform_id="ai370", observed="balanced")
            result = optimization_backup.restore_runtime_backup(
                manifest_path,
                runner=lambda command, **kwargs: subprocess.run(
                    command, env={"PATH": ""}, **kwargs
                ),
            )
            self.assertFalse(result["restored"])
            self.assertEqual(len(result["errors"]), 1)
            self.assertIn("powerprofilesctl not available", result["errors"][0])

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
            self.assertIsNone(resolved)

    def test_latest_manifest_in_skips_failed_capture_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            root = optimization_backup.backup_root(latest)
            failed_dir = root / "20260104T120000-failed001"
            failed_dir.mkdir(parents=True)
            (failed_dir / optimization_backup.MANIFEST_NAME).write_text(
                json.dumps({"items": []}, indent=2) + "\n",
                encoding="utf-8",
            )
            captured_dir = root / "20260103T120000-captured01"
            captured_dir.mkdir(parents=True)
            (captured_dir / optimization_backup.MANIFEST_NAME).write_text(
                json.dumps(
                    {
                        "items": [{"id": "power_profile", "observed": "balanced"}],
                    },
                    indent=2,
                )
                + "\n",
                encoding="utf-8",
            )
            resolved = optimization_backup.latest_manifest_in(latest)
            self.assertEqual(resolved, captured_dir / optimization_backup.MANIFEST_NAME)

    def test_apply_skips_rollback_when_pre_apply_capture_failed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            (latest / "s1-m5-system-profile.json").write_text(
                PROFILE_FIXTURE.read_text(encoding="utf-8"), encoding="utf-8"
            )
            _seed_manifest(latest, platform_id="ai370", observed="balanced")
            state = latest / "power.state"
            state.write_text("performance\n", encoding="utf-8")
            set_log = latest / "set.log"
            bindir = latest / "bin"
            bindir.mkdir()
            _powerprofilesctl_stub(bindir, set_performance_fails=True, get_fails=True)
            (bindir / "cpupower").write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            (bindir / "cpupower").chmod(0o755)
            env = {
                **os.environ,
                "LATEST_DIR": str(latest),
                "PATH": f"{bindir}:/bin:/usr/bin",
                "STATE": str(state),
                "SET_LOG": str(set_log),
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
            self.assertEqual(completed.returncode, 1, completed.stderr + completed.stdout)
            report = json.loads(
                (latest / "s2-m6-optimization-application.json").read_text(encoding="utf-8")
            )
            self.assertEqual(report["backup"]["status"], "failed")
            self.assertEqual(report["status"], "FAIL")
            self.assertEqual(state.read_text(encoding="utf-8").strip(), "performance")
            if set_log.exists():
                self.assertNotIn(
                    "set balanced",
                    set_log.read_text(encoding="utf-8"),
                    "rollback must not restore from stale manifest",
                )
            self.assertTrue(
                any("rollback skipped" in warning.lower() for warning in report["warnings"]),
                report["warnings"],
            )

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
            self.assertFalse(report["applied"])
            self.assertFalse(report["runtime_apply"]["applied"])
            self.assertEqual(report["status"], "WARN")
            self.assertIn("power_profile: unsupported", report["warnings"])
            self.assertEqual(state.read_text(encoding="utf-8").strip(), "balanced")
            self.assertEqual(report["backup"]["status"], "captured")
            self.assertIn("skipped", report["backup"]["note"].lower())
            self.assertNotIn("Apply succeeded", report["backup"]["note"])

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
            self.assertEqual(completed.returncode, 1, completed.stderr + completed.stdout)
            report = json.loads(
                (latest / "s2-m6-optimization-application.json").read_text(encoding="utf-8")
            )
            system_profile.validate_document(report, optimization_plan.S2_M6_SCHEMA, "S2-M6")
            self.assertFalse(report["applied"])
            self.assertEqual(report["status"], "WARN")
            self.assertEqual(report["backup"]["status"], "restored")
            self.assertEqual(state.read_text(encoding="utf-8").strip(), "balanced")
            self.assertNotIn("runtime_rollback", report)

    def test_apply_rollback_failed_when_all_powerprofilesctl_set_fail(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            (latest / "s1-m5-system-profile.json").write_text(
                PROFILE_FIXTURE.read_text(encoding="utf-8"), encoding="utf-8"
            )
            state = latest / "power.state"
            state.write_text("balanced\n", encoding="utf-8")
            bindir = latest / "bin"
            bindir.mkdir()
            _powerprofilesctl_stub(bindir, set_always_fails=True)
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
            combined = completed.stderr + completed.stdout
            self.assertEqual(completed.returncode, 1, combined)
            report = json.loads(
                (latest / "s2-m6-optimization-application.json").read_text(encoding="utf-8")
            )
            system_profile.validate_document(report, optimization_plan.S2_M6_SCHEMA, "S2-M6")
            self.assertFalse(report["applied"])
            self.assertEqual(report["status"], "FAIL")
            self.assertEqual(report["backup"]["status"], "rollback_failed")
            self.assertFalse(report["backup"]["rollback_available"])
            self.assertTrue(report["backup"].get("restore_errors"))


if __name__ == "__main__":
    unittest.main()
