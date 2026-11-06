"""S2-M4 NPU visibility checks payload from inventory JSON under reports/latest."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def _load_json(latest: Path, name: str) -> dict[str, Any]:
    path = latest / name
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def build_checks_payload(
    latest_dir: Path,
    *,
    module_present: bool,
    device_nodes_present: bool,
    module_text: str,
    device_text: str,
) -> dict[str, Any]:
    latest = latest_dir
    inventory = _load_json(latest, "xrt-ryzen-ai-install.json")
    status = _load_json(latest, "npu-acceleration-status.json")
    capabilities = _load_json(latest, "npu-capabilities.json")
    backend = _load_json(latest, "vitis-ai-ep-status.json")
    runtime = inventory.get("runtime") or {}

    xrt_examine = str(capabilities.get("xrt_smi_examine") or "")
    xrt_validate = str(capabilities.get("xrt_smi_validate") or "")
    runtime_tools = str(status.get("runtime_tools") or runtime.get("xrt") or "")
    ryzen_ai = str(runtime.get("ryzen_ai") or "")

    runtime_ready = (
        runtime_tools in {"available"}
        or ryzen_ai in {"available"}
        or runtime.get("xrt") == "available"
    )

    examine_lower = xrt_examine.strip().lower()
    if (
        not xrt_examine.strip()
        or examine_lower in {"not-run", "not-visible"}
        or examine_lower.startswith("command-not-found")
    ):
        firmware_ready = False if not runtime_ready else None
    elif "error" in examine_lower and "firmware" not in examine_lower:
        firmware_ready = False
    else:
        firmware_ready = True

    providers = backend.get("amd_provider_candidates") or []
    provider_smoke = str(backend.get("provider_smoke") or "")
    backend_ready = bool(providers) or provider_smoke == "visible"

    return {
        "module_present": module_present,
        "device_nodes_present": device_nodes_present,
        "firmware_ready": firmware_ready,
        "runtime_ready": runtime_ready,
        "backend_ready": backend_ready,
        "provider_candidates": providers,
        "provider_smoke": provider_smoke,
        "module_text": module_text,
        "device_text": device_text,
        "xrt_smi_validate": xrt_validate,
    }
