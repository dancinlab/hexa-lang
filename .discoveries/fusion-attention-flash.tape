@V := "tape" :: spec [active]
  version = "1.2"

@I := "fusion-attention-flash-discovery" :: identity [active]
  brief = "Discovery log — fused flash-attention vs cuBLAS-using attention stack (GPU §10 moat)."
  flow  = "discovery → CLAIMS.tape → hexa verify (g5) → .verdicts/ → paper_on_discovery"

# ───────────────────────────────────────────────────────────────────────
# F-FUSION-ATTENTION-FLASH — fused flash-attention structural moat (GPU §10).
# Structural clause PROVEN closed-form (🔵); wall clause FALSIFIED (🔴 ruled-out).

@C disc_fusion_attention_flash := "fused flash-attention structural moat is real; naive-kernel wall is not" :: discovery [slug=fusion-attention-flash group=GPU]
  id           = "F-FUSION-ATTENTION-FLASH"
  seed         = "softmax(Q K^T / sqrt(d)) V in ONE fused kernel, online-softmax tiling (S never to HBM) vs cuBLAS-using baseline (gemmStridedBatchedEx QK^T -> write S -> softmax kernel -> gemmStridedBatchedEx .V)"
  date         = "2026-05-25"
  host         = "ubu-2 RTX 5070 sm_120 driver 580 · CUDA 12.0 ptxas · cuBLAS 12.9 · GPU uncontended"
  verdict_tier = "🔵 SUPPORTED-FORMAL (structural) + 🔴 wall axis ruled-out (g3 closed-negative)"
  target       = "§10 'Whole-program-fusion >=30%' moat box (the single OPEN closure box)"
  finding      = "structural clause PROVEN: 1 launch vs 3, 0 vs O(N^2) S-HBM, total-HBM ratio R(N,d)=1.25+N/d (33.25x @N2048/d64, 65.25x @N4096); hexa-native compiled recompute reproduces R exactly. WALL FALSIFIED: naive scalar fused kernel 1.4-1.5x SLOWER than cuBLAS Tensor-Core baseline at every shape."
  ruled_out    = "structural fusion ALONE does not win wall vs cuBLAS — moat necessary not sufficient; >=30% wall needs fused inner GEMMs at Tensor-Core throughput (wmma over Q/K/V blocks, S in smem)."
  numeric      = "fused vs f64 CPU ref rel-err <= 1e-2 PASS all shapes (max_rel ~1e-6)."
  ptxas        = "pure-ASCII, ptxas sm_80 rc=0, sm_90 rc=0, driver-JIT sm_120 rc=0."
  verdict_ptr  = ".verdicts/fusion-attention-flash/F-FUSION-ATTENTION-FLASH.txt"
  artifact     = "archive/fires/fusion_attention_flash_2026_05_25/ + tool/fusion_attn_{flash_host,cublas_baseline}.c"
  next_claim   = "Tensor-Core fused flash-attention (wmma) — does the structural moat convert to >=30% wall once inner GEMMs run at TC throughput?"
