# RFC 049 — forge: mixed-precision substrate (BF16 Tensor Core + LayerCast-style det)

- **Status**: design-draft (2026-05-17) — DESIGN ONLY, no implementation
- **Date**: 2026-05-17
- **Severity**: HIGH (forge 의 FP64-only substrate 가 Hopper/Blackwell Tensor Core 를 사용할 수 없는 구조적 한계 — Phase R Stage 2 C v2 wall FAIL 의 근본 원인 candidate)
- **Priority**: P2 (RFC 044 / RFC 040+041 기반 위에서 mixed-precision tier 추가; flame Phase 4+ 와 paired, 즉시 fire 아님)
- **RFC-number note**: 본 RFC 의 number 는 user 가 요청한 "RFC 047" 이 이미 flame Phase 4b (rfc_047_flame_phase4b_block_fusion_ir_pass.md) 에 할당되어 049 로 land. PARADIGM.md §2.4 + §10 의 "RFC 047+" 표기는 그 placeholder 가 만들어진 시점에 flame Phase 4b RFC 가 존재하지 않았던 데 기인하는 stale label — 본 RFC (049) 가 paradigm 적 successor. PARADIGM.md 갱신은 별도 task.
- **Source convergence**:
  - LayerCast paper (arxiv 2506.09501) — BF16 weight + FP32 compute = FP32-level reproducibility + 34% memory save
  - Phase R Stage 2 C v2 wall FAIL (state/forge_phaseR_c_stage2_v2_2026_05_17 — multi-block fused fwd+bwd 가 cuBLAS Dgemm 보다 5.99-32.3× slower; root cause = FP64 substrate 가 Tensor Core 못 사용)
  - forge thesis (PARADIGM.md §7) — "regime-tiered substrate, 공통 D' within-run det FREE" + §10 non-claim "cross-precision (BF16/FP16) 는 본 paradigm 에 포함 X, LayerCast paradigm 별도 RFC"
  - cuBLAS 12.9 BF16x9 FP32 emulation — Hopper/Blackwell BF16 TC 로 FP32 wall 3-4× 빨라짐 (NVIDIA 공식)
- **Source evidence (g3 — every claim below traces to a real capture or cited literature)**:
  - `state/forge_phaseR_c_stage2_v2_2026_05_17/result.json` + `C_STAGE2_V2_ANALYSIS.md` — multi-block fused FP64 kernel 가 모든 shape 에서 cuBLAS Dgemm 대비 wall slower (128³ 5.99×, 256³ 32.3×, 512³ 25.4×). bytes_ratio = 0.6667 PASS, det PASS, **wall FAIL across the board** — F5 (Phase 3 perf path): "Production CUDA fused kernel ... 또는 Tensor Core 활용 위한 mixed precision (FP64 master + BF16 compute)"
  - `state/forge_phaseR_d_2026_05_17/D_ANALYSIS.md` §3 F2 — H100 cuBLAS DEFAULT 가 PEDANTIC 과 bit-equal output 하면서 +15-33% 빠름. F2 가설: "DEFAULT 가 FP64 emulation via Tensor Core composite (cuBLASLt heuristic) 가능" — Hopper FP64 TC 가 없는데 wall 차이가 있다면 다른 path. **검증 필요** (ncu profiling, RFC 049 후속).
  - `self/forge/PARADIGM.md` §2.4 — "LayerCast-style cross-precision (BF16/FP16) determinism 은 별도 paradigm (RFC 047+, 현 forge 의 FP64 packed-double farr 무관)" — 본 RFC 가 그 placeholder 의 실체화.
  - `self/forge/PARADIGM.md` §8 D-stage-2 row — "BF16/FP16 substrate determinism. LayerCast paradigm (RFC 047+). FP64 forge 와 직교. priority LOW — flame 의 mixed-precision plan 후."
  - **Literature anchors** (PARADIGM_RESEARCH.md §3 + 본 RFC web search):
    - LayerCast (arxiv 2506.09501 v1/v2): BF16 weight, FP32 compute, just-in-time upcast → divergence rate **≤ 3.4%** vs full FP32 (BF16-only 9.15% std deviation, AIME'24 DeepSeek-R1-Distill-Qwen-7B). Memory **34% 감소**.
    - cuBLAS 12.9 BF16x9: H100/Blackwell BF16 TC 로 FP32 emulate, native FP32 matmul 대비 **3-4×** wall speedup (NVIDIA blog 2026).
    - H100 SM_90 throughput: FP64 TC **60 TFLOPS** vs BF16/FP16 TC **989 TFLOPS** → **~16× theoretical raw throughput ratio**. Native FP32 TC 67 TFLOPS, TF32 TC 989 TFLOPS.
    - BF16 numerical: 8-bit exponent (FP32 동일 dynamic range) + 7-bit mantissa. Loss scale **불필요** (FP16 와 다른 점, NVIDIA Hopper docs).
    - WMMA tile (Hopper sm_90): 16×16×16 for FP16/BF16, 16×16×32 for FP8, 16×8×32 for TF32. PTX `mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32`.

## Scope of this RFC — DESIGN DRAFT, honest framing

본 RFC 는 **design document only**. forge 의 FP64-only substrate 위에
mixed-precision tier (BF16 storage + BF16 Tensor Core compute + FP32
accumulator + FP64 master weight) 를 **paradigm 으로 명세**하고,
falsifier 사전등록 + literature anchor land 만 한다. 어떤 .cu / hexa
source 도 본 RFC 에서 추가 안 함. 후속 Phase R' (mixed-precision fire
campaign) 가 별도 RFC + user gate.

