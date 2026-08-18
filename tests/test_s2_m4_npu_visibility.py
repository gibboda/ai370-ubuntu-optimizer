#!/usr/bin/env python3
"""S2-M4 NPU visibility publisher CLI, schema, and non-inference tests."""

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
PUBLISH_CLI = ROOT / "scripts/s2-m4-publish-npu-visibility.py"
COLLECTOR = ROOT / "scripts/s2-m4-validate-npu-stack.sh"
CHECK_210 = ROOT / "scripts/210-check-ryzen-ai-software.sh"
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


class Stage2NpuVisibilityTests(unittest.TestCase):
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
        system_profile.validate_document(report, capability_ladder.S2_M4_SCHEMA, "S2-M4")
        return report

    def test_publisher_cli_writes_schema_valid_report(self) -> None:
        hardware = hardware_from_fixture("observed-ai370.json")
        checks = capability_ladder.normalize_npu_checks(
            {"firmware_ready": True, "runtime_ready": True, "backend_ready": True},
            hardware,
        )
        with tempfile.TemporaryDirectory() as directory:
            report = self.publish_cli(checks, PROFILE_FIXTURE, Path(directory) / "report.json")
        self.assertEqual(report["milestone"], "S2-M4")
        self.assertEqual(report["artifact"], "s2-m4-npu-runtime-validation")
        self.assertFalse(report["ladder"]["validation_claim"])
        self.assertNotEqual(report["ladder"]["current"], "APPLICATION_READY")
        self.assertEqual(report["consumed_profile"]["schema"]["version"], 3)
        self.assertEqual(
            report["consumed_profile"]["fingerprint"]["value"],
            json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))["fingerprint"]["value"],
        )

    def test_visibility_does_not_claim_inference(self) -> None:
        hardware = hardware_from_fixture("observed-ai370.json")
        checks = {
            "module_present": True,
            "device_nodes_present": True,
            "firmware_ready": True,
            "runtime_ready": True,
            "backend_ready": True,
        }
        with tempfile.TemporaryDirectory() as directory:
            report = self.publish_cli(checks, PROFILE_FIXTURE, Path(directory) / "report.json")
        by_id = {step["id"]: step for step in report["ladder"]["steps"]}
        self.assertFalse(report["ladder"]["validation_claim"])
        self.assertEqual(by_id["BACKEND_READY"]["status"], "satisfied")
        self.assertEqual(by_id["MODEL_READY"]["status"], "unknown")
        self.assertEqual(by_id["APPLICATION_READY"]["status"], "unknown")
        self.assertNotEqual(report["ladder"]["current"], "APPLICATION_READY")
        notes = " ".join(report["notes"]).lower()
        self.assertIn("not executed inference", notes)

    def test_publisher_without_profile_records_null_fingerprint(self) -> None:
        checks = {
            "module_present": False,
            "device_nodes_present": False,
            "firmware_ready": False,
            "runtime_ready": False,
            "backend_ready": False,
        }
        with tempfile.TemporaryDirectory() as directory:
            report = self.publish_cli(checks, None, Path(directory) / "report.json")
        self.assertIsNone(report["consumed_profile"]["fingerprint"]["value"])

    def test_missing_npu_checks_publish_unsupported_ladder(self) -> None:
        checks = {
            "module_present": False,
            "device_nodes_present": False,
            "firmware_ready": False,
            "runtime_ready": False,
            "backend_ready": False,
            "module_text": "",
            "device_text": "",
        }
        with tempfile.TemporaryDirectory() as directory:
            report = self.publish_cli(checks, None, Path(directory) / "report.json")
        self.assertEqual(report["status"], "UNSUPPORTED")
        self.assertEqual(report["ladder"]["assessment"], "UNSUPPORTED")

    def test_invalid_report_does_not_replace_last_valid_publication(self) -> None:
        hardware = hardware_from_fixture("observed-ai370.json")
        valid = capability_ladder.build_s2_m4_visibility_report(
            hardware,
            {"firmware_ready": True, "runtime_ready": True, "backend_ready": True},
            capability_ladder.consumed_profile_from_system_profile(
                json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))
            ),
        )
        invalid = json.loads(json.dumps(valid))
        invalid["ladder"]["validation_claim"] = True
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "s2-m4-npu-runtime-validation.json"
            system_profile.atomic_write_document(
                destination, valid, capability_ladder.S2_M4_SCHEMA, "S2-M4"
            )
            before = destination.read_bytes()
            with self.assertRaises(system_profile.ProfileValidationError):
                system_profile.atomic_write_document(
                    destination, invalid, capability_ladder.S2_M4_SCHEMA, "S2-M4"
                )
            self.assertEqual(destination.read_bytes(), before)

    def test_hardware_from_system_profile_matches_fixture_npu(self) -> None:
        profile = json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))
        hardware = system_profile.hardware_from_system_profile(profile)
        self.assertTrue(hardware["npu"]["present"])
        self.assertEqual(hardware["npu"]["devices"][0]["bound_driver"], "amdxdna")

    def test_live_npu_checks_without_profile_detect_module(self) -> None:
        checks = {
            "module_present": True,
            "device_nodes_present": True,
            "firmware_ready": False,
            "runtime_ready": False,
            "backend_ready": False,
            "module_text": "amdxdna 12345 0",
            "device_text": "/dev/accel/accel0",
        }
        hardware = capability_ladder.hardware_from_live_npu_checks(checks)
        document = capability_ladder.npu_ladder_from_visibility(hardware, checks)
        self.assertTrue(hardware["npu"]["present"])
        self.assertEqual(document["current"], "DRIVER_READY")
        self.assertFalse(document["validation_claim"])

    def test_collector_does_not_run_npu_benchmark(self) -> None:
        source = COLLECTOR.read_text(encoding="utf-8")
        self.assertNotRegex(source, r'(?m)^\s*bash .+230-benchmark-npu\.sh')
        self.assertNotIn("npu_ep_verify", source)
        self.assertIn("visibility only", source.lower())
        check_210 = CHECK_210.read_text(encoding="utf-8")
        self.assertIn("skipped-visibility-only", check_210)
        self.assertIn("VISIBILITY_ONLY", check_210)


if __name__ == "__main__":
    unittest.main()
