# GPU-ROOFLINE — append-only step log

## 2026-05-30 — MS#1 sub-task 1a 규모 재평가 = honest STOP (1b 선결 의존) (gpu-rfl-ms1-1a)

### MS#1 1a 🟠 MIR fragment-operand threading — BLOCKED (1b 선결 필요, flip 보류)

코드-감사 결과 1a 는 **1b/1c 선결 없이 독립 완결 불가** → honest STOP. fail 아님, multi-session 의존 확정.

**핵심 발견 — WMMA emit 경로가 둘로 분리(disjoint):**

1. **`gpu_wmma_*` STMT_CALL 경로**(`nvptx_target.hexa:1778-1816`) — placeholder `{/* a */}` 가 있는 그 경로.
   - **codegen 소비 측 threading 은 이미 완결**: L1791-1793(mma 의 src A/B/C)·L1806(store_c 의 src D)
     가 `s.args[i].kind == "local"` 이면 `_nvptx_wmma_frag_tuple(s.args[i].local_id, ...)` 로 실제 FRAG
     tuple 을 emit. placeholder 는 `s.args` 가 비었을 때만 fallback. 즉 **operand threading 을 받을 준비가
     codegen 에 이미 되어 있음** — 1a 가 손댈 codegen 변경분 = 없음(no-op).
   - **그러나 이 op 들을 생산하는 HIR→MIR 경로가 부재**: `gpu_wmma_*` STMT_CALL 은 오직 test fixture
     (`nvptx_lower_test.hexa` Case 23/threading)에서만 합성됨. `hir_to_mir.hexa` 에 `gpu_wmma` 참조 0건
     (grep 확인). 따라서 "MIR 이 K-loop 을 돌며 fragment Local 을 s.args 로 운반" 할 K-loop 자체가
     소스 레벨에 없음. 그 producer(parametric per-tile load/mma/store K-loop)를 만드는 것이 곧
     **1b(HIR fixed-array/shared-tile surface) + 1c(grid/CTA geometry parametric emit)**.

