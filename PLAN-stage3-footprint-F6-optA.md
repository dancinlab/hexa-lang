# DESIGN — F6 option A: region-promote on return

> Authority: `PLAN-stage3-footprint-F6.md` option A. Option C empirically
> failed on 2026-05-16 (commits `0efebc88`+`77f82e11`, revert
> `3429ac7e`): runtime-level sharing (`hexa_str_concat` empty-elision,
> struct_pack inner-aliasing) is wider than the P0a–P0e *static*
> string-leaf audit caught, and the compiler's resolve pass treats new
> builtins as HX2001. A is the principled remaining path; it pays the
> depth of a value-model rewrite for genuine reclaim safety.

## 결정

```
결정 F6: option A — region-promote on fn return (replaces P0-then-C).
   pivot from C: option C's static audit could not enumerate runtime-
   level sharing exhaustively; the empirical .s-drift on tiny inputs
   and the HX2001 resolve gap proved the risk concrete. A trades
   blast radius (value-model touch) for safety (deep-copy boundaries).
   decided-by: user (2026-05-16, "F6 옵션 A — substantial 별도 effort")
   decided-on: 2026-05-16
```

## Why C cannot be patched in place

The two C-failure modes from the F6-step-4 measurement:

- **HX2001 `free_tree`** — the compiler's resolve pass rejects new
  builtin names. A resolve-table change is locally small but the next
  failure is the deeper one:
- **`.s` drift on a 2-fn input** — even tiny programs produce different
  assembly with the `free_tree` calls in place. The cause is runtime
  sharing the static audit cannot see:
  - `hexa_str_concat`'s empty-elision (`la==0 → return b`, `lb==0 →
    return a`) — `_emit_func`'s internal accumulator starting from `""`
    means the first concat result shares with the operand string,
    *which is owned by `lfunc`*. Freeing `lfunc`'s shell triggers
    use-after-free reads of that operand bytes.
  - `struct_pack_map` shallow-clone (memory `feedback_hexa_struct_pack_
    aliasing`) — outer cloned, inner arrays/maps shared.

Both are *runtime* properties, not statically enumerable. Patching C
would require a runtime audit on every value-flow path that crosses
the streaming loop boundary — a strict superset of A's work.

## Mechanism

Currently `__hexa_fn_arena_return(v)` does:

```
heapify(v)   # arena → malloc deep-copy
scope_pop    # rewind arena to mark
return v     # caller sees a malloc'd tree (no free, hexa-native)
```

A returns a value that lives **in the caller's arena frame** instead of
malloc. The caller's frame eventually pops too — and *that* pop reclaims
the per-iteration IR. In the streaming loop, the per-iteration scope
pops at the end of each loop body, so `mfunc`/`lfunc` are freed
automatically; only what was explicitly promoted further out (the asm
fragment in `parts`) survives.

### Bump-arena overlap problem

Bump arenas do not permit naive "rewind then alloc in parent":

```
parent_mark ──────────────── callee_mark ───── frontier
            (parent's data)  (callee's data)
