# RFC — work-stealing job-system perf (measured: threaded path unrunnable)

status: MEASURED on aiden (real OS threads, -DHEXA_THREADS) — NO throughput
        number captured: the threaded pool path crashes before producing one.
        Same runtime-substrate wall as the lock-free queue (HexaVal arena/struct
        not thread-safe). reference expectation (rayon work-stealing absorbs an
        unbalanced workload) NOT reachable.
bench: `test/game_jobpool_perf.hexa` (opt-in HEXA_THREADS, byteeq-neutral)
since: 2026-06-27
host: aiden, 12-core x86_64, taskset-pinned 0-11

## build recipe (the r3 thread-enabled path, reproduced)

Identical to the lockfree lane: regen `self/native/thread.c` from its emitter
(STALE on disk — the r3 trap), `hexa build --c-only`, inject the thread/atomic
`extern HexaVal …` decls, `gcc -O2 -DHEXA_THREADS`, link thread runtime.o +
`array_core_native.o map_core_native.o -Wl,--allow-multiple-definition -lpthread`,
run `HEXA_THREADS=1` taskset-pinned. (thread_real.hexa param `fn`→`worker_fn`
keyword fix as in the lockfree lane.)

## result — threaded pool path crashes (no jobs/s captured) 🧱

| config                          | outcome |
|---------------------------------|---------|
| DEFAULT build (no -DHEXA_THREADS)| does NOT link — `atomic_cell_store`/`atomic_cell_add` are HEXA_THREADS-gated runtime globals, absent in the default runtime (the bench uses stdlib/atomic_real). |
| -DHEXA_THREADS, RAYON_NUM_THREADS=1 | `map key 'submitted' not found` (flood) → SIGBUS (RC=135) |
| -DHEXA_THREADS, RAYON_NUM_THREADS=2 | same — `map key 'submitted' not found` → SIGBUS |
| -DHEXA_THREADS, RAYON_NUM_THREADS=8 | SIGBUS (RC=135) |

gdb backtrace (8 workers, captured):

    Thread 1 SIGBUS: hxlcl_realloc () <- hexa_array_push () <- pool_submit () <- main ()

TWO failure surfaces, both runtime-substrate:

1. **`map key 'submitted' not found`** — `pool_submit` does
   `atomic_incr(p.submitted)`. In the threaded backend the `ThreadPool` struct
   (now carrying populated `tids`/`bottoms`/`tops` arrays) is represented at
   runtime as a MAP, and the `.submitted` field access degrades to a failed map
   lookup. The struct field-access path is not reliable for this struct shape
   under the threaded path.

2. **SIGBUS in `hxlcl_realloc` ← `hexa_array_push` ← `pool_submit`** (MAIN
   thread) — `pool_submit` builds a `[job, arg]` HexaVal array per submission
   (`_make_job`) and pushes it on the injector channel. While the main thread
   keeps allocating/realloc'ing these arrays in the shared arena, the worker
   threads concurrently `chan_recv` and read them; the arena `realloc` relocates
   the block under the readers → SIGBUS. Same non-thread-safe-arena wall the
   lock-free lane hit (there it was SIGSEGV in `hexa_array_push` from the
   consumer side; here it is SIGBUS from the producer/submit side).

## reference-match verdict — NOT reachable; divergence specified 🧱

reference (rayon / Chase-Lev work-stealing): on an UNBALANCED workload (heavy +
light jobs interleaved) idle workers steal the queued light jobs while heavies
run, so wall-time stays near the balanced case (steal efficiency → 1.0). This
CANNOT be measured in hexa: the pool's threaded path crashes before any job
throughput is produced, at every worker count tested.

The wall is NOT the work-stealing algorithm (the default-synchronous oracle in
test/game_jobpool_bench.hexa passes — uniform/unbalanced reduces match the
closed-form reference, order-insensitively). The wall is the **hexa runtime
substrate** under real threads:
- the per-submission `[job,arg]` HexaVal array allocation races the shared,
  non-thread-safe arena (`hexa_arena_alloc`/`hxlcl_realloc`) → SIGBUS;
- the `ThreadPool` struct field-access degrades to a failed map lookup under the
  threaded code path.

Both are the same class of finding the lock-free lane measured: hexa's
value-boxing + shared arena + struct→map representation are not safe for
allocating real-thread workloads.

## honest next (only if the substrate wall is taken on)

1. **arena thread-safety** (runtime, gating) — a per-thread arena or a
   guarded bump pointer so concurrent `hexa_array_push`/`realloc` from N threads
   is safe. byteeq-3-target-verified (touches the shared default allocator).
2. **struct field-access under threaded path** (codegen/runtime) — the
   `.submitted` map-lookup-not-found is a struct-representation bug to root-cause
   separately (struct → reliable field access regardless of array-field
   population / thread arg boxing).
3. **non-allocating job dispatch** (stdlib/codegen, the beyond-parity lever) —
   pass jobs through the channel without per-submit HexaVal-array allocation
   (e.g. a packed fn+arg int pair), removing the arena pressure. Moot until (1).

verdict: 🧱 MEASURED WALL — the work-stealing pool is algorithmically sound
(default-synchronous oracle passes) but its real-thread path is unrunnable on
the current runtime: SIGBUS in the shared arena (`hexa_array_push`/`realloc`
under concurrent worker reads) plus a struct→map field-access failure. No
jobs/s or steal-efficiency number could be honestly captured. Reported as a
negative result with the crash sites specified.
