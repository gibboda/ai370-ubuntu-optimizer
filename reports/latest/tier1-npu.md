# Tier 1 AMDXDNA / NPU Detection

**Status:** PASS

- AMDXDNA/XDNA present: true
- XRT tools: missing

## Kernel module evidence
amdxdna               172032  0
amd_pmf               131072  1 amdxdna
gpu_sched              69632  2 amdxdna,amdgpu

## Device node evidence
/dev/accel
/dev/accel/accel0

Missing AMDXDNA or XRT is not fatal in Tier 1. Tier 3 performs software enablement and benchmarking.