RFC 044 의 dual-mechanism × regime-tiered substrate 위에서 본 RFC 가
**제3의 직교 mechanism (precision-tiered storage/compute)** 를 더한다.
RFC 035 (bf16 round-trip on packed-double arena) 와 RFC 047 (flame
Phase 4b block fusion IR pass) 와 직교 — 둘 다 본 RFC 의 substrate 위
에서 작동 가능. flame 측 surface (autocast policy 등) 는 본 RFC 의
scope 밖 (flame stdlib 책임, RFC 043 consumer).

## Problem — FP64 substrate 의 Tensor Core 사용 불가 한계

### Phase R Stage 2 C v2 (multi-block fused fwd+bwd) wall FAIL 의 root cause

`state/forge_phaseR_c_stage2_v2_2026_05_17/C_STAGE2_V2_ANALYSIS.md` 의
F3-F5 가 wall FAIL 의 mechanism 을 명확히 가르친다:

- F3 — Wall time SLOWER than Phase 1 single-block at large shape (256³)
- F4 — "cuBLAS Dgemm 가 큰 shape 에서 superior scaling (Tensor Core
  무관, 단순 CUDA Core 도 cuBLAS 가 잘 optimized)"
- F5 — "Production C fused kernel 필요 features: ... 또는 Tensor Core
  활용 위한 mixed precision (FP64 master + BF16 compute)"

즉 **FP64 substrate 에서는 H100 BF16 TC (989 TFLOPS) / FP16 TC (989
TFLOPS) / TF32 TC (989 TFLOPS) 에 접근 불가**. FP64 TC 는 60 TFLOPS
이고, cuBLAS Dgemm 자체가 이미 그 ceiling 의 76% (51.24 TFLOPS, FORGE
.tape x_oracle_cublas) — custom FP64 kernel 가 cuBLAS 를 넘기는 것은
hardware ceiling 에 가까운 영역. **fusion 으로 traffic 33% 줄여도 wall
time 은 compute 가 cuBLAS Dgemm 의 1/N 효율이면 무용**.

### LayerCast 가 가르치는 cross-precision 결정성 보존

LayerCast (arxiv 2506.09501) 가 BF16 nondeterminism 의 mechanism 과
mitigation 을 명확히 anchor:

- **BF16 only** (storage + compute): DeepSeek-R1-Distill-Qwen-7B AIME'24
  9.15% accuracy std deviation (greedy decoding 에서, GPU 수/유형/배치
  변화에 따라). 9000+ token response length 차이.
- **FP32 only**: ~0% std deviation. 비용 = 2× memory + 2× wall.
- **LayerCast (BF16 storage + FP32 compute, JIT upcast per linear)**:
  divergence rate ≤ 3.4%, **FP32-level reproducibility 달성** + 34%
  memory save.

이건 forge 의 D' (within-run det FREE, FP64 single-process) 의
**mixed-precision generalization** 이다. forge 가 BF16 substrate 를
land 한다면 LayerCast-style storage/compute split 이 D' 의 substrate-
level 보존 mechanism.

### gap (현 SOTA 와 forge 의 distinctive 위치)