2. **matmul-shape 경로**(`_nvptx_emit_matmul_body`, `nvptx_target.hexa:7580+`) — 소스 `gpu_matmul(...)` 이
   실제로 lower 되는 경로(`hir_to_mir.hexa:1248`, `_nvptx_mfunc_is_matmul_shape` recognise).
   - 이 경로는 fragment threading 을 **이미 hand-emit PTX 텍스트 템플릿으로 완결**: L7613-7617 의
     `wmma.mma...frc0, fra0, frb0, frc0` 가 A·B → mma, C accumulator chain 을 직접 연결. K-loop·stride
     상수(`32768`/`8192`/`65536`)도 여기 hand-PTX. placeholder STMT_CALL 경로를 전혀 거치지 않음.
   - `F-RFC067-TILE-LOOP-NUMERIC` 는 이 경로로 **이미 PASS**(GPU.md:47, PR #191, single-tile max|Δ|=0).
     1a 문서가 "미발화" 라 한 것은 placeholder STMT_CALL 경로 기준이고, 실제 working 경로는 matmul-shape.

**결론**: 1a "fragment-operand threading" 은 (a) codegen 소비 측은 이미 구현됨, (b) STMT_CALL producer 는
부재하며 그 producer 제작 = 1b+1c, (c) 실 GEMM 경로(matmul-shape)는 별도로 이미 threading 완결. 따라서
**surgical 1a-only 변경으로 실제 효과를 내는 코드 변경분이 없음** — placeholder 경로를 건드려도 producer
없이는 no-op, producer 를 만들면 1b/1c 침범. spec 이 예상한 honest STOP 조건("불가(1b 선결)면 STOP") 충족.

**권고 순서**: 1b(HIR fixed-array surface → shared-tile parametric) 먼저 → 그 surface 가 parametric K-loop
MIR(per-tile `gpu_wmma_load_a/b` → `gpu_wmma_mma`(threaded args) → `gpu_wmma_store_c`)을 생산하게 한 뒤
1a 의 codegen 소비 측(이미 준비됨)이 자동 활성. 1c(grid/CTA geometry)와 병행. codegen 무변경(이미 완결).

**byte-eq 회귀**: 1a 가 코드 변경 0 이므로 256×256 출력 불변 자명(회귀 N/A). 기존 §hexa-emit-direct
256 1점(max|Δ|=0, PR #214)·matmul-shape PASS(PR #191) 그대로. STOP 이라 ubu-2 fire 미실행(불필요).

## 2026-05-30 — batch B drain: MS#4 flame attention lane (gpu-roofline-batch-b)

### MS#4 🟢 flame — attention 커널 별도 roofline lane [PASS, measured]
- 커널 위치: flame attention = `stdlib/flame/decoder_block_lib.hexa:363-428` CPU host scalar 루프(farr_*).
  GPU 설계(PHASE4D7/4D9) = QKᵀ·PV → cuBLAS Dgemm dispatch · softmax → CPU causal-prefix(byte-eq forge
  masked-attn 커널 부재). **flash-attention 아님** — S(score) 행렬을 HBM 에 materialize.
- 측정: ubu-2 RTX 5070 $0 fire(`/tmp/flame_attn_roofline.cu`, pure-ASCII, cuBLAS SGEMM, 200 timed median,
  2-run < 0.4% drift). shape = flame d768 config T=1024·hd=64·nh=12·nkv=4 GQA.
- **AI = 28.44 F/B < ridge 61 → memory-bound**. binding-roof = BW × AI:
  - QKᵀ achieved 9242 GFLOP/s = **56.1%** of HBM-roof(DtoD 578.88)/58.0%(STREAM 559.52)
  - PV  achieved 8035 GFLOP/s = **48.7%**/50.4%
  - attn-core(QKᵀ+PV) achieved 8597 GFLOP/s = **52.1%**/54.0%
- 정직: full-materialized(non-causal 상한) — 실제 causal 은 ~½ cost·동일 AI. softmax 는 GPU 커널 부재 →
  roofline-N/A(미산입, 명시적 누락). 52% 는 cuBLAS 비효율 아님 — materialized-attention 의 AI 천장(S
  write/read binding). flash-attn 로 가면 AI↑ 여지 = 향후 lever(미구현). theoretical 672 GB/s 분모로는 45.2%.
- MS#3 롤업의 "attention 미산입(honest gap)" 이 본 측정으로 채워짐. 결과 = bench.md §attention-lane.

## 2026-05-30 — batch A drain: @goal 갱신 + MS#2/#3/#6 (gpu-roofline-batch-a)

### @goal 갱신
- 측정대-구축 @goal → 7 마일스톤 포괄 상위 목표로 보강(의미 보존+확장): "모든 dominant 커널을
  HW 물리 천장 % 로 측정·확정하고 도달 가능 천장까지 끌어올린다 · cuBLAS 천장이면 못 이김≠실패 ·
  hexa-emit 은 variable-shape 로 직접 % 를 연다".

### MS#2 🔵 GPU — PTX-diff → roofline 정적 예측 (fire 없이) [PASS]
- 기존 GPU.md PTX-diff $0 oracle 재활용(신규 fire 0): N104 cuBLAS SASS-diff · N67 vec-add scale-up ·
  RFC067-D HGEMM 5-shape. PTX instruction histogram → flops_done/bytes_moved 정적 AI → ridge(61) binding 선택.
- 4/4 비교쌍 정적 예측 vs 기존 실측 ±15% 게이트 PASS(실제 Δ ≤3pp):
  vec-add AI=0.167≪ridge → 93% BW-roof(N67 실측 93% spec) · cuBLAS HMMA-dense → 0.53 ratio(N104 0.533) ·
  hexa naive WMMA SMEM-tile 부재 → monotonic 강등 0.767→0.287(RFC067-D 곡선 일치).
- 정직: 정적 AI 는 L2/reg 재사용 못 봄 → memory-bound 보수적; L2 hit-rate·occupancy = roofline-N/A(정적).
- 결과 = GPU-ROOFLINE.bench.md §ptx-static.

### MS#3 🟢 flame — 학습 step 전체 dominant 커널 roofline 완전 롤업 [PASS, 부분]
- linear(14–45% HBM-roof, H100) + FFN(14–35%, H200) 시간-가중 합산 = **~14–42% of HBM-roof**.
  둘 다 memory-bound(AI<ridge 61) 동질 → binding 정합(혼합 없음).
- 정직: 개별 %는 실측-유래(🟢), step-time 비중(35/45/20%)은 가정(🟠 — PERF.md per-kernel 프로파일 부재,
  step time 114–133s FP64 통합값만 측정). attention 커널 별도 측정 미존재(MS#4) → 롤업에서 명시적 누락 표기,
  "누락 커널 0" 게이트 부분충족(2-커널 합산만). H100/H200 분모 명시(RTX 5070 아님).
- 결과 = GPU-ROOFLINE.bench.md §flame-lane.

### MS#6 🔴 forge — FP64 TC 41–43% 천장 origin 분석 [CLOSED-NEGATIVE]
- 가설(operand SMEM tiling 부재 = §3.9a HARD_WALL) **확정**. 3 독립 fire 수렴:
  Phase R C-V3(41–43% baseline) · RFC 052 §3.9a("no SMEM operand tiling/reuse, memory-bound" + 12% occupancy 직접 명시) ·
  RFC 060-C FP64 mega-kernel(2× A100, 1.8–4.4× 느림, "Phase R 41–43% 와 정합" 교차 확증).
- finding: SMEM-tile 없이 cuBLAS(77–87% CUTLASS-grade) 따라잡기 = 물리적 닫힘 = 확정 천장 = "못 이김≠실패".
  끌어올림 = C Phase 4 CUTLASS-grade(SMEM 타일링+SW pipelining+autotune, 3–6주 vendor-tuning, batch 밖).
- tier = 🔴 CLOSED-NEGATIVE(valid finding). 결과 = GPU-ROOFLINE.bench.md §forge-lane.

### 안전 / scope
- 격리 worktree `gpu-roofline-batch-a` ← origin/main. 공유 트리·타 에이전트 브랜치 미접촉. 명시 3경로만 stage.
- 신규 fire 0(전부 기존 측정 재계산/정적분석) · codegen·.c·.cu 무변경 · vast RTSC 학습 pod 미접촉.
- 남은 open: MS#1(hexa-emit 직접 %·variable-shape codegen) · MS#4(attention lane fire) · MS#5(WMMA shape sweep) · MS#7(멀티디바이스 분모) — 후속 fire-bearing batch.

## 2026-05-30 — 단일 SSOT 통합 + 7 open milestone 생성 (gpu-roofline-consolidate)

### 문서 통합 (수치 SSOT 단일화)
- flame/forge 의 roofline % 수치표를 `domains/GPU-ROOFLINE.bench.md` 단일 SSOT 로 이전:
  - §flame-lane = `stdlib/flame/PERF.md §GPU-ROOFLINE lane` 의 학습 커널 표(H100/H200 BW-util · FP64 mega-kernel HARD_WALL).
  - §forge-lane = `self/forge/PLAN.md §GPU-ROOFLINE lane` 의 forge 커널 표(hand-WMMA 41–43% · cuBLAS 77–87% · DSM-FFN · BF16 inherit).
- 원위치(PERF.md/PLAN.md)는 "측정 SSOT = domains/GPU-ROOFLINE.bench.md (수치 중복 제거)" 1줄 pointer 로 대체.
  분석/scope/HARD_WALL 서술은 원위치 보존(수치표만 이전 — 의미 손실 0).
- `domains/GPU-ROOFLINE.md` 에 GPU·flame·forge 3-lane 통합 요약 섹션 추가(각 lane 1줄 현황 + .bench.md 링크).

### 7 open milestone 생성 (각 falsifier+측정법 inline)
- GPU 2(#1 hexa-emit 커널 직접 roofline · #2 PTX-diff 정적예측) · flame 2(#3 step 전체 롤업 · #4 attention lane) ·
  forge 2(#5 WMMA variable-shape · #6 FP64 TC 41–43% origin 🔴) · 공통 1(#7 멀티디바이스 분모 A100/H100).
- 기존 deferred 2건(hexa-emit 커널 · PTX-diff)은 #1·#2 로 승격(중복 제거).
- 측정 fire 안 함 — open 으로 두고 후속 loop 위임. codegen 무변경. vast RTSC 학습 pod 미접촉.

### 안전
- 격리 worktree `gpu-roofline-consolidate` ← origin/main. 공유 트리 미접촉. 명시 5경로만 stage.

## 2026-05-30 — 도메인 신설 + achieved-peak 분모 박제

### 측정대 신설 (UNSHADOW roofline 측정대와 동형)
- GPU 도메인 + flame(학습) + forge(GPU 커널) 에 HW 물리 천장(roofline) % 측정대 신설.
- 구조 = Q3 하이브리드: 잣대(분모) 1개를 `domains/GPU-ROOFLINE.*` SSOT 로, flame/forge 는
  합병 아닌 **상속 lane**(각자 doc 에 roofline 표, 분모 공유).
- 격리 worktree `gpu-roofline-stand` ← origin/main `a5c5c684d`. 공유 트리 보호.
- 병렬 UNSHADOW agent 가 hexa-loop + domains/UNSHADOW.* 작업 중 → 그 파일 안 건드림.

### ubu-2 RTX 5070 achieved-peak 실측 ($0 fire, pool ubu-2)
- 디바이스: NVIDIA GeForce RTX 5070, sm_120, 48 SM, 2542 MHz core, 192-bit × 14001 MHz mem.
- nvcc 12.0 은 `-arch=sm_120` 미지원 → `-arch=sm_90` 으로 컴파일, driver 580 JIT 가 sm_120 으로
  forward-compat(GPU.md fire 이력과 동일 경로). non-ASCII PTX 없음(소스 순수 ASCII).
- microbench `/tmp/gpu_peak_microbench.cu`(repo root 밖 — `.cu` 손작성 hexa-native 훅 차단):
  - HBM 대역폭(STREAM copy) = **559.52 GB/s** (median 0.9595 ms, theoretical 672 의 83.3%)
  - FP32 FMA-chain = **34.11 TFLOP/s** (median 1.5108 ms, marketing 30.9 의 ~110%)
  - FP16 half2 CUDA-core = **35.95 TFLOP/s** (median 2.8674 ms)
- `/tmp/gpu_tc_peak.cu`(cuBLAS HGEMM tensor-core):
  - M=1024 76.87 · M=2048 102.73 · **M=4096 126.52 TFLOP/s** (분모 박제값)
- ridge-point(FP32) = 34.11 / 0.55952 ≈ **61 flops/byte**.

### 측정대 어댑터 (기존 GPU PTX-diff $0 oracle + ubu-2 fire 재사용)
- 기존 `tool/gpu_hbm_roofline.cu`(HBM BW + cuBLAS SGEMM AI-based roofline %) 재사용.
- roofline 분모 산출 = 커널 메타(bytes_moved, flops_done) → AI → binding-roof 자동선택
  (ridge-point) → achieved/binding-roof %. 절차 = GPU-ROOFLINE.bench.md §roofline.
- codegen 무변경(측정대 + 문서만).

### §roofline 표 (cuBLAS SGEMM small-M sweep, ubu-2, K=N=4096)
- M=1 102.07% · M=8 100.77% · M=32 99.96% · M=64 94.99% · M=128 57.02% (of HBM-roof).
- M=1024 = compute-bound → HBM-roof 12% 는 잣대 오류, compute-peak 의 76.34% 가 binding.
- 정직: memory-bound 영역에서 cuBLAS 가 100% 천장에 붙음 = "못 이김 ≠ 실패"(물리 천장).

### flame / forge 상속 lane
- `stdlib/flame/PERF.md` §GPU-ROOFLINE lane 추가 — 학습 step dominant 커널 roofline % 롤업.
- `self/forge/PLAN.md` §GPU-ROOFLINE lane 추가 — forge GPU builtin 커널 단위 %.
- 둘 다 분모 = GPU-ROOFLINE §peak 상속(합병 아님 · 1줄 명시).

### g5
- roofline % 분자 커널 = cuBLAS(reference BLAS, 정확성 자명). hexa-emit 커널 byte-eq 는 기존
  GPU.md 재인용(PR #190 byte_mismatch 0/1024 · PR #1215 max_rel ≤ 1.74e-7). 환산 무의미 = roofline-N/A.

### 안전
- vast RTSC 학습 pod 미접촉(adopt/list 만 — 이번엔 list 도 불필요, fire 는 무료 pool ubu-2).
- `.cu` 는 /tmp(repo root 밖) 에서만 작성·컴파일. repo root 손작성 0.

## 2026-05-30 — batch C drain: MS#5 forge WMMA variable-shape roofline sweep (ubu-2 fire)

### §wmma-shape-sweep (MS#5 🟢) — ubu-2 RTX 5070 $0 fire
- 측정대 `/tmp/ms5_host.cu`(repo root 밖·pure-ASCII): 기존 hexa-emit WMMA PTX 로드 +
  cuBLAS GemmEx(f16→f32 tensor-op) 동shape 나란히 + byte-eq(hexa WMMA vs CPU FP64 ref).
  median of 200(20 warmup, cudaEventRecord per-launch).
- 커널: `wmma_256x256_grid` = compiler-emitted(PR #214, 256-locked) · 128/512/1024 =
  hand-emit shape-port(N4 방식, 동일 WMMA microcode, address-arith 상수만 scale).
  M=128 PTX 신규 shape-port(2×2 grid of 64×64 block, k_tiles=8).
- **shape sweep ratio = 0.994(128) → 0.786(256) → 0.448(512) → 0.292(1024)** 단조 강등.
  → **0.767 은 강하게 shape 의존** 확정. M=128 = cuBLAS parity(둘 다 launch-bound tiny),
  M↑ 하며 SMEM-operand-tile 부재 naive K-loop 이 compute/BW-bound 에서 밀림.
- **byte-eq max|Δ|=0 全 shape**(N4 timing-only fire 가 빠뜨린 정확성 게이트 추가).
  sawtooth int 입력, f16-mul-f32-acc lossless → CPU FP64 ref 와 bit-exact.
- N4 곡선(0.767/0.417/0.287)과 run-to-run drift 이내 일치(measure 재현성).
- honest: variable-shape **compiler** emission 은 MS#1(multi-session codegen) 의존 — 미구현.
  ratio 곡선은 microcode-동일 hand-port 라 valid. "cuBLAS 못 이김 ≠ 실패"(SMEM-tile 부재 =
  MS#6 CLOSED-NEGATIVE 동일 origin · 끌어올림 = CUTLASS-grade §0.1 3–6주, batch 밖).
- artifact: `archive/fires/gpu_roofline_ms5_wmma_shape_sweep_2026_05_30/`
  (ms5_host.cu + ms5_fire.log + wmma_128x128_grid.ptx + README.md).

### 안전
- vast RTSC 학습 pod 미접촉. fire = 무료 pool ubu-2 RTX 5070($0). codegen 무변경.
- `.cu`/`.ptx` 는 /tmp(ubu-2)·archive/fires(repo) 에서만. repo root 손작성 0.

## 2026-05-30 — batch D drain: MS#1 hexa-emit 직접 achieved/peak % (256-locked 1점) + codegen 규모 산정

### MS#1 부분 진전 (256-locked, open 유지 — variable-shape compiler emission = multi-session)
- **falsifier/측정법**: compiler-emitted hexa WMMA 커널(`wmma_256x256_grid`, PR #214, 256-locked)의
  TFLOPS 를 device achieved tensor-core peak 분모로 **직접** 환산(cuBLAS 와의 ratio 아님 =
  cuBLAS-INDEPENDENT numerator) + byte-eq(hexa WMMA vs CPU FP64 ref).
- **2026-05-30 ubu-2 RTX 5070 sm_120 $0 fire** — `cuModuleLoad` 로 compiler-emit PTX 직접 로드,
  median of 200(20 warmup, cudaEventRecord per-launch). pure-ASCII, base64 byte-exact 전송.
- **결과(2 run, stable)**: hexa-emit `wmma_256x256_grid` = **3.53–3.59 TFLOPS** ·
  **DIRECT achieved/peak = 2.79–2.84%**(분모 §peak 박제 126.52 TF) / **4.96–5.05%**(same-process
  cuBLAS HGEMM M=4096 = 71.13 TF) · **byte-eq max|Δ|=0**(full 256×256, sawtooth int lossless).
- **분모 2개 정직 병기**: §peak 박제 126.52 TF(§peak fire 시점 GB205 default cfg) vs 본 fire
  same-process 71.13 TF(CUBLAS_COMPUTE_32F f32-acc + sm_90 PTX JIT). 둘 다 기록(격차 숨김 금지).
- **왜 % 가 작은가(정직)**: 256³ 는 TC 가 saturate 안 되는 launch/occupancy-bound 영역.
  shape-local cuBLAS(S=256)조차 자기 M=4096 peak 의 3.5% 뿐 → M=4096-peak 분모 대비 % 가 작은 게
  물리적 정직. hexa-emit 은 shape-local cuBLAS 의 **79–80%** 까지 따라붙음(MS#5 ratio 0.786 일치).
- hexa-emit TFLOPS(3.53–3.59) = MS#5 sweep(3.507)와 일치 = 측정 재현성.
- 상세 = `.bench.md §hexa-emit-direct`. artifact = `archive/fires/gpu_roofline_ms1_hexa_emit_direct_2026_05_30/`.

### codegen 규모 산정 (honest STOP — variable-shape compiler emission = multi-session)
- `nvptx_target.hexa` 직접 코드-감사: 현 WMMA 경로는 **단일 16×16×16 타일 intrinsic** 만 emit.
  256-grid 드라이버(CTA 기하·K-loop·stride 상수 32768/8192/65536)는 **hand-PTX** 에 박힘.
- 4 gap 확정(소스 코멘트가 직접 명시): (1a) `gpu_wmma_mma` fragment operand = placeholder
  `{/* a */}`, "Real GEMM K-loop integration is the P4 wiring"(미완, F-RFC067-TILE-LOOP-NUMERIC
  미발화) · (1b) `.shared` staging = synthetic 2048 B 고정(`_nvptx_shared_default_bytes`),
  HIR 에 `[T; N]` fixed-array surface 부재 → shape-param SMEM-tile 불가 · (1c) grid/CTA 기하 +
  stride 상수 codegen-parametric 부재 · (1d) shape-sweep byte-eq 회귀 + 직접 % 곡선.
- frontend(HIR/MIR) + backend(NVPTX) 양쪽 변경 = **1-batch surgical 불가 = multi-session**.
  → MS#1 open 유지 + `## MS#1 codegen sub-milestone` 4 sub-task(1a-1d) 로 분해 등록.
- batch scope = 256-locked 직접 % 측정(부분 진전) + codegen 규모 정직 산정 + sub-task 분해.
  codegen 무변경(측정 + 문서만 — over-promise 금지).

### 안전
- vast RTSC 학습 pod 미접촉. fire = 무료 pool ubu-2 RTX 5070($0). codegen 무변경.
- `.cu`/`.ptx` 는 /tmp(ubu-2)·archive/fires(repo) 에서만. repo root 손작성 0.
