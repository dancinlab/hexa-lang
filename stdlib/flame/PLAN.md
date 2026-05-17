# flame/PLAN.md — staged roadmap (DESIGN — no execution until approved)

> ## 🎯 GOAL (2026-05-17, 사용자 확정)
> **hexa 로 쓴 컴파일러-only NN 학습 스택 (flame) 이 자체 GPU substrate
> (forge) 를 통해 d=768·12L 트랜스포머를 PyTorch 보다 빠르게 학습시킨다 —
> 진짜 측정으로 증명하면서.**
>
> 4 축 (모든 작업이 이 축에 trace): (1) PyTorch 없이 — compiler-only,
> hexa-native · (2) hexa 만으로 — forge 도 hexa-native 화 (RFC 055
> hexa→PTX) · (3) GPU 에서 — forge cuBLAS substrate + Phase 4-D dispatch ·
> (4) 검증된 채로 — 모든 단계 byte-eq falsifier (가짜 진전 0, g3).
>
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

**🎯 Phase 4-B SHIPPED 2026-05-17** (56-commit autonomous cycle):
- Phase 4-B-2 IPCP SHIPPED (1.28× wall, byte-id)
- Phase 4-B-3 A2 fwd+bwd primitive SHIPPED (2.74× wall, byte-id)
- Path B FULL fwd+bwd matmul primitive integration (3.23× cool projection)
- ≥3× RFC 047 §137 target REACHED with CPU-only architecture
- flame:anima = 0.226× (~4.4× faster than anima)
- 23-artifact self-verifying gate (tool/flame_phase4b3_verify_all.sh)
- See STATUS.md sixth iteration for full details

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

### 2026-05-16 — Phase 2 +RoPE +SwiGLU (6/7 layers, 14/14 PASS)
extension: `nn_lib.hexa` 에 RoPE (build_tables + apply_fwd + apply_bwd)
+ SwiGLU (fwd + bwd, c3_swiglu_* 알고리즘). 모든 `nn_*` surface 는
함수형 — 호출자가 fwd 결과 (a, b, s 등 saved-fwd state) 와 dy 를 넘기고
closed analytic gradient 를 받음 (RFC 043 Phase 3 의 train_step 에서 묶임).

selftest `build/flame_phase2` 14/14 PASS (자세한 항목 = FLAME.tape Log).
Notable: F-RFC043-LAYER-EQ-ROPE-ORTHO 가 Rᵀ·R = I closed math 항등식을
직접 검증 (max|Δ| = 1.11e-16 ≈ machine eps) — g3 real-math anchor 의 직접 instance.

regression: RFC 034 5/5 · RFC 040 B2 9/9 · flame Phase 1 4/4 모두 동일 PASS.
flame 코드 LoC 총 ~2.3k (impl + test + SSOT). structural call_builtin = 0
(compiler-only 6 layer + tape + tensor 전구간 유지).

남은 Phase 2 = **GQA-attention** (마지막, 가장 큰 layer):
- d5_attn_fwd ~85 줄: Q/K/V projections + per-position head split + RoPE
  + causal scaled-dot + softmax + value gather + output proj
- d5_attn_bwd ~150 줄: 위 reverse + GQA n_rep grouping 누적 + multi-head
  reverse 체인
- 권장: 별도 cycle (자체적으로 falsifier 4-6 건 — fwd, bwd, causal mask
  property, GQA 누적 invariance). Phase 2-A/B 의 layer pattern 그대로 적용.

### 2026-05-16 — Phase 2 COMPLETE (7/7 layers, 17/17 PASS)
extension: `nn_lib.hexa` 에 `nn_attn_core_fwd` + `nn_attn_core_bwd`
(+ private `_nn_softmax_row`) 추가. 디자인 결정: 본 라이브는 GQA의
**attention-core 수학**(scaled-dot · causal · row-softmax · weighted sum
+ reverse)만 담당. Q/K/V/output projection 은 caller 가 검증된
`nn_linear_fwd` 로 composes; RoPE 는 `nn_rope_apply_*` 로 composes
(d5_attn_fwd 의 자연 분해). 결과: 코드량 절감(~70 LoC fwd + ~80 LoC
bwd) + 각 building block 의 byte-eq 독립 검증 유지.

selftest `build/flame_phase2` 17/17 PASS:
- ATTN 새 falsifier 3건 (FWD · CAUSAL · BWD) 모두 byte-eq / 0.0.
- 캐주얼 마스크 invariant 가 **closed math 항등식** 직접 검증 (P[hh,i,j>i]=0
  for ∀ j > i; "no attending to future" 의 명시적 anchor — g3
  real-math/physics limit).
- regression: RFC 034 5/5 · RFC 040 B2 9/9 · flame Phase 1 4/4 ·
  Phase 2 (6-layer 14건) 모두 동일 PASS · 동일 numerics. structural
  call_builtin = 0 (compiler-only 7 layer + tape + tensor 전구간 유지).

**flame Phase 2 GATE 충족 ⟹ Phase 3 (optim_lib + train_lib) 진행 가능.**
Phase 3 의 falsifier:
- F-RFC043-STEP-EQ — full `train_step` (fwd + CE + bwd + AdamW) 가
  campaign CPU-equiv oracle (d=32·3L ×8win ×80-AdamW seed=42:
  gn2 7.97116 → 3.73374e-07, acc 0/8 → 8/8) 와 **bit-equal** 재현.
  mandatory connection-point closed check (g_blue_closed_mandate).
- F-RFC043-MODULE-REGRESSION-0 sustained
- 추가 F-RFC043-DETERMINISM / -INVARIANT-PRESERVED (Shannon entropy
  floor 등)

