# PR 3: Make Stage 1 read-only; move platform validation to Stage 2

**GitHub issue:** [#169](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/169)

Copy this body into a GitHub issue, or run:

```bash
gh issue create --title "PR 3: Make Stage 1 read-only; move platform validation to Stage 2" --body-file .github/issues/pr3-read-only-stage1.md
```

## Summary

Implement migration plan PR 3: canonical Stage 1 = **probe + profile only**. BIOS, kernel, GPU/NPU visibility, tuning, and platform gates move to Stage 2 commands and reports.

**Suggested PR title:** `refactor(stage1): Make stage1 read-only; move platform validation to stage2`

**Depends on:** None remaining. GPU publisher `stage2-gpu-validate` landed in `#176` / `0.20.0`. NPU visibility-only publisher `stage2-npu-validate` landed in `#180` / `0.21.0`. Library and schemas landed in `0.18.0`/`0.19.0`.

**Blocks:** R1 Tier removal prep

**PR 3a status (orchestrator + `stage2-platform-*`):** landed in `#183` / `0.21.1` with leftover-label follow-up `#184`. `stage1` is read-only profile publication. `stage2-platform-validate` invokes existing GPU/NPU commands plus firmware/kernel wrappers and the `90-validate.sh` S2-M7 shim. `stage2-validate` remains the runtime/NPU cheap gate.

**PR 3b status (Workstream C / S2-M7):** landed in `#197`. Canonical publisher writes `s2-m7-platform-validation.json`; `90-validate.sh` is the compatibility shim for `require_tier123_pass`.

**PR 3c Workstream D status (S2-M5/S2-M6):** landing in `#199`. Canonical plan/apply JSON and in-script `--approve` split exist. Backup/rollback remain Planned; S2-M5/S2-M6 stay **In progress**. BIOS/kernel JSON splits, `require_tier123_pass` S2-M7 preference, migration-plan step 3, and `TASK_PROPOSALS.md` stay in this issue as remaining PR 3c workstreams.

Verified 2026-08-22 on `main` after `#197`: `stage1` / `tier1` call `run_stage1_profile` only. `--apply-tuning` on Stage 1 warns toward `stage2-optimize-apply --approve`. `run_stage1_inventory()` is redirected to `stage2-platform-inventory`. `full-stack` / `all` run profile → platform validate → runtime. Legacy `firmware` / `kernel-amd` / `tune` warn toward `stage2-*`. This issue is **not complete**.

Inventory review: https://github.com/gibboda/ai370-ubuntu-optimizer/pull/175
Follow-up after GPU publisher: https://github.com/gibboda/ai370-ubuntu-optimizer/pull/179
NPU publisher: https://github.com/gibboda/ai370-ubuntu-optimizer/pull/180
PR 3a orchestrator: https://github.com/gibboda/ai370-ubuntu-optimizer/pull/183
PR 3a follow-up: https://github.com/gibboda/ai370-ubuntu-optimizer/pull/184
PR 3b S2-M7 publisher: https://github.com/gibboda/ai370-ubuntu-optimizer/pull/197
PR 3c Workstream D tuning boundary: https://github.com/gibboda/ai370-ubuntu-optimizer/pull/199

---

## Workstream A: Stage 1 orchestrator

- [x] Make `stage1` / `tier1` call `run_stage1_profile` only; emit deprecation for old mixed path
- [x] Redirect or deprecate `run_stage1_inventory()` → `stage2-platform-inventory`
- [x] Remove `AI370_APPLY_TUNING` from Stage 1 env export paths
- [x] Remove script 80 / `--with-ai-smoke` from Stage 1 (redirect to Stage 3 benchmark stub)
- [x] Update `usage()` — Stage 1 = probe + profile; Stage 2 = platform validate

## Workstream B: Stage 2 platform commands

- [x] `stage2-firmware-validate` → wrap `20-check-bios.sh` (S2-M1)
- [x] `stage2-kernel-validate` → wrap `30-validate-kernel.sh` (S2-M2)
- [x] `stage2-gpu-validate` already exists (`#176` / S2-M3); invoke it from platform validate, do not recreate
- [x] `stage2-npu-validate` visibility-only already exists (`#180` / S2-M4); invoke it from platform validate, do not recreate
- [x] `stage2-optimize-plan` → `40-platform-tuning.sh` plan-only (S2-M5)
- [x] `stage2-optimize-apply --approve` → tuning apply (S2-M6)
- [x] `stage2-platform-validate` → S2-M1–M4 + S2-M7 via `90-validate.sh` shim

`stage2-validate` stays the runtime/NPU cheap gate. The original alias-to-platform-validate item is **superseded**; do not treat it as remaining work (see Non-goals).

## Workstream C: Split `90-validate.sh` (S2-M7)

Canonical S2-M7 publisher. `90-validate.sh` is the compatibility shim. Landed in `#197`.

- [x] Add `scripts/s2-m7-publish-platform-validation.py`
- [x] Add `configs/schemas/s2-m7-platform-validation.schema.json`
- [x] Publish `reports/latest/s2-m7-platform-validation.json`
- [x] Slim `90-validate.sh` to compat shim writing `tier1-validation.json`
- [x] Remove inline gfx1150/NPU re-detection from `90-validate.sh`

## Workstream D: Tuning boundary (S2-M5/S2-M6)

Command wrappers exist (Workstream B). Canonical JSON and an in-script plan/apply split landed. Backup/rollback remain Planned; keep S2-M5/S2-M6 **In progress**.

- [x] Split plan vs apply in `40-platform-tuning.sh`; apply requires `--approve`
- [x] Canonical outputs: `s2-m5-optimization-plan.json`, `s2-m6-optimization-application.json`
- [x] Keep compat `tier1-platform-tuning.json` until R1
- [x] Remove tuning from all Stage 1 / `full-stack` Stage 1 paths

## Workstream E: Firmware/kernel canonical outputs (S2-M1/S2-M2)

Wrappers consume `s1-m5-system-profile.json` (`test_s2_m1_firmware.py`). Canonical milestone JSON is still Planned.

- [ ] `s2-m1-firmware-validation.json` from `20-check-bios.sh`; keep `tier1-firmware.json` compat
- [ ] Split BIOS facts vs policy in `20-check-bios.sh`
- [ ] `s2-m2-kernel-driver-validation.json` from `30-validate-kernel.sh`

## Workstream F: Compatibility and gates

- [ ] `require_tier123_pass` prefers `s2-m7-platform-validation.json`; fallback `tier1-validation.json`
- [ ] Switch `10-detect-hardware.sh` callers to `stage1-probe` + `stage1-profile`
- [x] Fix `full-stack` / `all` sequence: profile → platform validate → runtime
- [x] Legacy commands (`kernel-amd`, `tune`, `firmware`) warn toward `stage2-*`

## Tests

- [x] `tests/test_s2_m7_platform_validation.py` — aggregate from fixture milestone JSONs
- [x] `tests/test_s2_m5_optimization_plan.py` — plan-only, no mutation
- [x] `tests/test_s2_m6_optimization_apply.py` — apply requires `--approve`
- [x] Update `tests/smoke_tier1.sh` — `stage1` does not require tuning artifacts
- [x] Add `tests/smoke_stage2_platform.sh`
- [x] Update `tests/test_repository_instructions.py` — Stage 1 read-only

## Documentation and ROADMAP

- [x] Rewrite README Stage 1 section (probe + profile only)
- [x] Add Stage 2 platform command table to README
- [x] Correct README Stage 2 header that claims S2-M1–S2-M7 scope is implemented; match ROADMAP (S2-M3/S2-M4/S2-M5/S2-M6/S2-M7 In progress; S2-M1/M2 remain Planned)
- [x] Correct README Lemonade/Digest owners (S3-M5 / S3-M4 diagnostics, not S2-M6/S2-M7)
- [ ] Update ROADMAP milestone status for S2-M1/M2/M5/M7 only when exit evidence exists
- [ ] Mark migration plan step 3 done
- [ ] Deprecate `TASK_PROPOSALS.md` Tier language

## Definition of done

- [x] `./ai370-optimize.sh stage1` runs only S1-M1–M5 (read-only)
- [x] `./ai370-optimize.sh stage2-platform-validate` runs S2-M1/M2/M3/M4 + S2-M7 (`90-validate.sh` shim)
- [x] `--apply-tuning` only on `stage2-optimize-apply --approve`
- [x] `s2-m7-platform-validation.json` validates against schema
- [x] `tier1-validation.json` compat shim preserves `require_tier123_pass`
- [x] Portable tests pass on generic CI hardware
- [x] README and ROADMAP agree Stage 1 is read-only
- [x] README does not label Planned Stage 2 milestones as implemented
- [x] PR title passes `bash scripts/validate-pr-title.sh`

## Non-goals

- Removing Tier aliases (R1)
- Full S3 runtime re-orchestration
- System-profile schema v4 bump
- Re-implementing `stage2-gpu-validate` (already on `main` via `#176`)
- Re-implementing `stage2-npu-validate` (already on `main` via `#180`)
- Aliasing `stage2-validate` to platform validate (PR 3a kept it as the runtime/NPU cheap gate)

## Optional split

- **PR 3a** — Orchestrator + `stage2-platform-*` commands. Landed in `#183` / `0.21.1` plus follow-up `#184`.
- **PR 3b** — Split `90-validate.sh` → `s2-m7-publish-platform-validation.py`. Landed in `#197`.
- **PR 3c Workstream D** — S2-M5/S2-M6 canonical JSON and in-script `--approve` split. Landing in `#199`. Backup/rollback stay Planned.
- **PR 3c remaining** — S2-M1/M2 canonical JSON (Workstream E); `require_tier123_pass` S2-M7 preference and `10-detect-hardware.sh` callers (Workstream F); mark migration-plan step 3 done; deprecate `TASK_PROPOSALS.md` Tier language.
