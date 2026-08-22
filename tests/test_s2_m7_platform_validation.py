#!/usr/bin/env python3
"""S2-M7 platform validation publisher: aggregate from fixture milestone JSONs."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/raw-probes/v1"
PROFILE_FIXTURE = ROOT / "tests/fixtures/system-profile/v3/valid-reference.json"
PUBLISH_CLI = ROOT / "scripts/s2-m7-publish-platform-validation.py"
SHIM = ROOT / "scripts/90-validate.sh"
sys.path.insert(0, str(ROOT / "scripts/lib"))
import capability_ladder  # noqa: E402
import platform_validation  # noqa: E402
import system_profile  # noqa: E402


def hardware_from_probe(name: str) -> dict:
    raw = json.loads((FIXTURES / name).read_text(encoding="utf-8"))
    return system_profile.hardware_from_input(raw)


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def write_compat_artifacts(reports_dir: Path, scope: str, *, gpu_arch: str | None, npu: bool, vulkan: str) -> None:
    for name in platform_validation.expected_compat_artifacts(scope):
        payload: dict = {"status": "PASS"}
        if name == "tier1-firmware.json":
            payload["bios_acceptable"] = "true"
        elif name == "tier1-gpu-stack.json":
            payload.update(
                {
                    "amdgpu": "loaded" if gpu_arch else "missing",
                    "gpu_arch": gpu_arch,
                    "vulkan": vulkan,
                    "opencl": "not-visible",
                    "rocm": "not-visible",
                }
            )
        elif name == "tier1-npu.json":
            payload["amdxdna"] = {"present": npu}
        write_json(reports_dir / name, payload)


def write_visibility_reports(
    reports_dir: Path,
    *,
    profile: dict | None,
    gpu_checks: dict,
    npu_checks: dict | None,
    probe_name: str = "observed-ai370.json",
) -> None:
    hardware = hardware_from_probe(probe_name)
    consumed = capability_ladder.consumed_profile_from_system_profile(profile)
    gpu_report = capability_ladder.build_s2_m3_visibility_report(hardware, gpu_checks, consumed)
    write_json(reports_dir / "s2-m3-gpu-runtime-visibility.json", gpu_report)
    if npu_checks is not None:
        npu_report = capability_ladder.build_s2_m4_visibility_report(hardware, npu_checks, consumed)
        write_json(reports_dir / "s2-m4-npu-runtime-validation.json", npu_report)


class Stage2PlatformValidationTests(unittest.TestCase):
    def publish_cli(
        self,
        reports_dir: Path,
        output: Path,
        *,
        profile_path: Path | None,
        scope: str = "full",
        strict: str = "false",
        cli_profile: str = "ai370",
        compat_output: Path | None = None,
    ) -> subprocess.CompletedProcess[str]:
        command = [
            "python3",
            str(PUBLISH_CLI),
            "--reports-dir",
            str(reports_dir),
            "--output",
            str(output),
            "--scope",
            scope,
            "--strict",
            strict,
            "--cli-profile",
            cli_profile,
        ]
        if profile_path is not None:
            command.extend(["--profile", str(profile_path)])
        if compat_output is not None:
            command.extend(["--compat-output", str(compat_output)])
        return subprocess.run(command, capture_output=True, text=True)

    def seed_reference_dir(self, reports_dir: Path, scope: str = "full") -> Path:
        profile_path = reports_dir / "s1-m5-system-profile.json"
        shutil.copyfile(PROFILE_FIXTURE, profile_path)
        profile = json.loads(profile_path.read_text(encoding="utf-8"))
        write_compat_artifacts(
            reports_dir, scope, gpu_arch="gfx1150", npu=True, vulkan="visible"
        )
        write_visibility_reports(
            reports_dir,
            profile=profile,
            gpu_checks={
                "vulkan": "visible",
                "rocm": "visible",
                "opencl": "visible",
                "gpu_arch": "gfx1150",
            },
            npu_checks={
                "module_present": True,
                "device_nodes_present": True,
                "firmware_ready": True,
                "runtime_ready": True,
                "backend_ready": True,
            },
        )
        return profile_path

    def test_publisher_aggregates_fixture_milestone_jsons(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            reports_dir = Path(directory)
            profile_path = self.seed_reference_dir(reports_dir)
            output = reports_dir / "s2-m7-platform-validation.json"
            result = self.publish_cli(reports_dir, output, profile_path=profile_path)
            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads(output.read_text(encoding="utf-8"))
            system_profile.validate_document(
                report, platform_validation.S2_M7_SCHEMA, "S2-M7"
            )
            self.assertEqual(report["milestone"], "S2-M7")
            self.assertEqual(report["artifact"], "s2-m7-platform-validation")
            self.assertEqual(report["status"], "PASS")
            self.assertTrue(report["acceptance"]["radeon_890m_gfx1150"])
            self.assertTrue(report["acceptance"]["amdxdna_npu"])
            self.assertTrue(report["acceptance"]["vulkan_validated"])
            self.assertEqual(report["checks"]["gpu_arch"], "gfx1150")
            self.assertEqual(
                report["consumed_profile"]["fingerprint"]["value"],
                json.loads(PROFILE_FIXTURE.read_text(encoding="utf-8"))["fingerprint"]["value"],
            )
            by_id = {entry["id"]: entry for entry in report["milestones"]}
            self.assertTrue(by_id["S2-M3"]["canonical"])
            self.assertTrue(by_id["S2-M4"]["canonical"])
            self.assertEqual(by_id["S2-M3"]["artifact"], "s2-m3-gpu-runtime-visibility.json")

    def test_non_strict_acceptance_miss_keeps_pass(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            reports_dir = Path(directory)
            write_compat_artifacts(
                reports_dir, "full", gpu_arch="unknown", npu=False, vulkan="visible"
            )
            output = reports_dir / "report.json"
            result = self.publish_cli(reports_dir, output, profile_path=None, strict="false")
            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads(output.read_text(encoding="utf-8"))
            system_profile.validate_document(
                report, platform_validation.S2_M7_SCHEMA, "S2-M7"
            )
            self.assertEqual(report["status"], "PASS")
            self.assertFalse(report["acceptance"]["radeon_890m_gfx1150"])
            self.assertFalse(report["acceptance"]["amdxdna_npu"])
            self.assertTrue(report["warnings"])
            self.assertFalse(report["failures"])
            self.assertIsNone(report["consumed_profile"]["fingerprint"]["value"])

    def test_strict_mode_fails_missing_gfx1150_and_npu(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            reports_dir = Path(directory)
            write_compat_artifacts(
                reports_dir, "full", gpu_arch="unknown", npu=False, vulkan="visible"
            )
            output = reports_dir / "report.json"
            result = self.publish_cli(reports_dir, output, profile_path=None, strict="true")
            self.assertEqual(result.returncode, 3, result.stderr)
            report = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(report["status"], "FAIL")
            self.assertTrue(report["strict"])
            self.assertTrue(report["failures"])
            self.assertIn("strict", " ".join(report["failures"]))

    def test_facts_come_from_profile_not_host_probe(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            reports_dir = Path(directory)
            profile_path = reports_dir / "s1-m5-system-profile.json"
            shutil.copyfile(PROFILE_FIXTURE, profile_path)
            write_compat_artifacts(
                reports_dir, "full", gpu_arch=None, npu=False, vulkan="not-visible"
            )
            output = reports_dir / "report.json"
            result = self.publish_cli(
                reports_dir, output, profile_path=profile_path, strict="false"
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(report["checks"]["gpu_arch"], "gfx1150")
            self.assertTrue(report["checks"]["npu_present"])
            self.assertTrue(report["acceptance"]["radeon_890m_gfx1150"])
            self.assertTrue(report["acceptance"]["amdxdna_npu"])
            self.assertEqual(report["classified_platform_id"], "ai370")

    def test_inventory_skips_tuning_and_npu_canonical(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            reports_dir = Path(directory)
            write_compat_artifacts(
                reports_dir, "inventory", gpu_arch="gfx1150", npu=True, vulkan="visible"
            )
            output = reports_dir / "report.json"
            result = self.publish_cli(
                reports_dir, output, profile_path=None, scope="inventory"
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads(output.read_text(encoding="utf-8"))
            by_id = {entry["id"]: entry for entry in report["milestones"]}
            self.assertEqual(by_id["S2-M4"]["status"], "SKIPPED")
            self.assertEqual(by_id["S2-M5"]["status"], "SKIPPED")
            self.assertTrue(report["acceptance"]["inventory_only"])
            self.assertIsNone(report["artifacts"]["platform_tuning"])
            self.assertFalse(report["acceptance"]["ai_smoke_required"])

    def test_compat_json_preserves_require_tier123_pass_shape(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            reports_dir = Path(directory)
            profile_path = self.seed_reference_dir(reports_dir)
            output = reports_dir / "s2-m7-platform-validation.json"
            compat = reports_dir / "tier1-validation.json"
            result = self.publish_cli(
                reports_dir,
                output,
                profile_path=profile_path,
                compat_output=compat,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            data = json.loads(compat.read_text(encoding="utf-8"))
            self.assertEqual(data["tier"], 1)
            self.assertEqual(data["status"], "PASS")
            self.assertIn("radeon_890m_gfx1150", data["acceptance"])
            self.assertIn("amdxdna_npu", data["acceptance"])
            self.assertEqual(data["canonical_artifact"], "reports/latest/s2-m7-platform-validation.json")

    def test_invalid_report_does_not_replace_last_valid_publication(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            reports_dir = Path(directory)
            profile_path = self.seed_reference_dir(reports_dir)
            valid = platform_validation.build_s2_m7_platform_validation_report(
                reports_dir,
                profile=json.loads(profile_path.read_text(encoding="utf-8")),
            )
            invalid = json.loads(json.dumps(valid))
            invalid["stage"] = 1
            destination = reports_dir / "s2-m7-platform-validation.json"
            system_profile.atomic_write_document(
                destination, valid, platform_validation.S2_M7_SCHEMA, "S2-M7"
            )
            before = destination.read_bytes()
            with self.assertRaises(system_profile.ProfileValidationError):
                system_profile.atomic_write_document(
                    destination, invalid, platform_validation.S2_M7_SCHEMA, "S2-M7"
                )
            self.assertEqual(destination.read_bytes(), before)

    def test_child_unsupported_does_not_fail_aggregate(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            reports_dir = Path(directory)
            write_compat_artifacts(
                reports_dir, "full", gpu_arch="unknown", npu=False, vulkan="not-visible"
            )
            write_visibility_reports(
                reports_dir,
                profile=None,
                gpu_checks={
                    "amdgpu": "missing",
                    "gpu_arch": None,
                    "vulkan": "not-visible",
                    "opencl": "not-visible",
                    "rocm": "not-visible",
                },
                npu_checks={
                    "module_present": False,
                    "device_nodes_present": False,
                    "firmware_ready": False,
                    "runtime_ready": False,
                    "backend_ready": False,
                },
                probe_name="unsupported-host.json",
            )
            output = reports_dir / "report.json"
            result = self.publish_cli(reports_dir, output, profile_path=None)
            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads(output.read_text(encoding="utf-8"))
            by_id = {entry["id"]: entry for entry in report["milestones"]}
            self.assertIn(by_id["S2-M3"]["status"], {"WARN", "UNSUPPORTED"})
            self.assertNotEqual(report["status"], "FAIL")

    def test_shim_script_does_not_live_redetect(self) -> None:
        text = SHIM.read_text(encoding="utf-8")
        self.assertNotIn("hardware-detect.sh", text)
        self.assertNotIn("detect_gpu_arch", text)
        self.assertNotIn("detect_npu_present", text)
        self.assertNotIn("vulkaninfo", text)
        self.assertIn("s2-m7-publish-platform-validation.py", text)
        self.assertIn("stage2-platform-validate", text)
        self.assertIn("stage2-platform-inventory", text)

    def test_shim_script_writes_canonical_and_compat(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            reports_dir = Path(directory)
            self.seed_reference_dir(reports_dir)
            env = os.environ.copy()
            env["AI370_REPORTS_DIR"] = str(reports_dir)
            env["AI370_STAGE1_STRICT"] = "false"
            result = subprocess.run(
                ["bash", str(SHIM), "ai370", "safe", "runtime", "full"],
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            canonical = json.loads(
                (reports_dir / "s2-m7-platform-validation.json").read_text(encoding="utf-8")
            )
            compat = json.loads((reports_dir / "tier1-validation.json").read_text(encoding="utf-8"))
            system_profile.validate_document(
                canonical, platform_validation.S2_M7_SCHEMA, "S2-M7"
            )
            self.assertEqual(compat["tier"], 1)
            self.assertEqual(compat["status"], canonical["status"])
            self.assertTrue((reports_dir / "tier1-summary.md").is_file())
            self.assertEqual(
                (reports_dir / "tier1-validation.txt").read_text(encoding="utf-8").strip(),
                canonical["status"],
            )


if __name__ == "__main__":
    unittest.main()
