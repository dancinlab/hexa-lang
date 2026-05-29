# HEXA-TRAIN-FLOOR — log

Append-only history sister of `HEXA-TRAIN-FLOOR.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-30 — 🟢 M8 gemv 게이트 rekey — cols 기준 → rows 기준 (M7 회귀 가드, RTX 5070 실측)

M7이 #2122 게이트 키(`cols < HEXA_GEMV_CUBLAS_MIN_DIM`)를 부분 반증한 걸 닫음.
진짜 성능 판별자 = `cols`(내적 차원)가 아니라 **rows**(출력 차원 = on-device
커널의 #blocks). on-device 커널이 one-block-per-row 라 rows가 커지면 cuBLAS가
이김.

- [x] **재키잉**: `self/cuda/runtime_cuda_emit.hexa` `_hx_cuda_farr_packed_gemv_offset_gpu`
  host wrapper의 분기를 `cols < min_dim` → **`rows < min_rows`**(default 512)로 변경.
  env = 새 `HEXA_GEMV_CUBLAS_MIN_ROWS`(legacy `HEXA_GEMV_CUBLAS_MIN_DIM`은 rows
  alias로 back-compat 유지). M7 crossover 근거 주석 동봉. 도움 doc 코멘트(~L1235)도
  `rows`로 갱신. fp32(M6)·AKIDA-int4 경로 무손상(분기 위쪽 그대로).
- [x] **방식 = 순수 rows 기준** (rows·cols 총-work 아님): M7 표가 rows가 단독 판별자임을
  보임 — rows≤256이면 모든 cols(64~768)서 on-device 승, rows=768이면 모든 cols서
  cuBLAS 승. cols는 결정을 뒤집지 않음 → rows-only가 정답. default 512는 측정된
  win@256과 loss@768 사이.
- [x] **검증**: `hexa_real parse self/cuda/runtime_cuda_emit.hexa` → clean.
- [x] **실측 (ubu-2 RTX 5070, $0)** — `.verdicts/hexa-train-floor/M8-gate-rekey.txt`
  (g5 verbatim). source = `tool/train_floor_m7/m8_gate_rekey.cu`(rekey된 게이트
  decision + 동일 block-reduction 커널 + cublasDgemv byte-faithful 복제):
  - **M7 회귀 케이스 rows=768·cols=64 → 게이트가 cuBLAS 선택**(7.8~8.0 vs on-device
    10.8 us) = 회귀 제거 확인. ✅
  - 작은 work(rows 16·64) → on-device 선택, 전부 더 빠름. ✅
  - **default(512) 3-run 전부 `ANY_REGRESSION=NO`** = 무회귀 🟢. rows=256 corner는
    coin-flip tie(M7 0.96, M8 default 3-run 모두 on-device 미세 우세) — default가
    on-device로 두는 게 맞음. (override 256 sweep는 rows=256을 cuBLAS로 밀어 오히려
    "gate가 더 빠른 on-device를 안 골랐다" YES가 떠 calibration 검증.)
- [x] **g5/g3**: 무회귀가 실측(3-run NO)으로 확인 → 🟢. 과대주장 0.

## 2026-05-30 — 🟢🟠 M7 라이브 측정 — RTX 5070(ubu-2, pool, $0)서 1차 사이클 🟠 검증

1차 사이클(M1~M6)의 🟠(static/분석) 클레임을 **실제 GPU(RTX 5070, ubu-2 pool 호스트,
비용 $0)** 에서 측정으로 검증했다. cross-repo anima 트레이너 전체 빌드(runtime regen
블로커)는 **deferred** — 대신 emitter SSOT(`runtime_cuda_emit.hexa`·`runtime_core_emit
.hexa`)의 생성 커널/게이트를 **byte-faithful 하게 복제한 standalone 마이크로벤치**로
각 fix 메커니즘을 직접 측정(instrument-first / cheap-first). 측정대 raw stdout =
`.verdicts/hexa-train-floor/M7-*.txt` (g5 verbatim). 소스 = `tool/train_floor_m7/`.

### 측정 환경

- 호스트: **ubu-2** (Linux x86_64, glibc) · GPU **RTX 5070** (12GB, driver 580.159.03) · nvcc 12.0 · cuBLAS
- 유료 pod **미사용** (전부 무료 pool 호스트서 측정 완료 — A100 헤드룸 검증은 잔여 🟠로 남김)

### A/B 측정 표

#### (1) M4 roofline + M6 fp32 lever — `M7-fp32-roofline.txt` → **🟢 승격**

5070 cuBLAS square GEMM(2N³ FLOPs) fp64(DGEMM) vs fp32(SGEMM) 실측:

| N | fp64 TFLOPs | fp32 TFLOPs | fp32/fp64 |
|---|---|---|---|
| 1024 | 0.485 | 20.51 | 42.3× |
| 2048 | 0.497 | 24.89 | 50.1× |
| 4096 | 0.500 | 24.25 | 48.5× |

- **M4 roofline 예측 검증 = 맞음(CONFIRMED).** 측정 fp64 rate(0.50 TFLOPs) → 트레이너
  fp64 floor = 3.03e12 / 0.50e12 = **6.06 s/step (0.165 step/s)**. M4 예측 **6.58 s/step
  (0.15 step/s)** 및 DECODER 관측 post-#2017/#2018 **0.156~0.18 step/s** 와 ~10% 내 일치.
  → "트레이너는 5070서 이미 fp64 compute roofline 에 닿아 있다"는 M4 핵심 주장 실측 확인.
- **M6 fp32 lever 검증 = 맞음.** 측정 fp32/fp64 ceiling-lift = **42~50×** (M4 예측 **~44×**).
  → fp32 floor = 3.03e12 / 24.5e12 = **0.124 s/step (8.09 step/s)**.

#### (2) M2/M3 gemv d-threshold 게이트 — `M7-gemv-dthreshold.txt` → 🟢(메커니즘) + 🟠(게이트 키 정정)

5070서 cuBLAS Dgemv vs on-device fp64 커널 vs on-device fp32 커널 per-call latency(us):

| rows(out) | cols(d) | cuBLAS us | ondev fp64 us | ondev fp32 us | f64/cuBLAS | f32/f64 |
|---|---|---|---|---|---|---|
| 768 | 64 | 8.08 | 10.82 | 7.12 | **1.34** | 0.66 |
| 256 | 64 | 7.52 | 7.25 | 6.00 | **0.96** | 0.83 |
| 64 | 64 | 7.29 | 6.22 | 5.82 | **0.85** | 0.94 |
| 16 | 768 | 10.19 | 6.42 | 6.19 | **0.63** | 0.97 |

- **메커니즘은 실재(🟢)**: 충분히 작은 work 에서 on-device 커널이 cuBLAS 보다 빠르다
  (f64/cuBLAS 0.63~0.96, 즉 cuBLAS 가 최대 1.6× 느림) — #1354/#2017·#2018 가설 입증.
- **그러나 게이트 키가 정정 필요(🟠)**: 현 게이트는 `cols < min_dim(128)` (= 내적 차원 d)
  기준이나, 실측의 진짜 판별자는 **rows(=출력 차원=#blocks)** 다. rows=768(큰 출력)에서는
  on-device 가 cuBLAS 보다 **느리다**(1.1~1.34×) → 이때 게이트가 켜지면 오히려 회귀.
  rows 가 작아야(≤256) on-device 가 이긴다. **falsifier 존중**: "cols<128 면 무조건
  on-device 가 빠르다"는 단순 명제는 5070서 **부분 반증** — d=64라도 rows=768이면 cuBLAS 우세.
  → 게이트를 `rows·cols` (총 work) 또는 rows 기준으로 재키잉하는 follow-up 이 정답.

#### (3) M1/M3 farr-trim RSS-churn — `M7-farr-trim-rss.txt` → 🟠 유지(synthetic 미재현)

`HEXA_FARR_TRIM` startup mallopt(M_MMAP/M_TRIM_THRESHOLD=256KiB) ON vs OFF, glibc
trainer alloc 패턴(1.2MB large farr + 32~128KB small interleave) 복제:

| variant | OFF climb | ON climb | 결론 |
|---|---|---|---|
| v1 (large free-each-step) | +0 KB/step | +0 KB/step | 둘 다 climb 없음(재현 실패) |
| v2 (retained 64KB pins) | +63.69 KB/step | +63.69 KB/step | 둘 다 동일 — climb 은 살아있는 small(<256KB)서, mallopt 무관 |

- **NOT confirmed(🟠 유지)**: synthetic 으로는 fix 효과를 재현 못 했다. v2 의 climb 은
  genuinely-LIVE 한 64KB(<256KB mmap 임계) 청크 누적 → **어떤 mallopt 도 회수 불가**.
  1.2MB large farr 의 free 는 TRIM 시 OS 반환되나 매 step 재사용돼 climb 을 만든 적 없음.
- 결론: HEXA_FARR_TRIM 은 monotonic climb 이 **free'd large(>256KB) 청크가 pinned arena
  top 뒤에 갇힌** 모양일 때만 도움. 실제 anima 트레이너의 200~325MB/step climb 이 그
  모양인지는 **여기서 미측정**(full anima 트레이너 빌드 = deferred). 메커니즘은 sound
  (startup 1회 mallopt, steady-state 비용 0)나 실효는 real-trainer RSS_TRACE fire 대기.

#### (4) A/B ledger — `tool/train_floor_bench.hexa --ledger` → `exports/perf/train_floor_m7_ab.md`

측정 floor 로 채운 A/B ledger (arm H = fp64, arm P = hexa-fp32):

| backend | step/s | s/step | GPU-days (100k step) |
|---|---|---|---|
| hexa-native (fp64) | 0.165 | 6.06 | 7.01 |
| hexa-native (fp32) | 8.090 | 0.124 | 0.143 |

Δ = **49.03×** (fp32 가 fp64 대비; M4 예측 44× 와 정합). prod 100k step 환산 = 7.01 → 0.143 GPU-days.

### 🟢 승격된 클레임

- **M4 roofline 예측** (트레이너 = fp64 COMPUTE-bound, 5070 fp64 floor ≈ 0.15 step/s) → 🟢
  (측정 0.165 step/s, ~10% 내 일치).
- **M6 fp32 lever 크기** (5070 ~44× ceiling-lift) → 🟢 (측정 42~50×).
- **M2/M3 게이트 메커니즘** (작은 work 에서 on-device > cuBLAS) → 🟢 (메커니즘 실재 확인).

### 남은 🟠 (honest)

- **M2/M3 게이트 키**: `cols<128` 이 아니라 **rows(또는 rows·cols)** 가 진짜 판별자 —
  d=64라도 rows=768이면 cuBLAS 우세(부분 반증). 게이트 재키잉 follow-up cycle 필요.
- **M1/M3 RSS-churn 실효**: synthetic 미재현 → real anima 트레이너 RSS_TRACE fire 대기.
- **A100 occupancy 헤드룸**(M4: fp64 floor 의 6.4× 헤드룸) = A100 유료 pod 필요 → 미측정 유지.
- **cross-repo anima 트레이너 빌드**(runtime regen 반영) = 별개 cycle (HALT 조건 회피, deferred).

## 2026-05-30 — 🟠 M6 fp64→fp32 dtype 스위치 첫 슬라이스 (gemv, opt-in · 미측정)

M4가 지목한 진짜 천장 lever(**fp64 COMPUTE-bound → fp32/bf16**)의 첫 bounded
shippable slice. 학습 hot-path의 fp64 정밀도를 env `HEXA_TRAIN_DTYPE`로 선택
가능하게 했다 — 최소 1개 hot 커널(packed_gemv)에 fp32 변형 + dtype 디스패치 추가.
**기본 fp64 유지(무회귀)**, fp32는 opt-in. GPU 실측 안 함(M7).

### ① fp64 박힌 학습 hot-path 전수 매핑 (`self/cuda/runtime_cuda_emit.hexa`)

| 지점 | file:line(emit) | fp64 형태 | M6 상태 |
|---|---|---|---|
| 디바이스 슬롯 미러 테이블 | `_CudaFarrSlot.d_buf` `double*` (~L76) | 저장 자체가 fp64 | scope (storage layout = bf16 sibling TU) |
| H2D/D2H 복사 | `_h2d`/`_d2h` `sizeof(double)` (~L223/259) | fp64 바이트 | scope (slot fp64면 불변) |
| matmul (Phase A) | `cublasDgemm` (~L655) | fp64 D-gemm | scope |
| matmul_t | `cublasDgemm` (~L1664) | fp64 D-gemm | scope |
| outer | `cublasDgemm` (~L1770) | fp64 D-gemm | scope (K=1 bit-exact) |
| **gemv (packed)** | `cublasDgemv` + `_hx_k_packed_gemv_offset` (~L1239/1732) | fp64 D-gemv + fp64 on-device 커널 | **✅ M6 fp32 변형 추가** |
| AdamW | `_hx_k_adamw_step`/`_inplace` (~L1171/1201) | fp64 옵티마이저 상태 | scope (수렴 민감 — master fp64 권장) |
| softmax/rmsnorm/ce/rope 커널 | `__global__ ... double` (~L893~2107) | fp64 reduction | scope |
| 엘리먼트와이즈(add/scale/mul/silu) | `_hx_cuda_kern_*` `double` (~L1918~) | fp64 | scope |
| bf16 substrate | `self/cuda/runtime_bf16_emit.hexa` | `__nv_bfloat16` storage class (RFC 049 Stage 2 scaffold) | 이미 존재 — TensorCore 경로는 여기 (M6 범위 밖) |

### ② 구현한 dtype 스위치

- **env**: `HEXA_TRAIN_DTYPE` — `fp32`/`f32`/`float` → fp32 compute path 활성.
  그 외(unset·`fp64`·`f64`·`double`·`bf16`·미인식) → fp64(현행, 정확) fail-safe.
- **selector**: `_hx_train_dtype_is_fp32()` (emit ~L1707) — getenv+strcmp, 미인식
  값은 절대 silent downgrade 안 함(정확 경로로 fail-safe).
- **fp32 커널**: `_hx_k_packed_gemv_offset_f32` (emit ~L1255) + `_hx_warp_sum_f`/
  `_hx_block_sum_f` — 기존 fp64 `_hx_k_packed_gemv_offset`/`_hx_block_sum`의
  `float` 미러. fp64 디바이스 버퍼를 load에서 fp64→fp32 narrow, dot-product를
  fp32로 reduce, store에서 fp32→fp64 widen (호스트 packed-double ABI 불변).
- **디스패치 wire**: `_hx_cuda_farr_packed_gemv_offset_gpu` (emit ~L1794, `#ifdef
  __CUDACC__` 내부) — `_hx_train_dtype_is_fp32()` true면 fp32 커널, else 기존
  d-threshold→fp64 cuBLAS 경로로 fallthrough. cuBLAS min-dim sync gate와 독립
  (fp32 = compute-precision 선택, dispatch-cost 선택 아님).

### ③ 정확도 경계

- 기본 dtype = **fp64 유지** → 1차 사이클(#2122/#2127 등) 무회귀.
- fp32는 24-bit 만티사(fp64 53-bit) → dot-product 상대오차 ~cols·2^-24. mixed-
  precision 학습 영역 = **수렴에 영향** → opt-in only, bit-eq vs fp64 미주장.
- 추론 AKIDA-int4 경로 무손상(이 변경은 forge GPU 학습 substrate만).

### ④ 잔여 scope (honest)

- **bf16/TensorCore**: `cublasGemmEx`/WMMA = `runtime_bf16_emit.hexa` 별도 storage
  class(2-byte). M6는 fp32 슬라이스만; bf16은 별 트랙(RFC 049 Stage 2 fire).
- **나머지 hot 커널 fp32화**: matmul/matmul_t/outer(Dgemm)·AdamW·softmax/rmsnorm/
  rope·elementwise — gemv와 동일 패턴으로 확장 가능하나 M6 bounded slice 밖.
- **slot storage fp32**: `_CudaFarrSlot.d_buf`를 fp32로 = H2D 대역폭 절반 + cuBLAS
  Sgemv 직접. 현 슬라이스는 fp64 storage 유지 + load-time narrow(레이아웃 무변경).

### 🟠 사유

GPU/clang 실측 없음(g5) — `hexa_real parse` 게이트만 통과(syntactic). fp32 커널은
verified fp64 `_hx_block_sum` 패턴의 정확한 `float` 미러 + 표준 C selector. 실제
step/s 게인(A100 32×·5070 44× 천장) + 수렴 영향 측정은 M7(GPU pod + regen 필요).
B9: runtime_cuda.c는 generated → emitter(`runtime_cuda_emit.hexa`)만 수정.

## 2026-05-30 — 🟠 M5 A/B step-rate 측정대 스캐폴드 (harness만, 미측정)

hexa-native 학습기 step-rate vs PyTorch step-rate 를 **동일 모델/설정**에서 A/B
비교하는 측정대(harness)를 구축했다. `tool/unshadow_bench.hexa` (UNSHADOW A/B
측정대) 패턴 미러 — 두 arm, 같은 호스트/workload, 페어드 ledger row + Δ. **GPU
실행은 하지 않음** (비용 + cross-repo infra) — 라이브 측정은 honest defer.

### 만든 파일

- [x] **`tool/train_floor_bench.hexa`** — A/B step-rate 측정대 (log-driven).
  arm H = anima 디코더 트레이너 (`train_v3_moe_longtrain.hexa`, DECODER M5
  `STEP_RATE_LOG` 생산자), arm P = 동일 (d·layers·batch·seq) HuggingFace-Trainer
  baseline (`hexa dojo llm` payload). 두 모드:
  - `--plan` : 두 arm 의 cloud-dispatch 명령 한 세트 출력 (GPU 안 돌림 · pod
    rent 안 함 · 비용 0). honest-defer 표면.
  - `--ledger --hexa-log <p> --pytorch-log <p>` : 실제 GPU fire 가 만든 두 arm
    로그를 파싱 → A/B ledger (실측 경로). STEP_RATE_LOG 포맷 호환 파서.
- [x] **`tool/TRAIN_FLOOR_BENCH.md`** — 한국어 실행법 + 로그 포맷 + ledger 포맷.

### ledger 포맷

markdown 표 + JSONL row 동시 출력. 열 = `backend · step/s · s/step · peak RSS(MB)
· GPU-days(prod)`. GPU-days = `prod_steps / (step_per_s × 86400)` (`--prod-steps`
0 이면 생략). Δ row = `pytorch_step/s ÷ hexa_step/s` (×, >1 = PyTorch 빠름).
baseline 참조 = M1 기록값 (hexa-native 0.28 step/s · 1.99 s/step · 77~122
GPU-days · GPU util 0~8% · 🔴 INFEASIBLE) 을 ledger 하단에 명시. 두 arm 중 하나라도
step/s 미파싱 시 SKELETON + `⚠ 🟠 INCOMPLETE` 표시.

### 로그 포맷 (STEP_RATE_LOG 호환)

마지막 occurrence 채택. step/s = `<n> step/s`|`step_rate=<n>`, s/step =
`<n> s/step`|`sec_per_step=<n>`, RSS = `RSS <n>MB`|`peak_rss_mb=<n>`. DECODER
트레이너의 기존 `<n> step/s`·`<n> s/step` 출력 그대로 호환.

### 실행법 (1줄)

`hexa run tool/train_floor_bench.hexa --plan --d 64 --batch 1 --host ubu-2`
(dispatch 명령 출력) → 실측 후 `--ledger --hexa-log <p> --pytorch-log <p>`.

### 🟠 사유 (g5 — 측정 없음)

`hexa_real parse tool/train_floor_bench.hexa` = `OK ... parses cleanly`
(syntactic gate PASS). 측정대 코드 + 사용법은 완성, 로그 파서는 self-test 대상.
**라이브 GPU step-rate 측정 0** (비용 + cross-repo anima 트레이너 infra) →
🟢/🔵 금지, verdict 🟠. 실제 fire 가 두 arm 로그를 채우면 `--ledger` 로 terminal
verdict(🟢 Δ measured) 전환. macOS 4GB memcap 으로 로컬 interp 실행은 OOM
(SIGKILL 137) — 실행은 ubu-2/GPU pod 원격이 정상 경로.

## 2026-05-30 — 🟠 M3 glibc malloc-tuning 배선 (env-gated, 미측정)

M1 단편화 가설(`malloc_trim`/`mallopt` 호출 0개 → freed chunk OS 미반환 → main-arena
누적)에 대응해, runtime init constructor 에 **glibc malloc 튜닝 배선**을 추가.
host-farr free 경로 자체(`hexa_farr_free`)는 hand-maintained 한 gitignored
`self/runtime.c` HI-tier(RFC 061 P2/P3 미이주, 본 worktree 부재)라 직접 못 고침 →
대신 **alloc 분류 자체를 mmap 으로 유도**해 free 시 즉시 OS 반환되게 하는 동등-효과
fix 를 tracked emit SSOT 에 배선.

### 바꾼 file:line

- `self/runtime_core_emit.hexa:333` (편집 후) — `_hexa_init_mem_cap` 닫힘 직후에
  신규 `__attribute__((constructor)) _hexa_init_malloc_tuning()` 를 emit. CORE-tier
  runtime_core.c SSOT (B9-generated, byte-identical regen #1871).

### 메커니즘

`HEXA_FARR_TRIM=1` 시 startup 1회 `mallopt(M_MMAP_THRESHOLD, 256KiB)` +
`mallopt(M_TRIM_THRESHOLD, 256KiB)`. 256KiB 임계 → per-step 거대 packed-double
farr chunk(V·8B ≈ 1.2MB) 가 mmap-backed 가 되어 `free()` 시 즉시 **munmap → OS
반환** (main-arena 우회), 동시에 top-chunk 도 eager trim. per-free 비용 0(startup
1회 set) → steady-state throughput 회귀 불가, 유일 tradeoff = 거대 alloc/free 당
syscall 1회(소수 buffer 재사용 trainer 라 수용가능).

### env 게이트

- `HEXA_FARR_TRIM=1` — 활성 스위치 (default OFF → 추론 AKIDA-int4 + self-compile
  의 fat-arena 보존 무손상, training driver 만 opt-in)
- `HEXA_FARR_MMAP_KB=<N>` / `HEXA_FARR_TRIM_KB=<N>` — 임계 KiB 오버라이드 (M4 sweep)
- glibc 전용: `#if defined(__linux__) && defined(__GLIBC__)` 가드 (macOS/musl 무동작)

