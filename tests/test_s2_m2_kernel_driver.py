#!/usr/bin/env python3
"""S2-M2 kernel driver validation publisher: read-only, requires Stage 1 profile."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROFILE_FIXTURE = ROOT / "tests/fixtures/system-profile/v3/valid-reference.json"
KERNEL_SCRIPT = ROOT / "scripts/30-validate-kernel.sh"
sys.path.insert(0, str(ROOT / "scripts/lib"))
import kernel_validation  # noqa: E402
import system_profile  # noqa: E402


def load_reference_profile() -> dict:
    return json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))


class Stage2KernelDriverTests(unittest.TestCase):
    def test_script_requires_stage1_profile(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            completed = subprocess.run(
                ["bash", str(KERNEL_SCRIPT), "ai370", "safe", "runtime"],
                check=False,
                capture_output=True,
                text=True,
                env={**os.environ, "LATEST_DIR": directory},
            )
        self.assertEqual(completed.returncode, 2)
        self.assertIn("s1-m5-system-profile.json", completed.stderr + completed.stdout)

    def test_script_writes_canonical_and_compat_json(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            (latest / "s1-m5-system-profile.json").write_text(
                PROFILE_FIXTURE.read_text(encoding="utf-8"), encoding="utf-8"
            )
            completed = subprocess.run(
                ["bash", str(KERNEL_SCRIPT), "generic-ryzen-ai", "safe", "runtime"],
                check=False,
                capture_output=True,
                text=True,
                env={**os.environ, "LATEST_DIR": str(latest)},
            )
            self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
            canonical = json.loads(
                (latest / "s2-m2-kernel-driver-validation.json").read_text(encoding="utf-8")
            )
            compat = json.loads((latest / "tier1-kernel-plan.json").read_text(encoding="utf-8"))
            self.assertTrue((latest / "s2-m2-kernel-driver-validation.md").is_file())
        system_profile.validate_document(
            canonical, kernel_validation.S2_M2_SCHEMA, "S2-M2"
        )
        fixture = load_reference_profile()
        self.assertEqual(canonical["milestone"], "S2-M2")
        self.assertEqual(canonical["cli_profile"], "generic-ryzen-ai")
        self.assertEqual(canonical["classified_platform_id"], "ai370")
        self.assertIn(canonical["status"], {"PASS", "WARN"})
        self.assertEqual(
            canonical["consumed_profile"]["fingerprint"]["value"],
            fixture["fingerprint"]["value"],
        )
        self.assertEqual(compat["status"], canonical["status"])
        self.assertEqual(
            compat["canonical_artifact"],
            "reports/latest/s2-m2-kernel-driver-validation.json",
        )
        self.assertEqual(compat["consumed_profile"]["fingerprint"]["value"], fixture["fingerprint"]["value"])

    def test_publisher_requires_stage1_profile(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            facts = Path(directory) / "facts.json"
            facts.write_text(
                json.dumps(
                    {
                        "kernel": "6.14.0",
                        "target_kernel": "6.11",
                        "kernel_ok": True,
                        "amdgpu_ok": True,
                        "amdxdna_seen": False,
                        "linux_firmware_state": "present",
                        "status": "PASS",
                        "os_description": "Ubuntu",
                        "os_version": "24.04",
                        "os_codename": "noble",
                        "recommendations": [],
                    }
                ),
                encoding="utf-8",
            )
            output = Path(directory) / "s2-m2-kernel-driver-validation.json"
            completed = subprocess.run(
                [
                    "python3",
                    str(ROOT / "scripts/s2-m2-publish-kernel-driver-validation.py"),
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

    def test_invalid_report_does_not_replace_last_valid_publication(self) -> None:
        profile = load_reference_profile()
        valid = kernel_validation.build_s2_m2_kernel_driver_validation(
            profile,
            facts={
                "kernel": "6.14.0",
                "target_kernel": "6.11",
                "kernel_ok": True,
                "amdgpu_ok": True,
                "amdxdna_seen": False,
                "linux_firmware_state": "present",
                "status": "PASS",
                "os_description": "Ubuntu",
                "os_version": "24.04",
                "os_codename": "noble",
                "recommendations": [],
            },
        )
        invalid = json.loads(json.dumps(valid))
        invalid["stage"] = 1
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "s2-m2-kernel-driver-validation.json"
            system_profile.atomic_write_document(
                destination, valid, kernel_validation.S2_M2_SCHEMA, "S2-M2"
            )
            before = destination.read_bytes()
            with self.assertRaises(system_profile.ProfileValidationError):
                system_profile.atomic_write_document(
                    destination, invalid, kernel_validation.S2_M2_SCHEMA, "S2-M2"
                )
            self.assertEqual(destination.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