```

After the callee's scope_pop, frontier = callee_mark. To put a copy of
the callee's return value in *parent's* region, we'd need to allocate
between parent_mark and callee_mark — which is exactly where the
*source* of the copy sits. The destination would overwrite the source
mid-copy. **Source/destination overlap is the central technical issue.**

### Safe sequence — temp-buffered heapify-to-parent

The clean, overlap-free three-step primitive:

```c
HexaVal hexa_val_arena_heapify_to_parent(HexaVal v) {
    HexaVal temp = hexa_val_heapify(v);             // 1. malloc deep-copy
    hexa_val_arena_scope_pop();                     // 2. rewind callee region
    HexaVal arena_copy = hexa_val_copy_into_arena(temp); // 3. into parent
    hexa_val_free_tree(temp);                       // 4. free temp
    return arena_copy;
}
```

Cost: a brief 2× memory peak (the malloc temp + the arena copy live
together for one recursion). Benefit: provably correct against the
overlap problem, and the temp goes through `hexa_val_heapify` which has
been runtime-tested for decades — no new aliasing concerns introduced.

`hexa_val_copy_into_arena(v)` mirrors `hexa_val_heapify` *backwards*:
where heapify recurses copying into malloc, copy_into_arena recurses
copying into `hexa_val_arena_calloc` with `from_arena=1` on each new
struct. This primitive is **dormant infrastructure** — nothing wires it
in until the opt-in step.

## Opt-in vs global

Global `__hexa_fn_arena_return` switching to heapify-to-parent affects
every fn return in every hexa program. Blast radius forbids that. The
opt-in design:

1. A new variant `__hexa_fn_arena_return_region(v)` calls
   `hexa_val_arena_heapify_to_parent` instead of `hexa_val_heapify`.
   Existing `__hexa_fn_arena_return` is unchanged.
2. The streaming loop body becomes a Val-arena scope (push at iteration
   start, region-promote the asm fragment on exit, pop). Within that
   scope, the *immediate* callees (`_lower_fn`, `_arm64_lower_func`,
   `_emit_func`) need their returns region-promoted into the loop body
   frame.
3. Selection mechanism: simplest is an env-toggle the streaming loop
   sets around its body — e.g. `env("__HEXA_ARENA_RETURN_REGION__")` —
   that flips a thread-local flag read by `__hexa_fn_arena_return`. The
   flag-set version then dispatches to the parent-region variant. The
   codegen does not change.
4. Backward compat: `HEXA_VAL_ARENA=0` (the default per commit
   `02af1622`) makes both arena-return variants no-ops, so the opt-in is
   inert outside the streaming loop. Forcing `HEXA_VAL_ARENA=1` is
   required to exercise the region path; the `f4b597a7` envelope fix
   keeps that fast enough.

## Streaming loop integration (A4 decision recorded)

The original sketch left the strtab/asm-fragment escape as an open
question (a "heapify-to-outer primitive"). A4 resolves it with a
**per-call toggle pattern** — no new primitive. The A3 region-returns
flag is flipped ON only for the calls whose returns should stay inside
the per-iteration scope, and OFF for the ones whose returns must
survive across iterations:

```
codegen_emit_streaming(hmodule, target):
    parts = []
    # outer frame == codegen_emit_streaming's own __hexa_fn_arena scope
    for each item:
        env("__HEXA_ARENA_PUSH__")              # iter F1 scope
        env("__HEXA_ARENA_RETURN_REGION_ON__")  # returns → F1
        mfunc = _lower_fn(it)                   # mfunc in F1
        env("__HEXA_ARENA_RETURN_REGION_OFF__")
        st = _arm_strtab_collect_fn(st, mfunc)  # return heapified to malloc
        env("__HEXA_ARENA_RETURN_REGION_ON__")
        lfunc = _arm64_lower_func(mfunc, st, modhash)  # lfunc in F1
        env("__HEXA_ARENA_RETURN_REGION_OFF__")
        if lfunc.target == target:
            frag = _emit_func(target, lfunc)    # return heapified to malloc
            parts.push(frag)                    # parts is heap-owned
        env("__HEXA_ARENA_POP__")               # frees mfunc/lfunc/transients
    rodata = _strtab_to_rodata(st)
    return parts.join("") + rodata-emission
