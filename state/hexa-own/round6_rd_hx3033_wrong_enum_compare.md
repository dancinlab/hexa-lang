# round6 Rung D (aq) — HX3033 wrong-enum `==`/`!=` compare REJECT

Rust E0308 (rustc_hir_typeck check_expr_binop → op::check_overloaded_binop →
demand::eqtype). The compare-site sibling of HX3030 (wrong-enum MATCH). A
`c == Dir::North` where `c: Color` can never be true (enum tags are nominal), so
the comparison is a silently-dead always-false branch — same silent-mismatch bug
class as HX3030.

## Anchor re-verification (origin/main cc2e19a80)

All insertion points re-grepped against the current tree; no divergence from the
§0 mechanism / named PRECEDENT (HX3030):

| point | spec anchor | actual (cc2e19a80) |
|---|---|---|
| fire site | `_types_check_binop` :3500 compare arm early-return `_types_t_bool()` :3531 | confirmed :3500 / :3531 (inside the `len(lt.kind)==0 \|\| len(rt.kind)==0` unknown-operand arm) |
| helpers | HX3030 `_types_enum_registry_has` / `_types_resolve_alias_name` / `_types_enum_path_head` / `_types_struct_name_of` / `_types_env_lookup` / `_types_is_ident` / `_types_is_enum_path_kind` | all present, reused as-is |
| `_emit_hx3033` | mirror `_emit_hx3030` band policy (:2100) | inserted after `_emit_hx3030` block |
| catalog DiagSpec | after HX3032 `},` (:619) | inserted after HX3032 block (:619) |
| corpus.yml regex | :175 `HX30(1[167]\|2[4-6]\|30)` | → `HX30(1[167]\|2[4-6]\|3[03])` (adds 33) |

## Mechanism (why the fire site is :3531, not the :3608 known-both arm)

An `Enum::Variant` EnumPath operand ALWAYS infers `_types_empty_type()`
(`_types_check_binop` :3243 return). So for `c == Dir::North` the RHS `rt.kind`
is empty → the `len(lt.kind)==0 || len(rt.kind)==0` unknown-operand arm (:3524)
is entered → reaches the compare early-return at :3531. The known-both compare
arm at :3608 is therefore never reached for an enum-path compare. Single fire
site = :3531 (complete).

## Design

- **Fire condition**: op is `==`/`!=` AND at least one operand is an EnumPath
  literal AND BOTH operands resolve (after alias substitution) to a REGISTERED
  enum (`_types_enum_registry_has`) AND the two enum names differ.
- **Operand enum recovery** (`_types_operand_enum_name`): EnumPath operand → its
  head IS the enum (`_types_enum_path_head`); value operand → `named:<Enum>` from
  the already-inferred Type (`lt`/`rt`, params / module-lets), with a block-local
  `let c: Color` recovered via the r5 `{}name` side slot
  (`_types_env_lookup(env, "{}"+name)`). Mirrors HX3030's scrutinee recovery.
- **Conservative under-reject (all SILENT)**: scalar/struct/HexaVal operand,
  unknown/cross-module enum head (bind's HX2001 territory), same-enum compare
  (`c == Color::Red`). Never over-rejects.
- **Band policy**: real source → build-refusing Error (REJECT, FLIP-3 flagless);
  byte-eq test fixtures (`compiler/test/`, `*_test.hexa`) stay Warning via
  `_types_strict_for`.

## byteeq neutrality

Diag-only: types erase at MIR, severity never reaches codegen. No new emit;
catalog is rodata data (gen3≡gen4 fixpoint unaffected). Real-band Error is
harmless iff HX3033 fires 0 over the corpus — the corpus.yml census grep now
includes 33 (advisory census).

## Tests (types_test.hexa, (aq))

- `_build_case_hx3033_wrong_enum_compare` — `enum Color{Red,Green}` ·
  `enum Dir{North,South}` · `fn f(c: Color) { let a = c == Dir::North; let b = c == Color::Red }`
  → **1 HX3033 Error** (the `Dir::North` compare only); `c == Color::Red`
  (same enum) → 0.
- `_build_case_hx3033_fixture` — same wrong-enum compare AST on
  `case_hx3033_test.hexa` → **1 HX3033 Warning** (fixture carve-out).

## Verification status

- HX3033 next-free confirmed (`grep -rn HX3033` = ∅ before this change).
- catalog parity: `grep -c 'DiagSpec {'` == `grep -c 'fix_it_kind:'` = **77/77** GREEN.
- NON-CI: `types_test.hexa` runs via **pool bare-run** (mini = git/gh only). PR CI
  byteeq 3-target is the byteeq proof; static-types-corpus census (advisory)
  confirms HX3033 = 0 on the corpus.

## Conservative FN (future rounds)

- non-enum-path both sides where a var pair `c1 == c2` are two different enums:
  requires both to be inferred non-empty registered enums AND at least one an
  EnumPath — a `c1 == c2` value-pair (no EnumPath) is silent (documented FN).
- call-RHS enum operand (`get() == Dir::North`) fires only if the callee fn type
  is modeled to `named:<Enum>` → else empty → silent.
