<!-- markdownlint-disable MD013 MD024 -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v2.0.0...v2.1.0) (2026-09-05)


### Features

* **agents:** Normalize native pre-merge agent roles ([#291](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/291)) ([9e47177](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/9e471774120950d478d333ee57cfa9f8bbae6af4))

## [2.0.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v1.0.0...v2.0.0) (2026-09-05)


### ⚠ BREAKING CHANGES

* **agents:** Make Grok exclusive independent reviewer ([#289](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/289))

### Features

* **agents:** Make Grok exclusive independent reviewer ([#289](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/289)) ([3a5781e](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/3a5781e206ae8c1c326bad4ab5c4f6457b04d0e3))

## [Unreleased]

## [1.0.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.31.0...v1.0.0) (2026-09-05)


### ⚠ BREAKING CHANGES

* **release:** Route the 1.0.0 bump through Release Please ([#288](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/288))

### Features

* **governance:** Make specialist pass risk-tiered ([#285](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/285)) ([6425922](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/6425922a3fa28b1b01f6669c49461c3cd328ec09))


### Miscellaneous Chores

* **release:** Route the 1.0.0 bump through Release Please ([#288](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/288)) ([0d189d7](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/0d189d71d59a00e2f1fa4046c6354ec46a0dc815))

## [0.31.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.30.0...v0.31.0) (2026-09-05)


### Features

* **agents:** add Bugbot Autofix cost ladder ([#283](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/283)) ([097f4c3](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/097f4c362a8fa6f24e17195ea439368d4484e90a))

## [0.30.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.29.1...v0.30.0) (2026-09-04)


### Features

* **agents:** harden external-agent local execution ([#281](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/281)) ([a22d9fd](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/a22d9fd7df1277d89ae82be41a1f51a581a430b7))

### Changed

- **deps:** bump `pip` from 26.1.2 to 26.2 in `/configs/ai-runtime` ([#279](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/279)) ([3273851](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/3273851f724faa9de1b7864a8ea85d4c4b9a8051))
- Prefer account login for local independent review: SuperGrok (`grok login`)
  and Antigravity Google login. Do not use `XAI_API_KEY` or `GEMINI_API_KEY`
  for `grok`/`agy`. Do not pin Antigravity `modelProvider` (that requires
  `GEMINI_API_KEY`); from the repository root, merge
  `.github/antigravity/settings.json` into
  `~/.gemini/antigravity-cli/settings.json` without wiping
  `trustedWorkspaces`, and drop any existing `modelProvider` so `agy` uses
  the default login backend. ([#280](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/280)) ([c90fcde](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/c90fcdee9c0077781250399f89c53da566e069d9))
- Require Grok Build (`grok`) and Antigravity CLI (`agy`) to act as
  advisory independent reviewers and specialist advisors, and to leave a
  COMMENT-only pull-request comment or COMMENT review recording that
  advice. GitHub MCP for Grok stays read-only; Cursor or the CODEOWNER may
  post the attributed record when the reviewer cannot. `agy` remains the
  independent-review fallback if Grok is unavailable and is not an
  automatic default peer for identical work. Machine-readable governance
  contracts updated: roles schema bumped to v3, advice-record objects use
  per-form `form_constraints` instead of a single `github_review_state`, and
  `allowed_roles` in `pr-governance.json` now uses canonical role keys.
  PR template advice-record checkbox updated with N/A path. ([#277](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/277)) ([7d4c3c1](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/7d4c3c1fbec4fa358cc94c3e3334693d10c92610))

## [Unreleased]

### Changed

- Allow Conventional Commit scope `contract` for machine-readable agent and
  PR contracts under `config/`.

## [0.29.1](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.29.0...v0.29.1) (2026-09-01)


### Bug Fixes

* **deps:** Align offline AI runtime pins with transformers 5.5.0 ([#276](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/276)) ([79b584d](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/79b584ded2568ffa27280d95580fb3eaa5305fc4))

## [0.29.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.28.0...v0.29.0) (2026-08-31)


### Features

* **settings:** add snyk-secure-development plugin configuration ([#274](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/274)) ([4321b30](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/4321b30c1e68877f8af555b9bd802a3279f15a38))

## [0.28.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.27.0...v0.28.0) (2026-08-30)


### Features

* **agents:** Define controlled cross-repository distribution ([#272](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/272)) ([c69e12a](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/c69e12a407315b786da4f85bde695d6c6c2b7059))

### Documentation

* **governance:** Add CODEOWNER AI second-look and advisory final pass ([#271](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/271)) ([b03095e](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/b03095ef95d81f7809e420ef99e6f037702ee418))

### Tests

* **agents:** Validate MCP configuration drift ([#264](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/264)) ([d295b79](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/d295b79c86a06a270287f623b7808e1afe370a01))
* **governance:** Verify advisory AI review boundary ([#265](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/265)) ([bf0cd5f](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/bf0cd5f6a7786f033f425a6dc1b51c32998c9b6b))
* **agents:** Enforce cross-contract consistency ([#266](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/266)) ([3d4d5fd](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/3d4d5fdc2e062c8f8f06a9a277c60492097a2ace))
* **agents:** Enforce contract release compatibility ([#267](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/267)) ([b3707a3](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/b3707a36b951a7ce825b11efaf919aab295b509e))
* **agents:** Add architecture conformance gate ([#268](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/268)) ([f44c166](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/f44c1661ad9ef7715ea9bcf27dc5f983c5d9b8c9))
* **agents:** Add architecture mutation coverage ([#269](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/269)) ([c5f24ae](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/c5f24ae4fd9326e721aa38a13b7a3bd7f8a7b210))
* **agents:** Audit architecture contract coverage ([#270](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/270)) ([8168842](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/81688420fdc17b8c11b1ccb8206b2f34d14f0043))

### Added

- CODEOWNER-assigned AI second look and process-required Copilot/Codex
  advisory final specialist pass. Encoded in `AGENTS.md`,
  `config/pr-governance.json` `review_pipeline`, CODEOWNERS comments, and
  the pull-request template. The expected `Protect main` ruleset requires
  CODEOWNER reviews (`require_code_owner_reviews`). Second-look `agy` is a
  Grok-unavailable independent-reviewer fallback, not a peer of Grok Build.
  Allocation records use `independent_review` for Grok/`agy` and
  `specialist_review` for an Antigravity second look (and for a recorded
  Copilot/Codex COMMENT pass). AI remains advisory and cannot be a merge
  gate or required status check. `@gibboda` remains the only GitHub
  CODEOWNER.
- Deterministic GitHub MCP configuration drift validation in
  `config/agent-mcp-contract.json` and
  `docs/AGENT-MCP-DRIFT-VALIDATION.md`. Tracked Cursor and Grok MCP
  configuration is parsed against the credential capability contract.
  `tests.test_agent_mcp_contract` is part of the portable suite.
- Repository-owned PR governance contract in `config/pr-governance.json`.
  It records the expected `Protect main` ruleset, pins `ShellCheck` as
  the required deterministic check, and keeps AI review advisory.
  `tests.test_pr_governance_contract` is part of the portable suite.
- Deterministic cross-contract consistency checks in
  `tests/test_agent_cross_contract_consistency.py`. Existing
  machine-readable agent contracts must agree with one another and
  continue to defer to `AGENTS.md`.
  `tests.test_agent_cross_contract_consistency` is part of the portable
  suite.
- Architecture-level agent-contract compatibility metadata in
  `config/agent-contract-compatibility.json` and
  `docs/AGENT-CONTRACT-COMPATIBILITY.md`. It records the compatible
  contract schema set and the repository release class for contract
  changes. `AGENTS.md` remains authoritative. Introduction is
  backward-compatible and first ships in `0.28.0`.
  `tests.test_agent_contract_compatibility` is part of the portable
  suite.
- Controlled cross-repository architecture distribution in
  `config/agent-distribution.json`, `config/agent-distribution-lock.json`,
  and `docs/AI-AGENT-DISTRIBUTION.md`. The portable package is the
  vendor-neutral role, escalation, work-allocation, credential, and MCP
  contracts. `AGENTS.md`, PR governance, CODEOWNERS, CI composition,
  coverage evidence, and repository-release compatibility metadata stay
  local. Synchronization is PR-only, fail-and-review on local drift, and
  never auto-merged. `tests.test_agent_distribution_contract` is part of
  the portable suite.

## [Unreleased]

## [0.27.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.26.0...v0.27.0) (2026-08-30)


### Features

* **agents:** Define credential capability contract ([#262](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/262)) ([4db075f](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/4db075f4262852e479ecd1f65630d92e8172922e))

### Tests

* **agents:** Enforce duplicate-agent allocation ([#261](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/261)) ([7f1082a](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/7f1082a7b8fd98ba95a58c87f261521ab491ecaf))

### Added

- Public agent work-allocation schema in
  `config/agent-work-allocation.schema.json` and
  `docs/AGENT-WORK-ALLOCATION.md`. Records document duplicate-agent
  allocation under `AGENTS.md` and do not confer authorization. Nested
  escalation records must be complete, and `additional_resource` must
  match `selected_resource`. `tests.test_agent_work_allocation` is part
  of the portable suite.
- Machine-readable credential capability contract in
  `config/agent-credential-capabilities.json` and
  `docs/AGENT-CREDENTIAL-CAPABILITIES.md`. It names client authorization
  boundaries and portable secret names; it does not grant permissions
  or store credential values. `tests.test_agent_credential_capabilities`
  is part of the portable suite.

## [0.26.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.25.0...v0.26.0) (2026-08-29)


### Features

* **agents:** Add structured escalation records ([#259](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/259)) ([d76d089](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/d76d08948db15fe1a16e810c09072db4d4d7adaa))

### Added

- Structured AI escalation records in
  `config/agent-escalation-record.schema.json` and
  `docs/AGENT-ESCALATION-RECORD.md`. Records are required before invoking
  another AI agent, including explicitly requested review. They document
  authorization and do not confer it. `maintainer_approved` selections
  require a concrete `approved_resource` identifier.
- Machine-readable multi-agent architecture contract in
  `config/agent-roles.json`, with portable CI coverage from
  `tests.test_agent_role_contract`.
- Vendor-neutral multi-agent architecture overview in
  `docs/AI-AGENT-ARCHITECTURE.md` (Cursor orchestrator flow, secrets
  domains, and manual authentication prerequisites).
- GitHub Copilot custom agents under `.github/agents/` (`reviewer`,
  `security-reviewer`, `test-reviewer`).
- Antigravity workspace specialist agents under `.agents/agents/`
  (`architecture-reviewer`, `security-reviewer`, `test-reviewer`).
- Shared official GitHub MCP architecture for Cursor, Grok Build,
  Antigravity, and Copilot: hosted endpoint
  `https://api.githubcopilot.com/mcp/` with toolsets `default,projects`.
  Setup and least-privilege contract: `.github/github-mcp.md`. Grok uses
  project `.grok/config.toml` with `GITHUB_GROK_PAT` and
  `X-MCP-Readonly`.
- Conventional Commit scope `agents` for agent policy and orchestration
  (`AGENTS.md`, `.cursor/`, `.github/instructions/`).
- Cursor hybrid orchestration boundary in `.cursor/rules/cursor.mdc`: GitHub
  pull requests remain the automated CI/review surface, and Cursor does not
  copy repository-owned reviewer secrets.
- Cursor GitHub MCP config (`.cursor/mcp.json`) plus Cloud Agent
  allowlist notes in `.cursor/rules/cursor.mdc`. Authenticate with
  `GITHUB_CURSOR_PAT` (replaces Projects-only `GITHUB_MCP_PAT`); do not
  commit tokens or a dashboard-overriding `.cursor/environment.json`.
- Independent xAI/Grok pull-request review owned by S5-M6
  (`.github/grok/`, `scripts/grok_pr_review.py`). GitHub Actions calls the
  xAI API directly, schema-validates JSON, applies confidence thresholds,
  and publishes an advisory review. Deterministic CI remains a separate
  `portable-tests` workflow and never calls Grok. Invalid or unauthorized
  `XAI_API_KEY` values soft-skip so advisory review cannot fail the job.
- Optional Gemini/Antigravity pull-request review owned by S5-M6
  (`.github/antigravity/`, `scripts/gemini_pr_review.py`). GitHub Actions
  calls the Gemini API directly with `GEMINI_API_KEY`. The Antigravity CLI
  provider pin lives in `.github/antigravity/settings.json` for local copy
  into `~/.gemini/antigravity-cli/`; CI does not run `agy`. Missing,
  invalid, quota-exhausted, or retired-model Gemini responses soft-skip.
  HTTP 403 `PERMISSION_DENIED` for a syntactically valid key that cannot
  call the Generative Language API also soft-skips. Unrelated 403s still
  fail the advisory job.
  Default model is `gemini-3.6-flash` (override with `GEMINI_MODEL`).
  The Actions job checks out the PR base revision for review machinery
  and fetches the PR head only to build diffs.
- GitHub issue forms and a label workflow apply type, area, and bump labels
  on open, then clear queue labels on close. S5-M6 helper
  `scripts/github_label_policy.py` owns the deterministic policy.

### Changed

- Align `AGENTS.md` to a vendor-neutral multi-agent hierarchy: Cursor is the
  primary development orchestrator, Antigravity is the secondary/specialist,
  Grok Build is independent advisory review (not a mandatory implementation
  path), GitHub Actions remains deterministic validation, and GitHub Copilot
  is the GitHub-native fallback. Add precedence, least-agent, and secrets-
  domain rules. Sync Cursor/Grok/Antigravity/Copilot overlays, label policy
  globs for `.agents/` and `.github/agents/`, and repository instruction
  contract tests.

- Align specialist overlay shape in `AGENTS.md`: GitHub Copilot and Codex
  are the named specialist products with instruction overlays. Other
  agents require explicit maintainer approval and a unique gap. Independent
  review docs (`.github/grok/`, `.github/antigravity/`) are not
  implementation overlays. The capability-routing table replaces the Claude
  row with an "other explicitly approved agent" escape hatch. Claude and
  Gemini remain named only as anti-patterns (vendor ladder, Gemini CLI
  product name, GitHub `GEMINI_API_KEY`). `CONTRIBUTING.md` lists the same
  overlay map.

- Remove the S5-M6 xAI and Gemini GitHub Actions advisory reviewers
  (`grok-pr-review.yml`, `gemini-pr-review.yml`, `scripts/grok_pr_review.py`,
  `scripts/gemini_pr_review.py`). Independent review is local Grok Build
  (`grok`) with Antigravity CLI (`agy`) as backup. GitHub Actions does not
  call xAI or Gemini and does not use `XAI_API_KEY` or `GEMINI_API_KEY`.

- Clarify agent planes, human final decision authority, and capability
  routing in `AGENTS.md` without changing Cursor as primary or Grok Build
  as the preferred secondary agent. Copilot overlay names the GitHub
  product in scope. Validation catalog matches tools this repository
  actually runs.

- Rename the S5-M6 advisory xAI Actions workflow display name from
  `Grok Build PR Review` to `Independent xAI/Grok PR Review` so GitHub's
  check list does not confuse that API-key job with Grok Build.

- Shared agent policy now has an explicit Agent hierarchy: GitHub remains
  the control plane (not an implementation agent), Cursor stays the default
  task owner, deterministic validation runs before escalation, Grok Build is
  the preferred secondary agent, and GitHub Copilot, Codex, Claude, Gemini,
  and other approved agents are specialist resources. Duplicate paid-agent
  usage is prohibited unless an explicit reason justifies parallel analysis.
- Copilot and Codex overlays point at the Agent hierarchy in `AGENTS.md`
  instead of restating specialist-escalation rules.
- Specialist escalation may use Copilot, Codex, Claude, or Gemini while
  Grok Build is available only when that specialist uniquely provides a
  required capability. Cursor remains the default task owner in the
  architecture agent-execution rules and Grok review responsibility split.
- Remove the accidental repo-root `.gemini/antigravity-cli/settings.json`
  copy from #245. Ignore `.gemini/` so local Antigravity CLI setup cannot
  be committed; the canonical pin remains `.github/antigravity/settings.json`.

- Grok review checkout uses the same `actions/checkout@v5` defaults as
  other workflows so the llama.cpp gitlink does not fail credential
  stripping. `--print-prompt` emits metadata only and does not log
  untrusted PR text or credentials.

- Align compatibility script labels, JSON `milestone`/`stage` fields, and user
  docs with ROADMAP owners (S3-M1 models, S3-M4/S3-M5/S3-M6 runtimes,
  S4-M1/S4-M3 applications). Compatibility wrappers emit deprecation warnings.
  XRT install reports set `stage` from the same owner as `milestone` (S2-M4
  inventory vs S3-M4 approved install). The CPU/GPU/NPU comparison report uses
  `stage: 3` with `milestone: S3-M6`. `tier` remains a compatibility field.
- Document the per-PR README/ROADMAP sync contract in
  `docs/RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md`. README Stage 2
  high-level status matches ROADMAP (S2-M7 Implemented; S2-M1–S2-M6 In
  progress). Instruction tests compare README Stage 2 labels with ROADMAP
  milestone rows.

## [0.25.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.24.0...v0.25.0) (2026-08-23)


### Features

* **stage2:** Prefer S2-M7 in require_tier123_pass ([#203](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/203)) ([d190a81](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/d190a815b359334701b71aba0d8f941347f9e79a))

### Added

- `require_tier123_pass` prefers `s2-m7-platform-validation.json` and falls
  back to `tier1-validation.json`.
- `tests/test_s2_m7_gate.py` proves the S2-M7 preference and compat fallback.

### Changed

- `stage2-platform-validate`, `stage2-platform-inventory`, and legacy
  `hardware` / `inventory` / `audit` / `baseline-plan` callers use
  `stage1-probe` + `stage1-profile` instead of `10-detect-hardware.sh`.
- Missing `tier1-hardware.json` / `tier1-npu.json` no longer demote S2-M7
  when the Stage 1 profile is present.
- ROADMAP marks S2-M7 **Implemented**. S2-M1/S2-M2/S2-M5 stay **In progress**.
  Migration plan step 3 is done. `TASK_PROPOSALS.md` is a Stage/Milestone
  compatibility backlog.

## [0.24.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.23.0...v0.24.0) (2026-08-22)


### Features

* **stage2:** Publish S2-M1 firmware and S2-M2 kernel reports ([#201](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/201)) ([ad57b56](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/ad57b5646b47566325391dadeef6cb613f17e968))

### Added

- S2-M1 firmware validation publisher
  (`scripts/s2-m1-publish-firmware-validation.py`) writes
  `s2-m1-firmware-validation.json` with BIOS facts vs policy split.
- S2-M2 kernel/driver validation publisher
  (`scripts/s2-m2-publish-kernel-driver-validation.py`) writes
  `s2-m2-kernel-driver-validation.json`.
- `tests/test_s2_m2_kernel_driver.py` proves canonical S2-M2 JSON plus
  compatibility `tier1-kernel-plan.json`.

### Changed

- `scripts/20-check-bios.sh` publishes canonical S2-M1 JSON and keeps
  `tier1-firmware.json` until R1. BIOS identity facts stay separate from
  classified-platform policy. Failed `fwupdmgr get-devices` probes are
  warnings, not visible devices.
- `scripts/30-validate-kernel.sh` publishes canonical S2-M2 JSON and keeps
  `tier1-kernel-plan.json` until R1. Module inventory probe failures stay
  `unknown` (`null`) instead of false "not loaded".
- ROADMAP marks S2-M1/S2-M2 **In progress** (not Implemented): canonical
  JSON exists; remaining work is remediation docs and the kernel/driver
  matrix.

## [0.23.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.22.0...v0.23.0) (2026-08-22)


### Features

* **stage2:** Publish S2-M5 plan and S2-M6 apply reports ([#199](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/199)) ([2cf508a](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/2cf508a5533c586958b4f6b4c1ba1b4a1e25d70e))

## [0.22.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.21.1...v0.22.0) (2026-08-22)


### Features

* **stage2:** Add S2-M7 platform validation publisher ([#197](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/197)) ([c0dd093](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/c0dd093a1d30ce2c9d8a7c5d154993a9780d7b84))

## [0.21.1](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.21.0...v0.21.1) (2026-08-18)


### Bug Fixes

* **stage2:** Correct leftover Stage 1 labels after read-only split ([#184](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/184)) ([4e74194](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/4e741946fa7ad33916b428ad336a8c4a929b015a))

## [0.21.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.20.0...v0.21.0) (2026-08-18)


### Features

* **stage2:** Add visibility-only NPU capability ladder ([#180](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/180)) ([1771b2b](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/1771b2be970552a603fdfade8d80030640ee373c))

## [0.20.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.19.0...v0.20.0) (2026-08-18)


### Features

* **stage2:** Add S2-M3 GPU visibility publisher ([#176](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/176)) ([9b5b7db](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/9b5b7dbfaa96db40a7db6965dc1f14e24b58808d))

## [0.19.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.18.0...v0.19.0) (2026-08-18)


### Features

* **stage2:** Add S2-M3 and S2-M4 visibility report schemas ([#173](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/173)) ([22abe09](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/22abe09104d784d5dad90c0bdb192ff202efb6ba))

## [0.18.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.17.0...v0.18.0) (2026-08-18)


### Features

* **stage2:** Add capability ladder library for GPU and NPU visibility ([#170](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/170)) ([3c397ca](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/3c397ca5ae9bc93e37fac40543dfdc2e2889f6d3))

## [0.17.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.16.0...v0.17.0) (2026-08-17)


### Features

* **stage1:** Add canonical S1-M2 through S1-M5 profile pipeline ([#166](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/166)) ([3869974](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/3869974e5dc59b96bf0fd8c13f34dee08517e5b9))

## [0.16.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.15.0...v0.16.0) (2026-08-12)


### Features

* **stage1:** Add canonical S1-M1 system probe ([#160](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/160)) ([d17b53c](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/d17b53cf7bba36cf073c86a3d762fa29a1c8951e))

## [0.15.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.14.0...v0.15.0) (2026-08-10)


### Features

* **stage1:** Stabilize system profile fingerprint ([#157](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/157)) ([b5795c5](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/b5795c5b0e76df35ec7044dc5b3b1076011cf8fd))

## [0.14.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.13.0...v0.14.0) (2026-08-04)


### Features

* **stage1:** Expand system profile contract ([#153](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/153)) ([d9d474c](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/d9d474c610e1662234e3700163c950507bb71d0d))

## [0.13.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.12.5...v0.13.0) (2026-07-25)


### Features

* **baseline:** Add versioned system profile builder ([#142](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/142)) ([7710d23](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/7710d237583a1a9f90bf3466317167d1be099406))

## [0.12.5](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.12.4...v0.12.5) (2026-07-13)


### Bug Fixes

* **tier2:** Do not treat ollama list header as models ([#139](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/139)) ([d16fc29](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/d16fc296069e7bd1b1e69c7c3c4ed36edebc62ef))

## [0.12.4](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.12.3...v0.12.4) (2026-07-13)


### Bug Fixes

* **tier1:** Avoid double inactive zram status ([#137](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/137)) ([3e8418a](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/3e8418ae065e81a889ba8a48dbb99d950b6c04db))

## [0.12.3](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.12.2...v0.12.3) (2026-07-13)


### Bug Fixes

* **tier1:** Keep Stage 1 PASS on soft acceptance misses ([#134](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/134)) ([6dd215f](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/6dd215f9e6567eb409b28348b90a8e2f91fdacdd))

## [0.12.2](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.12.1...v0.12.2) (2026-07-12)


### Bug Fixes

* use manifest format for model dirs and exact Ollama tags ([#126](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/126)) ([b2fae5a](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/b2fae5a7b0cc2f2f2e3b01ce9b536f2b63a73e91))

## [0.12.1](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.12.0...v0.12.1) (2026-07-12)


### Bug Fixes

* address Package C Codex review on inventory and tier2 ([#123](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/123)) ([b044eee](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/b044eee33e72470a08b4f4c97b9669abeda0bead))

## [0.12.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.11.0...v0.12.0) (2026-07-12)


### Features

* implement S2-M7 Digest AI model analysis tooling ([#118](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/118)) ([efa195d](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/efa195d14b19a024bffaf60f06ca971baaec6afe))

## [0.11.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.10.1...v0.11.0) (2026-07-12)


### Features

* implement S2-M6 TurnkeyML and Lemonade LLM serving ([#116](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/116)) ([e15ed48](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/e15ed48c0d6168f0da7067f887bd9184e020266e))

## [0.10.1](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.10.0...v0.10.1) (2026-07-12)


### Bug Fixes

* wire RAG offline paths and require torch for embeddings ([#114](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/114)) ([f6b86d2](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/f6b86d2bb90e34bf2dbcb0017a67bd55925e5383))

## [0.10.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.9.1...v0.10.0) (2026-07-12)


### Features

* complete S2-M3 offline RAG lifecycle ([#112](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/112)) ([f47e5b7](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/f47e5b7e9b3db85c96db5d7ac7f6750660699a8c))

## [0.9.1](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.9.0...v0.9.1) (2026-07-12)


### Bug Fixes

* require profiled EP execution before NPU pass ([#109](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/109)) ([0340a4a](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/0340a4a7c8034b20de062388b454248bc56a914e))

## [0.9.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.8.0...v0.9.0) (2026-07-12)


### Features

* add S2-M4 CPU/GPU/NPU comparison benchmark ([#107](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/107)) ([589c26d](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/589c26d05591d84473ad7c3895b5d2b5c49725d2))

## [0.8.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.7.0...v0.8.0) (2026-07-11)


### Features

* prefer Ryzen AI venv and runtime env for Stage 2 NPU validation ([#103](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/103)) ([02d92ee](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/02d92eed16b0be5fad2ff5a8d9e7397df1390d94))

## [0.7.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.6.0...v0.7.0) (2026-07-11)


### Features

* Enhance XRT/NPU package selection logic and documentation ([#101](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/101)) ([c3fe160](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/c3fe1600b3f71832fceb5df690842d1aaf7d8f16))

## [0.6.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.5.1...v0.6.0) (2026-07-11)


### Features

* add AMD artifacts directory to .gitignore ([#98](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/98)) ([133765c](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/133765ca2b315717d2c8a92f51ebfc5506107c30))

## [0.5.1](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.5.0...v0.5.1) (2026-07-11)


### Bug Fixes

* remove duplicate installation script calls for XRT and Ryzen AI ([#95](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/95)) ([026bd6a](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/026bd6acff4e4f77c004bb03a65cd2659d13960e))

## [0.5.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.4.0...v0.5.0) (2026-07-11)


### Features

* add Ryzen AI NPU runtime installer and update related scripts and documentation ([#92](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/92)) ([b1b6e3c](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/b1b6e3c9a59baabbf272fd0546d6d7949e321c40))
* Enhance installation scripts for XRT and Ryzen AI ([#93](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/93)) ([951d34d](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/951d34d9949912bca81317ef93652ead282b2f82))

## [0.4.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.3.1...v0.4.0) (2026-07-04)


### Features

* add tier3 validation script and update NPU status reports ([#88](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/88)) ([6dad73d](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/6dad73d8c0c4f68c04cc597f79c2f588c06ff8db))

## [0.3.1](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.3.0...v0.3.1) (2026-07-04)


### Bug Fixes

* **release:** use valid release PR scope ([#86](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/86)) ([fdbdf7c](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/fdbdf7c77f635a883da6f318730060daf6f29814))

## [0.3.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.2.0...v0.3.0) (2026-07-04)


### Features

* add LICENSE file with full text of GNU General Public License v3 ([#84](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/84)) ([c619d51](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/c619d5127efb1827cf97817308859f71c14f347b))

## [0.2.0](https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.1.0...v0.2.0) (2026-07-04)


### Features

* **acceleration:** Add offline AI hardware roadmap ([#14](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/14)) ([1d6b41b](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/1d6b41b22d66ef508b2242cc5250b935cee47106))
* add additional parameters for Snyk organization configuration ([#38](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/38)) ([8ebd8cc](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/8ebd8ccc7cb5a2f2de2f2f210cbb9b344f75e1df))
* add amd-acceleration-env.sh script and tracked files backup ([#74](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/74)) ([60f267b](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/60f267b675a888eded106bae21d9e6f6e5735204))
* Add comprehensive roadmap for AI370 Ubuntu Optimizer project ([#34](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/34)) ([e776c52](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/e776c52e78b9599b6b96ae747c3747a69d273a5e))
* add Grok Agent tasks for commit + push + PR automation ([#21](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/21)) ([828d96b](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/828d96bf2505f29f7b159e883ccf67be172f8b84))
* Add opt-in AMD acceleration install phase and ComfyUI GPU-launch integration ([#17](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/17)) ([fc41794](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/fc417942a62e34a3eb564138f3ed8f2769f28152))
* add stage 1 firmware validation ([#39](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/39)) ([cceb5bc](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/cceb5bc51a450fef083cd1d9efc20e8136b7c92a))
* Add status reports for AnythingLLM, RAG validation, and embedding models ([#68](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/68)) ([bd4450d](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/bd4450ddba87abe94b8e5d083bb7cc6a9745ac5a))
* Add Tier 1 hardware and firmware detection scripts and reports ([#22](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/22)) ([2f94b77](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/2f94b7743d64bfdfe410cca65ee69d2c2fc86100))
* add tier 2 status reports for llama.cpp, ollama, Open WebUI, and PyTorch ROCm installations ([#61](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/61)) ([860df1d](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/860df1dbb51d861fb977b9ed44a6f4c4e4a8ad4c))
* **baseline:** Add hardware-driven baseline phases ([#13](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/13)) ([81cf604](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/81cf604c60c1334e3224eab21a2847429a69833e))
* **comfyui:** Add production ComfyUI workflows and benchmarking harness ([#8](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/8)) ([994119f](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/994119f733779df3f0ba04a66265391d4438f3ca))
* **config:** Add TASK_PROPOSALS.md with actionable typo/bug/docs/test tasks ([#7](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/7)) ([33c0186](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/33c01869beb9eec8ceddfb020d74cb574f7031f5))
* disable automatic organization selection in Snyk settings ([#37](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/37)) ([96e4578](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/96e4578e19196e0ae25e91e55d464602b6a170c0))
* Grok Build Plan Mode (Architecture and Planning) ([#24](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/24)) ([27c83d1](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/27c83d1811349cde3b7bb6e0bcdd746714249bee))
* Introduce roadmap 'stage' commands with legacy 'tier' aliases and update docs ([#54](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/54)) ([f7d705a](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/f7d705ad2d9a2621848b18596d3beff4cd443930))
* Open WebUI - use dedicated venv and fail-safe venv bootstrap ([#60](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/60)) ([d7edf0a](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/d7edf0a6ca4c837231b3a2e0b30852919f9e97f9))
* Reorganize optimizer into nine-phase audit-first flow; add firmware, tuning, LLM, and ComfyUI benchmark phases ([#15](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/15)) ([4538cd6](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/4538cd6777fe9453e18c9bbbf1b7a7d669951048))
* short description ([#31](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/31)) ([9f77258](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/9f772585ec177a8cf7e6d70ac5065acbb566bbe0))
* **tier2:** Implement AMD AI Stack S2-M2 ([#51](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/51)) ([9dea789](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/9dea7892a580e27d5384b0fa2551a2955cbb6813))
* **tier2:** S2-M5 Add offline model manifest, storage policy, validator script and integrate into Tier 2 ([#52](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/52)) ([4d7ccf2](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/4d7ccf209f0dcb95fd862713d6c37f579840876f))
* **tier:** Add Tier 1 validation and benchmarking scripts for AI370 ([#26](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/26)) ([efd9226](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/efd92268fbb310f9fbe36e3e0ec10898829ebc47))
* **tier:** Add Tier 2 AI runtime installers/validators and integrate into ai370-optimize flow ([#30](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/30)) ([799b852](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/799b8524057eef5557e110e6e95489edbb51aeee))
* **tier:** Add Tier‑1 kernel/NPU validation and hardware detection library; integrate into workflow ([#27](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/27)) ([b4c0126](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/b4c0126b113b6c1578da4f0036951ccf6d261ff9))
* update configuration paths and add new environment files for improved structure ([#33](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/33)) ([28b5c32](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/28b5c329c1df8e04a245c8c53c472e0a14ff41b2))
* update firmware and hardware reports with accurate BIOS, system information, and timestamps; enhance validation summary ([#67](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/67)) ([3367811](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/3367811bbe84a7a07584b8fda8db9180e666dc28))
* update firmware and hardware reports with accurate timestamps and system information; add ONNX Runtime status ([#66](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/66)) ([f63a666](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/f63a666b829cc62618f8cc895d2db4206fcda1cb))
* update hardware and firmware detection scripts and reports with accurate BIOS and system information ([#64](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/64)) ([35791db](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/35791db23c13f2c2e5d3dd45113a559448eb98a0))
* update timestamps and model information across various reports for consistency ([#70](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/70)) ([c41be1f](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/c41be1fb23939d0df630223c7c4d983e625b48a2))
* update timestamps and model information for reports ([#71](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/71)) ([55ccc5f](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/55ccc5fa7c3779c5519cd2b3c7c8fd910aaf6911))
* **vscode:** add settings and extensions recommendations for improved development experience ([#32](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/32)) ([687af53](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/687af536ad356fda7b65b1a8835d6da7e7b185de))
* **workflows:** Add ShellCheck workflow for shell script linting ([#29](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/29)) ([e69e521](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/e69e521224adb5e59c6d7ad47b197e36fb3883ab))


### Bug Fixes

* Add final validation script for project checks ([#4](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/4)) ([0614acb](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/0614acbaa4453d17943dbb641a07e5220fd1534d))
* Allow offline AI benchmark to reuse a prepared venv ([#18](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/18)) ([076cf21](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/076cf21df7d8e548dbf5146917d4d07e495862ba))
* **comfyui:** Fix all command to include ComfyUI workflow stage ([#9](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/9)) ([d4a8bac](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/d4a8bacf831f40ae900c5119d07b537f3b739e89))
* disable auto-select organization in Snyk settings and update README for test conventions ([#42](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/42)) ([865059c](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/865059c1c48936d6ad426b39ae2bb179d0b933a3))
* Normalize machine gate JSON timestamp to ISO 8601 Z format ([eab3cc6](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/eab3cc65852170ebed020256c6d677a2fa2761ae))
* remove the file ([6e89b22](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/6e89b22b889a96e1a904fc1636d0833c275e2249))
* **tier2:** Tier2 PyTorch installer purge pip cache and use nightly wheels for Python 3.14+ ([#56](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/56)) ([859be68](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/859be68d82f1e8fb9c5b3d5bcc5f4a9f7205a2a7))
* tolerate missing onnxruntime in npu validation ([#16](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/16)) ([1e0745e](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/1e0745e8aea87147ab071b200cc1a12cb059e757))
* tolerate missing optional PyTorch companion wheels ([#55](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/55)) ([2ef5301](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/2ef5301c8c49671cd26ade9254f8551c8e6498eb))
* Update firmware and hardware reports with new timestamps and validation statuses ([#72](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/72)) ([26bdace](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/26bdace19840fe25c120679a2e98267022b5c15f))
* Update README with canonical roadmap and sync changes ([#47](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/47)) ([c1cec90](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/c1cec90342f82c1b89cb8cbb8f26f69e2c30bba6))
* update timestamps and correct storage summary in reports ([#63](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/63)) ([b9fcd6e](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/b9fcd6e6c6a370b95437fab19904992931174de1))
* update timestamps and model modification times in tier 1 and tier 2 reports ([#65](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/65)) ([95df504](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/95df50460794d8ab6572bdf141514cfdbbd17877))
* update timestamps in firmware and hardware reports to reflect latest data ([#58](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/58)) ([147e21b](https://github.com/gibboda/ai370-ubuntu-optimizer/commit/147e21b2b20b7346cf74a419c271cf1dd1b4515b))

## [Unreleased]

### Added

- **Optimization Roadmap & Project Tooling**:
  - Comprehensive Roadmap ([ROADMAP.md](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/docs/ROADMAP.md)) outlining project milestones, targets, and goals (#34, #35, #49).
  - ShellCheck workflow (`.github/workflows/shellcheck.yml`) for automated shell script validation (#29).
  - Conventional Commits linter and audit script to enforce project commit standards (#11, #45).
  - Snyk configuration for automated security scans (#37, #38).
  - Recommended VS Code workspace configuration (`.vscode/settings.json`, `.vscode/extensions.json`) (#32).
- **Stage 1 (Hardware & Firmware Validation)**:
  - Stage 1 firmware check script ([25-check-firmware.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/25-check-firmware.sh)) and stage 1 firmware validation status report (#39).
  - BIOS target detection for version 2.01 on AI370, writing status to validation reports (#22, #41).
  - Integrated Tier 1 validation, benchmarking, and detection scripts with the core flow (#26, #27).
  - Test harness ([smoke_tier1.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/tests/smoke_tier1.sh)) and verification suite ([README.md](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/tests/README.md)) (#26).
- **Stage 2 (Local AI Stack)**:
  - Installer/validator scripts for llama.cpp ([110-install-llama-cpp.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/110-install-llama-cpp.sh)), ollama ([120-install-ollama.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/120-install-ollama.sh)), Open WebUI ([130-install-open-webui.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/130-install-open-webui.sh)), and PyTorch ROCm ([100-install-pytorch-rocm.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/100-install-pytorch-rocm.sh)) (#30).
  - Status reports for AnythingLLM ([300-install-anythingllm.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/300-install-anythingllm.sh)), RAG validation ([320-validate-rag.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/320-validate-rag.sh)), and embedding models ([310-install-embedding-models.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/310-install-embedding-models.sh)) (#68).
  - Offline model storage policy validator and model manifest manager ([150-validate-offline-model-storage.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/150-validate-offline-model-storage.sh)) (#52).
- **Stage 3 (NPU & Acceleration)**:
  - AMD Acceleration environment script ([amd-acceleration-env.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/amd-acceleration-env.sh)) and tracked files backup registry (#74).
  - Vitis AI Execution Provider, XDNA2 NPU detection, ONNX Runtime status integration, and benchmarks (#66).

### Changed

- **Orchestration Reorganization**:
  - Reorganized optimizer orchestrator ([ai370-optimize.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/ai370-optimize.sh)) into a structured 9-phase audit-first flow (firmware, hardware, CPU, memory, storage, tuning, local AI, NPU, benchmarks) (#15).
  - Deprecated legacy scripts and archived them in `scripts/legacy/`.
  - Introduced `stage` commands in the orchestrator interface while maintaining legacy `tier` aliases for backward compatibility (#54).
- **Reports & Validation Output**:
  - Enhanced firmware and hardware detection scripts to output precise reports with accurate BIOS, system information, storage summaries, and validation statuses (#58, #63, #64, #66, #67, #70, #71, #72, #75).
  - Normalized validation timestamps across reports to use standard ISO 8601 UTC (Z) format.
  - Pinned `venv` packages and included installed package lists in validation status reports (#69).
- **Environments & Compatibility**:
  - Configured Open WebUI to use a dedicated Python virtual environment (`venv`) with a fail-safe bootstrap fallback (#60).
  - Updated PyTorch ROCm installer to purge the pip cache and use nightly wheels for Python 3.14+ compatibility (#56).

### Fixed

- **OS Detection & Platform Fallbacks**:
  - Fixed OS detection fallback logic in hardware reporting scripts (#10).
- **Dependencies & Packages**:
  - Addressed missing optional PyTorch companion wheels (#55).
- **Benchmark & Execution Issues**:
  - Integrated ComfyUI GPU-launch benchmarks, addressing offline bench reuse errors on existing virtual environments (#9, #17, #18).
  - Refined validation and reporting logic to tolerate missing optional onnxruntime packages in NPU validation (#16).

## [0.1.0] — 2026-04-30

### Added

- Initial structure: hardware audit, AMD baseline, AI stack, ROCm/iGPU,
  Ryzen AI NPU, guided acceleration, ComfyUI workflows scripts
- VERSION file and CHANGELOG following Keep a Changelog format

[Unreleased]: https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/gibboda/ai370-ubuntu-optimizer/releases/tag/v0.1.0
