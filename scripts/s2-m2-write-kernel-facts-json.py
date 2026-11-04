#!/usr/bin/env python3
"""Write S2-M2 kernel/driver facts JSON for 30-validate-kernel.sh.

Internal helper CLI: ``30-validate-kernel.sh`` loads the Stage 1 profile before
calling this writer. Exempt from loading the Stage 1 profile itself (see
``scripts/AGENTS.md``).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import kernel_validation_facts  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="S2-M2 kernel facts JSON writer")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--kernel", default="")
    parser.add_argument("--target-kernel", default="")
    parser.add_argument("--kernel-ok", default="unknown")
    parser.add_argument("--amdgpu-ok", default="unknown")
    parser.add_argument("--amdxdna-seen", default="unknown")
    parser.add_argument("--linux-firmware-state", default="unknown")
    parser.add_argument("--status", default="WARN")
    parser.add_argument("--os-description", default="")
    parser.add_argument("--os-version", default="")
    parser.add_argument("--os-codename", default="")
    parser.add_argument(
        "--recommendations-json",
        default="[]",
        help="JSON array of recommendation strings",
    )
    args = parser.parse_args()
    try:
        recommendations = json.loads(args.recommendations_json or "[]")
    except json.JSONDecodeError:
        recommendations = []
    if not isinstance(recommendations, list):
        recommendations = []
    document = kernel_validation_facts.build_kernel_facts_document(
        kernel=args.kernel,
        target_kernel=args.target_kernel,
        kernel_ok=args.kernel_ok,
        amdgpu_ok=args.amdgpu_ok,
        amdxdna_seen=args.amdxdna_seen,
        linux_firmware_state=args.linux_firmware_state,
        status=args.status,
        os_description=args.os_description,
        os_version=args.os_version,
        os_codename=args.os_codename,
        recommendations=[str(item) for item in recommendations if str(item).strip()],
    )
    kernel_validation_facts.write_kernel_facts_json(args.output, document)


if __name__ == "__main__":
    main()
