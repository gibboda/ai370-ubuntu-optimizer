"""S2-M2 kernel validation fact JSON (shared by 30-validate-kernel.sh and tests)."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def tri_bool(text: str) -> bool | None:
    if text == "true":
        return True
    if text == "false":
        return False
    return None


def build_kernel_facts_document(
    *,
    kernel: str,
    target_kernel: str,
    kernel_ok: str,
    amdgpu_ok: str,
    amdxdna_seen: str,
    linux_firmware_state: str,
    status: str,
    os_description: str,
    os_version: str,
    os_codename: str,
    recommendations: list[str],
) -> dict[str, Any]:
    return {
        "kernel": kernel,
        "target_kernel": target_kernel,
        "kernel_ok": tri_bool(kernel_ok),
        "amdgpu_ok": tri_bool(amdgpu_ok),
        "amdxdna_seen": tri_bool(amdxdna_seen),
        "linux_firmware_state": linux_firmware_state,
        "status": status,
        "os_description": os_description,
        "os_version": os_version,
        "os_codename": os_codename,
        "recommendations": recommendations,
    }


def write_kernel_facts_json(path: Path, document: dict[str, Any]) -> None:
    path.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
