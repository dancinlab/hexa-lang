# L3 borrow checker 설계 census (웨이브3 wf_880b274e-833 · 2026-07-03)

All evidence gathered. Final findings below.

---

# L3 Full Borrow Checker — Design Census (read-only)

## (1) Which IR layer has / could cheaply gain NLL's region+CFG info

**MIR is the answer — the CFG already exists; spans are the gap.**

| Layer | CFG | Spans | Evidence |
|---|---|---|---|
| AST (bind/types walkers) | none (tree walk) | yes (`Expr.span`) | `compiler/check/types.hexa` own-lint walks Expr tree; PR#4088 walker same |
| HIR | none — explicitly "1:1 translation pass: every AST Expr produces exactly one HExpr (no flattening)" | yes (`hir.hexa:50,70`) | `compiler/lower/ast_to_hir.hexa:9-11` |
| **MIR** | **real basic-block CFG with bidirectional edges**: `Block { id, stmts, preds, succs }` (`compiler/ir/mir.hexa:114-119`), edges maintained by `_add_edge` (`compiler/lower/hir_to_mir.hexa:743-757`), `STMT_BR`/`STMT_BR_COND` (`mir.hexa:88-89`) | **no** — `Stmt` has no span field (`mir.hexa:66-73`); only `MFunc.def_line` (`mir.hexa:131`) | |

Bonus proto-region info already in MIR: `Local.arena_id` (`mir.hexa:29-31`) and `STMT_ARENA_NEW`/`STMT_ARENA_DROP` (`mir.hexa:92-93`) — the arena lifetime model is first-class in the IR. This matches the pre-existing RFC verdict: "a borrow checker would be a MIR-level dataflow pass (`compiler/ir/mir.hexa`), structurally byteeq-safe" (`state/rfc_advanced_typesystem.md:71`).

Two structural constraints:
- **Span gap**: a post-hoc MIR pass can only anchor diagnostics at fn granularity. Precedent fix: `hir_to_mir.hexa` already emits span-carrying diags (HX1101-1104, `hir_to_mir.hexa:926-954,1205`) *during* lowering while `HExpr.span` is in hand, drained via `hir_to_mir_diags()` (`hir_to_mir.hexa:37`, consumed `compiler/main.hexa:~815`). Run borrowck interleaved with lowering, or accept a Stmt schema-add (trap: TypeRef schema-add was deferred over "~36 literal sites"; `parser.hexa:405-408` — Stmt likely similar ripple).
- **Per-fn streaming**: main.hexa keeps only one fn's MFunc resident at a time (memory note at `compiler/main.hexa:~786`). Fine — NLL is intra-procedural anyway; forbids cheap whole-program aliasing.

## (2) Smallest honest L3 rung vs real dataflow

**Already on main (L2, merged)**: `HEXA_OWN_LINT=1` HX3012 use-after-move for `@own let` — per-fn side registry, newest-entry-wins shadowing, bare-ident move sites only (`types.hexa:1211-1300`; call sites 2111/2304/2424/2774; per-fn reset 3907; catalog `diag/catalog.hexa:357`). AST-linear, no branches.

**Closed PR #4088** (`feat/borrow-checker`, commit `51bd86168`, +349 lines `compiler/check/bind.hexa`, gate `HEXA_BORROW_CHECK`): HX2007 use-after-move with aggregate/Copy classification, and HX2008 = the closure-capture **&mut proxy** — a `mut` local captured by ≥2 closures in one fn, self-described: "PROXY... (no true `&mut` aliasing exists to observe)" and "function-wide closure count... honest over-approximation". Traps visible in the diff: let-type extraction string-parses the `|Type` suffix off `Expr.text` (`_borrow_let_type_name`) instead of a real TypeRef; every bare-ident call-arg is assumed a by-value move.

