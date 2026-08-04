#!/usr/bin/env python3
"""Normalize, validate, and atomically publish the Stage 1 system profile."""

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
SCHEMA_VERSION = 2
SCHEMA_URI = "https://ai370.local/schemas/system-profile-v2.json"
DEFAULT_SCHEMA = Path(__file__).resolve().parents[2] / "configs/schemas/system-profile.schema.json"


class ProfileValidationError(ValueError):
    """Raised when a candidate profile violates the published contract."""


def _known(value: Any) -> bool:
    return value not in (None, "", "unknown", [], {})


def _nullable(value: Any) -> Any:
    return value if _known(value) else None


def _state(value: Any) -> str:
    return "observed" if _known(value) else "unknown"


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
    board = dmi.get("board", {})
    firmware = raw.get("firmware", {})
    os_info = raw.get("os", {})
    kernel = raw.get("kernel", {})
    gpu = raw.get("gpu", {})
    accelerators = raw.get("accelerators", {})
    storage = raw.get("storage", {})
    missing_tools = raw.get("collection", {}).get("missing_tools", [])
    gpu_lines = [device.get("device_name") or device.get("class") or "" for device in gpu.get("devices", [])]
    npu_present = accelerators.get("state") == "observed"
    npu_drivers = sorted({device.get("bound_driver") for device in accelerators.get("devices", []) if device.get("bound_driver")})
    npu_nodes = [node.get("path") for node in accelerators.get("device_nodes", []) if node.get("path")]
    return {
        "_raw_stage1": raw,
        "system": {"vendor": _probe_value(system.get("vendor")), "product": _probe_value(system.get("product")),
                   "version": _probe_value(system.get("version")), "bios_vendor": _probe_value(firmware.get("bios_vendor")),
                   "bios_version": _probe_value(firmware.get("bios_version")), "bios_date": _probe_value(firmware.get("bios_date")),
                   "uefi": firmware.get("uefi", {}).get("state", "unknown"),
                   "secure_boot": {"state": firmware.get("secure_boot", {}).get("state", "unknown"),
                                   "enabled": firmware.get("secure_boot", {}).get("enabled")},
                   "os": os_info.get("pretty_name"), "os_id": os_info.get("id"), "os_name": os_info.get("name"),
                   "os_version_id": os_info.get("version_id"), "os_codename": os_info.get("version_codename"),
                   "kernel": kernel.get("release"), "kernel_architecture": kernel.get("architecture"),
                   "board_vendor": _probe_value(board.get("vendor")), "board_product": _probe_value(board.get("product")),
                   "board_version": _probe_value(board.get("version"))},
        "cpu": {"model": cpu.get("model_name"), "vendor": cpu.get("vendor_id"), "family": cpu.get("family"),
                "cpu_model": cpu.get("model"), "stepping": cpu.get("stepping"), "architecture": cpu.get("architecture"),
                "topology": cpu.get("topology", {}), "logical_cores": cpu.get("topology", {}).get("logical_processors")},
        "gpu": {"text": "\n".join(gpu_lines), "arch": gpu.get("architecture", {}).get("value"),
                "devices": gpu.get("devices", []), "amdgpu_module": "loaded" if any(d.get("bound_driver") == "amdgpu" for d in gpu.get("devices", [])) else ""},
        "npu": {"present": npu_present, "module_text": "\n".join(npu_drivers), "device_text": "\n".join(npu_nodes),
                "devices": accelerators.get("devices", []), "device_nodes": npu_nodes},
        "memory": {"total_bytes": raw.get("memory", {}).get("total_bytes"), "total": raw.get("memory", {}).get("total_bytes")},
        "storage": {"devices": storage.get("devices", []), "nvme": "\n".join(device.get("name", "") for device in storage.get("devices", []) if str(device.get("name", "")).startswith("nvme"))},
        "tools": {"missing": ",".join(missing_tools)},
    }

def _pci() -> dict[str, None]:
    return {"address": None, "vendor_id": None, "device_id": None,
            "subsystem_vendor_id": None, "subsystem_device_id": None}


