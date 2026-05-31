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
  parent_rfc = "RFC 043 (docs/rfc/rfc_drafts_2026_05_12/rfc_043_hexa_torch_compiler_only_nn_stdlib.md)"
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
  decoder_block_lib.hexa -> "[Phase 3-B LANDED 2026-05-17] one decoder block fwd+bwd (pre-norm; RMSNorm+attn+residual+RMSNorm+SwiGLU+residual); packed Bp/Bc layout helpers; GRAD-EXACT 9-probe central-diff 2/2 PASS @ max rel = 3.59e-10"
  flame_block_test.hexa -> "[LANDED 2026-05-17 Phase 3-B] selftest (F-RFC043-BLOCK-DET · F-RFC043-BLOCK-GRAD-EXACT)"
  decoder_lib.hexa -> "[Phase 3-C LANDED 2026-05-17] full ConsciousDecoderV2 composition (embedding · n_layer block stack · final RMSNorm · tied LM head · CE/gn2/predict helpers); GRAD-EXACT 10-probe 2/2 PASS @ max rel = 2.66e-08"
  flame_decoder_test.hexa -> "[LANDED 2026-05-17 Phase 3-C] selftest (F-RFC043-DECODER-DET · F-RFC043-DECODER-GRAD-EXACT — campaign F-D-PORT-5b 등가)"
  train_lib.hexa -> "[Phase 3-D LANDED 2026-05-17] compiled train_step + 80-step trajectory + nn_decoder_init (seed-fixed LCG); F-RFC043-TRAIN-{DET,DESCENT,FIT} 3/3 PASS — gn2 collapse 3.5e18× (toy d=8·2L)"
  flame_train_test.hexa -> "[LANDED 2026-05-17 Phase 3-D] 80-step trainer selftest entrypoint"
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
  path = "hexa-lang docs/rfc/rfc_drafts_2026_05_12/rfc_043_hexa_torch_compiler_only_nn_stdlib.md"
  branch = "rfc043-hexa-torch" ; sha = "4dcaf80f"
  consolidates = "042 SUBSUMED · 041 kernel-backend · 040 tensor-backend · 034 autograd-foundation"

@X x_rfc045 := "RFC 045 — flame Phase 3 algorithmic byte-eq with anima oracle (CLOSURE)" :: rfc [d=2026-05-17 active]
  path = "hexa-lang docs/rfc/rfc_drafts_2026_05_12/rfc_045_flame_phase3_algorithmic_byte_eq_with_anima_oracle.md"
  branch = "rfc043-hexa-torch" ; sha = "(TBD on commit)"
  closes = "F-RFC043-STEP-EQ at algorithm-byte-eq tier · 40 falsifier PASS · regression 0 · structural call_builtin = 0"
  evidence = "21-commit chain Phase 3-A..3-J · gn2[0]=7.97113 vs anima 7.97116 |Δ|=3.12e-5 · final 8.87e-7 vs 3.73e-7 (2.4× drift; same shape) · acc 8/8 = anima 8/8 · init weight byte-id max|Δ|=0.0 · source #4 (dict vs packed-farr impl-level) CONFIRMED by direct anima same-toolchain execution"
  rename_note = "Originally drafted as RFC 044 (commit 829e5076), renamed to RFC 045 to yield 044 to the parallel-session forge regime work (RFC 040/041 lineage continuation has stronger numerical-position claim)."

@X x_rfc048 := "RFC 048 — flame Phase 4-C: fwd+bwd graph fusion at compile time" :: rfc [d=2026-05-17 draft]
  path = "hexa-lang docs/rfc/rfc_drafts_2026_05_12/rfc_048_flame_phase4c_fwd_bwd_graph_fusion.md"
  branch = "rfc043-hexa-torch" ; sha = "(TBD on commit)"
  scope = "Stage 3 from RFC 046 (HIGHEST IMPACT — bwd is 75% of per-step wall per PERF.md 5-run). IR pass detects nn_decoder_block_fwd/bwd pairs and emits single specialized fused C function per (T,d,nh,nkv,h) tuple with register-resident block cache."
  builds_on = "RFC 047 (Phase 4-B IR pass is the prerequisite Stage 2 specialization); extends it with fwd/bwd pairing detection + rewrite"
  asserts = "F-RFC048-FUSED-WALL-IMPROVED: ≥2× over Phase 4-B baseline (4.5s → 2.5s on M-Mac CPU d=32·3L 80-step); combined Phase 4 (B+C) = ≥5× over Phase 3-J; F-RFC048-EAGER-PYTORCH-MATCH = ≤1.3× of eager-PyTorch 336.85s on A100 d=768·12L"
  mechanism = "block cache (Bc ~8K floats × 3 layers × 80 steps × 8 windows = ~30M cache transfers) becomes register-resident inside the fused kernel; clang -O2 register allocation across the entire fwd+bwd dataflow eliminates ~50-70% per-step DRAM traffic"
  staged = "Phase 4-C-1 pairing detection (~1 cycle) → 4-C-2 single-layer fused emit (~2 cycles, ~2-3× over Phase 4-B) → 4-C-3 multi-layer decoder_lib rewrite (~2 cycles, full 5× combined) → 4-C-4 d=768·12L specialization + GPU dispatch (~1 fire cycle, ~\$5-20)"
  preserves = "flame public API (g_flame_api_fixed); Phase 3 numerics byte-id (F-RFC048-STEP-EQ preserves flame ↔ anima 3.12e-5 delta exactly)"

