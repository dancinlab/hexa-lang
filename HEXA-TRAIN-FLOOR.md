@title: 🐢 HEXA-TRAIN-FLOOR — "거북이 학습기 바닥"
@goal: hexa-native 학습기를 production scale에서 feasible하게 — step-rate floor를 물리 한계(roofline)까지 끌어올려 closure. 추론은 AKIDA-int4 순수 유지(g1), 학습 경로만 대상.

# HEXA-TRAIN-FLOOR — current state

hexa-native 트레이너 throughput이 production scale에서 🔴 INFEASIBLE.
DECODER M5 STEP_RATE_LOG 실측 기준 baseline:

| 지표 | 값 | 의미 |
|---|---|---|
| step-rate | 0.28 step/s (1.99 s/step) | 너무 느림 |
| production 환산 | 77~122 GPU-days | 사실상 1회 학습 불가 |
| 판정 | 🔴 INFEASIBLE | scale에서 hexa-native 학습 막힘 |

## M1~M7 1차 사이클 결과 (2026-05-30 · static 🟠 → M7 RTX 5070 실측 일부 🟢 승격)

M7 실측(ubu-2 RTX 5070, $0): **M4 roofline · M6 fp32 lever = 🟢 CONFIRMED** (관측 0.165 step/s ≈ 예측 0.15 · fp32/fp64 42~50× ≈ 예측 44×). M2/M3 게이트 메커니즘 🟢이나 키가 rows 기준이어야 함이 실측으로 정정됨(→ M8). M1/M3 RSS-churn 실효 = 🟢 MEASURED (2026-05-30, PR #2175): farr 버퍼 hxlcl no-op-free 가 진짜 원인 — option-b real-libc 우회로 per-step RSS +256MB → 0MB/step 완전 평탄화(ubu-2, verdict `M1M3-hxlcl-free-fix.txt`). A100 헤드룸만 🟠 유지(deferred).


| PR | 닫은 것 | 메커니즘 |
|---|---|---|
| #2122 | M2 + M3 (동일 root) | gemv d-threshold 게이팅 — d<128이면 cuBLAS 우회 on-device 커널. #2017/#2018 회귀(d=64서 sync>cuBLAS) 직접 차단. env `HEXA_GEMV_CUBLAS_MIN_DIM` |
| #2123 | M1 churn 보너스 FIX | 시작 시 `mallopt(M_MMAP/M_TRIM_THRESHOLD,256KiB)` → 큰 farr가 mmap-backed → `free()` 즉시 munmap. env `HEXA_FARR_TRIM` |
| #2127 | M4 instrument + roofline | `hexa_rss_trace_on_free`(env `HEXA_RSS_TRACE`) + roofline 분석 |
| #2124 | M5 측정대 | `tool/train_floor_bench.hexa` A/B step-rate 하니스 (`--plan`/`--ledger`) |

## 🔑 M4 핵심 발견 — 진짜 바닥은 fp64 정밀도 (sync/메모리 아님)

roofline 분석 (d768·12L fp64: P=104.2M, FLOPs/step=3.03e12, AI=207 FLOP/byte):

| GPU | fp64 floor | 관측 대비 | 결론 |
|---|---|---|---|
| A100 | 0.312 s/step (3.21 step/s) | 관측 1.99s = floor의 15.7% (6.4× 헤드룸) | occupancy 회수 여지 |
| RTX 5070 | 6.58 s/step (0.15 step/s) | post-#2017/#2018(0.156~0.18) **정확 일치** | 이미 fp64 천장 |

- 트레이너는 **COMPUTE-bound (fp64)** — memory/sync-bound 아님 (mem-only floor가 관측보다 100~300× 낮음).
- 최대 lever = **fp64 → fp32/bf16(TensorCore)** — A100 32× · 5070 44× 천장 인하.
- M2/M3(sync)·M1/M3(churn) fix는 fp64 천장 *내부* occupancy(16%→100%) 회수까지만. 천장 자체는 정밀도가 박는다.

## 경계 (변경 금지)

- 추론 = AKIDA-int4 순수 유지 (g1 핵심).
- 학습만 PyTorch 우회 가능 (CLM d5/B0 트랙). 이 도메인은 hexa-native 학습 경로 자체의 floor를 다룸.

## milestones

- [x] M1 RSS churn 200~325MB/step source localize — AdamW 外 CUDA/runtime-side 지점 특정
- [x] M2 작은 행렬(d=64) GPU↔CPU sync 오버헤드 제거 — fused/batched dispatch or d-threshold 게이팅
- [x] M3 #2017/#2018 회귀 분석 — 왜 3× 느려졌나, cuBLAS gemv를 d-threshold로 조건부 활성
- [x] M4 step-rate floor 측정 — roofline 기준 물리 천장 산출 (끝 = 100% 아닌 물리 한계)
- [x] M5 PyTorch 대비 throughput parity 측정대 구축 — A/B 측정 + verdict 영속
- [x] M6 fp64 → fp32/bf16(TensorCore) 학습 경로 — M4가 지목한 진짜 천장 lever (A100 32×·5070 44× floor 인하). 추론 int4와 분리된 학습-mixed-precision 트랙
- [x] M7 라이브 측정으로 1차 사이클 🟠 → 🟢 승격 — RTX 5070(ubu-2, $0) 실측: M4 roofline(0.165≈0.15 예측)·M6 fp32 lever(42~50×≈44×)·M2/M3 게이트 메커니즘 = 🟢 승격(#2132, verdict `.verdicts/hexa-train-floor/`). 잔여 = M8 + deferred
- [x] M8 M2/#2122 게이트 키 정정 — 실측상 진짜 판별자는 `cols`(d) 아니라 **rows(출력차원=#blocks)**. d=64라도 rows=768이면 cuBLAS 우세 → 현 게이트 d=64서 회귀 위험. `rows·cols`(총 work) 기준 재키잉 (부분 반증 fix, shipped #2122 회귀 가드)

## deferred

- ~~M1/M3 RSS-churn 실효(🟠)~~ → 🟢 CLOSED (2026-05-30, PR #2175): 진짜 원인은 mallopt(#2123) dead-code 가 아니라 farr 가 hxlcl no-op-free arena 에 묶인 것. option-b real-libc 우회로 +256MB/step → 0MB/step 평탄화 실측. mallopt 가 무관했던 이유 = hxlcl 이 glibc arena 를 raw mmap 으로 우회. verdict `M1M3-hxlcl-free-fix.txt`.
- A100 occupancy 헤드룸(M4: fp64 floor 의 6.4×) = 유료 A100 pod 필요 → 미측정 유지.
- cross-repo anima 트레이너를 새 hexa runtime(#2122~#2130)으로 빌드 = runtime regen 블로커 → 별개 cycle(HALT 회피, deferred).
- `hexa_farr_free` 본체 1줄 call-site patch = 다음 edge-runtime.c regen 시 적용 (B9 #2065로 본체가 gitignored, runtime.h 주석에 patch-spec 명시됨).
