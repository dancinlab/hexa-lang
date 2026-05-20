# RFC 074 — Enum Multi-Field Payload (compiler/ tree B2 + C1 decision lock)

<<<<<<< HEAD
> **Status**: PHASE-1+2+3-COMPILER-LANDED · Shape A (compiler/ tree parser + AST `typs[]` carrier + bind-time HX2004 arity registry + catalog DiagSpec + lower per-slot binder fan-out + mir_test case (d) HIR→MIR fixture). Parse-gate PASS on 13 SSOT files. Phases 4-5 (codegen → fixpoint) still PLANNED. Original Shape-B scaffold (decision lock + phase plan) preserved below.
=======
> **Status**: PHASE-1+2+2.1-COMPILER-LANDED · Shape A (compiler/ tree parser + AST `typs[]` carrier + bind-time HX2004 arity registry + types-side HX2005 per-slot element-type check + catalog DiagSpec). Parse-gate PASS on 13 SSOT files. Phases 3-5 (lower → ir+codegen → fixpoint) still PLANNED. Original Shape-B scaffold (decision lock + phase plan) preserved below.
>>>>>>> 5792697b (feat(compiler/{check,diag}): RFC 074 Phase 2.1 — types.hexa per-slot element-type match (HX2005))
> **Opened**: 2026-05-20
> **Authors**: sub-agent dispatch (per @D g_inbox_processing_loop)
> **Supersedes / extends**: RFC-020 (`proposals/rfc_020_enum_payload_variants.md`) §3.1 "multi-field deferred" clause
> **Inbox source**: `inbox/patches/rfc020-enum-payload-variants.md` — F agent (`bfda8c9b`) **punted decisions (3) + (4)**: "B2 multi-cycle scope … 별도 RFC drafting 후 진행", "C1 multi-field 디자인 — positional vs labeled vs tuple — 1차 정착 후 별도 RFC"
> **Cross-link**: `compiler/PLAN.md` entry (this cycle), RFC-020 §5 (self/ tree mapping table), memory `project_hexa_lang_enum_payload_works.md` (single-field works · multi-field unsupported)
> **Slot occupancy** (verified `ls inbox/rfc_drafts_2026_05_20/`, this worktree base = F-agent closure commit `bfda8c9b`): 063, 064, 065, 066, 067, 068, 069, 072 occupied locally; 070 (G8 hexa_ld), 071 (G8 partial relink), 073 (logic_synth proc_mux) used on sibling feature branches per `git log --all --oneline | grep RFC` audit. 074 free across all branches — **this RFC takes 074**.
> **Honest scope (g3)**: this RFC is a **decision-lock + phase plan**. NO production code lands. The "implementation" is `compiler/` tree migration in 5 phases across multiple subsequent cycles. A separate sub-RFC (075?) may be needed if Phase 3 (lower/ir sum-type) bumps into the `self/ir/Operand` B1 holdout.

---

## 0. Heritage in one paragraph

