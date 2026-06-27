# RFC — M:N green-thread scheduler + async integration (opt-in, default-OFF)

Status: **design + oracle + cooperative N=1 executor landed; real parallel C substrate = build-gated next slice**
Lane: `real-concurrency-mn` · continuation of `state/rfc_real_concurrency_optin.md` (slice ②).
Date: 2026-06-27 · SSOT for the M:N runtime design. History → CHANGELOG + git.

---

## 0. Problem — two concurrency halves that never met

hexa currently ships **two disjoint concurrency mechanisms**, and neither is an M:N
runtime:

| half | file | what it is | gap |
|------|------|-----------|-----|
| **real OS threads (1:1)** | `stdlib/thread_real.hexa` + `self/native/thread_emit.hexa` → `thread.c`, gated `self/runtime_emit_full.hexa:2472` `#if defined(HEXA_THREADS)` | `thread_spawn` = **one `pthread_create` per task, run-to-completion**, joined by handle. Real multicore (slice ② / PR#4050). | no worker pool, no work-stealing, no yield/park — a spawn of 100k tasks = 100k OS threads. |
| **cooperative green threads (M:1)** | `self/async_runtime.hexa` | a `Scheduler` with a **single** `ready_queue`, futures, park-on-`wait_*`, round-robin. Pure-hexa simulation. | single global queue, no per-worker locality, no real OS parallelism (sim only). |
| **work-stealing model (N)** | `self/work_stealing.hexa` | per-worker deques + steal-from-front, but tasks are **run-to-completion** and `scheduler_start`/`worker_loop_step` are explicitly `// In full impl, spawn OS worker threads` / `// run interpreter` — never wired to threads. | not wired to threads; no park/resume (can't model a blocked goroutine). |

**M:N** = the missing union: **M** green-thread tasks (G) multiplexed onto **N**
worker processors (P), each P with a local run-queue, idle P stealing from a busy P,
a task **yielding its P when it blocks** (channel recv on empty) and being **made
runnable again** when a sender hands it a value. That is exactly the Go GMP
scheduler.

## 1. Reference — Go runtime GMP (white-box)

The design is reference-matched to the Go runtime scheduler (the canonical production
M:N implementation). Cited symbols (Go `src/runtime/`):

- `runtime2.go` — `g` / `m` / `p` structs; G states `_Grunnable`/`_Grunning`/`_Gwaiting`/`_Gdead`; **P owns `runq [256]guintptr`** (a fixed local ring) plus a one-slot `runnext`.
- `proc.go schedule()` — the per-M loop: find a runnable G, switch to it.
- `proc.go findRunnable()` — **order**: P-local `runqget` → `globrunqget` (global injector) → `netpoll` → `stealWork`. (Our `mn_findrunnable` mirrors local→global→steal; netpoll is N/A in a CPU-only oracle.)
- `proc.go runqsteal()` / `runqgrab()` — an idle P steals **~half** of a victim P's local queue from the **oldest (head/FIFO) end**.
- `proc.go globrunqget()` — pulls a **batch** (`n/gomaxprocs + 1`) off the global queue.
- `proc.go runqput()` / `runqputslow()` — push to the local P; on overflow move half to the global queue.
- `chan.go chansend()` / `chanrecv()` — a recv on an empty chan **`gopark`s** the G (→ `_Gwaiting`); a send with a waiting receiver hands the value **directly** and `goready`s it (→ `_Grunnable`, re-enqueued).
- `GOMAXPROCS` = number of P = the **N** in M:N.

Cross-language corroboration (same model, different sugar): Rust **tokio**
multi-thread runtime (per-worker `Local` deque + `Steal`, `Injector` global queue,
`tokio/src/runtime/scheduler/multi_thread/`); Erlang BEAM run-queues per scheduler
with migration; .NET ThreadPool work-stealing queues.

## 2. Design — three layers

```
   M green-thread tasks (G)                     ← user `go`/spawn
        │  runqput
        ▼
   N processors (P) — per-P local deque ──steal──▶ other P    ← work-stealing
        │  findrunnable: local→global→steal
        ▼
   bound to N OS worker threads (M = pthread)   ← real parallelism (HEXA_THREADS)
        │
   global injector queue  ◀── runqputslow overflow + goready(woken G)
```

- **G (task)**: id, state, park-reason, entry closure, result. Blocking on a channel
  = `gopark` (yield P); woken by a sender = `goready` (re-enqueue).
- **P (processor)**: a local run-queue deque. Owner pushes/pops the **back** (LIFO =
  cache locality of freshly-spawned work); a thief steals from the **front** (FIFO =
  oldest/coldest). On local-queue overflow, spill to the global queue.
- **Worker (M / OS thread)**: a fixed pool of N pthreads (NOT 1-per-task), each
  running the `schedule()` loop: `findrunnable` → run G until it returns or parks.

## 3. What landed in THIS slice (byteeq-neutral, mini-tractable)

`self/mn_scheduler.hexa` — the **executable SPEC / oracle** for the design above,
written in the functional/immutable interpreter subset so it runs under the plain
`hexa run` and stays **byteeq-neutral** (not in the self-host compiler closure;
registered for documentation in `self/lib.hexa` only, exactly like `async_runtime`
+ `work_stealing`). It unifies the three halves:

- per-P deques + steal (from `work_stealing.hexa`), **plus**
- cooperative `gopark`/`goready` on channel block (from `async_runtime.hexa`), **plus**
- a global injector queue with `runqputslow` overflow and `goready` re-enqueue (new),

and encodes the Go transitions as a **pure deterministic function of its inputs** —
so it doubles as the **byte-eq test oracle** for the future C substrate: a correct
`-DHEXA_MN_SCHED` build, single-stepped in the same order, MUST reproduce the exact
transition counts (`n_steals` / `n_global_gets` / `n_parks` / `n_ready` /
`n_completed`).

Tests (`hexa run self/mn_scheduler.hexa`): **10 test fns / 29 assertions, 0 FAIL**
(captured in isolation on the local interpreter — the all-in-one process times out
only on the stale Jun-25 build's slow native compile, not on logic). Covers GMP
mapping, round-robin runqput, LIFO local pop, global overflow, findrunnable
order (local→global→steal), FIFO steal of the oldest, park-on-empty-recv,
goready-direct-handoff on send, buffered send/recv, full drain-to-idle.

## 3b. Cooperative N=1 green-thread executor — LANDED (opt-in `HEXA_COROUTINE`)

The oracle in §3 is a **pure transition function** — it *models* the GMP state
machine but does not actually **drive** a task forward through suspendable segments.
This slice adds the smallest real, runnable executor on top: a **GOMAXPROCS=1
cooperative scheduler** that genuinely spawns green threads, yields between explicit
step segments, and joins to completion — a single OS thread with a fully
deterministic round-robin yield order. It is gated behind the opt-in env
`HEXA_COROUTINE` (mirroring `atomic_ops.hexa:atomic_real_enabled`'s `env("HEXA_THREADS")`
precedent — an existing builtin, no new keyword, frozen-safe) and is **byteeq-neutral**
(the file is not in the self-host compiler closure; the executor fns are inert pure
definitions unless called, and they are called only inside the env-gated test block —
so default `hexa run self/mn_scheduler.hexa` output is byte-identical to §3's oracle).

**Reference-match (Go GMP @ GOMAXPROCS=1).** With N=1 there is exactly one P, so
`proc.go findRunnable()`'s `stealWork` loop is a **no-op** (no victim P) and the pick
order collapses to a single FIFO ready queue (`runqget`→`globrunqget`). The
cooperative yield is `proc.go goschedImpl()`/`Gosched()`: the running G is set
`_Grunnable` and **re-enqueued runnable**, then the scheduler picks the next G. Core
rule reproduced: **a single P ⇒ fully deterministic round-robin at every explicit
scheduling point** (here each step-segment boundary == one `Gosched`). Cited in the
module header.

**API** (`self/mn_scheduler.hexa`, all immutable/returns-fresh):

- `MNCoroTask { id, steps:[string], resume_pc, state, result }` — a resumable green
  thread = explicit step segments + a resume PC (honest non-preemptive model).
- `MNCoop { ready:[int], tasks, trace:[string], n_yields, n_completed }` — a **single
  FIFO ready queue** (= GOMAXPROCS=1, one P, no steal). `trace` is the deterministic
  interleave record == the byte-eq signal a future C substrate must reproduce.
- `mn_coop_new()` · `mn_coop_spawn(s, steps)` (enqueue runnable to BACK) ·
  `mn_coop_step(s)` (dequeue FRONT, run `steps[resume_pc]`, append `"<id>:<pc>"` to
  trace, advance pc; if more segments → **yield**: requeue to BACK + `n_yields++`,
  else **done** + `n_completed++`) · `mn_coop_run(s)` (drive until ready drains) ·
  `mn_coop_join(s, tid)` (drive until task `tid` is "done").

**Tests** (run only under `HEXA_COROUTINE=1`): `test_coop_spawn_yield_join` (3 tasks ×
2 segments → asserts the exact round-robin interleave `1:0, 2:0, 3:0, 1:1, 2:1, 3:1`,
all done, `n_yields == 3`), `test_coop_join_returns_result` (join drives a 3-segment
task to "done", result delivered), `test_coop_n1_deterministic` (two independent runs
→ identical trace). Default run = unchanged 10 fns / 29 assertions; `HEXA_COROUTINE=1`
= +3 coop tests.

**Honest scope / wall.** Yield here is **cooperative-explicit** (step + resume-PC),
**NOT** true preemptive mid-function suspension with register/stack save — that
remains walled exactly as §5 (frozen 151c52c8 parser blocks stackless CPS; stackful
`ucontext` is build+race-gated, pool-only). This slice delivers the requested
deterministic N=1 cooperative **spawn / yield / join**, not register/stack-saving
coroutines, and not real parallelism (N=1, single OS thread).

## 4. Real C substrate — the next slice (build-gated, NOT in this PR)

The production runtime lives behind a **new opt-in macro `HEXA_MN_SCHED`** (default
unset → not compiled → runtime.c object byte-identical → byteeq gen3≡gen4
unaffected, same isolation discipline as `HEXA_THREADS`). Emitted via the **emitter
SSOT** — `self/native/thread_emit.hexa` (→ `thread.c`) and/or
`self/runtime_emit_full.hexa` — **never** by hand-editing the gitignored `.c`. It
requires (all of which the emitter CAN express in C; none need a new keyword/`@attr`
or a frozen-blob 151c52c8 parser change):

1. **Worker pool** — `pthread_create` × N once at init (N = `GOMAXPROCS` env, default
   = online CPUs), each running the `schedule()` loop. Reuses the existing
   `hxlcl_pthread_*` floor shims already gated under `HEXA_THREADS`.
2. **Chase-Lev work-stealing deque** in C — lock-free `push`/`pop` (owner) + `steal`
   (thief) over the `_Atomic` cells already provided under `HEXA_THREADS`
   (`self/native/thread_emit.hexa:296` block). Reference: Chase & Lev 2005, "Dynamic
   Circular Work-Stealing Deque"; Le et al. 2013 correct C11 memory orders.
3. **Global injector queue** — a mutex-guarded MPMC queue (the condvar-backed channel
   substrate in `thread.c` is the template).
4. **Bind G ↔ P ↔ M** with the same findrunnable order as the oracle.

## 5. THE WALL — true preemptible green-thread *yield* (honest stop)

Layers 1–4 above give an **M:N executor of run-to-completion tasks** (M tasks, N
workers, work-stealing). The *full goroutine* semantics — a G that **suspends
mid-function** at a channel recv, yields its OS worker to another G, and resumes
later on **any** worker — needs one of two things, and **both hit a measured wall on
this stack**:

- **(A) Stackless CPS / async-state-machine transform in the compiler frontend** (how
  Rust `async fn` and C# `async` lower). **WALL**: the parser is the **frozen blob
  151c52c8**; introducing `async`/`await`/`yield` as real suspension points (not the
  current RFC-022 "parse-but-run-synchronously") requires new frontend lowering the
  faithful build cannot parse → faithful build-break. Out of bounds per the
  no-new-keyword guardrail.
- **(B) Stackful coroutines (one stack per G, swap on yield)** — `ucontext`
  `makecontext`/`swapcontext` or a hand-written register-save trampoline. This CAN go
  through the emitter SSOT as C under `HEXA_MN_SCHED`, but: (i) `ucontext` is
  deprecated/absent on some targets (POSIX-obsolescent; macOS keeps it, musl-static
  is fragile); (ii) the current task entry runs via `hexa_call1(fn_val, arg)` which
  **runs to completion** — to make `hexa_channel_recv` yield back to the scheduler
  mid-call, the channel primitives must become **scheduler-aware** (swap to the
  worker's scheduler context instead of `pthread_cond_wait`), i.e. a non-trivial
  rewrite of `thread.c`'s channel + a per-G stack allocator; (iii) verifying it is
  **build + multicore-race-test gated** — forbidden on `mini` (git/gh only), requires
  the aiden/summer pool.

**Decision (release-integrity > self-host progress):** land the design + the
byteeq-neutral oracle now; do **NOT** speculatively merge an unverified C substrate.
The run-to-completion M:N executor (layers 1–4) is the next pool-built slice; full
stackful-yield (B) is the slice after that, both gated on `mini`-forbidden multicore
build+race verification. Stackless (A) stays walled by the frozen parser.

## 6. Determinism / release-integrity invariants (every slice)

- Default build never defines `HEXA_MN_SCHED` (nor `HEXA_THREADS`) → substrate
  preprocesses out → runtime.c object **byte-identical to origin/main** → byteeq
  gen3≡gen4 fixpoint unaffected. The self-host / faithful / byteeq builds are the
  deterministic single-threaded path and can never observe a thread schedule.
- No new keyword / builtin / `@attr` (frozen 151c52c8). Reuse `hxlcl_pthread_*` +
  `_Atomic` floor already present under `HEXA_THREADS`.
- `.c` is a gitignored build artifact — edit the `*_emit.hexa` SSOT only.
- Promotion to default-ON is **user-go** + 3-target (x86_64-linux · arm64-linux ·
  darwin-arm64) byteeq GREEN + shipping smoke, on the pool — never from `mini`.
