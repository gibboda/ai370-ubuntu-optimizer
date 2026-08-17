#!/usr/bin/env python3
"""S1-M5 publication, schema, and interrupted-write tests."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/raw-probes/v1"
V3_FIXTURES = ROOT / "tests/fixtures/system-profile/v3"
S1_M2 = ROOT / "scripts/s1-m2-normalize-profile.py"
S1_M3 = ROOT / "scripts/s1-m3-classify-platform.py"
S1_M4 = ROOT / "scripts/s1-m4-derive-capabilities.py"
S1_M5 = ROOT / "scripts/s1-m5-publish-profile.py"
SPEC = importlib.util.spec_from_file_location(
    "system_profile", ROOT / "scripts/lib/system_profile.py"
)
assert SPEC and SPEC.loader
system_profile = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(system_profile)


def load_raw(name: str) -> dict:
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


class Stage1PublishTests(unittest.TestCase):
    def publish_cli(self, raw: dict, directory: Path) -> tuple[dict, str]:
        raw_path = directory / "raw.json"
        facts_path = directory / "s1-m2-normalized-facts.json"
        class_path = directory / "s1-m3-platform-classification.json"
        caps_path = directory / "s1-m4-capability-candidates.json"
        profile_path = directory / "s1-m5-system-profile.json"
        summary_path = directory / "s1-m5-inventory-summary.md"
        compat_path = directory / "system-profile.json"
        raw_path.write_text(json.dumps(raw), encoding="utf-8")
        subprocess.run(
            ["python3", str(S1_M2), "--input", str(raw_path), "--output", str(facts_path)],
            check=True, capture_output=True, text=True,
        )
        subprocess.run(
            ["python3", str(S1_M3), "--input", str(facts_path), "--output", str(class_path)],
            check=True, capture_output=True, text=True,
        )
        subprocess.run(
            ["python3", str(S1_M4), "--input", str(facts_path), "--output", str(caps_path)],
            check=True, capture_output=True, text=True,
        )
        subprocess.run(
            ["python3", str(S1_M5), "--facts", str(facts_path),
             "--classification", str(class_path), "--capabilities", str(caps_path),
             "--output", str(profile_path), "--summary", str(summary_path),
             "--compat-output", str(compat_path), "--generator-version", "test"],
            check=True, capture_output=True, text=True,
        )
        profile = json.loads(profile_path.read_text(encoding="utf-8"))
        summary = summary_path.read_text(encoding="utf-8")
        compat = json.loads(compat_path.read_text(encoding="utf-8"))
        self.assertEqual(profile["classification"], compat["classification"])
        self.assertEqual(profile["fingerprint"]["value"], compat["fingerprint"]["value"])
        return profile, summary

    def test_pipeline_publishes_valid_v3_profile_and_summary(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            profile, summary = self.publish_cli(load_raw("observed-ai370.json"), Path(directory))
        system_profile.validate_profile(profile)
        system_profile.validate_document(profile, system_profile.S1_M5_SCHEMA, "S1-M5")
        self.assertEqual(profile["classification"]["platform_id"], "ai370")
        self.assertEqual(profile["gpus"][0]["architecture"], "gfx1150")
        self.assertEqual(profile["gpus"][0]["pci"]["vendor_id"], "1002")
        self.assertEqual(profile["gpus"][0]["pci"]["device_id"], "1900")
        self.assertEqual(profile["generation"]["generator"]["name"], "system_profile.py")
        self.assertIn("Stage 1 system profile", summary)
        self.assertIn("not validation claims", summary)
        self.assertIn("gfx1150", summary)

    def test_compat_system_profile_validates_as_v3(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            profile, _summary = self.publish_cli(load_raw("observed-ai370.json"), Path(directory))
            compat = json.loads((Path(directory) / "system-profile.json").read_text(encoding="utf-8"))
        system_profile.validate_profile(compat, ROOT / "configs/schemas/system-profile.schema.json")
        self.assertEqual(compat["schema"]["version"], 3)
        self.assertEqual(compat["fingerprint"]["value"], profile["fingerprint"]["value"])

    def test_invalid_candidate_does_not_replace_last_valid_profile(self) -> None:
        valid = json.loads((V3_FIXTURES / "valid-reference.json").read_text())
        invalid = json.loads((V3_FIXTURES / "invalid-contract.json").read_text())
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "s1-m5-system-profile.json"
            system_profile.atomic_write_document(
                destination, valid, system_profile.S1_M5_SCHEMA, "S1-M5"
            )
            before = destination.read_bytes()
            with self.assertRaises(system_profile.ProfileValidationError):
                system_profile.atomic_write_document(
                    destination, invalid, system_profile.S1_M5_SCHEMA, "S1-M5"
                )
            self.assertEqual(destination.read_bytes(), before)
            self.assertEqual(list(destination.parent.glob(".s1-m5-system-profile.json.*")), [])

    def test_schema_failure_reports_contract_violations(self) -> None:
        profile = json.loads((V3_FIXTURES / "invalid-contract.json").read_text())
        with self.assertRaises(system_profile.ProfileValidationError) as caught:
            system_profile.validate_document(profile, system_profile.S1_M5_SCHEMA, "S1-M5")
        self.assertIn("fingerprint.value", str(caught.exception))


if __name__ == "__main__":
    unittest.main()
