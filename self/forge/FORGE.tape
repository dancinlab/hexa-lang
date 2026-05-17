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

@X x_paradigm_ssot := "PARADIGM.md — forge paradigm 결정 SSOT (measurement-anchored)" :: ssot [d=2026-05-17 active]
  path = "self/forge/PARADIGM.md"
  what = "Phase R 4 fire (D/B/C 완료, A in-flight) 의 측정 anchor 종합. paradigm 사전 등록 가설 모두 over-optimistic FAIL → data-anchored X' reframe (D' B' C' A'). Meta-thesis = forge 는 regime-tiered substrate (작은=Graphs, 중간=SMEM, 큰=DSM, 모두=D' det FREE)."
  consumers = "RFC 044 draft 의 토대 · PLAN §Phase 2-4 재정의 trigger"

@X x_paradigm_research := "PARADIGM_RESEARCH.md — literature snapshot (가설 수립용, paradigm 결정의 근거 아님)" :: ref [d=2026-05-16 active]
  path = "self/forge/PARADIGM_RESEARCH.md"
  scope = "한국 alternatives + 글로벌 AOT-NN 컴파일러 SOTA + arxiv 2025-2026. PARADIGM.md 의 가설 sources, NOT decision sources (g3: 결정은 실측으로만)"

@X x_phaseR_fires := "Phase R 실측 산출 (D/B/C 완료, A in-flight 2026-05-17)" :: code [d=2026-05-17 active]
  d = "state/forge_phaseR_d_2026_05_17/{result.json, D_ANALYSIS.md} — H100 PEDANTIC vs DEFAULT, within-run det FREE"
  b = "state/forge_phaseR_b_2026_05_17/{result.json, B_ANALYSIS.md} — H200 FFN cuBLAS vs CUDA Graphs, shape-tiered"
  c = "state/forge_phaseR_c_2026_05_17/{result.json, C_ANALYSIS.md} — H100 linear fwd+bwd, redundancy 1.500× constant"
  a = "state/forge_phaseR_a_2026_05_17/ — AOT trainer vs PyTorch eager (in-flight)"
  cost = "D $0.40 + B $0.25 + C $0.30 = $0.95 (A 대기)"
  experiments = "self/cuda/experiments/{d_determinism.cu, b_ffn_baseline.cu, c_linear_autograd.cu, a_aot_trainer.cu, a_pytorch_baseline.py, dispatch_{d,b,c,a}.sh}"

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

### 2026-05-17 — Phase R / D fire data + D' reframe
H100 SXM cuBLAS 12.4.5 · 6 shape FP64 Dgemm sweep · vast.ai $0.40. 결과:
- pre-reg falsifier "cost ≤ 15%" = **FAIL** (max +33.39%)
- PEDANTIC ≡ DEFAULT bit-equal (모든 shape) → PEDANTIC = correctness 무 benefit
- DEFAULT 도 within-run deterministic → **FP64 single-process determinism FREE** (실측)
- **D' (data-anchored reframe)**: forge FP64 substrate = within-run det FREE; PEDANTIC opt-in only (+15-33% cost, no FP64 benefit). LayerCast-style BF16/FP16 det = 별도 paradigm RFC 047+. PARADIGM.md SSOT 후속.
산출: state/forge_phaseR_d_2026_05_17/{result.json, D_ANALYSIS.md}.

### 2026-05-17 — Stage 2 C Phase 1 PASS + Stage 2 B fire BLOCKED (Hopper supply)
**C Stage 2 Phase 1** (A100 SXM cc=8.0 cuBLAS 12.4.5 · $0.30): single-block SMEM-resident fused kernel vs cuBLAS chain, 3 shape (16/32/64).
- F-FORGE-C-STAGE2-FUSED-CEILING ✅ PASS — bytes_ratio = 0.6667 every shape (≤ 0.75 threshold)
- F-FORGE-C-STAGE2-DET-PRESERVE ✅ PASS — max|Δ| < 1e-16 (TOL_OP 7 orders headroom)
- wall-time slower than cuBLAS (single-block naive vs Tensor Core) — Phase 2 production kernel 필요 (2-3 weeks)
- C 이론적 HBM 이점 + 결정성 모두 anchor 확인. PARADIGM.md §4.5 + RFC 044 falsifier 마킹.
산출: state/forge_phaseR_c_stage2_2026_05_17/{result.json, C_STAGE2_ANALYSIS.md}.

**B Stage 2 fire BLOCKED**: H100/H200 ≤$50/hr 0 offers (Hopper supply 시장 fully booked). Kernel code (b_dsm_ffn_stage2.cu — cluster API smoke + cuBLAS baseline) + dispatch land — Hopper 가용 시 fire.

Phase R 누적 cost: **$1.95** (6 fires complete + 1 blocked).

