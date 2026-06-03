@title: 🧹🇨 RUNTIME-PORT — port the portable runtime.c floor to hexa-native

@goal: Drive the genuinely hand-authored C runtime floor (self/runtime.c, 14919 LOC / ~596 fns) to its TRUE irreducible minimum by porting every function that is NOT a bootstrap primitive to hexa-native — each port gated by RUNEQ / byte-diff against the C original before the C is retired. End state: self/runtime.c contains only the irreducible bootstrap core (raw alloc · GC scan · value-tag bit ops · the primitives hexa itself lowers to); everything above that floor (array/string/regex/fn helpers) is hexa-native. This is ACTUAL PORTING, not the C-ZERO emitter-backed reclassification.

# RUNTIME-PORT — current state

C-ZERO proved the repo's tracked .c is 0 and every shim/artifact is emitter-backed
or .hexanoport-by-design. The one residual it formally marked IRREDUCIBLE was
self/runtime.c (the bootstrap C runtime: GC, value tags, string/alloc) + the
platform FFI shims. RUNTIME-PORT re-opens that "irreducible" label as a FRONTIER,
not a wall: runtime.c has ~596 functions, but only a minority are true bootstrap
primitives. Higher-level helpers (hexa_array_push/new/get, hexa_str*, hexa_len,
hexa_truthy, hexa_re_* regex, hexa_fn_new, hexa_farr_*) are candidates to become
hexa-native, compiled by the self-hosting gen3 and proven equivalent before the C
copy is removed. self/runtime.hexa (34953B) already exists as the hexa-side anchor.

## milestones

- [ ] PORTABILITY INVENTORY — classify all ~596 runtime.c functions into 3 tiers: (A) IRREDUCIBLE bootstrap primitive (raw mmap/alloc, GC core scan, value-tag encode/decode, what hexa lowers to) — must stay C; (B) PORTABLE high-level helper (array/string/regex/fn/farr) — hexa-native candidate; (C) FFI/platform shim (posix/pthread/extern) — irreducible external ABI. Record LOC per tier in RUNTIME-PORT.log.md → defines the true floor target.
- [ ] first PORT — pick the highest-tractability tier-B function (leaf, no GC-internal deps, e.g. hexa_len / hexa_truthy), implement in hexa, compile via gen3, RUNEQ vs the C original (same inputs → same outputs/bits), retire the C body behind the hexa one.
- [ ] tier-B batch ports — array helpers (push/new/get) + string helpers, each RUNEQ-gated, C body removed only on green.
- [ ] regex subsystem (hexa_re_*) — port the regex helpers to hexa-native (self-contained, no GC-core entanglement).
- [ ] floor ledger — running LOC: irreducible-C-floor vs ported-to-hexa, published as the runtime.c burn-down toward the true minimum.

## deferred

- the irreducible bootstrap core (GC scan / raw alloc / value-tag bit ops) — formally mark + freeze as the minimal C floor (a self-hosting language needs SOME C runtime; the goal is to prove the minimum, not reach literal 0).
- platform FFI shims (hxblas/hxqwen32b/hxvdsp_linux) — irreducible external ABI (vendor lib boundary); out of port scope, already classified by C-ZERO.
