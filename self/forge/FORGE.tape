#!/usr/bin/env tape
# ══════════════════════════════════════════════════════════════════════
# FORGE.tape — forge GPU compute substrate SSOT (tape v1.2).
# Grammar primer: see ~/core/tape/spec/tape.md. Entry form:
#   @<type> <id> := "<subj>" :: <kind> [<grades>]  + 2-space body lines.
# Types: @V spec @I identity @L layout @D governance/decision
#        @X external-citation @N note. Edges: <: specializes ~> supersedes
#        |> verified-by @> projects-to. Arch (latest-wins) head + append-
#        only `## Log` (v1.2 arch-vs-history split).
#
# forge = hexa-lang's GPU compute substrate (RFC 040 device-farr + cuBLAS
# + RFC 041 .cu kernels). flame stdlib calls forge through compiled
# builtin dispatch. forge = LABEL on existing self/runtime.c + self/cuda/
# code; this tape is the durable SSOT for that labeled layer.
# ══════════════════════════════════════════════════════════════════════

@V v1 := "tape" :: spec [active]
  version = "1.2"

# ─── §1 Identity ─────────────────────────────────────────────────────

@I forge_id := "forge" :: identity-claim [d=2026-05-16 active]
  kind = "GPU compute substrate (device-farr alloc/copy/free + cuBLAS Dgemm + .cu kernels)"
  brief = "C/CUDA runtime layer that flame stdlib calls through compiled builtin dispatch"
  analog = "flame:forge :: torch:ATen (forge writes C/CUDA; flame writes hexa)"
  status = "NAMING + SCAFFOLD 2026-05-16 — underlying code already landed across RFC 040 campaign; this directory is the SSOT label, not new code"
  lives_in = "self/runtime.c (cuBLAS bindings + hexa_farr_*_gpu dispatchers + hexa_cuda_* runtime) + self/cuda/ (.cu kernels)"
  parent_rfc = "RFC 040 (device-farr + cuBLAS) + RFC 041 (.cu kernels) + RFC 043 (flame consumer)"
  not_what = "NOT a hexa stdlib (those go in stdlib/) · NOT a separate repo (hexa-first) · NOT a GPU codegen backend (hexa-src→PTX is a hypothetical future RFC, out of forge scope)"

# ─── §2 Layout ───────────────────────────────────────────────────────

@L forge_layout := "forge package layout (label on existing code)" :: structure [d=2026-05-16 active]
  README.md -> "overview + position in stack + verified oracles"
  PLAN.md -> "staged roadmap; Phase 0 paired with flame Phase 0 (preservation MET)"
  FORGE.tape -> "this — SSOT + §X cross-link to flame's preservation index"
  hexa_cuda_runtime -> "self/runtime.c — hexa_cuda_alloc/copy/free/sync + hexa_farr_*_gpu dispatchers (already landed)"
  cublas_impl -> "self/cuda/runtime_cuda.c — cuBLAS Dgemm wiring (RFC 040 ✅ verified 4× 51 TFLOPS)"
  cuda_kernels -> "self/cuda/*.cu — planned real elementwise/reduce kernels (RFC 041, currently TODO[cuda] stubs except farr_matmul_gpu)"
  evidence_pin -> "self/cuda/PHASE_D_H100_EVIDENCE.md — original landing evidence"
  note = "forge does NOT physically relocate any code. self/runtime.c GPU portions + self/cuda/ stay where they are (avoid build/link path churn). forge = the documentation/SSOT label."

# ─── §3 Governance ───────────────────────────────────────────────────

@D g_forge_substrate_role := "substrate role mandate" :: governance [required d=2026-05-16 active]
  rule = "forge = C/CUDA runtime substrate that flame stdlib calls. forge MUST NOT contain hexa source (that's stdlib/). flame MUST NOT contain C/CUDA kernels (that's forge). Layer boundary enforced by directory."
  why = "torch:ATen 분리와 동일 — orchestration (hexa-src) ↔ kernel (C/CUDA) 가 같은 파일에 섞이면 컴파일러-only mandate 가 흔들리고 build 단순성이 깨짐"
  @> README.md

