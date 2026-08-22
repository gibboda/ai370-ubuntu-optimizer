"""S2-M5 optimization plan and S2-M6 approved application reports.

Planning is the default. Apply requires ``--approve``. These builders do not
run governors, zram, or power-profile commands.
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
S2_M5_SCHEMA = PROJECT_ROOT / "configs/schemas/s2-m5-optimization-plan.schema.json"
S2_M6_SCHEMA = PROJECT_ROOT / "configs/schemas/s2-m6-optimization-application.schema.json"
S2_M5_ARTIFACT = "s2-m5-optimization-plan"
S2_M6_ARTIFACT = "s2-m6-optimization-application"
COMPAT_RELATIVE = "reports/latest"
COMMANDS_RELATIVE = f"{COMPAT_RELATIVE}/tier1-cpu-runtime-commands.sh"


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def proposed_actions_for_mode(mode: str) -> list[dict[str, Any]]:
    """Runtime actions the generated command script may run after --approve."""
    target = "performance" if mode == "aggressive" else "balanced"
    return [
        {
            "id": "power-profile",
            "description": f"Set runtime power profile to {target} via powerprofilesctl",
            "tool": "powerprofilesctl",
            "mutating": True,
        },
        {
            "id": "cpupower-info",
            "description": "Report CPU frequency info when cpupower is present",
            "tool": "cpupower",
            "mutating": False,
        },
    ]


def build_s2_m5_optimization_plan(
    profile: dict[str, Any],
    *,
    facts: dict[str, Any],
    cli_profile: str = "ai370",
    mode: str = "safe",
    persistence: str = "runtime",
) -> dict[str, Any]:
    """Build the canonical S2-M5 plan document. Never records an apply."""
    warnings: list[str] = []
    cpu_source = facts.get("cpu_source") or "live"
    mem_source = facts.get("mem_source") or "live"
    if cpu_source != "s1-m5-system-profile":
        warnings.append("CPU model fell back to a live probe; Stage 1 profile had no CPU name.")
    if mem_source != "s1-m5-system-profile":
        warnings.append(
            "Memory total fell back to a live probe; Stage 1 profile had no memory size."
        )
    status = "WARN" if warnings else "PASS"
    classified = firmware_policy.classified_platform_id(profile)
    return {
        "schema": {
            "name": "s2-m5-optimization-plan",
            "version": 1,
            "uri": "https://ai370.local/schemas/s2-m5-optimization-plan-v1.json",
        },
        "stage": 2,
        "milestone": "S2-M5",
        "artifact": S2_M5_ARTIFACT,
        "consumed_profile": capability_ladder.consumed_profile_from_system_profile(profile),
        "status": status,
        "cli_profile": cli_profile,
        "classified_platform_id": classified,
        "mode": mode,
        "persistence": persistence,
        "plan_only": True,
        "approved": False,
        "cpu": {
            "model": str(facts.get("cpu_model") or ""),
            "target_power": str(facts.get("target_power") or "balanced"),
            "governor": str(facts.get("governor") or ""),
            "identity_source": cpu_source,
        },
        "memory": {
            "total": str(facts.get("mem_total") or ""),
            "zram0": str(facts.get("zram_active") or ""),
            "identity_source": mem_source,
        },
        "storage": {"report": f"{COMPAT_RELATIVE}/tier1-storage.md"},
        "proposed_actions": proposed_actions_for_mode(mode),
        "compatibility_reports": [
            "tier1-platform-tuning.json",
            "tier1-cpu-plan.md",
            "tier1-memory.md",
            "tier1-storage.md",
            "tier1-cpu-runtime-commands.sh",
        ],
        "warnings": warnings,
        "notes": [
            "S2-M5 is plan-only. It does not set power profiles, governors, or zram.",
            "Apply with ./ai370-optimize.sh stage2-optimize-apply --approve "
            "(scripts/40-platform-tuning.sh apply --approve).",
            "Generated commands are written to reports/latest/tier1-cpu-runtime-commands.sh "
            "for review before any apply.",
        ],
    }


def build_s2_m6_optimization_application(
    profile: dict[str, Any],
    *,
    plan: dict[str, Any] | None,
    cli_profile: str = "ai370",
    dry_run: bool = False,
    applied: bool = False,
    commands: str = COMMANDS_RELATIVE,
) -> dict[str, Any]:
    """Build the canonical S2-M6 apply document. Caller must have --approve."""
    warnings: list[str] = []
    if dry_run:
        warnings.append("Dry-run: runtime tuning commands were not executed.")
    if plan is None:
        warnings.append("S2-M5 plan artifact was missing; apply recorded without a consumed plan.")
    status = "WARN" if warnings else "PASS"
    classified = firmware_policy.classified_platform_id(profile)
    plan_artifact = "s2-m5-optimization-plan.json"
    if plan and plan.get("artifact"):
        plan_artifact = f"{plan['artifact']}.json"
    return {
        "schema": {
            "name": "s2-m6-optimization-application",
            "version": 1,
            "uri": "https://ai370.local/schemas/s2-m6-optimization-application-v1.json",
        },
        "stage": 2,
        "milestone": "S2-M6",
        "artifact": S2_M6_ARTIFACT,
        "consumed_profile": capability_ladder.consumed_profile_from_system_profile(profile),
        "status": status,
        "cli_profile": cli_profile,
        "classified_platform_id": classified,
        "approved": True,
        "dry_run": dry_run,
        "applied": applied and not dry_run,
        "plan_artifact": plan_artifact,
        "runtime_apply": {
            "requested": True,
            "applied": applied and not dry_run,
            "dry_run": dry_run,
            "commands": commands,
        },
        "backup": {
            "status": "not-implemented",
            "note": (
                "Configuration backup and rollback remain Planned S2-M6 exit evidence."
            ),
        },
        "warnings": warnings,
        "notes": [
            "S2-M6 requires --approve. AI370_APPLY_TUNING alone does not apply tuning.",
            "Backup and rollback are not implemented; keep S2-M6 In progress until "
            "those exit-evidence tests exist.",
        ],
    }


def compat_tier1_platform_tuning(
    plan: dict[str, Any],
    *,
    runtime_apply: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Compatibility tier1-platform-tuning.json until R1."""
    document: dict[str, Any] = {
        "tier": 1,
        "phase": "platform-tuning",
        "timestamp": _utc_now(),
        "profile": plan["cli_profile"],
        "classified_platform_id": plan["classified_platform_id"],
        "mode": plan["mode"],
        "persistence": plan["persistence"],
        "cpu": dict(plan["cpu"]),
        "memory": dict(plan["memory"]),
        "storage": dict(plan["storage"]),
        "compatibility_reports": list(plan["compatibility_reports"]),
        "consumed_profile": plan["consumed_profile"],
        "canonical_artifact": f"{COMPAT_RELATIVE}/s2-m5-optimization-plan.json",
    }
    if runtime_apply is not None:
        document["runtime_apply"] = runtime_apply
        document["canonical_apply_artifact"] = (
            f"{COMPAT_RELATIVE}/s2-m6-optimization-application.json"
        )
    return document


