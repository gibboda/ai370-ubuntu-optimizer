# Configuration-specific instructions

These requirements supplement the repository-wide [`/AGENTS.md`](../AGENTS.md)
policy for all files under `configs/`.

- Hardware profiles are declarative data, not executable shell policy.
- Schema versions are immutable once released.
- Breaking profile-contract changes require a new schema version.
- Profiles use normalized identifiers and distinguish required evidence from
  optional evidence.

## JSON schema versioning (Stage and profile artifacts)

Policy for files under `configs/schemas/`:

- **No version bump** when a change only adds an optional property, widens an
  enum, or adds non-required `$defs` that existing documents omit.
- **Requires `-v2` (new `$id` and schema `version`)** when a change adds a
  property to `required`, narrows an enum, removes a property, or renames a
  field consumers rely on.
- When bumping schema version, update the builder/document `schema.uri` to match
  the new `$id`, add fixtures and consumer tests for the new version, and record
  migration notes for downstream readers.
- Published builders must **always emit** optional fields defined in the current
  schema (for example `support_assessment` on S2-M2 and full `backup` metadata
  on S2-M6 including `rollback_available` when applicable).

## Internal backup manifest

The S2-M6 runtime backup manifest (`schema.name`: `s2-m6-runtime-backup`) under
`reports/latest/s2-m6-runtime-backups/<backup_id>/manifest.json` is an **internal**
apply-session artifact. It is not registered in `configs/schemas/`; consumers are
`optimization_backup.py` and the S2-M6 rollback CLI only.
