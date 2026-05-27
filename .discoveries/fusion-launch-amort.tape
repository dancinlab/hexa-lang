@V := "tape" :: spec [active]
  version = "1.2"

@X fusion_launch_amort := "fused 5-op elementwise chain beats per-op stack unconditionally by launch + HBM amortization" :: discovery [active]
  id            = "fusion-launch-amort"
  seed          = "launch-overhead amortization (GPU.md §5f) — fuse a >=5-op elementwise chain into 1 launch vs 5-launch eager baseline"
  date          = "2026-05-25"
  domain        = "GPU"
  falsifier     = "F-FUSION-LAUNCH-AMORT — fused 1-launch >=5-op chain beats 5-launch per-op baseline by >=30% in the launch-bound regime"
  verdict_tier  = "🔵/🟢 SUPPORTED (structural closed-form + numerical projection) — timed wall DEFERRED-to-serial"
  finding       = "fused 1 launch vs 5; HBM 3 vs 11 transfers/elem; pct_faster bounded [72.7%, 80%] for ALL n — the >=30% win is UNCONDITIONAL (not just launch-bound), strongest 80% at small n"
  surprise      = "falsifier predicted a launch-bound-only crossover n*; instead n* is NEGATIVE — the HBM-traffic axis (3 vs 11) carries the >=30% into the bandwidth-bound regime, so the win never drops below 30%"
  oracle        = "archive/fires/gpu_fusion_launch_amort_2026_05_25/oracle.hexa (built native, exit 0)"
  ptxas         = "ptxas -arch=sm_80 -v on ubu-2 CUDA 12.0 — fused rc=0 (11 regs, 0 spill), baseline rc=0 (5 entries, 0 spill)"
  verdict_ptr   = ".verdicts/fusion-launch-amort/fusion_launch_amort.txt"
  next_claim    = "serial timed silicon fire (host_fusion_launch.c) records fused_med_ms / baseline_med_ms / pct_faster on ubu-2 RTX 5070 — confirms projection + flips §10 >=30% box"
