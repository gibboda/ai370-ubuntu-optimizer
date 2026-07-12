# Tests

Lightweight smoke tests for the ai370-ubuntu-optimizer tier commands and artifact generation. These are **not** full system tests (hardware-dependent phases are best-effort).

## Running

```bash
bash tests/smoke_tier1.sh
bash tests/smoke_tier2.sh
```

Or from repo root after making executable:

```bash
./tests/smoke_tier1.sh
./tests/smoke_tier2.sh
```

## Scope (current)

### Stage 1 (`smoke_tier1.sh`)

- Syntax (`bash -n`)
- Non-mutating or dry-run friendly execution of tier scripts
- Presence + basic structure of `reports/latest/tier1-*.json` artifacts
- Milestone 1 acceptance signals (GPU arch, NPU, BIOS metadata, Vulkan keys)

### Stage 2 (`smoke_tier2.sh` — Package D)

- Syntax for Stage 2 installers, validators, Lemonade/Digest/RAG scripts, and libs
- Manifest parse + chat/coding/embedding categories
- `155` model layout staging (no downloads) + `150` offline storage validate
- `145` tier2 + `240` tier3 aggregators
- Structure checks for gate JSON (`tier2-validation`, `tier3-validation`, offline storage)
- Orchestrator help mentions `stage1-inventory` and `--with-lemonade`

These help prevent regressions in script generation, JSON writers, and the cross-tier gate.

See `TASK_PROPOSALS.md` and the main implementation plan for additional test ideas (real execution benchmarks, persistent tuning, etc.).

## Conventions

- Follow the repository shell standards (SPDX, `set -euo pipefail`, `main()` where applicable).
- Smokes must be runnable without the physical AI370 hardware and without network (use `--offline` paths where relevant).
- Do not mutate system state.
