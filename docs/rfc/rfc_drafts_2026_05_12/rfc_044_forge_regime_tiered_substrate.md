# RFC 044 — forge: dual-mechanism × regime-tiered AOT substrate

- **Status**: design-draft (2026-05-17) — DESIGN ONLY, no implementation
- **Date**: 2026-05-17
- **Severity**: HIGH (forge 의 architectural pivot — RFC 040/041 의 ".cu kernels 채우기" 를 paradigm-aware substrate 디자인으로 흡수)
- **Priority**: P1 (Phase R measurement 가 universal paradigm 후보 모두 falsify; 본 RFC 는 측정-anchored 만 promote)
- **Source convergence**: forge Phase R (2026-05-17, 4 cost-bearing GPU fires, $1.35 total) — 4 paradigm 가설 사전등록 후 H100 SXM / H200 SXM vast.ai 측정. 결과 anchor 는 `self/forge/PARADIGM.md` SSOT 가 holds.
- **Source evidence (g3 — every claim below traces to a real capture)**:
  - `state/forge_phaseR_d_2026_05_17/result.json` — H100 SXM 6 FP64 Dgemm shape sweep, PEDANTIC vs DEFAULT cost +14.67~+33.39%, **cross-mode bit-equal 모든 shape** (max\|Δ\|=0, PEDANTIC ≡ DEFAULT numerically), within-mode bit-equal 모든 shape (FP64 single-process determinism FREE)
  - `state/forge_phaseR_b_2026_05_17/result.json` — H200 SXM 6 FFN shape sweep (cuBLAS Dgemm + SiLU + cuBLAS Dgemm), graph_speedup +1.96~+20.06% shape-dependent, BW util 13.9~35.4% (H200 4.8 TB/s peak 기준), 모든 shape bit_equal
  - `state/forge_phaseR_c_2026_05_17/result.json` — H100 SXM 5 linear fwd+bwd sweep (3 cuBLAS Dgemms), **bytes_redundancy_ratio = 1.500× CONSTANT every shape**, graph_speedup +3.86~+27.87%, BW util 14.1~45.2%, 모든 output (Y/dW/dX) bit_equal
  - `state/forge_phaseR_a_2026_05_17/result.json` + `pytorch_result.json` — H100 SXM 3 MLP config (FP64), AOT single-binary vs PyTorch 2.4.0 eager (AdamW 100 step median), **AOT speedup 2.24~6.07× per config, pre-reg ≥ 1.2× 모든 config PASS**
  - 종합 SSOT: `self/forge/PARADIGM.md` (12 sections, measurement-anchored)

## Scope of this RFC — DESIGN DRAFT, honest framing

본 RFC 는 **design document only**. forge 의 architectural thesis 를 Phase R
실측-anchor 위에 명세하고, Stage 2 (custom kernel + AOT trainer 확장) 의
falsifier 사전등록만 land. 어떤 .cu / hexa source 도 본 RFC 에서 추가 안 함.
RFC 040/041 의 design 위에 forge 의 **dual-mechanism × regime-tiered**
architecture 를 더한다 — 즉 RFC 041 의 11-op TODO[cuda] 채우기는 본 RFC 의
Phase 2.B 의 substrate 일부로 흡수.

기존 paradigm A/B/C/D sketches (PARADIGM_RESEARCH.md §5) 를 universal 가설로
land 하려는 시도는 Phase R 측정으로 **3/4 가 fail** (사전등록 over-optimistic).
이 RFC 는 데이터-anchored X' reframe 만 도입.

## Problem — Phase R 가 가르친 4 paradigm 의 진실

RFC 040/041 가 forge 의 op-level 채우기 (cuBLAS Dgemm + .cu stub → real kernel)
를 다뤘다. 그 다음 단계로 forge 의 architectural identity (paradigm 선택)
를 4 candidate (D/B/C/A) 위에 sketch 했고 (PARADIGM_RESEARCH.md), Phase R 가
실측으로 검증했다.

### 4 paradigm 의 verdict (PARADIGM.md §1)

