# HEXA-DDP — step log (append-only)

## 2026-06-07 — domain init
- Registered the multi-GPU data-parallel (DDP) workstream as a distinct domain (separate from [[HEXA-FUSION]] which is single-GPU util/own-GEMM). 6 milestones DDP-M1..M6 in dependency order.
- Probe finding: flame DDP/all-reduce is docs-only (self/forge/PARADIGM.md·PLAN.md·README — NO collective impl in stdlib/flame); pod rent pattern is num_gpus=1 only. So DDP needs BOTH the hexa-native collective (M1, hardware-free) AND multi-GPU rent infra (M2, hardware wildcard).
- Honest (g5): parallel = throughput, N-GPU speedup always < N× (Amdahl + comm). byte-eq gate (1-GPU == N-GPU) before any speedup. NCCL/cuBLAS = roofline. Single-GPU efficiency already banked by HEXA-FUSION (own-GEMM TF32 PARITY #2870 + conv cure #2868).
- First lever = DDP-M1 (ring-all-reduce hexa-native, 2-rank in-process sim, byte-eq) — buildable NOW with no multi-GPU hardware.

## 2026-06-07 — DDP-M1 GREEN (ring-all-reduce hexa-native, hardware-free)
- Built `stdlib/ddp/ring_all_reduce.hexa`: canonical ring all-reduce over N ranks modelled as N rows of one host buffer (rank r at r*S). Phase 1 reduce-scatter (N-1 steps) + Phase 2 all-gather (N-1 steps). Each step materialises a staging buffer so the simultaneous P2P sends of one ring step don't clobber each other intra-step (matches what real transport guarantees). Chunk partition `ring_chunk_start` handles S not a multiple of N (first S%N chunks get +1 element). Transport = in-process array copy (`t_get`/`t_set` host farr) — M3 swaps this copy for cudaMemcpyPeer/NVLink P2P, schedule unchanged.
- Test `stdlib/ddp/ring_all_reduce_test.hexa`: in-process N-rank sim, distinct deterministic seed per (rank,index) so a wrong chunk/offset surfaces as non-zero Δ. Compares every rank's row against a serial elementwise sum.
- **GATE (g5) GREEN**: 9/9 pass. byte-eq max|Δ|=0 FP64 for N∈{2,4} with S NOT a multiple of N (S=7→4,3 · S=10→3,3,2,2 · S=13→4,3,3,3) plus even S=64. Step count `ring_step_count(N)==2(N-1)` asserted (N=2→2, N=4→6, canonical optimum). Verdict verbatim: `.verdicts/hexa-ddp-m1/F-DDP-RING-BYTEEQ.txt`. Built+ran locally (clang -O2 native, exit 0).
- **HONEST (g5) — scope boundary**: M1 proves the COLLECTIVE ALGORITHM is bit-exact vs serial sum. It does NOT mean parallel training runs. Real multi-GPU transport (P2P/NCCL) = DDP-M3; multi-GPU hardware = DDP-M2 (the wildcard). M1 GREEN unblocks M3 (only the transport leg remains to swap in).
- Falsifiers held: F-DDP-RING-BYTEEQ (sim == serial sum, max|Δ|=0) · F-DDP-RING-STEPS (2(N-1)).
