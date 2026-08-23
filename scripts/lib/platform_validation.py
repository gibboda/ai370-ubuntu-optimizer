"""S2-M7 platform validation aggregate.

S2-M7 consumes Stage 1 profile facts and Stage 2 milestone reports. It does
not re-probe PCI, sysfs, or modules. The canonical Stage 1 profile is
required; leftover ``tier1-*`` reports are not an unbound PASS. Milestone
reports that carry ``consumed_profile`` must match the current fingerprint or
they are treated as missing. Reference-platform gfx1150/NPU acceptance is
policy here; ``--strict`` is the opt-in that elevates those misses to FAIL.
Generic hosts are not required to match the EliteMini AI370 identity unless
that flag is set.

Child visibility ``UNSUPPORTED`` or ``WARN`` does not fail the aggregate.
Child ``FAIL`` does. Missing gfx1150/NPU without ``--strict`` is recorded in
``warnings`` without demoting overall ``PASS``.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import capability_ladder
import firmware_policy
import system_profile

PROJECT_ROOT = Path(__file__).resolve().parents[2]
S2_M7_SCHEMA = PROJECT_ROOT / "configs/schemas/s2-m7-platform-validation.schema.json"
S2_M7_ARTIFACT = "s2-m7-platform-validation"
COMPAT_RELATIVE = "reports/latest"

MILESTONE_SPECS: tuple[dict[str, Any], ...] = (
    {
        "id": "S2-M1",
        "canonical": "s2-m1-firmware-validation.json",
        "compat": "tier1-firmware-validation.json",
        "required_scopes": ("inventory", "full", "smoke"),
    },
    {
        "id": "S2-M2",
        "canonical": "s2-m2-kernel-driver-validation.json",
        "compat": "tier1-kernel-plan.json",
        "required_scopes": ("inventory", "full", "smoke"),
    },
    {
        "id": "S2-M3",
        "canonical": "s2-m3-gpu-runtime-visibility.json",
        "compat": "tier1-gpu-stack.json",
        "required_scopes": ("inventory", "full", "smoke"),
    },
    {
        "id": "S2-M4",
        "canonical": "s2-m4-npu-runtime-validation.json",
        "compat": "tier1-npu.json",
        "required_scopes": ("full", "smoke"),
    },
    {
        "id": "S2-M5",
        "canonical": "s2-m5-optimization-plan.json",
        "compat": "tier1-platform-tuning.json",
        "required_scopes": ("full", "smoke"),
    },
)


def load_optional_json(path: Path) -> dict[str, Any] | None:
    """Return a JSON object from path, or None when missing or unreadable."""
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None


def normalize_scope(scope: str) -> str:
    """Map caller scope to inventory, full, or smoke."""
    if scope in {"inventory", "full", "smoke"}:
        return scope
    if scope in {"true", "false"}:
        return "full"
    return "full"


def normalize_strict(value: Any) -> bool:
    """True when strict reference-platform acceptance is requested."""
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in {"true", "1", "yes", "on"}


def _known(value: Any) -> bool:
    return value not in (None, "", "unknown", "UNKNOWN")


def _ladder_step_satisfied(report: dict[str, Any] | None, step_id: str) -> bool:
    if not report:
        return False
    ladder = report.get("ladder") or {}
    for step in ladder.get("steps") or []:
        if isinstance(step, dict) and step.get("id") == step_id:
            return step.get("status") == "satisfied"
    return False


def _document_status(document: dict[str, Any] | None) -> str | None:
    if not document:
        return None
    status = document.get("status")
    if status is None:
        return None
    text = str(status).strip().upper()
    return text or None


def _fingerprint_value(source: Any) -> str | None:
    """Return a fingerprint string, or None when unset, empty, or unknown."""
    if source is None:
        return None
    if isinstance(source, str):
        text = source.strip()
        if not text or text.lower() in {"unknown", "none", "null"}:
            return None
        return text
    if isinstance(source, dict):
        return _fingerprint_value(source.get("value"))
    return None


def document_is_stale_for_profile(
    profile: dict[str, Any],
    document: dict[str, Any],
) -> bool:
    """True when a report's consumed fingerprint does not match the current profile.

    Documents without ``consumed_profile`` are compatibility files and are not
    treated as stale here. Fingerprint-bearing reports must match:

    - both non-null and equal → accept
    - profile non-null and child different or null → stale
    - profile null → accept only when the child fingerprint is also null
    """
    consumed = document.get("consumed_profile")
    if not isinstance(consumed, dict):
        return False
    child_fp = _fingerprint_value(consumed.get("fingerprint"))
    profile_fp = _fingerprint_value(profile.get("fingerprint"))
    if profile_fp is None:
        return child_fp is not None
    return child_fp != profile_fp


def _stale_missing_entry(
    spec: dict[str, Any],
    *,
    artifact: str,
    warning: str,
    rejected_canonical: bool,
) -> dict[str, Any]:
    return {
        "id": spec["id"],
        "artifact": artifact,
        "status": "MISSING",
        "canonical": False,
        "document": None,
        "stale_warning": warning,
        "rejected_canonical": rejected_canonical,
    }


def collect_milestone(
    reports_dir: Path,
    spec: dict[str, Any],
    scope: str,
    profile: dict[str, Any],
) -> dict[str, Any]:
    """Resolve one Stage 2 milestone from canonical JSON, else compatibility JSON."""
    canonical_path = reports_dir / spec["canonical"]
    compat_path = reports_dir / spec["compat"]
    canonical = load_optional_json(canonical_path)
    compat = load_optional_json(compat_path)
    required = scope in spec["required_scopes"]
    empty = {
        "stale_warning": None,
        "rejected_canonical": False,
    }
    if canonical:
        if document_is_stale_for_profile(profile, canonical):
            return _stale_missing_entry(
                spec,
                artifact=spec["canonical"],
                warning=(
                    f"{spec['id']} report fingerprint does not match the current "
                    f"Stage 1 profile; treating {spec['canonical']} as missing."
                ),
                rejected_canonical=True,
            )
        status = _document_status(canonical) or "PASS"
        return {
            "id": spec["id"],
            "artifact": spec["canonical"],
            "status": status,
            "canonical": True,
            "document": canonical,
            **empty,
        }
    if not required:
        return {
            "id": spec["id"],
            "artifact": None,
            "status": "SKIPPED",
            "canonical": False,
            "document": None,
            **empty,
        }
    if compat:
        if document_is_stale_for_profile(profile, compat):
            return _stale_missing_entry(
                spec,
                artifact=spec["compat"],
                warning=(
                    f"{spec['id']} report fingerprint does not match the current "
                    f"Stage 1 profile; treating {spec['compat']} as missing."
                ),
                rejected_canonical=False,
            )
        status = _document_status(compat) or "PASS"
        return {
            "id": spec["id"],
            "artifact": spec["compat"],
            "status": status,
            "canonical": False,
            "document": compat,
            **empty,
        }
    return {
        "id": spec["id"],
        "artifact": spec["compat"],
        "status": "MISSING",
        "canonical": False,
        "document": None,
        **empty,
    }


def expected_compat_artifacts(scope: str) -> list[str]:
    """Compatibility filenames 90-validate historically required."""
    names = [
        "tier1-hardware.json",
        "tier1-firmware.json",
        "tier1-firmware-validation.json",
        "tier1-kernel-plan.json",
        "tier1-gpu-stack.json",
        "tier1-npu.json",
    ]
    if scope in {"full", "smoke"}:
        names.append("tier1-platform-tuning.json")
    if scope == "smoke":
        names.append("tier1-local-ai-benchmark.json")
    return names


def gpu_arch_from_inputs(
    *,
    s2_m3: dict[str, Any] | None,
    profile: dict[str, Any] | None,
    gpu_stack: dict[str, Any] | None,
) -> str | None:
    """GPU architecture from S2-M3, then the consumed profile, then compat GPU JSON."""
    if s2_m3:
        checks = s2_m3.get("checks") or {}
        arch = checks.get("gpu_arch")
        if _known(arch):
            return str(arch)
    if profile:
        arch = capability_ladder.target_gpu_arch_from_profile(profile)
        if _known(arch):
            return str(arch)
    if gpu_stack:
        arch = gpu_stack.get("gpu_arch")
        if _known(arch):
            return str(arch)
    return None


def npu_present_from_inputs(
    *,
    s2_m4: dict[str, Any] | None,
    profile: dict[str, Any] | None,
    npu_compat: dict[str, Any] | None,
) -> bool | None:
    """NPU presence from S2-M4 visibility, then profile identity, then compat NPU JSON."""
    if s2_m4:
        checks = s2_m4.get("checks") or {}
        module_present = checks.get("module_present")
        device_nodes = checks.get("device_nodes_present")
        if isinstance(module_present, bool) or isinstance(device_nodes, bool):
            return bool(module_present) or bool(device_nodes)
        if _ladder_step_satisfied(s2_m4, "DETECTED"):
            return True
        return False
    if profile:
        hardware = system_profile.hardware_from_system_profile(profile)
        npu = hardware.get("npu") or {}
        if npu.get("present") is True:
            return True
        if npu.get("devices"):
            return True
        return False
    if npu_compat:
        amdxdna = npu_compat.get("amdxdna") or {}
        present = amdxdna.get("present")
        if isinstance(present, bool):
            return present
    return None


def vulkan_state_from_inputs(
    *,
    s2_m3: dict[str, Any] | None,
    gpu_stack: dict[str, Any] | None,
) -> str:
    """Vulkan visibility from S2-M3 or compat GPU JSON. Never live-probes vulkaninfo."""
    for document in (s2_m3, gpu_stack):
        if not document:
            continue
        checks = document.get("checks") if "checks" in document else document
        vulkan = (checks or {}).get("vulkan")
        if vulkan in {"visible", "not-visible", "unknown", "not-applicable"}:
            return str(vulkan)
        if vulkan is True or vulkan == "true":
            return "visible"
    return "unknown"


def amdgpu_state_from_inputs(
    *,
    s2_m3: dict[str, Any] | None,
    gpu_stack: dict[str, Any] | None,
) -> str:
    for document in (s2_m3, gpu_stack):
        if not document:
            continue
        checks = document.get("checks") if "checks" in document else document
        amdgpu = (checks or {}).get("amdgpu")
        if amdgpu in {"loaded", "missing", "unknown"}:
            return str(amdgpu)
    return "unknown"


def bios_acceptable_from_inputs(
    *,
    s2_m1: dict[str, Any] | None,
    firmware_compat: dict[str, Any] | None,
) -> str:
    """BIOS policy from S2-M1 or compat firmware JSON. Never live-reads DMI."""
    for document in (s2_m1, firmware_compat):
        if not document:
            continue
        policy = document.get("policy") if isinstance(document.get("policy"), dict) else {}
        for value in (document.get("bios_acceptable"), policy.get("bios_acceptable")):
            if value in {"true", "false", "unknown", True, False}:
                if value is True:
                    return "true"
                if value is False:
                    return "false"
                return str(value)
    return "unknown"


def build_s2_m7_platform_validation_report(
    reports_dir: Path,
    *,
    profile: dict[str, Any],
    scope: str = "full",
    strict: bool = False,
    cli_profile: str = "ai370",
) -> dict[str, Any]:
    """Aggregate milestone reports and profile facts into the S2-M7 document."""
    scope = normalize_scope(scope)
    strict = normalize_strict(strict)
    reports_dir = Path(reports_dir)

    collected = [
        collect_milestone(reports_dir, spec, scope, profile) for spec in MILESTONE_SPECS
    ]
    by_id = {entry["id"]: entry for entry in collected}
    s2_m1 = by_id["S2-M1"]["document"]
    s2_m3_entry = by_id["S2-M3"]
    s2_m4_entry = by_id["S2-M4"]
    s2_m3 = s2_m3_entry["document"] if s2_m3_entry["canonical"] else None
    s2_m4 = s2_m4_entry["document"] if s2_m4_entry["canonical"] else None
    gpu_stack = load_optional_json(reports_dir / "tier1-gpu-stack.json")
    npu_compat = load_optional_json(reports_dir / "tier1-npu.json")
    firmware_compat = load_optional_json(reports_dir / "tier1-firmware.json")
    gpu_stack_for_facts = None if s2_m3_entry["rejected_canonical"] else gpu_stack
    npu_compat_for_facts = None if s2_m4_entry["rejected_canonical"] else npu_compat
    if s2_m3 is None and gpu_stack_for_facts:
        s2_m3_checks_source = gpu_stack_for_facts
    else:
        s2_m3_checks_source = s2_m3

    gpu_arch = gpu_arch_from_inputs(
        s2_m3=s2_m3, profile=profile, gpu_stack=gpu_stack_for_facts
    )
    npu_present = npu_present_from_inputs(
        s2_m4=s2_m4, profile=profile, npu_compat=npu_compat_for_facts
    )
    vulkan = vulkan_state_from_inputs(
        s2_m3=s2_m3_checks_source, gpu_stack=gpu_stack_for_facts
    )
    amdgpu = amdgpu_state_from_inputs(
        s2_m3=s2_m3_checks_source, gpu_stack=gpu_stack_for_facts
    )
    bios_acc = bios_acceptable_from_inputs(s2_m1=s2_m1, firmware_compat=firmware_compat)
    classified = firmware_policy.classified_platform_id(profile)

    gfx_ok = gpu_arch == "gfx1150"
    npu_ok = npu_present is True
    vulkan_ok = vulkan == "visible"

    status = "PASS"
    failures: list[str] = []
    warnings: list[str] = []

    def record_fail(message: str) -> None:
        nonlocal status
        status = "FAIL"
        failures.append(message)

    def record_warn(message: str) -> None:
        nonlocal status
        if status == "PASS":
            status = "WARN"
        warnings.append(message)

    def record_acceptance(message: str) -> None:
        if strict:
            record_fail(f"{message} (strict)")
        else:
            warnings.append(message)

    if not gfx_ok:
        seen = gpu_arch if gpu_arch else "unknown"
        record_acceptance(
            f"Radeon 890M / gfx1150 not detected (saw: {seen}). Check amdgpu firmware/kernel."
        )
    if not npu_ok:
        record_acceptance(
            "AMDXDNA / XDNA2 NPU not detected. Kernel module or device node missing. "
            "(Tier 3 is experimental.)"
        )
    if not vulkan_ok:
        record_warn("Vulkan not clearly validated in Stage 2 GPU visibility reports.")
    if bios_acc == "false":
        record_warn(
            f"BIOS version not at target for classified platform "
            f"{classified or cli_profile} (see firmware report)."
        )

    # Stage 1 profile + S2-M4 replace the 10-detect-hardware inventory files.
    profile_superseded_compat = frozenset({"tier1-hardware.json", "tier1-npu.json"})
    for name in expected_compat_artifacts(scope):
        if name in profile_superseded_compat:
            continue
        if not (reports_dir / name).is_file():
            record_warn(f"Expected Tier 1 artifact missing: {name}")

    for entry in collected:
        if entry.get("stale_warning"):
            warnings.append(entry["stale_warning"])
        if entry["status"] == "FAIL":
            record_fail(f"{entry['id']} status is FAIL ({entry['artifact']})")

    notes = _notes_for_scope(scope, strict)
    artifacts = {
        "hardware": f"{COMPAT_RELATIVE}/tier1-hardware.json",
        "kernel": f"{COMPAT_RELATIVE}/tier1-kernel-plan.json",
        "gpu_stack": f"{COMPAT_RELATIVE}/tier1-gpu-stack.json",
        "npu": f"{COMPAT_RELATIVE}/tier1-npu.json",
        "firmware": f"{COMPAT_RELATIVE}/tier1-firmware.json",
        "firmware_validation": f"{COMPAT_RELATIVE}/tier1-firmware-validation.json",
        "platform_tuning": (
            f"{COMPAT_RELATIVE}/tier1-platform-tuning.json"
            if scope in {"full", "smoke"}
            else None
        ),
        "local_ai": (
            f"{COMPAT_RELATIVE}/tier1-local-ai-benchmark.json" if scope == "smoke" else None
        ),
    }

    return {
        "schema": {
            "name": "s2-m7-platform-validation",
            "version": 1,
            "uri": "https://ai370.local/schemas/s2-m7-platform-validation-v1.json",
        },
        "stage": 2,
        "milestone": "S2-M7",
        "artifact": S2_M7_ARTIFACT,
        "consumed_profile": capability_ladder.consumed_profile_from_system_profile(profile),
        "status": status,
        "scope": scope,
        "strict": strict,
        "cli_profile": cli_profile,
        "classified_platform_id": classified,
        "acceptance": {
            "radeon_890m_gfx1150": gfx_ok,
            "amdxdna_npu": npu_ok,
            "vulkan_validated": vulkan_ok,
            "bios_version_acceptable": bios_acc,
            "inventory_only": scope == "inventory",
            "ai_smoke_required": scope == "smoke",
        },
        "checks": {
            "gpu_arch": gpu_arch,
            "npu_present": npu_present,
            "vulkan": vulkan,
            "amdgpu": amdgpu,
            "bios_acceptable": bios_acc,
        },
        "milestones": [
            {
                "id": entry["id"],
                "artifact": entry["artifact"],
                "status": entry["status"],
                "canonical": entry["canonical"],
            }
            for entry in collected
        ],
        "artifacts": artifacts,
        "failures": failures,
        "warnings": warnings,
        "notes": notes,
    }


def _notes_for_scope(scope: str, strict: bool) -> list[str]:
    notes: list[str] = [
        "S2-M7 aggregates Stage 2 milestone reports and Stage 1 profile facts; "
        "it does not re-detect GPU architecture or NPU presence from sysfs/PCI. "
        "The Stage 1 profile is required. Milestone reports whose consumed "
        "fingerprint does not match the current profile are treated as missing.",
        "Child GPU/NPU visibility UNSUPPORTED or WARN does not fail this aggregate. "
        "Missing gfx1150/NPU is reference-platform acceptance, not generic policy, "
        "unless --strict / AI370_STAGE1_STRICT is set.",
    ]
    if scope == "inventory":
        notes.append(
            "Inventory-only validation: platform-tuning and local-AI smoke (80) not required. "
            "Run stage2-optimize-plan for platform plans; use scripts/80-benchmark-local-ai.sh "
            "for script 80."
        )
    elif scope == "full":
        notes.append(
            "Platform validation: local-AI smoke (80 / tier1-local-ai-benchmark.json) is optional. "
            "Use scripts/80-benchmark-local-ai.sh (scope=smoke) to require it. "
            "Missing gfx1150/NPU is recorded in warnings[] without demoting status to WARN "
            "(gate stays PASS unless --strict)."
        )
    else:
        notes.append(
            "Smoke-scope validation: requires tier1-local-ai-benchmark.json from script 80 "
            "(./ai370-optimize.sh is read-only Stage 1; use scripts/80-benchmark-local-ai.sh)."
        )
    if strict:
        notes.append(
            "Strict mode: missing gfx1150 or NPU is FAIL (AI370_STAGE1_STRICT / --strict)."
        )
    return notes


def compat_tier1_validation(report: dict[str, Any]) -> dict[str, Any]:
    """Compatibility tier1-validation.json consumed by require_tier123_pass until R2."""
    timestamp = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    return {
        "tier": 1,
        "status": report["status"],
        "scope": report["scope"],
        "strict": report["strict"],
        "timestamp": timestamp,
        "profile": report["cli_profile"],
        "acceptance": {
            **report["acceptance"],
            "rocm_note": (
                "ROCm is validated for visibility only in Stage 2. Full stack install is opt-in."
            ),
        },
        "artifacts": report["artifacts"],
        "failures": list(report["failures"]),
        "warnings": list(report["warnings"]),
        "notes": list(report["notes"]),
        "canonical_artifact": "reports/latest/s2-m7-platform-validation.json",
    }


def compat_summary_markdown(report: dict[str, Any]) -> str:
    """Human summary previously written by 90-validate.sh."""
    gfx_ok = report["acceptance"]["radeon_890m_gfx1150"]
    npu_ok = report["acceptance"]["amdxdna_npu"]
    strict = report["strict"]
    gpu_arch = report["checks"]["gpu_arch"] or "unknown"
    if gfx_ok:
        gfx_label = "PASS"
    elif strict:
        gfx_label = "FAIL"
    else:
        gfx_label = "WARN"
    if npu_ok:
        npu_label = "PASS"
    elif strict:
        npu_label = "FAIL"
    else:
        npu_label = "WARN"

    lines = [
        "# Stage 2 / S2-M7 Platform Validation Summary",
        "",
        f"**Status:** {report['status']}",
        (
            f"Profile: {report['cli_profile']} | Classified: "
            f"{report['classified_platform_id'] or 'unknown'} | "
            f"Scope: {report['scope']} | Strict: {strict}"
        ),
        "",
        "## Acceptance Criteria",
        f"- Radeon 890M (gfx1150): {gfx_label} (detected: {gpu_arch})",
        f"- AMDXDNA / XDNA2 NPU: {npu_label}",
        "- Vulkan validated: (see s2-m3-gpu-runtime-visibility.json / tier1-gpu-stack.json)",
        (
            f"- BIOS version (classified {report['classified_platform_id'] or report['cli_profile']}): "
            f"{report['acceptance']['bios_version_acceptable']}"
        ),
        "- ROCm: visibility-only at this milestone.",
        "",
    ]
    if report["failures"]:
        lines.append("## Failures")
        lines.extend(f"- {item}" for item in report["failures"])
        lines.append("")
    if report["warnings"]:
        lines.append("## Warnings")
        lines.extend(f"- {item}" for item in report["warnings"])
        lines.append("")
    lines.extend(
        [
            "## Scope",
            f"- Validate scope: {report['scope']}",
            f"- Strict gate: {strict}",
        ]
    )
    if report["scope"] == "inventory":
        lines.append("- Inventory-only: platform-tuning and local-AI smoke not required.")
        lines.append(
            "- Run `stage2-optimize-plan` for platform plans; "
            "`scripts/80-benchmark-local-ai.sh` for script 80."
        )
    elif report["scope"] == "full":
        lines.append("- Platform aggregate: local-AI smoke (script 80) is optional.")
        lines.append(
            "- Missing gfx1150/NPU is listed under Warnings without demoting status to WARN;"
        )
        lines.append(
            "  overall PASS still opens the Stage 3 gate. Use --strict for hard AI370 checks."
        )
    else:
        lines.append("- Smoke scope: requires tier1-local-ai-benchmark.json from script 80.")
    lines.extend(
        [
            "",
            "## Next steps",
            "- Run Stage 2 (runtime + NPU) before Stage 3 (ComfyUI / generative).",
            "- Re-check: ./ai370-optimize.sh stage2-platform-validate [--strict]",
            "- Inventory-only re-check: ./ai370-optimize.sh stage2-platform-inventory [--strict]",
            "- Canonical report: reports/latest/s2-m7-platform-validation.json",
            "",
        ]
    )
    return "\n".join(lines)


def publish_s2_m7_platform_validation(
    reports_dir: Path,
    output: Path,
    *,
    profile: dict[str, Any],
    scope: str = "full",
    strict: bool = False,
    cli_profile: str = "ai370",
    compat_output: Path | None = None,
    compat_markdown: Path | None = None,
    compat_status: Path | None = None,
) -> dict[str, Any]:
    """Validate, atomically publish S2-M7, and optionally write compatibility files."""
    report = build_s2_m7_platform_validation_report(
        reports_dir,
        profile=profile,
        scope=scope,
        strict=strict,
        cli_profile=cli_profile,
    )
    system_profile.atomic_write_document(output, report, S2_M7_SCHEMA, "S2-M7")
    if compat_output is not None:
        system_profile.atomic_write_text(
            compat_output,
            json.dumps(compat_tier1_validation(report), indent=2) + "\n",
        )
    if compat_markdown is not None:
        system_profile.atomic_write_text(compat_markdown, compat_summary_markdown(report))
    if compat_status is not None:
        system_profile.atomic_write_text(compat_status, f"{report['status']}\n")
    return report
