# Conventional Commits Audit

Date: 2026-05-27 (UTC)

## Scope
- Reviewed current git commit subjects in this repository's fetched history.
- Normalized GitHub squash-merge subjects by ignoring any trailing ` (#PR)` suffix, then compared the remaining title to this repository's documented convention from `CONTRIBUTING.md`: `type(scope): Subject` (optional `!` before `:` for breaking changes, with an upper-case subject).
- Because default-branch history is created by squash merges, repository-level compliance is primarily enforced through PR titles, which GitHub uses for the merged commit subject.

## Summary
- Total commits scanned: 39
- Commit subjects matching the documented repository convention after normalization: 7
- Commit subjects not matching the documented repository convention: 32

## Contributor findings
- `gibboda`: mixed compliance; 6 of 38 scanned subjects match the documented format after normalization, while many older commits use leading emoji prefixes, unlisted scopes, or lower-case subjects after the colon.
- `Copilot`: one sampled commit (`chore: Addressing PR comments (#3)`) matches the documented format after normalization.

## Notable non-compliance patterns
1. Leading emoji before the type (e.g., `✨ feat(...)`, `♻️ refactor(...)`, `📝 docs(...)`).
2. Missing conventional type/scope prefix (e.g., `Fix OS detection fallback in hardware report (#10)`).
3. Lower-case subjects after the colon, which are non-compliant in this repository because `CONTRIBUTING.md` requires the subject to begin with an upper-case letter (for example `docs(audit): add conventional commits compliance report` and `fix: remove the file`).

## Recommendation
- CI should validate both PR titles and every commit subject pushed to a PR against the documented repository convention so non-conforming contributions are blocked before merge.
- Optional local hook tooling (for example `commit-msg` via Husky, lefthook, or pre-commit) can provide earlier feedback before contributors push.
