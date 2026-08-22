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
import system_profile  # noqa: E402


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
            canonical = json.loads(
                (latest / "s2-m1-firmware-validation.json").read_text(encoding="utf-8")
            )
            facts_md = (latest / "tier1-firmware.md").read_text(encoding="utf-8")
            policy_md = (latest / "tier1-firmware-validation.md").read_text(
                encoding="utf-8"
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
        system_profile.validate_document(
            canonical, firmware_policy.S2_M1_SCHEMA, "S2-M1"
        )
        self.assertEqual(canonical["milestone"], "S2-M1")
        self.assertNotIn("bios_expected", canonical["facts"]["bios"])
        self.assertNotIn("bios_version", canonical["policy"])
        self.assertEqual(canonical["policy"]["bios_expected"], "2.01")
        self.assertEqual(canonical["policy"]["bios_acceptable"], "false")
        self.assertEqual(canonical["facts"]["bios"]["version"], "2.00")
        self.assertEqual(canonical["facts"]["bios"]["identity_source"], "s1-m5-system-profile")
        self.assertEqual(
            canonical["consumed_profile"]["fingerprint"]["value"],
            report["consumed_profile"]["fingerprint"]["value"],
        )
        self.assertIn("Firmware Facts", facts_md)
        self.assertNotIn("Target BIOS", facts_md)
        self.assertIn("Firmware Policy", policy_md)
        self.assertIn("acceptable:", policy_md)

    def test_failed_fwupd_get_devices_is_not_visible(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            latest = Path(directory)
            bindir = latest / "bin"
            bindir.mkdir()
            stub = bindir / "fwupdmgr"
            stub.write_text(
                "#!/bin/bash\n"
                "if [[ \"$1\" == \"--version\" ]]; then echo 'fwupd 1.9'; exit 0; fi\n"
                "if [[ \"$1\" == \"get-devices\" ]]; then\n"
                "  echo 'Failed to connect to daemon' >&2\n"
                "  exit 1\n"
                "fi\n"
                "exit 2\n",
                encoding="utf-8",
            )
            stub.chmod(0o755)
            (latest / "s1-m5-system-profile.json").write_text(
                PROFILE_FIXTURE.read_text(encoding="utf-8"),
                encoding="utf-8",
            )
            env = dict(os.environ)
            env["LATEST_DIR"] = str(latest)
            env["PATH"] = f"{bindir}:{env['PATH']}"
            completed = subprocess.run(
                ["bash", str(BIOS_SCRIPT), "generic-ryzen-ai", "safe", "runtime"],
                check=False,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
            canonical = json.loads(
                (latest / "s2-m1-firmware-validation.json").read_text(encoding="utf-8")
            )
        self.assertEqual(canonical["facts"]["fwupd"]["status"], "available")
        self.assertFalse(canonical["facts"]["fwupd"]["devices_visible"])
        self.assertTrue(
            any("get-devices failed" in warning for warning in canonical["warnings"]),
            canonical["warnings"],
        )


class FirmwareCanonicalPublisherTests(unittest.TestCase):
    def test_facts_exclude_policy_fields(self) -> None:
        profile = load_reference_profile()
        facts = firmware_policy.firmware_facts(profile)
        self.assertNotIn("bios_expected", facts)
        self.assertNotIn("bios_acceptable", facts)
        policy = firmware_policy.firmware_policy_verdict(profile, facts)
        self.assertNotIn("bios_version", policy)
        self.assertEqual(policy["bios_expected"], "2.01")
        self.assertEqual(policy["bios_acceptable"], "false")

    def test_publisher_requires_stage1_profile(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "s2-m1-firmware-validation.json"
            completed = subprocess.run(
                [
                    "python3",
                    str(ROOT / "scripts/s2-m1-publish-firmware-validation.py"),
                    "--profile",
                    str(Path(directory) / "missing.json"),
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
        valid = firmware_policy.build_s2_m1_firmware_validation(profile)
        invalid = json.loads(json.dumps(valid))
        invalid["stage"] = 1
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "s2-m1-firmware-validation.json"
            system_profile.atomic_write_document(
                destination, valid, firmware_policy.S2_M1_SCHEMA, "S2-M1"
            )
            before = destination.read_bytes()
            with self.assertRaises(system_profile.ProfileValidationError):
                system_profile.atomic_write_document(
                    destination, invalid, firmware_policy.S2_M1_SCHEMA, "S2-M1"
                )
            self.assertEqual(destination.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
