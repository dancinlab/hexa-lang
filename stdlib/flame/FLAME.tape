#!/usr/bin/env tape
# ══════════════════════════════════════════════════════════════════════
# FLAME.tape — flame stdlib SSOT (tape v1.2). Grammar primer: see
# ~/core/tape/spec/tape.md. Entry form:
#   @<type> <id> := "<subj>" :: <kind> [<grades>]  + 2-space body lines.
# Types: @V spec @I identity @L layout @D governance/decision
#        @X external-citation @N note. Edges: <: specializes ~> supersedes
#        |> verified-by @> projects-to. Arch (latest-wins) head + append-
#        only `## Log` (v1.2 arch-vs-history split).
#
# flame = hexa-native compiler-only PyTorch-equivalent NN stdlib.
# This tape is the DURABLE preservation hub: §X anchors EVERY RFC
# 040→043 campaign artifact by branch·SHA·path·RFC# so nothing is
# 물거품 (lost). DESIGN ONLY — zero implementation.
# ══════════════════════════════════════════════════════════════════════

@V v1 := "tape" :: spec [active]
  version = "1.2"

# ─── §1 Identity ─────────────────────────────────────────────────────

@I flame_id := "flame" :: identity-claim [d=2026-05-16 active]
  kind = "hexa-native compiler-only PyTorch-equivalent NN training stdlib"
  brief = "Tensor + reverse-mode autograd + nn layers + AdamW + cuBLAS, hexa build-native, ZERO hexa_interp dispatch"
  analog = "flame:hexa :: torch:Python (torch = handheld flame; project 'fire' 어휘 정합)"
  status = "Phase 0 CLEARED 2026-05-16 (preservation verified) → Phase 1 (tensor_lib + autograd_lib) IN PROGRESS"
  parent_rfc = "RFC 043 (inbox/rfc_drafts_2026_05_12/rfc_043_hexa_torch_compiler_only_nn_stdlib.md)"
  structure = "fat native stdlib + thin hexa orchestration ⟹ no heavy interpreted driver loop (RFC 042 ceiling closed structurally)"

# ─── §2 Layout (planned lib-split — compiled-first, NOT one file) ─────

@L flame_layout := "flame package layout" :: structure [d=2026-05-16 active]
  README.md -> "overview + foundation pointer"
  PLAN.md -> "staged roadmap; Phase 0 = 보존/통합 (물거품 방지)"
  FLAME.tape -> "this — SSOT + §X preservation index"
  flame.hexa -> "[LANDED 2026-05-16 Phase 1 4/4] entrypoint (use stdlib/flame/*_lib + Phase 1 selftest)"
  tensor_lib.hexa -> "[LANDED 2026-05-16 Phase 1] Tensor — host farr (RFC 040 device-farr backend; device routing = Phase 4 honest carve-out)"
  autograd_lib.hexa -> "[LANDED 2026-05-16 Phase 1] reverse-mode tape thin wrapper over RFC 034 ad_*"
  nn_lib.hexa -> "[Phase 2 ALL 7 layers LANDED 2026-05-16: Linear + RMSNorm + Embedding + LMHead + RoPE + SwiGLU + Attention-core fwd/bwd, 17/17 PASS]"
  flame_nn_test.hexa -> "[LANDED 2026-05-16] selftest entrypoint for nn_lib (F-RFC043-LAYER-EQ-* 17 falsifiers); includes ROPE-ORTHO (Rᵀ·R = I machine-ε) + ATTN-CAUSAL (P[hh,i,j>i]=0 closed math invariants) — g3 real-limit anchors"
  optim_lib.hexa -> "[Phase 3-A LANDED 2026-05-17: AdamW thin wrapper, F-RFC043-OPTIM-EQ 1/1 PASS, byte-eq to ag_adamw_step]"
  flame_optim_test.hexa -> "[LANDED 2026-05-17 Phase 3-A] selftest entrypoint for optim_lib"
  decoder_block_lib.hexa -> "[Phase 3-B planned] one decoder block (RMSNorm + GQA-attn + residual + RMSNorm + SwiGLU + residual) as nn_* composition"
  train_lib.hexa -> "[Phase 3-C planned] compiled train_step + 80-step trajectory (F-RFC043-STEP-EQ ⟸ campaign d=32·3L oracle 7.97116→3.73374e-07)"
  note = "[LANDED] = built + falsifier PASS. lib-split mandatory (compiled: main/_selftest 동거 시 C 심볼 중복). 각 selftest 는 독립 entrypoint 파일."

