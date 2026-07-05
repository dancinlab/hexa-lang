All facts verified from source. Here is the design.

---

# TL;DR

Your option list (A/B/C) is built on a premise the tree falsifies: **the compiler-synthesis problem for the runtime.a floor was already solved** — `stage_resolve_runtime_a:1214-1217` compiles the runtime members with `-fno-builtin-memcpy -fno-builtin-memset -fno-builtin-memmove -fno-builtin-memcmp` (+ gcc-only `-fno-tree-loop-distribute-patterns`) **unconditionally, today, with a captured measurement** ("MEASURED (summer): clang-18 drops them with -fno-builtin-* alone; gcc also needs -fno-tree-…"). And the fast native bodies already exist: the frozen runtime.c SSOT carries **#4366 overlapping-load-dispatch `static hxlcl_memcpy/memset/memcmp/memmove`** (`self/runtime_emit_full.hexa:395/651/698/725`) plus a **textual override block** `#define memcpy(d,s,n) hxlcl_memcpy(...)` etc. (`runtime_emit_full.hexa:2835-2853`). So neither (A), (B), nor (C) is the right move. The correct minimal flip is a third mechanism — swap the **shim's libc-delegate arms** to the #4366 bodies + mirror the override block into the **standalone runtime_core TU** — and it drops **all three** symbols, byteeq-clean, with no new `-fno-builtin` and no perf concern.

# 0. Corrections to your established facts

1. **`self/codegen.hexa:98-116` is NOT a drop mechanism.** The fn is `_hexa_name_is_reserved` (`codegen.hexa:11`), called at `codegen.hexa:246`: `if _hexa_name_is_reserved(name) { return "u_" + name }`. Returning true means *"a user-level hexa identifier with this name gets mangled to `u_<name>`"* — pure collision avoidance against libc/keyword names in emitted C. It neither emits externs, routes to native bodies, nor suppresses anything. Irrelevant to the floor.
2. **Registry `:auto` vs `:0` (line 1533):** the value is the *default* for `HEXA_RT_NATIVE_<SYM>` (the **seed** gate family, not `HEXA_RT_SELFEMIT_<SYM>`). A symbol is "claimed" only if gate≠0 **AND** `self/native/hxlcl_<sym>_<suf>.s` exists (line 1538). For memcpy/memset/memcmp there is no seed, so `:auto` would be a literal no-op. The registry is **dedup-only** (tells the SELFEMIT/MEMLEAF loops to skip seed-claimed symbols, lines 1554/1644); it drops nothing by itself.
3. **The MEMLEAF/SELFEMIT paths are on the ship path structurally but OFF by gate.** `release_build:77` exports `HEXA_RT_MULTIOBJ=1` default — the multi-object branch IS the default ship path. But MEMLEAF per-symbol gates default `0` (line 1641), and their fixtures are **naive byte loops**, and a live emit at Stage-0b needs a hexa binary — the exact faithful-RED failure class that forced strcmp to switch to baked seeds (block comment at 1852-1858).
4. **How the default path stands today (verified per-TU):**
   - `runtime.o` (S2, from runtime.c): carries the *static* #4366 fast bodies + the override block → **no UND mem\*** of its own. The hot large-n sites (`farr_zeros` memset at `runtime_emit_full.hexa:9571`, array clones) already run the measured dispatch bodies today.
   - `runtime_core.o` (S3, standalone TU): `runtime_core_sysheaders.h` declares `hxlcl_mem*` prototypes (:61-63) but has **no override block** → runtime_core.c's **6 bare `memcpy(` call sites** (emitter lines 5007, 5833, 6598, 6637, 9588, 9646 — all small fixed-size: 16B HexaVal COW, grapheme clusters, 4B f32) stay `U memcpy`. Zero bare `memset(`/`memcmp(` sites in this TU.
   - `hxlcl_shim.o` (S4): the `#ifndef HEXA_RT_SELFEMIT_<SYM>` fallback arms are **libc delegates** (`return memcpy(d,s,n)` — shim emitter lines 271/289/310) → `U memcpy`, `U memset`, `U memcmp`.
   - That's the complete UND inventory for these 3 (extra_obj members are hand-asm 0-libc seeds; strdup's bare memcpy at shim emitter:473 is already dropped via the `:auto` strdup seed; calloc's memset arm at :249 is REALLOC-gated, dead since the #4600 revert).

# 1. TRUTH on compiler synthesis vs #define

**Yes, memcpy and memset can leave the runtime.a floor byteeq-clean now, without any new `-fno-builtin`** — because for the archive members it's already on and measured (1214-1217). Your crux ("`#define` can't catch compiler-synthesized `call memcpy`") is correct in general, but it's already neutralized in `runtime.o`/`runtime_core.o`, and the dump surface (`nm -u runtime.a`, nobaseline-gate.yml:333) contains only archive members.

The one place your fear is **live**: `shim.o` compiles **without** `$_zeroc_nobuiltin` (line 3132). Put a native C loop body into the shim and clang's loop-idiom pass turns it back into `call memcpy` — self-recursion; this exact trap is documented from measurement in the shim emitter itself (lines 62-63: "clang lowers their inner copy loop to a `call memcpy` in the full 57-fn TU"). So the flip MUST add the nobuiltin flags to the S4 compile in the same PR.

What genuinely **cannot** drop this round: memcpy/memset in **emitted user C / the final binary** (clang synthesizes them into user objects; no macro catches that). But that floor is not what the faithful-nobaseline dump measures, so the flip is honest for the runtime.a floor.

# 2. The safe subset + mechanism (option D, not A/B/C)

**All three — memcmp + memset + memcpy — in one PR.** Three edits:

