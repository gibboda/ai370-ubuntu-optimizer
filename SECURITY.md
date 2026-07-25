# Security Policy

## Supported Versions

Security fixes are provided for the latest published release and the current
`main` branch. Older releases and experimental or planned roadmap components
may not receive security updates. Upgrade to the latest release before
reporting an issue when practical.

## Reporting a Vulnerability

Do not open a public issue or discussion for a suspected, unpatched
vulnerability.

Use GitHub's private vulnerability reporting feature from the repository's
**Security** tab. If private reporting is not available, ask a maintainer for a
private reporting channel without including vulnerability details in the
public request.

Include as much of the following information as possible:

- The affected release, commit, script, and configuration.
- The Ubuntu version and relevant hardware profile.
- Reproduction steps or a minimal proof of concept.
- The security impact and any known mitigations.
- Whether reproduction requires elevated privileges, online mode, or an
  explicit risk-acceptance option.
- Sanitized logs or generated reports that help confirm the finding.

Before attaching output, remove credentials, tokens, usernames, hostnames, IP
addresses, device serial numbers, private model paths, and other personal or
system-identifying data.

The maintainers aim to acknowledge a report within three business days and
provide an initial assessment within seven business days. Resolution time will
depend on severity and complexity. Please allow a reasonable remediation
period and coordinate public disclosure with the maintainers.

## Security Scope

Examples of relevant reports include:

- Shell or command injection.
- Unsafe privileged operations, file permissions, persistence changes, or
  path handling.
- Insecure downloads, package installation, archive extraction, or integrity
  verification.
- Credential disclosure or sensitive information written to reports.
- Unintended exposure of local inference or web services.
- A bypass of an explicit safety or risk-acceptance gate.
- Validation logic that incorrectly identifies a security-sensitive state as
  safe.

General support requests, hardware compatibility problems without a security
impact, and reports about unsupported versions are out of scope.

Vulnerabilities that originate solely in Ubuntu, AMD software, ROCm, XRT,
Ollama, Open WebUI, or another third-party component should normally be
reported to that upstream project. Report them here when this project's
configuration or integration introduces the vulnerability, exposes it in a
new way, or materially increases its impact.

## Safe Harbor

Good-faith security research must avoid data destruction, persistence, service
disruption, privacy violations, social engineering, and access to data that
does not belong to the researcher. Stop testing and report the issue if
sensitive data is encountered.

The project will not pursue action against researchers who follow this policy,
make a good-faith effort to avoid harm, and allow a reasonable opportunity to
investigate and remediate the issue. Reporter credit will be provided on
request when legally permissible.