@D g_forge_verify_oracle := "kernel parity oracle 강제" :: governance [required d=2026-05-16 active]
  rule = "신규/수정 forge 커널 (cuBLAS 바인딩, .cu kernel) 은 CPU farr reference 와 byte-equal (또는 RFC 040 명시 TOL_OP/TOL_MATMUL) parity 통과 후 land. 구조검증('컴파일됐다', '실행됐다')만으로 land 금지."
  oracles = "[@x_oracle_cublas] (max|Δ|=4.44e-15) + [@x_oracle_phaseB2] (9/9 CPU-equiv) + per-op TOL spec in RFC 041"
  connection_point = "flame ↔ forge 경계 = 검증 connection-point. flame falsifier (F-RFC043-AG-EQ, F-RFC043-STEP-EQ) 의 GRAD-EXACT/STEP-EQ 가 forge 커널 호출을 거쳐 PASS 해야 함 — forge 가 oracle 깨면 flame 도 FAIL"
  authority = "anima AGENTS.tape §0 g_blue_closed_mandate · g3 · f1/f2"
  @> README.md

@D g_forge_perf_floor := "성능 floor + 금지" :: governance [required d=2026-05-16 active]
  floor = "raw dense GEMM = cuBLAS/NVIDIA roofline. forge MATCHES not beats. anchor = measured 51.24 TFLOPS FP64 H100 (76% peak)"
  win_above_floor = "(a) .cu kernels replacing TODO[cuda] stubs (RFC 041) · (b) memory-traffic minimisation (fused epilogues for flame to dispatch) · (c) static-shape specialisation at substrate boundary"
  forbidden = "NO n=6 lattice numerology in any perf assertion — hard fail (f1/f2 deny:write). anchors = Shannon / memory-bandwidth / cuBLAS-measured roofline only. 가짜 배수 금지 (g3)."
  @> README.md

@D g_forge_preservation := "물거품 방지 (flame Phase 0 와 페어)" :: governance [required d=2026-05-16 active]
  rule = "forge 산출물은 flame §X 캠페인 인덱스의 부분집합 (RFC 040 device-farr + cuBLAS + RFC 041 .cu stubs). flame Phase 0 가 2026-05-16 CLEARED 됐고 (rfc043-hexa-torch a8bc5e08 가 5 캠페인 브랜치 + §X 9 SHA 의 strict 선형 ancestor, origin==local 바이트동일) forge 도 그 결과 상속."
  residual = "main divergence (다른 세션 interp-retirement R1/R2/R3 + F6-A in-flight) — forge blocker 아님; 그쪽 안정화 후 화해"
  cross_repo = "anima evidence (state/hexad_gpu_fire_*, docs/anima_rfc040_phase_*) = anima 잔류 — 참조만, 복제 X (g3 drift-avoidance)"
  @> PLAN.md

@D g_forge_no_relocation := "기존 코드 이동 금지" :: governance [required d=2026-05-16 active]
  rule = "forge 명명으로 self/runtime.c 의 GPU 부분 + self/cuda/* 를 물리적으로 이동/리네임 금지. 빌드 경로 churn = build_verify 회귀 risk. self/forge/ 는 LABEL 디렉토리 (README + PLAN + tape) only. 신규 .cu 추가 시 self/cuda/ 에 배치 (기존 컨벤션 유지)."
  why = "g3 drift-avoidance + hexa-lang Makefile / build_verify 가 self/cuda/runtime_cuda.c 경로에 hardcoded; rename = 광범위 churn 위험 0 이득"
  @> README.md