- **Edit 1 — `self/runtime_core_hxlcl_shim_emit.hexa` :271, :289, :310** (edit the emitter, never the gitignored .c — `regen_shim_from_emitter` at stage:122 rematerializes it): replace the three libc-delegate fallback arms with the **verbatim #4366 dispatch bodies** copied from `runtime_emit_full.hexa` (memcmp ~:395ff, memcpy ~:651ff, memset ~:698ff), external linkage, keep `__attribute__((noinline))`, keep the outer `#ifndef HEXA_RT_SELFEMIT_<SYM>` gates untouched. Optional but recommended insurance (realloc-revert lesson): wrap delegate-vs-native in `#ifdef HEXA_RT_MEM_LIBC` with **native as the unflagged default** — polarity-correct (flag-on = enable the external dep) and gives an instant opt-out without a git revert.
- **Edit 2 — `tool/stage_resolve_runtime_a:3132`**: add `$_zeroc_nobuiltin` to the S4 shim compile (it's in scope; defined at 1214). **Mandatory with Edit 1** — anti-self-recursion.
- **Edit 3 — `self/runtime_core_sysheaders.h`** (tracked, non-frozen), after the prototype block ending at :63 (i.e., after all its `#include`s — same placement discipline as runtime.c's own block): add the three function-like overrides verbatim from the runtime.c pattern:
  ```c
  #define memcpy(d,s,n)  hxlcl_memcpy((void *)(d), (const void *)(s), (size_t)(n))
  #define memset(p,c,n)  hxlcl_memset((void *)(p), (int)(c), (size_t)(n))
  #define memcmp(a,b,n)  hxlcl_memcmp((const void *)(a), (const void *)(b), (size_t)(n))
  ```
  Function-like macros don't touch the already-parsed `<string.h>` prototypes or `hxlcl_memcpy(` tokens; runtime_core.c is an include-fragment with no further libc includes. Also fix the stale header comment ("the DEFAULT build never sees it" — false since the MULTIOBJ default flip; S3 force-includes it on the ship path).

Why not the others: **(A)** codegen_full prologue is the wrong surface — it changes emitted *user* C, which is not in runtime.a; it cannot touch runtime_core.o or shim.o. **(B)** registry flip is a no-op without seeds, and MEMLEAF fixtures are naive byte loops + Linux-only + need a Stage-0b emit binary (the measured faithful-RED class). **(C)** memcmp-only rests on the falsified premise; memcmp is not safer than the other two here.

Perf: strictly neutral-or-better by existing captured numbers. Hot large-n paths already bind to the static dispatch bodies in runtime.o (unchanged). The flip only (a) retargets runtime_core.o's six small-fixed-size sites and shim consumers from a libc PLT call to the dispatch body measured **1.3-2.0× faster in exactly the small-copy regime, parity at large**, and (b) deletes delegate hops.

# 3. Co-drop / registry lockstep

**No registry change at 1533** — and that's by design, not omission: `memcpy:0 memcmp:0 memset:0` key the `HEXA_RT_NATIVE_*` *seed* family, no seeds exist, no consuming-block default changes, so there is no default pair to mirror (the convergence-4591 class is about gate-default mismatches; this PR changes zero gate defaults). No new archive member is added on the default path (same member set, different shim bytes) → no new S5 multidef surface; the `ld -r` gate (:3141-3152, loud FATAL) still validates. The darwin SELFEMIT smoke is untouched: its `-DHEXA_RT_SELFEMIT_<SYM>` still drops whichever body the shim arm carries → still exactly one `hxlcl_<sym>` provider; the 21-member assert is unaffected. **Do** add a lockstep comment at the shim arms: if `hxlcl_mem*` seeds ever land as RT-NATIVE `:auto`, that PR must bump the 1533 entries — the existing rule, unchanged.

# 4. What WAITS for the pool-perf round

- The **final-binary / emitted-user-C floor**: interposing the literal `memcpy`/`memset` symbols at final link + `-fno-builtin` on emitted-C compiles. That's the CLAUDE.md "measured-viable next round" — byte-changing for user binaries and perf-gated. Nothing in this PR touches it.
- Upgrading the MEMLEAF/SELFEMIT naive-byte-loop fixtures to the dispatch bodies (opt-in path only; cosmetic for the floor).
- **strlen/strcpy/strncpy/strcat**: same recipe applies *structurally*, but each swaps a glibc SIMD implementation for a C body on genuinely hot paths (strlen especially). Each needs its own measured dispatch body first. Not this round.

# 5. Neutrality + convergence

Be honest in the PR: this is a **bytes-changing default flip of runtime.a** — there is no "OFF path stays byte-identical" claim to make (unless you take the `HEXA_RT_MEM_LIBC` opt-out arm, which restores today's delegates exactly). Gen3≡gen4 byteeq is structurally unaffected (`build_selfhost.sh` builds its own rt.o flag-free and never consumes runtime.a — stage:1456), but per the #4599 lesson byteeq+install-link prove nothing about runtime behavior, so gate on: byteeq 3-target GREEN + S5 multidef=0 + SELFEMIT smoke GREEN + a **full faithful/self-host build execution** on the pool (it exercises the swapped bodies) + exit42/hello consumer smoke + the advisory dump showing `memcpy memset memcmp` gone, and one isolated small/large mem micro on summer to re-capture the dispatch-body numbers in-archive. Attribute any residue with `nm -u -A build/runtime.a` per member.

Two convergence entries are warranted: **(i)** "shim.o must compile with `_zeroc_nobuiltin` whenever any shim arm carries a native mem body — else the body self-recurses into `call memcpy`"; **(ii)** "the standalone runtime_core TU (sysheaders) must mirror runtime.c's textual override block — divergence silently re-opens the nm-UND floor" (that divergence is precisely why memcpy survived every round so far).
