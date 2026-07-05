# Wall A endgame — r9+ rung census + HEXA_STATIC_TYPES flip-criteria design

Read-only census, 2026-07-03. Refs pinned: main @ `9f1b7a70d`, `origin/feat/static-types-r8` @ `9df473f14` (stacked on `origin/feat/static-types-r7prep-array-lower` @ `50d2d9910` — **NOT yet in main**, `git merge-base --is-ancestor` verified). Line numbers marked **(main)** = `compiler/check/types.hexa` on main, **(r8)** = the same file at `origin/feat/static-types-r8`.

## 0. Current ladder state (what exists, with attach points)

**Merged to main (r1–r6, #4094→#4108), all opt-in `HEXA_STATIC_TYPES=1`, HX3011 fatal REJECT:**

| rung | check | site (main) |
|---|---|---|
| r1 | scalar-literal RHS on typed `let` | types.hexa:2235–2262 (gate :2242) |
| r2 | ident/call RHS on typed `let` | types.hexa:2264+ |
| r3 | decl/init-split + ident-LHS re-assign | types.hexa:2314–2334 (gate :2329) |
| r4 | array-element assign `a[i]=…` (block-local annotated lets, text-parsed elem) | types.hexa:2336–2364 |
| r5 | struct-field assign `s.f=…` (field-type side registry) | types.hexa:2365–2410; registry types.hexa:1129+, recorder :3777 |
| r6 | struct-lit field-init `P{x:…}` | types.hexa:2512–2561 (gate :2535) |

**Default-ON substrate the ladder rides on** (these fire without any flag): HX3003 call-arg check via `_types_equal` (types.hexa:2827–2846), HX3004 return check (types.hexa:2221 statement-return; :3921 tail-expr; fn return lowered at :3897 via `_types_lower_type_ref`), HX3005 match-arm body join (`_check_match`, now via `_types_assignable` — #4605 segment(b), matching the if/else join). **All value-flow sites (let/assign/return/call-arg/if-join/field-init/match arm-body) now use `_types_assignable`** — the bare-`_types_equal` value-flow census is closed. `_types_equal` on main is kind-string-only; `_types_assignable` adds int/float-literal coercion + HexaVal wildcard (the strict-superset guarantees each swap is loosening-only, byteeq-neutral).

**Segment(b) rungs on top of the value-flow closure**: HX3005 match-join unit-permissive guard (#4606 Rung A, if/else-join parity); Rung B actual-`unit` permissive guard on the return/assign/module-let Error sites (unannotated-return call resolving to `unit` no longer false-fires HX3004/HX3001; bare `return` still fires E0069); **HX3025 index-on-scalar REJECT (Rust E0608)** — indexing a KNOWN scalar (int/float/bool/char) is a guaranteed runtime error (hexa_array_get aborts) surfaced to S3, `_types_strict_for` banded (string excluded v1). catalog next-free is now HX3026; corpus census greps `HX30(1[167]|2[45])`.

**On the r8 branch (unmerged):**
- r7-prep (`HEXA_STATIC_TYPES_ARRAY_LOWER=1`): structured lowering `[T]`→`Type{kind:"array", args:[elem]}` in `_types_lower_type_ref` (r8:963), element-recursive `_types_equal` (r8:1775–1778), structured display (r8:231). Params inherit it automatically (`_types_bind_params` → `_types_lower_type_ref`, main:3804–3814); so does the fn return type (main:3897).
- r8: ArrayLit structural inference (both flags, r8:2729–2760) → the **default-ON** HX3003 site rejects `g([1.5])` vs `fn g(xs:[i64])` with zero new check code; r8b param/module-let index-assign fallback (r8:2472–2503).

## A. r9+ rungs — next 3–5 REJECTs by value, on top of r8

### r9a — Index/Field READ inference (highest value: 1 rung feeds 5 existing check sites)
- **What**: today Field and Index *reads* fall to the STUB and return unknown (types.hexa:2565 "Field / Index / StructLit / Wildcard — STUB v1"), so `let s: string = xs[0]` with `xs:[i64]`, and `let n: i64 = p.name`, pass silently in BOTH modes. Rung: flag-gated inference arms — Index: infer base, `kind:"array"` → return `args[0]` (structured bases exist under ARRAY_LOWER via params/lets/ArrayLit); Field: receiver struct name → `_types_lookup_struct_field_typename` (the r5 registry, already consumed at main:2401 and :2547) → return the lowered field type.
- **Why highest value**: it produces no new diagnostic site — it feeds the r1/r2 let checks, r3 assign, default-ON HX3003 (:2840), HX3004 (:2221), HX3005 (:2884). Every downstream check becomes element/field-aware at once.
- **Implementability**: HIGH — both carriers exist; unknown-fallback keeps it conservative (nested receivers `s.inner.x` stay silent, consistent with the documented ceiling in catalog.hexa:348 explain).
- **Dependency**: r7-prep + r8 merged first. Byteeq-neutral by the same first-`&&`-operand idiom.

### r9b — fn-return array element REJECT + element-literal coercion arm (cheapest; coercion part is flip-BLOCKING)
- **What**: `fn f() -> [i64] { return [1.5] }`. Under the r8 stack this **already almost falls out free**: return annotation lowers structured (r8:963 via main:3897), `return [1.5]` infers `array[f64]` (r8:2729), and the existing HX3004 site (main:2221) calls `_types_assignable` → `_types_equal` element recursion (r8:1775) → REJECT. Remaining work = tests + one real gap: **element-level literal coercion**. `_types_assignable`'s coercion arms key on `src.kind` being a literal (main:1767–1778); an ArrayLit src is neither, so `fn f() -> [f32] { return [0.0] }` (and `let xs:[f32] = [0.0]`, `g([0])` vs `[i32]`) would FALSE-fire — `[0.0]` infers `array[f64]`. Rung: extend assignability — expected `kind:"array"` + actual `kind:"array"` + src ArrayLit → per-element `_types_assignable` with the element expr as `src`.
- **Value**: HIGH — false-positive prevention is a hard prerequisite for any default-ON flip (§B); the REJECT itself closes the return-position hole.
- **Implementability**: HIGH, ~30 LOC + tests; attach `_types_assignable` main:1767 + the two HX3004 sites.
- **Dependency**: r7-prep + r8.

### r9c — match: literal-pattern vs scrutinee REJECT (+ structural arm consistency for free)
- **What**: `_check_match` explicitly discards the pattern type — "discard the inferred pattern type (no equality check at v1)" (types.hexa:2864), and `_scrut_t` is inferred then unused (:2856). Rung: flag-gated — for scalar *literal* patterns (LiteralInt/Float/String/Bool/Char) whose inferred type and the scrutinee type are both known scalars that disagree → HX3011 (Rust E0308 in `check_pat`). Conservative skips: ident binders, `_`, EnumPath, `match_guard` carriers (:2874). Note: arm-BODY element-level consistency (`[i64]` arm vs `[f64]` arm) already falls out of r7-prep's `_types_equal` recursion through the existing HX3005 site (:2884) — test-only.
- **Value**: MEDIUM-HIGH — `match n { "x" -> … }` on an integer scrutinee is a real silent-mismatch class; no registry needed.
- **Implementability**: HIGH — all machinery local to `_check_match`.
- **Dependency**: none beyond merged r7-prep (for the body-consistency bonus); the literal-pattern check works on bare `HEXA_STATIC_TYPES=1`.

### r9d — struct-lit field-EXISTENCE check (unknown field name)
- **What**: r6 deliberately scoped it out — "field-existence / nominal-field diagnostics are separate, not r6 scope" (types.hexa:2528). The r5 registry records every field NAME per struct (recorder :3777). Rung: flag-gated — a field-init whose name misses the registry for a known struct → REJECT (Rust E0560 "struct has no field named"); missing-required-fields (E0063) as a warning-band follow-on.
- **Value**: MEDIUM — typo-class bugs; also hardens r6 itself (today a typo'd field name silently skips the type check).
- **Implementability**: HIGH — attach inside the r6 arm (:2535–2561). Needs a **new diag code**: HX3011 is already double-booked — catalog.hexa:348 (mismatched types, Error) vs catalog.hexa:612 (HKT kind-arity, Warning) reuse the same code. Allocate fresh (HX3013+) and fix the collision pre-flip.
- **Dependency**: r5 registry only (in main).

### r9e — closure param/ret typing (C2) · Map/generic lowering — enumerate, DEFER
- Closure: C1 representation is a bare `fn` kind with empty args/ret, explicitly "C2 scope" (types.hexa:2445–2452) — typing closure params/returns would feed HX3003 at indirect call sites. Real but a bigger lift (binder env threading).
- Map/generic element lowering: `Map<K,V>` parses as `TypeRef{kind:"generic", name:"Map", args:[K,V]}` (parser.hexa:468) and degrades to a string sentinel dropping args (types.hexa:932–941 main). The ARRAY_LOWER pattern extends mechanically (`kind:"map"`, 2-arg recursion in `_types_equal`) — but corpus surface is ~nil (`Map<` appears in 1 stdlib file; no map-literal inference exists — parser.hexa:1088 `{}` ambiguity unresolved). **Low measured value → defer** until a corpus census shows demand. Naming it a wall now would be premature; naming it a rung now would be a filler round.

**Recommended order: r9b(coercion) → r9a → r9c → r9d; r9e deferred.** r9b first because it is the sole false-positive source the r8 stack introduces and gates everything in §B.

## B. FLIP CRITERIA — measured conditions for HEXA_STATIC_TYPES default-ON

### B.1 Precedent flip-gate patterns (extracted)

**Archetype 1 — bit-identical perf flip** (`HEXA_ARENA_BLOCK_BSEARCH`, #3952→#3956, commit eb53d8032): land default-OFF **with byte-identity proven by measurement** ("sha-equal, 213k probe points, 0 divergence") + captured perf (~3.36× stage-1); flip PR = TU-wide default-define, **native-canonical polarity with an opt-OUT escape** (`-DHEXA_ARENA_BLOCK_BSEARCH_OFF`), gated by 3-target byteeq CI (arm64/darwin confirmed by the flip CI itself).

**Archetype 2 — bit-changing flip** (FRAG-REGEN #4430, commit dcd110884): **measure-before-flip on HEAD** (ON-verify: build rc=0, floor 82→67 U, 0 residual, captured on summer); flip PR **NOT auto-merged** — held for faithful-nobaseline 3-target GREEN + byteeq gen3≡gen4; **revert-on-RED**; sub-gates flipped as separate follow-ons.

**Archetype 3 — zeroc flip round** (#4449 glob / #4450 fgets / 49654f1b4 qsort, 2026-07-03): hard rule per flip = "byteeq 3타깃+faithful+install smoke GREEN에만 머지·RED시 revert", pre-flip gated-body scan, verify-via-PR when the pool is unusable.

**Diagnostic-gate precedent** (closest in kind to static-types): HX8004 `@cite`/`@verify` is a default-ON *build-refusing diagnostic* that ships with a **per-site escape** (`@grace`) — a REJECT flip needs a grace mechanism, not just an env toggle. Also relevant: the repo already runs a two-severity ladder — HX3010 non-exhaustive-match ships as default-ON **Warning** (catalog.hexa:340), HX3012 own-lint as opt-in warning band — i.e. warn-first→error-later is established practice.

### B.2 What makes static-types different from every precedent
Flipping `HEXA_STATIC_TYPES` does not change emitted bytes for **accepted** programs (REJECT-only checks); it changes which programs **build at all** (HX3011 is Severity::Error → fatal, catalog.hexa:348). So the flip gate needs one axis no prior flip had — **corpus-clean = 0 HX3011 on the entire tracked .hexa corpus** (compiler 389 files/157k LOC + stdlib 2,249/543k + self 1,167/410k ≈ 1.11M LOC) — plus the standard byteeq/faithful axes, because the checker runs inside the self-host build itself.

### B.3 Proposed flip ladder (F0→F5)

- **F0 — rungs that must exist first (flip-blocking):** r7-prep + r8 merged; **r9b element-literal coercion** (the only known false-positive source; without it `let xs:[f32]=[0.0]` breaks legitimate corpus code); fold `HEXA_STATIC_TYPES_ARRAY_LOWER` into `HEXA_STATIC_TYPES` (a default-ON flip of a two-flag AND is incoherent); fix the HX3011 code collision (catalog.hexa:348 vs :612) and refresh the :348 explain (its "r6 = the last scope-wireable rung" claim is already stale vs r8). r9a/r9c/r9d raise flip *value* but are NOT blockers — missing inference only under-rejects (unknown-tolerant `_types_equal` contract, types.hexa:1706), it never false-fires.
- **F1 — corpus-clean census (the new gate):** a CI job / pool run compiling the full corpus with the flag ON, both frontends, capturing HX3011 count. **No workflow currently references STATIC_TYPES** (grep of `.github/workflows/*` = 0 hits) — this job must be created and must be green before any flip PR. Target: **0 diagnostics**; true positives found in-corpus get fixed as ordinary PRs first (that is the flip's value proof — captured numbers of real bugs caught).
- **F2 — dual-frontend + byteeq:** gen2 C-transpile and aprime native must produce **identical flag-ON diagnostic streams** on the corpus (two-backend path-mismatch is a known repo failure mode), and flag-ON self-host must keep **byteeq gen3≡gen4 + 3-target GREEN** (r8 already claims per-rung "both-frontend verification on pool/CI" — the flip re-proves it corpus-wide, not per-test).
- **F3 — perf budget (measure, don't assume):** flag-ON adds per-node `env()` string compares (4 gate sites on main: types.hexa:2044/2242/2329/2535, more on branch) plus r8b's scratch re-infer per index-assign. Pre-flip refactor: hoist the env reads to a once-per-`type_check()` cached bool (byteeq-neutral). Then measure stage-1 self-compile wall ON vs OFF (median-of-3, summer, isolated — not back-to-back). **Budget: ≤2% wall delta**; the compile-speed campaign (#3952/#3956) treats stage-1 wall as a guarded asset, so a typecheck regression above noise is a flip-blocker.
- **F4 — severity + escape polarity:** flip in two steps, mirroring HX3010/HX3012: **step 1 = default-ON Warning band** (build never breaks; corpus + downstream users observe for a cycle), **step 2 = escalate to Error** with (a) env opt-out `HEXA_STATIC_TYPES=0` retained and (b) a `@grace`-style per-site waiver considered for third-party code. This keeps native-canonical polarity (strict checker = the canonical default; the escape enables a *relaxation*, matching #3956's opt-OUT direction — never `HEXA_NO_STATIC_TYPES`).
- **F5 — flip PR mechanics (archetype 2/3 discipline):** measure-before-flip captured on HEAD (corpus-clean count, perf delta, dual-frontend diff = 0); flip PR held for byteeq 3-target + faithful + install smoke + the F1 corpus job GREEN; **never on x86-only green**; revert-to-OFF on any RED; Warning→Error escalation as a separate follow-on PR.

### B.4 Measured flip conditions — summary table

| # | condition | measurement | target |
|---|---|---|---|
| 1 | corpus-clean | HX3011 count, full tracked corpus, flag ON, both frontends | 0 (true positives pre-fixed) |
| 2 | false-positive rungs closed | r9b coercion arm + its test matrix | merged, cases green |
| 3 | dual-frontend parity | gen2 vs aprime flag-ON diag-stream diff | byte-identical |
| 4 | self-host integrity | byteeq gen3≡gen4 + 3-target, flag ON | GREEN |
| 5 | perf budget | stage-1 self-compile wall ON/OFF, median-of-3, post env-hoist | ≤2% |
| 6 | escape hatch | opt-out env + warn-first severity step | shipped before Error flip |
| 7 | release integrity | faithful-nobaseline 3-target + install.sh consumer smoke | GREEN, revert-on-RED |