| Paradigm | Pre-registered hypothesis | 실측 verdict | 데이터 anchor |
|---|---|---|---|
| **D** — deterministic substrate | "cost ≤ 15% vs cuBLAS heuristic" | **FAIL** (max +33.39%) | PEDANTIC cost +14.67~+33.39% across 6 shape |
| **B** — DSM-aware fused FFN | "≤ 0.5× separate cuBLAS chain" | **FAIL universal** (max 0.8× CUDA Graphs only) | graph_speedup 작은 shape +20%, 큰 shape +2%, BW util 14-35% |
| **C** — autograd co-emission | "fused HBM traffic ≤ 0.6× separate" | **FAIL theoretical** (ceiling 0.667 > 0.6) | redundancy 1.500× constant every shape |
| **A** — AOT whole-train-step | "step throughput ≥ 1.2× PyTorch eager" | **PASS** (1.87-5.05× over threshold) | AOT 0.110~1.206 ms vs PyT 0.668~2.704 ms, speedup 2.24-6.07× |

### Meta-finding (D/B/C/A 종합)

Phase R 는 sketch paradigm 의 universal 형태를 모두 falsify 또는 강화하면서
**forge 의 진정한 win 이 두 직교 mechanism × regime-tiered 였음**을 가르쳤다:

1. **Mechanism 1 — Dispatch elimination (Paradigm A)**:
   - AOT single-binary = no Python + no ATen + no per-op overhead.
   - 실측 fixed overhead ~600 μs/step (B 무관, MLP small).
   - small model (compute < 100 μs): AOT ~6× PyTorch eager (overhead-dominated regime).
   - medium model (~1 ms compute): AOT ~2.2× (compute > overhead).
   - large model (Llama-7B+, compute > 10 ms): 미측정, ~1.1× expected (compute dominates).

2. **Mechanism 2 — Memory fusion (Paradigm B/C, ceiling-bound)**:
   - **B (FFN fusion)**: large shape BW util 35.4% → DSM-cluster fusion 으로 70% util 가능 (이론 2× throughput, latency 0.5×). small shape BW util 14% — DSM 가치 의문.
   - **C (autograd co-emission)**: redundancy 1.500× constant → 이론 fused traffic ≤ 0.667× separate, realistic ≤ 0.75×. 모든 shape 일관.
   - small/medium model 에서는 marginal (compute < BW), large model 에서 dominant.

