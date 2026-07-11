# AMD NPU / Ryzen AI Stack Status

This document tracks the Stage 2 AMD AI Stack validation path for the
Minisforum EliteMini AI370 / AMD XDNA-class NPU target.

## Scope

S2-M2 validates the local AMD AI Stack without assuming that proprietary or
platform-specific Ryzen AI components are already present. The scripts are safe
by default: they generate status reports when hardware, kernel modules, runtime
tools, ONNX Runtime, or NPU execution providers are missing.

## Validation flow

Preferred launcher path (inventory-only for XRT unless risk is accepted):

```bash
./ai370-optimize.sh stage2-npu
# Install staged XRT/Ryzen AI packages (requires AMD artifacts):
./ai370-optimize.sh stage2-npu --accept-amd-acceleration-risk
```

Script order for S2-M2:

```bash
./scripts/205-install-xrt-ryzen-ai.sh   # inventory, or install when 5th arg is true
./scripts/200-install-onnxruntime.sh
./scripts/210-check-ryzen-ai-software.sh
./scripts/220-check-vitis-ai-ep.sh
./scripts/230-benchmark-npu.sh
./scripts/240-write-tier3-validation.sh
```

Use `--offline` through the top-level launcher or pass `true` as the fourth
script argument when validating pre-staged offline artifacts. Offline ONNX
Runtime installation expects wheels under `.ai370-ai/wheelhouse`. Stage XRT/NPU
`.deb` files and optional `ryzen_ai-*.tgz` under `.ai370-ai/amd-artifacts`
(see `configs/amd-acceleration.env`). Without `--accept-amd-acceleration-risk`,
`205` only inventories artifacts and writes diagnostics (exit 0 on WARN).

## Generated reports

| Report | Producer | Purpose |
| --- | --- | --- |
| `reports/latest/xrt-ryzen-ai-install.json` | `scripts/205-install-xrt-ryzen-ai.sh` | XRT/Ryzen AI staging inventory or risk-accepted install result. |
| `reports/latest/xrt-ryzen-ai-install.md` | `scripts/205-install-xrt-ryzen-ai.sh` | Human-readable XRT/Ryzen AI install/staging summary. |
| `reports/latest/xrt-ryzen-ai-env.sh` | `scripts/205-install-xrt-ryzen-ai.sh` | PATH/setup snippet for XRT and Ryzen AI install root. |
| `reports/latest/onnxruntime-status.json` | `scripts/200-install-onnxruntime.sh` | ONNX Runtime version, provider list, CPU-provider smoke status, install action. |
| `reports/latest/onnxruntime-status.md` | `scripts/200-install-onnxruntime.sh` | Human-readable ONNX Runtime status summary. |
| `reports/latest/npu-acceleration-status.json` | `scripts/210-check-ryzen-ai-software.sh` | Kernel module, device node, runtime tool, and ONNX Runtime provider detection. |
| `reports/latest/npu-capabilities.json` | `scripts/210-check-ryzen-ai-software.sh` | Expanded NPU/XRT capability details. |
| `reports/latest/xrt-status.txt` | `scripts/210-check-ryzen-ai-software.sh` | Captured `xrt-smi examine` and `xrt-smi validate` output when `xrt-smi` is available. |
| `reports/latest/vitis-ai-ep-status.json` | `scripts/220-check-vitis-ai-ep.sh` | AMD/Ryzen/Vitis execution-provider detection and recommendations. |
| `reports/latest/vitis-ai-ep-status.md` | `scripts/220-check-vitis-ai-ep.sh` | Human-readable execution-provider summary. |
| `reports/latest/npu-benchmark.json` | `scripts/230-benchmark-npu.sh` | CPU baseline and AMD-provider benchmark timings when available, or actionable limitations. |
| `reports/latest/npu-benchmark.md` | `scripts/230-benchmark-npu.sh` | Human-readable NPU benchmark/diagnostic summary. |

## Expected signals

A fully enabled NPU stack should show these signals:

- AMDXDNA/XDNA-related kernel module loaded.
- NPU device node visible, such as `/dev/accel*` or an XDNA/XRT device node.
- XRT/Ryzen AI runtime tools available, preferably including `xrt-smi`.
- ONNX Runtime import succeeds in `.ai370-ai/venv`.
- ONNX Runtime provider list includes an AMD/Ryzen/Vitis/XDNA provider.
- `scripts/230-benchmark-npu.sh` completes a local generated ONNX smoke model
  using that provider.

## Troubleshooting matrix

| Symptom | Likely cause | Next action |
| --- | --- | --- |
| No AMDXDNA/XDNA kernel module | Kernel, firmware, or driver support missing | Re-run Tier 1 kernel/NPU detection and confirm platform firmware support. |
| No NPU device node | Firmware, kernel driver, or permissions issue | Check `reports/latest/tier1-npu.md` and `reports/latest/npu-capabilities.json`. |
| `xrt-smi` missing | Ryzen AI/XRT runtime tools are not installed or not in `PATH` | Stage Ubuntu 26.04 XRT/NPU `.deb` files under `.ai370-ai/amd-artifacts/` (see `configs/amd-acceleration.env`), re-run with `--accept-amd-acceleration-risk`, then rerun `scripts/210-check-ryzen-ai-software.sh`. |
| No matching XRT/NPU debs / staged `*_24.04-*` ignored | Configured globs expect `*_26.04-*` package names | Stage Ubuntu 26.04 debs, or override `XRT_DEB_GLOBS` if you intentionally use another release’s packages. |
| `ERROR: No wheels found in the current directory` | AMD `install_ryzen_ai.sh` expects `.whl` files in the process CWD | Use current `scripts/205-install-xrt-ryzen-ai.sh` (runs the installer from the extract directory). Ensure `ryzen_ai-*.tgz` fully extracted under `.ai370-ai/ryzen-ai/source`. |
| Ryzen AI install needs Python 3.12 | Ryzen AI 1.7.x wheels and installer hard-require `python3.12` | Install Python 3.12 on `PATH` (host default may be 3.13/3.14). `uv python install 3.12` is fine; the toolkit resolves the real binary so AMD’s `venv --copies` works. |
| `ensurepip` / `venv --copies` fails | uv/pyenv **shim** copied into the venv breaks stdlib paths | Re-run with current `scripts/205-install-xrt-ryzen-ai.sh`, or put the real `.../cpython-3.12.*/bin` ahead of shims on `PATH`. |
| ONNX Runtime missing | Python environment has not been prepared | Run `scripts/200-install-onnxruntime.sh`; in offline mode, stage wheels in `.ai370-ai/wheelhouse`. |
| ONNX Runtime has only CPU provider | AMD execution-provider package is not installed or not compatible | Stage/install the matching Ryzen AI / Vitis AI ONNX Runtime provider package (produced by the Ryzen AI software install into `.ai370-ai/ryzen-ai/venv`). |
| AMD provider visible but benchmark fails | Provider/runtime/model compatibility issue | Inspect `reports/latest/vitis-ai-ep-status.md`, `reports/latest/npu-benchmark.md`, and `reports/latest/xrt-status.txt`. |

## Completion criteria

S2-M2 can be treated as complete when all deliverable scripts exist, the status
document exists, and the benchmark step always emits either successful NPU
timings or a clear limitation report explaining why the local hardware/software
stack cannot run NPU inference yet.
