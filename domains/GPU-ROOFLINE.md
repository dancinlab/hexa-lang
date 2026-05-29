# GPU-ROOFLINE — current state

@title: 🛸 GPU-ROOFLINE — HW 물리 천장(roofline) % 잣대

@goal: GPU 커널을 디바이스 HW 물리 천장(roofline = min(compute-roof, memory-roof)) 의 몇 % 인가로 측정하는 단일 잣대(SSOT) 를 세운다. 분모 = ubu-2 RTX 5070 achieved-peak 실측(대역폭 GB/s + FLOP TFLOP/s, fp32/fp16/tensor) · theoretical 스펙 나란히(격차 숨김 금지) · 측정 디바이스 명시. flame(학습)·forge(커널) 는 이 잣대를 **상속**하는 lane(합병 아님). UNSHADOW perf 측정대(clang -O2 floor) 와 동형 — 거기는 CPU clang -O2 가 floor, 여기는 GPU HW peak 가 ceiling.

## 전제 — roofline 잣대 (UNSHADOW 와 동형)

UNSHADOW 가 CPU 에서 "clang -O2 를 floor 로 상속, 그 위 hexa 우위를 측정" 했다면, GPU-ROOFLINE 은 GPU 에서 **HW 물리 천장(roofline) 을 분모로 박제하고 achieved/binding-roof % 를 측정**한다. 핵심 차이 = GPU 는 메모리-bound 영역에서 cuBLAS 가 이미 천장에 붙어있음 — "못 이김 ≠ 실패"(물리 천장 기준이라 못 이기는 게 정상, roofline % 로 정직 표기).

- **roofline = min(compute-roof, memory-roof)** (Williams et al.). compute-roof = FLOP peak (TFLOP/s). memory-roof = 대역폭(GB/s) × arithmetic-intensity(flops/byte). 커널 AI 로 binding roof 자동선택(ridge-point = compute-peak / mem-peak).
- **분모 = achieved-peak 실측**(ubu-2 RTX 5070, sm_120). theoretical 스펙 나란히. 디바이스 명시. 상세 = `GPU-ROOFLINE.bench.md §roofline`.
- **측정대 = 기존 GPU PTX-diff $0 oracle + ubu-2 $0 fire 재사용**. codegen 무변경(측정대 + 문서만).
- flame/forge 는 합병 아닌 **상속 lane** — 각자 doc(`stdlib/flame/PERF.md` · `self/forge/PLAN.md`)에 roofline 표를 추가, 분모는 GPU-ROOFLINE 공유. 상세 = `GPU-ROOFLINE.easy.md`.

## 3-lane 통합 (GPU · flame · forge — 수치 SSOT = GPU-ROOFLINE.bench.md)

roofline % 수치표는 모두 `domains/GPU-ROOFLINE.bench.md` 단일 SSOT 로 모았다(원본 PERF.md/PLAN.md 는 1줄 pointer + 분석/HARD_WALL 서술 보존). 잣대(분모)는 ubu-2 RTX 5070 achieved-peak 1개 공유.

| lane | 현황 (1줄) | 수치 SSOT |
|---|---|---|
| **GPU 커널** | cuBLAS SGEMM small-M M=1~32 = HBM-roof 100% 천장 붙음 · HGEMM-TC M=4096 = 126.52 TF achieved-peak 박제 | `.bench.md §peak · §roofline` |
| **flame (학습)** | RFC 060-C linear/FFN = 14–45% of HBM-roof(memory-bound) · FP64 mega-kernel = cuBLAS 미만(HARD_WALL §3.9a) | `.bench.md §flame-lane` |
| **forge (커널)** | hand-WMMA Dgemm 41–43% FP64 TC peak(cuBLAS 77–87%) = compute-bound HARD_WALL §3.9a | `.bench.md §forge-lane` |

## milestones

