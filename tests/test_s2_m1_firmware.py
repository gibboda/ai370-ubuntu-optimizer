#!/usr/bin/env python3
"""S2-M1 firmware policy consumes the Stage 1 system profile."""

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
BIOS_SCRIPT = ROOT / "scripts/20-check-bios.sh"
sys.path.insert(0, str(ROOT / "scripts/lib"))
import firmware_policy  # noqa: E402


def load_reference_profile() -> dict:
    return json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))


class FirmwarePolicyTests(unittest.TestCase):
    def test_ai370_policy_comes_from_classified_platform_not_cli_profile(self) -> None:
        profile = load_reference_profile()
        self.assertEqual(firmware_policy.classified_platform_id(profile), "ai370")
        self.assertEqual(firmware_policy.expected_bios_version("ai370"), "2.01")
        self.assertEqual(firmware_policy.expected_bios_version("generic-ryzen-ai"), "")
        report = firmware_policy.build_firmware_baseline(
            profile,
            selected_profile="generic-ryzen-ai",
            timestamp="2026-01-01T00:00:00Z",
            fwupd_devices_present=False,
        )
        self.assertEqual(report["profile"], "generic-ryzen-ai")
        self.assertEqual(report["classified_platform_id"], "ai370")
        self.assertEqual(report["bios_expected"], "2.01")
        self.assertEqual(report["bios_version"], "2.00")
        self.assertEqual(report["bios_acceptable"], "false")
        self.assertEqual(report["consumed_profile"]["schema"]["version"], 3)
        self.assertEqual(
            report["consumed_profile"]["fingerprint"]["value"],
            profile["fingerprint"]["value"],
        )

    def test_generic_classified_platform_has_no_bios_target(self) -> None:
        profile = load_reference_profile()
        profile["classification"]["platform_id"] = "generic-ryzen-ai"
        report = firmware_policy.build_firmware_baseline(
            profile,
            selected_profile="ai370",
            timestamp="2026-01-01T00:00:00Z",
            fwupd_devices_present=False,
        )
        self.assertEqual(report["classified_platform_id"], "generic-ryzen-ai")
        self.assertEqual(report["bios_expected"], "")
        self.assertEqual(report["bios_acceptable"], "unknown")

    def test_matching_bios_is_acceptable(self) -> None:
        self.assertEqual(firmware_policy.bios_acceptable("2.01", "2.01"), "true")
        self.assertEqual(firmware_policy.bios_acceptable("MB 2.01", "2.01"), "true")
        self.assertEqual(firmware_policy.bios_acceptable("2.00", "2.01"), "false")
        self.assertEqual(firmware_policy.bios_acceptable(None, "2.01"), "unknown")
        self.assertEqual(firmware_policy.bios_acceptable("2.01", ""), "unknown")

    def test_missing_profile_raises(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            missing = Path(directory) / "s1-m5-system-profile.json"
            with self.assertRaises(FileNotFoundError):
                firmware_policy.load_system_profile(missing)


class FirmwareScriptTests(unittest.TestCase):
    def test_script_requires_stage1_profile(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            completed = subprocess.run(
                ["bash", str(BIOS_SCRIPT), "ai370", "safe", "runtime"],
                check=False,
                capture_output=True,
                text=True,
                env={**os.environ, "LATEST_DIR": directory},
            )
        self.assertEqual(completed.returncode, 2)
        self.assertIn("s1-m5-system-profile.json", completed.stderr + completed.stdout)

    def test_script_records_classified_policy_and_fingerprint(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            (latest / "s1-m5-system-profile.json").write_text(
                PROFILE_FIXTURE.read_text(encoding="utf-8"),
                encoding="utf-8",
            )
            env = dict(os.environ)
            env["LATEST_DIR"] = str(latest)
            completed = subprocess.run(
                ["bash", str(BIOS_SCRIPT), "generic-ryzen-ai", "safe", "runtime"],
                check=False,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
            report = json.loads((latest / "tier1-firmware.json").read_text(encoding="utf-8"))
            validation = json.loads(
                (latest / "tier1-firmware-validation.json").read_text(encoding="utf-8")
            )
        self.assertEqual(report["profile"], "generic-ryzen-ai")
        self.assertEqual(report["classified_platform_id"], "ai370")
        self.assertEqual(report["bios_expected"], "2.01")
        self.assertEqual(report["consumed_profile"]["schema"]["version"], 3)
        self.assertEqual(
            report["consumed_profile"]["fingerprint"]["value"],
            load_reference_profile()["fingerprint"]["value"],
        )
        self.assertEqual(
            validation["consumed_profile"]["fingerprint"]["value"],
            report["consumed_profile"]["fingerprint"]["value"],
        )


if __name__ == "__main__":
    unittest.main()
