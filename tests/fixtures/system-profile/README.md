# System-profile fixtures

The `v2/` directory contains sanitized, deterministic documents for the Stage 1
system-profile contract. `valid-reference.json` represents a fully observed
generic reference machine. `invalid-contract.json` intentionally has a malformed
fingerprint and an undeclared system property; it must never be published.

Fixture directories are versioned with the schema. A future breaking contract
must add a new directory rather than changing the meaning of these documents.
