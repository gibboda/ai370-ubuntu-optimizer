# Tests

Lightweight smoke tests for the ai370-ubuntu-optimizer tier commands and artifact generation. These are **not** full system tests (hardware-dependent phases are best-effort).

## Running

```bash
bash tests/smoke_tier1.sh
# (future)
bash tests/smoke_tier2.sh
bash tests/run-all-smokes.sh
```

Or from repo root after making executable:
```bash
./tests/smoke_tier1.sh
```

## Scope (current)
- Syntax (`bash -n`)
- Non-mutating or dry-run friendly execution of tier scripts
- Presence + basic structure of `reports/latest/tierN-*.json` (and MD) artifacts
- Milestone 1 acceptance signals, including Radeon 890M/gfx1150 detection, AMDGPU, Vulkan, ROCm clean-missing reporting, AMDXDNA clean-missing reporting, BIOS 2.01 validation metadata, and `90-validate.sh` artifact generation

These help prevent regressions in script generation, JSON writers, and the cross-tier gate.

See `TASK_PROPOSALS.md` and the main implementation plan for additional test ideas (real execution benchmarks, persistent tuning, etc.).

## Conventions
- Follow the repository shell standards (SPDX, `set -euo pipefail`, `main()` where applicable).
- Smokes must be runnable without the physical AI370 hardware and without network (use `--offline` paths where relevant).
- Do not mutate system state.
