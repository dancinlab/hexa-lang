# DESIGN-GATE — F6: per-function IR reclaim

> Companion to `PLAN-stage3-footprint.md` (F6). This is a **decision
> document**, not an implementation plan — it frames one architectural
> choice that must be made before stage-3 footprint work continues.
> Governance: step-by-step-decision-gate — one gate, one recorded
> decision (`결정` block at the end).

## The decision being gated

> **How should the streaming compiler reclaim a function's MFunc/LFunc
> once that function has been emitted, given hexa-native has no GC?**

F1–F4 are landed: the back-half is fused into one per-function loop
(`codegen_emit_streaming`) and the O(N·T) asm accumulator is gone. But
the per-function IR is still **not freed** — F6 is the only remaining
lever that actually moves native RSS.

## Background — why F1–F4 do not suffice

`PLAN-stage3-footprint.md` Finding §1: every sub-call in the fused loop
(`_lower_fn`, `_arm64_lower_func`, `_emit_func`) returns a value;
`__hexa_fn_arena_return` (runtime.c) **heapifies the return to the
malloc heap** and pops that call's arena frame. hexa-native has no
`free`/GC, so each iteration's MFunc/LFunc — logically dead once its
text is emitted — persists on the malloc heap until process exit. On the
25,932-line self-compile that is the 10–16 GB driver.

## The cross-cutting hazard — aliasing

Any reclaim scheme must respect that per-function IR **shares storage
with longer-lived structures**. Concrete evidence — `_collect_strs_from_stmt`
(`compiler/codegen/arm64_darwin.hexa`):

```
keys.push(o.str_val)     // o.str_val is the MFunc operand's string
```

The streaming loop's `ArmStrTab st` accumulates string literals by
pushing `o.str_val` — the **same** HexaVal string handle the MFunc holds.
`st` outlives every iteration (it is consumed for `.rodata` after the
loop). So freeing iteration i's MFunc tree would dangle `st.keys[*]`.
The same question applies to LFunc → `st` label references and to MFunc
→ HItem (hmodule) string sharing.

**Therefore: no reclaim scheme is safe until cross-iteration stores are
escape-disciplined** — a value stored into a structure that outlives the
current iteration must be *copied* out of the per-iteration region, not
referenced. This is a prerequisite for every option below, call it **P0**:

> **P0** — make `_arm_strtab_collect_fn` (and any other cross-iteration
> store) deep-copy the interned string (`hexa_str_own` / explicit dup)
> so `st` owns its keys independently of any MFunc. Small, local,
> byte-identical, parse-gate + build verifiable. Must land first.

## Options

### A. Region-promote on return (escape-aware heapify)

Change `__hexa_fn_arena_return` so a returned value is promoted into the
**caller's** arena frame instead of the malloc heap. The streaming loop
body becomes one arena scope; each iteration's IR is promoted only as
far as the loop-body frame and freed by that frame's pop.

- *Mechanism*: `hexa_val_heapify` gains a "destination = parent arena
  frame" mode; the scope-pop reclaims it. Region/escape model.
- *Cost*: touches the core value model — every `fn` return in every
  hexa program. High blast radius; the bump allocator + mark stack must
  handle promotion-copy without source/destination overlap (callee
  region sits above the parent frontier — copy must go via a temporary
  or be ordered carefully).
- *Risk*: high. This is the principled long-term answer but it is a
  value-model change, not a footprint patch.

### B. Re-enable the array/struct freelist

`doc/stage0_arena_phases.md` notes `array_free_list` reclaim is disabled
(M4-fix, `self/hexa_full.hexa`). Re-enabling it returns dropped backing
store to a freelist for reuse.

- *Mechanism*: reuse the existing (dormant) freelist; needs refcount or
  ownership discipline to know a struct is truly dead.
- *Cost*: medium — the freelist exists; the discipline does not.
- *Risk*: high — it was disabled *because* of the shallow-clone aliasing
  defect (see memory `feedback_hexa_struct_pack_aliasing`: outer cloned,
  inner `[[T]]` shared). Re-enabling without full ownership tracking
  reintroduces use-after-free. Same P0 hazard, repo-wide.

### C. Targeted explicit-drop intrinsic for the streaming loop

Add a runtime hook `hexa_val_free_tree(v)` (exposed as
`env("__HEXA_DROP__")` or a builtin); the streaming loop calls it on
`mfunc` and `lfunc` once each is consumed.

- *Mechanism*: recursive free of a malloc'd HexaValStruct tree. Caller
  asserts the value is unshared.
- *Cost*: low — one runtime function + two call sites in `stream.hexa`.
  Blast radius is exactly the streaming loop.
- *Risk*: medium — **unsafe without P0** (would free `st`'s strings).
  With P0 landed, the loop's `mfunc`/`lfunc` are provably unshared at
  the drop point and the free is sound. Verifiable: byte-diff of the
  emitted `.s` (drop must not change output) + RSS probe.

## Recommendation

**P0 first, then C.** Rationale:

- P0 is mandatory for A and B too — it is not throwaway work.
- C with P0 is the minimum-blast-radius path that actually frees the
  per-function IR: ~one runtime function + two call sites, no change to
  the value model or to any other hexa program. It directly and only
  serves the streaming loop, which is the verdict's hot path.
- A is the principled end-state but is a value-model rewrite — schedule
  it as its own effort, not as a footprint unblock. C does not preclude
  A later (C's `free_tree` is subsumed by A's region pop).
- B carries A's risk without A's generality — not recommended.

Verification for P0+C: emitted `.s` byte-identical to pre-F6 (drop is
not allowed to change output), and the stage-1 self-compile peak RSS
measured below the no-reclaim baseline. Both gate on the stage-1 build
(shared with F5).

## 결정 (to be recorded)

```
결정 F6: <A | B | C | P0-then-C>  ·  <rationale>
   recommended: P0-then-C
   decided-by: <user>            decided-on: <YYYY-MM-DD>
```

Pending user confirmation. Until recorded, F6 is not implemented —
F1–F4 (landed) stand on their own as the streaming structure + the
O(n²) accumulator fix.