# ─── §3 Governance ───────────────────────────────────────────────────

@D g_flame_compiler_only := "compiler-only mandate" :: governance [required d=2026-05-16 active]
  rule = "flame 는 `hexa build` native 전용. hexa_interp dispatch 0 (인터프리터 폐기중 directive 정합). compiled C codegen + cuBLAS/CUDA 커널 직결."
  @> README.md

@D g_flame_verify_anchor := "§8/g_blue_closed_mandate 검증 anchor" :: governance [required d=2026-05-16 active]
  rule = "flame 모든 레이어 fwd/bwd + train_step 은 검증된 oracle 에 byte-equal (또는 RFC 040 측정 fp-tol). connection-point 검증 필수."
  oracle = "[@x_oracle_cpu_bitequal] + [@x_oracle_cublas] + [@x_oracle_phaseB2]"
  authority = "anima AGENTS.tape §0 g_blue_closed_mandate · g3"
  @> README.md

@D g_flame_perf_thesis := "성능 thesis — floor·forbidden·north-star" :: governance [required d=2026-05-16 active]
  north_star = "ULTIMATE (multi-cycle, NOT near-term/measured): exceed eager-PyTorch end-to-end training throughput for the fixed verified ConsciousDecoderV2 arch"
  mechanism = "whole-program AOT compile (no interpreter/Python-dispatch/GIL) · compile-time fusion (bottleneck=memory bandwidth not FLOPs) · static-shape specialization"
  floor = "raw dense GEMM = cuBLAS/NVIDIA roofline — flame MATCHES not beats; win is ABOVE GEMM. anchor = measured 51.24 TFLOPS FP64 (76% H100 peak)"
  forbidden = "NO n=6 lattice numerology in any perf assertion — hard fail (f1/f2 deny:write). anchors = Shannon / memory-bandwidth / cuBLAS-measured roofline only"
  staged = "near=feasible+correct+self-sufficient(no .py) → mid=match eager-PyTorch → ultimate=exceed. qualitative, no fabricated multiple"
  @> README.md

@D g_flame_preservation := "물거품 방지 — 캠페인 산출물 보존" :: governance [required d=2026-05-16 active]
  rule = "RFC 040→043 campaign 의 모든 산출물은 §X 에 정확한 branch·SHA·path·RFC# 로 참조-기록. 이동(move)은 flame 에 진짜 속하고 타처 load-bearing 아닌 것만; 그 외 전부 참조(reference) — 중복 금지(drift-avoidance g3)."
  biggest_risk = "RESOLVED 2026-05-16 (Phase 0 진단 — g3 실측). '5 scattered branches' = 부정확 프레이밍. 실측: 5개 캠페인 브랜치 tip + §X 9개 load-bearing SHA 전부가 rfc043-hexa-torch (a8bc5e08) 의 strict 선형 ancestor (divergent tail = 0); origin/rfc043-hexa-torch == 로컬 바이트동일 (push 완료, 5 브랜치 모두 origin 독립 push 이중망). orphan-loss 위험 실재 안 함."
  residual = "잔여 = main-divergence (only). 로컬 main 1f1c3403 stale (origin/main 대비 0 ahead / 22 behind = 타 세션 interp-retirement R1/R2/R3 + F6-A in-flight). rfc043 는 origin/main 의 FF 아님 → 메인라인 통합은 merge 필요. 이는 후순위 분리작업이며 Phase 1 blocker 아님 (interp-retirement R3 안정화 후 화해)."
  phase0_acceptance = "MET — 모든 campaign artifact §X 에서 해석가능 + 검증완료(origin==local); 미통합 load-bearing orphan 브랜치 없음. Phase 1 = rfc043-hexa-torch 에서 진행."
  cross_repo = "anima evidence/arch/oracle = anima 잔류, §X 참조만 (cross-repo, 복제 X)"
  @> PLAN.md

@D g_flame_api_fixed := "API 고정, 구현 성숙으로 단계화" :: governance [required d=2026-05-16 active]
  rule = "API 표면 RFC 043 에서 1회 설계·고정. 'PyTorch-parity → exceed' = 같은 API 의 구현 성숙 (PyTorch eager→Inductor 패턴), 파일/API 분기 아님."
  @> PLAN.md

