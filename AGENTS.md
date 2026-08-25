# AGENTS.md

This file is the shared instruction surface for every implementation agent
that works in this repository. It is authoritative for agent roles,
escalation, cost policy, deterministic validation, architecture, testing,
naming, and change discipline.

Agent-specific files must not restate this policy. They may only add
behavior that applies to that agent or environment:

- Cursor-specific notes: [`.cursor/rules/`](.cursor/rules/)
- GitHub Copilot: [`.github/instructions/copilot.instructions.md`](.github/instructions/copilot.instructions.md)
- Codex: [`.github/instructions/codex.instructions.md`](.github/instructions/codex.instructions.md)
- Conventional Commit types, scopes, and human contributor workflow:
  [`CONTRIBUTING.md`](CONTRIBUTING.md)

Nested `AGENTS.md` files remain in force for their directories.
`.github/copilot-instructions.md` is a compatibility pointer, not a second
policy surface. Do not treat this repository as Cursor-exclusive: other
agents may work here when escalated, but routine work stays with Cursor
whenever practical.

## Contributor commit policy

All contributors and co-contributors, including humans, AI agents, and
automation, must follow this repository's Conventional Commit standard. The
person or automation creating a commit and opening its pull request is
responsible for ensuring that the shared commit subject and PR title comply on
behalf of every contributor and `Co-authored-by` identity credited in the
change.

Commit subjects and PR titles must use this format:

```text
type(optional-scope): Subject
```

[`CONTRIBUTING.md`](CONTRIBUTING.md) is authoritative for allowed types,
scopes, examples, and release versioning. The `tier`, `tier1`, and `tier2`
scopes are deprecated compatibility scopes. Do not use them for new work;
retain them until their `docs/ROADMAP.md` compatibility removal targets are
reached.

Before opening a pull request, validate the title:

```bash
bash scripts/validate-pr-title.sh "$PR_TITLE"
```

Do not open the PR unless the title validation command passes.

## Multi-agent development policy

### Roles

- Cursor Agent is the primary/default implementation agent.
- Grok Build is the preferred secondary agent when available, if Cursor cannot
  complete the work and a second implementation path is still warranted.
- GitHub Copilot, Codex, Claude, and other metered cloud agents are
  specialist/escalation resources. They must not be invoked automatically for
  routine work. If Grok Build is unavailable, an available specialist agent
  may be used for a narrowly scoped escalation need.
- GitHub remains the source of truth and control plane for repositories,
  Issues and Projects, branches and pull requests, GitHub Actions, rulesets
  and branch protection, CodeQL, Dependabot, secret scanning, code scanning,
  and releases.
- Every agent follows the same repository policies when used.

### Default work for the primary agent

Keep routine work with Cursor whenever practical. Cursor handles:

- repository analysis
- planning
- implementation
- refactoring
- debugging
- testing
- CI failure remediation
- documentation
- commit preparation
- pull-request preparation

Do not auto-escalate those tasks to Grok Build, GitHub Copilot, Codex,
Claude, or other metered cloud agents.

### Escalation and secondary use

Escalate only when at least one of the following is true:

- Cursor cannot reliably complete the task after a practical attempt
- an independent second opinion has substantial value
- security or architecture changes warrant additional review
- specialized reasoning is needed that Cursor cannot provide
- the developer explicitly requests a named secondary or specialist agent

Preferred order when escalation is justified:

1. Stay with Cursor and reuse existing findings, logs, issue/PR discussion, and
   deterministic check output.
2. Use Grok Build as the preferred secondary implementation agent when
   available.
3. If Grok Build is unavailable, use an available specialist agent such as
   GitHub Copilot, Codex, Claude, or another explicitly approved agent for the
   narrowly scoped escalation need.

Do not invoke multiple paid or cloud agents for the same routine task. Before
starting a new paid-agent analysis, reuse prior agent findings, logs, issue/PR
discussion, CI results, tests, and local validation output.
Minimize duplicate paid-agent analysis across the same change.

### Cost and capacity

Optimize AI usage for an independent-developer budget. Prefer Cursor for
default throughput. Do not assume unlimited tokens, premium requests, AI
credits, or paid-agent capacity. Metered specialist agents are scarce
resources, not parallel reviewers for every change.

### Deterministic validation over AI review

Prefer deterministic validation over AI review:

- builds
- tests
- linters
- formatters
- type checking
- GitHub Actions
- CodeQL
- dependency scanning
- secret scanning
- repository validation scripts

