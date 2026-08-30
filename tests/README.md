# Tests

Lightweight smoke tests for the ai370-ubuntu-optimizer tier commands and artifact generation. These are **not** full system tests (hardware-dependent phases are best-effort).

## Running

```bash
bash tests/smoke_tier1.sh
bash tests/smoke_stage2_platform.sh
bash tests/smoke_tier2.sh
python3 -m unittest tests.test_system_profile tests.test_s1_m1_probe tests.test_s1_m2_normalize tests.test_s1_m3_classify tests.test_s1_m4_capabilities tests.test_s1_m5_publish tests.test_capability_ladder tests.test_s2_visibility_schemas tests.test_s2_m3_gpu_visibility tests.test_s2_m4_npu_visibility tests.test_s2_m7_platform_validation tests.test_s2_m7_gate tests.test_s2_m1_firmware tests.test_s2_m2_kernel_driver tests.test_s2_optimize_profile tests.test_s2_m5_optimization_plan tests.test_s2_m6_optimization_apply tests.test_repository_instructions tests.test_github_label_policy tests.test_agent_role_contract tests.test_agent_work_allocation tests.test_agent_credential_capabilities tests.test_agent_mcp_contract tests.test_pr_governance_contract tests.test_agent_cross_contract_consistency tests.test_agent_contract_compatibility tests.test_agent_architecture_coverage
python3 -m unittest tests.test_agent_architecture_conformance
python3 -m unittest discover -s tests -p 'test_agent_architecture_mutations*.py'
```

Or from repo root after making executable:

```bash
./tests/smoke_tier1.sh
./tests/smoke_stage2_platform.sh
./tests/smoke_tier2.sh
```

## Scope (current)
