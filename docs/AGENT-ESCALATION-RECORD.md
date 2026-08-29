# AI agent escalation record

`AGENTS.md` is authoritative for escalation policy. This document provides the reusable record format for the eight questions that `AGENTS.md` requires before another AI agent is invoked. It does not create a second routing policy or require escalation when escalation is unnecessary.

The machine-readable shape is `config/agent-escalation-record.schema.json`.

## When to create a record

Create a record before invoking another AI agent. That includes secondary
or specialist use for an unresolved gap and any explicitly requested named
secondary, specialist, or independent-review agent. The record remains
required for those explicitly requested reviews; it
does not turn advisory review into a merge gate.

Do not create an escalation merely to justify duplicate routine analysis. Reuse Cursor findings, deterministic evidence, logs, tests, issue/PR discussion, and prior agent output first.

## Required fields

The record preserves the eight questions in `AGENTS.md`:

1. `unresolved_gap` — what remains unresolved.
2. `deterministic_tooling_assessment` — whether deterministic tooling can answer it and what evidence was checked.
3. `cursor_limit` — why Cursor cannot reliably resolve it after a practical attempt.
4. `missing_capability` — the capability needed to close the gap.
5. `selected_resource` — the resource that best matches that capability.
   When the value is `maintainer_approved`, `approved_resource` must name
   the concrete approved specialist.
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

`maintainer_approved` is a category, not a resource. A record that selects
it must also set `approved_resource` to the concrete specialist the
maintainer approved. Named enum values already identify the resource, so
they must not use `approved_resource`.

Adding a resource to this list does not change the hierarchy. Resource
selection remains governed by `AGENTS.md` and `config/agent-roles.json`.
A record documents that selection and any required maintainer approval; it
does not confer approval or change routing policy.

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

A `maintainer_approved` record must name the concrete specialist:

```json
{
  "schema_version": 1,
  "unresolved_gap": "A narrowly scoped specialist is needed after Cursor and deterministic checks.",
  "deterministic_tooling_assessment": "Portable tests and CI do not cover the remaining provider-specific gap.",
  "cursor_limit": "Cursor completed the practical pass; the remaining work needs a maintainer-named specialist.",
  "missing_capability": "A unique specialist interface that named providers do not cover.",
  "selected_resource": "maintainer_approved",
  "approved_resource": "example-specialist",
  "scope": "Use only the maintainer-approved specialist for the named gap; do not re-implement routine Cursor work.",
  "completion_criterion": "Close the named gap or record that the specialist cannot answer it.",
  "stop_condition": "Stop when the gap is closed, deterministic evidence answers it, the specialist is unavailable, or tests contradict the specialist."
}
```

## Recording location

The schema defines the record, not a mandatory storage backend. A record may be placed in the relevant issue or PR discussion, task notes, or another repository-approved work artifact. Do not commit ephemeral escalation records solely to satisfy the format unless the record itself has lasting documentation value.

## Authority and stop behavior

A record is evidence of the bounded escalation described by its scope. It
documents the eight required questions and any required maintainer
approval; it does not authorize the selected resource and
does not grant repository, merge, release, or governance authority.
Codex and other `maintainer_approved` specialists still require explicit
maintainer approval and a unique capability gap. Stop when the defined
gap is closed, deterministic evidence answers it, the selected resource
is unavailable, or tests contradict the agent.
Do not automatically chain to another vendor.