@D g_forge_phase_falsifiers := "Phase 1/2/3 falsifier 사전등록" :: governance [required d=2026-05-16 active]
  F_FORGE_CUBLAS_EQ = "Phase 1: farr_matmul_gpu ≡ CPU farr_matmul at TOL_MATMUL ≤ 2e-9 on fresh GPU fire post-main-merge (max|Δ|=4.44e-15 이미 4× 검증, parity 유지 검증)"
  F_FORGE_KERNEL_EQ = "Phase 2: 신규 .cu (softmax_rows/rmsnorm_rows/add/scale/mul/silu/silu_grad/rmsnorm_bwd/adamw/outer/matmul_t) 각각이 (a) CPU farr reference 와 TOL_OP parity + (b) 기존 cuBLAS-reshape 우회 경로와 boundary test 일치"
  F_FORGE_FUSED_EQ = "Phase 3: fused epilogue (norm+act+residual into GEMM) ≡ unfused pipeline at TOL_OP + measured bandwidth ↑ (qualitative; no fabricated multiple)"
  rule = "각 falsifier 는 compiled-native 경로(`hexa build`, no interp) 에서만 PASS 인정. 가짜 target 금지 — reference 는 §X oracle 또는 RFC 041 명시 TOL spec."
  authority = "RFC 040/041 §Verification + g_blue_closed_mandate"
  @> PLAN.md

# ─── §X External citations — preservation cross-link ─────────────────
# Most campaign artifacts are indexed in flame's FLAME.tape §X. forge
# only adds substrate-specific @X entries; otherwise we POINT at flame
# rather than duplicate (g3 drift-avoidance).

@X x_flame_index := "flame §X — primary preservation index (cross-ref, not duplicate)" :: ref [d=2026-05-16 active]
  path = "stdlib/flame/FLAME.tape §X"
  what = "RFC 040→043 캠페인 전 산출물 (branch · SHA · path · RFC#) + verified oracles. forge artifacts 는 그 부분집합 — 중복 보존 금지 (g3)"

@X x_rfc040 := "RFC 040 — device-farr + cuBLAS design SSOT" :: rfc [d=2026-05-16 active]
  path = "hexa-lang inbox/rfc_drafts_2026_05_12/rfc_040_*"
  branch = "rfc/farr-gpu-cuda-backend (design 95c208f6)"
  scope = "device-farr ext + hexa_farr_*_gpu dispatchers + cuBLAS Dgemm wiring + TOL_MATMUL spec"

@X x_rfc041 := "RFC 041 — real .cu kernels for non-matmul ops" :: rfc [d=2026-05-16 active]
  path = "hexa-lang inbox/rfc_drafts_2026_05_12/rfc_041_*"
  branch = "rfc041-042-upstream-needs dae35fee"
  scope = "softmax_rows/rmsnorm_rows/add/scale/mul/silu/silu_grad/rmsnorm_bwd/adamw/outer/matmul_t 11-op real kernels (currently TODO[cuda] -1 stubs)"

@X x_cublas_impl := "cuBLAS Dgemm landed impl" :: code [d=2026-05-16 active]
  branch = "phase-d-cublas-h100"
  sha = "180263d3 (runtime_cuda.c) · 903c0285 (real-wire stub→impl + link-fix + GPU smoke) · 54d56e4a (7 Phase A builtins interp parity)"
  path = "self/cuda/runtime_cuda.c · self/runtime.c · self/cuda/PHASE_D_H100_EVIDENCE.md"

@X x_phaseB2_ops := "Phase B2 — 7 backward farr ops scaffold" :: code [d=2026-05-16 active]
  branch = "rfc040-phaseB2-complete"
  sha = "017b988f"
  ops = "farr_matmul_t/outer/mul/silu/silu_grad/rmsnorm_bwd/adamw _gpu — #ifdef HEXA_CUDA TODO[cuda] stub + CPU helper; 11-builtin interp backfill"
  verified = "tmp_rfc040_phaseB2_smoke.hexa 9/9 vs boxed c3_*/dt2_* reference"

