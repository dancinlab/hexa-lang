# GPU-ROOFLINE — append-only step log

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
