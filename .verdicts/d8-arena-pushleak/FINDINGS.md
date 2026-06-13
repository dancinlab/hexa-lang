# d8-runtime hot-loop array leak (handoff da19aa72) — root cause + soundness wall

Status: **NOT FIXED (handoff stays OPEN).** A leak-free AND escape-safe fix is
NOT achievable as a contained `self/runtime_core.c` change. This document records
the verified root cause, the empirical soundness wall, and the validated-safe
partial mitigation. No corrupting fix was shipped.

Authored on summer (linux, CPU-only), fresh clone `~/d8-arena-work` off
origin/main `f1832e1ea`. Isolated runtime built+linked from the worktree;
program output verified byte-for-byte.

## SSOT

- `self/runtime_core.c` is gitignored and **generated** from the SSOT emitter
  `self/runtime_core_emit.hexa` (byte-identity gated by
  `self/runtime_core_byte_diff.hexa`, PASS at baseline).
- `self/runtime.c` (where the allocator lives) is a **frozen git seed**, also
  gitignored, restored by `tool/restore_frozen_seeds` from
  `FROZEN_SEED_REF=151c52c82502e93d01735c58b43b017d102fee63`. It has NO emitter.

## Verified root cause (deeper than the handoff states)

The handoff frames the bug as "arena scope-pop rewinds the bump pointer but
never free()s heap-promoted push-array buffers." That is a SYMPTOM. The actual
root cause is in `self/runtime.c`:

    static void hxlcl_free(void *p) { (void)p; }          // NO-OP
    static void *hxlcl_realloc(void *p, size_t n) {        // never frees old
        ... void* np = hxlcl_malloc(n); memcpy(np, p, ...); return np; }
    // malloc/free/realloc are #define'd to these in runtime_core.c (L344-346).

The runtime allocator is a **non-reclaiming bump allocator** (4 MB mmap chunks;
`hxlcl_free`/`hxlcl_munmap` are no-ops by design, for self-host compiler speed).
Therefore:

1. `free()` does NOTHING. Adding `hexa_val_free_tree()` calls at scope-pop is a
   complete no-op at the allocator level — it cannot reclaim anything.
2. Every `push()` grow leaks: `realloc` mallocs a new buffer and the old one is
   never freed. The per-grow sizes (8,16,...,2048) sum to ~64 KB per 2000-elem
   array — exactly the measured ~64 KB/iteration leak.
3. Peak RSS scales LINEARLY with iteration count -> jetsam SIGKILL (137) on
   long hot loops (QFORGE Sternheimer chi0 n=645).

`HEXA_ARRAY_PUSH_ARENA=1` "works around" this by routing push buffers through the
reclaimable bump arena (which DOES reset on scope-pop) — but that arena reset is
unsound for escapes (it rewinds memory still reachable from outer scopes), which
is why it corrupts (solves=0 vs 590). Same family as the unsound fix below.

This matches #3324 (core_fft), which did NOT fix the runtime — it reused fixed
`farr` scratch + explicit `farr_free` at the STDLIB level to dodge the leak.

## The soundness wall (why a contained runtime fix corrupts escapes)

In COMPILED (d8 native) mode the ONLY runtime escape barrier is
`__hexa_fn_arena_return` -> `hexa_val_heapify` on the RETURN value. Codegen emits
NO barrier for non-return escapes:

- module-global assignment `G = xs;` is a bare C store (codegen.hexa AssignStmt
  Ident arm) — never heapified.
- `hexa_array_set` / `hexa_map_set` store the value RAW — never heapified.

So an array created in a scope can escape via a global / outer container WITHOUT
the runtime ever observing it. Any free-on-scope-pop that frees non-heapified
arrays therefore frees still-live memory -> corruption.

## Empirical proof (summer, CPU)

Three runtime variants built from the same worktree and linked against the same
transpiled programs:

| variant            | mem RSS (20k / 100k iters) | escape-return | global-store     | arena-slice global |
|--------------------|----------------------------|---------------|------------------|--------------------|
| baseline           | 1.28 GB / 6.4 GB (LEAK)    | 332334000… ✓  | 174750/100/599 ✓ | 20/60/5 ✓          |
| libc-routed alloc  | 0.64 GB / 3.2 GB (2x↓)     | 332334000… ✓  | 174750/100/599 ✓ | 20/60/5 ✓          |
| + free-on-pop      | 3.8 MB / 3.8 MB (FLAT)     | 332334000… ✓  | **(empty/crash)**| **SEGV (exit 139)**|

- **libc-routing alone** = fully correct on every case, ~2x RSS reduction, no
  perf cost (slightly faster), 7/7 array+arena tests byte-identical to baseline.
  PARTIAL: does not flatten (final buffers still never free()d — nothing calls
  free on a dropped scope-local array).
- **free-on-scope-pop** (libc-free + register-arrays-in-scope + free
  non-heapified on pop) FLATTENS memory completely (6.4 GB -> 3.8 MB) AND keeps
  return-escapes correct — but **CORRUPTS global-store escapes** (prints nothing
  / wrong value) and **SEGVs on arena-slice global escapes**. This is the
  corrupting fix the handoff warned about; it was NOT shipped.

Repros under `repros/` (all 5 reproduce the table deterministically).

## What a complete sound fix requires (out of runtime_core.c scope)

Leak-free AND escape-safe needs escape barriers at EVERY non-return store that
can outlive the current scope:
- codegen: heapify-mark on module-global `Ident = arr` assignments;
- runtime: heapify the value arg in `hexa_array_set` / `hexa_map_set` when
  `__hexa_val_mark_top > 0`.
Then free-on-scope-pop becomes sound. This spans BOTH codegen.hexa AND
runtime_core_emit.hexa, plus a re-pin of the frozen runtime.c seed for the
allocator change — a multi-file release-pipeline change, not a contained
runtime fix.

## Recommended next steps

1. Land the GATED reclaiming allocator (`HEXA_RT_LIBC_ALLOC=1`, default OFF =
   byte-identical) as a safe 2x mitigation — `safe-reclaiming-alloc.patch`. This
   needs a re-pin of `FROZEN_SEED_REF` (release op) since runtime.c is a seed.
2. For full flattening: add the codegen + set-path escape barriers above, THEN
   wire free-on-scope-pop. Gate behind a flag until the barrier coverage is
   proven complete against the repro matrix.
3. Until then, the #3324 pattern (app-level fixed scratch + explicit free) is the
   only sound way to bound RSS in a specific hot loop.

DO NOT mark da19aa72 done.
