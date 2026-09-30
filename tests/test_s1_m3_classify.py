#!/usr/bin/env python3
"""Table-driven S1-M3 platform classification tests."""

from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
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

sys.path.insert(0, str(ROOT / "scripts/lib"))
import firmware_policy  # noqa: E402
import hardware_profile  # noqa: E402


CASES = (
    ("observed-ai370.json", "ai370", "exact", "observed"),
    ("observed-ryzen-ai-pro-360.json", "strix-point-ryzen-ai", "family", "observed"),
    ("observed-ryzen-ai-max-strix-halo.json", "strix-halo-ryzen-ai", "family", "observed"),
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

    def test_hardware_profiles_share_one_platform_architecture(self) -> None:
        architecture = hardware_profile.platform_architecture_id()
        self.assertEqual(architecture, "ryzen-ai-linux")
        point = hardware_profile.profile_by_id("ai370")
        halo = hardware_profile.profile_by_id("ryzen-ai-halo")
        assert point is not None and halo is not None
        self.assertEqual(point["platform_architecture"], architecture)
        self.assertEqual(halo["platform_architecture"], architecture)
        self.assertEqual(halo["id"], "strix-halo-ryzen-ai")
        self.assertNotEqual(point["hardware_family"], halo["hardware_family"])
        self.assertEqual(point["validation"], "project-verified")
        self.assertEqual(halo["validation"], "officially-documented")
        self.assertEqual(hardware_profile.providers("ai370"), hardware_profile.providers("strix-halo"))
        self.assertEqual(hardware_profile.gpu_target("ai370"), "gfx1150")
        self.assertEqual(hardware_profile.gpu_target("strix-point"), "gfx1150")
        self.assertEqual(hardware_profile.gpu_target("strix-halo-ryzen-ai"), "gfx1151")
        self.assertEqual(hardware_profile.gpu_target("generic-ryzen-ai"), "")
        raw = json.loads(
            (FIXTURES / "observed-ryzen-ai-max-strix-halo.json").read_text(encoding="utf-8")
        )
        profile = system_profile.build_profile(raw, "test")
        system_profile.validate_profile(profile)
        self.assertEqual(profile["gpus"][0]["architecture"], "gfx1151")
        self.assertIsNone(profile["gpus"][0]["pci"]["device_id"])

    def test_ryzen_ai_max_product_string_beats_strix_point_signature(self) -> None:
        raw = json.loads((FIXTURES / "observed-ryzen-ai-pro-360.json").read_text(encoding="utf-8"))
        raw["cpu"]["model_name"] = "AMD Ryzen AI MAX+"
        facts = system_profile.normalize_facts(raw)
        document = system_profile.classify_platform_document(facts)
        self.assertEqual(document["classification"]["platform_id"], "strix-halo-ryzen-ai")
        self.assertEqual(document["classification"]["confidence"], "family")

    def test_bios_policy_stays_on_the_ai370_profile(self) -> None:
        self.assertEqual(firmware_policy.expected_bios_version("ai370"), "2.01")
        self.assertEqual(firmware_policy.expected_bios_version("strix-point-ryzen-ai"), "")
        self.assertEqual(firmware_policy.expected_bios_version("strix-halo-ryzen-ai"), "")

    def test_shell_adapter_reads_profile_gpu_target(self) -> None:
        script = ROOT / "scripts/lib/hardware-profile.sh"
        env = {**os.environ, "PROJECT_ROOT": str(ROOT)}
        for profile, expected in (
            ("ai370", "gfx1150"),
            ("strix-halo", "gfx1151"),
            ("generic-ryzen-ai", ""),
        ):
            with self.subTest(profile=profile):
                completed = subprocess.run(
                    [
                        "bash",
                        "-c",
                        'source "$1" && hardware_profile_gpu_target "$2"',
                        "bash",
                        str(script),
                        profile,
                    ],
                    check=True,
                    capture_output=True,
                    text=True,
                    env=env,
                )
                self.assertEqual(completed.stdout, expected)

    def test_shell_adapter_reads_classified_platform_gpu_target(self) -> None:
        script = ROOT / "scripts/lib/hardware-profile.sh"
        env = {**os.environ, "PROJECT_ROOT": str(ROOT)}
        cases = (
            ("strix-halo-ryzen-ai", "gfx1151"),
            ("ai370", "gfx1150"),
            (None, ""),
        )
        for platform_id, expected in cases:
            with self.subTest(platform_id=platform_id):
                with tempfile.TemporaryDirectory() as directory:
                    profile_path = Path(directory) / "s1-m5-system-profile.json"
                    profile_path.write_text(
                        json.dumps({"classification": {"platform_id": platform_id}}),
                        encoding="utf-8",
                    )
                    completed = subprocess.run(
                        [
                            "bash",
                            "-c",
                            'source "$1" && hardware_profile_gpu_target_from_system_profile "$2"',
                            "bash",
                            str(script),
                            str(profile_path),
                        ],
                        check=True,
                        capture_output=True,
                        text=True,
                        env=env,
                    )
                    self.assertEqual(completed.stdout, expected)


if __name__ == "__main__":
    unittest.main()
