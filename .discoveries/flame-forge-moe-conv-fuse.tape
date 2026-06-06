@discovery := "fused multi-expert Conv1d MoE kernel — f5e18a0f conv-under-fill cure" :: hexa-fusion

  id           = "flame-forge-moe-conv-fuse"
  seed         = "handoff f5e18a0f (anima H200): CLMConvMoE MoE = ModuleList of E=30 ConvExpert
                  nn.Conv1d(d=6208,d,K=3) → 30 small launches UNDER-FILL the SM scheduler (~74s/step);
                  grouped-conv groups=30 → 11x slower (cuDNN naive fallback). Neither fills the GPU."
  cure         = "one own-device-kernel: ALL E experts' Conv1d in ONE saturating launch, tile =
                  (expert, out-channel-block, time-block) — the 3rd option cuDNN can't give."
  verdict_tier = "🟢 GREEN gate PASS + regime-split finding"

  GATE         = "byte-exact: fused/grouped vs ModuleList-30 max|Δ|=0 (device-vs-device);
                  2.98e-7 vs CPU = fp32 FMA contraction (same accum order, NOT a bug)."

  finding      = "L40S 142 SMs, two regimes:
                   UNDER-FILL (d=512, 32 CTAs/separate-launch): FUSED 13.0ms vs ModuleList 34.9ms
                     vs grouped 37.1ms → fused 2.68x faster than ModuleList, 2.85x faster than grouped.
                     = THE CURE (fill where 30-small-convs under-fill).
                   SATURATED (d≥1024, ModuleList already ≥98% util): no fill headroom → fused loses
                     to 30 well-sized launches on the memory roofline (naive per-channel MAC kernel)."
  honest       = "win = FILL/boundary-removal where under-fill exists, NOT raw-conv superiority
                  (cuDNN conv = roofline). grouped is WORST in both regimes (reproduces f5e18a0f)."

  pod          = "vast L40S 39744220 ($0.668/hr), gate+perf+util harvested INLINE, DESTROYED leak-0."
  artifacts    = "tool/gpu_moe_conv_fuse.cu · tool/gpu_moe_conv_fuse_run.sh ·
                  .verdicts/hexa-fusion/F-FUSION-MOE-CONV-FUSE.txt"

  next         = "(1) tiled-shared-memory / im2col-GEMM per-CTA kernel to win the SATURATED regime on
                  the memory roofline (kernel-quality axis, separate from the fill thesis);
                  (2) re-measure the d=6208 under-fill crossover on an actual H100/H200 (the f5e18a0f
                  shape) — expected in/near under-fill regime on big-SM GPUs but not measured here."
  chain        = "f5e18a0f"
