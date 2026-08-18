# PR 3: Make Stage 1 read-only; move platform validation to Stage 2

**GitHub issue:** [#169](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/169)

Copy this body into a GitHub issue, or run:

```bash
gh issue create --title "PR 3: Make Stage 1 read-only; move platform validation to Stage 2" --body-file .github/issues/pr3-read-only-stage1.md
```

## Summary

Implement migration plan PR 3: canonical Stage 1 = **probe + profile only**. BIOS, kernel, GPU/NPU visibility, tuning, and platform gates move to Stage 2 commands and reports.

**Suggested PR title:** `refactor(stage1): Make stage1 read-only; move platform validation to stage2`

**Depends on:** PR 2 / [#168](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/168) remaining NPU visibility-only publisher. GPU publisher `stage2-gpu-validate` already landed in `#176` / `0.20.0`. Library and schemas landed in `0.18.0`/`0.19.0`.

**Blocks:** R1 Tier removal prep

Verified 2026-08-18: `run_stage1()` still invokes `20-check-bios.sh`, `30-validate-kernel.sh`, `40-platform-tuning.sh`, `70-validate-gpu-stack.sh` (now a wrapper around `s2-m3-validate-gpu-stack.sh`), and `90-validate.sh`. `--apply-tuning` remains a Stage 1 compatibility path.

Inventory review: https://github.com/gibboda/ai370-ubuntu-optimizer/pull/175

---

## Workstream A: Stage 1 orchestrator

- [ ] Make `stage1` / `tier1` call `run_stage1_profile` only; emit deprecation for old mixed path
- [ ] Redirect or deprecate `run_stage1_inventory()` → `stage2-platform-inventory`
- [ ] Remove `AI370_APPLY_TUNING` from Stage 1 env export paths
- [ ] Remove script 80 / `--with-ai-smoke` from Stage 1 (redirect to Stage 3 benchmark stub)
- [ ] Update `usage()` — Stage 1 = probe + profile; Stage 2 = platform validate

## Workstream B: Stage 2 platform commands

- [ ] `stage2-firmware-validate` → wrap `20-check-bios.sh` (S2-M1)
- [ ] `stage2-kernel-validate` → wrap `30-validate-kernel.sh` (S2-M2)
- [x] `stage2-gpu-validate` already exists (`#176` / S2-M3); invoke it from platform validate, do not recreate
- [ ] `stage2-npu-validate` visibility-only (from PR 2 / #168) (S2-M4)
- [ ] `stage2-optimize-plan` → `40-platform-tuning.sh` plan-only (S2-M5)
- [ ] `stage2-optimize-apply --approve` → tuning apply (S2-M6)
- [ ] `stage2-platform-validate` → S2-M1–M4 + S2-M7 aggregate
- [ ] `stage2-validate` alias for platform validate until S3 gates split

## Workstream C: Split `90-validate.sh` (S2-M7)

This is the canonical `90-validate.sh` split. Do not start it in #168.

- [ ] Add `scripts/s2-m7-publish-platform-validation.py`
- [ ] Add `configs/schemas/s2-m7-platform-validation.schema.json`
- [ ] Publish `reports/latest/s2-m7-platform-validation.json`
- [ ] Slim `90-validate.sh` to compat shim writing `tier1-validation.json`
- [ ] Remove inline gfx1150/NPU re-detection from `90-validate.sh`

## Workstream D: Tuning boundary (S2-M5/S2-M6)

- [ ] Split plan vs apply in `40-platform-tuning.sh`; apply requires `--approve`
- [ ] Canonical outputs: `s2-m5-optimization-plan.json`, `s2-m6-optimization-application.json`
- [ ] Keep compat `tier1-platform-tuning.json` until R1
- [ ] Remove tuning from all Stage 1 / `full-stack` Stage 1 paths

## Workstream E: Firmware/kernel canonical outputs (S2-M1/S2-M2)

- [ ] `s2-m1-firmware-validation.json` from `20-check-bios.sh`; keep `tier1-firmware.json` compat
- [ ] Split BIOS facts vs policy in `20-check-bios.sh`
- [ ] `s2-m2-kernel-driver-validation.json` from `30-validate-kernel.sh`

## Workstream F: Compatibility and gates

- [ ] `require_tier123_pass` prefers `s2-m7-platform-validation.json`; fallback `tier1-validation.json`
- [ ] Switch `10-detect-hardware.sh` callers to `stage1-probe` + `stage1-profile`
- [ ] Fix `full-stack` / `all` sequence: profile → platform validate → runtime
- [ ] Legacy commands (`kernel-amd`, `tune`, `firmware`) warn toward `stage2-*`

## Tests

- [ ] `tests/test_s2_m7_platform_validation.py` — aggregate from fixture milestone JSONs
- [ ] `tests/test_s2_m5_optimization_plan.py` — plan-only, no mutation
- [ ] `tests/test_s2_m6_optimization_apply.py` — apply requires `--approve`
- [ ] Update `tests/smoke_tier1.sh` — `stage1` does not require tuning artifacts
- [ ] Add `tests/smoke_stage2_platform.sh`
- [ ] Update `tests/test_repository_instructions.py` — Stage 1 read-only

## Documentation and ROADMAP

- [ ] Rewrite README Stage 1 section (probe + profile only)
- [ ] Add Stage 2 platform command table to README
- [ ] Correct README Stage 2 header that claims S2-M1–S2-M7 scope is implemented; match ROADMAP (S2-M3/M4 In progress, S2-M1/M2/M5–M7 Planned)
- [ ] Correct README Lemonade/Digest owners (S3-M5 / S3-M4 diagnostics, not S2-M6/S2-M7)
- [ ] Update ROADMAP milestone status for S2-M1/M2/M5/M7 only when exit evidence exists
- [ ] Mark migration plan step 3 done
- [ ] Deprecate `TASK_PROPOSALS.md` Tier language

## Definition of done

- [ ] `./ai370-optimize.sh stage1` runs only S1-M1–M5 (read-only)
- [ ] `./ai370-optimize.sh stage2-platform-validate` runs S2-M1/M2/M3/M4 + S2-M7
- [ ] `--apply-tuning` only on `stage2-optimize-apply --approve`
- [ ] `s2-m7-platform-validation.json` validates against schema
- [ ] `tier1-validation.json` compat shim preserves `require_tier123_pass`
- [ ] Portable tests pass on generic CI hardware
- [ ] README and ROADMAP agree Stage 1 is read-only
- [ ] README does not label Planned Stage 2 milestones as implemented
- [ ] PR title passes `bash scripts/validate-pr-title.sh`

## Non-goals

- Removing Tier aliases (R1)
- Full S3 runtime re-orchestration
- System-profile schema v4 bump
- Re-implementing `stage2-gpu-validate` (already on `main`)

## Optional split

- **PR 3a** — Orchestrator + `stage2-platform-*` commands
- **PR 3b** — Split `90-validate.sh` → `s2-m7-publish-platform-validation.py`
- **PR 3c** — README, smokes, ROADMAP sync
