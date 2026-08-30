# Agent contract compatibility

`AGENTS.md` remains the authoritative repository policy. This document and
`config/agent-contract-compatibility.json` define only the deterministic
compatibility and release rules for the machine-readable contracts derived
from that policy.

## Architecture contract version

`architecture_contract_version` versions the compatible set of multi-agent
contract semantics. It is independent from each file's `schema_version` and
from the repository's SemVer release.

The compatibility contract lists the exact schema version expected for every
participating contract. CI fails when one contract changes schema version
without updating the architecture compatibility declaration.

## Change classification

Classify a contract change before release:

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

## Validation

Run:

```bash
python3 -m unittest tests.test_agent_contract_compatibility
```

The suite verifies that all declared contract files exist, their exact schema
versions form the declared compatible set, release classifications remain
fail-closed, and the repository version is not older than the release that
introduced the architecture contract version.

This contract does not grant agent permissions, alter GitHub governance, or
make AI review a merge gate.
