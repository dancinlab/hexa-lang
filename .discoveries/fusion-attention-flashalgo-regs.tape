@X fusion_attn_flashalgo_regs := "register-resident S/P + warp-shuffle softmax FALSIFIED: the shuffle-based row reduction REGRESSES the fused attention wall vs R8's reg-O (1.29-1.56x slower) because the cross-lane shfl_xor dependency chain stalls the small-tile per-tile critical path. Surfaced a reg-S + smem-scratch-reduce variant that BEATS R8 by 13.2% at N=4096 (still 1.42x cuBLAS, 🟠)" :: discovery [slug=fusion-attention-flashalgo-regs group=GPU]
  seed         = "F-FUSION-ATTN-FLASHALGO-REGS -- eliminate R8's residual S/P smem round-trip via register-resident S, warp-shuffle softmax (shfl_sync rowmax+rowsum), and mma-from-regs P.V, and measure it beating the cuBLAS-batched-GEMM+softmax+batched-GEMM stack on at least one (N,d) shape"
  date         = "2026-05-25"
  host         = "ubu-2 RTX 5070 sm_120 driver 580 (48 SMs, uncontended)"
  verdict_tier_target = "GREEN above-cuBLAS-stack OR ORANGE quantified-partial (measured)"
  verdict_tier_reached = "RED FALSIFIED (warp-shuffle design) + ORANGE (surfaced smem-reduce variant)"

  finding_1    = "REPACK NEEDS NO SHUFFLE: on sm_120 the m16n16k16 f32 accumulator per-lane (elem->(row,col)) map is IDENTICAL to the f16 matrix_a map (matrix_a duplicates elems 0..7 into 8..15). The acc->operand repack is a LOCAL register move pa.x[i]=pa.x[i+8]=acc.x[i]. Proven bit-exact (max|O_reg-O_smem|=0) by frag_repack_partc.cu"
  finding_2    = "the warp-shuffle SOFTMAX (not the repack) is the regression cause. Controlled A/B: held reg-S+reg-P-repack constant, swapped only the row-reduce -- shfl_xor (6-deep cross-lane chain) is ~1.5x SLOWER than a 16-float smem-scratch reduce at every shape. The shfl chain stalls the per-tile critical path between QK^T mma and P.V mma on the small 16x16 tile"
  finding_3    = "shfl-regS REGRESSES vs R8 reg-O: 1.51/1.55/1.56/1.29x slower at N=512/1024/2048/4096 (2.1-3.1x slower than cuBLAS). The pre-registered win condition (fused_ms<cublas_stack_ms) is NOT met on any shape -> FALSIFIED"
  finding_4    = "SURFACED winner: reg-S + reg-P-repack + smem-SCRATCH reduce (NOT full S/P round-trip, NOT shuffles) ties R8 at N<=2048 and BEATS R8 by 13.2% at N=4096 (0.2645 vs 0.3045 ms, ratio 0.868, reproducible to 0.1% over 3 reps). The reg-S/reg-P moat helps at large N but only when the reduction stays cheap"
  finding_5    = "numeric rel_rowscale IDENTICAL to R8 at all 4 shapes -> register path is bit-equivalent; ptxas-clean 0-spill on sm_80/90/120; occupancy 28 (shfl)/25 (smem-reduce) CTAs/SM both exceed R8's 24 -> occupancy is NOT the binding constraint"

  binding      = "at d=64 / 16x16 wmma tile the attention kernel is LATENCY/DEPENDENCY bound, not bandwidth bound. Warp-shuffle reductions lose to smem scratch because their cross-lane sync chain is on the critical path and cannot be hidden by the small single-warp wmma pipeline"
  win          = "NO -- shfl-regS 2.1-3.1x slower than cuBLAS AND slower than R8; even the surfaced smem-reduce variant is 1.42-2.08x cuBLAS. GEMM-fusion (axis-A) attention axis still NOT-above-cuBLAS at d=64. Section 10 box UNCHANGED"

  next_cycle   = "(a) larger Q tile BM=32/64 + 2-4 warps to give the wmma pipeline enough in-flight work to hide the row reduction; (b) cp.async double-buffer of K/V to overlap next-tile load with current P.V; (c) the smem-reduce-reg-S variant (beats R8 at N=4096) pushed to BM=64 multi-warp to break the small-N occupancy floor. Do NOT retry a warp-shuffle softmax at 16x16 -- this round closed-negatives that lever"

  artifacts    = "archive/fires/fusion_attn_flashalgo_regs_2026_05_25/ : frag_repack_probe.cu + frag_repack_partc.cu (repack probe, bit-exact PASS), fa_regS_v1_oracle.cu (the warp-shuffle design, RED falsified), fa_regS_noshfl_diag.cu (the smem-reduce variant, surfaced ORANGE), result.json (full matrix)"
  verdict      = ".verdicts/fusion-attention-flashalgo-regs/F-FUSION-ATTN-FLASHALGO-REGS.txt"