@X x_oracle_cublas := "VERIFIED ORACLE — cuBLAS ≡ CPU" :: oracle [d=2026-05-16 active]
  fact = "cuBLAS Dgemm vs CPU: max|Δ|=4.44e-15 (<1e-9); reduction-heavy measured TOL_MATMUL ≈ 2e-9 (RFC 040 fp-non-assoc honest caveat)"
  perf = "51.24 TFLOPS FP64 H100 (76% peak) · 13,526 GF/s A100 · 4× independent verify (2 H100 + 2 A100)"
  same_as = "FLAME.tape x_oracle_cublas (intentional duplicate of the oracle FACT only; not the artifact list)"

@X x_oracle_phaseB2 := "VERIFIED ORACLE — Phase B2 ops vs boxed (CPU path)" :: oracle [d=2026-05-16 active]
  fact = "tmp_rfc040_phaseB2_smoke.hexa 9/9 — matmul_t/outer/mul/silu/silu_grad/rmsnorm_bwd/adamw _gpu (no-CUDA path) ≡ c3_*/dt2_* boxed reference"
  caveat = "no-CUDA path only — real .cu kernels (RFC 041) not yet exist; Phase 2 falsifier F-FORGE-KERNEL-EQ"
  same_as = "FLAME.tape x_oracle_phaseB2 (FACT cross-ref)"

@X x_anima_gpu_evidence := "anima cross-repo GPU evidence (reference, not relocate)" :: ref [d=2026-05-16 active]
  repo = "dancinlab/anima main"
  state = "state/hexad_gpu_fire_phaseD_/phaseE_/phaseE2_/a100_/runpod_/2026_05_16/* — fire logs + result.json"
  docs = "docs/anima_rfc040_phase_d_h100_cublas_2026_05_16.md + phase_e_d_train5_gpu_routed_2026_05_16.md + phase_e2_backward_fathost_2026_05_16.md"
  shas = "anima 27e96e348 (Phase D) · e8f6c13d8 (integrated -DHEXA_CUDA) · 4d8fd45ba (A100 retry) · e7085187e (runpod 4th verify + dep-bug fix) · 6335f1602 (Phase E fwd GPU-routed) · 6c0fbe08f (Phase E2 bwd + fat host)"
  note = "anima 잔류 — forge 가 참조만 (cross-repo, 복제 X, g3)"

# ─── §N Notes ────────────────────────────────────────────────────────

@N n_label_only := "forge = label, not relocation" :: note [d=2026-05-16 active]
  text = "self/forge/ 신규 디렉토리는 README + PLAN + tape 만. self/runtime.c GPU 부분 + self/cuda/ 코드는 그대로 (이동 0). g_forge_no_relocation 강제. flame ↔ forge 양방향 크로스레프는 flame 동시작업(다른 세션 Phase 1 in-flight) 안정화 후 후속 커밋."

@N n_naming_rationale := "왜 'forge' 인가" :: note [d=2026-05-16 active]
  text = "(a) flame 과 thermal 패밀리 통일 ('flame builds on forge'); (b) 기능 정확 = 무거운 컴퓨트가 일어나는 substrate/엔진; (c) f1/f2 안전 (격자/수비학 함의 0); (d) 영어/한국어 모두 자연스러움 (HF/upstream 영어 mandate · 세션 한글 mandate 양립); (e) 짧음 (5 글자) — torch/flame 과 어휘 길이 비슷"

## Log

### 2026-05-16 — FORGE.tape created (NAMING, scaffold-only)
사용자 directive 2026-05-16 "forge 로 가자 세팅해줘" → self/forge/{README,
PLAN, FORGE.tape} 작성. forge = 기존 GPU substrate (self/runtime.c GPU
부분 + self/cuda/runtime_cuda.c) 의 SSOT 라벨. 코드 이동 0 (g3 +
g_forge_no_relocation). flame ↔ forge 양방향 크로스레프는 flame
동시작업(다른 세션 Phase 1 in-flight, FLAME.tape/PLAN.md 수정 중)
안정화 후 후속 커밋 — 이번 커밋은 forge-only, flame WIP 무영향.
캠페인 산출물 참조-보존은 [@x_flame_index] 가 primary, forge §X 는
substrate-specific 보완 (cuBLAS impl 위치 + RFC 040/041 명시 + anima
cross-repo evidence pin).
