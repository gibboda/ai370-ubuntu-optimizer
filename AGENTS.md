# AGENTS.md

## Contributor commit policy

All contributors and co-contributors, including humans, AI agents, and
automation, must follow this repository's Conventional Commit standard. The
person or automation creating a commit and opening its pull request is
responsible for ensuring that the shared commit subject and PR title comply on
behalf of every contributor and `Co-authored-by` identity credited in the
change.

## Codex PR creation policy

When Codex creates commits or pull requests in this repository, it must use this
repository's Conventional Commit standard before opening the PR.

Commit subjects and PR titles must use this format:

```text
type(optional-scope): Subject
```

Allowed types:

- `feat`
- `fix`
- `chore`
- `refactor`
- `docs`
- `test`
- `ci`
- `perf`

Allowed scopes:

- `audit`
- `baseline`
- `amd`
- `ai-stack`
- `rocm`
- `npu`
- `acceleration`
- `comfyui`
- `config`
- `architecture`
- `workflows`
- `vscode`
- `release`
- `stage`
- `stage1`
- `stage2`
- `stage3`
- `stage4`
- `stage5`
- `tier`
- `tier1`
- `tier2`

The `tier`, `tier1`, and `tier2` scopes are deprecated compatibility scopes.
Do not use them for new work; retain them until their `docs/ROADMAP.md`
compatibility removal targets are reached.

Rules:

- Scope is optional.
- The subject must start with a letter.
- Do not use leading emoji.
- Do not use a plain English title without a Conventional Commit type.
- Use `!` after the type or scope only for breaking changes.
- Validate the PR title before opening the PR.

Examples:

```text
fix: Relax S3-M7 NPU execution gate
docs: Add ComfyUI heterogeneous acceleration roadmap
chore(release): release 0.12.3
feat(stage3): Add model validation report
ci(workflows): Update PR title lint workflow
```

Before creating a PR, run:

```bash
bash scripts/validate-pr-title.sh "$PR_TITLE"
```

Do not open the PR unless the title validation command passes.

## Documentation authority

- `docs/ROADMAP.md` is authoritative for current Stage/Milestone ownership,
  canonical deliverables, implementation status, and Tier compatibility
  removal.
- `docs/HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md` is the target Ryzen AI
  Linux platform architecture. Its Stages 0 through 11 are platform layers,
  not public command names, until `docs/ROADMAP.md` is updated.
- `docs/RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md` is the current-to-target
  inventory, assumption classification, and file-by-file migration map.
- `README.md` is the user-facing installation and command guide.
- Documentation must distinguish current behavior from target behavior during
  migration.
- A milestone is not complete until its canonical outputs and deterministic
  tests exist.
- Never label planned functionality as implemented.

## Stage 1 boundary

- Stage 1 is read-only.
- Stage 1 may collect facts, normalize data, classify hardware, derive
  capability candidates, validate the profile contract, and publish reports.
- Stage 1 must not install packages, modify configuration, apply tuning, start
  services, download artifacts, or run AI workload benchmarks.
- BIOS, firmware, kernel, driver, GPU, NPU, and runtime observations collected
  in Stage 1 are facts, not reference-machine success requirements.

## System-profile contract

- Stage 2 and later must consume the canonical Stage 1 system profile.
- Later stages may not infer capabilities solely from a CLI profile name.
- Hardware identity, device visibility, driver binding, runtime availability,
  and workload execution must remain separate states.
- Every later-stage result must record the consumed profile schema version and
  hardware fingerprint.

## Hardware portability

- The Minisforum EliteMini AI370 is the reference development and physical
  integration-test system, not a universal hardware assumption.
- Generic collectors must not require HX 370, Radeon 890M, `gfx1150`, BIOS
  2.01, Strix Point, or XDNA2.
- Prefer normalized PCI/sysfs/DMI identifiers and declarative platform
  definitions over marketing-name parsing.
- Unknown or future Ryzen AI systems must produce valid profiles with explicit
  unknown or unsupported states.
- Supporting a newer Ryzen AI platform should normally require profile/device
  data and fixtures rather than collector rewrites.

## Naming

- Canonical public naming uses `stageN` and `SN-MN`.
- Do not introduce new Tier-named commands, scripts, reports, tests, functions,
  JSON fields, or documentation sections.
- Existing Tier names are compatibility surfaces only and may be changed solely
  through the documented migration plan.
- Every new script and artifact must identify its owning Stage and Milestone.

## Testing

- Portable CI must not depend on the executing host's hardware.
- Deterministic tests must use versioned probe/profile fixtures.
- Physical EliteMini tests must be opt-in integration tests.
- Tests must not suppress unexpected failures with unconditional `|| true`.
- Hardware classification changes require reference-system, newer-Ryzen-AI,
  missing-tool, degraded-driver, and unsupported-host coverage.

## Change discipline

- Schema changes require schema-version review, migration notes, fixtures, and
  consumer tests.
- Stage boundary changes require corresponding updates to `docs/ROADMAP.md`,
 `README.md`, and command help.
- Never add `try`/`catch` blocks around imports.

## Cursor Cloud specific instructions

This repository is a Bash CLI toolkit (`./ai370-optimize.sh`), not a
long-running service or GUI app. There is nothing to "serve"; you run commands
and inspect the JSON/Markdown artifacts written under `reports/latest/` (that
directory is gitignored).

- Toolchain: `bash`, `python3`, `jq`, `node`/`npm`, and `shellcheck` are all
 provided by the base environment. `shellcheck` is a system dependency (apt),
 not a repo package, so it is baked into the environment rather than the
 startup update script. The update script only runs `npm ci` for the single
 `markdownlint-cli2` dev dependency.
- Lint: `shellcheck` is the CI-authoritative lint. Reproduce CI exactly with
 `shellcheck --severity=error $(git ls-files '*.sh')` (see
 `.github/workflows/shellcheck.yml`). `markdownlint-cli2` is available via npm
 but is NOT wired into CI; running it on all `*.md` reports pre-existing style
 errors under `workflows/comfyui/`, so scope it to files you actually touch.
- Tests: portable, hardware-independent tests are
 `python3 -m unittest tests.test_system_profile tests.test_s1_m1_probe tests.test_s1_m2_normalize tests.test_s1_m3_classify tests.test_s1_m4_capabilities tests.test_s1_m5_publish tests.test_capability_ladder tests.test_s2_visibility_schemas tests.test_s2_m3_gpu_visibility tests.test_s2_m4_npu_visibility tests.test_repository_instructions`
 plus the CLI smokes `bash tests/smoke_tier1.sh` and `bash tests/smoke_tier2.sh`
 (see `tests/README.md`). All run without AI370 hardware and without network.
- Non-obvious gotcha: on generic hardware (any cloud VM), Stage 1/Stage 2
 commands report `WARN` for missing Radeon 890M / XDNA2 NPU / ROCm and still
 exit `0`. Per the Stage 1 boundary rules above, these are recorded facts, not
 failures — do NOT treat a `WARN` status or missing-hardware messages as a
 broken environment. Stage 2 scripts exit non-zero only on `status=FAIL`.
- Before opening a PR, validate the title:
 `bash scripts/validate-pr-title.sh "$PR_TITLE"`.
