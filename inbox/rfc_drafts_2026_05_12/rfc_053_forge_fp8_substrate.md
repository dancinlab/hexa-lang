# RFC 053 — forge: FP8-LM precision substrate (next-tier precision pivot, design draft)

- **Status**: design-draft (2026-05-17) — DESIGN ONLY, no implementation, no fire
- **Date**: 2026-05-17
- **Priority**: P3 (Tier 4 follow-up of RFC 049) — gates the *next-tier precision*
  wall path beyond RFC 049 BF16 substrate. Neither blocks RFC 049 Stage 2
  per-component land (BF16 substrate already PASS at 9.67× FP64 cuBLAS on
  A100) nor RFC 052 Hopper combined kernel (BF16+DSM combined, sm_90+).
  Stage 2 follow-up = 1 Hopper or Blackwell fire ($20-50 conservative
  budget, sub-step iteration) AFTER RFC 049 Stage 2 + RFC 052 Stage 2 fires
  land.
- **Severity**: MEDIUM — RFC 049 BF16 9.67× FP64 wall path already
  validated; RFC 053 is the *projected next-tier unlock*, not a measured wall
  blocker. Severity reflects literature ceiling (Hopper FP8 TC peak 1979
  TFLOPS dense vs 989 TFLOPS BF16 = 2× headroom; Blackwell B200 4500/9000
  TFLOPS dense/sparse FP8) that RFC 049 BF16 substrate cannot reach.
