#!/usr/bin/env python3
"""Adapter for declarative Ryzen AI hardware profiles.

One platform architecture (``ryzen-ai-linux``) owns every profile. AI370 /
Strix Point and Ryzen AI Halo / Strix Halo are separate hardware profiles of
that platform. This module loads match rules, capability expectations,
provider names, and optimization-profile names. It does not probe hardware,
install runtimes, or apply tuning.
"""

from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CATALOG_PATH = PROJECT_ROOT / "configs/profiles/hardware-profiles.json"
TUNING_DIR = PROJECT_ROOT / "configs/tuning"
_PROFILE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
_MODE_PROFILES = frozenset({"safe", "aggressive"})
_MATCH_KEYS = ("id", "confidence", "priority", "description", "requires", "requires_if_known", "optional")


class HardwareProfileError(ValueError):
    """Raised when the declarative hardware-profile catalog is invalid."""


def _require_profile_id(value: str, label: str) -> str:
    if not _PROFILE_ID.fullmatch(value):
        raise HardwareProfileError(f"{label} is not a safe profile id: {value!r}")
    return value


@lru_cache(maxsize=1)
def load_catalog() -> dict[str, Any]:
    """Load and validate the hardware-profile catalog."""
    try:
        document = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise HardwareProfileError(f"Cannot read {CATALOG_PATH}: {exc}") from exc
    if document.get("schema_version") != 1:
        raise HardwareProfileError("hardware-profiles.json schema_version must be 1")
    architecture = document.get("platform_architecture") or {}
    architecture_id = str(architecture.get("id") or "")
    _require_profile_id(architecture_id, "platform_architecture.id")
    profiles = document.get("profiles")
    if not isinstance(profiles, list) or not profiles:
        raise HardwareProfileError("hardware-profiles.json requires a profiles list")
    seen: set[str] = set()
    aliases: dict[str, str] = {}
    for profile in profiles:
        if not isinstance(profile, dict):
            raise HardwareProfileError("each hardware profile must be an object")
        profile_id = _require_profile_id(str(profile.get("id") or ""), "profile.id")
        if profile_id in seen:
            raise HardwareProfileError(f"duplicate hardware profile id {profile_id}")
        seen.add(profile_id)
        if profile.get("platform_architecture") != architecture_id:
            raise HardwareProfileError(
                f"{profile_id} must use platform architecture {architecture_id}"
            )
        for key in ("confidence", "priority", "description", "requires", "capabilities", "providers"):
            if key not in profile:
                raise HardwareProfileError(f"{profile_id} is missing {key}")
        overlay = str(profile.get("optimization_profile") or "")
        if overlay:
            _require_profile_id(overlay, f"{profile_id} optimization_profile")
            if not (TUNING_DIR / f"{overlay}.env").is_file():
                raise HardwareProfileError(
                    f"{profile_id} optimization profile {overlay}.env is missing"
                )
        for alias in profile.get("aliases") or []:
            alias_id = _require_profile_id(str(alias), f"{profile_id} alias")
            if alias_id in seen or alias_id in aliases:
                raise HardwareProfileError(f"duplicate hardware profile alias {alias_id}")
            aliases[alias_id] = profile_id
    document["_alias_index"] = aliases
    return document


def classification_tables() -> dict[str, Any]:
    """Return matcher tables in the shape Stage 1 classification already uses."""
    catalog = load_catalog()
    definitions: list[dict[str, Any]] = []
    for profile in catalog["profiles"]:
        definition = {key: profile[key] for key in _MATCH_KEYS if key in profile}
        definitions.append(definition)
    return {
        "platform_definitions": definitions,
        "cpu_family_profiles": list(catalog.get("cpu_family_profiles") or []),
        "cpu_family_signatures": list(catalog.get("cpu_family_signatures") or []),
        "gpu_architecture_mappings": dict(catalog.get("gpu_architecture_mappings") or {}),
        "npu_family_mappings": list(catalog.get("npu_family_mappings") or []),
    }


def profiles() -> list[dict[str, Any]]:
    """Return the declarative hardware profiles."""
    return list(load_catalog()["profiles"])


def platform_architecture_id() -> str:
    """Return the single platform architecture id shared by every profile."""
    return str(load_catalog()["platform_architecture"]["id"])


def profile_by_id(profile_id: str | None) -> dict[str, Any] | None:
    """Resolve a profile id or alias. Reject path separators."""
    if not profile_id or not _PROFILE_ID.fullmatch(str(profile_id)):
        return None
    catalog = load_catalog()
    wanted = catalog.get("_alias_index", {}).get(profile_id, profile_id)
    for profile in catalog["profiles"]:
        if profile["id"] == wanted:
            return profile
    return None


def gpu_target(profile_id: str | None) -> str:
    """Return the profile GPU arch capability, or empty when the profile has none."""
    profile = profile_by_id(profile_id)
    if not profile:
        return ""
    arch = str((profile.get("capabilities") or {}).get("gpu_arch") or "").strip()
    return arch


def providers(profile_id: str | None) -> dict[str, list[str]]:
    """Return named providers/backends for a hardware profile."""
    profile = profile_by_id(profile_id)
    if not profile:
        return {}
    raw = profile.get("providers") or {}
    return {str(kind): [str(item) for item in names] for kind, names in raw.items()}


def plan_note(profile_id: str | None) -> str | None:
    """Describe a hardware optimization overlay that S2-M5 must not apply.

    Mode files ``safe`` and ``aggressive`` stay the existing plan modes. A
    hardware-specific overlay is recorded as plan data only.
    """
    profile = profile_by_id(profile_id)
    if not profile:
        return None
    overlay = str(profile.get("optimization_profile") or "")
    if not overlay or overlay in _MODE_PROFILES:
        return None
    return (
        "Declarative optimization profile "
        f"configs/tuning/{overlay}.env is plan data for hardware profile "
        f"{profile['id']} and is not applied by S2-M5."
    )
