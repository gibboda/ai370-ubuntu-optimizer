# PR 2: Structured GPU and NPU capability ladders (Stage 2 visibility)

**GitHub issue:** [#168](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/168)

Copy this body into a GitHub issue, or run:

```bash
gh issue create --title "PR 2: Structured GPU and NPU capability ladders (Stage 2 visibility)" --body-file .github/issues/pr2-capability-ladders.md
```

## Summary

Implement migration plan PR 2: expose GPU/NPU **capability ladders** as structured, schema-backed states. S1-M4 candidates remain non-validating; Stage 2 scripts publish **visibility assessment** reports.

**Suggested PR title:** `feat(stage2): Add visibility-only NPU capability ladder`

**Depends on:** None

**Blocks:** PR 3 / [#169](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/169) (S2-M7 should consume ladder reports)

**Landed on `main`:** workstreams A and B (`0.18.0` / `0.19.0`), plus Workstream C GPU publisher (`#176` / `0.20.0`). Remaining work is the visibility-only NPU publisher.

Inventory review: https://github.com/gibboda/ai370-ubuntu-optimizer/pull/175

---

## Workstream A: Shared capability model

- [x] Add `scripts/lib/capability_ladder.py` with GPU/NPU ladder step IDs, assessment enums, and compute helpers
- [x] Document input → ladder mapping in module docstrings
- [x] Add ROADMAP status-semantics paragraph for ladder vs candidate vs validation
- [x] Wire into `system_profile.py` only if needed (kept separate)

## Workstream B: Schemas and canonical outputs

- [x] Add `configs/schemas/s2-m3-gpu-runtime-visibility.schema.json`
- [x] Add `configs/schemas/s2-m4-npu-runtime-validation.schema.json`
- [x] Update `docs/ROADMAP.md` — S2-M3/M4 → **In progress**

## Workstream C: GPU visibility (S2-M3)

Landed in `#176` / `0.20.0`. Do not re-implement.

- [x] Add `scripts/s2-m3-validate-gpu-stack.sh` (or refactor `70-validate-gpu-stack.sh` with compat wrapper)
- [x] Publish `reports/latest/s2-m3-gpu-runtime-visibility.json` (atomic write)
- [x] Keep compat `tier1-gpu-stack.json` until R1
- [x] Remove hardcoded `"target_gpu_arch": "gfx1150"` from authority JSON; read from profile
- [x] Add `stage2-gpu-validate` to `ai370-optimize.sh`
- [x] Consume `s1-m5-system-profile.json` when present (schema version + fingerprint)

## Workstream D: NPU visibility (S2-M4, visibility only)

`stage2-npu-validate` already exists as a mixed visibility-plus-benchmark path (`205`/`210`/`220`/`230`/`240`). Do not treat the name as missing. Add a visibility-only owner path; keep the bench-heavy path as compatibility until S3-M6.

- [ ] Split visibility vs execution in `scripts/210-check-ryzen-ai-software.sh`
- [ ] Add `scripts/s2-m4-validate-npu-stack.sh` (no `230-benchmark-npu.sh`)
- [ ] Publish `reports/latest/s2-m4-npu-runtime-validation.json`
- [ ] Keep compat `npu-acceleration-status.json` / `npu-capabilities.json`
- [ ] Add visibility-only `stage2-npu-validate` (or a documented flag) distinct from the bench-heavy path
- [ ] Integrate `205` inventory-only mode into S2-M4 ladder

## Workstream E: Consumers (deferred to #169)

Do not split `scripts/90-validate.sh` here. Issue #169 owns the S2-M7 aggregate. This issue only must not expand `require_tier123_pass`.

- [x] Leave `90-validate.sh` as the mixed compatibility aggregate until #169
- [x] Defer `require_tier123_pass` comment/report updates to #169 (`s2-m3-gpu-runtime-visibility.json` exists; the gate still reads `tier1-validation.json`)

## Tests

- [x] `tests/test_capability_ladder.py` — ladder transitions from fixture dicts
- [x] `tests/test_s2_visibility_schemas.py` — unpublished report builders validate
- [x] `tests/test_s2_m3_gpu_visibility.py` — publisher CLI + schema + atomic write (`#176`)
- [ ] `tests/test_s2_m4_npu_visibility.py` — visibility does not claim inference
- [ ] Extend `tests/test_s1_m4_capabilities.py` — no new `validation_claim: true`
- [x] Update `tests/smoke_tier1.sh` — assert `s2-m3-gpu-runtime-visibility.json` after GPU validate (`#176`)
- [ ] Update `tests/test_repository_instructions.py` — help mentions visibility-only NPU path

## Documentation

- [x] Add ladder semantics (`docs/ROADMAP.md`)
- [x] Update `docs/RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md` inventory status (review pass 2026-08-18)
- [x] Document `stage2-gpu-validate` command and S2-M3 output contract in `README.md` (`#176`)
- [ ] Update `README.md` Stage 2 NPU section (visibility-only path + output contract)

## Definition of done

- [x] `stage2-gpu-validate` writes valid `s2-m3-gpu-runtime-visibility.json` (`#176`)
- [ ] Visibility-only NPU validate writes valid `s2-m4-npu-runtime-validation.json`
- [x] Legacy `tier1-gpu-stack.json` still produced (`#176`)
- [ ] Portable unit tests pass without AI370 hardware
- [ ] S1-M4 candidates still have `validation_claim: false` everywhere
- [ ] PR title passes `bash scripts/validate-pr-title.sh`

## Non-goals

- Rewiring `run_stage1()` / Stage 1 read-only boundary (PR 3 / #169)
- Splitting `90-validate.sh` into S2-M7 (PR 3 / #169)
- Marking ROADMAP S2-M3 Implemented (missing driver/Vulkan/ROCm layer fixtures remain)
- Runtime execution proof (S3-M3/M4)
- Removing Tier aliases or reports (R1/R2)
