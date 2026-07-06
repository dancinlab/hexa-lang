# round5 R1 (ap) — HX3030 wrong-enum match pattern REJECT

Rust E0308 (rustc_hir_typeck check_pat → demand::eqtype). Extends the r9c
literal-pattern REJECT from scalar literals to enum-path patterns. A `match c { Dir::North -> … }`
where `c: Color` can never match (enum tags are nominal), so the arm is silently
dead — same silent-mismatch bug class as r9c.

## Anchor re-verification (origin/main c92390aa50, spec anchored on stale afd85ea98)

All 5 insertion points re-grepped against current tree; no divergence from spec structure:

| point | spec anchor | actual (c92390aa) |
|---|---|---|
| (a) `_types_enum_registry_has` | ~:1240 before `_types_struct_registry_reset` | inserted before `fn _types_struct_registry_reset` (was :1240) |
| (b) `_emit_hx3030` | after `_emit_hx3026` :2082 | after `_emit_hx3026` (ended :2081) |
| (c) check body | `_check_match` else, after r9c :3825 | after r9c lit block close in `_check_match` (:3773) else-branch |
| (d) catalog DiagSpec | after HX3029 `},` :570 | after HX3029 block close :570 |
| (e) corpus.yml regex | :175 `HX30(1[167]\|2[4-6])` | :175 → `HX30(1[167]\|2[4-6]\|30)` |

## Design

- **Fire condition**: BOTH scrutinee enum (`sh`) AND pattern head (`phead`) resolve
  (after alias substitution) to a REGISTERED enum (`_types_enum_registry_has`), AND `phead != sh`.
- **Scrutinee recovery**: param / module-let carry `named:<Enum>` in the env →
  `_types_struct_name_of(scrut_t.kind)`; block-local `let c: Color` recovered via
  the r5 `{}name` side slot (`_types_env_lookup(env, "{}"+name)`).
- **Conservative under-reject (all SILENT)**: struct-typed scrutinee (`_types_enum_registry_has` fails),
  unknown/cross-module enum head (bind's HX2001 territory), HexaVal/unknown scrutinee,
  guarded (`match_guard`) arm (stays on the r9c discard path). Never over-rejects.
- **Band policy**: real source → build-refusing Error (REJECT, FLIP-3 flagless);
  byte-eq test fixtures (`compiler/test/`, `*_test.hexa`) stay Warning via `_types_strict_for`.

## byteeq neutrality

Diag-only: types erase at MIR, severity never reaches codegen. Real-band Error is
harmless iff HX3030 fires 0 over the corpus — proven by the corpus.yml census grep
lockstep (regex now includes 30). No new emit; gen3≡gen4 fixpoint unaffected (catalog is data).

## Tests (types_test.hexa, (ap))

- `_build_case_hx3030_wrong_enum` — `enum Color{Red,Green}` · `enum Dir{North,South}` ·
  `fn f(c: Color) { match c { Dir::North -> 1, Color::Red -> 2, _ -> 0 } }` → **1 HX3030 Error**
  (Dir arm only). Same-module struct control `fn g(p: Point) { match p { Color::Red -> 1, _ -> 0 } }`
  → 0 (Point not a registered enum → under-reject).
- `_build_case_hx3030_fixture` — same wrong-enum AST on `case_hx3030_test.hexa` → **1 HX3030 Warning**.

## Verification status

- catalog parity: `grep -c 'DiagSpec {'` == `grep -c 'fix_it_kind:'` = **74/74** GREEN.
- NON-CI: `types_test.hexa` runs via **pool bare-run** (mini = git/gh only). PR CI byteeq
  3-target is the byteeq proof; static-types-corpus census (advisory) confirms HX3030 = 0 on corpus.

## Conservative FN (round6 candidates)

- guard-carrier arm silence (intended r9c parity).
- call-RHS scrutinee (`match get() { … }`) fires only if callee fn type is modeled → else unit → silent.
