# Raw Stage 1 probe fixtures

The `v1/` directory contains sanitized raw probe artifacts used by portable
system-profile tests. These fixtures intentionally cover the reference
EliteMini AI370, the Ryzen AI 300 family, a constructed Ryzen AI MAX / Strix
Halo profile, unsupported hosts, missing tools, unreadable probes, degraded
drivers, and unrelated accelerator nodes. The canonical S1-M1 command replays
them with `--fixture` so portable tests never depend on the executing host.
S1-M2 through S1-M5 consume the same fixtures and derive GPU architecture from
PCI vendor:device mappings rather than marketing names.

`observed-ryzen-ai-max-strix-halo.json` is constructed from AMD ROCm Strix Halo
documentation. It is not a captured probe. GPU architecture `gfx1151` is
supplied because this repository has no verified Strix Halo PCI device id to
add to `gpu-pci-architectures.json`. The NPU id `1022:17f0` is the existing
XDNA2 mapping shared by Strix, Krackan, and Strix Halo. No CPUID is invented.
