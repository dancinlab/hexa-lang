# HEXA-TRAIN-FLOOR — log

Append-only history sister of `HEXA-TRAIN-FLOOR.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

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

