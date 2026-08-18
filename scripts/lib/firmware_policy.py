"""BIOS policy from the classified Stage 1 platform, not the CLI profile name.

Stage 2 firmware results must consume ``s1-m5-system-profile.json`` so the
verdict is tied to detected hardware (schema version + fingerprint) rather than
``--profile`` alone.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import capability_ladder

PROJECT_ROOT = Path(__file__).resolve().parents[2]
PROFILES_DIR = PROJECT_ROOT / "configs/profiles"
SYSTEM_PROFILE_ARTIFACT = "s1-m5-system-profile.json"


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
    }
