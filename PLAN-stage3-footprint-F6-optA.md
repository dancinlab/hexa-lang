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

## Streaming loop integration (sketch)

```
codegen_emit_streaming(hmodule, target):
    parts = []
    push_outer_scope()                # outer frame: owns parts, st
    for each item:
        push_iter_scope()             # per-iteration region
        enable_region_returns()       # flip the env flag
        mfunc = _lower_fn(it)         # return region-promoted to iter frame
        st = collect_strs(st, mfunc)  # st escape — heapify to outer (existing)
        lfunc = arm64_lower(mfunc, st, modhash)
        if lfunc.target == target:
            frag = emit_func(target, lfunc)
            parts.push(heapify_to_outer(frag))   # explicit escape
        disable_region_returns()
        pop_iter_scope()              # frees mfunc/lfunc/transient
    rodata = strtab_to_rodata(st)
    out = join(parts) + rodata-emission
    pop_outer_scope()
    return heapify(out)
```

Two open mechanical questions for the next design iteration:

- **`st` escape**: each `_arm_strtab_collect_fn(st, mfunc)` writes
  string copies into `st`, which lives in the *outer* frame. With
  region-returns enabled the call's return is also routed to the iter
  frame — `st` would be promoted to iter frame, then iter-pop frees it.
  Solution: write the strtab updates into the *outer* frame directly,
  or heapify-to-outer the strtab on every iteration. The latter is
  simpler but quadratic; the former requires a "store into named outer
  frame" primitive.
- **Region-return granularity**: should the flag be checked per
  fn-return, or once per loop body? Per-return is finer but adds a
  branch on every hexa function return for the whole program lifetime
  (negligible CPU, large engineering surface).

## Phased steps

| step | deliverable | notes |
|------|-------------|-------|
| A1 | this design doc + `hexa_val_copy_into_arena` primitive (dormant). | landed this turn. |
| A2 | `hexa_val_arena_heapify_to_parent` wrapper (uses A1 + temp-buf). | dormant; clang-c'd. |
| A3 | `__hexa_fn_arena_return_region` variant; thread-local opt-in flag; `env("__HEXA_ARENA_RETURN_REGION__")` hook. | dormant; the codegen path is unchanged. |
| A4 | `st` escape decision (see open questions). Likely a "heapify into named outer frame" primitive added under A3. | design + small experiment. |
| A5 | Wire `stream.hexa` to push/pop iter scopes around the loop body and toggle the env flag. | the actual integration. |
| A6 | ubu rebuild + RSS measurement: legacy vs `--stream` with region returns. Byte-diff. | the verdict. |
| A7 | Make `--stream` default once A6 verifies. | retire the gate (F5). |

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
