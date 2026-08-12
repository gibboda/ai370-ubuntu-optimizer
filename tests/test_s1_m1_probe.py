#!/usr/bin/env python3
"""Portable fixture tests for the canonical S1-M1 raw probe command."""

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/raw-probes/v1"
SCRIPT = ROOT / "scripts/s1-m1-probe-system.sh"


class Stage1ProbeFixtureTests(unittest.TestCase):
    def replay(self, fixture: str) -> dict:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "inventory.json"
            subprocess.run(
                ["bash", str(SCRIPT), "--fixture", str(FIXTURES / fixture),
                 "--output", str(output)], check=True, capture_output=True, text=True
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


if __name__ == "__main__":
    unittest.main()
