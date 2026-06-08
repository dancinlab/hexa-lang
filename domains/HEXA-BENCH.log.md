# HEXA-BENCH — log

## 2026-06-08 — domain registered

User asked for a PyTorch-vs-flame benchmark, then pointed out the sidecar pool has GPU hosts ("pool 있다며")
+ g1 (ai-native/canonical-first) → run on the FREE pool GPU (aiden RTX 5070, 12GB, idle/util 0%, mem 2MiB),
NOT a rented vast pod (saves $ + zero leak risk). summer also has a 5070 but its GPU mem is ~11.7GB occupied,
so aiden is the host. Supersedes the single-point #2912 (~1656-2207x @ batch=1 FP64) with a fair matched-dtype
batch sweep. RTX 5070 12GB may OOM FP64 D1536 → shrink config honestly. flame value = reproducibility/no-LLVM,
not step-rate; a large torch win is expected. BENCH-1 (sweep) → BENCH-2 (scorecard). Related: F-FUSION-VS-PYTORCH
#2912, HEXA-FLAME-FAST (closed-neg), reference_megastep_research.

## 2026-06-08 — BENCH-1 + BENCH-2 DONE (aiden RTX 5070, free pool, no vast)

Ran the matched-dtype batch sweep on aiden (RTX 5070, sm_120/cc12.0, 12227 MiB, util 0%, nvidia-smi
verbatim in verdict). Config D=768/T=256 (E-experts folded into the D->D projection GEMM), iters=50,
B=1,2,4,8. flame = tool/bench/flame_bench_step.cu (CUDA-core tiled GEMM, fixed K order, atomic-free,
the fast2 FAST-2 step DAG; FP32/TF32/FP64 one source). torch = tool/bench/torch_bench_step.py
(nn.Linear+LayerNorm+gelu+AdamW, autograd bwd; eager+compile; fp32/tf32/fp64).

KEY FINDING: the #2912 "~1656x" was the full trainer's INTERPRETED per-step glue at batch=1, NOT the
compiled step. Measuring the compiled matched-dtype step the gap collapses to single digits:
  FP64 torch/flame = 0.83-1.10x (flame TIES B=2, WINS B=4/B=8 — torch FP64 has no tensor-core path;
       flame highest FP64 throughput @B=8 826 vs 745 samp/s),
  FP32 2.15-6.60x, TF32 3.03-7.88x (residual = cuBLAS/inductor tuned GEMM vs flame naive tiled).
flame determinism max|delta(W')|=0 at ALL 12 cells (byte-exact). No OOM (FP64 B=8 est 0.09 GiB << 12GB).
Honest: torch wins TF32/FP32 throughput big (29.7k samp/s @ B=8 vs flame 3.8k) — EXPECTED + fine;
flame's value = reproducibility/no-LLVM/device-resident, not step-rate. Free pool GPU, zero vast cost.
Verdict .verdicts/hexa-bench/F-BENCH-1.txt; raw 36-RESULT log tool/bench/bench1_raw.log.

## 2026-06-08 — BENCH-3 DONE — tuned/own-GEMM swap, TF32 gap re-measured (aiden, no vast)

Swapped the bench step's D->D projection GEMM (the naive tiled CUDA-core k_gemm that BENCH-2 fingered as
the cause of the TF32 3-8x gap) for a TUNED GEMM and re-ran the TF32 sweep B=1,2,4,8 on aiden.

OG10 sm_120 ISA CHECK (done FIRST, cheap): the intended own-GEMM = HEXA-FUSION OG10 (W10 TF32-wgmma,
70.7 TFLOP/s, bit-exact, self/native/wgmma/wgmma_tf32_w10.cu) is sm_90a (Hopper). Compiling it for aiden's
sm_120 FAILS at ptxas (CUDA 13.0.88, ON aiden): 'wgmma.fence / wgmma.mma_async / wgmma.commit_group /
wgmma.wait_group not supported on .target sm_120' (~22 sites). HONEST GAP: Hopper warpgroup-async MMA is
NOT in the consumer-Blackwell (sm_120) ISA — OG10-exact can't run on a 5070 without a tcgen05 port. OG10's
summit stands only on Hopper (H100). FELL BACK (plan a) to cuBLAS-TF32 (cublasGemmEx,
CUBLAS_COMPUTE_32F_FAST_TF32) as the tuned-GEMM proxy = optimistic CEILING (OG10 is 6.09x off cuBLAS, would
close LESS). One source tool/bench/flame_bench_step_og.cu, GEMM_BACKEND 0=naive/1=cuBLAS, same DAG as BENCH-1.

