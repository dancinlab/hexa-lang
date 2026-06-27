# RFC — Generic STRUCT monomorphization (opt-in, default-OFF)

> SSOT for the `compiler/optimize/monomorphize.hexa` struct lanes. Companion
> to the function lane (`$$g`). Polarity: native-canonical-default — the
> type-ERASED dynamic path stays the default; monomorphization is an opt-in
> constraint gated by `HEXA_MONOMORPHIZE=1`, and the nested lane is further
> sub-gated by `HEXA_MONO_GENERIC_STRUCT=1`. Byteeq-neutral on all 3 release
> targets (no default lowering emits a `$$gs` marker).

## Reference (read first)

- **rustc** `rustc_monomorphize::collector` — a worklist fixpoint. Each
  fully-substituted distinct `Instance` becomes one mangled `MonoItem`;
  instantiating `Box<Pair<i32>>` transitively enqueues `Pair<i32>` first.
  Dedup is per `Instance`.
- **zig** — comptime-type instantiation: a generic struct is instantiated
  once per distinct comptime type argument.
- **swift** — a specialized metadata record per concrete generic argument.

hexa borrows the *transitive collection* idea (inner instance collected
before the outer consults it) and the *per-Instance mangled symbol* idea,
mapped onto the surviving construct→call MIR form.

## Lane ① — single-level generic struct (`Box<Int>(5)`)  [R1, PR #4058]

A generic struct constructed via the call form `Box<Int>(5)` parses as
`ExprKind::Call` and survives erasure as `STMT_CALL op="Box"`. Marked
templates carry the DISTINCT sentinel `MONO_STRUCT_TEMPLATE_MARK = "$$gs"`
(disjoint from the fn marker `$$g`: a `$$gs` name's last three bytes are
`$gs`, never `$$g`). The pass reuses the proven function-lane machinery —
`_mono_collect_templates` / `_mono_find_template` / `_mono_rewrite_calls` —
to emit `Box$int` / `Box$str`, retarget each construction call, keep `Box`
as the erased-constructor fallback for `dyn` sites, and never leak `$$gs` to
codegen. A mixed fn+struct module co-specializes in one deterministic pass
(beyond-parity vs rustc's two separate collector arms). Unit-tested
`compiler/optimize/monomorphize_struct_test.hexa` (struct lane + control +
mixed).

## Lane ② — NESTED generic struct (`Box(Pair(5,6))`)  [R2, this PR]

The wall: a generic struct whose argument is ANOTHER generic-struct
instance. `Box(Pair(5,6))` lowers to two `STMT_CALL`s in SSA order — the
inner `Pair(5,6)` writes a local, then `Box(<that local>)`. The single-level
`_mono_tag_of` sees the Box call's `arg[0]` as a `local` (not a const),
returns `"dyn"`, and parks the outer construction on the erased path.

The fix is a per-function **producer map** built incrementally inside the
forward statement scan:

- `_mono_int_find(ids, v)` — parallel-array index lookup (mirrors
  `_mono_str_in`), backs the map `prod_ids[i] → prod_names[i]`.
- `_mono_tag_of_n(arg, prod_ids, prod_names)` — sibling of `_mono_tag_of`.
  Const cases are byte-identical; a `local` operand is looked up in the
  producer map and resolves to the inner instance name (e.g. `"Pair$int"`),
  used as the nested type tag.
- `_mono_call_instance_n(s, bases, prod_ids, prod_names, nested)` —
  delegates VERBATIM to `_mono_call_instance` when `!nested` (lane ①
  byte-identical), else infers the nested tag.
- `_mono_scan_wanted` and `_mono_rewrite_calls` thread `nested` and build the
  SAME producer map (same forward order, same gate, keyed by the original
  `dst.id`) so the wanted-set and the retarget agree on every nested tag.

When the inner `Pair(...)` resolves to `Pair$int`, that is recorded against
its `dst.id`; the outer `Box(local)` then resolves to tag `"Pair$int"` and
retargets `Box → Box$Pair$int`. Both `Pair$int` and `Box$Pair$int` land in
`wanted`. Pass-2 longest-prefix base-recovery resolves `Box$Pair$int → Box`
(the prefix `Box$` matches; `Pair$` does not) and `Pair$int → Pair`, so each
instance clones the correct template. Inner-construction-precedes-outer SSA
order is the hexa analog of the rustc collector's transitive enqueue.

### Gating / byteeq

Three independent layers keep DEFAULT output byte-identical:

1. **Pass-level gate** — `compiler/main.hexa` runs the pass only under
   `HEXA_MONOMORPHIZE=1`, which no release/self-host build sets.
2. **Sub-gate** — nested tag inference is read once inside `monomorphize()`
   as `env("HEXA_MONO_GENERIC_STRUCT") == "1"`. Unset → `nested = false` →
   producer maps stay empty, `_mono_tag_of_n`'s local case is never taken →
   bit-identical to lane ①'s single-level `$$g`/`$$gs`.
3. **No runtime/shim bytes** — `monomorphize.hexa` is a compiler-internal
   MIR→MIR pass; `shim.o` (the C-floor runtime substrate) is untouched, so
   its sha is trivially unchanged.

The compiler binary's own bytes change (added pass code), but byteeq is the
`gen3 ≡ gen4` OUTPUT fixpoint, not binary-vs-prior identity; the new code is
deterministic (forward scans, no clock/rng) and self-host never sets either
env, so `gen3 ≡ gen4` is preserved on all 3 targets.

## R3 — honest limitations

- **Copy-through / phi-merged producers.** The producer map records the
  DIRECT construct→call form only. If the inner instance flows through an
  intermediate let-binding or a branch-merge (phi) before reaching the outer
  call, the operand resolves to an unmapped local and falls back to `"dyn"`
  (erased path). Closing this needs producer propagation across copies / a
  phi join — a follow-on round.
- **No real per-T struct layout.** Structs are erased before MIR
  (`lower_hir` lowers `ITEM_FN` only, `_type_id_of = 0` for all structs,
  `struct_lit` drops the name, `MModule` has no struct table). The lanes
  land the pass CAPABILITY + tests on the surviving call-construction form;
  a typed producer (synthetic constructor MFunc — R2a — or a typed-layout IR
  — R2b, full rustc per-T layout parity) is the unresolved wall.

## Verification

- Local unit test: `compiler/optimize/monomorphize_struct_test.hexa` — lane
  ① (struct/control/mixed) PLUS lane ② nested (sub-gate UNSET inert + SET
  retargets `Box → Box$Pair$int`). Function-lane regression
  `monomorphize_test.hexa` unchanged.
- CI (pool/Blacksmith, NOT mini): byteeq 3-target DEFAULT byte-identity +
  `HEXA_MONOMORPHIZE=1 HEXA_MONO_GENERIC_STRUCT=1` nested-emit assertion +
  fn/struct-lane regression. Merge only on CI green.
