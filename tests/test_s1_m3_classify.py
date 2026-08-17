#!/usr/bin/env python3
"""Table-driven S1-M3 platform classification tests."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/raw-probes/v1"
SCRIPT = ROOT / "scripts/s1-m3-classify-platform.py"
SPEC = importlib.util.spec_from_file_location(
    "system_profile", ROOT / "scripts/lib/system_profile.py"
)
assert SPEC and SPEC.loader
system_profile = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(system_profile)


CASES = (
    ("observed-ai370.json", "ai370", "exact", "observed"),
    ("observed-ryzen-ai-pro-360.json", "strix-point-ryzen-ai", "family", "observed"),
    ("unsupported-host.json", None, "none", "unsupported"),
)


class Stage1ClassifyTests(unittest.TestCase):
    def classify_fixture(self, name: str) -> dict:
        raw = json.loads((FIXTURES / name).read_text(encoding="utf-8"))
        facts = system_profile.normalize_facts(raw)
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "facts.json"
            output = Path(directory) / "class.json"
            source.write_text(json.dumps(facts), encoding="utf-8")
            subprocess.run(
                ["python3", str(SCRIPT), "--input", str(source), "--output", str(output)],
                check=True, capture_output=True, text=True,
            )
            return json.loads(output.read_text(encoding="utf-8"))

    def test_table_driven_family_and_unknown_platforms(self) -> None:
        for fixture, platform_id, confidence, state in CASES:
            with self.subTest(fixture=fixture):
                document = self.classify_fixture(fixture)
                system_profile.validate_document(
                    document, system_profile.S1_M3_SCHEMA, "S1-M3"
                )
                classification = document["classification"]
                self.assertEqual(classification["platform_id"], platform_id)
                self.assertEqual(classification["confidence"], confidence)
                self.assertEqual(classification["state"], state)

    def test_generic_ryzen_ai_family_without_300_signature(self) -> None:
        raw = json.loads((FIXTURES / "observed-ai370.json").read_text(encoding="utf-8"))
        raw["dmi"]["system"]["product"]["value"] = "Some Other Box"
        raw["cpu"]["model_name"] = "AMD Ryzen AI 9"
        raw["cpu"]["family"] = 25
        raw["cpu"]["model"] = 1
        facts = system_profile.normalize_facts(raw)
        document = system_profile.classify_platform_document(facts)
        self.assertEqual(document["classification"]["platform_id"], "generic-ryzen-ai")
        self.assertEqual(document["classification"]["confidence"], "family")

    def test_unknown_platform_when_cpu_identity_is_missing(self) -> None:
        raw = json.loads((FIXTURES / "unreadable-probe.json").read_text(encoding="utf-8"))
        facts = system_profile.normalize_facts(raw)
        document = system_profile.classify_platform_document(facts)
        self.assertIsNone(document["classification"]["platform_id"])
        self.assertEqual(document["classification"]["confidence"], "none")
        self.assertEqual(document["classification"]["state"], "unknown")


if __name__ == "__main__":
    unittest.main()