### 검증

- `hexa parse self/runtime_core_emit.hexa` → `OK: ... parses cleanly` (EXIT 0).
- emit C fragment 격리 `clang -O2 -Wall -Wextra -c` → EXIT 0 (코드 경고 0).
- runtime regen(emitter→runtime_core.c) 미실행: regen 은 heavy pool build 이고
  base `self/runtime.c` 가 worktree 부재(gitignored). SSOT emit 변경이 canonical
  surface 이므로 push; regen 은 build_hexa_cli `_regen_runtime_core()` 가 머지 후
  byte-identical 로 흡수.

### verdict = 🟠 이유

라이브 RSS/alloc **측정 0** (g5: 측정 없이 🟢/🔵 금지). 메커니즘 정합성은 높음
(mmap-backed large-alloc → munmap-on-free 가 main-arena retention 을 직접 우회) +
정적 검증(parse·clang) 통과지만, per-step RSS 단조증가가 실제로 끊기는지는 M4
라이브 측정 전까지 미확정. fix + 정적 검증만이 M3 범위.
## 2026-05-30 — 🟠 M4 instrument hook + roofline floor (분석, GPU 비용 0)

M1 추천 instrument hook 을 코드로 구현 + d768 trainer 의 roofline 기반 step-rate
floor(물리 천장)를 분석적으로 산출. **라이브 GPU 측정 0** → verdict 🟠.

