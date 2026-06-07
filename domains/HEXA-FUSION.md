# HEXA-FUSION — current state

@title: 🔥 HEXA-FUSION — whole-program train-step fusion (match PyTorch+CUDA → exceed)

@goal: hexa codegen 이 CLMConvMoE train step 전체(fwd → CE → bwd → AdamW)를 단일 device-resident 그래프로 fuse 해 (1) 인터프리터를 per-step hot path 에서 제거 → util-GREEN(MEAN≥20%) = PyTorch+CUDA 수준 따라잡기, (2) library-call 스택이 구조적으로 못 하는 op-boundary fusion + compile-time 특화로 그 이상을 연다. 실현 능력은 [[GPU]] whole-program-fusion North-Star(§5d/§5f/§5g), 적용 대상은 [[FLAME-PERF]] 트레이너, cure 대상은 [[FORGE-UTILGREEN]] option-B. 잣대 = [[GPU-ROOFLINE]]. **정직 경계 (g5)**: raw GEMM 우위 주장 금지 — cuBLAS = roofline, 우위 주장 0. own-GEMM 현 상태 = TF32 own-GEMM 이 **70.7/71.0 TFLOP/s 정상(summit)**(6.06–6.09× off cuBLAS-TF32, **bit-exact**); parity gap 은 software decode-copy(32KB band ⊥ occupancy)에 **구조적으로 bound**(양쪽 dtype OG11–OG14 입증). research #2854 의 "descriptor-direct 로 decode-copy 제거" 가설은 **OG15 가 FALSIFY**(3200-cfg descriptor sweep rel-RMS 1.000 floor — decode band 는 96→64KB 제거-가능하나 read 가 bit-exact 아님: 손수 짠 `cuTensorMapEncodeTiled` box 가 canonical CuTe `Layout_K_SW128_Atom` 이 아닌 atom-major stacking 을 land). larger-tile/deep-ring/warp-spec 전부 closed-neg. moat = **경계 제거**(launch + op-boundary), NOT 커널 한 장 속도.

## ── current state snapshot (2026-06-06, post OG-ladder drain) ──

- **own-GEMM TF32 summit (OG10)** = **70.7–71.0 TFLOP/s, 6.06–6.09× off cuBLAS-TF32, 2 CTA/SM, bit-exact** —
  the OG-ladder frontier; OG11→OG15 are all closed-neg on the SAME 32KB-band-vs-occupancy / atom-encoding wall
  (OG15 FALSIFIED the descriptor-direct shortcut: band removable 96→64KB but read not bit-exact). The one net-new
  lever = **OG16 canonical-atom match** (net-new kernel, deliberate future decision — no auto-fire).