**Smallest honest L3 rung** — and the key semantic fact: hexa arrays are *already* shared mutable handles ("hexa arrays are shared handles, so `_lr_blocks[i].stmts.push(s)` grows the same array the stored Block holds", `hir_to_mir.hexa:713-716`). So `let y = x` on an array **aliases today, no `&` needed**. The smallest rung that is honestly "L3" rather than L2-rebadged:
- intra-fn, **intra-block** alias tracking at MIR: record handle-copy edges (`STMT_ASSIGN` local→local for aggregate-typed locals), warn on write-through-one-alias-then-read-through-other under a two-phase-ish rule. This is RFC §4.1 R1 exactly (`rfc_advanced_typesystem.md:155-160`), no region inference, no fixed point.
- **Real dataflow starts** at conditional moves / loop-carried borrows / "lifetime = liveness of the reference" (NLL RFC 2094): needs backward liveness over `Block.preds/succs` with fixed-point iteration (loop back-edges exist in the CFG). That is RFC R2 (`rfc_advanced_typesystem.md:161-164`) — genuinely cheap here because both edge directions are already materialized, but it is a per-fn O(blocks×locals) bitset pass and must stay flag-gated (compile-speed campaign context).

**Granularity ceiling (honest)**: MIR `Operand` carries `local_id` only — no place projections (`mir.hexa:55-63`). Field-disjoint borrows (`&mut x.a` + `&mut x.b`) — the flagship NLL precision — are unrepresentable; whole-local granularity is the ceiling without a place/path schema-add to Operand.

## (3) Surface syntax status

- Lexer: `TokenKind::Amp` exists but only as bitwise-and (`compiler/lex/tokens.hexa:62`, `lexer.hexa:541-543`); `AmpAmp` logical-and (`tokens.hexa:60`). **No** `KwOwn/KwMove/KwBorrow` in the native lexer keyword set (`tokens.hexa:76-97`). The gen2 seed *does* recognize `own/borrow/move/drop` as reserved words (`self/bootstrap.hexa:94-97`) — reservation only, no semantics.
- Parser: `&` appears only as a binary bitwise op (`parser.hexa:557`); `parse_unary` handles only `- ! ~` (`parser.hexa:683-703`); `parse_type` has no Amp arm. ARCHITECTURE wall node: "real `own`/`borrow`/`&mut` tokens are unavailable (`&` lexes only as bitwise-and, measured in PR#4088)".
- **However**: two sanctioned, frozen-seed-safe routes exist:
  1. **Type-position fold**: `parse_type` already consumes a prefix `*` and folds it into the type-name string (`"*Void"`, `parser.hexa:374-399`). `&T` / `&mut T` can ride the identical fold (`name = "&T"`) — zero new TokenKind, zero TypeRef schema change. `Amp` is even already whitelisted inside generic-args type lookahead (`parser.hexa:152`).
  2. **Expr-position**: prefix `&x` is currently a parse error (binary Amp needs a left operand), so adding an Amp arm to `parse_unary` is purely additive; represent it as the existing `ExprKind::UnOp` with `text="&"`/`"&mut"` (UnOp already dispatches on op text, `parser.hexa:685-688`) — respects the L1-defer discipline "no new TokenKind/ExprKind" (ladder cell `hexa-own-ladder-milestones`).
  3. Zero-syntax alternative: annotations. `@own` already parses and drives HX3012; `@shared` proves a full annotation→AST→HIR→MIR `Local.space` channel (`parse/ast.hexa:119-124`, `mir.hexa:44-50`) that `@borrow`/`@borrow_mut` could reuse verbatim.
- Trap: gen2 (`self/parser.hexa`) must also parse whatever surface lands or files using it become native-backend-only, violating the ladder's two-backend gate; byteeq holds only while compiler sources themselves don't use the new syntax (gen3≡gen4 untouched).

## (4) Reference-match scope that is meaningful under arena+GC-free default

The pipeline's own RFC already adjudicated this: borrow *enforcement* is **vacuous under the bump-arena** — nothing frees mid-scope (`rfc_advanced_typesystem.md:112,151-153,170-172`). Honest slices of rustc borrowck semantics, ranked:

