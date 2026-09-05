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
This repository previously shipped architecture contract version `1`.
Because `config/pr-governance.json` schema `2` changes an existing field's
semantics, this change increments `architecture_contract_version` to `2`
under the breaking-change rule below.

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

The currently recorded change is `breaking`. `config/pr-governance.json`
schema `2` changes the meaning of
`review_pipeline.final_advisory_specialist_pass.process_required`, and this
repository's compatibility rule classifies changed existing field semantics
as breaking even when merge authority and required checks stay unchanged.
The recorded `previous_repository_version` is therefore `0.31.0`, and the
first repository release that may ship architecture contract version `2` is
`1.0.0`. Release Please must produce that `1.0.0` release. Do not
hand-edit `VERSION`, `.release-please-manifest.json`, or the generated
changelog heading on a pending `0.32.0` Release Please PR to satisfy the
floor. Land a `!` Conventional Commit with a `Release-As: 1.0.0` footer
on `main` so Release Please can open the major Release PR.

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
- incrementing an existing architecture contract version requires a breaking
  change classification and a major repository release

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

Because this repository classifies changed existing field semantics as
breaking, this schema increment also increments
`architecture_contract_version` from `1` to `2` and moves the first
eligible repository release from the `0.31.0` baseline to `1.0.0`. Merge
authority, required checks, and the advisory-review invariants are
unchanged, but a schema-1 consumer must not consume schema 2 until it
understands the scoped `process_required` meaning. Update
`contracts.pr_governance.schema_version` to `2` in
`config/agent-contract-compatibility.json` and preserve the schema-1
fixture under `tests/fixtures/pr-governance/`.

This contract does not grant agent permissions, alter GitHub governance, or
make AI review a merge gate.
