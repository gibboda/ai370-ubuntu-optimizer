# Conventional Commits Audit

Date: 2026-05-27 (UTC)

## Scope
- Reviewed git commit subjects in this repository.
- Compared commit subject format to Conventional Commits 1.0.0 (`<type>[optional scope]: <description>`).

## Summary
- Total commits scanned: 37
- Commits matching strict Conventional Commits pattern: 7
- Commits not matching strict pattern: 30

## Contributor findings
- `gibboda`: mixed compliance; many commits use leading emoji prefixes (for example `✨ feat(...)`) or sentence-case subjects without a type prefix, which are non-compliant under strict parsing.
- `Copilot`: one sampled commit (`chore: Addressing PR comments (#3)`) is compliant.
- `Codex`: no commits authored by `Codex` or a codex-associated noreply identity were found in current history, so Codex compliance cannot be confirmed from existing commits.

## Notable non-compliance patterns
1. Leading emoji before the type (e.g., `✨ feat(...)`, `♻️ refactor(...)`, `📝 docs(...)`).
2. Missing conventional type/scope prefix (e.g., `Fix OS detection fallback in hardware report (#10)`).
3. Inconsistent capitalization in descriptions (not required by spec, but usually standardized by lint rules).

## Recommendation
- Add commit linting (e.g., commitlint + commit-msg hook in CI) to enforce Conventional Commits for all contributors, including AI agents.
- Optionally document whether emoji prefixes are allowed; if they are desired, formalize a custom regex and tooling configuration.