### (A) instrument hook — env-가드 RSS-trace 헬퍼

- [x] **hook 위치**: `self/runtime.h` 말미(`#endif HEXA_RUNTIME_H` 직전),
  `static inline void hexa_rss_trace_on_free(void)`. env **`HEXA_RSS_TRACE`** opt-in
  (unset = zero overhead, 분기 1회). free 마다 `mallinfo2()` before → `malloc_trim(0)`
  → after delta(`uordblks`+`hblkhd`)를 stderr 1줄(`[rss-trace] step-free N: …`)로 로그.
  `#if defined(__GLIBC__)` 가드 — macOS/musl 은 no-op stub(추론 AKIDA-int4·비-Linux
  빌드 byte-무영향).
- [x] **M3 충돌 회피(CRITICAL)**: M3 는 `hexa_farr_free` **본체**(`self/runtime.c`)에
  trim 호출을 직접 배선 중. 본 헬퍼는 **헤더(별도 파일)**에 살고 default-OFF —
  같은 라인 편집 0. 본체는 헬퍼를 `hexa_rss_trace_on_free();` **한 줄**로만 호출
  (free(e->buf) 직후) → M3 trim 라인과 합성되나 절대 겹치지 않음.

#### ⚠ B9 제약 — 본체 wiring 은 edge-asset regen 대기 (committable emitter 부재)

