Repo writes are denied in this session (same as the F2 design round), so the full design is below, ready to paste to `state/hexa-own/flip6_native_heap_design_fable.md`.

---

# FLIP-6 — native RECLAIMING heap allocator (`HEXA_RT_HEAP_NATIVE`) · axis-② terminal flip

**TL;DR**: Segregated size-class free-lists (non-coalescing, LIFO) carved from 4 MB mmap arenas for small blocks + mmap-per-allocation/munmap for large blocks, emitted as a C body in the **shim TU** behind `-DHEXA_RT_HEAP_NATIVE`, keeping the F2 +16/magic header ABI unchanged. The HXFARR carve-out re-routes from `__libc_calloc/__libc_free` to two new cross-member exports `hxlcl_heap_calloc/hxlcl_heap_free`. One `_heap_def` stage variable feeds **five** compile sites (the #4614 LAW). PR-A is byte-neutral OFF; the flip is a 1-line tri-state change gated on byteeq 3-target reconverge + the L1/L3 leak witnesses.

**Anchor validity**: I verified the five emit files are blob-identical between local HEAD and origin/main (`3a5ea08fb`), so their line numbers below are current. `tool/stage_resolve_runtime_a` anchors are **origin/main** — the local checkout is detached pre-#4679; do not trust local line numbers for that file.

## 0. Surface correction + PREREQ census (before any code)

Your scout said 5 UNDs; the prior plan (`state/hexa-own/done_3blocker_execution_plan_fable.md:71-73`) said exactly 3. Source-level read says the truth is probably **4**:

| UND | producer | verdict |
|---|---|---|
| `malloc` | shim `hxlcl_malloc` F2 arm `malloc(want+16)` — `runtime_core_hxlcl_shim_emit.hexa:169` | certain |
| `free` | shim `hxlcl_free` F2 arm `free(base)`/`free(p)` — shim_emit:201-205 | certain (the plan's "3" missed this) |
| `__libc_calloc`/`__libc_free` | HXFARR carve-out — `tool/restore_frozen_seeds:403-406`, glibc arm | certain on linux |
| `calloc` | shim F1 arm already routes `hxlcl_malloc`+`hxlcl_memset` under REALLOC-F2 default-ON (shim_emit:298) | probably **already gone**; the scout may have read a stale archive |

- **PREREQ-1**: fresh pool census — `bash tool/release_build` on aiden, then `nm -u -A build/runtime.a` per member. This resolves 3-vs-5 AND the ARCHITECTURE.json:428 self-contradiction (#4679 DRAFT-label stale vs MERGED · `__libc_*` "landed" vs :4110/:4128 "WALL").
- **PREREQ-2**: check whether `munmap` is already an UND (mmap certainly is — safetensors RFC025 + frozen arena). If new, it lands as a **sanctioned syscall-leaf** (same class as mmap / raw-svc getpid #4358) — say so explicitly in the flip PR with the TOTAL count, because the advisory dump excludes `__libc_` from the reducible line and a silent +1 reads as a miss.

**Standing walls — in scope NOT to touch**: `HEXA_RT_ALLOC_NATIVE` hexa-value arena (`self/rt/alloc.hexa`) is a different allocator, explicitly not FLIP-6; frame-arena letregion/promotion and #4703/#4706 churn rungs are terminal; the 22.7 GB decode retention is device-residency, not this heap; the frozen amalgam bump family (`runtime_emit_full.hexa:1181-1225`) stays noop-free — "true-free heap" for the compiler arena was FALSIFIED once (WALL-2).

## 1. Allocator architecture

**Strategy**: segregated size-class free-lists + large-object mmap. Reference-match:
- **Small path** = tcmalloc's size-class central-freelist design (Ghemawat/Menage), stripped of per-thread caches: fixed class table, freed blocks pushed LIFO per class, O(1) malloc/free. musl *oldmalloc*'s coalescing bins were considered and rejected — coalescing needs boundary tags (a new header ABI, breaking F2 compat) and ~3× the code, while the RSS witness is large-buffer, not small-fragmentation.
- **Large path** = dlmalloc's `mmap_threshold` behavior (each large chunk its own mapping; `free` == `munmap`; RSS returns to the OS immediately). dlmalloc defaults to 256 KB; we set **`total > 4096`** so every ~786 KB farr buffer (the leak witness regime) is on the exact-reclaim path.
- **Header** = the in-house F1v2/F2 ABI, **unchanged**: `base[0..8)=n`, `base[8..16)=HXLCL_ALLOC_MAGIC` (`0xA110CA7EDA7A600DULL`, shim_emit:154), user ptr `base+16`. On the free list, `base[0..8)` is reused as the next pointer and the tag is zeroed — so double-free magic-misses to a no-op for free.

**Semantics parity with libc**: `malloc(0)`→1-byte (existing arm); **calloc overflow guard** `if (sz && nm > SIZE_MAX/sz) return NULL` (musl check — the current F1 arm lacks it, libc had it: add it); realloc **needs zero changes** — the F2 arm (shim_emit:254-267) is already fully family-internal (`hxlcl_malloc/memcpy/free`) and inherits reclaim automatically, `realloc(p,0)=NULL` and foreign-trap stay; **16 B alignment** holds by construction (page-aligned arenas, all class sizes %16==0, 16 B header); **thread safety** — user binaries have real threads and previously inherited libc malloc's locking, so the native core takes a single global spinlock via `__atomic_test_and_set` (inlined, no pthread/libc UND); per-thread magazines are a named-but-deferred perf rung.

**Core** (~140 emitted-C lines, structurally portable to `.hexa` later — no varargs/errno/setjmp, only mmap/munmap, so the axis-③-era port to a `self/rt/heap.hexa` mirroring `self/rt/alloc.hexa`'s sys_mmap pattern is mechanical):

```c
#ifdef HEXA_RT_HEAP_NATIVE
#define HXHEAP_ARENA_SZ  (4u*1024u*1024u)   /* mirrors HXLCL_ALLOC_CHUNK_SZ */
#define HXHEAP_SMALL_MAX 4096                /* total incl 16B header */
static const unsigned short hxheap_class_sz[27] = {
  32,48,64,80,96,112,128,160,192,224,256,320,384,448,512,
  640,768,896,1024,1280,1536,1792,2048,2560,3072,3584,4096 }; /* frag ≤25% */
static void *hxheap_freelist[27];
static char *hxheap_arena_ptr, *hxheap_arena_end;
static volatile int hxheap_lock;
```

- `hxheap_alloc(n)`: `total=align16(n+16)`; ≤4096 → pop class list, else bump-carve from the arena (fresh 4 MB mmap when exhausted — mirrors runtime_emit_full.hexa:1208-1218); >4096 → `mmap(NULL, n+16, …MAP_ANON…)`. Write `base[0]=n; base[1]=MAGIC`. Free recomputes the class from `n` — no extra header fields.
- `hxheap_free(p)`: `total>4096` → `munmap(base, n+16)` (kernel rounds the length — no page-size query, darwin 16 KB pages need no special case); else zero tag + LIFO push.
- `hxheap_calloc(nm,sz)`: overflow guard; **large path skips memset** (MAP_ANON is zero-filled — exactly the `__libc_calloc` fresh-page win the decode workload relies on); small path `hxlcl_memset`.
- **Exports**: `hxlcl_malloc/free/calloc` re-route to the backend, plus two **new globals** `hxlcl_heap_calloc(size_t,size_t)` / `hxlcl_heap_free(void*)` — required because inside the frozen amalgam TU the names `hxlcl_calloc/free` are shadowed by its own `static` bump family, so the HXFARR carve-out must reach the shim's allocator cross-member under distinct names (same wrinkle as the strdup seed's exported `_hxlcl_malloc`, runtime_emit_full.hexa:354-361). Grep-verified collision-free in-tree. All new symbols exist only under the `-D` → OFF shim.o byte-identical.

**HXFARR interaction**: `tool/restore_frozen_seeds:392-419` gains a first arm injected above the `__GLIBC__` arm:

```c
#ifdef HEXA_RT_HEAP_NATIVE
extern void *hxlcl_heap_calloc(size_t, size_t);
extern void  hxlcl_heap_free(void *);
#define HXFARR_CALLOC(nm,sz) hxlcl_heap_calloc((nm),(sz))
#define HXFARR_FREE(p)       hxlcl_heap_free((p))
#elif defined(__GLIBC__)
/* existing arms unchanged */
```

This is what actually drops `__libc_calloc/__libc_free` — and it **fixes darwin's farr leak as a side effect**: today darwin's `#else` arm expands (via the file-wide rename) to the static noop-free bump family, so long-running darwin decode leaks by design. Same 5-line parity arm goes in the emitter default block `self/runtime_emit.hexa:2816-2820` so a future regen can't silently revert the carve-out.

## 2. Bifurcation — the exact coexistence rule

The #4614 LAW stands: *an allocator header-ABI flag must reach every TU that produces or consumes family pointers; byteeq/install-link are structurally blind; only a faithful RUN witnesses a split.* FLIP-6 restates it as **producer-tags, consumer-dispatches**:

1. **One dispatch point**: every deallocation routes through shim `hxlcl_free`/`hxlcl_heap_free`, branching on `base[8..16)`: MAGIC → native reclaim; anything else → **no-op** (NOT libc free, NOT trap). Rationale: under ON, the only legitimate magic-miss producers are frozen-arena pointers (pad=0 — never legally libc-freeable today, so no-op is strictly safer than today's `free(p)` arm) and hypothetical sanctioned-API heap. Debug arm `-DHXHEAP_TRAP_FOREIGN` traps for the smoke suite. `hxlcl_realloc`'s magic-miss stays `__builtin_trap()` (F2 contract).
2. **Native ptr never libc-freed**: on the ON path libc `free` has *no remaining call sites* — S3's sysheaders rename (`runtime_core_sysheaders.h:150-159`, F2 default-ON, platform-neutral) covers runtime_core.c; the amalgam's file-wide defines cover its own; HXFARR routes to `hxlcl_heap_*`; the shim's own `free(`/`malloc(` literals sit inside non-HEAP arms. Gate [B] proves it by `nm -u` per member.
3. **Libc ptr never native-freed**, inverted: no libc producer exists ON-path; anything that leaks in (FFI/sanctioned) magic-misses → bounded leak, never corruption. Deliberate polarity: *fail toward leak, never toward cross-family free.*
4. **One `-D` variable, FIVE compile sites** (`_heap_def`) or rule 2 breaks exactly as #4614 did: S2 `runtime.o` :3076 (the awk-patched frozen amalgam carries HXFARR), S3 :3081, S4 :3094, **CUDA-caseB `runtime_cuda_host.o` :3144** (it compiles `self/runtime.c` separately — #4679 didn't need this because CUDA reuses runtime_core.o, but HXFARR lives in runtime.c), and single-TU fallbacks :3164/:3172.
5. **Lever interlocks** (mirroring the existing `:2016` pattern): `HEXA_RT_HEAP_NATIVE != 0` **forces `_rnre_mode` ON** (heap-native without the F2 header/rename re-creates the #4614 bifurcation), **forces `_rnfr_mode=0`** (a no-op free seed would un-reclaim) and **forces `_rnca_mode=0`** (one symbol one provider — #4591 co-drop lesson). The strdup seed stays adoptable (its `bl _hxlcl_malloc` resolves to the header-writing native malloc, family-consistent).
6. **darwin rule**: nothing glibc-gated may carry FLIP-6 semantics — all new arms are platform-neutral. The glibc `mallopt/malloc_trim` constructor becomes inert but is sanctioned CRT; dropping it is optional post-flip cosmetics, not FLIP-6.

## 3. Leak gate — the 30 GB no-recurrence witness

All flag-ON, pool (aiden linux + ghost darwin; mini = git/gh only), isolated not back-to-back:

- **[L1] original witness re-run**: the harness in `incoming/patches/farr-noop-free-decode-leak.md` — 20k iters × ~1.5 MB farr alloc+drop. Record: noop-free **29.7–30.3 GB linear** vs `__libc_free` **5.2 MB FLAT** (restore_frozen_seeds:381-382). PASS: native-ON MaxRSS ≤ 64 MB **and** slope ≈ 0 — sample `VmRSS` every 500 iters, linear fit < 1 MB/1000 iters (`/usr/bin/time -v` for coarse MaxRSS, the sampled series as the recurrence proof; darwin: `/usr/bin/time -l` + `ps -o rss=` sampling, absolute bar since darwin had no reclaiming baseline).
- **[L2] round-trip + threaded smoke** (extends F2's gate [C] / `tool/routec_alloc_native_verify.sh`): malloc→realloc grow/shrink content+header; strdup→free; calloc zeroed + **overflow-guard returns NULL**; 10k × (1 MB calloc → free) RSS flat (munmap really returns); double-free no-ops (tag==0); foreign free traps under `-DHXHEAP_TRAP_FOREIGN`, no-ops without; the .hexa 10k map set/delete + array-growth kill-path exits 0; N threads × 1M malloc/free churn exits 0 with post-join freelist walk consistent.
- **[L3] real workload**: bytegpt decode worker (GEN=110 class; record 25.8 GB RSS vs ~5 GB weights) on aiden, ON vs OFF isolated: RSS ceiling ≤ weights + 1 GB, flat ≥ 30 min. Capture the series into `state/`.
- **Perf non-regression** (flip precondition): `bench/check_regress.sh --threshold 1.20` alloc_heavy/dict_100k/oop_heavy + stage-1 self-compile wall median-of-3 ≤ 2 %. If alloc_heavy regresses, measured levers in order: clz class-lookup, then per-thread magazines — neither in round-3a.

## 4. Staging

- **PR-A mechanism** (round-3a, §5): default-OFF, byte-neutral. Gate [A]: flag unset → all arms preprocess away, `_heap_def=""` → `sha256(runtime.a)` + per-member shas identical (capture in PR body); byteeq trivially GREEN (byteeq/faithful workflows set no `HEXA_RT_*` env). ⚠️ One real neutrality hazard: the awk inserts lines into the frozen runtime.c → **if CFLAGS carries `-g`, DWARF line shifts bit-change runtime.o even with the flag OFF**. Check CFLAGS first; the sha capture decides — if RED, restructure the injection to be byte-position-stable (append-at-end) or run the PR as DRAFT-byteeq. Don't assume.
- **Flag-ON measurement** (no merge): `HEXA_RT_HEAP_NATIVE=1 bash tool/release_build` on aiden+ghost → gate [B] `nm -u` per member: zero `malloc|free|calloc|__libc_calloc|__libc_free` anywhere; S5 `ld -r` multidef == 0 (validates the new `hxlcl_heap_*` exports); TOTAL UND −4/−5 (+munmap disclosure per PREREQ-2). Then §3 gates.
- **PR-B flip**: one line `:-0`→`:-auto` (strtod-tail #4651 / F2 #4621 template, measurement citation in the comment). Gates: byteeq 3-target **reconverge**, faithful nobaseline darwin+linux RUN (the only structural witness — proven twice), install.sh consumer smoke 3/3, [L1]+[L3] captures linked. Post-merge: ARCHITECTURE.json:4110 sanctioned list minus `__libc_calloc/__libc_free`, :428 reconcile, CHANGELOG.jsonl same-change. Rollback = 1-line revert; PR-A is inert OFF.

## 5. Round-3a first PR — exact edits (PR-A)

Mirrors #4679's coupling (`_rng_strcmp_def`: empty local → set in the adopting branch → appended to compile lines), except the variable feeds five sites. **Correction to the prompt**: the allocator body belongs in `self/runtime_core_hxlcl_shim_emit.hexa` (the shim TU is the family provider; the C-emitter per-target compile dodges the Route-C fp-ABI wall) — `runtime_emit.hexa` only gets the 5-line HXFARR parity arm.

1. `self/runtime_core_hxlcl_shim_emit.hexa` — after the MAGIC block (**:152-155**): the §1 core under `#ifdef HEXA_RT_HEAP_NATIVE` (+ `<sys/mman.h>` under the same guard); `hxlcl_malloc` **:156-178** → 3-arm (`HEAP_NATIVE` native / existing F2 verbatim / delegate verbatim); `hxlcl_free` **:190-211** → insert HEAP_NATIVE arm above F2 arm; `hxlcl_calloc` **:282-302** → insert native arm (overflow guard + large zero-skip); `hxlcl_realloc` **:230-268** untouched; BYTEID arms untouched. Regenerate the derived `.c` in the same PR; keep the `buf.len() > 65536` flush cadence around the new block.
2. `tool/restore_frozen_seeds:392-419` — the HXFARR first arm (§1); keep the `HXFARR_CALLOC` idempotence marker semantics.
3. `self/runtime_emit.hexa:2816-2820` — emitter-parity arm in the `#ifndef HXFARR_CALLOC` default block.
4. `tool/stage_resolve_runtime_a` (origin/main anchors) — `local _heap_def=""` beside **:1503/:1514**; early tri-state `_heap_mode="${HEXA_RT_HEAP_NATIVE:-0}"` **before :2010** (it must precede the seed-mode reads it forces); interlocks: `_rnfr_mode=0` beside **:2016**, `_rnca_mode=0` beside **:2201**, `_rnre_mode` force-ON + `_heap_def="-DHEXA_RT_HEAP_NATIVE"` + a log echo in the **:2598-2602** F2 block; append `$_heap_def` at **:3076, :3081, :3094, :3144, :3164, :3172**.
5. `CHANGELOG.jsonl` same-change (L0 gate); PR body carries the OFF-sha capture.

PR-A claims nothing except "OFF = byte-identical, mechanism reviewable" — no default flip, no seeds, no UND-drop claim.

## 6. Open items for the implementer

1. PREREQ-1 census (3 vs 4 vs 5, per-member) → rewrite the §0 table with evidence.
2. PREREQ-2 munmap UND status → flip-PR wording.
3. `-g` in runtime.a CFLAGS → decides the awk-injection neutrality tactic.
4. Sanctioned-API heap-returning census on the emitted runtime_core.c/runtime.c (`getline|asprintf|realpath|get_current_dir_name`) — decides whether the `free` UND fully drops; if one appears, report it, don't hide it.
5. Whether byteeq's DWARF surface sees the shim.c regen (same `-g` question).

One incidental finding: I attempted to save this to `state/hexa-own/flip6_native_heap_design_fable.md` but writes are denied in this session — the content above is complete and paste-ready. Also note the ing-log references a `scratchpad/flip6_spec.md` from an earlier session; it does not exist in this checkout — this document supersedes it.