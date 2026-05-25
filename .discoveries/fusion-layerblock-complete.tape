@V := "tape" :: spec [active]
  version = "1.2"

@I := "fusion-layerblock-complete-discovery" :: identity [active]
  brief = "Discovery log — R13 COMPLETE fused transformer block (axis C), the last unmeasured axis of the GPU fusion campaign."
  flow  = "discovery -> CLAIMS.tape -> .verdicts/ -> paper_on_discovery (ONLY on 🟢; this is 🟠 -> NO paper)"

# ----------------------------------------------------------------------
# F-FUSION-LAYERBLOCK-COMPLETE -- closes the R8(structural)/R9(stub) gap.
# R9 timed a STUB (empty flash-attn key-loop + naive scalar FFN -> NaN, 588x
# slower). R13 builds the COMPLETE kernel and times it -> near-ceiling.

@C disc_fusion_layerblock_complete := "the COMPLETE fused transformer block (R10 flash-attn + cuBLAS-TC GEMMs + cross-layer LN/residual/SiLU seam fusion) is numerically faithful (max_rel 8e-4, naninf=0) but only +1% above a fair cuBLAS-using eager stack on d=768·12L training-batch — CONFIRMING the campaign empirical law that a GEMM/compute-dominated block is near-ceiling, NOT a >=30% win" :: discovery [slug=fusion-layerblock-complete group=GPU]
  id            = "F-FUSION-LAYERBLOCK-COMPLETE"
  axis          = "C  --  cross-layer transformer-block fusion (LAST unmeasured axis; completes the fusion landscape)"
  seed          = "transformer block { LN -> QKV-proj -> flash-attn -> OUT-proj -> +res1 -> LN2 -> SwiGLU-FFN(up,gate,SiLU,down) -> +res2 } built COMPLETE (R10 multi-warp+cp.async WMMA flash-attn embedded per-head + cuBLAS GemmEx FP16-TC for all 5 GEMMs + fused glue) vs a FAIR per-op eager stack sharing the same cuBLAS GEMMs"
  date          = "2026-05-26"
  host          = "ubu-2 (summer-B650M-K) RTX 5070 sm_120 driver 580 / nvcc-ptxas CUDA 12.9 native sm_120; nvidia-smi 0% util / 5 MiB pre-fire"
  shape         = "d=768 n_heads=12 head_dim=64 S=512 B=8 -> M=B*S=4096 rows; dff=4*d=3072 (training-batch, GEMM-dominated)"
  verdict_tier  = "ORANGE near-ceiling closed-negative (numeric PASS + complete + fair baseline, +1% < 30%)"
  finding       = "NUMERIC PASS (max_rel_rowscale 8.00e-4 @ refRows=64, 8.52e-4 @ 128; max_abs 1.0e-3; naninf=0) — the R9 stub-NaN gap is CLOSED, this is a COMPLETE faithful kernel. WALL: fused 3.795 ms vs eager 3.832 ms = fused/eager 0.990 = +0.94..+1.03% above eager (3 reproducible runs, std <0.1%). gate30 BELOW-30% -> WIN FALSIFIED."
  decomposition = "5x cuBLAS GemmEx = 1.208 ms = 31.8% of fused wall; flash-attn (96 fa_head launches) = 2.425 ms = 63.9%; fused glue (LN/residual/SiLU/gather-scatter) ~0.16 ms = 4.3%. COMPUTE FLOOR (GEMM+attn) = 95.6%. Max possible fusion win is glue-bounded ~4% -> measured ~1%."
  empirical_law = "CONFIRMS the campaign law (fusion >=30% win inversely related to GEMM-throughput-boundedness): axis-A elementwise (no GEMM) 73-76% win; axis-A attention (GEMM-dominated) 1.149x near-ceiling; axis-C full block (GEMM+attn 95.6% of wall) +1% near-ceiling. Law holds across all 3 axes."
  ruled_out     = "axis-C as a >=30% wall win in the GEMM-dominated regime. The R8 structural moat (3 vs 11 launches, 9.667x less activation-HBM at dff=4d) is REAL and unchanged, but the activation-HBM it eliminates is a tiny fraction of a wall that is 95.6% GEMM+attn compute — so it cannot convert to a >=30% wall win. cuBLAS GEMM roofline + R10 flash-attn are untouchable by cross-layer fusion."
  honest_scope  = "(@D g3) the wall is even MORE compute-dominated than a pure-GEMM block because flash-attn adds 63.9%; R10 flash-attn is itself ~1.149x BELOW cuBLAS (F-FUSION-ATTN-MULTIWARP 🟠), so the attention term is hexa's own kernel not a cuBLAS call. Both stacks share the SAME cuBLAS GEMMs (fair roofline, NOT a strawman naive GEMM — R11/R12 lesson) and the SAME flash-attn; only the glue launches differ."
  ptxas         = "pure-ASCII; nvcc/ptxas 12.9 native sm_120 rc=0; fa_head flash-attn 94 regs / 14336 B smem / 0 spills (<< 49152 B cap); all glue kernels 0-spill."
  numeric       = "f64 CPU reference of the FULL block (LN1->QKV->per-head softmax-attn->OUT->+res1->LN2->up/gate->SiLU*gate->down->+res2), per-row-scaled rel + NaN/Inf hard-fail counter, tol 1e-2."
  verdict_ptr   = ".verdicts/fusion-layerblock-complete/F-FUSION-LAYERBLOCK-COMPLETE.txt"
  artifact      = "archive/fires/fusion_layerblock_complete_2026_05_26/ {lb_complete.cu, result.json, fire.log}"
  reuse         = "R10 flash-attn = archive/fires/fusion_attn_multiwarp_2026_05_26/fa_mw_cpasync_oracle.cu (verbatim core, embedded as fa_head); R6 SwiGLU activation = archive/fires/fusion_axisA_breadth_2026_05_25/host_swiglu.c (k_swiglu); cuBLAS GemmEx FP16-TC for the 5 GEMMs (fair roofline)."
  section10     = "axis-C box stays [ ] (NOT flipped to win); the R9 🔴 stub entry is SUPERSEDED by this measured complete-kernel 🟠 near-ceiling. closure 8/8 unchanged."
  paper         = "NO -- /paper triggers only on 🟢 >=30% surprise win; this 🟠 CONFIRMS the honest near-ceiling hypothesis (not a refutation), so no paper per @D paper_significance / paper_gate."
