# Multi-Agent Architecture Distribution

`AGENTS.md` remains authoritative in every consumer repository. Cross-repository distribution shares validated machine-readable architecture contracts; it does not create a remote policy authority and does not overwrite repository-local governance.

## Source package

The source repository publishes the package boundary in `config/agent-distribution.json`. Consumers pin an immutable source commit or release tag in `config/agent-distribution-lock.json`.

Portable contracts are the vendor-neutral role, escalation, work-allocation, credential-capability, and MCP contracts. Repository-local policy and governance remain local, including `AGENTS.md`, PR governance, CODEOWNERS, CI composition, architecture coverage evidence, and repository-release compatibility metadata in `config/agent-contract-compatibility.json`. That compatibility file embeds this repository's release history and pins the local `config/pr-governance.json` schema, so copying it would fail consumers that keep their own `VERSION` or governance contract.

## Controlled synchronization

Synchronization follows these rules:

1. Read the source distribution manifest and an immutable source ref.
2. Compare only the declared portable files against the consumer lock's managed files.
3. If a managed consumer file has local divergence from its previously pinned source, stop and require review; do not overwrite it.
4. Never synchronize repository-local files from the source package.
5. Update portable files and the consumer lock together on a dedicated branch.
6. Run the consumer repository's deterministic architecture validation.
7. Deliver synchronization through a pull request. Never auto-merge architecture synchronization.
8. The consumer's human governance remains final authority.

This deliberately favors detectable drift over automatic convergence. A consumer may adopt a newer package version only after reviewing compatibility and repository-specific effects.

## Consumer lock

A consumer lock records the package name/version, source repository, immutable source ref, and exact managed-file list. The source repository also carries a lock with `role: source` so the package boundary is testable before distribution.

## Future automation boundary

Automation may discover a newer compatible source package, prepare a branch, copy only declared portable files, update the lock, run deterministic tests, and open a pull request. Automation must not rewrite local policy, bypass compatibility validation, force synchronization across local divergence, or merge the pull request.
