# Test-specific instructions

These requirements supplement the repository-wide [`/AGENTS.md`](../AGENTS.md)
policy for all files under `tests/`.

- Portable tests use fixtures and must not depend on `/sys`, `/dev`, `lspci`,
  `lsmod`, or network state unless explicitly marked as integration tests.
- Hardware fixtures must be sanitized, versioned, and documented.
- Physical hardware tests are opt-in.
- Unexpected failures must not be hidden with unconditional `|| true`.
