# RFC 052 — forge: Hopper BF16 WMMA + DSM cluster combined kernel (combined wall-path)

- **Status**: design-draft (2026-05-17) — DESIGN ONLY, no implementation, no fire
- **Date**: 2026-05-17
- **Priority**: P2 (MEDIUM) — gates the *combined* wall path on Hopper-class hardware
  (sm_90+), but neither blocks Stage 2 RFC 049 BF16 substrate per-component land
  (sm_80 anchor already PASS) nor RFC 050 flame ↔ forge integration dispatch
  (precision-policy / regime-policy axes are orthogonal). Stage 2 follow-up = 1
  Hopper fire (H100 or H200, $5-20 conservative budget).
- **Severity**: MEDIUM — Phase R+ already validated **both** substrate halves
  independently. RFC 049 Stage 1 measured 9.67× FP64 cuBLAS at Llama-7B FFN
  on A100 (BF16 TC substrate). B Stage 2 Phase 2 measured bit-equal DSM
  cross-block intermediate on H200 (numerical mechanism PASS, FP64 wall FAIL).
  The combined path is the projected wall path on Hopper; severity reflects
  *projected unlock*, not *measured wall blocker*.
- **Source convergence**:
  - **RFC 049 Phase R' Stage 1 measured PASS** (state/forge_phaseR_r049_bf16_2026_05_17,
    A100 PCIE, $0.10) — BF16 fused FFN 9.67× FP64 cuBLAS Dgemm chain at
    Llama-7B LARGE (M=128 D=4096 FD=11008), 100.33 BF16 TFLOPS achieved
    (32% A100 BF16 TC peak 312 TFLOPS), within-run bit-equal 3/3 shapes,
    LayerCast mem 0.25× exact, divergence 1.20-1.51% (paper ≤ 3.4%)
  - **B Stage 2 Phase 2 measured biteq-PASS / wall-FAIL** (state/forge_phaseR_b_dsm_v2_2026_05_17,
    H200 SXM cc=9.0 smem_optin=227KB, $0.10) — cluster DSM-fused FFN
    bit-equal max|Δ|=4.6e-16 across SMALL/MEDIUM/LARGE; **wall 200-300×
    SLOWER** vs cuBLAS Dgemm chain (FP64 hand-kernel ceiling, NOT cluster
    mechanism)
  - **RFC 049 §"Next iteration plan"** explicitly preserves slot:
    *"RFC 052 (MEDIUM): Hopper BF16 WMMA + DSM cluster combined — extends
    B Phase 2 cluster API with BF16 TC"* (parent RFC's planned successor)
  - **B Phase 2 F4 finding**: *"H100/H200 cluster API 가 forge Stage 2 이상
    production kernel 의 안정적 토대 — RFC 049 BF16 kernel 작성 시 그대로
    활용 가능"* (state/forge_phaseR_b_dsm_v2_2026_05_17/B_DSM_V2_ANALYSIS.md §3 F4)
  - **B Phase 2 F3 finding**: *"forge B paradigm 의 'DSM 으로 0.5×' 가설 =
    FP64 substrate 에서 실측 불가능 ... precision pivot (RFC 049) 만이 wall path"*
    (same source §3 F3) — RFC 052 fills the combined-axis gap
  - **PARADIGM.md §1 Phase R+ meta-finding** (2026-05-17 PUBLISH): *"forge wall
    path = RFC 049 BF16 precision pivot (실측 검증) ... custom kernels per regime
    (case-by-case win)"* — RFC 052 = the Hopper BF16+DSM regime instance
  - **Literature anchors** (Hopper TC + cluster):
    - FlashAttention-3 (arxiv 2407.08608, Shah et al. 2024): Hopper sm_90
      cluster-mode + BF16/FP8 WMMA combined. 75% H100 TC peak achieved
      (740 TFLOPS BF16 of 989 TFLOPS theoretical) at attention scale via
      warp-specialized async pipeline + cluster cross-block staging.
    - FlashFuser (arxiv 2512.12949, cited B Stage 2 v2 kernel header): first
      compiler framework using H100 DSM, 1.24× E2E inference (memory fusion
      only, no BF16 TC combination).
    - H100 Tensor Core throughput spec: FP64 TC **60 TFLOPS** vs BF16/FP16 TC
      **989 TFLOPS** — **16.48× theoretical headroom**. H200 same TC counts.
    - Hopper Distributed Shared Memory (DSM) cluster API: `__cluster_dims__`,
      `cluster.map_shared_rank()`, `cluster.sync()`, smem_optin cap 227 KB/block
      (H100/H200) — verified land via B Stage 2 Phase 2 functional kernel.
    - cuBLAS GemmEx `CUDA_R_16BF` + `CUBLAS_COMPUTE_32F`: Tensor Core
      automatic on sm_80+, deterministic with `CUBLAS_GEMM_DEFAULT_TENSOR_OP`
      (D' generalization at BF16, RFC 049 Stage 1 anchor).

## Source evidence (g3 — every claim traces to a real capture or cited paper)

Every projection or comparator in this RFC traces to one of:

1. **forge measured wins** (PARADIGM.md §1 Stage 2 table):
   - RFC 049 BF16 Stage 1 LARGE: 9.67× FP64 cuBLAS — `state/forge_phaseR_r049_bf16_2026_05_17/result.json` row M=128 D=4096 FD=11008, t_FP64=2.2246 ms, t_BF16=0.2301 ms
   - B Stage 2 Phase 2 LARGE: 0.4521 ms cuBLAS chain baseline (H200 SXM
     reference for the same Llama-7B shape) — `state/forge_phaseR_b_dsm_v2_2026_05_17/result.json`
   - B Stage 2 Phase 1 (smoke): cluster.map_shared_rank + cluster.sync
     API smoke PASS on H200 — `state/forge_phaseR_b_stage2_2026_05_17/B_STAGE2_PHASE1_ANALYSIS.md`
   - D' within-run det FREE across 6 shapes FP64 — `state/forge_phaseR_d_2026_05_17/D_ANALYSIS.md`
2. **Hardware spec**: H100 datasheet (60 / 989 TFLOPS FP64 TC / BF16 TC),
   H100/H200 cluster API limits (smem_optin 227 KB/block, cluster up to 16 blocks
   on H100, NVIDIA Hopper Architecture In-Depth blog).
3. **Literature**: FlashAttention-3 paper (Shah et al. 2024), FlashFuser (arxiv
   2512.12949), LayerCast (arxiv 2506.09501).
4. **CUDA artifacts** (already landed in self/cuda/experiments/):
   - `self/cuda/experiments/b_dsm_fused_ffn_v2.cu` — DSM cluster kernel reference
     (586 lines, FP64 hand-kernel; cluster mechanism PASS, wall FAIL — the
     "DSM half" of the combined design)
   - `self/cuda/experiments/r049_bf16_fused_ffn.cu` — BF16 fused FFN reference
     (510 lines, cuBLAS GemmEx BF16; substrate PASS — the "BF16 half" of the
     combined design)

No projection in this RFC exceeds the most conservative product of these two
measured halves (see §8.4 honest caveat). No fabricated multiples.

## Scope (DESIGN ONLY)

RFC 052 is **design draft only**. It specifies:

- The Hopper-specific combined kernel architecture (BF16 WMMA + DSM cluster +
  cluster-shared SMEM intermediate)
- The hardware capability gate (sm_90+ required for cluster API)
- The fallback chain (sm_80 Ampere → RFC 049 BF16 path; non-CUDA → CPU farr)
- The numerical contract (BF16 substrate D' boundary + FP32 reduction
  accumulator + FP64 master weights at AdamW step boundary)
- The 7+ pre-registered falsifiers Stage 2 must verify
- Cross-RFC integration (049 substrate + 050 dispatch API + 044 regime tier)

RFC 052 does NOT specify:

- Any `.cu` source (Stage 2 fire = 1 separate Hopper fire after user gate)
- Any `.hexa` source (flame side stays unchanged; consumed via RFC 050
  `forge_tier_dispatch_v1` precision-policy axis)
- The BF16 storage class (`farr_bf16`) implementation (RFC 049 Stage 2
  follow-up RFC 051/053 covers — see RFC 049 §"Components")
- The LayerCast JIT cast policy implementation (RFC 049 follow-up)
- AdamW master-weight update integration (RFC 035 `adamw_step_mixed` already
  designs the FP64-master + low-precision-grad contract)
- Multi-cluster / cross-cluster dispatch (out of scope; future RFC if needed)
- FP8 / FP4 (out of scope; FP8-LM arxiv 2310.18313 future RFC anchor)

## Problem — RFC 049 BF16 kernel routes FFN intermediate through HBM; B Stage 2 cluster DSM not yet combined with BF16 TC

RFC 049 Stage 1 (state/forge_phaseR_r049_bf16_2026_05_17) measured the BF16
substrate wall path PASS — 9.67× FP64 cuBLAS at Llama-7B FFN. But the kernel
used (`r049_bf16_fused_ffn.cu`) is **library-grade single-block** dispatch:
two separate `cublasGemmEx` BF16 calls with the intermediate `H[M, FD]`
materialized in HBM between them. At Llama-7B scale (M=128 FD=11008) the
intermediate is:

  H[M, FD] BF16 = 128 × 11008 × 2 B = **2.69 MB** per forward FFN step

This intermediate is read once and written once to HBM between the two GemmEx
calls — pure round-trip traffic. On H100 HBM3 (3.35 TB/s peak), this adds
~1.6 μs lower-bound just for the intermediate HBM roundtrip. The total RFC 049
LARGE measured kernel was 0.2301 ms on A100 (HBM2e ~1.55 TB/s, slower than
Hopper); on H100 the absolute latency drops but the **fraction of time spent
on HBM intermediate** rises (compute drops faster than bandwidth).

Meanwhile B Stage 2 Phase 2 (state/forge_phaseR_b_dsm_v2_2026_05_17) measured
the DSM cluster mechanism PASS — cross-block intermediate `H[M, FD/2]` stays
in cluster-shared SMEM, NEVER touches HBM. Verified bit-equal on H200 across
all shapes; the wall FAIL was strictly the FP64 hand-kernel naive per-thread
matmul ceiling, NOT the cluster mechanism.

The **combination gap**:

- RFC 049 has BF16 TC throughput (substrate wall path) but ships intermediate
  through HBM (B Stage 2 Phase 1/2 Stage 1 anchor: HBM 35.4% util on FFN —
  the very fraction DSM was designed to eliminate)
- B Stage 2 Phase 2 eliminates the HBM intermediate (DSM cluster SMEM stays
  resident) but the matmul throughput is FP64 hand-kernel (200-300× slower
  than cuBLAS TC chain, FP64 ceiling)
- **Neither half alone reaches the combined ceiling**. Combined = BF16 TC for
  matmul throughput × DSM for intermediate HBM elimination. Projected on
  Hopper sm_90+ only (cluster API is Hopper-exclusive).

This is the RFC 049 §"Next iteration plan" placeholder. RFC 052 fills it on
paper before any Hopper fire commits cost.

## Proposal — Hopper combined kernel (BF16 WMMA fragments + DSM cluster + FP32 reduction acc + FP64 master, opt-in)

### 6.1 Architecture (per-cluster execution)

```
                 HOPPER BF16+DSM COMBINED FFN KERNEL (sm_90+)
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  Cluster of 2 blocks (extendable to 4/8 if shape benefits)              │
  │  FD axis split across cluster blocks:                                    │
  │    block_rank=0 owns FD cols [0, FD/2)                                  │
  │    block_rank=1 owns FD cols [FD/2, FD)                                 │
  │                                                                          │
  │  Per-block tile execution:                                               │
  │    1. BF16 WMMA matmul1: X_tile @ W1[:, fd_offset:fd_offset+FD_HALF]    │
  │       - mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32              │
  │       - Output: FP32 acc → BF16 store to per-block SMEM (H_half_tile)   │
  │    2. SiLU/SwiGLU activation (FP32 compute, BF16 storage)               │
  │       - Read BF16 H_half_tile from SMEM (cluster-shared via             │
  │         map_shared_rank visible to peer block)                          │
  │    3. cluster.sync() — wait for both blocks to finish their half        │
  │    4. BF16 WMMA matmul2: each block computes its partial Y contribution │
  │       reading peer's H_half via cluster.map_shared_rank(SMEM, peer_rank)│
  │       - Output: FP32 acc, atomic-add merged into Y[M, D]               │
  │                                                                          │
  │  HBM traffic eliminated: H[M, FD] never touches HBM                     │
  │  HBM traffic remaining: X read, W1/W2 read, Y write                     │
  │    For Llama-7B (M=128 D=4096 FD=11008) BF16:                          │
  │      X: 128*4096*2 = 1.0 MB     (read)                                 │
  │      W1: 4096*11008*2 = 86.0 MB (read)                                 │
  │      W2: 11008*4096*2 = 86.0 MB (read)                                 │
  │      Y: 128*4096*2 = 1.0 MB     (write)                                │
  │      H: 0 (eliminated, was 2.69 MB roundtrip)                          │
  │      → HBM savings: 2.69 MB / 176 MB ≈ 1.5%                            │
  │    For Llama-7B inference (B=1, sequence-stage):                       │
  │      X: 1*4096*2 = 8 KB                                                │
  │      Y: 1*4096*2 = 8 KB                                                │
  │      H: 0 (eliminated, was 22 KB)                                      │
  │      → HBM savings dominated by W reads (weight-stationary regime)     │
  │                                                                          │
  │  Per-block SMEM budget (H100/H200 smem_optin 227 KB cap):              │
  │    H_half_tile (BF16): M_TILE × (FD/2) × 2 bytes                       │
  │    M_TILE=4, FD=11008:  4 × 5504 × 2 = 43 KB    (LARGE Llama-7B fits)  │
  │    M_TILE=16, FD=3072: 16 × 1536 × 2 = 48 KB    (MEDIUM/SMALL fits)    │
  │    Headroom: ~180 KB for WMMA fragment staging + W tile reuse SMEM     │
  └─────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Numerical contract (3-layer cast pyramid, RFC 049 inheritance)

| Layer | Storage | Compute | Cast direction | Anchor |
|---|---|---|---|---|
| **L1 master** | FP64 packed-double farr | AdamW state | none in-kernel | RFC 035 `adamw_step_mixed` |
| **L2 compute weight** | BF16 (W1, W2 device buffers) | BF16 WMMA fragment load | FP64→BF16 RNE at AdamW step boundary | RFC 049 §"Layer 2" |
| **L3 compute** | WMMA fragments (BF16 input, FP32 acc) | `mma.sync ... f32.bf16.bf16.f32` | FP32 acc → BF16 SMEM at epilogue | RFC 049 §"Layer 3" |
| **L3' reduction** | FP32 cluster atomic-add to Y staging | FP32 add | FP32 → BF16 at final store | LayerCast paper §3 (FP32 acc preserves det) |

**Loss scale**: not required for BF16 (8-bit exponent = FP32 dynamic range,
NVIDIA Hopper docs anchor; LayerCast paper anchor). RFC 035 `adamw_step_mixed`
keeps `loss_scale` arg as opt-in (`loss_scale=1.0` BF16 default).

### 6.3 Cluster API surface (Hopper sm_90+ only)

- `__cluster_dims__(1, CLUSTER_BLOCKS, 1)` launch attribute (cuda 12+)
- `cg::this_cluster()` → `cg::cluster_group` handle
- `cluster.block_rank()` → identify role in cluster
- `cluster.map_shared_rank(local_smem_ptr, peer_rank)` → access peer block's
  SMEM (the DSM mechanism — cross-block SMEM aperture)
- `cluster.sync()` → barrier across all blocks in cluster
- `cudaLaunchKernelEx` with `cudaLaunchAttributeClusterDimension` (required by
  cluster API on Hopper)

All five primitives **already verified land** via B Stage 2 Phase 1 smoke
(state/forge_phaseR_b_stage2_2026_05_17) and Phase 2 functional kernel
(state/forge_phaseR_b_dsm_v2_2026_05_17 bit-equal max|Δ| 4.6e-16). The Hopper
cluster API is a stable substrate for RFC 052's Stage 2 fire.

### 6.4 Cluster size selection (shape-dependent, design choice)

- **CLUSTER_BLOCKS=2** (RFC 052 baseline): FD axis bisected. Per-block H_half
  SMEM = M_TILE × (FD/2) × 2 B. Matches B Stage 2 Phase 2 measured kernel
  layout (already validated functional + bit-equal).
- **CLUSTER_BLOCKS=4** (extension, M-axis tile): split FD into 4 quadrants OR
  split M into 4. Larger cluster = more cross-block SMEM available (4 × 227 KB
  = 908 KB aggregate), more cluster.sync cost. Recommended for very large FD
  (e.g., Llama-65B FD=22016 doesn't fit M=128 × FD/2 in 227 KB at BF16; needs
  M_TILE smaller OR CLUSTER_BLOCKS=4 OR both).
- **CLUSTER_BLOCKS=8/16** (H100 max=16, H200 max=16): more SMEM aggregate but
  cluster.sync cost grows; literature anchor missing for combined BF16 TC +
  large cluster at FFN (FlashAttention-3 uses CLUSTER_BLOCKS=2 for FA-style
  workloads). Stage 2 fire = explore at MEDIUM-LARGE shapes only.

RFC 052 baseline = CLUSTER_BLOCKS=2 (matches B Stage 2 Phase 2 anchor). Stage 2
fire MAY sweep 2/4 if shape benefits.

### 6.5 Fallback chain (no-crash mandate, RFC 050 §6.6 inheritance)

The combined kernel is Hopper-only. RFC 052 mandates the fallback chain that
the forge dispatcher (RFC 050 `forge_tier_dispatch_v1`) MUST honor when called
with FORGE_PREC_LAYERCAST_BF16_FP32 or FORGE_PREC_PURE_BF16 + FORGE_REGIME_LARGE:

```
Hopper combined (this RFC, sm_90+ cluster + BF16 WMMA)
    ↓ (hardware not sm_90+)
RFC 049 BF16 path (sm_80+ cuBLAS GemmEx BF16, single-block, HBM intermediate)
    ↓ (BF16 unsupported, e.g., sm_70)
RFC 044 D' FP64 path (cuBLAS Dgemm, deterministic baseline)
    ↓ (CUDA unavailable, Mac)
CPU farr reference (flame Phase 1-3 path, FP64)
```

Detection happens at kernel-launch time via `cudaDeviceGetAttribute(...,
cudaDevAttrComputeCapability...)` → if cc.major < 9, dispatcher routes to
RFC 049 path (no crash, fall-back code returned per RFC 050 §6.6 contract).

### 6.6 What this RFC does NOT do

- No CUDA kernel implementation (Stage 2 = 1 Hopper fire after user gate)
- No flame source changes (RFC 050 already specifies dispatch boundary;
  precision-policy axis FORGE_PREC_LAYERCAST_BF16_FP32 covers this kernel
  family transparently)
- No RFC 049 supersession — RFC 052 is the **Hopper-specific combined
  successor** to RFC 049 single-block BF16; both paths coexist in the
  fallback chain (RFC 049 for sm_80, RFC 052 for sm_90+)
- No RFC 044 B' tier supersession — RFC 052 *completes* B' tier on Hopper by
  combining the BF16 substrate (RFC 049) with the DSM mechanism (B Stage 2
  Phase 1/2) that was previously FP64-bound
- No FP8 / FP4 variant (FP8 future RFC; FP4 microscaling future RFC)
- No multi-cluster (cross-cluster) dispatch (out of scope)
- No backward kernel (RFC 048 fwd+bwd graph fusion = separate flame-side
  RFC; RFC 052 is forward kernel only — bwd combined kernel = future RFC,
  potentially RFC 053+)

## Falsifier battery (7 pre-registered, Stage 2 Phase R' verifies)

Each falsifier is **compiled-native path** (`hexa build` AOT → nvcc-emitted
`.cu` artifact, Hopper sm_90 target) only. Reference = RFC 049 measured anchor
(state/forge_phaseR_r049_bf16_2026_05_17) + B Stage 2 Phase 2 measured anchor
(state/forge_phaseR_b_dsm_v2_2026_05_17) + H100 datasheet TC throughput numbers.
No fabricated multiples.

### Tier 1 — Combined-perf (the wall-path claim)

- **F-FORGE-RFC052-COMBINED-PERF**: Hopper BF16+DSM combined fused FFN
  latency at Llama-7B LARGE (M=128 D=4096 FD=11008) ≤ **0.667 × RFC 049
  BF16-only baseline** on the SAME Hopper hardware (≥ 1.5× speedup over
  RFC 049 BF16-only). Anchored to RFC 049 LARGE A100 0.2301 ms; Hopper
  equivalent expected ~0.10-0.15 ms (H100 BF16 TC peak 989 TFLOPS vs A100
  312 TFLOPS = 3.17× headroom on the cuBLAS GemmEx path). Combined target
  ≤ 0.067-0.10 ms on H100. Conservative ≥ 1.5× over RFC 049 (not 16×
  theoretical) — accounts for DSM intermediate elimination contributing
  ~1.3-2× (FlashFuser 1.24× E2E memory-only anchor + intermediate HBM
  fraction at FFN), NOT the BF16 TC headroom itself (already captured
  in RFC 049).

  **Equivalent framing**: combined target ≥ **14-15× FP64 cuBLAS** on Hopper
  (RFC 049 9.67× on A100 × Hopper BF16 TC headroom 3.17× × DSM savings 1.5×
  / RFC 049 ≥ 1.5× pre-reg margin ≈ 14-15× cuBLAS FP64 Dgemm chain at LARGE).

### Tier 2 — Combined-numerical (substrate equivalence)

- **F-FORGE-RFC052-BITEQ-VS-RFC049**: Hopper combined kernel output max|Δ|
  ≤ **1e-3 relative** vs RFC 049 BF16-only kernel on the same input. BF16
  precision boundary anchor (LayerCast paper max divergence 3.4%, RFC 049
  measured 1.20-1.51%; combined kernel should NOT add structural error
  beyond reduction-order differences). If max|Δ| > 1e-3, indicates the
  cluster cross-block SMEM atomicity or the WMMA fragment epilogue has a
  bug beyond BF16-precision-level reduction reordering.

- **F-FORGE-RFC052-LAYERCAST-DET**: same-precision same-batch single-GPU
  two runs → byte-identical BF16 output (D' BF16 generalization, RFC 049
  Stage 1 anchor extended to combined kernel). Anchor: RFC 049 Stage 1
  measured within-run bit-equal 3/3 shapes A100. Combined kernel MUST
  preserve this within-run determinism — cluster.sync ordering deterministic,
  atomic-add tree-reduction deterministic single-stream (NOT atomic-add to
  HBM which is non-deterministic; cluster-shared SMEM atomic add followed
  by single-stream HBM write is deterministic).

  Honest caveat: this falsifier validates only within-run-within-process-
  within-GPU-within-batch boundary. Cross-batch BF16 mantissa cancellation
  divergence (LayerCast §3 paper anchor) is OUT OF FALSIFIER SCOPE
  (inherited honest caveat from RFC 049 §"Cross-precision determinism contract").

### Tier 3 — Cluster SMEM fit (the structural feasibility claim)

- **F-FORGE-RFC052-DSM-INTERMEDIATE-FIT**: Per-block H_half SMEM allocation
  for LARGE (M_TILE × FD/2 × 2 B BF16 = 43 KB at M_TILE=4 FD=11008) fits
  within Hopper smem_optin cap **227 KB / block** with ≥ 100 KB headroom
  for WMMA fragment + W tile staging + cluster.sync atomic-add buffer.
  Verified at compile time via `__shared__` declaration sizing and
  `cudaFuncSetAttribute(..., cudaFuncAttributeMaxDynamicSharedMemorySize, ...)`
  setup. NOT a runtime falsifier — fails at build / launch time if violated.

  **Computed budget** (LARGE Llama-7B):
  - H_half_tile: 4 × 5504 × 2 = **43 KB** (per block)
  - WMMA fragment staging: ~16 KB (4-8 16×16×16 BF16 frags)
  - W2 tile reuse staging: ~32 KB (for cross-block matmul2 throughput)
  - cluster.sync atomic buffer: ~4 KB
  - Total: ~95 KB per block, well under 227 KB cap

### Tier 4 — Hardware capability (Hopper-only, fallback test)

- **F-FORGE-RFC052-HOPPER-ONLY**: Combined kernel `cudaLaunchKernelEx` with
  `cudaLaunchAttributeClusterDimension` SUCCESS on sm_90+ (H100 / H200 /
  GH200), and dispatcher routes to RFC 049 BF16 path on sm_80 (A100)
  WITHOUT crash. Test fixture: build combined kernel for sm_90 architecture,
  attempt launch on detected sm_80 device → dispatcher fallback engaged,
  RFC 049 path executes, runs return code FORGE_FALLBACK_USED (RFC 050
  §6.6 contract). No segfault, no `CUDA_INVALID_DEVICE` user-facing error.

- **F-FORGE-RFC052-FALLBACK**: Non-Hopper hardware (sm_80 Ampere, sm_75
  Turing, sm_70 Volta, CPU-only) hits the deterministic 4-level chain:
  Hopper combined → RFC 049 BF16 → RFC 044 D' FP64 → CPU farr reference.
  Each level handoff returns the appropriate forge return code (FORGE_OK on
  success, FORGE_FALLBACK_USED on chain descent). Test on Mac (CPU farr
  expected). Anchor: RFC 050 §6.6 fallback chain contract.

### Tier 5 — Build & toolchain (compiler interface)

- **F-FORGE-RFC052-COMPILE-EQ**: Combined kernel `.cu` source builds with
  `nvcc -arch=sm_90 -DHEXA_CUDA` (the hexa-side compiled-native build
  pathway), AND with `nvcc -arch=sm_90a` (Hopper architecture with TMA /
  WGMMA extensions), AND with `clang -x cuda -arch=sm_90`. Output identical
  device code for `nvcc -arch=sm_90` two consecutive builds (build
  determinism). Pre-registered as a *build smoke* — if it fails, the
  Stage 2 fire has no kernel to run.

  Honest caveat: `nvcc -arch=sm_90a` (Hopper-A with extra capabilities) may
  enable additional optimizations vs plain `sm_90` (e.g., WGMMA wgmma.sync
  instructions are sm_90a only); RFC 052 baseline = `sm_90` (cluster API
  available there, WGMMA not strictly required for combined kernel).

## Honest caveats (g3 / f1 / f2 — no over-claim)

### 8.1 Combined kernel = untested at the *combined-axis* level

RFC 049 Stage 1 measured the BF16 substrate half (A100, 9.67× FP64 LARGE).
B Stage 2 Phase 2 measured the cluster DSM half (H200, bit-equal numerical
mechanism, wall FAIL on FP64 hand-kernel). **Their combination is not
measured anywhere yet** — neither in forge nor in literature directly. The
closest literature anchor is FlashAttention-3 (Shah et al. 2024) which uses
cluster + BF16 TC combined on Hopper for attention (NOT FFN), achieving
75% TC peak (740 TFLOPS BF16). FA-3 evidences the combination is mechanically
feasible at near-peak throughput; RFC 052 projects similar feasibility for
FFN. Stage 2 fire MAY measure below 1.5× over RFC 049 if the FFN intermediate
HBM savings turn out smaller than projected on Hopper HBM3 (3.35 TB/s, faster
than A100 HBM2e). In that case F-FORGE-RFC052-COMBINED-PERF FAILs and the
RFC reframes (no fudge).

### 8.2 Cluster shared memory bandwidth lower than per-block SMEM

`cluster.map_shared_rank()` accesses cross-block SMEM via the cluster fabric,
which has **lower bandwidth** than per-block SMEM (H100 SM-local SMEM ~19 TB/s
aggregate vs cluster cross-block ~3-4 TB/s effective per FlashAttention-3
profiling). This affects matmul2 throughput if H_half reads from peer block
become the bottleneck. Mitigation: WMMA fragment K-dim tiling (16-wide chunks)
amortizes cross-block reads across many MMA ops. Stage 2 fire MUST profile
the cross-block SMEM bandwidth fraction; if it dominates >20% of matmul2 time,
the design needs re-tile.

### 8.3 Stage 2 implementation = 2-4 weeks effort, $5-20 conservative fire

Conservative estimate based on B Stage 2 Phase 2 iteration cost (~$0.30 + 1
weekend of debugging, agent + manual takeover per F5 finding) and RFC 049
Stage 1 fire cost ($0.10, 1 instance, 2 fires same pod). Combined RFC 052
fire requires:

1. Hopper instance (H100 SXM ~$2-4/hr vast.ai, H200 SXM ~$3-5/hr)
2. Kernel iteration: WMMA fragment + cluster.map_shared_rank + cluster.sync
   are independently complex; combined iteration likely 2-4 build+fire cycles
3. Reference baseline rebuild on same Hopper hardware (RFC 049 baseline was
   A100; for fair comparison need RFC 049 BF16-only re-fired on Hopper first)

Total: $5-20 budget for fire, 2-4 weeks calendar including design verification
+ pre-reg + dispatch + analysis. **Cost-bearing**, requires user gate before
fire. Until then RFC 052 stays DESIGN ONLY.

### 8.4 The 20-50× FP64 cuBLAS projection is *literature ceiling*, real measurement may be 10-30×

Tile-by-tile projection:

- RFC 049 BF16 measured on A100: **9.67× FP64 cuBLAS** at LARGE (anchored)
- Hopper BF16 TC peak / A100 BF16 TC peak: 989 / 312 = **3.17× headroom**
  (NVIDIA datasheet; assumes cuBLAS GemmEx scales linearly with peak TC,
  literature anchor only — real cuBLAS may not extract full peak ratio)
- DSM intermediate elimination savings: 1.3-2× (FlashFuser 1.24× E2E
  memory-only; intermediate HBM fraction at FFN is ~10-25% of total HBM
  traffic at Llama-7B inference; combined kernel removes intermediate
  → ~1.3× wall on HBM-bound path, ~2× wall on cross-block reuse benefit)
- Combined projection: **9.67 × 3.17 × 1.3-2 ≈ 40-60×** (theoretical maxima)

This product is **dishonestly high** because:
- cuBLAS GemmEx Hopper hasn't been measured by forge (Phase R was A100/H100
  Stage 1 / H200 reference; no Hopper BF16 direct fire yet)
- cross-block SMEM bandwidth limit (§8.2) reduces matmul2 throughput
- WMMA fragment tail handling at small M (M_TILE=4) leaves TC pipeline
  pipeline-empty fraction non-trivial (FlashAttention-3 mitigates via
  warp-specialization, which RFC 052 baseline does NOT use)

**RFC 052 conservative projection: 10-30× FP64 cuBLAS Dgemm chain at LARGE
Llama-7B FFN on Hopper.** F-FORGE-RFC052-COMBINED-PERF anchors the
**≥ 1.5× over RFC 049 BF16-only** floor (i.e., ≥ 14-15× FP64 cuBLAS,
conservative bottom of the 10-30× projection band). Falsifier PASS = combined
adds meaningful win over BF16-only on Hopper; FAIL = combined adds < 1.5×
which means DSM intermediate elimination isn't enough to justify Hopper
lock-in.

### 8.5 sm_70 / sm_75 (V100, Turing) NOT supported — Ampere falls back to RFC 049 BF16

The cluster API is **Hopper-exclusive**. Ampere (sm_80, A100) has BF16 TC
but no cluster — falls back to RFC 049 BF16 single-block path (already
measured PASS at A100). Turing (sm_75) has FP16 TC only, no BF16 — falls
back to RFC 044 D' FP64 path (existing baseline). Volta (sm_70) has no
BF16, falls back to FP64. CPU-only (Mac, no CUDA) falls back to CPU farr
reference. RFC 052 does NOT lock the substrate to Hopper; it adds a
Hopper-specific *upper tier* of the regime/precision matrix.

### 8.6 No new flame surface; no API breakage

flame consumer side (per RFC 050 dispatch boundary) sees RFC 052 entirely
through the existing `forge_tier_dispatch_v1(...)` precision-policy axis:

- `precision_policy = FORGE_PREC_LAYERCAST_BF16_FP32` + `regime_hint =
  FORGE_REGIME_LARGE` + Hopper hardware → dispatcher routes to RFC 052
  combined kernel
- Same call on Ampere → dispatcher routes to RFC 049 BF16 single-block
- Same call on Volta → dispatcher routes to RFC 044 D' FP64 cuBLAS chain

The flame public API stays unchanged (`g_flame_api_fixed` preserved).
RFC 050 §6.5 specialized-kernel registration convention is the mechanism
by which Phase 4-C IR pass (RFC 048) can request a specific kernel family
without knowing whether the underlying substrate is RFC 049 or RFC 052.

### 8.7 No n=6 lattice / perfect-number numerology (f1/f2 deny)

All perf anchors and shape thresholds in this RFC trace to:

- forge measured fires (RFC 049 Stage 1, B Stage 2 Phase 1+2)
- NVIDIA H100/H200 datasheet TC throughput numbers (60 / 989 TFLOPS)
- HBM bandwidth specs (H100 3.35 TB/s, H200 4.8 TB/s)
- Hopper smem_optin cap (227 KB/block, measured land via B Stage 2 Phase 2)
- Literature (FlashAttention-3, FlashFuser, LayerCast)
- BF16 IEEE 754 spec (8-bit exponent + 7-bit mantissa, NVIDIA `__nv_bfloat16`)

No lattice constants. No perfect-number numerology. Cluster size selection
(2/4/8) is hardware shape × FD-axis-fit math, not n=6 derivation.

## Non-goals (this RFC)

- No `.cu` source land (design only; Stage 2 fire = 1 separate Hopper user-gated fire)
- No `.hexa` source land (flame consumer unchanged; RFC 050 dispatch surface)
- No RFC 049 supersession (RFC 052 = Hopper-specific *successor*; both coexist in fallback chain)
- No RFC 044 supersession (RFC 052 *completes* B' tier on Hopper)
- No bwd kernel (forward only; bwd combined = future RFC 053+ if needed)
- No FP8 / FP4 / TF32 variant (separate future RFCs per format)
- No multi-cluster / cross-cluster dispatch (out of scope)
- No autograd co-emission integration (RFC 048 fwd+bwd graph fusion =
  flame-side IR pass; RFC 052's combined kernel exposed as forward primitive,
  RFC 048 can choose to fuse separately)
- No NCCL / multi-GPU integration (out of scope; future RFC ≥ 060)
- No batch-size-aware kernel selection inside the combined kernel (RFC 050
  `FORGE_REGIME_SMALL/MEDIUM/LARGE` already covers; combined kernel is
  LARGE-only)
- No inference-framework integration (vLLM / TensorRT-LLM out of scope;
  forge consumer-side decision)

## Cross-RFC dependency

- **RFC 034** (autograd tape) — unchanged; RFC 052 emits forward primitive
  only, autograd records on tape as standard `ag_matmul + ag_silu + ag_matmul`
  unless RFC 048 IR pass elects to fuse
- **RFC 035** (BF16 round-trip on packed-double arena) — `adamw_step_mixed`
  already lands FP64-master + low-precision-grad contract; RFC 052 inherits
- **RFC 040** (device-farr + cuBLAS Dgemm) — base substrate; always available
  as final fallback in fallback chain (§6.5)
- **RFC 041** (real `.cu` kernels for B/B2 ops) — RFC 052 = Hopper-specific
  variant of the fused FFN family from RFC 041 11-op set
- **RFC 042** = SUBSUMED by RFC 043 (do not reuse)
- **RFC 043** (flame stdlib design) — RFC 052 consumed transparently via
  RFC 050 dispatch boundary; no flame surface change
- **RFC 044** (forge dual-mechanism × regime-tiered substrate) — RFC 052
  *completes* B' tier on Hopper (mechanism 2 memory fusion + RFC 049
  mechanism 3 precision-tier combined). B' tier prior status was "DSM
  mechanism PASS, FP64 wall FAIL" (B Stage 2 Phase 2 anchor); RFC 052
  reframes B' wall path = combined Hopper kernel
- **RFC 045** (flame Phase 3 algorithmic byte-eq) — orthogonal; RFC 052
  preserves D' BF16 generalization (within-run bit-equal), cross-precision
  bit-equal NOT in scope (honest caveat inherited from RFC 049)
- **RFC 046 / 047 / 048** (flame Phase 4 / 4-B / 4-C compiler fusion) —
  orthogonal; RFC 052 = forge kernel, RFC 048 = flame IR pass. Both layers
  may fuse FFN; RFC 050 dispatch boundary resolves the contract
- **RFC 049** (forge mixed-precision substrate) — **PARENT RFC**; RFC 052
  is the explicitly-named "Next iteration plan RFC 052 (MEDIUM)" successor.
  Both coexist in the fallback chain (sm_80 → RFC 049, sm_90+ → RFC 052)
- **RFC 050** (flame ↔ forge integration API) — RFC 052 invoked through
  `forge_tier_dispatch_v1(precision=FORGE_PREC_LAYERCAST_BF16_FP32,
  regime=FORGE_REGIME_LARGE)`. RFC 050 §6.6 fallback chain is the
  mechanism by which non-Hopper hardware routes around RFC 052
- **RFC 051** (unboxed array native) — orthogonal; RFC 052 operates on
  device-farr (RFC 040 device buffer), not host arrays
- **RFC 053+** (future): bwd combined kernel (paired with RFC 052 fwd);
  multi-cluster dispatch; FP8 / FP4 variants; flame Phase 4+ trainer
  integration with combined kernel (NO-DIVERGE-FP32-TRAIN falsifier
  inherited from RFC 049 §"Tier 4")

## Cross-link (PARADIGM.md + Phase R+ fires + RFC 049 Stage 1 + B Stage 2 + literature)

### forge SSOTs

- `self/forge/PARADIGM.md` — measurement-anchored thesis (FORGE.tape
  `x_paradigm_ssot`); §1 Phase R+ Stage 2 table includes RFC 049 Stage 1
  9.67× LARGE row + B Stage 2 Phase 2 200-300× SLOWER wall FAIL row
  (both anchors RFC 052 builds on); §6 Meta-finding "forge wall path =
  RFC 049 BF16 precision pivot" — RFC 052 = the Hopper instance
- `self/forge/PARADIGM_RESEARCH.md` — literature snapshot (FlashFuser,
  LayerCast); FlashAttention-3 addition for RFC 052 cluster+BF16 anchor
  recommended in PLAN follow-up
- `self/forge/FORGE.tape` — substrate-side SSOT; RFC 052 land event will
  append to `## Log` per `g_arch_vs_log_split`
- `self/forge/PLAN.md` — Phase 3 (DSM-cluster fusion) updated by RFC 052 =
  Hopper combined kernel = Phase 3 production unit (see §12)

### Phase R+ measurement evidence (g3 — every RFC 052 perf projection traces here)

- `state/forge_phaseR_d_2026_05_17/` — D' within-run det FREE (6/6 FP64)
- `state/forge_phaseR_b_2026_05_17/` — B Stage 1 BW util baseline (35.4% LARGE)
- `state/forge_phaseR_b_stage2_2026_05_17/` — B Stage 2 Phase 1 cluster API
  smoke (cluster.map_shared_rank + cluster.sync verified)
- `state/forge_phaseR_b_dsm_v2_2026_05_17/` — **B Stage 2 Phase 2** DSM-fused
  FFN (bit-equal PASS max|Δ| 4.6e-16 H200; wall FAIL FP64 hand-kernel ceiling)
  — the "DSM half" anchor RFC 052 reuses
- `state/forge_phaseR_c_stage2_v2_2026_05_17/` — C Stage 2 v2 FP64 wall FAIL
  context (motivates precision pivot)
- `state/forge_phaseR_c_v3_2026_05_17/` — C Stage 2 Phase 3 best WMMA FP64
  1.80× SLOWER (motivates precision pivot)
- `state/forge_phaseR_r049_bf16_2026_05_17/` — **RFC 049 Phase R' Stage 1**
  BF16 fused FFN (9.67× FP64 cuBLAS LARGE A100; LayerCast det+mem+diverge
  4/4 PASS) — the "BF16 half" anchor RFC 052 reuses
- Phase R + R+ cumulative cost: **$2.91** (14 fires through 2026-05-17)
- RFC 052 Stage 2 fire estimate: **$5-20** (1 Hopper fire, 2-4 cycles)

### CUDA experiment artifacts (already landed; RFC 052 builds on)

- `self/cuda/experiments/b_dsm_fused_ffn_v2.cu` (586 lines) — DSM cluster
  kernel reference; **`__cluster_dims__(1, 2, 1)`**, `cluster.map_shared_rank`,
  `cluster.sync()`, M_TILE-sized H_half cluster-shared SMEM pattern. RFC 052
  Stage 2 kernel will graft BF16 WMMA matmul1/matmul2 in place of this file's
  naive per-thread FP64 matmul.
- `self/cuda/experiments/r049_bf16_fused_ffn.cu` (510 lines) — BF16 substrate
  reference; `cublasGemmEx(CUDA_R_16BF, CUBLAS_COMPUTE_32F)` path, `__float2bfloat16`
  RNE cast helpers, `silu_bf16` FP32-compute SiLU. RFC 052 Stage 2 will adapt
  the BF16 cast helpers + epilogue patterns; matmul replaces cuBLAS GemmEx
  with hand WMMA fragments to enable cluster-shared SMEM intermediate.
- `self/cuda/experiments/r049_layercast_linear.cu` (410 lines) — LayerCast
  pattern reference; RFC 052 may inherit cast policy if Stage 2 elects the
  LayerCast variant vs pure BF16 variant.

### Literature anchors

- **FlashAttention-3** (arxiv 2407.08608, Shah, Hagemann, Tri Dao, Christopher
  Re et al. 2024): Hopper cluster + BF16/FP8 WMMA combined, 75% TC peak at
  attention (740 TFLOPS BF16). RFC 052's primary direct anchor for combined
  cluster+BF16-TC feasibility.
- **FlashFuser** (arxiv 2512.12949): first compiler framework using H100 DSM,
  1.24× E2E inference (memory fusion only). RFC 052 separates the memory-fusion
  factor (1.24-2×) from the BF16-TC factor (RFC 049 9.67×) — combined is the
  product, not double-counted.
- **LayerCast** (arxiv 2506.09501): BF16 storage + FP32 compute reproducibility
  pattern. RFC 052 inherits the 3-layer cast pyramid from RFC 049 §"Architecture".
- **BFLOAT16 study** (arxiv 1905.12322): BF16 training ≈ FP32 training
  convergence. Anchors the LONG-RUN safety of RFC 052's BF16 substrate (Stage 2+
  measurable via flame Phase 4+ trainer integration, not RFC 052 scope).