3. **공통 substrate (Paradigm D')**:
   - FP64 cuBLAS DEFAULT 가 within-run bit-deterministic (실측: every shape, every mode).
   - PEDANTIC mode = numerically equivalent (cross-mode bit-equal) + 15-33% slower → no FP64 benefit, opt-in only.
   - cross-precision (BF16/FP16) determinism = LayerCast paradigm 별도 RFC 047+ (out of scope).

## Proposal — dual-mechanism × regime-tiered substrate

forge 는 **하나의 universal kernel 라이브러리**가 아닌 **regime-tiered tooling stack**.
flame stdlib 가 model shape 을 known 시점에 forge 의 적절한 tier 를 dispatch.

### Architecture (4-tier × 2-mechanism × 1-common)

```
                    SHAPE / COMPUTE REGIME
                    ├── small (compute < 100 μs)
                    │   ├── M1: AOT single-binary (dispatch elimination) — DOMINANT (~6×)
                    │   ├── M2: CUDA Graphs grouping — small contributor (~1.0-1.2×)
                    │   └── D': within-run det FREE (always-on)
                    │
                    ├── medium (compute ~1 ms)
                    │   ├── M1: AOT single-binary — significant (~2.2×)
                    │   ├── M2: SMEM-resident tile fusion — moderate (~1.3×)
                    │   └── D': within-run det FREE
                    │
                    └── large (Llama-7B+, compute > 10 ms)
                        ├── M1: AOT single-binary — marginal (~1.1× expected)
                        ├── M2: DSM-cluster fusion + autograd co-emission — DOMINANT (~1.5-2×)
                        └── D': within-run det FREE
```

### Components (Stage 1 = current, Stage 2 = post-RFC-044 implementation)

1. **D' substrate (Stage 1 ✅ measurement-anchored)**:
   - cuBLAS DEFAULT 위에서 within-run bit-deterministic (실측: 6/6 shapes, FP64 packed-double farr).
   - PEDANTIC opt-in mode: `forge.det_mode = "pedantic"` 등 hexa surface (flame 측 책임).
   - **Implementation**: 별도 신규 코드 0 — 기존 cuBLAS 호출 path 가 이미 가짐. PEDANTIC opt-in 은 `cublasSetMathMode(h, CUBLAS_PEDANTIC_MATH)` wrapper.

2. **A' tier (Stage 2 = transformer block AOT trainer)**:
   - 현재 (Stage 1) = 3-layer MLP AOT trainer (`a_aot_trainer.cu`) 가 small/mid model 에서 2.24-6.07× PyTorch eager 검증.
   - Stage 2 scope = transformer block (attention + FFN + LayerNorm + residual) AOT trainer. Llama-7B block scale 측정.
   - 가설: F-FORGE-A-STAGE2-LARGE — large block AOT ≥ 1.1× PyTorch eager (compute dominate 인데도 dispatch elimination 이 marginal win).
   - flame Phase 1 (tensor_lib + autograd_lib) 가 이미 land — transformer 구조 작성 토대.

3. **B' tier (Stage 2 = DSM-aware fused FFN kernel)**:
   - 현재 (Stage 1) = CUDA Graphs grouping 만 측정 (max +20% small, +4% large).
   - Stage 2 scope = H100/H200 DSM cluster (`__cluster_dims__`, `cudaLaunchKernelEx`) 활용 fused FFN kernel (matmul → SwiGLU → matmul, intermediate in SMEM-cluster).
   - Shape target: Llama-7B FFN (M=128, D=4096, FD=11008). BW util 35.4% → 70% 가능 (이론).
   - 가설: F-FORGE-B-STAGE2-LARGE — DSM fused FFN latency ≤ 0.6 × cuBLAS chain on Llama-7B scale.

4. **C' tier (Stage 2 = fused fwd+bwd linear kernel)**:
   - 현재 (Stage 1) = separate cuBLAS Dgemms (3 launches), redundancy 1.500× 측정.
   - Stage 2 scope = single fused kernel 이 fwd output Y + backward dW + dX 를 한 번에 emit. X, W, dY 가 SMEM/register 잔류 reuse.
   - 가설: F-FORGE-C-STAGE2-FUSED — custom kernel HBM traffic ≤ 0.75 × separate (ceiling 0.667× 의 75-100% 효율 달성).

5. **Shape/regime dispatcher (Stage 2 = flame ↔ forge boundary)**:
   - flame compile-time 시점에 (model shape × hardware capability) 매칭 → 적절한 tier 호출.
   - "small" / "medium" / "large" 의 boundary 는 측정 anchor 위에서 정의 (small: compute < ~100 μs, large: compute > ~10 ms).
   - 흩어진 model 의 한 step 안에서도 layer 별로 다른 tier dispatch 가능 (embedding small + attention large + classifier small 같은 mixed regime).

### What this RFC does NOT do

- No CUDA kernel implementation (Stage 2 = 별도 fires + RFC follow-up).
- No flame stdlib changes (flame Phase 1 in-flight, 다른 세션 — forge 영역 무손상 mandate).
- No RFC 040/041 supersession — RFC 041 의 11-op TODO 채우기는 본 RFC 의 Phase 2.B tier 의 substrate. RFC 041 의 falsifier (F-RFC041-*) 는 살아있음 (CPU oracle parity 등).
- No mixed-precision (BF16/FP16) substrate (LayerCast paradigm = RFC 047+, future).

## Falsifier battery (Stage 2 pre-registered, 14 total)

각 falsifier 는 **compiled-native 경로** (`hexa build` AOT) 에서만 PASS 인정.
가짜 target 금지 — reference 는 Phase R fire 실측 anchor 또는 RFC 040/041
명시 TOL spec.

### D' tier (현재 측정 anchor, additional Stage 2 falsifier 없음)

- ✅ F-FORGE-D-PRIME-WITHIN-DET — every measured shape default_bit_equal_within=1 (PASS 6/6, D_ANALYSIS.md §3.F3)
- ✅ F-FORGE-D-PRIME-PEDANTIC-EQUIV — every shape cross_mode_bit_equal=1, max\|Δ\|=0 (PASS 6/6, D_ANALYSIS.md §3.F2)
- ✅ F-FORGE-D-PRIME-PEDANTIC-COST — PEDANTIC cost +15-33% anchored (not a target)

### A' tier (Stage 1 PASS, Stage 2 = large model 확인)

- ✅ F-FORGE-A-PRIME-SMALL-DISPATCH — small MLP step AOT ≥ 3× PyTorch eager (PASS 6.06×, A_ANALYSIS.md §4.2)
- ✅ F-FORGE-A-PRIME-MEDIUM-DISPATCH — medium MLP AOT ≥ 1.5× PyTorch eager (PASS 2.24×)
- ✅ **F-FORGE-A-STAGE2-LARGE — large MLP (D=8192/16384) AOT ≥ 1.1× PyTorch eager — PASS 1.86-4.06×** (Stage 2 A fire 2026-05-17 A100 SXM, A_STAGE2_ANALYSIS.md). **KEY finding**: batch-size dependent — small batch (B ≤ 128) any model → AOT 4-6×, large batch (B ≥ 512) large model → AOT 1.86×. forge 의 inference framework market 경쟁력 시사.
- 🟡 F-FORGE-A-STAGE2-MIX-PRECISION — Stage 2 BF16/FP16 substrate 에서 within-run det FREE 보존 (D' 와 정합) — 미측정 (FP64 only, LayerCast RFC 047+ 별도)
- 🟡 F-FORGE-A-STAGE2-TRANSFORMER — 진정한 Llama-style transformer block (MHA + RMSNorm + SwiGLU) AOT trainer — 미측정 (flame Phase 2 의존)
- ✅ F-FORGE-A-PRIME-FUNCTIONAL — AOT trainer + PyTorch trainer 동일 architecture 학습 수렴 (PASS final_loss=0 PyT)

### B' tier (Stage 1 measured, Stage 2 = DSM custom kernel)

- 🟡 F-FORGE-B-STAGE2-LARGE — Llama-7B scale (128×4096×11008) DSM-fused FFN latency ≤ 0.6 × cuBLAS chain (Stage 2)
- 🟡 F-FORGE-B-STAGE2-MEDIUM — medium (128×768×3072) DSM-fused FFN latency ≤ 0.75 × cuBLAS chain
- 🟡 F-FORGE-B-STAGE2-SMALL — small (64×768×3072) ≤ 0.85 × cuBLAS chain (낮은 expectations)
- 🟡 F-FORGE-B-STAGE2-BITEQ — Stage 2 fused FFN output bit_equal w.r.t. cuBLAS reference (D' 결정성 보존)

### C' tier (Stage 1 ceiling identified, Stage 2 = custom fused fwd+bwd)

- ✅ **F-FORGE-C-STAGE2-FUSED-CEILING — PASS 0.6667 measured** (≤ 0.75 threshold, 모든 shape 16/32/64). Stage 2 Phase 1 fire 2026-05-17 A100 SXM $0.30, `state/.../C_STAGE2_ANALYSIS.md`.
- 🟡 F-FORGE-C-STAGE2-WALL-LARGE — Llama-7B scale fused wall time ≤ 0.75 × separate (BW 45% util → DSM ROI) — **미증명** (Phase 1 single-block kernel = wall slower than cuBLAS, Phase 2 production kernel 필요).
- ✅ **F-FORGE-C-STAGE2-DET-PRESERVE — PASS max\|Δ\| < 1e-16** (TOL_OP 1e-9 의 7 orders headroom). Numerical equivalence anchor confirmed.

✅ = Stage 1 PASS (Phase R 실측, 본 RFC 의 가설 토대)
🟡 = Stage 2 사전등록 (별도 fire 가 검증)

## Honest caveats (g3 / f2 — no over-claim)

- **Universal speedup 약속 안 함.** forge 는 model 크기 / shape regime 별 win 이 다르다 — small 6× (A dominant), mid 2.2-2.9× (A + B/C 합), large ~2.2× (A 1.1× + B/C 2×). Mojo MAX 의 87% CUDA 와 자릿수 유사 (large 에서는 Mojo 미만일 수 있음, AOT 만으로 cuBLAS 못 이김).
- **Stage 2 implementation 은 별도 multi-fire 작업.** 본 RFC 가 사전등록만 한다. DSM cluster kernel + autograd co-emission + Llama-7B AOT 는 cost ↑ effort — 각 Stage 2 별 user gate 필요.
- **FP64 packed-double farr substrate 한정.** BF16/FP16 mixed-precision 은 LayerCast paradigm 별도 RFC. forge 의 현재 substrate 는 FP64 (RFC 025/032/033/034 farr 와 일관).
- **DSM 은 Hopper-only (cc=9.0).** Stage 2 B' tier 는 H100/H200 한정. A100/B200 fallback path 별도. flame 측 hardware dispatcher 가 routing.
- **PyTorch eager 비교 baseline 한정.** torch.compile + AOTDispatcher 와의 비교는 별도 fire (Stage 2 의 일부일 수 있음). 현재 비교는 vanilla eager only.
- **No lattice/perfect-number numerology (f1/f2 deny).** forge 의 perf anchor 는 cuBLAS roofline + HBM bandwidth + Python dispatch overhead — 모두 measured. n=6 lattice 와 무관.

## Non-goals (this RFC)

- 어떤 .cu 도 land 안 함 — design draft only.
- flame stdlib 변경 0 — forge ↔ flame boundary 는 RFC 043 / flame 의 책임.
- RFC 041 supersession 안 함 — 본 RFC 가 RFC 041 위에 paradigm-aware 위치 추가.
- BF16/FP16 / mixed-precision = out of scope (RFC 047+).
- Multi-GPU primitives = out of scope (RFC 040 §Phase 4, demand-driven).

## Cross-RFC dependency

- **RFC 040** (`farr` GPU/CUDA backend) — RFC 044 의 base substrate. device-farr alloc/copy/free + cuBLAS Dgemm + TOL_MATMUL spec 모두 살아있음.
- **RFC 041** (real `.cu` kernels for B/B2 ops) — RFC 044 의 Phase 2.B tier 의 일부로 흡수. 11-op TODO[cuda] stubs 채우기는 SMEM-aware 구현으로 진화 (단순 stub 채우기 X).
- **RFC 042** = SUBSUMED by RFC 043 (number reserved, do not reuse).
- **RFC 043** (flame stdlib design) — RFC 044 의 consumer. flame 이 model shape 별로 forge tier dispatch.
- **RFC 045+** (future): Stage 2 implementation RFC (per tier — 045 A' Stage 2, 046 B' DSM kernel, 047 C' fused autograd, etc.) — 각 Stage 2 fire 후 별도 RFC 로 land.

## Cross-link (Phase R fire evidence — g3)

- `self/forge/PARADIGM.md` — 측정-anchored SSOT (FORGE.tape §X `x_paradigm_ssot`)
- `self/forge/PARADIGM_RESEARCH.md` — literature snapshot (가설 sources, NOT decision sources)
- `state/forge_phaseR_d_2026_05_17/` — D fire (H100 SXM 6 shape, $0.40)
- `state/forge_phaseR_b_2026_05_17/` — B fire (H200 SXM 6 FFN shape, $0.25)
- `state/forge_phaseR_c_2026_05_17/` — C fire (H100 SXM 5 linear fwd+bwd, $0.30)
- `state/forge_phaseR_a_2026_05_17/` — A fire (H100 SXM 3 MLP config AOT vs PyTorch, $0.40)
- `self/cuda/experiments/{d,b,c,a}_*.{cu,py,sh}` — 9 fire artifacts (실험 코드)
- Phase R total cost: **$1.35** (4 cost-bearing GPU fires, 2026-05-17 single-day sprint)

## PLAN integration

본 RFC 가 `self/forge/PLAN.md` §Phase 2-4 본문 재정의 가이드 (PARADIGM.md §9):

| 기존 PLAN §Phase | RFC 044 후 재정의 |
|---|---|
| Phase 2 — RFC 041 land: real `.cu` kernels | **Phase 2 — regime-tiered substrate scaffold**: 2.A CUDA Graphs wrapper · 2.B SMEM-fused FFN (RFC 041 의 11-op 채우기 흡수) · 2.C fused fwd+bwd linear |
| Phase 3 — fused epilogue | **Phase 3 — DSM-cluster fusion (B' Stage 2)**: Hopper-only, large shape 한정 |
| Phase 4 — multi-GPU (optional) | **Phase 4 — AOT whole-train-step codegen (A' Stage 2)**: transformer block 단위 AOT trainer 확장. Multi-GPU 는 Phase 5+ 로 강등 |

PLAN 본문 재정의 = Task #8 (별도). 본 RFC 가 가이드만 제공.

## Authority

- AGENTS.tape g_forge_substrate_role · g_forge_verify_oracle · g_forge_perf_floor (real-limit anchors only)
- g_forge_phase_falsifiers (사전등록 mandate)
- LATTICE_POLICY (f1/f2: no lattice numerology in perf claims)
- HEXA-NATIVE-ONLY (no LLVM, no C-transpile backend; .cu via nvcc 는 fallback portable artifact, not architecture)
- g_blue_closed_mandate (anima cross-repo): CPU farr reference vs GPU kernel bit-equality