### 2026-05-17 — Stage 2 A fire COMPLETED (F-FORGE-A-STAGE2-LARGE PASS, batch-size finding)
**A Stage 2** (A100 SXM4 80GB · cuBLAS 12.4.2 · PyTorch 2.4.0 · $0.30, H100 fallback): scaled-up MLP 3 configs.
- large_b128 (D=8192 B=128): AOT 5.29ms vs PyT 21.19ms = **4.00×**
- large_b512 (D=8192 B=512): AOT 19.94ms vs PyT 37.14ms = **1.86×**
- xlarge_b128 (D=16384 B=128): AOT 19.99ms vs PyT 81.24ms = **4.06×**

F-FORGE-A-STAGE2-LARGE PASS 모든 config (사전등록 ≥1.1× 의 1.69-3.69× 초과).
- **KEY**: batch-size 가 A win 의 dominant variable (compute size 아님). small batch any model → 4-6×, large batch → 1.86×.
- A100 fallback 에서도 압도적 → A paradigm = GPU-generation 독립.
- forge 의 inference framework market 경쟁력 시사 (vLLM/TensorRT-LLM 영역).
- PARADIGM.md §A + §6 batch-size aware 갱신. RFC 044 falsifier 마킹.
Phase R 누적 cost: $1.65 (5 fires). 산출: state/forge_phaseR_a_stage2_2026_05_17/{result.json, pytorch_result.json, A_STAGE2_ANALYSIS.md}.

### 2026-05-17 — RFC 044 DRAFT + PLAN §Phase 2-4 재정의 land
**RFC 044** (`inbox/rfc_drafts_2026_05_12/rfc_044_forge_regime_tiered_substrate.md`): 측정-anchored forge architectural pivot. dual-mechanism × regime-tiered substrate 명세 + 14 falsifier 사전 등록 (5 Stage 1 PASS · 9 Stage 2 pre-reg). RFC 040/041 superseded X — RFC 041 의 11-op TODO 채우기는 Phase 2.B substrate 로 흡수 (SMEM-aware 구현으로 진화).

