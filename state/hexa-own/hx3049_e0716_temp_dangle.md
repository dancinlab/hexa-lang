# HX3049 — E0716 temporary-dropped-while-borrowed (② memory-management lane, round11)

## Verdict
Lane ② borrowck ladder has a **clean low-risk rung** in candidate (a) E0716 — implemented as
HX3049, opt-in `HEXA_BORROWCK`, byteeq-neutral, FP=0 by construction, corpus-0.

## What & why
`r = &make()` / `r = &mut make()` (assign-arm re-borrow of a **call temporary**) into a ref
binding `r` declared in an enclosing scope → the temporary is materialized only for the
enclosing statement and dropped at its end (temporary-scope drop point), so the re-borrow into
the longer-lived `r` dangles. Rust E0716 (`temporary value dropped while borrowed`, rustc_borrowck).

It is the **assign-site sibling of the already-shipped return-site HX3041** (`return &<temp>`,
E0515): both reuse the same syntactic temp classifier (inner HIR node kind) at a different escape
site. It completes the asn-lane, which previously handled only **named** origins (HX3036 E0597
`r = &x`) and had no representation for an unnamed temporary.

## Why NO new dataflow axis was needed (the census question, answered)
- **Full E0716** (temporaries stored into arbitrary places + Rust's temporary-lifetime-extension
  modeling) DOES need a new temp-tracking axis — a temporary has no name and no scope-log entry,
  and the extension rules (which contexts extend, RFC 66) are the FP-hard part.
- But there is a **clean subset that needs NO new axis**: a temporary's lifetime is the STATEMENT,
  strictly shorter than any binding declared before it, so `r = &<temp>` (with `r` a pre-existing
  ref binding) is an **UNCONDITIONAL** dangle at the assign site — emitted inline like HX3041, no
  reach-matrix (unlike the HX3036 named-origin lane, whose origin can share `r`'s scope so it needs
  the round8 forward-reachability event-matrix).

## FP=0 — three independent guards
1. **Assign hook only** → the LET-init form `let r = &make()` (which Rust's temporary-lifetime-
   extension makes VALID) never reaches this branch; it lowers through the let-lane, which only
   tracks `&<ident>` (hir_to_mir.hexa:5076), never a call temp.
2. **`call`-only** → `struct_lit`/`array_lit`/`binop` temporaries are const-promotable in the
   reference model (rvalue static promotion → `'static`), so `r = &(x+1)` / `r = &[1,2]` /
   `r = &P{..}` is NOT E0716 → EXCLUDED, SILENT.
3. **Known-ref gate** (`_bck_find_ref(lhs) >= 0`) → fires only when `r` was declared as `let r = &…`
   earlier, guaranteeing both that `r` is reference-typed and that it outlives the statement.

Report-only (no MIR mutation, no asn-lane row, no `_bck_note_move`). Honesty caveat inherited from
HX3041: classifies per rustc, not proven against hexa's arena free-model.

## Wiring
- `compiler/lower/hir_to_mir.hexa` — `_bck_emit_temp_dangle()` (clone of `_bck_emit_ret_temp`);
  else-arm of the `&`/`&mut` unop branch in the assign hook's asn-lane (beside the HX3036 track).
- `compiler/diag/catalog.hexa` — HX3049 DiagSpec (Warning band; STRICT→Error). Parity 93==93.
  Next-free now HX3050.
- `compiler/check/borrowck_test.hexa` — `_run_temp_dangle_probe` + 6 probes:
  hz_asn_temp_call ×1, hz_asn_temp_call_mut ×1, fp_letinit_temp 0, fp_asn_temp_binop 0,
  fp_asn_temp_struct 0, fp_asn_temp_unknown_ref 0. OFF → all 0 (byteeq proof); STRICT → error-band.

## Verify
- byteeq-neutral: flag-OFF (`_bck_active` default false) → emit path unreached → codegen .text
  byte-identical → PR-CI byteeq is the proof.
- logic: `HEXA_BORROWCK=1 hexa run compiler/check/borrowck_test.hexa` (summer).

## NEXT ② round / depletion
The `call`-temp subset is the ONLY unconditional E0716 form. Remaining E0716 (struct/array/binop
temps behind promotion, temporaries stored into fields/vectors, lifetime-extension contexts) needs
a genuine new temp-materialization + statement-drop-scope axis. Other remaining borrowck E-codes
(E0509 Drop-glue, E0501 closure-borrow-conflict) likewise need new axes. Arena-reclaim is a MEASURED
terminal (do not retry); stack-alloc (#4697) is the sole real arena win and its extension is a
measure-first pool task, report-only until proven. After HX3049 the borrowck lane is at its
low-risk-subset floor — further rungs require new dataflow axes (honest near-depletion).
