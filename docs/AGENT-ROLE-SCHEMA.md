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

The current contract is schema version 2.

Version 1 established the authority, policy-domain, role, and invariant model. Version 2 added `overlay_contract`; it did not change the role hierarchy, merge authority, or the meaning of the version-1 role and invariant fields.

For the version-1-to-version-2 transition:

1. All version-1 top-level policy domains, roles, and invariants remain present and semantically equivalent in version 2.
2. Version 2 may add overlay validation data without changing version-1 role semantics.
3. A version-1 consumer that only consumes version-1 fields can migrate by explicitly accepting version 2 only after verifying that the fields it consumes retain the expected shape and semantics.
4. A consumer that requires `overlay_contract` must require schema version 2 or newer and must still reject unknown future versions until support is added.

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
