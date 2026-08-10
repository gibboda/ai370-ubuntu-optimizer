# System-profile fixtures

The `v3/` directory contains sanitized, deterministic documents for the current
Stage 1 system-profile contract. `valid-reference.json` is schema-valid with
explicit unknown states for motherboard, GPU/NPU runtimes, UEFI, and Secure
Boot; it does not represent a fully observed machine. The invalid v3 fixture
intentionally has a malformed fingerprint and an undeclared system property; it
must never be published. The `v2/` fixtures are retained as migration evidence.

Fixture directories are versioned with the schema. A future breaking contract
must add a new directory rather than changing the meaning of these documents.