`self/runtime.c`(= `hexa_farr_free` 본체 site, 본래 `runtime.c:6298`)는 **#2065
`.c`-graduation** 으로 tracked `.c`=0 달성 시 **gitignored edge-tarball 빌드 자산**
(`build/runtime.a`)이 됨. `runtime_core.c`(→`runtime_core_emit.hexa`)·16 native
fragment 과 달리 **runtime.c 루트 본체에는 committable `.hexa` emitter 가 없다**
(`stage_resolve_runtime_a` 가 prebuilt 를 pull). 따라서 본체 1줄 call-site 는 다음
edge-runtime.c regen 때 적용할 **patch spec** 로 헤더 주석에 명시:

```c
HexaVal hexa_farr_free(HexaVal h_v) {
    ...
    if (e->buf) { free(e->buf); e->buf = NULL; e->len = 0; }
    hexa_rss_trace_on_free();   // <-- M4 hook (1줄, M3 trim 과 비겹침)
    ...
}
```

헤더(`self/runtime.h`)는 tracked → 헬퍼는 이번 PR 로 land. 사용법:
`HEXA_RSS_TRACE=1 <trainer>` → step 별 `trimmed=Δ` 가 #1(arena retention) vs
#4(VAL_ARENA plateau)를 분리한다 (M1 §"instrument hook 1점" 정합).

### (B) roofline floor — d768·12L trainer (fp64 doubles)

config(SSOT `stdlib/flame/flame_d768_12L_corpus_test.hexa`): T=1024 · d=768 ·
nh=12 · nkv=4(GQA) · h=3072 · V=256(byte) · L=12 · B=nsamp=4. **fp64**.

| 지표 | 값 | 근거 |
|---|---|---|
| params P | 104.2M (per-layer 8.65M × 12 + emb) | header bp_total 식 |
| tokens/step | 4096 (T·B) | T=1024·B=4 |
| FLOPs/step | **3.03e12** (matmul 6·P·tok=2.56e12 + attn 4.64e11) | 6·P·tok + 3·(2·2·L·T²·d·B) |
| bytes/step | **1.46e10** (weight 3·P·8 + act 2·L·20·T·B·d·8) | naive fresh-farr per op(M1) |
| arithmetic intensity | **207 FLOP/byte** | ridge point(~5–10) 훨씬 위 → **compute-bound** |

#### roofline floor step-rate (peak 스펙은 공개치)

