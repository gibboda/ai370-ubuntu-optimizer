# AI agent escalation record

`AGENTS.md` is authoritative for escalation policy. This document provides the reusable record format for the eight questions that `AGENTS.md` requires before another AI agent is invoked. It does not create a second routing policy or require escalation when escalation is unnecessary.

The machine-readable shape is `config/agent-escalation-record.schema.json`.

## When to create a record

Create a record before invoking a secondary or specialist AI because an unresolved gap requires escalation. Independent review that is already explicitly requested by the maintainer may use the same record when useful, but the record does not turn advisory review into a merge gate.

Do not create an escalation merely to justify duplicate routine analysis. Reuse Cursor findings, deterministic evidence, logs, tests, issue/PR discussion, and prior agent output first.

## Required fields

The record preserves the eight questions in `AGENTS.md`:

1. `unresolved_gap` — what remains unresolved.
2. `deterministic_tooling_assessment` — whether deterministic tooling can answer it and what evidence was checked.
3. `cursor_limit` — why Cursor cannot reliably resolve it after a practical attempt.
4. `missing_capability` — the capability needed to close the gap.
5. `selected_resource` — the resource that best matches that capability.
6. `scope` — the exact bounded work delegated to that resource.
7. `completion_criterion` — the evidence or result that closes the gap.
8. `stop_condition` — when escalation must stop.

`schema_version` is also required for deterministic consumers. Optional `context` may link the record to an issue, pull request, commit, or concise notes.

## Resource identifiers

The schema uses stable role-oriented identifiers for currently approved resources:

- `antigravity`
- `github_copilot`
- `codex`
- `grok_build`
- `antigravity_cli`
- `maintainer_approved`

Adding a resource to this list does not change the hierarchy. Resource selection remains governed by `AGENTS.md` and `config/agent-roles.json`.

## Example

```json
{
  "schema_version": 1,
  "unresolved_gap": "A concurrency failure remains unexplained after the primary implementation and local tests.",
  "deterministic_tooling_assessment": "Portable tests and CI reproduce the failure but do not identify the race source.",
  "cursor_limit": "Cursor completed the practical debugging pass but cannot reliably identify the race from the available traces.",
  "missing_capability": "Independent specialist concurrency analysis.",
  "selected_resource": "antigravity",
  "scope": "Review only the failing concurrency path and existing traces; do not re-implement unrelated code.",
  "completion_criterion": "Identify a testable root-cause hypothesis or conclude that the available evidence is insufficient.",
  "stop_condition": "Stop when the gap is closed, deterministic evidence answers it, the specialist is unavailable, or tests contradict the specialist.",
  "context": {
    "notes": "Reuse the existing Cursor analysis and CI logs."
  }
}
```

## Recording location

The schema defines the record, not a mandatory storage backend. A record may be placed in the relevant issue or PR discussion, task notes, or another repository-approved work artifact. Do not commit ephemeral escalation records solely to satisfy the format unless the record itself has lasting documentation value.

## Authority and stop behavior

A valid record authorizes only the bounded escalation described by its scope; it does not grant repository, merge, release, or governance authority. Stop when the defined gap is closed, deterministic evidence answers it, the selected resource is unavailable, or tests contradict the agent. Do not automatically chain to another vendor.
