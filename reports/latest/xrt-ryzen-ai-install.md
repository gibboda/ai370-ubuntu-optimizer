# XRT / Ryzen AI Install Status

Status: PASS
Profile: ai370 | Mode: safe | Offline: false
Risk accepted: true
Install action: installed-or-validated

## Runtime

- XRT tools: available
- Ryzen AI install: available
- Kernel module: loaded
- Device node: present

## Artifacts

- Root: `/home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/.ai370-ai/amd-artifacts`
- Staged XRT debs: 0
- Ryzen AI archive: `none`

## Next steps

- Stage Ubuntu 26.04 XRT/NPU `.deb` files under the artifact root (see `configs/amd-acceleration.env`).
- Optionally stage `ryzen_ai-*.tgz` for the Ryzen AI software installer.
- Re-run with `--accept-amd-acceleration-risk` to install staged packages:
  `./ai370-optimize.sh stage2-npu --accept-amd-acceleration-risk`
- Source `/home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/reports/latest/xrt-ryzen-ai-env.sh` after install for XRT PATH setup.
- Continue with `scripts/210-check-ryzen-ai-software.sh` and `scripts/230-benchmark-npu.sh`.

## Detail

XRT and/or Ryzen AI stack installed or already available after risk-accepted install path.