- [x] 🟢 ubu-2 RTX 5070 achieved-peak microbench 1회 실측 (분모 박제) — `/tmp/gpu_peak_microbench.cu`(nvcc 12.0 `-arch=sm_90` PTX forward-compat → sm_120 driver-JIT). **대역폭 559.52 GB/s**(STREAM copy, theoretical 672 의 83.3%) · **FP32 34.11 TFLOP/s**(FMA-chain) · **FP16(half2 CUDA-core) 35.95 TFLOP/s** · **FP16 tensor-core 126.52 TFLOP/s**(cuBLAS HGEMM M=4096, `/tmp/gpu_tc_peak.cu`). theoretical 나란히 = GPU-ROOFLINE.bench.md §peak. 디바이스 = NVIDIA GeForce RTX 5070, sm_120, 48 SM, 2542 MHz, 192-bit 14001 MHz mem. 상세 = GPU-ROOFLINE.log.md
- [x] 🟢 측정대 어댑터 — roofline 분모 계산(커널 메타 bytes/flops + GPU peak 상수 + binding-roof 자동선택 ridge-point + achieved/binding-roof %) 산출 절차를 `GPU-ROOFLINE.bench.md §roofline` 에 문서화. 기존 `tool/gpu_hbm_roofline.cu`(HBM BW + cuBLAS SGEMM AI-based roofline %) 재사용. 산출 = achieved_GFLOPS / (min(compute_peak, BW×AI)) × 100. 상세 = GPU-ROOFLINE.log.md
- [x] 🟢 §roofline 표 (커널 × achieved × binding-roof × roofline%) — cuBLAS SGEMM small-M sweep(ubu-2 실측): M=1 102%·M=8 101%·M=32 100%·M=64 95%·M=128 57%·M=1024 12% of HBM-roof(memory-bound 영역은 천장에 붙음). cuBLAS HGEMM(tensor) M=1024 76.87·M=2048 102.73·M=4096 126.52 TFLOP/s. 정직: cuBLAS 가 메모리-bound 영역에서 이미 roofline = "못 이김 ≠ 실패". 상세 = GPU-ROOFLINE.bench.md §roofline
- [x] 🟢 flame 롤업 lane — `stdlib/flame/PERF.md §GPU-ROOFLINE lane` 추가. 학습 step dominant 커널(GEMM/FFN/linear) 을 GPU roofline % 로 롤업(기존 PERF 의 H100/H200 BW-util 수치 재계산 + ubu-2 RTX 5070 분모 명시). 분모 = GPU-ROOFLINE 잣대 상속 1줄 명시. 상세 = stdlib/flame/PERF.md
- [x] 🟢 forge 커널 lane — `self/forge/PLAN.md §GPU-ROOFLINE lane` 추가. forge GPU builtin 커널 단위 achieved/peak %(hand-WMMA 41-43% FP64 TC peak·cuBLAS 77-87% 기존 측정 + RTX 5070 분모 명시). 분모 = GPU-ROOFLINE 잣대 상속 1줄 명시. 상세 = self/forge/PLAN.md
- [x] 🟢 g5 — roofline % 산출 커널 출력 정확성 verbatim 기록. cuBLAS = reference BLAS(정확성 자명) · 기존 hexa-emit GPU 커널 byte-eq(GPU.md PR #190/#1215 = byte_mismatch 0/1024, max_rel ≤ 1.74e-7) 재인용. 환산 무의미 메트릭 = roofline-N/A 명시. 상세 = GPU-ROOFLINE.bench.md §g5

## milestones — open frontier (7 구체 milestone · 각 falsifier+측정법 inline)

> 측정 fire 는 후속 /hexa-loop·/cycle 이 집는다(이 도메인 통합 PR 은 문서+milestone 까지).
> 측정 호스트 = ubu-2 RTX 5070($0 fire) · 멀티디바이스 분모는 측정 pod preapproved ·
> **vast RTSC 학습 pod 미접촉**(adopt/list 만). codegen 무변경.

- [ ] 1. 🔵 **GPU**: hexa-emit 커널 직접 roofline % (cuBLAS 아닌 hexa codegen 산출) — 현재 hexa-emit wmma 는 256×256 shape-locked(GPU.md PR #214, ratio 0.767 vs cuBLAS). **falsifier/측정법**: variable-shape WMMA emission(multi-session codegen) 후 hexa-emit 커널의 직접 achieved/peak % 측정 · byte-eq 게이트(byte_mismatch=0) · ubu-2 RTX 5070
- [ ] 2. 🔵 **GPU**: PTX-diff → roofline 정적 예측 (fire 없이) — **falsifier/측정법**: hexa-emit vs `nvcc -ptx` instruction histogram 으로 AI(flops/bytes) 정적 추정 → binding-roof 예측 → $0 사전 roofline % 추정 · 실측 fire 와 대조해 예측 정확도 **±15%** 게이트
- [ ] 3. 🟢 **flame**: 학습 step 전체 dominant 커널 roofline 완전 롤업 — 현재는 부분 롤업(linear/FFN 개별). **falsifier/측정법**: attention+FFN+linear 합산 achieved/peak % 를 학습 step 전체에 대해 산출 vs 현재 부분 롤업 · ubu-2 RTX 5070 · 합산 % 가 부분 합과 정합(누락 커널 0)
- [ ] 4. 🟢 **flame**: attention(flash-attn류) 커널 별도 roofline lane — 현 lane 엔 attention 커널 분리 없음. **falsifier/측정법**: ubu-2 attention 커널 achieved/peak % 측정 · memory-bound vs compute-bound binding 판정(ridge ≈ 61 대비 AI) · `.bench.md §flame-lane` 행 추가
- [ ] 5. 🟢 **forge**: WMMA variable-shape roofline (현 256-shape-locked 0.767) — 현 측정은 256 단일 shape. **falsifier/측정법**: shape sweep(128/256/512/1024)별 achieved/peak % vs cuBLAS · ubu-2 RTX 5070 · shape 별 ratio 곡선(0.767 이 shape 의존인지 판정)
- [ ] 6. 🔴 **forge**: FP64 TC 41–43% 천장 origin 분석 — hand-WMMA Dgemm 이 FP64 TC peak 41–43% 에 막힘. **falsifier/측정법**: operand SMEM tiling 부재 = §3.9a HARD_WALL 가설 검증/반증 · SMEM-tiled variant microbench 로 % 이동 여부 · closed-negative OK(HARD_WALL 확정도 valid finding)
- [ ] 7. 🌐 **공통**: 멀티디바이스 분모 (A100/H100 추가) — 현 분모는 RTX 5070 1개. **falsifier/측정법**: 측정 pod(preapproved)서 디바이스별(A100/H100) achieved-peak microbench(BW·FP32·FP16-TC) · theoretical 스펙 나란히 · `.bench.md §peak` 에 디바이스별 분모 행 추가 · vast RTSC 학습 pod 미접촉
