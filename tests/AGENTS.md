# Test-specific instructions

These requirements supplement the repository-wide [`/AGENTS.md`](../AGENTS.md)
policy for all files under `tests/`.

- Portable tests use fixtures and must not depend on `/sys`, `/dev`, `lspci`,
  `lsmod`, or network state unless explicitly marked as integration tests.
- GitHub Actions **Portable tests** run as unprivileged `ai370ci` (no passwordless
  `sudo`), export `AI370_CI_NO_HOST_MUTATION=1` for test steps, and fail on host
  drift canary mismatches. Scripts are not required to read that variable yet.
- Hardware fixtures must be sanitized, versioned, and documented.
- Physical hardware tests are opt-in.
- Unexpected failures must not be hidden with unconditional `|| true`.
