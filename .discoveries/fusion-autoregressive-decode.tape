@V := "tape" :: spec [active]
  version = "1.2"

@X fusion_autoregressive_decode := "fused per-token autoregressive decode beats PyTorch eager structurally by launch-count + temp-HBM elimination (axis E, novel)" :: discovery [active]
  id            = "fusion-autoregressive-decode"
  seed          = "axis E (novel) -- autoregressive single-token fusion. Fuse a whole transformer-decoder layer step (LN + 3-GEMV QKV + KV-append + attention + O-proj + LN + FFN-up + SiLU + FFN-down + 2x residual) into 1-2 mega-kernels so the q-vector flows through registers/smem across all ops; never round-trip temps through HBM. At decode batch=1 (post-first-token) the per-op compute is tiny vs the per-launch overhead, so launch-count reduction transfers nearly 1:1 into wall reduction."
  date          = "2026-05-25"
  domain        = "GPU"
  falsifier     = "F-FUSION-AUTOREGRESSIVE-DECODE -- a fused hexa-emitted kernel uses STRUCTURALLY FEWER launches than PyTorch eager's >=17 per-token launches AND projects launch-bound wall reduction >=30%"
  verdict_tier  = "BLUE (structural-formal) -- launch ratio + temp-HBM ratio + closed-form launch-bound projection; timed silicon DEFERRED to round 9"
  finding       = "fused 2 vs eager 17 launches/layer/token (8.5x fewer); temp-HBM 0 vs 112656 B (100% eliminated); projected launch-bound wall reduction 70.6% (>=30% UNCONDITIONAL across launch-bound + compute-saturated regimes)"
  surprise      = "the moat is much larger per-layer than for any other axis-A workload because a transformer-decoder layer has so many separable ops (17+) that PyTorch's eager API forces into separate launches. 12-layer model => fused 24 launches/token vs eager 204 -- launch overhead alone is ~70% of the per-token wall in eager."
  oracle        = "archive/fires/fusion_autoregressive_decode_2026_05_25/oracle.hexa (HEXA_MAC_BUILD_OK=1 hexa build, exit 0)"
  ptxas         = "ptxas 12.0 on ubu-2 -- fused RC=0 sm_80/sm_90 (32+27 regs, 40960+16384 B smem, 0 spill); eager 17 entries RC=0 sm_80/sm_90; sm_120 via driver-JIT (forward-compat per prior fires)"
  verdict_ptr   = ".verdicts/fusion-autoregressive-decode/F-FUSION-AUTOREGRESSIVE-DECODE.txt"
  next_claim    = "round-9 timed silicon fire on ubu-2 RTX 5070: f64 CPU ref + per-row-scaled RMS rel <= 1e-2 numeric + cudaEvent warmup 20 / timed 200 median wall measurement; sweep L in {64,256,512,1024,2048} to map launch-bound -> compute-bound transition; expected wall reduction in [30%, 70%]"

@discovery fusion_autoregressive_timed_r9 := "axis E round-9 timed wall — 🔴 FALSIFIED (closed-negative)" :: gpu-fire [2026-05-26]
  host          = "ubu-2 RTX 5070 sm_120 driver 580.159.03 / CUDA 12.0; nvidia-smi 0% util pre-fire each L"
  numeric       = "🔴 FAIL both fused (max_rel≈1.61) and eager (max_rel≈1.9) vs tol 1e-2 ∀L — decode_attn_fused omits online-softmax (placeholder weight) + un-zeroed smem-atomic RMSNorm; eager k1 placeholder unit-scale + k9 no-norm softmax."
  wall          = "fused FLAT ~80 ms ∀L; eager ~1.89→1.98 ms; fused ~40-42× SLOWER (pct_above_eager -4138%@L=64 → -3957%@L=2048). NO launch-bound win, NO crossover. fused = 1 CTA/768 threads (1/48 GPU, single-SM serial)."
  ruled_out     = "the projected 70.6% launch-bound win. Premise (per-op compute << launch overhead at decode batch=1) FALSIFIED at d=768: per-op GEMVs dominate; single-CTA fused kernel can't use GPU parallelism. Launch-count moat (2 vs 17) does NOT convert."
  crossover     = "NONE — fused monotonically slower across L∈{64,256,512,1024,2048}; the launch-bound→compute-bound transition never crosses 1× (fused stays ~40× above eager)."
  verdict_ptr   = ".verdicts/fusion-autoregressive-decode/F-FUSION-AUTOREGRESSIVE-DECODE-TIMED.txt"
  artifact      = "tool/r9_walls/{ar_host.c, ar_result_L{64,256,512,1024,2048}.json}"
  section10     = "axis-E row stays [ ]/FALSIFIED-on-wall. closure 8/8 unchanged (axis-E is a lane)."
  next_claim    = "axis-E timed win needs real online-softmax in decode_attn_fused + multi-CTA/warp-parallel tiled GEMVs; INBOX upstream: both fused+eager decode PTX on main are structural stubs (attn softmax omitted)."
