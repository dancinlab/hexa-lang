# RFC — lock-free MPMC queue perf (measured, reference-match verdict)

status: MEASURED on aiden (real OS threads, -DHEXA_THREADS) — uncontended head-to-head
        captured; CONTENDED (≥4+4) blocked by a runtime-substrate wall (arena not
        thread-safe). reference expectation (Vyukov beats mutex at ≥4 threads) NOT
        reproduced; divergence point specified.
bench: `test/game_lockfree_contended.hexa` (opt-in HEXA_THREADS, byteeq-neutral)
since: 2026-06-27
host: aiden, 12-core x86_64, taskset-pinned 0-11, 3-run median, background load ~2.5-3.4

## build recipe (the r3 thread-enabled path, reproduced)

1. regen `self/native/thread.c` from `self/native/thread_emit.hexa`
   (the on-disk `.c` ships STALE — missing the `atomic_cell_*` + real-pthread
   block — exactly the r3 reproducibility trap; MUST regen first).
2. `hexa build <bench>.hexa -o /tmp/x --c-only` → `build/artifacts/x.c`.
3. inject `extern HexaVal thread_spawn,…,atomic_cell_add,…;` decls (the
   C-transpiled bench references the runtime fn-globals but emits no extern decl
   for them — separate-TU link needs them forward-declared).
4. `gcc -O2 -DHEXA_THREADS -I self -c x.c` + `gcc -O2 -DHEXA_THREADS -c self/runtime.c`
   (runtime.c carries `hexa_clock()`=CLOCK_MONOTONIC wall-clock + the pthread block).
5. link: thread runtime.o FIRST + `array_core_native.o map_core_native.o`
   (the `rt_*_native` symbols) `-Wl,--allow-multiple-definition -lpthread -lm`.
6. run `HEXA_THREADS=1` (SOURCE_DATE_EPOCH unset so `time_ms`/`clock` are real
   monotonic), taskset-pinned.

stdlib fix needed to build: `thread_real.hexa` named a parameter `fn`
(`pub fn thread_start(fn, arg)`), which the current compiler reserves as a
keyword (FIX-6 parse error when the module is imported). Renamed → `worker_fn`.
byteeq-neutral (thread_real is opt-in, not in any self/ closure).

## numbers — UNCONTENDED 1 producer + 1 consumer (the only stable config)

3-run median, taskset-pinned, 100k tokens, conservation=true on every run:

| queue                         | throughput (ops/s) | vs mutex |
|-------------------------------|--------------------|----------|
| Vyukov lock-free (lfq_*)      | **1,353,412** (1.27-1.43 M) | 0.53×   |
| mutex+condvar channel (chan_*)| **2,590,750** (2.55-2.64 M) | 1.00×   |

→ even with NO contention the lock-free queue is **~1.9× SLOWER** than the mutex
channel. Root cause: `lfq_pop` allocates a 2-element `[ok, value]` result array
per pop (HexaVal boxing + `hexa_array_push`), whereas `chan_recv` returns the
value directly. The per-op allocation tax dominates the CAS-vs-lock difference.

(context: the r3 microbench measured the mutex channel at 40.1 M msg/s
UNCONTENDED — but that was a bare same-thread send→recv ping-pong with no
per-op array alloc. This bench measures full push+pop round-trips through the
queue API, so absolute numbers are not comparable to the 40M figure; the
load-bearing comparison is lock-free vs mutex under the SAME bench.)

## CONTENDED (4 producers + 4 consumers) — runtime-substrate WALL 🧱

`HEXA_THREADS=1 ... /tmp/lf_thr` with P=C=4 → **SIGSEGV (RC=139)**.
gdb backtrace (captured, 8 worker threads):

    Thread N: hexa_array_push () ← lfq_pop () ← lfq_consumer () ← _hexa_thread_entry

The crash is in `hexa_array_push` (building the `[ok,value]` return tuple), NOT
in the Vyukov CAS logic. `hexa_arena_alloc`/`hxlcl_realloc` (the global bump
arena) has NO mutex/atomic guard — concurrent allocations from ≥3-4 threads
race the shared bump pointer → heap corruption → SIGSEGV. At 1+1 the race window
is small enough that 100k pops survive; at 4+4 it crashes immediately.

## reference-match verdict — NOT reproduced; divergence specified 🧱

reference (crossbeam ArrayQueue vs Mutex<VecDeque>): the lock-free queue should
pull MULTIPLES AHEAD of the mutex at ≥4 threads (head/tail CAS scales, single
lock serializes). In hexa this is NOT reproduced, and the divergence point is
measured, not guessed:

1. the Vyukov ALGORITHM is correct — the single-thread oracle passes 18/18
   (FIFO order, full-rejection, wrap-around re-arm, conservation), and at 1+1
   real threads conservation holds (sum_in==sum_out).
2. the queue is slower uncontended (0.53×) because EVERY pop allocates its
   result tuple from the arena — hexa's `{tag,payload}` value-boxing turns each
   dequeue into an `hexa_array_push`, a cost the mutex channel (direct value
   return) does not pay.
3. the contended head-to-head — the whole point of a lock-free queue — CANNOT
   be measured: the shared arena allocator is not thread-safe, so ≥4 threads
   crash before any number is produced.

The wall is NOT the lock-free data structure; it is the **hexa runtime
substrate**: (a) value-boxing makes per-op allocation unavoidable, (b) the arena
allocator has no cross-thread synchronization. Until those are addressed (a
thread-safe / per-thread arena, and an unboxed integer fast-path for the queue
payload + result), a lock-free MPMC queue cannot beat — or even safely race —
the mutex channel under real contention.

## honest next (only if the substrate wall is taken on)

- **arena thread-safety** (runtime, the gating fix): a per-thread arena or a
  mutex/atomic-guarded bump pointer so ≥4-thread allocation is safe. This is a
  runtime-substrate change (`hexa_arena_alloc`), out of this bench's scope, and
  must be byteeq-3-target-verified — it touches the shared default allocator.
- **unboxed queue payload + non-allocating pop** (codegen/stdlib): make
  `lfq_pop` return `(ok, value)` without allocating a HexaVal array (an out-param
  or a packed int), removing the per-op `hexa_array_push`. This is the hexa
  beyond-parity lever (no-LLVM codegen shaping the queue op) — but it is moot
  until arena thread-safety lands, since even a non-allocating pop still touches
  the shared `vals` array across threads.

verdict: 🧱 MEASURED WALL — lock-free MPMC queue is algorithmically correct
(oracle 18/18, 1+1 conservation) but (i) ~1.9× slower than the mutex channel
even uncontended (boxing alloc tax) and (ii) crashes at ≥4 threads (non-thread-
safe arena). The reference scaling win is unreachable on the current runtime
substrate. Reported as a negative result with the divergence point specified.
