@X fusion_attn_multicta := "multi-CTA wide-KV fused flash-attention closes the round-3 wall gap ~3-8x but does not beat cuBLAS-TC" :: discovery [slug=fusion-attention-multicta group=GPU]
  seed         = "F-FUSION-ATTN-MULTICTA-WALL -- one CTA per query block, online softmax, S in shared never to HBM, wmma inner GEMMs, re-time vs cuBLAS-TC"
  date         = "2026-05-25"
  host         = "ubu-2 RTX 5070 sm_120 driver 580 (48 SMs)"
  verdict_tier_target = "ORANGE quantified-partial (measured)"

  finding_1    = "round-3 numeric FAIL was a METRIC ARTIFACT not a kernel bug -- naive |err|/(|want|+1e-6) blows up on near-zero attention outputs; honest per-row-scaled + RMS metric shows the round-3 algorithm is already CORRECT (rel_rowscale 5e-4)"
  finding_2    = "round-3 was ALSO already multi-CTA (grid=N/16); the deficit was 1-warp/CTA per-16-key softmax overhead, not a single CTA"
  finding_3    = "the lever that closes the gap = WIDEN KV tile BK=16->BK=256 (16 wmma subtiles/softmax round) -> amortizes softmax+rescale 16x -> 9-15x -> ~2x (CUDA-C) / 3.4-5x (hand-PTX)"
  finding_4    = "multi-warp-per-CTA is SLOWER (cuts grid count + raises smem/CTA); 1-warp/CTA max-grid wins (MEASURED)"
  finding_5    = "register-resident-O accumulator FAILED numeric (wrong m16n16k16 fp32 C-frag row map) -- the classic WMMA fragment-layout trap; reverted to the shared round-trip"

  binding      = "at d=64 the per-16x16-tile online-softmax overhead -- NOT S-HBM traffic -- is the wall; cuBLAS amortizes GEMMs over huge tiles the tiny 16x16 WMMA fused path cannot match"
  win          = "NO -- fused 1.3-5.0x slower than cuBLAS-TC; GEMM-fusion axis remains NOT-won; sec10 box stays [x] via launch-amort only"

  next_cycle   = "(a) hexa-codegen path with VECTORIZED smem loads (ld.shared.v4) + unrolled softmax to approach the 1.3-2.0x CUDA-C floor -- still likely not a win; (b) larger head dim d=128/256 where GEMM arithmetic intensity rises and fusion's HBM-saving may matter; (c) accept the GEMM-fusion axis as a clean ORANGE and pursue a different sec10 moat axis (e.g. fused MLP epilogue chains)"

  artifacts    = "archive/fires/fusion_attention_multicta_2026_05_25/ : flash_attn_wmma_mcta.ptx (shipped), flash_attn_wmma_mcta.sm80.ptx, fa_wmma_host.c, fa_cublas_tc_baseline.c, fa_bk_oracle.cu (geometry oracle), fa_multiwarp_oracle.cu, fa_combo_oracle.cu, fa_regO_oracle.cu, fa_wmma_oracle.cu, fire.log, result.json"
  verdict      = ".verdicts/fusion-attention-multicta/F-FUSION-ATTN-MULTICTA-WALL.txt"
