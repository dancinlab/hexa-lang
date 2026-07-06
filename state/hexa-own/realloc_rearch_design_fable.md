Root-caused from source, and the finding overturns the framing: **the abort was never in realloc's body — the `-D` flag itself bifurcated the heap into two pointer ABIs, and darwin is the only target where the caller family isn't closed by macros.** The seed apparatus was fighting the wrong defect both times. (Repo write is denied in this session, so the full design is below; I saved the root cause to memory.)

---

## 1. ROOT CAUSE of the darwin-arm64 SIGABRT

**Build shape**: `release_build` exports `HEXA_RT_MULTIOBJ=1` (tool/release_build:77), so the failing faithful binary links the multi-object runtime.a: `runtime.o` (frozen amalgam minus core — its hxlcl_* are `static`, a self-contained mmap bump-arena family) + `runtime_core.o` (S3, `stage_resolve_runtime_a:3136`, compiled with `-include self/runtime_core_sysheaders.h`) + `hxlcl_shim.o` (S4, :3149, receives `$_mo_shim_def`) + seed members.

**The kill chain under the flip**:

1. `-DHEXA_RT_NATIVE_REALLOC` goes **only to the S4 shim TU**. It flips `hxlcl_malloc` to the header ABI: `malloc(n+16)`, size at base, **return base+16** (shim_emit:144-150). The F1 arms for calloc/strdup, and the adopted calloc/strdup seeds (whose `bl _hxlcl_malloc` is an undefined extern resolved by the shim), all route through it — every hxlcl-family pointer becomes base+16.
2. `hxlcl_free` is the **no-op seed** (`HEXA_RT_NATIVE_FREE` defaults `auto` at :1993 and `self/native/hxlcl_free_arm64.s` exists) — so hxlcl_free never aborts. It's innocent.
3. `runtime_core.c` interns map keys via **`hxlcl_strdup`** (runtime_core_emit.hexa:3861, :3884, :3964, :5593) → base+16 family pointers.
4. It frees those keys via **bare libc `free()`**: `rt_map_delete` → `free(t->slots[si].key)` (runtime_core_emit.hexa:**4671**) and map destroy (:6019–:6033). In the standalone S3 TU these are raw libc **on darwin only**, because:
   - `runtime_core_sysheaders.h:116-134` renames **only memcpy/memset/memcmp** (the #4604 mem-leaf block) — no malloc-family rename;
   - the in-file re-arm `#define free(p) hxlcl_free(...)` (runtime_core_emit.hexa:395-406) sits inside **`#if defined(__linux__) && defined(__GLIBC__)`** — dead on darwin;
   - the amalgam rename (runtime_emit_full.hexa:2882) exists only on the single-TU path.
5. libc `free(base+16)` on a mid-chunk pointer → darwin libmalloc "pointer being freed was not allocated" → `abort()` → **Abort trap: 6** at the first module-map delete in map-heavy `hexa_module_loader`.

**Why fixing the seed changed nothing (#4614)**: on darwin, `runtime_core.c` has **zero explicit `hxlcl_realloc` call sites** — every realloc site is bare (libc on darwin). The seed was nearly inert; the crash came entirely from the `-D`'s side effect on `hxlcl_malloc`. That's also why byteeq (build_selfhost builds its own rt.o) and install-link (link-clean) are structurally blind — only a faithful RUN witnesses a heap-family split.

**Answers to your three recon questions**: (1) header = `base[0..8)=size_t n`, `base[8..16)=reserved pad`, user ptr = base+16, identical layout/alignment on all 3 targets (frozen arena at runtime_emit_full:1187-1208 uses the same convention). (2) The native realloc body (hxlcl_core.hexa:1255) is correct *for family pointers*; it never corrupts by itself (writes bounded by n). (3) darwin's hxlcl_malloc is **not** a different allocator — the difference is macro coverage on the caller side, not ISA or allocator path. Linux stays green because glibc's `<malloc.h>` re-arm block closes the family there.

## 2. The F2 design — self-contained shim body + family-closing rename + magic guard

**Header F1v2** — use the reserved 8 bytes as a family tag (HexaStrHdr `HEXA_STR_MAGIC` precedent, runtime_core_emit:845): `base[0..8)=size` (frozen position, BYTEID-compatible), `base[8..16)=HXLCL_ALLOC_MAGIC` (e.g. `0xA110CA7EDA7A600DULL`; frozen arena leaves that pad 0). The magic makes free/realloc **strictly today-equivalent for every non-family pointer** (e.g. the `from_arena` map keys at :3843): magic-miss → the exact libc call today's code makes. Every today-green flow stays green by construction.

**Shim edits** (all inside the existing `#ifdef HEXA_RT_NATIVE_REALLOC` arms → OFF path byte-identical; add forward decls for `hxlcl_memcpy/memset/strlen` under the same ifdef since they're defined later in the file):

```c
/* malloc: add the tag */
void *__attribute__((noinline)) hxlcl_malloc(size_t n) {
    size_t want = n ? n : 1;
    unsigned char *base = (unsigned char *)malloc(want + HXLCL_HDR_BYTES);
    if (!base) return (void *)0;
    ((size_t *)base)[0] = want;               /* size @ [0..8) — frozen-floor position */
    ((size_t *)base)[1] = HXLCL_ALLOC_MAGIC;  /* family tag @ [8..16) (frozen pad slot) */
    return base + HXLCL_HDR_BYTES;
}
/* free: magic-guarded — REPLACES the blind free(p-16) F1 arm, which would abort on
 * foreign pointers (arena kdup keys, any pre-flip source) */
void hxlcl_free(void *p) {
    if (!p) return;
    unsigned char *base = (unsigned char *)p - HXLCL_HDR_BYTES;
    if (((size_t *)base)[1] == HXLCL_ALLOC_MAGIC) { ((size_t *)base)[1] = 0; free(base); }
    else free(p);                              /* foreign: exactly today's behavior */
}
/* realloc: 3-arm restructure (mem-leaf #4604 shape) */
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* verbatim BYTEID measurement arm — UNCHANGED */
#elif !defined(HEXA_RT_NATIVE_REALLOC)
void  *hxlcl_realloc(void *p, size_t n)               { return realloc(p, n); }
#else
void *__attribute__((noinline)) hxlcl_realloc(void *p, size_t n) {
    if (!p) return hxlcl_malloc(n);
    if (n == 0) return (void *)0;              /* frozen-floor contract (no free) */
    unsigned char *base = (unsigned char *)p - HXLCL_HDR_BYTES;
    if (((size_t *)base)[1] != HXLCL_ALLOC_MAGIC) {
        fprintf(stderr, "hxlcl_realloc: foreign pointer (no family header)\n");
        __builtin_trap();   /* fail LOUD; a libc-realloc fallback would keep realloc on the nm-UND floor */
    }
    size_t old_n = ((size_t *)base)[0];
    void *np = hxlcl_malloc(n);
    if (!np) return (void *)0;
    size_t copy_n = (n < old_n) ? n : old_n;
    hxlcl_memcpy(np, p, copy_n);
    hxlcl_free(p);          /* real reclaim (musl-faithful move); degrades to floor leak if free is no-op */
    return np;
}
#endif
```

Same-PR hygiene: the F1 fallback calloc arm's bare `memset` → `hxlcl_memset`, F1 strdup arm's bare `strlen/memcpy` → `hxlcl_strlen/hxlcl_memcpy` (otherwise those fallbacks silently re-introduce the UNDs #4604/#4605 removed).

**The load-bearing fix — `runtime_core_sysheaders.h`** (standalone-TU-only prelude, amalgam never sees it), after the hxlcl prototype block:

```c
#ifdef HEXA_RT_NATIVE_REALLOC
#undef malloc
#undef free
#undef realloc
#undef calloc
#define malloc(n)     hxlcl_malloc((size_t)(n))
#define free(p)       hxlcl_free((void *)(p))
#define realloc(p,n)  hxlcl_realloc((void *)(p), (size_t)(n))
#define calloc(nm,sz) hxlcl_calloc((size_t)(nm), (size_t)(sz))
#endif
```

Placed after `<stdlib.h>` so prototypes parse un-expanded (same discipline as the mem* block); the linux glibc re-arm block `#undef`s and re-defines identically around `<malloc.h>` — no conflict. Producer census in runtime_core.c is clean: no getline/asprintf/getcwd/bare-strdup; all freed/realloc'd pointers are bare malloc/realloc (renamed as one family), hxlcl_strdup (family), or arena kdup (foreign → magic-miss → today's libc free). HexaStrHdr strings are free-never and `HX_STRLEN`'s magic check is unaffected.

**stage_resolve_runtime_a**: delete the seed-consume block (:2562-2658); the flip becomes a pure `-D` on **both** TUs — add `local _mo_rtcore_def=""` beside `_mo_shim_def` (:1498), set both when `HEXA_RT_NATIVE_REALLOC != 0`, append `$_mo_rtcore_def` to the S3 compile (:3136; the CUDA archive at :3183 reuses the same runtime_core.o, so it's covered). Add a **block-level FREE-seed exclusion** in the :1993 block: when realloc-F2 is active, skip the free-seed adoption so the shim's magic-guarded *reclaiming* free serves (a no-op free would regress user-binary reclaim to zero) — this is the #4591 lesson stated at the block, not in the SELFEMIT co-drop registry (free/realloc are absent from the SELFEMIT lists). calloc/strdup seeds stay adoptable — their `bl hxlcl_malloc` extern resolves to the header-writing malloc, family-consistent either way. `auto` and `1` become equivalent (no seed to be missing).

**Your explicit questions**: `-fno-builtin-realloc` is NOT needed — no LLVM pass synthesizes a realloc call (loop-idiom recognizes memcpy/memset only), and the body's copy goes through `hxlcl_memcpy` under the already-present `-fno-builtin-memcpy`. The sysheaders `#define realloc` override **is required** — bare `realloc(` sites exist (read_lines fline grow, bucket/array growth) and bare `free(` sites are the actual killers. This is *not* shim-only like str-leaf, because the allocator changes pointer ownership/ABI: caller sites are part of the allocator surface.

## 3. Seed path disposition

Fully replaced: delete the stage block, retire `tool/regen_hxlcl_realloc_native_s.sh` (header note), keep `hxlcl_core.hexa::hxlcl_realloc` as a Route C measurement artifact (routec smoke) marked "retired from the ship path". No seeds to delete on main (the revert already removed them).

## 4. Gates

PR-A (mechanism, default-OFF byte-neutral) → PR-B (flip `:-0 → :-auto`) gated on captured output:
- **[A] OFF neutrality**: shim.o + runtime_core.o + archive sha256 identical vs baseline; byteeq 3-target CI.
- **[B] ON nm assertions** (extend `tool/routec_alloc_native_verify.sh`): `nm -u hxlcl_shim.o` has no `realloc`; `nm -u runtime_core.o` has no bare `malloc|free|realloc|calloc` (rename proof); S5 `ld -r` multidef == 0.
- **[C] round-trip smoke** (tiny C main + ON archive, darwin+linux): malloc(24)→realloc(4096) content+header, shrink to 8, strdup→free, calloc zeroed→free, **libc-interop**: `f = malloc(32)` direct libc → `hxlcl_free(f)` must not abort (magic-miss), plus an rt-level miniature of the kill path: a .hexa doing 10k map set/delete + array growth + read_lines built against the ON archive → exit 0.
- **[D] faithful build EXECUTION** on darwin-arm64 (the only witness of this class, proven twice) + linux; 3-target GREEN + install.sh consumer smoke before the default flip.

## 5. Convergence — hxlcl-realloc-arm64-s-1

- **FALSIFIED**: "sliced seed body was the root cause" — seed integrity fixed (#4610, ret=6/bb=25) and the abort persisted (job 85260915220). Slicer bug real but secondary.
- **CONFIRMED**: shim-only `-DHEXA_RT_NATIVE_REALLOC` bifurcates the heap into two pointer ABIs; darwin-only because runtime_core.c's malloc-family rename is `__linux__ && __GLIBC__`-gated. Kill site = bare libc `free(hxlcl_strdup'd map key)` = `free(base+16)` (runtime_core_emit.hexa:4671).
- **LAW**: an allocator header-ABI flag must reach every TU that produces or consumes family pointers — caller call sites are part of the allocator surface. byteeq/install-link are structurally blind to heap-family splits; the witnesses are faithful RUN and the [C] round-trip smoke. Corollary: before flipping any hxlcl allocator lever, grep the standalone TU for bare malloc-family sites per target-conditional macro coverage.

One note: I attempted to write this design to `state/hexa-own/realloc_rearch_design_fable.md` but writes are denied in this session — if you want it as a file, the content above is complete and ready to paste.