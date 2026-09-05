# Agent contract compatibility

`AGENTS.md` remains the authoritative repository policy. This document and
`config/agent-contract-compatibility.json` define only the deterministic
compatibility and release rules for the machine-readable contracts derived
from that policy. The JSON file is validation metadata. It does not grant
permissions, alter GitHub governance, or replace `AGENTS.md`. It is
repository-local: it records this repository's release history and the local
`config/pr-governance.json` schema, and it is not part of the portable
cross-repository architecture package.

## Architecture contract version

`architecture_contract_version` versions the compatible set of multi-agent
contract semantics. It is independent from each file's `schema_version` and
from the repository's SemVer release.

The compatibility contract lists the exact schema version expected for every
participating contract. CI fails when one contract changes schema version
without updating the architecture compatibility declaration.

`previous_architecture_contract_version` is the last shipped architecture
contract version, or `0` when no architecture contract has shipped yet.
This repository's first architecture contract is version `1`. Introducing
version `1` from `0` is the initial publication of this metadata, not an
increment of an already-shipped architecture contract.

## Change classification

Classify a contract change before release and record it as
`current_change_class`:

| Change | Minimum repository release | Architecture contract version |
| --- | --- | --- |
| Documentation only | patch | unchanged |
| Backward-compatible contract behavior | minor | unchanged |
| Breaking architecture-contract behavior | major | increment |

A breaking change includes removing or renaming required fields, changing
existing field semantics or authority, weakening security/governance
invariants, changing canonical role ownership or merge authority, making
advisory AI review a required merge gate, or removing supported contract
resources/clients.

A backward-compatible change may add optional fields with safe defaults, add a
specialist without changing existing role semantics, tighten validation while
preserving previously valid records, or add cross-contract invariants that
remain consistent with `AGENTS.md`.

When a change does not clearly fit the backward-compatible list, treat it as
breaking until deterministic evidence proves compatibility.

The first publication of this file is `backward_compatible`: it adds
architecture-level metadata and tests without changing existing contract
semantics. Conventional Commit types such as `test` do not bump the
repository version by themselves; `release-please` owns `VERSION`. The
recorded `introduced_repository_version` is therefore the next minor release
that may first ship this file (`0.28.0`), not a finalized release that
already shipped without it (`0.27.0`). A human may retag the pull request
`bump:minor` when the automated `test` label is `bump:patch`.

## Repository version fields

| Field | Meaning |
| --- | --- |
| `previous_repository_version` | Last finalized repository release used as the baseline |
| `introduced_repository_version` | First repository release that may contain this architecture contract version |
| `current_change_class` | Declared documentation-only, backward-compatible, or breaking class |

`VERSION` may still equal a finalized tag while this file is on an unreleased
branch. In that case `introduced_repository_version` must be strictly newer
than that finalized tag, and the delta must satisfy the declared change
class. After `release-please` bumps `VERSION`, the in-tree version must be
greater than or equal to `introduced_repository_version`.

Incrementing an existing `architecture_contract_version` (`previous` ≥ 1)
requires `current_change_class=breaking` and a major repository release
versus `previous_repository_version`.

These checks are fixture/metadata-driven. They do not parse git history,
GitHub labels, or `release-please` output.

## Validation

Run:

```bash
python3 -m unittest tests.test_agent_contract_compatibility
```

The suite verifies that:

- every declared contract file exists
- listed schema versions are exact
- change-class tables remain monotonic and fail-closed
- `current_change_class` is a declared class
- `introduced_repository_version` is valid SemVer and is not older than
  `previous_repository_version`
- if `VERSION` still equals the last finalized release, `introduced` is
  strictly newer and matches the declared change class
- if `VERSION` has already been bumped, it is not older than `introduced`
- introducing architecture contract version `1` from `0` follows the
  declared change class (this publication: backward-compatible / minor)
- incrementing an existing architecture contract version requires a major
  repository release

The suite does not claim that GitHub labels, Conventional Commit type, or
`release-please` have already applied that repository bump.

## `pr-governance.json` schema 1 to schema 2

`config/pr-governance.json` schema 2 changes the interpretation of
`review_pipeline.final_advisory_specialist_pass.process_required`.

Schema 1 treated that boolean as an unconditional process requirement
for every pull request. Schema 2 sets `process_required` to `false` so
it cannot be read as always-on, and adds `process_required_for` plus
`required_risk_tiers`. The pass is process-required only when the
recorded risk tier is in those lists (currently `high`).

Schema 2 also adds `risk_tier_precedence=highest_matching_wins` and
`risk_tier_rank`. When a change matches both a high-risk criterion
(for example `security`) and a low-risk criterion (for example
`chore_or_dependency_bump`), the highest matching tier wins.

This is a single-contract schema increment, not an
`architecture_contract_version` increment. Merge authority, required
checks, and the advisory-review invariants are unchanged. Update
`contracts.pr_governance.schema_version` to `2` in
`config/agent-contract-compatibility.json`. A schema-1 consumer must
not consume schema 2 until it understands the scoped
`process_required` meaning. Preserve the schema-1 fixture under
`tests/fixtures/pr-governance/`.

This contract does not grant agent permissions, alter GitHub governance, or
make AI review a merge gate.
