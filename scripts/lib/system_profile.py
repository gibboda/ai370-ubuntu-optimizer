#!/usr/bin/env python3
"""Build the versioned Stage 1 system profile from collected hardware facts."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import tempfile
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


SCHEMA_NAME = "ai370-system-profile"
SCHEMA_VERSION = 1


def _known(value: Any) -> bool:
    return value not in (None, "", "unknown", [], {})


def classify(hardware: dict[str, Any]) -> dict[str, Any]:
    cpu_model = str(hardware.get("cpu", {}).get("model", ""))
    gpu_arch = str(hardware.get("gpu", {}).get("arch", ""))
    npu_present = hardware.get("npu", {}).get("present") is True
    evidence: list[str] = []
    mismatches: list[str] = []

    if "Ryzen AI 9 HX 370" in cpu_model:
        evidence.append("CPU model matches Ryzen AI 9 HX 370")
    else:
        mismatches.append("CPU model does not match Ryzen AI 9 HX 370")
    if gpu_arch == "gfx1150":
        evidence.append("GPU architecture matches gfx1150")
    else:
        mismatches.append("GPU architecture does not match gfx1150")
    if npu_present:
        evidence.append("XDNA device or kernel module is visible")
    else:
        mismatches.append("XDNA device and kernel module are not visible")

    exact = len(evidence) == 3
    amd_ryzen_ai = "AMD" in str(hardware.get("cpu", {}).get("vendor", "")) and "Ryzen AI" in cpu_model
    if exact:
        matched, confidence = "ai370", "exact"
    elif amd_ryzen_ai:
        matched, confidence = "generic-ryzen-ai", "family"
    else:
        matched, confidence = None, "none"
    return {
        "matched_profile": matched,
        "confidence": confidence,
        "evidence": evidence,
        "mismatches": mismatches,
    }


def build_profile(hardware: dict[str, Any], generator_version: str = "unknown") -> dict[str, Any]:
    gpu = hardware.get("gpu", {})
    npu = hardware.get("npu", {})
    missing = hardware.get("tools", {}).get("missing", "")
    missing_tools = [item for item in str(missing).split(",") if item]
    unknowns = []
    for label, value in (
        ("system.vendor", hardware.get("system", {}).get("vendor")),
        ("system.product", hardware.get("system", {}).get("product")),
        ("cpu.model", hardware.get("cpu", {}).get("model")),
        ("gpu.arch", gpu.get("arch")),
        ("memory.total", hardware.get("memory", {}).get("total")),
    ):
        if not _known(value):
            unknowns.append(label)

    fingerprint_input = json.dumps(
        {
            "system": hardware.get("system", {}),
            "cpu": hardware.get("cpu", {}),
            "gpu_text": gpu.get("text", ""),
            "storage": hardware.get("storage", {}),
        },
        sort_keys=True,
    ).encode()
    return {
        "schema": {"name": SCHEMA_NAME, "version": SCHEMA_VERSION},
        "generation": {
            "timestamp": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
            "generator_version": generator_version,
            "hardware_fingerprint": hashlib.sha256(fingerprint_input).hexdigest(),
            "complete": not unknowns,
        },
        "classification": classify(hardware),
        "hardware": {
            "system": hardware.get("system", {}),
            "cpu": hardware.get("cpu", {}),
            "gpu": gpu,
            "npu": npu,
            "memory": hardware.get("memory", {}),
            "storage": hardware.get("storage", {}),
        },
        "capabilities": {
            "gpu": {
                "present": _known(gpu.get("text")),
                "driver_bound": gpu.get("amdgpu_module") == "loaded",
                "architecture": gpu.get("arch") if _known(gpu.get("arch")) else None,
                "rocm_candidate": gpu.get("arch") == "gfx1150",
            },
            "npu": {
                "present": npu.get("present") is True,
                "kernel_device_visible": npu.get("present") is True,
                "runtime_candidate": npu.get("present") is True,
            },
            "storage": {"nvme_present": _known(hardware.get("storage", {}).get("nvme"))},
        },
        "unknowns": unknowns,
        "collection": {"missing_tools": missing_tools, "failed_probes": []},
    }


def atomic_write(path: Path, data: dict[str, Any]) -> None:
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
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--generator-version", default="unknown")
    args = parser.parse_args()
    with args.input.open(encoding="utf-8") as stream:
        hardware = json.load(stream)
    atomic_write(args.output, build_profile(hardware, args.generator_version))


if __name__ == "__main__":
    main()
