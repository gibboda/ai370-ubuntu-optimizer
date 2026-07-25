#!/usr/bin/env python3
"""Unit tests for deterministic Stage 1 profile normalization and classification."""

import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "system_profile", ROOT / "scripts/lib/system_profile.py"
)
assert SPEC and SPEC.loader
system_profile = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(system_profile)


def inventory(cpu: str, vendor: str, gpu: str, npu: bool) -> dict:
    return {
        "system": {"vendor": "Micro Computer", "product": "AI370", "kernel": "6.14"},
        "cpu": {"model": cpu, "vendor": vendor, "logical_cores": 24},
        "gpu": {"text": "AMD Radeon 890M", "arch": gpu, "amdgpu_module": "loaded"},
        "npu": {"present": npu, "module_text": "amdxdna" if npu else "", "device_text": ""},
        "memory": {"total": "32Gi"},
        "storage": {"summary": "nvme0n1", "nvme": "nvme0n1"},
        "tools": {"missing": "clinfo,jq"},
    }


class SystemProfileTests(unittest.TestCase):
    def test_exact_ai370_classification(self) -> None:
        profile = system_profile.build_profile(
            inventory("AMD Ryzen AI 9 HX 370", "AuthenticAMD", "gfx1150", True), "test"
        )
        self.assertEqual(profile["schema"], {"name": "ai370-system-profile", "version": 1})
        self.assertEqual(profile["classification"]["matched_profile"], "ai370")
        self.assertEqual(profile["classification"]["confidence"], "exact")
        self.assertTrue(profile["capabilities"]["gpu"]["rocm_candidate"])
        self.assertEqual(profile["collection"]["missing_tools"], ["clinfo", "jq"])

    def test_generic_ryzen_ai_classification(self) -> None:
        profile = system_profile.build_profile(
            inventory("AMD Ryzen AI 7 PRO 360", "AuthenticAMD", "unknown", False)
        )
        self.assertEqual(profile["classification"]["matched_profile"], "generic-ryzen-ai")
        self.assertEqual(profile["classification"]["confidence"], "family")
        self.assertFalse(profile["capabilities"]["npu"]["present"])
        self.assertIn("gpu.arch", profile["unknowns"])

    def test_unsupported_host_is_not_forced_into_profile(self) -> None:
        profile = system_profile.build_profile(
            inventory("Intel Xeon", "GenuineIntel", "unknown", False)
        )
        self.assertIsNone(profile["classification"]["matched_profile"])
        self.assertEqual(profile["classification"]["confidence"], "none")


if __name__ == "__main__":
    unittest.main()
