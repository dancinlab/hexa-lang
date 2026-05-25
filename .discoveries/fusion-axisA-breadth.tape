@V := "tape" :: spec [active]
  version = "1.2"

@I := "fusion-axisA-breadth-discovery" :: identity [active]
  brief = "Discovery log — whole-program-fusion moat broadened from 1 workload (launch-amort) to the NN elementwise/norm surface: LayerNorm · RMSNorm · Softmax · SwiGLU."
  flow  = "discovery → CLAIMS.tape → compiled f64-ref harness (g5 broken on ubu) → .verdicts/ → paper_on_discovery"

@X fusion_axisA_breadth := "whole-program fusion beats the eager/per-op NN elementwise+norm surface by >=30% wall across 4 workloads (LayerNorm RMSNorm Softmax SwiGLU), generalizing the launch-amort moat from 1 data point to N+1=5" :: discovery [active]
  id            = "fusion-axisA-breadth"
  seed          = "expand the WON §5f launch-overhead / §5a memory-bound fusion axis from ONE workload (launch-amort 5-op chain) to MORE real NN operators — make the moat a robust general result"
  date          = "2026-05-25"
  domain        = "GPU"
  host          = "ubu-2 RTX 5070 sm_120 driver-JIT forward-compat, CUDA 12.0, idle 0%, $0 LOCAL"
  falsifier     = "per workload: a single fused kernel (1 launch) beats the eager per-op stack by >=30% wall on a transformer-shaped tensor. FALSIFIED if any workload < 30%"
  verdict_tier  = "🟢 SUPPORTED-NUMERICAL — 8/8 timed silicon measurements PASS >=30%, 8/8 numeric PASS (per-row RMS rel <= 1.9e-7)"
  method        = "fused 1-kernel vs eager multi-launch; cuLaunchKernel + cuEvent; 20 warmup + 200 median; numeric vs f64 CPU ref (HONEST per-row-scaled RMS rel, tol 1e-2); serial timing"
  finding_ln    = "LayerNorm (eager 4-launch reduce-mean/var+normalize+affine -> fused 1): large 66.2%, small 72.7%; launch 4x, HBM 6->3"
  finding_rms   = "RMSNorm/LLaMA (eager 3-launch reduce-sq+normalize+scale -> fused 1): large 59.5%, small 58.6%; launch 3x, HBM 5->3"
  finding_sm    = "Softmax (eager 4-launch row-max+exp+row-sum+div -> fused 1 online): large 65.9%, small 56.3%; launch 4x, HBM 6->4"
  finding_swi   = "SwiGLU (eager 3-launch sigmoid+mul-gate+mul-up -> fused 1): large 63.0%, small 47.8%; launch 3x, HBM 8->3 (largest traffic cut)"
  surprise      = "the win holds in BOTH launch-bound (small) and bandwidth-bound (large) regimes for all 4 — the HBM-traffic axis carries >=30% into large sizes (mirrors launch-amort's negative crossover n*). honest per-row RMS metric avoided the round-3 attention near-zero false-FAIL on softmax"
  ptxas         = "ptxas -arch=sm_90 -v on ubu-2 CUDA 12.0 — all 8 fused + eager modules rc=0, 0 spill"
  verdict_ptr   = ".verdicts/fusion-axisA-{layernorm,rmsnorm,softmax,swiglu}/<workload>.txt"
  moat_count    = "moat now N+1=5 workloads: these 4 (LayerNorm/RMSNorm/Softmax/SwiGLU) + launch-amort 73-76%"
  next_claim    = "paper fusion-elementwise-moat-breadth (>=3 workloads measured >=30% — clean broad result, 4/4 satisfied) + GPU.md §10 moat-evidence-base note"
