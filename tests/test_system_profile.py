#!/usr/bin/env python3
"""Deterministic contract and publication tests for the Stage 1 profile."""

import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/system-profile/v3"
V2_FIXTURES = ROOT / "tests/fixtures/system-profile/v2"
RAW_FIXTURES = ROOT / "tests/fixtures/raw-probes/v1"
SPEC = importlib.util.spec_from_file_location("system_profile", ROOT / "scripts/lib/system_profile.py")
assert SPEC and SPEC.loader
system_profile = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(system_profile)


def inventory(cpu: str, vendor: str, gpu: str, npu: bool, product: str = "Ryzen AI system",
              cpu_family: int | None = None, cpu_model: int | None = None,
              system_vendor: str | None = None) -> dict:
    return {
        "system": {"vendor": system_vendor, "product": product, "kernel": "6.14",
                   "os": "Ubuntu 24.04", "bios_version": "2.00"},
        "cpu": {"model": cpu, "vendor": vendor, "family": cpu_family, "cpu_model": cpu_model, "logical_cores": 24},
        "gpu": {"text": "AMD display controller", "arch": gpu, "amdgpu_module": "loaded"},
        "npu": {"present": npu, "module_text": "amdxdna" if npu else "", "device_text": ""},
        "memory": {"total": "32GiB"}, "storage": {"summary": "nvme0n1", "nvme": "nvme0n1"},
        "tools": {"missing": "clinfo,jq"},
    }


class SchemaContractTests(unittest.TestCase):
    def test_versioned_valid_fixture_satisfies_contract(self) -> None:
        profile = json.loads((FIXTURES / "valid-reference.json").read_text())
        system_profile.validate_profile(profile)

    def test_v2_fixture_requires_archived_migration_schema(self) -> None:
        profile = json.loads((V2_FIXTURES / "valid-reference.json").read_text())
        with self.assertRaises(system_profile.ProfileValidationError):
            system_profile.validate_profile(profile)
        system_profile.validate_profile(
            profile, ROOT / "configs/schemas/system-profile-v2.schema.json"
        )

    def test_invalid_fixture_reports_all_contract_violations(self) -> None:
        profile = json.loads((FIXTURES / "invalid-contract.json").read_text())
        with self.assertRaises(system_profile.ProfileValidationError) as caught:
            system_profile.validate_profile(profile)
        self.assertIn("fingerprint.value", str(caught.exception))
        self.assertIn("fingerprint.inputs", str(caught.exception))
        self.assertIn("unexpected property", str(caught.exception))

    def test_invalid_candidate_does_not_replace_last_valid_profile(self) -> None:
        valid = json.loads((FIXTURES / "valid-reference.json").read_text())
        invalid = json.loads((FIXTURES / "invalid-contract.json").read_text())
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "system-profile.json"
            system_profile.atomic_write(destination, valid)
            before = destination.read_bytes()
            with self.assertRaises(system_profile.ProfileValidationError):
                system_profile.atomic_write(destination, invalid)
            self.assertEqual(destination.read_bytes(), before)
            self.assertEqual(list(destination.parent.glob(".system-profile.json.*")), [])