| dimension | 현 SOTA | forge 의 distinctive 위치 |
|---|---|---|
| BF16 substrate 결정성 | PyTorch AMP = nondeterministic (GradScaler heuristic + atomic_add) · LayerCast = inference-only manual pipeline | **AOT-compiled BF16 storage + FP32 compute path** (LayerCast 의 training 일반화 + substrate-level 보존) |
| Tensor Core 활용 (training) | torch.compile + AOTInductor = JIT (compile cost per shape) · Mojo MAX = inference-first | **AOT single-binary BF16 TC kernel chain** (RFC 044 A' Stage 2 의 mixed-precision 확장) |
| Master weight (FP64) | PyTorch AMP = FP32 master (FP64 X) · NVIDIA Apex = FP32 master · 모든 stack FP32 ceiling | **FP64 master weight** (RFC 035 의 packed-double arena 와 lockstep) — 더 conservative dynamic range, AdamW state 더 정확. trade-off = 2× master memory. |
| cuBLAS BF16x9 emulation | cuBLAS 12.9 H100/Blackwell 에서 FP32 wall 3-4× 가능 | **substrate-level FP32 path** option: BF16 TC 로 BF16x9 emulate → effective FP32 compute at TC throughput. 별도 paradigm tier. |

## Proposal — mixed-precision substrate architecture (3-layer cast)

forge 의 mixed-precision tier 는 LayerCast 의 generalization +
PyTorch AMP 의 master-weight contract + cuBLAS BF16x9 의 emulation
option 을 **하나의 substrate-level paradigm 으로 통합**.

### Architecture (3-layer cast pyramid)

```
                     FORGE MIXED-PRECISION SUBSTRATE
  ┌──────────────────────────────────────────────────────────────────┐
  │  Layer 1 — MASTER WEIGHTS                                         │
  │    Storage: FP64 packed-double farr (RFC 025/032/034/035)         │
  │    Use: AdamW step, gradient accumulation across micro-batches    │
  │    Anchor: D' within-run det FREE (PARADIGM §2.4)                 │
  └──────────────────────────────────────────────────────────────────┘
                              ↓ cast (RNE, RFC 035-style)
  ┌──────────────────────────────────────────────────────────────────┐
  │  Layer 2 — COMPUTE WEIGHTS                                        │
  │    Storage: BF16 storage class (NEW — half-width arena)           │
  │    Use: forward matmul, backward dW/dX                            │
  │    Cast: just-in-time per linear (LayerCast-style)                │
  │    Anchor: ≤ 3.4% divergence vs FP32 (paper)                      │
  └──────────────────────────────────────────────────────────────────┘
                              ↓ load to TC (wmma::fragment)
  ┌──────────────────────────────────────────────────────────────────┐
  │  Layer 3 — COMPUTE                                                │
  │    Hardware: H100/H200 BF16 TC (989 TFLOPS)                       │
  │    Accumulator: FP32 (mma.sync.f32.bf16.bf16.f32)                 │
  │    Output cast: FP32 → BF16 (storage) 또는 FP32 → FP64 (master    │
  │      gradient before AdamW)                                       │
  │    Loss scale: NOT NEEDED for BF16 (8-bit exponent = FP32 range)  │
  └──────────────────────────────────────────────────────────────────┘
```

### Components (Stage 1 = design only, Stage 2+ = follow-up RFC + fire)

1. **BF16 storage class (`farr_bf16`)** — Stage 2 (RFC 050+):
   - Half-width arena (현 RFC 035 v1 의 "packed-double 위 RNE 라운드" 와 다른
     실제 byte halving). RFC 035 v1 의 Roadmap (RFC 035 §"Roadmap follow-up")
     가 명시한 follow-up.
   - ABI: `hexa_farr_bf16_alloc(n) -> ptr` · `hexa_farr_bf16_to_f64(src, dst, n)`
     · `hexa_farr_bf16_from_f64(src, dst, n)`. ALL deterministic (RNE).
   - Memory: BF16 = 2 bytes/elem vs FP64 8 bytes → **75% reduction at storage
     layer** (LayerCast 의 34% 는 KV-cache 만 BF16, 본 RFC 는 weight + activation
     모두 BF16 가능 → 더 큰 reduction).
   - flame 측 surface: `tensor.to_bf16()` / `tensor.master()` (flame Phase 3+ 의 책임).

2. **BF16 Tensor Core compute kernels (`*_bf16_gpu`)** — Stage 2 (RFC 050+):
   - `hexa_farr_matmul_bf16_gpu(A, B, C, M, N, K)` — cuBLAS GemmEx with
     `CUDA_R_16BF` input + `CUDA_R_32F` compute + `CUDA_R_32F` accumulator,
     output written back as BF16 (또는 FP32 캐스트 후 caller 가 BF16 round).
   - 새 .cu kernel (`self/cuda/farr_matmul_bf16.cu` 등) — wmma::fragment 또는
     PTX `mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32`.
   - Fused epilogue tier (RFC 044 B'/C' Stage 2) 의 BF16 TC 버전:
     `farr_ffn_bf16_gpu` (BF16 matmul → SwiGLU FP32 → BF16 matmul, FP32
     accumulator 전체). DSM cluster (Hopper) 와 직교 — DSM 은 SMEM scale,
     BF16 TC 는 compute throughput.

3. **LayerCast-style JIT upcast policy** — Stage 2+ (RFC 050+):
   - flame compile-time 시점에 forge dispatcher 가 (model precision policy)
     × (kernel) 매칭 → 적절한 cast 삽입.
   - 3 modes (precision policy):
     - **`full_fp64`** (current default): D' anchor. Master = FP64, compute = FP64.
       No TC use. Slowest, most accurate.
     - **`layercast_bf16_fp32`** (recommended for large model training):
       Master = FP64, storage (weight) = BF16, compute = FP32 (cuBLAS BF16x9
       emulation 또는 BF16 TC + FP32 acc + LayerCast JIT cast). Memory 34-75%
       save, wall ≤ 0.3× FP64 (literature anchor).
     - **`pure_bf16`** (max throughput, accept ≤ 3.4% divergence):
       Master = BF16, storage = BF16, compute = BF16 TC + FP32 acc.
       Loss scale NOT needed (BF16 exponent range = FP32 range). Fastest,
       lowest memory, highest divergence.

4. **Cross-precision determinism contract** — Stage 2 (사전등록):
   - **Within-precision within-run**: BF16 single-process single-GPU 도 forge
     dispatch path 에서 bit-equal (cuBLAS GemmEx deterministic mode +
     atomic-add 회피 + tree-reduce custom kernel). D' anchor 의 BF16 generalization.
   - **Cross-precision NOT bit-equal**: FP64 vs BF16 vs FP16 outputs 는 numerical
     close (≤ 1e-2 relative, LayerCast anchor) 이지만 bit-equal X. 정직한 caveat.
   - **Cross-batch-size NOT bit-equal** (BF16 substrate): LayerCast paper §3
     anchor — batch 변화 때 reduction tree 가 다르면 BF16 mantissa cancellation
     으로 divergence. forge dispatcher 가 batch-size aware kernel 선택해야
     batch-stable det 가능. (FP64 substrate D' 는 이 limitation 없음, RFC 049
     mixed-precision 의 honest caveat.)

5. **AdamW master-weight update (FP64 path 보존)** — Stage 2 (RFC 050+):
   - RFC 035 의 `adamw_step_mixed` 가 이미 master-weight contract 구현
     (FP64 m, v, param + low-prec gradient 소비, loss_scale unscale, skip-on-
     nonfinite). 본 RFC 가 substrate 에 BF16 storage class 추가 후 RFC 035 의
     `adamw_step_mixed` 가 native BF16 grad input 으로 동작.
   - **Loss scale 가 BF16 에서 필요?** LayerCast 와 BF16 spec (8-bit exponent
     = FP32 dynamic range) 가 일관되게 "BF16 에서 loss scale 不必要" 라고 anchor
     — FP16 와 다른 점. 그러나 RFC 035 의 `adamw_step_mixed` 가 loss_scale 인자
     포함 = optional (loss_scale=1.0 가 BF16 default). conservative defensiveness.

### What this RFC does NOT do

- No CUDA kernel implementation (Stage 2+ = 별도 fires + RFC 050+).
- No flame stdlib changes (flame Phase 1 in-flight + Phase 3+ surface = flame 책임).
- No RFC 044 supersession — 본 RFC 가 RFC 044 의 dual-mechanism × regime-tiered
  위에 mixed-precision tier (제3 mechanism) 추가.
- No RFC 035 supersession — RFC 035 v1 의 packed-double 위 BF16 round-trip 가
  Stage 1 (current); 본 RFC 가 Stage 2 의 half-width arena 토대.
- No flame Phase 4 (RFC 046/047/048) supersession — 그들이 flame 측 fusion IR.
  본 RFC 는 forge 측 substrate. 양쪽 양립.
- No FP8 / TF32 substrate. BF16 + FP16 + FP32 (compute) + FP64 (master) only.
  FP8 (E4M3/E5M2) 는 별도 RFC (FP8-LM arxiv 2310.18313 anchor 필요).
- No mixed-precision inference framework (vLLM 영역, RFC 044 Stage 2 A' 의 응용 영역). 본 RFC = training substrate 우선.

## Falsifier battery (Stage 2 pre-registered, 7 falsifiers — literature anchor land)

각 falsifier 는 **compiled-native 경로** (`hexa build` AOT) + Phase R'
mixed-precision fire 에서만 PASS 인정. 가짜 target 금지 — reference 는
LayerCast paper anchor + RFC 035 v1 anchor + cuBLAS BF16x9 NVIDIA blog
data 만.

### Tier 1 — Tensor Core perf (Mechanism 검증)

- 🟡 **F-FORGE-RFC049-BF16-TC-PERF**: forge BF16 TC fused FFN (M=128, D=4096,
  FD=11008 — Llama-7B scale) latency ≤ **0.2 × cuBLAS Dgemm FP64 chain**
  (현 RFC 044 B Stage 1 baseline = 0.4461 ms H200, 본 falsifier target ≤ 0.09 ms).
  Literature anchor: BF16 TC 989 TFLOPS vs FP64 TC 60 TFLOPS = 16× theoretical;
  realistic kernel ~30% TC util → 5× wall expected. **"≥ 5×"** 사전등록 conservative
  (literature 의 16× 의 1/3 만 claim).
- 🟡 **F-FORGE-RFC049-BF16x9-FP32-EMULATE**: forge BF16x9 emulation path (cuBLAS
  GemmEx 12.9 BF16 input + FP32 compute) wall ≤ **0.4 × cuBLAS Sgemm native
  FP32** (cuBLAS NVIDIA 2026 blog anchor: 3-4× speedup → ≤ 0.33× wall; conservative
  ≤ 0.4×).

### Tier 2 — LayerCast 결정성 보존 (Substrate det contract)

- 🟡 **F-FORGE-RFC049-LAYERCAST-DET**: BF16 storage + FP32 compute single-process
  single-GPU forge dispatch path = **same-precision same-batch bit-equal**
  (within-run det). FP64 D' anchor 의 BF16 generalization. **anchor**: 두 번 같은
  seed 같은 batch 같은 GPU → byte-identical BF16 output.
- 🟡 **F-FORGE-RFC049-LAYERCAST-DIVERGE**: BF16 storage + FP32 compute LLM inference
  divergence rate **≤ 5%** vs full FP32 baseline (LayerCast paper anchor ≤ 3.4%,
  forge target conservative ≤ 5%). DeepSeek-R1-Distill-Qwen-7B AIME'24 또는 equivalent
  reasoning benchmark. **paper 직접 anchor**.

### Tier 3 — Memory saving (Storage class)

- 🟡 **F-FORGE-RFC049-LAYERCAST-MEM**: BF16 weight storage (half-width arena)
  footprint ≤ **0.3 × FP64 footprint** (실 BF16 = 0.25 × FP64, target ≤ 0.3×
  로 overhead 5% margin). LayerCast 의 34% mem save 자릿수 — 본 RFC 는 weight
  + activation 모두 BF16 가능 → 더 큰 reduction. 측정 = same model state_dict
  serialized in both formats.

### Tier 4 — Numerical safety (Training convergence anchor)

- 🟡 **F-FORGE-RFC049-NO-DIVERGE-FP32-TRAIN**: BF16 forward + BF16 backward +
  FP64 master + AdamW (`adamw_step_mixed` from RFC 035) 가 full-FP64 training
  대비 final loss ≤ **1.05 × FP64 baseline** (≤ 5% accuracy degradation) over
  100-1000 step convergence on representative benchmark (MNIST + small transformer
  scale). 별도 fire 필요 — flame Phase 4+ trainer 통합 후.
  - **paper anchor**: BFLOAT16 study (arxiv 1905.12322) — BF16 training 가 FP32
    training 과 거의 동등 (RNet-50, Transformer, GAN 등 광범위). 본 falsifier
    가 그 anchor 의 forge substrate-level 재현.

### Tier 5 — Hardware portability honest caveat

- 🟡 **F-FORGE-RFC049-HW-PORTABILITY**: BF16 substrate path 가 **sm_80+** (A100,
  H100, H200, B100, B200) 에서 functional. sm_70 (V100) = FP16 fallback path
  지원 (BF16 hardware X). sm_60 이하 = mixed-precision substrate 미지원
  (FP64-only fallback). forge dispatcher 가 cc query 후 적절한 path 선택.
  **anchor**: NVIDIA Hopper datasheet (sm_90 BF16 TC full support); A100 sm_80
  BF16 TC 지원 (Ampere) but smaller TC count.

🟡 = Stage 2+ 사전등록 (별도 fire + RFC 050+ 가 검증)
모든 falsifier 미실측 — 본 RFC = design + sufficient pre-reg only.

## Honest caveats (g3 / f1 / f2 — no over-claim)

### 1. Numerical range / cancellation

- **BF16 의 7-bit mantissa** 가 FP32 의 23-bit / FP64 의 52-bit 보다 훨씬 작음.
  Linear-layer 의 reduction (K-dim sum) 에서 **catastrophic cancellation 가능**
  — small gradient elements (≤ 1e-3) 가 large activation reduction 에서 사라짐.
  FP32 accumulator 가 mitigate, 그래도 100% safety 아님.
- **LayerCast 의 ≤ 3.4% divergence** 는 inference 결과 anchor (DeepSeek-R1-Distill).
  **Training convergence** divergence 는 paper 가 직접 측정 X — 본 RFC 의
  F-FORGE-RFC049-NO-DIVERGE-FP32-TRAIN 가 그 gap 채우기 사전등록.
- **Gradient explosion threshold** (BF16 max ~3.4e38 same as FP32) 는 BF16 가 FP16
  보다 안전하지만, mantissa cancellation 누적 시 explode 까지 가는 case 가능.
  PyTorch AMP 의 NaN-guard / RFC 035 의 skip-on-nonfinite 가 기존 safety net.

### 2. Tensor Core 한정 hardware

- **BF16 TC**: sm_70 (V100) 미지원, sm_75 (Turing) FP16 TC only, **sm_80+ (Ampere)
  부터 BF16 TC 지원**. forge 가 sm_70/sm_75 fallback path 별도 필요 (FP16 TC 또는
  FP32 software emulation). 본 RFC 의 distribution 가정 = H100/H200/A100/B100 만
  primary target.
- **DSM cluster API**: Hopper sm_90 only. mixed-precision substrate 와 DSM fusion
  결합 시 sm_90 lock-in. A100 fallback = single-block kernel (RFC 044 B' Stage 2
  와 동일 caveat).
- **WMMA fragment API** vs **mma.sync PTX**: WMMA = wrapper, mma.sync = native
  intrinsic. forge 가 PTX 직접 emit 할지 (HEXA-NATIVE-ONLY 가 nvcc 의존 가능 모드
  명시) 결정 필요 — current path = .cu via nvcc (RFC 040/041 와 일관).

### 3. D' (within-run det FREE) 의 mixed-precision 보존 형태

- FP64 substrate D' = within-run + single-process + single-GPU 에서 bit-equal.
- BF16 substrate 의 D' 는 **same-precision same-batch same-GPU single-process**
  에서만 bit-equal. cross-batch-size, cross-GPU-count 는 BF16 mantissa cancellation
  으로 divergence (LayerCast §3 anchor).
- FP64 D' 의 boundary 는 **same-process** 이고, BF16 D' 의 boundary 는 **same-
  process + same-batch + same-GPU** — strictly narrower. flame 측 precision
  policy 가 trade-off 명시 mandatory.
- **PEDANTIC mode (FP64)** = numerically equivalent (cross-mode bit-equal). BF16
  PEDANTIC equivalent **존재하지 않음** — BF16 TC algorithms 가 cuBLAS algo path
  마다 다른 reduction tree → bit-equal output 보장 불가. honest caveat.

### 4. "5× perf claim" anchor — literature only, 실측 미증명

- F-FORGE-RFC049-BF16-TC-PERF 의 "≥ 5×" 는 H100 BF16 TC (989 TFLOPS) vs FP64 TC
  (60 TFLOPS) = 16× theoretical 의 ~1/3 conservative.
- **literature anchor 만**: cuBLAS 12.9 BF16x9 의 FP32 wall 3-4× speedup (NVIDIA
  공식 blog 2026). FlashFuser 의 1.24× E2E inference (memory fusion only, BF16
  TC 무관).
- **실측 검증**: Phase R' (mixed-precision fire campaign) 가 별도 fire — 본 RFC
  는 design + pre-reg only. 실측 결과 가 5× 미달이면 falsifier FAIL, 본 RFC 의
  paradigm reframe 트리거 (RFC 049' 등).

### 5. forge ↔ flame interface 변경

- 본 RFC 가 land 되면 forge dispatcher API 가 `precision_policy` 인자 받음.
- flame 측 (RFC 043 의 flame stdlib) 가 model compile-time 에 precision policy
  결정 → forge 에 dispatch. RFC 043 의 flame surface 변경 follow-up RFC 필요
  (본 RFC scope 밖, flame Phase 4+ trigger).
- RFC 035 의 `adamw_step_mixed` 가 이미 master-weight contract 구현 — 본 RFC
  가 그 contract 의 substrate-level 일반화.

### 6. No lattice / perfect-number numerology (f1/f2 deny)

- forge mixed-precision perf anchor = BF16 TC throughput (NVIDIA hardware spec) +
  HBM bandwidth (H100 3.35 TB/s, H200 4.8 TB/s) + LayerCast paper data — 모두
  measured / cited.
- n=6 lattice 와 무관. BF16 mantissa bit count (7) / FP32 mantissa (23) / FP64
  mantissa (52) 도 lattice 와 무관 (IEEE 754 standard).

## Non-goals (this RFC)

- 어떤 .cu 도 land 안 함 — design draft only.
- 어떤 hexa source 도 land 안 함 (flame surface 는 flame Phase 4+ RFC).
- flame stdlib 변경 0 — forge ↔ flame boundary 는 RFC 043 / flame 의 책임.
- RFC 044 / 045 / 046 / 047 / 048 supersession 안 함 — 본 RFC 가 그들 위에 직교
  precision-tier 추가.
- RFC 035 (BF16 round-trip on packed-double) supersession 안 함 — Stage 1 v1
  이 본 RFC 의 Stage 2 half-width arena 의 precursor.
- FP8 (E4M3/E5M2) substrate = out of scope (별도 RFC, FP8-LM arxiv 2310.18313
  anchor).
- TF32 substrate = out of scope (TF32 는 input-side truncation only, BF16
  substrate 의 special case 로 흡수 가능 but 별도 RFC).
- Multi-GPU / cross-GPU determinism = out of scope (RFC 044 Phase 5+).
- Inference framework integration (vLLM / TensorRT-LLM 영역) = out of scope.

## Cross-RFC dependency

- **RFC 035** (`farr` BF16 round-trip on packed-double arena) — 본 RFC 의 v1
  precursor. RFC 035 Roadmap §"A true half-width `bf16_farr` storage class" 가
  본 RFC 의 Stage 2 component 1.
- **RFC 040** (`farr` GPU/CUDA backend) — 본 RFC 의 base substrate. device-farr
  alloc/copy/free + cuBLAS Dgemm + TOL_MATMUL spec 모두 살아있음.
- **RFC 041** (real `.cu` kernels for B/B2 ops) — 본 RFC 의 BF16 TC kernels
  (`farr_matmul_bf16_gpu`, `farr_ffn_bf16_gpu`) 가 RFC 041 의 11-op kernel
  family 의 BF16 variant.
- **RFC 042** = SUBSUMED by RFC 043 (do not reuse).
- **RFC 043** (flame stdlib design) — 본 RFC 의 consumer. flame 가 precision
  policy 를 compile-time 에 결정 → forge dispatch.
- **RFC 044** (forge dual-mechanism × regime-tiered substrate) — 본 RFC 가 그 위에
  precision-tier (제3 직교 mechanism) 추가. RFC 044 의 dual-mechanism (dispatch
  elimination + memory fusion) 모두 BF16 substrate 위에서 작동.
- **RFC 045** (flame Phase 3 algorithmic byte-eq with anima oracle) — 본 RFC 와
  직교 (flame 측 oracle, forge 측 substrate).
- **RFC 046 / 047 / 048** (flame Phase 4/4b/4c compiler fusion) — 본 RFC 와 직교.
  flame fusion IR 가 본 RFC 의 BF16 substrate 위에서 fuse 가능.
- **RFC 050+** (future): mixed-precision Stage 2 implementation RFC (per component
  — 050 BF16 storage class + GemmEx, 051 LayerCast JIT cast policy, 052 BF16 TC
  fused FFN kernel, etc.) — 각 Stage 2 fire 후 별도 RFC.

## Cross-link (literature + measurement anchor — g3)

### forge SSOTs
- `self/forge/PARADIGM.md` — 측정-anchored SSOT (FORGE.tape §X `x_paradigm_ssot`),
  특히 §2.4 (D' reframe) + §8 (D-stage-2 row) + §10 (non-claim "cross-precision
  은 RFC 047+ 별도") — 본 RFC 가 그 placeholder 의 실체화.
- `self/forge/PARADIGM_RESEARCH.md` §3 LayerCast (literature snapshot) — 본 RFC
  primary citation source.
- `self/forge/FORGE.tape` §X — `x_paradigm_ssot` + `x_phaseR_fires` + `x_oracle_cublas`.

### Phase R measurement evidence
- `state/forge_phaseR_d_2026_05_17/` — D fire (H100 6 shape, $0.40) — FP64 D' anchor
- `state/forge_phaseR_c_stage2_v2_2026_05_17/` — C Stage 2 v2 fire (A100 3 shape,
  $0.02) — multi-block FP64 wall FAIL root cause anchor (본 RFC 의 motivating evidence)
- `state/forge_phaseR_b_stage2_2026_05_17/` — B Stage 2 fire (H200 cluster API smoke,
  $0.12) — DSM API anchor (본 RFC 의 BF16 TC + DSM 결합 가능성 leverage point)
- `state/forge_phaseR_a_stage2_2026_05_17/` — A Stage 2 fire (A100 4-6× small batch,
  $0.30) — dispatch-elimination paradigm (본 RFC 의 BF16 path 가 그 mechanism 위에서 작동)
- Phase R 누적 cost: **$2.09** (8 fires complete) — 본 RFC 는 0 fire, design only.

### Literature (paper / blog / spec)
- LayerCast (arxiv 2506.09501 v1/v2): "Give Me FP32 or Give Me Death? Challenges
  and Solutions for Reproducible Reasoning" / "Understanding and Mitigating
  Numerical Sources of Nondeterminism in LLM Inference". https://arxiv.org/abs/2506.09501
- BFLOAT16 study (arxiv 1905.12322): "A Study of BFLOAT16 for Deep Learning Training"
  — BF16 training 가 FP32 training 과 거의 동등 (광범위 model anchor). https://arxiv.org/pdf/1905.12322
- FP8-LM (arxiv 2310.18313): "FP8-LM: Training FP8 Large Language Models" — out of
  scope but referenced for future FP8 substrate RFC. https://arxiv.org/pdf/2310.18313
- cuBLAS 12.9 BF16x9: "Unlocking Tensor Core Performance with Floating Point
  Emulation in cuBLAS" (NVIDIA blog 2026). https://developer.nvidia.com/blog/unlocking-tensor-core-performance-with-floating-point-emulation-in-cublas/
- NVIDIA Hopper Architecture In-Depth (BF16 TC, WMMA 16×16×16, mma.sync PTX):
  https://developer.nvidia.com/blog/nvidia-hopper-architecture-in-depth/
- NVIDIA H100 Tensor Core GPU Datasheet (60 TFLOPS FP64 TC vs 989 TFLOPS BF16/FP16 TC):
  https://www.megware.com/fileadmin/user_upload/LandingPage%20NVIDIA/nvidia-h100-datasheet.pdf
- PyTorch AMP docs (autocast bf16 + GradScaler + master weight contract):
  https://docs.pytorch.org/docs/stable/amp.html

### Related RFCs (in-repo)
- RFC 035 — bf16 round-trip on packed-double arena (이미 land, 본 RFC v1 precursor)
- RFC 044 — forge dual-mechanism × regime-tiered substrate (본 RFC 가 위에 precision-tier 추가)
- RFC 043 — flame stdlib design (본 RFC 의 consumer)
- RFC 047 — flame Phase 4b block fusion IR pass (RFC-number 충돌 reason)

## PLAN integration

본 RFC 가 `self/forge/PLAN.md` §Phase 4+ 본문 갱신 가이드 (RFC 044 의 PLAN integration
§Phase 2-4 재정의 위에 추가). PARADIGM.md §9 의 Phase 4 = "AOT whole-train-step codegen
(A' Stage 2)" — 본 RFC 가 그 Phase 4 의 mixed-precision 변형 path 추가:

| 기존 PLAN §Phase | RFC 044 후 | RFC 049 후 추가 |
|---|---|---|
| Phase 2 | regime-tiered substrate scaffold (2.A Graphs / 2.B SMEM / 2.C fwd+bwd) | — (현행 유지) |
| Phase 3 | DSM-cluster fusion (B' Stage 2, Hopper) | — (현행 유지, BF16 변형은 Phase 4+) |
| **Phase 4** | AOT whole-train-step (A' Stage 2 transformer) | **Phase 4.FP64** (current) + **Phase 4.MIXED** (RFC 049 BF16 TC substrate, flame Phase 4+ 와 paired) |
| Phase 5+ | multi-GPU (강등) | mixed-precision multi-GPU = Phase 6 (별도 RFC) |

flame Phase 4+ 와 paired = flame Phase 4 (RFC 046 compiler fusion) + 4b (RFC 047
block fusion IR) + 4c (RFC 048 fwd+bwd graph fusion) 가 land 후 → flame Phase 5
(precision policy surface) 가 forge mixed-precision substrate 의 consumer 로 동작.

flame Phase 4+ 가 land 안 된 시점에 forge RFC 049 Stage 2 fire 진행 시 = consumer-
less substrate (검증 어려움). 그러므로 본 RFC = design + pre-reg only, fire = flame
Phase 4+ land 후 별도 user gate.

PLAN 본문 갱신 = 별도 task (RFC 049 land 후).

## Authority

- AGENTS.tape g_forge_substrate_role · g_forge_verify_oracle · g_forge_perf_floor
  (real-limit anchors only)
- g_forge_phase_falsifiers (사전등록 mandate)
- LATTICE_POLICY (f1/f2: no lattice numerology in perf claims)
- HEXA-NATIVE-ONLY (no LLVM, no C-transpile backend; .cu via nvcc 는 fallback
  portable artifact, not architecture)
- g_blue_closed_mandate (anima cross-repo): CPU farr reference vs GPU kernel
  bit-equality (BF16 path 의 oracle 정의 follow-up RFC 필요 — BF16 CPU reference
  의 RNE rounding contract)
- g3 (real-limits-first): 모든 perf claim 이 literature 또는 measurement anchor —
  본 RFC 의 falsifier 7 개 모두 paper data 또는 NVIDIA spec 직접 reference
- g_arch_vs_log_split: 본 RFC = architecture draft (편집 가능, latest-wins).
  fire 결과 land 시 FORGE.tape ## Log 에 append-only event 등록.
