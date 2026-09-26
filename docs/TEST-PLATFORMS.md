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
- Firmware baseline: BIOS 2.01
- Operating system class: Ubuntu 26.04 LTS
- Kernel class: Linux 7.x or later

Do not pin a specific kernel release. Detect features, versions, and
capabilities so newer supported kernels remain acceptable.

Repository profile data, fixtures, and subsequently verified observations are
more authoritative than this descriptive baseline when they differ.

## Officially documented hardware profile

### AMD Ryzen AI MAX / MAX+ (Strix Halo, Ryzen AI Halo)

Role: declarative hardware profile of the same Ryzen AI Linux platform as the
EliteMini AI370. This is not a second platform architecture and it is not the
physical integration system.

Documented identity, from AMD ROCm Strix Halo guidance:

- Product family: AMD Ryzen AI MAX and MAX+
- Codename: Strix Halo (Ryzen AI Halo in this repository's profile aliases)
- Integrated GPU target: `gfx1151`, RDNA 3.5
- NPU family: XDNA2, using the shared Strix/Krackan/Strix Halo PCI identity
  already mapped as `1022:17f0`
- Memory class: unified LPDDR5X, up to 128 GB
- Optimization data: shared-memory GTT/TTM guidance in
  `configs/tuning/strix-halo-shared-memory.env`
- Support class: officially documented. Physical validation is opt-in.

Do not copy AI370 BIOS 2.01, `gfx1150`, or EliteMini DMI identity onto this
profile. No Strix Halo CPUID is recorded until a sanitized probe supplies it.

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