@D g_flame_phase1_falsifiers := "Phase 1 falsifier 사전등록 (구현 전 고정)" :: governance [required d=2026-05-16 active]
  scope = "Phase 1 = tensor_lib.hexa (RFC 040 device-farr residence) + autograd_lib.hexa (RFC 034 tape generalized)"
  F_RFC043_BUILD = "`hexa build` 가 flame stdlib (lib-split) 의 native 바이너리를 0 clang redefinition 으로 산출; 어떤 stdlib op 에서도 hexa_interp dispatch 도달 불가 (compiler-only 를 구조적으로 검증, 가정 아님)"
  F_RFC043_AG_EQ = "일반화된 autograd tape 가 RFC 034 의 landed exact 결과를 RFC 034 자신의 reference 에 재현 (closed B-D-4 CE-softmax Jacobian max|grad−(softmax−onehot)| = 0.0); 전체 layer-set tape 는 central-difference GRAD-EXACT PASS ([@x_oracle_cpu_bitequal] GRAD-EXACT 가 reference). AOT 경로가 exact-grad correctness 를 깨면 FAIL"
  F_RFC043_AG_TRAJ_ORACLE = "20-step (X[B·D]·W[D·C] → CE → backward → AdamW) 의 loss trajectory 가 RFC 034 oracle (loss[0]=1.64219, loss[19]=0.228332) 와 일치 — printed-precision floor 1e-4. matmul wrapper 의 arg ordering 까지 검증하는 oracle-비교 (구조-검증 self-determinism 만으로 우회 불가). g3 honesty 결과 추가."
  rule = "세 falsifier 는 compiled-native 경로(`hexa build`, no interp/py)에서만 PASS 인정. F-RFC043-AG-EQ + F-RFC043-AG-TRAJ-ORACLE 는 connection-point closed check — 구조검증('tape 가 돌았다')로 대체 불가 (g_blue_closed_mandate). 가짜 target 금지 — reference 는 §X verified oracle."
  authority = "RFC 043 §Verification + anima g_blue_closed_mandate · g3 · f1/f2"
  @> PLAN.md

@D g_flame_phase2a_falsifiers := "Phase 2-A falsifier 사전등록 (Linear + RMSNorm)" :: governance [required d=2026-05-16 active]
  scope = "Phase 2-A = nn_lib.hexa Linear + RMSNorm (fwd+bwd, closed-form analytic vjp). Phase 2-B (RoPE / GQA-attn / SwiGLU / embed / tied-head) = 별도 cycle."
  F_RFC043_LAYER_EQ_LINEAR_FWD = "nn_linear_fwd 가 closed-form reference (ikj order, bias broadcast) 에 1e-12 absolute (RFC 040 §2.2 measured fp-tol; FMA-vs-hexa-scalar last-ulp gap honest carve-out). 가짜 byte-eq 주장 금지 — fp-non-assoc 은 documented limit."
  F_RFC043_LAYER_EQ_LINEAR_BWD = "nn_linear_bwd {dW, dx, db} ≡ closed analytic vjp (dW=xᵀ·dy, dx=dy·Wᵀ, db=sum_rows(dy)) byte-equal (양쪽 hexa loop = 동일 fp 환경)."
  F_RFC043_LAYER_EQ_RMSNORM_FWD = "nn_rmsnorm_fwd {y, xn, inv} ≡ c3_rmsnorm_fwd algebra byte-equal (g_i·x_i/sqrt(mean(x²)+ε))."
  F_RFC043_LAYER_EQ_RMSNORM_BWD = "nn_rmsnorm_bwd {dx, dg} ≡ c3_rmsnorm_bwd closed vjp byte-equal (dxn=dy·g, dg=dy·xn, dot=Σ(dxn·x), dx=inv·dxn − scale·x)."
  rule = "fwd cross-impl 비교는 fp-tol; pure-scalar bwd 는 byte-eq. 양쪽 모두 closed-form analytic anchor (g3 real-limit = closed Jacobian + bit-exact reference equivalence). 가짜 reference 금지 — c3_*/c3_rmsnorm_* 은 anima d_train3_lib.hexa 의 검증된 boxed reference (cross-repo)."
  authority = "RFC 043 §Verification + RFC 040 §2.2 fp-tol + g_blue_closed_mandate"
  @> PLAN.md

# ─── §X External citations — PRESERVATION INDEX (참조-보존) ──────────
# SHAs as-reported by the Phase D/E/E2/RFC bg agents this session
# (honest: branch+description authoritative if a SHA drifted).

