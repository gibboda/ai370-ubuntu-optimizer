# XRT / Ryzen AI Install Status

Status: PASS
Profile: ai370 | Mode: safe | Offline: false
Risk accepted: false
Install action: skipped-no-risk-ack

## Runtime

- XRT tools: available
- Ryzen AI install: available
- Kernel module: loaded
- Device node: present

## XRT deb selection

- Mode: auto
- Host Ubuntu: 26.04
- Version preference source: auto
- Version preference: 26.04, 24.04
- Match source: ubuntu-24.04
- Matched package Ubuntu tag: 24.04

## Artifacts

- Root: `/home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/.ai370-ai/amd-artifacts`
- Staged XRT debs: 4
  - `/home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/.ai370-ai/amd-artifacts/xrt_202610.2.21.75_24.04-amd64-base.deb`
  - `/home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/.ai370-ai/amd-artifacts/xrt_202610.2.21.75_24.04-amd64-base-dev.deb`
  - `/home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/.ai370-ai/amd-artifacts/xrt_202610.2.21.75_24.04-amd64-npu.deb`
  - `/home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/.ai370-ai/amd-artifacts/xrt_plugin.2.21.260102.53.release_24.04-amd64-amdxdna.deb`
- Ryzen AI archive: `/home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/.ai370-ai/amd-artifacts/ryzen_ai-1.7.1.tgz`

## Next steps

- Stage XRT/NPU `.deb` files under the artifact root. Auto mode prefers the host Ubuntu version, then the previous LTS, then tags discovered in staged filenames (resolved order: 26.04, 24.04).
- Optionally pin with `XRT_UBUNTU_VERSIONS`, set `XRT_DEB_GLOBS` as a last-resort override, or use `XRT_DEB_GLOBS_MODE=override` for custom globs only.
- Optionally stage `ryzen_ai-*.tgz` for the Ryzen AI software installer.
- Re-run with `--accept-amd-acceleration-risk` to install staged packages:
  `./ai370-optimize.sh stage2-npu --accept-amd-acceleration-risk`
- Source `/home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/reports/latest/xrt-ryzen-ai-env.sh` after install for XRT PATH setup.
- Continue with `scripts/210-check-ryzen-ai-software.sh` and `scripts/230-benchmark-npu.sh`.

## Detail

XRT tools already available. Risk not accepted so no package install was attempted. Staged debs: 4.