| GPU | fp64 peak | floor(fp64) | step/s | gap vs 1.99s(0.28st/s) | bound |
|---|---|---|---|---|---|
| **A100-80G SXM** | 9.7 TF | **0.312 s/step** | 3.21 | 측정 1.99s = **6.4× 느림 = floor 의 15.7%** | COMPUTE(fp64) |
| A100-40G PCIe | 9.7 TF | 0.312 s/step | 3.21 | 6.4× (15.7%) | COMPUTE(fp64) |
| RTX 4090 | 1.29 TF | 2.345 s/step | 0.43 | 0.85× (이미 floor 근처) | COMPUTE(fp64) |
| **RTX 5070(sm_120)** | ~0.46 TF | **6.58 s/step** | 0.15 | — (post-fix 0.156–0.18st/s ≈ 5070 fp64 floor!) | COMPUTE(fp64) |

#### bound 판정 = **COMPUTE-bound (fp64)**, NOT memory/sync

- arithmetic intensity 207 ≫ ridge → 메모리 아님. mem-only floor 는 A100 7.2ms /
  5070 21.7ms (관측 1.99–6.4s 대비 100–300×↓) → **메모리 대역폭은 천장이 아니다**.
- 5070 fp64 floor(6.58s) > 관측 baseline(1.99s) → **baseline 0.28st/s 는 5070 fp64
  로 못 나옴** = baseline 은 A100급 또는 fp32 경로였을 가능성. 반면 **post #2017/#2018
  회귀치 0.156–0.18st/s 는 5070 fp64 compute floor(0.15st/s)와 정확 일치** → 5070 에선
  트레이너가 **이미 fp64 roofline 에 닿아 있다**(더 못 짜냄, 천장).
- A100 에선 1.99s = floor 의 16% → 6.4× 헤드룸. 0~8% GPU util(도메인 doc)은 작은-op
  간 sync/dispatch stall 로 fp64 유닛에 일이 안 닿는 것 = **fp64 천장 자체는 정상이나
  occupancy 손실**. M2(d-threshold)·M3(arena)는 이 16%→100% 헤드룸을 메우는 작업.

#### 핵심 lever (instrument-first 사전예측)

같은 FLOPs 라도 unit peak 이 precision 으로 갈림:

| | A100 fp64 | A100 fp32 | A100 tf32-TC | 5070 fp64 | 5070 bf16-TC |
|---|---|---|---|---|---|
| floor s/step | 0.312 | 0.155 | 0.0097 | 6.58 | 0.022(mem) |
| step/s | 3.21 | 6.45 | 103 | 0.15 | 46 |

→ **가장 큰 천장 인하는 fp64→fp32/bf16(TC)** (A100 32×, 5070 44×). 메모리/sync 최적화
(M2·M3)는 fp64 천장 내 16%→100% 헤드룸 회수까지만 — 그 위 한계는 precision 이 결정.
이 분석은 instrument-first(faithful 모델로 GPU값 사전예측) — 실측 전 천장 + bound 확정.

### 🟠 사유 (g5 — 측정 없음)

instrument 코드(헤더 헬퍼) + 분석 모델(FLOPs/bytes/peak/floor 표) + 측정 실행법
(`HEXA_RSS_TRACE=1`)만 land. **라이브 GPU step/s·RSS Δ 실측 0** → 🟢/🔵 금지,
verdict 🟠. FLOPs/bytes 는 추산(naive fresh-farr 가정)이라 ±, peak 은 공개 스펙.
`hexa_real parse` 게이트는 헤더(.h)라 미적용 — C 헤더 syntactic 은 clang -fsyntax 후속.

## 2026-05-30 — 🟠 M2 cuBLAS gemv d-threshold 게이팅 (코드 수정, 미측정)

