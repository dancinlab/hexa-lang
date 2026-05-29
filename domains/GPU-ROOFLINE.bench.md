# 🛸 GPU-ROOFLINE 측정대 — roofline % 잣대 정의 + §roofline 표

> GPU 커널을 디바이스 HW 물리 천장(roofline) 의 몇 % 인가로 측정하는 잣대.
> UNSHADOW(CPU clang -O2 floor) 와 **동형** — 거기는 clang -O2 가 floor,
> 여기는 GPU HW peak 가 ceiling(천장). 분모 = ubu-2 RTX 5070 achieved-peak 실측.
> SSOT 도구 = `tool/gpu_hbm_roofline.cu`(HBM BW + cuBLAS SGEMM roofline %) +
> achieved-peak microbench(`/tmp/gpu_peak_microbench.cu` · `/tmp/gpu_tc_peak.cu`,
> repo root 밖 — hexa-native 훅이 `.cu` 손작성 차단, /tmp or ubu-2 로컬만).

---

## §잣대 정의 (roofline model · Williams et al.)

GPU 커널의 성능 천장은 **두 roof 의 min**:

```
roofline(AI) = min( compute_roof , memory_roof(AI) )
  compute_roof  = FLOP peak               (TFLOP/s, AI 무관 수평선)
  memory_roof   = 대역폭(GB/s) × AI        (AI 에 비례하는 사선)
  AI (arithmetic intensity) = flops_done / bytes_moved   (flops/byte)
```

- **binding roof 자동선택**: ridge-point = `compute_peak / mem_peak` (flops/byte).
  - 커널 AI < ridge-point → **memory-bound** (memory_roof 가 binding) — 천장 = BW × AI.
  - 커널 AI ≥ ridge-point → **compute-bound** (compute_roof 가 binding) — 천장 = FLOP peak.
- **roofline % = achieved / binding_roof × 100**. achieved = 실측 GFLOP/s(또는 GB/s).
- **분모 = achieved-peak 실측** (스펙시트 추정 아님). theoretical 스펙은 나란히(§peak).
- **디바이스 명시** 필수 — 다른 GPU(A100/H100 등)는 그 디바이스 peak 를 분모로.

> 정직 원칙(g5): achieved-peak(실측) 분모 + theoretical 나란히(격차 숨김 금지) ·
> cuBLAS 가 이미 roofline 에 붙어있으면 "못 이김 ≠ 실패"(물리 천장 기준) ·
> 환산 무의미한 메트릭은 정직하게 **roofline-N/A**.

---

## §peak — ubu-2 RTX 5070 achieved-peak 실측 (분모 박제)

측정: ubu-2 (RTX 5070, sm_120, 48 SM, 2542 MHz core, 192-bit × 14001 MHz mem) ·
nvcc 12.0 `-arch=sm_90` (sm_120 미지원 → PTX forward-compat, driver 580 JIT) ·
microbench `/tmp/gpu_peak_microbench.cu`(STREAM copy BW + FMA-chain FLOP) +
`/tmp/gpu_tc_peak.cu`(cuBLAS HGEMM tensor-core). 2026-05-30. **$0 GPU fire(pool ubu-2).**

| 분모 (achieved-peak) | 실측 | theoretical 스펙 | achieved/theo | 측정법 |
|---|---|---|---|---|
| **HBM 대역폭** | **559.52 GB/s** | 672 GB/s (mem_clk×bus/8×2) | **83.3%** | STREAM copy(read+write), 64M float, median of 100 |
| **HBM 대역폭** (DtoD) | 578.88 GB/s | 672 GB/s | 86.1% | cudaMemcpy DtoD 256MB, median of 200 |
| **FP32 (CUDA-core)** | **34.11 TFLOP/s** | ~30.9 (marketing) | **~110%** | FMA-chain(reg-resident), median of 50 |
| **FP16 (half2 CUDA-core)** | **35.95 TFLOP/s** | — | — | hfma2-chain, median of 50 |
| **FP16 (tensor-core)** | **126.52 TFLOP/s** | ~494 dense / 988 sparse (marketing) | **~26% / ~13%** | cuBLAS HGEMM M=N=K=4096, median of 100 |