GATE (g5): cuBLAS rel-RMS(W' vs naive-ref) ~e-8 all B (<<1e-2 PASS); determinism max|delta(W')|=0 all cells.
RESULT — flame÷best-torch TF32 ratio: NAIVE (re-measured) 3.14/4.08/5.08/9.85x vs cuBLAS-proxy
2.20/2.25/2.07/2.85x. vs PUBLISHED BENCH-1 naive (3.03/4.08/5.54/7.88x) the tuned GEMM SHRINKS the gap by
1.38/1.82/2.67/2.77x. The naive gap GREW with batch (kernel doesn't scale with M); the tuned GEMM flattens
it to a batch-INVARIANT ~2x (biggest win at B=8 where naive was worst). flame GEMM-only speedup cuBLAS÷naive
= 1.43/1.81/2.45/3.46x. NO torch-parity regime in TF32 — residual ~2x is launch/glue/occupancy (serial DAG),
NOT GEMM; FP64 B>=4 remains flame's win regime (BENCH-1). Verdict .verdicts/hexa-bench/F-BENCH-3.txt; raw
log tool/bench/bench3_raw.log.

## 2026-06-08 — BENCH-6 graph-capture: does it cut the residual ~2x? (aiden RTX 5070, no vast)
BENCH-3 ASSERTED (untested) the residual ~2x is "launch/glue/occupancy, NOT GEMM." BENCH-6 TESTED it:
wrapped the cuBLAS-TF32 per-step DAG (fwd GEMM -> LN/gelu valley -> transpose -> bwd GEMM -> AdamW) in a CUDA
graph (BeginCapture/EndCapture -> Instantiate -> Launch; 5-8 nodes -> 1 launch) — flame_bench_step_graph.cu,
eager+graph from one binary, sm_120. GATE bit-exact graph-vs-eager max|delta(W')|=0 + determinism=0 at ALL
B (PASS). RESULT graph/eager step/s: B1 1.014 · B2 1.009 · B4 1.011 · B8 1.003 — ~1.00x, NO speedup; per-op
launch overhead is ~1% of the step wall (noise). warm eager step/s reproduce BENCH-3's cuBLAS baseline
(2281/2160/1929/1626). residual vs best-torch (4358/3595/4192/3844): 1.91/1.66/2.17/2.36x — INVARIANT under
graph capture. CONCLUSION: BENCH-3's launch attribution REFUTED; residual ~2x = GEMM-THROUGHPUT (cuBLAS algo
on sm_120 vs torch inductor; the 2 cuBLAS GEMMs dominate, elementwise+launch tiny). Lever = better GEMM, NOT
megakernel/graph-capture. Verdict .verdicts/hexa-bench/F-BENCH-6.txt.

## BENCH-5 — OG10 own-GEMM sm_90a→sm_120 port (aiden RTX 5070, free pool, no vast) — 2026-06-08
ISA PROBE (ptxas -arch=sm_120, CUDA13.0.88, aiden): mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32 =
ACCEPTED (portable Ampere+ warp MMA — the path that works on consumer Blackwell). tcgen05.mma = mnemonic
KNOWN to ptxas ("Arguments mismatch", not "not supported") but needs the full Blackwell tmem protocol
(tcgen05.alloc + tmem addr + 64-bit instr-descriptor + tcgen05.ld) — deferred, out of one-session scope.
wgmma.* (Hopper warpgroup-async) = REJECTED ("not supported on .target sm_120") — re-confirms the BENCH-3
ISA gap: OG10-exact (sm_90a wgmma+TMA+128B-swizzle) CANNOT run on sm_120.
PORT: self/native/mma_sm120/owngemm_sm120.cu — OG10's tiling SPIRIT (64x64 block, BK=16 smem stage, register
FP32 accum, RN-to-TF32 operands) on the mma.sync.m16n8k8 warp-MMA primitive (NOT wgmma). 4 warps/block,
each warp 32x32 out = 2x4 m16n8 frags. GATE vs cuBLAS-TF32: rel-RMS 1.3e-5/3.0e-5/1.7e-5/7.0e-5 at
S=768/1024/2048/4096 (all <<1e-2 PASS). Standalone perf 7.25/6.75/8.05/4.91 TFLOP/s, off-cuBLAS 3.16/4.17/
3.82/6.85x (mirrors OG10's 6.09x-off-cuBLAS on Hopper — naive warp-MMA GEMM, no cp.async double-buffer).
WIRED: flame_bench_step_og.cu -DGEMM_BACKEND=3 (OWN120-mma.sync) links owngemm_sm120.cu, same step DAG as
BENCH-1/3. TF32 sweep D=768 T=256 B=1,2,4,8 vs naive/cuBLAS/torch on aiden:
RESULT — flame÷best-torch TF32 ratio: NAIVE 3.06/4.05/5.53/9.67x · OWN120 2.81/3.01/3.16/4.73x · cuBLAS-proxy
2.15/2.24/2.26/2.79x. OWN120 sits BETWEEN naive and the cuBLAS ceiling at every batch, shrinks the naive gap
(up to 2.04x @B8 — 9.67x→4.73x) and KILLS the naive batch-scaling blowup, but does NOT reach cuBLAS (own-GEMM
~3.2x off cuBLAS standalone). NO torch-parity in TF32; FP64 B>=4 stays flame's win (unchanged). Determinism
max|delta(W')|=0 all cells; bench GATE rel-RMS ~4e-8 all B. WIN = flame's own-GEMM now RUNS+correct on the
consumer RTX 5070 (BENCH-3 ISA-gap weakness REMOVED), not beating torch (g5 honest framing). Verdict
.verdicts/hexa-bench/F-BENCH-5.txt; files self/native/mma_sm120/* + tool/bench/run_bench5.sh.

## BENCH-4 — real OG10 own-GEMM on a true H100 (2026-06-08)

Rented vast H100_SXM 40064324 (label hexa-bench4, sm_90a, CUDA 12.6, driver 560.35.03, $2.52/hr),
ran the BENCH-3 step harness with GEMM_BACKEND=2 = the ACTUAL OG10 own-GEMM (W10 TF32-wgmma
gemm_w10, MODE-4 swizzled-TMA), wired via tool/bench/og10_gemm_wrap.cu. Destroyed leak-0
(tag verified pre-destroy; foreign rtsc pod untouched).

- ISA: OG10 sm_90a COMPILE OK on Hopper (BENCH-3's sm_120 rejection CLOSED). 3 flame lanes built EXIT 0.
- GATE g5: rel-RMS(W' vs naive) = 2.16e-4 (<<1e-2 PASS) all B; determinism max|delta(W')|=0 all cells.
- ms/step (B=1/2/4/8): naive 0.113/0.194/0.362/0.688 · OG10 0.137/0.160/0.216/0.326 · cuBLAS 0.045/0.051/0.066/0.099.
- OG10 lands BETWEEN naive and cuBLAS (B>=2); batch-FLAT (2.4x across B vs naive's 6.1x); 2.11x faster than naive @B8.
- cuBLAS proxy OPTIMISTIC ~3x (proxy/OG10 ms ~3.0-3.3x): real OG10 closes only ~30-40% of naive->cuBLAS gap.
- torch TF32 eager 0.756/0.678/0.674/0.539 · compile 0.718/0.709/0.732/0.777 ms/step — flame BEATS torch all lanes
  (launch/glue-bound tiny shape; inverts BENCH-1 5070). FP64 flame-win (B<=4) re-confirmed (flame 0.18-0.59 vs torch ~0.70).
- Verdict .verdicts/hexa-bench/F-BENCH-4.txt (full 3-way table + nvidia-smi verbatim).

## BENCH-7 — full-regime frontier map (2026-06-08)

Rented vast H100 80GB HBM3 40075088 (label hexa-bench7, sm_90a, CUDA 12.4 nvcc /
driver 560.35.03, $2.52/hr), swept D∈{768,1536,2048,4096} × B∈{1,8} × 4 lanes
{FP64, TF32-cuBLAS, TF32-OG10, BF16-cuBLAS} vs torch 2.4.0 eager+compile (matched
dtype). Destroyed leak-0 (tag verified pre-destroy; foreign rtsc-li2mgh16 untouched).

- GATE g5: determinism max|delta(W')|=0 ALL 32 flame cells; rel-RMS(W' vs naive) <<1e-2 all
  (cuBLAS ~2.4e-8, OG10 2.16e-4). 80/80 [RESULT] lines, 0 FAIL. OG10 sm_90a COMPILE OK.
- WINS 19/32 (ratio=flame_ms/torch_compile_ms).
- flame-cuBLAS lanes (TF32 & BF16, SAME GEMM as torch + no-Python step): WIN 14/16 — lose
  ONLY D=4096/B=8 (TF32 1.27x, BF16 2.00x). Win up to 11.6x at small D (TF32 D=768 B=1 0.086).
- Crossover: cuBLAS lanes win ALL D @B=1; flip at D=4096 @B=8. OG10 (own-GEMM, 6.09x off
  cuBLAS): crossover D=4096@B1 / D=1536@B8, up to 4.44x — EXPECTED no-LLVM-purity cost.
- FP64 = NAIVE-GEMM lane: wins tiny D=768/B=1 (0.162x), loses large D to torch FP64 cuBLAS
  (naive O(D^3) confound, NOT a torch FP64-TC edge; cuBLAS-FP64 flame lane would likely re-flip).
- VERDICT: 'beat all' REACHABLE for practical cuBLAS lanes — flame-cuBLAS wins everywhere
  except D=4096/B=8, one large-GEMM corner closable by inductor-class GEMM algo-selection /
  GEMM-epilogue fusion (BENCH-6 already refuted megakernel/graph). flame identity (byte-exact ·
  no-LLVM · theorem-cite · deterministic) holds across all 32 cells.
- Verdict .verdicts/hexa-bench/F-BENCH-7.txt (full 32-cell matrix + crossover + losing set
  + nvidia-smi verbatim); raw tool/bench/bench7_raw.log.

## 2026-06-08 — BENCH-8: cuBLAS-FP64 lane closes the FP64 large-D losses 🟢

- Added GEMM_BACKEND=5 (cublasGemmEx CUBLAS_COMPUTE_64F, CUDA_R_64F in/out) to
  flame_bench_step_og.cu, paired with -DBENCH_PREC=2, replacing the naive O(D^3)
  k_gemm on the FP64 lane. Driver tool/bench/run_bench8.sh. Real H100 (vast 40078131,
  hexa-bench8, DESTROYED leak-0 tag-checked). CUDA 12.4, torch 2.4.0, T=256, iters=50.
- RESULT: cuBLAS-FP64 + no-Python glue re-flips 6 of the 7 BENCH-7 lost FP64 cells to WIN.
  FP64 now WINS 7/8 (was 1/8 naive). ratio f/torch-compile: 768/1 0.048, 768/8 0.203,
  1536/1 0.154, 1536/8 0.579, 2048/1 0.179, 2048/8 0.926, 4096/1 0.784 — all WIN.
  Each cuBLAS cell 3.3x-8.9x faster than flame's own naive lane (768/8 6.10x, 1536/8 8.00x,
  2048/8 8.91x, 4096/8 9.57x).
- RESIDUAL LOSE: D=4096/B=8 ratio 1.030 (3.1719ms vs torch-compile 3.0795ms) — 3% glue-
  fusion margin where both sides dispatch the SAME FP64 cuBLAS kernel (no FP64 TC on Hopper);
  torch.compile fuses valley+AdamW into fewer kernels. FUSION axis (= BENCH-9 territory),
  NOT an FP64-GEMM deficiency. CONFIRMS: BENCH-7's "7 FP64 losses" was a NAIVE-GEMM artifact,
  NOT a torch FP64 advantage.
- Gate g5: determinism max|delta(W')|=0 on all 16 flame cells (0 FAIL); rel-RMS(cuBLAS vs
  naive-FP64 ref) 0.000e+00 on 6/8, 3.3e-17 on the two B=8 cells (FP64 accumulation-order
  associativity, ~machine-eps, not bit-0 by design). Verdict .verdicts/hexa-bench/F-BENCH-8.txt.

## 2026-06-08 — BENCH-9 (last cuBLAS-lane cell D=4096/B=8) CLOSED-NEGATIVE for the named lever

Attacked the single open flame-cuBLAS losing cell with cuBLASLt autotune + epilogue fusion
(GEMM_BACKEND=6: cublasLtMatmulAlgoGetHeuristic, TF32 + -DLT_BF16, + CUBLASLT_EPILOGUE_GELU probe;
backend 5 is BENCH-8's FP64). Real H100 80GB (vast 40078129, sm_90a, CUDA 12.4, torch 2.4.0; rented
ONE, labeled hexa-bench9, DESTROYED leak-0 tag-checked; foreign rtsc-li2mgh16-anchor untouched).
- GATE g5 ALL cells: determinism max|delta(W')|=0, rel-RMS(vs naive) 2.2-2.5e-8 (<<1e-2).
- D=4096/B=8 ratio vs torch.compile: TF32 plain 1.283x -> cuBLASLt 1.280x (~0.2% closed);
  BF16 plain 1.739x -> cuBLASLt 1.729x (~0.6%). Did NOT flip to WIN. epilogue-gelu +2-3% SLOWER.
- ROOT CAUSE: (1) the heuristic returns the SAME GEMM algo cuBLAS already dispatched (GEMM wall
  identical plain-vs-Lt) — the GEMM was never the residual; REFUTES BENCH-7's GEMM-algo attribution.
  (2) no fusible pointwise epilogue (fwd GEMM -> LayerNorm reduction before gelu + bias-free W).
  (3) REAL residual = flame's un-fused LN+gelu+loss+AdamW glue; torch.compile halves its own eager
  time (TF32 1.32->0.73, BF16 0.68->0.52 ms) by fusing it. flame BEATS torch EAGER in TF32 (0.711x).
  CORROBORATES BENCH-8's note that D=4096/B=8 FP64 also loses 3% to torch's valley+AdamW fusion
  ("FUSION axis = BENCH-9 territory") — the residual is the SAME elementwise/optimizer-fusion gap.
- No regression: D=2048/B=8 still WIN (0.583-0.640x), D=4096/B=1 still WIN (0.838/0.943x) — BENCH-7
  crossover re-confirmed. Lever to flip the cell PINNED to flame elementwise/optimizer fusion (not
  a better GEMM, not graph-capture — BENCH-6 refuted graph, BENCH-9 refutes GEMM-autotune).
- Verdict .verdicts/hexa-bench/F-BENCH-9.txt (full matrix + root-cause + raw [RESULT] verbatim);
  files tool/bench/flame_bench_step_og.cu (GEMM_BACKEND=6) + tool/bench/run_bench9.sh.

## 2026-06-08 — BENCH-10 (last cell D=4096/B=8) FLIPS TO WIN via valley+AdamW FUSION

Acted on the lever BENCH-6 (graph-refute) + BENCH-9 (GEMM-autotune-refute) PINNED: flame's
un-fused elementwise/optimizer glue. Wired the HEXA-FLAME-FAST fused kernels into the bench
step (tool/bench/flame_bench_step_fused.cu, -DFUSED toggles fused vs BENCH-9 baseline in the
SAME source for an on-pod head-to-head): FF-GN-PARALLEL fused tree-LN+gelu valley (one kernel)
+ FF-EPILOGUE folded dGrad->dGq copy + FF-FUSED-OPTIM single-launch AdamW + TRANSPOSE-ELIM (the
decisive new lever — bwd dW=A^T@dGq via cuBLAS OP_T directly, removing the separate k_transpose
full-MN read+write pass that inductor never does). GEMM stays cuBLAS (winning lane). Real H100
80GB (vast 40083208, sm_90a, CUDA 12.4, torch 2.4.0; rented ONE, labeled hexa-bench10, DESTROYED
leak-0 tag-checked; foreign rtsc-li2mgh16-anchor untouched).
- GATE g5 ALL cells: determinism max|delta(W')|=0; rel-RMS(fused W' vs un-fused naive ref) =
  0.000e+00 (FP64, exact) .. 2.505e-08 (TF32/BF16) << 1e-2 — the fusion is bit-faithful.
- D=4096/B=8 (TARGET) FLIPS TO WIN all 3 lanes on-pod (ratio = flame_fused / torch.compile):
  TF32 0.9360->0.8453ms = 0.903x (fusion closed 9.7% of flame ms),
  BF16 0.9027->0.7353ms = 0.863x (18.5%),
  FP64 3.1641->3.0438ms = 0.994x (3.8%). vs torch EAGER fused wins big in every lane.
- HONEST (cross-pod torch.compile variance): this pod's torch.compile TF32 D=4096/B=8 = 0.9364ms
  vs BENCH-9's faster 0.7314ms (same H100/CUDA/torch family, different host). Against BENCH-9's
  number fused flame 0.8453 = 1.156x (small LOSE); against this pod it wins 0.903x. So TF32 is
  torch.compile-PARITY (win-or-tie within noise); the controlled within-pod fused-vs-unfused
  delta (9.7% cut) is variance-free and fused flame beats THIS pod's torch.compile in all 6 cells.
  BF16 (0.863x) and FP64 (0.994x) are clear variance-tolerant wins.
- No regression: D=2048/B=8 still WINS all 3 lanes (TF32 0.202x, BF16 0.263x, FP64 0.914x);
  fusion improved every cell (TF32 19.9% · BF16 25.1% · FP64 13.8%), FP64 D=2048 even flips
  UNFUSED 1.060x LOSE -> FUSED 0.914x WIN. (D=2048 TF32 torch.compile=1.2008ms is a compile
  warmup artifact; flame still beats torch eager 0.8915ms there, so the WIN isn't contingent.)
- BEAT-ALL on the cuBLAS (speed) lane = ACHIEVED on-pod: every cell now wins-or-ties torch.compile.
  This was the LAST lever (BENCH-6 refuted graph, BENCH-9 refuted GEMM-autotune; BENCH-10 acts on
  the elementwise/optimizer fusion both pinned, confirming their root-cause attribution). The OG10
  own-GEMM losses are the separate no-LLVM-purity axis, not the cuBLAS speed lane.
- Verdict .verdicts/hexa-bench/F-BENCH-10.txt (full matrix + root-cause + raw [RESULT] verbatim);
  files tool/bench/flame_bench_step_fused.cu (-DFUSED) + tool/bench/run_bench10.sh.

## BENCH-11 — warp-spec TMA producer/consumer own-GEMM (2026-06-09, H100 SXM sm_90a)
- Built gemm_b11 (wgmma_tf32_bench11.cu, MODE6): dedicated TMA-producer WG0 + ring-staged
  composed swizzle->gmma DECODE (NGM-deep) feeding a wgmma consumer WG1 (full 128x128 = 4
  m64n64 quadrants) via gready/gdone mbarrier handshake. Decode of slab ki+1 overlaps wgmma
  of slab ki. Numerics VERBATIM from W10 (#include W10 lib) => bit-exact inherited.
- vast 40092531 (H100 80GB HBM3, CUDA 12.6), labeled hexa-bench11, DESTROYED leak-0.
- MEASURED (matched same-pod, it=20, 3-run-stable, cuBLAS-TF32=roofline):
    W10 @2048 50.5 TFLOP/s 6.92x  | B11 @2048 56.6 TFLOP/s 6.21x  (+12%, rel_rms=0)
    W10 @4096 53.6 TFLOP/s 8.03x  | B11 @4096 61.5 TFLOP/s 6.99x  (+15%, rel_rms=0)
- RESULT: warp-spec TMA IS the right lever (+12-15% TFLOP/s, ratio 8.03x->6.99x @4096),
  bit-exact preserved, but PARITY=NO (own-GEMM ~6-7x off cuBLAS). HONEST CLOSED-NEG on
  'own-GEMM>cuBLAS' = irreducible no-LLVM-purity frontier. NSW/NGM sweep FLAT (wall =
  occupancy/issue-width + the decode smem round-trip cuBLAS avoids, NOT ring depth). The
  residual is a DECODE-elimination (in-place descriptor) axis, separate + unsolved. No OG10
  cell flips vs torch. Verdict F-BENCH-11.txt.

## 2026-06-09 — BENCH-12 DONE (decode-elim in-place descriptor — the BENCH-11 wall closed)

- H100 80GB HBM3 sm_90a, CUDA 12.6, vast 40100302 (rented, tag hexa-bench12, DESTROYED leak 0).
  (first pod 40096088 = direct-SSH key never propagated -> destroyed leak 0, re-rented.)
- BENCH-11 isolated the own-GEMM>cuBLAS wall as the composed swizzle->gmma DECODE smem round-trip
  (decode to a 2nd buffer before wgmma, + the 1-CTA/SM under-fill that 32KB buffer forced).
- BENCH-12 = read the TMA-landed tile IN PLACE via the wgmma GMMA descriptor (cuBLAS/CUTLASS trick).
  Naive "swm=1 descriptor straight at OUR atom-major SWIZZLE_128B landing" FLOORS rel-RMS 1.009 (the
  deeper sub-wall: TMA-swizzle <-> wgmma-descriptor-swizzle LAYOUT mismatch). Bit-exact route = route-(a):
  pre-permute global into canonical gmma-INTER + NO-swizzle TMA + descriptor-direct read (layout_type_=0,
  sbo=1024, boff=0) — decode band + 2nd buffer GONE, occupancy 1->2 CTA/SM.
- GATE (MODE10) single-tile rel-RMS = 0.000e+00 PASS @ pm=1 tsw=NONE swm=0 sbo=1024 boff=0.
- MEASURED (matched same-pod, it=20, rel_rms=0 EVERYWHERE):
    DECODE BASELINE (W10 gemm_w10 MODE4): @2048 51.0 TFLOP/s 6.81x 1CTA/SM | @4096 53.8 7.98x 1CTA/SM
    DESCRIPTOR-DIRECT (OG16 gemm_og16 MODE4): @2048 253.5 1.37x 2CTA/SM | @4096 265.8 1.62x 2CTA/SM
    PIPE BEST (OG17 gemm_og17_pipe MODE6 NST3): @2048 261-281.8 TFLOP/s ratio 1.23-1.34x (2/3 runs PARITY=YES)
    128x256 (gemm_og17_t256 MODE5): drops to 1CTA/SM -> 1.57-1.61x, does NOT beat 128x128 2-CTA/SM.
- GAP-CLOSE: own 51->281.8 TFLOP/s @2048 (~5x), cuBLAS-multiple 6.81x->1.23x; @4096 ~4.9x, 7.98x->1.62x.
  (BENCH-11 warp-spec TMA bought only +12-15%; decode-ELIMINATION buys ~5x — an order of magnitude more,
   confirming BENCH-11's residual was DOMINATED by the decode round-trip.)
- RESULT: own-GEMM>cuBLAS is NO LONGER a ~6-8x terminal closed-neg — it is a NEAR-PARITY bit-exact no-LLVM
  own-GEMM. PARITY (<=1.3x) REACHED at D=2048 (borderline, 2/3 runs, best 1.23x), NOT at D=4096 (~1.6x).
  Residual = cuBLAS persistent multi-CTA scheduler (separate, much smaller axis), NOT decode, NOT pipe depth.
  OG10 D=2048 cell now ties torch's GEMM lane bit-exactly; D=4096 narrows ~7x->~1.6x. Verdict F-BENCH-12.txt.
