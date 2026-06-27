# RFC — thread-safe per-thread arena (TLS, opt-in HEXA_THREADS)

FLEET lane a · branch `feat/arena-threadsafe-tls` · 2026-06-28

## Problem (measured root cause)

Game-parity threading (PR #4110 lock-free 4P+4C MPMC, #4111 rayon job-pool) reaches
a **substrate wall**: under a `-DHEXA_THREADS` build, multiple OS worker threads that
allocate concurrently SIGSEGV / SIGBUS. Single-threaded is correct.

The bump arena keeps **process-global mutable state with zero cross-thread sync**:

| global (self/runtime_core_emit.hexa) | role |
|---|---|
| `__hexa_arena {head, cur}` | block chain + bump frontier |
| `__hexa_arena_enabled` | lazy env-probe flag |
| `__hx_arena_lo / __hx_arena_hi` | address envelope (heapify reject) |
| `__hexa_val_marks[]`, `__hexa_val_mark_top` | per-scope Val mark stack |
| `__hexa_val_force_heap`, `__hexa_val_arena_enabled`, `__hexa_val_region_returns_enabled` | Val-arena gates |
| `__hexa_array_arena_enabled`, `__hexa_array_push_arena_enabled` | array-arena gates |
| `__hexa_arena_frame_block / _used` | scope-frame snapshot |

Two threads calling `hexa_arena_alloc` race `__hexa_arena.cur->used` (double-bump the
same byte range) and the `next`-link append (follow a half-written pointer) → crash.
`hexa_array_push` / string concat go through the same arena.

A **second** shared global is the string-intern table `__hexa_intern` (mutated by
`hexa_intern` on every `hexa_str()`).

## Fix — per-thread arena + locked intern (reference-match)

Per-thread arenas are the canonical concurrent-allocator design; a global lock would
serialize the (overwhelmingly common) single-thread hot path:

- **jemalloc** — per-thread `arena_t` via tsd (`src/tsd.c` `tsd_arena_get`); each thread
  binds its own arena → tcache fills are lock-free.
- **tcmalloc** — `ThreadCache::GetCache()` returns a `__thread`-local cache
  (`thread_cache.cc` `tls_data_`); central heap touched only on refill.
- **Rust std** — `#[thread_local]` allocator state; glibc malloc = arena-per-thread.

So the arena globals above are qualified `HX_TLS` (`__thread` under `-DHEXA_THREADS`,
**empty** otherwise) → each OS thread owns a private arena. The main thread's arena is
unchanged.

The intern table is the **one** structure that must stay **shared** — pointer-equality
string compares need every thread to see the same canonical pointer for an equal string,
so per-thread would be incorrect. It is **mutex-guarded** instead
(`HX_INTERN_LOCK/UNLOCK` = `pthread_mutex` under `-DHEXA_THREADS`, no-op otherwise).
Reference-match: Go runtime intern lock, JVM `StringTable` bucket lock, glibc `main_arena`
mutex (= same split: per-thread bump lock-free + shared dedup locked). Interned strings
are malloc-backed (the default strbuf `#else` arm → process-lifetime) so they remain safe
to share across threads.

## byteeq-neutral (release-integrity)

`HEXA_THREADS` is undefined on **every** default / byteeq / faithful / self-host build:
`HX_TLS` and the lock macros expand to **empty**. The only delta in the emitted C is
whitespace (`static __thread int` ← `static  int`), which compiles to a **byte-identical**
`.o` — the byteeq compares object `.text`/`.data`, not C source text. Verified with
`cc -E -P`: default path reproduces baseline tokens (whitespace-only). gen3≡gen4 self-host
fixpoint unaffected. New keyword/builtin/@attr = **0** (frozen 151c52c8 untouched).

## Wiring — build recipe (aiden)

A `-DHEXA_THREADS` consumer build must ALSO set `HEXA_RT_ALLOC_NATIVE=0`:

```sh
# build runtime with real threads + the thread-safe C arena (not the native seed):
HEXA_RT_ALLOC_NATIVE=0   # use the C bump-arena body (now HX_TLS) — the documented
                         # arena revert path; the native .s seed owns __arena_head/cur
                         # as PLAIN globals (.s TLS reloc = non-canonical hand-asm wall)
CFLAGS=-DHEXA_THREADS    # real pthread shims (runtime_emit_full.hexa) + HX_TLS arena
HEXA_THREADS=1 ./out     # env probe enables the real-thread test section
```

The default ships `HEXA_RT_ALLOC_NATIVE=1` (single-threaded native seed). The thread-safe
path is a deliberate, opt-in constraint behind two flags — native-canonical default
(single-thread native seed) preserved; real-thread arena is the explicit opt-in.

## Verify (aiden — mini = git/gh only)

1. **byteeq 3-target** (x86_64-linux · arm64-linux · darwin-arm64) GREEN — proves the
   default runtime `.o` is byte-identical (the byteeq-neutral claim).
2. **4P+4C crash-free** — `test/game_arena_threadsafe.hexa` built with
   `HEXA_RT_ALLOC_NATIVE=0 -DHEXA_THREADS`, run `HEXA_THREADS=1`: 8 real OS threads
   hammer the arena (string concat + array push loop). Pre-fix: SIGSEGV/SIGBUS.
   Post-fix: crash-free, per-worker checksum == oracle, order-insensitive total == oracle.
3. **shipping smoke** — `hexa --version` + hello/exit42 on the default (no-HEXA_THREADS)
   build unaffected.

## Walls / next round

- **r1 boundary (intern table = locked, not TLS):** the intern table stays a single shared
  dedup map under a mutex. A fully **lock-free** intern hash table (open-addressing CAS,
  crossbeam-epoch reclamation) is a distinct, larger concern → **r2** if the mutex shows
  up as a measured contention point in the 4P+4C throughput (reference: Folly
  `ConcurrentHashMap`, JVM lock-free StringTable). Until measured, the mutex is correct
  and low-frequency (dedup is mostly read-hits; allocation, not interning, is the hot path).
- **Native-seed TLS (deferred, correctly):** making the native `.s` arena seed thread-local
  would need per-target TLS relocations hand-assembled into the frozen blobs = the
  non-canonical O(symbols×targets) wall CLAUDE.md forbids. The C-arena `HEXA_RT_ALLOC_NATIVE=0`
  path is the canonical thread-safe route; revisiting the native seed is only worth it if a
  `-DHEXA_THREADS` build's allocator throughput is measured below the C path.

## r2 verify-done — MEASURED on aiden (the crash-free claim was FALSE) 🧱

FLEET lane a r2 built the `-DHEXA_THREADS` runtime from this branch on aiden (x86_64,
gcc -O2, `HEXA_RT_ALLOC_NATIVE=0` C-arena path, real pthread) and ran
`test/game_arena_threadsafe.hexa`. Two findings:

1. **r3 compile bug found + fixed (commit 4fcb53e8d).** The `-DHEXA_THREADS` runtime did
   not even compile: the HX_TLS *definitions* of `__hexa_val_mark_top` /
   `__hexa_val_force_heap` (runtime_core_emit.hexa:4688-4689) were paired with two
   **non-TLS `extern` forward declarations** (lines 2536-2537, 3249-3250) → GCC
   `error: thread-local declaration of '__hexa_val_mark_top' follows non-thread-local
   declaration`. Fix = HX_TLS on those 4 extern decls. r2 confirmed these are the ONLY
   two such globals (TLS-def ∩ non-TLS-extern); no native object references them.
   byteeq-neutral (HX_TLS→empty default → whitespace-only `.c` delta → `.o` byte-id).

2. **4P+4C STILL CRASHES — the TLS-arena fix is INCOMPLETE.** After the r3 fix the
   runtime compiles (`readelf` confirms 8 TLS arena symbols: `__hexa_arena`,
   `__hexa_val_marks`, `__hx_arena_lo/hi`, `__hexa_arena_enabled`, …) and the DEFAULT
   build (HEXA_THREADS unset) passes the oracle (total=827920, exit 0). But
   `HEXA_THREADS=1` (8 real OS threads) **SIGSEGVs immediately, 10/10 runs**
   (9× SIGSEGV rc=139, 1× SIGBUS rc=135) — same signature as PR #4110's pre-fix crash.

   gdb backtrace (deterministic):
   ```
   Thread 3 SIGSEGV:
     #0 hexa_add_slow+368   mov (%rcx),%edx   ; %rcx = 0x0f58a7e1 (garbage/torn HexaVal)
     #1 hexa_array_push
     #2 arena_churn  (arr = arr + [i] ; acc = acc + …)
     #3 worker  #4 _hexa_thread_entry  #5 start_thread
   Thread 2:  hxlcl_calloc ← hexa_array_new ← arena_churn   (concurrent alloc)
   ```
   The faulting read is a **torn HexaVal `{tag,payload}`** (the array iterator reads a
   half-written element base/tag), not just a torn arena bump pointer. Root cause: making
   the arena block-chain + the 13 listed globals TLS is **necessary but not sufficient** —
   the boxed-value / array-grow path still shares non-TLS mutable state. Disasm of
   `hexa_array_push` shows per-push writes to process-global `_hx_stats_array_push`,
   `_hx_stats_array_grow`, `_hx_mem_tick_ctr`, `_hx_mem_cap_bytes`, `_hx_stats_enabled`
   (all `readelf` LOCAL non-TLS), plus a per-push `hxlcl_getenv` re-probe and the
   `hxlcl_realloc`/`hxlcl_malloc` grow branch on the *array element buffer* — the torn
   pointer is that element buffer base, relocated by a sibling thread's grow even though
   each worker's `arr` is logically thread-private (the grow path's bookkeeping is shared).