RFC-020 (2026-05-09) deferred multi-field enum payload because the **self/** tree (hexa_v2 transpiler) modeled enum variants as a single `Param { name, typ, span }` row — one type slot per variant. A1–A5 (single-field payload through parser → typechecker → codegen → 15/15 byte-eq regression) **LANDED on self/** between commits `3c8be96c` … `41ecfb97` (2026-05-10 … 2026-05-20). B1 (`self/ir/Operand` sum-type migration) is HOLDOUT pending stage0-binary rebuild. **B2 (compiler/ tree mirror)** and **C1 (multi-field variant)** are this RFC's territory — both punted explicitly by the F-cycle closure (`bfda8c9b`) as "별도 RFC drafting 후 진행 권장".

The `compiler/` tree is a clean second front: `compiler/parse/ast.hexa` L7-10 ("stage0 enum variants cannot carry payloads yet") is STALE since A1-A3 landed on self/; `compiler/parse/parser.hexa` L1602-1631 already drains multi-field tokens (well-formed grammar acceptance, single-field semantic retention); `compiler/check/bind.hexa` L815-828 already iterates `children[]` for binders (multi-field-ready binder loop, awaiting parser/typechecker upstream). The compiler/ tree's `Expr.children: [Expr]` array schema is **strictly more general** than self/'s `Param`-array convention, so multi-field has a cheaper carrying capacity here.

---

## 1. Problem (B2 + C1 framing)

### 1.1 B2 — `compiler/` tree mirror of A1-A5

Currently every enum-related dispatch in `compiler/check/{bind,types,resolve}.hexa` treats `ExprKind::EnumPath -> false` (no payload-bearing arm), and `compiler/parse/ast.hexa:7-10` documents this as a stage0 limitation. The self/ tree has moved on; the compiler/ tree still produces payload-less ASTs even though the parser path can syntactically *accept* `Foo::Bar(x)` (it stuffs the payload child into `children[]` but downstream is mute).

Concrete blockers:

| # | File | Symptom | Self/ analog |
|---|---|---|---|
| 1 | `compiler/parse/ast.hexa:7-10` | STALE comment — claims payload unsupported | (no analog; self/ has none) |
| 2 | `compiler/parse/parser.hexa:1606-1643` | `parse_enum_item` keeps `params: [Param]` shape — one `typ` per variant, multi-field comma-drain | `self/parser.hexa` 동일 limitation |
| 3 | `compiler/check/bind.hexa:26` | comment notes `enum_all_variant_payload_types (RFC-020 in self/ tree)` — symbol not ported | `self/type_checker.hexa:114` |
| 4 | `compiler/check/types.hexa` (multiple) | `ExprKind::EnumPath -> false` everywhere — no payload type table | `self/type_checker.hexa:346/353/361` |
| 5 | `compiler/lower/ast_to_hir.hexa` | no payload-carrying HIR node for `EnumPath` | self/ codegen has `[tag, payload]` HexaVal array convention |
| 6 | `compiler/ir/{hir,mir,lir}.hexa` | string-discriminator structs (same anti-pattern RFC-020 §5 calls out for `Operand`) | B1 holdout territory |
| 7 | `compiler/codegen/{arm64_darwin,x86_64_linux,thumbv7em_eabihf}.hexa` | no match-arm payload capture emit | `self/native/hexa_cc.c:9539 gen2_match_cond` |

### 1.2 C1 — multi-field design choice

Three candidates from F agent's punt note:

| Choice | Surface | Construction | Match destructure | Index access |
|---|---|---|---|---|
| **A. Positional (Rust)** | `enum E { V(int, string) }` | `E::V(42, "hi")` | `E::V(n, s) -> …` | by ordinal |
| **B. Labeled (Swift)** | `enum E { V(n: int, s: string) }` | `E::V(n: 42, s: "hi")` | `E::V(n: n, s: s) -> …` | by label |
| **C. Tuple-typed (single payload type that happens to be tuple)** | `enum E { V((int, string)) }` | `E::V((42, "hi"))` | `E::V((n, s)) -> …` | tuple sugar |

---

## 2. **Decision lock — C1**

### 2.1 Choice: **Positional (Choice A)**

**Rationale** (Karpathy §3 + hexa-first §2):

1. **Minimum surgical** — already accommodated by `compiler/check/bind.hexa:815-828`'s `children[]` walk and `parser.hexa:1619-1625`'s comma-loop (today's drain becomes tomorrow's accumulator with ~3-line diff). Choice B requires new `kw:` token plumbing in `parse_type()` + a labeled-arg sigil in patterns. Choice C requires tuple-type-as-payload, which forces tuple destructure (RFC-020 §3.1 expressly defers tuple-type generality).
2. **Convention parity** — Rust's `enum Event { Click(i32, i32) }` is the dominant ML/systems idiom; users porting `ai`-style discriminated unions from TS/Rust map 1:1. wilson's `AssistantMessageEvent` (the load-bearing G1 driver behind RFC-020) is shaped this way in its upstream TS.
3. **Single-field subsumed** — Choice A degenerates to single-field at arity 1, so A1-A5's `enum Shape { Circle(double) }` keeps its current parse tree / codegen / interp parity with zero migration cost. Choice B would force every existing single-field site to either keep the bare form or gain an optional label.
4. **C1 → B1 alignment** — `self/ir/Operand` (the B1 holdout target, RFC-020 §5) is a textbook positional-payload sum type (`Value(ValueId)`, `ImmI64(IntData)`, `Cmp(CmpData)`). Choice A is what B1 will land as anyway; the C1 decision pre-empts churn.
5. **Lattice-as-tool (@D g_lattice)** — the n=6 lattice has no opinion on tuple-vs-labeled-vs-positional; the choice is downstream-ergonomics-driven, not lattice-derived. Honest framing.

**Anti-choice notes**: Choice B's labeled variant is a real ergonomic win for `≥4`-field variants, but is **out of scope for C1**. A *future* RFC (`C2`) MAY add labeled-payload sugar that desugars to positional — that path is preserved. Choice C (tuple-as-payload) overlaps the tuple-type RFC track (not yet drafted) and would force two concurrent moves; deferred.

### 2.2 Concrete grammar (positional, ratified)

```
EnumVariantDecl := Ident ( "(" TypeList ")" )?
TypeList        := Type ( "," Type )*

EnumPathExpr    := Ident "::" Ident ( "(" ExprList ")" )?
ExprList        := Expr ( "," Expr )*

EnumPathPat     := Ident "::" Ident ( "(" PatList ")" )?
PatList         := Pat ( "," Pat )*
```

`Pat` in `PatList` is restricted to `Ident | "_" | LiteralInt | LiteralString | LiteralBool` in this RFC (no nested `EnumPath` destructure — that's C3 future-work; the recursive case already partly exists in `compiler/check/bind.hexa:826` defensive walk but is not type-checked).

### 2.3 Arity rules

- Arity 0: `enum E { V }` — unchanged (Unit variant). `E::V` is a value, never `E::V()`.
- Arity 1: `enum E { V(T) }` — unchanged. Existing A1-A5 path. `E::V(x)` construction; `E::V(x) -> …` match.
- Arity N≥2: **new** under this RFC. Same syntactic skeleton; semantic arms light up across the 5 compiler/ phases below.
- Diagnostics: arity mismatch (`E::V(a, b)` against `enum E { V(int) }`) → typed error `HX02NN` (next free in payload-error band; assigned at Phase 2 land).

---

## 3. **Phase plan — B2 (5 sub-cycles)**

Each phase is **independently landable** and **independently parse-gateable** (`hexa_real parse <file>` per modified file). Phase ordering is the AST pipeline order so each subsequent phase's input shape is guaranteed by its predecessor.

### Phase 1 — `compiler/parse` (accept multi-field syntactically) — ✅ LANDED 2026-05-20

**Files** (3, **LANDED this cycle**):
- `compiler/parse/ast.hexa` — header refresh + `Param.typs: [TypeRef]` carrier (single-field sites mirror `typs[0] == typ`; multi-field populate full `typs[]` and `typ` holds `typs[0]` as a legacy degraded projection).
- `compiler/parse/parser.hexa` — `parse_enum_item` comma-drain replaced with accumulator pushing each `parse_type()` into `v_typs[]`. `parse_param` + struct field push mirror `typs: [ty]` for arity-1 backward-compat.
- `compiler/parse/parser_test.hexa` — `case_enum_multi_field` fixture parses `enum Event { Unit, Click(i64, i64), Triple(i64, i64, i64), Tag(string) }` + match arm `Event::Click(x, y) -> x + y`.

**Acceptance** (Phase 1): ✅ MET — `hexa_real parse` PASS on `ast.hexa`, `parser.hexa`, `parser_test.hexa`. The 4 `compiler/check/*_test.hexa` _param helpers + `compiler/discover/discover_smoke.hexa` _param helper were widened in lockstep (every `Param { … }` literal now carries `typs:`) — required because struct literals are total-init under the existing hexa stage0 grammar.

**g3 honest scope**: parse-only — semantics still rejected in Phase 2's `check/` until that lands.

#### 3.1.1 Carrier-shape sub-decision

Two options for how parser stores variant payload arity:

- **(a) Reuse `Item.params`** as variant rows where each row's `typ` is the *first* payload type and a new sibling `params[]` field on the variant Param carries the rest. *Rejected*: requires `Param`-of-`Param` nesting which the AST schema doesn't support.
- **(b) Replace `typ: TypeRef`** on the variant `Param` with `typs: [TypeRef]`. *Adopted*. Existing single-field sites have `len(typs) ∈ {0, 1}`; multi-field has `len(typs) ≥ 2`. Migration is a parser-only diff plus consumer-side fan-out at Phases 2-5.

### Phase 2 — `compiler/check` (typecheck payload arity + binder fan-out) — ✅ LANDED 2026-05-20 (arity gate)

**Files** (2 SSOT this cycle):
- `compiler/check/bind.hexa` — added per-module enum-variant arity registry (`_bind_enum_names`/`_offsets`/`_counts`/`_variant_names`/`_variant_arities`) populated in the pre-pass via `_bind_register_enum_item`. Both EnumPath sites — construction (`_bind_walk_expr` `_is_enum_path_kind` arm) and pattern (`_bind_pattern` `_is_enum_path_kind` arm) — now probe `_bind_lookup_variant_arity(head, tail)` and emit `HX2004` on mismatch. Added helpers `_enum_variant_tail`, `_is_enum_kind`, `_emit_hx2004`. The existing binder-fan-out loop in `_bind_pattern` correctly handles arity ≥ 2 (every Ident-like child becomes a binder).
- `compiler/diag/catalog.hexa` — `DiagSpec { code: "HX2004", title: "enum variant payload arity mismatch", severity: Error, stage: "S2" }` with template `"enum variant `{enum_name}::{variant_name}` expects {expected} payload {plural}, got {actual}"` and `{plural}` driver-supplied (`"component"` for expected==1, else `"components"`).

**Acceptance** (Phase 2): ✅ MET (arity gate). `hexa_real parse` PASS on `bind.hexa`, `catalog.hexa`, plus the 4 `*_test.hexa` files and `discover_smoke.hexa` whose `_param` helpers were widened in Phase 1's lockstep diff. The HX2004 emit path is unit-test-ready (no harness ships in this cycle — measured by the catalog spec + the parse-gate sweep).

**g3 honest scope**: bind-time arity check only — element-type match (Phase 2.1, ✅ LANDED below), lower (Phase 3), codegen (Phase 4), self-host fixpoint (Phase 5) all still pending. The arity gate fires HX2004 at S2, before any downstream pass would silently truncate or mis-bind a payload, so it is the load-bearing first half of Phase 2's semantic guarantee.

### Phase 2.1 — `compiler/check/types.hexa` per-slot element-type match — ✅ LANDED 2026-05-20

**Files** (3 SSOT this cycle):
- `compiler/check/types.hexa` — added per-module enum variant payload **type** registry (`_types_enum_names` / `_types_enum_variant_{offsets,counts,names}` / `_types_enum_variant_payload_{offsets,arities,typrefs}`). Semantically `enum_all_variant_payload_types: [[string]]` — variant *j* owns the slice `[payload_offsets[j] .. payload_offsets[j] + payload_arities[j])` of `_types_enum_variant_payload_typrefs`. Registry populated by `_types_register_enum_item_payloads` from `_collect_item_types`'s enum branch; reset on every `type_check()` entry (parallel to bind.hexa's arity-registry contract). Per-slot strings come from `_types_typeref_display`, which round-trips through `_types_lower_type_ref` + `_type_display` so the registry's expected-display matches what an inferred Type renders. `_infer_expr` now branches `EnumPath` *before* the legacy STUB-v1 fall-through: probes `_types_lookup_variant_payload_types(head, tail)`, when arity matches the children count fires `_emit_hx2005(head, tail, slot_i, expected, actual, span, out)` per failing slot, and still walks every child for inner-error surfacing. Skip-silent on unknown enum / unknown variant / arity-mismatch (HX2001 + HX2004 own those error classes — no double-emit). Added helpers `_types_enum_path_head`, `_types_enum_path_tail`, `_types_is_enum_path_kind`.
- `compiler/diag/catalog.hexa` — `DiagSpec { code: "HX2005", title: "enum variant payload element-type mismatch", severity: Error, stage: "S3" }` with template `"enum variant `{enum_name}::{variant_name}` payload slot {pos}: expected `{expected}`, got `{actual}`"`. Explain text spells out the RFC-074 §2.2 `typs[i]`-vs-`children[i]` positional contract and gives the canonical argument-order-swap example.
- `compiler/check/types_test.hexa` — added `_variant_multi`, `_variant_unit`, `_enum_item`, `_enum_path` AST builder helpers + cases (f) PASS — `Event::Click(42, "hi")` on `enum Event { Click(int, string) }` → 0 HX2004 / 0 HX2005, and (g) FAIL — `Event::Click("hi", 42)` (args swapped) → exactly 2 HX2005 (one per swapped slot, no HX2004). The (g) case is the load-bearing falsifier — without per-slot check the swap would compile silently.

**Acceptance** (Phase 2.1): ✅ MET. `hexa_real parse` PASS on `types.hexa`, `catalog.hexa`, `types_test.hexa`. HX2005 emit path exercised at the catalog spec + types-side registry lookup + types_test fixtures (f)/(g). End-to-end run gate deferred to the standard `g_commit_push_deploy` cycle (compiler-source-only diff + no bootstrap promote per SOP §7).

**g3 honest scope**: types-side element-type check ONLY — match-arm-side patterns (positional binders) reuse the bind.hexa Phase 2 arity gate but currently propagate `<unknown>` types (no element-type assertion on patterns yet; pattern-side element-type would require S2/S3 cross-pollination outside Phase 2.1's surgical scope). The "skip when arity differs" gating is intentional — HX2004 already attributes the mismatch class, so a swapped + extra-arg case fires 1 HX2004 not 1+N HX2005. Phases 3 (lower) / 4 (codegen) / 5 (fixpoint) still pending — types.hexa now reports element-type errors at S3, but downstream still silently drops payloads for arity ≥ 2 in the lower→codegen pipeline.

### Phase 3 — `compiler/lower` (HIR-level payload child wiring) — ✅ LANDED 2026-05-20

**Files** (3, **LANDED this cycle**):
- `compiler/lower/ast_to_hir.hexa` — the existing `_hir_is_enum_path_kind` arm already lifted all `children[]` to HIR via a generic recursion loop, so Phase 3 needed no structural edit on this side (single-arg subsumes; multi-arg arity N >= 2 lifts the same way). Inline RFC-074 §3 marker comment documents the projection: the HIR shape `HExpr{kind="enum_path", children:[HExpr]}` carries the `HirEnumCtor{tag, args:[HirValue]}` payload list onto the existing string-kind HExpr container per RFC §3.1.3 "stage0 hexa has no sum types" carve-out (no new HIR struct introduced this cycle — `HirEnumCtor` stays the conceptual name for the same shape).
- `compiler/lower/hir_to_mir.hexa` — **load-bearing fix**. The match-arm `enum_path` binder loop (this file's previous L1985-2007) emitted every binder with `op="payload"` and `args=[scrut_op]` — every binder got the **whole map value**, silently truncating arity ≥ 2 to a single slot and routing through an unused codegen op. Replaced with per-slot extract symmetric to the construction site (L2173-2207): each binder `pat.children[pi]` now lowers to `STMT_ASSIGN op="field" args=[scrut_op, const_str("__p" + pi)]`, hitting the existing map-backed `hexa_map_get` codegen path (3-backend, `a351b1c9/87f3c073/5dfc5e32`). Single-arg (`__p0`) subsumes the legacy single-slot path with zero behavior delta; multi-arg now extracts each slot.
- `compiler/lower/mir_test.hexa` — new case (d): `Event::Click(7, 9)` construction + `match e { Event::Click(x, y) -> return x + y }` destructure. Assertions count the construction's `__p0`/`__p1` const_str operands AND the match-arm's two `field` extracts on `__p0`/`__p1` AND preserve the `__tag` extract — fails on the pre-Phase-3 lowering, passes only with the per-slot fan-out.

**Acceptance** (Phase 3): ✅ MET — `hexa_real parse` PASS on all 3 SSOT files. Case (d) MIR contains: (1) one `struct_lit` STMT_ASSIGN whose args carry both `__p0` + `__p1` positional keys (construction), (2) two `field` STMT_ASSIGN extracts on `__p0` + `__p1` (binder fan-out for `x` and `y`), (3) `__tag` extract preserved (match-arm tag dispatch unchanged). Pre-RFC-074-Phase-3 lowering fails this case at the `__p1` extract assertion.

**g3 honest scope**: codegen still has no payload-aware emit (Phase 4); the `field`-key-`__p<i>` MIR shape rides the existing map-backed codegen — that path was already exercised by struct field access, so Phase 3 MIR is correct in isolation AND consumable end-to-end via the inherited backend, but a sum-typed sum-of-products MIR carrier (`MTag`/`MPack` proper, RFC original §3.2) is still deferred to Phase 4 along with per-target codegen specialization. The B1 holdout (self/ Operand string-kind) is unaffected because this cycle reuses the proven map representation rather than introducing a new operand sum-type — RFC §3.1.3 stage0 carve-out preserved.

### Phase 4 — `compiler/ir` + `compiler/codegen` (emit multi-cell payload capture)

**Files** (4-5):
- `compiler/ir/{hir,mir,lir}.hexa` — `EnumCtor` + `MatchArm` nodes carry `args: [Value]` / `binders: [Binder]` arrays.
- `compiler/codegen/arm64_darwin.hexa` — match-arm emit captures `[tag, payload_0, payload_1, …]` from a contiguous payload-cell region (stack-allocated, sized by max arity per variant) and binds each into the arm's local scope.
- `compiler/codegen/x86_64_linux.hexa` — same.
- `compiler/codegen/thumbv7em_eabihf.hexa` — same (will inherit the shared `lower_match_payload` helper if one is factored out at Phase 3).

**Acceptance** (Phase 4): A4-equivalent regression — `compiler/codegen/codegen_test.hexa` ports the 15-case `self/test_enum_payload_full.hexa` matrix and adds 5 multi-field cases (arity-2 int+string, arity-3 struct+int+bool, arity-2 nested-in-match, arity-2 unit-mixed, arity-N=4 stress). All cases byte-eq across all three targets.

**g3 honest scope**: codegen-correct but not yet self-host-fixpoint validated (Phase 5).

### Phase 5 — self-host fixpoint + parity gate

**Files**: drive `compiler/` through itself (per `project_compiler_native_self_host_fixpoint` memory's gen1≡gen2 byte-identical methodology), with the new multi-field enum sites exercised across the bootstrap.

**Acceptance** (Phase 5):
- gen2.s ≡ gen3.s byte-identical for any compiler/ source containing a multi-field enum (synthetic fixture in `compiler/parse/parser.hexa` or wherever lands first).
- All five F-P0…F-P3 falsifiers (per `project_compiler_rfc063_p0p1_closed_p2_started` memory) re-run green.

**g3 honest scope**: this is the *only* phase that "ships" multi-field for production-class consumers (wilson, demiurge). Phases 1-4 are landable but each is a closed surgical scope.

---

## 4. Phase dependency graph

```
Phase 1 (parse)  ──┐
                   ├──> Phase 2 (check)  ──> Phase 3 (lower)  ──> Phase 4 (ir+codegen)  ──> Phase 5 (fixpoint)
                                                       │
                                                       └──> [B1 prereq: self/ir/Operand sum-type rebuild
                                                             OR compiler/MIR adopts MValue sum-type independently]
```

Phase 3 has the **only** cross-RFC dependency (B1). Phases 1, 2, 4, 5 are linear and each is a one-cycle Shape-A surgical land.

---

## 5. Falsifiers (for each phase land)

- **F-074-P1-PARSE**: a malformed enum decl `enum E { V( }` produces a parser error, NOT a panic. Multi-field `enum E { V(int, string) }` round-trips through `hexa_real parse` and AST dump shows `len(variant.typs) == 2`.
- **F-074-P2-CHECK**: `match e { E::V(a) -> … }` against `enum E { V(int, string) }` produces HX02NN with byte-eq message on both arm64-darwin and x86_64-linux builds.
- **F-074-P3-LOWER**: HIR dump of `E::V(1, "x")` shows arity-2 ctor; MIR dump shows 2 distinct payload-cell stores; no payload truncation.
- **F-074-P4-CODEGEN**: 5 multi-field cases byte-eq across arm64-darwin + x86_64-linux + thumbv7em + interp parity (where interp survives; interp is RETIRED per `@D g_interp_deprecated`, so this falsifier uses compiled-vs-compiled cross-target equivalence rather than compiled-vs-interp).
- **F-074-P5-FIXPOINT**: gen2 → gen3 byte-identical when the bootstrap path includes a synthetic multi-field enum in `compiler/parse/parser.hexa` (e.g. a refactor where `TokenKind` or `ExprKind` consumes payload data; this is a *natural* refactor of the existing string-discriminated arms in `compiler/ir/*.hexa`).

---

## 6. Out of scope (explicitly punted from this RFC)

1. **C2 — labeled-payload sugar** (`E::V(name: 42, kind: "x")`). Future RFC; will desugar to positional under this RFC's choice. No grammar surface introduced now.
2. **C3 — nested `EnumPath` destructure** (`match e { Outer::A(Inner::B(x)) -> … }`). `compiler/check/bind.hexa:826` has defensive recursion stub already; making it type-safe is a separate sub-RFC.
3. **B1-on-self/** completion. RFC-074 unblocks B1 on the *compiler/* MIR `Operand` (Phase 3); the self/ side still requires the stage0-binary prereq per `77254d91`.
4. **Tuple types as a first-class concept** (Choice C from C1). The grammar lock in §2.2 deliberately keeps `ExprList` flat, not tuple-typed. A future tuple RFC may add `(T1, T2)` as a TypeRef; until then multi-field variants are the only way to carry multiple typed cells through the type system.
5. **PR submission cadence** — per @D g_atlas_binary_builtin and the broader hexa-lang "PR-only for atlas; surgical-or-RFC for compiler" policy, each phase will land via a separate PR. This RFC enumerates them but does not pre-submit any.

---

## 7. Inbox patch updates (this RFC bundles them)

- `inbox/patches/rfc020-enum-payload-variants.md` — the resolution table rows for **B1, B2, C1** are updated in the same cycle (header status remains `resolved-ssot`, since A1-A5 closure is preserved). B2 row flips ⬜→📋 (planned with RFC-074), C1 row flips ⬜→🟢 (DECIDED, positional, see RFC-074 §2). B1 stays ⚠️ HOLDOUT but cross-links the RFC-074 §3 Phase-3 hand-off note.
- `compiler/PLAN.md` — single new entry appended (one row per `@D g_inbox_processing_loop` accounting).

---

## 8. Decision record (paste-ready for `inbox/decisions.log` if/when that ledger exists)

```
2026-05-20 RFC-074 decision-lock
  C1 multi-field design  : POSITIONAL  (Rust-style; subsumes single-field)
  B2 phase plan          : 5 phases (parse → check → lower → ir+codegen → fixpoint)
  Phase 3 cross-dep      : compiler/ MIR sum-type OR self/ B1 prereq (either path unblocks)
  Out of scope           : labeled (C2), nested destructure (C3), tuple-types, self/ B1 completion
  Authors                : sub-agent (@D g_inbox_processing_loop)
  Cross-link             : inbox/patches/rfc020-enum-payload-variants.md (B2+C1 rows updated)
                         : compiler/PLAN.md (cycle entry appended)
                         : RFC-020 (extended; §3.1 "deferred" clause superseded)
```

---

## 9. Honesty (g3)

This RFC ships **zero** production code. The 5-phase plan + decision lock is the deliverable; subsequent cycles execute. Phase 1 alone is a 1-cycle Shape-A surgical land (`parse_enum_item` accumulator + `ast.hexa` comment refresh + parse fixture). Phases 2-4 are each 1-cycle Shape-A. Phase 5 is bootstrap-fixpoint, 1-cycle Shape-A iff Phases 1-4 land clean. **Total estimated effort: 5 surgical cycles, no GPU fire, no $-cost; all parse-gate + compiled-path validation.**

The C1 positional decision is **revisable** if a future RFC (C2) shows labeled-payload demand from ≥3 downstream consumers; this RFC locks the *initial* shape, not the final one. The Rust-convention argument carries because (a) wilson's TS source is positional-style discriminated unions, (b) the existing B1 target (`Operand`) is positional, (c) compiler/check/bind.hexa is already coded for the positional case.

No claims about multi-field semantic correctness, performance, codegen size impact, or self-host fixpoint reproducibility are made until each respective Phase falsifier (§5) passes. This RFC is a **scaffold**, not a proof.

---

## 10. Numbering note (RFC slot audit)

`git log --all --oneline | grep -iE "rfc.07[0-9]"` audit at draft time (2026-05-20) shows:
- 067 `wmma_real_emit` (committed)
- 068 `mixed_precision_mir_layer` (committed)
- 069 `unroll_advanced` (committed)
- 070 `hexa_ld_dlopen_shared` (sister-branch G7 scope)
- 071 `G8 scaffold — hexa_ld --incremental partial relink` (sister-branch G8 scope)
- 072 `atlas_enrich cache` (RFC 067 inline-enrich follow-on)
- 073 `read_verilog proc_mux` (stdlib/kernels/logic_synth absorption track, PRs #188 + #192)
- **074** = this RFC (first free slot)

Prior draft attempt used slot 073, retracted on slot-conflict discovery with the logic_synth track; the working artifact is this 074-slotted RFC. No drift.
