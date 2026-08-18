# PR 2: Structured GPU and NPU capability ladders (Stage 2 visibility)

Copy this body into a GitHub issue, or run:

```bash
gh issue create --title "PR 2: Structured GPU and NPU capability ladders (Stage 2 visibility)" --body-file .github/issues/pr2-capability-ladders.md
```

## Summary

Implement migration plan PR 2: expose GPU/NPU **capability ladders** as structured, schema-backed states. S1-M4 candidates remain non-validating; Stage 2 scripts publish **visibility assessment** reports.

**Suggested PR title:** `feat(stage2): Add structured GPU and NPU capability ladders`

**Depends on:** None

**Blocks:** PR 3 (`90-validate.sh` / S2-M7 should consume ladder reports)

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

- [ ] Add `scripts/s2-m3-validate-gpu-stack.sh` (or refactor `70-validate-gpu-stack.sh` with compat wrapper)
- [ ] Publish `reports/latest/s2-m3-gpu-runtime-visibility.json` (atomic write)
- [ ] Keep compat `tier1-gpu-stack.json` until R1
- [ ] Remove hardcoded `"target_gpu_arch": "gfx1150"` from authority JSON; read from profile
- [ ] Add `stage2-gpu-validate` to `ai370-optimize.sh`
- [ ] Consume `s1-m5-system-profile.json` when present (schema version + fingerprint)

## Workstream D: NPU visibility (S2-M4, visibility only)

- [ ] Split visibility vs execution in `scripts/210-check-ryzen-ai-software.sh`
- [ ] Add `scripts/s2-m4-validate-npu-stack.sh` (no `230-benchmark-npu.sh`)
- [ ] Publish `reports/latest/s2-m4-npu-runtime-validation.json`
- [ ] Keep compat `npu-acceleration-status.json` / `npu-capabilities.json`
- [ ] Add visibility-only `stage2-npu-validate` (document vs bench-heavy path)
- [ ] Integrate `205` inventory-only mode into S2-M4 ladder

## Workstream E: Consumers (prep for PR 3)

- [ ] Refactor `scripts/90-validate.sh` to read ladder reports when present (fallback to legacy probes)
- [ ] Move gfx1150/NPU policy to profile comparison (not hardcoded)
- [ ] Update `require_tier123_pass` comments in `ai370-optimize.sh` only

## Tests

- [x] `tests/test_capability_ladder.py` — ladder transitions from fixture dicts
- [ ] `tests/test_s2_m3_gpu_visibility.py` — publisher CLI + schema + atomic write
- [ ] `tests/test_s2_m4_npu_visibility.py` — visibility does not claim inference
- [ ] Extend `tests/test_s1_m4_capabilities.py` — no new `validation_claim: true`
- [ ] Update `tests/smoke_tier1.sh` — assert `s2-m3-gpu-runtime-visibility.json` after GPU validate
- [ ] Update `tests/test_repository_instructions.py` — help mentions new commands

## Documentation

- [ ] Update `README.md` Stage 2 section (commands + output contract)
- [ ] Update `docs/RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md` inventory status
- [ ] Add ladder semantics (`docs/ROADMAP.md` or `docs/CAPABILITY_LADDERS.md`)

## Definition of done

- [ ] `stage2-gpu-validate` writes valid `s2-m3-gpu-runtime-visibility.json`
- [ ] `stage2-npu-validate` writes valid `s2-m4-npu-runtime-validation.json` (visibility only)
- [ ] Legacy `tier1-gpu-stack.json` still produced
- [ ] Portable unit tests pass without AI370 hardware
- [ ] S1-M4 candidates still have `validation_claim: false` everywhere
- [ ] PR title passes `bash scripts/validate-pr-title.sh`

## Non-goals

- Rewiring `run_stage1()` / Stage 1 read-only boundary (PR 3)
- Runtime execution proof (S3-M3/M4)
- Removing Tier aliases or reports (R1/R2)
