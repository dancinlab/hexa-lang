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

> **P0 — escape-edge discipline.** Before any per-iteration value can be
> freed, every reference *from* a longer-lived structure *into*
> per-function IR must become an owned copy. A copy is cheap and exact:
> `s.substring(0, len(s))` — `hexa_str_substring` allocates a fresh
> buffer (`hexa_strbuf_alloc` + `memcpy`), and `len()` on a string is the
> byte length (`HX_STRLEN`), so the copy is byte-exact incl. UTF-8.
>
> Audited edges (each an independent, byte-identical, parse-gate +
> byte-diff verifiable fix):
>
>   - **P0a** `st.keys ← MFunc operand strings` — CONFIRMED.
>     `_collect_strs_from_stmt` does `keys.push(o.str_val)`, sharing the
>     MFunc's string handle. Fix: push a copy.
>   - **P0b** `LFunc ← st.labels` — CONFIRMED. `_arm64_strtab_lookup`
>     returns `st.labels[i]` by reference; the LFunc operand stores that
>     handle (callers at arm64_darwin.hexa:538/719/852/893). Freeing an
>     LFunc would dangle `st.labels`. Fix: store a copy of the label in
>     the LFunc operand.
>   - **P0c** `MFunc ← HItem/hmodule strings` — CONFIRMED. `_lower_fn`
>     reaches `_const_str_op(e.text)` (hir_to_mir.hexa:542,76) — the MIR
>     `const_str` operand's `str_val` *is* the HIR node's `.text` handle.
>     `hmodule` outlives the loop. Fix: copy at `_const_str_op`.
>   - **P0d** `LFunc ← MFunc strings` — NARROW. `_arm64_op_for_operand_st`
>     routes `const_str` through `_arm64_strtab_lookup` → an `st` label
>     (that is P0b); only the strtab-miss *fallback* `_arm64_op_label(
>     o.str_val)` (arm64_darwin.hexa:540) carries the MFunc string. Since
>     `_arm_strtab_collect_fn` interns every `const_str` before codegen,
>     the miss path should be unreachable — but harden it with a copy.
>   - **P0c-2** `MFunc.name ← HItem.name` — CONFIRMED. `_lower_fn` returns
>     `MFunc { name: it.name, ... }` (hir_to_mir.hexa:1573) — shares the
>     HItem name handle. Fix: copy.
>   - **P0e** non-string sharing — **AUDITED CLEAN.** `_lower_fn` builds
>     `params`/`locals`/`blocks` as fresh arrays from a fresh `LowerCtx`;
>     `_arm64_lower_func` builds `instrs` fresh. Neither takes an
>     array/struct *container* by reference from a longer-lived value.
>     All cross-lifetime sharing is **string-leaf only** — the edges
>     above are the complete set.
>
> **Audit complete.** The escape edges are P0a, P0b, P0c, P0c-2, P0d —
> all string leaves, all found, no arbitrary substructure sharing (P0e).
> Option C is therefore **fully enumerable**: forced-copy these five and
> the per-function IR is provably isolated, so `free_tree` is sound.
>
> **Residency subtlety.** `__hexa_fn_arena_return`'s heapify copies only
> *arena*-resident strings (the `f4b597a7` envelope returns already-heap
> pointers untouched). So whether a given edge is live at runtime depends
> on each string's arena-vs-heap residency at return time — not
> statically decidable. This is why each P0x fix must be a **forced**
> copy (`s.substring(0,len(s))` always allocates): a forced copy is
> residency-independent, so the longer-lived structure owns its strings
> regardless. With the audit complete and the edge set closed, C is the
> low-blast-radius path; A remains the principled end-state.
>
> P0 is needed for **B and C**, not A — A's region model promotes on
> escape automatically. Each P0x lands independently; P0c/P0d must be
> audited before C is declared safe (this is the bulk of C's real cost —
> see Options).

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
  asserts the value is unshared at the drop point.
- *Cost*: low *in blast radius* (one runtime function + two call sites
  in `stream.hexa`) but the **real cost is P0** — the free is sound only
  once every escape edge (P0a–P0d) is disciplined. P0a/P0b are confirmed
  and small; P0c/P0d still need the audit. So C = `free_tree` +
  4 small escape-copy fixes + 2 audits, each independently verifiable.
- *Risk*: medium. Each P0x is byte-identical and byte-diff checkable;
  the residual risk is an *unaudited* escape edge — a missed sharing
  path → use-after-free. The audit (P0c/P0d) is the gating work, not the
  `free_tree` call. Verifiable end-to-end: emitted `.s` byte-diff (drop
  must not change output) + stage-1 RSS probe.

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