@X x_rfc047 := "RFC 047 — flame Phase 4-B: per-block IR pass for compile-time block fusion" :: rfc [d=2026-05-17 draft]
  path = "hexa-lang docs/rfc/rfc_drafts_2026_05_12/rfc_047_flame_phase4b_block_fusion_ir_pass.md"
  branch = "rfc043-hexa-torch" ; sha = "(TBD on commit)"
  scope = "Stage 2 from RFC 046 — per-block specialized C kernel emit via IR pass at `hexa build` time; static-shape specialization on (T, d, nh, nkv, h)"
  preserves = "flame public API (g_flame_api_fixed); Phase 3 numerics byte-id (F-RFC047-STEP-EQ preserves flame ↔ anima 3.12e-5 delta exactly)"
  asserts = "F-RFC047-BLOCK-WALL-IMPROVED: ≥3× wall reduction over Phase 3-J + 4-A-bwd baseline (13.33s → ≤4.5s on M-Mac CPU d=32·3L 80-step), minimum ≥2× for shippable"
  staged = "Phase 4-B-1 pass scaffold + pattern match (~1 cycle) → 4-B-2 fwd emission (~1-2 cycles, ~2× wall) → 4-B-3 bwd emission (~1-2 cycles, ~5× wall combined) → 4-B-4 d=768·12L specialization + GPU prep (~1 cycle)"
  granularity_floor_response = "Phase 4-B's within-block fusion is the right answer to the ~32K-ops granularity floor — small reductions (drin, attention_core_bwd P·dY) become inline code in the specialized C function rather than separate farr_matmul calls"

@X x_rfc046 := "RFC 046 — flame Phase 4: compiler fusion for eager-PyTorch end-to-end throughput match" :: rfc [d=2026-05-17 draft]
  path = "hexa-lang docs/rfc/rfc_drafts_2026_05_12/rfc_046_flame_phase4_compiler_fusion.md"
  branch = "rfc043-hexa-torch" ; sha = "(TBD on commit)"
  asserts = "f-RFC046-EAGER-PYTORCH-MATCH: flame d=768·12L wall ≤1.3× eager-PyTorch 336.85s on A100 after Stage 3 fwd+bwd graph fusion"
  staged = "Stage 1 (epilogue fusion, ~2×, 1 cycle) → Stage 2 (block fusion, ~5×, 2 cycles) → Stage 3 (fwd+bwd graph fusion, ~10×, 2-3 cycles) → Stage 4 (GPU dispatch + eager-PyTorch comparison, ~$5-20)"
  preserves = "Phase 3 numerics byte-id (F-RFC046-STEP-EQ regression preserves 3.12e-5 flame ↔ anima delta exactly); flame public API (g_flame_api_fixed)"
  honesty = "asserts ≤1.3× threshold based on Phase 3 baseline 18.5s d=32·3L scaling math; if Phase 4-D measures >1.3× ratio, falsifier FAILS and design iterates (no fudge)"

@X x_rfc_chain := "backing RFCs 040/041/042/034" :: rfc [d=2026-05-16 active]
  rfc_040 = "farr GPU/CUDA backend (device-farr + cuBLAS) — docs/rfc/, branch rfc/farr-gpu-cuda-backend (design 95c208f6)"
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

@N n_clm_convmoe_port_gap := "CLM-ConvMoE flame port — 4 missing op families" :: note [d=2026-06-01 active]
  text = "anima CLM(CLMConvMoE) production trainer를 flame로 .hexa 작성하려면(anima a_train_flame_forge directive · P6_SCALE_LADDER_7B) flame에 4개 연산군 선행 필요. flame 현재 = attention 트랜스포머(rmsnorm·rope·attn_dt·silu_gate·tied-lmhead·CE·AdamW·ag_tape) — CLM은 Conv-MoE라 구조 상이."
  gap_conv1d = "causal-dilated Conv1d (trunk · embed_conv · ConvExpert · router · readout) fwd+bwd — flame 0 files (2026-06-01 grep). NEEDED."
  gap_groupnorm = "GroupNorm fwd+bwd — flame 0 files. NEEDED (CLM uses GroupNorm, not rmsnorm)."
  gap_moe_router = "sparse-MoE router (softmax + top-k expert combine) fwd+bwd — flame has PureField dual-expert only, no top-k routing. NEEDED."
  gap_int4_ste = "int4-sym[-7,+7] per-output-channel STE fake-quant (QAT envelope · AKIDA rejects -8) fwd+STE-bwd — flame 0 files. NEEDED."
  discipline = "each op = fwd+bwd + byte-equal/GRAD-EXACT oracle per flame Phase pattern (cf. nn_lib F-RFC043-LAYER-EQ). then assemble train_clm.hexa over forge GPU substrate · GPU-resident verify."
  scoped_by = "param formula P6 §1: mid d512/L8/E8=13.65M · large d768/L12/E12=44.68M (verified). measurement rung ⊥ deploy (a_scale_honest_scope)."
