# RFC — game-frame multithread perf (measure-first baseline)

status: r1 MEASURED (aiden · numbers + attribution below) · r4 native-unbox-job-payload = MEASURED WALL 🧱 (memory-layout tax, NOT call-overhead — access-unbox codegen already exists, fires byteeq-safe, moves ratio 0; see "## r4")
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


## status — r1 MEASURED (aiden · 2026-06-27)

Build: native-emit (`hexa build` C-transpile → `hexa_clock()` = `CLOCK_MONOTONIC`, wall-clock) linked against a runtime
compiled with `-DHEXA_THREADS` (`gcc -O2`, real `pthread_create`/`pthread_join` + C11 `_Atomic` cells + `-lpthread`).
Host: aiden, 12-core x86_64, background pool load ~2.8 (affects the p=8 efficiency lane — honest caveat). 3 runs, medians below.

> ⚠️ build note (reproducibility): the in-tree `self/runtime.c` + `self/native/thread.c` seeds were STALE — the
> `#if defined(HEXA_THREADS)` real-pthread block and the `atomic_cell_*` block live in the emitter SSOTs
> (`self/runtime_emit_full.hexa`, `self/native/thread_emit.hexa`) but had never been regenerated into the on-disk `.c`.
> A first build linked the SYNCHRONOUS `#else` shims (`rt_pthread_noop`) and gave fake 25 ns/spawn + flat p-scaling.
> Regenerating both `.c` from their emitters before compiling with `-DHEXA_THREADS` produced real threads (verified:
> `nm` shows `U pthread_create@GLIBC`; lane (d) then scales 1.99x/3.41x/4.73x). Anyone reproducing MUST regen first.

| lane | metric | median (3 runs) | reading |
|------|--------|-----------------|---------|
| (a) spawn/join | us / thread (real pthread create+join) | **7.60 us** (6.98-8.29) | glibc `pthread_create` (mmap stack + clone) bound |
| (b) channel | msg/s, 1-thread send->recv ping-pong | **40.1 M msg/s** (~25 ns/msg) | uncontended mutex lock/unlock + condvar signal bound |
| (c) atomic | ops/s on ONE shared `_Atomic` cell | K1 **174.9M** / K2 **113.7M** / K4 **120.0M** / K8 **100.2M** (all sum_ok=true) | aggregate CAPS / declines — cache-line (MESI) contention |
| (d) N-thread scale | speedup / efficiency, fixed 40M ops | p2 **1.99x**/0.996 / p4 **3.41x**/0.85 / p8 **4.73x**/0.59 | real parallelism; p8 eff loss confounded by bg load |
| (e) boxed vs raw | boxed/raw ratio, 2M accumulate | **4.61x** (4.34-4.77), chk-equal | `{tag,payload}` box + array push/index, alloc/mem-traffic bound |

### bottleneck attribution (measure-first — from captured numbers, not self-judgement)

- **(a) spawn/join — NOT a frame bottleneck at game scale.** 7.60 us/thread is real `pthread_create`+`join`. A 60 FPS frame
  budget is 16,600 us; spawning ~10-50 workers/frame costs 76-380 us = 0.5-2.3 % of budget. A thread-POOL only pays off if a
  design spawns hundreds-thousands of workers PER FRAME (>=~2000/frame would exhaust the budget). The numbers do NOT justify
  a pool yet.
- **(b) channel — NOT a bottleneck at game scale.** 40.1 M msg/s >> the 100s-1000s of task hand-offs a frame needs. Caveat: this
  is the UNCONTENDED same-thread fast-path (lock/unlock + signal, 25 ns); a real cross-thread blocking hand-off (condvar wakeup
  ~us) is slower and is NOT measured by this ping-pong — an honest follow-up lane.