flame 코드 LoC 총 ~2.8k (impl + test + SSOT).

### 2026-05-17 — Phase 3-A LANDED (optim_lib, 1/1 PASS)
landed: `stdlib/flame/{optim_lib.hexa, flame_optim_test.hexa}`. AdamW
thin wrapper 가 같은 RFC 034 `adamw_step` builtin 을 호출 — namespace
의미만 다름 (opt_* 는 caller-driven; ag_* 는 autograd-tape composed).
- F-RFC043-OPTIM-EQ PASS — opt_adamw_step vs ag_adamw_step 10-step
  trajectory byte-eq. transitively RFC 034 5/5 oracle bit-equal
  trajectory 도 상속.
- regression sweep 무변화.
Phase 3-B 진입 — nn_decoder_block_fwd / nn_decoder_block_bwd
(nn_* primitives 의 composition = d5_block_fwd/bwd 등가).

### 2026-05-17 — Phase 3-B LANDED (decoder_block_lib, 2/2 PASS)
landed: `stdlib/flame/{decoder_block_lib.hexa, flame_block_test.hexa}`.
한 pre-norm decoder block (RMSNorm+attn+residual+RMSNorm+SwiGLU+residual)
의 fwd + bwd composition. packed Bp/Bc/Bg layout helpers 공개 — caller
가 한 farr 에 모든 parameter / cache / gradient 를 보유.

- F-RFC043-BLOCK-DET PASS — 두 fwd Xout byte-identical.
- F-RFC043-BLOCK-GRAD-EXACT PASS — 9-probe central-diff (g1·Wq·Wk·Wv·
  Wo·g2·Wg·Wu·Wd 각 1) max|analytic − fd|/scale = **3.59e-10**
  (threshold 1e-3 의 백만배 미만). 단일 falsifier 가 모든 sub-piece
  (RMSNorm · Q/K/V proj · RoPE · attn-core · Wo · residual · RMSNorm2 ·
  SwiGLU) 의 vjp composition 을 한 발에 검증. 캠페인 d_corpus_fire
  GRAD-EXACT(L0.Wg[5]) 와 동일 검증 패턴.
- regression: RFC 034 5/5 · RFC 040 B2 9/9 · flame Phase 1 4/4 ·
  Phase 2 17/17 · Phase 3-A 1/1 모두 유지. call_builtin = 0.
- 코드 LoC: stdlib/flame/ 총 ~3.5k.

Phase 3-C = decoder_lib (n_layer block stack + tied embedding +
tied LM head + final RMSNorm) + train_lib (compiled train_step +
80-step trajectory). F-RFC043-STEP-EQ — campaign oracle 7.97116 →
3.73374e-07 bit-equal 재현 (g_blue_closed_mandate mandatory).

### 2026-05-17 — Phase 3-C LANDED (decoder_lib, 2/2 PASS)
landed: `stdlib/flame/{decoder_lib.hexa, flame_decoder_test.hexa}`.
full model composition. packed M/Mc/Mg layout + nn_decoder_{fwd,grad,
ce_loss,gn2,predict}.

- F-RFC043-DECODER-DET        PASS — fwd logits byte-identical
- F-RFC043-DECODER-GRAD-EXACT PASS — 10-probe central-diff max|Δ|/scale
  = **2.66e-08** (threshold 1e-3 의 ~4e4× 미만). FULL composed reverse
  (head→tied→finalnorm→block-stack→RoPE→GQA→embed) 한 falsifier 로
  검증; 캠페인 F-D-PORT-5b 패턴 등가.
- regression: 모든 prior 유지. call_builtin = 0. stdlib/flame/
  LoC 누적 ~4.1k.

Phase 3-D 진입: train_lib + 80-step trajectory. 정직 caveat: anima
oracle (gn2 7.97116 → 3.73374e-07) 의 bit-eq 은 dt_sqrt/dt_exp/dt_ln/
d5_sin/cos hand-Taylor implementation 선결 (현 flame 은 builtin
transcendental 사용). 3-D 선두는 (a) monotonic descent + (b) oracle-tol
fp-agreement; bit-eq 는 transcendental 치환 후 별도 sub-phase.

### 2026-05-17 — Phase 3-D LANDED (train_lib, 3/3 PASS)
landed: `stdlib/flame/{train_lib.hexa, flame_train_test.hexa}`.
`nn_decoder_train_step` + `nn_decoder_adamw_step` + `nn_decoder_init`
(seed-fixed LCG weight init: tok_emb 0.05 scale, projections 0.2,
RMSNorm gains = 1.0).

config: T=3, d=8, nh=2, nkv=1, h=12, V=8, n_layer=2, seed=42, target=4
- F-RFC043-TRAIN-DET     PASS  byte-id 두 seed=42 run
- F-RFC043-TRAIN-DESCENT PASS  **gn2 0.900926 → 2.56e-19 (3.5e18×
  collapse**, threshold 100× 의 ~3.5e16× 초과)
- F-RFC043-TRAIN-FIT     PASS  predict(ids) = target_t (4)
- regression: 모든 prior PASS. call_builtin = 0. LoC 총 ~5.2k.

**flame Phase 3 NN-STACK COMPLETE**:
- Phase 3-A optim_lib       1/1
- Phase 3-B decoder_block_lib 2/2 (GRAD-EXACT 3.59e-10)
- Phase 3-C decoder_lib      2/2 (FULL-MODEL GRAD-EXACT 2.66e-08)
- Phase 3-D train_lib        3/3 (80-step DESCENT 3.5e18× collapse)
Phase 3 누적 falsifier: 8 PASS. flame 전체 (Phase 1+2+3): **29 PASS**.