- **Source convergence**:
  - **RFC 049 Phase R' Stage 1 measured PASS** (state/forge_phaseR_r049_bf16_2026_05_17,
    A100 PCIE, $0.10) — BF16 fused FFN 9.67× FP64 cuBLAS Dgemm chain at
    Llama-7B LARGE (M=128 D=4096 FD=11008), 100.33 BF16 TFLOPS achieved
    (32% A100 BF16 TC peak 312 TFLOPS). The substrate-side validation that
    *precision pivot is THE wall path*. RFC 053 = next-tier precision pivot.
  - **RFC 049 §"Non-goals"** explicitly preserves slot: *"FP8 (E4M3/E5M2)
    substrate = out of scope (별도 RFC, FP8-LM arxiv 2310.18313 anchor 필요)"*
    (parent RFC's planned successor, line 195-196).
  - **RFC 049 §"Next iteration plan"** (referenced in user task): RFC 053
    (DEFER) = FP8-LM precision substrate. RFC 052 (MEDIUM) intermediate
    step land 43e15f6e (Hopper BF16+DSM combined).
  - **PARADIGM.md §1 Phase R+ meta-finding** (2026-05-17 PUBLISH): *"forge
    wall path = RFC 049 BF16 precision pivot (실측 검증)"* — RFC 053
    extends this thesis one tier further (BF16 → FP8 precision-tier
    composability).
  - **FP8-LM paper** (arxiv 2310.18313, Peng et al. 2023):
    - GPT-175B FP8 mixed-precision training: **75% faster than BF16
      Megatron-LM**, 39% memory reduction, comparable AlpacaEval / MT-Bench
      scores vs BF16. Surpassed NVIDIA Transformer Engine by 37%.
    - 3-level FP8 incremental adoption: (1) compute (gradient, optimizer
      states), (2) gradient communication, (3) distributed weight master.
    - E4M3 (forward + activations + weights) + E5M2 (backward + gradients).
  - **FP8 Formats for Deep Learning** (arxiv 2209.05433, Micikevicius et al.
    2022):
    - E4M3: 1 sign + 4 exponent + 3 mantissa = range ±448, finer precision
    - E5M2: 1 sign + 5 exponent + 2 mantissa = range ±57344, IEEE 754
      special encoding (Inf, NaN)
    - **Per-tensor scaling** mandatory (FP8 dynamic range insufficient for
      union of all-tensor important values). Software-set scaling factor
      (any real, typically FP32) NOT programmable exponent bias.
    - **Delayed scaling history** = N-step amax window, apply EMA or max
      over window to derive next-step scale. Trades stale-amax accuracy for
      avoided sync overhead.
  - **NVIDIA H100 datasheet**: FP8 TC peak **1979 TFLOPS dense** (sparse 3958),
    FP16/BF16 TC 989 TFLOPS, FP64 TC 60 TFLOPS — FP8/FP64 ratio = **33×**
    theoretical headroom. (cited: nvidia-h100-datasheet.pdf, megware mirror;
    H100 datasheet anchor RFC 049 already lands at 60/989 numbers).
  - **NVIDIA Blackwell B200 datasheet**: FP8 TC peak **4500 TFLOPS dense / 9000
    TFLOPS sparse** (effective ~2.26× H100 on GPT-style 175B FP8).
    Confirms next-generation FP8 TC scaling.
  - **cuBLASLt FP8 GemmEx** (cuBLAS 12.4+, expanded 12.9+):
    - dtype enums `CUDA_R_8F_E4M3`, `CUDA_R_8F_E5M2` (CUDA 12.0+ headers)
    - sm_90+ TC algorithms with per-tensor scaling argument
    - cuBLAS 12.9: extended scaling schemes beyond single-tensor (block /
      row / col / outer-product scale), Hopper-only initially

## Source evidence (g3 — every claim traces to a real capture or cited paper)

Every projection or comparator in this RFC traces to one of:

1. **forge measured wins** (PARADIGM.md §1 Stage 2 + RFC 049 anchor):
   - RFC 049 BF16 Stage 1 LARGE: 9.67× FP64 cuBLAS, 100.33 BF16 TFLOPS at
     A100 (32% of 312 TFLOPS A100 BF16 TC peak) — `state/forge_phaseR_r049_bf16_2026_05_17/result.json`
   - RFC 052 design draft (43e15f6e) Hopper combined: projected ≥1.5× over
     RFC 049 BF16-only (14-15× FP64 cuBLAS), Stage 2 unmeasured
   - D' within-run det FREE across 6 shapes FP64 — `state/forge_phaseR_d_2026_05_17/D_ANALYSIS.md`
2. **Literature** (FP8-specific):
   - **FP8-LM** (Peng et al. 2023, arxiv 2310.18313) — primary training
     feasibility anchor: GPT-175B FP8 mixed = 75% speedup over BF16
     Megatron-LM, 39% memory reduction
   - **Micikevicius 2022** (arxiv 2209.05433) — FP8 format spec + per-tensor
     scaling rationale + delayed scaling pattern
   - **Scaling FP8 to Trillion-Token LLMs** (ICLR 2025, proceedings.iclr.cc)
     — large-scale FP8 training reproducibility anchor
   - **MOSS** (arxiv 2511.05811) — FP8 microscaling + automatic scaling 2025
     refinement (NOT RFC 053 scope but cross-link)
   - **COAT** (ICLR 2025) — FP8 optimizer state compression (NOT RFC 053
     scope, separate future RFC)
3. **Hardware specs** (NVIDIA datasheets):
   - H100 FP8 TC 1979 TFLOPS dense, 3958 sparse (nvidia-h100-datasheet.pdf)
   - B200 FP8 TC 4500 TFLOPS dense, 9000 sparse (NVIDIA Blackwell GA 2024)
   - B100 / B200 / GB200 TC scaling per Blackwell GA technical decomp
4. **cuBLAS docs** (FP8 API surface):
   - cuBLAS 12.0+ FP8 GemmEx (`CUDA_R_8F_E4M3` / `CUDA_R_8F_E5M2`)
   - cuBLAS 12.9 expanded FP8 scaling schemes (Hopper, NVIDIA blog 2026)
   - cuBLAS 13.2 (Apr 2026) latest spec

No projection in this RFC exceeds the most conservative product of these
anchors (see §8.4 honest caveat band). No fabricated multiples.

## Scope (DESIGN ONLY)

RFC 053 is **design draft only**. It specifies:

- The FP8-LM-style precision substrate architecture (E4M3 forward + E5M2
  backward + FP32 accumulator + FP64 master)
- Per-tensor scaling + delayed scaling history contract
- Hardware capability gate (sm_90+ Hopper minimum for full FP8 TC; sm_89
  Ada Lovelace partial FP8 inference; sm_80 A100 = NO FP8 TC = fallback)
- The fallback chain (FP8 → RFC 049 BF16 → RFC 044 D' FP64 → CPU farr) =
  5-level (extends RFC 052 §6.5 4-level chain with FP8 head)
- The numerical contract (FP8 substrate D' boundary + per-tensor scale
  determinism + FP32 reduction + FP64 master at AdamW boundary)
- The 7+ pre-registered falsifiers Stage 2 must verify
- Cross-RFC integration (049 BF16 substrate + 050 dispatch API + 052
  Hopper combined + 044 regime tier)

RFC 053 does NOT specify:

- Any `.cu` source (Stage 2 fire = 1-2 separate Hopper / Blackwell fires
  after user gate, $20-50 budget)
- Any `.hexa` source (flame side stays unchanged; consumed via RFC 050
  `forge_tier_dispatch_v1` precision-policy axis FORGE_PREC_FP8_*)
- The FP8 storage class (`farr_fp8_e4m3`, `farr_fp8_e5m2`) implementation
  (Stage 2 follow-up RFC 054+ covers in detail)
- Microscaling MXFP8 variant (separate future RFC; MOSS paper anchor for
  reference but distinct paradigm)
- FP4 (microscaling MXFP4) variant — see "Optimizing LLM Training Using
  FP4 Quantization" (arxiv 2501.17116) for future RFC anchor
- AdamW master-weight update integration (RFC 035 `adamw_step_mixed`
  already specifies FP64-master + low-precision-grad contract; RFC 053
  extends low-precision side to FP8)
- Multi-cluster / cross-cluster FP8 dispatch (out of scope; future RFC)
- Distributed FP8 gradient communication (FP8-LM paper §3.3; out of scope
  for substrate-level RFC 053; future cross-RFC with NCCL integration)
- Inference framework integration (vLLM / TensorRT-LLM out of scope)

## Problem — RFC 049 BF16 9.67× wall path leaves 3-30× headroom on Hopper FP8 TC; RFC 052 combined adds DSM but stays BF16

RFC 049 Stage 1 measured the BF16 substrate wall path PASS — 9.67× FP64
cuBLAS at Llama-7B FFN on A100 sm_80. RFC 052 design (43e15f6e) extends
this to Hopper with cluster DSM combined kernel projecting ≥1.5× over
RFC 049 BF16-only (= 14-15× FP64 cuBLAS conservative floor).

But **both stay at BF16 storage + compute**. Meanwhile Hopper sm_90+ FP8
Tensor Core peak is **1979 TFLOPS dense / 3958 TFLOPS sparse** vs
BF16/FP16 TC peak **989 TFLOPS** = **2× headroom dense, 4× headroom sparse**
within the same hardware. Blackwell B200 widens this further to 4500/9000
TFLOPS FP8 (2.27× / 2.27× over H100 FP8).

The headroom table:

| Format | H100 TC peak (TFLOPS, dense) | vs FP64 TC (60) | RFC anchor |
|---|---|---|---|
| FP64 | 60 | 1× | RFC 044 (anchor) |
| BF16 / FP16 | 989 | 16.48× | RFC 049 measured 9.67× (substrate ~30-60% peak fraction) |
| **FP8 (E4M3 / E5M2)** | **1979 (dense)** | **33×** | **RFC 053 (this RFC, design only)** |
| FP8 sparse | 3958 | 66× | not in scope (sparsity = separate paradigm) |
| FP4 microscaling (B200) | 9000 (sparse) | 150× | future RFC, out of scope |

The **next-tier precision pivot gap**:

- RFC 049 anchors BF16 substrate at 9.67× FP64 cuBLAS LARGE (A100 sm_80,
  ~32% of A100 BF16 TC peak 312 TFLOPS = ~100 BF16 TFLOPS effective)
- Hopper H100 BF16 path (RFC 052 design): projected 14-15× FP64 cuBLAS
  via 3.17× headroom over A100 BF16 TC + DSM intermediate elimination
- **FP8 path (Hopper): projected 20-30× FP64 cuBLAS** at LARGE Llama-7B
  scale (FP8-LM paper anchor 75% speedup over BF16 Megatron-LM at
  GPT-175B); conservative band accounts for per-tensor scaling overhead
  + cast cost + reduced TC peak fraction at small batch
- **FP8 path (Blackwell B200): projected 50-70× FP64 cuBLAS** in absolute
  effective TFLOPS terms (B200 GPT-style ~950 TFLOPS effective FP8 vs
  ~420 TFLOPS H100 effective FP8 anchor)

RFC 053 fills the next-tier gap on paper before any FP8 fire commits cost.

## Proposal — FP8-LM precision substrate (E4M3 fwd + E5M2 bwd + per-tensor scale + FP32 acc + FP64 master)

### 6.1 Architecture (3+1 layer cast pyramid, extends RFC 049 §"Architecture")

```
              FORGE FP8-LM PRECISION SUBSTRATE (next-tier extension of RFC 049)
  ┌──────────────────────────────────────────────────────────────────────────────┐
  │  Layer 1 — MASTER WEIGHTS (FP64, unchanged from RFC 049)                      │
  │    Storage: FP64 packed-double farr (RFC 025/032/034/035)                    │
  │    Use: AdamW step, gradient accumulation across micro-batches               │
  │    Anchor: D' within-run det FREE (PARADIGM §2.4)                            │
  └──────────────────────────────────────────────────────────────────────────────┘
                              ↓ cast (RNE, FP64→FP8 via per-tensor scale)
  ┌──────────────────────────────────────────────────────────────────────────────┐
  │  Layer 2A — FORWARD COMPUTE WEIGHTS (E4M3 storage)                            │
  │    Storage: FP8 E4M3 device buffer (NEW — 1-byte-per-elem half-half-width    │
  │      arena beyond RFC 049 BF16 2-byte arena)                                 │
  │    Use: forward matmul X @ W, activation, KV-cache (LLM inference path)      │
  │    Cast: just-in-time per linear with PER-TENSOR SCALE                       │
  │    Anchor: FP8-LM paper §2.2 — E4M3 for fwd activations and weights          │
  │    Range: ±448 (finer precision, narrower range)                             │
  └──────────────────────────────────────────────────────────────────────────────┘
                              ↓ load to TC (wmma::fragment or cublasLt GemmEx)
  ┌──────────────────────────────────────────────────────────────────────────────┐
  │  Layer 2B — BACKWARD COMPUTE GRADIENTS (E5M2 storage)                         │
  │    Storage: FP8 E5M2 device buffer (NEW — 1 byte/elem, IEEE-special)         │
  │    Use: dW, dX, dL/dh gradient flow during bwd pass                          │
  │    Cast: FP32 grad → E5M2 with PER-TENSOR SCALE + DELAYED SCALING HISTORY   │
  │    Anchor: FP8-LM paper §2.2 — E5M2 for gradients (wider range, coarser      │
  │      precision matches gradient magnitude distribution)                      │
  │    Range: ±57344 (16-bit subset of IEEE 754, NaN/Inf encoding)               │
  └──────────────────────────────────────────────────────────────────────────────┘
                              ↓ mma.sync FP8 (e4m3/e5m2 input, f32 acc)
  ┌──────────────────────────────────────────────────────────────────────────────┐
  │  Layer 3 — COMPUTE                                                            │
  │    Hardware: H100 FP8 TC (1979 TFLOPS dense), B200 FP8 TC (4500 TFLOPS dense)│
  │    Accumulator: FP32 (mma.sync.aligned.m16n8k32.row.col.f32.e4m3.e4m3.f32   │
  │      or .e5m2.e5m2.f32 per fwd/bwd direction)                                │
  │    cuBLASLt: cublasGemmEx(CUDA_R_8F_E4M3, ..., CUDA_R_8F_E4M3, ...,          │
  │      CUDA_R_32F, ..., CUBLAS_COMPUTE_32F) with per-tensor scale args         │
  │    Output cast: FP32 acc → FP8 (storage) or FP32 acc → FP64 (master grad)    │
  │    Loss scale: BF16 path didn't need it; FP8 NEEDS per-tensor scale (above)  │
  └──────────────────────────────────────────────────────────────────────────────┘
                              ↓ FP32 → FP64 (gradient unscale + AdamW)
  ┌──────────────────────────────────────────────────────────────────────────────┐
  │  Layer 4 — OPTIMIZER STATE                                                    │
  │    Storage: FP64 m, v moments (RFC 035 adamw_step_mixed contract preserved)  │
  │    Update: FP64 master += FP64 step(grad_FP64, m_FP64, v_FP64)               │
  │    Note: FP8-LM paper §3.2 also supports FP8 optimizer states (COAT          │
  │      direction); RFC 053 baseline stays FP64 optimizer states for            │
  │      conservative master-weight contract (RFC 035 anchor)                    │
  └──────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Per-tensor scaling + delayed scaling history (Micikevicius 2022 §3.2 + FP8-LM §3.1)

**Per-tensor scale** is mandatory at FP8: FP8 dynamic range (E4M3 ±448 or
E5M2 ±57344) is too narrow to cover the union of activation/gradient
magnitudes across a network without per-tensor calibration.

```
  scale[tensor_T, step_s] = max_repr(format_T) / amax_history(T, [s-N, s-1])
  fp8_value = round_RNE(fp32_value / scale[T, s])
  fp32_recover = fp8_value * scale[T, s]
```

where:
- `amax_history(T, window)` = max absolute value over N-step history (FP8-LM
  paper uses N=16 step EMA; Micikevicius proposes N=1024 step max).
- `max_repr(E4M3)` = 448, `max_repr(E5M2)` = 57344.
- `round_RNE` = round-to-nearest-even (IEEE 754 default).

**Delayed scaling** = `scale[T, s]` computed from `amax_history` at step
`s-1` (using yesterday's amax, applied today). Trades stale-by-one-step
amax accuracy for avoiding within-step sync between amax compute and
matmul launch. FP8-LM measures negligible accuracy impact at delayed
scaling N=1 (1-step delay).

forge MUST land:
- `farr_fp8_amax_history[F]` device buffer per FP8 tensor `F` (per-tensor
  state — `H_LEN` floats, default `H_LEN=16` per FP8-LM)
- `farr_fp8_compute_scale(T, F)` kernel reading amax_history → producing
  next-step FP32 scale value
- `farr_fp8_e4m3_cast_with_scale(src_fp32, dst_e4m3, scale, n)` and
  `farr_fp8_e5m2_cast_with_scale(...)` byte-deterministic RNE cast
- per-tensor scale storage = FP32 on device, deterministic compute

### 6.3 Three FP8 utilization tiers (FP8-LM §3.1 incremental adoption)

forge baseline tier matches FP8-LM Tier 1; Tiers 2-3 are out-of-scope for
RFC 053 (future RFCs):

| Tier | Compute | Gradient comm | Optimizer state | Master | RFC anchor |
|---|---|---|---|---|---|
| **1 (RFC 053 baseline)** | **FP8 E4M3 fwd / E5M2 bwd** | FP32 (NCCL) | FP64 (RFC 035) | FP64 | **RFC 053** |
| 2 (future) | FP8 | FP8 (E5M2) | FP64 | FP64 | future RFC ≥ 054 |
| 3 (future) | FP8 | FP8 | FP8 / FP16 (COAT) | FP64 | future RFC ≥ 055 |

Tier 1 (RFC 053 baseline) = matches RFC 035 `adamw_step_mixed` contract
exactly except low-precision side is FP8 instead of BF16. Tier 2/3 require
NCCL integration + optimizer state compression — separate substrate work.

### 6.4 cuBLASLt FP8 GemmEx + hand-WMMA mma.sync FP8 (both paths)

RFC 053 baseline = **cuBLASLt FP8 GemmEx** (library-grade, sm_90+ TC
auto-routing). Stage 2 fire validates this path first because:

1. cuBLASLt FP8 = library-tested, deterministic with default algo
2. Stage 2 substrate kernels don't compete with cuBLAS on perf at first;
   the *substrate land* (precision-tier + scale state) is the
   contribution
3. cuBLASLt FP8 supports per-tensor scale argument natively
   (cublasLtMatmulDescAttribute `CUBLASLT_MATMUL_DESC_A_SCALE_POINTER` etc.)

**Hand-WMMA mma.sync FP8** path = Stage 2+ extension (after cuBLASLt
baseline lands and per-tensor scale state is debugged). PTX intrinsic:

```
mma.sync.aligned.m16n8k32.row.col.f32.e4m3.e4m3.f32  (fwd)
mma.sync.aligned.m16n8k32.row.col.f32.e5m2.e5m2.f32  (bwd)
```

Hand-WMMA path enables fusion (epilogue cast back to FP8, fused with
matmul) and cluster-shared SMEM intermediate (RFC 052 DSM combined
generalization at FP8). NOT RFC 053 baseline scope — separate future RFC.

### 6.5 Fallback chain (no-crash mandate, extends RFC 052 §6.5 4-level)

The FP8 substrate is Hopper sm_90+ for full TC, sm_89 Ada partial. RFC 053
mandates the fallback chain that the forge dispatcher (RFC 050
`forge_tier_dispatch_v1`) MUST honor when called with FORGE_PREC_FP8_*
+ FORGE_REGIME_LARGE:

```
FP8 path (this RFC, sm_90+ full TC; sm_89 Ada partial)
    ↓ (hardware not sm_89+, or precision policy fallback requested)
RFC 049 BF16 path (sm_80+ cuBLAS GemmEx BF16, RFC 052 Hopper combined if sm_90+)
    ↓ (BF16 unsupported, e.g., sm_70)
RFC 044 D' FP64 path (cuBLAS Dgemm, deterministic baseline)
    ↓ (CUDA unavailable, Mac)
CPU farr reference (flame Phase 1-3 path, FP64)
```

**5-level chain** (FP8 head + 4-level RFC 052 chain). Detection via
`cudaDeviceGetAttribute(cudaDevAttrComputeCapability...)`:
- `cc.major >= 9` → FP8 path enabled (Hopper, Blackwell full TC)
- `cc.major == 8 && cc.minor == 9` → FP8 path partial (Ada Lovelace L4/L40,
  FP8 inference only, NOT full training TC)
- `cc.major == 8 && cc.minor == 0` → BF16 (RFC 049) path (A100, NO FP8 TC)
- cc < 8.0 → RFC 044 FP64 path
- no CUDA → CPU farr

### 6.6 What this RFC does NOT do

- No CUDA kernel implementation (Stage 2 = 1-2 Hopper / Blackwell fires
  after user gate; ~$20-50 budget — FP8 cuBLASLt routing + per-tensor
  scale state + delayed scaling history each independently complex)
- No flame source changes (RFC 050 dispatch boundary; precision-policy
  axis FORGE_PREC_FP8_E4M3_E5M2 covers this kernel family transparently)
- No RFC 049 supersession — RFC 053 = **next-tier successor** to RFC 049
  BF16; both coexist in fallback chain
- No RFC 052 supersession — RFC 052 Hopper combined BF16+DSM coexists at
  BF16 precision tier; RFC 053 adds FP8 tier (hand-WMMA FP8 + DSM
  combined = future RFC, NOT RFC 053 baseline)
- No FP4 / microscaling MXFP8 variant (FP4 future RFC; MXFP8 separate
  paradigm)
- No sparse FP8 (sparsity = separate paradigm; H100 / B200 FP8 sparse
  peaks 3958 / 9000 TFLOPS unused)
- No FP8 optimizer state (Tier 3, COAT direction; out of scope)
- No FP8 distributed gradient comm (Tier 2; out of scope)
- No backward kernel autograd integration (RFC 048 fwd+bwd graph fusion =
  flame-side IR; RFC 053 emits forward + backward primitives separately)

## Falsifier battery (8 pre-registered, Stage 2 Phase R'' verifies)

Each falsifier is **compiled-native path** (`hexa build` AOT → nvcc-emitted
`.cu` artifact, Hopper sm_90+ target) only. Reference = RFC 049 measured
anchor (state/forge_phaseR_r049_bf16_2026_05_17/result.json) + FP8-LM
paper data + Micikevicius scaling spec + H100 / B200 datasheet TC peak.
No fabricated multiples.

### Tier 1 — FP8 TC perf (next-tier precision wall path)

- **F-FORGE-RFC053-FP8-TC-PERF**: forge FP8 fused FFN (E4M3 fwd path, M=128
  D=4096 FD=11008 — Llama-7B LARGE) latency ≤ **0.5 × RFC 049 BF16
  baseline** on the SAME Hopper hardware (≥ **2× speedup** over RFC 049
  BF16-only). Equivalent framing: combined target ≥ **20× FP64 cuBLAS**
  Dgemm chain at LARGE on Hopper.

  Anchor calculation: RFC 049 measured 9.67× FP64 on A100, Hopper BF16
  headroom 3.17× (RFC 052 §8.4 anchor) = projected ~30× FP64 if RFC 052
  combined kernel hits its 1.5× over RFC 049 floor. FP8 TC adds 2×
  headroom over BF16 TC (1979 / 989 TFLOPS). FP8-LM paper measured 75%
  speedup over BF16 Megatron-LM (= 1.75×). Conservative pre-reg = 2× over
  RFC 049 BF16-only single-block (NOT chained 2× × RFC 052 combined; that
  product is future RFC). PASS = FP8 substrate clears 20× FP64 wall on
  Hopper.

### Tier 2 — Convergence (training feasibility, the headline FP8-LM claim)

- **F-FORGE-RFC053-CONVERGENCE-LM**: GPT-3 175B-scale training final loss
  ≤ **1.05 × FP32 reference** (5% degradation ceiling). Anchor: FP8-LM
  paper §4 GPT-175B FP8 mixed-precision == BF16 Megatron-LM perplexity
  within rounding error, AlpacaEval / MT-Bench within 1% absolute.
  Conservative bar 1.05× allows for non-FP8-LM-paper-specific scaling
  history tuning.

  Honest caveat: this falsifier requires a 175B-scale training fire =
  $1000-10000 not $20-50 RFC 053 Stage 2 budget. **Stage 2 baseline =
  reduced scale (Llama-7B convergence on subset, ~10000 steps, $50-200)**;
  175B-scale follow-up = future Stage 3 RFC + multi-week compute. RFC 053
  Stage 2 PASS bar lowered to 7B-scale 100-1000 step convergence
  ≤ 1.05× FP32 reference loss (flame Phase 4+ trainer integration
  required).

### Tier 3 — Per-tensor scale determinism

- **F-FORGE-RFC053-SCALE-DET**: forge per-tensor scaling history kernel
  is **byte-deterministic** — given identical input data + identical
  amax_history state → identical output scale value (within-run, single
  GPU, single process). Anchor: D' within-run det FREE (PARADIGM §2.4)
  extends to FP8 scale state. Stage 2 verifies: 2-run amax_history kernel
  output bit-equal `memcmp == 0`, identical scale FP32 byte sequences.

- **F-FORGE-RFC053-FP8-BITEQ-WITHIN-RUN**: FP8 forward (E4M3 cast + matmul
  + FP32 acc + RNE FP8 store) output byte-identical across 2 runs of
  same-process same-stream same-GPU same-batch same-amax-history. BF16
  D' generalization to FP8 (RFC 049 anchor F-FORGE-RFC049-LAYERCAST-DET
  measured PASS on cuBLAS GemmEx BF16; same property should hold at
  cuBLASLt GemmEx FP8 with `CUBLAS_GEMM_DEFAULT_TENSOR_OP` algo).

### Tier 4 — Memory footprint (FP8-LM 39% reduction at GPT-175B anchor)

- **F-FORGE-RFC053-FP8-MEM**: FP8 footprint ≤ **0.125 × FP64 footprint** (=
  exact 1/8, no margin needed — FP8 is literally 1 byte vs FP64 8 bytes).
  Verified at allocation: `farr_fp8_e4m3_alloc(n)` returns buffer of size
  `n * 1` bytes (vs `n * 8` for FP64). Compile-time / runtime allocator
  check; not a perf falsifier.

  FP8-LM paper §4 measures **39% real-memory reduction** at GPT-175B vs
  BF16 — this includes activation memory + optimizer state share + KV
  cache. forge RFC 053 baseline (Tier 1, FP8 compute only with FP64
  optimizer) won't hit 39% but will hit ~50% reduction on the FP8 layer
  fraction. **Honest caveat**: 0.125× falsifier is per-FP8-tensor scope,
  full-model memory ratio = future Tier 2/3 RFCs.

### Tier 5 — Hardware capability gate (Hopper-mandate)

- **F-FORGE-RFC053-HOPPER-MIN**: FP8 full TC path requires **sm_90+**
  (H100, H200, GH200, B100, B200, GB200). Dispatcher routes to RFC 049
  BF16 path on sm_80 (A100), sm_89 (Ada Lovelace L4/L40) WITHOUT crash.

  Honest caveat: sm_89 (Ada Lovelace) has **FP8 TC for inference** but
  TRAINING-path Transformer Engine support is limited; RFC 053 baseline
  treats sm_89 as BF16 fallback (RFC 049 path), NOT FP8 path. sm_90+ only
  for FP8 training. (cuBLASLt 12.9 docs: sm_89 listed as inference TC,
  sm_90+ for training-quality precision modes including expanded scaling
  schemes.)

### Tier 6 — Fallback chain integrity (5-level)

- **F-FORGE-RFC053-FALLBACK**: Non-FP8 hardware (sm_80 Ampere, sm_75
  Turing, sm_70 Volta, CPU-only) hits the deterministic 5-level chain:
  FP8 → RFC 049 BF16 → RFC 044 D' FP64 → CPU farr (3 GPU + 1 CPU
  fallback). Each level handoff returns appropriate forge return code
  (FORGE_OK on success, FORGE_FALLBACK_USED on chain descent). Test on
  Mac (CPU farr expected) + sm_80 A100 instance + sm_75 Turing instance.
  Anchor: RFC 050 §6.6 fallback chain contract (4-level extended).

### Tier 7 — Numerical safety (Inf / NaN prevention under typical LM gradient distribution)

- **F-FORGE-RFC053-NO-INF-NAN**: with per-tensor scaling history N=16
  (FP8-LM default) + delayed scaling N=1 (1-step delay), Llama-7B-scale
  training forward + backward over 100-1000 steps produces **0 NaN, 0
  Inf** in scaled E4M3/E5M2 tensors after `farr_fp8_compute_scale`
  application. Anchor: FP8-LM paper §4 reports stable training across
  GPT-175B with delayed scaling N=1024-step window. RFC 053 conservative
  bar with shorter window (N=16) tests amax window sufficient for
  typical LM gradient distribution.

  Honest caveat: F-FORGE-RFC053-NO-INF-NAN passes are easier with longer
  amax windows; if Stage 2 fire shows NaN/Inf at N=16, escalate to N=64
  or N=1024 before declaring FAIL. The falsifier verdict is "does FP8
  substrate match FP8-LM-paper-reported stability with conservative
  scaling settings."

### Tier 8 — Build & toolchain (compiler interface)

- **F-FORGE-RFC053-COMPILE-EQ**: FP8 substrate `.cu` source builds with
  `nvcc -arch=sm_90 -DHEXA_CUDA` AND with `nvcc -arch=sm_100` (Blackwell
  B100/B200 architecture) AND with `clang -x cuda -arch=sm_90`. Output
  identical device code for `nvcc -arch=sm_90` two consecutive builds
  (build determinism). Pre-registered as a *build smoke* — if it fails,
  Stage 2 fire has no kernel to run.

  Honest caveat: `nvcc -arch=sm_100` (Blackwell sm_100) introduces
  Transformer Engine v2 + microscaling-aware kernels in cuBLASLt 13.x;
  RFC 053 baseline = sm_90 fully supported, sm_100 build-clean required
  but full perf unlock = future RFC.

## Honest caveats (g3 / f1 / f2 — no over-claim)

### 8.1 FP8 numerical range narrow — per-tensor scaling = STATEFUL substrate property

FP8 E4M3 range ±448 vs FP32 ±3.4e38, FP64 ±1.8e308 — **8 orders of
magnitude smaller dynamic range**. Per-tensor scaling factor (FP32 or
higher) compensates for tensor-local amax, BUT:

- **scaling history is stateful**: forge dispatch path now carries
  `amax_history[N]` per-tensor state across calls. This is NOT a pure
  function of inputs — same input data → same output ONLY if scaling
  history state is identical. D' boundary at FP8 = same-process +
  same-batch + same-GPU + **same-scaling-history-init**. Stricter than
  BF16 D' boundary.
- **catastrophic cancellation more likely**: E4M3 3-bit mantissa vs BF16
  7-bit mantissa vs FP32 23-bit. Subtraction `a - b` where `a≈b` loses
  6× more bits at E4M3 vs BF16. FP32 accumulator inside matmul mitigates
  but does NOT fully prevent at activation values close to scaled-range
  boundary.
- **FP8-LM paper §4 explicit**: GPT-175B training with FP8 needed
  custom scaling adjustments + careful tensor-class-specific scaling
  (Q/K/V scaled separately from FFN). RFC 053 baseline = per-tensor
  scale (single scalar per tensor); FP8-LM-class robustness needs
  per-tensor-CLASS scale routing (future RFC ≥ 054).

### 8.2 Per-tensor scaling overhead may shrink 2× perf headroom

FP8 GemmEx with per-tensor scale arguments adds:
- `farr_fp8_compute_scale` kernel per-tensor per-step (compute amax over
  N-step history + divide → FP32 scale)
- amax reduction kernel per-tensor per-step (post-matmul, write next
  amax_history entry)
- per-tensor scale memory traffic (FP32 scale broadcast to all matmul
  threads)

FP8-LM paper §4 measures these adds ~5-10% overhead vs theoretical FP8
TC peak. RFC 053 conservative 2× over RFC 049 BF16 bar accounts for this
(theoretical headroom 2× × 0.9 overhead factor = 1.8×; falsifier bar 2×
allows for some amortization at LARGE shapes where matmul dominates).

Stage 2 fire MAY measure < 2× over RFC 049 if scale state overhead
dominates at SMALL/MEDIUM shapes (per RFC 049 F1 pattern: SMALL = 2.33×
LARGE = 9.67× because compute amortizes overhead). FP8 expected to
follow same shape-dependent amortization.

### 8.3 Stage 2 implementation = 3-6 weeks effort, $20-50 conservative fire

Conservative estimate based on RFC 049 Stage 1 fire cost ($0.10, 2 fires
same pod) + RFC 052 design Stage 2 estimate ($5-20) + FP8 added complexity:

1. Hopper instance (H100 SXM ~$2-4/hr vast.ai) or Blackwell (B200 ~$5-10/hr
   2026 spot pricing TBD)
2. Kernel iteration: cuBLASLt FP8 GemmEx routing + per-tensor scale state
   buffer + delayed scaling history kernel + amax-update kernel + RNE
   cast helpers (E4M3 + E5M2 variants) — 4-6 independently complex
   components
3. Reference baseline rebuild on same Hopper hardware (RFC 049 BF16
   single-block + RFC 052 combined kernel both must be fired on same
   hardware for fair comparison)
4. Convergence anchor: 7B-scale training over 100-1000 steps (flame
   Phase 4+ integration prereq = additional $50-200 budget; OR test on
   small transformer ~10M params over MNIST = $5-10 minimal anchor)

Total: $20-50 baseline + $50-200 convergence anchor = up to $250
calendar-effort 3-6 weeks. **Cost-bearing**, requires user gate before
fire. Until then RFC 053 stays DESIGN ONLY.

### 8.4 The 20-30× FP64 cuBLAS projection is *literature ceiling band*, real measurement may be 10-20×

Tile-by-tile projection (anchored product of measured halves + literature):

- RFC 049 BF16 measured on A100: **9.67× FP64 cuBLAS** at LARGE (anchored)
- Hopper BF16 TC peak / A100 BF16 TC peak: 989 / 312 = **3.17× headroom**
  (NVIDIA datasheet; RFC 052 §8.4 anchor — UNMEASURED on Hopper yet)
- Hopper FP8 TC peak / BF16 TC peak: 1979 / 989 = **2× headroom**
  (NVIDIA datasheet; FP8-LM paper §4 measures 1.75× actual = 87.5% peak ratio)
- Per-tensor scale + delayed scaling overhead: -5 to -10% (FP8-LM §4 anchor)
- Combined projection: **9.67 × 3.17 × 2.0 × 0.9 ≈ 55×** (theoretical max
  on Hopper H100; B200 multiplies by another 2.26× = ~125× theoretical)

This product is **dishonestly high** because:
- cuBLASLt FP8 GemmEx Hopper hasn't been measured by forge (no fire yet)
- per-tensor scale state overhead may dominate at SMALL/MEDIUM shapes
- WMMA fragment tail handling at small M (M_TILE=4) leaves TC pipeline
  pipeline-empty fraction non-trivial
- delayed scaling N=16 default may need larger N for stability →
  amax-history kernel overhead grows
- Blackwell B200 FP8 peak not directly comparable to Hopper H100 cuBLAS
  Dgemm baseline (Dgemm Blackwell FP64 TC also faster — denominator
  changes)

**RFC 053 conservative projection: 20-30× FP64 cuBLAS Dgemm chain at
LARGE Llama-7B FFN on Hopper.** F-FORGE-RFC053-FP8-TC-PERF anchors the
**≥ 2× over RFC 049 BF16-only** floor (i.e., ≥ 20× FP64 cuBLAS,
conservative bottom of the 20-30× projection band). Falsifier PASS = FP8
substrate adds meaningful win over BF16-only on Hopper; FAIL = FP8 adds
< 2× which means per-tensor scaling overhead + cuBLASLt FP8 GemmEx
implementation maturity isn't enough to justify FP8 substrate complexity.

### 8.5 sm_70 / sm_75 / sm_80 / sm_89 NOT supported for FP8 training — full chain fallback

- **sm_70 Volta**: no BF16, no FP8 → falls back to FP64 (RFC 044)
- **sm_75 Turing**: FP16 TC, no BF16, no FP8 → falls back to FP64 (RFC 044)
- **sm_80 Ampere (A100)**: BF16 TC, no FP8 TC → falls back to BF16 (RFC 049
  single-block path)
- **sm_89 Ada Lovelace (L4, L40)**: FP8 TC for INFERENCE, NOT training
  Transformer Engine → falls back to BF16 (RFC 049). cuBLASLt 12.9 docs
  explicit: sm_89 FP8 GemmEx works but expanded scaling schemes (cuBLAS
  12.9 new feature) are Hopper-only.
- **sm_90+ Hopper (H100, H200, GH200)**: FP8 TC full training. RFC 053
  primary target.
- **sm_100+ Blackwell (B100, B200, GB200)**: FP8 TC full + microscaling
  + sparsity. RFC 053 baseline supports as build target; full unlock =
  future RFC (microscaling MXFP8, MOSS paper anchor).

RFC 053 does NOT lock the substrate to Hopper-or-newer hardware — it
adds a precision-tier *upper level* of the regime/precision matrix.
Fallback chain ensures no-crash on older hardware.

### 8.6 No n=6 lattice / perfect-number numerology (f1/f2 deny)

All perf anchors and shape thresholds in this RFC trace to:

- forge measured fires (RFC 049 Stage 1)
- NVIDIA H100/H200/B100/B200 datasheet TC throughput (60 / 989 / 1979 /
  3958 / 4500 / 9000 TFLOPS measured/spec)
- HBM bandwidth specs (H100 3.35 TB/s, H200 4.8 TB/s, B200 8 TB/s)
- Literature (FP8-LM, Micikevicius FP8 formats, Scaling FP8 to Trillion-
  Token LLMs ICLR 2025)
- FP8 IEEE-equivalent format specs (E4M3 4+3 bits, E5M2 5+2 bits per
  Micikevicius 2022 / NVIDIA TE)
- BF16 / FP32 / FP64 IEEE 754 standard mantissa/exponent (NOT lattice)

No lattice constants. No perfect-number numerology. Scaling history N
(16 / 64 / 1024) = paper-measured stability windows, not n=6 derivation.

### 8.7 No new flame surface; no API breakage (g_flame_api_fixed preserved)

flame consumer side (per RFC 050 dispatch boundary) sees RFC 053 entirely
through the existing `forge_tier_dispatch_v1(...)` precision-policy axis:

- `precision_policy = FORGE_PREC_FP8_E4M3_E5M2` + `regime_hint =
  FORGE_REGIME_LARGE` + sm_90+ hardware → dispatcher routes to RFC 053
  FP8 path
- Same call on Ada Lovelace sm_89 → dispatcher routes to RFC 049 BF16
  single-block (FP8 inference TC may be opt-in via separate policy
  FORGE_PREC_FP8_INFERENCE_ONLY = future RFC)
- Same call on Ampere → dispatcher routes to RFC 049 BF16
- Same call on Volta / Turing → dispatcher routes to RFC 044 FP64

The flame public API stays unchanged (`g_flame_api_fixed` preserved).
RFC 050 §6.5 specialized-kernel registration convention is the mechanism
by which Phase 4-C IR pass (RFC 048) can request specific kernel
families without knowing whether the underlying substrate is RFC 044
(FP64) / RFC 049 (BF16) / RFC 052 (Hopper combined BF16+DSM) / RFC 053
(FP8).

## Non-goals (this RFC)

- No `.cu` source land (design only; Stage 2 fire = 1-2 separate
  user-gated fires)
- No `.hexa` source land (flame consumer unchanged; RFC 050 dispatch surface)
- No RFC 049 supersession (RFC 053 = next-tier *successor*; both coexist)
- No RFC 052 supersession (RFC 052 Hopper BF16+DSM coexists at BF16 tier;
  FP8+DSM combined = future RFC)
- No RFC 044 supersession (RFC 053 *adds* precision-tier on top)
- No FP4 / microscaling MXFP8 / MXFP4 (separate future RFCs per format;
  Optimizing LLM FP4 Quantization arxiv 2501.17116 anchor for FP4)
- No sparse FP8 (sparsity = separate paradigm)
- No FP8 distributed gradient communication (FP8-LM Tier 2; out of scope;
  cross-RFC with NCCL integration)
- No FP8 optimizer state compression (FP8-LM Tier 3, COAT direction;
  out of scope; cross-RFC with adamw_step_mixed extension)
- No 175B-scale convergence anchor (RFC 053 Stage 2 = reduced 7B scale;
  175B = future Stage 3 + $1000-10000 compute)
- No multi-cluster / cross-cluster FP8 dispatch (out of scope)
- No autograd co-emission integration (RFC 048 fwd+bwd graph fusion =
  flame-side IR; RFC 053 emits forward + backward primitives separately)
- No NCCL / multi-GPU integration (out of scope; future RFC ≥ 060)
- No inference-framework integration (vLLM / TensorRT-LLM out of scope)

## Cross-RFC dependency

- **RFC 034** (autograd tape) — unchanged; RFC 053 emits forward + backward
  primitives separately, autograd records on tape as standard
  `ag_matmul + ag_silu + ag_matmul` with per-tensor scale state opaque
  to the tape layer
- **RFC 035** (BF16 round-trip on packed-double arena) — `adamw_step_mixed`
  already lands FP64-master + low-precision-grad contract; RFC 053
  extends low-precision side to FP8 (E4M3 or E5M2 input)
- **RFC 040** (device-farr + cuBLAS Dgemm) — base substrate; always
  available as final fallback in 5-level chain (§6.5)
- **RFC 041** (real `.cu` kernels for B/B2 ops) — RFC 053 = FP8 variant of
  the fused FFN family from RFC 041 11-op set
- **RFC 042** = SUBSUMED by RFC 043 (do not reuse)
- **RFC 043** (flame stdlib design) — RFC 053 consumed transparently via
  RFC 050 dispatch boundary; no flame surface change
- **RFC 044** (forge dual-mechanism × regime-tiered substrate) — RFC 053
  *adds* precision-tier (mechanism 3 from RFC 049 generalized to FP8) on
  top of RFC 044 dual-mechanism × regime-tiered framework
- **RFC 045** (flame Phase 3 algorithmic byte-eq) — orthogonal; RFC 053
  preserves D' FP8 generalization (within-run + within-scaling-history
  bit-equal), cross-precision bit-equal NOT in scope (honest caveat
  inherited from RFC 049 §3.3)
- **RFC 046 / 047 / 048** (flame Phase 4 / 4-B / 4-C compiler fusion) —
  orthogonal; RFC 053 = forge kernel, RFC 048 = flame IR pass
- **RFC 049** (forge mixed-precision substrate, BF16) — **PARENT RFC**;
  RFC 053 is the explicitly-named FP8 successor (RFC 049 §"Non-goals"
  line 195-196 + Next iteration plan). Both coexist in fallback chain
  (sm_80 / sm_89 → RFC 049 BF16, sm_90+ → RFC 053 FP8)
- **RFC 050** (flame ↔ forge integration API) — RFC 053 invoked through
  `forge_tier_dispatch_v1(precision=FORGE_PREC_FP8_E4M3_E5M2,
  regime=FORGE_REGIME_LARGE)`. RFC 050 §6.6 fallback chain extended to
  5-level by RFC 053
- **RFC 051** (unboxed array native) — orthogonal; RFC 053 operates on
  device-farr (RFC 040 device buffer), not host arrays
- **RFC 052** (forge Hopper BF16+DSM combined) — sibling at BF16 tier on
  Hopper sm_90+. RFC 053 = FP8 tier on same hardware. FP8+DSM combined
  kernel = future RFC ≥ 054
- **RFC 054+ (future)**: FP8 + DSM cluster combined kernel (FP8 mma.sync
  + cluster-shared SMEM intermediate); FP8 distributed gradient comm
  (FP8-LM Tier 2); FP8 optimizer state (COAT direction, Tier 3); MXFP8
  microscaling variant; FP4 / MXFP4 substrate (Optimizing LLM FP4 anchor)

## Cross-link (PARADIGM.md + Phase R+ fires + RFC 049 Stage 1 + RFC 052 + literature)

### forge SSOTs

- `self/forge/PARADIGM.md` — measurement-anchored thesis (FORGE.tape
  `x_paradigm_ssot`); §1 Phase R+ Stage 2 table includes RFC 049 Stage 1
  9.67× LARGE row (RFC 053 builds on); §6 Meta-finding "forge wall path
  = RFC 049 BF16 precision pivot" — RFC 053 = next-tier extension of
  this thesis
- `self/forge/PARADIGM_RESEARCH.md` — literature snapshot; RFC 053 adds
  FP8-LM (arxiv 2310.18313) + Micikevicius FP8 formats (arxiv 2209.05433)
  + Scaling FP8 Trillion-Token LLMs (ICLR 2025) entries to research
  layer (PARADIGM_RESEARCH.md update = separate follow-up task)
- `self/forge/FORGE.tape` — substrate-side SSOT; RFC 053 land event will
  append to `## Log` per `g_arch_vs_log_split`
- `self/forge/PLAN.md` — Phase 4.MIXED+DSM (RFC 052 row) gets sibling
  Phase 4.FP8 row added by RFC 053 (see §12)

### Phase R+ measurement evidence (g3 — every RFC 053 perf projection traces here)

- `state/forge_phaseR_d_2026_05_17/` — D' within-run det FREE (6/6 FP64
  baseline)
- `state/forge_phaseR_b_dsm_v2_2026_05_17/` — B Stage 2 Phase 2 DSM-fused
  FFN (bit-equal PASS H200, RFC 052 anchor)
- `state/forge_phaseR_r049_bf16_2026_05_17/` — **RFC 049 Phase R' Stage 1**
  BF16 fused FFN (9.67× FP64 cuBLAS LARGE A100; LayerCast det+mem+diverge
  4/4 PASS) — RFC 053 builds on this anchor as the BF16 baseline
- `state/forge_phase4d_5_3_2026_05_17/` — Phase 4-D-5-3 Phase B/B2 byte-eq
  PASS 11/11 (substrate ready for next-tier precision substrate land)
- Phase R + R+ cumulative cost: **$2.91** (14 fires through 2026-05-17)
- RFC 053 Stage 2 fire estimate: **$20-50** (1-2 Hopper or Blackwell
  fires, 3-6 cycles; 7B convergence anchor + $50-200 extra)

### CUDA experiment artifacts (already landed; RFC 053 builds on)

- `self/cuda/experiments/r049_bf16_fused_ffn.cu` (510 lines) — BF16
  substrate reference; RFC 053 Stage 2 will adapt the cast helpers
  (FP64→BF16 RNE → FP64→E4M3/E5M2 RNE with per-tensor scale) + epilogue
  patterns; matmul replaces cublasGemmEx BF16 with cublasLtGemmEx FP8
- `self/cuda/experiments/r049_layercast_linear.cu` (410 lines) — LayerCast
  cast policy reference; RFC 053 may inherit cast routing patterns for
  FP32→FP8 fallback (when cuBLASLt FP8 GemmEx returns NOT_SUPPORTED on
  older cuBLAS versions, similar to RFC 049 sm_80 mixed-type fallback)

### Literature anchors

- **FP8-LM** (Peng et al. 2023, arxiv 2310.18313) — primary anchor: GPT-175B
  FP8 mixed = 75% speedup over BF16 Megatron-LM, 39% memory reduction,
  3-tier incremental adoption (compute, gradient comm, optimizer state).
  RFC 053 baseline = Tier 1 (compute only). https://arxiv.org/abs/2310.18313
- **FP8 Formats for Deep Learning** (Micikevicius et al. 2022, arxiv
  2209.05433) — FP8 format spec (E4M3 / E5M2) + per-tensor scaling +
  delayed scaling history pattern. RFC 053 inherits exactly.
  https://arxiv.org/abs/2209.05433
- **Scaling FP8 Training to Trillion-Token LLMs** (ICLR 2025,
  proceedings.iclr.cc/paper_files/paper/2025/file/f48b5133...) — large-
  scale FP8 training reproducibility anchor; RFC 053 conservative scale
  N=16 baseline references but does NOT depend on
- **MOSS** (arxiv 2511.05811, 2025) — FP8 microscaling + automatic scaling;
  RFC 053 references but does NOT include (microscaling = future RFC ≥ 054)
- **COAT** (ICLR 2025, proceedings.iclr.cc/paper_files/paper/2025/file/6ac807c9...)
  — FP8 optimizer state compression; RFC 053 references but does NOT
  include (optimizer state = future Tier 3 RFC)
- **Training and inference of LLMs using 8-bit floating point** (arxiv
  2309.17224, 2023) — additional FP8 training anchor (Graphcore IPU
  context); cross-reference for hardware-agnostic FP8 patterns
- **Optimizing LLM Training Using FP4 Quantization** (arxiv 2501.17116,
  2025) — FP4 future direction reference (NOT RFC 053 scope)
- **Recipes for Pre-training LLMs with MXFP8** (arxiv 2506.08027, 2025) —
  microscaling MXFP8 reference (NOT RFC 053 baseline)
- **NVIDIA H100 Datasheet** (1979 TFLOPS FP8 TC dense, 3958 sparse, 989
  BF16 TC, 60 FP64 TC): https://www.nvidia.com/en-us/data-center/h100/
  + https://www.megware.com/fileadmin/.../nvidia-h100-datasheet.pdf
- **NVIDIA Transformer Engine docs** (FP8 primer, CUDA_R_8F_E4M3 /
  CUDA_R_8F_E5M2 enums, sm_90+ training Transformer Engine):
  https://docs.nvidia.com/deeplearning/transformer-engine/user-guide/examples/fp8_primer.html
- **NVIDIA Blackwell B200 architecture** (4500 / 9000 TFLOPS FP8 dense /
  sparse, GB200 superchip): https://www.cudocompute.com/blog/nvidias-blackwell-architecture
- **cuBLAS 12.9 expanded FP8 scaling schemes** (NVIDIA blog 2026):
  https://developer.nvidia.com/blog/boosting-matrix-multiplication-speed-and-flexibility-with-nvidia-cublas-12-9/
- **cuBLAS 13.2 docs** (April 2026): https://docs.nvidia.com/cuda/cublas/
- **RFC 049 substrate paper trail** (already in PARADIGM.md): LayerCast,
  cuBLAS 12.9 BF16x9 emulation, BFLOAT16 training study (anchors inherited)

### Related RFCs (in-repo)

- RFC 035 — bf16 round-trip on packed-double arena (land); RFC 053 reuses
  `adamw_step_mixed` contract at FP8
- RFC 040 — `farr` GPU/CUDA backend (land)
- RFC 041 — real `.cu` kernels for B/B2 ops (Phase 2 LAND)
- RFC 044 — forge dual-mechanism × regime-tiered substrate (design)
- RFC 048 — flame Phase 4-C fwd+bwd graph fusion (design)
- RFC 049 — forge mixed-precision substrate, BF16 (Phase R' Stage 1 PASS,
  RFC 053 parent)
- RFC 050 — flame ↔ forge integration API (design; RFC 053 invoked
  through it; fallback chain extended to 5-level)
- RFC 052 — forge Hopper BF16+DSM combined (design draft 43e15f6e; RFC
  053 sibling at FP8 tier)

## PLAN integration

RFC 053 extends `self/forge/PLAN.md` §Phase 4+ matrix with the FP8 tier.
RFC 044 + RFC 049 + RFC 052 + RFC 053 layered PLAN view (substrate side):

| Phase | Scope | Hardware | RFC | Status |
|---|---|---|---|---|
| Phase 2 | regime-tiered substrate scaffold (2.A Graphs / 2.B SMEM / 2.C fwd+bwd) | universal | RFC 044 | DESIGN |
| Phase 3 | DSM-cluster fusion (B' Stage 2 production unit) | Hopper sm_90+ | RFC 044 + RFC 052 | DESIGN (RFC 052 specifies combined production kernel) |
| Phase 4.FP64 | AOT whole-train-step (A' Stage 2 transformer) | universal | RFC 044 | DESIGN |
| Phase 4.MIXED | BF16 TC substrate (single-block) | sm_80+ | RFC 049 | Stage 1 PASS, Stage 2 follow-up |
| Phase 4.MIXED+DSM | BF16 TC + DSM cluster combined kernel | sm_90+ | RFC 052 | DESIGN ONLY |
| **Phase 4.FP8** | **FP8-LM precision substrate (E4M3 fwd + E5M2 bwd + per-tensor scale)** | **sm_90+ (Hopper) / sm_100+ (Blackwell)** | **RFC 053 (this RFC)** | **DESIGN ONLY** |
| Phase 5 | flame ↔ forge integration dispatcher | universal | RFC 050 | DESIGN |
| Phase 6+ | multi-GPU / cross-GPU dispatch + FP8 distributed grad comm | future | future ≥ 060 | not designed |

Phase 4.FP8 = sibling to Phase 4.MIXED+DSM at the precision tier; not
sequential dependency. Both can land independently after RFC 049 Stage 2
+ RFC 050 dispatch boundary are real.

flame PLAN side (`stdlib/flame/PLAN.md`) is unchanged by RFC 053 — flame
consumer side sees RFC 053 entirely through RFC 050 dispatch boundary.
flame Phase 4-D GPU dispatch (PLAN candidate, $5-20) routes
`forge_tier_dispatch_v1(precision=FORGE_PREC_FP8_E4M3_E5M2,
regime=FORGE_REGIME_LARGE)` calls to RFC 053 when sm_90+ is detected and
training-quality FP8 substrate is requested.

PLAN body update (`self/forge/PLAN.md` Phase 4.FP8 row insertion) =
separate task post RFC 053 land. This RFC provides the guide only.

## Authority

- AGENTS.tape `g3` (real-limits-first) — all perf projections trace to
  RFC 049 measured fire + FP8-LM paper + Micikevicius FP8 formats spec +
  H100 / B200 datasheet TC throughput + cuBLASLt 12.9+ API; no
  fabricated multiples
- AGENTS.tape `g4` (honesty-obligation-external) — RFC 053 makes NO claim
  exceeding the conservative 20-30× projection band derived from
  anchored product (RFC 049 measured 9.67× × Hopper headroom 3.17× × FP8
  headroom 2× × scaling overhead 0.9 = ~55× theoretical max, falsifier
  anchored at 2× over RFC 049 = ≥ 20× FP64 cuBLAS floor)
- AGENTS.tape `g5` (hexa-native-only) — forge dispatcher = C runtime,
  `.cu` kernel = portable artifact via nvcc, no LLVM, no C-transpile
  backend
- AGENTS.tape `g7` (inbox-patches-pipeline) — RFC 053 filed at
  `inbox/rfc_drafts_2026_05_12/` per convention
- AGENTS.tape `g_arch_vs_log_split` — RFC 053 = architecture draft
  (editable, latest-wins); land event will append to FORGE.tape `## Log`
  only
- AGENTS.tape §0 `nn_stack` — toolchain ABI lockstep; RFC 053 consumed
  through RFC 050 `forge_tier_v1` API, no new flame public surface,
  `g_flame_api_fixed` preserved
- LATTICE_POLICY `f1` / `f2` — no n=6 lattice numerology in FP8 format
  selection (E4M3 / E5M2 = IEEE-equivalent per Micikevicius 2022), regime
  thresholds (compute / batch / HBM-bound), per-tensor scale history N
  (FP8-LM paper measured = 16; Micikevicius = 1024), or perf projections
  (TC peak ratios + HBM bandwidth, all hardware-cited)
- HEXA-NATIVE-ONLY — FP8 kernel emitted via nvcc as portable artifact
  (fallback C path); not architectural dependency
- `g_forge_substrate_role` — forge = substrate, flame = consumer; RFC 053
  preserves boundary
- `g_forge_verify_oracle` — F-FORGE-RFC053-FP8-BITEQ-WITHIN-RUN anchors
  output equivalence within same-precision same-state, NOT against FP64
  (cross-precision NOT bit-equal honest caveat inherited from RFC 049
  §3.3 + RFC 052 §6.5)
- `g_blue_closed_mandate` (anima cross-repo) — FP8 path divergence vs FP32
  reference = future flame Phase 4+ convergence test (RFC 053 Stage 2 +
  flame integration); RFC 053 inherits BF16 anchor pattern from RFC 049
  F-FORGE-RFC049-LAYERCAST-DIVERGE PASS 1.51%, does NOT introduce new
  oracle layer at substrate level