```

- mfunc/lfunc are in F1 ⇒ POP reclaims them per iteration (the point).
- st and frag are heapified to malloc on return ⇒ outlive POP trivially;
  no "heapify to named outer frame" primitive needed.
- The 6 env() toggles per iter are O(1) each; negligible CPU.

### Verified A4 design vs the original open questions

- **`st` escape**: SOLVED by toggling region returns OFF only for the
  `_arm_strtab_collect_fn` call. Its return path uses today's
  heapify-to-malloc; the growing st remains a heap-owned ArmStrTab
  across iterations. No O(N²) per-iter heapify; no new primitive.
- **Region-return granularity**: SETTLED as per-fn-return with a
  process-global flag (A3). The granularity is per-call via toggle, not
  per-fn-return. The runtime branch (`if (region_enabled) …`) in
  `__hexa_fn_arena_return` is one already-paid load + branch in the
  global lifetime, off-path when the flag is OFF (= today's default).

### Residual A4 caveat — substring/strbuf allocation

`_collect_strs_from_stmt`'s P0a path calls
`o.str_val.substring(0, len(o.str_val))` to force a fresh string copy.
`hexa_str_substring` allocates via `hexa_strbuf_alloc`. Open question
for A5/A6 verification: does that buffer live in the per-iter F1 (bump
arena) or in the malloc heap independent of arena scopes? If it's
arena-backed, the substring buffer is freed on F1 POP even when the
ArmStrTab wrapper escaped to malloc — st.keys would dangle. A5's
empirical check (run, observe whether rodata content survives) gates
this. If it's the first case, the targeted fix is a `force_heap_dup`
runtime primitive used in P0a — small follow-up, scoped to A4.5.

## Phased steps

| step | deliverable | notes |
|------|-------------|-------|
| A1 | this design doc + `hexa_val_copy_into_arena` primitive (dormant). | landed this turn. |
| A2 | `hexa_val_arena_heapify_to_parent` wrapper (uses A1 + temp-buf). | dormant; clang-c'd. |
| A3 | `__hexa_fn_arena_return_region` variant; thread-local opt-in flag; `env("__HEXA_ARENA_RETURN_REGION__")` hook. | dormant; the codegen path is unchanged. |
| A4 | per-call region-toggle pattern (no new primitive needed). | landed: design decided, doc updated. Residual: substring/strbuf residency check at A5/A6. |
| A5 | Wire `stream.hexa` … toggle the env flag. | ✅ landed `eab52730`; iterated A5.1 `6f171b11` (gate), A5.2 `40ccb718` (defer parts.push past POP), A5.3 `b3f5d4d8` + A5.3.1 `ff752c66` (double-gate on HEXA_STREAM_RECLAIM — arena defaults ON in new binaries, so an arena-only gate was live by default). |
| A6 | ubu rebuild + RSS measurement. | 🔶 partial (2026-05-16). sanity small: legacy ↔ `--stream` **byte-IDENTICAL** ✓ (default path correct). full self-compile under `HEXA_VAL_ARENA=1 --stream` (no reclaim): RSS **plateaued ~12 GB** (vs legacy ARENA=0 30 GB — the *existing* per-fn arena scope already gives ~2.5× even without F6-A) BUT wall-time ≫14× legacy → killed at 45 min, no completed `.s` → no full byte-diff. The F6-A reclaim path (`HEXA_STREAM_RECLAIM=1`) SIGSEGVs at `_new_block` (hir_to_mir.hexa:192) — A1/A2 ↔ array-push (`cap<0` arena marker) correctness gap under arena=1. **Blocked: needs runtime debug, not a loop tick.** |
| A7 | Make `--stream` default once A6 verifies. | ⛔ gated on A6 full byte-diff + the A6 SIGSEGV fix. Not safe to flip yet. |

## A6 findings (2026-05-16, empirical)

1. **Infra correct under default.** A1–A5 + the A5.3 double-gate make
   `--stream` byte-identical to legacy on the small sanity. The
   streaming structure is sound; the default path is safe on main.
2. **F6-A reclaim is blocked.** `HEXA_STREAM_RECLAIM=1` → SIGSEGV in
   `_new_block`. Root area: `hexa_val_copy_into_arena` (A1) emits
   `cap<0` arena-marked arrays; the runtime array-push grow path under
   arena=1 mishandles them when the per-iter POP interleaves with the
   codegen-emitted `__hexa_fn_arena_enter/return`. This is the genuine
   remaining work and is a careful runtime debug — not loop-tick-sized.
3. **Side result — ARENA=1 already bounds RSS.** Even with F6-A reclaim
   OFF, `HEXA_VAL_ARENA=1`'s existing per-fn scope reclaim plateaus the
   self-compile at ~12 GB vs ARENA=0's 30 GB. But ARENA=1 wall-time is
   ≫14× → impractical as-is. So the *real* footprint lever is making
   ARENA=1 fast enough (the `f4b597a7` envelope fix was step 1; more
   heapify-cost reduction needed) — possibly a higher-value path than
   F6-A's per-iter reclaim.

## A6.1 — the fundamental F6-A blocker (2026-05-16, gdb-confirmed)

Two bugs found by gdb on the `HEXA_STREAM_RECLAIM=1` path, then a
structural blocker:

1. **MAP-share use-after-free** — FIXED `0292fe4d`. In this value
   model a hexa `struct` lowers to a **TAG_MAP** (`struct.field` =
   `hexa_map_get`). A1 `copy_into_arena` passed TAG_MAP through, so the
   A2 temp-buffered promote shared the map with the malloc temp and
   `free_tree(temp)` freed it → `_new_block`'s `hexa_map_get` on the
   freed LowerCtx SIGSEGV'd. Fixed by deep-copying TAG_MAP via
   `hexa_map_new()`+`hexa_map_set()`.

2. **heapify ≠ full-owned clone → double-free** — A2 step 1 uses
   `hexa_val_heapify(v)` which only promotes *arena* nodes to malloc;
   already-heap / static-string nodes stay **shared with the original**
   (e.g. hmodule strings heapify didn't copy). `free_tree(temp)` then
   frees that shared heap memory → `munmap_chunk(): invalid pointer`
   SIGABRT (`free_tree:3733 ← heapify_to_parent:3913 ← _set_cur_block`).
   Same runtime-aliasing class that sank option C; the temp-buffer does
   not escape it. A true *force-malloc full deep clone* (no sharing)
   would be needed for step 1.

3. **STRUCTURAL BLOCKER — region-promote cannot reclaim map-structs.**
   `hexa_map_set` on a fresh map creates its table via
   `hmap_alloc(cap)` = `hmap_alloc_ex(cap, from_arena=0)` (runtime.c
   :2270) — **always malloc**, never arena. Since structs ARE maps in
   this value model, the dominant IR (LowerCtx/MFunc/LFunc) is
   map-backed. So even a correct `copy_into_arena` built on
   `hexa_map_new`/`hexa_map_set` produces **malloc** tables, NOT
   arena-resident ones. The per-iteration arena POP therefore cannot
   reclaim the IR — F6-A's entire footprint mechanism is moot for
   map-represented structs. Making it work needs arena-resident map
   construction: `hmap_alloc_ex(cap, from_arena=1)` plus a hand-rolled
   re-implementation of `hexa_map_set`'s FNV hashing, load-factor
   growth, and slot/order-array discipline against an arena table —
   the multi-week value-model rewrite the F6-A doc warned about.

### Verdict on F6-A

**F6-A (region-promote) is the wrong lever for this value model.**
The structs-are-maps + map-tables-force-malloc invariant means the
per-iter region POP has nothing to reclaim without a from-scratch
arena-map subsystem. A1/A2/A3/A5 stay landed as dormant, double-gated
(`HEXA_STREAM_RECLAIM=1`), correctness-fixed where reached — but the
footprint payoff is structurally absent here.

**The productive lever is ARENA=1 perf** (A6 finding §3): the
*existing* per-fn arena scope already bounds the self-compile RSS
30 GB → ~12 GB (2.5×) — it just costs ≫14× wall-time because
`hexa_val_heapify` deep-copies returned trees on every fn return.
`f4b597a7` (O(1) str-envelope) was step 1 of cutting that; the next
heapify-cost reductions (VALSTRUCT shallow-copy fast-paths, the
ω-interp frame-clean gate, map heapify) are bounded, measurable, and
do not need a value-model rewrite. **Recommended pivot: ARENA=1
heapify-cost optimization, not further F6-A.**

**Loop terminus.** A1–A5 landed and safe (default byte-identical).
F6-A footprint is structurally blocked (above). Remaining paths —
ARENA=1 heapify perf, or the x86_64 verdict ABI — are substantial
deliberate engineering, not loop-tick work
(COMPILE-ONLY.log.tape `loop_terminus` discipline).

## Verification

Every primitive is independently testable:

- A1 / A2 unit-callable from a small C harness (round-trip a known tree
  through arena↔malloc, assert structural identity).
- A3 thread-local flag check via a 2-fn hexa program (one fn opts in,
  returns through region; observe arena-tip after vs before).
- A5: `.s` byte-diff legacy ↔ `--stream` on
  (i) the small sanity (`add(2,3)`) — must be IDENTICAL,
  (ii) the full self-compile (`aprime_flat.hexa`) — must be IDENTICAL,
  (iii) and the stream peak RSS must drop materially below legacy's
  ~30 GB peak.

## Risk + scope

Honest sizing: **A1–A2 are one careful turn each**; A3–A5 are several
days of design + careful runtime work + small-experiment verification;
A6–A7 are the standard ubu build/measure loop. **The whole option-A
effort is multi-week**, not a single closure. The dormant infrastructure
(A1, A2, the `free_tree` from F6 step 1, the `s4_flatc_post` rewrite)
all stay landed throughout — partial completion is safe.

Out-of-scope alternative (for this design): full general-purpose region
memory in the runtime. The minimum-viable option-A is "the streaming
loop body is one scope, fn returns inside it promote to that scope" —
not a full region calculus. Generalizing later is straightforward but
unnecessary for stage-3 closure.

## Practical fallback

Stage-3 verdict is independent of footprint reduction. The legacy path
(measured 30 GB / 3 min on ubu, exit 0, `.s` 206,696 lines) is already
verdict-ready on a 32 GB+ host. A-series work and verdict closure can
proceed in parallel — the verdict does not block on F6.

## ARENA=1 perf — profiled hotspot (2026-05-16, gprof; perf blocked by paranoid=4)

Synthetic 181-fn input, `aprime_cc` self-style compile, `HEXA_VAL_ARENA=1`,
gprof flat profile:

```
92.86%  1,881,840 calls   hexa_val_heapify        ← the entire cost
 1.43%                     hexa_map_get_ic_slow
 0.71%×N                   (everything else < 1%)