class NormalizationTests(unittest.TestCase):
    def test_complete_profile_is_valid_and_exactly_classified(self) -> None:
        profile = system_profile.build_profile(
            inventory("AMD Ryzen AI 9 HX 370", "AuthenticAMD", "gfx1150", True, "EliteMini AI370", 26, 36), "test"
        )
        system_profile.validate_profile(profile)
        self.assertEqual(profile["schema"]["version"], 3)
        self.assertEqual(profile["classification"]["platform_id"], "ai370")
        self.assertEqual(profile["classification"]["confidence"], "exact")
        self.assertEqual(profile["fingerprint"]["algorithm"], "sha256")
        self.assertEqual(profile["fingerprint"]["algorithm_version"], 1)
        self.assertEqual(profile["fingerprint"]["inputs"], ["accelerators", "cpu", "dmi", "pci_devices", "storage"])
        self.assertEqual([tool["state"] for tool in profile["collection"]["tools"]],
                         ["tool_missing", "tool_missing"])

    def test_newer_ryzen_ai_is_a_family_match(self) -> None:
        profile = system_profile.build_profile(
            inventory("AMD engineering sample", "AuthenticAMD", "unknown", False, cpu_family=26, cpu_model=36)
        )
        system_profile.validate_profile(profile)
        self.assertEqual(profile["classification"]["platform_id"], "strix-point-ryzen-ai")
        self.assertEqual(profile["classification"]["confidence"], "family")
        self.assertEqual(profile["capability_candidates"][1]["state"], "not_present")

    def test_elitemini_identity_survives_unavailable_npu_driver(self) -> None:
        without_npu = inventory("AMD Ryzen AI 9 HX 370", "AuthenticAMD", "gfx1150", False, "EliteMini AI370", 26, 36)
        with_npu = inventory("AMD Ryzen AI 9 HX 370", "AuthenticAMD", "gfx1150", True, "EliteMini AI370", 26, 36)
        profile = system_profile.build_profile(without_npu, "test")
        profile_with_npu = system_profile.build_profile(with_npu, "test")
        system_profile.validate_profile(profile)
        system_profile.validate_profile(profile_with_npu)
        self.assertEqual(profile["classification"]["platform_id"], "ai370")
        self.assertEqual(profile["capability_candidates"][1]["state"], "not_present")
        self.assertEqual(profile["fingerprint"]["value"], profile_with_npu["fingerprint"]["value"])

    def test_degraded_npu_driver_keeps_device_visibility_separate(self) -> None:
        host = inventory("AMD Ryzen AI 9 HX 370", "AuthenticAMD", "gfx1150", True, "EliteMini AI370", 26, 36)
        host["npu"] = {"present": True, "module_text": "", "device_text": "/dev/accel/accel0", "devices": []}
        profile = system_profile.build_profile(host, "test")
        system_profile.validate_profile(profile)
        self.assertEqual(profile["classification"]["platform_id"], "ai370")
        self.assertEqual(profile["accelerators"][0]["state"], "observed")
        self.assertEqual(profile["accelerators"][0]["driver"]["state"], "unknown")
        self.assertEqual(profile["accelerators"][0]["runtime"], "unknown")

    def test_unsupported_host_has_explicit_state(self) -> None:
        profile = system_profile.build_profile(inventory("Intel Xeon", "GenuineIntel", "unknown", False))
        system_profile.validate_profile(profile)
        self.assertIsNone(profile["classification"]["platform_id"])
        self.assertEqual(profile["classification"]["state"], "unsupported")

    def test_fingerprint_is_null_when_lspci_unavailable(self) -> None:
        host = inventory("AMD Ryzen AI 9 HX 370", "AuthenticAMD", "gfx1150", True, "EliteMini AI370", 26, 36)
        host["tools"] = {"missing": "lspci,clinfo"}
        profile = system_profile.build_profile(host, "test")
        system_profile.validate_profile(profile)
        self.assertIsNone(profile["fingerprint"]["value"])

    def test_known_non_minisforum_vendor_does_not_match_ai370_exact_identity(self) -> None:
        profile = system_profile.build_profile(
            inventory("AMD Ryzen AI 9 HX 370", "AuthenticAMD", "gfx1150", True, "AI370",
                      cpu_family=26, cpu_model=36, system_vendor="Framework")
        )
        system_profile.validate_profile(profile)
        self.assertEqual(profile["classification"]["platform_id"], "strix-point-ryzen-ai")
        self.assertEqual(profile["classification"]["confidence"], "family")


