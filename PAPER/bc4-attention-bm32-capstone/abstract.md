# Abstract draft

We present **BC4**, a 12-round closed-form-then-empirical campaign attacking
fused FlashAttention v3 vs cuBLAS-TC 3-launch on a consumer NVIDIA Blackwell
GPU (RTX 5070, sm_120). Round 14 (BM=32, BK=32, register-resident O,
cp.async.cg K/V double-buffer) achieves the campaign's first ratio ≤1.0×:
**0.927× @ N=4096** (7.3% faster than cuBLAS-TC) and **0.909× @ N=1024**
(9.1% faster), with numeric PASS (per-row-scaled rel ≤ 7.14e-4) and 5
CTAs/SM occupancy (target was 3).

Two methodological contributions accompany the capstone: (1) a **cheap-first
oracle pattern** that produced 5 verified instances of multi-cycle campaign
savings, including refuting the round-7 closing-note recommendation
(`BM=32 + register-resident O → 2-4 CTAs/SM`) by quantitative smem accounting
before silicon, and (2) **AI-aware roofline rule** — sub-roofline ratios must
be computed against the *binding* roofline per arithmetic intensity (compute
peak for AI ≥ peak_compute/peak_BW; HBM bandwidth roofline otherwise) —
which retired a phantom 5-10× wedge claim that emerged from misapplying the
FP32 compute peak as a universal reference.

The honest landscape at session end: R14 BM=32 BK=32 = (BM, BK) local
optimum (PR #1742 alt wedges A/B falsified); wgmma hardware-blocked on
Blackwell (PR #1744, Hopper-only); TMA on V cited-deferred (round-7
Δ 0.01% + closed-form analysis = secondary lever); Blackwell-native
tcgen05.mma and FP8 e4m3 deferred to discrete future cycles as the
remaining capstone-extension candidates.
