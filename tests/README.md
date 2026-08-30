# Tests

Lightweight smoke tests for the ai370-ubuntu-optimizer tier commands and artifact generation. These are **not** full system tests (hardware-dependent phases are best-effort).

## Running

```bash
bash tests/smoke_tier1.sh
bash tests/smoke_stage2_platform.sh
bash tests/smoke_tier2.sh
python3 -m unittest tests.test_system_profile tests.test_s1_m1_probe tests.test_s1_m2_normalize tests.test_s1_m3_classify tests.test_s1_m4_capabilities tests.test_s1_m5_publish tests.test_capability_ladder tests.test_s2_visibility_schemas tests.test_s2_m3_gpu_visibility tests.test_s2_m4_npu_visibility tests.test_s2_m7_platform_validation tests.test_s2_m7_gate tests.test_s2_m1_firmware tests.test_s2_m2_kernel_driver tests.test_s2_optimize_profile tests.test_s2_m5_optimization_plan tests.test_s2_m6_optimization_apply tests.test_repository_instructions tests.test_github_label_policy tests.test_agent_role_contract tests.test_agent_work_allocation tests.test_agent_credential_capabilities tests.test_agent_mcp_contract tests.test_pr_governance_contract tests.test_agent_cross_contract_consistency tests.test_agent_contract_compatibility tests.test_agent_distribution_contract
python3 -m unittest tests.test_agent_architecture_conformance
python3 -m unittest tests.test_agent_architecture_coverage
python3 -m unittest discover -s tests -p 'test_agent_architecture_mutations*.py'
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
- Strict mode (`AI370_STAGE1_STRICT=true`) elevates missing gfx1150/NPU to FAIL
- Presence + structure of `reports/latest/tier1-*.json` gate artifacts
- Apply path is `stage2-optimize-apply --approve --dry-run`
- Agent architecture contract tests include role, allocation, credential, MCP,
  PR governance, cross-contract, compatibility, distribution, conformance,
  coverage, and mutation validation.
- `test_agent_distribution_contract.py` validates the portable-vs-local package
  boundary, immutable source lock, PR-only synchronization, fail-and-review
  drift handling, and the prohibition on overwriting repository-local policy.
- Independent review is local Grok Build (advisory) / Antigravity CLI backup.
  GitHub Actions does not call xAI or Gemini.

### Stage 2 platform (`smoke_stage2_platform.sh`)

- Help mentions `stage2-platform-validate`, firmware/kernel/optimize commands
- `stage2-validate` remains documented as the runtime/NPU cheap gate
- `stage2-optimize-apply` without `--approve` exits non-zero
- Seeds `tests/fixtures/system-profile/v3/valid-reference.json` and runs
  `stage2-firmware-validate` / `stage2-kernel-validate` / `stage2-optimize-plan`
  without host Stage 1 probing
- `stage2-optimize-apply --dry-run --approve` writes
  `s2-m6-optimization-application.json` without applying commands

### Stage 2 runtime (`smoke_tier2.sh` — Package D)

- Syntax for Stage 2 installers, validators, Lemonade/Digest/RAG scripts, and libs
- Manifest parse + chat/coding/embedding categories
- Structure checks for gate JSON (`tier2-validation`, `tier3-validation`, offline storage)

See `TASK_PROPOSALS.md` and the main implementation plan for additional test ideas.

## Conventions

- Follow the repository shell standards (SPDX, `set -euo pipefail`, `main()` where applicable).
- Smokes must be runnable without the physical AI370 hardware and without network (use `--offline` paths where relevant).
- Do not mutate system state (`stage2-optimize-apply` requires `--approve` and is not used without `--dry-run` in smokes).
