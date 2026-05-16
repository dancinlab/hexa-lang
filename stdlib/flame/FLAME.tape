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
  status = "DESIGN + SCAFFOLD 2026-05-16 — implementation NOT started, gated on RFC 043 review + PLAN Phase 0"
  parent_rfc = "RFC 043 (inbox/rfc_drafts_2026_05_12/rfc_043_hexa_torch_compiler_only_nn_stdlib.md)"
  structure = "fat native stdlib + thin hexa orchestration ⟹ no heavy interpreted driver loop (RFC 042 ceiling closed structurally)"

# ─── §2 Layout (planned lib-split — compiled-first, NOT one file) ─────

@L flame_layout := "flame package layout" :: structure [d=2026-05-16 active]
  README.md -> "overview + foundation pointer"
  PLAN.md -> "staged roadmap; Phase 0 = 보존/통합 (물거품 방지)"
  FLAME.tape -> "this — SSOT + §X preservation index"
  flame.hexa -> "[planned] entrypoint (import *_lib + selftest)"
  tensor_lib.hexa -> "[planned] Tensor — device-farr (RFC 040)"
  autograd_lib.hexa -> "[planned] reverse-mode tape (RFC 034 generalized)"
  nn_lib.hexa -> "[planned] Linear/RMSNorm/RoPE/GQA-attn/SwiGLU/embed/tied-head"
  optim_lib.hexa -> "[planned] AdamW (RFC 040 B2)"
  train_lib.hexa -> "[planned] compiled train_step + CE loss"
  note = "[planned] = NOT created. lib-split mandatory (compiled: main/_selftest 동거 시 C 심볼 중복)."

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
  biggest_risk = "5 scattered hexa-lang branches (실 cuBLAS impl + 11 farr ops + interp fix) → PLAN Phase 0 branch consolidation 으로 해소 (orphan-branch loss 방지)"
  cross_repo = "anima evidence/arch/oracle = anima 잔류, §X 참조만 (cross-repo, 복제 X)"
  @> PLAN.md

@D g_flame_api_fixed := "API 고정, 구현 성숙으로 단계화" :: governance [required d=2026-05-16 active]
  rule = "API 표면 RFC 043 에서 1회 설계·고정. 'PyTorch-parity → exceed' = 같은 API 의 구현 성숙 (PyTorch eager→Inductor 패턴), 파일/API 분기 아님."
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