#2018(offset cuBLAS Dgemv) 가 작은 d(=64)에서 cuBLAS 라이브러리 dispatch 비용 +
H2D/D2H sync 왕복이 절약한 FLOPs 보다 커서 ~3× 느려진(0.28 → 0.156~0.18 step/s)
문제(hexa-lang #1354 예측)에, **contraction dim `cols`(=gemv 내적 차원, "d") 기준
d-threshold 게이팅**을 넣었다. 작은 d 면 cuBLAS 우회 → on-device 커널, 큰 d 면 기존
cuBLAS 유지.

### 무엇을 어디에 바꿨나

- [x] **on-device gemv 커널 추가** — `self/cuda/runtime_cuda_emit.hexa:1226` 부근
  (`#endif __CUDACC__ kernel bodies` 직전). `_hx_k_packed_gemv_offset` —
  one-block-per-row 도트곱 + `_hx_block_sum` 블록 reduction(softmax/ce 커널과 동일
  고정 트리). cuBLAS 라이브러리 dispatch(handle state·heuristic·kernel-select)
  오버헤드 없이 default stream 위에서 실행. cuBLAS-tiled 가 아닌 블록 reduction
  순서라 matmul TOL caveat 동일(bit-eq 아님 — 기존 블록 reduction 커널들과 같은 caveat).
- [x] **host wrapper 게이트 분기** — `_hx_cuda_farr_packed_gemv_offset_gpu`,
  `self/cuda/runtime_cuda_emit.hexa:1692~1730`. H2D/out-alloc 직후, `cols < min_dim`
  이면 커널 launch + `cudaDeviceSynchronize` + `_d2h_out` 로 early-return.
  `_ensure_cublas()` 호출을 함수 머리에서 **cuBLAS 분기 직전으로 이동**(작은-d 경로는
  cuBLAS handle 불필요).

### threshold 값 / override

- 기본값 **128**(보수적), env **`HEXA_GEMV_CUBLAS_MIN_DIM`** 로 오버라이드
  (`getenv`+`atol`, `<stdlib.h>` 이미 include). 근거 1줄 주석 코드에 포함(#1354).

### 회귀 가드

- 큰-d(≥128) 경로는 cuBLAS `cublasDgemv` 호출·인자(P_dev/U_dev/O_dev, lda 등) **무변경**.
- 커널 분기 전체가 `#ifdef __CUDACC__` 안 → nvcc 없이 빌드 시 항상 cuBLAS 폴백(no-CUDA
  host 무영향).
- 추론 경로(AKIDA-int4) 무접촉 — 이 함수는 학습 fp64 host-farr gemv 전용.
- CPU oracle 무변경 → `test/regression/farr_packed_gemv_offset_byte_eq.hexa`
  (CPU API vs inline scalar, GPU 미경유) 영향 없음.

### 🟠 사유 (g5 — 측정 없음)

코드 수정 + 정적 검증만 수행. `hexa_real parse self/cuda/runtime_cuda_emit.hexa`
= `OK ... parses cleanly` (syntactic gate PASS). **speedup 실측(GPU 실행) 미수행**
이므로 🟢/🔵 금지 — verdict 🟠. 실제 d=64 step/s 회복 측정은 후속(M4 측정대 분리).

## 2026-05-30 — 🟠 M1 churn source localize (static, 미측정)

200~325MB/step host-RSS churn 의 코드 site 를 **정적 추적 + byte-scale 추산**으로
지목. 측정 없음(M4 분리). #2017(in-place AdamW)·#2018(offset gemv) land 후 잔여
별개 source. anima trainer 결백 (anima $0 source-read 로 ~4.4MB/step 만 매칭 → 관측
대비 ~1/50). 추적 결론: **단일 거대 alloc 이 아니라 glibc arena retention 으로
증폭된 host-farr churn** 이 가장 유력.

### 핵심 메커니즘 — host RSS 단조증가의 원인은 "할당량"이 아니라 "회수 실패"

관측치는 *host RSS* 가 5.5GB → 52GB 로 **단조 증가**다 (anima INBOX entry #2030).
per-step alloc/free 총량(~4.4MB anima 측 + 아래 runtime 측 후보)이 200MB 에 못
미치는데도 RSS 가 단조로 오른다는 사실 자체가 **"freed chunk 가 OS 로 반환되지
않는다"** 는 시그널이다 — 즉 true leak 이 아니라 glibc main-arena fragmentation
+ retention. 이게 anima 의 50× gap 을 정확히 설명한다 (free 는 되지만 RSS 는 안
줄어듦). runtime 전체에 `malloc_trim`/`mallopt(M_MMAP_THRESHOLD/M_TRIM_THRESHOLD)`
호출이 **0개** (전수 grep: `self/**/*.hexa` 에서 hit 없음, fs_munmap·safetensors 만
존재) — arena 반환 정책이 완전히 미관리 상태.

### 랭킹된 후보 site 표

| # | site (file:line) | 메커니즘 | byte-scale 추산 (per step) | 신뢰도 |
|---|---|---|---|---|
| 1 | **host-farr 할당기 `hexa_farr_zeros`→calloc / `hexa_farr_free`→free** (runtime.c, B9 generated — 선언 `self/runtime.h:923`; emit 경로 SSOT) + glibc arena 미반환 | `_gpu`/CPU op 마다 **fresh host output farr** 를 calloc, free 됨에도 다양한 chunk size(V·8B≈1.2MB ↔ weight extract 32–128KB)가 main-arena 를 단편화 → freed top 미수축. `malloc_trim` 부재로 OS 미반환 | 누적 도메인 = 전체 step working-set (수십 MB) × arena-retain 비율 → 관측 200–325MB/step 단조증가와 정합 (free 총량 ≪ RSS 증분) | 높음 (메커니즘 정합·grep 으로 trim 부재 확정) |
| 2 | **`_ensure_dev_alloc_out` / `_h2d` 의 free-then-malloc** `self/cuda/runtime_cuda_emit.hexa:769-780`·`220-231` | `if(!s->d_buf || s->len!=e->len){ cudaFree; cudaMalloc; }` — **size-cached**. step-invariant shape 면 churn 0. *device* 메모리지 host RSS 아님 | shape 불변 시 0 B/step. 가변 shape 일 때만 device-side. host RSS 와 무관 | 낮음 (host RSS 설명 못함·size-gated) |
| 3 | **bf16 layercast linear per-call `cudaMalloc(dX)+cudaMalloc(dY)+free`** `self/cuda/runtime_bf16_emit.hexa:691-761` | 호출당 dX(M·K·4B)+dY(M·N·4B) device staging 신규 alloc/free. 명백한 per-call churn이나 **device-side** | M·K·4 + M·N·4 (device). d=64·작은 M 이면 KB 급. host RSS 아님 | 낮음 (device-only·d=64 작음) |
| 4 | **HEXA_VAL_ARENA bump 블록 미수축** `self/runtime_core_emit.hexa:3770-3773` (`hexa_arena_reset`) | scope pop 시 `b->used=0`·`cur=head` 만 — 블록 chain 은 retain (`free`/`munmap` 안 함). high-water 까지 grow 후 plateau | 단조증가 아님(고수위 plateau). step 마다 shape 가 커지지 않으면 200MB/step 못 만듦 | 중간 (보조 증폭 가능, 단독 driver 아님) |

추가 확인: `_gpu` op 군(`farr_matmul_t_gpu`·`outer_gpu`·`mul_gpu`·`silu_gpu`·
`silu_grad_gpu`·`rmsnorm_bwd_rows_gpu`·`softmax_rows_gpu`·`adamw_step_gpu`)은
전부 "-> int **new farr** [n]" 시그니처 = **호출당 fresh host output farr**
(`self/runtime.h:1240-1338`). `self/runtime.h:1262-1266` 주석이 직접 명시:
"`farr_softmax_rows_gpu` … allocates a fresh output farr per call via
`hexa_farr_zeros` … a per-step alloc for a 29M-param trainer". #2017(in-place
AdamW)·BC-ANIMA M2(in-place softmax)는 이 패턴 중 **2개만** in-place 로 막았고,
나머지 `_gpu` op 의 fresh-farr 패턴 + glibc retention 이 #1 의 본체다.
d=64 의 gemv 는 GPU gate(`rows·cols>8192`, runtime.h:1345) 기준 logits gemv
(V·d=151643·64≈9.7M) 만 GPU, weight gemv(64·64=4096)는 CPU fallback → CPU
fallback 도 fresh host farr 할당.

### #1 용의자

**host-farr `hexa_farr_zeros`/`hexa_farr_free` 의 per-step fresh-output 패턴이
glibc main-arena 에 retain 되는 것** (`runtime.h:923` 선언; 본체는 B9 generated
runtime.c). 단일 거대 alloc 이 아니라 **분산된 host-farr churn × arena 미반환**
의 곱으로 200–325MB/step 단조증가를 만든다. 보조 증폭 = HEXA_VAL_ARENA 블록
retain(후보 #4). device-side(후보 #2·#3)는 host RSS 와 무관 → 배제.

### M4 instrument hook 1점

**`hexa_farr_free` 진입점 1곳** (runtime.c, `runtime.h:927` 선언) 에 hook:
free 직후 `malloc_trim(0)` 의 RSS 회복량을 `mallinfo2().hblkhd`/`uordblks`
delta 로 step 마다 로그. 이 한 점이 (a) "freed 됐는데 RSS 안 주는가"(retention
가설)와 (b) per-step free 총 byte 를 동시에 계측 → #1 vs #4 를 분리한다.
대안 보조 hook = `HEXA_VAL_ARENA` 의 `hexa_arena_reset` 진입점(runtime_core_emit
.hexa:3770)에 block-chain 총 used/capacity 로그 (후보 #4 plateau 검증용).

### verdict = 🟠 이유

코드 정적 추적 + byte-scale 추산만 수행, **라이브 RSS/alloc 측정 0** (g5: 측정
없이 🟢/🔵 금지). 메커니즘 정합성은 높으나(arena retention + fresh-farr 패턴 +
trim 부재 확정) byte-scale 가 추산이라 200–325MB 정확 매칭은 M4 측정 전까지
미확정. 단일 site 단정 대신 "분산 churn × arena 미반환" 결론 — 이 또한 정직한
localize (plan completion criteria 의 valid 결론).

## 2026-05-30T00:00Z — bf16 천장 돌파 (M6 fp32 → bf16 확장)

`HEXA_TRAIN_DTYPE=bf16` 경로 추가. dtype selector 를 fp64|fp32|bf16 3-way 로
일반화하고, 학습 hot 커널 `packed_gemv_offset` 에 in-place bf16-MAC 슬라이스를
추가. bf16 substrate(`self/cuda/runtime_bf16_emit.hexa`, RFC 049)는 이미 같은
TU 에 `#include "runtime_bf16.c"`(emit L3637)로 링크됨 → `_hx_gemm_ex_bf16`
(cublasGemmEx · CUDA_R_16BF · CUBLAS_COMPUTE_32F · TENSOR_OP) 재사용 가능.

### 구현 (self/cuda/runtime_cuda_emit.hexa, B9 emitter)
- `#include <cuda_bf16.h>` 추가 (`__double2bfloat16`/`__bfloat162float`).
- 3-way selector: `_hx_train_dtype()` → enum HX_TRAIN_DTYPE_{FP64,FP32,BF16}.
  env `HEXA_TRAIN_DTYPE` ∈ {bf16,bfloat16}=BF16, {fp32,f32,float}=FP32, 그 외/unset=FP64.
  M6 `_hx_train_dtype_is_fp32()` 는 shim 으로 위임(무회귀). 기본 fp64 유지.
- bf16 커널 `_hx_k_packed_gemv_offset_bf16`: 연산자 fp64→bf16(RNE) narrow,
  곱 fp32 widen, **FP32 accumulator**(수렴 안정, GemmEx COMPUTE_32F 규율 동일).
  storage 는 fp64 유지(host ABI 불변). dispatcher 에 bf16 분기 추가(fp32 앞).

### 실측 (ubu-2 RTX 5070, $0, .verdicts/hexa-train-floor/bf16-lever.txt)
- (A) in-place bf16-MAC **gemv 커널 = 🔴 NEGATIVE**: bf16/f64 = 0.85–5.67x
  latency(bf16 더 느림, cols≥128). 이유: per-element bf16 변환 오버헤드 +
  per-row block-reduction 은 memory-bound + scalar bf16 는 TensorCore(WMMA) 미가동.
  fp32(M6)가 in-place 최선(f32/f64 0.66–0.94). 정확도 OK(max|rel| ~1.3e-2 @cols≥128).
- (B) **bf16 TensorCore GemmEx vs fp64 Dgemm = 🟢 24.9x(n=256) → 123x(n=2048)**.
  진짜 M4 천장 돌파는 square GEMM(cublasGemmEx TENSOR_OP) = RFC 049 `_hx_gemm_ex_bf16`
  shape. 단 bf16 **storage tile** 필요(fp64-storage gemv wrapper 는 in-place WMMA 불가).

### finding / scope
bf16 lever 의 실제 거처는 **gemv 가 아니라 TensorCore GemmEx matmul**. gemv 슬라이스는
selector parity + 완결성 위해 opt-in 으로 랜딩(기본 fp64, NOT recommended 명시).
잔여(M9+): `matmul_t`/`matmul` 을 bf16 storage + `_hx_gemm_ex_bf16` 로 배선해
실제 24.9–123x 천장 돌파 흡수. 추론 AKIDA-int4 무손상(별개 경로).

## 2026-05-30 — A100 헤드룸 (RENTED A100 80GB PCIe, vast.ai, GPU 사전승인)
M7/M8/bf16 마이크로벤치 스타일을 **실제 A100** 에서 재측정 (pod 38457696, ssh3.vast.ai:17696,
nvcc 12.4 native sm_80). preflight(closed-form) = d768·12L f64+adamw on a100-80gb = 15.97 GiB
PASS(>15% headroom). GemmEx shape = `self/cuda/runtime_bf16_emit.hexa _hx_gemm_ex_bf16` verbatim.
raw verdict = `.verdicts/hexa-train-floor/A100-headroom.txt` (2 runs). source =
`tool/train_floor_m7/a100_headroom.cu`.

### 측정 (square GEMM n=256/512/768/1024/2048, FLOPs=2n^3, reps=200)
- **(1) A100 fp64 Dgemm 🟢**: 4.40 → 18.08 TFLOP/s (n=256→2048). n=2048 = fp64 peak(~19.5)의
  ~93% = 대형 GEMM 은 이미 fp64 roofline 근접. 5070 fp64(~0.50 TFLOP/s, M7)의 **~30–36×**
  (n≥768) — M4 예측 fp64 floor headroom 6.4× **이상** = CONSISTENT (floor 는 하한).
- **(2) bf16 GemmEx vs fp64 Dgemm 🟢 측정 / 🟠 32× 예측 대비**: lift = 1.19×(n=256) →
  8.8×(n=2048), n 따라 monotone 상승하나 **트레이너 dims(n≤2048)서 ~8.8× 포화 — M4 의
  headline 32× 미도달**. 32× 는 asymptotic(n≫2048, bf16-TC peak 312 / fp64 peak 19.5 = 16×
  matched, 32× 는 un-tuned 베이스라인). falsifier 존중 — 과대주장 0(g3).

### cross-device honest 비교
bf16-lever (B) 가 RTX 5070 서 측정한 동일 GemmEx-vs-Dgemm = 24.9×→123×. A100 비율이 더 작은(1.2–8.8×)
이유 = A100 는 **진짜 fp64 유닛**(데이터센터)이라 베이스라인이 강함; 5070(컨슈머)은 fp64 ~1/64 로
crippled → 비율 inflate. **A100 의 1.2–8.8× 가 production honest number**: fp64-capable GPU 에서
트레이너 dims 의 bf16 레버는 ~5–9×지 32× 아님.

### scope / limitation (정직)
이 마이크로벤치는 A100 **GEMM 천장(fp64 floor + bf16 lift)** 만 측정. 완전한 occupancy "헤드룸"
(real step/s, 커널런치+메모리+activation 오버헤드, e2e per-step)은 real d768·12L 트레이너(cross-repo
anima, runtime-regen 블로커)가 필요 — 여기선 불가. 추론 AKIDA-int4 무관(학습 GEMM 경로).

### teardown
pod 38457696 `hexa cloud down --force` confirmed destroyed · `reconcile` 0-drift · 5s 프로브 pod
3개(38457517/583/627)도 leak-guard auto-destroy + registry forget. 내 pod 0개 잔존.

## 2026-05-30 — cross-repo anima 빌드 시도 (HEXA-TRAIN-FLOOR branch-4 unblock)

DECODER 트레이너(`anima/training/train_full_decoder.hexa`, 순수 hexa CPU)를 새 hexa
runtime(#2122~#2142)으로 빌드해 env flag(`HEXA_FARR_TRIM`·`HEXA_RSS_TRACE`)를
**실제 트레이너에서 live** 시키려는 시도. 결과 = **🔴 HONEST HALT (B9 top-amalgam SSOT 부재)**.
빌드 못 함 — 단, regen 경로 대부분이 작동함을 입증하고 진짜 블로커를 1줄로 특정.

### regen 경로 (확인)
- env flag 거처: `HEXA_FARR_TRIM`/`HEXA_RSS_TRACE` = `self/runtime_core_emit.hexa` →
  `self/runtime_core.c` (**CPU CORE runtime** — CUDA 불필요, branch-4 RSS-churn 에 정확히 일치).
  `HEXA_GEMV_CUBLAS_MIN_ROWS`/`HEXA_TRAIN_DTYPE` = `self/cuda/runtime_cuda_emit.hexa` (GPU-only, branch-4 무관).
- 빌드 레시피 = `tool/build_hexa_cli.hexa` step `[0-pre]`: 외부 hexa runner 가 PATH 에
  있으면 native/*.c·runtime_core.c·runtime_hi_gen.c·forge/cuda .c 를 emitter SSOT 에서 regen.
- 호스트: ubu-2(linux, RTX5070, nvcc O) = 설치 hexa 가 `~/.hx/bin/self/runtime.c` 부재로
  어떤 .hexa 도 못 컴파일(install dir 미시드). mini(arm64 mac) = canonical dir 에 작동하는
  stale `runtime.c`(af645e419, 2026-05-26) + 32 native .c 보유 = **live buildable window**.

### 시도 (mini, $0, LOCAL_BUILD=1)
`/tmp` 에 origin/main(f269c4a9a) fresh clone → canonical 의 stale `runtime.c`+fragments 시드
→ `hexa run tool/build_hexa_cli.hexa`. 진행: bootstrap hexat OK → `[0-pre]` regen OK
(**runtime_core.c 에 HEXA_FARR_TRIM 4-hit 폴드 확인** · native 16 + forge + hi_gen 전부 regen)
→ stage1~3 transpile OK → **stage4 link FAIL**:
```
Undefined symbols for architecture arm64:
  "_bits_to_float", referenced from: __lower_hexpr in main_native-*.o
  "_float_to_bits", referenced from: __lower_hexpr / __nvptx_f64_hexlit in main_native-*.o
ld: symbol(s) not found for architecture arm64
build_hexa_cli: compile driver failed (rc=1)
```

### 진짜 블로커 (B9, 1줄 특정)
top-level `self/runtime.c` **amalgam 자체가 emitter SSOT 없음** (모든 #include fragment 은
`_emit.hexa` 있는데 top 만 없음) + gitignored. `float_to_bits`/`bits_to_float` 의 weak def 는
PR #1677(acc8435a)이 `self/runtime.c` 에 박음 (tensor_kernels_emit.hexa 는 dup 제거 — 주석이
#1677 canonical=runtime.c 명시). fresh clone 의 컴파일러(main.hexa `_lower_hexpr`)는 이 심볼을
호출하지만, fresh clone 으로 **2026-05-26 이후 심볼을 가진 runtime.c 를 재생성할 수단이 없음**.
시드한 stale runtime.c(2026-05-26)는 #1677 이전이라 def 0개. → 빌드 reproducible 불가.

### 결론 / branch-4 영향
- CORE-runtime flag regen 은 **작동** (runtime_core.c FARR_TRIM 폴드 성공). 블로커는 한 층 위
  top-amalgam ABI 갭이지 flag 가 아님.
- **branch-4(real RSS-churn) 는 이 cycle 로 unblock 안 됨** — top `runtime.c` SSOT 갭 선결 필요.
- handoff `97ee1245` (hexa-lang): GAP = `self/runtime_emit.hexa` SSOT 추가 OR runtime.c git-track
  OR float_to_bits def 를 fragment emitter 로 이동 → fresh-clone 빌드 reproducible 화.
- residue 정리: ubu-2 `~/.hx/bin/self/*.c` 임시 symlink 제거 완료. mini `/tmp/htf` = 임시(자동 폐기).

## 2026-05-29T20:28Z — branch-4 retry (cold-seed) RSS-churn 실측

cold-seed default path (build_hexa_cli step0)로 ubu-2(x86_64·RTX 5070) `/tmp` fresh-clone
(origin/main 71f49bc, 재확인 ef911fd4a 동일) 클린 빌드 시도. 결과: **stale-path 오진 일부 배제,
그러나 float_to_bits LINK 벽은 REAL** — verdict `.verdicts/hexa-train-floor/M1M3-rss-live.txt`.

### 콜드시드 트랜스파일러 = 정상 (branch-3 부분 오진 FALSIFIED)
- `clang ... hexa_cc_seed.c -o build/hexat` RC=0 · smoke transpile OK.
- 콜드시드 escape 입증: seed→`runtime.o`(main 무력화 `-Dmain=__seed_main_unused`)→emitter 링크로
  runtime_core.c / runtime_hi_gen.c / 16 native fragment 전부 emitter SSOT 에서 재생성 성공.
- seed L2-25196 (`amalgam BEGIN runtime.c`..`END`) 추출 → standalone `self/runtime.c`(1.13MB)
  복원 → `clang -c` clean(.o 623KB). 즉 콜드시드는 runtime amalgam 복원까지 가능.

### 그러나 float_to_bits 정의 부재가 최종 벽 (미션 전제 INVERSION)
- 미션 전제 "seed 가 float_to_bits 6 DEFINE" → 실측 FALSE. 6 hits 전부 codegen emit-string
  (`hexa_str("hexa_float_to_bits(")` L39261-40452). 함수 BODY 아님.
- runtime.h L508-511 가 proto 선언, codegen 이 호출 EMIT, 그러나 정의(body)는 seed·재생성
  runtime_core.c·runtime_core_emit.hexa·runtime*.hexa·warm runtime.o 전부 ZERO = dangling decl.
- VERBATIM 재현: `float_to_bits(1.5)` user-prog → `undefined reference to 'hexa_float_to_bits'`
  (콜드시드 갓-추출 runtime.c 링크 · stale 0). branch-3 LINK 실패와 동일, stale 원인 아님.
- 본 로그 직전(prior branch-4) 진단과 합치: PR #1677(acc8435a)이 weak def 를 **top
  self/runtime.c** 에 박았고 seed 는 #1677 이전 → 0 defs. top amalgam = emitter SSOT 부재 +
  gitignored → fresh clone(콜드시드 포함) 으로 def-보유 runtime.c 재생성 수단 없음.

### branch-4(real RSS-churn) = 이 cycle 도 unblock 안 됨
- anima 디코더 트레이너는 float bit-reinterpret(quant/AKIDA-int4 pack) codegen → 위 link 벽 →
  빌드 불가 → 1-step 미도달 → **HEXA_FARR_TRIM on/off per-step RSS Δ UNMEASURED (🟠)** →
  M1/M3 churn-fix 🟢/🔴 판정 불가.
- 선결: runtime SSOT(self/runtime_core_emit.hexa .c-text 또는 fragment emitter)에 4-함수
  union-pun 정의 랜딩 + top `self/runtime.c` emitter-SSOT 화(HEXA-CC-ZERO.md L23·HEXA-BUILDFLOOR
  M1 동일 gap). 그 후 콜드 full build → 트레이너 빌드 → RSS A/B 재시도.
- residue: ubu-2 `/tmp/hexa-train-floor-b4` 임시 클론(자동 폐기). pod 미사용(GPU 불필요 — 빌드
  벽에서 차단). 격리 worktree 만 사용, install/warm tree 무손상.
