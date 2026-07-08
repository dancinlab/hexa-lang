# HEXA-OWN L5 — E0382 use-after-move at the 3 NON-CALL move sites (HX3014 reuse)

Status: **LANDED** (opt-in `HEXA_BORROWCK`, default-OFF, byteeq-neutral).
Branch: `feat/borrowck-e0382-noncall`. Verified GREEN on `summer` (pool).

## What
The DUAL of the HX3040/E0505 round. HX3040 flags a move-out of an `@own` param
`a` **while a live loan exists** at the three non-call move sites
(`let b = a` / `b = a` / `return a`). This round records that **same** non-call
move into the move registry so any **later use** of `a` fires the existing
Rule-2 "use after move" (Rust **E0382**). Previously the non-call move was
detected (for the borrow check) but never recorded, so a subsequent use of the
moved-from binding was a silent hole.

## Mechanism — HX3014-reuse (no new catalog code, no new fixpoint)
- Catalog stays **88/88** (`grep -c 'DiagSpec {' == grep -c 'fix_it_kind:' == 88`).
- No new analysis axis: reuses `_bck_note_move` + Rule-2 (intra-block
  `hir_to_mir.hexa:1618` and the M4 NLL cross-block reach-matrix `:1779`) verbatim.
- Wire points (each **inside** the existing `if _bck_is_own_binding(_bck_cur_fn, <name>)`
  gate of the HX3040 non-call move-detect):
  - **return** (`hir_to_mir.hexa` ~:4204): `_bck_note_move(args[0].local_id, "<return move>", ctx2.cur_block, e.span)` (guarded `args[0].kind == "local"`).
  - **let** (~:4685): `_bck_note_move(rhs_op.local_id, "<let move>", ctx2.cur_block, e.span)` + destination detach.
  - **assign** (~:5042): `_bck_note_move(rr.operand.local_id, "<assign move>", ctx2.cur_block, e.span)` + destination detach (guarded `rr.operand.kind == "local"`).

### Design-adaptation notes (reference-match on origin/main)
1. **No by-name resolver needed.** The design proposed `_bck_note_move_by_name`
   on the premise "the gates hold the ident TEXT, not a lowered operand." That is
   stale — the operand IS in scope at every site (`args[0]` at return, `rhs_op`
   at let, `rr.operand` at assign), and all three current blocks are `ctx2.cur_block`.
   So the existing `_bck_note_move(local_id, …)` is reused directly — strictly
   more minimal and more precise (exact local, not a name-scan).
2. **b-alias FP found + fixed (design gap).** Group-granular Rule-2 fires on any
   use of the moved group. After `let b = a` / `b = a`, `b` joins `a`'s group, so
   a later use of the **move-TARGET** `b` (the correct `let b = a; return b`
   idiom) would spuriously fire HX3014 — this **regressed the existing HX3040
   `nc_move` probes**. Fix: under a real `@own` move, **DETACH** the destination
   `b` into a fresh group (`_bck_track(dst.id, name, _bck_new_group())`) — `b` is
   the new sole owner, `a` is dead. Only under `@own` (a real move); a non-`@own`
   handle-copy keeps the group-join so Rule-1 aliasing is intact. This is the
   move-semantics-correct model and removes the FP entirely.
3. **`@own` param source-string works.** The `@own`-param parser carrier is
   landed (the HX3040 `_src_hz_nc_move_*` probes compile `fn f(@own a: [i64])`
   from source), so the E0382 probes are source-string based, not hand-built HIR.

## byteeq-neutral argument
Whole pass gated on `_bck_active` / `HEXA_BORROWCK` (default-OFF): flag-OFF
populates no registry, runs no fixpoint, and every new call is unreachable →
diag stream + `.text` byte-identical → PR-CI byteeq trivially GREEN. Merge on
`selfhost-gates-summary` (pool-light — the whole HX3001~3043 ladder shipped this
way). STRICT (`HEXA_BORROWCK_STRICT=1`) re-bands the same diagnostic to a
build-refusing Error via the caller override (precision unchanged).

## corpus-0
`@own` adoption on the shipping tree is ≈0 → `_bck_own_pnames` stays empty →
`_bck_is_own_binding` is always false → the new calls are never reached on real
source → 0 real fires regardless of the flag.

## Test — `compiler/check/borrowck_test.hexa` (`_run_e0382_probe`, HX3014)
- `hz_e0382_let`  `let b=a; let n=a[0]`      → HX3014 ×1
- `hz_e0382_assign` `let mut b=[0]; b=a; a[0]` → HX3014 ×1
- `fp_e0382_borrow` `let r=&a; a[0]`          → 0 (borrow, not a move)
- `fp_e0382_reassign` `let b=a; a=[9]; a[0]`  → 0 (reassign re-groups → clears)
- `fp_e0382_return_only` `return a`           → 0 (use-before-move, no later use)

## Verify (summer, pool) — captured
```
=== OFF (default) === all E0382 probes ×0 → ALL PASS
=== ON  (HEXA_BORROWCK=1) === hazards ×1, controls ×0 → ALL PASS
=== STRICT (HEXA_BORROWCK_STRICT=1) === hazards ×1 Error-band, controls ×0 → ALL PASS
Existing HX3040 nc_move probes: no stray HX3014 (b-alias detach) → no regression.
Final: "ALL PASS — M3 discriminator + M4 cross-block liveness hold"
```

## Known limitation (opt-in only, corpus-0)
Move tracking is group-granular. The destination-detach fixes the direct
move-target alias. A pre-existing alias created **before** a move
(`let c = a; g(a); c[0]`) still fires on `c` via the group — this is the
existing call-arg Rule-2 behavior (a dangling-alias catch), unchanged by this
round and never reachable on real source (`@own` ≈ 0).