@X x_rfc043 := "RFC 043 — flame design SSOT" :: rfc [d=2026-05-16 active]
  path = "hexa-lang inbox/rfc_drafts_2026_05_12/rfc_043_hexa_torch_compiler_only_nn_stdlib.md"
  branch = "rfc043-hexa-torch" ; sha = "4dcaf80f"
  consolidates = "042 SUBSUMED · 041 kernel-backend · 040 tensor-backend · 034 autograd-foundation"

@X x_rfc_chain := "backing RFCs 040/041/042/034" :: rfc [d=2026-05-16 active]
  rfc_040 = "farr GPU/CUDA backend (device-farr + cuBLAS) — inbox/, branch rfc/farr-gpu-cuda-backend (design 95c208f6)"
  rfc_041 = "Phase B/B2 real CUDA kernels — branch rfc041-042-upstream-needs dae35fee (currently only farr_matmul_gpu has a real kernel; rest TODO[cuda] -1 stubs)"
  rfc_042 = "AOT-native trainer — SUBSUMED by 043 (rfc041-042-upstream-needs dae35fee)"
  rfc_034 = "farr reverse-mode autograd — LANDED (matmul→CE tape; flame generalizes it)"

@X x_branch_phaseAB := "Phase A/B scaffolding" :: code [d=2026-05-16 active]
  branch = "rfc/farr-gpu-cuda-backend"
  phaseA = "5ae8823f — HexaFarrEntry device-farr ext + farr_matmul_gpu dispatcher + tmp_rfc040_smoke 5/5"
  phaseB = "c0122caa — farr_softmax_rows/rmsnorm_rows/add/scale _gpu + tmp_rfc040_phaseB_smoke 6/6"

@X x_branch_cublas := "real cuBLAS Dgemm + interp fix" :: code [d=2026-05-16 active]
  branch = "phase-d-cublas-h100"
  runtime_cuda = "180263d3 self/cuda/runtime_cuda.c (cuBLAS Dgemm impl)"
  real_wire = "903c0285 — TODO stub→real _hx_cuda_* + _hx_farr_table/_count export link-fix + main.hexa HEXA_CUDA gate + GPU smoke"
  interp_fix = "54d56e4a — 7 Phase A builtins added to hexa_full.hexa::call_builtin (compiled-only→interp parity)"

@X x_branch_phaseB2 := "Phase B2 — 7 backward farr ops" :: code [d=2026-05-16 active]
  branch = "rfc040-phaseB2-complete" ; sha = "017b988f"
  ops = "farr_matmul_t/outer/mul/silu/silu_grad/rmsnorm_bwd/adamw _gpu — #ifdef HEXA_CUDA TODO[cuda] stub + CPU helper; 11-builtin interp backfill"
  verified = "tmp_rfc040_phaseB2_smoke.hexa 9/9 vs boxed c3_*/dt2_* reference"

@X x_anima_phaseE := "anima Phase E — d_train5 fwd GPU-routed" :: evidence [d=2026-05-16 active]
  repo = "dancinlab/anima main" ; sha = "6335f1602"
  what = "d5_proj_batch_g + 8 GEMM routed via farr_matmul_gpu; CPU bit-equal; in-loop cuBLAS power/mem signature (H200)"
  doc = "docs/anima_rfc040_phase_e_d_train5_gpu_routed_2026_05_16.md"

@X x_anima_phaseE2 := "anima Phase E2 — backward GPU-routed + fat-host" :: evidence [d=2026-05-16 active]
  repo = "dancinlab/anima main" ; sha = "6c0fbe08f"
  what = "d5_outer_g/matvec_t_g/swiglu_bwd_g + 8 bwd sites via farr_matmul_gpu reshapes; CPU bit-equal; GRAD-EXACT PASS on real A100; d=768·12L init reached (fat host 251GB/128vCPU)"
  finding = "B2 ops are TODO[cuda] -1 stubs (NOT real kernels) — routed bwd through the ONE real cuBLAS kernel via GEMM reshapes"
  doc = "docs/anima_rfc040_phase_e2_backward_fathost_2026_05_16.md + state/hexad_gpu_fire_phaseE2_2026_05_16/result.json"

