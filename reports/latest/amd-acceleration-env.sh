#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Generated after Ryzen AI / XRT install

export PATH="/home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/.ai370-ai/tools/bin:$PATH"
if [[ -d /opt/rocm/bin ]]; then
  export PATH="/opt/rocm/bin:$PATH"
fi
if [[ -d /opt/rocm/lib ]]; then
  export LD_LIBRARY_PATH="/opt/rocm/lib:${LD_LIBRARY_PATH:-}"
fi
if [[ -f /opt/xilinx/xrt/setup.sh ]]; then
  # shellcheck source=/dev/null
  source /opt/xilinx/xrt/setup.sh
fi
export LD_LIBRARY_PATH="/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
export RYZEN_AI_INSTALLATION_PATH="/home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/.ai370-ai/ryzen-ai/venv"