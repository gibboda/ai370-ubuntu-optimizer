# Tests

Lightweight smoke tests for the ai370-ubuntu-optimizer tier commands and artifact generation. These are **not** full system tests (hardware-dependent phases are best-effort).

## Running

```bash
bash tests/smoke_tier1.sh
bash tests/smoke_tier2.sh
python3 -m unittest tests.test_system_profile tests.test_s1_m1_probe tests.test_s1_m2_normalize tests.test_s1_m3_classify tests.test_s1_m4_capabilities tests.test_s1_m5_publish tests.test_capability_ladder tests.test_s2_visibility_schemas tests.test_repository_instructions
```

Or from repo root after making executable:

```bash
./tests/smoke_tier1.sh
./tests/smoke_tier2.sh
```

## Scope (current)

### Stage 1 (`smoke_tier1.sh` — Package E)

- Syntax (`bash -n`) for canonical Stage 1 scripts, `40-platform-tuning`, `lib/common.sh`, orchestrator
- Help mentions `stage1-inventory`, `stage1-profile`, `--with-ai-smoke`, `--apply-tuning`, `--strict`
- `stage1-inventory` → asserts `scope == inventory` and no local-AI smoke requirement
- Asserts `tier1-npu.json` from script `10`
- Runs `40-platform-tuning` plan-only and asserts platform-tuning artifacts
- `stage1-validate` (full scope) → no AI smoke required by default
- Strict mode (`AI370_STAGE1_STRICT=true`) elevates missing gfx1150/NPU to FAIL
- Presence + structure of `reports/latest/tier1-*.json` gate artifacts
- Fixture-style classification tests for the versioned system profile are in
  `test_system_profile.py` and do not depend on host hardware
- Canonical Stage 1 owner tests: `test_s1_m1_probe.py`,
  `test_s1_m2_normalize.py`, `test_s1_m3_classify.py`,
  `test_s1_m4_capabilities.py`, `test_s1_m5_publish.py`
- Stage 2 visibility library tests: `test_capability_ladder.py`,
  `test_s2_visibility_schemas.py`

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
- Do not mutate system state (Stage 1 apply-tuning is opt-in and not used in smokes).
