# HEXA-TRAIN-FLOOR M7 — 라이브 측정 마이크로벤치

1차 사이클(M1~M6) 🟠 클레임을 실제 GPU(RTX 5070, ubu-2 pool, $0)서 검증하기 위한
standalone 마이크로벤치. cross-repo anima 트레이너 전체 빌드(runtime regen 블로커)를
우회하고, emitter SSOT 의 생성 커널/게이트를 **byte-faithful 복제**해 각 fix 메커니즘을
직접 측정한다 (instrument-first / cheap-first).

| 파일 | 측정 축 | SSOT 복제 대상 | verdict |
|---|---|---|---|
| `m7_gemv_bench.cu` | M2/M3 gemv d-threshold 게이트 + M6 fp32 | `runtime_cuda_emit.hexa` `_hx_k_packed_gemv_offset[_f32]` + cublasDgemv(OP_T), HX_RR_BLOCK=256 | `.verdicts/hexa-train-floor/M7-gemv-dthreshold.txt` |
| `m7_gemm_roofline.cu` | M4 roofline + M6 fp32 ceiling-lift | cuBLAS DGEMM vs SGEMM (트레이너 dominant 비용) | `.verdicts/hexa-train-floor/M7-fp32-roofline.txt` |
| `m7_farr_rss.c` / `m7_farr_rss2.c` | M1/M3 HEXA_FARR_TRIM RSS-churn | `runtime_core_emit.hexa` `_hexa_init_malloc_tuning` mallopt 게이트 | `.verdicts/hexa-train-floor/M7-farr-trim-rss.txt` |

## 빌드 + 실행 (ubu-2 / RTX 5070)

```sh
# GEMV (3 path × contraction-dim sweep), rows = 출력 차원
nvcc -O3 -arch=sm_90 -lcublas m7_gemv_bench.cu -o m7_gemv_bench
./m7_gemv_bench 768 4000     # rows=768 reps=4000
./m7_gemv_bench 64  4000     # rows=64 (작은 출력차원 — on-device 가 cuBLAS 이김)

# GEMM roofline (fp64 vs fp32 throughput)
nvcc -O3 -arch=sm_90 -lcublas m7_gemm_roofline.cu -o m7_gemm_roofline
./m7_gemm_roofline

# farr RSS-churn A/B (glibc Linux)
gcc -O2 m7_farr_rss2.c -o m7_farr_rss2
./m7_farr_rss2 200            # OFF
HEXA_FARR_TRIM=1 ./m7_farr_rss2 200   # ON
```

## 핵심 결과 (raw = `.verdicts/hexa-train-floor/`)

- **M4 roofline 🟢**: 5070 fp64 GEMM 0.50 TFLOPs → 트레이너 fp64 floor 6.06 s/step
  (0.165 step/s) = M4 예측 6.58 s/step(0.15) 및 DECODER 관측 0.156~0.18 와 일치.
- **M6 fp32 lever 🟢**: fp32/fp64 = 42~50× (M4 예측 44×).
- **M2/M3 게이트 🟢(메커니즘) / 🟠(키)**: 작은 work 에서 on-device > cuBLAS 확인.
  단 진짜 판별자는 `rows`(출력차원=#blocks)지 `cols`(d)가 아님 → 게이트 재키잉 필요.
- **M1/M3 RSS-churn 🟠**: synthetic 미재현 — real anima 트레이너 RSS_TRACE fire 대기.