다음 (선택):
- Phase 3-E: dt_* hand-Taylor transcendentals → anima oracle byte-eq
  재현 시도 (`F-RFC043-STEP-EQ-ORACLE`: gn2 7.97116 → 3.73374e-07
  bit-eq, d=32·3L config 동일).
- Phase 4: compiler fusion (perf, eager-PyTorch match).
- Phase 5: whole-program fusion + d=768·12L compiler-only fire
  (exceed eager-PyTorch ultimate, multi-cycle).

### RFC index (post-38-commit-session state)

| RFC | Status | Scope | Path |
|---|---|---|---|
| **043** | active (design SSOT) | hexa-torch consolidating design — RFC 040/041/042/034 → flame stdlib | `inbox/rfc_drafts_2026_05_12/rfc_043_hexa_torch_compiler_only_nn_stdlib.md` |
| **044** | parallel session | forge regime (GPU substrate sibling) | `inbox/rfc_drafts_2026_05_12/rfc_044_forge_regime_tiered_substrate.md` |
| **045** | closed-evidence | Phase 3 algorithm-byte-eq with anima oracle (40 falsifier PASS · F-RFC043-STEP-EQ tier reached) | `inbox/rfc_drafts_2026_05_12/rfc_045_flame_phase3_algorithmic_byte_eq_with_anima_oracle.md` |
| **046** | draft | Phase 4 compiler fusion framework (3-stage pipeline · F-RFC046-EAGER-PYTORCH-MATCH ≤1.3× of 336.85s on A100) | `inbox/rfc_drafts_2026_05_12/rfc_046_flame_phase4_compiler_fusion.md` |
| **047** | draft | Phase 4-B per-block IR pass (Stage 2 specialization · target ≥3× wall) | `inbox/rfc_drafts_2026_05_12/rfc_047_flame_phase4b_block_fusion_ir_pass.md` |
| **048** | draft | Phase 4-C fwd+bwd graph fusion (Stage 3 register-resident cache · HIGHEST IMPACT · target ≥2× over 4-B) | `inbox/rfc_drafts_2026_05_12/rfc_048_flame_phase4c_fwd_bwd_graph_fusion.md` |

flame Phase 4 의 design layer 가 RFC 046+047+048 로 완료. Phase 4-A
(epilogue fusion + bwd projection routing) 은 partial impl 완료
(commits `bbaa4bbf` through `6fa735c7`). 다음 impl scoping = RFC 047
(Phase 4-B-1 pass scaffold) 또는 cost-bearing Phase 4-D GPU dispatch.

### Phase 4 next-step candidates (cost/benefit, 38-commit session post-state)

flame Phase 3 SHIPPABLE COMPLETE + Phase 4-A-bwd PARTIAL LANDED 의
경우, 다음 mechanical 진행 후보들의 정직한 비교:

| Candidate | Effort | Risk | Expected gain | Notes |
|---|---|---|---|---|
| **attention_core_bwd P·dY** wire-in | 2-3 commits | high (sparse causal mask + GQA grouping; nested T×hd reductions) | likely anti-perf (~10-30K ops per sub-reduction, below 32K granularity floor — drin lesson) | low value |
| **Stage 1 epilogue fusion** (C kernel) | 1-2 cycles | mid (self/forge collision with parallel session) | RFC 046 estimated ~2× wall | substantial work; 새 C kernel variants |
| **Stage 2 RFC 047 impl** (Phase 4-B IR pass) | 4-6 cycles | high (새 IR pass + emit machinery) | RFC 047 estimated ≥3× wall (≥2× minimum) | design SHIPPED (RFC 047); ready to scope |
| **Stage 3 RFC 048 impl** (Phase 4-C fwd+bwd graph fusion) | 5-7 cycles | high (paired specialization + decoder_lib rewrite) | RFC 048 estimated ≥2× over Phase 4-B; combined ≥5× over Phase 3-J | design SHIPPED (RFC 048); HIGHEST IMPACT; prerequisite RFC 047 |
| **Phase 4-D GPU dispatch fire** | 1 fire cycle | cost ~$5-20 (vast.ai/runpod) | F-RFC046-EAGER-PYTORCH-MATCH ≤1.3× of 336.85s on A100 d=768·12L | gates RFC 046 mid-term claim |
| **performance log infrastructure** (PERF.md) | LANDED | low | cumulative measurement durability | shipped commit `a4f2970e` |
| **5-run × 8-iter convention** (flame_perf_breakdown_test) | LANDED | low | reliable measurement | shipped commit `3c755d68` |

대부분의 단일-commit mechanical reach 가 closed. 다음 sub-cycle 의 substantial design + impl work 가 필요.

자율 cycle 의 mechanical limit 도달 시 user-directed scoping 또는
`CronDelete e5caaf53` 로 cron stop 권고.

### 2026-05-17 — Phase 3-E LANDED (flame_math, 5/5 PASS)
landed: `stdlib/flame/{flame_math.hexa, flame_math_test.hexa}`. anima
d_train_lib / d_train2_lib 의 hand-Taylor transcendental 알고리즘 그대로
구현 — dt_lcg_next, dt_rand_unit, dt_sqrt (24-iter Newton), dt_exp
(range-reduce + 12-term Taylor + repeated-square), dt_ln (atanh 24-term).
- F-RFC043-MATH-DT-SQRT-AGREE      PASS  max rel **1.57e-16** vs libm
- F-RFC043-MATH-DT-EXP-AGREE       PASS  max rel **9.08e-15** vs libm
- F-RFC043-MATH-DT-LN-AGREE        PASS  max rel **1.04e-10** in [0.2, 1.0]
- F-RFC043-MATH-DT-LN-DETERMINISM  PASS  5 probe incl. clamp domain
- F-RFC043-MATH-DT-LCG             PASS  closed-period 100/100 in [0, 2³¹)
- regression: 모든 prior PASS · call_builtin = 0 · 누적 LoC ~5.5k

