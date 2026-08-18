#!/usr/bin/env python3
"""Portable tests for structured GPU/NPU capability ladders."""

from __future__ import annotations

import importlib.util
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/raw-probes/v1"
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


class CapabilityLadderTests(unittest.TestCase):
    def test_ai370_probe_reaches_driver_ready(self) -> None:
        hardware = hardware_from_fixture("observed-ai370.json")
        document = capability_ladder.gpu_ladder_from_hardware(hardware)
        self.assertFalse(document["validation_claim"])
        self.assertEqual(document["current"], "DRIVER_READY")
        self.assertEqual(document["assessment"], "AVAILABLE")
        by_id = {step["id"]: step for step in document["steps"]}
        self.assertEqual(by_id["DETECTED"]["status"], "satisfied")
        self.assertEqual(by_id["DRIVER_READY"]["status"], "satisfied")
        self.assertEqual(by_id["VULKAN_READY"]["status"], "unknown")

    def test_non_amd_gpu_stops_at_detected(self) -> None:
        hardware = hardware_from_fixture("unsupported-host.json")
        document = capability_ladder.gpu_ladder_from_hardware(hardware)
        self.assertEqual(document["current"], "DETECTED")
        self.assertEqual(document["assessment"], "AVAILABLE")
        by_id = {step["id"]: step for step in document["steps"]}
        self.assertEqual(by_id["DETECTED"]["status"], "satisfied")
        self.assertEqual(by_id["DRIVER_READY"]["status"], "unsupported")
        self.assertEqual(by_id["VULKAN_READY"]["status"], "skipped")

    def test_missing_gpu_probe_is_unsupported(self) -> None:
        hardware = hardware_from_fixture("failed-probe.json")
        document = capability_ladder.gpu_ladder_from_hardware(hardware)
        self.assertEqual(document["current"], None)
        self.assertEqual(document["assessment"], "UNSUPPORTED")
        self.assertEqual(document["steps"][0]["status"], "unsupported")

    def test_visibility_extends_gpu_ladder(self) -> None:
        hardware = hardware_from_fixture("observed-ai370.json")
        checks = {"vulkan": "visible", "rocm": "visible", "opencl": "visible"}
        document = capability_ladder.gpu_ladder_from_visibility(hardware, checks)
        by_id = {step["id"]: step for step in document["steps"]}
        self.assertEqual(by_id["VULKAN_READY"]["status"], "satisfied")
        self.assertEqual(by_id["ROCM_READY"]["status"], "satisfied")
        self.assertEqual(by_id["HIP_READY"]["status"], "satisfied")
        self.assertEqual(document["current"], "HIP_READY")
        self.assertEqual(by_id["FRAMEWORK_READY"]["status"], "unknown")

    def test_missing_vulkan_is_degraded(self) -> None:
        hardware = hardware_from_fixture("observed-ai370.json")
        checks = {"vulkan": "not-visible", "rocm": "not-visible", "opencl": "not-visible"}
        document = capability_ladder.gpu_ladder_from_visibility(hardware, checks)
        self.assertEqual(document["current"], "DRIVER_READY")
        self.assertEqual(document["assessment"], "DEGRADED")

    def test_npu_probe_reaches_driver_ready(self) -> None:
        hardware = hardware_from_fixture("observed-ai370.json")
        document = capability_ladder.npu_ladder_from_hardware(hardware)
        self.assertEqual(document["current"], "DRIVER_READY")
        self.assertEqual(document["assessment"], "AVAILABLE")

    def test_non_xdna_host_is_unsupported(self) -> None:
        hardware = hardware_from_fixture("accelerator-non-xdna.json")
        document = capability_ladder.npu_ladder_from_hardware(hardware)
        self.assertEqual(document["assessment"], "UNSUPPORTED")

    def test_npu_visibility_does_not_claim_application_ready(self) -> None:
        hardware = hardware_from_fixture("observed-ai370.json")
        checks = {"runtime_ready": True, "backend_ready": True, "firmware_ready": True}
        document = capability_ladder.npu_ladder_from_visibility(hardware, checks)
        self.assertFalse(document["validation_claim"])
        by_id = {step["id"]: step for step in document["steps"]}
        self.assertEqual(by_id["RUNTIME_READY"]["status"], "satisfied")
        self.assertEqual(by_id["BACKEND_READY"]["status"], "satisfied")
        self.assertEqual(by_id["APPLICATION_READY"]["status"], "unknown")
        self.assertNotEqual(document["current"], "APPLICATION_READY")


if __name__ == "__main__":
    unittest.main()