- **whole-step megakernel — BOTH walls CLOSED** (g5): wall 1 = un-fusable cuBLAS host call removed by the in-line
  device own-GEMM (#2697); wall 2 = the two GroupNorm full-Y reductions closed by a cooperative grid-synced GN,
  byte-eq max|Δ|=0 A100-confirmed. STRUCTURAL-COMPLETENESS, not a util/perf win (util term = GEMM-gap occupancy,
  a separate closed-neg).
- **5-axis north-star**: axes 1 (own-GEMM perf) + 2 (cuBLAS-impossible megakernel) DONE/closed; axes 3/4/5
  (reflect → dojo / README / commons) are the downstream reflect lanes (axis-5 sign-gated, user-only). See §5-axis.
- **fused multi-expert Conv1d MoE kernel — the flame+forge cure for the f5e18a0f conv-under-fill root cause**
  (2026-06-06, F-FUSION-MOE-CONV-FUSE 🟢): a single own-device-kernel computes ALL E=30 ConvExpert Conv1d
  in ONE GPU-saturating launch (tile = expert × out-channel-block × time-block), the structural 3rd option
  cuDNN can't give (it offers only 30-separate-launch UNDER-FILL or grouped-conv 11x REGRESSION). GATE FIRST:
  byte-exact vs the 30-separate-conv reference (max|Δ|=0 device-vs-device; 2.98e-7 vs CPU = fp32 FMA
  contraction, same accum order). FINDING (L40S 142 SMs): regime-split — in the UNDER-FILL regime (d=512,
  32 CTAs/separate-launch) the fused kernel is **2.68x faster than ModuleList-30 and 2.85x faster than
  grouped** = the cure demonstrated; once each launch already saturates the GPU (d≥1024, ≥98% util) there is
  no fill headroom and the naive per-channel MAC kernel loses to 30 well-sized launches on the memory roofline.
  Grouped is WORST in both regimes (reproduces the f5e18a0f regression). HONEST: the win is FILL/boundary-
  removal where under-fill exists, NOT raw-conv superiority (cuDNN conv = roofline). The d=6208/H200 production
  shape lives in the under-fill regime on a big-SM GPU but that crossover is not re-measured here (H100/H200
  access unresolved, out of scope). verdict: .verdicts/hexa-fusion/F-FUSION-MOE-CONV-FUSE.txt
- [x] **OG-FUSE-OPT — tiled/shared-mem fused MoE-conv kernel** — added path (D): stage the input
  time-window into smem once per CTA (CI_TILE-chunked, coalesced) + register-blocked time accumulators,
  removing path (C)'s CO_TILE-fold redundant global X reads. L40S sm_89 (vast 39749770, DESTROYED leak 0):
  byte-eq max|D|=0 vs the 30-conv reference HELD both regimes (gate + perf-shape cross-check). Tiling gave
  a real 1.61x fused-vs-fused speedup at d=2048 (C 1662→D 1034 ms). BUT (D) STILL loses to ModuleList-30
  at d=2048 (1034 vs 333 ms) → saturated-win FALSIFIED. Residual roofline = WEIGHT bandwidth + L2-weight-
  locality, NOT fill (util 98.7% for A/C/D alike — already saturated); weights are unique/touched-once so
  fusion can't shrink weight traffic. Fusion remains an UNDER-FILL-only cure.
  verdict: .verdicts/hexa-fusion/F-FUSION-MOE-CONV-OPT.txt
- [x] **OG-FUSE-PROD-KERNEL — weight-bandwidth-optimal GEMM-conv kernel BEATS ModuleList at the
  production wall** — 🟢 the OG-FUSE-OPT closed-negative REVERSED. (2026-06-07, H100 80GB, vast 39761793
  DESTROYED leak 0.) The OPT verdict pinned the saturated d=6208 wall as WEIGHT-bandwidth bound (weights
  touched once, no reuse → fusion/fill can't help, tiled-D still loses to ModuleList) and named the cure:
  weight REUSE. Path (E) k_moe_conv_gemm recasts each expert Conv1d as an implicit GEMM
  (Y[t,co]=Σ_k Σ_ci Xshift_k[t,ci]·W_k[ci,co]) and REGISTER-TILES it (BM=64 time × BN=64 outch, BK=16,
  4×4 micro-tile): the weight smem tile is loaded ONCE and reused across all BM time-rows → BM-fold weight
  reuse, weight HBM traffic cut ~BM×. ci-ascending k-inner accumulation preserved → **byte-eq max|Δ|=0 vs
  ModuleList-30** (device-vs-device, gate FIRST + perf-shape cross-check at every d). PERF (H100 132 SMs):
  d=4096 E=249.7 vs A=1649.2 ms (6.60x); **d=6208 (THE measured wall) E=568.1 vs A=3734.5 ms (6.57x)**;
  d=8192 E=982.9 vs A=13466.6 ms (13.70x). Util @d=6208 BOTH ~92% saturated → the win is NOT fill (the OPT
  closed-neg regime) but pure WORK-REDUCTION via weight reuse (same FLOPs, less HBM). tiled-D LOSES to A at
  d=6208 (3997 vs 3734 ms) confirming OPT. cuBLAS roofline (F) stays ~15x below E — no superiority claim,
  E reaches a far better roofline point. The production cure is "replace ModuleList+fused/tiled with the
  GEMM-conv kernel", NOT "the wall is fundamental". verdict: .verdicts/hexa-fusion/F-FUSION-MOE-CONV-PROD-KERNEL.txt
- [x] **OG-FUSE-XOVER — d=6208/H200 production crossover** ✅ (2026-06-07, F-FUSION-MOE-CONV-XOVER 🔴
  closed-negative): measured on the EXACT production GPU (NVIDIA H200, 132 SMs, sm_90, vast 39749545
  DESTROYED leak-0). GATE FIRST PASS at every swept d — byte-eq max|Δ|(fused/grouped vs ModuleList-30)=0,
  device-vs-CPU 2.98e-7 fp32-FMA. d-sweep {4096,6208,8192} median step (ms), winner=ModuleList-30 EVERY d:
  d=4096 A=1648.8 / C-fused=3132.7 / B-grouped=16134 · **d=6208(PROD) A=3736.1 / C=7076.2 / B=37921** ·
  d=8192 A=8902.1 / C=12660.6 / B=64351.7. util MEAN 96-97% / PEAK 100% on ALL 3 paths at ALL d (saturated).
  **VERDICT: d=6208/H200 is in the SATURATED regime — the f5e18a0f fused-conv launch cure DOES NOT APPLY
  to the real 7B CLMConvMoE step.** ModuleList-30 already issues 1568 CTAs/launch at d=6208 (~12× the 132
  SMs) → no under-fill headroom → fused loses 1.89×. The #2859 "d=6208 lives in under-fill" conjecture is
  FALSIFIED; under-fill on a 132-SM GPU needs d≲384 (below any real MoE width). The ~74s/step production
  wall is therefore a roofline/memory problem (→ OG-FUSE-OPT tiled kernel), NOT a launch-fill problem. The
  cure stays valid only for genuinely small-d under-fill (L40S d=512). verdict:
  .verdicts/hexa-fusion/F-FUSION-MOE-CONV-XOVER.txt (+ .raw.txt verbatim).
- [x] **OG-FUSE-FOLD — fold the fused kernel into the flame CLMConvMoE trainer** ✅ (2026-06-07,
  F-OGFUSE-FOLD 🟢): wired tool/gpu_moe_conv_fuse.cu into stdlib/flame as the device MoE-conv path —
  clm_moe_conv_fused.hexa now folds the env-gated device MoE-conv DISPATCH into the CLMConvMoE expert
  BLOCK (conv ⊕ route), the actual trainer step: `moe_block_fwd_dispatch` produces ex_out[E·T·d] via
  `moe_conv_fwd_dispatch` (HEXA_FUSE_MOE_CONV / HEXA_FUSE_ALL → fused/GEMM-conv path E; default OFF →
  E-conv ModuleList-30 oracle) then runs moe_lib's softmax router. Before this, ex_out was NOT produced
  by the dispatch + fed to the router — the fused kernel was a standalone selftest, NOT the trainer path.
  GATE (g5) byte-eq fused trainer block == ModuleList-30, **max|Δ| = 0.000e+00**: (1) CPU flame block
  fold F-CLM-MOE-BLOCK-FOLD-EQ=1 — fuse_on=1 AND fuse_on=0 both 0.0 over E∈{30,4}, dil∈{1,2}; (2) GPU
  dev-vs-dev (RTX A2000 sm_86) [GATE-DEV-EQ] GEMM-vs-ModuleList = 0.000e+00, GATE OVERALL => PASS (the
  GEMM-conv path E the fold routes to). Env-gate = HEXA_FUSE_MOE_CONV. The fused kernel IS now the flame
  trainer's device MoE-conv path, byte-eq — application path for the f5e18a0f cure CLOSED. Pod destroyed,
  leak 0. verdict: .verdicts/hexa-fusion/F-OGFUSE-FOLD.txt.
- [x] **OG-FUSE-RIGHTSIZE — right-sized-GPU per-regime validation** ✅ (2026-06-07, F-FUSION-MOE-CONV-RIGHTSIZE 🟢):
  validated the f5e18a0f cure on a RIGHT-SIZED **RTX 4070 (46 SMs = 3.09x fewer than the L40S 142-SM baseline)**.
  GATE FIRST (g5): byte-eq max|Δ|(fused vs 30-conv ref) = **0.000e+00** at EVERY swept d (256/512/1024/2048);
  2.98e-7 vs CPU = fp32 FMA contraction (same accum order). FINDING — **right-sizing WIDENS the fused-win
  regime: YES**. L40S baseline: fused wins in only 1 of 4 shapes (d=512 2.68x, loses ALL d≥1024). RTX 4070:
  fused wins OUTRIGHT in 2 of 4 (**d=256 8.91x · d=2048 1.67x**) + ties d=512, loses only the narrow mid-band
  d=1024 (0.435x) = fused-favorable in 3 of 4 vs 1 of 4. Two honest mechanisms: (1) deep under-fill at d=256
  (8 CTAs/launch ≪ 46 SMs) → 8.91x; (2) launch-amortization/wave-continuity at d=2048 (one 15360-CTA launch
  removes 29 inter-launch bubbles a 46-SM GPU can't hide) → 1.67x. The mid-band d=1024 loss = memory-roofline
  (naive per-CTA MAC, no shared-mem tiling) = the OG-FUSE-OPT axis, orthogonal to fill. HONEST (g5): win =
  fill + launch-amortization (boundary removal), NOT a faster conv (cuDNN conv = roofline). util counter
  saturates 100% in both regimes (can't resolve occupancy) → cuEvent step-time is the authoritative fill
  proxy. Right-sizing dodges big-GPU contention + the H100/H200 access-unresolved blocker AND structurally
  favors fusion. pod RTX 4070 39749656 DESTROYED leak-0. verdict: .verdicts/hexa-fusion/F-FUSION-MOE-CONV-RIGHTSIZE.txt
  (2026-06-07, CODE FOLD GREEN — standalone byte-eq validated, full-trainer build DEFERRED):
  stdlib/flame/clm_moe_conv_fused.hexa folds the fused E-expert MoE-conv into flame. moe_conv_fwd_dispatch
  routes on env HEXA_FUSE_MOE_CONV (or HEXA_FUSE_ALL): SET → moe_conv_fused_fwd (ALL E experts in ONE
  strided-batched GEMM, the one-launch own-kernel analogue); default OFF → moe_conv_modulelist_fwd (E
  separate forge convs = the under-fill baseline). Both byte-eq. Mirrors the .cu k_moe_conv_fused layout
  (X[T·d] shared · W[E·d·d·K] · b[E·d] · Y[E·T·d]) and the clm_conv_batched.hexa E=2 precedent generalized
  to E experts. GATE F-CLM-MOE-CONV-FUSE-FOLD-EQ = 1: fused == E× ModuleList max|Δ| = 0.0 over
  {E=30 dil=1, E=30 dil=2, E=4 dil=1} on Mac CPU (`hexa run`, no link dep). verdict:
  .verdicts/hexa-fusion/F-CLM-MOE-CONV-FUSE-FOLD-EQ.txt. DEFERRED: the full 7B clm_prod_gpu on-pod build +
  the own-device-kernel util Δ at production shape (d=6208, E=30, H100/H200) — NO full train was run.
- [x] **OG-FUSE-PROD-FOLD — route the flame MoE-conv to the GEMM-conv weight-reuse path E** — the
  PRODUCTION fold. OG-FUSE-FOLD wired the strided-batched FUSED path (moe_conv_fused_fwd), which is the
  UNDER-FILL kernel — it LOSES at production d=6208 (saturated, memory-roofline bound). OG-FUSE-PROD-KERNEL
  then found the real winner: path E k_moe_conv_gemm (6.57× vs ModuleList-30 at d=6208/H100, byte-exact).
  This fold makes the production path = path E. (2026-06-07, CODE FOLD GREEN — standalone byte-eq validated,
  full-trainer build DEFERRED.) stdlib/flame/clm_moe_conv_fused.hexa adds moe_conv_gemm_fwd: per-expert
  register-tiled GEMM with weight-tile reuse across the T time-rows. The conv is recast as an implicit GEMM
  (Y[t,co]=Σ_k Σ_ci Xshift_k[t,ci]·W_k[ci,co]); the shared im2col xcol[T·(d·K)] is built ONCE (all experts
  read the SAME X — NO E× xcol replication, unlike the batched fused path's [E·T·Kdim] blowup that costs at
  d=6208), then ONE forge_dispatch_matmul(xcol, T, Kdim, Wt_e, d) per expert reuses the shared xcol while
  the weight tile streams. The im2col contraction index j=ci·K+k (ascending) IS the ci-outer/k-inner order
  the device kernel k_moe_conv_gemm accumulates in (lines 346-363) → byte-IDENTICAL to moe_conv_modulelist_fwd
  / nn_conv1d_fwd (weight reuse is a SCHEDULING property of the device GEMM, NOT a math re-association; this
  is the path-E own-GEMM, NOT the cuBLAS path-F roofline which reorders ci and is only rel-RMS-eq).
  moe_conv_fwd_dispatch now routes path E under HEXA_FUSE_MOE_CONV (or HEXA_FUSE_ALL); default OFF →
  moe_conv_modulelist_fwd (the byte-eq oracle). GATE F-CLM-MOE-CONV-GEMM-FOLD-EQ = 1: GEMM-conv path E ==
  E× ModuleList max|Δ| = 0.0 over {E=30 dil=1, E=30 dil=2, E=4 dil=1} on Mac CPU (`hexa run`, no link dep);
  the legacy strided-batched fused path also stays max|Δ|=0. verdict:
  .verdicts/hexa-fusion/F-CLM-MOE-CONV-GEMM-FOLD-EQ.txt. The fold makes the 6.57× REACHABLE by the trainer;
  it does NOT itself measure a trainer speedup. DEFERRED: the full 7B clm_prod_gpu on-pod build + the
  GEMM-conv util Δ / step-time at production shape (d=6208, E=30, H100/H200) — NO full train was run; the
  6.57× is the KERNEL benchmark (PR #2867), the on-trainer measurement is the next step.
- [x] **OG-FUSE-PROD-PERF — close path E → cuBLAS roofline via GEMM perf levers** — 🔴 CLOSED-NEGATIVE for
  the cp.async double-buffer lever. (2026-06-07, H100 80GB HBM3, vast 39771465 DESTROYED leak 0.) Goal: push
  path E (k_moe_conv_gemm, 6.57× over ModuleList-30, byte-eq) CLOSER to the cuBLAS strided-batched roofline
  (path F, ~15× below E) WITHOUT losing weight-reuse / byte-eq. Lever (a) APPLIED: new path G
  k_moe_conv_gemm_db — a STAGES-deep smem RING (Xs window + Ws weight slabs) prefetched via
  cp.async.ca.shared.global + commit_group/wait_group so the next K-chunk's HBM loads are in flight while this
  chunk's register MAC runs. Accumulation order BIT-IDENTICAL to E (ci asc, k inner) → **GATE byte-eq
  max|Δ|=0 vs ModuleList-30** (gate FIRST at d=192 AND perf-shape cross-check at d=6208, both 0.0). PERF
  (H100 132 SMs, median 20 iters): **path G is UNIFORMLY ~7% SLOWER than path E** — d=2048 G=68.95 vs
  E=64.45; d=4096 G=265.1 vs E=247.8; **d=6208 (prod) G=602.7 vs E=563.9 ms** (A=3709, F-roofline=35.9 →
  E 6.58× over A, 15.7× from roofline). FALSIFIER (pre-registered): "cp.async prefetch hides the per-chunk
  Xs+Ws load latency the OG-FUSE-OPT verdict pinned, closing E→cuBLAS" — FALSIFIED. MECHANISM: GM_BK=16 →
  d/16≈388 chunks; per chunk cp.async pays commit/wait + an extra __syncthreads while the per-chunk compute
  (16 ci × K=3 over a 4×4 tile) is tiny → pipeline bookkeeping > latency hidden. Path E already overlaps
  loads via OCCUPANCY (many CTAs/SM, warp scheduler hides latency), so explicit prefetch adds overhead w/o
  adding overlap. The OPT-pinned wall is L2/WEIGHT BANDWIDTH (a bandwidth bound) — cp.async addresses LATENCY,
  so it structurally cannot move it. RULED-OUT AXIS: latency-hiding is NOT the lever; path E is at its design
  ceiling on the latency axis. The remaining E→cuBLAS gap = arithmetic-intensity + wgmma (levers c/b, next
  cycle). (Forced GM_STAGES 3→2: 3-stage static __shared__ ring = 49536 B > 48KB/49152 B static-smem hard cap
  → cudaErrorInvalidValue; 2-stage = 33024 B fits. Deeper static ring impossible; dynamic smem wouldn't
  change the bandwidth conclusion.) Lever (b) wgmma TF32 NOT applied — OG16 atom still at swizzle-parity
  frontier, breaks byte-eq, K=3/BK=16 doesn't map to m64n64k8 K-major TMA tile. HONEST: path E's 6.57× cure
  is UNCHANGED / NOT regressed; this prunes the cp.async lever from the gap-closing search. PR #2871.
  verdict: .verdicts/hexa-fusion/F-FUSION-MOE-CONV-PROD-PERF.txt
- [x] **OG-FUSE-PROD-PERF2 — close path E → cuBLAS via wider register tile (arithmetic intensity)** —
  🔴 CLOSED-NEGATIVE for the wider-register-tile / arithmetic-intensity lever. (2026-06-07, H100 80GB
  HBM3, vast 39774277 RENTED+DESTROYED leak 0.) The PROD-PERF verdict named the correct residual lever:
  raise ARITHMETIC INTENSITY (wider register micro-tile → more FLOPs per staged smem byte → less
  bandwidth-starved). Lever (c) APPLIED: new templated path H k_moe_conv_gemm_wide<BM,BN,BK,TM,TN>
  (dynamic smem so wide tiles exceed the 48KB static cap) + a 7-config sweep (64×64 control → 128×128
  t8×8 → 128×128 BK8). Accumulation order BIT-IDENTICAL to E (ci asc, k inner) → **GATE byte-eq
  max|Δ|=0 vs ModuleList-30 for ALL 7 configs** (gate FIRST at d=192 AND perf-shape cross-check at
  d=6208, all 0.0; NO reorder forced). PERF (H100 132 SMs, median 20 iters, d=6208): **EVERY wider tile
  REGRESSED.** 64×64 t4×4 (= path E, dynamic-smem) 514ms (BEST, ties E); 128×64 t8×4 616ms (+20%);
  64×128 t4×8 745ms (+45%); 128×128 t8×8 919ms (+79%); 128×128 t8×4-512thr 868ms (+69%); 64×64 t8×8-64thr
  993ms (+93%); 128×128 BK8 (AI=0.996, 4× path E's 0.248) **920ms — the highest-intensity config is the
  SLOWEST.** cuBLAS-F roofline 34.6ms → ratio E/F = 16.4×, best-wide/F = 14.9× (just path E). FALSIFIER
  (pre-registered): "wider tile raises FLOP/byte → E→cuBLAS ratio drops below ~10×" — FALSIFIED;
  ratio did NOT move, throughput regressed monotonically with intensity. MECHANISM (the W12/OG17-256-tile
  failure mode CONFIRMED here): wider tile → bigger register accumulator (up to 8×8=64 acc/thread) +
  bigger Ws smem → OCCUPANCY collapses → fewer warps to hide the WEIGHT-stream HBM latency; and K=3/BK=16
  is a SHALLOW contraction with NO deep-K reuse for a fat micro-tile to amortise (the conv's 13.87GB
  weight bank is touched ~once). SAME wall the cp.async probe hit from the other side: weight/L2 BANDWIDTH
  + reuse-poverty — NEITHER latency-hiding NOR arithmetic-intensity moves it. RULED-OUT AXIS: register-tile
  width. STANDS: path E (64×64 t4×4) = the production deliverable (6.57× over ModuleList, byte-exact); the
  E→cuBLAS gap is a fundamental register-vs-bandwidth wall. HONEST: nothing shipped regresses the cure
  (H0 ties E exactly). PR pending. verdict: .verdicts/hexa-fusion/F-FUSION-MOE-CONV-PROD-PERF2.txt
- [ ] **OG-FUSE-RIGHTSIZE — right-sized-GPU per-regime validation** — validate the cure on a right-sized
  GPU (RTX 5070 / L40S) per regime to dodge big-GPU contention + the access-unresolved blocker; the
  byte-eq D1536-saturates-5070-to-98% fact already shows right-sizing is the practical lever.

## 전제 — 왜 fusion 인가 (host-feed 축이 닫힌 뒤)

FORGE-UTILGREEN lever-1~5 가 GEMM repack 을 전부 device 化했어도 util MEAN 은 0.6% 에 PINNED — 8× workload sweep 에서 PEAK 38→78% 배증, MEAN flat → binding constraint = **인터프리트 per-step 드라이버 루프 wall-time**(F-RFC046 root). host-feed 축은 CLOSED-NEGATIVE TERMINAL. 유일 cure = 인터프리터를 hot path 에서 빼는 것 = train step 을 device-resident 그래프로 fuse = 이 도메인.

```
🐍 PyTorch eager — "전문 기계 조립라인"        🔥 HEXA-FUSION — "한 기계 안에서"
─────────────────────────────────         ─────────────────────────────────
 Python ─launch→[cuBLAS]→[cuDNN]→...         codegen →[ fwd→CE→bwd→AdamW
   op 마다 최고속 기계, 기계 사이                       = ONE device 그래프 ]
   = 컨베이어 이동·대기(launch+boundary)         컨베이어(launch/op 경계) 자체 없음
```

- PyTorch 약점 = **library-call 경계**(cuBLAS/cuDNN monolithic black-box, op-by-op dispatch). torch.compile/Inductor 가 일부 fuse 하나 Python tracing + Triton 한계.
- hexa 강점 = 컴파일러가 train step 전체를 **한 IR** 로 봄 → op 경계 넘는 fusion + compile-time 특화 가능.

## 측정 닫힘 (2026-06-04 — 빌드벽 SOLVED · ② CLOSED-NEGATIVE · research → ④)

- **빌드벽 SOLVED** (이전 "유지자/CI 에만 존재" 결론 번복): 신규 임대 idle H100_NVL pod 에서
  frozen-seed 번들(self/ 전체)로 clm_prod_gpu 빌드+학습 성공. KEY = nvcc 에도 `-DHEXA_CUDA`
  (없으면 58→40 launcher), `-lcuda`, glibc2.35 pod 재빌드(summer .o 는 `__isoc23_strtol` 비이식).
- **util A/B (clean idle, baseline 0.00%)**: ASYNC=0 12.50% (CE 4.47→3.65 PASS) vs ASYNC=1 10.28%.
  ② async = 🔴 CLOSED-NEGATIVE (util 안 오름 + byte-eq 깸). sizing 도 역효과(12.71→2.94%).
- **research(web+arxiv)**: launch-bound 진단 확정 → 유일 해법 = ④ CUDA Graph(host 임계경로 제거).
- **빌드/측정 킷** (repo-외 durable): `~/hexa-fusion-cuda-kit/` — `rebuild.sh`(신규 pod 원샷),
  `work/clm_prod_gpu`·`runtime_cuda.o`(-DHEXA_CUDA), `fusion_build_sources.tgz`, 측정로그.
  메모리 = `project_hexa_fusion_util_green` + `project_clmprod_gpu_build_seed_drift`(SOLVED).
- **L2 ④ CUDA-graph 닫힘 (2026-06-07, 🔴 per-step WALL CLOSED-NEG)**: capture/replay byte-eq max\|Δ\|=0 CORRECT but per-step wall FLAT ≈1.0x (0.97-1.03x) launch-bound→BW-bound — host bound = 인터프리트 inter-op glue, NOT cudaLaunch (⑧ ≥30% proof = pure-kernel sub-graph 한정). ① device-resident + ② async + ④ graph 모두 닫힘. 잔여 = whole-step megakernel (이미 CLOSED-NEG) / vs-PyTorch closure 벤치.

## ── 사다리: match (L1) → graph (L2) → exceed (L3) ──

### L1 — device-resident (= PyTorch eager 수준, util-GREEN)

- [~] **device-resident tensor lifetime** — param/grad/moment 를 step 전체에 GPU-resident 유지(host roundtrip 0). falsifier: 기존 오라클 byte-eq max|Δ|=0 ∧ nvidia-smi devmem persist across step. **W1-① PARTIAL (PR #2555 m,v + #2559 grad-db + #2561 int4)**: m,v + bias grad db + **int4 quant(W-fwd/dW-STE, 정수-exact)** device-resident 착지(env `CLM_PROD_DEVRESIDENT`, byte-eq ALL-PASS). 잔여: dX col2im transpose(orthogonal) · self-host pod build · devmem/util fire. **③ 정밀화: 텐서 resident 만으론 부족 — op 사이 인터프리트 host glue 도 fuse 해야 util MEAN gap 닫힘**. 상세 = §W1 results.
- [x] **async kernel-launch pipeline / per-step driver 제거 — 🔴 CLOSED-NEGATIVE (2026-06-04 측정)** — ② async 머지(#2619-2624)를 idle H100_NVL 에서 A/B 측정: ASYNC=0 util MEAN **12.50%** vs ASYNC=1 **10.28%** → async 가 util 을 **안 올림(오히려 ↓)** + ASYNC=1 byte-eq 깸(CE 4.89→4.86 vs 4.47→3.65, ②d sync제거 race). 워크로드 sizing 도 역효과(util 단조감소 12.71→2.94% @ D 1536→4608). falsifier `util MEAN≥20%` = FALSIFIED. 진단(research): 단일-스트림 async 는 host 를 임계경로에서 못 뺌 → 구조적으로 불가. verdict `.verdicts/hexa-fusion/F-FUSION-ASYNC-UTIL-AB.txt`.
- [x] **fwd-only fused device kernel 프로토타입 + util Δ probe** ✅ W1-③ — H100 fwd-only fire: MEAN 0.56→**2.83%** (5×↑) PEAK 21→**81%**, 여전히 RED. **진단**: device 는 세게 돌 수 있음 + binding = 인터프리트 per-step glue(GEMM 아님). 텐서 resident 만으론 부족 → inter-op glue fusion(⑤) 필요. 상세 = §W1 results.

### L2 — graph capture (= torch.compile / CUDA-graph 수준)

- [x] **per-step CUDA-graph capture/replay — 🔴 CLOSED-NEGATIVE (per-step WALL, H100_NVL measured 2026-06-07)** — captured fwd→ce_grad→bwd ONCE (cudaStreamBeginCapture/EndCapture/InstantiateWithFlags) + replayed bulk middle steps with ONE `cudaGraphLaunch`; AdamW + first/last-nwin metric steps stay eager. **byte-eq HARD GATE PASSED**: GRAPH=1 == GRAPH=0 epoch-1 ∧ epoch-N mean CE BIT-IDENTICAL at all 5 shapes (max\|Δ\|=0; capture SOUND, no host-dep leak, NOT a race). **SPEEDUP FALSIFIED**: per-step WALL eager-vs-replay FLAT ≈1.0x across the WHOLE launch-bound→BW-bound sweep — 0.973x (D128/T32) · 0.998x (256/64) · 1.010x (512/128) · 0.995x (768/256) · 1.027x (1536/512); range −2.82%..+2.65% = noise, largest Δ at BW-bound NOT launch-bound. The ≥30%/~1.7× expectation is NOT realized. **ROOT CAUSE (g5 honest)**: the ⑧ launch-amort ≥30% proof holds for a PURE-kernel sub-graph (cudaLaunch+HBM bound); this flame CLMConvMoE step's host critical path is INTERPRETED inter-op glue (per-window token t_get/t_set loop + eager 28-call AdamW + metric-step d2h + inter-op host glue), NOT cudaLaunch latency — amortizing the tiny captured kernel-issue slice moves the wall ~0, and there is NO launch-bound knee to exploit. Wall-axis confirmation of the prior util-only verdicts (F-FUSION-GRAPH-AB +1.32pp · -WHOLESTEP-AB +0.35pp). RULED OUT: "wrapping the flame step's fwd→bwd kernel region in a cudaGraph realizes the proven launch-amort wall win". A real wall win needs the WHOLE step (device-resident AdamW step-t + host token/glue loops) as ONE captured device program = whole-step megakernel, already CLOSED-NEG (F-FUSION-GRAPH-WHOLESTEP-AB / -MEGA-OWNGEMM-INTEGRATE). verdict `.verdicts/hexa-fusion/F-FUSION-CUDAGRAPH-REPLAY.txt`. harness `tool/hexa-fusion/fire_cudagraph_shapesweep.sh`. pod 39881262 destroyed, leak 0. 출처: PyTorch CUDA Graphs · Mirage MPK arxiv:2512.22219 · vLLM/SGLang piecewise.

### L3 — fusion moat (= PyTorch 초과 · 구조적)

- [x] **fwd+bwd autograd-aware fusion** (GPU.md §5d) — forward + backward 커널을 한 device 그래프로 fuse. falsifier: `F-FUSION-TRAINSTEP-EQ` max|Δ|=0 (fused == op-by-op reference). **🟢 byte-eq HOLDS (max|Δ|=0, admissible glue-only graph) · 🔴 wall CLOSED-NEGATIVE (~1.00×, -0.08pp)** — fused fwd+bwd graph removes host launch boundaries / launch latency, NOT on the critical path (binding = 인터프리트 per-step 드라이버 루프 + serial-DAG occupancy floor). GEMM-pulling fully-fused variant CANNOT hold byte-eq (own-GEMM ≠ cublasDgemm bit level). verdict `.verdicts/hexa-fusion/F-FUSION-TRAINSTEP-EQ.txt` (cites M2/B6/B3/P2A real-pod fires, all DESTROYED leak-0; ④ #2910 ~1.0x · W2 0.53% MEAN 일치).
- [x] **compile-time specialization** (GPU.md §5b) ✅ W1-⑥ (PR #2558) — known-(M,N,K) GEMM 특화: M/N/K `.param` 제거 · bounds-setp 에 M/N immediate baking · K stride literal-fold · K 수축 완전 unroll(loop·back-edge·counter 제거). emit Δ: generic fma 1(looped) → specialized K straight-line. default re-emit byte-eq max|Δ|=0. 잔여: dead-output elim · MIR call-site auto-select · WMMA matmul 경로 확장 · silicon. 상세 = §W1 results.
- [x] **operator-specific surgical override** (GPU.md §5g) ✅ W1-⑦ (PR #2556) — per-call-site WMMA precision override(`_nvptx_wmma_mnemonic_override` reads dst Local.precision). emit Δ: load `.shared.f16`→`.shared.bf16` · mma `.f32.f32`→`.f32.bf16.bf16.f32`, **store-c default .f32 유지(per-site granularity 증명)**. default re-emit byte-eq max|Δ|=0. 잔여: HIR `@bf16` grammar → Local.precision · silicon fire. 상세 = §W1 results.
- [x] **launch-overhead amortization 우위 측정** (GPU.md §5f · R12) ✅ W1-⑧ — ≥30% wall win UNCONDITIONAL (n*<0, no crossover; launch-bound 80% → BW-bound 72.7%), $0 oracle exit 0 + 실측 교차확인 max|Δ|=1.1e-5. raw-GEMM 우위 아님(경계 제거뿐). 상세 = §W1 results.

### L3 — whole-step megakernel: BOTH WALLS CLOSED (2026-06-06, g5 verbatim)

- [x] **glue-block megakernel — 2nd wall (GroupNorm grid-sync) CLOSED · 🟢 byte-eq A100-confirmed** — own-GEMM removed the FIRST wall (persistent kernel calls device `_hx_k_gemm` in-line, no un-fusable cuBLAS host call, #2697). The SECOND wall = the two GroupNorm full-Y reductions (GN#1 block-1/L3-c, GN#2 block-2/L3-d; G=1 mean/var over ALL T·C) needed a cross-block barrier a plain kernel lacks. **NOW CLOSED** via a cooperative grid-synced GN (`_hx_k_groupnorm_coop` + `cudaLaunchCooperativeKernel` + `cooperative_groups::this_grid().sync()`, env `HEXA_FUSE_GN_COOP`, -2 → sequential byte-eq fallback). Two-phase: ONE thread per group runs the IDENTICAL sequential t-outer/c-inner reduction (no tree re-assoc, same NR-40 `_hx_gn_sqrt_dev`) → `grid.sync()` broadcasts mu/inv → embarrassingly-parallel normalize. **byte-eq HARD GATE (g5) PASSED on real A100-SXM4-40GB (sm_80)**: 4/4 cases incl. T=1536 C=1536 G=1 (whole-tensor, 2.36M elems) → **max|Δ|=0, bitdiff_words=0**. cudaDevAttrCooperativeLaunch=1, grid fits one wave (108 SM × 18 blk/SM = 1944 max-coresident, coop_grid≤1944). **정직 경계 (g5)**: this is STRUCTURAL-COMPLETENESS, NOT a util/perf win — byte-eq FORCES the reduction single-thread so the coop launch buys ZERO reduction-parallelism; binding util term = GEMM-gap occupancy (F-FUSION-OCCUPANCY-WALL), untouched. VALUE = the whole-step megakernel is now FULLY realized: 100% hexa-owned, cuBLAS-call-free, no un-fusable GN host op. **SUPERSEDES** F-FUSION-GN-COOP-KERNEL-CLOSED-NEG.txt (that ANALYSIS-only "don't build it" verdict stands for the UTIL goal — correct, zero util lift — but its byte-eq-impossible premise is now MEASURED FALSE for the COMPLETENESS goal). verdict `.verdicts/hexa-fusion/F-FUSION-MEGAKERNEL-GN-GRIDSYNC.txt`. pod destroyed, leak 0.
- [x] **MEGA-OWNGEMM-INTEGRATE — 🔴 CLOSED-NEGATIVE (H100 sm_90a measured)** — wiring the OG17 TF32-PARITY wgmma own-GEMM as an IN-KERNEL GEMM inside the persistent whole-step COOPERATIVE megakernel is structurally IMPOSSIBLE at production CLM shapes. Falsifier fired on TWO independent axes: (1) wgmma needs a 128-thr warpgroup but the megakernel is uniform blockDim=64 → blockDim<128 CANNOT issue wgmma (STRUCTURAL, all S); (2) the wgmma coop one-wave residency ceiling is FIXED at 2 CTA/SM × 132 = 264 CTAs, while the GEMM output-tile grid scales (S/128)² — S=2048→256 tiles fits but S=4096→1024 tiles EXCEEDS the wave → grid.sync DEADLOCK (the decisive axis). OG10 1-CTA/SM fallback RULED OUT (132-CTA ceiling, worse). OG17 parity itself CONFIRMED bit-exact rel_rms=0 @ 259-267 TFLOP/s STANDALONE (own-ability holds at launch granularity), but a single-launch cuBLAS-free coop megakernel with a parity in-kernel GEMM is NOT achievable. Verdict .verdicts/hexa-fusion/F-FUSION-MEGA-OWNGEMM-INTEGRATE.txt. Strengthens the prior util-megakernel closed-neg.

### closure — vs PyTorch+CUDA 벤치

- [x] **vs-PyTorch+CUDA wall 벤치** 🔴 CLOSED-NEG — H100 SXM, 동일 CLMConvMoE D1536/T512/E2/K3 batch=1, 3-way: **flame 0.167 step/s (5.98 s/step, FP64) · torch eager 276.7 step/s (3.61 ms) · torch.compile 368.5 step/s (2.71 ms)**. flame÷torch = **0.0006× (eager) / 0.00045× (compile)** — torch 가 ~1656×/2207× FASTER, flame 은 1.3× 도달 ❌. wall = **INTERPRETED per-step driver glue** (window t_get/t_set + eager AdamW + CE-grad host glue) — NOT raw GEMM(util peak 100% in-GEMM, ≈cuBLAS), NOT kernel-fusion(#2910 capture/replay·#2911 fwd+bwd 둘 다 ~1.0× closed-neg 확인). 실제 lever = interpreter-elimination of per-step driver, batch>1 fill 만으론 1000× gap 안 닫힘(glue 가 B 와 함께 증가). verdict `.verdicts/hexa-fusion/F-FUSION-VS-PYTORCH.txt`. **정직**: cuBLAS=roofline 라 flame own-GEMM≈parity at best → raw GEMM 으론 애초에 못 이김(맞음); 단 측정 gap 은 GEMM precision 으로 설명 불가한 ~3 orders. branch 4/4 close-out(L3-fold GREEN · #2910 · #2911 · 본 verdict)로 vs-PyTorch wall 질문 CLOSED.

- [x] **BATCH-FILL throughput (samples/s) lever — the REAL ~1.3× the vs-PyTorch data pointed to** 🟢 CONFIRMED — H100 SXM (39893326), CLMConvMoE D1536/T512/E2/K3, samples/s = B/per-step-slope (2-point timed, init-subtracted). **≥1.3× hit at B=2 (1.504×)**; curve climbs **B=1 0.1747 → B=2 0.2628(1.50×) → B=4 0.3503(2.01×) → B=8 0.4168(2.39×) → B=16 0.4785(2.74×) → B=32 0.5161 samples/s (2.95×)**; util MEAN climbs 10.4→30.0% (median 0% throughout). B=64 single M=32768 step UNMEASURABLE (>20min/3steps = the cap signal). **Saturation**: monotone-↑ through B=32 but sharply diminishing (+0.50×→+0.21× per doubling), asymptote ≈3× — the per-position INTERPRETED glue (window t_get/t_set + CE-grad + AdamW, all ∝B·Tw) caps it (same wall as vs-PyTorch). **byte-eq**: B=1 determinism max|Δ|=0 (run-A==run-B bit-identical CE); B=1=exact prior path; B>1 carries the documented K-1 causal-conv SEAM-only Δ (GEMM shapes identical, CE descends). Reconciles M5-util (different regime/MEAN-metric) + vs-PyTorch (fill can't close the ~1656× *torch* gap but DOES give a 2.95× flame *self*-speedup — distinct question). Real flame speedup lever CONFIRMED; uncapping it = interpreter-elimination of the per-step glue. verdict `.verdicts/hexa-fusion/F-FUSION-BATCHFILL.txt`. Pod DESTROYED leak-0.

- [x] **INTERP-ELIM — native/AOT-compile the per-step driver** 🔴 CLOSED-NEGATIVE (2026-06-08, F-FUSION-INTERP-ELIM): native-compiled the full per-step driver glue (token-pack t_get/t_set + im2col/col2im + db-colsum + CE softmax-grad + AdamW, verbatim from clm_prod.hexa host fallbacks) two ways from one source — INTERPRETED (`hexa run`, bytecode) vs NATIVE (hexat→C→gcc -O2). GATE byte-eq **max|Δ|=0** (native==interp checksums on every buffer, all configs). SPEEDUP **🔴 ~1.0× — NO uncap**: Mac D1536/Tw512 B=1 native 1690ms vs interp 1727ms (1.02×), B=4 0.99×; per-op im2col-loop 1.05×, AdamW-builtin parity. ROOT CAUSE — the interpreter only interprets cheap loop scaffold; t_get/t_set→farr_get/set, adamw_step, exp are NATIVE-C builtins in BOTH arms, so AOT-compiling removes a negligible fraction. H100: the FULL native real-trainer clm_prod_gpu util MEAN **0.43% MEDIAN 0%** = IDENTICAL to the M5 interpreted ~0.45% → interp-elim does NOT change the step's duty cycle. FALSIFIES the #2912 "interpreter" attribution for the host-arithmetic glue: the ≈3×/~1656× wall is the serial un-fused FP64 cuBLAS op-DAG + per-op launch/sync dispatch (the M2/M3/M5 structural closed-neg), NOT bytecode interpretation. Closes **≈0%** of the torch gap via this lever. Remaining levers unchanged (precision/algorithm fusion OR right-sized GPU). Pod 39912326 DESTROYED leak-0. verdict `.verdicts/hexa-fusion/F-FUSION-INTERP-ELIM.txt`.
- [x] **PRECISION-CHANGE — TF32/BF16 own-GEMM flame step, does precision uncap >3×?** 🔴 CLOSED-NEGATIVE (2026-06-08, F-FUSION-PRECISION-CHANGE): the FIRST honest uncap lever g85 named beyond the ~3× batch-fill cap — REFUTED on the real flame step. runtime_cuda.c PATCHED (env `HEXA_GEMM_PREC=fp64|tf32|bf16` in BOTH matmul launchers via cublasGemmEx tensor-core; one-shot rel_rms-vs-FP64 [PREC-GATE]). H100 SXM (vast 39923836, driver 560.35.05, D1536/T512/E2/K3). **GATE PASS (W14 ≤1e-2, dtype-stated)**: TF32 rel_rms_vs_fp64=**2.76e-04**, BF16=**2.61e-03** (first GEMM M512/K4608/N1536); CE descends. **SPEEDUP 🔴 NO UNCAP**: step/s **B1 fp64 0.19778 → tf32 0.20165 (1.020×) · bf16 0.20289 (1.026×)**; **B4 fp64 0.05122 → tf32 0.04953 (0.967× — SLOWER)**. util **MEDIAN pinned at ~1% (≈0%)** for fp64/tf32/bf16 alike. The ~3× ceiling is NOT lifted. ROOT CAUSE — the FP64 GEMM is NOT the wall; the step is launch-/glue-bound (median util ≈0%, device idle between bursts), so cheaper-arithmetic tensor-core GEMMs shrink an already-small bursty fraction and the per-GEMM fp64→low-prec convert+alloc TAXES the launch-bound bottleneck (B4 goes negative). Same wall as INTERP-ELIM (~1.0×) + FP64-fusion: PER-OP DISPATCH is dtype-invariant. **Refutes the g85 "compute-bound dense fusion" hope** — the step was never GEMM-compute-bound. Narrows the remaining uncap lever to **RIGHT-SIZED GPU only**. HONEST: the HEXA_GEMM_PREC tf32/bf16 path is a real reusable correct artifact (gate PASS); the NEGATIVE is on the speedup axis. Pod DESTROYED leak-0 (tag hexa-prec confirmed). verdict `.verdicts/hexa-fusion/F-FUSION-PRECISION-CHANGE.txt`. build kit `.verdicts/hexa-fusion/precision-change-build/`.

## ── completion roadmap (goal: 병렬 발사 전략으로 HEXA-FUSION 완성) ──

각 웨이브의 독립 레인을 병렬 백그라운드 에이전트로 발사 → 착지 시 verdict 를 본 문서에 g5 verbatim 기록 → 다음 웨이브 발사. pod 레인 = idle 재사용·1-fire·즉시 down. byte-eq max|Δ|=0 = 전 레인 hard gate. raw-GEMM 우위 주장 금지.

```
W1 (fired 06-03)  ──────────────────────────────────  4/6 landed
  ⑧ launch-amort ✅  ⑨ baseline ✅  ⑦ override ✅  ① m/v [~]
  ③ fwd-only probe 🔄   ⑥ compile-time spec 🔄
        │ gate: ① FULL (grad+param) + pod self-host build
        ▼
W2 (① full → util-GREEN MATCH)  ─────────────────────
  ①b grad-residency 🔄   ①c param W (host int4 re-quant 차단 해소)
  ② async launch pipeline → F-RFC046 util MEAN≥20% fire  ← util-GREEN MATCH 닫힘
  ④ CUDA-graph capture/replay   ⑤ fwd+bwd autograd-aware fusion
        │ gate: util-GREEN ∧ ⑤ fused
        ▼
W3 closure  ─────────────────────────────────────────
  ⑨-full hexa-vs-PyTorch wall bench (compute-bound MATCH · launch-bound EXCEED)
  → 9/9 terminal → HEXA-FUSION 완성
```

병렬 가능 노드(현재): ①b·①c·⑥·③ 동시. ②④⑤ 는 ① full 착지가 gate(공유 device-resident 기반). ⑨-full 은 ② util fire 이후.

## ── first parallel wave (W1) — 6 independent lanes fired 2026-06-03 ──

Dependency DAG 추출: 선행 0 인 노드를 전부 뽑아 동시 발사(maximal parallelism). 4 lanes $0(agent/mac/codegen·oracle) + 2 lanes pod(GPU 실측). 나머지 ②④⑤ + ⑨-full 은 ① 착지 후 unblock.

```
t0 (선행 없음 — 병렬 발사)              blocks ▶  대기
─────────────────────────────                   ──────
① device-resident tensor lifetime ──┬─▶ ② async launch · ④ CUDA-graph · ⑤ fwd+bwd fusion
③ fwd-only fused probe (util Δ)  ────┘   (⑤ 설계 입력)
⑥ compile-time specialization        (독립 codegen)
⑦ operator surgical override         (독립 codegen)
⑧ launch-amort 측정 (R12 재사용)      (독립 $0 oracle)
⑨ vs-PyTorch baseline                (독립 — full bench 만 ① 대기)
```

| lane | milestone | 기질 | 비용 | falsifier |
|---|---|---|---|---|
| ① | device-resident tensor lifetime | forge/codegen | agent $0 | byte-eq max\|Δ\|=0 ∧ devmem persist |
| ③ | fwd-only fused device probe | pod H100 | 💰 1-fire | util MEAN Δ vs 0.6% floor |
| ⑥ | compile-time specialization | codegen emit | mac $0 | 특화 emit Δ + byte-eq |
| ⑦ | operator surgical override | codegen emit | mac $0 | override emit Δ + byte-eq |
| ⑧ | launch-amort 측정 | static oracle | mac $0 | vs-call wall Δ < 1.0× |
| ⑨ | vs-PyTorch+CUDA baseline | pod | 💰 1-fire | PyTorch util/step-rate 기준선 |

pod 비용 가드: idle READY pod 재사용 우선 · 신규 rent 시 smallest-sufficient 1대 · single fire · 측정 후 즉시 down.

## ── W1 results — landed 2026-06-03 (2/6 first, g5 verbatim) ──

### ⑧ launch-amort 우위 — ✅ RE-CONFIRMED ($0 mac-local, byte-identical, exit 0)

```
[1] LAUNCH      fused 1 vs baseline 5  → 5.0× fewer
[2] HBM/elem    fused 3 vs baseline 11 → 3.67× less
[3] 30%-crossover n* = -26595.7 (NEGATIVE ⇒ no crossover)
    ⇒ ≥30% wall win UNCONDITIONAL across all n>0 (launch-bound 80% → BW-bound 72.7%)
[4] pct_faster: n=64→79.98% · n=1024→79.69% · n=16M→72.88%
VERDICT: structural advantage PROVEN — ORACLE_EXIT=0
```

elementwise/glue sub-graph 에서 fusion 이 op-by-op(cuBLAS-style) 스택보다 **항상 72.7~80% 빠름**. 실측 교차확인(ubu-2 RTX 5070, n∈{1024…16.7M}, max|Δ|=1.1e-5, `.verdicts/fusion-launch-amort-wall/`). 정직: launch + HBM-traffic 경계 제거뿐, raw-GEMM 우위 아님.

### ⑨ PyTorch+CUDA baseline — ✅ MEASURED (H100 sm_90, d1536/T512, 1.09B ConvMoE)

| 스택 | step/s | util MEAN |
|---|---|---|
| PyTorch eager | 1.872 | **100.00%** (n=266) |
| torch.compile | 1.871 | 99.99% (n=265) |

pod 39139563(anima idle) 재사용·발견상태 복귀(0% util), 신규 rent 0. **target line**: 이 shape 에서 성숙 라이브러리 스택은 H100 을 **이미 util 100% 포화**(eager==compile) = **compute-bound**.

### ① device-resident tensor lifetime — ✅ PARTIAL slice (PR #2555, base main, byte-eq ALL-PASS)

AdamW moments **m,v GPU-resident across the whole CLMConvMoE train loop** (host roundtrip = 0 for m/v). Root cause: `forge_dispatch_adamw` D2H'd W,m,v every step; m/v escape only into `_adam` (host fwd/bwd never read them) → per-step m/v D2H+H2D = pure removable roundtrip. New `_keepmv` builtin elides it (marks m/v `loc=FARR_DEVICE, dirty_host=0` → next step H2D-skip). env `CLM_PROD_DEVRESIDENT` (default off → byte-identical).

```
F-CLM-DEVFEED-IM2COL-EQ = 1   (max|Δ|=0.0)
F-CLM-DEVFEED-FWD-EQ    = 1   (max|Δ|=0.0)
F-CLM-DEVFEED-BWD-EQ    = 1   (dW=0.0 dX≤5.55e-17 db=0.0)
F-CLM-DEVFEED-ADAM-EQ   = 1   (adam 5-step W max|Δ|=0.0)
ALL-PASS — device im2col/col2im + device AdamW byte-eq to host feed
```
verdict: `.verdicts/hexa-fusion/F-CLM-DEVFEED-DEVRESIDENT-MV.txt`. raw-GEMM 우위 주장 0 — roundtrip 제거뿐.

### ①b device-resident GRAD half — ✅ (PR #2559, base fusion/l1-devresident-mv, byte-eq ALL-PASS)

bias grad **db device-resident across bwd→AdamW**. Root: `conv*_bwd_via_forge*` 가 device GEMM 출력 dy 를 host 로 읽어 `db[co]=Σ_t dy` 를 host reduce → `_adam` 재업로드. db 는 `_adam` 외 host 미참조 → 제거가능. 새 `_hx_cuda_farr_db_colsum_gpu`(1 thread/channel, **sequential t-sum, tree 재결합 없음 → bit-exact**, db `loc=FARR_DEVICE dirty_host=0`).

```
F-CLM-DEVFEED-DB-EQ = 1   (db dil∈{1,2} colsum-vs-host max|Δ|=0.0)
+ IM2COL/FWD/BWD/ADAM-EQ 전부 max|Δ|=0.0 유지  → ALL-PASS
```
verdict: `.verdicts/hexa-fusion/F-CLM-DEVFEED-DEVRESIDENT-GRAD.txt`. raw-GEMM 우위 주장 0.

### ①c device int4 quant (the crux) — ✅ (PR #2561, base fusion/l1-devresident-grad, integer-exact byte-eq)

int4 quant wall 격파 → W resident 가능. device fwd-quant `forge_dispatch_int4_quant`(per-out-channel `s=max|W|/7`, `q=clamp(round(W/s),±7)`, W `loc=FARR_DEVICE dirty_host=0`) + STE-masked bwd `forge_dispatch_int4_quant_bwd`(`dW=dy·mask`, dW resident).

```
int4 fwd max|Δ| wq=0.0 scale=0.0 qlevel=0.0 mask=0.0
int4 bwd (STE) max|Δ| dW=0.0
F-CLM-DEVFEED-INT4QUANT-EQ = 1   (정수-exact: max|Δ|>0 이면 FAIL — FMA-drift 핑계 없음)
ALL-PASS (im2col/fwd/db/int4/adam = max|Δ|0.0, bwd dX≤5.55e-17)
```
verdict: `.verdicts/hexa-fusion/F-CLM-DEVFEED-DEVRESIDENT-PARAM.txt`. 잔여: dX col2im transpose(quant 과 orthogonal) · self-host pod build(HEXA_CUDA emit) → W/dW/db/m/v ALL resident → util fire. raw-GEMM 우위 주장 0.

### ③ fwd-only fused util Δ probe — ✅ MEASURED (H100 sm_90, d1536/T512, pod 39139563 reused, $0)

fwd-only 경로(ce-grad+bwd+20×AdamW elide, fwd byte-identical)로 device-residency 가 util 을 움직이는지 측정.

```
n=1048 PEAK=81% MEAN=2.8349% busy_mean=13.26% pct≥20=5.06% mem_max=67699MiB (66GB·116-120W)
F-CLM-DEVFEED-FWD-EQ = 1 (fwd dil=1,2 max|Δ|=0.0)
```
| path | PEAK | MEAN |
|---|---|---|
| lever-2 full-step | 19% | 0.50% |
| lever-3 full-step | 21% | 0.56% |
| **fwd-only (③)** | **81%** | **2.83%** |

**HONEST: 부분적으로 움직임 — MEAN 0.56→2.83% (5×↑), PEAK 21→81%, 단 여전히 RED**(78.6% 샘플 0%). **결정적 정밀화**: PEAK 81% = device 를 세게 driven 가능 증명 + bwd/AdamW host tail 제거가 util 회복 ⇒ binding = **인터프리트 per-step driver loop(F-RFC046 root), NOT GEMM kernels** 재확정. 그러나 fwd-only 내부 0% 잔여 floor = **텐서 device-resident 만으론 부족, op 사이 인터프리트 host glue(add·gelu·groupnorm·moe-router 스칼라 루프)도 fuse 해야 MEAN→20% 닫힘** ⇒ ②(async-launch)·⑤(fwd+bwd fusion)의 진짜 과제 = inter-op glue 제거. verdict: `.verdicts/hexa-fusion-l1-fwdonly/F-RFC046-FWDONLY-UTIL.txt`. raw-GEMM 우위 주장 0.

### ⑤ inter-op glue fusion (slice 1: residual-add) — ✅ (PR #2564, base #2561)

③ 가 찾은 잔여 floor 의 최고빈도 glue: 잔차 `xt = xec + hg0`(매 step T·d host scalar 루프, t-conv↔router-conv GEMM 사이)을 device 로. `forge_dispatch_residual_add` → `_hx_cuda_farr_residual_add_gpu` grid-stride, 출력 `FARR_DEVICE dirty_host=0`.

```
residual-add max|Δ| out=0.0
F-CLM-DEVFEED-RESIDUAL-EQ = 1
ALL-PASS (im2col/fwd/bwd/db/int4quant/adam 전부 max|Δ|0.0 유지)
```
verdict: `.verdicts/hexa-fusion-l3-glue/F-CLM-DEVFEED-RESIDUAL-EQ.txt`. raw-GEMM 우위 주장 0.

### ⑤b inter-op glue fusion (slice 2: gelu ×3 + groupnorm ×2) — ✅ (PR #2566, base #2564, bit-exact)

`forge_dispatch_gelu`(EXACT erf-based, device `erf()`=IEEE libm) + `forge_dispatch_groupnorm`(10-arg; sequential reduction + host-identical NR-40 sqrt → no tree re-assoc). 출력 `FARR_DEVICE dirty_host=0`.

```
gelu max|Δ| out=0.0                              → F-CLM-DEVFEED-GELU-EQ = 1
groupnorm max|Δ| y=0.0 xhat=0.0 mean=0.0 inv=0.0 → F-CLM-DEVFEED-GROUPNORM-EQ = 1
ALL-PASS (전 F-CLM-DEVFEED-* max|Δ|0.0 유지, no regression)
```
verdict: `.verdicts/hexa-fusion-l3-glue/F-CLM-DEVFEED-GELU-GN-EQ.txt`. raw-GEMM 우위 주장 0.

### ⑤c inter-op glue fusion (slice 3 FINAL: expert-pack + moe-router + embedding) — ✅ (consolidated #2571, bit-exact)

`forge_dispatch_expert_pack2` · `forge_dispatch_moe_router`(softmax: moe_lib `_moe_exp` Taylor 재현 + seq accumulation → strict 0) · `forge_dispatch_embedding`(token gather). 출력 `FARR_DEVICE dirty_host=0`.

```
expert-pack max|Δ| ex_out=0.0 → F-CLM-DEVFEED-EXPACK-EQ = 1
moe-router max|Δ| y=0.0 probs=0.0 → F-CLM-DEVFEED-MOEROUTER-EQ = 1
embedding max|Δ| xe=0.0 → F-CLM-DEVFEED-EMBED-EQ = 1
ALL-PASS (전 F-CLM-DEVFEED-* max|Δ|0.0 유지)
```
verdict: `.verdicts/hexa-fusion-l3-glue-final/F-CLM-DEVFEED-FINAL-GLUE-EQ.txt`. **🎯 fwd 인터프리트-glue EXHAUSTED 확정** — clm_prod_fwd 의 모든 host scalar 루프(embedding→conv→groupnorm→gelu→residual→expert-pack→moe-router)가 device-gated. W2 self-host pod util refire UNBLOCKED. raw-GEMM 우위 주장 0.

### ⑤-bwd BWD-tail glue fusion (slice 1) — ✅ (PR #2584, base main, strict byte-eq)

fwd glue 소진 후 다음 floor = bwd/AdamW-tail 인터프리트 glue. `forge_dispatch_gelu_bwd`(GELU'=Φ+x·φ, host literal/order 동일) · `forge_dispatch_groupnorm_bwd`(dgamma/dbeta/dX, seq reduction no atomics, saved fwd inv) · `forge_dispatch_expert_unpack2`(pack 의 bwd mirror). 출력 `FARR_DEVICE dirty_host=0`.

```
gelu_bwd max|Δ| dg=0.0 → F-CLM-DEVFEED-GELU-BWD-EQ = 1
groupnorm_bwd max|Δ| dgamma=0.0 dbeta=0.0 dX=0.0 → F-CLM-DEVFEED-GROUPNORM-BWD-EQ = 1
expert-unpack max|Δ| dex0=0.0 dex1=0.0 → F-CLM-DEVFEED-EXUNPACK-EQ = 1
ALL-PASS (전 F-CLM-DEVFEED-* max|Δ|=0 유지)
```
verdict: `.verdicts/hexa-fusion-l3-bwd-glue/F-CLM-DEVFEED-BWD-GLUE-EQ.txt`. raw-GEMM 우위 주장 0.

### ⑤-bwd2 BWD glue EXHAUST (slice 2 FINAL) — ✅ (consolidated #2591 = ⑤-bwd+⑤-bwd2, strict byte-eq)

`forge_dispatch_ce_grad`(CE softmax-grad, seq per-row) · `forge_dispatch_moe_router_bwd`(cached probs, seq, no atomics) · `forge_dispatch_grad_sum3/2`(dxt/dxec) · `forge_dispatch_embedding_bwd_scatter`(deterministic, NO atomics, host-order accumulate). 출력 `FARR_DEVICE dirty_host=0`.

```
ce_grad max|Δ| dlogits=0.0 → F-CLM-DEVFEED-CE-GRAD-EQ = 1
moe_router_bwd max|Δ| dlogits=0.0 dex_out=0.0 → F-CLM-DEVFEED-MOEROUTER-BWD-EQ = 1
grad-sum max|Δ| sum3=0.0 sum2=0.0 → F-CLM-DEVFEED-GRADSUM-EQ = 1
embedding-scatter max|Δ| dtable=0.0 → F-CLM-DEVFEED-EMBSCATTER-EQ = 1
ALL-PASS — 19 oracles 전부 max|Δ|=0
```
verdict: `.verdicts/hexa-fusion-l3-bwd-glue2/F-CLM-DEVFEED-BWD-GLUE2-EQ.txt`. **🎯 bwd 인터프리트-glue EXHAUSTED 확정** — fwd+bwd 둘 다 소진 → 인터프리터가 full-step hot path 거의 이탈. 잔여 orthogonal: dX col2im · per-tensor AdamW tail. main merge: consolidated #2591(rebase clean ← #2584/#2590). raw-GEMM 우위 주장 0.

### 📦 main merge (2026-06-02) — device-resident + glue 전부 landed

squash×스택 충돌(베이스 재작성)을 rebase + consolidation 으로 해소하고 6 logical PR 전부 main 착지:
`#2552`(reorg) · `#2556`(⑦) · `#2558`(⑥) · `#2555`(①m/v) · `#2570`(domain doc, rebased ← #2553) · `#2571`(device-resident port + 전 fwd glue, consolidated ← #2559/#2561/#2564/#2566 + ⑤c). 전부 env-gated `CLM_PROD_DEVRESIDENT` default off → byte-identical, 동작 변화 0. 남은 것: W2 pod util fire · bwd/AdamW-tail fusion(②⑤) · ④ CUDA-graph · ⑨-full bench.

### ⑦ operator surgical override — ✅ (PR #2556, base main, emit Δ ∧ byte-eq)

`compiler/codegen/nvptx_target.hexa` `_nvptx_wmma_mnemonic` was handle-uniform (cuBLAS model: one handle pins compute-type for all GEMMs). New `_nvptx_wmma_mnemonic_override(op,prec)` reads dst Local.precision → ONE call-site carries `.bf16` while siblings keep default (empty in every real run today → default byte-identical).

```
[byte-eq] default-path re-emit IDENTICAL — max|Δ|=0   PASS
[emit Δ]  override call-site emits .bf16 family         PASS
[per-site] store-c keeps default .shared.f32            PASS
F-FUSION-WMMA-OVERRIDE: PASS (emit Δ ∧ default byte-eq max|Δ|=0)
```
verdict: `.verdicts/fusion-wmma-override/F-FUSION-WMMA-OVERRIDE.txt`. 잔여: HIR `@bf16` → Local.precision grammar · silicon fire. raw-GEMM 우위 주장 0 — cuBLAS 가 못 하는 override 능력 probe.

### ⑥ compile-time specialization — ✅ (PR #2558, base main, emit Δ ∧ byte-eq)

`compiler/codegen/nvptx_target.hexa` GEMM 은 shape-generic emit(M/N/K = runtime `.param.u64`, K data-dependent loop). 새 `emit_ptx_gemm_module_specialized(M,N,K)` (additive, 0 deletion): compile-time 상수 shape 면 M/N/K param·`ld.param`·`cvt` 제거, M/N bounds-setp immediate, K stride literal-fold, K 수축 완전 unroll(`$L_LOOP`·back-edge·`kk` counter 제거).

```
emit-Δ: generic fma.rn.f64 count=1 (looped) vs specialized=3 (K straight-line, M4/N4/K3) — CONFIRMED
✅ BYTE-EQ: generic GEMM PTX IDENTICAL (origin/main == new binary), max|Δ|=0 — no regression
F-FUSION-GEMM-SHAPE-SPECIALIZE: rc=0
```
verdict: `.verdicts/hexa-fusion/F-FUSION-GEMM-SHAPE-SPECIALIZE.txt`. 잔여: dead-output elim(§5b 2nd) · MIR call-site auto-select · WMMA matmul 경로(`_nvptx_emit_matmul_body` K/16 tile) · silicon. raw-GEMM 우위 주장 0 — 런타임 loop-control + shape param-load 경계 제거(라이브러리는 런타임 dispatch).

## ── ② async-launch pipeline — slice 1 ✅ (W2-confirmed lever, 2026-06-03) ──

W2 가 확정한 진짜 unblock(인터프리트 per-step 드라이버 제거)의 첫 codegen 슬라이스. PR #2619 (base main). fwd device-kernel 10개(im2col·im2col_t·db_colsum·int4_quant·residual_add·gelu·groupnorm·expert_pack2·moe_router·embedding)를 **단일 non-blocking CUDA 스트림 `g_forge_stream`** 로 launch + per-call host-sync 제거 → 커널 back-to-back 큐. sync 는 step 경계(D2H readback 전 `cudaStreamSynchronize`)에서만.

`self/cuda/runtime_cuda_emit.hexa`: `g_forge_stream`(lazy) · `_forge_async_on()`(env `HEXA_CUDA_ASYNC` 우선, unset→`CLM_PROD_DEVRESIDENT` 따름, default off→legacy per-call sync) · `_forge_launch_check()`(async=`cudaGetLastError`, legacy=`cudaDeviceSynchronize`) · `_forge_sync()`(`_d2h`/`_d2h_out` 에 주입).

```
$ hexa run stdlib/flame/clm_conv_devfeed.hexa
ALL-PASS — 19/19 oracles max|Δ|=0, 0 FAIL
```
async-OFF = emitted-C byte-identical(substrate + 10 launch rewrite + 2 D2H sync 주입만, #2571/#2591 byte-eq 유지). async-ON = same kernels·one stream·sync-before-readback 라 **by construction byte-eq**. verdict: `.verdicts/hexa-fusion-l1-async/`. **잔여(②b 진행중)**: bwd-tail+AdamW wrapper 를 스트림에 · `cublasSetStream` 으로 GEMM 큐 합류 → 전체 step 단일 async 스트림 → ④ CUDA-graph 가능. **util MEAN≥20% 검증 = pod fire 필요 (env-congested → DEFERRED, 코드는 byte-eq 검증·landed)**. raw-GEMM 우위 주장 0.

## ── W2 util fire verdict — 🔴 CLOSED-NEGATIVE (2026-06-03, g5 verbatim) ──

full fwd+bwd device-resident step (glue 전량 device, byte-eq strict 0) 의 첫 직접 util 측정. pod H100 sm_90, d1536/T512 E2 nsamp32 epochs3, corpus 2MB, CLM_PROD_DEVRESIDENT=1 DEVFEED=1 BATCHED=1.

```
util MEAN=0.5296%  PEAK=32%  busy_mean=3.51%  pct_ge20=0.13%  n=776
devmem=28427MiB (28GB device-resident)  peak_power=116.6W
CE 3.82753 → 2.83301   F-CLM-PROD-DESCENT=1 (descent 🟢)
```
verdict: `.verdicts/hexa-fusion-w2-util/` (W2-VERDICT block). **util-GREEN gate = MEAN≥20% → 미달 🔴** (스크립트의 "GREEN(peak≥20%)" 표기는 오류 — gate 는 PEAK 아님 MEAN).

**결정적 CLOSED-NEGATIVE**: util MEAN 비교 — lever-2 0.50% · lever-3 0.56% · fwd-only(③) 2.83% · **W2 full fwd+bwd 0.53%**. glue 를 전량 device 化(byte-eq 검증)했는데도 MEAN floor 가 안 닫힘 ⇒ **병목은 glue op 들이 아니라 인터프리트 per-step 드라이버 루프 자체**(~30 device 커널을 1개씩 host-sync 디스패치). full step(fwd+bwd+adam)이 fwd-only 보다 *더 낮은* 것도 일치(host 오케스트레이션 2배). **"per-op device化" 축을 결정적으로 배제** — HEXA-FUSION device-resident+glue 는 필요 인프라(main landed·byte-eq 검증)이나 util-GREEN 엔 불충분.

**⇒ 다음 진짜 레버 확정**: ② async-launch pipeline(host-sync 없이 커널 큐) · ④ CUDA-graph(step 캡처/replay) · 또는 단일 fused train-step mega-kernel — 인터프리트 per-step 드라이버 제거. ⑤ fwd+bwd autograd fusion 의 "한 device 그래프" 도 이 방향. 정직 caveat: 빌드가 fe2e43a(laneg)+splice(prebuilt 가 forge_dispatch 로워링 미포함)였으나 결과 0.53% 가 전 이전 측정과 일치 → 결론 robust. paper_negative_ok 자격(닫힌 음성: per-op device화 축 배제).

## ── 전략 정정 (⑧+⑨ 합성) — 2-regime: compute-bound=MATCH · launch-bound=EXCEED ──

⑨ 가 확정: 프로덕션 shape(d1536 dense MoE)는 **compute-bound** — PyTorch 가 같은 H100·shape 에서 util 100% 를 이미 찍는다. ⇒ hexa 의 util-RED(0.6%)는 GPU 일이 작아서가 **아니라 인터프리터 host-loop 가 굶긴 것**(PyTorch 100% 가 그 반증). 따라서:

```
regime                compute-bound (dense GEMM)        launch-bound (elementwise glue · 30 builtin · 20× AdamW)
────────              ──────────────────────────        ────────────────────────────────────────────────────
PyTorch               util 100% · roofline (포화)        op-by-op launch 손해
HEXA 목표             = MATCH (못 이김 ≠ 실패)           = EXCEED (⑧: ≥30% wall win UNCONDITIONAL)
도달 수단             lane ① device-resident 면 충분      lane ⑤⑥⑦ fusion + compile-time 특화
```

- **util-GREEN(=match)** 는 lane ① (device-resident, host-loop 제거)만으로 도달 — 워크로드가 이미 충분히 무거움(⑨ 증명). 추가 fusion 불필요.
- **exceed-PyTorch** 는 오직 launch-bound regime(작은 op·glue)에서 — ⑧ 이 ≥30% 무조건 우위를 $0 로 박제. dense GEMM 은 둘 다 roofline → 비김.
- 측정 전제(g5): full hexa-vs-PyTorch wall 벤치는 lane ① 착지 후 unblock(⑨-full).

## ── 상속: 이미 측정된 fusion 승리 (재유도 금지, cite) ──

이 도메인은 GPU 도메인의 fusion 캠페인이 측정한 교두보를 상속한다 (재측정 아님 · g5 verbatim 인용):
- **attention fusion R14 ≤1.0× vs cuBLAS-TC 3-launch** (GPU.md §1p, F-FUSION-ATTN-BM32-OCCUPANCY) — launch-bound 영역에서 라이브러리 스택을 실제로 앞지른 측정 beachhead.
- **F-FUSION-LAUNCH-AMORT $0 oracle** (GPU.md §1h, R12) — launch-overhead amortization 정적 증명.
- **whole-program-fusion epilogue GEMM+bias+GeLU** structural finding (GPU.md §1h, 2026-05-25).

## ── 정직 가드 (a_scale_honest_scope · g5) ──

- raw GEMM/커널 한 장으로 cuBLAS 우위 주장 = 즉시 falsified(GPU.md:84 박제). 이 도메인의 win 은 **오직** 경계 제거(launch + op-boundary fusion + compile-time 특화).
- util≥20% 는 항상 single-driver pod fire verdict 소유 — 소스 단독 주장 금지.
- byte-eq(max|Δ|=0) 는 모든 fusion milestone 의 hard gate — 정확성 없는 가속은 무효.

## ── ② async-launch pipeline — codegen LANDED · util 측정 BLOCKED (seed-drift) ──

W2 가 지목한 binding constraint(인터프리트 per-step 드라이버: ~30 device 커널을 host-sync 로 1개씩 디스패치 → GPU starve)의 **codegen 해제가 main 에 전량 착지**. 4 슬라이스, 전부 async-off byte-identical(CUDA stream-0 = default 의미) + host-ref oracle 19/19 max|Δ|=0:

```
② async pipeline (self/cuda/runtime_cuda_emit.hexa) — single g_forge_stream
├─ #2619 fwd 커널 async (g_forge_stream + _forge_launch_check)      merged
├─ #2621 GEMM stream  (cublasSetStream + _forge_sync @readback)     merged
├─ #2622 bwd/opt 14 launch → g_forge_stream (단일스트림 정합)        merged
└─ #2624 device-resident bwd 9 sync 제거 (cudaDeviceSync→launch_chk) CI
```
async-on 시 학습 1스텝 전체(fwd 커널 + cuBLAS GEMM + bwd 커널 + optimizer)가 **단일 forge-stream** 에서 host readback 경계에서만 sync — per-op host barrier 제거. async **off**(기본) 는 byte-identical 이라 회귀 0. 제외: col2im/adamw(host readback `_d2h_out` 후 sync 필수) · softmax/ce_seed/rmsnorm(default stream).

**util A/B 측정(ASYNC=0 vs =1) = 🔴 BLOCKED** — pool RTX 5070(summer/aiden, $0 렌트) 에서 빌드를 끝까지 추적, **4 블로커 해결**(emit write_file·flatten argv placeholder·nvcc `-x cu`·cuda include) 후 **seed-drift 벽**:
- clm_prod → `nn_gelu_bwd`(hexa) → `forge_dispatch_gelu_bwd`(host C wrapper)
- 그 host wrapper(gelu_bwd·expert_pack2·expert_unpack2·moe_router_bwd 등 W2 device-resident glue)가 로컬 `self/runtime.c` 시드·emit·브랜치소스 어디에도 없음 — W2 pod runtime.c 에 손스플라이스됐다가 로컬 미저장(gitignored seed). `hexa_call4` 타입에러 = hexa_cc.c↔runtime.c 시드 ABI 불일치까지.
- ⇒ GPU 경로는 byte-eq oracle 부재 → 손으로 맞춘 wrapper 로 측정 시 **g5 위반(조용한 오염)**. fabricate 거부, 측정은 시드재구성을 갖춘 별도 검증사이클로 분리. 레시피 전문: memory `project_clmprod_gpu_build_seed_drift`.

**부수 발견 (실버그)**: emit 의 device runtime 쓰기가 `exec("cat > path <<EOF" + c_text + "EOF")` 였는데 c_text>128KB(현재 244KB) 이면 단일 `sh -c` argv 가 `MAX_ARG_STRLEN`(128KB) → E2BIG 로 **조용히 실패**. pool 에서 재현(prebuilt interp + 컴파일 바이너리 양쪽). `write_file`(rt_write_file fopen)로 교체 → byte-identical · #2630. fresh 빌드 호스트의 잠재 wall 제거.

verdict: `.verdicts/hexa-fusion-l1-async/` (async byte-eq) · 측정-block 은 음성-결과로 정직 기록(util 수치 미주장 — single-driver pod fire verdict 부재).

## ── own-GEMM WMMA2 sm_90 (Hopper H100) launch fix — ✅ LAUNCHES · 🔴 PARITY CLOSED-NEG (2026-06-06, g5 verbatim) ──

verdict F-FUSION-WMMA2-SM90-VERIFY(#2796) 진단: own-GEMM `_hx_k_sgemm_cm_wmma2` 가 native **sm_90** 에서 launch 안 됨 — `cudaErrorInvalidValue`. 근인 = STATIC `__shared__` 합 **57344 B**(As 32768 + Bs 16384 + tmp 8192) > sm_90 per-block static cap **49152 B**. Blackwell sm_120 은 더 큰 static admit 으로 통과(README 1.13× = 거기서 측정). Tensor-Core codegen 은 정상(sm_90 SASS HMMA 84) — 실패는 순수 launch-config/shared-mem.

**FIX (dynamic-shared opt-in, 128×64 타일 유지, math byte-identical)**: As/Bs/tmp → `extern __shared__ float hxg_smem[]`(옛 static 과 동일 offset) + launcher/driver 에 `cudaFuncSetAttribute(_hx_k_sgemm_cm_wmma2, cudaFuncAttributeMaxDynamicSharedMemorySize, 57344)` 1회 + `<<<grid,block,57344>>>` 3rd arg. OFF-safe(HEXA_OWN_GEMM_WMMA2 경로만, default cuBLAS 무변).

**native sm_90 측정** (vast 39622686, nvidia-smi `NVIDIA H100 80GB HBM3, compute_cap 9.0`, nvcc 12.4, `-gencode arch=compute_90,code=sm_90`, pod DESTROYED leak 0):
```
wmma2 cudaFuncSetAttribute(maxDynSmem=57344) -> no error
wmma2 launch status: launch=no error  sync=no error   ← LAUNCHES YES (cudaErrorInvalidValue 제거)
3-way ms/iter @ M=N=K=2048, 50 iters:
  cuBLAS (TF32)       : 0.05072 ms/iter   (1.00x)            [~339 TFLOP/s]
  tiled-WMMA2(CUTLASS): 1.49432 ms/iter   (29.46x vs cuBLAS) [~11.5 TFLOP/s]
  tiled-WMMA2 rel-RMS = 4.766e-06  PASS  (TF32 tol 3e-3)
stability re-run 100it: cuBLAS 0.05042 / WMMA2 1.48678 (29.49x) — stable
```
**PARITY-RESTORED: NO**. launch fix 는 성공(sm_90 launch + correctness PASS)이나 native-H100 parity 미회복 — WMMA2 가 cuBLAS 대비 **29.46× 느림**, Blackwell 1.13× 와 무관. 근인(cuobjdump -res-usage): **REG:236/thread**(60416 regs/256-thread block) + 57344 B dyn-smem → H100 65536 regs/SM 에서 **~1 block/SM** = register/occupancy-bound. Blackwell 1.13× 는 sm_120 의 더 큰 레지스터 파일/occupancy 헤드룸에 의존했고 sm_90 으로 **transfer 안 됨**. 정직(g5): cuBLAS = roofline, raw-GEMM 우위 주장 0. **CLOSED-NEGATIVE on sm_90 parity axis** — dynamic-shared opt-in 은 launch 에 필요(충분)하나 parity 엔 불충분; 잔여는 별개 occupancy(레지스터-압) 축. verdict: `.verdicts/hexa-fusion/F-FUSION-SM90-DYNSHARED-FIX.txt`.

## ── own-GEMM cuBLAS-class mainloop sm_90 — ✅ 3/4 levers landed · 🔴 PARITY CLOSED-NEG (mma.sync ceiling) (2026-06-06, g5 verbatim) ──

`F-FUSION-SM90-WARPTILE-RETUNE`(#2800) 가 occupancy 축을 닫고 진단을 inner-loop **math pipeline** 으로 좁힌 뒤, cuBLAS/CUTLASS-class mainloop 기법을 직접 적용. 새 커널 `_hx_k_sgemm_cm_wmma2_cb`(env `HEXA_OWN_GEMM_WMMA2_CB`, default OFF = parent byte-identical).

**LEVERS (3/4 landed, 1 named residual):**
- **L1 ✓ 하드웨어 TF32 mma.sync** — raw PTX `mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32`, round 는 operand 레지스터에서 `cvt.rna.tf32.f32` 로 fuse (parent 의 per-element software `__float_to_tf32` 프래그먼트 스윕 제거). m16n8k8 = 1 native HMMA vs wmma 16x16x8 의 2.
- **L2 ✓ 깊은 cp.async 파이프라인** — HXG_CB_STAGES-deep 링(default 3), wait_group N. on-pod 스윕: 2→11.65, 3→11.55, 4→11.50, 5→10.99 TFLOP/s ⇒ **2-stage 에서 포화**(global→shared latency 가 binding 아님을 2차 확인).
- **L4 ✓ register-blocked epilogue** — thread 당 m16n8 accumulator 4×.f32 레지스터를 col-major C 로 직접 store (shared round-trip/`__syncwarp` 제거).
- **L3 ✗ ldmatrix** — `ldmatrix.x4` 는 `.b16`(16-bit) op, TF32 operand 는 32-bit ⇒ indexed shared load 사용. 32-bit `ldmatrix.trans` swizzle 이 named residual.

**correctness 핵심 수정**: 초기 빌드 rel-RMS 1.0(garbage). m16n8k8 `.tf32` A/B operand k-index 는 `{tig, tig+4}`(fp16-style `{tig*2, tig*2+1}` 아님). standalone mma probe(sm_90)로 canonical layout 확정 → **rel-RMS EXACTLY 0.000e+00**(이 seed 에서 cuBLAS-TF32 oracle 과 bit-exact; parent 는 4.766e-06).

**native sm_90 측정** (vast 39628863, `NVIDIA H100 80GB HBM3, compute_cap 9.0`, nvcc 12.6, `-arch=sm_90`, pod DESTROYED leak 0):
```
cuBLAS-TF32   : 0.051 ms   ~339.7 TFLOP/s   (roofline baseline)
parent WMMA2  : 1.538 ms     11.17 TFLOP/s   30.4× off cuBLAS   rel-RMS 4.77e-06
CB variant    : 1.488 ms     11.55 TFLOP/s   29.4× off cuBLAS   rel-RMS 0.000e+00 (run2 11.54, stable)
REG: parent 240/thr · CB 128/thr (STACK 56)
```
**own GFLOP/s before→after: 11,167 → 11,546 (+3.4%) · gap 30.4× → 29.4× ⇒ ~3.4% of cuBLAS gap closed · PARITY: N.**

**FINDING (CLOSED-NEGATIVE — mma.sync warp-level = ceiling)**: 3개 표현가능 lever 전부 landed + correct 이나 합산 +3.4% 에 그침. stage-depth 가 2 에서 포화(축2 재확인)하는 것과 합쳐, binding constraint 는 **mma.sync 명령어 클래스 자체**. Hopper 에서 cuBLAS 는 **wgmma.mma_async**(warpgroup-level async MMA) + **TMA**(`cp.async.bulk.tensor`)로 TC peak 도달 — mma.sync 가 pipelining/epilogue 튜닝과 무관하게 닿을 수 없는 별개 클래스. 잔여 ~29× 는 wgmma+TMA rewrite(sm_90a-specific, CUTLASS-3.x-class kernel)이지 mainloop retune 아님. 정직(g5): parity-seeking, cuBLAS=roofline, 우위 주장 0. CB 는 env-gated default-OFF 로 ship(parent byte-identical) — 검증된 작은-양성 datapoint + 날카로워진 negative(다음 lever = wgmma/TMA, 명시). verdict: `.verdicts/hexa-fusion/F-FUSION-SM90-CUBLAS-MAINLOOP.txt`.

## ── wgmma.mma_async + TMA own-GEMM sm_90 — ✅ FEASIBILITY PASS · 🟠 layout residual (2026-06-06, g5 verbatim) ──

The residual lever named by `F-FUSION-SM90-CUBLAS-MAINLOOP` (mma.sync ceiling 11.55 TFLOP/s = 29.4× off cuBLAS): the warpgroup-async class. Standalone kit `self/native/wgmma/` — f16 + tf32 wgmma probes, a `cuTensorMapEncodeTiled` + `cp.async.bulk.tensor.2d` + mbarrier TMA pipeline feeding a `wgmma.m64n128k8` warpgroup mainloop, + `build_and_measure.sh`. Native sm_90 H100 (vast 39628805, `NVIDIA H100 80GB HBM3, compute_cap 9.0`, nvcc 12.6, `-arch=sm_90a`, pod DESTROYED leak 0).

**PROBE FEASIBLE: YES.** sm_90a builds clean and **wgmma.mma_async EXECUTES CORRECTLY on native H100** (f16 m64n32k16 probe: nonzero 2048/2048, sum 1962.49 vs ref 1956.87). This converts the prior `F-FUSION-ATTN-WGMMA-WALL` (bc4-r15, 2026-05-28) **hardware-blocked closed-negative** — same wgmma kernel silently NOP'd on Blackwell sm_120 (output all-zero) — into **testable + builds + runs** on real Hopper. The whole Hopper async PTX surface (`cuTensorMapEncodeTiled` driver API + `cp.async.bulk.tensor.2d.shared::cluster.global.mbarrier::complete_tx::bytes` + `mbarrier.init`/`arrive.expect_tx`/`try_wait.parity`) is **ptxas-accepted on sm_90a** (TMA GEMM TMA-BUILD=0). **The own-source emit path is NOT the blocker.**

**RESIDUAL (🟠): the no-swizzle core-matrix shared-memory LAYOUT.** TF32 single-warpgroup mainloop builds + launches but rel-RMS **1.309e+00** (FAIL vs 3e-3). An isolated process-safe (LBO,SBO) descriptor sweep over {16,32,64,128,256,512} found **no combo below 1.309** — descriptor byte-offsets are NOT the binding error. A structured-input diagnostic (C[m][n]=n) confirmed the **accumulator-register → C(row,col) epilogue mapping is CORRECT** (thread 0 receives column-octets 8,16,…,56). The binding residual is the wgmma no-swizzle **8×16B core-matrix tiling** of A/B in shared (a permutation/transpose leaves the contraction ~uncorrelated, rel-RMS ≈ √2); the integrated TMA pipeline additionally faults at runtime (coordinate/mbarrier-phase addressing). Pinning this is the precise CUTLASS-3.x swizzle wedge.

**own GFLOP/s: NOT-REPORTED** (kernel not bit-correct — g5 forbids perf on a wrong-result kernel). **PARITY: NO (not measured). % gap closed: 0% measured.** Honest: parity-seeking, cuBLAS=roofline, no superiority claim. **FINDING** = a POSITIVE feasibility Δ (wgmma+TMA build+run-feasible on native sm_90, vs the prior cannot-test closed-negative) + a sharpened named residual (the ruled-IN axis is operand shared-layout correctness, NOT the instruction/descriptor/epilogue/emit-path). verdict: `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-TMA.txt`.

## ── wgmma no-swizzle layout — 🔴 residual PINNED to B K-core stride (closed-neg) · `F-FUSION-SM90-WGMMA-SWIZZLE` (2026-06-06, g5 verbatim) ──

Resume from `F-FUSION-SM90-WGMMA-TMA`'s rel-RMS 1.309 residual. Native **H200** (Hopper compute_cap 9.0 = sm_90a-identical to H100 for wgmma/TMA), nvcc 12.6 `-arch=sm_90a`, **3 vast H200 contracts (2 RECLAIMED mid-run, re-rented) — all DESTROYED, leak 0**.

**SWIZZLE-FIXED: NO (this pass)** — but the binding residual is now **PINNED to ONE operand + ONE stride** (a strict advance over the prior "operand layout" framing). An **on-hardware reverse-engineering** (distinct-ramp A/B + one-hot selector on the other operand; epilogue independently confirmed correct prior) decoded *exactly what wgmma reads*:

```
B read-map, plain row-major B, desc(lA16 sA32 lB16 sB32):
  KSEL=0: n0->B[0][0]✓  n1->B[0][4]   ok=8/64
  KSEL=1: n0->B[0][1]   n1->B[0][5]   ok=0/64   <- k'=0, NOT k'=1
  KSEL>0: every selector reads k'=0                kslices_active=8/8
```

Two superimposed defects, both in the **wgmma B no-swizzle core-matrix layout**: (1) **K-STRIDE COLLAPSE** — for contraction k=1..7 wgmma re-reads B's K=0 core-matrix (k′ pinned to 0 ∀ KSEL); dominant ≈√2 rms error. (2) **N-OCTET INTERLEAVE** — output col n ← logical col ≈4n within an 8-wide octet.

**RULED OUT deterministically**: a **>2300-config** sweep — A/B shared layout ∈ {plain row-major, two 8-row-strip core tilings, col-major-B} × descriptor (LBO,SBO) ∈ {16,32,64,128,256,512} both operands × 3 epilogue register-maps (fault-isolated per-process) — found **no config below rel-RMS 1.36** (best 1.362, AL0/BL2/EPI0). The residual is **NOT** a plain-layout/offset/epilogue permutation.

**RULED IN (next-cycle, scoped)**: build the B (and A) shared tile via the **CUTLASS `GMMA::Layout` core-matrix builder** — B's 8 K-values as a contiguous 8-row core-matrix, descriptor LBO = one-core-matrix stride, swizzle field matched to the TMA `cuTensorMapEncodeTiled` swizzle (none/32B/64B/128B). Verify FIRST on the single-tile decode probe to **k′==KSEL identity (rel-RMS 0)** before any 2048³ perf run.

**own GFLOP/s: NOT-REPORTED** (g5 — no perf on a wrong-result kernel). single-tile rel-RMS 1.309 · full-GEMM N/A · PARITY: NO · % gap closed: 0% measured · **pod destroyed: YES (leak 0)**. Honest: parity-seeking, cuBLAS=roofline, no superiority claim. Kit: `self/native/wgmma/{wgmma_tf32_decode,wgmma_tf32_bdecode,wgmma_tf32_full}.cu` + `sweep_fast.sh`. verdict: `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-SWIZZLE.txt`.

## ── forge sm_90 own-GEMM parity — CONSOLIDATED FINAL STATE (honest ladder · de-risked OPEN residual) ──

This consolidates the sm_90 own-GEMM parity campaign (four honest-negative
attempts, all verbatim verdicts above). The own-GEMM seeks **parity** with
cuBLAS, never superiority — cuBLAS is the roofline; there is NO own-vs-cuBLAS
superiority claim on any architecture. The measured ladder, each rung a real
on-silicon run with its own verdict:

| rung | kernel | result | gap vs cuBLAS-TF32 | verdict |
|---|---|---|---|---|
| 0 | parent WMMA2 (sm_90 launch-fixed) | rel-RMS 4.77e-06 | **30.4×** off | `F-FUSION-SM90-DYNSHARED-FIX` |
| — | WMMA2-RR (occupancy retune) | 1→2 blocks/SM, −4% | ruled out | `F-FUSION-SM90-WARPTILE-RETUNE` |
| 1 | mma.sync cuBLAS-class mainloop (CB) | bit-exact (rel-RMS 0.000e+00) | **29.4×** off (+3.4%) | `F-FUSION-SM90-CUBLAS-MAINLOOP` |
| 2 | wgmma.mma_async + TMA | FEASIBLE (builds+runs sm_90a) | not measured | `F-FUSION-SM90-WGMMA-TMA` |
| 3 | wgmma no-swizzle bit-correctness | BLOCKED (rel-RMS 1.309) | not measured | `F-FUSION-SM90-WGMMA-SWIZZLE` |
| OG2/3 | wgmma GMMA INTER 8×4 layout | bit-exact (rel-RMS 0) @2048³ | layout SOLVED | `F-FUSION-SM90-WGMMA-GMMA-LAYOUT` |
| OG8 | TMA-producer dual-consumer-WG | bit-exact, **66.9 TFLOP/s** | **6.43×** off (2 CTA/SM) | `F-FUSION-SM90-WGMMA-W8` |
| OG10 | composed swizzle-decode (permute-free) | bit-exact, **70.7 TFLOP/s** ★ TF32 summit | **6.09×** off cuBLAS-TF32 (2 CTA/SM, +5.7%) | `F-FUSION-SM90-WGMMA-W10` |
| OG11 | 128×256 tile (lever-1) | bit-exact, 65.5–66.4 TFLOP/s | 🔴 CLOSED-NEG — occupancy 2→1 CTA/SM (regresses 70.7) | `F-FUSION-SM90-WGMMA-W11` |
| OG12 | tile↔warp-spec coupling | bit-exact, 26.1 TFLOP/s @sub-decode | 🔴 CLOSED-NEG — smem shrink holds 2 CTA/SM but serializes decode↔MMA; setmaxnreg ungrantable | `F-FUSION-SM90-WGMMA-W12` |
| OG13 | deep async decode ring (NSTG-deep gmma scratch) | bit-exact, 51.9 TFLOP/s @NSTG≥2 | 🔴 CLOSED-NEG — 1 CTA/SM (regresses 70.7); **TF32 async-pipeline axis EXHAUSTED** | `F-FUSION-SM90-WGMMA-W13` |
| OG14 | **FP16/BF16** own-GEMM (NEW dtype axis) | bit-exact-vs-same-dtype, **71.6 TFLOP/s** (2 CTA/SM) | **11.5×** off cuBLAS-**FP16** — PARITY NO; OG13 16KB-band overlap REFUTED (.k16 band still 32KB) | `F-FUSION-SM90-WGMMA-W14-FP16` |
| OG15 | descriptor-direct (delete 32KB decode band) | 🔴 **CLOSED-NEG** — single-tile rel-RMS floor **1.000** / GEMM **1.392** (3200-cfg sweep, none 0) → GATE FAIL, no perf | research #2854 FALSIFIED: TMA-SWIZZLE_128B ≢ wgmma Swizzle<3,4,3> for atom-major box. smem 96→**64 KB/CTA** (32KB band IS removable, but read not bit-exact). OG10 70.7 KEPT | `F-FUSION-SM90-WGMMA-W15` |
| OG16 | **canonical-atom match** (route-a: gmma-INTER global pre-permute + NO-swizzle TMA + descriptor-direct, band REMOVED *and* USED) | bit-exact (rel-RMS 0) @2048³ & 4096³, **264.7 TFLOP/s** (3.77× the OG10 frontier, 2 CTA/SM, 96→64KB) | **1.37–1.62×** off cuBLAS-TF32 — OG15 falsifier OVERTURNED, ~85–90% of the gap closed, PARITY NO | `F-FUSION-SM90-WGMMA-OG16` |
| OG17 | **🟢 PARITY** — relaxed-`wait_group 1` ping-pong pipeline (W11 lever-3, reopened by OG16's band removal) on the OG16 tile | bit-exact (rel-RMS 0) @2048³ & 4096³ all NST 3 reps, **280 TFLOP/s** @2048 NST3 (2 CTA/SM) | **1.24× = PARITY YES** @S=2048 (~81% of cuBLAS-TF32); @4096 1.56× (residual = 256-tile reg-realloc, MODE5/W12 closed-neg). 'own-GEMM can't reach cuBLAS-TF32' wall **CLOSED @2048** | `F-FUSION-SM90-WGMMA-OG17` |
| OG18 | **FP16/BF16 canonical-atom port** — the OG16 route-a + OG17 relaxed-pipe recipe re-derived for the f16 .k16 8×8 atom (gmma_phys16), global pre-lay + NO-swizzle TMA, descriptor-direct (the OG14 32KB decode band GONE *and* used) | bit-exact same-dtype (rel_rms **0.000e+00**) single-tile AND full GEMM @2048³ & 4096³, **504.3 TFLOP/s** @4096 (MODE5 128×256 NST3) | **1.64×** off cuBLAS-FP16 — OG14 **13.37×→1.64× CLOSED** (8.2× own lift, same-pod apples: W14 61.2 TFLOP/s on the SAME H100), PARITY NO; recipe GENERALIZES across dtype, residual = pipeline-depth on 2× FP16 roofline. bf16 1.75× | `F-FUSION-SM90-WGMMA-OG18` |
| OG19 | **FP16 relaxed-pipe in the OG17 parity regime** — drive the MODE6 relaxed-`wait_group 1` ping-pong (OG18's f16 pipe, run only @4096 before) at **S=2048** (OG17's TF32 parity spot) + the **NST=2/3/4 ring** across both regimes (deeper ring now band-free) | bit-exact same-dtype (rel_rms **0.000e+00**) at EVERY config @2048³ & 4096³, **505.3 TFLOP/s** @4096 (MODE5 NST4 — new peak) | **best ratio 1.56×** (MODE6 S=2048 NST3) off cuBLAS-FP16 — the relaxed-pipe lever GENERALIZES (same direction as TF32 1.37→1.24×) but **FP16 PARITY NO** (honest **FP16-ceiling**: 2× FP16 roofline + k16 occupancy/ring bound leave a residual the pipeline can't close; NST=4 drops to 1 CTA/SM). NOT regressed below OG18; TF32 PARITY stays banked | `F-FUSION-SM90-WGMMA-OG19` |

**Ladder narrative (honest, g5):**
1. **30.4× → 29.4×** is the only measured improvement: the mma.sync cuBLAS-class
   mainloop (3/4 levers landed — hardware-TF32 `mma.sync.m16n8k8`, deep
   `cp.async` pipeline, register-blocked epilogue; `ldmatrix` did not land) is
   **bit-exact** but closes only ~3.4% of the cuBLAS gap. The binding ceiling
   is the **`mma.sync` warp-level instruction class itself** — on Hopper,
   cuBLAS reaches TC peak via `wgmma.mma_async` (warpgroup-async) + TMA, a class
   `mma.sync` cannot reach by any mainloop tuning.
2. **wgmma + TMA is FEASIBLE on sm_90a** (build + run): `wgmma.mma_async`
   executes correctly and the full Hopper async PTX surface
   (`cuTensorMapEncodeTiled` + `cp.async.bulk.tensor.2d` + `mbarrier.*`)
   compiles and launches. **The own-source emit path is NOT the blocker** —
   this converts the prior hardware-blocked `F-FUSION-ATTN-WGMMA-WALL`
   closed-negative into a testable-on-Hopper problem.
3. **wgmma bit-correctness is BLOCKED** on the no-swizzle B-operand core-matrix
   shared-memory layout: a **K-stride collapse** (k=1..7 re-read B's K=0
   core-matrix) + an **N-octet interleave**, the rel-RMS 1.309 residual. A
   >2300-config exhaustive sweep (layout × descriptor (LBO,SBO) × epilogue
   register-map) found no config below rel-RMS 1.36, **deterministically ruling
   out** the residual being a plain-layout / offset / epilogue permutation.

**NAMED RESIDUAL (concrete next-cycle claim, multi-session):** implement the
real CUTLASS-3.x `GMMA::Layout` core-matrix builder for the B (and A) shared
tile — B's 8 K-values laid out as a contiguous 8-row core-matrix, descriptor
LBO = one-core-matrix stride, swizzle field matched to the TMA
`cuTensorMapEncodeTiled` swizzle mode. Verify FIRST on the single-tile decode
probe to `k′==KSEL` identity (rel-RMS 0) before any 2048³ perf run.

**PARITY framing (g5):** own-GEMM **parity** is achieved only on Blackwell
(the 1.13× iso figure is sm_120-specific). On native sm_90 (Hopper, H100/H200)
parity is **NOT achieved** — it is an **OPEN, de-risked named residual**: the
instruction class (wgmma+TMA) and the emit path are proven feasible; the single
remaining wall is the CUTLASS core-matrix layout above. No perf number is
reported on any non-bit-correct kernel (g5). cuBLAS = roofline; no superiority
claim. Kit: `self/native/wgmma/`. Pods all destroyed across every run (leak 0).

## ── OG15 descriptor-direct — 🔴 CLOSED-NEG (research #2854 FALSIFIED) · `F-FUSION-SM90-WGMMA-W15` (2026-06-06, g5 verbatim) ──

The research deep-dive `#2854` (docs/research/sm90-wgmma-parity-rewrite-deepdive.md) predicted the
OG10/OG11 in-place swizzle floor (rel-RMS 1.392) was a fixable **descriptor-encoding bug** (nonexistent
"MODE5" / compact SBO / dropped base_offset_ phase), and that building the GMMA descriptor with
`layout_type_=1`, `SBO=1024B`, `base_offset_=phase` pointing DIRECTLY at the SWIZZLE_128B-TMA tile
would reach **rel-RMS 0** and let us DELETE the OG10 32KB software decode band — reopening the campaign.
OG15 tested this falsifier on native H100 sm_90a (vast 39738178 DESTROYED leak 0, nvcc 12.6.77 driver
560.35.05 — OG10-apples).

**RESULT: FALSIFIED.** A 3200-config in-process descriptor sweep (layout_type_∈{0,1,2,3} × SBO∈{0..4096}B
× base_offset_∈{0..7} × LBO∈{0..2048}B) **FLOORS at single-tile rel-RMS 1.000** (best @ swm=1 sbo=1024
boff=2) and **full-GEMM rel-RMS 1.392** — NO config reaches 0. The 3 named fixes are each
necessary-DIRECTION-correct (best basin IS swm=1/sbo=1024; base_offset_ moves the residual 1.107→1.000,
confirming the phase axis is real) but **INSUFFICIENT**. A MODE6 localizer (descriptor-direct AND OG10
composed-decode wgmma in the SAME kernel) measured composed_rel=**0.000** (the wgmma+descriptor mechanism
is correct) but desc_rel=**1.107** (the swizzle-mode-1 in-place read is uncorrelated) — pinning the defect
to the **TMA-swizzle ↔ wgmma-swizzle interaction**, exactly the "3rd interaction" OG10 named.

**THE GAP IN THE RESEARCH (precise):** the load-bearing claim "the TMA box swizzle and the wgmma
descriptor swizzle are the SAME `Layout_K_SW128_Atom` (`Swizzle<3,4,3>`) BY CONSTRUCTION" holds **only when
the SMEM layout is BUILT from the atom via `tile_to_shape(Layout_K_SW128_Atom)` and the TMA from THAT SAME
layout** (CuTe's path). Our hand-rolled `cuTensorMapEncodeTiled` box ({32,64} A / {32,32} per B atom) lands
an **atom-major stacking** (MODE2 oracle: g XOR (r&7), atom a @ a*256 floats) — a DIFFERENT byte
permutation than the canonical atom, so `layout_type_=1`'s fixed HW de-swizzle reads the wrong
core-matrices. The research conflated "TMA lands a 128B-swizzled tile" with "TMA lands the EXACT canonical
atom."

**THE DECODE-BAND REMOVAL IS REAL (the one mechanical positive):** OG15 desc-direct smem = **64.0 KB/CTA
@NST=2** vs OG10 **96.0 KB/CTA** = a **32 KB drop**, 2 CTA/SM held. But UNUSABLE — g5 forbids perf on a
wrong-result kernel. own GFLOP/s **NOT-REPORTED**. OG10 frontier re-measured same-pod: **71.0 TFLOP/s, 6.06×,
rel-RMS 0** — KEPT, NO regression. PARITY=NO, cuBLAS=roofline, no superiority claim.

**THE OG11–OG14 "EXHAUSTED" VERDICTS STAND (NOT superseded).** The exhaustion was NOT merely a descriptor
bug — the descriptor-direct alternative is itself blocked by the same swizzle-interaction wall, now measured
at 3200-config resolution. **OG16 frontier** to claim the 32KB prize: MATCH the canonical atom — either (a)
re-encode A/B in GLOBAL so the SWIZZLE_128B TMA lands the canonical `Layout_K_SW128_Atom` byte pattern (then
the field-fix applies), or (b) port `make_gmma_desc`'s EXACT LBO/SBO computation FOR the atom-major layout (a
DIFFERENT descriptor than the canonical one). Both = net-new kernel structure, not a field sweep. The other
reopened levers (128×256 tile / deep-ring / warp-spec setmaxnreg / persistent-collective / split-K /
FP16-reopen) all remain occupancy-gated BEHIND the decode-removal, which is itself gated on canonical-atom
match. Frontier UNCHANGED = OG10 `gemm_w10` (70.7, 6.09×, 2 CTA/SM, bit-exact). verdict:
`.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W15.txt`.

## ── own-GEMM sm_90a OG-ladder (own-GEMM W1→W15, RENAMED OG1→OG15 to disambiguate from the L1 fusion-campaign W1-①…⑨ above): BIT-CORRECT achieved · summit OG10 70.7 · OG11–OG15 closed-neg (2026-06-06, g5) ──

> **Ladder disambiguation:** this `OG#` ladder is the **own-GEMM wgmma perf climb** (forge's
> `self/native/wgmma/*.cu`). It is DISTINCT from the L1 **fusion-campaign** `W1-①…⑨` items near the top of
> this doc (device-resident · async · CUDA-graph · megakernel). The two used the same `W` prefix and collided;
> the perf ladder is now `OG1→OG16`. Verdict slugs keep their on-disk `…-W#` filenames (unchanged on disk).

The breakthrough route is the **own-GEMM** itself (forge's `self/native/wgmma/*` .cu) —
NOT a separate flame/forge mechanism. flame rides forge rides this kernel, so closing
the own-GEMM gap lifts the whole stack automatically. **OG1→OG10 = the measured bit-exact climb to the
70.7 TFLOP/s summit; OG11→OG15 = closed-neg rungs that ALL hit the same 32KB-decode-band-vs-occupancy /
atom-encoding wall (these STAND — NOT superseded; OG15 confirmed the descriptor-direct alternative hits
the same wall).**

- [x] **OG1 GMMA::Layout B-core-matrix builder** ✅ (#2819) — INTER 8×4 TF32 core layout (LBO 128B/SBO 256B).
- [x] **OG2 single-tile identity verify** ✅ (#2819) — rel-RMS **0.000e+00** — the swizzle is SOLVED ★ (the
      no-swizzle 8×16B core-matrix wall above is now CLOSED — the residual was one constant: 8×4 elems, not 8×8).
- [x] **OG3 full wgmma+TMA GEMM bit-correct** ✅ (#2819) — rel-RMS **0 @ 2048³** (own == cuBLAS == CPU-f64);
      2nd bug fixed: wgmma reads shared via the async proxy → needs `fence.proxy.async.shared::cta`.
- [x] **OG4 sm_90 parity measure** ✅ honest — naive single-wgmma/block own **20.2 TFLOP/s**, 17.67× off.
- [x] **OG5 pipeline tune** ✅ — wide-N TN=128 → **38.0 TFLOP/s** (9.35× off), bit-exact.
- [x] **OG6 cp.async multi-stage ring (async-pipe)** ✅ (#2833) — own **38.0 → 50.7 TFLOP/s** @4096³, rel-RMS **0**
      (+33%) → **8.39× off** cuBLAS-TF32 (~422). ~11.5% of gap closed. warp-spec first pass: race fixed
      (`wg_bar`) → rel-RMS 0 but 35.0 only (a SINGLE consumer warpgroup STARVES the tensor cores at TM=64).
- [x] **OG7 dual-consumer-warpgroup warp-spec (TM=128)** — 🔴 CLOSED-NEGATIVE (bit-exact, occupancy-bound).
      BUILT (MODE 3 `gemm_ws2`, 384 thr = 3 WG: 1 cp.async producer WG + 2 consumer WGs each `wgmma` over its
      64-row band × the SHARED B tile) + run on native sm_90a H100 (vast 39651872, DESTROYED leak 0, nvcc 12.5.82).
      **BIT-EXACT** (rel_rms **0** @ S=2048/4096, NST=2..5) but **32.0 TFLOP/s (13.2×) — SLOWER** than OG6 async-pipe
      50.7 (8.39×). OG7 hypothesis FALSIFIED. Root cause (on-pod `cudaOccupancyMaxActiveBlocksPerMultiprocessor`):
      a 128-thread cp.async producer WG at TM=128 is **register-bound to 1 block/SM** (90 regs × 384 thr;
      2 CTAs = 69120 > 65536 regs/SM) → 256 compute-thr/SM vs async-pipe's 4×128 = 512. More consumer WGs cannot win
      while the producer eats a full WG AND evicts the 2nd resident CTA. verdict: `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W7.txt`.
- [x] **OG8 TMA-driven production** ✅ BIG-PROGRESS — `cp.async.bulk.tensor.2d` + a SINGLE elected producer thread
      (freeing 255) → BOTH warpgroups consume, CTA shrinks 384→256 thr. MODE 4 `gemm_ws_tma`. native sm_90a H100
      (vast 39701877, DESTROYED leak 0, nvcc 12.6). **BIT-EXACT** rel_rms **0** @ S=2048..8192. own **50.7 → 66.5
      TFLOP/s** @4096 (+31%; 69.6 @8192) → **6.44×** off cuBLAS. **Occupancy 1 → 2 CTA/SM** (the OG7-predicted fix,
      measured). ~26% of the parity gap closed. PARITY=NO. verdict `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W8.txt`.
- [~] **OG9 swizzled-TMA (drop the per-K-step permute)** — 🟡 CLOSED-NEG (naive) + mechanism PROVEN + frontier KEPT.
      MODE 5 `gemm_ws_tma_sw`: `CU_TENSOR_MAP_SWIZZLE_128B` so the tile lands wgmma-ready. native sm_90a H100
      (vast 39704602, DESTROYED leak 0, nvcc 12.6). **PERMUTE REMOVED — SASS-proven** (gemm_ws_tma STS=28 →
      gemm_ws_tma_sw STS=0, one __syncthreads dropped), **occupancy 2 CTA/SM preserved**. BUT **bit-exact GATE FAIL**:
      rel_rms FLOOR **1.392** across ~100 (lbo×sbo×kstep) descriptor configs (lbo inert) → NO perf number (g5).
      ROOT CAUSE measured: the FP32 128B-swizzle is **g_phys = g XOR ((r+1)&7)** (NOT textbook g XOR r), and it must
      STILL compose with the 8×4 INTER core (gmma_phys) — a two-layer permutation one linear descriptor can't express.
      OG8 66.9/6.41× frontier **KEPT (no regression)**. verdict `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W9.txt`.
- [x] **OG10 composed swizzle decode** ✅ BIG-PROGRESS LIFT (beats OG8) — 🟢 BIT-EXACT + frontier lifted ★ **TF32 SUMMIT**. On-pod
      MODE2/MODE3 dumps RE-MEASURED the true layout and **corrected the OG9 handoff**: the FP32 SWIZZLE_128B law is
      the **textbook g XOR (r&7)** (OG9's (r+1)&7 was a partial-8-row-probe artifact); the wall was the SECOND layer
      (gmma INTER core packing), not the swizzle. The COMPOSED decode (read gmma_phys(m,k) from swizzled slot, pure
      index, no transpose scratch) is **bit-exact**: single-tile GATE 1+2 rel_rms **0.000e+00** (before any big run,
      g5), full-GEMM rel_rms **0** @2048/4096/8192. KEY occupancy fix: gmma scratch = a SINGLE shared buffer (not
      NST-ring-staged) → smem 131→98 KB/CTA → **2 CTA/SM restored**. Same-pod apples: OG8 66.9 (6.43×) → **OG10 70.7
      TFLOP/s (6.09×) @S=4096** (+5.7%, 75.5 @8192; re-measured 71.0/6.06× @OG15-pod), ~6.3% of the gap closed. In-place wgmma HW swizzle descriptor =
      **CLOSED-NEG** (floor 1.392 ~40 cfgs, a 3rd interaction — HW de-swizzle ≠ TMA atom stacking). native sm_90a
      H100 (vast 39707146, DESTROYED leak 0, nvcc 12.6 driver 560.35.05). verdict `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W10.txt`.

**OG11–OG15 — closed-neg rungs (ALL hit the SAME 32KB-band-vs-occupancy / atom-encoding wall; STAND, not superseded):**
- [x] **OG11 research-named top levers** — 🔴 LEVER-1 CLOSED-NEGATIVE (occupancy-coupled) + frontier KEPT (#2850).
      Applied the litscan top-3 levers on the OG10 composed-decode. native sm_90a H100 (vast 39717398, DESTROYED leak
      0). bit-exact rel_rms 0 throughout. **LEVER 1 (128×256 tile, the named +34% jump) REGRESSED**: smem 98→147
      KB/CTA collapses occupancy **2→1 CTA/SM**, own 65.5–66.4 (< 70.6 same-binary baseline, -6.0%); the accumulator-
      reuse gain does NOT cover the halved residency (the litscan Q2-step5 tile↔warp-spec coupling CONFIRMED by
      measurement). LEVER 3 (ping-pong) cannot rescue it. **OG10 70.7/6.09× frontier KEPT — no regression shipped.**
      verdict `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W11.txt`. kernel `self/native/wgmma/wgmma_tf32_w11.cu`.
- [x] **OG12 tile + warp-spec register-realloc (coupled)** — 🔴 CLOSED-NEGATIVE (#2851) — the coupled lever does NOT
      close on this TF32 kernel, on TWO grounds. native sm_90a H100 (vast 39719243, DESTROYED leak 0, nvcc 12.6,
      driver 580.95.05). bit-exact rel_rms 0 throughout. **(b) MODE10 per-K8-sub decode** shrinks the decode scratch
      48KB→12KB → smem 147→**108.0 KB/CTA → 2 CTA/SM RESTORED** (the OG11-pinned occupancy gate MET, 108<114) but own
      **COLLAPSES to 26.1 TFLOP/s** @4096 (ptxas C7511 wgmma serialized; the sub-decode forces a __syncthreads +
      fresh decode per K8 sub-step → serializes decode↔MMA — occupancy was NEVER the wall, decode/MMA OVERLAP is).
      **(a) MODE9 warp-spec setmaxnreg 40/232 UNREALIZABLE**: ptxas C7507 IGNORES it (the 128×256 tile's 128 accum
      regs/thr force min regs) AND the separate-producer-WG mbarrier handshake DEADLOCKED (timeout exit 124). The
      register-realloc the litscan needs is DENIED by the bigger tile's own accumulator footprint. **128×256 output
      tile = DEAD AXIS for this kernel. OG10 70.7/6.09× frontier KEPT — no regression shipped.** verdict
      `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W12.txt`. kernel `self/native/wgmma/wgmma_tf32_w12.cu`.
- [x] **OG13 deep async decode ring** 🔴 CLOSED-NEG — attacked residual (b): ring the gmma decode scratch NSTG-deep
      so decode(N+1) overlaps wgmma(N) (producer-ahead software pipeline, KEEP the OG10 decode-copy per OG12). BIT-EXACT
      at NSTG≥2 (rel_rms 0) but ONE added 32 KB gmma band pushes smem 96→128 KB/CTA → occupancy **2→1 CTA/SM**, and
      the overlap gain does NOT recover the halved occupancy: own **70.7 → 51.9 TFLOP/s @4096 (−27%)**. NSTG 2/3/4 flat
      at 1 CTA/SM. The SAME wall OG12 hit from the other side (OG12 serializes to hold 2 CTA/SM; OG13 overlaps but loses
      it): **2 CTA/SM and decode/MMA overlap are MUTUALLY EXCLUSIVE** for this 128×128 FP32-scratch TF32 kernel. OG10
      70.7 frontier **KEPT (no regression)**. H100 (vast 39725711, DESTROYED leak 0, nvcc 12.6 driver 560.35.03).
      verdict `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W13.txt`.
- [x] **OG14 PRECISION axis — FP16/BF16 own-GEMM (NEW dtype campaign)** ✅ landed correct, 🔴 OG13 thesis refuted
      (2026-06-06). The user-opted-into separate dtype axis after OG13 closed the TF32 async-pipeline. Ported the OG10
      composed-swizzle-decode own-GEMM to 16-bit operands + f32 accumulate (`wgmma.mma_async...m64n64k16.f32.f16.f16`
      and `.bf16.bf16`). **f16 GMMA layout RE-DERIVED** (8×8 core, 128B, vs TF32 8×4); on-GPU MODE2/3 dump confirms
      the SWIZZLE_128B law = textbook g XOR (r&7) on 8-f16 granules, atom-major. **GATE CHANGE (g5, STATED): NOT
      bit-exact-vs-FP64** — precision-appropriate rel_rms ≤1e-2 vs SAME-DTYPE oracle (cuBLAS-FP16/BF16, NOT TF32).
      GATES PASS: MODE0/1/7 rel_rms **0.000e+00**; full GEMM rel_rms **0** (far inside 1e-2). **f16 frontier
      `gemm_f16_w14` NST=2: own 71.6 TFLOP/s @4096 (76.4 @8192), 96 KB/CTA → 2 CTA/SM, cuBLAS-FP16 827.2, ratio
      11.55×, PARITY=NO**. BF16 mirrors (71.1 @4096, 11.48× off cuBLAS-BF16). **🔴 OG13 "16KB band → 2 bands at
      2 CTA/SM reopens the overlap" REFUTED**: f16 wgmma is .k16, so a natural K-slab is 64-wide (one 128B atom),
      band holds 2× K-elems → **32 KB = SAME as TF32**; MODE6 ring bit-exact but every 2nd-band config → 1 CTA/SM →
      regress (50.9 @4096, −29%). The own kernel stays decode/occupancy-bound at ~71-76 TFLOP/s (≈ TF32 OG10 absolute)
      while cuBLAS-FP16 roofline DOUBLED (827 vs 431) → same-dtype ratio WIDENED. **TF32 OG10 70.7/6.09× summit stays
      the TF32 frontier — OG14 is a separate dtype axis, untouched.** NOT the forge BF16-TC megakernel (different
      artifact). native sm_90a H100 (vast 39729157, DESTROYED leak 0, nvcc 12.6 driver 560.35.03). Residual: escape
      the software decode (f16 HW-swizzle in-place — TF32 OG10 MODE5 was closed-neg, f16 unexplored) OR 32-K half-atom
      slab (band → 16 KB). verdict `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W14-FP16.txt`.
- [x] **OG15 descriptor-direct (delete the 32KB decode band)** — 🔴 CLOSED-NEG, research #2854 FALSIFIED (#2855).
      3200-cfg descriptor sweep FLOORS rel-RMS 1.000 single-tile / 1.392 GEMM (none 0). The 32KB band IS removable
      (smem 96→64 KB/CTA, 2 CTA/SM held) but the in-place read is NOT bit-exact: our hand-rolled
      `cuTensorMapEncodeTiled` box lands an **atom-major stacking ≠ the canonical CuTe `Layout_K_SW128_Atom`**, so
      `layout_type_=1`'s fixed HW de-swizzle reads the wrong core-matrices. Confirms OG11–OG14 STAND (the
      descriptor-direct alternative hits the same swizzle-interaction wall). OG10 71.0/6.06× re-measured same-pod, KEPT.
      Full writeup in the OG15 section above. verdict `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W15.txt`.

**The next net-new frontier (the ONLY remaining lever to claim the removable 32KB band):**
- [x] **OG16 — match the canonical CuTe `Layout_K_SW128_Atom`** — 🟢 **LANDED, bit-exact, the wall CRACKS.** Route (a):
      re-encode A/B in GLOBAL into the canonical **gmma-INTER** layout + a **NO-swizzle TMA** so the SMEM tile IS the
      wgmma-ready layout the descriptor addresses, then descriptor-direct (layout_type_=0, SBO=1024B) reads it with **NO
      in-kernel decode band**. The winning member is the cleaner sub-variant the OG15 field-sweep could not reach (the W10
      composed-decode MOVED from the hot loop into a one-time global transform). **single-tile rel-RMS 0.000e+00** (OG15
      floored 1.000) → **full-GEMM rel-RMS 0.000e+00** (@2048³ & @4096³) → perf. **smem 96→64 KB/CTA @NST=2, 2 CTA/SM**
      (the OG15-proven-removable 32KB band now REMOVED **AND USABLE**). **own 70.2 → 264.7 TFLOP/s (3.77×); ratio vs
      cuBLAS-TF32 6.09× → 1.37× (best, S=2048 NST=3) / 1.62× (S=4096 NST=2) = ~85–90% of the gap closed, bit-exact.**
      PARITY (≤1.3×) NOT crossed (best 1.37×) — cuBLAS = roofline, gap-closure NOT superiority. Residual = the now-UNGATED
      perf axis (warp-spec setmaxnreg / larger tile / ping-pong epilogue / deeper ring — the decode⊥occupancy
      contradiction that pinned OG11–OG15 is GONE). One-time pre-permute amortized over K-reuse/batched weights (O(MK+KN)
      vs O(MNK), not in the steady-state hot loop). H100 native sm_90a, nvcc 12.6.77 (W10-apples), pod 39761328 DESTROYED
      leak 0. verdict `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-OG16.txt`.

- [x] **OG18 — FP16/BF16 canonical-atom port: the OG14 11.5×-off-cuBLAS-FP16 wall was the SAME decode-band bound,
      not an FP16-intrinsic limit** — 🟢 **LANDED, same-dtype bit-exact, OG14 gap CLOSED.** Ported the OG16 route-a
      (global pre-lay into the canonical gmma atom + NO-swizzle TMA → descriptor-direct, no in-kernel decode band) +
      OG17 relaxed-`wait_group 1` pipeline to the FP16 `.k16` **8×8** gmma atom (re-derived `gmma_phys16`, differs
      from TF32's 8×4). **GATE FIRST (g5, rel_rms ≤ 1e-2 vs same-dtype cuBLAS-FP16, NOT bit-exact-vs-FP64):**
      single-tile MODE10 sweep → **rel_rms 0.000e+00 @ swm=0 sbo=256 boff=0** (f16 atom MATCHED band-free) → full
      GEMM MODE4/5/6 **rel_rms 0.000e+00** @2048³ & 4096³ → perf. **own 61.2 → 504.3 TFLOP/s (8.2×, MODE5 128×256
      NST3 @4096); ratio vs cuBLAS-FP16 13.37× → 1.64×** (same-pod apples: W14/OG14 rebuilt on the SAME H100 = 61.2
      TFLOP/s / 13.37×). PARITY (≤1.3×) NOT crossed — cuBLAS-FP16 = roofline (~825 @4096, 2× TF32), gap-closure NOT
      superiority. The recipe **GENERALIZES across dtype**: decode-band removal is the dominant lever for both TF32
      (6.09→1.37×) and FP16 (13.37→1.64×). Residual to parity = the same warp-spec / deeper-pipeline gap, now on a
      2× FP16 roofline (NOT layout/correctness — both bit-exact). bf16 same path (467.3 TFLOP/s, 1.75×). H100 native
      sm_90a, nvcc 12.6.77, pod 39772559 DESTROYED leak 0. verdict `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-OG18.txt`.
- [x] **OG19 — apply OG17's relaxed-pipe to FP16 in the OG17 parity regime: does the lever cross FP16 PARITY?**
      🟢 **LANDED, same-dtype bit-exact — HONEST FP16-CEILING, PARITY NO.** OG18 ran the f16 relaxed-`wait_group 1`
      pipe (MODE6) ONLY @S=4096 (1.64×); OG17 crossed TF32 parity (1.24×) specifically @S=2048 NST3. OG19 drives
      MODE6 @S=2048 (the unexplored OG17 sweet spot) + the NST=2/3/4 ring across BOTH regimes (deeper ring now
      band-free). **GATE FIRST (g5):** single-tile + EVERY full-GEMM config **rel_rms 0.000e+00** @2048³ & 4096³.
      **FINDING:** the relaxed-pipe lever GENERALIZES — it LIFTS the S=2048 ratio (MODE6 NST3 **1.56×** vs MODE4
      baseline 1.63×), the SAME direction OG17 saw for TF32 (1.37→1.24×). But **FP16 PARITY NOT crossed**: the
      identical lever lands at 1.56× (not 1.24×) because FP16's roofline is ~2× TF32 — same own TFLOP/s ÷ 2× larger
      cuBLAS-FP16 denominator. Deeper ring (NST=4) drops to 1 CTA/SM (occupancy-bound, not latency-bound) so does NOT
      help. **own 504.3 → 505.3 TFLOP/s (new peak, MODE5 NST4); best ratio 1.64× → 1.56×.** NOT regressed below OG18;
      TF32 PARITY (OG17 1.24×) stays banked; FP16 characterized at its honest best ratio. H100 native sm_90a, nvcc
      12.6.77, pod 39774499 DESTROYED leak 0. verdict `.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-OG19.txt`.

- [x] **TF32 async-pipeline axis EXHAUSTED (OG7–OG15)** — OG8 (TMA-producer) + OG9 (permute-removal) + OG10 (composed
      decode = SUMMIT) + OG11/OG12 (output-tile DEAD, decode/MMA overlap = wall) + OG13 (deeper ring regresses
      occupancy) + OG15 (descriptor-direct FALSIFIED) collectively close the TF32 own-GEMM perf axis at **OG10 70.7
      TFLOP/s, 6.09× off cuBLAS-TF32, 2 CTA/SM, bit-exact**. The remaining lever is **OG16 canonical-atom match** (then
      the removable 32KB band is usable); the **precision change (FP16/BF16, OG14)** is a separate dtype axis already
      measured (own ≈71-76 but cuBLAS-FP16 roofline doubled → ratio widened). **RECOMMEND no auto-fire on the TF32 perf
      axis — OG16 is a deliberate net-new-kernel decision.**


**STATE**: correctness CLOSED (OG2/OG3 bit-exact). Occupancy CLOSED (OG8/OG10 2 CTA/SM). **TF32 summit = OG10
`gemm_w10` 70.7–71.0 TFLOP/s, 6.06–6.09× off cuBLAS-TF32, 2 CTA/SM, bit-exact** (beats OG8 66.5/6.44× by +5.7%).
**OG11→OG15 are all closed-neg on the SAME wall** — the parity gap is structurally bound by the software decode-copy
(32KB band ⊥ occupancy, proven both dtypes OG11–OG14) and OG15 (3200-cfg descriptor sweep) FALSIFIED the
descriptor-direct shortcut: the band IS removable (96→64 KB/CTA) but the read is not bit-exact because the
hand-rolled box lands an atom-major stacking ≠ the canonical CuTe `Layout_K_SW128_Atom`. The ONE named net-new
frontier is **OG16 (match the canonical atom)** — net-new kernel structure, the only lever to make the removable
band usable. The in-place HW-descriptor path stays CLOSED-NEG (OG10). cuBLAS = roofline, no superiority claim.

## 🎯 Session north-star — the 5 axes (2026-06-06)

Pinned by the user as this session's tracked axes. Two upstream "make it work" axes (1,2) + three downstream "reflect it everywhere" axes (3,4,5) that fold the results of 1+2 into the dojo / README / commons. Honest framing throughout: bit-exact gate before perf · cuBLAS = roofline · no superiority claim · util-via-megakernel is already a closed-negative (value = ownership/completeness, not a util win).

| # | axis | what | status |
|---|---|---|---|
| 1 | own-GEMM perf — util on H100 too | sm_90a own-GEMM **OG-ladder** (OG1→OG16; disambiguated from the L1 fusion-campaign W1-①…⑨) toward cuBLAS parity (H100 low-util on D1536 = right-sizing: byte-eq D1536 saturates an RTX 5070 to 98%, an H100 to ~13%). OG6 async-pipe 50.7 (8.39x) -> OG7 dual-consumer closed-neg -> OG8 TMA-producer 66.5 (6.44x, occupancy 1->2 CTA/SM) -> OG9 swizzled-TMA -> **OG10 composed-decode 70.7–71.0 (6.06–6.09x) = TF32 SUMMIT (bit-exact)** -> **OG11→OG15 ALL closed-neg on the SAME 32KB-band-vs-occupancy / atom-encoding wall** (OG11/12 output-tile DEAD, OG13 deep-ring regress, OG15 descriptor-direct FALSIFIED #2854: band removable 96→64KB but read not bit-exact, atom-major ≠ canonical CuTe `Layout_K_SW128_Atom`). **NEW dtype axis OG14 FP16/BF16** — bit-exact-vs-same-dtype, own 71.6 (2 CTA/SM) but **11.5x off cuBLAS-FP16** (roofline doubled). TF32 summit UNTOUCHED. **The ONE net-new frontier = OG16 (match the canonical atom — net-new kernel, NOT a field sweep; deliberate future decision, no auto-fire).** | 🔴 TF32 axis EXHAUSTED at OG10 70.7; OG16 = only remaining lever (canonical-atom match) |
| 2 | cuBLAS-impossible parallel | persistent whole-step megakernel: a persistent kernel CANNOT call cuBLAS, so cuBLAS structurally caps fusion at the GEMM boundary. own-GEMM removed THAT wall (megakernel calls our device GEMM in-line); 2nd wall = the 2 GroupNorm full-y reductions need a grid-sync cooperative kernel (cudaLaunchCooperativeKernel + grid.sync) | GN grid-sync in flight |
| 3 | reflect 1+2 -> dojo | fold the own-GEMM ladder + megakernel-wall story into stdlib/dojo (hexa-cuda track) | downstream of 1,2 |
| 4 | reflect 1+2 -> README | flame.forge.hexa-cuda trinity GPU section (PR #2842 reorganized it); fold the OG8/OG10 numbers + both-walls-closed story | #2842 = 1st pass, numbers TODO |
| 5 | reflect 1+2 -> commons.tape | governance directive capturing own-GEMM-parity + cuBLAS-impossible-megakernel — sign-gated (sidecar sign commons, user-only) | downstream, needs sign |
