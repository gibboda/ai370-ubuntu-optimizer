# S2-M4 NPU visibility scope

`stage2-npu-validate` (default) runs `scripts/s2-m4-validate-npu-stack.sh` in **visibility-only**
mode. It publishes `s2-m4-npu-runtime-validation.json` with `validation_claim: false` and does
**not** run `scripts/230-benchmark-npu.sh` or claim executed inference.

## Visibility vs provider selection vs execution

| Concern | Stage 2 (S2-M4) | Stage 3 |
| --- | --- | --- |
| Module / device nodes | Ladder `DETECTED` / `DRIVER_READY` | Same facts may be reused |
| Firmware / runtime / backend visibility | Ladder steps through `BACKEND_READY` | Runtime install proof |
| Provider candidates (Vitis AI EP, etc.) | `provider_selection` records candidates only | Execution validation |
| Inference / MatMul benchmarks | **Out of scope** | S3-M4 / S3-M6 |

When the collector observes ONNX Runtime provider candidates, the report may include
`provider_selection.inference_executed: false` even if `backend_ready` is true.

## Mixed `--bench` compatibility path

`./ai370-optimize.sh stage2-npu --bench` and `stage2-npu-validate --bench` still invoke the
legacy 210/220/230/245 compatibility chain until canonical S3-M6 benchmarks exist. That path is
**not** the default S2-M4 publisher and must not be treated as Stage 2 exit evidence.

Default validation command (portable CI uses fixture publishers instead):

```bash
./ai370-optimize.sh stage1
./ai370-optimize.sh stage2-npu-validate
```

Hardware-only xrt-smi / Vitis execution checks remain optional integration tests, not CI gates.
