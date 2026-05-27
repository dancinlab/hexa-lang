# M4-fix — array_free_list re-enable plan (2026-05-10)

> Status: **BLOCKED on A2 landing**. Audit-only; no code changes
> applied this pass. Re-evaluate once A2 (`_splice_imported_items`
> in-place accumulator) lands and reduces array_store churn.

## A2 status check

`git log --oneline | grep -i splice` on `main` returned only
`94e26ead feat(bt 74-D): ssot_mirror multi-line splice fix` —
unrelated to A2. The site `compiler/parse/parser.hexa:1312
_splice_imported_items` still uses the per-item `out.push(...)`
pattern. **A2 NOT landed.** Re-enable deferred per task brief.

## Disable site (current state)

`self/hexa_full.hexa:18021` — `pub let mut array_free_list = []`

- `val_array()` at line 18023: freelist *pop* is fully commented out
  (lines 18024-18033). New slot is unconditionally appended to
  `array_store`.
- `array_decref()` at line 18056: refcount decrement runs, but the
  reclamation push (`array_free_list.push(idx)` when refcount hits 0)
  is commented (lines 18070-18074). Slot stays referenced as a dead
  hole; `array_store` grows monotonically.
- Reset site: `array_free_list = []` at line 18937 (interpreter init).

`self/runtime.c:3247` carries the matching comment: the per-slot
high-water mark for incremental heapify is left stale on decref →
"M4-fix freelist disabled means S won't be reused, so the stale
value is harmless." Re-enabling the freelist forces this comment to
become a live correctness concern (see § Refcount discipline).

## Disable reason (from in-source audit)

Comment block at lines 18060-18068 documents the original failure:

> "rt 32 pushed freed slots onto array_free_list for val_array()
> reuse, but struct fields hold array slot references without
> incrementing refcount. This caused slot aliasing corruption: a
> struct's array field would point to a slot reused by a different
> variable."

Class: silent-corruption (no panic). Surfaced as wrong values, not
exceptions. The comment block at lines 18438-18443 of
`set_struct_field` is the post-mortem fix that would make re-enable
safe — but it is not exhaustive (env_pop_scope, enum payload store,
closure capture also need audit).

## Refcount discipline rules (re-enable invariants)

1. **Every TAG_ARRAY/TAG_STRUCT bind incs refcount; every drop
   decs.** `env_define`, `set_struct_field` (lines 18444-18470 —
   already correct), enum payload write, closure capture, and
   call_stack frame restore must all incref-on-share / decref-on-drop.
2. **Replace-then-decref ordering.** When overwriting a field that
   may equal the new value (e.g. in-place push returns same slot),
   incref new BEFORE decref old (`set_struct_field` lines 18448-18466
   already follows this — model for other sites).
3. **CoW path.** `array_push_inplace` line 18133 and the indexed-set
   path at 18170 must NOT push to `array_free_list` when they decref
   on the COW path; the new `val_array()` reuse via freelist would
   alias the slot the caller just released.
4. **water mark invalidation.** `self/runtime.c:3225 hexa_array_water_set`
   must be reset to 0 when `array_free_list` reuses a slot via
   `val_array()`. Add a `hexa_array_water_reset(idx)` call inside
   the (currently disabled) freelist-pop path.
5. **env_pop_scope decref already correct** (lines 6932-6942) —
   confirmed.

## Audit env design

`__HEXA_ARRAY_FREELIST_AUDIT__=1` environment flag:

- On every Nth decref (N=1024, configurable via
  `__HEXA_ARRAY_FREELIST_AUDIT_PERIOD__`), walk `env_var_vals`,
  `struct_store`, `enum_data_store`, `closure_store`, and the
  `call_stack` frame buffer.
- Recompute live refcount per slot index; assert against
  `array_refcounts[idx]`.
- On mismatch: emit
  `[freelist-audit] slot=N expected=E observed=O` to stderr and
  call `__hexa_panic` (NOT silent — drift is the failure mode the
  freelist disable was guarding against).
- Drop-in site: top of `array_decref` after the refcount
  decrement, gated on `getenv("__HEXA_ARRAY_FREELIST_AUDIT__")`.

## Re-enable steps (when A2 lands)

1. Confirm A2 commit on `main` (`git log --oneline | grep splice`
   shows the `_splice_imported_items` accumulator commit).
2. Add `__HEXA_ARRAY_FREELIST_AUDIT__` audit hook to `array_decref`
   per § Audit env design.
3. Uncomment lines 18024-18033 (val_array freelist pop) and
   18070-18074 (decref freelist push) in `self/hexa_full.hexa`.
4. Add `hexa_array_water_set(idx, 0)` weak-link call into the
   uncommented val_array freelist branch.
5. Rebuild stage0: agent #94 method — clang -O2 on cached
   `/tmp/hexa_full_regen.c` (~90 s).
6. First 10 self-compile runs MUST set `__HEXA_ARRAY_FREELIST_AUDIT__=1`.
7. Run full baseline: `test_enum_payload_full` (15/15),
   `stdlib/test/test_cancel` (23/23), `test_async_codegen` (4/4),
   `compiler/check/{bind,types,resolve}_test`, m0/hello asm
   byte-identical (377 bytes).
8. Probe `compiler/main.hexa --emit=asm`; record peak RSS via
   `/usr/bin/time -l`. Target < 1 GB (stretch); minimum gate is
   strictly less than the post-A2 RSS number.
9. Update `doc/stage1_punch_list_v2.md` table row for M4-fix with
   measurement and audit-clean run count.
10. After 10 audit-clean runs: drop the env var to default-off
    (keep the code path opt-in for future regressions).

## Deferred — block list

- A2 commit on main (parser splice in-place accumulator).
- Audit harness landing (step 2 above) — can pre-land independently
  to de-risk the gate flip.

— Plan author: agent (M4-fix audit), 2026-05-10
