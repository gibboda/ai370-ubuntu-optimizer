# Script-specific instructions

These requirements supplement the repository-wide [`/AGENTS.md`](../AGENTS.md)
policy for all files under `scripts/`.

- Stage 1 collectors must remain read-only.
- Probes must be best-effort, but must record failure reasons.
- Generic hardware detection must use structured identifiers.
- Shell scripts must use strict mode (`set -euo pipefail`) and pass ShellCheck.
- **Entry-point** Stage 2 and later scripts (orchestrator commands, `stage2-*`
  wrappers, and milestone publish/validate scripts invoked directly by the CLI)
  must load and validate the canonical Stage 1 system profile
  (`reports/latest/s1-m5-system-profile.json` or an explicit `--profile` path).
- **Internal helper CLIs** under `scripts/` that are only invoked by a
  profile-loading parent (for example from `40-platform-tuning.sh`) are exempt
  from loading the profile themselves when the parent already did. Each exempt
  helper must state that exemption in its module docstring.
- Hardware-specific overrides must be declarative.
