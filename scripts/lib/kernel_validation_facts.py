"""S2-M2 kernel validation fact JSON (shared by 30-validate-kernel.sh and tests)."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def bool_or_none(value: Any) -> bool | None:
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
        "kernel_ok": bool_or_none(kernel_ok),
        "amdgpu_ok": bool_or_none(amdgpu_ok),
        "amdxdna_seen": bool_or_none(amdxdna_seen),
        "linux_firmware_state": linux_firmware_state,
        "status": status,
        "os_description": os_description,
        "os_version": os_version,
        "os_codename": os_codename,
        "recommendations": recommendations,
    }


def write_kernel_facts_json(path: Path, document: dict[str, Any]) -> None:
    path.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