AI reviews are advisory. They are not required merge gates. Exhaustion of an
optional AI agent's quota must not block development when required
deterministic validation passes. Do not spend paid-agent capacity on review
when the required checks already answer the question.

Independent pull-request review through the xAI/Grok API is a repository-owned
GitHub Actions subsystem (S5-M6, `.github/grok/`). It is not Cursor, not Grok
Build, and not a Marketplace review action. Deterministic CI must remain able
to pass or fail without that workflow. See `.github/grok/README.md`.

The Testing and Change discipline sections below remain the authoritative
detail for what this repository requires those checks to cover.

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

## Before changing code

Read these sources in order, then any nested `AGENTS.md` that applies to the
files being changed:

1. This file (`AGENTS.md`).
2. `docs/ROADMAP.md`.
3. `docs/HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md` for the target platform
   architecture.
4. `docs/RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md` for the current-to-target
   inventory and file mapping.
5. The profile schema relevant to the change (the canonical system profile is
   `configs/schemas/system-profile.schema.json`).

Use this file as the complete shared policy. Agent-specific files add only
the extra steps that apply to that agent.

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
- Canonical names come from `docs/ROADMAP.md`; do not introduce new Tier-named
  commands, scripts, reports, tests, functions, JSON fields, or documentation
  sections.
- Existing Tier names are compatibility surfaces only and may be changed solely
  through the documented migration plan.
- Every new script and artifact must identify its owning Stage and Milestone.
- Do not add public `stage6` through `stage11` commands.

## Repository shape

This repository is a Bash CLI toolkit (`./ai370-optimize.sh`), not a
long-running service or GUI app. There is nothing to "serve"; you run commands
and inspect the JSON/Markdown artifacts written under `reports/latest/` (that
directory is gitignored).

## Testing

- Portable CI must not depend on the executing host's hardware.
- Deterministic tests must use versioned probe/profile fixtures.
- Physical EliteMini tests must be opt-in integration tests.
- Tests must not suppress unexpected failures with unconditional `|| true`.
- Hardware classification changes require reference-system, newer-Ryzen-AI,
  missing-tool, degraded-driver, and unsupported-host coverage.
- `shellcheck` is the CI-authoritative lint. Reproduce CI exactly with
  `shellcheck --severity=error $(git ls-files '*.sh')` (see
  `.github/workflows/shellcheck.yml`).
- `markdownlint-cli2` is not a CI gate. If used, scope it to files you
  actually touch; running it on all `*.md` reports pre-existing style errors
  under `workflows/comfyui/`.
- Portable, hardware-independent tests are listed in `tests/README.md` and
  run without AI370 hardware and without network:

  ```bash
  python3 -m unittest tests.test_system_profile tests.test_s1_m1_probe tests.test_s1_m2_normalize tests.test_s1_m3_classify tests.test_s1_m4_capabilities tests.test_s1_m5_publish tests.test_capability_ladder tests.test_s2_visibility_schemas tests.test_s2_m3_gpu_visibility tests.test_s2_m4_npu_visibility tests.test_s2_m7_platform_validation tests.test_s2_m7_gate tests.test_s2_m1_firmware tests.test_s2_m2_kernel_driver tests.test_s2_optimize_profile tests.test_s2_m5_optimization_plan tests.test_s2_m6_optimization_apply tests.test_repository_instructions tests.test_github_label_policy tests.test_grok_pr_review
  bash tests/smoke_tier1.sh
  bash tests/smoke_stage2_platform.sh
  bash tests/smoke_tier2.sh
  ```

- On generic hardware, Stage 1/Stage 2 commands report `WARN` for missing
  Radeon 890M / XDNA2 NPU / ROCm and still exit `0`. These are recorded facts,
  not failures. Do not treat a `WARN` status or missing-hardware messages as a
  broken environment. Stage 2 scripts exit non-zero only on `status=FAIL`.

## Change discipline

- Schema changes require schema-version review, migration notes, fixtures, and
  consumer tests.
- Stage boundary changes require corresponding updates to `docs/ROADMAP.md`,
  `README.md`, and command help.
- README high-level status must match `docs/ROADMAP.md` milestone rows in the
  same commit. The per-PR documentation sync contract lives in
  `docs/RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md`.
- When the profile contract changes, update schema tests and downstream
  consumer tests.
- Never add `try`/`catch` blocks around imports.
