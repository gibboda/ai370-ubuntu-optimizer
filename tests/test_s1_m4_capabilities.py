#!/usr/bin/env python3
"""S1-M4 tests proving capability candidates are not validation claims."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/raw-probes/v1"
SCRIPT = ROOT / "scripts/s1-m4-derive-capabilities.py"
SPEC = importlib.util.spec_from_file_location(
    "system_profile", ROOT / "scripts/lib/system_profile.py"
)
assert SPEC and SPEC.loader
system_profile = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(system_profile)


def load_raw(name: str) -> dict:
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


class Stage1CapabilityTests(unittest.TestCase):
    def derive_cli(self, raw: dict) -> dict:
        facts = system_profile.normalize_facts(raw)
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "facts.json"
            output = Path(directory) / "caps.json"
            source.write_text(json.dumps(facts), encoding="utf-8")
            subprocess.run(
                ["python3", str(SCRIPT), "--input", str(source), "--output", str(output)],
                check=True, capture_output=True, text=True,
            )
            return json.loads(output.read_text(encoding="utf-8"))

    def test_candidates_are_never_validation_claims(self) -> None:
        document = self.derive_cli(load_raw("observed-ai370.json"))
        system_profile.validate_document(document, system_profile.S1_M4_SCHEMA, "S1-M4")
        by_id = {item["id"]: item for item in document["capability_candidates"]}
        self.assertTrue(by_id["gpu.rocm"]["candidate"])
        self.assertEqual(by_id["gpu.rocm"]["state"], "observed")
        self.assertFalse(by_id["gpu.rocm"]["validation_claim"])
        self.assertTrue(by_id["npu.runtime"]["candidate"])
        self.assertFalse(by_id["npu.runtime"]["validation_claim"])
        self.assertIn("not runtime execution proof", " ".join(document["notes"]))

    def test_true_candidate_does_not_imply_runtime_pass(self) -> None:
        document = self.derive_cli(load_raw("observed-ai370.json"))
        for candidate in document["capability_candidates"]:
            if candidate["candidate"] is True:
                self.assertFalse(candidate["validation_claim"])
                self.assertNotEqual(candidate["state"], "PASS")

    def test_missing_npu_is_not_present(self) -> None:
        document = self.derive_cli(load_raw("missing-tool.json"))
        by_id = {item["id"]: item for item in document["capability_candidates"]}
        self.assertEqual(by_id["npu.runtime"]["state"], "not_present")
        self.assertIsNone(by_id["npu.runtime"]["candidate"])

    def test_missing_lspci_is_tool_missing(self) -> None:
        document = self.derive_cli(load_raw("failed-probe.json"))
        by_id = {item["id"]: item for item in document["capability_candidates"]}
        self.assertEqual(by_id["gpu.rocm"]["state"], "tool_missing")
        self.assertIsNone(by_id["gpu.rocm"]["candidate"])

    def test_non_xdna_accelerator_is_not_an_npu_candidate(self) -> None:
        document = self.derive_cli(load_raw("accelerator-non-xdna.json"))
        by_id = {item["id"]: item for item in document["capability_candidates"]}
        self.assertEqual(by_id["npu.runtime"]["state"], "not_present")
        self.assertIsNone(by_id["npu.runtime"]["candidate"])

    def test_sata_only_storage_is_not_an_nvme_candidate(self) -> None:
        document = self.derive_cli(load_raw("storage-sata-only.json"))
        by_id = {item["id"]: item for item in document["capability_candidates"]}
        self.assertEqual(by_id["storage.nvme"]["state"], "not_present")
        self.assertIsNone(by_id["storage.nvme"]["candidate"])
        self.assertEqual(by_id["storage.nvme"]["evidence"], [])

    def test_failed_pci_probe_does_not_claim_gpu_absence(self) -> None:
        raw = load_raw("failed-probe.json")
        raw["collection"]["missing_tools"] = [
            name for name in raw["collection"]["missing_tools"] if name != "lspci"
        ]
        raw["pci"]["state"] = "probe_failed"
        raw["gpu"]["state"] = "probe_failed"
        document = self.derive_cli(raw)
        by_id = {item["id"]: item for item in document["capability_candidates"]}
        self.assertEqual(by_id["gpu.rocm"]["state"], "probe_failed")
        self.assertIsNone(by_id["gpu.rocm"]["candidate"])

    def test_no_fixture_introduces_validation_claim_true(self) -> None:
        for fixture in sorted(FIXTURES.glob("*.json")):
            with self.subTest(fixture=fixture.name):
                document = self.derive_cli(load_raw(fixture.name))
                for candidate in document["capability_candidates"]:
                    self.assertIsNot(candidate["validation_claim"], True)
                    self.assertFalse(candidate.get("validation_claim", False))


if __name__ == "__main__":
    unittest.main()
