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
(see `configs/amd-acceleration.env`).

XRT `.deb` selection (auto mode, default — no hard-coded Ubuntu list):

1. Prefer the host Ubuntu `VERSION_ID` from `/etc/os-release`.
2. Fall back to the previous Ubuntu LTS (`YY.04` minus two years).
3. Also try Ubuntu tags discovered in staged deb filenames under
   `AMD_ARTIFACT_ROOT` (newest first).
4. If still none, try an explicit `XRT_DEB_GLOBS` override (env or config).
5. Otherwise treat staged XRT packages as missing (install path fails when risk
   is accepted and XRT tools are not already available).

Optional pin: set `XRT_UBUNTU_VERSIONS="26.04 24.04"` to force a fixed try-order.
Set `XRT_DEB_GLOBS_MODE=override` to skip version fallback and require
`XRT_DEB_GLOBS` only. Without `--accept-amd-acceleration-risk`, `205` only
inventories artifacts and writes diagnostics (exit 0 on WARN).

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

## Python environments (two venvs)

Stage 2 NPU intentionally uses **two** Python environments:

| Path | Purpose | Typical packages |
| --- | --- | --- |
| `.ai370-ai/ryzen-ai/venv` | AMD Ryzen AI software + NPU EP (preferred for S2-M2 checks) | `ryzen-ai`, `onnxruntime-vitisai` (import name `onnxruntime`), `onnxruntime-genai-ryzenai` |
| `.ai370-ai/venv` | Stock CPU ONNX Runtime from `scripts/200-install-onnxruntime.sh` | PyPI `onnxruntime`, `onnx`, `numpy` |

`scripts/210-check-ryzen-ai-software.sh`, `scripts/220-check-vitis-ai-ep.sh`, and
`scripts/230-benchmark-npu.sh` resolve the interpreter via
`scripts/lib/npu-venv.sh` and **prefer the Ryzen AI venv** when it is usable.
They also call `prepare_npu_runtime_env` to source XRT (`/opt/xilinx/xrt/setup.sh`)
and prepend AMD native library dirs (`voe/lib`, `onnxruntime/capi`,
`flexml/flexml_extras/lib`) to `LD_LIBRARY_PATH`. Without that, ORT may list
`VitisAIExecutionProvider` but fall back to CPU at session create time with
errors such as `libxcompiler-core-without-symbol.so: cannot open shared object file`.

For interactive shells after install:

```bash
source reports/latest/xrt-ryzen-ai-env.sh
source .ai370-ai/ryzen-ai/venv/bin/activate   # optional; also sets LD_LIBRARY_PATH
```

Do **not** `pip install onnxruntime` into the Ryzen AI venv. AMD replaces stock
ORT with `onnxruntime-vitisai` / `onnxruntime-genai-ryzenai`. Installing the
PyPI package names can break the NPU provider stack.

### Harmless installer warnings

During a fresh Ryzen AI install, AMD’s `install_ryzen_ai.sh` runs:

```bash
uv pip uninstall onnxruntime onnxruntime-vitisai onnxruntime-genai onnxruntime-genai-ryzenai
```

before installing the AMD wheels. On a clean venv you may see:

```text
warning: Skipping onnxruntime as it is not installed
warning: Skipping onnxruntime-genai as it is not installed
```

Those messages are expected and **not** a failure. After a successful install,
`pip list` shows `onnxruntime-vitisai` and `onnxruntime-genai-ryzenai`, and
`import onnxruntime` still works (with `VitisAIExecutionProvider` when XRT/NPU
are available).

## Expected signals

A fully enabled NPU stack should show these signals:

- AMDXDNA/XDNA-related kernel module loaded.
- NPU device node visible, such as `/dev/accel*` or an XDNA/XRT device node.
- XRT/Ryzen AI runtime tools available, preferably including `xrt-smi`.
- ONNX Runtime import succeeds in `.ai370-ai/ryzen-ai/venv` (preferred) or stock
  `.ai370-ai/venv` for CPU-only checks.
- ONNX Runtime provider list includes an AMD/Ryzen/Vitis/XDNA provider (requires
  the Ryzen AI venv).
- `scripts/230-benchmark-npu.sh` completes a local generated ONNX smoke model
  using that provider.

## Troubleshooting matrix

