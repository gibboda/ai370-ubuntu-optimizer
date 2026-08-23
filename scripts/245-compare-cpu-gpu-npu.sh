#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S3-M6: compare CPU, GPU (ROCm/HIP), and NPU (Vitis AI EP) microbenchmark paths.
# Emits reports/latest/cpu-gpu-npu-comparison.{json,md}.
# Idempotent; does not download models or install packages.
# Script id 245 (id 240 is reserved for 240-write-tier3-validation.sh).

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/npu-venv.sh
source "$PROJECT_ROOT/scripts/lib/npu-venv.sh"

LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$PROJECT_ROOT/.ai370-ai"
STOCK_VENV_PY="$AI_ROOT/venv/bin/python"
OUT_JSON="$LATEST_DIR/cpu-gpu-npu-comparison.json"
OUT_MD="$LATEST_DIR/cpu-gpu-npu-comparison.md"

# Microbenchmark knobs (override via environment).
COMPARE_ORT_WARMUP="${COMPARE_ORT_WARMUP:-5}"
COMPARE_ORT_RUNS="${COMPARE_ORT_RUNS:-25}"
COMPARE_TORCH_SIZE="${COMPARE_TORCH_SIZE:-512}"
COMPARE_TORCH_ITERS="${COMPARE_TORCH_ITERS:-20}"