@X x_anima_pytorch_d768 := "anima .py d=768·12L fire (interim track)" :: evidence [d=2026-05-16 active]
  repo = "dancinlab/anima main" ; sha = "931dd68b0"
  result = "ConsciousDecoderV2 d=768·12L 283.72M params; init CE 5.590832 → final 0.000708 (descent 5.590124); 2500 step; wall 336.85s; DONE rc=0"
  honest = "Python substrate (NOT hexa-native) · hexa-arch mirror · hexa CPU-equiv anchored · ckpt-LOST evidence-only (fire.log durable) · 152KB corpus ⟹ memorization NOT LM-quality"
  path = "state/anima_pytorch_d768x12L_fire_2026_05_16/fire.log"

@X x_anima_campaign_misc := "Phase D / A100 / runpod evidence" :: evidence [d=2026-05-16 active]
  phaseD = "anima 27e96e348 (runtime_cuda.c + Phase D evidence) + e8f6c13d8 (integrated -DHEXA_CUDA build + GPU smoke 5/5)"
  a100 = "anima 4d8fd45ba (A100 retry honest — cuBLAS build proven, d=384 substrate wall)"
  runpod = "anima e7085187e (runpod A100 — 4th cuBLAS verify 13.5 TFLOPS + dep-upload bug found/fixed; earlier 'd=256 limit' RETRACTED as dep bug)"
  state_dirs = "anima state/hexad_gpu_fire_{2026_05_16,a100_,runpod_,phaseE_,phaseE2_}/ + docs/anima_rfc040_phase_d_h100_cublas_2026_05_16.md"

@X x_oracle_cpu_bitequal := "VERIFIED ORACLE — CPU bit-equal trainer" :: oracle [d=2026-05-16 active]
  fact = "d=32·3L ×8win ×80 AdamW seed=42: gn2 7.97116 → 3.73374e-07, acc 0/8→8/8, GRAD-EXACT PASS"
  proves = "refactored hexa ConsciousDecoderV2 trainer numerically correct (Phase E/E2 ≡ boxed baseline). flame F-RFC043-STEP-EQ MUST hit this."

@X x_oracle_cublas := "VERIFIED ORACLE — cuBLAS ≡ CPU" :: oracle [d=2026-05-16 active]
  fact = "cuBLAS Dgemm vs CPU: max|Δ|=4.44e-15 (<1e-9); reduction-heavy measured TOL_MATMUL ≈ 2e-9 (RFC 040 fp-non-assoc honest caveat)"
  perf = "51.24 TFLOPS FP64 H100 (76% peak) · 13,526 GF/s A100 · 4× independent verify (2 H100 + 2 A100)"

@X x_oracle_phaseB2 := "VERIFIED ORACLE — Phase B2 ops vs boxed" :: oracle [d=2026-05-16 active]
  fact = "tmp_rfc040_phaseB2_smoke.hexa 9/9 — matmul_t/outer/mul/silu/silu_grad/rmsnorm_bwd/adamw _gpu (no-CUDA path) ≡ c3_*/dt2_* boxed reference"

@X x_anima_arch := "verified architecture source" :: ref [active]
  hexad = "dancinlab/anima HEXAD/ — ConsciousDecoderV2 7-module, 🔵 SUPPORTED-FORMAL; py anchor ready/models/conscious_decoder.py"
  dual_track = "anima HEXAD/PLAN.md §9 (e57da2c83 / 5fa77b60d) — .py interim ⇄ hexa-native, RFC 041/042/043 upstream"

# ─── §N Notes ────────────────────────────────────────────────────────

@N n_no_exec := "no execution until approved" :: note [d=2026-05-16 active]
  text = "flame = DESIGN/SCAFFOLD only. Implementation gated on RFC 043 review + PLAN Phase 0 (branch consolidation) + explicit user go. Nothing here builds; build_verify unaffected."

@N n_preservation := "물거품 방지 요지" :: note [d=2026-05-16 active]
  text = "사용자 directive 2026-05-16 '지금까지 작업한 것들 물거품 되면 안되니까 옮길 것 옮기고 참조로 해야되면 참조로 기록'. → §X 가 그 보존 인덱스. 단일 최대 risk = 5 hexa-lang branch 미통합 → PLAN Phase 0. 복제 아닌 참조 (g3 drift-avoidance)."

## Log

