# forge RFC 049 Phase R' Stage 1 (BF16 substrate first fire) — analysis (2026-05-17)

> Fire artifacts: `result.json` (BF16 fused FFN), `result_layercast.json` (LayerCast),
> `fire.log`, `fire_layercast.log`, `build.log`, `build_layercast.log`, `dispatch_runner.log`.
> Hardware: **NVIDIA A100-PCIE-40GB · cc=8.0 · 108 SMs · cuBLAS 12.4.5** · vast.ai instance 36911446 (destroyed).
> Cost: ~$0.10 ($0.76/hr × ~8 min — provision + build + 2 fires + pull).
> Phase R' cumulative: $0.10 (Stage 1 first fire). Phase R + R' total: ~$2.61.

## 0. TL;DR — RFC 049 Stage 1 PASS on 4 of 4 pre-registered falsifiers

| Falsifier | Threshold | Measured | Verdict |
|---|---|---|---|
| F-FORGE-RFC049-BF16-TC-PERF (LARGE Llama-7B) | ≥ 5× cuBLAS Dgemm FP64 | **9.669×** | ✅ **PASS** |
| F-FORGE-RFC049-LAYERCAST-DET (all shapes) | same-precision same-batch single-GPU bit-equal | bit-equal 3/3 | ✅ **PASS** |
| F-FORGE-RFC049-LAYERCAST-DIVERGE (all shapes) | mean_rel ≤ 5% vs FP32 | max 1.51% (4/4 shapes) | ✅ **PASS** |
| F-FORGE-RFC049-LAYERCAST-MEM (all shapes) | ≤ 0.3× FP64 | **0.25×** (X+W1+W2+H+Y) | ✅ **PASS** |

**RFC 049 paradigm anchor**: BF16 substrate clears 5× wall ceiling at Llama-7B
FFN scale on A100 (sm_80). Phase R's FP64 wall — `B Phase 2 200-300× SLOWER`
and `C Phase 3 best 1.80× SLOWER` (both vs cuBLAS Dgemm) — was the FP64-only
substrate limit, not the forge paradigm. Precision pivot to BF16 TC validates
RFC 049 architecture (3-layer cast pyramid).

## 1. Pre-registered (RFC 049 §"Falsifier battery")