def plan_markdown(plan: dict[str, Any], *, swap_show: str, nvme: str) -> str:
    """Human plan previously written by 40-platform-tuning.sh."""
    classified = plan["classified_platform_id"] or "unknown"
    cpu = plan["cpu"]
    memory = plan["memory"]
    lines = [
        "# Stage 2 / S2-M5 Optimization Plan",
        "",
        f"Selected CLI profile: {plan['cli_profile']} | Classified platform_id: {classified}",
        f"Mode: {plan['mode']} | Persistence: {plan['persistence']}",
        f"Generated: {_utc_now()}",
        "CPU/memory identity from Stage 1 profile (governor/zram/swap are live runtime).",
        "",
        "## CPU",
        "",
        f"- Target power profile: {cpu['target_power']} (runtime only via powerprofilesctl)",
        f"- Current governor: {cpu['governor'] or 'unknown'}",
        f"- CPU: {cpu['model']}",
        "",
        "## Memory",
        "",
        f"- Total memory: {memory['total']}",
        f"- zram0 active: {memory['zram0']}",
        "- Current swap:",
        swap_show or "(none)",
        "",
        "Recommendations (runtime-only):",
        "- Consider enabling zram for better interactive behavior on 32/64 GB LPDDR5X systems.",
        "- Review swappiness if using heavy local LLM inference.",
        "",
        "## Storage",
        "",
        "### NVMe",
        nvme or "No NVMe devices detected via lsblk",
        "",
        "Review and run the generated commands only after `--approve`:",
        f"  {COMMANDS_RELATIVE}",
        "",
        "Canonical report: reports/latest/s2-m5-optimization-plan.json",
        "",
    ]
    return "\n".join(lines)


def publish_s2_m5_optimization_plan(
    output: Path,
    plan: dict[str, Any],
    *,
    compat_output: Path | None = None,
    compat_markdown: Path | None = None,
    markdown_text: str | None = None,
) -> dict[str, Any]:
    """Validate and atomically publish the S2-M5 plan."""
    system_profile.atomic_write_document(output, plan, S2_M5_SCHEMA, "S2-M5")
    if compat_output is not None:
        system_profile.atomic_write_text(
            compat_output,
            json.dumps(compat_tier1_platform_tuning(plan), indent=2) + "\n",
        )
    if compat_markdown is not None and markdown_text is not None:
        system_profile.atomic_write_text(compat_markdown, markdown_text)
    return plan


def publish_s2_m6_optimization_application(
    output: Path,
    application: dict[str, Any],
    *,
    plan: dict[str, Any] | None = None,
    compat_output: Path | None = None,
) -> dict[str, Any]:
    """Validate and atomically publish the S2-M6 apply report."""
    system_profile.atomic_write_document(output, application, S2_M6_SCHEMA, "S2-M6")
    if compat_output is not None and plan is not None:
        system_profile.atomic_write_text(
            compat_output,
            json.dumps(
                compat_tier1_platform_tuning(
                    plan, runtime_apply=application["runtime_apply"]
                ),
                indent=2,
            )
            + "\n",
        )
    return application
