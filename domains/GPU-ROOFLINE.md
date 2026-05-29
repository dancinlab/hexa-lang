# GPU-ROOFLINE — current state

@title: 🛸 GPU-ROOFLINE — HW 물리 천장(roofline) % 잣대

@goal: GPU·flame·forge 의 모든 dominant 커널을 디바이스 HW 물리 천장(roofline = min(compute,memory roof) · 분모 = achieved-peak 실측)의 몇 % 인지로 측정해 천장 대비 위치를 확정하고, 도달 가능한 천장까지 끌어올린다. cuBLAS 가 이미 천장이면 '못 이김 ≠ 실패' 로 정직 표기 · hexa-emit 커널은 variable-shape 로 확장해 직접 % 를 연다.

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
| **forge (커널)** | hand-WMMA Dgemm 41–43% FP64 TC peak(cuBLAS 77–87%) = compute-bound HARD_WALL §3.9a · hexa-emit WMMA HGEMM shape sweep ratio 0.994→0.292(128→1024, byte-eq 0) = 0.767 은 shape 의존 | `.bench.md §forge-lane · §wmma-shape-sweep` |

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
- [x] 2. 🔵 **GPU**: PTX-diff → roofline 정적 예측 (fire 없이) — **PASS** 4/4 비교쌍(vec-add·cuBLAS HGEMM·hexa HGEMM M=256/M=1024) 정적 PTX-op-count 예측이 기존 ubu-2 실측과 ±15% 이내(실제 ≤3pp): AI 0.167 vec-add→93% BW-roof / HMMA-dense→0.53 cuBLAS-ratio / SMEM-tile 부재→monotonic 강등 0.767→0.287 모두 적중. 정적 한계(L2 hit-rate·occupancy)=roofline-N/A 표기. 상세 = GPU-ROOFLINE.bench.md §ptx-static
- [x] 3. 🟢 **flame**: 학습 step 전체 dominant 커널 roofline 완전 롤업 — linear(14–45%)+FFN(14–35%) 시간-가중 합산 = **~14–42% of HBM-roof**(둘 다 memory-bound 동질 → binding 정합). 🟢 개별 %는 실측-유래·🟠 step-time 비중(35/45/20%)은 가정(PERF.md per-kernel 프로파일 부재) · attention 커널은 별도 측정 미존재(MS#4)로 **명시적 누락** 표기("누락 0" 게이트 부분충족). 상세 = GPU-ROOFLINE.bench.md §flame-lane
- [x] 4. 🟢 **flame**: attention(flash-attn류) 커널 별도 roofline lane — **2026-05-30 ubu-2 RTX 5070 $0 fire**(`/tmp/flame_attn_roofline.cu`, cuBLAS QKᵀ+PV @ T=1024·hd=64·nh=12). **AI=28.44 F/B < ridge 61 → memory-bound**; attn-core achieved 8597 GFLOP/s = **52.1% of HBM-roof**(BW×AI, DtoD)/54.0%(STREAM). flame attention = CPU farr 스칼라(decoder_block_lib.hexa:363) — GPU 설계는 QKᵀ·PV→cuBLAS·softmax→CPU(forge masked-attn 커널 부재). flash-attn 아님(S materialize → AI 천장). 상세 = `.bench.md §attention-lane`
- [x] 5. 🟢 **forge**: WMMA variable-shape roofline (현 256-shape-locked 0.767) — **2026-05-30 ubu-2 RTX 5070 $0 fire**(`/tmp/ms5_host.cu`, cuBLAS GemmEx f16→f32 동shape). shape sweep M=N=K∈{128,256,512,1024} forge/cuBLAS ratio = **0.994 → 0.786 → 0.448 → 0.292** 단조 강등 → **0.767 은 강하게 shape 의존**(M=128 parity launch-bound, M↑ 하며 SMEM-tile 부재로 강등). **byte-eq max|Δ|=0 全 shape**(N4 가 빠뜨린 정확성 게이트 추가). honest: M=256 만 compiler-emitted(256-locked, MS#1 의존), 128/512/1024 = 동일 microcode hand-emit shape-port. "cuBLAS 못 이김 ≠ 실패"(SMEM-operand-tile 부재 = MS#6 동일 origin). 상세 = `.bench.md §wmma-shape-sweep`
- [x] 6. 🔴 **forge**: FP64 TC 41–43% 천장 origin 분석 — **CLOSED-NEGATIVE**: origin = **operand SMEM tiling/reuse 부재**(+ naive launch occupancy) 확정. RFC 052 §3.9a 가 직접 측정 명시("no SMEM operand tiling/reuse, memory-bound"), RFC 060-C FP64 mega-kernel(2× A100)이 다른 축에서 동일 41–43% 교차 확증. SMEM-tile 없이 cuBLAS(77–87% CUTLASS-grade) 따라잡기 = 물리적 닫힘 = "못 이김 ≠ 실패". 끌어올림=C Phase 4 CUTLASS-grade(3–6주, batch 밖). 상세 = GPU-ROOFLINE.bench.md §forge-lane
- [ ] 7. 🌐 **공통**: 멀티디바이스 분모 (A100/H100 추가) — 현 분모는 RTX 5070 1개. **falsifier/측정법**: 측정 pod(preapproved)서 디바이스별(A100/H100) achieved-peak microbench(BW·FP32·FP16-TC) · theoretical 스펙 나란히 · `.bench.md §peak` 에 디바이스별 분모 행 추가 · vast RTSC 학습 pod 미접촉