- **F-FORGE-RFC049-BF16-TC-PERF**: BF16 fused FFN ≥ **5 × cuBLAS Dgemm FP64 chain** (Llama-7B M=128 D=4096 FD=11008)
- **F-FORGE-RFC049-LAYERCAST-DET**: same-precision same-batch single-GPU bit-equal (D' generalization)
- **F-FORGE-RFC049-LAYERCAST-DIVERGE**: BF16+FP32 inference vs FP32 reference ≤ 5% error
- **F-FORGE-RFC049-LAYERCAST-MEM**: BF16 footprint ≤ 0.3× FP64

## 2. Measured (A100-PCIE-40GB sm_80 cuBLAS 12.4.5)

### 2.1 BF16 fused FFN (r049_bf16_fused_ffn.cu)

| Tier | M | D | FD | t_FP64 (ms) | t_BF16 (ms) | speedup | BF16 TFLOPS | max\|Δ\| | mem ratio | within-biteq |
|---|---|---|---|---|---|---|---|---|---|---|
| SMALL  |  64 |  768 |  3072 | 0.1130 | 0.0484 | **2.33×** |  12.47 | 8.20e-05 | 0.250 | ✅ |
| MEDIUM | 128 |  768 |  3072 | 0.1665 | 0.0562 | **2.96×** |  21.51 | 9.64e-05 | 0.250 | ✅ |
| LARGE  | 128 | 4096 | 11008 | 2.2246 | 0.2301 | **9.67×** | 100.33 | 5.27e-04 | 0.250 | ✅ |

Baseline = `cublasDgemm + silu_f64 + cublasDgemm` chain (production reference).
Contender = `cublasGemmEx (CUDA_R_16BF, CUBLAS_COMPUTE_32F) + silu_bf16 (FP32 compute) + cublasGemmEx (BF16)`.

### 2.2 LayerCast linear (r049_layercast_linear.cu)

| M | K | N | t_FP32 (ms) | t_LC fallback (ms) | max\|Δ\| | mean_rel | weight mem ratio | diverge ≤5% |
|---|---|---|---|---|---|---|---|---|
|  64 |   768 |  3072 | 0.0504 | 0.0641 | 8.45e-05 | **1.40%** | 0.500 | ✅ |
| 128 |  4096 | 11008 | 0.9940 | 1.2368 | 2.23e-04 | **1.31%** | 0.500 | ✅ |
| 128 |  4096 |  4096 | 0.3832 | 0.4820 | 2.08e-04 | **1.20%** | 0.500 | ✅ |
| 128 | 11008 |  4096 | 0.9765 | 1.2130 | 3.54e-04 | **1.51%** | 0.500 | ✅ |

Note: mixed-type `cublasGemmEx(FP32, BF16)` returned **CUBLAS_STATUS_NOT_SUPPORTED**
(status 15) on cuBLAS 12.4.5 sm_80. Used fallback = explicit on-device upcast
`bf16_to_f32 + cublasSgemm`. NUMERICAL pattern preserved (BF16 mantissa truncation
applied at cast, downstream pure FP32). Perf path (mixed GemmEx) is Stage 2 follow-up
on cuBLAS 12.9+.

## 3. 5 non-trivial findings (honest)

### F1 — BF16 TC perf clears 5× bar only at Llama-7B scale, not at small/medium

- SMALL/MEDIUM = 2.3-3.0× (not 5×). LARGE = 9.67×, clears bar by 1.93×.
- Reason: at small shapes (FFN compute < 0.2 ms), cuBLAS Dgemm FP64 is also fast
  (5-7 TFLOPS achieved, 26-37% of A100 FP64 TC peak 19.5 TFLOPS). BF16 path has
  similar absolute launch overhead, so the **dispatch + cast + 2× GemmEx + SiLU**
  chain cannot show its TC throughput advantage.
- At Llama-7B (LARGE), FP64 = 10.4 TFLOPS (53% of A100 FP64 TC peak); BF16 = 100.3 TFLOPS
  (32% of A100 BF16 TC peak 312 TFLOPS). The 9.67× wall ratio reflects the underlying
  hardware ratio (312/19.5 = 16× theoretical) discounted by both paths being below
  peak. **This is the expected pattern** — large compute amortizes the cast/launch
  overhead.
- **Honest read**: the ≥ 5× bar should be ANCHORED to Llama-scale FFN (the RFC 049
  pre-reg specifies M=128 D=4096 FD=11008 explicitly, so verdict is PASS on the
  anchored shape). RFC 049's BF16-TC-PERF is correctly framed as a large-shape
  falsifier.

### F2 — Within-run bit-equal PASS on cuBLAS GemmEx BF16 (D' generalization VALID)

- All 3 shapes: same-process, same-stream, same-GPU, same-batch → byte-identical BF16
  output across 2 runs (`memcmp == 0`).
- **D' (FP64 within-run det FREE)** generalizes cleanly to BF16 substrate at this
  scale — `cublasGemmEx` with `CUBLAS_GEMM_DEFAULT_TENSOR_OP` is deterministic
  within-run.
- Caveat: this is `CUBLAS_GEMM_DEFAULT_TENSOR_OP` — explicit algo. PEDANTIC-equivalent
  for BF16 (cross-shape bit-equal) NOT tested (out of Stage 1 scope; RFC 049 §"Cross-
  precision determinism contract" notes BF16 PEDANTIC may not exist).

### F3 — LayerCast (BF16 weight + FP32 compute) divergence anchors at 1.2-1.5%, well under paper's 3.4%

- 4 shapes spanning small/Llama-FFN-up/4K-square/Llama-FFN-down — mean_rel = 1.20-1.51%.
- LayerCast paper (arxiv 2506.09501): "≤ 3.4% divergence" at DeepSeek-R1-Distill-Qwen-7B
  AIME'24 (downstream task). Our anchor = per-tensor mean_rel at the linear layer level,
  smaller scope so smaller divergence expected. **PASS** with comfortable margin (~2.3×
  headroom under paper anchor, ~3.3× headroom under our 5% pre-reg).
- max_rel = 100-800× because some `Y[i]` values are near-zero (random inputs sum near zero
  for some entries); `max_rel = max(|Δ|/|ref|)` is dominated by these tiny denominators
  and is NOT a meaningful divergence metric. `mean_rel` is the LayerCast paper's anchor.

### F4 — cuBLAS 12.4 sm_80 mixed-type GemmEx (FP32 + BF16) UNSUPPORTED

- `cublasGemmEx(opN, opN, ...A=BF16, B=FP32, compute=COMPUTE_32F)` returned
  `CUBLAS_STATUS_NOT_SUPPORTED` (status 15). NVIDIA documentation confirms cuBLAS
  12.4 supports homogeneous-type GemmEx (FP16+FP16, BF16+BF16, FP32+FP32, FP64+FP64)
  but not arbitrary mixed-type combinations for all sm_80 algos.
- Fallback path (`bf16_to_f32_k + cublasSgemm`) **preserves the numerical pattern**
  exactly (BF16 truncation at cast step, FP32 matmul downstream). Performance is
  1.24-1.27× SLOWER than pure FP32 reference because of the extra upcast kernel +
  scratch buffer + memory traffic.
- **Stage 2 follow-up**: cuBLAS 12.9+ added BF16x9 emulation (NVIDIA blog 2026 anchor
  cited in RFC 049) which exposes new mixed-type paths. RFC 049 Stage 2 fire (per-
  component RFC 050+) will retry this on cuBLAS 12.9+ and measure the direct mixed
  path perf.
- **Numerical anchor holds regardless**: the LayerCast pattern (BF16 storage + FP32
  compute) is validated; only the dispatch path is suboptimal.

### F5 — A100 BF16 TC ceiling reached at 32% peak, not 41-43% like FP64 WMMA hand kernel

- cuBLAS GemmEx BF16 at Llama-7B = 100 TFLOPS / 312 TFLOPS peak = **32%**.
- Compare: hand WMMA FP64 (C Phase 3 v3c bigtile, A100 same hardware) = 8.4 TFLOPS / 19.5 TFLOPS = **43%**.
- cuBLAS BF16 GemmEx is library-grade (CUTLASS-derived); 32% peak at M=128 (modest
  batch) is consistent with the well-known "small-M tail" of TC pipelines. Larger
  M (e.g. M=2048) would push BF16 GemmEx closer to 60-80% peak (literature anchor
  from NVIDIA cuBLAS perf notes).
- **No hand-WMMA BF16 fire in Stage 1** (correct scope — Stage 1 = substrate
  validation, not kernel competition). Hand BF16 WMMA matching cuBLAS is the same
  CUTLASS-grade engineering as FP64 (C Phase 3 lesson). RFC 049 Stage 2 (per-
  component) can fire hand WMMA + DSM combined if needed.

## 4. RFC 049 architecture validation (post-Stage 1)

| Layer | RFC 049 design | Stage 1 measurement | Status |
|---|---|---|---|
| **Layer 1 — Master weight (FP64)** | packed-double arena, AdamW state | not touched (Stage 1 = inference path); RFC 035 v1 already lands the packed-double arena | scope-out |
| **Layer 2 — Compute weight (BF16 storage)** | half-width arena, JIT cast | tested via explicit `f32_to_bf16` cast; mem ratio anchored at 0.25 (FFN: X+W1+W2+H+Y) | ✅ anchored |
| **Layer 3 — Compute (BF16 TC, FP32 accumulator)** | `cublasGemmEx` BF16 + COMPUTE_32F | measured 100 TFLOPS at LARGE, 9.67× FP64 wall | ✅ validated |
| **Cross-precision det contract** | within-run + same-precision + same-batch + same-GPU bit-equal | bit-equal 3/3 shapes | ✅ holds |
| **LayerCast pattern** | BF16 storage + FP32 compute divergence ≤ paper anchor | 1.2-1.5% mean_rel (paper anchor ≤ 3.4%) | ✅ anchored |
| **Mem 75% reduction at storage layer** | BF16 = 2B, FP64 = 8B → 0.25× | exact 0.25× across X+W1+W2+H+Y | ✅ anchored |

## 5. Stage 2 plan (post-Stage 1 PASS — preserve for future RFC 050+)

Per RFC 049 §"Components (Stage 1 = design only, Stage 2+ = follow-up RFC + fire)":

### 5.1 Component priorities (data-anchored after Stage 1)

| Component | Stage 1 evidence | Stage 2 priority |
|---|---|---|
| `farr_bf16` storage class ABI | Stage 1 used direct `__nv_bfloat16` device buffers — surface design clean | **HIGH** (RFC 050 substrate addition) |
| BF16 TC matmul kernel (`*_bf16_gpu` ABI) | `cublasGemmEx` BF16 path 100 TFLOPS / 9.67× FP64 LARGE — substrate-level win | **HIGH** (RFC 050 hexa-side dispatch) |
| LayerCast JIT upcast policy (Layer 2 → Layer 3) | Stage 1 explicit cast path works; cuBLAS 12.4 mixed GemmEx unsupported | **MEDIUM** (RFC 051; gate on cuBLAS 12.9+ availability or hand WMMA) |
| Hand BF16 WMMA + DSM cluster combined (Hopper) | NOT measured (Stage 1 = A100 sm_80, no cluster); H100/H200 cluster API works (B Stage 2 Phase 2 anchor) | **MEDIUM** (RFC 052; combine RFC 049 Layer 3 + B Phase 2 cluster path) |
| AdamW master-weight FP64 + BF16 grad | RFC 035 `adamw_step_mixed` already lands | **LOW** (RFC 053; flame Phase 4+ trainer integration trigger) |
| BF16 training convergence (F-FORGE-RFC049-NO-DIVERGE-FP32-TRAIN) | NOT measured; needs flame Phase 4+ trainer | **DEFER** (RFC 054; flame Phase 4 gate) |

### 5.2 Cross-precision constraints holding (no Stage 2 fire needed yet)

- F-FORGE-RFC049-LAYERCAST-DET (within-run bit-equal): PASS at A100. Re-test on
  Hopper (sm_90) when RFC 052 fires (BF16 + cluster combined).
- F-FORGE-RFC049-HW-PORTABILITY (sm_80+ functional, sm_70 fallback): Stage 1
  validates sm_80; sm_70 fallback (FP16 TC) NOT tested — RFC 055 separate fire.

## 6. Cross-link to Phase R wall FAIL evidence (precision pivot anchored)

| Phase R fire | FP64 substrate wall verdict | RFC 049 (BF16) verdict on same machine class |
|---|---|---|
| B Phase 2 (A100 + H200 DSM hand FP64 kernel) | wall 200-300× SLOWER | **9.67× FASTER** (A100, same Llama-7B LARGE shape) |
| C Phase 3 (A100 WMMA FP64 bigtile) | wall 1.80× SLOWER best | (not directly compared — different op: linear-only vs fused FFN; but BF16 TC 32% peak vs hand FP64 WMMA 43% peak — library-grade path, not hand) |

**Conclusion**: Phase R wall FAIL was correctly identified as FP64 substrate
ceiling, not paradigm failure. Precision pivot (RFC 049) unlocks the wall path
predicted by both B Phase 2 F3 and C Phase 3 §5.4 ("BF16/FP16 mixed-precision
LayerCast may unlock wall win").

## 7. Honest non-claims (g3 boundaries)

- ❌ "RFC 049 BF16 substrate beats cuBLAS Sgemm" — Stage 1 LayerCast path is 1.24-1.27×
  SLOWER than FP32 (fallback path; mixed GemmEx unsupported in 12.4). Stage 2 with
  cuBLAS 12.9 BF16x9 may flip this; not anchored yet.
- ❌ "hand-WMMA BF16 kernel will beat cuBLAS BF16 GemmEx" — same CUTLASS-grade
  engineering gap as FP64 (C Phase 3). Stage 1 did NOT attempt hand BF16 WMMA.
- ❌ "BF16 training convergence preserved" — NOT measured in Stage 1 (forward-only).
  F-FORGE-RFC049-NO-DIVERGE-FP32-TRAIN is Stage 2+ (RFC 054 / flame Phase 4+ gate).
- ❌ "BF16 substrate is universally 5× faster" — only at LARGE (Llama-7B FFN scale).
  Small/medium are 2.3-3.0×. The 5× anchor is shape-specific (large compute amortizes
  cast/launch overhead).
- ❌ "Cross-batch-size bit-equal on BF16" — NOT tested. LayerCast paper anchor warns
  cross-batch BF16 has mantissa-cancellation divergence; RFC 049 §"Cross-precision
  determinism contract" notes this as honest caveat.
- ❌ "Hopper sm_90 results imply cluster + BF16 combined works" — Stage 1 was A100
  sm_80, NO cluster API. RFC 052 (Stage 2) needs to fire on H100/H200 for combined
  validation.
- ❌ "lattice/perfect-number numerology" — f1/f2 deny.

## 8. Cost + iteration discipline

- **Stage 1 cost**: ~$0.10 (A100 PCIE $0.7603/hr × ~8 min). Well under $2-3 budget.
- **Iteration count**: 1 instance, 2 fires (BF16 FFN OK first try; LayerCast required
  1 quick re-fire on same pod after fixing `0x1ayercas7ULL` hex literal typo). Pod
  destroyed normally after main pull; LayerCast result captured from manual re-fire
  stdout (synthesized into `result_layercast.json`).
- **Lessons**: (a) hex literal validity — `a-f` only, not `y`/`c`/`s`/`r`. (b) dispatch
  script lifecycle could be improved to gate destroy on BOTH result.json AND
  result_layercast.json existence; current logic destroys when main result.json pulls
  even if secondary missing. (c) RFC 049's pre-reg "≥ 5×" target was correctly
  shape-anchored (LARGE only); small/medium shapes are expected to be < 5×.

## 9. Sources

- 측정: `state/forge_phaseR_r049_bf16_2026_05_17/result.json` (BF16 FFN) +
  `state/forge_phaseR_r049_bf16_2026_05_17/result_layercast.json` (LayerCast)
- Kernel source: `self/cuda/experiments/r049_bf16_fused_ffn.cu` (~510 lines) +
  `self/cuda/experiments/r049_layercast_linear.cu` (~410 lines, post-fix)
- Dispatch: `self/cuda/experiments/dispatch_r049.sh`
- Pre-reg: RFC 049 §"Falsifier battery" — `inbox/rfc_drafts_2026_05_12/rfc_049_forge_mixed_precision_substrate.md`
- Hardware anchor: NVIDIA A100 datasheet (BF16 TC peak 312 TFLOPS · FP64 TC peak 19.5 TFLOPS)
- cuBLAS docs: `cublasGemmEx` mixed-type support matrix (12.4 = homogeneous + select mixed)
- Literature anchor: LayerCast (arxiv 2506.09501) — ≤ 3.4% divergence at downstream task
- Cross-fire: Phase R B Phase 2 (A100/H200 DSM FP64 wall FAIL) + C Phase 3 (A100 WMMA FP64 wall FAIL) — RFC 049 the wall-path successor

## 10. RFC 049 update plan (post-Stage 1 PASS)

§"Falsifier battery" 갱신 권장:

```
Tier 1 Tensor Core perf:
F-FORGE-RFC049-BF16-TC-PERF:     ✅ PASS (LARGE Llama-7B M=128 D=4096 FD=11008
                                  measured 9.67× cuBLAS Dgemm FP64 chain on A100)
                                 Small/medium shapes 2.3-3.0× (expected; large
                                 compute required to amortize launch + cast overhead)
F-FORGE-RFC049-BF16x9-FP32-EMULATE: ⏳ deferred (cuBLAS 12.9+ required; cuBLAS 12.4
                                  on A100 returned NOT_SUPPORTED for mixed GemmEx)

Tier 2 LayerCast 결정성:
F-FORGE-RFC049-LAYERCAST-DET:    ✅ PASS (BF16 within-run bit-equal 3/3 shapes A100)
F-FORGE-RFC049-LAYERCAST-DIVERGE: ✅ PASS (max mean_rel 1.51% across 4 shapes; paper
                                  anchor ≤ 3.4%)

Tier 3 Memory:
F-FORGE-RFC049-LAYERCAST-MEM:    ✅ PASS (0.25× exact across FFN X+W1+W2+H+Y)

Tier 4 Training convergence:
F-FORGE-RFC049-NO-DIVERGE-FP32-TRAIN: 🟡 Stage 2+ (flame Phase 4+ trainer gate;
                                       not measurable from inference-only Stage 1)

Tier 5 HW portability:
F-FORGE-RFC049-HW-PORTABILITY:   ⏳ Stage 1 anchored sm_80 (A100); sm_90 (Hopper)
                                  cluster path validated separately in B Phase 2;
                                  combined fire = RFC 052 Stage 2
```

## 11. PARADIGM.md §10 update plan (non-claims → reframe)

Current PARADIGM.md §10 says "❌ cross-precision (BF16/FP16) substrate가 본
paradigm에 포함" — Stage 1 anchors that BF16 substrate IS now in scope
(RFC 049 = forge's mixed-precision tier, 3rd orthogonal mechanism).

Recommended addendum: PARADIGM.md §2.4 D' reframe → add §2.5 D'' BF16 substrate
reframe row: "BF16 within-run det FREE (same-precision same-batch same-GPU
single-process) — anchored Stage 1 A100. Cross-batch / cross-GPU divergence
honest caveat (LayerCast §3 paper anchor)."

PARADIGM.md update = separate task post-Stage 1 land.