**PLAN §Phase 2-4 재정의**:
- Phase 2 → 3 sub-tier (2.A CUDA Graphs · 2.B SMEM-fused FFN · 2.C fused fwd+bwd linear)
- Phase 3 → DSM-cluster fusion (B' Stage 2, Hopper-only)
- Phase 4 → AOT whole-train-step (A' Stage 2)
- Phase 5+ → multi-GPU (강등)
§2 gating 표 + flame ↔ forge mapping 표 동기화.

### 2026-05-17 — Phase R 종합 완료 (A 결과 + PARADIGM.md PUBLISH)
**A (H100 SXM 80GB cuBLAS 12.4.2 · PyTorch 2.4.0 · $0.40)**: 3 configs · AOT single-binary vs PyTorch eager (FP64 MLP+AdamW):
- mnist_b32 (784×256×10, B=32): AOT 0.110 ms vs PyT 0.668 ms = **6.065×**
- mnist_b128 (B=128 同): **6.013×** (batch 변화 무영향 → ~85% overhead)
- mid_b32 (4096×4096×100): AOT 1.206 ms vs PyT 2.704 ms = **2.243×**
- pre-reg ≥1.2× 모든 config PASS · 사전등록 under-optimistic, 실측 압도
- **A' (dispatch-regime-aware)**: small 6× → mid 2.24× → large ~1.1× (compute dominates expected). dispatch elimination mechanism, NOT memory fusion.

**Phase R 종합 (D/B/C/A 4 fire, $1.35 total)** → `PARADIGM.md` PUBLISH:
- 4 paradigm 측정-anchored verdict + X' reframe + Stage 2 falsifier 사전등록
- **Meta-thesis**: forge = **dual-mechanism × regime-tiered AOT substrate**.
  - Mechanism 1 (Dispatch elimination, A): small/mid model dominant.
  - Mechanism 2 (Memory fusion, B/C): large model dominant.
  - 공통 D': within-run det FREE.
  - vs PyTorch/XLA/Mojo: 둘 다 native, regime-tiered = distinctive.
- Stage 2 진입 순서 추천: A → B → C (각 user gate). RFC 044 draft 후속.

### 2026-05-17 — Phase R / C result + C' reframe + A dispatched
**C (H100 SXM 80GB cuBLAS 12.4.5 · $0.30)**: 5 shape linear fwd+bwd. range: graph_speedup [+3.86%, +27.87%], **redundancy 1.500× constant**, BW util [14.1%, 45.2%], bit_equal Y/dW/dX = 1 all.
- F1 redundancy 1.500× constant → 이론적 fused ceiling 0.667× (33% traffic reduction)
- F2 pre-reg "≤ 0.6×" = theoretical impossibility → **FAIL**
- F3 bit-equality 모든 output → D' det 확장 anchor
- **C' (data-anchored)**: realistic ≤ 0.75× fused/separate. regime-tiered: 작은 shape = CUDA Graphs FREE (+20-28%), 큰 shape (Llama-7B+) = DSM 가치 명확.
**Meta-finding (D/B/C 일관)**: 사전등록 universal 가설 모두 over-optimistic. 데이터 가 **regime-tiered tooling** 가르침 — 작은 = Graphs, 중간 = SMEM, 큰 = DSM, 모두 = D' det FREE.
산출: state/forge_phaseR_c_2026_05_17/{result.json, C_ANALYSIS.md}.

**A dispatched**: 3-layer MLP AOT trainer (single CUDA binary) vs PyTorch eager (pytorch:2.4 image preinstalled). 3 configs · median step_ms 비교 · falsifier ≥ 1.2×.

### 2026-05-17 — Phase R / B Stage 1 result + B' reframe + C dispatched
**B (H200 SXM 143GB · cuBLAS 12.4.5 · $0.25)**: 6 shape FFN sweep. Range: graph_speedup ∈ [+1.96%, +20.06%], BW util ∈ [13.9%, 35.4%] (H200 peak 4.8 TB/s). All bit_equal=1.
- pre-reg "≤ 0.5×" universally **FAIL** (CUDA Graphs max 0.8× only)
- 큰 shape (Llama-7B) BW util 35% → DSM Stage 2 potential 0.5×-0.7× (이론)
- **B' (data-anchored)**: shape-dependent paradigm. small = CUDA Graphs +20% FREE; large (Llama-7B+) = DSM Stage 2 ROI 명확. Universal 가설 기각 → shape-tiered F-FORGE-B-PRIME-DSM-{SMALL/MEDIUM/LARGE}.
산출: state/forge_phaseR_b_2026_05_17/{result.json, B_ANALYSIS.md}.

**C dispatched**: linear fwd+bwd separate vs CUDA Graphs · HBM redundancy · BW util. H100/H200 vast.ai 진행 중.

### 2026-05-17 — Phase R / B Stage 1 dispatched
B Stage 1 = full DSM kernel 아닌 prerequisite 진단. cuBLAS FFN chain (Dgemm+SiLU+Dgemm) separate vs CUDA Graphs · BW util · per-kernel breakdown. H100 vast.ai 진행 중. Stage 1 결과로 Stage 2 (custom DSM cluster kernel) 진입 결정.

### 2026-05-17 — Phase R 진입 (paradigm 실험·검증, experiment-first)
사용자 정정 2026-05-17: paradigm 은 literature/sketch 박제 아닌 **실측으로
채택/기각**. PLAN §1 에 Phase R 신규 삽입 (Phase 1 클리어 후 Phase 2-4
재정의 gate). 4 paradigm × falsifiable hypothesis 사전등록:
- D (determinism-default): cuBLAS PEDANTIC vs default · perf cost ≤ 15%
- B (DSM-aware fused FFN): H100 fused FFN latency ≤ 0.5× separate cuBLAS
- C (autograd co-emission): fused fwd+bwd HBM traffic ≤ 0.6× separate
- A (AOT whole-train-step): 3-layer MLP AOT throughput ≥ 1.2× PyTorch eager
cost ascending fire 순서 = D → B → C → A. 측정 hardware = H100 SXM5 fresh
fire (vast.ai/runpod). 결과 → `PARADIGM.md` SSOT → RFC 044 → Phase 2-4
재정의. flame 영역 무손상. 첫 fire (D) hardware/code/watchdog 별도 게이트.
@> PLAN.md

### 2026-05-16 — paradigm research snapshot LANDED (PARADIGM_RESEARCH.md)
사용자 directive 2026-05-16 "CUDA 포팅 아님, 더 뛰어난 아키텍쳐/패러다임"
+ "한국 alternatives + arxiv deep research, 데이터 먼저 확보" → 8-track
parallel WebSearch + 5 WebFetch (한국 NPU 신생들 / 글로벌 AOT-NN
컴파일러 SOTA / arxiv 2025-2026). 산출: `self/forge/PARADIGM_RESEARCH.md`
(§1-§8 데이터 brief + paradigm gap synthesis + 사용자 결정 A+B + sources).
핵심 발견 — (a) 한국 측 새 paradigm 언어 = 없음 (Moreh full-trace 가
유일한 학습 paradigm 이나 PyTorch frontend wrapper); (b) AOT × whole-
train-step (fwd+bwd+opt) = **2026-05 누구도 안 해결한 frontier**
(torch.compile precompile WIP, JAX = JIT, Mojo MAX = inference-first);
(c) FlashFuser (arxiv 2512.12949) 가 H100 DSM 으로 inference 1.24× E2E
+ 58% DRAM↓ 실증 — forge 의 floor anchor; (d) LayerCast (arxiv
2506.09501) 가 결정성 paradigm 의 직접 evidence. 사용자 결정 = **A+B
둘 다**: A = RFC 044 design draft, B = FlashFuser-style DSM prototype
(forge floor 확인용 minimal experiment, full kernel 포팅 아님). 이번
update 는 research trail 만 — RFC 044 / PARADIGM.md / PHASE2_PREP 은
후속 커밋. flame 영역 무손상 (stdlib/flame/* 미접근).
