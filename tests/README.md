# Tests

Lightweight smoke tests for the ai370-ubuntu-optimizer tier commands and artifact generation. These are **not** full system tests (hardware-dependent phases are best-effort).

## Running

```bash
bash tests/smoke_tier1.sh
bash tests/smoke_stage2_platform.sh
bash tests/smoke_tier2.sh
python3 -m unittest tests.test_system_profile tests.test_s1_m1_probe tests.test_s1_m2_normalize tests.test_s1_m3_classify tests.test_s1_m4_capabilities tests.test_s1_m5_publish tests.test_capability_ladder tests.test_s2_visibility_schemas tests.test_s2_m3_gpu_visibility tests.test_s2_m4_npu_visibility tests.test_s2_m7_platform_validation tests.test_s2_m7_gate tests.test_s2_m1_firmware tests.test_s2_m2_kernel_driver tests.test_s2_optimize_profile tests.test_s2_m5_optimization_plan tests.test_s2_m6_optimization_apply tests.test_repository_instructions tests.test_github_label_policy tests.test_agent_role_contract tests.test_agent_work_allocation
```

Or from repo root after making executable:

```bash
./tests/smoke_tier1.sh
./tests/smoke_stage2_platform.sh
./tests/smoke_tier2.sh
```

## Scope (current)

### Stage 1 (`smoke_tier1.sh`)

- Syntax (`bash -n`) for canonical Stage 1 scripts, `40-platform-tuning`, `lib/common.sh`, orchestrator
- Help mentions `stage1-profile`, `stage2-platform-validate`, visibility-only NPU, redirected `--with-ai-smoke` / `--apply-tuning`, `--strict`
- `stage1` publishes `s1-m5-system-profile.json` and does not write tuning or `90-validate` artifacts
- `stage2-platform-inventory` → asserts `scope == inventory` and no local-AI smoke requirement
- Asserts `s2-m3-gpu-runtime-visibility.json` from the S2-M3 GPU publisher
- Asserts `s2-m1-firmware-validation.json` and `s2-m2-kernel-driver-validation.json`
  from `stage2-platform-inventory`
- Runs `40-platform-tuning` plan-only and asserts platform-tuning artifacts
- Direct `90-validate.sh` full-scope contract (no AI smoke required by default)
- Asserts `s2-m7-platform-validation.json` after the S2-M7 publisher shim
- Strict mode (`AI370_STAGE1_STRICT=true`) elevates missing gfx1150/NPU to FAIL
- Presence + structure of `reports/latest/tier1-*.json` gate artifacts
- Apply path is `stage2-optimize-apply --approve --dry-run`
- Fixture-style classification tests for the versioned system profile are in
  `test_system_profile.py` and do not depend on host hardware
- Canonical Stage 1 owner tests: `test_s1_m1_probe.py`,
  `test_s1_m2_normalize.py`, `test_s1_m3_classify.py`,
  `test_s1_m4_capabilities.py`, `test_s1_m5_publish.py`
- Stage 2 visibility tests: `test_capability_ladder.py`,
  `test_s2_visibility_schemas.py`, `test_s2_m3_gpu_visibility.py`,
  `test_s2_m4_npu_visibility.py`
- Stage 2 platform aggregate tests: `test_s2_m7_platform_validation.py`
  (fixture milestone JSONs; no live PCI/NPU re-detection) and
  `test_s2_m7_gate.py` (`require_tier123_pass` prefers S2-M7)
- Stage 2 firmware policy tests: `test_s2_m1_firmware.py` (classified
  `platform_id`, consumed fingerprint, facts vs policy, canonical publisher)
- Stage 2 kernel/driver tests: `test_s2_m2_kernel_driver.py` (canonical
  S2-M2 JSON plus compatibility `tier1-kernel-plan.json`)
- Stage 2 optimize profile tests: `test_s2_optimize_profile.py` (plan-only
  wrapper records classified `platform_id` and consumed fingerprint)
- Stage 2 tuning boundary tests: `test_s2_m5_optimization_plan.py`
  (plan-only, no mutation) and `test_s2_m6_optimization_apply.py`
  (apply requires `--approve`)
- GitHub label policy tests: `test_github_label_policy.py` (issue/PR open
  and close label mutations from `.github/label-policy.json`)
- Agent-role contract tests: `test_agent_role_contract.py` (machine-readable
  multi-agent architecture in `config/agent-roles.json`)
- Agent work-allocation tests: `test_agent_work_allocation.py` (duplicate-agent
  allocation contract in `config/agent-work-allocation.schema.json`)
- Independent review is local Grok Build (advisory) / Antigravity CLI backup.
  GitHub Actions does not call xAI or Gemini; there are no
  `test_grok_pr_review.py` or `test_gemini_pr_review.py` suites.

### Stage 2 platform (`smoke_stage2_platform.sh`)

- Help mentions `stage2-platform-validate`, firmware/kernel/optimize commands
- `stage2-validate` remains documented as the runtime/NPU cheap gate
- `stage2-optimize-apply` without `--approve` exits non-zero
- Seeds `tests/fixtures/system-profile/v3/valid-reference.json` and runs
  `stage2-firmware-validate` / `stage2-kernel-validate` / `stage2-optimize-plan`
  without host Stage 1 probing
- Asserts BIOS policy from classified `platform_id` (not CLI `--profile`)
  and the consumed Stage 1 fingerprint, plus `s2-m1-firmware-validation.json`
- Asserts `s2-m2-kernel-driver-validation.json` from `stage2-kernel-validate`
- Asserts optimize plan records classified identity + fingerprint, writes
  `s2-m5-optimization-plan.json`, and stays plan-only
- `stage2-optimize-apply --dry-run --approve` writes
  `s2-m6-optimization-application.json` without applying commands
- Does not invoke live `stage1` or `stage2-platform-validate` (those probe
  `/sys` / PCI / modules; keep them on `smoke_tier1.sh` / integration)

### Stage 2 runtime (`smoke_tier2.sh` — Package D)

- Syntax for Stage 2 installers, validators, Lemonade/Digest/RAG scripts, and libs
- Manifest parse + chat/coding/embedding categories
- `155` model layout staging (no downloads) + `150` offline storage validate
- `145` tier2 + `240` tier3 aggregators
- `stage1-probe` + `stage1-profile` then `s2-m4-validate-npu-stack.sh` visibility-only publisher (no 230)
- Structure checks for gate JSON (`tier2-validation`, `tier3-validation`, offline storage)
- Orchestrator help mentions `stage1-inventory` and `--with-lemonade`

These help prevent regressions in script generation, JSON writers, and the cross-tier gate.

See `TASK_PROPOSALS.md` and the main implementation plan for additional test ideas (real execution benchmarks, persistent tuning, etc.).

## Conventions

- Follow the repository shell standards (SPDX, `set -euo pipefail`, `main()` where applicable).
- Smokes must be runnable without the physical AI370 hardware and without network (use `--offline` paths where relevant).
- Do not mutate system state (`stage2-optimize-apply` requires `--approve` and is not used without `--dry-run` in smokes).
