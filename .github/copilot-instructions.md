# Copilot implementation instructions

Before changing code, read these sources in order:

1. [`/AGENTS.md`](/AGENTS.md).
2. [`/docs/ROADMAP.md`](/docs/ROADMAP.md).
3. The profile schema relevant to the change (the canonical system profile is
   [`/configs/schemas/system-profile.schema.json`](/configs/schemas/system-profile.schema.json)).
4. Any more deeply nested `AGENTS.md` that applies to files being changed.

Use the root instructions as the complete policy. In implementation work:

- Stage 1 is read-only: it is a hardware detector and system-profile builder.
  Do not add package installation, tuning, service control, downloads, or AI
  benchmarks to Stage 1.
- Stage 2 and later consume the canonical Stage 1 profile.
- Keep hardware identity, device visibility, driver binding, runtime readiness,
  and benchmark success as separate fields.
- Do not treat HX 370, Radeon 890M, `gfx1150`, BIOS 2.01, Strix Point, or XDNA2
  as generic requirements. Prefer structured PCI/sysfs/DMI evidence and
  declarative platform profiles.
- The Minisforum EliteMini AI370 is a reference development and physical test
  platform, not a universal hardware assumption. Keep physical EliteMini checks
  in an opt-in integration suite.
- Use Stage/Milestone terminology; do not introduce new Tier names.
- Use deterministic fixtures for portable tests.
- When the profile contract changes, update schema tests and downstream
  consumer tests.
- Never add `try`/`catch` blocks around imports.
