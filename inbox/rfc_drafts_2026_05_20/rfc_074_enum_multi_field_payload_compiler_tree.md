# RFC 074 — Enum Multi-Field Payload (compiler/ tree B2 + C1 decision lock)

> **Status**: PHASE-1-SELF-LANDED · Shape A (self/ tree parser+ast — parse-gate PASS, deployed-binary regen deferred). compiler/ tree Phase 1 still PLANNED.
> **Opened**: 2026-05-20
> **Phase 1 self/ landed**: 2026-05-20 — `self/parser.hexa::parse_enum_decl` now drives the comma-loop accumulator through `parse_type_annotation` (was `p_expect_ident`); `self/ast.hexa` EnumDecl + Param comments refreshed (positional `[string]` payload arity). Parse-gate `hexa_real parse` PASS on both files. Deployed-binary regen = standard deploy cycle (g_commit_push_deploy), not this sub-cycle.
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

### Phase 1 — `compiler/parse` (accept multi-field syntactically)

**self/ tree Phase 1 LANDED 2026-05-20** (Shape A surgical, this cycle):
- `self/parser.hexa::parse_enum_decl` (L1924+) — `vtypes.push(p_expect_ident())` → `vtypes.push(parse_type_annotation())`. Comma-loop accumulator preserved (already array-shaped); upgrade enables `[T]`, `T?`, `Foo<T>` payload types in addition to bare idents. Header comment block added (RFC 074 cross-link).
- `self/ast.hexa` — EnumDecl + Param header comments refreshed: positional `[string]` payload arity convention documented; future migration of `Param.typ → Param.typs: [string]` flagged as Phase 2-4 (typechecker/codegen multi-arg).
- **Parse-gate**: `hexa_real parse self/parser.hexa` + `hexa_real parse self/ast.hexa` both PASS. Self-test fixture `enum E { V(int, string), Triple(int, string, bool) }` parses cleanly (legacy single-ident path was already accepting comma-list; Phase 1 generalises the per-slot type grammar).
- **Honest limit**: deployed `hexa_real` is pre-Phase-1, so the `enum R { Ok([int]), Err(string?) }` rich-type fixture parse-errors against it (LBracket unexpected). Once `g_commit_push_deploy` cycle regenerates hexa_v2, that gate passes. The SSOT-edit gate (this cycle) is fully measured PASS.

**Files** (3, compiler/ tree — still PLANNED):
- `compiler/parse/ast.hexa` — update L7-10 STALE comment ("stage0 enum variants cannot carry payloads yet" → "enum variants carry positional payload list per RFC-074 §2.2; payload arity = `len(variant.typs)` per Param.typs carrier-shape"). Document the new `typs: [TypeRef]` convention.
- `compiler/parse/parser.hexa` — replace `parse_enum_item`'s comma-drain (L1619-1625) with an accumulator that pushes each parsed type into the variant's `typs: [TypeRef]`. Construction site (`parse_primary`'s `EnumPath` arm) already collects `children[]` correctly — verify.
- `compiler/parse/parser.hexa` — pattern parser (`parse_match_pattern` near L1093-1111) already routes `Variant(payload)` through `parse_expr`'s EnumPath path; verify `children[]` accumulates all comma-separated patterns rather than just the first.

**Acceptance** (Phase 1):
- `hexa_real parse compiler/parse/parser.hexa` → OK
- `hexa_real parse compiler/parse/ast.hexa` → OK
- New fixture `compiler/parse/parse_test.hexa` — parses `enum E { V(int, string) }` and `match e { E::V(a, b) -> … }` without lex/parse error; AST inspection confirms `len(variant.typs) == 2` and `len(pat.children) == 2`.

**g3 honest scope**: parse-only — semantics still rejected in Phase 2's `check/` until that lands.

#### 3.1.1 Carrier-shape sub-decision

Two options for how parser stores variant payload arity:

- **(a) Reuse `Item.params`** as variant rows where each row's `typ` is the *first* payload type and a new sibling `params[]` field on the variant Param carries the rest. *Rejected*: requires `Param`-of-`Param` nesting which the AST schema doesn't support.
- **(b) Replace `typ: TypeRef`** on the variant `Param` with `typs: [TypeRef]`. *Adopted*. Existing single-field sites have `len(typs) ∈ {0, 1}`; multi-field has `len(typs) ≥ 2`. Migration is a parser-only diff plus consumer-side fan-out at Phases 2-5.

### Phase 2 — `compiler/check` (typecheck payload arity + binder fan-out)

**Files** (3-4):
- `compiler/check/bind.hexa` — extend `_bind_pattern`'s `_is_enum_path_kind` arm (L812-831) to verify arity matches the parsed `typs` length; emit HX02NN on mismatch. The existing binder-fan-out loop is already correct.
- `compiler/check/types.hexa` — turn every `ExprKind::EnumPath -> false` arm (~12 sites) into a real probe; introduce `enum_all_variant_payload_types: [[string]]` (parallel-array of arrays — outer index = variant slot, inner = positional types). Mirrors self/'s `enum_all_variant_payload_types` but lifted from string to `[string]`.
- `compiler/check/resolve.hexa` — register multi-field variants by walking `Item.params[i].typs[]`. Single-field path unchanged.
- `compiler/check/types_test.hexa` — fixtures for arity-OK, arity-too-few, arity-too-many, type-mismatch-per-slot.

**Acceptance** (Phase 2): all `compiler/check/*_test.hexa` PASS + new arity fixtures PASS + `hexa_real parse` clean per file.

**g3 honest scope**: typecheck-only — lower/ir/codegen still drop payloads in Phase 3's territory.

### Phase 3 — `compiler/lower` (HIR-level payload child wiring)

**Files** (2):
- `compiler/lower/ast_to_hir.hexa` — lower `ExprKind::EnumPath` with payload to a HIR `HirEnumCtor { tag: i32, args: [HirValue] }` (positional). Match patterns lower to `HirMatchArm { tag, binders: [HirBinder] }`.
- `compiler/lower/hir_to_mir.hexa` — flatten to MIR `MTag` + `MPack` instructions over a contiguous payload-cell vector. **NOTE**: this phase is where the B1 holdout (self/ Operand) starts to bite — if the compiler/ MIR's `Operand` is still string-kind-discriminated, the payload-cells need a uniform `MValue` carrier. Decision: **adopt a sum-typed `MValue` only at Phase 3 land time**, conditional on B1 prereq (interp rebuild) being met OR a parallel B1-equivalent landing on compiler/ MIR first.

**Acceptance** (Phase 3): lower_test fixtures show the multi-field enum construction surviving HIR→MIR with arity preserved.

**g3 honest scope**: codegen still has no payload-aware emit (Phase 4); MIR is correct in isolation but un-rendered.

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
