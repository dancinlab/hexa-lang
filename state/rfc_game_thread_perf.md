# RFC — game-frame multithread perf (measure-first baseline)

status: r1 baseline harness landed (numbers pending pool/CI run)
owner: feat/game-thread-microbench
since: 2026-06-27
bench: `test/game_thread_microbench.hexa` (opt-in `HEXA_THREADS`, byteeq-neutral)

## 0. one principle — NO pool/job-system before the numbers

> **측정 전 thread-pool / job-system / lock-free queue 구현 금지.**
> blind-optimize 금지. 먼저 baseline 수치를 만들고(r1), 그 수치가 가리키는 병목을
> 귀속(r2)한 뒤에만, 그 병목 하나를 겨냥한 개선을 별도 PR로 한다(r3).

현재 동시성 primitive (이미 실측됨):
- `stdlib/thread_real.hexa` — `thread_start`/`thread_wait` = pthread 1:1 spawn/join,
  `chan_new`/`send`/`recv`/`close` = mutex+condvar 채널.
- `stdlib/atomic_real.hexa` — `atomic_cell`/`get`/`set`/`fetch_add`/`CAS` = C11 seq-cst.
- **thread-pool · job-system · lock-free queue 는 없음.** 게임-프레임 멀티스레드 벤치 0건.
- 전부 opt-in `HEXA_THREADS` (default-OFF → 동기 fallback, byteeq gen3≡gen4 불변).

이 RFC 가 닫으려는 갭 = "게임 프레임을 N 스레드로 돌릴 때 무엇이 병목인가"를 **수치로** 아는 것.
그 수치 없이 pool/job-system 을 짓는 것은 추측 최적화이며 이 RFC 가 금지한다.

## 1. 측정 사다리

### r1 — baseline (이 PR)
`test/game_thread_microbench.hexa` 가 5 레인을 wall-clock(`clock()` = native CLOCK_MONOTONIC)으로
측정해 print 한다:

| lane | 측정량 | 단위 | 프레임-예산 의미 |
|------|--------|------|------------------|
| (a) spawn/join | N× `thread_spawn→thread_join` 왕복 | µs/thread | "프레임마다 worker spawn" 설계가 무는 per-thread 비용 |
| (b) channel | M× send→recv 핑퐁 (mutex+condvar) | msg/s | task hand-off 처리량 천장 |
| (c) atomic contention | K threads × T fetch_add, 한 cell | ops/s + K∈{1,2,4,8} 스케일 | 공유 카운터 경합 한계 + sum==K·T 정합 |
| (d) N-thread scale | 고정 총작업을 p∈{1,2,4,8} 분배 | speedup vs p=1, efficiency | spawn/join 경로가 실제로 선형 스케일하는지 |
| (e) boxed vs raw | 같은 루프 raw-int vs boxed-array | ratio× | boxing 오버헤드 proxy (thread arg 도 box) |

빌드/실행은 pool/CI (aiden·summer 또는 -DHEXA_THREADS CI 레인)에서:
`HEXA_THREADS=1 hexa test/game_thread_microbench.hexa`. **mini 에선 빌드/실행 금지** (git/gh only).

### r2 — 병목 귀속 (다음 PR, r1 수치 확보 후)
r1 캡처 수치로 dominant cost 를 **귀속**한다 (LLM 자가판정 금지 · 캡처된 출력으로):
- (a) µs/thread 가 프레임 예산(16.6 ms @ 60 FPS)의 유의미한 분율인가? → spawn-amortization 레버.
- (d) efficiency 가 p 증가에서 급락하는가? → spawn/join serialize 또는 false-sharing/atomic 경합.
- (b) msg/s 가 프레임당 필요한 task 수를 못 받치는가? → 채널이 hand-off 병목.
- (c) ops/s 가 K 증가에서 평탄/역행하는가? → seq-cst cell 경합 (lock-free 큐 후보 신호).
- (e) boxed/raw ratio 가 큰가? → job payload unboxing 레버 (codegen).

귀속은 가능하면 더 낮은 레벨 안정 신호로 (하네스 wall-clock 노이즈 → 반복 median, 필요 시 perf/nsys).

### r3 — 타깃 개선 (또 다른 PR, r2 가 한 병목을 지목할 때만)
r2 가 지목한 **단일** 병목만 겨냥:
- (a)/(d) 가 spawn 비용이면 → thread-pool (worker 재사용) — **이때 비로소** 정당.
- (c) 가 atomic 경합이면 → sharded counter 또는 lock-free MPMC 큐.
- (e) 가 boxing 이면 → job payload native-unbox (codegen, byteeq-safe opt-in).
각 개선은 byteeq 3타깃 GREEN + r1 동일 벤치로 before/after 수치 대조로 증명. native-canonical-default
polarity 유지 (개선은 기본 native, 실험은 플래그 opt-in).

## 2. byteeq / 릴리스 무결성
- 벤치는 `test/` 트리 독립 파일. `self/` 가 import 안 함 → self-host 클로저 밖 → default 빌드 경로 불변.
- (c) atomic 레인은 `-DHEXA_THREADS`-gated `atomic_cell_*` 글로벌을 참조하므로 **그 런타임에서만** 링크
  (default 빌드엔 미포함 = opt-in 아티팩트). (a)/(b)/(d) 의 thread/channel 글로벌은 양쪽 빌드에 존재
  (default 는 동기 실행) → default 빌드에서도 serial baseline 으로 의미 있음.
- ARCHITECTURE.json 미변경 (language-surface 충돌 회피; 설계 doc 은 이 RFC).

## 3. 산출
- r1: 이 PR (harness only). 수치는 pool/CI 실행 결과로 본 doc 의 "status" 와 CHANGELOG 에 박제.
- r2/r3: 별도 PR. **r1 수치가 병목을 가리키기 전에는 pool/job-system 을 짓지 않는다.**
