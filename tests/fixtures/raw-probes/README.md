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

`observed-ryzen-ai-hx470.json` is a sanitized Stage 1 probe derived from a
Minisforum AI Series host (AMD Ryzen AI 9 HX 470) captured at repository
commit `1d1f78b` on 2026-11-03. Redacted before commit: storage and block
device serial numbers, partition/disk UUIDs, full `lsblk` inventory, probe
stdout blobs, hostnames, usernames/home paths, and MAC addresses. Hardware
IDs, DMI product/vendor strings, CPU model text, PCI slot ids, and BIOS version
remain. The iGPU PCI id is `1002:150e`. The XDNA2 function `1022:17f0` appears
in both the PCI inventory and accelerator inventory with class
`Signal processing controller`, matching current lspci. The sensor hub
`1022:164a` shares that class and must not become an NPU.

`observed-ryzen-ai-hx470-pci-npu-only.json` is the same host identity with an
empty accelerator device list so portable tests cover `_npu_devices_from_raw`
PCI-inventory fallback (NPU only under `pci.devices`).
