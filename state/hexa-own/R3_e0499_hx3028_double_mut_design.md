# R3 — HX3028 E0499 double-mutable-borrow split (HEXA-OWN)

Round-4 dual-lane batch, rung R3. Opt-in borrow checker (`HEXA_BORROWCK=1`) faithfulness
split: rustc reports the *two mutable borrows* case with its own code **E0499**, distinct
from the shared-vs-mutable **E0502**. Before this rung both fired **HX3021** (E0502). This is
a **code-split rung, not a new detection** — the conflict is already detected at the single E3
branch; we only re-code the both-`&mut` subset.

## Anchors (re-verified vs origin/main `55ebb60d7`)

| Spec anchor | Actual | Note |
|---|---|---|
| conflict predicate `_bck_ref_mut[i] \|\| new_is_mut` ~:761 | `compiler/lower/hir_to_mir.hexa:761` | unchanged (still the union conflict test) |
| emit site ~:3143–3150 | `hir_to_mir.hexa:3183–3206` | branch inserted; vars are `_bk_cfi` / `_bk_new_mut` |
| clone source `_bck_emit_borrow_conflict` ~:822–853 | `hir_to_mir.hexa:822–853` | cloned to `_bck_emit_double_mut` at :855–893 |
| catalog insert after HX3026 close ~:532 | `compiler/diag/catalog.hexa:533` (new DiagSpec) | mirrors HX3027 (:489–505) |
| `hz_mut_while_mut` ~:445 | `borrowck_test.hexa:445` | migrated to `_run_double_mut_probe` |
| `fp_reborrow_suppress` ~:627 | `borrowck_test.hexa:627` | expectation migrated |

## Changes

1. **emit-site branch** (`hir_to_mir.hexa:3185–3206`): `if _bck_ref_mut[_bk_cfi] && _bk_new_mut`
   → `_bck_emit_double_mut` (HX3028), `else` → `_bck_emit_borrow_conflict` (HX3021). This is the
   **sole** HX3028 emit site, so the two codes share one same-site dedup array with zero contention.
2. **`_bck_emit_double_mut`** (`hir_to_mir.hexa:855–893`): verbatim clone of `_bck_emit_borrow_conflict`
   — same dedup array (`_bck_e_lines`/`_bck_e_cols`), same args, HX3028, same STRICT re-band.
3. **catalog HX3028 DiagSpec** (`catalog.hexa`): `Severity::Warning` + STRICT escalation note,
   Rust E0499 template `"cannot borrow \`{name}\` as mutable more than once at a time"`, flow-insensitive
   FP class documented — HX3027-spec-shaped.

## Test migration (`borrowck_test.hexa`)

- `hz_mut_while_mut` → **`_run_double_mut_probe`**: `HX3028 ×1`, all other codes `0` (asserts `HX3021=0`).
- `fp_reborrow_suppress` → the re-borrow `let n = &mut x` while `&mut x` live is mut-mut, so it now
  routes to HX3028: **`HX3028 ×1 · HX3021 ×0 · HX3027 ×0`**.
- `hz_shared_while_mut` **unchanged** → stays `HX3021 ×1` (shared-vs-mut is still E0502).
- **§5.4 rider** `hz_compound_assign` (`let m = &mut x; x = x + 1`): pins the faithful dual-fire
  **`HX3023 ×1` (write-through) + `HX3027 ×1` (RHS use)** — distinct spans → both survive dedup;
  Rust is likewise dual (E0506 + E0503). No HX3028 (no second borrow).
- All probes: OFF (`HEXA_BORROWCK` unset) → empty stream; STRICT → error-band == code count.

## Byteeq argument

Every site is gated on `_bck_active` (default OFF). Default build emits nothing new and is
byte-identical. HX3028 is purely a **re-coding** of an existing (already opt-in) HX3021 emission.

## Verification

`borrowck_test.hexa` is **NON-CI** → requires pool 3-mode (OFF/ON/STRICT) bare-run on both backends
(aprime-only = false-green); ambient-env branching means `setenv` inside the harness is inert, so each
mode is a separate process. Gated by the orchestrator before merge.