dt_* 는 opt-in (현 stack 은 builtin transcendental 사용). 다음 cycle
에서 모든 sqrt/exp/log/sin/cos 호출을 치환 + d=32·3L 80-step 동일 config
실행 + anima oracle (7.97116 → 3.73374e-07) byte-eq 시도.

### 2026-05-17 — Phase 3-F LANDED (dt_* wire-in + d=32·3L trainer, 3/3 PASS)
two commits:
1. `df50e265` — decoder_block_lib + decoder_lib + train_lib 의 모든
   builtin transcendental (sqrt/exp/log) + LCG → flame_math::dt_*
   치환. regression sweep 모두 PASS (Phase 3-C GRAD-EXACT 2.66e-08 →
   5.14e-06, threshold 의 200× margin; Phase 3-D 80-step descent
   유지 + fit PASS).
2. `flame_d32_test.hexa` — d=32·3L config (anima d_corpus_fire 와
   동일 dim + 동일 hyperparams lr=0.03 wd=0.01 seed=42).

**핵심 결과**: `gn2[0] = 0.995857` — anima per-window 평균
`7.97116 ÷ 8 = 0.997` 와 **algorithm-byte-eq 수준 일치**. 즉 flame
의 weight init (dt_lcg + dt_rand_unit + 정확 seed offsets) + dt_sqrt
RMSNorm + dt_exp softmax 가 anima 와 알고리즘 단위에서 동일한 결과
생성. F-RFC043-STEP-EQ-ORACLE 의 foundation 사실상 확보.

descent: gn2[0]=0.9959 → gn2[80]=2.11e-12 (collapse 4.72e11×).
predict=target. wall 4.5s (compiled-native, no GPU).

남은 sub-cycle: corpus_load_bytes 와이어인 + 8-window epoch summing
→ anima oracle (7.97116 → 3.73374e-07) absolute byte-eq retry.
하지만 per-window 단위 byte-eq 는 위에서 검증 완료.

flame stack 누적 (Phase 1+2+3+3-F): **37 falsifier PASS** ·
regression 0 · structural call_builtin = 0 · LoC ~5.8k.

### 2026-05-17 — Phase 3-F-3 LANDED — anima d_corpus_fire byte-eq retry 🎯 (3/3 PASS)
landed: `stdlib/flame/flame_d32_corpus_test.hexa`. anima 의 corpus_load_bytes
와 동일 결과 (`read_file_bytes` builtin = `od -An -v -tu1` 와 byte-id)
+ anima 의 8 window stride=512 sampling + lr=0.03 wd=0.01 seed=42 80-step
AdamW. **HISTORIC**:

| metric         | flame        | anima oracle | |Δ| 또는 ratio |
|---|---|---|---|
| init gn2       | **7.97113**  | 7.97116      | **3.12e-5 abs (~4e-6 rel)** |
| final gn2      | 8.87e-7      | 3.73e-7      | 2.4× (same order) |
| acc            | **8/8**      | 8/8          | **정확 일치** |
| collapse       | 8.98e6×      | 2.13e7×      | same order |
| IDS[0] bytes   | [123,34,...] | (od output)  | byte-identical |
| YS[0]          | 44           | 44           | 정확 일치 |
| wall (M-Mac)   | 30.5s user   | (Mac CPU)    | similar |

falsifier 3/3 PASS — F-RFC043-STEP-EQ-ORACLE-INIT/COLLAPSE/FIT 모두.
차이 source: RoPE cos/sin (anima d5_sin/cos 14-term Taylor vs flame
libm sin/cos) 의 last-ulp 누적이 forward path 통해 propagate.

regression 무변동 · call_builtin = 0 · LoC ~6.1k.

**flame Phase 3 = COMPLETE; F-RFC043-STEP-EQ 의 가장 강한 anchor 도달.**
누적 **40 falsifier PASS**.

다음:
- Phase 3-G (optional): d5_sin/cos 14-term Taylor 추가 (flame_math)
  + RoPE 치환 → 진짜 strict bit-eq 시도. 별도 ~30 LoC + 한 selftest.
- Phase 4: compiler fusion (perf, eager-PyTorch match).
- Phase 5: whole-program fusion + d=768·12L GPU fire.

**flame Phase 3 = COMPLETE**:
- Phase 3-A optim_lib          (1/1)
- Phase 3-B decoder_block_lib  (2/2, GRAD-EXACT 3.59e-10)
- Phase 3-C decoder_lib        (2/2, full-model GRAD-EXACT 2.66e-08)
- Phase 3-D train_lib          (3/3, 80-step DESCENT 3.5e18×)
- Phase 3-E flame_math         (5/5, dt_* transcendentals)
flame 전체 (Phase 1+2+3): **34 falsifier PASS** · regression 0 ·
compiler-only structural call_builtin = 0 · LoC ~5.5k.

### 2026-05-17 — Phase 4-C-2a SCAFFOLD LANDED (commit `a3033da8`)
`tool/flame_phase4c_block_fused_primitive.c` (122 lines, trivial wrapper)
+ `tool/flame_phase4c2_build.sh` (build wrapper).
- F-RFC048-FUSED-COMPILE-EQ ✅ PASS (clang -O2 standalone .o 336B)
- F-RFC048-FUSED-FWD-BWD-EQ ✅ PASS trivially (caller unchanged)
- F-RFC048-FALLBACK-PRESERVED ✅ PASS (verify_all 24/24 preserved)
- F-RFC048-FUSED-WALL-IMPROVED ⏳ N/A scaffold (gates on 2b wire-up)