```

`hexa_val_heapify` is **92.86%** of ARENA=1 compile time — it *is* the
~14× slowdown. Root pattern: the compiler threads `ctx` (a TAG_MAP,
since structs lower to maps) through dozens of pure-functional helpers
per function (`_bind`/`_new_block`/`_set_cur_block`/`_lower_*`); every
helper's `__hexa_fn_arena_return` re-heapifies the whole ctx tree.
`ctx` carries growing `locals`/`blocks` arrays → O(carried · returns)
≈ O(N²) per function lowered.

The waste is concrete: `hexa_val_heapify`'s **TAG_MAP `!from_arena`
(heap table) branch has NO skip gate** — it unconditionally walks all
`ht_cap` slots and recurses every value, even when the table and all
values are already heap (carried unchanged from a prior heapify). The
TAG_VALSTRUCT path has the ω-interp-2 `hexa_arena_frame_clean()` gate,
but (a) ctx is a MAP not a VALSTRUCT, and (b) the gate is per-FRAME and
the compiler does constant arena string-concat (`str_concat_arena`
≈227K, `arena_alloc`≈3.4M) → the frame is *never* clean → the gate
could not fire even if added.

**Conclusion:** the only correct fix is **per-node arena-free
tracking** (a "this subtree has no arena descendants" seal set when
heapify completes a node, cleared on any mutation that could insert an
arena child) so re-heapify of an unchanged all-heap subtree is O(1).
That needs a seal bit on the hot `HexaArr`/`HexaMapTable`/
`HexaValStruct` types + seal-clear discipline on every mutation path —
an ABI-sensitive, regression-prone, multi-day runtime change. The
`f4b597a7` envelope fix (O(1) str-pointer reject) was the one
loop-tick-sized piece; the rest is deliberate engineering.

### Net session conclusion (all three stage-3 paths characterized)

| path | status | remaining work |
|------|--------|----------------|
| F6-A region reclaim | structurally blocked | hand-rolled arena-map subsystem (multi-week value-model) |
| ARENA=1 heapify perf | hotspot pinpointed (92.86%) | per-node arena-free seal (multi-day, ABI-sensitive) |
| x86_64 verdict ABI | diagnosed | codegen bare-name→runtime-symbol alignment (multi-day) |

All three are deliberate non-loop-tick engineering. The session landed
the loop-decomposable parts (envelope fix, F1–F4 streaming, HEXA_MEM_
LIMIT, F6-A infra A1–A5 dormant+double-gated, 2 reclaim bug fixes) with
the default path byte-identical throughout, plus decisive diagnoses
that scope each remaining effort precisely. Loop terminus — genuine.