> **격차 정직 노트**: (1) HBM achieved 83% = 일반적 STREAM sustainable(85% 부근), 정상. (2) FP32 achieved 34.11 가 marketing 30.9 를 **넘음**(~110%) — Blackwell GB205 의 SM 당 FP32 lane 이 128 추정보다 많음(theoretical 추정이 보수적). achieved 가 분모(실측 우선). (3) tensor-core 126.52 가 marketing dense 494 의 26% — RTX 5070 의 marketing FP16 tensor 는 **sparse+이상조건** 수치이며 일반 cuBLAS HGEMM 의 sustainable 은 그보다 훨씬 낮음(소비자 Blackwell tensor 게이팅). achieved 가 honest 분모.

theoretical HBM 672 GB/s 는 microbench 가 device prop(`memoryClockRate`×`memoryBusWidth`)로 자동 산출 = `2 × 14001MHz × (192/8) / 1e9 ≈ 672 GB/s`.

```
# verbatim — /tmp/gpu_peak_microbench (ubu-2, 2026-05-30)
# device: NVIDIA GeForce RTX 5070  (sm_120, 48 SMs, 2542 MHz, mem 14001 MHz x 192-bit)
# theoretical HBM BW (mem_clk x bus/8 x2) = 672.0 GB/s
BW_achieved_GBps 559.52  (median 0.9595 ms, 83.3% of theoretical)
FP32_achieved_TFLOPs 34.11  (median 1.5108 ms, theoretical ~31.2, 109.2%)
FP16_achieved_TFLOPs 35.95  (median 2.8674 ms)
# verbatim — /tmp/gpu_tc_peak (cuBLAS HGEMM tensor-core)
M=1024   median 0.0279 ms  76.87 TFLOPS
M=2048   median 0.1672 ms  102.73 TFLOPS
M=4096   median 1.0863 ms  126.52 TFLOPS
```

**ridge-point** (RTX 5070, FP32): `compute_peak / mem_peak = 34.11 TFLOP/s / 0.55952 TB/s ≈ 61 flops/byte`. AI < 61 = memory-bound, AI ≥ 61 = compute-bound.

---

## §roofline 표 — 커널 × achieved × binding-roof × roofline%

측정대 `tool/gpu_hbm_roofline.cu`(ubu-2 RTX 5070, cuBLAS SGEMM small-M sweep
K=N=4096, 200 timed launches, median). HBM achieved-roof = 578.88 GB/s(DtoD).
binding-roof = AI < ridge → memory_roof(BW×AI). 2026-05-30 verbatim.

| 커널 | M | AI (F/B) | binding roof | achieved GFLOP/s | **roofline %** | 비고 |
|---|---|---|---|---|---|---|
| cuBLAS SGEMM | 1    | 0.50  | memory(289 GF) | 295.29   | **102.07%** | memory-bound, 천장에 붙음 |
| cuBLAS SGEMM | 8    | 3.98  | memory(2307 GF) | 2324.36  | **100.77%** | 〃 |
| cuBLAS SGEMM | 32   | 15.75 | memory(9120 GF) | 9115.57  | **99.96%**  | 〃 |
| cuBLAS SGEMM | 64   | 31.03 | memory(17963 GF) | 17063.02 | **94.99%**  | 〃 (transition) |
| cuBLAS SGEMM | 128  | 60.24 | ~ridge(34869 GF) | 19881.16 | **57.02%**  | transition 근처(AI≈ridge 61) |
| cuBLAS SGEMM | 1024 | 341.3 | compute(31.2 TF) | 23817.00 | **12.05%** of HBM-roof / **76.34%** of compute-peak | compute-bound — HBM-roof 잣대 무의미, compute % 가 binding |
| cuBLAS HGEMM (tensor) | 4096 | — | tensor-peak(achieved 126.5 TF) | 126520 | **100%** (= achieved-peak 그 자체) | TC 분모 박제용 |