- **(c) atomic contention — MEASURED WALL (does not parallelize).** Aggregate throughput on one shared seq-cst cell goes
  174.9M->113.7M->120.0M->100.2M ops/s as K=1->8: it CAPS/declines, never scales. Wall-time grows ~linearly with K. This is the
  textbook cache-line-bounce signature (the line ping-pongs between cores under `__atomic_fetch_add` seq-cst). A single hot
  shared counter is the lever for a sharded/striped counter — but ONLY if a real workload has one.
- **(d) N-thread scale — real threads parallelize CPU work.** Near-ideal to p=4 (3.41x, 0.85 eff). The p=8 drop to 0.59 is
  largely background-pool-load + memory-bandwidth/turbo confound on a busy 12-core box (spawn cost is 7.6us vs 24ms work/thread
  = 0.03 %, so NOT spawn-amortization-bound). Clean signal: the spawn/join path itself does not serialize.
- **(e) boxing — MEASURED, broadest tax.** 4.61x constant overhead, same result (pure overhead). Every `{tag,payload}` HexaVal
  push/index pays it; thread args box every value too. This taxes EVERY path, not just one lane.

### verdict + r4 next

The current primitives are ADEQUATE for the spawn (a) and channel (b) paths at realistic game-frame worker/task counts — a
thread-pool / job-system is **NOT warranted by these numbers** (would be blind-optimize). The two MEASURED walls are
(e) boxing 4.61x (always-on, codegen-addressable, byteeq-safe native-unbox of job payloads) and (c) single-atomic
non-scaling (sharded counter — only if a real workload exposes a hot shared cell).

