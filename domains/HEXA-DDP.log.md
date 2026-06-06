# HEXA-DDP — step log (append-only)

## 2026-06-07 — domain init
- Registered the multi-GPU data-parallel (DDP) workstream as a distinct domain (separate from [[HEXA-FUSION]] which is single-GPU util/own-GEMM). 6 milestones DDP-M1..M6 in dependency order.
- Probe finding: flame DDP/all-reduce is docs-only (self/forge/PARADIGM.md·PLAN.md·README — NO collective impl in stdlib/flame); pod rent pattern is num_gpus=1 only. So DDP needs BOTH the hexa-native collective (M1, hardware-free) AND multi-GPU rent infra (M2, hardware wildcard).
- Honest (g5): parallel = throughput, N-GPU speedup always < N× (Amdahl + comm). byte-eq gate (1-GPU == N-GPU) before any speedup. NCCL/cuBLAS = roofline. Single-GPU efficiency already banked by HEXA-FUSION (own-GEMM TF32 PARITY #2870 + conv cure #2868).
- First lever = DDP-M1 (ring-all-reduce hexa-native, 2-rank in-process sim, byte-eq) — buildable NOW with no multi-GPU hardware.
