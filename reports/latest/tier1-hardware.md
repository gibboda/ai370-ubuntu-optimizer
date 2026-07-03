# Tier 1 Hardware Detection

**Profile:** ai370 | **Mode:** safe | **Persistence:** runtime

## System
- Product: Micro Computer (HK) Tech Limited EliteMini Series
- BIOS: 2.01
- OS: Ubuntu 26.04 LTS (26.04 / resolute)
- Kernel: 7.0.0-27-generic

## CPU
- Model: AMD Ryzen AI 9 HX 370 w/ Radeon 890M
- Vendor: AuthenticAMD
- Logical cores: 24

## GPU (iGPU)
- Detected: 65:00.0 Display controller [0380]: Advanced Micro Devices, Inc. [AMD/ATI] Strix [Radeon 880M / 890M] [1002:150e] (rev c1)
	Subsystem: Advanced Micro Devices, Inc. [AMD/ATI] Strix [Radeon 880M / 890M] [1002:150e]
65:00.1 Audio device [0403]: Advanced Micro Devices, Inc. [AMD/ATI] Radeon High Definition Audio Controller [1002:1640]
	Subsystem: Advanced Micro Devices, Inc. [AMD/ATI] Radeon High Definition Audio Controller [1002:1640]
- Architecture: gfx1150
- amdgpu module: loaded (ok)

## NPU (XDNA2)
- Present: true
- Module: amdxdna               172032  0
amd_pmf               131072  1 amdxdna
gpu_sched              69632  2 amdxdna,amdgpu
- Devices: /dev/accel
/dev/accel/accel0

## Memory / Storage
- Memory: 28Gi
- Storage: loop0                     4K loop
loop1                  13.4M loop
loop2                   442M loop
loop3                 425.9M loop
loop4                  13.5M loop
loop5                    74M loop
loop6                  66.8M loop
loop7                  66.8M loop
loop8                  63.8M loop
loop9                  19.6M loop
loop10                   20M loop
loop11                252.7M loop
loop12                606.1M loop
loop13                 16.5M loop
loop14                252.7M loop
loop15                614.5M loop
loop16                 91.7M loop
loop17                  402M loop
loop18                  395M loop
loop19                 18.8M loop
loop20                 18.8M loop
loop21                 49.3M loop
loop22                 15.7M loop
loop23                  580K loop
loop24                  828K loop
nvme0n1 CT1000P3PSSD8 931.5G disk
- NVMe: present

## Missing tools (best-effort detection)
none
