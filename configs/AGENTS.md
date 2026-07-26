# Configuration-specific instructions

These requirements supplement the repository-wide [`/AGENTS.md`](../AGENTS.md)
policy for all files under `configs/`.

- Hardware profiles are declarative data, not executable shell policy where
  avoidable.
- Schema versions are immutable once released.
- Breaking profile-contract changes require a new schema version.
- Profiles use normalized identifiers and distinguish required evidence from
  optional evidence.
