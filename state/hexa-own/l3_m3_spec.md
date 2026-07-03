All evidence gathered and verified against source. Returning the spec content below (read-only run — no files written to the repo; the parent saves it to `state/hexa-own/l3_m3_spec.md`).

---

# L3-M3 — MIR intra-block loan pass: implementation spec (hand-off-ready)

2026-07-03 · read-only census against main @ f00897610 (+ origin fetch) · feeds from `state/hexa-own/l3_m0_measurement.md` (probe verdicts), `state/hexa-own/l3_borrow_census.md` §(2)/§(5) M3, `state/rfc_advanced_typesystem.md` §4.1 R1 (:155-160).

**One-line goal**: the discriminating detector M0 proved missing — warn on *write-through-one-alias-then-use-through-another* on shared-handle locals, intra-block, at HIR→MIR lowering time (spans in hand), flag `HEXA_BORROWCK=1`, diag `HX3014`, warning-band, byte-neutral OFF. Fixes both M0 prerequisites *inside* the M3 shape: (1) call-arg move classification and (2) read/write alias discrimination.

## 0. Verified substrate facts (all re-checked this census)

| claim | verdict | evidence |
|---|---|---|
| `hir_to_mir_diags()` channel exists, span-carrying, single-drain | ✅ | `compiler/lower/hir_to_mir.hexa:30-40` (`_lr_diag` buffer, reset at `lower_hir` entry :4448), emit helpers `_emit_hx1101..1104` :925-956; drained ONCE in `compiler/main.hexa:816-818`, rendered + fatal-gate :828-841 (warnings don't abort — `_has_errors` checks severity) |
| Spans in hand during lowering | ✅ | `HExpr.span` (`compiler/ir/hir.hexa:51`), `Span{file,line,col,len}` (`compiler/lex/tokens.hexa:13-18`); every hook site below receives the `HExpr` |
| `HX3014` unclaimed | ✅ | zero grep hits repo-wide; newest 3xxx on main = HX3012 (`compiler/diag/catalog.hexa:357`); **HX3013 is reserved** by `state/hexa-own/next_rounds_plan.md:160,187` for the L2.5 arena-escape lint — M3 must NOT take it |
| `HEXA_BORROWCK` unclaimed | ✅ | zero grep hits; RFC names it verbatim (`rfc_advanced_typesystem.md:131`). (#4088 used the *different* name `HEXA_BORROW_CHECK` — dead with the closed branch; do not reuse) |
| #4485 status | ⚠️ **stacked, not on main** | PR #4485 MERGED (2026-07-03T14:37Z) but into base `feat/own-l2-r2-return` = #4470's head; **#4470 (base main) is still OPEN**. The Copy predicate `_own_lint_name_is_copy`/`_own_lint_typeref_is_copy` and the `@own` param carrier land on main only when #4470's stack merges. Commit `62968f4fd` |
| `@own` param carrier shape (from #4485 diff) | ✅ read from `62968f4fd` | parser re-attaches inline `fn f(@own p: T)` as fn-item-level `Annotation{ name: "own", args: [LiteralString pname] }`; `ast_to_hir` copies ALL item annotations into `HItem.annotations` (`compiler/lower/ast_to_hir.hexa:2509-2525` — `fn_anns` loop + appended `param_names` annotation :2513-2517), so at `_lower_fn` both `own` and `param_names` are readable with zero new plumbing |
| MIR has no place projections / no Stmt span | ✅ | `Operand` carries `local_id` only (`compiler/ir/mir.hexa:55-62`); `Stmt` :66-73 span-less — census trap "do NOT add a span field to `Stmt`" stands; interleave-at-lowering is the only span-correct placement |

## 1. Prerequisite (1) — call-arg move classification

M0's killer: #4088 treated **every bare-ident call-arg as a by-value move** → ~950 HX2007, ~100% FP. Three candidates evaluated:

### (A) Copy-kind predicate (#4485) — necessary, NOT sufficient
- Source: `_own_lint_name_is_copy` / `_own_lint_typeref_is_copy` (`compiler/check/types.hexa` on `feat/own-l2-r2-return` @62968f4fd; scalars i8..u64/f16..f64/bool/char/unit = Copy, aggregates move).
- At the MIR layer M3 does not call it (AST-side, different Type representation). The HIR-side mirror is trivial: `Type.kind ∈ {i8,i16,i32,i64,f32,f64,bool,char,unit}` (`compiler/lower/ast_to_hir.hexa:115-145` kinds) — equivalently `_type_id_of(t) ∈ 1..8` for scalars (`hir_to_mir.hexa:181-209`).
- **Verdict: adopt as register-skip polarity** (scalar locals never enter the loan registry — same skip idiom as #4485), but it cannot fix M0's `fp_callarg` — that probe's arg was an **array** (not Copy). Insufficient alone.

### (B) @own-annotated param signatures — PRIMARY (this is the polarity inversion)
- Rule: **a call arg is a move IFF the resolved callee's corresponding param is declared `@own`; every other call is a read.** Default = read-only. This flips #4088's over-approximation to the exact opposite conservative direction and kills all four measured FP shapes at once (`fp_callarg`, the bigint `_nlimb` corpus shape, the argparse `len(s)` shape — all become reads).
- Mechanics: a `lower_hir` pre-pass over `module.items` (`ITEM_FN`) builds `fn-name → set(own-param-index)`: for each `Annotation{name:"own", args:[LiteralString pname]}` in `HItem.annotations`, map pname → position via the sibling `param_names` annotation (`ast_to_hir.hexa:2513-2517`). Exact precedent for this pre-pass shape: `_lr_fn_ref_names/_lr_fn_ref_arities` (`hir_to_mir.hexa:4484-4500`). `param_names` recovery already exists inside `_lower_fn` (:4141-4155).
- Unknown callees (runtime builtins, externs, indirect `STMT_CALL_INDIRECT` :1678-1700, `carrier_call` :1566-1591) → not @own → read-only. Honest consequence: with corpus @own adoption = 0 (M0 finding), Rule 2 (use-after-move) fires **only on newly annotated code** — that is correct behavior, not a gap; the noise floor goes to 0 by construction.
- **Dependency flag**: needs #4470's stack on main. M3 can merge before it — the pre-pass simply finds no `own` annotations and Rule 2 is inert; no code change needed when the stack lands.

### (C) Builtin whitelist for known-read-only stdlib fns — SUBSUMED, inverted
- Under (B)'s default-read polarity a *read-only* whitelist is dead weight. What M3 actually needs is the **inverse: a receiver-MUTATING method whitelist** for write classification (§2) — small, closed, verifiable against the codegen dispatch table: `push`→`hexa_array_push` (`compiler/codegen/arm64_darwin.hexa:1835`), `pop`→`hexa_array_pop` (:1836), `truncate`→`hexa_array_truncate` (:1863), `set`→`hexa_map_set_v` (:1953). (No `insert`/`remove`/`sort` method mappings exist in `_builtin_runtime_sym` :1806+ — whitelist is complete at 4 entries today; extend in lockstep with that table.)
- **Verdict: drop as a move classifier; keep the 4-entry mutator list as a WRITE classifier.**

## 2. Prerequisite (2) — read/write alias discrimination at hir_to_mir

Enumerated from `_lower_hexpr` dispatch (all verified with line numbers):

**WRITE through a local handle** (the only events that arm Rule 1):
| site | lowered shape | lines | written-through operand |
|---|---|---|---|
| field-assign `obj.f = v` | `STMT_ASSIGN op="field_set" args=[base, "f", val]` | `hir_to_mir.hexa:2133-2149` | `args[0]` (base) when `Operand.kind=="local"` |
| index-assign `a[i] = v` / `m[k] = v` | `STMT_ASSIGN op="index_set" args=[container, key, val]` | :2151-2168 | `args[0]` (container) |
| mutating method `a.push(x)` etc. | `STMT_CALL op="push"/"pop"/"truncate"/"set"`, receiver = `arg_ops[0]` (receiver-first convention :1713-1717, emission :1855-1866) | :1555-1867 | `arg_ops[0]` when op ∈ mutator whitelist §1(C) |

**NOT a write-through-handle** (binding-level events):
| site | shape | lines | loan effect |
|---|---|---|---|
| ident re-assign `b = x` (in-place reuse) | `STMT_ASSIGN op="assign"` onto existing local (`did_reuse` :2177-2186) | :2170-2225 | **edge-kill + re-point**: `b`'s local leaves its old alias group; if RHS is a bare aggregate ident, joins the RHS's group |
| `let b = a` | `STMT_ASSIGN op="let"`, fresh local + `_bind` | :2005-2096 (bind :2094) | **handle-copy edge** when RHS HExpr `kind=="ident"` AND aggregate-typed (fresh local id ⇒ shadowing is naturally safe) |

**READ observations** (what Rule 1/2 check against): the central hook is the ident lowering arm (:1146-1165) — every ident use resolves there via `_mir_lookup` with `e.span` in hand; `field` read (`op="field"` :3298-3323), `index` read (`op="index"` :3326+), binop/call args all funnel their base idents through it. One hook covers all reads.

**Aggregate-typed** (loan-eligible) = HIR `Type.kind == "array"` (`ast_to_hir.hexa:163`), `"named:*"` (structs are map-backed reference values — r24 comment :2124-2132), `"struct"` (:2438). Excluded: scalars (Copy §1A), `string` (no mutating method exists — all str builtins return new values), and **unknown `"?"`/`""`/`"generic:*"` kinds → NOT tracked** (precision-first polarity; the HIR type-fallback holes — memory `project_hexa_hir_array_elemtype_drop` — become documented false-*negatives*, never FPs).

## 3. Pass skeleton

**Placement — interleaved in `hir_to_mir.hexa`, no new pass file.** RFC R1 says `compiler/check/borrow.hexa` as a post-hoc MIR read-only pass, but the census correction stands: post-hoc MIR has no spans (`Stmt` span-less, `MFunc.def_line` only, `mir.hexa:131`) and the schema-add is a named trap. Interleaving mirrors the HX1101-1104 precedent exactly.

Hook sites (all guarded by one module-scope bool `_bck_on`, read once from `env("HEXA_BORROWCK")` at `lower_hir` entry — same idiom as `_arru_native_enabled` :210+):

1. **`lower_hir` (:4447)** — reset registries (like `_lr_diag`/`_lr_lambdas` :4448-4453); build the @own-param pre-pass map (§1B) next to the fn-ref pre-pass (:4484+).
2. **`_lower_fn` (:4120)** — per-fn registry reset (alongside `_lr_ctx_clear` :4124); register @own aggregate params as loan-tracked+moved-armed roots (annotations already iterated :4141-4155).
3. **let arm (:2094)** — after `_bind`: register aggregate local; add handle-copy edge on bare-ident RHS.
4. **assign arm (:2170-2225)** — edge-kill/re-point per §2.
5. **field_set (:2148) / index_set (:2167)** — record WRITE(group(base), name, span, cur_block).
6. **call arm** — mutator-whitelist receiver ⇒ WRITE (:1855-1866); per-arg @own lookup ⇒ MOVE (args loop :1719-1725, bare-ident args from `e.children[i].kind=="ident"`); all args also count as READs.
7. **ident arm (:1146)** — READ(name, span); evaluate both rules here.

**Loan-record shape** — module-scope parallel arrays (`_bck_*`), the `_own_lint_*` idiom (`types.hexa:1230-1234`) — no new struct, frozen-seed-safe:
- per tracked local: `_bck_local_ids: [i64]`, `_bck_group: [i64]` (representative = first member's local id), `_bck_names: [string]`, `_bck_block: [i64]`, `_bck_decl_lines/cols: [i64]`
- per group event (last-write / move): `_bck_grp_ids/_bck_grp_w_name/_bck_grp_w_line/_bck_grp_w_col/_bck_grp_w_block: …`, same quartet for move
- dedup: same-line/col suppression, cloned from `_own_lint_touch` (:1283-1285)

**The two rules** (both keyed on `ctx.cur_block` — an event is live only while `event.block == ctx.cur_block`; block ids from `LowerCtx.cur_block` :458-465, blocks split at every if/while/match/for → intra-block scope is exactly straight-line code):
- **Rule 1 — shared-XOR-mut**: READ or WRITE through local L′ where group(L′) has a recorded WRITE through a *different* name L in the same block ⇒ `HX3014` (args: alias name, writer name, write line). Fires on `hz_write_alias`; silent on `fp_arr_alias_read` (no write) and `fp_callarg` (no alias + calls are reads). **This is the discriminator.**
- **Rule 2 — use-after-move intra-block**: any use of a group with a recorded MOVE (call into an @own param, §1B) in the same block ⇒ `HX3014` (args: name, callee, move line). Copy-skip is inherited (scalars never registered).

**Diag**: new `DiagSpec` `HX3014` appended to `compiler/diag/catalog.hexa` **after** the (future) HX3013 slot — coordinate with L2.5 (`next_rounds_plan.md:194` adjacency-conflict warning applies to this line range too). Severity::Warning, stage "S3", one code with a `{rule}` template arg (`aliased write` | `use after move`). Emit via a `_emit_hx3014` clone of `_emit_hx1101` (:925-930) into `_lr_diag` — drain/render is already wired (`main.hexa:816-841`; warnings don't abort).

**Byte-neutrality**: flag-OFF ⇒ registries never populated, `_lr_diag` untouched, zero MIR shape change (the pass only *observes* — it never emits stmts/locals). Trivially byteeq-3-target GREEN; still run the gate (governance).

## 4. Test matrix + post-M3 M0 re-measurement

**Probe file family** (`compiler/check/borrowck_test.hexa` + shell gate, mirroring `borrow_check_test.hexa`'s 4-case contract — PASS with flag OFF and ON):

| probe | expect | proves |
|---|---|---|
| `hz_write_alias` — `let b = a; b[0]=99; print(a[0])` | HX3014 ×1 (Rule 1) | the M0-missing detector |
| `hz_write_alias_field` — struct alias, `c.depth = …` then read via other name | HX3014 ×1 | field_set arm |
| `hz_push_alias` — `let b = a; b.push(1); len(a)` | HX3014 ×1 | mutator whitelist |
| `fp_arr_alias_read` — `let b = a; print(a[0]+b[1])` | **0** | M0 FP #2 killed |
| `fp_callarg` — `foo(a)` then `a[0]`, foo's param not @own | **0** | M0 FP #1 killed |
| `fp_copy_int` | 0 | Copy skip |
| `fp_write_same_name` — `a[0]=1; print(a[0])`, no alias | 0 | XOR needs ≥2 names |
| `tp_own_param_move` — `fn g(@own p:[i64])`; `g(a); a[0]` | HX3014 ×1 (Rule 2) | @own move classification (requires #4470 stack; until then mark SKIP-annotated) |
| `xb_write_in_branch` — `let b=a; if c { b[0]=1 }; print(a[0])` | **0, documented** | intra-block ceiling → M4's discriminating probe |
| flag-OFF sweep of all probes | 0 diags, asm byte-identical | neutrality |

**M0 re-measurement protocol** (same vehicle + corpus as `l3_m0_measurement.md` — aiden, `aprime_cc dummy.hexa <file> --emit=asm`, per-build-closure counts):
- rerun the 11 closures with `HEXA_BORROWCK=1`: **expected HX3014 total = O(1..dozens), not ~950**; every hit hand-auditable (the volume itself is the pass/fail: >100 ⇒ classification failed, redo before merge).
- the probe matrix delta vs M0's table is the headline: `fp_callarg` 1→0, `fp_arr_alias_read` 1→0, `hz_write_alias` stays 1 **and is now distinguishable** — M0's "identically shaped to the two FPs" row inverts.
- rerun gen2-path control (all-zero expected — vehicle gap unchanged).
- capture compile-time delta flag-ON vs OFF on the largest closure (`bind.hexa`) — M0 noted no perf number existed; the loan pass is O(idents) with O(group) lookups, but measure, don't assert.

## 5. Honest infeasibility / scope flags

1. **Vehicle gap persists (M0's blocking finding)**: `hir_to_mir` runs only on the native frontend; the default `hexa build`/`run` gen2 hexat path has no MIR and will report 0 forever. Any "advisory coverage" claim must name the vehicle (`aprime_cc` / native route). Closing this = a separate gen2 decision, out of M3 scope.
2. **#4470 stack dependency is soft**: Rule 2's signal source (@own params, Copy predicate precedent) sits on `feat/own-l2-r2-return` until #4470 merges. M3 is mergeable before it (Rule 2 inert), but the `tp_own_param_move` probe can't go green until then.
3. **Intra-block ceiling**: every `if/while/for/match` splits blocks (`_new_block` :683) — cross-branch write-then-read is invisible by design. That is RFC R2/M4 (backward liveness over `Block.preds/succs`, :743-757), not an M3 defect; `xb_write_in_branch` pins it as a measured negative.
4. **Whole-local granularity**: no place projections in `Operand` (`mir.hexa:55-62`) — `x.a` vs `x.b` disjointness unrepresentable; a write to `x.a` through an alias flags reads of `x.b`. Advisory-band tolerable; document in the HX3014 explain.
5. **Alias-edge blind spots (false negatives, deliberate)**: aliases created via fn returns, struct-field loads, array-element loads of aggregates, cross-param aliasing, and unknown-typed (`"?"`) locals are not tracked. Polarity choice after M0: a quiet lint that is right beats a loud one that drowns (HX2007's fate).
6. **Method-name collision**: `op` for method calls is the bare method name (:1704); a *user* fn named `push` called method-style would misclassify as a mutator — but codegen's `_builtin_runtime_sym` dispatch has the identical ambiguity today, so M3 is no worse than the substrate.
7. **Enforcement stays vacuous** under the bump-arena (`rfc:170-172`) — HX3014 is a logic-bug lint, not memory safety; unchanged M6 wall.