| rustc slice | Meaningful for hexa? | Why |
|---|---|---|
| E0382 use-after-move | yes (protocol lint, already L2) | single-owner discipline; catalog text explicitly mirrors "rustc_borrowck use-after-move ... as a non-fatal WARNING" (`catalog.hexa:357` explain) |
| Aliasing-XOR-mutability on shared handles | **yes — the highest-value slice** | arrays/structs are shared handles today; two-names-one-array mutation is a live logic-bug class (the compiler's own hir_to_mir comments show the team both exploits and gets bitten by it) |
| Closure double-mut-capture | yes (PR#4088 HX2008 shape) | real data-race-shaped bug in the new thread/spawn surface |
| Arena-escape (returning arena-scoped handle) | yes but that's **L2.5, not started** — no region/escape check exists in `compiler/` (only `@no_arena` annotations on stdlib fns, `stdlib/runtime/numeric.hexa:1293`) | becomes true memory-safety only when `HEXA_STREAM_RECLAIM` free-tree ships |
| NLL end-of-borrow precision, two-phase borrows | marginal | only reduces false positives of the above; no soundness payoff under arena |
| Lifetime-parameterized signatures (`'a`), Polonius, drop-order, field-disjoint borrows | **not meaningful / infeasible** | `'a` syntax = frozen-lexer wall (`rfc:185-187`); no place projections in MIR; arena drops wholesale |

Also binding: the ladder SSOT itself gates L3 — "L3 full borrow checker(&/&mut·NLL) = rustc MIR borrowck reference-match — go/no-go is decided after **measuring** the defect classes L1~L2.5 missed (no unmeasured start)" (`ARCHITECTURE.json#hexa-own-ladder-l3-borrow`). L2.5 does not exist yet, so **L3 is formally double-gated: an unbuilt prerequisite rung + a required measurement**.

## (5) Proposed M-milestones (effort: S ≤1 pool-day, M = days, L = week+/blocked)

- **M0 census gate (S, mandatory-first)** — run `HEXA_OWN_LINT=1` + rebased PR#4088 walker over stdlib/compiler corpus + anima scratch repros; tally escaped defect classes. This *is* the ladder's go/no-go input. Trap: starting M2+ without it violates the SSOT cell verbatim.
- **M1 revive #4088 as the bind-stage advisory (S-M)** — code + 314-line `borrow_check_test.hexa` already exist on `feat/borrow-checker`; rebase, keep HX2007/HX2008 (band already allocated in the branch catalog; ladder forbids new HX9xxx). Trap: `_borrow_let_type_name` string-parsing of `Expr.text` diverges from types.hexa TypeRef classification — reconcile or scope-document.
- **M2 surface syntax (M)** — `&T`/`&mut T` via the `*T` name-fold in `parse_type` + `parse_unary` Amp arm as `UnOp text="&mut"`; mirror in `self/parser.hexa`; tree-sitter update (lockstep rule). Gates: byteeq 3-target (trivially GREEN while unused) + both backends. Trap: any new TokenKind/ExprKind = faithful-build-break — the fold route is the only sanctioned one.
- **M3 MIR intra-block loan pass (M)** — RFC R1: interleave in `hir_to_mir` (spans in hand, `hir_to_mir_diags()` channel exists), track handle-copies + `&`-UnOps, warn shared-XOR-mut and use-after-move intra-block. Flag `HEXA_BORROWCK=1`. Trap: do NOT add a span field to `Stmt` in the same PR (schema-ripple; separate cycle if ever).
- **M4 NLL liveness (M-L)** — RFC R2: backward fixed-point over `Block.preds/succs`, borrow ends at last use. Whole-local granularity only (no places) — document as measured ceiling. Trap: loop back-edge convergence + compile-time budget; keep off default path.
- **M5 strict promotion (S-M)** — `HEXA_BORROWCK_STRICT=1` fatal, selftest family per defect class, corpus-clean proof, both backends.
- **M6 enforcement (L, BLOCKED)** — borrows constraining actual frees. Infeasible without X = a non-arena allocator (`HEXA_STREAM_RECLAIM` free-tree, currently gated-live not default). Until then advisory is the honest ceiling — the RFC states this as the wall (`rfc:170-172`).

**Infeasible-without-X (honest walls)**: full rustc reference-match needs (a) reference types in a real type lattice (static-types is opt-in; TypeRef is name-string-based — no auto-deref/reborrow inference on a name-fold), (b) place projections in MIR `Operand` (field-granular borrows), (c) an allocator where violations are memory-unsafe. None of (a)(b)(c) exist; therefore the meaningful L3 target is **"NLL-shaped advisory aliasing lint on whole locals over the existing MIR CFG"**, not rustc parity — and per the ladder SSOT it may not start until the M0 measurement says L1/L2/L2.5 leave a defect class on the table.
