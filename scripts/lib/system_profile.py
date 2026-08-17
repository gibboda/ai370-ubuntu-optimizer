#!/usr/bin/env python3
"""Normalize, classify, derive candidates, and atomically publish the Stage 1 profile."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import tempfile
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


SCHEMA_NAME = "ai370-system-profile"
SCHEMA_VERSION = 3
SCHEMA_URI = "https://ai370.local/schemas/system-profile-v3.json"
FINGERPRINT_ALGORITHM_VERSION = 1
PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SCHEMA = PROJECT_ROOT / "configs/schemas/system-profile.schema.json"
S1_M2_SCHEMA = PROJECT_ROOT / "configs/schemas/s1-m2-normalized-facts.schema.json"
S1_M3_SCHEMA = PROJECT_ROOT / "configs/schemas/s1-m3-platform-classification.schema.json"
S1_M4_SCHEMA = PROJECT_ROOT / "configs/schemas/s1-m4-capability-candidates.schema.json"
S1_M5_SCHEMA = PROJECT_ROOT / "configs/schemas/s1-m5-system-profile.schema.json"
GPU_PCI_MAP_PATH = PROJECT_ROOT / "configs/profiles/gpu-pci-architectures.json"
RAW_INVENTORY_ARTIFACTS = frozenset({"stage1-raw-probes", "s1-m1-raw-inventory"})
_GPU_PCI_MAPPINGS: dict[str, dict[str, Any]] | None = None


class ProfileValidationError(ValueError):
    """Raised when a candidate profile violates the published contract."""


def _known(value: Any) -> bool:
    return value not in (None, "", "unknown", [], {})


def _nullable(value: Any) -> Any:
    return value if _known(value) else None


def _state(value: Any) -> str:
    return "observed" if _known(value) else "unknown"


def _identity_text(value: Any) -> str | None:
    """Normalize a human-readable hardware identity, never probe formatting."""
    if not _known(value):
        return None
    return " ".join(str(value).split()).casefold()


def _identity_id(value: Any) -> str | None:
    """Normalize hexadecimal identifiers emitted with optional 0x prefixes."""
    text = _identity_text(value)
    return text.removeprefix("0x") if text else None


def _pci_identity(device: dict[str, Any]) -> dict[str, str | None] | None:
    identity = {
        "vendor_id": _identity_id(device.get("vendor_id")),
        "device_id": _identity_id(device.get("device_id")),
        "subsystem_vendor_id": _identity_id(device.get("subsystem_vendor_id")),
        "subsystem_device_id": _identity_id(device.get("subsystem_device_id")),
    }
    return identity if identity["vendor_id"] and identity["device_id"] else None


def load_gpu_pci_architectures() -> dict[str, dict[str, Any]]:
    """Load the declarative PCI vendor:device to GPU architecture map."""
    global _GPU_PCI_MAPPINGS
    if _GPU_PCI_MAPPINGS is None:
        data = json.loads(GPU_PCI_MAP_PATH.read_text(encoding="utf-8"))
        _GPU_PCI_MAPPINGS = {str(key).lower(): value for key, value in data.get("mappings", {}).items()}
    return _GPU_PCI_MAPPINGS


def pci_architecture_key(vendor_id: Any, device_id: Any) -> str | None:
    vendor = _identity_id(vendor_id)
    device = _identity_id(device_id)
    return f"{vendor}:{device}" if vendor and device else None


def lookup_gpu_pci_mapping(vendor_id: Any, device_id: Any) -> dict[str, Any] | None:
    key = pci_architecture_key(vendor_id, device_id)
    return load_gpu_pci_architectures().get(key) if key else None


def lookup_gpu_arch_from_pci_text(text: str) -> str:
    """Return the first mapped gfx architecture from lspci -nn text, else unknown."""
    mappings = load_gpu_pci_architectures()
    for vendor, device in re.findall(r"\[([0-9a-fA-F]{4}):([0-9a-fA-F]{4})\]", text or ""):
        mapping = mappings.get(f"{vendor.lower()}:{device.lower()}")
        if mapping:
            return str(mapping["arch"])
    return "unknown"


def is_raw_inventory(data: dict[str, Any]) -> bool:
    """True when the document is an S1-M1 raw inventory, including live artifact names."""
    artifact = data.get("artifact")
    if artifact in {
        "s1-m2-normalized-facts",
        "s1-m3-platform-classification",
        "s1-m4-capability-candidates",
        "s1-m5-system-profile",
    }:
        return False
    if artifact in RAW_INVENTORY_ARTIFACTS:
        return True
    if data.get("milestone") == "S1-M1":
        return True
    return "dmi" in data and isinstance(data.get("dmi"), dict) and "cpu" in data


def _fingerprint_facts(hardware: dict[str, Any]) -> dict[str, Any]:
    """Return the versioned, normalized stable-identity fingerprint payload."""
    system, cpu = hardware.get("system", {}), hardware.get("cpu", {})
    gpu, npu, storage = hardware.get("gpu", {}), hardware.get("npu", {}), hardware.get("storage", {})
    raw_pci = hardware.get("_raw_stage1", {}).get("pci", {}).get("devices", [])
    # Build the canonical PCI identity list from raw_pci, preserving multiplicity.
    raw_identities = [identity for device in raw_pci
                      if (identity := _pci_identity(device)) is not None]
    # Filter class-specific entries (gpu, npu) that are already present in the
    # canonical raw PCI list to avoid double-counting while preserving exact
    # device counts from the authoritative source.
    raw_set = {json.dumps(identity, sort_keys=True, separators=(",", ":")) for identity in raw_identities}
    extra_identities = [
        identity for device in [*gpu.get("devices", []), *npu.get("devices", [])]
        if (identity := _pci_identity(device)) is not None
        and json.dumps(identity, sort_keys=True, separators=(",", ":")) not in raw_set
    ]
    pci_identities = [json.loads(v) for v in sorted(
        json.dumps(i, sort_keys=True, separators=(",", ":")) for i in raw_identities + extra_identities
    )]
    accelerators = [identity for device in npu.get("devices", [])
                    if (identity := _pci_identity(device)) is not None]
    # Sort deterministically while preserving multiplicity (identical accelerator
    # devices must not be collapsed to a single entry).
    accelerators = [json.loads(v) for v in sorted(
        json.dumps(identity, sort_keys=True, separators=(",", ":")) for identity in accelerators
    )]
    storage_identities = sorted({
        "|".join(filter(None, (_identity_text(device.get("model")),
                               _identity_text(device.get("serial")))))
        for device in storage.get("devices", []) if _known(device.get("serial"))
    })
    return {
        "cpu": {"vendor_id": _identity_text(cpu.get("vendor")),
                "family": _as_int(cpu.get("family")), "model": _as_int(cpu.get("cpu_model")),
                "stepping": _as_int(cpu.get("stepping")),
                "model_name": _identity_text(cpu.get("model"))},
        "dmi": {"system_manufacturer": _identity_text(system.get("vendor")),
                "system_product": _identity_text(system.get("product")),
                "system_version": _identity_text(system.get("version")),
                "board_manufacturer": _identity_text(system.get("board_vendor")),
                "board_product": _identity_text(system.get("board_product")),
                "board_version": _identity_text(system.get("board_version"))},
        "pci_devices": pci_identities,
        "accelerators": accelerators,
        "storage": storage_identities,
    }


def _bytes(value: Any) -> int | None:
    if isinstance(value, int) and not isinstance(value, bool) and value >= 0:
        return value
    # Accept both IEC (GiB, MiB, KiB) and SI (GB, MB, KB) suffixes, plus the
    # abbreviated forms emitted by `free -h` (Gi, Mi, Ki) that omit the trailing B.
    match = re.fullmatch(r"\s*([0-9]+(?:\.[0-9]+)?)\s*([KMGTPE]i?B|[KMGTPE]i)\s*", str(value), re.I)
    if not match:
        return None
    suffix = match.group(2).upper()
    # Normalise abbreviated IEC suffixes (Gi -> GiB, etc.)
    if not suffix.endswith("B"):
        suffix += "B"
    units = {"KB": 1000, "MB": 1000**2, "GB": 1000**3, "TB": 1000**4,
             "KIB": 1024, "MIB": 1024**2, "GIB": 1024**3, "TIB": 1024**4}
    multiplier = units.get(suffix)
    if multiplier is None:
        return None
    return int(float(match.group(1)) * multiplier)



def _probe_value(probe: Any) -> Any:
    if isinstance(probe, dict) and probe.get("state") == "observed":
        return probe.get("value")
    return None


def _hardware_from_raw_probes(raw: dict[str, Any]) -> dict[str, Any]:
    """Adapt the Stage 1 raw probe artifact to the profile builder input shape."""
    cpu = raw.get("cpu", {})
    dmi = raw.get("dmi", {})
    system = dmi.get("system", {})
    board = dmi.get("board") or dmi.get("motherboard") or {}
    firmware = raw.get("firmware", {})
    os_info = raw.get("os", {})
    kernel = raw.get("kernel", {})
    gpu = raw.get("gpu", {})
    accelerators = raw.get("accelerators", {})
    storage = raw.get("storage", {})
    missing_tools = raw.get("collection", {}).get("missing_tools", [])
    gpu_lines = [device.get("device_name") or device.get("class") or "" for device in gpu.get("devices", [])]
    _AMD_VENDOR_IDS = {"1022", "0x1022"}
    _XDNA_DRIVER = "amdxdna"
    accel_devices = accelerators.get("devices", [])
    accel_nodes = accelerators.get("device_nodes", [])
    _xdna_devices = [
        d for d in accel_devices
        if d.get("bound_driver") == _XDNA_DRIVER
        or str(d.get("vendor_id", "")).lower() in _AMD_VENDOR_IDS
        or "xdna" in str(d.get("device_name", "")).lower()
    ]
    _xdna_nodes = [n for n in accel_nodes if "xdna" in str(n.get("path", "")).lower()]
    npu_present = bool(_xdna_devices or _xdna_nodes)
    npu_drivers = sorted({device.get("bound_driver") for device in _xdna_devices if device.get("bound_driver")})
    npu_nodes = [node.get("path") for node in accel_nodes if node.get("path")]
    raw_arch = gpu.get("architecture", {})
    initial_arch = raw_arch.get("value") if isinstance(raw_arch, dict) else raw_arch
    return {
        "_raw_stage1": raw,
        "system": {"vendor": _probe_value(system.get("vendor")), "product": _probe_value(system.get("product")),
                   "version": _probe_value(system.get("version")), "bios_vendor": _probe_value(firmware.get("bios_vendor")),
                   "bios_version": _probe_value(firmware.get("bios_version")), "bios_date": _probe_value(firmware.get("bios_date")),
                   "uefi": firmware.get("uefi", {}).get("state", "unknown") if isinstance(firmware.get("uefi"), dict) else firmware.get("uefi", "unknown"),
                   "secure_boot": {"state": firmware.get("secure_boot", {}).get("state", "unknown") if isinstance(firmware.get("secure_boot"), dict) else "unknown",
                                   "enabled": firmware.get("secure_boot", {}).get("enabled") if isinstance(firmware.get("secure_boot"), dict) else None},
                   "os": os_info.get("pretty_name"), "os_id": os_info.get("id"), "os_name": os_info.get("name"),
                   "os_version_id": os_info.get("version_id"), "os_codename": os_info.get("version_codename"),
                   "kernel": kernel.get("release"), "kernel_architecture": kernel.get("architecture"),
                   "board_vendor": _probe_value(board.get("vendor")), "board_product": _probe_value(board.get("product")),
                   "board_version": _probe_value(board.get("version"))},
        "cpu": {"model": cpu.get("model_name"), "vendor": cpu.get("vendor_id"), "family": cpu.get("family"),
                "cpu_model": cpu.get("model"), "stepping": cpu.get("stepping"), "architecture": cpu.get("architecture"),
                "topology": cpu.get("topology", {}), "logical_cores": cpu.get("topology", {}).get("logical_processors")},
        "gpu": {"text": "\n".join(gpu_lines), "arch": initial_arch,
                "devices": gpu.get("devices", []), "amdgpu_module": "loaded" if any(d.get("bound_driver") == "amdgpu" for d in gpu.get("devices", [])) else ""},
        "npu": {"present": npu_present, "module_text": "\n".join(npu_drivers), "device_text": "\n".join(npu_nodes),
                "devices": accel_devices, "device_nodes": npu_nodes},
        "memory": {"total_bytes": raw.get("memory", {}).get("total_bytes"), "total": raw.get("memory", {}).get("total_bytes")},
        "storage": {"devices": storage.get("devices", []), "nvme": "\n".join(device.get("name", "") for device in storage.get("devices", []) if str(device.get("name", "")).startswith("nvme"))},
        "tools": {"missing": ",".join(missing_tools)},
    }


def _apply_gpu_architecture(hardware: dict[str, Any]) -> dict[str, Any]:
    """Set GPU architecture from PCI mappings. Never parse marketing names."""
    gpu = hardware.setdefault("gpu", {})
    mapped = None
    mapped_key = None
    for device in gpu.get("devices") or []:
        mapping = lookup_gpu_pci_mapping(device.get("vendor_id"), device.get("device_id"))
        if mapping:
            mapped = mapping
            mapped_key = pci_architecture_key(device.get("vendor_id"), device.get("device_id"))
            break
    if mapped:
        gpu["arch"] = mapped["arch"]
        gpu["family"] = mapped.get("family")
        gpu["architecture_source"] = f"pci:{mapped_key}"
    elif not _known(gpu.get("arch")):
        gpu["arch"] = None
        gpu.setdefault("family", None)
        gpu.setdefault("architecture_source", None)
    else:
        gpu.setdefault("architecture_source", "supplied")
        if not gpu.get("family"):
            gpu["family"] = GPU_ARCHITECTURE_MAPPINGS.get(str(gpu.get("arch")), {}).get("family")
    return hardware


def hardware_from_input(data: dict[str, Any]) -> dict[str, Any]:
    """Accept raw inventory, S1-M2 facts, or the legacy hardware test shape."""
    if data.get("artifact") == "s1-m2-normalized-facts":
        return hardware_from_normalized(data)
    if is_raw_inventory(data):
        return _apply_gpu_architecture(_hardware_from_raw_probes(data))
    return _apply_gpu_architecture(data)


def _pci() -> dict[str, None]:
    return {"address": None, "vendor_id": None, "device_id": None,
            "subsystem_vendor_id": None, "subsystem_device_id": None}



PLATFORM_DEFINITIONS: list[dict[str, Any]] = [
    {
        "id": "ai370",
        "confidence": "exact",
        "priority": 100,
        "description": "Minisforum EliteMini AI370 reference platform",
        "requires": [
            {"path": "system.product", "equals_any": ["EliteMini AI370", "AI370"]},
            {"path": "cpu.vendor", "equals_any": ["AuthenticAMD", "AMD"]},
            {"path": "cpu.model", "contains_any": ["Ryzen AI 9 HX 370"]},
        ],
        "requires_if_known": [
            {"path": "system.vendor", "equals_any": ["MINISFORUM", "Micro Computer (HK) Tech Limited"]},
        ],
        "optional": [
            {"path": "gpu.arch", "equals_any": ["gfx1150"]},
            {"path": "npu.family", "equals_any": ["xdna2"]},
        ],
    },
    {
        "id": "strix-point-ryzen-ai",
        "confidence": "family",
        "priority": 50,
        "description": "AMD Ryzen AI 300 family platform",
        "requires": [
            {"path": "cpu.vendor", "equals_any": ["AuthenticAMD", "AMD"]},
            {"path": "cpu.family_profile", "equals_any": ["ryzen-ai-300"]},
        ],
        "optional": [
            {"path": "gpu.family", "equals_any": ["rdna3.5"]},
            {"path": "npu.family", "equals_any": ["xdna2"]},
        ],
    },
    {
        "id": "generic-ryzen-ai",
        "confidence": "family",
        "priority": 10,
        "description": "Generic AMD Ryzen AI platform",
        "requires": [
            {"path": "cpu.vendor", "equals_any": ["AuthenticAMD", "AMD"]},
            {"path": "cpu.family_profile", "equals_any": ["ryzen-ai"]},
        ],
        "optional": [
            {"path": "gpu.family", "equals_any": ["rdna3.5", "unknown"]},
            {"path": "npu.family", "equals_any": ["xdna", "xdna2", "unknown"]},
        ],
    },
]

CPU_FAMILY_PROFILES: list[dict[str, Any]] = [
    {"id": "ryzen-ai", "contains_any": ["Ryzen AI"]},
]

CPU_FAMILY_SIGNATURES: list[dict[str, Any]] = [
    {"id": "ryzen-ai-300", "cpu_families": [26], "cpu_models": [36]},
]

GPU_ARCHITECTURE_MAPPINGS: dict[str, dict[str, Any]] = {
    "gfx1150": {"family": "rdna3.5", "description": "AMD RDNA 3.5 integrated GPU"},
    "gfx1151": {"family": "rdna3.5", "description": "AMD RDNA 3.5 integrated GPU alternative identifier"},
}

NPU_FAMILY_MAPPINGS: list[dict[str, Any]] = [
    {"family": "xdna2", "contains_any": ["xdna2", "ai engine v2"], "vendor_ids": ["1022", "0x1022"],
     "device_ids": ["17f0"]},
    {"family": "xdna", "contains_any": ["xdna", "ai engine"], "vendor_ids": ["1022", "0x1022"],
     "device_ids": ["1502"]},
]


def _first_match(value: str, mappings: list[dict[str, Any]]) -> str | None:
    folded = value.casefold()
    for mapping in mappings:
        if any(token.casefold() in folded for token in mapping.get("contains_any", [])):
            return mapping["id"]
    return None


def _as_int(value: Any) -> int | None:
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    if isinstance(value, str) and value.isdigit():
        return int(value)
    return None


def _cpu_family_profile(cpu: dict[str, Any]) -> str | None:
    cpu_family = _as_int(cpu.get("family"))
    cpu_model = _as_int(cpu.get("cpu_model"))
    for signature in CPU_FAMILY_SIGNATURES:
        families = {int(v) for v in signature.get("cpu_families", [])}
        models = {int(v) for v in signature.get("cpu_models", [])}
        if cpu_family in families and (not models or cpu_model in models):
            return signature["id"]
    return _first_match(str(cpu.get("model", "")), CPU_FAMILY_PROFILES)


def _npu_family(npu: dict[str, Any]) -> str | None:
    device_text = "\n".join(
        str(device.get("device_name") or device.get("name") or "") for device in npu.get("devices", [])
    )
    device_text = "\n".join([device_text, str(npu.get("module_text", "")), str(npu.get("device_text", ""))])
    vendor_ids = {str(device.get("vendor_id", "")).lower() for device in npu.get("devices", [])}
    device_ids = {str(device.get("device_id", "")).lower() for device in npu.get("devices", [])}
    for mapping in NPU_FAMILY_MAPPINGS:
        text_match = any(token.casefold() in device_text.casefold() for token in mapping.get("contains_any", []))
        device_match = bool(device_ids & {device.lower() for device in mapping.get("device_ids", [])})
        vendor_match = bool(vendor_ids & {vendor.lower() for vendor in mapping.get("vendor_ids", [])})
        if (device_match or text_match) and (vendor_match or npu.get("present") is True):
            return mapping["family"]
    return "unknown" if npu.get("present") is True else None


def _classification_facts(hardware: dict[str, Any]) -> dict[str, Any]:
    cpu = hardware.get("cpu", {})
    gpu = hardware.get("gpu", {})
    npu = hardware.get("npu", {})
    system = hardware.get("system", {})
    cpu_model = str(cpu.get("model", ""))
    cpu_family = _cpu_family_profile(cpu)
    gpu_arch = _nullable(gpu.get("arch"))
    gpu_mapping = GPU_ARCHITECTURE_MAPPINGS.get(str(gpu_arch), {}) if gpu_arch else {}
    return {
        "system.vendor": _nullable(system.get("vendor")),
        "system.product": _nullable(system.get("product")),
        "cpu.vendor": _nullable(cpu.get("vendor")),
        "cpu.model": _nullable(cpu_model),
        "cpu.family_profile": cpu_family,
        "gpu.arch": gpu_arch,
        "gpu.family": gpu.get("family") or gpu_mapping.get("family") or ("unknown" if _known(gpu_arch) else None),
        "npu.present": npu.get("present") is True,
        "npu.driver": _nullable(npu.get("module_text")),
        "npu.nodes": _nullable(npu.get("device_text")),
        "npu.family": _npu_family(npu),
    }


def _matches_requirement(value: Any, requirement: dict[str, Any]) -> bool:
    if "equals_any" in requirement:
        return any(str(value).casefold() == str(candidate).casefold() for candidate in requirement["equals_any"])
    if "contains_any" in requirement:
        return any(str(candidate).casefold() in str(value).casefold() for candidate in requirement["contains_any"])
    return bool(value)


def classify(hardware: dict[str, Any]) -> dict[str, Any]:
    facts = _classification_facts(hardware)
    matches: list[tuple[int, dict[str, Any], list[str], list[str]]] = []
    all_mismatches: list[str] = []
    for definition in PLATFORM_DEFINITIONS:
        evidence: list[str] = []
        mismatches: list[str] = []
        hard_mismatch = False
        for requirement in definition["requires"]:
            path = requirement["path"]
            value = facts.get(path)
            if _known(value) and _matches_requirement(value, requirement):
                evidence.append(f"required {path} matched {value}")
            else:
                mismatches.append(f"required {path} did not match; observed {value or 'unknown'}")
                hard_mismatch = True
        for requirement in definition.get("requires_if_known", []):
            path = requirement["path"]
            value = facts.get(path)
            if _known(value) and _matches_requirement(value, requirement):
                evidence.append(f"known {path} matched {value}")
            elif _known(value):
                mismatches.append(f"known {path} contradicted identity; observed {value}")
                hard_mismatch = True
            else:
                evidence.append(f"known {path} unavailable; platform identity retained")
        for requirement in definition.get("optional", []):
            path = requirement["path"]
            value = facts.get(path)
            if _known(value) and _matches_requirement(value, requirement):
                evidence.append(f"optional {path} matched {value}")
            elif _known(value):
                mismatches.append(f"optional {path} did not match; observed {value}")
            else:
                evidence.append(f"optional {path} unavailable; platform identity retained")
        if not hard_mismatch:
            matches.append((definition["priority"], definition, evidence, mismatches))
        all_mismatches.extend(f"{definition['id']}: {message}" for message in mismatches)

    if matches:
        _, definition, evidence, mismatches = sorted(matches, key=lambda item: item[0], reverse=True)[0]
        return {"state": "observed", "platform_id": definition["id"], "confidence": definition["confidence"],
                "evidence": [definition["description"], *evidence], "mismatches": mismatches}

    cpu_identified = _known(facts.get("cpu.model")) and _known(facts.get("cpu.vendor"))
    state = "unsupported" if cpu_identified else "unknown"
    return {"state": state, "platform_id": None, "confidence": "none",
            "evidence": [], "mismatches": all_mismatches}


def _normalized_gpu_device(device: dict[str, Any]) -> dict[str, Any]:
    mapping = lookup_gpu_pci_mapping(device.get("vendor_id"), device.get("device_id"))
    key = pci_architecture_key(device.get("vendor_id"), device.get("device_id"))
    return {
        "name": device.get("device_name") or device.get("name"),
        "address": device.get("slot") or device.get("address"),
        "vendor_id": _identity_id(device.get("vendor_id")),
        "device_id": _identity_id(device.get("device_id")),
        "subsystem_vendor_id": _identity_id(device.get("subsystem_vendor_id")),
        "subsystem_device_id": _identity_id(device.get("subsystem_device_id")),
        "bound_driver": device.get("bound_driver"),
        "architecture": mapping["arch"] if mapping else None,
        "architecture_family": mapping.get("family") if mapping else None,
        "architecture_source": f"pci:{key}" if mapping else None,
    }


def normalize_facts(raw: dict[str, Any]) -> dict[str, Any]:
    """S1-M2: normalize raw inventory into structured facts."""
    hardware = hardware_from_input(raw)
    system, cpu = hardware.get("system", {}), hardware.get("cpu", {})
    gpu, npu = hardware.get("gpu", {}), hardware.get("npu", {})
    memory, storage = hardware.get("memory", {}), hardware.get("storage", {})
    missing_tools = [name for name in str(hardware.get("tools", {}).get("missing", "")).split(",") if name]
    gpu_devices = [_normalized_gpu_device(device) for device in gpu.get("devices") or []]
    if gpu_devices:
        gpu_state = "observed"
    elif "lspci" in missing_tools:
        gpu_state = "tool_missing"
    else:
        gpu_state = "not_present"
    unknown_paths: list[str] = []
    for path, value in (
        ("system.manufacturer", system.get("vendor")),
        ("system.product", system.get("product")),
        ("cpu.vendor_id", cpu.get("vendor")),
        ("cpu.model_name", cpu.get("model")),
        ("gpu.architecture", gpu.get("arch")),
    ):
        if not _known(value):
            unknown_paths.append(path)
    raw_pci = hardware.get("_raw_stage1", {}).get("pci", {})
    npu_devices = []
    for device in npu.get("devices") or []:
        npu_devices.append({
            "name": device.get("device_name") or device.get("name"),
            "vendor_id": _identity_id(device.get("vendor_id")),
            "device_id": _identity_id(device.get("device_id")),
            "bound_driver": device.get("bound_driver"),
        })
    return {
        "schema": {"name": "s1-m2-normalized-facts", "version": 1,
                   "uri": "https://ai370.local/schemas/s1-m2-normalized-facts-v1.json"},
        "stage": 1,
        "milestone": "S1-M2",
        "artifact": "s1-m2-normalized-facts",
        "source_artifact": raw.get("artifact"),
        "system": {
            "manufacturer": _nullable(system.get("vendor")),
            "product": _nullable(system.get("product")),
            "version": _nullable(system.get("version")),
            "motherboard": {
                "manufacturer": _nullable(system.get("board_vendor")),
                "product": _nullable(system.get("board_product")),
                "version": _nullable(system.get("board_version")),
            },
        },
        "operating_system": {
            "id": _nullable(system.get("os_id")),
            "name": _nullable(system.get("os_name")),
            "pretty_name": _nullable(system.get("os")),
            "version_id": _nullable(system.get("os_version_id")),
            "version_codename": _nullable(system.get("os_codename")),
        },
        "kernel": {
            "release": _nullable(system.get("kernel")),
            "architecture": _nullable(system.get("kernel_architecture")),
        },
        "cpu": {
            "vendor_id": _nullable(cpu.get("vendor")),
            "model_name": _nullable(cpu.get("model")),
            "architecture": _nullable(cpu.get("architecture")),
            "family": _as_int(cpu.get("family")),
            "model": _as_int(cpu.get("cpu_model")),
            "stepping": _as_int(cpu.get("stepping")),
            "topology": cpu.get("topology") or {},
        },
        "memory": {"total_bytes": memory.get("total_bytes") if isinstance(memory.get("total_bytes"), int) else _bytes(memory.get("total"))},
        "storage": {"devices": storage.get("devices") or []},
        "gpu": {
            "state": gpu_state,
            "architecture": _nullable(gpu.get("arch")),
            "architecture_family": _nullable(gpu.get("family")),
            "architecture_source": gpu.get("architecture_source"),
            "devices": gpu_devices,
        },
        "npu": {
            "present": npu.get("present") is True,
            "family": _npu_family(npu),
            "driver": _nullable(npu.get("module_text")),
            "device_nodes": [node for node in (npu.get("device_nodes") or []) if node],
            "devices": npu_devices,
        },
        "firmware": {
            "bios_vendor": _nullable(system.get("bios_vendor")),
            "bios_version": _nullable(system.get("bios_version")),
            "bios_date": _nullable(system.get("bios_date")),
            "uefi": system.get("uefi") or "unknown",
            "secure_boot": system.get("secure_boot") or {"state": "unknown", "enabled": None},
        },
        "pci": {
            "state": raw_pci.get("state"),
            "devices": raw_pci.get("devices") or [],
        },
        "collection": {"missing_tools": missing_tools},
        "unknown_facts": [{"path": path, "state": "unknown", "reason": "collector returned no recognized value"}
                          for path in unknown_paths],
    }


def hardware_from_normalized(facts: dict[str, Any]) -> dict[str, Any]:
    """Reconstruct the internal hardware dict from S1-M2 normalized facts."""
    system = facts.get("system", {})
    board = system.get("motherboard", {})
    cpu = facts.get("cpu", {})
    gpu = facts.get("gpu", {})
    npu = facts.get("npu", {})
    memory = facts.get("memory", {})
    storage = facts.get("storage", {})
    os_info = facts.get("operating_system", {})
    kernel = facts.get("kernel", {})
    firmware = facts.get("firmware", {})
    gpu_devices = []
    for device in gpu.get("devices") or []:
        gpu_devices.append({
            "device_name": device.get("name"),
            "name": device.get("name"),
            "slot": device.get("address"),
            "address": device.get("address"),
            "vendor_id": device.get("vendor_id"),
            "device_id": device.get("device_id"),
            "subsystem_vendor_id": device.get("subsystem_vendor_id"),
            "subsystem_device_id": device.get("subsystem_device_id"),
            "bound_driver": device.get("bound_driver"),
        })
    npu_devices = []
    for device in npu.get("devices") or []:
        npu_devices.append({
            "device_name": device.get("name"),
            "vendor_id": device.get("vendor_id"),
            "device_id": device.get("device_id"),
            "bound_driver": device.get("bound_driver"),
        })
    missing_tools = facts.get("collection", {}).get("missing_tools", [])
    return {
        "_raw_stage1": {"pci": facts.get("pci") or {"state": None, "devices": []},
                        "artifact": facts.get("source_artifact")},
        "system": {
            "vendor": system.get("manufacturer"), "product": system.get("product"),
            "version": system.get("version"),
            "bios_vendor": firmware.get("bios_vendor"), "bios_version": firmware.get("bios_version"),
            "bios_date": firmware.get("bios_date"), "uefi": firmware.get("uefi", "unknown"),
            "secure_boot": firmware.get("secure_boot") or {"state": "unknown", "enabled": None},
            "os": os_info.get("pretty_name"), "os_id": os_info.get("id"), "os_name": os_info.get("name"),
            "os_version_id": os_info.get("version_id"), "os_codename": os_info.get("version_codename"),
            "kernel": kernel.get("release"), "kernel_architecture": kernel.get("architecture"),
            "board_vendor": board.get("manufacturer"), "board_product": board.get("product"),
            "board_version": board.get("version"),
        },
        "cpu": {
            "model": cpu.get("model_name"), "vendor": cpu.get("vendor_id"),
            "family": cpu.get("family"), "cpu_model": cpu.get("model"),
            "stepping": cpu.get("stepping"), "architecture": cpu.get("architecture"),
            "topology": cpu.get("topology") or {},
            "logical_cores": (cpu.get("topology") or {}).get("logical_processors"),
        },
        "gpu": {
            "text": "\n".join(filter(None, (device.get("name") for device in gpu.get("devices") or []))),
            "arch": gpu.get("architecture"),
            "family": gpu.get("architecture_family"),
            "architecture_source": gpu.get("architecture_source"),
            "devices": gpu_devices,
            "amdgpu_module": "loaded" if any(device.get("bound_driver") == "amdgpu" for device in gpu_devices) else "",
        },
        "npu": {
            "present": npu.get("present") is True,
            "module_text": npu.get("driver") or "",
            "device_text": "\n".join(npu.get("device_nodes") or []),
            "devices": npu_devices,
            "device_nodes": npu.get("device_nodes") or [],
        },
        "memory": {"total_bytes": memory.get("total_bytes"), "total": memory.get("total_bytes")},
        "storage": {
            "devices": storage.get("devices") or [],
            "nvme": "\n".join(device.get("name", "") for device in storage.get("devices") or []
                              if str(device.get("name", "")).startswith("nvme")),
        },
        "tools": {"missing": ",".join(missing_tools)},
    }


def classify_platform_document(facts: dict[str, Any]) -> dict[str, Any]:
    """S1-M3: classify a platform from normalized facts."""
    hardware = hardware_from_input(facts)
    return {
        "schema": {"name": "s1-m3-platform-classification", "version": 1,
                   "uri": "https://ai370.local/schemas/s1-m3-platform-classification-v1.json"},
        "stage": 1,
        "milestone": "S1-M3",
        "artifact": "s1-m3-platform-classification",
        "consumed_source": facts.get("artifact"),
        "classification": classify(hardware),
    }


def _pci_from_device(device: dict[str, Any]) -> dict[str, Any]:
    identity = _pci_identity(device) or {}
    return {
        "address": device.get("slot") or device.get("address"),
        "vendor_id": identity.get("vendor_id"),
        "device_id": identity.get("device_id"),
        "subsystem_vendor_id": identity.get("subsystem_vendor_id"),
        "subsystem_device_id": identity.get("subsystem_device_id"),
    }


def _gpu_records(hardware: dict[str, Any]) -> list[dict[str, Any]]:
    gpu = hardware.get("gpu", {})
    missing_tools = [name for name in str(hardware.get("tools", {}).get("missing", "")).split(",") if name]
    lspci_tool_present = "lspci" not in missing_tools
    records: list[dict[str, Any]] = []
    structured = gpu.get("devices") or []
    if structured:
        for idx, device in enumerate(structured):
            mapping = lookup_gpu_pci_mapping(device.get("vendor_id"), device.get("device_id"))
            driver_name = device.get("bound_driver")
            if driver_name:
                driver = {"state": "observed", "name": driver_name}
            else:
                driver = _gpu_driver(gpu)
            records.append({
                "state": "observed",
                "id": f"gpu{idx}",
                "name": device.get("device_name") or device.get("name") or gpu.get("text") or None,
                "pci": _pci_from_device(device),
                "driver": driver,
                "architecture": (mapping["arch"] if mapping else _nullable(gpu.get("arch"))),
                "vram_bytes": None,
                "runtime": "unknown",
            })
        return records
    gpu_text = gpu.get("text", "")
    if _known(gpu_text):
        for idx, line in enumerate(str(gpu_text).splitlines()):
            line = line.strip()
            if not line:
                continue
            records.append({
                "state": "observed",
                "id": f"gpu{idx}",
                "name": line,
                "pci": _pci(),
                "driver": _gpu_driver(gpu),
                "architecture": _nullable(gpu.get("arch")),
                "vram_bytes": None,
                "runtime": "unknown",
            })
        return records
    if not lspci_tool_present:
        return [{
            "state": "tool_missing",
            "id": "gpu0",
            "name": None,
            "pci": _pci(),
            "driver": {"state": "unknown", "name": None},
            "architecture": None,
            "vram_bytes": None,
            "runtime": "unknown",
        }]
    return []


def _storage_records(hardware: dict[str, Any]) -> list[dict[str, Any]]:
    storage = hardware.get("storage", {})
    missing_tools = [name for name in str(hardware.get("tools", {}).get("missing", "")).split(",") if name]
    lsblk_tool_present = "lsblk" not in missing_tools
    storage_devices: list[dict[str, Any]] = []
    raw_storage_devices = storage.get("devices", [])
    if raw_storage_devices:
        for device in raw_storage_devices:
            name = device.get("name")
            storage_devices.append({
                "state": "observed",
                "name": name or "unknown",
                "device_path": f"/dev/{name}" if name else None,
                "kind": device.get("type") or "unknown",
                "transport": device.get("tran"),
                "size_bytes": device.get("size") if isinstance(device.get("size"), int) else None,
                "removable": device.get("rm") if isinstance(device.get("rm"), bool) else None,
                "model": device.get("model"),
                "serial": device.get("serial"),
                "firmware_version": device.get("rev"),
            })
        return storage_devices
    if _known(storage.get("nvme")):
        for line in str(storage.get("nvme")).splitlines():
            fields = line.split()
            if fields:
                storage_devices.append({"state": "observed", "name": fields[0], "device_path": None, "kind": "disk", "transport": "nvme", "size_bytes": None, "removable": None, "model": None, "serial": None, "firmware_version": None})
        return storage_devices
    if not lsblk_tool_present:
        return [{
            "state": "tool_missing",
            "name": "unknown",
            "device_path": None,
            "kind": "unknown",
            "transport": None,
            "size_bytes": None,
            "removable": None,
            "model": None,
            "serial": None,
            "firmware_version": None,
        }]
    return []


def _accelerator_records(hardware: dict[str, Any]) -> tuple[list[dict[str, Any]], str | None]:
    npu = hardware.get("npu", {})
    npu_device_text = npu.get("device_text", "")
    npu_present = npu.get("present") is True
    accelerators: list[dict[str, Any]] = []
    npu_evidence = None
    if npu_present:
        npu_evidence = "XDNA device visible" if _known(npu_device_text) else "XDNA kernel module loaded"
        first = (npu.get("devices") or [{}])[0] if npu.get("devices") else {}
        nodes = [node for node in (npu.get("device_nodes") or []) if node]
        if not nodes and _known(npu_device_text):
            nodes = [line for line in str(npu_device_text).splitlines() if line]
        accelerators.append({
            "state": "observed",
            "id": "npu0",
            "kind": "npu",
            "name": first.get("device_name") or first.get("name") or "AMD XDNA",
            "pci": _pci_from_device(first) if first else _pci(),
            "device_nodes": nodes,
            "driver": _accel_driver(npu),
            "runtime": "unknown",
        })
    return accelerators, npu_evidence


def derive_capability_candidates(hardware: dict[str, Any]) -> list[dict[str, Any]]:
    """S1-M4: derive capability candidates that are not validation claims."""
    gpu = hardware.get("gpu", {})
    npu = hardware.get("npu", {})
    gpu_devices = _gpu_records(hardware)
    storage_devices = _storage_records(hardware)
    _, npu_evidence = _accelerator_records(hardware)
    npu_present = npu.get("present") is True
    if gpu_devices and gpu_devices[0]["state"] == "tool_missing":
        gpu_candidate_state = "tool_missing"
    elif gpu_devices:
        gpu_candidate_state = "observed"
    else:
        gpu_candidate_state = "not_present"
    if storage_devices and storage_devices[0]["state"] == "tool_missing":
        nvme_candidate_state = "tool_missing"
    elif storage_devices:
        nvme_candidate_state = "observed"
    else:
        nvme_candidate_state = "not_present"
    gpu_arch = gpu.get("arch")
    return [
        {"id": "gpu.rocm",
         "state": gpu_candidate_state,
         "candidate": str(gpu_arch) in GPU_ARCHITECTURE_MAPPINGS if gpu_candidate_state == "observed" else None,
         "evidence": [str(gpu_arch)] if _known(gpu_arch) else []},
        {"id": "npu.runtime",
         "state": "observed" if npu_present else "not_present",
         "candidate": npu_present if npu_present else None,
         "evidence": [npu_evidence] if npu_evidence else []},
        {"id": "storage.nvme",
         "state": nvme_candidate_state,
         "candidate": bool(storage_devices) if nvme_candidate_state == "observed" else None,
         "evidence": [storage_devices[0]["name"]] if storage_devices and storage_devices[0]["state"] == "observed" else []},
    ]


def derive_capability_document(facts: dict[str, Any]) -> dict[str, Any]:
    """S1-M4 artifact: candidates with an explicit non-validation flag."""
    hardware = hardware_from_input(facts)
    candidates = [{**candidate, "validation_claim": False} for candidate in derive_capability_candidates(hardware)]
    return {
        "schema": {"name": "s1-m4-capability-candidates", "version": 1,
                   "uri": "https://ai370.local/schemas/s1-m4-capability-candidates-v1.json"},
        "stage": 1,
        "milestone": "S1-M4",
        "artifact": "s1-m4-capability-candidates",
        "consumed_source": facts.get("artifact"),
        "capability_candidates": candidates,
        "notes": [
            "Candidates describe what this machine might support.",
            "A true candidate is not Stage 2 validation and not runtime execution proof.",
        ],
    }


def _gpu_driver(gpu: dict[str, Any]) -> dict[str, Any]:
    """Return a state-bearing driver binding object for a GPU entry."""
    if gpu.get("amdgpu_module") == "loaded":
        return {"state": "observed", "name": "amdgpu"}
    return {"state": "unknown", "name": None}


def _accel_driver(npu: dict[str, Any]) -> dict[str, Any]:
    """Return a state-bearing driver binding object for an accelerator entry."""
    if _known(npu.get("module_text")):
        return {"state": "observed", "name": "amdxdna"}
    return {"state": "unknown", "name": None}


def build_profile(hardware: dict[str, Any], generator_version: str = "unknown") -> dict[str, Any]:
    """Convert Stage 1 facts into the complete v3 system-profile contract."""
    hardware = hardware_from_input(hardware)
    system, cpu = hardware.get("system", {}), hardware.get("cpu", {})
    memory = hardware.get("memory", {})
    missing_tools = [name for name in str(hardware.get("tools", {}).get("missing", "")).split(",") if name]

    unknown_paths: list[str] = []
    for path, value in (
        ("system.manufacturer", system.get("vendor")),
        ("system.product", system.get("product")),
        ("operating_system.pretty_name", system.get("os")),
        ("kernel.release", system.get("kernel")),
        ("cpu.vendor_id", cpu.get("vendor")),
        ("cpu.model_name", cpu.get("model")),
        ("memory.total_bytes", _bytes(memory.get("total"))),
        ("firmware.bios_version", system.get("bios_version")),
    ):
        if not _known(value):
            unknown_paths.append(path)

    lspci_tool_present = "lspci" not in missing_tools
    fingerprint_facts = _fingerprint_facts(hardware)
    fingerprint_inputs = ["accelerators", "cpu", "dmi", "pci_devices", "storage"]
    digest: str | None = (
        hashlib.sha256(
            json.dumps(fingerprint_facts, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest()
        if lspci_tool_present else None
    )

    gpu_devices = _gpu_records(hardware)
    accelerators, _npu_evidence = _accelerator_records(hardware)
    storage_devices = _storage_records(hardware)
    tools = [{"name": name, "state": "tool_missing", "path": None, "version": None,
              "error": {"code": "not_found", "message": f"{name} was not found in PATH"}} for name in missing_tools]

    return {
        "schema": {"name": SCHEMA_NAME, "version": SCHEMA_VERSION, "uri": SCHEMA_URI},
        "generation": {"timestamp": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
                       "generator": {"name": "system_profile.py", "version": generator_version},
                       "complete": not unknown_paths},
        "fingerprint": {"algorithm": "sha256", "algorithm_version": FINGERPRINT_ALGORITHM_VERSION,
                        "value": digest,
                        "inputs": fingerprint_inputs},
        "system": {"state": _state(system.get("vendor") or system.get("product")),
                   "manufacturer": _nullable(system.get("vendor")), "product": _nullable(system.get("product")),
                   "version": _nullable(system.get("version")), "serial": None, "uuid": None,
                   "motherboard": {"state": _state(system.get("board_vendor") or system.get("board_product")), "manufacturer": _nullable(system.get("board_vendor")), "product": _nullable(system.get("board_product")),
                                   "version": _nullable(system.get("board_version")), "serial": None}},
        "operating_system": {"state": _state(system.get("os")), "id": _nullable(system.get("os_id")), "name": _nullable(system.get("os_name")),
                             "pretty_name": _nullable(system.get("os")), "version_id": _nullable(system.get("os_version_id")), "version_codename": _nullable(system.get("os_codename"))},
        "kernel": {"state": _state(system.get("kernel")), "release": _nullable(system.get("kernel")),
                   "architecture": _nullable(system.get("kernel_architecture")), "command_line": None},
        "cpu": {"state": _state(cpu.get("model")), "vendor_id": _nullable(cpu.get("vendor")),
                "model_name": _nullable(cpu.get("model")), "architecture": _nullable(cpu.get("architecture")), "family": int(cpu.get("family")) if str(cpu.get("family") or "").isdigit() else None,
                "model": int(cpu.get("cpu_model")) if str(cpu.get("cpu_model") or "").isdigit() else None, "stepping": int(cpu.get("stepping")) if str(cpu.get("stepping") or "").isdigit() else None,
                "topology": {"sockets": cpu.get("topology", {}).get("sockets"), "physical_cores": None,
                             "logical_processors": cpu.get("logical_cores") or None,
                             "cores_per_socket": cpu.get("topology", {}).get("cores_per_socket"), "threads_per_core": cpu.get("topology", {}).get("threads_per_core")}},
        "memory": {"state": _state(_bytes(memory.get("total"))), "total_bytes": _bytes(memory.get("total")),
                   "available_bytes": None},
        "storage": storage_devices, "gpus": gpu_devices, "accelerators": accelerators,
        "firmware": {"state": _state(system.get("bios_version")), "bios_vendor": _nullable(system.get("bios_vendor")),
                     "bios_version": _nullable(system.get("bios_version")), "bios_date": _nullable(system.get("bios_date")),
                     "uefi": system.get("uefi", "unknown"), "secure_boot": system.get("secure_boot", {"state": "unknown", "enabled": None})},
        "collection": {"tools": tools, "probes": [{"id": "compatibility-inventory", "state": "observed",
                                                       "source": "tier1-hardware.json", "error": None}]},
        "classification": classify(hardware),
        "capability_candidates": derive_capability_candidates(hardware),
        "unknown_facts": [{"path": path, "state": "unknown", "reason": "collector returned no recognized value"}
                          for path in unknown_paths],
    }


def assemble_profile(
    facts: dict[str, Any],
    classification: dict[str, Any],
    capabilities: dict[str, Any],
    generator_version: str = "unknown",
) -> dict[str, Any]:
    """S1-M5: compose the v3 profile from milestone artifacts."""
    profile = build_profile(facts, generator_version)
    if classification.get("classification"):
        profile["classification"] = classification["classification"]
    candidates = []
    for candidate in capabilities.get("capability_candidates") or []:
        candidates.append({key: value for key, value in candidate.items() if key != "validation_claim"})
    if candidates:
        profile["capability_candidates"] = candidates
    return profile


def render_inventory_summary(profile: dict[str, Any]) -> str:
    """S1-M5 Markdown rendering of the published system profile."""
    classification = profile.get("classification", {})
    system = profile.get("system", {})
    cpu = profile.get("cpu", {})
    gpus = profile.get("gpus") or []
    accels = profile.get("accelerators") or []
    firmware = profile.get("firmware", {})
    gpu_arch = gpus[0].get("architecture") if gpus else None
    lines = [
        "# Stage 1 system profile",
        "",
        f"**Platform:** {classification.get('platform_id') or 'unknown'} "
        f"({classification.get('confidence') or 'none'})",
        f"**Classification state:** {classification.get('state') or 'unknown'}",
        f"**Fingerprint:** {profile.get('fingerprint', {}).get('value') or 'null'}",
        f"**Schema:** {profile.get('schema', {}).get('name')} v{profile.get('schema', {}).get('version')}",
        "",
        "## System",
        f"- Manufacturer: {system.get('manufacturer') or 'unknown'}",
        f"- Product: {system.get('product') or 'unknown'}",
        f"- CPU: {cpu.get('model_name') or 'unknown'}",
        f"- BIOS: {firmware.get('bios_version') or 'unknown'}",
        f"- GPU architecture: {gpu_arch or 'unknown'}",
        f"- Accelerators observed: {len([item for item in accels if item.get('state') == 'observed'])}",
        "",
        "## Capability candidates",
        "",
        "These are not validation claims and do not prove runtime execution.",
        "",
    ]
    for candidate in profile.get("capability_candidates") or []:
        lines.append(
            f"- `{candidate.get('id')}`: state={candidate.get('state')} "
            f"candidate={candidate.get('candidate')}"
        )
    lines.append("")
    return "\n".join(lines)


def _resolve(root: dict[str, Any], reference: str) -> dict[str, Any]:
    node: Any = root
    for token in reference.removeprefix("#/").split("/"):
        node = node[token.replace("~1", "/").replace("~0", "~")]
    return node


def _validate(instance: Any, rule: dict[str, Any], root: dict[str, Any], path: str) -> list[str]:
    if "$ref" in rule:
        return _validate(instance, _resolve(root, rule["$ref"]), root, path)
    errors: list[str] = []
    types = rule.get("type")
    if types:
        allowed = [types] if isinstance(types, str) else types
        checks = {"object": lambda x: isinstance(x, dict), "array": lambda x: isinstance(x, list),
                  "string": lambda x: isinstance(x, str), "integer": lambda x: isinstance(x, int) and not isinstance(x, bool),
                  "boolean": lambda x: isinstance(x, bool), "null": lambda x: x is None}
        if not any(checks[k](instance) for k in allowed):
            return [f"{path}: expected {' or '.join(allowed)}"]
    if "const" in rule and instance != rule["const"]:
        errors.append(f"{path}: expected constant {rule['const']!r}")
    if "enum" in rule and instance not in rule["enum"]:
        errors.append(f"{path}: value {instance!r} is not allowed")
    if isinstance(instance, dict):
        for name in rule.get("required", []):
            if name not in instance:
                errors.append(f"{path}: missing required property {name!r}")
        properties = rule.get("properties", {})
        if rule.get("additionalProperties") is False:
            for name in instance.keys() - properties.keys():
                errors.append(f"{path}: unexpected property {name!r}")
        for name, value in instance.items():
            if name in properties:
                errors.extend(_validate(value, properties[name], root, f"{path}.{name}"))
    if isinstance(instance, list):
        if len(instance) < rule.get("minItems", 0):
            errors.append(f"{path}: expected at least {rule['minItems']} items")
        if rule.get("uniqueItems") and len({json.dumps(x, sort_keys=True) for x in instance}) != len(instance):
            errors.append(f"{path}: items must be unique")
        for index, value in enumerate(instance):
            errors.extend(_validate(value, rule.get("items", {}), root, f"{path}[{index}]"))
    if isinstance(instance, str):
        if len(instance) < rule.get("minLength", 0):
            errors.append(f"{path}: string is too short")
        if "pattern" in rule and re.search(rule["pattern"], instance) is None:
            errors.append(f"{path}: does not match {rule['pattern']!r}")
        if rule.get("format") == "date-time":
            try:
                parsed = datetime.fromisoformat(instance.replace("Z", "+00:00"))
                if parsed.tzinfo is None:
                    raise ValueError
            except ValueError:
                errors.append(f"{path}: is not an RFC 3339 date-time")
    if isinstance(instance, int) and not isinstance(instance, bool) and instance < rule.get("minimum", instance):
        errors.append(f"{path}: is less than {rule['minimum']}")
    return errors


def validate_document(data: dict[str, Any], schema_path: Path, label: str = "document") -> None:
    """Validate a JSON document, raising a single actionable exception on failure."""
    with schema_path.open(encoding="utf-8") as stream:
        schema = json.load(stream)
    errors = _validate(data, schema, schema, "$")
    if errors:
        raise ProfileValidationError(f"invalid {label}:\n- " + "\n- ".join(errors))


def validate_profile(profile: dict[str, Any], schema_path: Path = DEFAULT_SCHEMA) -> None:
    """Validate a profile, raising a single actionable exception on failure."""
    validate_document(profile, schema_path, "system profile")


def atomic_write_document(path: Path, data: dict[str, Any], schema_path: Path, label: str = "document") -> None:
    """Validate before creating a temporary file or replacing the last document."""
    validate_document(data, schema_path, label)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(data, stream, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    except BaseException:
        Path(temporary).unlink(missing_ok=True)
        raise


def atomic_write(path: Path, data: dict[str, Any], schema_path: Path = DEFAULT_SCHEMA) -> None:
    """Validate before creating a temporary file or replacing the last profile."""
    atomic_write_document(path, data, schema_path, "system profile")


def atomic_write_text(path: Path, text: str) -> None:
    """Atomically replace a text artifact."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(text)
            if not text.endswith("\n"):
                stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    except BaseException:
        Path(temporary).unlink(missing_ok=True)
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description="Publish the validated Stage 1 system profile")
    parser.add_argument("--lookup-gpu-arch", metavar="PCI_TEXT",
                        help="Print GPU architecture from lspci -nn text using the PCI map")
    parser.add_argument("--input", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    parser.add_argument("--generator-version", default="unknown")
    args = parser.parse_args()
    if args.lookup_gpu_arch is not None:
        print(lookup_gpu_arch_from_pci_text(args.lookup_gpu_arch))
        return
    if args.input is None or args.output is None:
        parser.error("--input and --output are required unless --lookup-gpu-arch is used")
    with args.input.open(encoding="utf-8") as stream:
        hardware = json.load(stream)
    atomic_write(args.output, build_profile(hardware, args.generator_version), args.schema)


if __name__ == "__main__":
    main()
