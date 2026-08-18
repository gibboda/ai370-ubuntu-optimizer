"""Structured GPU and NPU capability ladders for Stage 2 visibility assessment.

This module separates three vocabularies that must not be conflated:

1. **S1-M4 capability candidates** — what the machine might support (never a
   validation claim; owned by ``system_profile.derive_capability_candidates``).
2. **Ladder progression** — ordered readiness steps from detection through
   application readiness (this module).
3. **Runtime validation** — execution proof on a specific accelerator (Stage 3).

GPU ladder progression::

    DETECTED -> DRIVER_READY -> VULKAN_READY -> ROCM_READY ->
    HIP_READY -> FRAMEWORK_READY -> APPLICATION_READY

NPU ladder progression::

    DETECTED -> DRIVER_READY -> FIRMWARE_READY -> RUNTIME_READY ->
    BACKEND_READY -> MODEL_READY -> APPLICATION_READY

Overall assessment states (aggregate view of the ladder)::

    AVAILABLE   — prerequisite hardware/driver facts were observed.
    READY       — the requested visibility step and all prior steps are satisfied.
    DEGRADED    — partial progress with a known blocker on an earlier step.
    UNSUPPORTED — the domain is absent or explicitly unsupported on this host.
    UNKNOWN     — insufficient evidence; do not infer absence.

Input mapping (Stage 1 normalized hardware dict)::

    GPU DETECTED       — at least one GPU device with observed PCI identity.
    GPU DRIVER_READY   — ``gpu.amdgpu_module == "loaded"`` or bound ``amdgpu`` driver.
    NPU DETECTED       — ``npu.present is True`` or XDNA accelerator device observed.
    NPU DRIVER_READY   — NPU module text contains ``amdxdna`` or accelerator bound driver.

Input mapping (Stage 2 visibility checks dict) extends probe-derived steps:

    GPU VULKAN_READY   — ``checks["vulkan"] == "visible"``.
    GPU ROCM_READY     — ``checks["rocm"] == "visible"``.
    GPU HIP_READY      — same as ROCM_READY when HIP visibility is inferred from rocminfo.
    NPU RUNTIME_READY  — Ryzen AI / XRT packages or venv reported present (visibility only).
    NPU BACKEND_READY  — Vitis AI EP or equivalent provider registered (visibility only).

Steps above RUNTIME/BACKEND visibility without explicit checks remain ``UNKNOWN``.
``APPLICATION_READY`` is never inferred from package presence alone.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Literal

PROJECT_ROOT = Path(__file__).resolve().parents[2]
S2_M3_SCHEMA = PROJECT_ROOT / "configs/schemas/s2-m3-gpu-runtime-visibility.schema.json"
S2_M4_SCHEMA = PROJECT_ROOT / "configs/schemas/s2-m4-npu-runtime-validation.schema.json"

GateStatus = Literal["PASS", "WARN", "FAIL", "UNSUPPORTED", "SKIPPED"]

GpuLadderStep = Literal[
    "DETECTED",
    "DRIVER_READY",
    "VULKAN_READY",
    "ROCM_READY",
    "HIP_READY",
    "FRAMEWORK_READY",
    "APPLICATION_READY",
]

NpuLadderStep = Literal[
    "DETECTED",
    "DRIVER_READY",
    "FIRMWARE_READY",
    "RUNTIME_READY",
    "BACKEND_READY",
    "MODEL_READY",
    "APPLICATION_READY",
]

AssessmentState = Literal["AVAILABLE", "READY", "DEGRADED", "UNSUPPORTED", "UNKNOWN"]

StepStatus = Literal["satisfied", "not_satisfied", "unknown", "skipped", "unsupported"]

GPU_LADDER_STEPS: tuple[GpuLadderStep, ...] = (
    "DETECTED",
    "DRIVER_READY",
    "VULKAN_READY",
    "ROCM_READY",
    "HIP_READY",
    "FRAMEWORK_READY",
    "APPLICATION_READY",
)

NPU_LADDER_STEPS: tuple[NpuLadderStep, ...] = (
    "DETECTED",
    "DRIVER_READY",
    "FIRMWARE_READY",
    "RUNTIME_READY",
    "BACKEND_READY",
    "MODEL_READY",
    "APPLICATION_READY",
)


def _known(value: Any) -> bool:
    return value not in (None, "", "unknown", "UNKNOWN")


def _gpu_devices(hardware: dict[str, Any]) -> list[dict[str, Any]]:
    gpu = hardware.get("gpu") or {}
    devices = gpu.get("devices") or []
    return [device for device in devices if isinstance(device, dict)]


def _gpu_detected(hardware: dict[str, Any]) -> tuple[bool, list[str]]:
    devices = _gpu_devices(hardware)
    evidence: list[str] = []
    for device in devices:
        vendor = device.get("vendor_id")
        device_id = device.get("device_id")
        if _known(vendor) and _known(device_id):
            evidence.append(f"pci:{vendor}:{device_id}")
        elif _known(device.get("device_name")):
            evidence.append(str(device.get("device_name")))
    if evidence:
        return True, evidence
    gpu = hardware.get("gpu") or {}
    if _known(gpu.get("arch")):
        return True, [f"arch:{gpu.get('arch')}"]
    if _known(gpu.get("text")):
        return True, ["gpu.text"]
    return False, []


def _gpu_amd_vendor(hardware: dict[str, Any]) -> bool:
    for device in _gpu_devices(hardware):
        vendor = str(device.get("vendor_id", "")).lower().removeprefix("0x")
        if vendor == "1002":
            return True
    return False


def _gpu_driver_ready(hardware: dict[str, Any]) -> tuple[bool, list[str]]:
    gpu = hardware.get("gpu") or {}
    if gpu.get("amdgpu_module") == "loaded":
        return True, ["amdgpu module loaded"]
    for device in _gpu_devices(hardware):
        if device.get("bound_driver") == "amdgpu":
            return True, ["amdgpu bound driver"]
    return False, []


def _npu_present(hardware: dict[str, Any]) -> tuple[bool, list[str]]:
    npu = hardware.get("npu") or {}
    if npu.get("present") is True:
        evidence = [text for text in (npu.get("module_text"), npu.get("device_text")) if _known(text)]
        return True, evidence or ["npu.present"]
    return False, []


def _npu_driver_ready(hardware: dict[str, Any]) -> tuple[bool, list[str]]:
    npu = hardware.get("npu") or {}
    module_text = str(npu.get("module_text") or "")
    if "amdxdna" in module_text.lower():
        return True, ["amdxdna module"]
    for device in npu.get("devices") or []:
        if isinstance(device, dict) and device.get("bound_driver") == "amdxdna":
            return True, ["amdxdna bound driver"]
    return False, []


def _step_entry(step_id: str, status: StepStatus, evidence: list[str]) -> dict[str, Any]:
    return {"id": step_id, "status": status, "evidence": evidence}


def _highest_satisfied(steps: list[dict[str, Any]], ordered_ids: tuple[str, ...]) -> str | None:
    current: str | None = None
    for step_id in ordered_ids:
        step = next((item for item in steps if item["id"] == step_id), None)
        if step is None:
            break
        if step["status"] == "satisfied":
            current = step_id
            continue
        break
    return current


def _assessment_from_steps(steps: list[dict[str, Any]], ordered_ids: tuple[str, ...]) -> AssessmentState:
    if not steps:
        return "UNKNOWN"
    first = steps[0]
    if first["status"] == "unsupported":
        return "UNSUPPORTED"
    if first["status"] in {"unknown", "skipped"} and first["id"] == ordered_ids[0]:
        return "UNKNOWN"
    if all(step["status"] in {"unknown", "skipped"} for step in steps):
        return "UNKNOWN"
    current = _highest_satisfied(steps, ordered_ids)
    if current is None:
        if any(step["status"] == "not_satisfied" for step in steps):
            return "DEGRADED"
        return "UNKNOWN"
    if current == ordered_ids[-1]:
        return "READY"
    later_blocked = any(
        step["status"] == "not_satisfied"
        for step in steps
        if ordered_ids.index(step["id"]) > ordered_ids.index(current)
    )
    if later_blocked:
        return "DEGRADED"
    if current == ordered_ids[0]:
        return "AVAILABLE"
    return "AVAILABLE"


def build_ladder_document(
    domain: Literal["gpu", "npu"],
    steps: list[dict[str, Any]],
    *,
    validation_claim: bool = False,
) -> dict[str, Any]:
    """Return a portable ladder document suitable for Stage 2 visibility reports."""
    ordered = GPU_LADDER_STEPS if domain == "gpu" else NPU_LADDER_STEPS
    current = _highest_satisfied(steps, ordered)
    return {
        "domain": domain,
        "current": current,
        "assessment": _assessment_from_steps(steps, ordered),
        "steps": steps,
        "validation_claim": validation_claim,
    }


def gpu_ladder_from_hardware(hardware: dict[str, Any]) -> dict[str, Any]:
    """Derive probe-only GPU ladder steps from normalized Stage 1 hardware facts."""
    detected, detected_evidence = _gpu_detected(hardware)
    driver_ready, driver_evidence = _gpu_driver_ready(hardware)
    amd_gpu = _gpu_amd_vendor(hardware)
    if detected and not amd_gpu:
        driver_status: StepStatus = "unsupported"
    elif driver_ready:
        driver_status = "satisfied"
    elif detected:
        driver_status = "not_satisfied"
    else:
        driver_status = "not_satisfied"
    steps = [
        _step_entry(
            "DETECTED",
            "satisfied" if detected else "not_satisfied",
            detected_evidence,
        ),
        _step_entry("DRIVER_READY", driver_status, driver_evidence),
        _step_entry("VULKAN_READY", "unknown", []),
        _step_entry("ROCM_READY", "unknown", []),
        _step_entry("HIP_READY", "unknown", []),
        _step_entry("FRAMEWORK_READY", "unknown", []),
        _step_entry("APPLICATION_READY", "unknown", []),
    ]
    if not detected:
        steps[0]["status"] = "unsupported"
        for step in steps[1:]:
            step["status"] = "skipped"
    elif not amd_gpu:
        for step in steps[2:]:
            step["status"] = "skipped"
    return build_ladder_document("gpu", steps)


def gpu_ladder_from_visibility(
    hardware: dict[str, Any],
    checks: dict[str, Any],
) -> dict[str, Any]:
    """Merge Stage 1 hardware facts with Stage 2 GPU visibility checks."""
    document = gpu_ladder_from_hardware(hardware)
    steps = {step["id"]: step for step in document["steps"]}
    if not _gpu_detected(hardware)[0]:
        return document

    vulkan_visible = str(checks.get("vulkan", "")).lower() == "visible"
    rocm_visible = str(checks.get("rocm", "")).lower() == "visible"
    opencl_visible = str(checks.get("opencl", "")).lower() == "visible"

    steps["VULKAN_READY"]["status"] = "satisfied" if vulkan_visible else "not_satisfied"
    steps["VULKAN_READY"]["evidence"] = ["vulkan visible"] if vulkan_visible else []

    steps["ROCM_READY"]["status"] = "satisfied" if rocm_visible else "not_satisfied"
    steps["ROCM_READY"]["evidence"] = ["rocminfo visible"] if rocm_visible else []

    hip_visible = rocm_visible or opencl_visible
    steps["HIP_READY"]["status"] = "satisfied" if hip_visible else "not_satisfied"
    steps["HIP_READY"]["evidence"] = (
        ["rocminfo visible"] if rocm_visible else (["opencl visible"] if opencl_visible else [])
    )

    steps["FRAMEWORK_READY"]["status"] = "unknown"
    steps["APPLICATION_READY"]["status"] = "unknown"
    merged = [steps[step_id] for step_id in GPU_LADDER_STEPS]
    return build_ladder_document("gpu", merged)


def npu_ladder_from_hardware(hardware: dict[str, Any]) -> dict[str, Any]:
    """Derive probe-only NPU ladder steps from normalized Stage 1 hardware facts."""
    present, present_evidence = _npu_present(hardware)
    driver_ready, driver_evidence = _npu_driver_ready(hardware)
    steps = [
        _step_entry(
            "DETECTED",
            "satisfied" if present else "not_satisfied",
            present_evidence,
        ),
        _step_entry(
            "DRIVER_READY",
            "satisfied" if driver_ready else ("not_satisfied" if present else "not_satisfied"),
            driver_evidence,
        ),
        _step_entry("FIRMWARE_READY", "unknown", []),
        _step_entry("RUNTIME_READY", "unknown", []),
        _step_entry("BACKEND_READY", "unknown", []),
        _step_entry("MODEL_READY", "unknown", []),
        _step_entry("APPLICATION_READY", "unknown", []),
    ]
    if not present:
        steps[0]["status"] = "unsupported"
        for step in steps[1:]:
            step["status"] = "skipped"
    return build_ladder_document("npu", steps)


def npu_ladder_from_visibility(
    hardware: dict[str, Any],
    checks: dict[str, Any],
) -> dict[str, Any]:
    """Merge Stage 1 hardware facts with Stage 2 NPU visibility checks."""
    document = npu_ladder_from_hardware(hardware)
    steps = {step["id"]: step for step in document["steps"]}
    if not _npu_present(hardware)[0]:
        return document

    firmware_ready = checks.get("firmware_ready") is True
    runtime_ready = checks.get("runtime_ready") is True
    backend_ready = checks.get("backend_ready") is True

    steps["FIRMWARE_READY"]["status"] = (
        "satisfied" if firmware_ready else ("unknown" if checks.get("firmware_ready") is None else "not_satisfied")
    )
    steps["FIRMWARE_READY"]["evidence"] = ["firmware visible"] if firmware_ready else []

    steps["RUNTIME_READY"]["status"] = (
        "satisfied" if runtime_ready else ("unknown" if checks.get("runtime_ready") is None else "not_satisfied")
    )
    steps["RUNTIME_READY"]["evidence"] = ["runtime visible"] if runtime_ready else []

    steps["BACKEND_READY"]["status"] = (
        "satisfied" if backend_ready else ("unknown" if checks.get("backend_ready") is None else "not_satisfied")
    )
    steps["BACKEND_READY"]["evidence"] = ["backend visible"] if backend_ready else []

    steps["MODEL_READY"]["status"] = "unknown"
    steps["APPLICATION_READY"]["status"] = "unknown"
    merged = [steps[step_id] for step_id in NPU_LADDER_STEPS]
    return build_ladder_document("npu", merged)


def hardware_from_live_gpu_checks(checks: dict[str, Any]) -> dict[str, Any]:
    """Build a minimal hardware dict from live Stage 2 GPU visibility probes."""
    gpu_text = str(checks.get("gpu_text") or "")
    gpu_arch = checks.get("gpu_arch")
    amdgpu_loaded = str(checks.get("amdgpu", "")).lower() == "loaded"
    devices: list[dict[str, Any]] = []
    if gpu_text or _known(gpu_arch):
        vendor_id = "1002" if amdgpu_loaded or "1002" in gpu_text.lower() or "amd" in gpu_text.lower() else None
        if vendor_id:
            devices.append({"vendor_id": vendor_id, "device_name": gpu_text.splitlines()[0] if gpu_text else None})
        elif gpu_text:
            devices.append({"device_name": gpu_text.splitlines()[0]})
    return {
        "gpu": {
            "text": gpu_text,
            "arch": gpu_arch,
            "devices": devices,
            "amdgpu_module": "loaded" if amdgpu_loaded else "",
        },
        "npu": {
            "present": False,
            "module_text": "",
            "device_text": "",
            "devices": [],
            "device_nodes": [],
        },
    }


def hardware_from_live_npu_checks(checks: dict[str, Any]) -> dict[str, Any]:
    """Build a minimal hardware dict from live Stage 2 NPU visibility probes."""
    module_present = checks.get("module_present") is True
    device_nodes_present = checks.get("device_nodes_present") is True
    module_text = str(checks.get("module_text") or "")
    device_text = str(checks.get("device_text") or "")
    if module_present and "amdxdna" not in module_text.lower():
        module_text = "amdxdna"
    node_list = [line for line in device_text.splitlines() if line.strip()]
    if not node_list and device_nodes_present:
        node_list = [str(node) for node in (checks.get("device_nodes") or []) if node]
        device_text = "\n".join(node_list)
    present = module_present or device_nodes_present or bool(node_list) or bool(device_text)
    devices: list[dict[str, Any]] = []
    if present:
        devices.append(
            {
                "bound_driver": "amdxdna" if module_present or "amdxdna" in module_text.lower() else None,
                "device_name": node_list[0] if node_list else (device_text.splitlines()[0] if device_text else None),
            }
        )
    return {
        "gpu": {
            "text": "",
            "arch": None,
            "devices": [],
            "amdgpu_module": "",
        },
        "npu": {
            "present": present,
            "module_text": module_text,
            "device_text": device_text,
            "devices": devices,
            "device_nodes": node_list,
        },
    }


def target_gpu_arch_from_profile(profile: dict[str, Any] | None) -> str | None:
    """Return the reference GPU architecture from a consumed system profile."""
    if not profile:
        return None
    gpus = profile.get("gpus") or []
    if not gpus:
        return None
    architecture = gpus[0].get("architecture")
    return str(architecture) if _known(architecture) else None


def consumed_profile_from_system_profile(
    profile: dict[str, Any] | None,
    *,
    artifact: str | None = "s1-m5-system-profile.json",
) -> dict[str, Any]:
    """Build the consumed-profile reference block for Stage 2 visibility reports."""
    if not profile:
        return {
            "artifact": artifact,
            "schema": {
                "name": "ai370-system-profile",
                "version": 3,
                "uri": "https://ai370.local/schemas/system-profile-v3.json",
            },
            "fingerprint": {"algorithm": "sha256", "algorithm_version": 1, "value": None},
        }
    fingerprint = profile.get("fingerprint") or {}
    schema = profile.get("schema") or {}
    return {
        "artifact": artifact,
        "schema": {
            "name": schema.get("name", "ai370-system-profile"),
            "version": schema.get("version", 3),
            "uri": schema.get("uri", "https://ai370.local/schemas/system-profile-v3.json"),
        },
        "fingerprint": {
            "algorithm": fingerprint.get("algorithm", "sha256"),
            "algorithm_version": fingerprint.get("algorithm_version", 1),
            "value": fingerprint.get("value"),
        },
    }


def visibility_status_from_ladder(ladder: dict[str, Any]) -> GateStatus:
    """Map ladder assessment to Stage 2 gate vocabulary without claiming execution."""
    assessment = str(ladder.get("assessment", "UNKNOWN"))
    if assessment == "UNSUPPORTED":
        return "UNSUPPORTED"
    if assessment == "READY":
        return "PASS"
    if assessment in {"AVAILABLE", "DEGRADED", "UNKNOWN"}:
        return "WARN"
    return "WARN"


def normalize_gpu_checks(checks: dict[str, Any], hardware: dict[str, Any]) -> dict[str, Any]:
    """Normalize GPU visibility checks for the S2-M3 report contract."""
    gpu = hardware.get("gpu") or {}
    amdgpu_loaded = gpu.get("amdgpu_module") == "loaded" or any(
        device.get("bound_driver") == "amdgpu" for device in _gpu_devices(hardware)
    )
    gpu_arch = checks.get("gpu_arch", gpu.get("arch"))
    return {
        "amdgpu": "loaded" if amdgpu_loaded else ("missing" if _gpu_detected(hardware)[0] else "unknown"),
        "gpu_arch": str(gpu_arch) if _known(gpu_arch) else None,
        "vulkan": checks.get("vulkan", "unknown"),
        "opencl": checks.get("opencl", "unknown"),
        "rocm": checks.get("rocm", "unknown"),
    }


def normalize_npu_checks(checks: dict[str, Any], hardware: dict[str, Any]) -> dict[str, Any]:
    """Normalize NPU visibility checks for the S2-M4 report contract."""
    npu = hardware.get("npu") or {}
    module_present = checks.get("module_present")
    if module_present is None:
        module_present = "amdxdna" in str(npu.get("module_text") or "").lower()
    device_nodes_present = checks.get("device_nodes_present")
    if device_nodes_present is None:
        device_nodes_present = bool(npu.get("device_nodes") or npu.get("device_text"))
    return {
        "module_present": module_present if module_present is not None else None,
        "device_nodes_present": device_nodes_present if device_nodes_present is not None else None,
        "firmware_ready": checks.get("firmware_ready"),
        "runtime_ready": checks.get("runtime_ready"),
        "backend_ready": checks.get("backend_ready"),
    }


def build_s2_m3_visibility_report(
    hardware: dict[str, Any],
    checks: dict[str, Any],
    consumed_profile: dict[str, Any] | None = None,
    *,
    notes: list[str] | None = None,
) -> dict[str, Any]:
    """Build the canonical S2-M3 GPU runtime visibility report document."""
    normalized_checks = normalize_gpu_checks(checks, hardware)
    ladder = gpu_ladder_from_visibility(hardware, normalized_checks)
    return {
        "schema": {
            "name": "s2-m3-gpu-runtime-visibility",
            "version": 1,
            "uri": "https://ai370.local/schemas/s2-m3-gpu-runtime-visibility-v1.json",
        },
        "stage": 2,
        "milestone": "S2-M3",
        "artifact": "s2-m3-gpu-runtime-visibility",
        "consumed_profile": consumed_profile or consumed_profile_from_system_profile(None),
        "status": visibility_status_from_ladder(ladder),
        "checks": normalized_checks,
        "ladder": ladder,
        "notes": notes
        or [
            "Visibility assessment only; package presence is not workload execution.",
            "Ladder steps above HIP remain unknown until Stage 3 runtime validation.",
        ],
    }


def build_s2_m4_visibility_report(
    hardware: dict[str, Any],
    checks: dict[str, Any],
    consumed_profile: dict[str, Any] | None = None,
    *,
    notes: list[str] | None = None,
) -> dict[str, Any]:
    """Build the canonical S2-M4 NPU runtime visibility report document."""
    normalized_checks = normalize_npu_checks(checks, hardware)
    ladder = npu_ladder_from_visibility(hardware, normalized_checks)
    return {
        "schema": {
            "name": "s2-m4-npu-runtime-validation",
            "version": 1,
            "uri": "https://ai370.local/schemas/s2-m4-npu-runtime-validation-v1.json",
        },
        "stage": 2,
        "milestone": "S2-M4",
        "artifact": "s2-m4-npu-runtime-validation",
        "consumed_profile": consumed_profile or consumed_profile_from_system_profile(None),
        "status": visibility_status_from_ladder(ladder),
        "checks": normalized_checks,
        "ladder": ladder,
        "notes": notes
        or [
            "Visibility assessment only; backend registration is not executed inference.",
            "MODEL_READY and APPLICATION_READY remain unknown in Stage 2 visibility.",
        ],
    }
