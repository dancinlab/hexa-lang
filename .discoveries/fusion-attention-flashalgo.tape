@X fusion_attn_flashalgo := "FlashAttention-2 register-resident-O closes the round-7 regression and reduces the GEMM-fusion attention wall from 5.3-6.9x to 1.60-1.99x vs cuBLAS-TC at d=64 -- still 🟠 (not above-cuBLAS) but the largest single-round positive movement of the campaign" :: discovery [slug=fusion-attention-flashalgo group=GPU]
  seed         = "F-FUSION-ATTN-FLASHALGO-ABOVE-CUBLAS -- implement the TRUE FA-2 algorithm (online softmax INSIDE fused kernel, S never to HBM, running O REGISTER-RESIDENT, ONE launch) and measure it beating the cuBLAS-batched-GEMM+softmax+batched-GEMM stack on at least one (N,d) shape"
  date         = "2026-05-25"
  host         = "ubu-2 RTX 5070 sm_120 driver 580 (48 SMs)"
  verdict_tier_target = "GREEN above-cuBLAS-stack OR ORANGE quantified-partial (measured)"

  finding_1    = "round-4's failed register-resident-O attempt was a fragment-row-map bug not an algorithm fault -- empirical frag_probe.cu shows m16n16k16 f32 acc elems {0,1,4,5} -> row lane/4, elems {2,3,6,7} -> row lane/4+8 (round-4 used {0..3} -> lo, {4..7} -> hi which is the matrix_a/B convention, NOT the accumulator)"
  finding_2    = "with the correct row map, reg-O is the single largest lever discovered in 8 rounds: 5.3-6.9x -> 1.60-1.99x in ONE change. Smem 28864 B -> 1728 B (16.7x reduction). Occupancy 1 CTA/SM -> 24 CTAs/SM"
  finding_3    = "BK=256 wide-KV (the round-4 lever) becomes COUNTERPRODUCTIVE when combined with reg-O -- because wide-KV's amortization target (the O smem round-trip) no longer exists. Measured: regO+BK16=0.302ms vs regO+BK256=0.779ms at N=4096"
  finding_4    = "remaining 1.60-1.99x gap is the smem S/P round-trip + per-row softmax serial loop, NOT GEMM payload nor HBM S-materialization. cuBLAS still wins at d=64 by amortizing the small GEMM payload over larger TC tiles"
  finding_5    = "BM=32 with 2 warps/CTA is roughly neutral (slightly slower) -- per-row softmax remains 16-lane sequential so warp doubling doesn't speed up the softmax phase"

  binding      = "at d=64 the per-tile softmax + smem S/P round-trip is the residual wall (after reg-O removed the O round-trip). Eliminating it requires register-S + warp-shuffle softmax + mma.x4-from-regs feeding into P.V -- substantial rewrite, deferred"
  win          = "NO -- fused 1.60-1.99x slower than cuBLAS-stack; GEMM-fusion axis still NOT-won. BUT: largest positive gap-closure of the 8-round campaign (4-9x improvement vs round-7's regression)"

  next_cycle   = "(a) register-resident S + warp-shuffle softmax + mma.x4-from-regs P.V (eliminate smem S/P round-trip; the next algorithmic lever) -- expected sub-1.0x; (b) larger d=128/256 where GEMM intensity rises and HBM-saving dominates; (c) accept this axis as fundamentally bounded at d=64 and pursue head-dim-64 only on a different sec10 axis"

  artifacts    = "archive/fires/fusion_attn_flashalgo_2026_05_25/ : fa_regO_v2.sm{80,90,120}.ptx (shipped, pure-ASCII, ptxas-clean), fa_regO_v2_oracle.cu (algorithm), fa_regO_bk256_oracle.cu (slower variant), fa_regO_2warp_oracle.cu (neutral variant), fa_regO_4warp_oracle.cu (reference), frag_probe.cu (the row-map probe), fa_flashalgo_host.c (host driver)"
  verdict      = ".verdicts/fusion-attention-flashalgo/F-FUSION-ATTN-FLASHALGO-ABOVE-CUBLAS.txt"
