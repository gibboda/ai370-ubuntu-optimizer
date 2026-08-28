# AGENTS.md

This file is the shared instruction surface for every implementation agent
that works in this repository. It is authoritative for agent hierarchy,
agent roles, escalation, cost policy, deterministic validation, architecture,
testing, naming, and change discipline.

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

## Agent hierarchy

This repository uses the following hierarchy. Later entries do not replace
earlier ones. GitHub is the control plane and source of truth.
GitHub is not an implementation agent. Cursor remains the default task owner.

1. **GitHub** is the control plane and source of truth for repositories,
   Issues and Projects, branches and pull requests, GitHub Actions, rulesets
   and branch protection, CodeQL, Dependabot, secret scanning, code scanning,
   and releases.
2. **Cursor** is the primary/default implementation agent and the default
   task owner. Keep routine work with Cursor whenever practical.
3. **Deterministic validation** must run before escalation. Attempt local
   tests, linters, schema validation, and repository validation
   scripts, and reuse existing GitHub Actions output, before another AI
   agent is invoked.
4. **Grok Build** is the preferred secondary agent when available, if
   escalation is justified.
5. **GitHub Copilot, Codex, Claude, Gemini, and other approved agents** are
   specialist/escalation resources. Specialist use must be narrowly scoped
   and capability-driven. They must not be invoked automatically for
   routine work.
6. **GitHub Actions and repository checks** are the deterministic merge
   validation surface. They remain authoritative for facts they can verify.
7. **GitHub pull-request governance** (rulesets, branch protection, required
   checks, and human decisions) is the final merge authority.

The human maintainer retains final decision authority. No AI agent is merge,
policy, release, architecture, or repository-governance authority.

These numbered items describe four concerns. GitHub appears in more than one
because it is the control plane, not a step in an agent ladder:

```text
1 GitHub source of truth     → Authority
2 Cursor                     → AI execution (Primary)
3 Deterministic validation   → Validation / evidence
4 Grok Build                 → AI execution (preferred Secondary)
5 Copilot, Codex, Claude,
  Gemini, and other approved
  agents                     → AI execution (specialist/escalation)
6 GitHub Actions and
  repository checks          → Validation / evidence
7 PR governance and human
  decisions                  → Governance
```

Do not treat this map as Cursor → Grok Build → Claude → Gemini → Codex.

## Multi-agent development policy

### Roles

- Cursor Agent is the primary/default implementation agent.
- Grok Build is the preferred secondary agent when available, if Cursor cannot
  complete the work and a second implementation path is still warranted. It is
  also the preferred independent review tool for SuperGrok subscribers.
- GitHub Copilot, Codex, Claude, Gemini, and other metered cloud agents
  are specialist/escalation resources.
  They must not be invoked automatically for routine work. If Grok Build is
  unavailable, an available specialist agent may be used for a narrowly
  scoped, capability-driven escalation need.
  If Grok Build is available, a specialist may be used only when
  it uniquely provides a required capability that Grok Build cannot.
  Approved specialists include Antigravity when a Gemini-backed local tool
  is the capability being requested.
- GitHub remains the source of truth and control plane for repositories,
  Issues and Projects, branches and pull requests, GitHub Actions, rulesets
  and branch protection, CodeQL, Dependabot, secret scanning, code scanning,
  and releases. GitHub is not an implementation agent.
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
Claude, Gemini, or other metered cloud agents.

### Escalation and secondary use

Escalate only when at least one of the following is true:

- Cursor cannot reliably complete the task after a practical attempt
- an independent second opinion has substantial value
- security or architecture changes warrant additional review
- specialized reasoning is needed that Cursor cannot provide
- the developer explicitly requests a named secondary or specialist agent

Before invoking another AI agent, record:

1. What remains unresolved?
2. Can deterministic tooling answer it?
3. Why can't Cursor reliably resolve it?
4. What capability is missing?
5. Which resource best matches the gap?
6. What exact scope should it receive?
7. What constitutes completion?
8. When does escalation stop?

Stop when the defined gap is closed, deterministic evidence answers it, the
selected agent is unavailable, or tests contradict the agent.
Do not chain the next vendor automatically.

Attempt deterministic validation before another AI agent is invoked. Preferred
order when escalation is justified:

1. Stay with Cursor and reuse existing findings, logs, issue/PR discussion, and
   deterministic check output.
