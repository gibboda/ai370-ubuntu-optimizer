#!/usr/bin/env python3
"""S2-M3 GPU visibility publisher CLI, schema, and atomic-write tests."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/raw-probes/v1"
PROFILE_FIXTURE = ROOT / "tests/fixtures/system-profile/v3/valid-reference.json"
PUBLISH_CLI = ROOT / "scripts/s2-m3-publish-gpu-visibility.py"
SPEC = importlib.util.spec_from_file_location(
    "system_profile", ROOT / "scripts/lib/system_profile.py"
)
LADDER_SPEC = importlib.util.spec_from_file_location(
    "capability_ladder", ROOT / "scripts/lib/capability_ladder.py"
)
assert SPEC and SPEC.loader and LADDER_SPEC and LADDER_SPEC.loader
system_profile = importlib.util.module_from_spec(SPEC)
capability_ladder = importlib.util.module_from_spec(LADDER_SPEC)
SPEC.loader.exec_module(system_profile)
LADDER_SPEC.loader.exec_module(capability_ladder)


def hardware_from_fixture(name: str) -> dict:
    raw = json.loads((FIXTURES / name).read_text(encoding="utf-8"))
    return system_profile.hardware_from_input(raw)


class Stage2GpuVisibilityTests(unittest.TestCase):
    def publish_cli(
        self,
        checks: dict,
        profile_path: Path | None,
        output: Path,
    ) -> dict:
        checks_path = output.parent / "checks.json"
        checks_path.write_text(json.dumps(checks), encoding="utf-8")
        command = [
            "python3",
            str(PUBLISH_CLI),
            "--checks",
            str(checks_path),
            "--output",
            str(output),
        ]
        if profile_path is not None:
            command.extend(["--profile", str(profile_path)])
        subprocess.run(command, check=True, capture_output=True, text=True)
        report = json.loads(output.read_text(encoding="utf-8"))
        system_profile.validate_document(report, capability_ladder.S2_M3_SCHEMA, "S2-M3")
        return report

    def test_publisher_cli_writes_schema_valid_report(self) -> None:
        hardware = hardware_from_fixture("observed-ai370.json")
        checks = capability_ladder.normalize_gpu_checks(
            {"vulkan": "visible", "rocm": "visible", "opencl": "visible", "gpu_arch": "gfx1150"},
            hardware,
        )
        with tempfile.TemporaryDirectory() as directory:
            report = self.publish_cli(checks, PROFILE_FIXTURE, Path(directory) / "report.json")
        self.assertEqual(report["milestone"], "S2-M3")
        self.assertEqual(report["artifact"], "s2-m3-gpu-runtime-visibility")
        self.assertFalse(report["ladder"]["validation_claim"])
        self.assertEqual(report["consumed_profile"]["schema"]["version"], 3)
        self.assertEqual(
            report["consumed_profile"]["fingerprint"]["value"],
            json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))["fingerprint"]["value"],
        )

    def test_publisher_without_profile_records_null_fingerprint(self) -> None:
        hardware = hardware_from_fixture("observed-ai370.json")
        checks = capability_ladder.normalize_gpu_checks(
            {"vulkan": "not-visible", "rocm": "not-visible", "opencl": "not-visible"},
            hardware,
        )
        with tempfile.TemporaryDirectory() as directory:
            report = self.publish_cli(checks, None, Path(directory) / "report.json")
        self.assertIsNone(report["consumed_profile"]["fingerprint"]["value"])

    def test_invalid_report_does_not_replace_last_valid_publication(self) -> None:
        hardware = hardware_from_fixture("observed-ai370.json")
        valid = capability_ladder.build_s2_m3_visibility_report(
            hardware,
            {"vulkan": "visible", "rocm": "visible", "opencl": "visible"},
            capability_ladder.consumed_profile_from_system_profile(
                json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))
            ),
        )
        invalid = json.loads(json.dumps(valid))
        invalid["ladder"]["validation_claim"] = True
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "s2-m3-gpu-runtime-visibility.json"
            system_profile.atomic_write_document(
                destination, valid, capability_ladder.S2_M3_SCHEMA, "S2-M3"
            )
            before = destination.read_bytes()
            with self.assertRaises(system_profile.ProfileValidationError):
                system_profile.atomic_write_document(
                    destination, invalid, capability_ladder.S2_M3_SCHEMA, "S2-M3"
                )
            self.assertEqual(destination.read_bytes(), before)

    def test_hardware_from_system_profile_matches_fixture_gpu(self) -> None:
        profile = json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))
        hardware = system_profile.hardware_from_system_profile(profile)
        self.assertEqual(hardware["gpu"]["arch"], "gfx1150")
        self.assertEqual(hardware["gpu"]["devices"][0]["bound_driver"], "amdgpu")
        self.assertEqual(capability_ladder.target_gpu_arch_from_profile(profile), "gfx1150")

    def test_missing_device_checks_publish_unsupported_ladder(self) -> None:
        checks = {
            "amdgpu": "missing",
            "gpu_arch": None,
            "vulkan": "not-visible",
            "opencl": "not-visible",
            "rocm": "not-visible",
            "gpu_text": "",
        }
        with tempfile.TemporaryDirectory() as directory:
            report = self.publish_cli(checks, None, Path(directory) / "report.json")
        self.assertEqual(report["status"], "UNSUPPORTED")
        self.assertEqual(report["ladder"]["assessment"], "UNSUPPORTED")


if __name__ == "__main__":
    unittest.main()
