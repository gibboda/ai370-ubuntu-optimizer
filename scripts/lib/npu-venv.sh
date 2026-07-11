# SPDX-License-Identifier: GPL-3.0-only
#
# Shared helpers for Stage 2 NPU Python environments.
#
# Two venvs exist by design:
#   .ai370-ai/ryzen-ai/venv  — AMD Ryzen AI install (onnxruntime-vitisai / VitisAI EP)
#   .ai370-ai/venv           — stock CPU ONNX Runtime from scripts/200-install-onnxruntime.sh
#
# NPU EP checks and benchmarks must prefer the Ryzen AI venv when it is usable.
# Do not pip-install stock "onnxruntime" into the Ryzen AI venv; AMD ships
# onnxruntime-vitisai (import name: onnxruntime) and onnxruntime-genai-ryzenai.

# True when a Ryzen AI install root looks complete enough for provider checks.
npu_ryzen_ai_venv_usable() {
  local root="${1:-}"
  local py="${root}/bin/python"
  [[ -n "$root" && -x "$py" ]] || return 1
  if "$py" -c 'import ryzen_ai' >/dev/null 2>&1; then
    return 0
  fi
  # AMD package name is onnxruntime-vitisai; the import module is still onnxruntime.
  if "$py" -c 'import onnxruntime as ort; p=ort.get_available_providers(); assert any("vitis" in x.lower() or "ryzen" in x.lower() for x in p)' >/dev/null 2>&1; then
    return 0
  fi
  if "$py" -c 'import onnxruntime' >/dev/null 2>&1 && \
     compgen -G "${root}/lib/python*/site-packages/onnxruntime" >/dev/null 2>&1; then
    # Prefer this tree when ryzen-ai package is present even without EP yet.
    if compgen -G "${root}/lib/python*/site-packages/ryzen_ai" >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

# Resolve the Python interpreter for NPU / Vitis AI EP checks.
# Prints absolute path to python on stdout. Returns 0 when found.
resolve_npu_python() {
  local project_root="${1:-}"
  local ryzen_root stock_py
  if [[ -z "$project_root" ]]; then
    return 1
  fi
  ryzen_root="${project_root}/.ai370-ai/ryzen-ai/venv"
  stock_py="${project_root}/.ai370-ai/venv/bin/python"

  if npu_ryzen_ai_venv_usable "$ryzen_root"; then
    printf '%s\n' "${ryzen_root}/bin/python"
    return 0
  fi
  if [[ -x "$stock_py" ]]; then
    printf '%s\n' "$stock_py"
    return 0
  fi
  # Partial Ryzen AI tree still preferred over system python for diagnostics.
  if [[ -x "${ryzen_root}/bin/python" ]]; then
    printf '%s\n' "${ryzen_root}/bin/python"
    return 0
  fi
  return 1
}

# Label for reports: which venv path was selected.
npu_python_source_label() {
  local py="${1:-}"
  case "$py" in
    */.ai370-ai/ryzen-ai/venv/bin/python) printf 'ryzen-ai\n' ;;
    */.ai370-ai/venv/bin/python) printf 'stock\n' ;;
    *) printf 'other\n' ;;
  esac
}

# Prepare XRT + Ryzen AI shared-library paths for NPU EP checks/benchmarks.
# Mirrors what AMD patches into ryzen-ai/venv/bin/activate (flexml, ort capi, voe).
# Safe to call multiple times; no-ops when paths are missing.
prepare_npu_runtime_env() {
  local project_root="${1:-}"
  local ryzen_root site_packages

  if [[ -f /opt/xilinx/xrt/setup.sh ]]; then
    # shellcheck source=/dev/null
    source /opt/xilinx/xrt/setup.sh
  fi
  if [[ -d /opt/xilinx/xrt/bin ]]; then
    case ":${PATH}:" in
      *":/opt/xilinx/xrt/bin:"*) ;;
      *) export PATH="/opt/xilinx/xrt/bin:${PATH}" ;;
    esac
  fi

  if [[ -z "$project_root" ]]; then
    return 0
  fi
  ryzen_root="${project_root}/.ai370-ai/ryzen-ai/venv"
  if [[ ! -d "$ryzen_root" ]]; then
    return 0
  fi

  export RYZEN_AI_INSTALLATION_PATH="$ryzen_root"
  site_packages="$(ls -d "${ryzen_root}"/lib/python*/site-packages 2>/dev/null | head -n1 || true)"
  if [[ -z "$site_packages" ]]; then
    return 0
  fi

  local extras=()
  [[ -d "${site_packages}/flexml/flexml_extras/lib" ]] && extras+=("${site_packages}/flexml/flexml_extras/lib")
  [[ -d "${site_packages}/onnxruntime/capi" ]] && extras+=("${site_packages}/onnxruntime/capi")
  [[ -d "${site_packages}/voe/lib" ]] && extras+=("${site_packages}/voe/lib")

  if ((${#extras[@]} > 0)); then
    local joined
    joined="$(IFS=:; echo "${extras[*]}")"
    export LD_LIBRARY_PATH="${joined}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  fi
}
