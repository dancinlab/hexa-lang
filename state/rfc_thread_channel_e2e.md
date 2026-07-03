# RFC — thread_channel 2P+2C producer–consumer end-to-end (FLEET 잔여 #4 r2)

Status: build/measure on aiden (mini cannot build). WIP-checkpoint pushed before
measurement (이전 r1 a664ea5d 가 aiden idle 서 verdict/push 없이 종료 → 재시작).
Base: origin/main (#4140 descriptor · #4143/#4151 escape-relax · #4154 thread
fn-global fwd-decl · #4157 carrier bind · #4159 arm64).
Branch: feat/thread-channel-e2e.

## Problem / gap

#4154 proved `thread_spawn`/`thread_join` real-pthread e2e with a SHARED buffer,
but the mutex+condvar CHANNEL hand-off (`thread_channel_{new,send,recv,close}`)
was never exercised end-to-end across multiple producers AND consumers — the
core primitive for a game thread-pool / actor / job-queue. This lane closes that
gap with a SMALL N:M (2P+2C) producer–consumer + total-sum oracle.

## Primitive census (self/native/thread.c · emitter self/native/thread_emit.hexa)

  - `thread_channel_new()`           thread.c:134  → ch_id (>=0) / -errno (-EAGAIN full table)
  - `thread_channel_send(ch, v)`     thread.c:157  → 0 / -errno; blocks while
                                       count==CAP(1024); -EPIPE if closed
  - `thread_channel_recv(ch, t_ms)`  thread.c:183  → val OR "" sentinel;
                                       t<0 block · t=0 nonblock peek · t>0 timed (ETIMEDOUT→"")
  - `thread_channel_close(ch)`       thread.c:224  → 0 / -errno; broadcasts
                                       not_empty/not_full → blocked recv returns "" once drained
  - fn-global carriers               thread.c:261-264 (+ runtime.h:735-738, #4157 bind reg)
  - real pthread/condvar engaged only when runtime.c built -DHEXA_THREADS
    (runtime_emit_full.hexa:2472); DEFAULT build = synchronous shim
    (cond_wait = no-op → blocking recv spins). #4100 measured channel ping-pong
    at 40M msg/s.

KEY: the #4154 harness (measure_thread_fnglobal.sh) built runtime.a WITHOUT
-DHEXA_THREADS, so its "4P+4C" actually ran the synchronous inline shim (no real
OS threads). For a TRUE blocking channel hand-off the runtime AND the test MUST
be built -DHEXA_THREADS — this harness does so.

## Design (test/channel_2p2c_e2e.hexa · byteeq-NEUTRAL, NEW test file only)

  (1) ORACLE — always runs, default-build-safe. Pure arithmetic: total each
      producer WILL push, Σ_{i=1..ITEMS}(base*BIG+i). No channel/thread ops.
      ITEMS=200, BIG=1e6 → hand value oracle_total = 200040200.
  (2) REAL 2P+2C — gated by env("HEXA_THREADS"). 2 consumers spawn FIRST and
      BLOCK on the empty channel; 2 producers push 200 ints each (disjoint
      ranges); producers join; channel closes; consumers drain remaining + see
      "" sentinel; Σ(consumer partial sums) must == oracle. Sub-asserts:
        · thread_channel_new() >= 0
        · nonblocking recv on empty == "" (t=0 path)
        · timed (50ms) recv on empty == "" (ETIMEDOUT path)
        · Σ producer pushed-sums == oracle
        · 2P+2C consumed total == oracle (no loss/dup, lock-protected dequeue)
        · blocking recv on closed+drained channel == "" (close signal)

  thread_spawn passes ONE HexaVal arg → CH is a top-level mutable global
  referenced by both worker fns (the proven SHARED_CELL pattern,
  game_thread_microbench.hexa:94/97). Consumer uses a flag-controlled while
  (no `break`, not used as loop control in the test corpus).

## Harness (tool/measure_thread_channel_e2e.sh — aiden)

  - runtime.a built -DHEXA_THREADS (real pthread + condvar).
  - hexat transpiles test → user.c; clang -DHEXA_THREADS … -lpthread.
  - ORACLE run (no env) + 2P+2C run (HEXA_THREADS=1).
  - crash-free soak: CRASH_RUNS(20)× the 2P+2C binary, expect rc=0 + "0 failed"
    each (race-soak: order-insensitive total must be invariant).
  - G-BYTEEQ: DEFAULT runtime.o byte-identical branch vs origin/main (no runtime
    /codegen source touched → trivially neutral; verified by cmp).

## Verdict (filled after aiden run)

  - ORACLE rc: <pending>
  - 2P+2C rc + consumed total == oracle: <pending>
  - crash-free soak: <pending>/20
  - G-BYTEEQ DEFAULT runtime.o: <pending>

No new keyword/builtin/@attr; frozen 151c52c8 unchanged. mini = git/gh only.
