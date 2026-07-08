# 2-lane next batch — impl record (feat/types-2lane-next-batch)

Branch off `origin/main` (3a5ea08fb). Worktree `.worktrees/r-2lnext`. Design SSOT:
`scratchpad/twolane_next_batch.md` (BATCH-READY, 3 rungs). Shipped 2 of 3; rung 3 deferred (below).

## Rung 1 — Lane-A: HX3044 fan-out completion (index-place + field-place assign)
`compiler/check/types.hexa` `_infer_expr` Assign arm. HX3044 REUSED verbatim (no new catalog,
parity stays 88/88). Three new emit sites, each AFTER the existing HX3011 block and INSIDE the same
`_types_kind_is_scalar(...) && _types_kind_is_scalar(rhs_t)` guard, independent of the `r3_rejected`
kind gate (int-lit → int-kind is kind-assignable so HX3011 stays silent — exactly the overflow case):
- (E) index-place recorded sub-arm: `_types_int_lit_overflows(elem_t, e.children[1])` → `_emit_hx3044(elem_t, e.children[1].span, out)`
- (E, ARRAY_LOWER fallback): same with `base_t.args[0]`
- (F) field-place branch: same with `field_t`
Reuses `_types_int_lit_overflows` + `_emit_hx3044`. Model = the ident-place block (types.hexa:3320-3334).

## Rung 2 — Lane-B: builtin-method inference parse_int→i64 / parse_float→f64
`compiler/check/types.hexa` `_types_builtin_method_ret`. Two match arms added beside `to_int`/`to_float`:
`"parse_int" -> _types_t_i64()`, `"parse_float" -> _types_t_f64()`. Both selectors were already in
`_is_builtin_method` but fell to `_types_empty_type()` (opaque). Reference-matched: self/codegen.hexa
dispatch parse_int→hexa_str_parse_int / parse_float→hexa_str_parse_float returns bare int/float (NOT
Option) → monomorphic, receiver-independent → sound fixed i64/f64. No catalog, no predicate.

## Tests — compiler/check/types_test.hexa (self-contained balanced blocks, next labels after bn)
- bo hz_i8_index_assign_over `let a:[i8]; a[0]=300` → 1 HX3044 Error, 0 HX3011
- bp fp_i8_index_assign_fit `a[0]=127` → 0 HX3044
- bq hz_i8_field_assign_over `struct S{b:i8}; let s:S; s.b=300` → 1 HX3044 Error, 0 HX3011
- br fp_i8_field_assign_fit `s.b=127` → 0 HX3044
- bs parse_int_infer `n:i64=x.parse_int()`(ok) + `s:string=x.parse_int()`(mismatch) → 1 HX3011
- bt parse_float_infer `g:f64=x.parse_float()`(ok) + `k:i64=x.parse_float()`(mismatch) → 1 HX3011

## Guarantees
- byteeq-neutral: types erase at MIR (both rungs are type-check-pass only). .text byte-identical →
  PR-CI byteeq 3-target is the proof (pool-light: no heavy self-compile needed to merge).
- corpus-0: `git grep ': (i8|i16|i32)\b' -- '*.hexa' ':!*_test.hexa'` = 0 (Lane-A fires 0 real sites,
  ships as Error via FLIP-3 band). All `.parse_(int|float)()` call-sites (24) sink to int/i64/float/f64
  → Lane-B produces 0 new errors on the shipping tree.
- catalog parity 88/88 (no catalog code touched).

## Rung 3 — DEFERRED (borrowck E0382 use-after-move at 3 non-call move sites)
Design framed it as a "pure emit-wire" reusing HX3014 Rule-2 + NLL fixpoint. All infra verified present
(`_bck_note_move`, `_bck_is_own_binding`, `_bck_m_*` registries, gate sites exact at hir_to_mir.hexa
4197/4653/4993). BUT the design's single-"cur_block" assumption is contradicted by the code: the
block-index context variable is NOT uniform across the 3 sites (`ctx2`/`fctx`/`ctx_s`/`ctx_r` appear per
sub-arm), so pinning the correct block at each gate needs careful per-site tracing; a wrong block →
silent under-report (Rule-2 same-block scan misses) or wrong-group resolution. Plus it requires a
separate borrowck_test hand-built-HIR harness (`_run_tp_own_letmove` etc.), a distinct file with its own
MIR-building conventions + a separate pool verify. Value is corpus-0 (@own adoption ≈0 on the shipping
tree → 0 real fires regardless) and byteeq-neutral either way (opt-in `_bck_active` OFF), so deferring
costs nothing on release integrity. Follow-up: trace the exact ctx var at each of the 3 gates, add
`_bck_note_move_by_name` (design body), wire 3 calls, add borrowck_test probes, verify on pool.