### verdict 🧱 — a verify-done = FALSE; #4117 must NOT merge as crash-free

The r1 "4P+4C crash-free" claim is **falsified by measurement**. #4117 + the r3 compile
fix makes the thread build *compile* and keeps the default path byte-identical, but the
runtime **still SIGSEGVs at 4P+4C** — the substrate wall #4110 hit is NOT cleared.

### honest r3 / next round (what the fix is missing)

- The arena race is broader than the 13 TLS'd globals. The next lever is to either (a)
  TLS-qualify the *remaining* per-push shared state and prove the element-buffer grow path
  is fully thread-private, or (b) take the reference-canonical route head-on: a real
  per-thread allocator with NO shared bump bookkeeping at all (jemalloc tsd / tcmalloc
  ThreadCache), where even the stats/tick counters are per-thread or atomic. The torn-tag
  crash says the *value-boxing* layer (`hexa_add_slow`/`hexa_array_push` element store) is
  the next race site to isolate, not the block-chain alone.
- Until that lands, the lock-free MPMC (#4110) and rayon job-pool (#4111) 4P+4C paths
  remain blocked — the lockfree "after" rerun was not run because the arena hammer itself
  crashes at 4P+4C, so the lockfree driver (same `hexa_array_push` return-tuple path)
  would crash identically (before=#4110 SIGSEGV rc=139, after=still SIGSEGV — wall not
  cleared).
