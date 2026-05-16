# flame/PLAN.md — staged roadmap (DESIGN — no execution until approved)

> Design SSOT = `inbox/rfc_drafts_2026_05_12/rfc_043_hexa_torch_compiler_only_nn_stdlib.md`.
> This file = the flame-local operational roadmap (mirrors HEXAD/PLAN.md
> discipline: editable architecture head + append-only `## 진행 로그`).
> **All phases 📋 PLANNED. Nothing runs without explicit user go.**

## 0. 현재 상태 (2026-05-16)

flame = DESIGN + SCAFFOLD. RFC 043 filed (`rfc043-hexa-torch` `4dcaf80f`).
Foundation (cuBLAS substrate, GPU-routed trainer, autograd, verified
arch) is BUILT but **scattered across 5 hexa-lang branches + anima
state/docs** — see `FLAME.tape` §X for the exact preservation index.
Interim LM-scale results come from the `.py` track (proven: d=768·12L
init CE 5.59→0.0007, anima `931dd68b0`, Python substrate, hexa-arch
mirror, hexa CPU-equiv anchored).

## 1. 단계 (staged — API fixed, impl matures)

### Phase 0 — 보존 검증 (물거품 방지) ✅ CLEARED 2026-05-16, $0
- **실측 결과 (g3, 가정 아님)**: "5 scattered branches → merge/rebase"
  는 부정확 프레이밍. git 실측 — `rfc043-hexa-torch` (`a8bc5e08`) 가
  5개 캠페인 브랜치 tip (`rfc/farr-gpu-cuda-backend` ·
  `phase-d-cublas-h100` · `rfc040-phaseB2-complete` ·
  `rfc041-042-upstream-needs`) + `FLAME.tape` §X 의 9개 load-bearing
  SHA 전부의 **strict 선형 ancestor** (divergent tail = 0). 즉
  merge/rebase 화해 불필요 — 이미 단일 선형 체인.
- **orphan-loss 위험 실재 안 함**: `origin/rfc043-hexa-torch` ==
  로컬 `a8bc5e08` **바이트 동일** (push 완료), 5 브랜치 모두 origin
  독립 push (이중 안전망). 캠페인 체인 = 이미 GitHub 보존.
- **Anchor (not move) cross-repo evidence**: anima campaign state/docs
  + the verified oracles stay in anima; recorded as references only
  (drift-avoidance g3). RFCs stay in `inbox/` (intake convention).
- **Acceptance: MET** — every campaign artifact resolvable from
  `FLAME.tape` §X + 검증완료(origin==local); no load-bearing orphan
  branch. 잔여 = main-divergence only (로컬 main stale; `origin/main`
  +22 = 타 세션 interp-retirement R1/R2/R3 + F6-A **in-flight**).
  메인라인 merge 는 후순위 분리작업 (interp-retirement R3 안정화 후
  화해), **Phase 1 blocker 아님**. Phase 1 = `rfc043-hexa-torch` 진행.

### Phase 1 — Tensor + autograd (parity-correctness)
- `tensor_lib.hexa` (device-farr, RFC 040 residence) + `autograd_lib.hexa`
  (RFC 034 tape generalized: 1-matmul→CE ⇒ full op set).
- Falsifier F-RFC043-AG-EQ: tape grad ≡ verified analytic vjp (the
  Phase E/E2 GRAD-EXACT oracle), compiled-native.

### Phase 2 — nn layers
- `nn_lib.hexa`: Linear · RMSNorm · RoPE · GQA-attention · SwiGLU ·
  embedding · tied LM head — derived from the verified ConsciousDecoderV2
  / d_train5 farr-refactor (anima Phase E/E2).
- F-RFC043-LAYER-EQ: each fwd/bwd byte-equal (or RFC 040 measured fp-tol)
  to the existing verified hexa/boxed reference.

### Phase 3 — optim + train_step (full trainer, parity)
- `optim_lib.hexa` (AdamW, RFC 040 B2) + `train_lib.hexa` (compiled
  `train_step` + CE). **No heavy interpreted driver loop** (RFC 042
  ceiling closed structurally).
