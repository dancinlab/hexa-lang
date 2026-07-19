<!-- sidecar lab full · model=(default) · cwd=/Users/mini/dancinlab/hexa-lang · prompt=5188 chars · 2026-07-19T02:22:25.312Z -->

── fable (claude-fable-5) · exit 0 ──
All load-bearing facts are now verified. The most important discovery changes the shape of option (A), so let me state it up front and then give the full spec.

# Verdict

**Option (A) as written in the task — lexical live-scope tracking with frame pop — is UNSOUND.** Not because of the lowering side, but because of what `hir_to_mir` actually does at dispatch time: `hir_to_mir.hexa:4431` states "Nothing ever pops `_lr_bindings` (the frame_starts mechanism is unused)", and the ident-callee dispatch at `hir_to_mir.hexa:5382-5399` sends a call through the indirect `hexa_callN` path iff `_mir_lookup` finds *any binding named `len` minted earlier in the current function — including in already-closed sibling blocks*. So `{ let len = 5 } ; len(arr)` is lexically clear (a pop-tracking scope check would stamp i64) but the emitted call is **indirect through the dead slot**, not the builtin. A lexical-pop disqualifier would mis-stamp exactly those sites.

The correct lever — call it **(A′) dispatch-mirror per-site disqualify** — replaces the per-module pin with a disqualifier whose granularity is *exactly* `_mir_lookup`'s: **function-accumulating, order-sensitive, never-popped-within-fn, reset per fn item** (`_lr_ctx_clear` at `hir_to_mir.hexa:4036-4038` allocates fresh `_lr_bindings` per fn, so per-fn reset is the right boundary). This is *simpler* than lexical tracking (a per-slot bool, no sentinel bindings, no pop bookkeeping) and it recovers essentially all of the 2745 sites, including the common `let len = len(arr)` idiom (both passes bind the LHS *after* lowering the RHS — `ast_to_hir.hexa:2586→2596` mirrors hir_to_mir's RHS-then-`_bind` order).

Ranking: **A′ ≫ C (fold in as a rider) > B (dead end)**.

- **(B) is a dead end**, confirmed: `s.len()` field callees are already stamped by round-1 (`ast_to_hir.hexa:2456-2458`, `"len"` is in the method table at :162) and are shadow-immune, but normalizing free→method at lowering time would require the *same* builtin-vs-local decision before re-tagging the callee — it dodges nothing — and rewriting user source is out.
- **(C) composes with A′** as a one-line-per-name table growth (see rider below), not an alternative.

# Implementation spec — A′

All new code gated behind a new sub-flag `HEXA_UNBOX_FREE_SCOPED` (**default-OFF at landing**, read `== "1"`; flip PR later changes to `!= "0"`). When OFF, the existing per-module pin (`_free_disqualified`) stays byte-identical.

## New state + gate (ast_to_hir.hexa, next to `_lr_free_disq` at :244)

```
let mut _lr_free_scoped_on = false        // primed once per lower() — never read env per-binder
let mut _lr_free_mod_item: [bool] = []    // per-table-slot: module ITEM named <slot> exists
let mut _lr_free_fn_seen: [bool] = []     // per-table-slot: binder seen earlier in current fn
```

Prime `_lr_free_scoped_on = env_var("HEXA_UNBOX_FREE_SCOPED") == "1" && _hir_free_calltype_enabled()` in `lower()`'s existing setup block (:3177-3195 region, where the census/injection mode is decided), and clear it at lower() exit alongside `_lr_free_shadow_injected` (:3229). Size both bool arrays to `_lr_free_tbl_size()` there.

## Note sites (the ⊇-of-`_bind` argument)