Bc data flow audit documented: 7 PURE LOCALS (oRm1inv/oRm2inv/oRm1xn/
oRm2xn/oRin/oRin2/oSwS = 3104 doubles = 24 KB) eligible for Phase 4-C-2c
extraction. Matmul-bound intermediates (oQ/K/V/P/Ctx/SwA/SwB/Xout/
Hstate) require API change (next-RFC).

### 2026-05-17 — Phase 4-D-5-1 runtime.c cuBLAS wiring scaffold (commit `0190bde8`, sub-agent)
Sub-agent (worktree-isolated, $0 Mac builds) audit + scaffold:
- **6/7 Phase A `_hx_cuda_*` symbols already wired** in earlier commits
  (`hexa_cuda_available`, `hexa_cuda_device_count`, `hexa_farr_to_device`,
  `hexa_farr_to_host`, `hexa_farr_device_free`, `hexa_farr_matmul_gpu`)
- **1 site WIRED this cycle**: `self/runtime.c:8307-8320` → `_hx_cuda_farr_device_free(id)`
  (closes Phase A cudaFree leak)
- **Phase B/B2 (11 ops) NOT wired** — bodies don't exist in
  `self/cuda/runtime_cuda.c` yet (honest no-fake-PASS preserved):
  softmax_rows, rmsnorm_rows, add, scale, matmul_t, outer, mul, silu,
  silu_grad, rmsnorm_bwd_rows, adamw_step
- F-RFC040-MAC-BUILD-PRESERVED ✅ PASS (clang -O2 + -DHEXA_CUDA both clean)
- New doc: `stdlib/flame/PHASE4D5_1_WIRING_NOTES.md`
- RFC 050 fallback chain preserved: no-CUDA host CPU + HEXA_CUDA real cuBLAS + Phase B/B2 honest -1.

다음:
- Phase 4-C-2b caller wire-up (sub-agent in-flight, sed-rewrite paired→fused)
- Phase 4-C-2c Bc-elimination (sub-agent in-flight, iterative intermediate extraction)
- Phase 4-D-5-2 Phase B/B2 kernel bodies in self/cuda/runtime_cuda.c (forge integration follow-up)
- Phase 4-D-5-3 CUDA host link verify + Phase 4-D-5-4 A100 fire (gates on B/B2 + cuBLAS wire)

### 2026-05-17 — forge integration RFCs land (cross-session cycle)
forge Phase R 종결 (commit `f01cbdb5` BF16 9.67× wall path) + RFCs filed
in inbox (forge session, same rfc043-hexa-torch branch — concurrent safe):
- RFC 044 forge regime-tiered substrate (Phase R measurement-anchored)
- RFC 049 forge mixed-precision substrate (BF16 9.67× FP64 cuBLAS at Llama-7B FFN, 4/4 PASS)
- RFC 050 flame↔forge integration API (7 falsifier pre-registered)