- F-RFC043-STEP-EQ (§8/g_blue_closed_mandate connection check, MANDATORY):
  full step ≡ campaign bit-equal `7.97116 → 3.73374e-07` (d=32·3L).
- Milestone = **PyTorch-parity**: correct + feasible at LM scale,
  hexa-native self-sufficient (no `.py`).

### Phase 4 — compiler fusion (match eager-PyTorch)
- compile-time kernel fusion (norm/act/residual → matmul epilogue),
  memory-traffic minimization, static-shape specialization.
- F-RFC043-WALL-IMPROVED (qualitative — no fabricated multiple).

### Phase 5 — whole-program fusion (exceed eager-PyTorch — ULTIMATE)
- north-star per RFC 043 perf thesis. Floor = cuBLAS roofline (match);
  win = above GEMM. f1/f2: NO lattice perf claim. Multi-cycle.
- Acceptance = real d=768·12L compiled-only `.py`-free fire to a
  captured final loss (the goal the pure-hexa path couldn't reach).

## 2. 의존 (gating)

Phase 0 → 1 needs RFC 040 (device-farr+cuBLAS) land · RFC 034 (autograd)
land (✅) · RFC 041 (real kernels) for non-matmul ops. RFC 042 SUBSUMED
(no separate work). Implementation = dedicated multi-cycle, **user-gated**.

## 3. 진행 트리거

flame Phase 진입 = 이 PLAN `## 진행 로그` append + `FLAME.tape` 동기화 +
falsifier 사전등록 + 사용자 go. 우회 금지 (HEXAD Phase Gating 미러).

## 진행 로그

(append-only — 첫 실행 시 entry append)

### 2026-05-16 — flame/ 스캐폴드 LANDED (DESIGN, 실행 0)
README + PLAN + FLAME.tape 작성. RFC 043 filed (`4dcaf80f`). 캠페인 전
산출물 `FLAME.tape` §X 에 참조-보존 (branch·SHA·path·RFC#). Phase 0
= branch 통합(물거품 방지) 명시. 구현 미착수 — 사용자 검토·go 대기.

### 2026-05-16 — Phase 0 CLEARED + Phase 1 START
git 실측으로 Phase 0 진단: rfc043-hexa-torch 가 5 캠페인 브랜치의
strict 선형 상위집합 + origin push 검증(바이트동일) → 물거품 risk
이미 해소, Phase 0 acceptance MET. "5 scattered branches" 부정확
프레이밍 정정 (이 파일 + FLAME.tape + README). 사용자 결정 = option A.
Phase 1 falsifier 사전등록 (FLAME.tape `g_flame_phase1_falsifiers`:
F-RFC043-BUILD, F-RFC043-AG-EQ). Phase 1 (tensor_lib + autograd_lib)
구현 착수 — rfc043-hexa-torch 에서.

### 2026-05-16 — Phase 1 LANDED (4/4 PASS + regression 0)
landed: `stdlib/flame/{tensor_lib.hexa, autograd_lib.hexa, flame.hexa}`.
selftest 결과 (compiled-native `build/flame_phase1`, Mac no-CUDA):
- **F-RFC043-BUILD** PASS — clang redef 0; emitted C 의 ag_*/t_* surface
  는 `hexa_ad_*`/`hexa_farr_*` direct call, `call_builtin` = 0 →
  compiler-only 구조적 검증 (가정 아님).
- **F-RFC043-AG-EQ** PASS — `max|ag_grad − (softmax − onehot)| = 0.0
  < 1e-9` (anima B-D-4 closed Jacobian bit-equal); ag_* wrapper ↔
  RFC 034 ad_* oracle connection-point closed (g_blue_closed_mandate).
- **F-RFC043-DETERMINISM** PASS — seed=42 trajectory 두 run
  byte-identical.
- **F-RFC043-AG-TRAJ-ORACLE** PASS — 20-step trajectory loss[0]≈
  1.64219, loss[19]≈0.228332 (RFC 034 oracle, printed-precision floor
  1e-4 — bit-equal numerics). 이 falsifier 가 matmul wrapper arg
  ordering 까지 검증 (g3 honesty: 초기 3/3 PASS 가 ag_matmul arg-bug 를
  masking 했었음을 진단 중 발견 → fix + 추가).
- **F-RFC043-MODULE-REGRESSION-0** PASS — RFC 034 5/5 + RFC 040 B2
  9/9 smoke 재빌드 후 동일 PASS · 동일 numerics.
honest carve-out: device routing 미구현 (farr_*_gpu / cuda_* 의
codegen 미wired — RFC 041/042 upstream needs). 도입 = Phase 4. Phase
2 (nn layers) gate 충족 — 같은 ag_*/t_* 위 layer wrappers 추가
(g_flame_api_fixed: API signature 불변).

### 2026-05-16 — Phase 2-A LANDED (Linear + RMSNorm, 4/4 PASS + regression 0)
landed: `stdlib/flame/{nn_lib.hexa, flame_nn_test.hexa}`. Phase 2-A =
가장 단순한 두 layer (closed-form analytic vjp); Phase 2-B (RoPE /
GQA-attn / SwiGLU / embedding / tied-LM-head) = 별도 cycle.
selftest 결과 (compiled-native `build/flame_phase2a`):
- **F-RFC043-LAYER-EQ-LINEAR-FWD** PASS — max|nn_linear_fwd − closed
  ref| < 1e-12 (RFC 040 §2.2 measured fp-tol; FMA vs hexa-scalar
  last-ulp gap honest carve-out; reduction order = `ikj` 동일).
- **F-RFC043-LAYER-EQ-LINEAR-BWD** PASS — {dW, dx, db} byte-eq vs
  closed analytic vjp (dW = xᵀ·dy, dx = dy·Wᵀ, db = Σ_rows(dy)).
- **F-RFC043-LAYER-EQ-RMSNORM-FWD** PASS — {y, xn, inv} byte-eq vs
  `c3_rmsnorm_fwd` algebra (anima d_train3_lib.hexa).
- **F-RFC043-LAYER-EQ-RMSNORM-BWD** PASS — {dx, dg} byte-eq vs
  `c3_rmsnorm_bwd` closed vjp.
- **regression**: RFC 034 5/5 · RFC 040 B2 9/9 · flame Phase 1 4/4
  모두 동일 PASS / 동일 numerics. structural: nn_lib emitted C
  `call_builtin` = 0 → compiler-only 유지.
honest carve-out: layer-level autograd-tape integration (ad_* 가
새 op record) = Phase 3 (train_step). 현재 layer 들은 functional
bwd (c3_* / d5_block_bwd 패턴 — 호출자가 dy 를 넘기고 closed
analytic gradient 를 받음).

### 2026-05-16 — Phase 2 +2 layers (Embedding + Tied LM Head, 8/8 PASS)
extension: `nn_lib.hexa` 에 nn_embedding_fwd / nn_embedding_bwd_scatter
/ nn_lm_head_fwd / nn_lm_head_bwd 추가. `flame_nn_test.hexa` 에
match falsifier 4건 추가. selftest `build/flame_phase2` 8/8 PASS:
- F-RFC043-LAYER-EQ-EMBED-FWD       PASS — row copy byte-eq (d5_forward
  §"tok_emb embed lookup" 패턴)
- F-RFC043-LAYER-EQ-EMBED-SCATTER   PASS — scatter-add 누적 byte-eq
  (d5_grad §(b) tied-weight subtlety 패턴)
- F-RFC043-LAYER-EQ-LMHEAD-FWD      PASS — |Δ|<1e-12 (RFC 040 fp-tol;
  V·d matvec via farr_matmul(V·d · d·1))
- F-RFC043-LAYER-EQ-LMHEAD-BWD      PASS — dl⊗zT + tembᵀ·dl byte-eq
- regression: RFC 034 5/5 · RFC 040 B2 9/9 · flame Phase 1 4/4 +
  Phase 2-A 4/4 모두 동일 PASS · 동일 numerics. nn_lib emitted C
  `call_builtin` = 0 (compiler-only 유지).
남은 Phase 2 layer: RoPE (rotation tables + 정규 vjp) · SwiGLU
(3 linear + silu + Hadamard, c3_swiglu_*) · GQA-attn (큰 layer).
