# 🛸 GPU-ROOFLINE — 쉬운 설명 (7-element)

> GPU 커널이 "그 하드웨어로 물리적으로 낼 수 있는 최대"의 몇 % 인지 재는 잣대.

---

## 🛸 GPU-ROOFLINE — HW 물리 천장 잣대

- 아이콘: 🛸
- 이름: **GPU-ROOFLINE** (HW 물리 천장 % 잣대)
- 별칭: "지붕(roofline) 까지 몇 %" · GPU 천장 잣대 · achieved/peak %
- 한 줄: GPU 커널 속도를 "절대값(ms)" 이 아니라 **그 GPU 가 물리적으로 낼 수 있는 최대치(roofline)의 몇 %** 로 잰다. roofline = min(연산 천장 FLOP-peak, 메모리 천장 = 대역폭 × 연산밀도). UNSHADOW 가 CPU 에서 "clang -O2 가 바닥(floor)" 이듯, 여기는 "GPU HW peak 가 지붕(ceiling)".
- 하는 일: 커널마다 (옮긴 바이트수, 한 FLOP수) → 연산밀도(AI) → 두 천장 중 낮은 쪽(binding roof) 자동선택 → achieved/binding-roof % 보고. 분모(천장)는 ubu-2 RTX 5070 에서 **직접 실측**(스펙시트 추정 아님).
- 비유: 자동차를 "시속 몇 km" 가 아니라 "이 도로의 제한속도(=물리 천장) 의 몇 %" 로 재는 것. 막힌 도로(memory-bound)에선 제한속도 자체가 낮으니 거기 붙으면 100% — 그 이상은 물리적으로 불가능.
- 비교: 절대 ms = 디바이스마다 무의미 / roofline % = **디바이스 천장 대비라 공정**, "더 못 가는 게 정상인지(천장)" vs "여유 있는데 못 가는지(최적화 여지)" 를 구분.

---

## 왜 "못 이김 ≠ 실패" 인가 (핵심 정직 원칙)

```
        ┌─────────────────────────────────────────────┐
연산천장 │  compute_roof = FLOP peak (TFLOP/s)           │  ← AI 크면 여기 막힘
(수평선) │  RTX 5070 achieved: FP32 34.1 · TC 126.5 TF   │
        ├─────────────────────────────────────────────┤
메모리천장│  memory_roof = 대역폭 × AI (사선)             │  ← AI 작으면 여기 막힘
(사선)   │  RTX 5070 achieved: 559 GB/s (theo 672 의 83%)│
        └─────────────────────────────────────────────┘
   ridge-point = compute_peak / mem_peak ≈ 61 flops/byte
   AI < 61 → memory-bound (대역폭이 천장) · AI ≥ 61 → compute-bound
```

- cuBLAS SGEMM 은 작은 M(memory-bound)에서 **HBM 천장의 100% 에 이미 붙어있다**(M=1 102% · M=32 100%). 이건 cuBLAS 가 잘해서가 아니라 **물리적으로 그 이상 불가능**한 영역. → "hexa 가 여기서 cuBLAS 못 이김 = 실패 아님 = 천장임"(정직 표기).
- M=1024(compute-bound)에선 HBM-roof 12% 가 **잣대가 틀린 것** — binding roof 가 compute 라 compute-peak 의 76% 가 맞는 숫자. binding-roof 자동선택이 왜 필요한지의 실증.

---

## 측정 증거 (ubu-2 RTX 5070 · $0 fire · 2026-05-30)

| 분모 (achieved-peak 실측) | 값 | theoretical | 격차 |
|---|---|---|---|
| HBM 대역폭 | 559.52 GB/s | 672 GB/s | 83.3% (정상 STREAM) |
| FP32 (CUDA-core) | 34.11 TFLOP/s | ~30.9 marketing | ~110% (achieved>marketing) |
| FP16 (tensor-core) | 126.52 TFLOP/s | ~494 dense marketing | ~26% (marketing=sparse 이상조건) |

| 커널 (cuBLAS SGEMM) | AI | binding roof | roofline % |
|---|---|---|---|
| M=1 | 0.50 | memory | 102% (천장) |
| M=32 | 15.8 | memory | 100% (천장) |
| M=128 | 60.2 | ~ridge | 57% (transition) |
| M=1024 | 341 | compute | 76% of compute-peak |

> **요약 한 줄**: GPU 커널 속도는 절대 ms 가 아니라 "이 GPU 물리 천장의 몇 %" 로 잰다.
> 분모는 RTX 5070 에서 실측(대역폭 559 GB/s · FP32 34 TF · TC 126 TF). cuBLAS 가
> memory-bound 영역에서 100% 붙어있는 건 **물리 천장**이라 못 이기는 게 정상.
> flame(학습)·forge(커널)는 이 잣대를 **상속**(합병 아님) — 각자 doc 에 roofline 표, 분모 공유.
