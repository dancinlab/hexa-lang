@V := "tape" :: spec [active]
  version = "1.2"

@I := "fusion-autoregressive-complete-discovery" :: identity [active]
  brief = "Discovery log -- COMPLETE fused 2-mega-kernel autoregressive decode vs FAIR eager 18-launch stack (GPU §10 axis-E, launch-bound regime)."
  flow  = "discovery -> CLAIMS.tape -> hexa verify (g5) -> .verdicts/ -> paper_on_discovery (NOT triggered, 🟠)"

# ───────────────────────────────────────────────────────────────────────
# F-FUSION-AUTOREGRESSIVE-COMPLETE -- GPU Round 12. LAUNCH-BOUND decode axis.
# Pivot from R11 attention-GEMM near-ceiling (TERMINAL closed-negative) to the
# fusable launch-overhead axis (R6 elementwise moat: 73-76% above eager).
# 🟠 SUB-THRESHOLD: numeric PASS + complete + fair baseline + measured wall,
# but launch-saving realized (+3..+11%) is below the 30% gate.

@C disc_fusion_autoregressive_complete := "fused decode wins the launch-bound regime but below the 30% gate" :: discovery [slug=fusion-autoregressive-complete group=GPU]
  id           = "F-FUSION-AUTOREGRESSIVE-COMPLETE"
  seed         = "COMPLETE fused 2-mega-kernel single-token decode (RMSNorm+QKV-GEMV+KV-append+masked flash-attn+O-proj+RMSNorm+SwiGLU, ~2 launches/layer, multi-CTA cooperative grid, keys parallelized) beats FAIR eager 18-launch decode by >=30% wall in launch-bound regime (small KV-cache L)"
  date         = "2026-05-26"
  host         = "ubu-2 RTX 5070 sm_120 driver 580.159.03 · CUDA 12.0 ptxas · GPU uncontended"
  verdict_tier = "🟠 SUB-THRESHOLD launch-bound win (numeric PASS + complete + fair baseline + measured wall, <30%)"
  target       = "§10 axis-E autoregressive-decode closure row (launch-bound fusable axis)"
  finding      = "fused 2-kernel decode wins the LAUNCH-BOUND regime: +6.4% (L=64), +3.4% (L=256), +10.8% (L=512), +11.1% (L=1024); crossover to LOSS at L~1536 (-18.9%), L=2048 (-22.5%), L=4096 (-4.4%). The launch-overhead fusion moat is REAL for decode but the realized saving never reaches 30%."
  ruled_out    = "fused decode does NOT clear the 30% gate at any L. Net theoretical launch saving = (18-2)x1.81us launch - 10x0.85us grid.sync = ~20.4 us/layer; realized @ L=1024 = ~8.2 us (40% of net). What swamped it: (a) flash-merge serial over KW key-partials per head; (b) 10 grid.sync barriers serialize phases, defeating the cross-kernel latency-hiding the GPU gives independent eager launches; (c) one global cooperative-grid config can't retune occupancy per phase like 18 independent eager grids."
  numeric      = "fused vs f64 CPU autoregressive ref: per-row rel-err <= 3.2e-05 ALL L, nan_inf=0 ALL L -> PASS (FIRST GATE). eager rel-err <= 1.6e-05, nan_inf=0 (ref correct)."
  fairness     = "STRAWMAN CAUGHT (R11 lesson): first eager attn_av (CTA/head, HD=64 thr, serial-over-L) = 0.076ms@L4096 dominated the layer and FAKED a 47% fused win. Rewrote key-parallel (split L across KB blocks + flash-merge) = 0.0069ms@L4096 (10x). FAIR 18-launch eager is the baseline; all sub-kernels coalesced/parallel."
  ptxas        = "pure-ASCII; ptxas sm_80 rc=0, sm_90 rc=0, driver-JIT sm_120 rc=0. attn 45 reg/1024B smem/0 spill; ffn 37 reg/1024B smem/0 spill."
  crossover_L  = "~1536 (launch-bound L<=1024 fusion wins; attention compute/memory-bound L>=1536 eager wins)"
  best_win     = "+11.1% @ L=1024 (best launch-bound win; below 30% gate)"
  verdict_ptr  = ".verdicts/fusion-autoregressive-complete/F-FUSION-AUTOREGRESSIVE-COMPLETE.txt"
  artifact     = "archive/fires/fusion_autoregressive_complete_2026_05_26/ (decode_fused.ptx + decode_fused_kernels.cu + decode_fused_host.cu + decode_eager_baseline.cu + fire.log + result.json)"
  section10    = "axis-E decode row stays [ ] (sub-threshold; honest record appended). paper NOT triggered (🟠, @D paper_gate requires 🟢)."
  next_claim   = "Can the fused body close the ~12 us gap to net-theoretical? Levers: (1) collapse the 2 mega-kernels' RMSNorm grid.sync (precompute inv-rms with a cheap pre-pass), (2) parallel flash-merge (warp-reduce KW partials instead of serial), (3) per-phase occupancy via cluster-launch (sm_90) instead of one global grid -- or accept decode as a SUB-THRESHOLD launch-bound win and move to multi-layer whole-model fusion where the per-layer launch saving compounds x N_layers."
