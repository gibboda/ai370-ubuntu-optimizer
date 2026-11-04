"""S2-M2 kernel and driver validation report.

This builder records kernel, OS, module, and AMDGPU firmware-directory
observations. It does not change kernel parameters, packages, or firmware.
"""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import firmware_policy
import system_profile

PROJECT_ROOT = Path(__file__).resolve().parents[2]
S2_M2_SCHEMA = PROJECT_ROOT / "configs/schemas/s2-m2-kernel-driver-validation.schema.json"
S2_M2_ARTIFACT = "s2-m2-kernel-driver-validation"
SUPPORT_MATRIX = PROJECT_ROOT / "configs/profiles/kernel-driver-support-matrix.json"
COMPAT_RELATIVE = "reports/latest"


def load_support_matrix(path: Path = SUPPORT_MATRIX) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _version_ge(left: str, right: str) -> bool:
    import re

    def parts(value: str) -> list[int]:
        return [int(x) for x in re.findall(r"\d+", value)[:3]]

    left_parts = parts(left) + [0, 0, 0]
    right_parts = parts(right) + [0, 0, 0]
    left_parts = left_parts[:3]
    right_parts = right_parts[:3]
    return left_parts >= right_parts


def evaluate_support_matrix(
    facts: dict[str, Any],
    *,
    classified_platform_id: str | None,
    profile: dict[str, Any] | None = None,
    matrix: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Evaluate declarative kernel/driver support; returns codes and tier."""
    data = matrix or load_support_matrix()
    overlay = (data.get("classified_platform_overlays") or {}).get(classified_platform_id or "")
    minimum_kernel = str(
        (overlay or {}).get("minimum_kernel")
        or data.get("minimum_kernel_default")
        or "6.11"
    )
    kernel_version = str(facts.get("kernel") or "")
    kernel_ok = facts.get("kernel_ok")
    os_version = str(facts.get("os_version") or "")
    os_codename = str(facts.get("os_codename") or "").lower()
    codes: list[str] = []
    tier = "unknown"
    for entry in data.get("os_support") or []:
        version_ids = [str(item) for item in (entry.get("version_ids") or [])]
        codenames = [str(item).lower() for item in (entry.get("codenames") or [])]
        if os_version in version_ids or os_codename in codenames:
            tier = str(entry.get("tier") or "unknown")
            if tier == "unsupported" and entry.get("code"):
                codes.append(str(entry["code"]))
            break
    if kernel_version and not _version_ge(kernel_version, minimum_kernel):
        codes.append("kernel-below-minimum")
    elif kernel_ok is False:
        codes.append("kernel-below-minimum")
    gpu_present = bool((profile or {}).get("gpus"))
    accelerators = (profile or {}).get("accelerators") or []
    npu_present = any(
        isinstance(item, dict) and str(item.get("kind") or "").lower() == "npu"
        for item in accelerators
    )
    module_rules = data.get("module_expectations") or {}
    amdgpu_ok = facts.get("amdgpu_ok")
    if gpu_present:
        rule = module_rules.get("amdgpu") or {}
        if amdgpu_ok is False and rule.get("code_missing"):
            codes.append(str(rule["code_missing"]))
        elif amdgpu_ok is None and rule.get("code_unknown"):
            codes.append(str(rule["code_unknown"]))
    amdxdna_seen = facts.get("amdxdna_seen")
    if npu_present:
        rule = module_rules.get("amdxdna") or {}
        if amdxdna_seen is False and rule.get("code_missing"):
            codes.append(str(rule["code_missing"]))
    firmware_state = str(facts.get("linux_firmware_state") or "unknown")
    fw_rules = (data.get("firmware_expectations") or {}).get("amdgpu_directory") or {}
    if gpu_present and firmware_state == "missing" and fw_rules.get("code_missing"):
        codes.append(str(fw_rules["code_missing"]))
    return {
        "matrix_version": data.get("schema_version", 1),
        "minimum_kernel": minimum_kernel,
        "os_tier": tier,
        "codes": codes,
        "classified_platform_id": classified_platform_id,
    }


def _utc_now() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def _bool_or_none(value: Any) -> bool | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return value
    text = str(value).strip().lower()
    if text in {"true", "1", "yes", "on"}:
        return True
    if text in {"false", "0", "no", "off"}:
        return False
    return None


def build_s2_m2_kernel_driver_validation(
    profile: dict[str, Any],
    *,
    facts: dict[str, Any],
    cli_profile: str = "ai370",
    mode: str = "safe",
    persistence: str = "runtime",
    dry_run: bool = False,
) -> dict[str, Any]:
    """Build the canonical S2-M2 kernel/driver validation document."""
    recommendations = [
        str(item) for item in (facts.get("recommendations") or []) if str(item).strip()
    ]
    warnings = [str(item) for item in (facts.get("warnings") or []) if str(item).strip()]
    kernel_ok = _bool_or_none(facts.get("kernel_ok"))
    amdgpu_ok = _bool_or_none(facts.get("amdgpu_ok"))
    amdxdna_seen = _bool_or_none(facts.get("amdxdna_seen"))
    firmware_state = str(facts.get("linux_firmware_state") or "unknown")
    if firmware_state not in {"present", "missing", "unknown"}:
        firmware_state = "unknown"
    status = str(facts.get("status") or "").strip().upper()
    if status not in {"PASS", "WARN", "FAIL", "UNSUPPORTED", "SKIPPED"}:
        status = "WARN"
        if kernel_ok is True and amdgpu_ok is True and firmware_state == "present":
            status = "PASS"
        elif kernel_ok is False or amdgpu_ok is False or firmware_state == "missing":
            status = "WARN"
        elif amdgpu_ok is None:
            status = "WARN"
    if status == "WARN" and not warnings and recommendations:
        warnings = list(recommendations)
    classified = firmware_policy.classified_platform_id(profile)
    support = evaluate_support_matrix(
        facts,
        classified_platform_id=classified,
        profile=profile,
    )
    for code in support["codes"]:
        message = f"Support matrix: {code}"
        if message not in warnings:
            warnings.append(message)
    if support["os_tier"] == "unsupported" and status == "PASS":
        status = "WARN"
    return {
        "schema": {
            "name": "s2-m2-kernel-driver-validation",
            "version": 1,
            "uri": "https://ai370.local/schemas/s2-m2-kernel-driver-validation-v1.json",
        },
        "stage": 2,
        "milestone": "S2-M2",
        "artifact": S2_M2_ARTIFACT,
        "consumed_profile": firmware_policy.consumed_profile_block(profile),
        "status": status,
        "cli_profile": cli_profile,
        "classified_platform_id": classified,
        "support_assessment": support,
        "mode": mode,
        "persistence": persistence,
        "dry_run": dry_run,
        "kernel": {
            "version": str(facts.get("kernel") or "unknown"),
            "target_minimum": str(facts.get("target_kernel") or "6.11"),
            "acceptable": kernel_ok,
        },
        "os": {
            "description": str(facts.get("os_description") or "unknown"),
            "version_id": str(facts.get("os_version") or "unknown"),
            "codename": str(facts.get("os_codename") or "unknown"),
        },
        "modules": {
            "amdgpu_loaded": amdgpu_ok,
            "amdxdna_seen": amdxdna_seen,
        },
        "firmware": {"amdgpu_directory": firmware_state},
        "recommendations": recommendations,
        "warnings": warnings,
        "notes": [
            "S2-M2 is validation-only. It does not change kernel parameters, packages, or firmware.",
            "Kernel and module observations are live; the Stage 1 profile binds classified identity.",
        ],
        "compatibility_reports": [
            "tier1-kernel-plan.json",
            "tier1-kernel-plan.md",
            "tier1-kernel-plan.txt",
        ],
    }


def compat_tier1_kernel_plan(
    report: dict[str, Any],
    *,
    timestamp: str | None = None,
) -> dict[str, Any]:
    """Compatibility tier1-kernel-plan.json until R1."""
    return {
        "tier": 1,
        "phase": "validate-kernel",
        "timestamp": timestamp or _utc_now(),
        "profile": report["cli_profile"],
        "classified_platform_id": report["classified_platform_id"],
        "mode": report["mode"],
        "persistence": report["persistence"],
        "dry_run": report["dry_run"],
        "status": report["status"],
        "kernel": dict(report["kernel"]),
        "os": dict(report["os"]),
        "modules": dict(report["modules"]),
        "firmware": dict(report["firmware"]),
        "recommendations": list(report["recommendations"]),
        "consumed_profile": report["consumed_profile"],
        "canonical_artifact": f"{COMPAT_RELATIVE}/s2-m2-kernel-driver-validation.json",
    }


def publish_s2_m2_kernel_driver_validation(
    output: Path,
    report: dict[str, Any],
    *,
    compat_output: Path | None = None,
) -> dict[str, Any]:
    """Validate and atomically publish the S2-M2 report plus compatibility JSON."""
    system_profile.atomic_write_document(output, report, S2_M2_SCHEMA, "S2-M2")
    if compat_output is not None:
        system_profile.atomic_write_text(
            compat_output,
            json.dumps(compat_tier1_kernel_plan(report), indent=2) + "\n",
        )
    return report
