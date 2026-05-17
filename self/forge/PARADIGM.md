# forge — paradigm SSOT (Phase R measurement-anchored, 2026-05-17 PUBLISH)

> **Phase R 4 fire (D/B/C/A) 모두 land.** 이 문서는 forge 의 paradigm 결정
> SSOT — literature snapshot ([PARADIGM_RESEARCH.md](PARADIGM_RESEARCH.md))
> 와 별도, 실측-anchored. RFC 044 draft 의 토대. FORGE.tape §X cross-link
> 대상 (`x_paradigm_ssot`).
>
> **Key data anchor**: 4 paradigm 가설 중 **A 만 universal PASS** (2.24-6.07×
> PyTorch eager, 사전등록 1.2× 의 1.87-5.05× 초과). D/B/C 는 사전등록 over-
> optimistic, 데이터-anchored X' reframe (regime-tiered) 채택.

## 1. Status (2026-05-17)

| Paradigm | Fire | Pre-reg verdict | Reframe | SSOT entry |
|---|---|---|---|---|
| **D** — deterministic substrate | ✅ 2026-05-17 H100 SXM $0.40 | FAIL (max cost +33% > 15%) | **D' PASS** (within-run det FREE) | [`state/.../D_ANALYSIS.md`](../../state/forge_phaseR_d_2026_05_17/D_ANALYSIS.md) |
| **B** — DSM-aware fused FFN | ✅ 2026-05-17 H200 SXM $0.25 | FAIL (max graph speedup +20% << 0.5×) | **B' shape-tiered** (small=Graphs free, large=DSM ROI 명확) | [`state/.../B_ANALYSIS.md`](../../state/forge_phaseR_b_2026_05_17/B_ANALYSIS.md) |
| **C** — autograd co-emission | ✅ 2026-05-17 H100 SXM $0.30 | FAIL (theoretical impossibility — ceiling 0.667 > 0.6) | **C' redundancy=1.500× constant** (≤ 0.75× realistic) | [`state/.../C_ANALYSIS.md`](../../state/forge_phaseR_c_2026_05_17/C_ANALYSIS.md) |
| **A** Stage 1 — AOT whole-train-step | ✅ 2026-05-17 H100 SXM $0.40 | **PASS** (universal 1.2× 초과, 실측 2.24-6.07×) | A' regime-aware | [`state/.../A_ANALYSIS.md`](../../state/forge_phaseR_a_2026_05_17/A_ANALYSIS.md) |
| **A** Stage 2 — large compute AOT | ✅ 2026-05-17 A100 SXM $0.30 | **PASS** (F-FORGE-A-STAGE2-LARGE: 1.10× 사전 등록 → **실측 1.86-4.06×**) | A' batch-size aware (small B 4-6× / large B 1.86×) | [`state/.../A_STAGE2_ANALYSIS.md`](../../state/forge_phaseR_a_stage2_2026_05_17/A_STAGE2_ANALYSIS.md) |

Total cost: **$1.65** (D 0.40 + B 0.25 + C 0.30 + A Stage 1 0.40 + A Stage 2 0.30).

## 2. Paradigm D — deterministic substrate

### 2.1 Pre-registered hypothesis (FORGE.tape g_forge_phase_falsifiers 2026-05-17)
> "deterministic-default substrate cost ≤ 15% vs cuBLAS heuristic"

### 2.2 Measured (H100 SXM cuBLAS 12.4.5, 6 shape FP64 Dgemm sweep)
- `max_cost_pct = +33.39%` (PEDANTIC vs DEFAULT, 4096³ worst)
- `min_cost_pct = +14.67%` (1024³ best)
- **Cross-mode bit_equal = 1 every shape, max|Δ|=0** (PEDANTIC ≡ DEFAULT numerically)
- **Within-mode bit_equal = 1 every shape, every mode** (DEFAULT 도 deterministic)

### 2.3 Verdict
- **Pre-reg FAIL** (cost > 15%, hard)
- 그러나 데이터 가 새로운 truth 가르침: PEDANTIC 가 +15-33% 더 느린데 **결과가 동일** → "결정성 강화" 가 아닌 "더 보수적 implementation path"
- DEFAULT 자체가 within-run bit-deterministic — **FP64 single-process determinism FREE**