def classify(hardware: dict[str, Any]) -> dict[str, Any]:
    cpu_model = str(hardware.get("cpu", {}).get("model", ""))
    gpu_arch = str(hardware.get("gpu", {}).get("arch", ""))
    npu_present = hardware.get("npu", {}).get("present") is True
    evidence, mismatches = [], []
    checks = (("Ryzen AI 9 HX 370" in cpu_model, "CPU model matches Ryzen AI 9 HX 370",
               "CPU model does not match Ryzen AI 9 HX 370"),
              (gpu_arch == "gfx1150", "GPU architecture matches gfx1150",
               "GPU architecture does not match gfx1150"),
              (npu_present, "XDNA device or kernel module is visible",
               "XDNA device and kernel module are not visible"))
    for matched, positive, negative in checks:
        (evidence if matched else mismatches).append(positive if matched else negative)
    cpu_vendor = str(hardware.get("cpu", {}).get("vendor", ""))
    amd_ryzen_ai = "AMD" in cpu_vendor and "Ryzen AI" in cpu_model
    cpu_identified = _known(cpu_model) and _known(cpu_vendor)
    if len(evidence) == 3:
        platform_id, confidence, state = "ai370", "exact", "observed"
    elif amd_ryzen_ai:
        platform_id, confidence, state = "generic-ryzen-ai", "family", "observed"
    elif not cpu_identified:
        platform_id, confidence, state = None, "none", "unknown"
    else:
        platform_id, confidence, state = None, "none", "unsupported"
    return {"state": state, "platform_id": platform_id, "confidence": confidence,
            "evidence": evidence, "mismatches": mismatches}


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
    """Convert the Stage 1 raw probe artifact into the complete v2 contract."""
    if hardware.get("artifact") == "stage1-raw-probes":
        hardware = _hardware_from_raw_probes(hardware)
    system, cpu = hardware.get("system", {}), hardware.get("cpu", {})
    gpu, npu = hardware.get("gpu", {}), hardware.get("npu", {})
    memory, storage = hardware.get("memory", {}), hardware.get("storage", {})
    missing_tools = [name for name in str(hardware.get("tools", {}).get("missing", "")).split(",") if name]

    # Collect unknown facts across all major profile sections.
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

    # Fingerprint: hash only stable hardware-identity fields; exclude driver
    # bindings, module states, and runtime observations that change independently
    # of the physical hardware.
    fingerprint_facts = {
        "system": {"vendor": _nullable(system.get("vendor")), "product": _nullable(system.get("product"))},
        "cpu": {"vendor": _nullable(cpu.get("vendor")), "model": _nullable(cpu.get("model"))},
        "gpu": {"arch": _nullable(gpu.get("arch"))},
        "npu": {"present": npu.get("present")},
        "storage": {"nvme": _nullable(storage.get("nvme"))},
    }
    fingerprint_inputs = ["cpu", "gpu", "npu", "storage", "system"]
    digest = hashlib.sha256(
        json.dumps(fingerprint_facts, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()

    # GPU devices: one record per detected lspci line.
    gpu_text = gpu.get("text", "")
    lspci_tool_present = "lspci" not in missing_tools
    gpu_devices: list[dict[str, Any]] = []
    if _known(gpu_text):
        for idx, line in enumerate(str(gpu_text).splitlines()):
            line = line.strip()
            if not line:
                continue
            gpu_devices.append({
                "state": "observed",
                "id": f"gpu{idx}",
                "name": line,
                "pci": _pci(),
                "driver": _gpu_driver(gpu),
                "architecture": _nullable(gpu.get("arch")),
                "vram_bytes": None,
                "runtime": "unknown",
            })
    elif not lspci_tool_present:
        gpu_devices.append({
            "state": "tool_missing",
            "id": "gpu0",
            "name": None,
            "pci": _pci(),
            "driver": {"state": "unknown", "name": None},
            "architecture": None,
            "vram_bytes": None,
            "runtime": "unknown",
        })

    # Accelerators: NPU.
    npu_device_text = npu.get("device_text", "")
    npu_module_text = npu.get("module_text", "")
    npu_present = npu.get("present") is True
    accelerators: list[dict[str, Any]] = []
    if npu_present:
        if _known(npu_device_text):
            npu_evidence = "XDNA device visible"
        else:
            npu_evidence = "XDNA kernel module loaded"
        accelerators.append({
            "state": "observed",
            "id": "npu0",
            "kind": "npu",
            "name": "AMD XDNA",
            "pci": _pci(),
            "device_nodes": [],
            "driver": _accel_driver(npu),
            "runtime": "unknown",
        })
    else:
        npu_evidence = None

    # Storage devices: one record per non-empty lsblk output line; first field
    # is the device name.
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
    elif _known(storage.get("nvme")):
        for line in str(storage.get("nvme")).splitlines():
            fields = line.split()
            if fields:
                storage_devices.append({"state": "observed", "name": fields[0], "device_path": None, "kind": "disk", "transport": "nvme", "size_bytes": None, "removable": None, "model": None, "serial": None, "firmware_version": None})
    elif not lsblk_tool_present:
        storage_devices.append({
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
        })

    tools = [{"name": name, "state": "tool_missing", "path": None, "version": None,
              "error": {"code": "not_found", "message": f"{name} was not found in PATH"}} for name in missing_tools]

    # Capability candidates: distinguish probe failures from confirmed absence.
    gpu_candidate_state: str
    if gpu_devices and gpu_devices[0]["state"] == "tool_missing":
        gpu_candidate_state = "tool_missing"
    elif gpu_devices:
        gpu_candidate_state = "observed"
    else:
        gpu_candidate_state = "not_present"

    nvme_candidate_state: str
    if storage_devices and storage_devices[0]["state"] == "tool_missing":
        nvme_candidate_state = "tool_missing"
    elif storage_devices:
        nvme_candidate_state = "observed"
    else:
        nvme_candidate_state = "not_present"

    return {
        "schema": {"name": SCHEMA_NAME, "version": SCHEMA_VERSION, "uri": SCHEMA_URI},
        "generation": {"timestamp": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
                       "generator": {"name": "system_profile.py", "version": generator_version},
                       "complete": not unknown_paths},
        "fingerprint": {"algorithm": "sha256", "value": digest,
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
        "capability_candidates": [
            {"id": "gpu.rocm",
             "state": gpu_candidate_state,
             "candidate": gpu.get("arch") == "gfx1150" if gpu_candidate_state == "observed" else None,
             "evidence": [str(gpu.get("arch"))] if _known(gpu.get("arch")) else []},
            {"id": "npu.runtime",
             "state": "observed" if npu_present else "not_present",
             "candidate": npu_present if npu_present else None,
             "evidence": [npu_evidence] if npu_evidence else []},
            {"id": "storage.nvme",
             "state": nvme_candidate_state,
             "candidate": bool(storage_devices) if nvme_candidate_state == "observed" else None,
             "evidence": [storage_devices[0]["name"]] if storage_devices and storage_devices[0]["state"] == "observed" else []}],
        "unknown_facts": [{"path": path, "state": "unknown", "reason": "collector returned no recognized value"}
                          for path in unknown_paths],
    }


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


def validate_profile(profile: dict[str, Any], schema_path: Path = DEFAULT_SCHEMA) -> None:
    """Validate a profile, raising a single actionable exception on failure."""
    with schema_path.open(encoding="utf-8") as stream:
        schema = json.load(stream)
    errors = _validate(profile, schema, schema, "$")
    if errors:
        raise ProfileValidationError("invalid system profile:\n- " + "\n- ".join(errors))


def atomic_write(path: Path, data: dict[str, Any], schema_path: Path = DEFAULT_SCHEMA) -> None:
    """Validate before creating a temporary file or replacing the last profile."""
    validate_profile(data, schema_path)
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


def main() -> None:
    parser = argparse.ArgumentParser(description="Publish the validated Stage 1 system profile")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    parser.add_argument("--generator-version", default="unknown")
    args = parser.parse_args()
    with args.input.open(encoding="utf-8") as stream:
        hardware = json.load(stream)
    atomic_write(args.output, build_profile(hardware, args.generator_version), args.schema)


if __name__ == "__main__":
    main()
