@X fusion_attn_decomp_sweep := "KV-split (flash-decoding) closes the small-N occupancy gap but is a small-N-only lever; no decomposition of hand-PTX flash-attn beats cuBLAS" :: discovery [slug=fusion-attention-decomp-sweep group=GPU]
  seed         = "F-FUSION-ATTN-DECOMP-WALL -- sweep the full parallel-decomposition space of fused flash-attn (Bq x kv_split x BK x N); test whether KV-SPLIT (gridDim.z flash-decoding) closes the small-N occupancy gap (N=512 grid 32 CTAs < 48 SMs)"
  date         = "2026-05-25"
  host         = "ubu-2 RTX 5070 sm_120 driver 580 (48 SMs, 12GB), clean, $0 LOCAL"
  verdict_tier_target = "ORANGE quantified-partial -> closed-negative (measured)"
  round        = "5 of the GPU sec10 GEMM-fusion (attention) axis"

  matrix       = "153 configs swept (N{512,1024,2048,4096} x Bq{16,32,64} x kv_split{1,2,4,8,16} x BK{64,128,256}, d=64) -- ALL numeric PASS (rel_rowscale<=1e-2 vs f64 CPU ref)"
  oracle       = "CUDA-C nvcuda::wmma flash-decoding 2-kernel (partial-O + LSE merge); kv_split=1 reduces EXACTLY to the round-4 algorithm (max_abs 4.02796e-05 identical). 2-pass adds a partial-O HBM round-trip + 2nd-launch tax the round-4 single-kernel avoids; decomposition trend isolated within the consistent 2-pass frame, absolute compare also vs round-4 single-kernel"

  finding_1    = "KV-SPLIT CLOSES the small-N occupancy gap -- the user hypothesis CONFIRMED. N=512 Bq16: occupancy 32->128 CTAs, 0.146->0.058 ms (intra-framework 2.53x), reaching PARITY with the round-4 single-kernel (0.0568 ms) despite the 2-pass tax"
  finding_2    = "KV-split benefit SATURATES at the split K where ctas_partial >= ~48 SMs (N=512 plateaus at kv=4=128 CTAs; kv=8/16 REGRESS via over-subscription + merge cost)"
  finding_3    = "KV-split is a SMALL-N-ONLY lever -- at N>=2048 the grid is already saturated by N/Bq alone, so KV-split adds only the partial-O HBM tax: decomp-best 0.668ms vs round-4 single-kernel 0.245ms @N=2048 (2.7x WORSE). HBM partial cost grows as O(N*split*d)"
  finding_4    = "BK=256 confirmed best within every fixed (N,Bq,kv) (round-4 finding re-confirmed); Bq>16 uniformly SLOWER (cuts grid, opposite of what small-N needs)"
  finding_5    = "softmax-overhead floor re-confirmed -- even at max occupancy the per-16x16-tile online-softmax keeps the fused path ~3.4x above cuBLAS huge-tile GEMM; no decomposition breaches the round-4 binding constraint"

  binding      = "the GEMM-tile-efficiency wall (cuBLAS amortizes GEMMs over huge tiles) is FUNDAMENTAL; KV-split trades occupancy for HBM traffic (net-neutral small-N, net-negative large-N) and does not breach it"
  win          = "NO -- best ratio 3.47x @ N=512 (>30% win requires <=0.70). GEMM-fusion axis remains NOT-won; sec10 box stays [x], NOT flipped"
  optimum      = "per-shape: N512 Bq16/kv4/BK128 3.47x | N1024 Bq32/kv4/BK256 5.88x | N2048 Bq64/kv4/BK256 10.82x | N4096 Bq16/kv8/BK256 13.17x (all vs cuBLAS-TC)"

  next_cycle   = "(a) FUSE the merge into the partial kernel's last z-CTA via a grid-wide atomic LSE merge to kill the 2nd-launch + HBM-partial tax (would make KV-split a pure win at small-N, still likely not >cuBLAS); (b) larger head dim d=128/256 where GEMM arithmetic intensity rises and fusion HBM-saving may finally matter; (c) ACCEPT GEMM-fusion as a clean closed-negative (cuBLAS unbeatable by hand-PTX flash-attn at d=64) and pursue a different sec10 moat axis"

  artifacts    = "archive/fires/fusion_attention_decomp_2026_05_25/ : fa_decomp_oracle.cu (parameterized flash-decoding oracle), sweep_raw.txt (153 configs verbatim); exports/sweep/gpu-attn-decomp-2026-05-25/ : ledger.json, SUMMARY.md"
  verdict      = ".verdicts/fusion-attention-decomp-sweep/F-FUSION-ATTN-DECOMP-WALL.txt"
