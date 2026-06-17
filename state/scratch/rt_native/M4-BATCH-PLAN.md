# RT-NATIVE-ZEROC — M4 Parallel Port Plan (M2/M3 verdict + M4 batches + M5/M6 sketch)

Planning artifact (READ-ONLY task, no code edits). Branch: `rt-native-m1-x86-leaf-parity`
(has the landed M1 x86_64 leaf parity, #3474 + the M1 commit `1b9a9e694`).
Author host: aiden. Date: 2026-06-17.

Sources read: `.verdicts/rt-native-byteeq/{F-M1-X86-LEAF-PARITY, F-LEGB-RTCORE-PURE-CANDIDATES-ZERO,
F-LEGB-UNLOCK2-NANBOX-FEASIBILITY, F-LEG-B-STANDALONE-SCOPE, F-LEG-B-DEADCODE-PATH,
F-LEGB-STANDALONE-ELSE-NOGO}.txt`; `compiler/check/bind.hexa`,
`compiler/codegen/{arm64_darwin,x86_64_linux}.hexa`, `self/runtime_core.c`,
`tool/stage_resolve_runtime_a`, `scripts/scratch/rt_native/arena_port.hexa`.

================================================================================
## CRITICAL FRAMING (read before decomposing)
================================================================================

The 25 `__hx_*` leaf intrinsics live in ONE contiguous STMT_CALL block per backend
(arm64_darwin.hexa ~1890-2200; x86_64_linux.hexa ~1345-1640). They are DONE on both
targets (M1). **The M4 batches DO NOT edit the emitter.** Each batch is a `.hexa`
runtime-source file (a faithful port of a runtime_core.c fn family) that CALLS these
already-landed intrinsics. Therefore:

  * Batch independence is NOT about emitter-region conflicts — the emitter is frozen.
    The only shared emitter surface is the bind whitelist (bind.hexa:1221-1230), and it
    is ALSO done for all 25 names. New intrinsic additions (if any batch needs one) ARE
    the only emitter edits, and those serialize on that single block — see "new-intrinsic
    serialization" below.
  * Batch independence IS about: (a) which `.hexa` source file each batch owns (disjoint
    files = trivially parallel), and (b) the runtime DEPENDENCY graph (alloc before
    consumers, nanbox-ctor before consumers).

The census (F-LEGB-RTCORE-PURE-CANDIDATES-ZERO) proved the "pure portable fn" framing is
EXHAUSTED. M4 is NOT "find pure fns to port" — it is "port the substrate floor
(nanbox/syscall/alloc/raw-mem) using the M1 intrinsics." That is exactly what the 5
census categories are, and that is what these batches cover.

================================================================================
## 1. M2 / M3 COMPLETENESS VERDICT
================================================================================

### M2 (raw-mem: map/array ptr ops) — DONE-BY-M1 for the 64/32-bit word case;
###    one HONEST GAP: NO 8-bit (byte) ptr load/store, NO atomic, NO realloc-intrinsic.

Intrinsic inventory (bind.hexa:1225-1230, mirrored byte-for-byte in BOTH backends):
  ptr ops present: __hx_ptr_load64 / store64 / load32 / store32   (word + dword)
  ptr ops ABSENT : __hx_ptr_load8 / store8 (byte), any atomic, any realloc/memcpy/memset.
  (`grep -c "ptr_load8|ptr_store8|atomic|realloc" bind.hexa` = 0 — MEASURED.)

Is byte-level access needed? The runtime's raw-mem reaches DOWN to bytes in exactly two
places, and both are already covered WITHOUT a ptr8 intrinsic:
  * String byte reads: `__hx_str_byte` exists (byte load from a str base+idx → TAG_INT).
  * Hash table / array element stores are HexaVal-granular (16B) and key C-strings are
    duplicated via `hexa_strbuf_dup_n` (a memcpy). A pure-hexa port models 16B HexaVal
    slots as two 64-bit `__hx_ptr_store64` writes (tag lo, payload hi) — the natural
    granularity. Char-buffer dup (strbuf) needs a byte COPY loop: today expressible as a
    `__hx_str_byte` read + `__hx_ptr_store8`-equivalent... which is MISSING.

  VERDICT M2: word/dword raw-mem = COMPLETE-by-M1. **Follow-up needed (small): add
  `__hx_ptr_store8` / `__hx_ptr_load8`** (1 STMT_CALL case each per backend, identical
  shape to store32/load32 but `byte ptr` / `strb`/`ldrb`; the str_byte intrinsic already
  proves the byte-load encoding on both backends). This unblocks batch-strbuf (char-buffer
  dup/cat). Atomic + realloc are NOT needed (runtime is single-threaded; growth = alloc-new
  + copy-loop, no realloc intrinsic required). So M2 = DONE-BY-M1 **except one 2-case
  follow-up (ptr8)**, scoped to whoever lands batch-strbuf.

### M3 (syscall) — DONE-BY-M1. The generic 6-arg form covers every syscall the runtime uses.

Syscalls runtime_core.c actually issues (MEASURED, `grep` count over self/runtime_core.c):
  exit ×37, read ×29, write ×14, stat ×8, mkdir ×7, close ×4, mmap ×3, munmap ×1,
  getpid ×1, + open/openat (file path ops). All are ≤6 args.
  __hx_syscall0 (0-arg, e.g. getpid) + __hx_syscall6 (up to 6 args: read/write/open/
  close/mmap/munmap/stat/mkdir/exit) cover 100% of them.

A more general variadic `@syscall(num, ...)` is NOT needed: every libc-syscall the runtime
makes has ≤6 register args (Linux & Darwin both pass syscall args in ≤6 regs; >6-arg
syscalls don't occur here). syscall0 is a convenience alias for syscall6-with-zeros.
M1's verdict already RAN mmap(9)+munmap(11) end-to-end on real x86_64 (arena gate exit=5).

  VERDICT M3: DONE-BY-M1. No follow-up. The 2-form (syscall0/syscall6) is sufficient SSOT.

### NOTE — the allocator floor is libc malloc, NOT a syscall the runtime makes directly.
`hexa_arena_alloc` (runtime_core.c:3792) bottoms out in `malloc` (libc, via the
hxlcl_malloc rename shim), and mallopt tunes M_MMAP_THRESHOLD so large chunks are
mmap-backed *inside glibc*. The runtime does NOT call mmap directly for general allocation.
Two valid port strategies for batch-arena (see batch table): (A) model the bump-block chain
on top of hexa array growth (array growth IS malloc — the proven `arena_port.hexa` approach,
ZERO byte-eq risk), or (B) call `__hx_syscall6 mmap` for a raw page and bump within it. (A)
is strongly preferred (already prototyped, byte-eq-safe); (B) only if a malloc-free standalone
floor is later required. **This is the one genuine design fork in M4 — flag for the loop.**

================================================================================
## 2. M4 BATCH DECOMPOSITION (the core deliverable)
================================================================================

Each batch = one new `.hexa` source file under `stdlib/runtime/` (or the rt-native staging
dir) porting a runtime_core.c fn family, plus a per-fn byte-eq gate (~20 min/fn — the
dominant cost; this is why M4 is multi-session and why parallelism matters).

Legend — Intrinsics: which M1 leaves the batch needs (✅ all available | ⚠ needs ptr8
follow-up). Region: the `.hexa` source file it owns (disjoint files ⇒ parallel-safe).
Conflict: only the bind-whitelist + emitter block is shared, and ONLY a batch that needs a
NEW intrinsic touches it.

────────────────────────────────────────────────────────────────────────────────
WAVE 0 — FOUNDATION (must land before anything that allocates or constructs values)
────────────────────────────────────────────────────────────────────────────────

B1  batch-nanbox-ctor
    Fns: hexa_int, hexa_float, hexa_bool, hexa_void, hexa_bits_to_float, hexa_enum_str/_v
         (census category 1 — the 6-fn self-contained leaf set, UNLOCK2 verdict Q4).
    Intrinsics: ✅ none of the 25 leaf-READS — the CONSTRUCTOR side is the `_hv_load`/
         `_hv_store` codegen primitive, ALREADY inlined per operand kind on both backends.
         A hexa `let v: HexaVal = <int>` already lowers to `movz tag` + `mov payload`. So
         B1 is mostly a TYPE/SSOT exercise: expose hexa-source ctors that the emitter
         already inlines. May need __hx_tag (have it) for the bits_to_float reinterpret.
    Region: stdlib/runtime/nanbox.hexa (NEW file). No emitter edit.
    Independence: FULLY INDEPENDENT file. Dependency-ROOT (everything constructs HexaVals).
    Size: ~6 fns. Risk: low (UNLOCK2 proved no circularity; arm64 __hx_tag already 3/3 byte-id).

B2  batch-arena   (the allocator — STRATEGY-A: array-growth-backed; see M3 note)
    Fns: hexa_arena_new_block, hexa_arena_alloc, hexa_arena_mark, hexa_arena_rewind,
         hexa_arena_reset (+ HexaArenaBlock{next,cap,used} chain model).
    Intrinsics: ✅ none required under Strategy A (array growth = malloc). Under Strategy B:
         __hx_syscall6 (mmap/munmap) + __hx_ptr_store64/load64 — all ✅ available.
    Region: stdlib/runtime/arena.hexa (NEW file; PROTOTYPE EXISTS at
         scripts/scratch/rt_native/arena_port.hexa — faithful, byte-eq-reasoned).
    Independence: FULLY INDEPENDENT file. Dependency-ROOT for B5/B6/B7 (all allocate).
    Size: ~5 fns. Risk: low under A (prototype done); medium under B (raw mmap bump).

────────────────────────────────────────────────────────────────────────────────
WAVE 1 — RAW-MEM CONSUMERS (parallel; each owns a disjoint file; all depend on B1[+B2])
────────────────────────────────────────────────────────────────────────────────

B3  batch-strbuf   ⚠ NEEDS ptr8 follow-up (see M2 verdict)
    Fns: hexa_strbuf_dup_n, hexa_str_own_with_len, hexa_str_own (char-buffer dup/own).
    Intrinsics: __hx_str_byte (✅ read) + __hx_ptr_store8 (⚠ MISSING — the 2-case M2
         follow-up). Without ptr8 the byte-copy loop can't write; with it, trivial.
    Region: stdlib/runtime/strbuf.hexa (NEW file) + (the ptr8 intrinsic = the ONLY emitter
         edit in all of M4, lands in the shared STMT_CALL block + bind whitelist).
    Independence: file-independent of B4/B5/B6/B7; but its ptr8 emitter edit SERIALIZES
         against any other batch that also adds a new intrinsic (none currently planned).
         Land ptr8 FIRST as its own micro-PR, then B3 is pure-source.
    Size: ~3 fns + 2 intrinsic cases. Depends on: B1.

B4  batch-array-core
    Fns: hexa_array_new, hexa_array_get, hexa_array_set, hexa_array_push,
         hexa_array_pop, hexa_array_len/water_get/set, hexa_array_reserve.
    Intrinsics: ✅ __hx_arr_len (read), __hx_ptr_load64/store64 (16B HexaVal slot = 2 words),
         __hx_ptr_load32/store32 (int32 len/cap fields).
    Region: stdlib/runtime/array_core.hexa (NEW file).
    Independence: FULLY INDEPENDENT file. Depends on: B1 + B2 (alloc).
    Size: ~8-9 fns. Risk: medium (raw HX_ARR_ITEMS/len/cap offset arithmetic — must match
         the HexaArr{items,len,cap} struct layout exactly for byte-eq).

B5  batch-map-core
    Fns: hexa_map_new, hmap_find, hmap_grow, hexa_map_get, hexa_map_set, hexa_map_remove,
         hexa_map_contains_key, hexa_fnv1a_str (+ __map_* raw accessors).
    Intrinsics: ✅ __hx_ptr_load64/store64 (slot + HexaVal), __hx_ptr_load32/store32
         (slot count/cap), __hx_str_byte (fnv1a hashing reads key bytes).
    Region: stdlib/runtime/map_core.hexa (NEW file).
    Independence: FULLY INDEPENDENT file. Depends on: B1 + B2 + (fnv1a is self-contained,
         can co-locate). Hashing is byte-deterministic so byte-eq is tractable.
    Size: ~10 fns. Risk: medium-high (power-of-2 open-addressing + grow/rehash must be
         bit-identical to the C HX_MAP_TBL probe sequence).

B6  batch-array-hi   (the higher-order array combinators — delegate-shaped)
    Fns: hexa_array_map, filter, fold, sort, sort_by, reverse, slice, index_of, contains,
         shallow_clone, truncate (census category 5 wrappers over B4 primitives).
    Intrinsics: ✅ none new — these compose B4's get/set/push/len.
    Region: stdlib/runtime/array_hi.hexa (NEW file).
    Independence: FULLY INDEPENDENT file. Depends on: B4 (must land first — it calls
         array_core primitives), B1.
    Size: ~11 fns. Risk: low-medium (pure composition; sort comparator determinism).

B7  batch-map-hi   (map combinators — delegate-shaped)
    Fns: hexa_map_keys, values, entries, merge, invert, filter_keys, map_values, count,
         all, any, from_array, to_array.
    Intrinsics: ✅ none new — composes B5 + B4.
    Region: stdlib/runtime/map_hi.hexa (NEW file).
    Independence: FULLY INDEPENDENT file. Depends on: B5 (+ B4 for the array-returning ones).
    Size: ~12 fns. Risk: low-medium (composition; insertion-order preservation for keys/
         entries must match the C order-array).

────────────────────────────────────────────────────────────────────────────────
WAVE 2 — SYSCALL/FS + DELEGATE WRAPPERS (parallel; each disjoint file; depend on B1)
────────────────────────────────────────────────────────────────────────────────

B8  batch-syscall-fs
    Fns: rt_file_read/write/open/close, rt_fs_*, rt_path_exists, hexa_mkdir, __hexa_last_error
         (census category 2 — syscall floor).
    Intrinsics: ✅ __hx_syscall6 (read/write/open/close/stat/mkdir), __hx_syscall0 (getpid).
    Region: stdlib/runtime/syscall_fs.hexa (NEW file).
    Independence: FULLY INDEPENDENT file. Depends on: B1 (returns HexaVal). Note: stat/
         S_ISREG flag-masking is pure-int — expressible via __hx_payload_* arithmetic.
    Size: ~8-10 fns. Risk: medium (errno/last-error global state model + struct-stat field
         offsets; per-platform syscall NUMBER differs Linux vs Darwin — gate on BOTH).

B9  batch-string-delegate   (the rt_str_* delegate wrappers)
    Fns: hexa_str_replace→rt_str_replace, hexa_str_split→rt_str_split, hexa_pad_*→rt_pad_*,
         hexa_str_char_at→rt_str_char_at (category 5 delegates). rt_str_* ALREADY hexa-source
         (#3467) — this is the THIN HexaVal-typed wrapper layer over them.
    Intrinsics: ✅ __hx_tag (type-guard dispatch), __hx_str_byte.
    Region: stdlib/runtime/str_delegate.hexa (NEW file).
    Independence: FULLY INDEPENDENT file. Depends on: B1 + the already-landed rt_str_* hexa.
    Size: ~6-8 wrappers. Risk: LOW (1-line type-guard + delegate each; logic already native).
    NOTE: census flagged these as "already-native re-port" — keep them THIN; do not
    re-implement rt_str_* logic (it's done).

B10 batch-math-delegate   (libm-bound)
    Fns: hexa_log10/log2/tanh→rt_log10/log2/tanh, and the standalone-only libm 5
         (rt_cos/sin/exp/log/fmod — also surfaced in F-LEG-B-STANDALONE-SCOPE).
    Intrinsics: ✅ __hx_to_double / __hx_payload_f* for the HexaVal↔double boxing.
    Region: stdlib/runtime/math_delegate.hexa (wrappers) — note rt_cos/sin/exp/log already
         exist in stdlib/runtime/math.hexa but with a `float->float` ABI; this batch is the
         HexaVal-signature wrapper bridging that ABI mismatch (the exact concern raised in
         F-LEG-B-STANDALONE-SCOPE "ABI 발견").
    Independence: FULLY INDEPENDENT file. Depends on: B1.
    Size: ~8 wrappers. Risk: LOW-MEDIUM. POLICY: trig/exp/log = libm (CLAUDE.md "stdlib
         trig = libm"); do NOT hand-roll Taylor series. So these stay extern-libm-backed —
         the wrapper just does HexaVal↔double ABI conversion. (This is the ABI-wrapper work
         M5 needs anyway — landing it here pre-pays M5's standalone bridge.)

────────────────────────────────────────────────────────────────────────────────
OPTIONAL WAVE 3 — ctype / misc leaves (tiny, fully parallel, no deps beyond B1)
────────────────────────────────────────────────────────────────────────────────

B11 batch-ctype
    Fns: rt_isalnum, rt_isalpha (+ isdigit/isspace family) — standalone-only per
         F-LEG-B-STANDALONE-SCOPE; pure char-range tests.
    Intrinsics: ✅ __hx_payload_le/ge (range compares), __hx_str_byte. Already exists as
         stdlib/runtime/ctype.hexa — verify it covers the HexaVal-signature need + ABI.
    Region: stdlib/runtime/ctype.hexa (EXISTING — audit/extend, don't duplicate).
    Independence: FULLY INDEPENDENT. Depends on: B1. Size: ~4 fns. Risk: LOW.

────────────────────────────────────────────────────────────────────────────────
DEFERRED / OUT-OF-M4 (genuine floor — DO NOT port)
────────────────────────────────────────────────────────────────────────────────
  * libc malloc itself (the hxlcl_malloc/free/realloc/calloc substrate) — irreducible
    allocator floor UNLESS Strategy-B (raw mmap arena) is chosen. Keep as floor for M4.
  * The HexaVal struct *type definition* (self/runtime.h) + frozen 2-pass seed arena —
    intrinsic-expressible / git-tracked, classified small in F-LEGB-FLOOR-SIZED. Not M4.
  * net/pthread stubs (rt_net_fail/zero, rt_pthread_*) — 5 trivial constant-returning
    stubs (F-LEG-B-STANDALONE-SCOPE); fold into B8 or a micro-batch if/when M5 needs them.

================================================================================
## DEPENDENCY ORDER (topological)
================================================================================

  B1 (nanbox-ctor) ─┬─────────────────────────────────────────── root for ALL
                    │
  B2 (arena) ───────┼─── root for allocators (B4,B5)
                    │
  ptr8 micro-PR ────┴─── prereq for B3 only
                    │
  WAVE 1:  B3(strbuf, needs ptr8) │ B4(array-core, needs B2) │ B5(map-core, needs B2)
                    │                         │                          │
  WAVE 1b: B6(array-hi, needs B4) ────────────┘            B7(map-hi, needs B5,B4)
                    │
  WAVE 2:  B8(syscall-fs) │ B9(str-delegate) │ B10(math-delegate)   (only need B1)
  WAVE 3:  B11(ctype)                                              (only need B1)

Hard edges: B1 → everything. B2 → B4,B5. ptr8 → B3. B4 → B6 (and B7's array-returning fns).
B5 → B7. Everything else (B8,B9,B10,B11) depends ONLY on B1.

================================================================================
## PARALLELISM: WHAT CAN RUN FULLY PARALLEL vs MUST SERIALIZE
================================================================================

FULLY PARALLEL (disjoint .hexa files, no shared emitter edit):
  * WAVE 0: B1 ∥ B2 (different files, no dep between them) — 2-wide.
  * WAVE 1: B3 ∥ B4 ∥ B5 — 3-wide (after B1/B2 + ptr8 land).
  * WAVE 1b: B6 ∥ B7 — 2-wide (after B4/B5).
  * WAVE 2: B8 ∥ B9 ∥ B10 ∥ B11 — 4-wide (only need B1; can actually START in parallel
    with WAVE 1, since they don't touch arena/array/map — see "aggressive schedule" below).

MUST SERIALIZE:
  * The ONLY emitter-region conflict in all of M4 is the ptr8 intrinsic (shared STMT_CALL
    block + bind whitelist). It is a single 2-case micro-PR; land it standalone BEFORE B3.
    No other batch adds an intrinsic, so no other serialization on the emitter.
  * B1 must precede every value-constructing batch (i.e. all of them) — but B1 is small
    and mostly a thin SSOT exposure of already-inlined ctors, so it lands fast.
  * B2 must precede B4/B5. B4 precedes B6. B5 precedes B7.

AGGRESSIVE (recommended) SCHEDULE — the WAVE-2/3 batches (B8-B11) only need B1, so fan
them out CONCURRENTLY with WAVE-0/1:
  Wave A (fire on B1 landing): B2, B8, B9, B10, B11   (5-wide)
                               + ptr8 micro-PR (serial, tiny)
  Wave B (fire on B2+ptr8):    B3, B4, B5             (3-wide)
  Wave C (fire on B4,B5):      B6, B7                 (2-wide)

================================================================================
## REALISTIC ESTIMATE
================================================================================

  Batches: 11 (B1-B11) + 1 ptr8 micro-PR = 12 units.
  Functions: ~85-95 fns total (matches the census's 84 PURE survivors + the syscall/array/
             map raw-mem set; the broader ~1190 common-core is the eventual full leg-B bulk,
             of which these batches are the substrate-critical front).
             Per batch: 3-12 fns (median ~8).
  Parallel waves: 3 (Wave A 5-wide, Wave B 3-wide, Wave C 2-wide) + the serial ptr8 sliver.
  Cost driver: per-fn byte-eq gate ≈ 20 min (F-LEG-B-STANDALONE-SCOPE). ~90 fns × 20 min
             ≈ 30 gate-hours of verify — multi-session, but the 3-wave fan-out collapses
             wall-clock to roughly the longest path: B1 → B2 → B4 → B6 (~4 serial batch
             depths). With 5-wide Wave A, the campaign is throughput-bound on verify, not
             on dependency depth — i.e. parallelism HELPS materially.

================================================================================
## 3. M5 / M6 DESIGN SKETCH (later — switching the standalone build to native rt_*.o)
================================================================================

Mechanism (per F-LEGB-STANDALONE-ELSE-NOGO + tool/stage_resolve_runtime_a):

  * The PRIMARY shipping/CI runtime is the STANDALONE config: CI release/byteeq/miscompile/
    determinism gates → tool/release_build → tool/stage_resolve_runtime_a:271 compiles
    self/runtime.c with NO -DHEXA_HAS_HEXA_RT_STDLIB → the #else C-body path → build/runtime.a
    → linked into shipped ./hexa. So the #else C bodies are LIVE (NOT dead code — DEADCODE-PATH
    verdict was FALSIFIED). They cannot just be deleted.

  * M5 switch point = `build_runtime_a_from_source()` in tool/stage_resolve_runtime_a (the
    function that `ar rcs $RA build/runtime.o $extra_obj`). The Z2a precedent is ALREADY THERE:
    when HEXA_ZEROC_RT_HI=1 + build/rt_hi_native.o exists, it `sed`-removes the
    `#include "runtime_hi_gen.c"` and `ar`s a NATIVE-compiled rt_*.o into runtime.a instead.
    M5 generalizes that gate per batch: once batch Bk's stdlib/runtime/<file>.hexa is
    aprime-native-compiled to rt_Bk_native.o, add it to `$extra_obj` and excise the
    corresponding #else C bodies from the runtime.c TU (same sed/frozen-seed-coherent edit).

  * THE ABI WRAPPER CONCERN (F-LEG-B-STANDALONE-SCOPE "ABI 발견", and why B10/B11 pre-pay it):
    the #else C bodies have a HexaVal-uniform ABI (`HexaVal rt_cos(HexaVal)`), but the existing
    stdlib/runtime hexa-source has narrowed ABIs (`rt_cos(x: float) -> float`). A native rt_*.o
    that links into the standalone build MUST present the HexaVal-16B signature the rest of
    runtime.c calls — else the call frame is wrong (16B struct-return vs float-reg). So each
    batch's hexa source must EITHER be authored with the HexaVal signature (preferred — B1's
    nanbox ctors make this cheap) OR carry a HexaVal↔scalar shim. M4's delegate batches (B9/B10)
    are authored at the HexaVal boundary precisely so M5 inherits zero ABI debt.

  * FROZEN-SEED COHERENCE (F-LEG-B-DEADCODE-PATH complexity note): self/runtime.c is a frozen
    seed (git blob, restored by restore_frozen_seeds in cold STAGE-0). Any #else excision must
    be reflected in the frozen seed mechanism (new frozen revision OR restore_frozen_seeds
    update), or a cold regen re-restores the old C bodies. M5 must land the excision AS a
    frozen-seed bump, not just a warm-tree edit.

  * M6 = the dual-config gate: prove BOTH configs (HEXA_HAS extern-link of native rt_*.o AND
    standalone native-rt_*.o-linked) produce a byte-identical ./hexa, and that
    gen3≡gen4 self-host fixpoint holds on BOTH x86_64 and arm64. The dualconfig_gate.sh +
    byteeq_x86.sh scratch harnesses are the starting point. `ls self/*.c == ∅` is reached when
    every #else C-body family has a native rt_*.o replacement AND the frozen seed no longer
    carries those bodies.

  Order: M5 = per-batch flip of stage_resolve_runtime_a + frozen-seed bump (incremental, one
  batch at a time, each gated). M6 = the final dual-config + dual-target fixpoint gate + the
  `ls self/*.c == ∅` check. Both are AFTER all M4 batches land their native rt_*.o.

================================================================================
## HONEST UNKNOWNS (c9)
================================================================================
  * Strategy A-vs-B for B2/B4/B5 allocation (array-growth-over-malloc vs raw-mmap arena):
    A keeps libc malloc as floor (byte-eq-safe, prototype done); B removes malloc but is
    unproven and risks byte-eq drift. RECOMMEND A for M4; revisit B only if a malloc-free
    standalone floor becomes a hard requirement. Decision deferred to the loop.
  * Exact HexaArr / HexaMapTable field offsets for B4/B5 raw-mem must be read from the struct
    defs (runtime_core.c:1073 HexaArr, :1052 HexaMapTable) at port time — byte-eq depends on
    matching them precisely; not pre-verified here.
  * B9/B10/B11 may be PARTIALLY already-native (rt_str_* #3467, math.hexa, ctype.hexa exist) —
    these batches are AUDIT-THEN-THIN-WRAP, not greenfield; the loop should diff the existing
    hexa-source first to avoid re-porting (census category-5 "already-native re-port" caveat).
  * Per-platform syscall numbers (B8) differ Linux vs Darwin — both targets must gate; mmap is
    9 on Linux x86_64 but the BSD trap convention differs (arm64 uses x16+svc). M1 already
    handled this for syscall0/6 but B8's specific syscall numbers are per-call and must be
    table-driven per target.
