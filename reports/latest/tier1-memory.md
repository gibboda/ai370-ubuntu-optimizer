# Tier 1 Memory Report

- Total memory: 28Gi
- zram0 active: inactive
inactive
- Current swap:
/swap.img file 8G 1.2G -1

Recommendations (runtime-only):
- Consider enabling zram for better interactive behavior on 32/64 GB LPDDR5X systems.
- Review swappiness if using heavy local LLM inference.