2. Attempt deterministic validation (ShellCheck, portable tests, schema
   validation, repository validation scripts, GitHub Actions, CodeQL,
   dependency scanning, and secret scanning) before another AI agent is invoked.
3. Use Grok Build as the preferred secondary implementation agent when
   available.
4. If Grok Build is unavailable, use an available specialist agent such as
   GitHub Copilot, Codex, Claude, Gemini, or another explicitly approved agent
   for the narrowly scoped escalation need. If Grok Build is available, use a
   specialist only when that specialist uniquely provides a required
   capability that Grok Build cannot. Specialist use must be narrowly
   scoped and capability-driven.

Capability routing does not change the preferred order above:

| Resource | Role | Select when | Do not use when |
| --- | --- | --- | --- |
| Cursor | Primary | Default task ownership | Skipping Cursor only because another agent is available |
| Deterministic tests and CI | Evidence | Before any second AI agent | Asking an LLM to re-run ShellCheck or unittest |
| Grok Build | Preferred secondary; SuperGrok interactive review | Defined gap after Cursor, or independent review | Routine Cursor work; as a merge gate; treating a GitHub API key as Grok Build |
| Antigravity CLI (`agy`) | Backup independent review | Grok Build unavailable, including weekly limit | Default peer to Grok Build; using Gemini CLI as the product name; GitHub `GEMINI_API_KEY` |
| Codex | Specialist implementation | Codex interface or PR path is the gap | Default second opinion |
| GitHub Copilot | GitHub specialist | Coding agent, pull-request review, or Projects MCP | Parallel routine analysis |
| Claude | Specialist | Maintainer names it, or a unique capability gap | Default peer to Grok Build |

### Prevent duplicate AI usage

Do not spend paid or metered agent capacity on work that Cursor, existing
artifacts, or deterministic checks have already answered.

- Do not invoke multiple paid or cloud agents for the same routine task.
- Do not invoke multiple paid or metered agents for equivalent routine analysis.
- Before starting a new paid-agent analysis, reuse prior agent findings, logs, issue/PR
  discussion, CI results, tests, and local validation output.
- Minimize duplicate paid-agent analysis across the same change.
- Specialist use must be narrowly scoped and capability-driven. Choose the
  agent that uniquely provides the needed capability.
- Parallel multi-agent analysis requires an explicit reason, such as a
  developer request to compare named agents or a provider-specific capability
  that one agent cannot cover. Without that reason, invoke one agent at a
  time.

### Cost and capacity

Optimize AI usage for an independent-developer budget. Prefer Cursor for
default throughput. Do not assume unlimited tokens, premium requests, AI
credits, or paid-agent capacity. Metered specialist agents are scarce
resources, not parallel reviewers for every change.

### Deterministic validation over AI review

Prefer deterministic validation over AI review:

- tests
- linters (`shellcheck` is the CI-authoritative lint)
- schema validation
- PR-title and commit-subject validators
- repository validation scripts
- GitHub Actions
- CodeQL
- dependency scanning
- secret scanning

`markdownlint-cli2` is not a CI gate.
This repository does not run a formatter or type-checker as merge validation.

AI reviews are advisory. They are not required merge gates. GitHub Actions
and repository checks remain the deterministic merge validation surface.
GitHub pull-request governance is the final merge authority. Exhaustion of an
optional AI agent's quota must not block development when required
deterministic validation passes. Do not spend paid-agent capacity on review
when the required checks already answer the question.

Independent pull-request review is local Grok Build (`grok`), authenticated
by a SuperGrok account. If Grok Build is unavailable, use Antigravity CLI
(`agy`). GitHub Actions does not call xAI or Gemini and does not use
`XAI_API_KEY` or `GEMINI_API_KEY`. See `.github/grok/README.md` and
`.github/antigravity/README.md`.

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
  python3 -m unittest tests.test_system_profile tests.test_s1_m1_probe tests.test_s1_m2_normalize tests.test_s1_m3_classify tests.test_s1_m4_capabilities tests.test_s1_m5_publish tests.test_capability_ladder tests.test_s2_visibility_schemas tests.test_s2_m3_gpu_visibility tests.test_s2_m4_npu_visibility tests.test_s2_m7_platform_validation tests.test_s2_m7_gate tests.test_s2_m1_firmware tests.test_s2_m2_kernel_driver tests.test_s2_optimize_profile tests.test_s2_m5_optimization_plan tests.test_s2_m6_optimization_apply tests.test_repository_instructions tests.test_github_label_policy
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