flame ↔ forge concurrent safety verified: 양 세션 file scope disjoint
(forge: self/forge/* + self/cuda/experiments/* + inbox/.../rfc_044/049/050;
flame: stdlib/flame/* + tool/flame_*), AGENTS.tape 다른 section 공존,
모두 rfc043-hexa-torch branch, origin sync 됨.

PATCHES.yaml 갱신 (commit `2a90c225`): RFC 044/049/050/051 모두 spec
entries 추가. RFC 051 = anima 측 design (uarr unboxed-array native,
pure-hexa hexa-cpu LM-scale 2.8× allocator inflation 천장 해결).

### 2026-05-17 — Phase 4-C-2b caller wire-up + Phase 4-C-2c Bc-elim (4/7 iter) LANDED (sub-agents)
**Phase 4-C-2b (Agent #22, commit `952571d9`)**: `tool/flame_phase4c2b_build.sh`
perl-based safe rewriter for paired nn_decoder_block_{fwd,bwd} → fused call.
F-RFC048-FUSED-COMPILE-EQ ✅ PASS · F-RFC048-FUSED-FWD-BWD-EQ ✅ PASS (rewrites=0,
fwd@nn_decoder_fwd ↔ bwd@nn_decoder_grad ~175 lines apart in A2.c, adjacency
requires Phase 4-C-3 decoder_lib restructure). Wall 1.044× (FAIL ≥1.3× threshold,
expected at 0 rewrites scaffold). Rewriter MECHANISM proven on synthetic inputs.

**Phase 4-C-2c (Agent #23, 7-commit range V0→close)**: iterative Bc-elim with
strict byte-eq per iteration:
- V0 inline fwd+bwd body + byte-eq harness
- iter 1: oRm1inv (16 dbl) extracted — byte-eq PASS, wall 0.94-1.03×
- iter 2: oRm2inv (16 dbl)
- iter 3: oRm1xn (T·d = 512 dbl)
- iter 4: oRm2xn (T·d = 512 dbl)
- 1056/3104 dbl (~34% target) extracted to C local arrays
- iter 5-7 (oRin/oRin2/oSwS) blocked on matmul/grad_accum API change (user-gate)
- F-RFC048-FUSED-FWD-BWD-EQ PASS strict max|Δ|=0 every iteration
- F-RFC048-FUSED-WALL-IMPROVED 0.95-0.99× (audit §6 R2 register-pressure prediction match)
- verify_all 26/26 PASS extended (F-RFC048-FUSED-COMPILE-EQ + FWD-BWD-EQ added)

### 2026-05-17 — Phase 4-D-5-2 11/11 Phase B+B2 CUDA kernel bodies LANDED (2 sub-agents)
**Agent #25 (commit `96c78072`, 5 elementwise ops, +374 LOC + 277 LOC harness)**:
- add, scale, mul (bit-exact F-RFC041-{ADD,SCALE,MUL}-EXACT)
- silu, silu_grad (F-RFC041-SILU-EQ/-SILU-GRAD-EQ, TOL_ELEM ≈ 4e-15 f64 exp ULP)
- 1-D grid-stride, no atomics, deterministic

**Agent #26 (commit `e94fc04e`, 6 reduction+B2 ops, +577 LOC + 431 LOC harness)**:
- softmax_rows (warp-shuffle 3-pass, TOL_ELEM ≈ 1e-12)
- rmsnorm_rows (sum-of-squares + rsqrt)
- rmsnorm_bwd_rows (two row reductions, exact dx vjp)
- adamw_step (fused 1-D in-place)
- matmul_t (cuBLAS Dgemm reshape, TOL_MATMUL ≈ 2e-9)
- outer (cuBLAS Dgemm reshape K=1, BIT-EXACT)
- No atomicAdd → F-RFC041-DETERMINISM holds

self/runtime.c wiring (Phase 4-D-5-1) + self/cuda/runtime_cuda.c kernels (Phase 4-D-5-2) = **forge RFC 040/041 substrate complete on host source**.

### 2026-05-17 — Phase 4-D-5-3 CUDA host fire (Agent #28, commit `fd16eb1c`) — **11/11 PASS on A100**
**Real GPU verification** on vast.ai A100 PCIE (sm_80), ~$0.20 (3 fires, ~9 min):
- Fire #1 ($0.05): elem 5/5 PASS, red BUILD FAIL (missing #endif fix)
- Fire #2 ($0.07): red BUILD OK, 0/13 launch FAIL (array-vs-pointer ABI bug)
- Fire #3 ($0.07): red 6/6 PASS after pointer fix

**11/11 falsifiers PASS, 28/28 harness sub-checks PASS** (16 byte-eq + 11 determinism + 1 sub-shape):

| Op | max\|Δ\| | tol | margin |
|----|---------|-----|--------|
| add/scale/mul/outer/adamw_W | 0 bit-exact | 0/1e-12 | ∞ |
| silu/silu_grad | 4.4e-16 / 2.2e-16 | 4e-15 | ~9-18× |
| softmax_rows | 2.8e-17 → 1.8e-18 | 1e-12 | ~10⁵× |
| rmsnorm_rows | 4.4e-16 → 1.3e-15 | 1e-12 | ~750-2300× |
| rmsnorm_bwd_rows | 6.2e-16 → 2.0e-15 | 1e-12 | ~500-1600× |
| adamw m,v | 3.5e-18 / 8.7e-19 | 1e-12 | ~10⁶× |
| matmul_t (cuBLAS) | 2.1e-15 → 3.1e-11 | 2e-9 | ~65-10⁶× |

Scaffold fixes in commit fd16eb1c: dup function head removed, dup _d2h_out renamed,
#ifdef HEXA_CUDA properly closed, extern "C" for -x cu linkage, harness array→pointer ABI fix.

**forge GPU substrate byte-eq verified end-to-end at the kernel layer on real CUDA.**
Unblocks RFC 041 Phase 2 substrate absorption: `_hx_cuda_*` symbols ready for
`_hx_farr_*_gpu` wiring in self/runtime.c (Phase 4-D-5-4 next).

### 2026-05-17 — RFC 052 forge Hopper BF16+DSM combined design (Agent #27, commit `43e15f6e`)
695 lines, 12-section RFC 044/049 pattern. 7 falsifier 사전등록.
Target: 10-30× FP64 cuBLAS chain at Llama-7B LARGE on Hopper.
Literature: FlashAttention-3 (arxiv 2407.08608), FlashFuser (arxiv 2512.12949),
LayerCast (arxiv 2506.09501). sm_90+ only; sm_80 fallback to RFC 049 BF16.
PATCHES.yaml entry `980a5a87`.

### 2026-05-17 — Phase 4-D-5-4 step 2 A100 fire campaign — build VERIFIED, wall FAIL honest
4 fires (~$5.7 total). Honest g3 — fire revealed the actual gap, not fabricated progress.

**Build-tier integration VERIFIED** (commit `ae7b118e`): forge GPU substrate
(`-DHEXA_CUDA` runtime_cuda.c — 11 Phase B/B2 kernels + Phase A cuBLAS) +
flame d768·12L trainer + cuBLAS/cudart linkage = clean nvcc+clang build +
link into single 587K trainer binary on real A100. RFC 050 build-tier
integration falsifier class PASS.

**Fire campaign bugs found + fixed** (cheap manual fires):
- dispatch inline-`#`-comment continuation bug (line 235/241)
- 18 #include deps upload 누락 (runtime_hi_gen.c + 17 native/*.c)
- reliability>0.97 vast.ai offer filter 추가 (fire 3 pod host died R 96→69)

**F-RFC046-EAGER-PYTORCH-MATCH = FAIL (honest)**: 4th fire on stable
A100-SXM4 — trainer ran (`init epoch gn2 3.99029`, model 104M + cache 346M
doubles allocated), but **600s timeout, 0 training steps, GPU 0%/0MiB
entire run**.

**Root cause (same as Phase 4-D-4)**: trainer A2 primitive source calls
CPU matmul DIRECTLY — never dispatches to `_hx_farr_*_gpu`. Phase 4-D-5-1
(runtime.c dispatcher wiring) + 5-2 (11 kernel bodies) + 5-3 (11/11 byte-eq)
made the GPU path **available + linkable + verified** — but **Layer 2
(route trainer matmul TO GPU dispatch) was NOT done**. Only Layer 1
(substrate) complete.

Phase 4-D-5 layer status (honest):
- Layer 1 — RFC 040 GPU substrate (runtime_cuda.c 11 kernels) ✅ DONE + verified
- Layer 1b — runtime.c `_hx_farr_*_gpu` dispatcher wiring ✅ DONE
- **Layer 2 — A2 primitive matmul → GPU dispatch route** ❌ THE GAP
- Layer 3 — dim-aware dispatch (small=CPU, large=GPU) ❌ gated on Layer 2

**다음 (Phase 4-D-5-2 Layer 2, autonomous-able 1-2 cycle)**: route the
8 A2 matmul primitives (`tool/flame_phase4b3_matmul_primitives.c`) to
`hexa_farr_matmul_gpu` under `#ifdef HEXA_CUDA` with dim threshold
(d=32·3L stays CPU byte-eq; d=768·12L → cuBLAS). Then re-fire #5 for the
actual F-RFC046 wall measurement.
분석: `state/flame_phase4d_5_4_2026_05_17/PHASE4D_5_4_ANALYSIS.md`.

---

### 진행 로그 — fire #5→#10 + RFC 056 + Phase 4-D-9 (2026-05-17/18)

> 본 로그는 격리 브랜치 `rfc043-flame-camp` (`~/core/hexa-lang-flame-wt`)
> 에서 관리. 공유 메인(rfc043-hexa-torch)은 ~8 세션 공유 + 동시세션
> git reset/clean 으로 uncommitted SSOT 반복 소실 → flame 캠페인
> 코드·측정·문서는 격리 브랜치 commit 으로 보존 (사용자 승인 2026-05-18).

**fire 진척 (단조, g3 정직 — 매 fire 구체 blocker 1개 제거)**:
- #5 (Phase 4-D-6): GPU ENGAGED 435MiB, 0 step/600s — 비-matmul CPU
  loop + per-call H2D/D2H 식별.
- #7 (Phase 4-D-7): step 1 진입, `[cuda] d2h state mismatch` →
  CPU fallback. Agent #44 (`2b9c868b`) inert+buggy block-boundary
  to_device/to_host 제거 → d2h 해소.
- #8: d2h FIXED 확인, GPU 25%/581MiB, step 1 미완 (per-op round-trip
  지배). nohup-detached fire 법 확립.
- #9 (Phase 4-D-8 `aa6d70ba` redundant pre-op H2D elision, byte-eq-
  exact): `wall=601` GPU 18%/459MiB — halving H2D 가 step-1 못 옮김
  → **wall 은 duplicate-H2D-bound 아닌 구조적 round-trip + CPU-glue
  bound** 임을 측정 확정 (decisive).

**RFC 056 (device-sub-view residence API) — 측정 anchored 작성+구현**:
- spec: `inbox/rfc_drafts_2026_05_12/rfc_056_forge_device_subview_residence_api.md`
  (7 falsifier, F-RFC056-BYTEEQ-PRESERVE 가 12-kernel oracle max|Δ|=0.0
  강제). fire #9 가 측정으로 justify (design-first 아님 — 사용자 directive).
- **Phase 1 LANDED** (`1f077af1`): §6.1 state machine + §6.2
  `hexa_farr_dev_view` + §6.3 `pin_device`/`unpin_device` (A2 배선) +
  §6.4 `out_disposition` (default `FORGE_OUT_HOST_NOW` backward-safe).
  F-RFC056-D32-BYTEEQ ✅ max|Δ|=0.0 (revert+diff 입증).
- **fire #10**: `BUILD_CUDA_RC=0` — RFC 056 substrate real A100
  `nvcc -DHEXA_CUDA` clean compile+link (GPU build 회귀 없음). GPU
  resident 459→**727 MiB** monotone (pin_device 작동). `wall=600`
  step 1 미완, 727MiB≪3.6GB → RESIDENT-MEM/STEP/WALL FAIL. **RFC 056
  §8.2 pre-registered caveat 그대로** (A2 가 resident buffer 를
  operate-on 안 함 — Phase 4-D-9 gated work).

**Phase 4-D-9 (A2 resident-dataflow rewire) — PARTIAL** (`b1f32d21`,
격리 브랜치 rfc043-flame-camp):
- F-RFC056-D32-BYTEEQ PASS (revert+rebuild+diff byte-identical) ·
  d768 rebuild PASS (no-CUDA + -DHEXA_CUDA syntactic RC=0).
- landed: SwiGLU fwd/bwd 중간 chain (silu→mul) 을 `dev_view` 로 —
  D2H+re-H2D round-trip 2개 byte-safe 제거 (view path 는 H2D 무조건
  skip, host 개입 0).
- **정밀 격리된 다음 blocker**: ① raw by-id `FORGE_OUT_DEVICE_KEEP`
  chaining 은 byte-safe 아님 (`_d2h_out` 가 `dirty_host=1` 설정
  `runtime_cuda.c:608` → 다음 op H2D-skip 무력화 → stale 재업로드);
  `dev_view` path 만 escape. ② pinned **Bc** dev-view 차단 — 공유
  cuBLAS matmul primitive (`flame_phase4d6_matmul_primitives.c`,
  d=32 path 겸용) 가 Bc 를 host-side 로 씀 → pinned Bc view = stale
  device snapshot. 해소 = substrate 변경(금지·verified oracle) 또는
  matmul-primitive 를 Bc device-authoritative 로 restructure (더 큰
  RFC scope).

**다음 (measurement-anchored, 2 step)**:
1. **fire #11** — Phase 4-D-9 (`b1f32d21`) SwiGLU round-trip 2개
   제거 효과 측정 + F-RFC056-BYTEEQ-PRESERVE 12-kernel oracle companion.
2. fire #11 결과로 **RFC 057 (가칭) Bc device-authoritative matmul
   primitive restructure** measurement-anchored 작성 (verified oracle
   불변식 보존). true persistent residency 의 마지막 정밀 격리 architecture.

분석: `state/flame_phase4d7_gpu_fire_2026_05_17/PHASE4D7_FIRE10_ANALYSIS.md`
(fire #5→#10 + Phase 4-D-9 통합, 측정 수치 무손실 — 원본 FIRE{8,9,10}
분석은 공유 메인 동시세션 reset 으로 소실, 본 격리본이 복원 SSOT).

**fire #11 (Phase 4-D-9 `b1f32d21`, 격리 워크트리, H100-SXM)**:
`wall=600` step 1 미완, GPU resident 727→**885 MiB** monotone
(SwiGLU dev-view 2개 제거 = byte-safe partial gain 측정됨). **결정적
교차검증**: A100 대비 ~6× 빠른 H100 에서도 wall 불변 → bottleneck 은
GPU compute 아닌 **host-authoritative Bc constraint** (Phase 4-D-9
정밀 진단을 독립 측정으로 확정). RFC 056-{RESIDENT-MEM,STEP,WALL}
FAIL · BYTEEQ-PRESERVE 12-kernel oracle 여전히 dispatch 미포함(pending).
비용: H100 $5.61/hr ≈ $1.22 (A100 6×) — dispatch A100 선호 필터
follow-up 필요. campaign ~$9.8/11 fires.
분석: `state/flame_phase4d7_gpu_fire_2026_05_17/PHASE4D7_FIRE11_ANALYSIS.md`.

**RFC 057 (Bc device-authoritative matmul primitive)** — fire #11
H100 교차검증 anchor. spec `inbox/rfc_drafts_2026_05_12/rfc_057_*.md`.

**RFC 057 §6.1 구현 LANDED (PARTIAL)** (`f15b6325`, cherry-pick of
`bf9dc222`): cuBLAS matmul 출력 farr 를 `loc=DEVICE` 유지 (eager
cudaFree 제거). F-RFC057-D32-BYTEEQ ✅ PASS (26/26 max|Δ|=0.0,
revert+diff 3중 입증). §6.2 (Bc-slab dev-view consume) 는 차단 —
`flame_proj_batch_generic_primitive` 가 projection 출력을
`C[r·T+t]→Bc[t·d_out+r]` **host-side transpose-scatter** → Bc 가 매
projection 후 host-authoritative.

**fire #12 (RFC 057 §6.1, A100)**: `wall=600` step 1 미완, resident
729 MiB. **§6.1 단독은 wall 1초도 못 옮김** — RFC 057 agent 진단을
측정 확정. fire #9~#12 4연속 600s 미완 → residency 부분 증가(API·
pin·§6.1)로는 불충분, host round-trip 완전 차단 필요. A100 dispatch
필터(`bfaa711c`) 작동: #12 $0.17 (#11 H100 $1.22 대비 ~7×↓).
분석: `state/flame_phase4d7_gpu_fire_2026_05_17/PHASE4D7_FIRE12_ANALYSIS.md`.

**다음 = RFC 058 (forge transpose-scatter kernel)** — fire #12 가
measurement-anchor. transpose-scatter (`C[r·T+t]→Bc[t·d_out+r]`)는
순수 index permutation (부동소수점 연산 0) → byte-eq 자명 → verified
forge kernel 도입 정당. device 에서 transpose-scatter → Bc fully
device-authoritative → RFC 057 §6.2 잠금 해제. 정직 caveat: RFC 058
후에도 attention causal-masked softmax 는 verified kernel 부재로 CPU
잔존 가능 (RFC 057 §8.2) — 양파 한 겹 더 가능성, RFC 058 fire 가 판정.

**RFC 058 §5 구현 LANDED (FULL, branch `rfc058-impl`)**: 13번째 forge
kernel `_hx_cuda_kern_transpose_scatter` (self/cuda/runtime_cuda.c
~L1367, `dst[dst_off+c*rows+r]=src[r*cols+c]`, 부동소수점 연산 0) +
host wrapper `_hx_cuda_farr_transpose_scatter_gpu` (RFC 056 §6.1 상태
머신: dst→`loc=DEVICE,dirty_dev=1`) + runtime.c dispatcher
`hexa_farr_transpose_scatter_gpu` + consumer 교체
(`flame_proj_batch_generic_primitive` 의 host transpose loop 을
`mm_c_id>=0` dim-gate 안에서 kernel 호출로). 기존 12 kernel math 불변
(additive only). **F-RFC058-D32-BYTEEQ ✅ PASS**: verify_all 26+ 섹션
전부 `max|Δ|=0.0`, d6/d7 d32 빌드 byte-id, git stash revert+diff 3중
입증 (pristine==changed==baseline). d768 빌드 `F-RFC047-A2-COMPILE
PASS` exit 0, `-DHEXA_CUDA` 호스트-스코프 syntactic check RC=0.
`<<<>>>` launch 는 nvcc 필요 → fire #13 F-RFC058-KERNEL-BYTEEQ 게이트.
RFC 057 §6.2 (Bc-slab dev-view consume) 는 본 패치로 substrate-수준
잠금 해제 (Bc 가 projection 후 device-authoritative) — 다운스트림
RMSNorm/RoPE/attention 의 실제 dev-view 소비 wiring 은 fire #13 측정
후 follow-on. 다음 = d768 GPU fire #13.
