#!/usr/bin/env python3
"""Portable fixture tests for the canonical S1-M1 raw probe command."""

import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/raw-probes/v1"
SCRIPT = ROOT / "scripts/s1-m1-probe-system.sh"
SPEC = importlib.util.spec_from_file_location(
    "system_profile", ROOT / "scripts/lib/system_profile.py"
)
assert SPEC and SPEC.loader
system_profile = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(system_profile)


class Stage1ProbeFixtureTests(unittest.TestCase):
    def replay(self, fixture: str) -> dict:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "inventory.json"
            subprocess.run(
                [
                    "bash",
                    str(SCRIPT),
                    "--fixture",
                    str(FIXTURES / fixture),
                    "--output",
                    str(output),
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            return json.loads(output.read_text(encoding="utf-8"))

    def test_reference_elitemini(self) -> None:
        raw = self.replay("observed-ai370.json")
        self.assertEqual(raw["dmi"]["system"]["product"]["value"], "EliteMini AI370")
        self.assertEqual(raw["accelerators"]["devices"][0]["bound_driver"], "amdxdna")

    def test_another_ryzen_ai_platform(self) -> None:
        raw = self.replay("observed-ryzen-ai-pro-360.json")
        self.assertNotEqual(raw["dmi"]["system"]["product"]["value"], "EliteMini AI370")

    def test_missing_tools_are_explicit(self) -> None:
        self.assertIn("clinfo", self.replay("missing-tool.json")["collection"]["missing_tools"])

    def test_unreadable_probe_is_explicit(self) -> None:
        raw = self.replay("unreadable-probe.json")
        self.assertEqual(raw["dmi"]["system"]["product"]["state"], "permission_denied")
        self.assertTrue(raw["collection"]["permission_errors"])

    def test_unsupported_hardware_remains_inventory(self) -> None:
        raw = self.replay("unsupported-host.json")
        self.assertEqual(raw["cpu"]["vendor_id"], "GenuineIntel")

    def test_unrelated_accelerator_is_not_an_xdna_claim(self) -> None:
        raw = self.replay("accelerator-non-xdna.json")
        self.assertNotEqual(raw["accelerators"]["devices"][0]["vendor_id"], "1022")

    def test_signal_processing_class_selects_npu_pci_id_only(self) -> None:
        npu = {
            "class": "Signal processing controller [1180]",
            "vendor_id": "1022",
            "device_id": "17f0",
            "bound_driver": "amdxdna",
            "device_name": "Strix/Krackan/Strix Halo Neural Processing Unit [17f0]",
        }
        sensor_hub = {
            "class": "Signal processing controller [1180]",
            "vendor_id": "1022",
            "device_id": "164a",
            "bound_driver": "pcie_mp2_amd",
            "device_name": "Sensor Fusion Hub [164a]",
        }
        other = {
            "class": "Processing accelerators [1200]",
            "vendor_id": "10de",
            "device_id": "abcd",
            "bound_driver": "some_other_driver",
        }
        self.assertTrue(system_profile.is_stage1_accelerator(npu))
        self.assertTrue(system_profile.is_npu_pci_device(npu))
        self.assertFalse(system_profile.is_stage1_accelerator(sensor_hub))
        self.assertTrue(system_profile.is_stage1_accelerator(other))
        self.assertFalse(system_profile.is_npu_pci_device(other))

    def test_generic_npu_name_requires_amd_vendor(self) -> None:
        intel_npu = {
            "class": "Processing accelerators [1200]",
            "vendor_id": "8086",
            "device_id": "7d1d",
            "bound_driver": "intel_vpu",
            "device_name": "Meteor Lake Neural Processing Unit",
        }
        amd_named = {
            "class": "Signal processing controller [1180]",
            "vendor_id": "1022",
            "device_id": "17f2",
            "device_name": "Neural Processing Unit",
        }
        self.assertFalse(system_profile.is_npu_pci_device(intel_npu))
        self.assertTrue(system_profile.is_stage1_accelerator(intel_npu))
        self.assertTrue(system_profile.is_npu_pci_device(amd_named))


if __name__ == "__main__":
    unittest.main()