### 2026-05-16 — FLAME.tape created (scaffold, design-only)
flame/ 스캐폴드 (README + PLAN + FLAME.tape). RFC 043 filed `4dcaf80f`.
§X = RFC 040→043 campaign 전 산출물 참조-보존 인덱스 (branch·SHA·path·
RFC# + verified oracles). g_flame_preservation: 물거품 방지 = §X 참조 +
PLAN Phase 0 branch 통합. 구현 0 — 사용자 검토·go 대기.

### 2026-05-16 — Phase 0 CLEARED (preservation 실측 검증, g3)
git 실측: rfc043-hexa-torch (a8bc5e08) 가 5개 캠페인 브랜치 tip + §X
9개 load-bearing SHA 전부의 strict 선형 ancestor (divergent tail 0).
origin/rfc043-hexa-torch == 로컬 바이트동일 (push 완료). → 'orphan-branch
loss' 위험 실재 안 함; Phase 0 acceptance 이미 충족. '5 scattered
branches merge/rebase' 프레이밍은 부정확 → 정정. 잔여 = main-divergence
(타 세션 interp-retirement in-flight) = 후순위 분리작업, Phase 1 blocker
아님. 사용자 결정: option A (현상유지 + SSOT 정정 + Phase 1 착수).

### 2026-05-16 — Phase 1 START (tensor_lib + autograd_lib)
falsifier 사전등록: g_flame_phase1_falsifiers (F-RFC043-BUILD,
F-RFC043-AG-EQ). 구현은 rfc043-hexa-torch 에서 진행 (full substrate
lineage 보유: RFC 040 device-farr + RFC 034 autograd tape).

### 2026-05-16 — Phase 1 INITIAL (3/3 PASS, but matmul-arg bug masked)
초기 빌드: F-RFC043-BUILD / F-RFC043-AG-EQ / F-RFC043-DETERMINISM
PASS — 그러나 g3 honesty: Phase 2-A 진단 중 `ag_matmul` 의 wrapper
arg ordering 이 underlying `ad_matmul`/`farr_matmul` (runtime: a, M, K,
b, N) 과 어긋남을 발견. F-RFC043-AG-EQ (B-D-4 closed CE Jacobian) 은
matmul 비사용 — 진짜 PASS. F-RFC043-DETERMINISM 은 self-consistent
(같은 wrong-args 두 번) — 구조적 PASS, oracle 불일치는 미검출. 다음
entry 에서 fix + actual oracle-trajectory check 추가.

### 2026-05-16 — Phase 1 PASS (4/4 + regression 0, compiled-native)
FIX: ag_matmul / t_matmul / nn_linear_fwd 의 farr_matmul args를 runtime
ordering (a, M, K, b, N) 으로 정렬 + flame.hexa 의 호출자 `ag_matmul(X,
W, B, D, C)` → `ag_matmul(X, B, D, W, C)`. F-RFC043-AG-TRAJ-ORACLE
추가 — RFC 034 oracle (loss[0]≈1.64219, loss[19]≈0.228332) 와 직접 비교.

selftest 결과 (`build/flame_phase1`, Mac no-CUDA):
- F-RFC043-BUILD          PASS (clang redef 0; `grep call_builtin
  flame_phase1.c` = 0; `hexa_ad_*`/`hexa_farr_*` direct C-calls =
  structural compiler-only 검증, 가정 아님)
- F-RFC043-AG-EQ          PASS (max|ag_grad − (softmax − onehot)|
  = 0.0 < 1e-9 — anima B-D-4 closed Jacobian bit-equal ·
  connection-point closed (g_blue_closed_mandate met))
- F-RFC043-DETERMINISM    PASS (seed=42 trajectory 두 run byte-id)
- F-RFC043-AG-TRAJ-ORACLE PASS (20-step loss trajectory: loss[0]≈
  1.64219, loss[19]≈0.228332 within printed-precision floor 1e-4;
  RFC 034 oracle 와 bit-equal numerics — connection-point 실측 검증)
- F-RFC043-MODULE-REGRESSION-0 PASS (RFC 034 5/5 + RFC 040 B2 9/9
  re-build 후 동일 PASS, 동일 numerics)
Phase 2 gate 충족. API 표면 RFC 043 에서 고정(`g_flame_api_fixed`).

### 2026-05-16 — Phase 2-A LANDED (Linear + RMSNorm, 4/4 PASS + regression 0)
landed: `stdlib/flame/{nn_lib.hexa, flame_nn_test.hexa}`. Phase 2-A =
가장 단순한 두 layer (closed-form analytic vjp). Phase 2-B (RoPE /
GQA-attn / SwiGLU / embedding / tied-LM-head) = 별도 cycle.

selftest 결과 (`build/flame_phase2a`, Mac no-CUDA):
- F-RFC043-LAYER-EQ-LINEAR-FWD   PASS — max|Δ| < 1e-12 (RFC 040 §2.2
  measured fp-tol; FMA-vs-hexa-scalar last-ulp gap honest carve-out;
  ikj-order reduction matched between wrapper와 ref)
- F-RFC043-LAYER-EQ-LINEAR-BWD   PASS — {dW, dx, db} byte-eq vs
  closed vjp (dW=xᵀ·dy, dx=dy·Wᵀ, db=sum_rows(dy))
- F-RFC043-LAYER-EQ-RMSNORM-FWD  PASS — {y, xn, inv} byte-eq vs
  c3_rmsnorm_fwd algebra (anima d_train3_lib.hexa)
- F-RFC043-LAYER-EQ-RMSNORM-BWD  PASS — {dx, dg} byte-eq vs
  c3_rmsnorm_bwd closed vjp
- regression: RFC 034 5/5 · RFC 040 B2 9/9 · flame Phase 1 4/4
  모두 동일 PASS 동일 numerics. structural: nn_lib emitted C
  `call_builtin` = 0 (compiler-only 유지).
honest carve-out: layer-level autograd-tape integration (ad_* 가
새 op 를 record 하도록) 은 Phase 3 (train_step) — 현재 layer 들은
functional bwd (c3_* / d5_block_bwd 패턴).

### 2026-05-16 — Phase 2 +2 layers (Embedding + Tied LM Head, 8/8 PASS)
nn_lib 확장: `nn_embedding_fwd` / `nn_embedding_bwd_scatter` /
`nn_lm_head_fwd` / `nn_lm_head_bwd`. functional 형식 (caller-allocated
out farrs). 정직 캐브-아웃: tied-weight 의 dtemb 경로 두 항 (head
outer-product term + embedding scatter-add term) 은 호출자가 두
함수 호출로 조합 (d5_grad 패턴; flame Phase 3 train_step 에서 묶임).

falsifiers (`build/flame_phase2`):
- F-RFC043-LAYER-EQ-EMBED-FWD       PASS — row copy byte-eq
- F-RFC043-LAYER-EQ-EMBED-SCATTER   PASS — scatter-add 누적 byte-eq
- F-RFC043-LAYER-EQ-LMHEAD-FWD      PASS — |Δ|<1e-12 (RFC 040 fp-tol;
  V·d matvec via farr_matmul)
- F-RFC043-LAYER-EQ-LMHEAD-BWD      PASS — dl⊗zT + tembᵀ·dl byte-eq
- regression: RFC 034 5/5 · RFC 040 B2 9/9 · flame Phase 1 4/4 +
  Phase 2-A 4/4 모두 유지. structural call_builtin = 0.

남은 Phase 2 layer: RoPE / SwiGLU / GQA-attn (큰 순서대로).

### 2026-05-16 — Phase 2 +RoPE +SwiGLU (6/7 layers, 14/14 PASS, regression 0)
nn_lib 확장:
- `nn_rope_build_tables` / `nn_rope_apply_fwd` / `nn_rope_apply_bwd`
  (RoFormer convention; cos/sin tables, q' = q⊙cos + rh(q)⊙sin;
  bwd = orthogonal Rᵀ=R(−θ) closed)
- `nn_swiglu_fwd` / `nn_swiglu_bwd` (c3_swiglu_* algebra:
  a=Wg·r, b=Wu·r, s=silu(a)·b, o=Wd·s + closed bwd composition)
- private helpers _nn_sigmoid / _nn_silu / _nn_silu_grad

falsifiers (`build/flame_phase2`, 14/14 PASS):
- F-RFC043-LAYER-EQ-ROPE-TABLES   PASS (byte-eq cos/sin per-position)
- F-RFC043-LAYER-EQ-ROPE-FWD      PASS (byte-eq · q⊙cos + rh(q)⊙sin)
- F-RFC043-LAYER-EQ-ROPE-BWD      PASS (byte-eq · 직교 vjp)
- F-RFC043-LAYER-EQ-ROPE-ORTHO    PASS (max|fwd∘bwd(q')−q| = 1.11e-16
  ≈ machine eps; **Rᵀ·R = I closed orthogonality identity** = g3
  real-math/physics anchor)
- F-RFC043-LAYER-EQ-SWIGLU-FWD    PASS (|Δ|<1e-12 RFC 040 fp-tol;
  2 matvec + silu + Hadamard + matvec)
- F-RFC043-LAYER-EQ-SWIGLU-BWD    PASS (byte-eq · c3_swiglu_bwd vjp,
  isolated by feeding identical saved-fwd state to both bwd 호출)
- regression: RFC 034 5/5 · RFC 040 B2 9/9 · flame Phase 1 4/4 +
  Phase 2 (4 layer) 8/8 모두 동일 PASS. structural call_builtin = 0.

남은 Phase 2 = GQA-attention 1개 (가장 큰 layer — multi-head + GQA
n_rep grouping + causal mask + scaled-dot softmax; d5_attn_fwd
~85 lines + d5_attn_bwd ~150 lines). next cycle 의 집중 작업.

### 2026-05-16 — Phase 2 COMPLETE (7/7 layers, 17/17 PASS, regression 0)
nn_lib 확장: `nn_attn_core_fwd` / `nn_attn_core_bwd` (+ private
`_nn_softmax_row`). 디자인 결정: GQA-attention 의 **attention-core**
(scaled-dot · causal-mask · row-softmax · weighted sum + reverse)
만 본 라이브에 두고, Q/K/V/output projection 은 호출자가 이미 검증된
`nn_linear_fwd` 로 composes, RoPE 는 `nn_rope_apply_*` 로 composes
(d5_attn_fwd 의 코드 구조 그대로 — projections + per-head split +
attention math + output proj). 코드량 절감 + 각 piece 의 byte-eq
독립 검증 유지.

falsifiers (`build/flame_phase2`, 17/17 PASS):
- F-RFC043-LAYER-EQ-ATTN-FWD     PASS  byte-eq · GQA causal scaled-dot
  · row-softmax · weighted sum
- F-RFC043-LAYER-EQ-ATTN-CAUSAL  PASS  max|P[hh,i,j>i]|=0.0 — **closed
  math invariant** (no attending to future); g3 real-limit anchor
- F-RFC043-LAYER-EQ-ATTN-BWD     PASS  byte-eq · d5_attn_bwd 의 attn-core
  closed vjp (GQA accumulation across n_rep heads 검증)
- regression: RFC 034 5/5 · RFC 040 B2 9/9 · flame Phase 1 4/4 ·
  Phase 2 (6 layer) 14/14 모두 동일 PASS. structural call_builtin = 0.

flame Phase 2 = COMPLETE. ConsciousDecoderV2 의 7 building block 전체
(Linear · RMSNorm · Embedding · LMHead · RoPE · SwiGLU · Attention-core)
가 closed-form analytic vjp 와 byte-equal (또는 RFC 040 fp-tol)
compiled-native. ~2.8k LoC stdlib/flame/ landed.

Phase 3 gate (optim_lib + train_lib · F-RFC043-STEP-EQ) 충족:

### 2026-05-17 — Phase 3-A LANDED (optim_lib, 1/1 PASS)
landed: `stdlib/flame/{optim_lib.hexa, flame_optim_test.hexa}`. AdamW
thin wrapper — RFC 034 `adamw_step` builtin 위 namespace 명시 (opt_*
는 reverse-pass 가 끝난 후 caller-driven optimizer step; ag_* 는
autograd-tape composed). 동일 numerics, 다른 호출 의도.
- F-RFC043-OPTIM-EQ PASS — opt_adamw_step vs ag_adamw_step 10-step
  trajectory byte-eq (max|{W, m, v}| = 0.0 — same builtin, transitively
  RFC 034 5/5 oracle byte-eq trajectory 상속).
- regression: 모든 prior PASS 유지.
Phase 3-B = decoder_block composition (nn_* primitives 의 fwd/bwd
composition; d5_block_fwd/bwd 등가, 한 layer).
- optim_lib = RFC 034 의 adamw_step 위의 wrapper (이미 ag_adamw_step
  으로 검증됨; named wrapper 만 추가)
- train_lib = compiled train_step (fwd + CE + bwd + AdamW 의 묶음)
- F-RFC043-STEP-EQ = 전체 step 이 캠페인 CPU-equiv 오라클의 d=32·3L
  ×8win ×80-AdamW seed=42 7.97116 → 3.73374e-07 trajectory 와 byte-eq
  (g_blue_closed_mandate 의 mandatory connection-point closed check).