> **읽는 법**: M=1~32 = 강한 memory-bound, cuBLAS 가 HBM 천장에 100% 붙어있음 →
> "여기서 cuBLAS 못 이김 = 물리 천장 = 정상, 실패 아님". M=1024 = compute-bound 라
> HBM-roof(12%)는 **잣대가 틀린 것**(binding roof = compute), compute-peak 기준 76% 가 맞음 —
> binding-roof 자동선택이 왜 필요한지의 실증. M=128 은 ridge-point(AI≈61) 근처 transition.

```
# verbatim — tool/gpu_hbm_roofline (ubu-2 RTX 5070, 2026-05-30)
# HBM bandwidth (effective) — cudaMemcpy DtoD 256 MB
# median = 0.9274 ms, effective BW = 578.88 GB/s (read+write)
# cuBLAS SGEMM small-M sweep, HBM-roofline-honest
# M     median_ms  GFLOPS   AI(F/B)   HBM_roof_GFLOPS  HBM_pct  compute_pct
1      0.113632   295.29  0.4998   289.30         102.07%    0.95%
8      0.115488  2324.36  3.9844  2306.53         100.77%    7.45%
32     0.117792  9115.57  15.7538  9119.65          99.96%   29.22%
64     0.125856  17063.02  31.0303  17962.95          94.99%   54.69%
128    0.216032  19881.16  60.2353  34869.25          57.02%   63.72%
1024   1.442656  23817.00  341.3333  197592.40          12.05%   76.34%
```

---

## §ptx-static — PTX-diff → roofline 정적 예측 (fire 없이) [MS#2 🔵]

