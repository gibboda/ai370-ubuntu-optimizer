#!/usr/bin/env python3
"""Portable fixture tests for canonical S1-M2 fact normalization."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/raw-probes/v1"
SCRIPT = ROOT / "scripts/s1-m2-normalize-profile.py"
SPEC = importlib.util.spec_from_file_location(
    "system_profile", ROOT / "scripts/lib/system_profile.py"
)
assert SPEC and SPEC.loader
system_profile = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(system_profile)


def load_raw(name: str) -> dict:
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


class Stage1NormalizeTests(unittest.TestCase):
    def normalize_cli(self, raw: dict) -> dict:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "raw.json"
            output = Path(directory) / "facts.json"
            source.write_text(json.dumps(raw), encoding="utf-8")
            subprocess.run(
                ["python3", str(SCRIPT), "--input", str(source), "--output", str(output)],
                check=True, capture_output=True, text=True,
            )
            return json.loads(output.read_text(encoding="utf-8"))

    def test_ai370_pci_maps_to_gfx1150(self) -> None:
        facts = self.normalize_cli(load_raw("observed-ai370.json"))
        system_profile.validate_document(facts, system_profile.S1_M2_SCHEMA, "S1-M2")
        self.assertEqual(facts["gpu"]["architecture"], "gfx1150")
        self.assertEqual(facts["gpu"]["architecture_family"], "rdna3.5")
        self.assertEqual(facts["gpu"]["architecture_source"], "pci:1002:1900")
        self.assertEqual(facts["gpu"]["devices"][0]["architecture"], "gfx1150")

    def test_live_artifact_name_is_accepted(self) -> None:
        raw = load_raw("observed-ai370.json")
        raw["artifact"] = "s1-m1-raw-inventory"
        facts = self.normalize_cli(raw)
        self.assertEqual(facts["source_artifact"], "s1-m1-raw-inventory")
        self.assertEqual(facts["gpu"]["architecture"], "gfx1150")
        self.assertEqual(facts["system"]["product"], "EliteMini AI370")

    def test_unknown_gpu_pci_stays_unknown(self) -> None:
        facts = self.normalize_cli(load_raw("unsupported-host.json"))
        self.assertIsNone(facts["gpu"]["architecture"])
        self.assertEqual(facts["gpu"]["devices"][0]["vendor_id"], "8086")
        self.assertIsNone(facts["gpu"]["devices"][0]["architecture"])

    def test_marketing_name_is_not_architecture(self) -> None:
        raw = load_raw("observed-ai370.json")
        raw["gpu"]["devices"][0]["device_name"] = "Radeon 890M Strix Point"
        raw["gpu"]["devices"][0]["vendor_id"] = "1002"
        raw["gpu"]["devices"][0]["device_id"] = "ffff"
        facts = self.normalize_cli(raw)
        self.assertIsNone(facts["gpu"]["architecture"])
        self.assertNotEqual(facts["gpu"]["architecture"], "gfx1150")

    def test_missing_lspci_is_explicit(self) -> None:
        raw = load_raw("failed-probe.json")
        facts = self.normalize_cli(raw)
        self.assertEqual(facts["gpu"]["state"], "tool_missing")
        self.assertEqual(facts["gpu"]["devices"], [])
        self.assertIn("lspci", facts["collection"]["missing_tools"])

    def test_library_matches_cli(self) -> None:
        raw = load_raw("observed-ryzen-ai-pro-360.json")
        facts = system_profile.normalize_facts(raw)
        system_profile.validate_document(facts, system_profile.S1_M2_SCHEMA, "S1-M2")
        self.assertEqual(facts["gpu"]["architecture"], "gfx1150")
        self.assertNotEqual(facts["system"]["product"], "EliteMini AI370")


class GpuPciTextLookupTests(unittest.TestCase):
    def test_lspci_nn_text_maps_without_marketing_names(self) -> None:
        text = "03:00.0 VGA compatible controller [0300]: AMD [1002:1900]"
        self.assertEqual(system_profile.lookup_gpu_arch_from_pci_text(text), "gfx1150")

    def test_marketing_names_alone_are_unknown(self) -> None:
        text = "VGA compatible controller: AMD Radeon 890M Strix gfx1150"
        self.assertEqual(system_profile.lookup_gpu_arch_from_pci_text(text), "unknown")


if __name__ == "__main__":
    unittest.main()
