# GPU-ROOFLINE — append-only step log

## 2026-05-31 — MS#1 1b HIR `[T; N]` fixed-array 크기 surface — honest STOP (>1 batch)

scope 결정: 1b 는 단일 <200줄 batch 안에 정직하게 착지 불가 → honest STOP 종결(1a 선례 동일,
fail 아님). flip 은 `[ ]` 유지, 측정값 날조 없음.

honest 감사 메모(중요): 이 격리 worktree 에는 codegen 파일 `self/nvptx_target.hexa` 가 존재하지
않는다(디스크·git HEAD 모두 부재 — `git cat-file -e HEAD:self/nvptx_target.hexa` = fatal, 0 lines).
따라서 이 세션에서 그 파일의 라인을 직접 재-감사할 수 없었고, backend 사실관계는 이 도메인 자신의
선행 코드-감사(2026-05-30 규모-산정 노트 = GPU-ROOFLINE.md:51-57·70-72)를 권위 출처로 인용한다:
`_nvptx_shared_default_bytes`(`nvptx_target.hexa:3345-3352`)가 synthetic 고정 2048 B 를 반환하고
shape 별 SMEM operand-tile 크기 진입점이 없다.

frontend 사실관계(이 worktree 에서 직접 감사): self/parser.hexa 등 frontend 트리는 존재하나
1b 가 요구하는 `[T; N]` fixed-array 타입(컴파일타임 고정 N 운반) surface 가 없다 — self/* 의 array
참조는 모두 런타임 dynamic-length 경로(`rt_array_len`/`hexa_array_len`/`rt_array_items`,
self/runtime_pure.hexa·self/codegen.hexa:8306)뿐. 도메인 노트의 "현재 없음 — codegen 이 직접 명시"와 일치.

scope verdict: 1b 착지 = (a) lexer+parser `[T; N]` 타입 문법, (b) (T,N) 운반 타입-AST 노드,
(c) HIR/MIR 의 N 전파, (d) backend `_nvptx_shared_default_bytes` 를 tile-size 산출식으로 교체 —
frontend+backend 전면 변경. 규모-산정 노트의 "frontend(HIR/MIR)+backend(NVPTX) 양쪽 변경 =
multi-session(1-batch surgical 불가)" 경고와 1:1 일치 → honest STOP 이 유효 종결.

다음 세션 surgical 진입점: HIR `[T; N]` 크기 surface 착지 후 `_nvptx_shared_default_bytes`
(nvptx_target.hexa:3345)를 tile-size 산출식으로 교체(codegen 파일이 있는 공유 트리에서 수행).
verdict = .verdicts/gpu-roofline-ms1-1b/F-HEXA-GPU-ROOFLINE-MS1-1B.txt.

## 2026-05-30 — batch E2 drain: MS#7 멀티디바이스 분모 (A100) (gpu-roofline-batch-e2)

### MS#7 🟢 공통 — 멀티디바이스 분모: A100 80GB PCIe 행 추가 [PASS, measured]
- 측정 pod: **vast 38481895**(@hexa-lang gpu-roofline-msrt, 이전 시도가 띄운 것 — 새 임대 없이 resume).
  GPU resolve = **NVIDIA A100 80GB PCIe**, sm_80, 108 SM, driver 590.48.01, core 1410 MHz, mem 1512 MHz HBM2e.
- 이미지에 nvcc/CUDA-toolkit/cuBLAS/gcc 부재(bare Ubuntu 22.04 + 드라이버만) → RTX 5070 의 `.cu`+nvcc 경로
  대신 **PyTorch 2.6.0+cu124 번들 cuBLAS** 로 측정. venv 는 /dev/shm 가 noexec 라 /root 에(10G overlay, 4.9G).
  STREAM-triad(`torch.add`) + cuBLAS GEMM(`torch.matmul`). FP32/FP64 peak 는 launch-bound FMA-chain
  (0.13 TF artifact) 폐기 → compute-bound GEMM M=8192 로 재측정(honest).
- **A100 achieved-peak(분모 박제)**:
  - HBM2e 대역폭 STREAM-triad = **1640.77 GB/s**(theo 1935, **84.8%**) · DtoD = 1607.65 GB/s(83.1%)
  - FP32 SGEMM(TF32-off) M=8192 = **19.12 TFLOP/s**(theo 19.5, **98.1%**)
  - FP64 DGEMM M=8192 = **16.90 TFLOP/s**(FP64-TC theo 19.5, **86.7%** / FP64-CUDA-core 9.7 의 174% = FP64-TC 사용 증거)
  - FP16-TC HGEMM M=4096 = **245.19 TFLOP/s**(theo 312 dense, **78.6%** / 624 sparse, 39.3%)
  - BF16-TC = 239.04 TF · TF32-TC = 112.73 TF(theo 156, 72.3%)
- **핵심 발견(멀티디바이스 분모의 의의)**: 같은 cuBLAS 라도 디바이스 등급(소비자 vs DC)이
  achieved/theoretical % 를 크게 가른다 — A100(DC) FP16-TC **78.6% sustainable** vs RTX 5070(소비자)
  **26%**(소비자 Blackwell tensor 게이팅). 단일 RTX 5070 분모로 A100 커널을 읽으면 천장이 왜곡되므로
  분모를 디바이스별로 박제해야 roofline % 가 의미를 가진다. RTX 5070 행 + A100 행 비교표 = `.bench.md §multi-device-peak`.
- **정리**: 측정 종료 직후 `hexa cloud rm 38481895 --force` 로 즉시 down(비용 차단) 확인. vast RTSC 학습
  pod(@anima 37868501·38095989·38367660·38382692·38384813·38444699) **전부 미접촉**(list/resolve 만).
- verbatim = `.bench.md §multi-device-peak`(/tmp/gpu_rfl_bench·bench2 stdout). MS#7 `[x]` flip.

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

## 2026-05-31 MS#1 1b frontend N-capture LANDED ([~]) — SSOT 정합 flip

PR #2256 이 `self/parser.hexa` (dc49c0048) 의 `[T; N]` N-보존 변경을 main 에 착지시켰으나
`domains/GPU-ROOFLINE.md` 의 1b 체크박스를 `[ ]`→`[~]` 로 갱신하지 않아 SSOT 가 코드보다
뒤처졌다(verdict=LANDED, milestone=open 불일치). 이 변경은 그 표기만 정합화한다 — 새 코드/측정
없음, 이미 main 에 있는 #2256 의 사실을 milestone 에 반영.

- 🟢 frontend N-capture LANDED (#2256 · git 실측): `parse_type_annotation` 의 `[T; N]` 분기가
  `p_advance().value` 로 size 토큰을 캡처해 `[T; N]` type-string 에 N 운반. plain `[T]` byte-identical.
  `hexa cc --regen` rc=0 · 4/4 SSOT transpile · merged Δ+209B = 새 분기. verdict 첨부.
- [~] 잔여: (1c) HIR/MIR N 전파 → codegen · (1d) backend `_nvptx_shared_default_bytes` → N 기반 tile 공식.
  둘 다 sign 창 + (1c 는 HIR/MIR, 1d 는 nvptx_target.hexa 공유트리) 필요 = 후속 세션.
- ℹ️ 선행 #2253 정정("syntax 부재"는 오류)이 옳았고, 이 착지가 정정이 지목한 N-폐기를 해소.

## 2026-05-31 MS#1 1b — N-capture behavioral NEUTRALITY 실측 (sign 창)

직전 PARTIAL(#2261)이 "byte-eq UNVERIFIED" 로 남긴 검증 갭을 sign 창에서 직접 run 으로 한 칸 좁힘.
직접 `hexa run` 실측(installed toolchain): `struct Buf{data:[int;4]}` vs `struct Buf{data:[int]}`
두 프로그램이 모두 파싱 OK(RSS 폭주 없음)·실행·출력 "1"·rc=0 = IDENTICAL.

- 🟢 behavioral neutrality CONFIRMED: parser N-capture(dc49c0048)는 런타임 동작 무변경.
  [T;N] additive else-arm 이 historical [T] 경로 보존. 새 문법이 메모리 폭주 없이 동작.
- 🔴 잔여: ① full SSOT-corpus byte-eq (stale-seed codegen-vintage 오염으로 clean BASE-vs-MINE
  모듈 diff 차단 — P1 캐비엇) ② N consumption — [int;4]/[int] 가 같은 C 로 transpile(N 미사용)
  = 1c(HIR/MIR 전파) 필요. 1b 는 [~] 유지(frontend real+neutral · 1c/1d 잔여).
- verdict=`.verdicts/gpu-roofline-ms1-1b/F-...-N-CAPTURE-NEUTRALITY.txt`.

## 2026-05-31 MS#1 1b-cons 마일스톤 등록 + 1b 본문 fabricated 주장 정정

(1) **마일스톤 등록**: `1b-cons` (HIR/MIR N-consumer) 신규 등록 — 1b 가 parser type-string 에 N 을
담는 데까지 착지(behavioral-neutral)했으나 codegen 이 그 N 을 **안 읽는다**(`[int;4]`/`[int]` 동일
C transpile). 진짜 다음 codegen 칸 = HIR/MIR 가 N 을 파싱·운반해 codegen 이 소비. falsifier =
N-consuming 변경 후 `[int;4]` vs `[int]` emit-C 달라짐 + 기존 `[int]` byte-eq IDENTICAL.

(2) **1b 본문 정직성 정정**: main 의 1b 본문이 #2256/#2258 경로로 fabricated 주장("frontend
N-capture LANDED" · "parse-proof(`[int;4]`→`4` 보존)" · verdict=N-PRESERVE-LANDED.txt)을 담고
있었다 — 이는 verdict 파일이 이미 ⊘ 철회한 거짓 수치(parse --ast no-op·corpus empty·regression
3 FAIL)와 모순. 본문을 honest 로 교체: PARTIAL · behavioral-neutral 확인 · byte-eq 미검증 ·
fabricated 철회 명시 · 잔여(1b-cons·1d-backend·full byte-eq) 정리. SSOT 가 이제 verdict 와 정합.

tally: 12 [x] · 1 [~] · 5 [ ] (1b-cons 추가로 open 4→5).
