# RFC — thread fn-global forward-declaration in runtime.h (FLEET A3)

Status: build/measure pending on aiden (mini cannot build).
Base: feat/array-descriptor-discriminator (#4140 descriptor discriminator + #4143/#4151 escape-relax).
Branch: feat/thread-fnglobal-fwddecl.

## Problem (DX defect · ING#33 class)

A hexa SOURCE that directly spawns N OS threads sharing an escaping packed
`[i64]` buffer fails to compile through aprime / the C-transpile path:

  - The thread fn-globals — `thread_spawn` / `thread_join` /
    `thread_channel_{new,send,recv,close}` / `sleep_ms` / `now_ms` (+ atomic
    `atomic_cell_*` under `-DHEXA_THREADS`) — are TAG_FN shim *carrier globals*
    (`HexaVal thread_spawn;`) defined in native/thread.c and registered at
    runtime by `_hexa_init_thread_fn_shims`.
  - They were NOT forward-declared in `self/runtime.h`, so user.c that
    references `thread_spawn(fn,arg)` hits an undeclared identifier
    (C-transpile) / unresolved S1 name (aprime). Same class as ING#33
    (edge-clang fn-global undeclared).

`self/runtime.h` is a HAND-MAINTAINED tracked header (not emitter-generated).
The fn-pointer carriers for the pipe/exec families (`hx_pipe_*`, `hx_setenv`,
`sha1`, …) are already declared there by hand as `extern HexaVal <name>;` —
the canonical pattern. The thread/atomic carriers were simply never added.

## Census (file:line)

native/thread.c carrier globals (emitted by self/native/thread_emit.hexa):
  - thread_emit.hexa:383-390  unconditional thread carriers (thread_spawn …
    now_ms) — OUTSIDE the HEXA_THREADS guard.
  - thread_emit.hexa:364-369  atomic carriers (atomic_cell_*) — INSIDE the
    `#if defined(HEXA_THREADS)` guard (opens 296, closes 370).
  - thread_emit.hexa:392-409  `_hexa_init_thread_fn_shims` registers all via
    hexa_fn_new.

runtime.h before fix:
  - lines 720-727  the `hexa_thread_*`/`hexa_channel_*` *functions* ARE
    declared, but NO `extern HexaVal thread_*;` carrier lines.
  - reference pattern: runtime.h:630-637 `extern HexaVal hx_pipe_close; /* … */`
    (persistent_pipe carriers — bodies emitted by persistent_pipe_emit.hexa:440,
    externs added BY HAND to runtime.h).

## Fix (canonical · declaration-only)

self/runtime.h after thread.c fn decls (post line 727): add
  - 8 unconditional `extern HexaVal thread_spawn; …`
  - 6 `extern HexaVal atomic_cell_*;` under `#if defined(HEXA_THREADS)`
matching the existing carrier pattern. DECLARATIONS only — no code, so the
emitted .o is expected byte-identical (byteeq-neutral). No new keyword; frozen
blob 151c52c8 untouched.

New end-to-end test: test/real_spawn_packed_buf.hexa — hexa source that
directly `thread_spawn`s 4 workers, each producing+consuming an escaping packed
`[i64]` buffer (HEXA_PACK_ESCAPING), then `thread_join`s; the joined total must
equal the single-thread oracle. The real-thread 4P+4C variant that the A2 probe
(test/escaping_packed_worker_buf.hexa:43-52) named as a follow-on.

## Verification (aiden x86_64-linux — MEASURED 🏁, tool/measure_thread_fnglobal.sh)

sha 96ec23c8c · aiden-B650M-K · 2026-06-27.

- runtime.a (-DHEXA_PACK_ESCAPING) EXIT=0; DEFINES thread_spawn + thread_join.
- runtime.h DECLARES extern HexaVal {thread_spawn, thread_join,
  thread_channel_recv, sleep_ms, now_ms} (the fix is present).
- aprime EXIT=0.

AFTER (patched runtime.h — carrier decls present):
  - hexat transpile → user.c references `thread_spawn` as a bare-ident carrier
    (`HexaVal t0 = hexa_call2(thread_spawn, hexa_fn_new((void*)worker,0), …)`).
  - oracle (HEXA_PACK_ESCAPING=1)        rc=0 — 1/1 PASS, total=323200,
    worker(0)==80200.
  - 4P+4C (HEXA_PACK_ESCAPING + HEXA_THREADS) rc=0 — 2/2 PASS,
    "4P+4C spawn+join escaping total == oracle". 4 OS-thread workers each owning
    an escaping packed [i64] buffer survive, joined total == single-thread
    oracle. THIS is the a end-to-end (hexa source multithread, not C-probe). 🏁

BEFORE (runtime.h carrier decls stripped):
  - compile FAILED rc=1 —
    "error: use of undeclared identifier 'thread_spawn'" at
    before.user.c:137  HexaVal t0 = hexa_call2(thread_spawn, …).
  - This is the exact ING#33 class (edge-clang fn-global undeclared). The
    fwd-decl is the load-bearing fix.

G-BYTEEQ:
  - DEFAULT (no -DHEXA_PACK_ESCAPING, no -DHEXA_THREADS) runtime.o BYTE-IDENTICAL
    before/after the runtime.h decl (x86_64-linux). Declaration-only confirmed.
  - arm64-linux + darwin-arm64 byteeq delegated to CI 3-target gate (mini cannot
    build; a decl-only header change is target-independent — no codegen path
    touched).

## ING#33 cross-benefit

The same defect class (a fn-global referenced by user.c but undeclared in
runtime.h) breaks the edge-clang `hexa build`/`run` flow. These thread carriers
were a concrete instance; the fix declares them the canonical way, so any hexa
source using OS threads now builds through the C-transpile path on edge-clang
too (not just the threading test).

## Wall / next

No wall — a end-to-end is closed. b·c were already substrate-close
(#4140 runtime descriptor + #4143/#4151 codegen escape-relax). honest next
(orthogonal, not this PR): thread_channel_* (send/recv) end-to-end producer-
consumer over a real channel, and aprime native-backend resolution of the
thread carriers (today the user-facing C-transpile/`hexa run` path is fixed;
raw `aprime --emit` S1 name-resolution is a separate seed list).
