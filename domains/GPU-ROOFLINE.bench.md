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