**r4 (separate PR) = native-unbox job-payload (codegen)** — the broadest measured win since boxing taxes every path; gate
behind opt-in, prove with before/after on lane (e) + byteeq 3-target GREEN. (c) sharded-counter is deferred until a real
game workload shows a hot shared atomic (the bench's synthetic one-cell hammer is a worst-case proxy, not a real frame system).
Thread-pool is explicitly OFF the table at game scale per the (a)/(d) numbers.

## r4 — native-unbox job-payload: MEASURED WALL (memory-layout, NOT call-overhead) 🧱

owner: feat/game-thread-bench-v2 · MEASURED aiden x86_64 2026-06-27 · build/aprime_cc_r4 (fresh
gate-bearing native cc) + native --emit=obj run route (HEXA_RUN_NATIVE=1, default since #3782).

### the lever r3 named, and what it assumed

r3 attributed lane (e)'s **4.61×** boxed/raw tax to `{tag,payload}` HexaVal boxing on the array
push/index path and named r4 = "native-unbox job payload (codegen, opt-in, byteeq-safe)". The
implicit hypothesis: the tax is **call + tag-dispatch overhead** (every `buf[j]` → `call
hexa_index_get`, every `buf.push(x)` → `call hexa_array_push`) that a native inlined element
access would remove. **Measurement falsifies that hypothesis.**

### finding 1 — the access-unbox codegen ALREADY EXISTS and ALREADY FIRES (byteeq-safe)

`HEXA_UNBOX_ARRAY_NATIVE` (default-OFF, opt-in) in `compiler/codegen/x86_64_linux.hexa:1113-1290`
already replaces `arr[i]`/`arr[i]=v` boxed `call hexa_index_get/set` with an inlined HexaArr
descriptor walk, FOR a provably typed-prim array (MIR type_id 101..104 = `[i64]`/`[i32]`/`[f64]`/
`[f32]`) with a provably-int index. ARRU-debug trace on `let buf: [i64] = []`:
`[ARRU] index cont.type_id=101 idx.provint=1 gate_ok=1` — gate fires; ON asm emits 8 arru
fast-path lines + keeps 1 `hexa_index_get` (OOB slow path) vs OFF's single boxed call. Soundness
firewall = env-opt-in, container-must-be-typed-prim, OFF-path byte-identical (the existing
gen3≡gen4-safe pattern). This is exactly the codegen r4 would have built; it is already landed.

### finding 2 — it produces ZERO measurable speedup (the wall)

N=2M `boxed_accumulate` (push-loop + index-loop), native run route, OFF vs gate-ON, 3 runs each:

| form | OFF ratio (vs raw) | ARRAY-UNBOX ON ratio | Δ |
|------|--------------------|-----------------------|---|
| `let buf = []` (bench-as-written, untyped) | ~3.3× | ~3.4× | gate INERT (untyped → type_id 0 → can't fire) |
| `let buf: [i64] = []` (annotated, gate fires) | ~3.3× | ~3.4× | **within noise — no win** |

Pure index loop in isolation (N=5M, no push/alloc confound): OFF ~2.3× / ON ~2.3× — **no
measurable delta even when the fast-path provably emits.**

### finding 3 — ROOT (file:line): the tax is 16B-HexaVal memory traffic + realloc-grow, neither removable by access-unbox

- Every array element slot is a **full 16-byte HexaVal {tag@+0, payload@+8}** (LAYOUT locked,
  `stdlib/runtime/array_core.hexa:17`; element stride = sizeof(HexaVal) = 16). The native
  fast-path STILL does `imul rax,rax,16` + `mov dst,[r11+8]` (confirmed in emitted asm,
  `compiler/codegen/x86_64_linux.hexa:1232-1237`) — it eliminates the *call* + tag-dispatch but
  keeps the **same 16B-strided memory traffic** = half the cache density of a packed 8B `i64`
  array. The call was never the bottleneck; the per-element 16B traffic is. That is what the
  ~2.3× pure-index tax over a register-only raw loop measures.
- The **push half is the larger sub-cost** and is dominated by `hexa_array_push`'s **realloc
  grow-branch**, which is an explicit libc wall: `array_core.hexa:23-25` — "calloc/realloc — libc
  per-object heap, NO native seed exists (only the arena is native), so new()'s calloc descriptor
  + push()'s realloc grow-branch stay C (🧱 the seed cannot express a persistent
  individually-freeable heap)". A native fast-push could inline the in-bounds (len<cap) 16B store
  like arru_set, but every capacity-grow still falls to the C realloc, and the stored element is
  still a 16B HexaVal — so it cannot beat the memory-traffic floor either.

### verdict 🧱 — closed-negative for THIS lever; the real escape is a different data structure (already landed elsewhere)

"native-unbox the boxed-array access path" is a **measured closed-negative**: the codegen exists,
is byteeq-safe, fires correctly, and moves the ratio by 0 because the tax is memory-LAYOUT
(16B/elem + realloc), not call-overhead. This is NOT the Wall-A dynamic-type-erasure ceiling
(`compiler/check/types.hexa:931-939` generic-erase) — type provenance is proven fine here; it is a
distinct **memory-layout wall**.

The genuine lever for "unboxed job payload" is a **packed unboxed array** (8B-per-element `farr64`/
`farr32`, no per-element tag) — and that lever is **already closed** by the read-path boxing-unbox
campaign: `read_f32_array_at` → native `farr32` (4 B/elem), #3641/#3643, shipped v0.241.9+
([[project_hexa_boxing_unbox_campaign]], measured 522× RSS lever boxed int[] vs farr32). i.e. the
correct guidance for a perf-critical game job payload is "**use `farr`, not `[]`**" (a stdlib/usage
choice), not "codegen-unbox the boxed `[]`" (this round's null result).

### honest residual / next

- 🧱 No honest next round for *this* lever (access-unbox of boxed `[]`): measured ≈0 win, root is
  16B layout + libc realloc. Building a native fast-push that yields 0 measured gain would be
  filler — declined.
- The two MEASURED game-thread walls from r1 remain: (e) boxing (now characterized as a
  memory-LAYOUT tax → escape = packed `farr`, already landed) and (c) single-atomic non-scaling
  (sharded counter — still deferred until a real game workload exposes a hot shared cell).
- If a real game job-system materializes and its hot payload is a typed-prim array, the
  recommendation is `farr64` storage + (optionally) `HEXA_UNBOX_ARRAY_NATIVE` for the access — but
  the win comes from the 8B packing, not the access-unbox.
