# Script-specific instructions

These requirements supplement the repository-wide [`/AGENTS.md`](../AGENTS.md)
policy for all files under `scripts/`.

- Stage 1 collectors must remain read-only.
- Probes must be best-effort, but must record failure reasons.
- Generic hardware detection must use structured identifiers.
- Shell scripts must preserve strict mode and pass ShellCheck.
- Stage 2 and later scripts must load the canonical Stage 1 system profile.
- Hardware-specific overrides must be declarative or explicit.
