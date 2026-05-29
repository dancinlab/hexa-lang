# GPU-ROOFLINE — append-only step log

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