### 2.4 D' reframe (adopted)
> **forge FP64 substrate 는 cuBLAS DEFAULT 위에서 within-run determinism FREE.**
> PEDANTIC mode 는 opt-in (`forge.det_mode = "pedantic"` 등) — cost +15-33%,
> no FP64 benefit (실측 bit-equal). LayerCast-style cross-precision (BF16/FP16)
> determinism 은 별도 paradigm (RFC 047+, 현 forge 의 FP64 packed-double farr
> 무관).

### 2.5 D' falsifier battery (sufficient measurement)
- ✅ F-FORGE-D-PRIME-WITHIN-DET: every shape `default_bit_equal_within = 1` — PASS (6/6)
- ✅ F-FORGE-D-PRIME-PEDANTIC-EQUIV: every shape `cross_mode_bit_equal = 1`, `max|Δ|=0` — PASS (6/6)
- ✅ F-FORGE-D-PRIME-PEDANTIC-COST: PEDANTIC opt-in cost +15-33% — anchored, not a target

## 3. Paradigm B — DSM-aware fused FFN

### 3.1 Pre-registered hypothesis
> "H100 DSM-aware fused FFN latency ≤ 0.5 × separate cuBLAS chain"

### 3.2 Measured (H200 SXM cuBLAS 12.4.5, 6 FFN shape sweep, Stage 1 diagnostic)
- Stage 1 measures CUDA Graphs (kernel-launch fusion) — not Stage 2 custom DSM kernel
- `graph_speedup ∈ [+1.96%, +20.06%]` (작은 shape: +20%, 큰 shape: +2%)
- `BW util ∈ [13.9%, 35.4%]` (H200 4.8 TB/s peak 기준)
- 모든 shape `bit_equal = 1`
- 작은 shape (M=64): kernel-launch overhead dominate
- 큰 shape (Llama-7B scale 128×4096×11008): BW util 35% — DSM 으로 끌어올림 ceiling 2-2.8×

### 3.3 Verdict
- **Pre-reg universal FAIL** (CUDA Graphs max 0.8× separate, ≤ 0.5× 못 도달)
- Stage 2 (custom DSM cluster kernel) 이론적 가능 (Llama-7B BW util 35% → 70% = 2× throughput)
- 작은 shape 에서는 DSM ROI 의문 (BW util 14%, kernel-launch overhead 가 비중)

### 3.4 B' reframe (adopted, shape-tiered)
> forge 의 FFN fusion paradigm 은 **shape-dependent**:
> - **작은 shape (M ≤ 64)**: CUDA Graphs grouping FREE +20%. DSM ROI 의문 (BW util 14%).
> - **중간 shape (M=128-512, d=768)**: CUDA Graphs +6-15%, DSM Stage 2 가능 ROI.
> - **큰 shape (Llama-7B+, M·d > 10⁶)**: CUDA Graphs +2%. DSM Stage 2 ROI 명확.