main() {
  echo "[INFO] S3-M6: CPU / GPU / NPU comparison benchmark"
  echo "[INFO] Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent comparison configuration is not implemented. Use --persistence=runtime."
    exit 2
  fi

  mkdir -p "$LATEST_DIR"

  # Prefer Ryzen AI venv for ONNX NPU EP; stock venv for PyTorch ROCm.
  prepare_npu_runtime_env "$PROJECT_ROOT"
  local npu_python=""
  npu_python="$(resolve_npu_python "$PROJECT_ROOT" || true)"
  local npu_source
  npu_source="$(npu_python_source_label "${npu_python:-}")"

  local torch_python=""
  if [[ -x "$STOCK_VENV_PY" ]]; then
    torch_python="$STOCK_VENV_PY"
  elif [[ -n "$npu_python" && -x "$npu_python" ]]; then
    torch_python="$npu_python"
  elif command -v python3 >/dev/null 2>&1; then
    torch_python="$(command -v python3)"
  fi

  local ort_python="${npu_python:-$torch_python}"

  # Package C: reuse profiled NPU results from 230 when fresh (default on).
  REUSE_NPU_BENCH="${AI370_REUSE_NPU_BENCH:-true}"

  PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" OFFLINE="$OFFLINE" \
  ORT_PYTHON="${ort_python:-}" NPU_SOURCE="${npu_source:-unknown}" \
  TORCH_PYTHON="${torch_python:-}" LATEST_DIR="$LATEST_DIR" \
  PROJECT_ROOT="$PROJECT_ROOT" \
  REUSE_NPU_BENCH="$REUSE_NPU_BENCH" \
  COMPARE_ORT_WARMUP="$COMPARE_ORT_WARMUP" COMPARE_ORT_RUNS="$COMPARE_ORT_RUNS" \
  COMPARE_TORCH_SIZE="$COMPARE_TORCH_SIZE" COMPARE_TORCH_ITERS="$COMPARE_TORCH_ITERS" \
  python3 - "$OUT_JSON" "$OUT_MD" <<'PY'
import datetime
import json
import os
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

json_path = Path(sys.argv[1])
md_path = Path(sys.argv[2])

profile = os.environ.get("PROFILE", "ai370")
mode = os.environ.get("MODE", "safe")
persistence = os.environ.get("PERSISTENCE", "runtime")
offline = os.environ.get("OFFLINE", "false").lower() == "true"
ort_python = os.environ.get("ORT_PYTHON", "") or ""
npu_source = os.environ.get("NPU_SOURCE", "unknown")
torch_python = os.environ.get("TORCH_PYTHON", "") or ""
latest_dir = Path(os.environ.get("LATEST_DIR", "reports/latest"))
ort_warmup = int(os.environ.get("COMPARE_ORT_WARMUP", "5"))
ort_runs = int(os.environ.get("COMPARE_ORT_RUNS", "25"))
torch_size = int(os.environ.get("COMPARE_TORCH_SIZE", "512"))
torch_iters = int(os.environ.get("COMPARE_TORCH_ITERS", "20"))

provider_tokens = ("vitis", "vai", "ryzen", "xilinx", "amd", "xdna")
paths = []
diagnostics = []
prior_reports = {}
reuse_npu_bench = os.environ.get("REUSE_NPU_BENCH", "true").lower() == "true"
skip_live_npu_ort = False


def load_json(name: str):
    p = latest_dir / name
    if not p.is_file():
        return None
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception as exc:
        diagnostics.append(f"Could not parse prior report {name}: {type(exc).__name__}: {exc}")
        return None


def run_script(python_bin: str, code: str, timeout: int = 180):
    if not python_bin:
        return False, "", "no interpreter"
    with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as tf:
        tf.write(code)
        script = tf.name
    try:
        proc = subprocess.run(
            [python_bin, script],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        return proc.returncode == 0, proc.stdout.strip(), proc.stderr.strip()
    except FileNotFoundError:
        return False, "", f"interpreter not found: {python_bin}"
    except subprocess.TimeoutExpired:
        return False, "", f"timed out after {timeout}s"
    finally:
        try:
            Path(script).unlink(missing_ok=True)
        except Exception:
            pass


def parse_last_json(stdout: str):
    if not stdout:
        return None
    for line in reversed(stdout.splitlines()):
        line = line.strip()
        if not line:
            continue
        try:
            return json.loads(line)
        except json.JSONDecodeError:
            continue
    return None


# Package C: reuse NPU EP timings from scripts/230 when available.
npu_prior = load_json("npu-benchmark.json")
if npu_prior:
    prior_reports["npu-benchmark.json"] = npu_prior.get("status")
if reuse_npu_bench and npu_prior:
    for bench in npu_prior.get("benchmarks") or []:
        req = str(bench.get("requested_provider") or "")
        is_amd = any(t in req.lower() for t in provider_tokens)
        if not is_amd:
            continue
        if not (bench.get("ep_verified") and bench.get("ep_executed")):
            continue
        paths.append({
            "framework": "onnxruntime",
            "workload": "onnx_matmul_add_1x64",
            "requested_device": bench.get("requested_provider"),
            "actual_device": bench.get("actual_provider"),
            "device_class": "npu",
            "runs": bench.get("runs") or 0,
            "mean_ms": bench.get("mean_ms"),
            "median_ms": bench.get("median_ms"),
            "min_ms": bench.get("min_ms"),
            "max_ms": bench.get("max_ms"),
            "status": "pass",
            "note": "reused from npu-benchmark.json (230); set AI370_REUSE_NPU_BENCH=false to re-run",
            "ep_executed": True,
            "ep_verified": True,
            "profile": bench.get("profile") or {},
            "vaiml": bench.get("vaiml") or {},
            "source": "npu-benchmark.json",
        })
        skip_live_npu_ort = True
    if skip_live_npu_ort:
        diagnostics.append(
            "Reused profiled NPU EP results from npu-benchmark.json (Package C). "
            "Set AI370_REUSE_NPU_BENCH=false to force a live NPU MatMul in 245."
        )

# --- ONNX Runtime: CPU + NPU on identical MatMul+Add model ---
if ort_python:
    project_root = os.environ.get("PROJECT_ROOT", "")
    skip_npu = skip_live_npu_ort
    ort_code = f"""
import json, os, sys, tempfile
from pathlib import Path

warmup = {ort_warmup}
runs = {ort_runs}
tokens = {provider_tokens!r}
skip_npu = {skip_npu!r}
sys.path.insert(0, str(Path({project_root!r}) / "scripts" / "lib"))
payload = {{"ok": True, "error": "", "providers": [], "amd_candidates": [], "results": []}}

try:
    import numpy as np
    import onnx
    import onnx.helper as oh
    import onnx.numpy_helper as nh
    import onnxruntime as ort
    from npu_ep_verify import run_provider_benchmark
except Exception as e:
    payload["ok"] = False
    payload["error"] = f"{{type(e).__name__}}: {{e}}"
    print(json.dumps(payload))
    raise SystemExit(0)

providers = list(ort.get_available_providers())
amd = [p for p in providers if any(t in p.lower() for t in tokens)]
payload["providers"] = providers
payload["amd_candidates"] = amd
results = []

try:
    with tempfile.TemporaryDirectory(prefix="ai370-compare-ort-") as tmp:
        model_file = Path(tmp) / "matmul_add.onnx"
        input_tensor = oh.make_tensor_value_info("input", onnx.TensorProto.FLOAT, [1, 64])
        output_tensor = oh.make_tensor_value_info("output", onnx.TensorProto.FLOAT, [1, 64])
        weight = nh.from_array(np.eye(64, dtype=np.float32), name="weight")
        bias = nh.from_array(np.ones((64,), dtype=np.float32), name="bias")
        graph = oh.make_graph(
            [
                oh.make_node("MatMul", ["input", "weight"], ["mm"]),
                oh.make_node("Add", ["mm", "bias"], ["output"]),
            ],
            "ai370_compare_smoke",
            [input_tensor],
            [output_tensor],
            [weight, bias],
        )
        model = oh.make_model(graph, opset_imports=[oh.make_operatorsetid("", 17)])
        model.ir_version = min(model.ir_version, 10)
        onnx.checker.check_model(model)
        onnx.save(model, model_file)
        feed = {{"input": np.ones((1, 64), dtype=np.float32)}}

        def to_path_result(raw, device_class_hint):
            actual = raw.get("actual_provider")
            verified = bool(raw.get("ep_verified"))
            executed = bool(raw.get("ep_executed"))
            is_amd = any(t in (raw.get("requested_provider") or "").lower() for t in tokens)
            if is_amd:
                # Keep failed NPU attempts under device_class=npu for diagnostics;
                # aggregation only counts status=pass with ep_verified.
                dclass = "npu"
                st = "pass" if verified and executed else "fail"
            else:
                dclass = device_class_hint
                if "cpu" in (actual or "").lower():
                    dclass = "cpu"
                st = "pass" if verified else "warn"
            note = raw.get("note") or ""
            return {{
                "framework": "onnxruntime",
                "workload": "onnx_matmul_add_1x64",
                "requested_device": raw.get("requested_provider"),
                "actual_device": actual,
                "device_class": dclass,
                "runs": raw.get("runs") or 0,
                "mean_ms": raw.get("mean_ms"),
                "median_ms": raw.get("median_ms"),
                "min_ms": raw.get("min_ms"),
                "max_ms": raw.get("max_ms"),
                "status": st,
                "note": note,
                "ep_executed": executed,
                "ep_verified": verified,
                "profile": raw.get("profile") or {{}},
                "vaiml": raw.get("vaiml") or {{}},
            }}

        if "CPUExecutionProvider" in providers:
            raw = run_provider_benchmark(
                model_file,
                "CPUExecutionProvider",
                input_feed=feed,
                warmup=warmup,
                runs=runs,
                tokens=tokens,
                require_ep_execution=False,
                enable_vitis_options=False,
            )
            results.append(to_path_result(raw, "cpu"))
        else:
            results.append({{
                "framework": "onnxruntime",
                "workload": "onnx_matmul_add_1x64",
                "requested_device": "CPUExecutionProvider",
                "actual_device": None,
                "device_class": "cpu",
                "runs": 0,
                "mean_ms": None,
                "median_ms": None,
                "min_ms": None,
                "max_ms": None,
                "status": "skipped",
                "note": "CPUExecutionProvider not available",
                "ep_executed": False,
                "ep_verified": False,
            }})

        if skip_npu:
            # NPU path already filled from npu-benchmark.json by outer 245 process.
            pass
        elif amd:
            for p in amd[:1]:
                try:
                    raw = run_provider_benchmark(
                        model_file,
                        p,
                        input_feed=feed,
                        warmup=warmup,
                        runs=runs,
                        tokens=tokens,
                        require_ep_execution=True,
                        enable_vitis_options=True,
                    )
                    results.append(to_path_result(raw, "npu"))
                except Exception as e:
                    results.append({{
                        "framework": "onnxruntime",
                        "workload": "onnx_matmul_add_1x64",
                        "requested_device": p,
                        "actual_device": None,
                        "device_class": "npu",
                        "runs": 0,
                        "mean_ms": None,
                        "median_ms": None,
                        "min_ms": None,
                        "max_ms": None,
                        "status": "fail",
                        "note": f"{{type(e).__name__}}: {{e}}",
                        "ep_executed": False,
                        "ep_verified": False,
                    }})
        else:
            results.append({{
                "framework": "onnxruntime",
                "workload": "onnx_matmul_add_1x64",
                "requested_device": "VitisAIExecutionProvider",
                "actual_device": None,
                "device_class": "npu",
                "runs": 0,
                "mean_ms": None,
                "median_ms": None,
                "min_ms": None,
                "max_ms": None,
                "status": "skipped",
                "note": "No AMD/Vitis/Ryzen ONNX Runtime provider detected",
                "ep_executed": False,
                "ep_verified": False,
            }})
except Exception as e:
    payload["error"] = f"{{type(e).__name__}}: {{e}}"

payload["results"] = results
print(json.dumps(payload))
"""
    ok, out, err = run_script(ort_python, ort_code)
    payload = parse_last_json(out)
    if not payload:
        diagnostics.append(
            f"ONNX Runtime comparison failed: {(err or out or 'no output')[:300]}"
        )
    else:
        if payload.get("error"):
            diagnostics.append(f"ONNX Runtime note: {payload['error']}")
        if not payload.get("ok", True):
            diagnostics.append(
                f"ONNX Runtime unavailable in {ort_python}: {payload.get('error')}. "
                "Install via scripts/200-install-onnxruntime.sh or Ryzen AI (205)."
            )
        for r in payload.get("results") or []:
            paths.append(r)
            if r.get("status") == "skipped" and r.get("note"):
                diagnostics.append(r["note"])
else:
    diagnostics.append(
        "Skipped ONNX Runtime comparison: no Python interpreter resolved. "
        "Run stage2-npu or scripts/200-install-onnxruntime.sh."
    )

# --- PyTorch: CPU + GPU (ROCm/HIP via cuda device) ---
if torch_python:
    torch_code = f"""
import json, time

size = {torch_size}
iters = {torch_iters}
out = {{"ok": True, "error": "", "results": [], "hip": False, "cuda_available": False}}

try:
    import torch
except Exception as e:
    out["ok"] = False
    out["error"] = f"{{type(e).__name__}}: {{e}}"
    print(json.dumps(out))
    raise SystemExit(0)

out["hip"] = bool(getattr(torch.version, "hip", None))
out["hip_version"] = str(getattr(torch.version, "hip", None) or "")
out["cuda_available"] = bool(torch.cuda.is_available()) if hasattr(torch, "cuda") else False
try:
    out["device_count"] = int(torch.cuda.device_count()) if out["cuda_available"] else 0
    out["device_name"] = torch.cuda.get_device_name(0) if out["cuda_available"] and out["device_count"] else ""
except Exception as e:
    out["device_count"] = 0
    out["device_name"] = ""
    out["device_query_error"] = f"{{type(e).__name__}}: {{e}}"

def bench(device_name, dclass):
    device = torch.device(device_name)
    x = torch.randn(size, size, device=device)
    for _ in range(3):
        y = x @ x
    if device.type == "cuda":
        torch.cuda.synchronize()
    timings = []
    for _ in range(iters):
        if device.type == "cuda":
            torch.cuda.synchronize()
        t0 = time.perf_counter()
        y = x @ x
        if device.type == "cuda":
            torch.cuda.synchronize()
        timings.append((time.perf_counter() - t0) * 1000.0)
    mean = sum(timings) / len(timings)
    s = sorted(timings)
    mid = len(s) // 2
    median = s[mid] if len(s) % 2 else (s[mid - 1] + s[mid]) / 2
    note = ""
    if dclass == "gpu" and out["hip"]:
        note = "ROCm/HIP"
    return {{
        "framework": "pytorch",
        "workload": f"torch_matmul_{{size}}x{{size}}",
        "requested_device": device_name,
        "actual_device": device_name,
        "device_class": dclass,
        "runs": len(timings),
        "mean_ms": mean,
        "median_ms": median,
        "min_ms": min(timings),
        "max_ms": max(timings),
        "status": "pass",
        "note": note,
    }}

try:
    out["results"].append(bench("cpu", "cpu"))
except Exception as e:
    out["results"].append({{
        "framework": "pytorch",
        "workload": f"torch_matmul_{{size}}x{{size}}",
        "requested_device": "cpu",
        "actual_device": None,
        "device_class": "cpu",
        "runs": 0,
        "mean_ms": None,
        "median_ms": None,
        "min_ms": None,
        "max_ms": None,
        "status": "fail",
        "note": f"{{type(e).__name__}}: {{e}}",
    }})

if out["cuda_available"]:
    try:
        out["results"].append(bench("cuda", "gpu"))
    except Exception as e:
        out["results"].append({{
            "framework": "pytorch",
            "workload": f"torch_matmul_{{size}}x{{size}}",
            "requested_device": "cuda",
            "actual_device": None,
            "device_class": "gpu",
            "runs": 0,
            "mean_ms": None,
            "median_ms": None,
            "min_ms": None,
            "max_ms": None,
            "status": "fail",
            "note": f"{{type(e).__name__}}: {{e}}",
        }})
else:
    # Package D: richer gfx1150 / HIP diagnostics when GPU path is unavailable
    tip_parts = ["torch.cuda.is_available() is false"]
    if out["hip"]:
        tip_parts.append("HIP build present but no device")
        tip_parts.append(
            "On Radeon 890M (gfx1150) try a ROCm build that lists gfx1150, "
            "or set HSA_OVERRIDE_GFX_VERSION only as a last-resort experiment"
        )
        tip_parts.append("confirm rocminfo shows the agent and amdgpu is loaded")
    else:
        tip_parts.append("no ROCm/CUDA device for PyTorch (CPU-only torch?)")
        tip_parts.append("re-run scripts/100-install-pytorch-rocm.sh for a HIP wheel")
    out["results"].append({{
        "framework": "pytorch",
        "workload": f"torch_matmul_{{size}}x{{size}}",
        "requested_device": "cuda",
        "actual_device": None,
        "device_class": "gpu",
        "runs": 0,
        "mean_ms": None,
        "median_ms": None,
        "min_ms": None,
        "max_ms": None,
        "status": "skipped",
        "note": "; ".join(tip_parts),
        "hip": out["hip"],
        "hip_version": out.get("hip_version"),
    }})

print(json.dumps(out))
"""
    ok, out, err = run_script(torch_python, torch_code)
    payload = parse_last_json(out)
    if not payload:
        diagnostics.append(
            f"PyTorch comparison failed: {(err or out or 'no output')[:300]}"
        )
    else:
        if payload.get("error"):
            diagnostics.append(
                f"PyTorch unavailable in {torch_python}: {payload['error']}. "
                "Install via scripts/100-install-pytorch-rocm.sh."
            )
        for r in payload.get("results") or []:
            paths.append(r)
            if r.get("status") == "skipped" and r.get("device_class") == "gpu":
                note = r.get("note") or "GPU path skipped"
                diagnostics.append(note)
                # Surface gfx1150-oriented guidance once when HIP is present but unused
                if payload.get("hip") and not payload.get("cuda_available"):
                    diagnostics.append(
                        "GPU class skipped with HIP build: Radeon 890M/gfx1150 often needs a "
                        "ROCm PyTorch wheel that advertises the arch; check rocminfo + "
                        "scripts/100-install-pytorch-rocm.sh. NPU path is independent (230/reuse)."
                    )
            if r.get("status") == "fail" and r.get("device_class") == "gpu":
                diagnostics.append(
                    f"GPU matmul failed: {r.get('note')}. "
                    "For gfx1150, verify HIP runtime and that torch sees the device "
                    f"(hip={payload.get('hip')}, cuda_available={payload.get('cuda_available')})."
                )
else:
    diagnostics.append(
        "Skipped PyTorch comparison: no interpreter. Run scripts/100-install-pytorch-rocm.sh."
    )

# --- Prior related reports (context only) ---
npu_prior = load_json("npu-benchmark.json")
if npu_prior:
    prior_reports["npu_benchmark"] = {
        "status": npu_prior.get("status"),
        "providers": npu_prior.get("providers"),
        "benchmarks": npu_prior.get("benchmarks"),
    }
llm_prior = load_json("tier2-runtime-benchmark.json")
if llm_prior:
    prior_reports["llm_runtime_benchmark"] = {
        "status": llm_prior.get("status"),
        "measured": llm_prior.get("measured"),
        "metrics": llm_prior.get("metrics"),
        "pytorch_rocm": llm_prior.get("pytorch_rocm"),
    }

# Only verified passes contribute to device-class presence / speedups.
# NPU requires ep_verified (profiled kernels on the AMD EP), not merely session listing.
measured = []
for p in paths:
    if not isinstance(p.get("mean_ms"), (int, float)):
        continue
    if p.get("status") != "pass":
        continue
    if p.get("device_class") == "npu" and not (p.get("ep_verified") and p.get("ep_executed")):
        continue
    measured.append(p)
by_class = {"cpu": [], "gpu": [], "npu": [], "other": []}
for p in measured:
    by_class.setdefault(p.get("device_class") or "other", []).append(p)

classes_present = [c for c in ("cpu", "gpu", "npu") if by_class.get(c)]


def best_mean(entries):
    if not entries:
        return None
    return min(e["mean_ms"] for e in entries)


best = {c: best_mean(by_class.get(c) or []) for c in ("cpu", "gpu", "npu")}
comparisons = []

ort_cpu = [p for p in measured if p.get("framework") == "onnxruntime" and p.get("device_class") == "cpu"]
ort_npu = [p for p in measured if p.get("framework") == "onnxruntime" and p.get("device_class") == "npu"]
if ort_cpu and ort_npu:
    cpu_ms = best_mean(ort_cpu)
    npu_ms = best_mean(ort_npu)
    if cpu_ms and npu_ms and npu_ms > 0:
        comparisons.append(
            {
                "workload": "onnx_matmul_add_1x64",
                "baseline": "cpu",
                "candidate": "npu",
                "baseline_mean_ms": cpu_ms,
                "candidate_mean_ms": npu_ms,
                "speedup_vs_baseline": round(cpu_ms / npu_ms, 4),
                "note": "speedup > 1 means NPU faster than CPU on this microbenchmark",
            }
        )

torch_cpu = [p for p in measured if p.get("framework") == "pytorch" and p.get("device_class") == "cpu"]
torch_gpu = [p for p in measured if p.get("framework") == "pytorch" and p.get("device_class") == "gpu"]
if torch_cpu and torch_gpu:
    cpu_ms = best_mean(torch_cpu)
    gpu_ms = best_mean(torch_gpu)
    if cpu_ms and gpu_ms and gpu_ms > 0:
        comparisons.append(
            {
                "workload": f"torch_matmul_{torch_size}x{torch_size}",
                "baseline": "cpu",
                "candidate": "gpu",
                "baseline_mean_ms": cpu_ms,
                "candidate_mean_ms": gpu_ms,
                "speedup_vs_baseline": round(cpu_ms / gpu_ms, 4),
                "note": "speedup > 1 means GPU faster than CPU on this microbenchmark",
            }
        )

if len(classes_present) >= 2:
    comparisons.append(
        {
            "workload": "best_mean_per_class_mixed_frameworks",
            "baseline": None,
            "candidate": None,
            "baseline_mean_ms": None,
            "candidate_mean_ms": None,
            "speedup_vs_baseline": None,
            "best_mean_ms_by_class": {c: best[c] for c in ("cpu", "gpu", "npu") if best[c] is not None},
            "note": (
                "Means across different frameworks/workloads are not strictly comparable; "
                "use same-workload speedups above for fair ratios."
            ),
        }
    )

if not classes_present:
    status = "WARN"
    diagnostics.append(
        "No CPU/GPU/NPU timings were measured. Ensure PyTorch and/or ONNX Runtime are installed "
        "and re-run stage2-validate."
    )
elif len(classes_present) == 1:
    status = "WARN"
    diagnostics.append(
        f"Only {classes_present[0].upper()} path was measured; comparison is incomplete. "
        "Install missing stacks (PyTorch ROCm for GPU, Ryzen AI/ORT for NPU) when available."
    )
else:
    status = "PASS"

# Surface failed path notes (e.g. HIP invalid device function on wrong gfx target).
for p in paths:
    if p.get("status") == "fail" and p.get("note"):
        diagnostics.append(
            f"{(p.get('device_class') or 'path').upper()} path failed "
            f"({p.get('framework')}/{p.get('requested_device')}): {p['note']}"
        )

if "gpu" not in classes_present:
    gpu_failed = any(p.get("device_class") == "gpu" and p.get("status") == "fail" for p in paths)
    if gpu_failed:
        diagnostics.append(
            "GPU path failed at runtime (device visible but kernel/exec error). "
            "Often a ROCm/gfx architecture mismatch for Radeon 890M (gfx1150); "
            "reinstall matching PyTorch ROCm wheels via scripts/100-install-pytorch-rocm.sh."
        )
    else:
        diagnostics.append(
            "GPU path missing or skipped: install/validate PyTorch ROCm "
            "(scripts/100-install-pytorch-rocm.sh) and confirm torch.cuda.is_available()."
        )
if "npu" not in classes_present:
    npu_failed = [
        p
        for p in paths
        if p.get("device_class") == "npu" and p.get("status") in ("fail", "warn")
    ]
    if npu_failed:
        notes = "; ".join(
            (p.get("note") or f"{p.get('requested_device')}: not verified")[:200]
            for p in npu_failed[:2]
        )
        diagnostics.append(
            "NPU path not counted: provider may be visible but ORT profiling did not show "
            f"kernels on the AMD EP ({notes}). Session listing alone is insufficient; "
            "see docs/npu-status.md (EP execution verification)."
        )
    else:
        diagnostics.append(
            "NPU path missing: run stage2-npu with --accept-amd-acceleration-risk, ensure "
            "VitisAIExecutionProvider is visible, and prepare XRT env (see docs/npu-status.md)."
        )
if "cpu" not in classes_present:
    diagnostics.append(
        "CPU path missing: unexpected; check Python venvs under .ai370-ai/ and package imports."
    )

# Deduplicate diagnostics
seen = set()
unique_diag = []
for d in diagnostics:
    if d not in seen:
        seen.add(d)
        unique_diag.append(d)
diagnostics = unique_diag

data = {
    "tier": 2,
    "stage": 3,
    "milestone": "S3-M6",
    "phase": "compare-cpu-gpu-npu",
    "status": status,
    "timestamp": datetime.datetime.now(datetime.UTC).isoformat().replace("+00:00", "Z"),
    "profile": profile,
    "mode": mode,
    "persistence": persistence,
    "offline": offline,
    "interpreters": {
        "onnxruntime_python": ort_python,
        "onnxruntime_venv_source": npu_source,
        "pytorch_python": torch_python,
    },
    "knobs": {
        "ort_warmup": ort_warmup,
        "ort_runs": ort_runs,
        "torch_size": torch_size,
        "torch_iters": torch_iters,
    },
    "paths": paths,
    "device_classes_measured": classes_present,
    "best_mean_ms_by_class": {c: best[c] for c in ("cpu", "gpu", "npu")},
    "comparisons": comparisons,
    "prior_reports": prior_reports,
    "diagnostics": diagnostics,
}
json_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

lines = [
    "# CPU / GPU / NPU Comparison (S3-M6)",
    "",
    f"Profile: {profile} | Mode: {mode} | Offline: {offline}",
    "",
    f"**Status:** {status}",
    "",
    f"- ONNX Runtime Python: `{ort_python or 'none'}` ({npu_source})",
    f"- PyTorch Python: `{torch_python or 'none'}`",
    f"- Device classes measured: {', '.join(classes_present) if classes_present else 'none'}",
    "",
    "## Path timings",
    "",
]
if paths:
    lines.extend(
        [
            "| Framework | Workload | Class | Device | Mean ms | Median ms | Status |",
            "| --- | --- | --- | --- | ---: | ---: | --- |",
        ]
    )
    for p in paths:
        mean = p.get("mean_ms")
        med = p.get("median_ms")
        mean_s = f"{mean:.4f}" if isinstance(mean, (int, float)) else "—"
        med_s = f"{med:.4f}" if isinstance(med, (int, float)) else "—"
        lines.append(
            f"| {p.get('framework', '')} | {p.get('workload', '')} | {p.get('device_class', '')} | "
            f"{p.get('actual_device') or p.get('requested_device') or '—'} | {mean_s} | {med_s} | {p.get('status', '')} |"
        )
    lines.append("")
else:
    lines.append("No path timings recorded.")
    lines.append("")

if comparisons:
    lines.extend(["## Comparisons", ""])
    for c in comparisons:
        if c.get("speedup_vs_baseline") is not None:
            lines.append(
                f"- **{c['workload']}**: {c['candidate']} vs {c['baseline']} — "
                f"speedup **{c['speedup_vs_baseline']}×** "
                f"({c['candidate_mean_ms']:.4f} ms vs {c['baseline_mean_ms']:.4f} ms baseline)"
            )
            if c.get("note"):
                lines.append(f"  - {c['note']}")
        elif c.get("best_mean_ms_by_class"):
            lines.append(f"- Mixed-framework best means: `{c['best_mean_ms_by_class']}`")
            if c.get("note"):
                lines.append(f"  - {c['note']}")
    lines.append("")

if prior_reports:
    lines.extend(["## Related prior reports", ""])
    if "npu_benchmark" in prior_reports:
        lines.append(f"- `npu-benchmark.json` status: {prior_reports['npu_benchmark'].get('status')}")
    if "llm_runtime_benchmark" in prior_reports:
        m = prior_reports["llm_runtime_benchmark"].get("metrics") or {}
        tps = m.get("tokens_per_sec")
        lines.append(
            f"- `tier2-runtime-benchmark.json` status: {prior_reports['llm_runtime_benchmark'].get('status')}"
            + (f", tokens/s={tps}" if tps is not None else "")
        )
    lines.append("")

if diagnostics:
    lines.extend(["## Diagnostics", ""])
    lines.extend(f"- {d}" for d in diagnostics)
    lines.append("")

lines.extend(
    [
        "## How to re-run",
        "",
        "```bash",
        "./scripts/245-compare-cpu-gpu-npu.sh",
        "./ai370-optimize.sh stage2-validate",
        "```",
        "",
    ]
)
md_path.write_text("\n".join(lines), encoding="utf-8")
print(f"status={status}")
print(f"classes={','.join(classes_present) if classes_present else 'none'}")
PY

  echo "[INFO] Wrote $OUT_JSON"
  echo "[INFO] Wrote $OUT_MD"

  local status="WARN"
  if [[ -f "$OUT_JSON" ]]; then
    status="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status","WARN"))' "$OUT_JSON" 2>/dev/null || echo WARN)"
  fi
  echo "[INFO] Comparison status: $status"
  if [[ "$status" == "FAIL" ]]; then
    exit 1
  fi
}

main "$@"