class RawProbeNormalizationTests(unittest.TestCase):
    def _load(self, name: str) -> dict:
        return json.loads((RAW_FIXTURES / name).read_text())

    def test_observed_ai370_is_exactly_classified(self) -> None:
        raw = self._load("observed-ai370.json")
        profile = system_profile.build_profile(raw, "test")
        system_profile.validate_profile(profile)
        self.assertEqual(profile["classification"]["platform_id"], "ai370")
        self.assertEqual(profile["gpus"][0]["architecture"], "gfx1150")
        self.assertEqual(profile["gpus"][0]["pci"]["device_id"], "1900")
        xdna_accels = [a for a in profile["accelerators"] if a.get("state") == "observed"]
        self.assertTrue(xdna_accels, "AMD XDNA accelerator must be observed")
        self.assertEqual(xdna_accels[0]["driver"]["name"], "amdxdna")

    def test_fingerprint_ignores_volatile_state_order_and_formatting(self) -> None:
        raw = self._load("observed-ai370.json")
        raw["pci"]["devices"] = [
            {"vendor_id": "1022", "device_id": "1502"},
            {"vendor_id": "1002", "device_id": "1900"},
        ]
        changed = copy.deepcopy(raw)
        changed["timestamp"] = "2030-12-31T23:59:59Z"
        changed["kernel"]["release"] = "9.1.0-upgraded"
        changed["os"]["pretty_name"] = "Ubuntu 30.04 LTS"
        changed["gpu"]["devices"][0]["bound_driver"] = None
        changed["accelerators"]["devices"][0]["bound_driver"] = None
        changed["accelerators"]["device_nodes"] = []
        changed["cpu"]["model_name"] = "  AMD   Ryzen AI 9 HX 370\n"
        changed["dmi"]["system"]["vendor"]["value"] = "  MINISFORUM  "
        changed["gpu"]["devices"] = list(reversed(changed["gpu"]["devices"]))
        changed["accelerators"]["devices"] = list(reversed(changed["accelerators"]["devices"]))
        changed["pci"]["devices"] = list(reversed(changed["pci"]["devices"]))
        self.assertEqual(system_profile.build_profile(raw)["fingerprint"]["value"],
                         system_profile.build_profile(changed)["fingerprint"]["value"])

    def test_fingerprint_changes_with_device_identity(self) -> None:
        raw = self._load("observed-ai370.json")
        changed = copy.deepcopy(raw)
        changed["gpu"]["devices"][0]["device_id"] = "1901"
        self.assertNotEqual(system_profile.build_profile(raw)["fingerprint"]["value"],
                            system_profile.build_profile(changed)["fingerprint"]["value"])

    def test_non_hx370_ryzen_ai_fixture_matches_family_without_collector_change(self) -> None:
        raw = self._load("observed-ryzen-ai-pro-360.json")
        profile = system_profile.build_profile(raw, "test")
        system_profile.validate_profile(profile)
        self.assertEqual(profile["classification"]["platform_id"], "strix-point-ryzen-ai")
        self.assertEqual(profile["classification"]["confidence"], "family")
        self.assertEqual(profile["accelerators"][0]["state"], "observed")
        self.assertEqual(profile["accelerators"][0]["driver"]["state"], "unknown")
        self.assertEqual(profile["accelerators"][0]["runtime"], "unknown")

    def test_missing_tool_appears_in_collection(self) -> None:
        raw = self._load("missing-tool.json")
        profile = system_profile.build_profile(raw, "test")
        system_profile.validate_profile(profile)
        tool_states = {t["name"]: t["state"] for t in profile["collection"]["tools"]}
        self.assertIn("clinfo", tool_states)
        self.assertEqual(tool_states["clinfo"], "tool_missing")
        self.assertIn("rocminfo", tool_states)
        self.assertEqual(tool_states["rocminfo"], "tool_missing")

    def test_failed_probe_produces_valid_profile_with_unknown_firmware(self) -> None:
        raw = self._load("failed-probe.json")
        profile = system_profile.build_profile(raw, "test")
        system_profile.validate_profile(profile)
        fw = profile["firmware"]
        self.assertIsNone(fw["bios_version"])

    def test_unsupported_host_has_unsupported_state(self) -> None:
        raw = self._load("unsupported-host.json")
        profile = system_profile.build_profile(raw, "test")
        system_profile.validate_profile(profile)
        self.assertEqual(profile["classification"]["state"], "unsupported")
        self.assertIsNone(profile["classification"]["platform_id"])

    def test_storage_sata_only_has_no_nvme_in_storage_list(self) -> None:
        raw = self._load("storage-sata-only.json")
        profile = system_profile.build_profile(raw, "test")
        system_profile.validate_profile(profile)
        storage_names = [d.get("name", "") for d in profile["storage"]]
        self.assertFalse(any(str(n).startswith("nvme") for n in storage_names),
                         f"Expected no nvme devices, got: {storage_names}")
        nvme = next(item for item in profile["capability_candidates"] if item["id"] == "storage.nvme")
        self.assertEqual(nvme["state"], "not_present")
        self.assertIsNone(nvme["candidate"])

    def test_failed_pci_probe_preserves_probe_failed_gpu_state(self) -> None:
        raw = self._load("failed-probe.json")
        raw["collection"]["missing_tools"] = [
            name for name in raw["collection"]["missing_tools"] if name != "lspci"
        ]
        raw["pci"]["state"] = "probe_failed"
        raw["gpu"]["state"] = "probe_failed"
        profile = system_profile.build_profile(raw, "test")
        system_profile.validate_profile(profile)
        self.assertEqual(profile["gpus"][0]["state"], "probe_failed")
        self.assertIsNone(profile["gpus"][0]["architecture"])
        gpu = next(item for item in profile["capability_candidates"] if item["id"] == "gpu.rocm")
        self.assertEqual(gpu["state"], "probe_failed")
        self.assertIsNone(gpu["candidate"])

    def test_non_xdna_accelerator_does_not_set_npu_present(self) -> None:
        raw = self._load("accelerator-non-xdna.json")
        profile = system_profile.build_profile(raw, "test")
        system_profile.validate_profile(profile)
        observed_accels = [a for a in profile["accelerators"] if a.get("state") == "observed"]
        self.assertFalse(observed_accels,
                         "Non-AMD/XDNA accelerator must not produce an observed accelerator entry")


if __name__ == "__main__":
    unittest.main()
