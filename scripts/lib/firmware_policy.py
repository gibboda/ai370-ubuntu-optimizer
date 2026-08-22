"""BIOS facts from Stage 1 and policy from the classified platform.

Stage 2 firmware results must consume ``s1-m5-system-profile.json`` so the
verdict is tied to detected hardware (schema version + fingerprint) rather than
``--profile`` alone. Identity facts and policy verdicts stay separate.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import capability_ladder
import system_profile

PROJECT_ROOT = Path(__file__).resolve().parents[2]
PROFILES_DIR = PROJECT_ROOT / "configs/profiles"
SYSTEM_PROFILE_ARTIFACT = "s1-m5-system-profile.json"
S2_M1_SCHEMA = PROJECT_ROOT / "configs/schemas/s2-m1-firmware-validation.schema.json"
S2_M1_ARTIFACT = "s2-m1-firmware-validation"
COMPAT_RELATIVE = "reports/latest"


def load_system_profile(path: Path) -> dict[str, Any]:
    """Load and return a Stage 1 system profile document."""
    if not path.is_file():
        raise FileNotFoundError(
            f"Stage 2 requires the canonical Stage 1 profile {path}. "
            "Run ./ai370-optimize.sh stage1 first."
        )
    return json.loads(path.read_text(encoding="utf-8"))


def classified_platform_id(profile: dict[str, Any]) -> str | None:
    """Return classification.platform_id, or None when unset/unknown."""
    classification = profile.get("classification") or {}
    value = classification.get("platform_id")
    if value is None:
        return None
    text = str(value).strip()
    if not text or text.lower() in {"unknown", "none", "null"}:
        return None
    return text


def expected_bios_version(
    platform_id: str | None,
    *,
    profiles_dir: Path = PROFILES_DIR,
) -> str:
    """Read EXPECTED_BIOS_VERSION from configs/profiles/<platform_id>.env."""
    if not platform_id or "/" in platform_id or "\\" in platform_id:
        return ""
    env_path = profiles_dir / f"{platform_id}.env"
    if not env_path.is_file():
        return ""
    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if not line.startswith("EXPECTED_BIOS_VERSION="):
            continue
        value = line.split("=", 1)[1].strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
            value = value[1:-1]
        return value
    return ""


def observed_text(value: Any) -> str | None:
    """Return a usable observation string, or None when missing/unknown."""
    if value is None:
        return None
    text = str(value).strip()
    if not text or text.lower() in {"unknown", "none", "null"}:
        return None
    return text


def bios_acceptable(observed: str | None, expected: str) -> str:
    """Return true/false/unknown for observed BIOS vs platform policy."""
    expected_text = (expected or "").strip()
    observed_text_value = (observed or "").strip()
    if not expected_text or not observed_text_value:
        return "unknown"
    if (
        observed_text_value == expected_text
        or expected_text in observed_text_value
    ):
        return "true"
    return "false"


def firmware_facts(profile: dict[str, Any]) -> dict[str, str | None]:
    """BIOS and system identity facts from the consumed Stage 1 profile."""
    firmware = profile.get("firmware") or {}
    system = profile.get("system") or {}
    return {
        "bios_version": observed_text(firmware.get("bios_version")),
        "bios_date": observed_text(firmware.get("bios_date")),
        "bios_vendor": observed_text(firmware.get("bios_vendor")),
        "system_vendor": observed_text(system.get("manufacturer")),
        "system_product": observed_text(system.get("product")),
    }


def display_or_unknown(value: str | None) -> str:
    return value if value else "unknown"


def consumed_profile_block(profile: dict[str, Any]) -> dict[str, Any]:
    """Schema version + hardware fingerprint for Stage 2 firmware reports."""
    return capability_ladder.consumed_profile_from_system_profile(profile)


def build_firmware_baseline(
    profile: dict[str, Any],
    *,
    selected_profile: str,
    timestamp: str,
    fwupd_devices_present: bool,
) -> dict[str, Any]:
    """Build the compatibility tier1-firmware.json document."""
    platform_id = classified_platform_id(profile)
    expected = expected_bios_version(platform_id)
    facts = firmware_facts(profile)
    acceptable = bios_acceptable(facts["bios_version"], expected)
    return {
        "tier": 1,
        "phase": "check-firmware-baseline",
        "timestamp": timestamp,
        "profile": selected_profile,
        "classified_platform_id": platform_id,
        "bios_version": display_or_unknown(facts["bios_version"]),
        "bios_date": display_or_unknown(facts["bios_date"]),
        "bios_vendor": display_or_unknown(facts["bios_vendor"]),
        "bios_expected": expected,
        "bios_acceptable": acceptable,
        "policy_source": (
            f"configs/profiles/{platform_id}.env" if platform_id else None
        ),
        "system": {
            "vendor": display_or_unknown(facts["system_vendor"]),
            "product": display_or_unknown(facts["system_product"]),
        },
        "fwupd": {"devices_present": fwupd_devices_present},
        "consumed_profile": consumed_profile_block(profile),
        "canonical_artifact": f"{COMPAT_RELATIVE}/s2-m1-firmware-validation.json",
    }


def firmware_policy_verdict(
    profile: dict[str, Any],
    facts: dict[str, str | None],
) -> dict[str, Any]:
    """Classified-platform BIOS policy. Does not copy identity facts."""
    platform_id = classified_platform_id(profile)
    expected = expected_bios_version(platform_id)
    return {
        "source": f"configs/profiles/{platform_id}.env" if platform_id else None,
        "bios_expected": expected,
        "bios_acceptable": bios_acceptable(facts.get("bios_version"), expected),
    }


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _normalize_checks(checks: dict[str, Any] | None) -> dict[str, Any]:
    payload = checks if isinstance(checks, dict) else {}
    fwupdmgr_status = str(payload.get("fwupdmgr_status") or "unknown")
    if fwupdmgr_status not in {"available", "missing", "unknown"}:
        fwupdmgr_status = "unknown"
    packages = payload.get("microcode_packages") or []
    if not isinstance(packages, list):
        packages = []
    warnings = payload.get("warnings") or []
    if not isinstance(warnings, list):
        warnings = []
    return {
        "fwupdmgr_status": fwupdmgr_status,
        "fwupd_version_output": [
            str(item) for item in (payload.get("fwupd_version_output") or []) if str(item).strip()
        ],
        "fwupd_devices_visible": bool(payload.get("fwupd_devices_visible")),
        "linux_firmware_version": str(payload.get("linux_firmware_version") or "") or "unknown",
        "firmware_root_present": bool(payload.get("firmware_root_present")),
        "kernel_firmware_dir": str(payload.get("kernel_firmware_dir") or "unknown"),
        "secure_boot_state": str(payload.get("secure_boot_state") or "unknown"),
        "microcode_packages": [str(item) for item in packages if str(item).strip()],
        "warnings": [str(item) for item in warnings if str(item).strip()],
    }


def build_s2_m1_firmware_validation(
    profile: dict[str, Any],
    *,
    checks: dict[str, Any] | None = None,
    cli_profile: str = "ai370",
) -> dict[str, Any]:
    """Build canonical S2-M1 JSON with separate facts and policy objects."""
    identity = firmware_facts(profile)
    policy = firmware_policy_verdict(profile, identity)
    live = _normalize_checks(checks)
    warnings = list(live["warnings"])
    if policy["bios_acceptable"] == "false":
        expected = policy["bios_expected"] or "unknown"
        observed = display_or_unknown(identity["bios_version"])
        warnings.append(
            f"Observed BIOS {observed} does not match classified-platform target {expected}."
        )
    status = "WARN" if warnings else "PASS"
    classified = classified_platform_id(profile)
    return {
        "schema": {
            "name": "s2-m1-firmware-validation",
            "version": 1,
            "uri": "https://ai370.local/schemas/s2-m1-firmware-validation-v1.json",
        },
        "stage": 2,
        "milestone": "S2-M1",
        "artifact": S2_M1_ARTIFACT,
        "consumed_profile": consumed_profile_block(profile),
        "status": status,
        "cli_profile": cli_profile,
        "classified_platform_id": classified,
        "facts": {
            "bios": {
                "version": display_or_unknown(identity["bios_version"]),
                "date": display_or_unknown(identity["bios_date"]),
                "vendor": display_or_unknown(identity["bios_vendor"]),
                "identity_source": "s1-m5-system-profile",
            },
            "system": {
                "vendor": display_or_unknown(identity["system_vendor"]),
                "product": display_or_unknown(identity["system_product"]),
                "identity_source": "s1-m5-system-profile",
            },
            "fwupd": {
                "status": live["fwupdmgr_status"],
                "devices_visible": live["fwupd_devices_visible"],
            },
            "linux_firmware": {
                "package_version": live["linux_firmware_version"],
                "firmware_root_present": live["firmware_root_present"],
                "kernel_firmware_dir": live["kernel_firmware_dir"],
            },
            "secure_boot": {"state": live["secure_boot_state"]},
            "microcode": {"packages": live["microcode_packages"]},
        },
        "policy": policy,
        "warnings": warnings,
        "notes": [
            "S2-M1 is validation-only. It never flashes firmware or changes Secure Boot.",
            "BIOS identity facts come from the consumed Stage 1 profile.",
            "BIOS policy uses classified platform_id, not CLI --profile alone.",
            "Supplemental fwupd, linux-firmware, microcode, and Secure Boot checks are live.",
        ],
        "compatibility_reports": [
            "tier1-firmware.json",
            "tier1-firmware.md",
            "tier1-firmware-validation.json",
            "tier1-firmware-validation.md",
        ],
    }


def compat_tier1_firmware_validation(
    report: dict[str, Any],
    *,
    checks: dict[str, Any] | None = None,
    timestamp: str | None = None,
) -> dict[str, Any]:
    """Compatibility tier1-firmware-validation.json until R1."""
    live = _normalize_checks(checks)
    facts = report["facts"]
    return {
        "tier": 1,
        "phase": "check-firmware",
        "timestamp": timestamp or _utc_now(),
        "profile": report["cli_profile"],
        "classified_platform_id": report["classified_platform_id"],
        "status": report["status"],
        "checks": {
            "fwupdmgr": {
                "status": facts["fwupd"]["status"],
                "version_output": live["fwupd_version_output"],
                "devices_visible": facts["fwupd"]["devices_visible"],
            },
            "linux_firmware": {
                "package_version": facts["linux_firmware"]["package_version"],
                "firmware_root_present": facts["linux_firmware"]["firmware_root_present"],
                "kernel_firmware_dir": facts["linux_firmware"]["kernel_firmware_dir"],
            },
            "secure_boot": {"state": facts["secure_boot"]["state"]},
            "microcode": {"packages": facts["microcode"]["packages"]},
        },
        "warnings": list(report["warnings"]),
        "consumed_profile": report["consumed_profile"],
        "canonical_artifact": f"{COMPAT_RELATIVE}/s2-m1-firmware-validation.json",
    }


def publish_s2_m1_firmware_validation(
    output: Path,
    report: dict[str, Any],
    *,
    profile: dict[str, Any],
    checks: dict[str, Any] | None = None,
    compat_baseline: Path | None = None,
    compat_validation: Path | None = None,
) -> dict[str, Any]:
    """Validate and atomically publish the S2-M1 report plus compatibility JSON."""
    system_profile.atomic_write_document(output, report, S2_M1_SCHEMA, "S2-M1")
    if compat_baseline is not None:
        system_profile.atomic_write_text(
            compat_baseline,
            json.dumps(
                build_firmware_baseline(
                    profile,
                    selected_profile=report["cli_profile"],
                    timestamp=_utc_now(),
                    fwupd_devices_present=report["facts"]["fwupd"]["devices_visible"],
                ),
                indent=2,
            )
            + "\n",
        )
    if compat_validation is not None:
        system_profile.atomic_write_text(
            compat_validation,
            json.dumps(
                compat_tier1_firmware_validation(report, checks=checks),
                indent=2,
            )
            + "\n",
        )
    return report
