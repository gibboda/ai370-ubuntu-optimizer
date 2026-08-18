#!/usr/bin/env python3
"""Schema contract tests for Stage 2 GPU and NPU visibility reports."""

from __future__ import annotations

import importlib.util
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/raw-probes/v1"
PROFILE_FIXTURE = ROOT / "tests/fixtures/system-profile/v3/valid-reference.json"
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


class Stage2VisibilitySchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.profile = json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))
        cls.consumed = capability_ladder.consumed_profile_from_system_profile(cls.profile)

    def test_s2_m3_report_validates(self) -> None:
        hardware = hardware_from_fixture("observed-ai370.json")
        report = capability_ladder.build_s2_m3_visibility_report(
            hardware,
            {"vulkan": "visible", "rocm": "visible", "opencl": "visible"},
            self.consumed,
        )
        system_profile.validate_document(report, capability_ladder.S2_M3_SCHEMA, "S2-M3")
        self.assertEqual(report["milestone"], "S2-M3")
        self.assertFalse(report["ladder"]["validation_claim"])
        self.assertIn(report["status"], {"PASS", "WARN"})

    def test_s2_m4_report_validates(self) -> None:
        hardware = hardware_from_fixture("observed-ai370.json")
        report = capability_ladder.build_s2_m4_visibility_report(
            hardware,
            {"firmware_ready": True, "runtime_ready": True, "backend_ready": True},
            self.consumed,
        )
        system_profile.validate_document(report, capability_ladder.S2_M4_SCHEMA, "S2-M4")
        self.assertEqual(report["milestone"], "S2-M4")
        self.assertNotEqual(report["ladder"]["current"], "APPLICATION_READY")

    def test_non_amd_gpu_report_is_unsupported(self) -> None:
        hardware = hardware_from_fixture("unsupported-host.json")
        report = capability_ladder.build_s2_m3_visibility_report(
            hardware,
            {"vulkan": "not-visible", "rocm": "not-visible", "opencl": "not-visible"},
            self.consumed,
        )
        system_profile.validate_document(report, capability_ladder.S2_M3_SCHEMA, "S2-M3")
        self.assertEqual(report["status"], "WARN")
        self.assertEqual(report["ladder"]["current"], "DETECTED")

    def test_missing_npu_report_is_unsupported(self) -> None:
        hardware = hardware_from_fixture("missing-tool.json")
        report = capability_ladder.build_s2_m4_visibility_report(hardware, {}, self.consumed)
        system_profile.validate_document(report, capability_ladder.S2_M4_SCHEMA, "S2-M4")
        self.assertEqual(report["status"], "UNSUPPORTED")
        self.assertEqual(report["ladder"]["assessment"], "UNSUPPORTED")

    def test_invalid_s2_m3_report_rejected(self) -> None:
        hardware = hardware_from_fixture("observed-ai370.json")
        report = capability_ladder.build_s2_m3_visibility_report(
            hardware,
            {"vulkan": "visible", "rocm": "visible", "opencl": "visible"},
            self.consumed,
        )
        report["ladder"]["validation_claim"] = True
        with self.assertRaises(system_profile.ProfileValidationError):
            system_profile.validate_document(report, capability_ladder.S2_M3_SCHEMA, "S2-M3")


if __name__ == "__main__":
    unittest.main()