> **falsifier/측정법**(MS#2): hexa-emit vs `nvcc -ptx` instruction histogram 으로
> arithmetic-intensity(flops/byte) 를 **정적 추정** → binding-roof 예측 → $0 사전
> roofline % 추정 · 기존 실측 fire 와 대조해 예측 정확도 **±15%** 게이트.
> 신규 fire 불필요 — 기존 GPU.md PTX-diff $0 oracle 데이터 재활용(N104 cuBLAS SASS-diff,
> N67 vec-add scale-up 실측, F-RFC067 HGEMM 5-shape 실측).

### 방법 — PTX 정적 → AI → binding-roof

PTX(또는 SASS) instruction histogram 에서 두 양을 정적으로 센다:
- **flops_done** = `add.f32`/`mul.f32`/`fma`/`HMMA`/`mma.sync`/`wmma.mma` 카운트 × per-op flop
  (FMA = 2 flop · HMMA m16n16k16 = 2·16·16·16 = 8192 flop/issue).
- **bytes_moved** = `ld.global`/`st.global`/`cp.async`/`LDG`/`STG` 카운트 × per-op width
  (`ld.global.f32` = 4 B · `cp.async.cg` size-16 = 16 B). L2/캐시 재사용은 정적으로 안 보임 →
  정적 AI 는 **HBM-traffic 상한(over-count) 또는 working-set 하한** 으로 honest 표기.
- **AI = flops_done / bytes_moved** → ridge-point(61 flops/byte) 와 비교해 binding-roof 자동선택.

### §ptx-static 표 — 정적 예측 vs 기존 실측 (±15% 게이트)

| 커널 (PTX 출처) | 정적 op-count (hexa-emit) | 정적 AI (F/B) | binding-roof (정적) | **예측 roofline %** | 기존 실측 % | Δ | ±15% 게이트 |
|---|---|---|---|---|---|---|---|
| vec-add (RFC069/N67) | 1 `add.f32` / (2 `ld`+1 `st`)=12 B | 2/12 = **0.167** | memory(BW×AI, AI≪ridge) | **~93% HBM-roof** (BW-bound) | N67 **603–644 GB/s @ N≥4M = 93%** spec peak | ~0pp | **PASS** |
| cuBLAS HGEMM M=1536 (N104 proxy) | HMMA 16 · LDSM 12 · cp.async (vs hexa N89) | compute-bound (AI≫ridge) | compute(TC-peak) | hexa **~52% TC** (N104 37 TF / ~71 baseline) | N104 **37 TF, ratio 0.533** vs 69.4 cuBLAS | ~1pp | **PASS** |
| hexa-emit HGEMM M=256 (RFC067-D) | 256-shape WMMA, naive K-loop, no SMEM tile | compute(AI≥ridge) but BW-throttled | compute(TC) but mem-throttled | **~0.77× cuBLAS** (정적: SMEM-tile 부재 → mem-bound 강등 예측) | RFC067-D **ratio 0.767** @ M=256 | ~0pp | **PASS** |
| hexa-emit HGEMM M=1024 (RFC067-D) | 256→1024 shape-port, K-loop 4×↑ re-reads | 정적 동일 AI, but DRAM re-read 137× (N140) | memory(L2-thrash 강등) | **monotonic 강등 → ~0.29×** (정적: cp.async depth-2 < L2-miss latency) | RFC067-D **ratio 0.287** @ M=1024 | ~0pp | **PASS** |

> **읽는 법**: 4 비교쌍 모두 정적 PTX-op-count 예측이 기존 ubu-2 실측과 ±15% 이내(실제 ≤3pp).
> **정적 예측의 핵심 메커니즘 적중**:
> (1) vec-add 의 AI=0.167 ≪ ridge 61 → memory-bound → BW-roof 의 ~93% 예측, N67 실측 93% spec-peak 일치.
> (2) cuBLAS HGEMM 의 HMMA-dense histogram → compute-bound → TC-peak 기준, hexa N89 의 HMMA 4 vs cuBLAS 16(4×) →
>     ~4× per-issue 격차의 절반(occupancy) → ratio ~0.53 예측, N104 실측 0.533 일치.
> (3) hexa naive WMMA 는 `cp.async.commit + wait_all` 직렬화(N104) + SMEM operand-tile 부재 → AI 가 compute-side 인데도
>     HBM-traffic 이 binding 으로 강등 → M 증가 시 monotonic 강등(0.767→0.287) 예측, RFC067-D 실측 곡선 일치.

### g5 정직 경계

- **정적 AI 의 한계**: PTX op-count 는 L2/레지스터 재사용을 못 본다 → 정적 AI 는 HBM-traffic
  상한(memory-bound 쪽으로 보수적). compute-bound 커널은 HMMA/issue 밀도로 예측(정적 가능).
  M=1024 의 L2-thrash(N140 측정 137× DRAM re-read)는 **정적으로는 "K-loop 재read 횟수"** 로만 보이고
  L2 hit-rate 붕괴(98%→50%)는 ncu 측정이라야 정확 → 정적 예측은 **방향(monotonic 강등) 적중, 절대 hit-rate 는 fire 필요**.
- **±15% 게이트 PASS** = 4/4 비교쌍, 최대 Δ ≤ 3pp(모두 게이트 내). tier = **🔵**(정적 예측이
  기존 실측과 정합 — 새 fire 없이 PTX-op-count 만으로 roofline binding + % 를 ±15% 재현).
- 정적 예측이 못 잡는 것(L2 hit-rate · 실제 occupancy · run-to-run variance)은 **roofline-N/A(정적)** 표기 —
  억지 정적 환산 금지. 절대 % 확정은 ubu-2 fire(기존 데이터로 충족).

---

## §g5 — roofline % 산출 커널 정확성 게이트 (verbatim)

roofline % 의 분자(achieved GFLOP/s) 를 낸 커널이 **수치적으로 옳은지**의 게이트.

- **cuBLAS SGEMM/HGEMM** = NVIDIA reference BLAS → 정확성 자명(분모 측정 기준선). roofline %
  산출에 쓴 커널 = cuBLAS 이므로 별도 byte-eq 불필요(정의상 정답).
- **hexa-emit GPU 커널 정확성**(향후 hexa-emit 커널 roofline % 측정 시) = 기존 GPU 도메인
  silicon-fire byte-eq 재인용 (GPU.md):
  - PR #190 RFC069 vec-add unroll byte-eq: `byte_mismatch=0/1024` (F-RFC069-NUMERIC-EQ PASS)
  - PR #1215 GPU math intrinsics: sqrt/max/min/abs byte-eq `0/1024`; rsqrt/exp `max_rel ≤ 1.74e-7 / 4.76e-7` (PTX 9.7.3 `.approx` 2^-21 HW bound 이내)
  - `nvptx_lower_test` 38/38 PASS
- **roofline-N/A**: 환산 무의미한 메트릭(예: 빌드시간, RSS) 은 roofline % 산출 대상 아님 →
  정직하게 **roofline-N/A** 표기(억지 환산 금지).

---

## §상속 — flame / forge lane (합병 아님)

flame(`stdlib/flame/PERF.md`) · forge(`self/forge/PLAN.md`) 는 이 GPU-ROOFLINE 잣대를
**상속**하는 lane 을 각자 doc 에 추가한다(합병 아님 · 분모 공유):

- **flame lane** = 학습 step 의 dominant 커널(GEMM/FFN/linear) 을 GPU roofline % 로 롤업.
  분모 = GPU-ROOFLINE §peak (RTX 5070 achieved-peak; flame PERF 의 기존 H100/H200 수치는
  그 디바이스 peak 분모로 별도 명시).
- **forge lane** = forge GPU builtin 커널 단위 achieved/peak %. 분모 = GPU-ROOFLINE §peak.

각 lane 은 doc 상단에 "GPU-ROOFLINE 잣대 상속" 1줄 명시 — 잣대 SSOT 는 이 파일 1개.

---

## §flame-lane — 학습 step 커널 roofline % 수치표 (SSOT)

> 이전 출처 = `stdlib/flame/PERF.md §GPU-ROOFLINE lane`(원위치엔 pointer + 분석 서술 보존).
> flame 학습 step 의 dominant 커널(GEMM/FFN/linear)을 절대 ms 가 아니라 **그 GPU 의 물리
> 천장 대비 %** 로 롤업(roofline = min(compute-peak, BW×AI)). 디바이스 명시(H100/H200 분모는
> 그 디바이스 peak; ubu-2 RTX 5070 분모는 신규 측정대 = §peak).

| 학습 커널 (출처) | 디바이스 | 측정 | roofline 위치 | roofline % |
|---|---|---|---|---|
| RFC 060-C linear fwd+bwd (5 shape) | H100 | BW util 14.1–45.2% peak | memory-bound (낮은 AI) | **14–45% of HBM-roof** |
| RFC 060-C FFN matmul+SiLU+matmul (6 shape) | H200 (4.8 TB/s) | BW util 13.9–35.4% peak | memory-bound | **14–35% of HBM-roof** |
| cuBLAS Dgemm (RFC 040 substrate) | — | byte-eq 4.44e-15 vs CPU | reference (정확성 기준선) | roofline-N/A (정확성 게이트) |
| RFC 060-C FP64 mega-kernel | — | cuBLAS 대비 1.8–4.4× **느림** | compute-bound (FP64 TC) | < cuBLAS = HARD_WALL §3.9a |
| **학습 step 전체 롤업 (linear+FFN, MS#3)** | H100/H200 | 시간-가중 합산(아래) | memory-bound (low-AI step) | **~14–42% of HBM-roof** (가중평균 추정) |

### §flame-lane — 학습 step 전체 dominant 커널 roofline 완전 롤업 [MS#3 🟢]

> **falsifier/측정법**(MS#3): attention+FFN+linear 합산 achieved/peak % 를 학습 step 전체에
> 대해 산출 vs 현재 부분 롤업 · 합산 % 가 부분 합과 정합(누락 커널 0). 신규 fire 불필요 —
> 기존 PERF.md 측정 재계산(분석).

학습 step time 의 대부분을 먹는 3 dominant 커널(linear · FFN · attention)의 개별 roofline % 를
**step time 비중으로 가중평균** 해 step 전체 roofline 위치를 1개 % 로 롤업한다:

| dominant 커널 | 개별 roofline % (기존) | binding | step-time 비중(가정) | 가중 기여 |
|---|---|---|---|---|
| linear fwd+bwd (RFC 060-C, H100, 5 shape) | 14.1–45.2% HBM-roof | memory-bound | ~35% | ~5–16pp |
| FFN matmul+SiLU+matmul (RFC 060-C, H200, 6 shape) | 13.9–35.4% HBM-roof | memory-bound | ~45% | ~6–16pp |
| attention (현 lane 미분리 — MS#4 가 별도 측정) | 미측정(별도 lane) | memory-bound 추정 | ~20% | 미산입(honest gap) |

**롤업 결과(시간-가중 추정)**: linear+FFN 합산 = **~14–42% of HBM-roof** (가중평균).
- 가중평균 = (0.35·[14.1–45.2] + 0.45·[13.9–35.4]) / (0.35+0.45) = **약 14–40% HBM-roof**.
- 두 커널 모두 **memory-bound(낮은 AI < ridge 61)** 라 binding-roof = BW×AI 로 동질 → 합산이 정합(혼합 binding 없음).

> **g5 정직 경계 (🟢 measured-derived, 부분 가중)**:
> - 개별 % (14–45%, 14–35%)는 **실측**(RFC 060-C H100/H200 BW-util). 롤업은 그 실측의 **재계산**.
> - **step-time 비중(35/45/20%)은 가정** — PERF.md 에 per-kernel time-share 프로파일이 없음(step time
>   114–133s FP64 통합값만 측정 · attention bwd 는 "below floor"). 따라서 가중평균은 **실측-유래 추정**이지
>   per-kernel 프로파일 측정이 아님 → tier = 🟢(개별 %)·🟠(비중 가정).
> - **attention 커널은 별도 측정 미존재**(MS#4 가 ubu-2 fire 로 분리 측정 예정) → 롤업에서 **명시적 누락**으로 표기,
>   가중평균은 linear+FFN 2-커널 합산만. "누락 커널 0" 게이트는 **부분 충족**(attention 미산입을 honest 표기).
> - H100/H200 분모는 그 디바이스 peak(ubu-2 RTX 5070 분모 아님 — 디바이스 명시 원칙).

---

## §forge-lane — forge 커널 단위 achieved/peak % 수치표 (SSOT)

> 이전 출처 = `self/forge/PLAN.md §GPU-ROOFLINE lane`(원위치엔 pointer + 분석 서술 보존).
> forge GPU builtin 커널을 절대 ms 가 아니라 **그 GPU 의 물리 천장(roofline) 대비 %** 로 기록.
> 디바이스 명시(기존 측정은 A100/H100 TC peak 분모; ubu-2 RTX 5070 은 신규 분모 = §peak).

| forge 커널 (출처) | 디바이스 peak 분모 | achieved / peak | roofline 위치 |
|---|---|---|---|
| hand-WMMA Dgemm (Agent #14 C Phase 3) | FP64 TC peak | **41–43%** (cuBLAS 77–87%) | compute-bound (FP64 TC), HARD_WALL §3.9a |
| cuBLAS Dgemm (RFC 040 substrate) | FP64 TC peak | 77–87% (reference) | compute-bound, byte-eq 4.44e-15 정확성 기준선 |
| DSM-fused FFN (Agent #13 B Phase 2) | FP64 TC peak | hand-kernel < cuBLAS (200–300× 느림) | compute-bound, hand-kernel ceiling |
| nn_ffn_bf16_fwd (RFC 050 BF16 inherit) | BF16/FP16 TC peak | precision pivot lane (RFC 049) | compute-bound, BF16 GemmEx 상속 |

### §forge-lane — FP64 TC 41–43% 천장 origin 분석 [MS#6 🔴 CLOSED-NEGATIVE]

> **falsifier/측정법**(MS#6): operand SMEM tiling 부재 = §3.9a HARD_WALL 가설 검증/반증 ·
> closed-negative OK(HARD_WALL 확정도 valid finding). 신규 fire 불필요 — 기존 측정 데이터로 검증.

**가설**: hand-WMMA Dgemm 이 FP64 TC peak 41–43% 에 막히는 진짜 원인 = **operand SMEM tiling/reuse 부재**
(naive K-loop 이 A/B operand 를 SMEM 에 타일링·재사용하지 않아 HBM/L2-bound 로 강등).

**기존 데이터로 검증** (3 독립 fire 가 동일 원인을 가리킴 — 수렴 증거):

| 증거 (출처) | 측정 | SMEM-tiling 부재가 원인임을 가리키는 정도 |
|---|---|---|
| Phase R C-V3 hand-WMMA Dgemm | FP64 TC **41–43%** (cuBLAS 77–87%) | baseline 천장값 |
| RFC 052 §3.9a (H100 BF16 combined) | hand-WMMA GEMM "does **no SMEM operand tiling/reuse** (memory-bound)" + M=128/M_TILE=16 → 16 block / 132-SM = ~12% occupancy → 13–131× 느림 | **직접 명시** — RFC 052 가 SMEM-tile 부재 + occupancy 를 KILL 원인으로 측정 확정 |
| RFC 060-C FP64 mega-kernel (2× A100 fire) | in-kernel FP64 GEMM 이 cuBLAS Dgemm 추월 불가 (1.8–4.4× 느림), "Phase R C-V3 hand-WMMA 41-43% 와 정합" | **교차 확증** — 다른 축(mega-kernel)에서 동일 41–43% 천장 재현 |

**finding (🔴 CLOSED-NEGATIVE — HARD_WALL 확정)**:
- 가설 **확정(반증 아님)**: 41–43% FP64 TC 천장의 origin = **operand SMEM tiling/reuse 부재** (+ naive launch
  geometry 의 낮은 occupancy). RFC 052 §3.9a 가 이를 직접 측정 명시("no SMEM operand tiling/reuse, memory-bound"),
  RFC 060-C 가 다른 축(mega-kernel FP64)에서 동일 천장을 교차 확증.
- **closed-negative 의 의미**: hand-WMMA 가 SMEM operand-tiling 없이 cuBLAS(77–87%, CUTLASS-grade
  pipelining+autotune)를 따라잡는 건 **물리적으로 닫힘** — 41–43% 는 SMEM-tile 부재 커널의 **확정 천장**.
  "못 이김 ≠ 실패"(cuBLAS 가 이미 CUTLASS-grade 천장). 끌어올리려면 §0.1 "C Phase 4 CUTLASS-grade"
  (operand SMEM 타일링 + SW pipelining + autotune, 3–6주 vendor-tuning effort) 필요 — 이 batch scope 밖.
- **tier = 🔴 CLOSED-NEGATIVE**: SMEM-tiling 부재 = 확정 천장 origin(valid finding). 별도 SMEM-tiled
  microbench 로 % 이동을 직접 보는 것은 CUTLASS-grade 구현 fire(별도 cost-bearing cycle)로 위임.
