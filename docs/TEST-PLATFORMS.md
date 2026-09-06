# Test Platforms

This document records hardware used to validate the project. Test platforms are
reference environments, not definitions of the project architecture.

A successful result on one platform establishes compatibility only for the
recorded configuration and test scope. A limitation, workaround, optimization,
or vendor-specific dependency discovered on a test platform must not become a
project-wide requirement without architectural justification.

## Current primary physical integration platform

### Minisforum EliteMini AI370

Role: current development, integration, and validation platform for AMD Ryzen AI
support.

Baseline configuration:

- System: Minisforum EliteMini AI370
- Processor: AMD Ryzen AI 9 HX 370 (Strix Point)
- CPU architecture: Zen 5, 12 cores / 24 threads
- Integrated GPU: AMD Radeon 890M, RDNA 3.5, `gfx1150`
- NPU: AMD XDNA2, up to 50 TOPS
- Memory class: LPDDR5X-7500
- Storage class: PCIe 4.0 NVMe
- Firmware baseline: BIOS 2.01, verified April 2026

Repository profile data, fixtures, and subsequently verified observations are
more authoritative than this descriptive baseline when they differ.

## Portability rules

Generic collectors, schemas, orchestration, policy, and platform-independent
logic must not require:

- Minisforum hardware
- Ryzen AI 9 HX 370
- Strix Point
- Radeon 890M
- `gfx1150`
- XDNA2
- BIOS 2.01
- ROCm
- an AMD-specific runtime

Hardware-specific behavior belongs in declarative profiles, capability
detection, backend/provider modules, platform adapters, fixtures, or isolated
optimization layers as appropriate.

Unknown or future hardware must remain representable with explicit unknown,
unsupported, unavailable, or capability-state values rather than failing only
because it is not the current test platform.

## Evidence handling

When recording a test result, distinguish:

- detected hardware
- driver/runtime readiness
- backend readiness
- framework readiness
- workload execution
- benchmark/performance results

Hardware presence alone does not establish workload support.

For external support claims, use `docs/AUTHORITATIVE-SOURCES.md`.
For project architecture, use `docs/HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md`.
For migration status and current-to-target mapping, use
`docs/RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md` and `docs/ROADMAP.md`.
