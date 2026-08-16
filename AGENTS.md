# AGENTS.md

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

- `docs/ROADMAP.md` is authoritative for architecture, stages, milestones,
  migration status, and implementation status.
- `README.md` is the user-facing installation and command guide.
- Documentation must distinguish current behavior from target behavior during
  migration.
- A milestone is not complete until its canonical outputs and deterministic
  tests exist.

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