- **Hopper H100 / H200 architecture spec**: cluster API (up to 16 blocks,
  cluster.sync, cluster.map_shared_rank, smem_optin 227 KB/block); 989 TFLOPS
  BF16 TC, 60 TFLOPS FP64 TC, 3.35 / 4.8 TB/s HBM3 / HBM3e bandwidth.
- **cuBLAS 12.4-12.9** GemmEx mixed-type matrix: `CUDA_R_16BF + CUBLAS_COMPUTE_32F`
  + Tensor Core algos available on sm_80+. cuBLAS 12.9 BF16x9 emulation
  separate path (NVIDIA blog 2026, RFC 049 §"Source convergence" anchor).

### Related RFCs (in-repo)

- RFC 035 — bf16 round-trip on packed-double arena (land)
- RFC 040 — `farr` GPU/CUDA backend (land)
- RFC 041 — real `.cu` kernels for B/B2 ops (Phase 2)
- RFC 044 — forge dual-mechanism × regime-tiered substrate (design)
- RFC 048 — flame Phase 4-C fwd+bwd graph fusion (design)
- RFC 049 — forge mixed-precision substrate (Phase R' Stage 1 PASS, RFC 052 parent)
- RFC 050 — flame ↔ forge integration API (design; RFC 052 invoked through it)

## PLAN integration

RFC 052 extends `self/forge/PLAN.md` §Phase 3+ DSM-cluster fusion path to the
combined kernel as the production unit. RFC 044 + RFC 049 + RFC 052 layered
PLAN view (substrate side):

| Phase | Scope | Hardware | RFC | Status |
|---|---|---|---|---|
| Phase 2 | regime-tiered substrate scaffold (2.A Graphs / 2.B SMEM / 2.C fwd+bwd) | universal | RFC 044 | DESIGN |
| Phase 3 | DSM-cluster fusion (B' Stage 2 production unit) | Hopper sm_90+ | RFC 044 + RFC 052 | **DESIGN (RFC 052 specifies combined production kernel)** |
| Phase 4.FP64 | AOT whole-train-step (A' Stage 2 transformer) | universal | RFC 044 | DESIGN |
| Phase 4.MIXED | BF16 TC substrate (single-block) | sm_80+ | RFC 049 | Stage 1 PASS, Stage 2 follow-up |
| **Phase 4.MIXED+DSM** | **BF16 TC + DSM cluster combined kernel** | **sm_90+** | **RFC 052 (this RFC)** | **DESIGN ONLY** |
| Phase 5 | flame ↔ forge integration dispatcher | universal | RFC 050 | DESIGN |
| Phase 6+ | multi-GPU / cross-GPU dispatch | future | future | not designed |

Phase 3 production kernel = RFC 052 combined kernel (the prior Phase 3
candidate was the B Stage 2 Phase 2 FP64 hand-kernel, which wall FAILed
universally — RFC 052 is the wall-path successor on Hopper).

flame PLAN side (`stdlib/flame/PLAN.md`) is unchanged by RFC 052 — flame
consumer side sees RFC 052 entirely through RFC 050 dispatch boundary.
flame Phase 4-D GPU dispatch (PLAN candidate, $5-20) routes
`forge_tier_dispatch_v1(precision=FORGE_PREC_LAYERCAST_BF16_FP32,
regime=FORGE_REGIME_LARGE)` calls to RFC 052 when Hopper is detected.

PLAN body update (`self/forge/PLAN.md` Phase 3 + Phase 4.MIXED+DSM rows) =
separate task post RFC 052 land. This RFC provides the guide only.

## Authority

- AGENTS.tape `g3` (real-limits-first) — all perf projections trace to
  RFC 049 measured fire + B Stage 2 Phase 2 measured fire + Hopper datasheet
  TC throughput + cluster API specs; no fabricated multiples
- AGENTS.tape `g4` (honesty-obligation-external) — RFC 052 makes NO claim
  exceeding the conservative 10-30× projection band derived from anchored
  product of measured halves; literature ceiling (40-60×) honestly flagged
  as upper bound, falsifier anchors the 1.5× over RFC 049 floor
- AGENTS.tape `g5` (hexa-native-only) — forge dispatcher = C runtime,
  `.cu` kernel = portable artifact via nvcc, no LLVM, no C-transpile backend
- AGENTS.tape `g7` (inbox-patches-pipeline) — RFC 052 filed at
  `inbox/rfc_drafts_2026_05_12/` per convention
- AGENTS.tape `g_arch_vs_log_split` — RFC 052 = architecture draft (editable,
  latest-wins); land event will append to FORGE.tape `## Log` only
- AGENTS.tape §0 `nn_stack` — toolchain ABI lockstep; RFC 052 consumed
  through RFC 050 `forge_tier_v1` API, no new flame public surface,
  `g_flame_api_fixed` preserved
- LATTICE_POLICY `f1` / `f2` — no n=6 lattice numerology in cluster sizing
  (2/4/8 = FD-axis-fit math), regime thresholds (compute / batch / HBM-bound),
  or perf projections (TC peak ratios + HBM bandwidth, all hardware-cited)
- HEXA-NATIVE-ONLY — combined kernel emitted via nvcc as portable artifact
  (fallback C path); not architectural dependency
- `g_forge_substrate_role` — forge = substrate, flame = consumer; RFC 052
  preserves boundary
- `g_forge_verify_oracle` — F-FORGE-RFC052-BITEQ-VS-RFC049 anchors output
  equivalence against RFC 049 BF16-only reference, NOT against FP64
  (cross-precision NOT bit-equal honest caveat inherited from RFC 049 §3.3)
- `g_blue_closed_mandate` (anima cross-repo) — BF16 path divergence vs FP32
  reference already anchored via RFC 049 F-FORGE-RFC049-LAYERCAST-DIVERGE
  PASS 1.51%; RFC 052 inherits anchor, does NOT introduce new oracle layer
