# round7 R2 (au) — HX3033 ident-pair / value-operand compare extension

Branch: `fix/hexa-own-round7-r2-hx3033-identpair` (off origin/main `0657b2204`).
Static-check REJECT-ladder rung. Reuses HX3033 (no new DiagSpec).

## What changed
- **compiler/check/types.hexa ~:3639** — dropped the outer gate
  `if _types_is_enum_path_kind(children[0]) || _types_is_enum_path_kind(children[1])`
  in the unknown-operand `==`/`!=` arm. The inner triad
  (`_types_operand_enum_name` recover on both sides + `_types_enum_registry_has`
  both + `ln != rn`) stays as the real safety gate. Now value-operand pairs
  (ident×ident `c == d`, ident×call) fire when BOTH operands' enum names
  resolve/register/differ. scalar/struct/unregistered/cross-module →
  `""`/registry-filter → silent (unchanged). param×param never reaches this arm
  (both operands infer a known `named:` type → known-both compare arm / HX3001).
- **compiler/diag/catalog.hexa** — HX3033 explain refresh only (drop the
  "at least one operand is an Enum::Variant path literal" precondition). No new
  DiagSpec. Catalog parity unchanged: 77/77 (`DiagSpec {` == `fix_it_kind:`).
- **compiler/check/types_test.hexa** — 4 self-contained (au) builders + cases:
  1. `_build_case_hx3033_ident_pair` — block-local `c:Color == d:Dir` → 1 ERROR;
     same-enum `c == c2` silent (0).
  2. `_build_case_hx3033_param_blocklocal` — param `c:Color` × block-local
     `d:Dir` → 1 ERROR.
  3. `_build_case_hx3033_ident_fixture` — `*_test.hexa` path → 1 WARNING.
  4. `_build_case_hx3033_param_param_control` — ★ param×param → HX3033 × 0
     (HX3001 non-interference control; pins round6 §5.1 "probe unverified").
  - ALSO fixed the truncated `_build_case_let_binop_fixture` (missing 4-line
    tail) + two missing `}` in the (aq)/(ar) fixture-else registration blocks —
    known main breakage that "rides round6-B"; added here so the file parses.
    Converges with B on merge (types-test-hexa-1: reset+reapply, never union).

## Byteeq neutrality
S3 diag-only; types erase at MIR. Severity split (real Error / fixture Warning)
via `_types_strict_for`. Only the emission evidence-gate is loosened; no codegen
path touched. `_types_static_on = true` (flagless FLIP-3) so the block-local
`{}slot` recovery is already live.

## Verify (summer)
- types_test (au): 1/1/1(warn)/0 per contract.
- census GO/NO-GO: real-source HX3033 delta MUST be 0
  (`.github/workflows/static-types-corpus.yml` grep `HX30(...|3[03])`,
  `tool/build_aprime.sh -v build/hexat_linux`). If >0 → NO-GO, drop this rung.