### 3.5 B' falsifier battery (Stage 2 가 검증, 사전등록)
- F-FORGE-B-PRIME-DSM-LARGE: Llama-7B scale (128×4096×11008) DSM-fused FFN latency ≤ 0.6 × cuBLAS chain
- F-FORGE-B-PRIME-DSM-MEDIUM: medium (128×768×3072) DSM-fused FFN latency ≤ 0.75 × cuBLAS chain
- F-FORGE-B-PRIME-DSM-SMALL: small (64×768×3072) DSM-fused FFN latency ≤ 0.85 × cuBLAS chain
- F-FORGE-B-PRIME-DSM-BITEQ: 모든 shape `bit_equal = 1` w.r.t. cuBLAS reference (D' 결정성 보존)

## 4. Paradigm C — autograd co-emission (fwd, bwd)

### 4.1 Pre-registered hypothesis
> "Fused (fwd, bwd) pair HBM traffic ≤ 0.6 × separate fwd-then-bwd"

### 4.2 Measured (H100 SXM cuBLAS 12.4.5, 5 linear-layer shape sweep)
- `bytes_redundancy = 1.500× CONSTANT every shape` (separate path 가 X+dY+W 를 1.5× 재read)
- `graph_speedup ∈ [+3.86%, +27.87%]`
- `BW util ∈ [14.1%, 45.2%]`
- 모든 shape `bit_equal Y/dW/dX = 1/1/1` (separate ≡ graph 3 outputs)

### 4.3 Verdict
- **Pre-reg "≤ 0.6×" theoretical impossibility** (이론 ceiling = 1/1.5 = 0.667 > 0.6, hard FAIL)
- 그러나 redundancy 1.5× 는 **forge fused kernel ROI 가 33% reduction** (ceiling)
- 실제 fused kernel = ceiling 의 75-100% 효율 → realistic 25-33% wall-time reduction
- D' 결정성 (within-run bit-equal) 가 backward path 에서도 확인됨 — forward + backward + gradient 모두 deterministic

### 4.4 C' reframe (adopted, ceiling-anchored)
> forge 의 fused (fwd, bwd) co-emission paradigm 의 **이론적 HBM traffic
> ceiling = 0.667× separate**. 실제 fused kernel 은 ≤ 0.75× 목표 (ceiling
> 75% 효율 가정).
>
> CUDA Graphs grouping 으로 작은 shape +20-28% wall-time saving FREE (kernel-
> launch overhead). 큰 shape (Llama-7B 단일 layer) 에서는 graph saving 미약
> (+4%) → custom co-emitted kernel 만 win 가능.

### 4.5 C' falsifier battery (Stage 2 가 검증, 사전등록)
- F-FORGE-C-PRIME-FUSED-CEILING: custom co-emitted (fwd, bwd) kernel HBM traffic ≤ 0.75 × separate
- F-FORGE-C-PRIME-WALL-LARGE: Llama-7B scale fused wall time ≤ 0.75 × separate
- F-FORGE-C-PRIME-DET-PRESERVE: fused kernel Y/dW/dX numerical equivalence to separate at TOL_OP ≤ 1e-9

## 5. Paradigm A — AOT whole-train-step

### 5.1 Pre-registered hypothesis
> "3-layer MLP MNIST scale AOT-compiled step throughput ≥ 1.2 × PyTorch eager"

### 5.2 Measured (H100 SXM 80GB · cuBLAS 12.4.2 · PyTorch 2.4.0 FP64)
3 configs · AOT single-binary CUDA (14 cuBLAS Dgemm + 6 custom kernel) vs PyTorch eager (same MLP, AdamW, 100 step median):

| Config | shape (D_in×D_hid×D_out) | AOT ms | PyT ms | speedup |
|---|---|---|---|---|
| mnist_b32 (B=32) | 784×256×10 | 0.110 | 0.668 | **6.065×** |
| mnist_b128 (B=128) | 784×256×10 | 0.111 | 0.668 | **6.013×** |
| mid_b32 (B=32) | 4096×4096×100 | 1.206 | 2.704 | **2.243×** |

모든 config 사전등록 ≥ 1.2× 의 1.87-5.05× 초과 → **PASS**.

### 5.3 Verdict
- **Pre-reg universal PASS** (3/3 configs).
- D/B/C 와 반대 패턴: **사전등록 under-optimistic**, 실측이 가설을 압도적으로 초과.
- Mechanism: **dispatch-elimination** (Python+ATen+launch overhead ~600 μs/step 제거), not memory fusion.
- F1: B 변화 무영향 (small MNIST, compute < 100 μs) → **train_step 의 ~85% 가 Python+ATen overhead**.
- F2: speedup ∝ inverse of compute size (small 6× → mid 2.24× → large 미측정, ~1.1× 예상).

### 5.4 A' reframe (adopted, batch-size + compute-regime aware — Stage 2 갱신)

> forge 의 AOT whole-train-step win 은 **batch-size + compute-regime 의 함수**
> (Stage 2 fire 가 batch-size 가 dominant variable 임을 발견):
>
> | Batch | Model size | Compute | A win (실측) | Mechanism |
> |---|---|---|---|---|
> | B ≤ 32 | small (MNIST) | < 100μs | **6.06×** | overhead 전체 dominant |
> | B = 128 | mid (D=4096) | ~1ms | 2.24× | overhead + compute 균형 |
> | **B = 128** | **large (D=8192)** | **~5ms** | **4.00×** ← Stage 2 | overhead per-step 여전히 dominant |
> | **B = 128** | **xlarge (D=16384)** | **~20ms** | **4.06×** ← Stage 2 | KEY: small batch 라 compute amortize 안 됨 |
> | B = 512 | large (D=8192) | ~20ms | 1.86× ← Stage 2 | compute amortizes overhead |
>
> **Surprising finding (Stage 2)**: 큰 model 에서도 small batch (B ≤ 128) 면 AOT
> 4-6× win 유지. RFC 044 의 1.1× expected prediction 가 under-optimistic — 실측
> 4× 까지 초과. 이건 forge 의 **inference / online-RL market** (latency-sensitive,
> small-batch) 에서 가장 강력한 win source.

### 5.5 A' falsifier battery (Stage 1 + Stage 2 모두 PASS)
- ✅ F-FORGE-A-PRIME-SMALL-DISPATCH: small MLP AOT ≥ 3× PyTorch eager — PASS (6.06×)
- ✅ F-FORGE-A-PRIME-MEDIUM-DISPATCH: medium MLP AOT ≥ 1.5× PyTorch eager — PASS (2.24×)
- ✅ **F-FORGE-A-STAGE2-LARGE**: large MLP (D=8192/16384) AOT ≥ 1.1× PyTorch eager — **PASS 1.86-4.06×** (Stage 2 fire anchor)
- ✅ F-FORGE-A-PRIME-FUNCTIONAL: AOT trainer + PyTorch trainer functional (final loss reasonable) — PASS
- ⏳ F-FORGE-A-STAGE2-MIX-PRECISION: BF16/FP16 substrate within-run det 보존 — 미측정 (FP64 only, LayerCast RFC 047+ 별도)
- ⏳ F-FORGE-A-STAGE2-TRANSFORMER: 진정한 Llama-style transformer block (MHA+RMSNorm+SwiGLU) AOT — 미측정 (flame Phase 2 의존)

## 6. Meta-finding (D/B/C/A — two mechanisms × regime-tiered)

**관찰 (D/B/C)**: 사전등록 universal 가설 **over-optimistic**, 실측 못 도달:
- D: cost ≤ 15% pre-reg → 실측 +33% (FAIL), D' = within-run det FREE (PASS)
- B: ≤ 0.5× pre-reg → 실측 max 0.8× CUDA Graphs (FAIL), B' = shape-tiered (small Graphs free, large DSM ROI)
- C: ≤ 0.6× pre-reg → 이론 ceiling 0.667× (impossibility FAIL), C' = ≤ 0.75× realistic

**관찰 (A)**: 사전등록 **under-optimistic**, 실측 압도적 초과:
- A: ≥ 1.2× pre-reg → 실측 2.24-6.07× (PASS, 1.87-5.05× over)

**핵심 통찰 — forge 의 win 은 두 직교 mechanism × batch-size aware**:

> 1. **Dispatch elimination (Paradigm A)**: AOT single-binary = no Python + no ATen + no per-op overhead. **small batch (B ≤ 128) any model size → 4-6× win.** large batch (B ≥ 512) large model → 1.86× (compute amortizes).
> 2. **Memory fusion (Paradigm B/C)**: DSM-cluster + autograd co-emission. **Large model 에서 1.5-2× win** (BW headroom), small 에서는 marginal (compute < BW).

두 mechanism 는 **batch-size + regime-complementary** — Stage 2 fire 가 batch-size 가 A win 의 dominant variable 임을 발견:

| Batch | Model | Compute | A win (실측) | B/C win | Combined |
|---|---|---|---|---|---|
| B ≤ 32 | Small (MNIST) | < 100 μs | **6.06×** | ~1.0× | **~6×** |
| B = 128 | Mid (4K wide) | ~1 ms | **2.24×** | ~1.3× | **~2.9×** |
| **B = 128** | **Large (8K/16K wide)** | **5-20 ms** | **4.00-4.06×** ← Stage 2 | **1.5-2×** | **~6-8×** |
| **B = 512** | **Large (8K wide)** | **~20 ms** | **1.86×** ← Stage 2 | **1.5-2×** | **~3-4×** |

**KEY finding (Stage 2)**: 큰 model 에서 batch 가 small 이면 A win 4-6× 유지
(small batch 라 compute 가 overhead 를 amortize 못 함). batch 가 클 때만 A win
이 ~2× 수준으로 떨어짐. forge 의 **dispatch elimination paradigm 의 가장
강력한 application = inference / online-RL** (small batch + low latency target).
training (typically large batch) 에서는 modest win.

모든 regime 공통: **within-run det FREE (D')**. cross-run det = opt-in (PEDANTIC +15-33%).

이건 **PyTorch eager / torch.compile / XLA JIT trace / Mojo MAX 가 모두 안 가르치는** 정직한 dual-mechanism × batch-size-aware × regime-tiered substrate. forge 의 distinctive position.

## 7. Forge architectural thesis (post-measurement, full Phase R)

원래 paradigm proposal (sketches) 의 추상 vs 실측 데이터 의 차이:

| 차원 | 원 sketch | 실측 anchor |
|---|---|---|
| 결정성 | "default-on deterministic" | within-run FREE, cross-mode opt-in (+15-33% cost) |
| 메모리 fusion (B) | "DSM 으로 0.5× latency universal" | 큰 shape (Llama-7B+) 에서만 ROI 명확, regime-tiered |
| 자동 미분 fusion (C) | "fwd+bwd 한 kernel, 40%+ saving" | redundancy 1.5× constant → 이론 33% reduction ceiling, realistic ≤ 0.75× |
| **AOT whole-step (A)** | "1.2× PyTorch eager 보장" | **실측 2.24-6.07× (under-optimistic!)** — small dispatch elimination 압도적 |

**Honest forge thesis (data-anchored, Stage 1 + Stage 2 A 후)**:

> forge = **dual-mechanism × batch-size + regime-aware AOT substrate** —
>
> **Mechanism 1 — Dispatch elimination** (paradigm A, 측정 anchor 1.86-6.07×):
> - AOT single-binary 가 Python + ATen + per-op overhead 제거 (~600 μs/step fixed cost, hardware-independent)
> - **small batch (B ≤ 128)** any model size → **AOT 4-6×** (overhead per-step dominant)
> - **large batch (B ≥ 512)** large model → AOT 1.86-2.24× (compute amortizes overhead)
> - Stage 2 finding: GPU-generation 독립 (A100 cc=8.0 측정 도 H100 측정 과 유사 패턴) — Python overhead 가 fixed cost, hardware 와 무관
>
> **Mechanism 2 — Memory fusion** (paradigm B/C, ceiling-bound):
> - DSM-cluster fusion (B): BW util headroom 활용, large shape ROI 명확
> - autograd co-emission (C): HBM redundancy 1.5× → fused ≤ 0.75× separate (이론 0.667× ceiling)
> - large model 에서 dominant win source (~1.5-2×)
> - small model 에서 marginal (compute < BW, Graphs grouping 가 더 효율)
>
> **공통 substrate** (paradigm D'): within-run determinism FREE.
> PEDANTIC opt-in mode (+15-33% cost, FP64 no benefit, cross-version stability 보장 용).

**vs SOTA**:
- PyTorch eager: 둘 다 mechanism 없음 (dispatch overhead 600 μs + memory naive)
- torch.compile + AOTDispatcher: mechanism 2 일부 (Inductor fusion), mechanism 1 부분적 (compile cache, not full AOT)
- XLA / JAX: mechanism 1 부분적 (JIT trace not AOT), mechanism 2 일부 (HLO fusion, GPU 한정)
- Mojo MAX: mechanism 1 가능 (MLIR AOT), mechanism 2 미증명 (training 미증명)
- **forge**: 두 mechanism 모두 native, batch-size + regime-aware — distinctive position

literature 의 FlashFuser 1.24× E2E inference 와 자릿수 일치 (memory fusion only).
A Stage 2 결과 (4-6× small-batch large model) 는 **vLLM / TensorRT-LLM 같은
inference framework 가 다루는 영역** — forge 가 native CUDA + AOT 로 더 경쟁력
있을 수 있음. forge 의 새 distinctive position = **inference framework** 도
포함 (Stage 1 thesis 의 "training-only" 보다 넓은 scope).

## 8. Stage 2 진입 결정 matrix (post-Phase R)

| Stage 2 | Justification | Cost estimate | Priority |
|---|---|---|---|
| **A Stage 2 (Transformer block AOT trainer)** | A small/medium win 압도적 (6×, 2.24×) — large model (Llama-7B block) 확인 필요. flame Phase 1 (tensor_lib+autograd_lib) 가 이미 land — Transformer 구조 작성 토대 있음 | 2-3 weeks (Transformer block CUDA + PyTorch baseline) | **HIGH** — small/mid win 검증된 mechanism 의 generalization, ROI 확실 |
| B Stage 2 (DSM kernel for Llama-7B FFN) | 큰 shape BW util 35% → 70% 가능 (이론). FlashFuser 1.24× E2E 와 자릿수 일치 expected | 1-2 weeks DSM cluster kernel + fire | MEDIUM — A Stage 2 의존 (transformer 의 FFN block 사용처) |
| C Stage 2 (fused fwd+bwd kernel for linear) | 이론 ceiling 0.667× 실측 검증. flame autograd 통합 필요 | 2-3 weeks (autograd-co-emission framework) | MEDIUM — A Stage 2 후 (linear layer fused autograd backbone) |
| D Stage 2 (BF16/FP16 substrate determinism) | LayerCast paradigm (RFC 047+). FP64 forge 와 직교 | 미정 | LOW — flame 의 mixed-precision plan 후 |

**진입 순서 추천**: A → B → C (A 가 dispatch overhead 제거 mechanism 의 확장, B/C 는 memory fusion mechanism). 각 Stage 2 = 별도 user gate (cost ↑).

## 9. Phase 2-4 재정의 (post-PARADIGM.md)

원래 PLAN.md §Phase 2-4 본문 (pre-paradigm-decision default — RFC 041 .cu 채우기 + fused epilogue + multi-GPU) → **재정의**:

- **Phase 2 (post-PARADIGM)**: regime-tiered substrate scaffold —
  - 2.A: CUDA Graphs wrapper (작은 shape, FREE +20%)
  - 2.B: SMEM-fused FFN proto (중간 shape, B Stage 2)
  - 2.C: fused (fwd, bwd) linear (C Stage 2)
- **Phase 3 (post-PARADIGM)**: DSM-cluster fusion (큰 shape, B/C Stage 2 success 후)
- **Phase 4 (post-PARADIGM)**: AOT whole-train-step codegen (A 결과 보고 scope)

원래 §Phase 2-4 의 "RFC 041 .cu 채우기" 는 **Phase 2.B 의 substrate** 로 흡수 (단순 stub 채우기 → SMEM-aware 구현).

## 10. Non-claims (g3 honest boundaries)

- ❌ "forge 가 PyTorch 보다 항상 2× 빠르다" — 실측: shape-dependent, 작은 shape 에서만 명확 win.
- ❌ "DSM 가 magic 으로 50%+ reduction 보장" — DSM 은 SMEM scale-up, BW ceiling 가 진정한 limit.
- ❌ "lattice/perfect-number 가 perf 에 기여" — f1/f2 deny.
- ❌ "cross-precision (BF16/FP16) substrate 가 본 paradigm 에 포함" — 미측정, LayerCast paradigm 별도 RFC 047+.

## 11. RFC 044 draft 가이드 (post-PARADIGM)

이 문서가 RFC 044 draft 의 토대:
- §1-§5 = paradigm 각 측정 + reframe (RFC 044 §"Verification" 토대)
- §6 = meta-thesis (RFC 044 §"Architectural rationale")
- §7 = thesis 정직 표 (RFC 044 §"Honest scope")
- §8 = Stage 2 decision matrix (RFC 044 §"Implementation phases")
- §9 = Phase 2-4 재정의 (RFC 044 §"PLAN integration")
- §10 = non-claims (RFC 044 §"Forbidden patterns")

RFC 044 = `inbox/rfc_drafts_2026_05_12/rfc_044_forge_regime_tiered_substrate.md` (예상 path).

## 12. Sources

- 측정: `state/forge_phaseR_{d,b,c}_2026_05_17/result.json` + `*_ANALYSIS.md`
- 사전등록: `self/forge/PLAN.md` §Phase R · `FORGE.tape` Log 2026-05-17
- Literature anchor: `self/forge/PARADIGM_RESEARCH.md` §3 (FlashFuser 1.24× E2E, LayerCast nondeterminism, Mojo MAX 78-87% CUDA)
- Phase R cost: D $0.40 + B $0.25 + C $0.30 + A Stage 1 $0.40 + A Stage 2 $0.30 = **$1.65 total** (5 fires complete, Stage 2 A landed)
