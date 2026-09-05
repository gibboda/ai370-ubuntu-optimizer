# Agent role contract schema compatibility

`config/agent-roles.json` is the machine-readable contract derived from the human-authoritative `AGENTS.md`. This document defines compatibility and migration rules for consumers of that contract. It does not create a second policy authority.

## Version semantics

`schema_version` is a positive integer identifying the structural contract understood by deterministic consumers.

- A schema version change describes a machine-readable shape change, not an agent-policy or hierarchy change by itself.
- Additive fields that existing consumers can safely ignore do not require a new schema version unless they change a consumer's required interpretation.
- Removing or renaming fields, changing field types, changing required semantics, or otherwise making an existing conforming consumer unable to interpret the contract requires a schema-version increment.
- Consumers must reject schema versions newer than the maximum version they explicitly support. They must not silently guess how an unknown version should be interpreted.
- Consumers may support older versions explicitly. Support must be covered by deterministic tests or fixtures rather than assumed.

## Current compatibility

The current contract is schema version 3.

Version 1 established the authority, policy-domain, role, and invariant model. Version 2 added `overlay_contract`; it did not change the role hierarchy, merge authority, or the meaning of the version-1 role and invariant fields. Version 3 added several new fields to the `independent_reviewer` role: `providers` (list of eligible providers), `also_serves` (additional advisory roles the reviewer may fill), `form_constraints` (per-form `github_review_state` semantics, replacing a single `github_review_state` field), and `advice_record_required`. `advice_record_required` changes the required interpretation for consumers that track whether an assigned reviewer must produce a durable record, so a version increment is required. `form_constraints` clarifies that only the `comment_review` form carries a GitHub review state; the `pull_request_comment` form has no review state (`null`).

For the version-1-to-version-2 transition:

1. All version-1 top-level policy domains, roles, and invariants remain present and semantically equivalent in version 2. Version 2 may add safely ignorable fields inside those objects; it must not remove, rename, or change version-1 field values.
2. Version 2 may add overlay validation data without changing version-1 role semantics.
3. A version-1 consumer that only consumes version-1 fields can migrate by explicitly accepting version 2 only after verifying that the fields it consumes retain the expected shape and semantics.
4. A consumer that requires `overlay_contract` must require schema version 2 or newer and must still reject unknown future versions until support is added.

For the version-2-to-version-3 transition:

1. All version-2 top-level policy domains, roles, and invariants remain present and semantically equivalent in version 3.
2. Version 3 adds these fields inside the `independent_reviewer` role: `providers`, `also_serves`, `form_constraints`, and `advice_record_required`. A version-2 consumer that does not inspect these fields is unaffected. A consumer that enforces advice-record obligations or per-form review-state semantics must require schema version 3 or newer.
3. Within schema 3, `independent_reviewer.providers` is now exclusively
   `["grok_build"]` and `invariants.grok_exclusive_independent_review` is
   required. Overlay `required_any` markers may evolve to say that
   Antigravity is not an independent reviewer. Consumers that previously
   treated `antigravity_cli` as a Grok-unavailable independent-review
   provider must stop doing so. These are documented policy tightenings
   inside schema 3, not a new schema version.
3. A version-2 consumer may explicitly accept version 3 after verifying that the fields it consumes retain their expected shape and semantics.

## Migration procedure

When changing the schema:

1. Identify whether the change is additive/ignorable or compatibility-breaking for existing consumers.
2. Increment `schema_version` when existing consumers require changed interpretation or cannot safely consume the new shape.
3. Preserve a fixture for the previous supported schema under `tests/fixtures/agent-role-contract/`.
4. Update semantic tests to prove the intended compatibility or migration boundary.
5. Update this document with the new version's differences and consumer requirements.
6. Keep `AGENTS.md` authoritative. A schema migration must not silently alter hierarchy, authority, routing, or governance policy.

## Consumer rule

A deterministic consumer should declare a maximum supported schema version and fail closed when `schema_version` exceeds it. Compatibility must be explicit; the presence of familiar fields is not sufficient evidence that an unknown future schema is safe to consume.