1. **Choke-point** — inside `_define_in_scope` (:1540), flag-gated: `if _lr_free_scoped_on { let fi = _lr_free_tbl_index(_hir_let_name(name)); if fi >= 0 { _lr_free_fn_seen[fi] = true } }`. This covers every binder form that reaches `sc`: let (:2596), match ident-pattern (:2690) and guard-inner ident (:2634), struct-pattern binders (:2156), closure params (:2874), fn params (:3000), and the for-loop var (For desugars to a `let` at :2823, and the desugar temps `__for_it_N`/`__for_idx_N` are never table names). Use `_hir_let_name` to strip any `mut:` carrier prefix, mirroring hir_to_mir's `_strip_mut_prefix` at :5383.
2. **Enum-payload pattern binders** — the one binder form that never reaches `sc` (the EnumPath lowering arm at :2743-2769 lowers payload idents generically, no define; the destructure binding happens only in hir_to_mir's enum_path arm, and those binders **do** enter `_lr_bindings`, so they affect dispatch). Add a flag-gated `_free_scope_note_pattern(pat)` (mirror the traversal of `_free_census_pattern` :346-381, but only setting `_lr_free_fn_seen` for table names) called at both match-arm pattern paths: before `_lower_pattern_inner` in the guarded arm (:2643) and before `_lower_expr(pat, …)` in the unguarded arm (:2692).
3. **Catch binder** — `ExprKind::Try` carries the catch var in `e.text` (`ast.hexa:95-97`) and has **no dedicated arm** in `_lower_expr` (falls to the generic default arm at :2897). Add a flag-gated note at the top of that default arm: `if _hir_is_try_kind(k) { note e.text }`. This notes slightly *early* (disqualifies the try-body too, whereas hir_to_mir binds the catch var only before the catch body) — over-conservative, sound.
4. **Module items** — in the pre-pass loop (:3141-3172, the `_define_with_def` sites at :3159-3165), note table-named item names into `_lr_free_mod_item`. This mirrors `_mir_lookup_global` (ITEM_LET globals) plus direct-call user fns. (Grep confirms zero `fn len` items exist today, so this array will be all-false in practice — it's the safety rail.)
5. **Per-fn reset** — in `_lower_item`'s fn-item branch (~:2984, right where `fn_sc = _push_frame(module_scope)` happens, *before* the param defines at :3000): zero `_lr_free_fn_seen`. **Do NOT reset at the closure arm** (:2858): hir_to_mir gives lambda bodies fresh bindings (`_lr_ctx_fresh` :4050), so not resetting is over-conservative in both directions (host `len` binding poisons closure-body sites, closure param `len` poisons later host sites) — sound both ways; document it.

## Stamp-site query (the only consumer change)

At :2459-2460, replace `!_free_disqualified(bm_callee.text)` with `!_free_site_disqualified(bm_callee.text)` where:

```
fn _free_site_disqualified(name: string) -> bool {
    if !_lr_free_scoped_on { return _free_disqualified(name) }   // legacy per-module pin
    let fi = _lr_free_tbl_index(name)
    if fi < 0 { return false }
    return _lr_free_mod_item[fi] || _lr_free_fn_seen[fi]
}
```

## Soundness proof

Claim: flag-ON, a stamp at site *s* in fn *F* ⇒ the emitted call at *s* is the direct builtin (returns i64).

1. hir_to_mir dispatches *s* indirect iff `_mir_lookup` or `_mir_lookup_global` hits (`hir_to_mir.hexa:5384-5398`). `_lr_bindings` at that moment contains exactly the binders `_bind`-ed earlier in *F*'s lowering (fresh per fn at :4038, append-only, never popped; `_rebind` renames existing names only, introducing none).
2. The note-set at *s* is a superset of that: every AST binder form hir_to_mir `_bind`s is either `_define_in_scope`-d (hooked at the choke-point) or is an enum-payload/catch binder (noted explicitly at 2/3 above); note **order** matches or precedes bind order (let notes post-RHS in both passes — so `let len = len(arr)` stamps its RHS, correctly; patterns/params note pre-body in both; try notes earlier than bind — conservative). Desugar-minted names are never table names. Module notes ⊇ ITEM_LET globals ∪ fn items.
3. Hence "not disqualified at *s*" ⇒ both lookups miss ⇒ direct dispatch ⇒ `_builtin_runtime_sym("len")` ⇒ builtin ⇒ i64. ∎

And a **machine-checked version of this proof**, which is the real behavioral gate: add an XCHECK-gated assert in hir_to_mir's call arm right after `is_indirect` is decided (:5406): `if is_indirect && callee ident is a table name && e.typ.kind == "i64" → abort with a mis-stamp diagnostic`. An indirect-dispatched `len` call can only carry `typ i64` if the free-stamp fired on it — this oracle catches **every** would-be mis-stamp at compile time, over the entire self-compile. This replaces the #5025 shadow==census equality (which is a per-module-layer oracle and stays valid for the legacy path) as the behavioral proof for the flip; byteeq alone cannot catch it (gen3≡gen4 share contamination). Secondary drift assert under `HEXA_UNBOX_FREE_XCHECK=1` (census is re-primed there, :3194-3195): scoped-disqualified ⇒ `_free_census_member(name)`.

On the task's bind-hook question: don't thread per-site bits from bind(S2) — a span-keyed site map across the `phase_reset("post_check")` boundary is exactly the string-arena hazard #5025 avoided, and lowering owns the scope truth at the moment of the stamp anyway. Keep the #5025 injection unchanged for the legacy path; optionally use `_lr_free_shadow[slot]==false` as a fast-path "stamp without consulting fn_seen" (valid: bind's `_define_mut` is the authoritative binder superset), but it's a micro-opt, not required.

## Expected census delta + gates

- Re-census on summer: `HEXA_UNBOX_FREE_SCOPED=1 HEXA_CALLTYPE_CENSUS=1` self-compile → `ident:len fn-stamped` should jump 0 → **≈2600+/2745**; residue = sites in fns with an earlier `len` binder, try-bodies with catch-var `len`, closure-adjacent cases. Zero movement on all other census counters.
- Fixture suite (compile + census-classify; run where semantics are defined): `let len = len(arr)` (RHS stamped, runs correct); local closure `let len = …; len(1)` (not stamped); sibling-block `{ let len = 5 } len(arr)` (not stamped — documents the pre-existing dead-slot dispatch, census-assert only, no runtime assert); param `len` in one fn + `len(x)` in another (stamped); enum-payload binder `len` (later same-fn call not stamped); catch binder `len` (not stamped inside the try).
- PR-1 lands default-OFF: byteeq 3-target trivially GREEN (all code flag-guarded). PR-2 flips (`== "1"` → `!= "0"`) after: XCHECK dispatch-oracle clean over the full self-compile on summer, fixture suite green, gen3≡gen4 fixpoint with flag ON, byteeq 3-target + shipping smoke GREEN post-flip. `CHANGELOG.jsonl` same-change per the L0 gate.

## Rider (option C folded in)

Grow the three lockstep tables in the same PR — `_lr_free_tbl_index/_size/_name_at` (:265-276), `_bind_free_tbl_index/_size` (`bind.hexa:230-235`), `_hir_builtin_free_ret_prim` (:232) — with `byte_len→i64` (50) and `char_code→i64` (33) **after confirming each against the checker SSOT `check/types.hexa::_types_builtin_free_ret`** (grep: `grep -n "_types_builtin_free_ret" compiler/check/types.hexa`). Exclude `from_char_code` unless the checker says its return is a scalar int — a code→string signature is the likelier reading, and the table rule (:229-231) is checker-signature-confirmed-only.

── sol (gpt-5.6-sol) · exit 0 ──
OpenAI Codex v0.144.1
--------
workdir: /Users/mini/dancinlab/hexa-lang
model: gpt-5.6-sol
provider: openai
approval: never
sandbox: read-only
reasoning effort: none
reasoning summaries: none
session id: 019f7824-f786-7911-9a93-f0be3155138c
--------
user
