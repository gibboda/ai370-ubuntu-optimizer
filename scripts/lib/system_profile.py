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
    match = re.fullmatch(r"\s*([0-9]+(?:\.[0-9]+)?)\s*([KMGTPE]?i?B)?\s*", str(value), re.I)
    if not match:
        return None
    units = {"B": 1, "KB": 1000, "MB": 1000**2, "GB": 1000**3, "TB": 1000**4,
             "KIB": 1024, "MIB": 1024**2, "GIB": 1024**3, "TIB": 1024**4}
    return int(float(match.group(1)) * units.get((match.group(2) or "B").upper(), 1))


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
    amd_ryzen_ai = "AMD" in str(hardware.get("cpu", {}).get("vendor", "")) and "Ryzen AI" in cpu_model
    if len(evidence) == 3:
        platform_id, confidence, state = "ai370", "exact", "observed"
    elif amd_ryzen_ai:
        platform_id, confidence, state = "generic-ryzen-ai", "family", "observed"
    else:
        platform_id, confidence, state = None, "none", "unsupported"
    return {"state": state, "platform_id": platform_id, "confidence": confidence,
            "evidence": evidence, "mismatches": mismatches}


def build_profile(hardware: dict[str, Any], generator_version: str = "unknown") -> dict[str, Any]:
    """Convert the compatibility inventory into the complete v2 contract."""
    system, cpu = hardware.get("system", {}), hardware.get("cpu", {})
    gpu, npu = hardware.get("gpu", {}), hardware.get("npu", {})
    memory, storage = hardware.get("memory", {}), hardware.get("storage", {})
    missing_tools = [name for name in str(hardware.get("tools", {}).get("missing", "")).split(",") if name]
    unknown_paths = []
    for path, value in (("system.manufacturer", system.get("vendor")),
                        ("system.product", system.get("product")),
                        ("cpu.model_name", cpu.get("model")),
                        ("memory.total_bytes", _bytes(memory.get("total")))):
        if not _known(value):
            unknown_paths.append(path)

    fingerprint_facts = {"system": system, "cpu": cpu, "gpu": gpu, "npu": npu, "storage": storage}
    digest = hashlib.sha256(json.dumps(fingerprint_facts, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    gpu_present, npu_present = _known(gpu.get("text")), npu.get("present") is True
    gpu_devices = []
    if gpu_present:
        gpu_devices.append({"state": "observed", "id": "gpu0", "name": _nullable(gpu.get("text")),
                            "pci": _pci(), "driver": "amdgpu" if gpu.get("amdgpu_module") == "loaded" else None,
                            "architecture": _nullable(gpu.get("arch")), "vram_bytes": None, "runtime": "unknown"})
    accelerators = []
    if npu_present:
        accelerators.append({"state": "observed", "id": "npu0", "kind": "npu", "name": "AMD XDNA",
                             "pci": _pci(), "device_nodes": [], "driver": "amdxdna" if _known(npu.get("module_text")) else None,
                             "runtime": "unknown"})
    storage_devices = []
    if _known(storage.get("nvme")):
        storage_devices.append({"state": "observed", "name": str(storage["nvme"]).splitlines()[0],
                                "device_path": None, "kind": "disk", "transport": "nvme", "size_bytes": None,
                                "removable": None, "model": None, "serial": None, "firmware_version": None})
    tools = [{"name": name, "state": "tool_missing", "path": None, "version": None,
              "error": {"code": "not_found", "message": f"{name} was not found in PATH"}} for name in missing_tools]
    return {
        "schema": {"name": SCHEMA_NAME, "version": SCHEMA_VERSION, "uri": SCHEMA_URI},
        "generation": {"timestamp": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
                       "generator": {"name": "system_profile.py", "version": generator_version},
                       "complete": not unknown_paths},
        "fingerprint": {"algorithm": "sha256", "value": digest,
                        "inputs": ["cpu", "gpu", "npu", "storage", "system"]},
        "system": {"state": _state(system.get("vendor") or system.get("product")),
                   "manufacturer": _nullable(system.get("vendor")), "product": _nullable(system.get("product")),
                   "version": None, "serial": None, "uuid": None,
                   "motherboard": {"state": "unknown", "manufacturer": None, "product": None,
                                   "version": None, "serial": None}},
        "operating_system": {"state": _state(system.get("os")), "id": None, "name": None,
                             "pretty_name": _nullable(system.get("os")), "version_id": None, "version_codename": None},
        "kernel": {"state": _state(system.get("kernel")), "release": _nullable(system.get("kernel")),
                   "architecture": None, "command_line": None},
        "cpu": {"state": _state(cpu.get("model")), "vendor_id": _nullable(cpu.get("vendor")),
                "model_name": _nullable(cpu.get("model")), "architecture": None, "family": None,
                "model": None, "stepping": None,
                "topology": {"sockets": None, "physical_cores": None,
                             "logical_processors": cpu.get("logical_cores") or None,
                             "cores_per_socket": None, "threads_per_core": None}},
        "memory": {"state": _state(_bytes(memory.get("total"))), "total_bytes": _bytes(memory.get("total")),
                   "available_bytes": None},
        "storage": storage_devices, "gpus": gpu_devices, "accelerators": accelerators,
        "firmware": {"state": _state(system.get("bios_version")), "bios_vendor": None,
                     "bios_version": _nullable(system.get("bios_version")), "bios_date": None,
                     "uefi": "unknown", "secure_boot": {"state": "unknown", "enabled": None}},
        "collection": {"tools": tools, "probes": [{"id": "compatibility-inventory", "state": "observed",
                                                       "source": "tier1-hardware.json", "error": None}]},
        "classification": classify(hardware),
        "capability_candidates": [
            {"id": "gpu.rocm", "state": "observed" if gpu_present else "not_present",
             "candidate": gpu.get("arch") == "gfx1150", "evidence": [str(gpu.get("arch"))] if _known(gpu.get("arch")) else []},
            {"id": "npu.runtime", "state": "observed" if npu_present else "not_present",
             "candidate": npu_present, "evidence": ["XDNA device visible"] if npu_present else []},
            {"id": "storage.nvme", "state": "observed" if storage_devices else "not_present",
             "candidate": bool(storage_devices), "evidence": [storage_devices[0]["name"]] if storage_devices else []}],
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