| Symptom | Likely cause | Next action |
| --- | --- | --- |
| No AMDXDNA/XDNA kernel module | Kernel, firmware, or driver support missing | Re-run Tier 1 kernel/NPU detection and confirm platform firmware support. |
| No NPU device node | Firmware, kernel driver, or permissions issue | Check `reports/latest/tier1-npu.md` and `reports/latest/npu-capabilities.json`. |
| `xrt-smi` missing | Ryzen AI/XRT runtime tools are not installed or not in `PATH` | Stage XRT/NPU `.deb` files under `.ai370-ai/amd-artifacts/` (see `configs/amd-acceleration.env`), re-run with `--accept-amd-acceleration-risk`, then rerun `scripts/210-check-ryzen-ai-software.sh`. |
| No matching XRT/NPU debs | No host/previous-LTS/discovered tags matched and no override | Auto mode uses host `VERSION_ID`, previous LTS, and tags parsed from staged deb names, then `XRT_DEB_GLOBS`. Stage matching debs, pin `XRT_UBUNTU_VERSIONS`, or set `XRT_DEB_GLOBS` / `XRT_DEB_GLOBS_MODE=override`. |
| `ERROR: No wheels found in the current directory` | AMD `install_ryzen_ai.sh` expects `.whl` files in the process CWD | Use current `scripts/205-install-xrt-ryzen-ai.sh` (runs the installer from the extract directory). Ensure `ryzen_ai-*.tgz` fully extracted under `.ai370-ai/ryzen-ai/source`. |
| Ryzen AI install needs Python 3.12 | Ryzen AI 1.7.x wheels and installer hard-require `python3.12` | Install Python 3.12 on `PATH` (host default may be 3.13/3.14). `uv python install 3.12` is fine; the toolkit resolves the real binary so AMD’s `venv --copies` works. |
| `ensurepip` / `venv --copies` fails | uv/pyenv **shim** copied into the venv breaks stdlib paths | Re-run with current `scripts/205-install-xrt-ryzen-ai.sh`, or put the real `.../cpython-3.12.*/bin` ahead of shims on `PATH`. |
| `Skipping onnxruntime` / `Skipping onnxruntime-genai` | Clean venv: AMD uninstalls those names before installing `*-vitisai` / `*-ryzenai` wheels | Ignore if the installer continues and finishes. Verify with `.ai370-ai/ryzen-ai/venv/bin/python -c 'import onnxruntime as o; print(o.get_available_providers())'`. |
| ONNX Runtime missing (stock path) | Generic CPU venv not prepared | Run `scripts/200-install-onnxruntime.sh`; in offline mode, stage wheels in `.ai370-ai/wheelhouse`. |
| ONNX Runtime has only CPU provider while Ryzen AI is installed | Checks were using stock `.ai370-ai/venv` instead of Ryzen AI venv | Re-run `scripts/220-check-vitis-ai-ep.sh` / `stage2-npu-validate` with current scripts (prefer Ryzen AI venv). Confirm `venv_source` is `ryzen-ai` in the JSON reports. |
| ONNX Runtime has only CPU provider | AMD execution-provider package is not installed or not compatible | Stage/install the matching Ryzen AI / Vitis AI ONNX Runtime provider package (produced by the Ryzen AI software install into `.ai370-ai/ryzen-ai/venv`). |
| `Failed to load library libonnxruntime_vitisai_ep.so` / missing `libxcompiler-*.so` | `LD_LIBRARY_PATH` missing `voe/lib` (and related AMD dirs) | Re-run with current scripts (auto env prep), or `source reports/latest/xrt-ryzen-ai-env.sh` / activate the Ryzen AI venv before inference. |
| Benchmark requests VitisAI but `actual_provider` is CPU | EP listed but session factory fell back | Same as missing native libs / XRT env above; treat as WARN until `actual_provider` matches. |
| AMD provider visible but benchmark fails | Provider/runtime/model compatibility issue | Inspect `reports/latest/vitis-ai-ep-status.md`, `reports/latest/npu-benchmark.md`, and `reports/latest/xrt-status.txt`. |

## Completion criteria

S2-M2 can be treated as complete when all deliverable scripts exist, the status
document exists, and the benchmark step always emits either successful NPU
timings or a clear limitation report explaining why the local hardware/software
stack cannot run NPU inference yet.
