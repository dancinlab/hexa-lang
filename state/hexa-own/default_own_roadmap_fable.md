All evidence verified against the repo (origin/main @ 50b5aca58, branches surveyed per the survey-branches discipline). Three ground-truth corrections to your premise before the design, since they move rungs around:

- **M3 is merged** (#4503, `ce09e97d5`): `HEXA_BORROWCK=1` → HX3014, pass lives at `compiler/lower/hir_to_mir.hexa:423-660` (registries `_bck_*` :456+, rules in `_bck_check_use` :612-632, flag read at :4828). Your working branch (`fix/install-bare-cuda-pip`) predates it — that's why greps here miss it.
- **M4 (`_bck_nll_check`, cross-block) is NOT on main** — it sits on branch `feat/own-l3-m4-nll` (`3afc6a803`, fn at hir_to_mir.hexa:700, called :4997). Treat it as in-flight; `state/hexa-own/fp_probe_and_m6_verdict.md` isn't on this checkout either (likely rides that branch).
- **The #4470 `@own`-param stack is still NOT on main** (`_own_lint_name_is_copy` greps 0 on origin/main), so Rule 2 is inert today exactly as the M3 spec predicted (l3_m3_spec.md §1B). And crucially: **the gen2 shipping-advisory vehicle already exists as an unmerged branch** `fix/ownlint-shipping-advisory` (`75a4c3724`) — it wires `HEXA_OWN_LINT` only, not `HEXA_BORROWCK`.

---

## semantics pick

**Pick (C) — staged hybrid — but with the two axes named honestly, because "Rust-standard safety by default" decomposes into two different claims:**

1. **The discipline axis** (what is *checked*): move/aliasing-XOR-mutation rules enforced at compile time, zero runtime cost. Hexa can reach this **now** — the M3/M4 pass is precise (FP-probe verdict), observe-only (zero codegen change), and already implements the two rules that matter on this substrate.
2. **The stakes axis** (what a violation *costs*): in Rust, a violation is UB — memory unsafety. Under hexa's bump-arena (`self/runtime_core.c:4600-4627`, default-ON `hexa_val_arena_on` :3811), nothing frees mid-scope, returns are heapified, pushes are heapified (:2152-2161). **A borrow violation cannot be a use-after-free today.** The census adjudicated this and it stands: enforcement under the arena is a *correctness lint* (a real one — the aliased-write shape is a live logic-bug class the compiler's own code both exploits and gets bitten by), not memory safety.

So the honest verdicts on your three options:

- **(A) full Rust now = infeasible AND vacuous.** Infeasible: no place projections in MIR `Operand` (`compiler/ir/mir.hexa:55-62`), TypeRef is a name-string (no reference lattice), `&` lexes only as bitwise-and. Vacuous: even a perfect checker enforces against a hazard the allocator makes impossible. Worse, **move-by-default breaks the self-host by construction**: the compiler *deliberately relies* on shared-handle semantics — e.g. `_add_edge` (hir_to_mir.hexa, main): "*`.succs`/`.preds` are shared array handles on the stored Block; pushing to them needs no Block write-back*". You cannot make `let b = a` a move before there is a way to *say* "shared" (`&`-surface), or the compiler can't express its own data structures.
- **(B) alone = real but not the directive.** Default-ON advisory Rule 1+2 catches the actual hazard class by default with zero language change. It is the correct *first* deliverable, but stopping there while calling it "Rust parity" would be theatre: no moves, no borrows, warning-band.
- **(C)** = (B) as the enforcement lane, escalated warn→fatal on the static-types template, **plus the (A) lane explicitly gated on a named prerequisite: PREREQ-X = the `HEXA_STREAM_RECLAIM` free-tree allocator becoming default** (currently gated-live, non-default). PREREQ-X is the exact event that converts the checker from lint to memory-safety, and it is the only thing that ever will. Until it lands, every (A) rung that's buildable early (surface syntax, would-move census) is *preparation*, and should be labeled as such in the PRs.

## ladder

Two lanes. **Lane B (enforcement default-ON — no semantics change)** is the static-types flip replayed (`state/static-types/wall_a_endgame.md` F0→F5); **Lane A (move/borrow semantics)** is gated.

**Lane B — flip `HEXA_BORROWCK` default-ON, advisory→fatal:**

| rung | content | flip criteria / gate |
|---|---|---|
| **B0** (now) | `HEXA_BORROWCK_STRICT=1` opt-in fatal — severity escalation of HX3014 (spec below). Byteeq-neutral flag-OFF. | PR CI byteeq 3-target GREEN (trivial — observe-only) |
| **B0.5** | merge M4 (`feat/own-l3-m4-nll`) + the #4470 `@own` stack. Cross-block coverage is flip-blocking: a default checker escapable by wrapping the write in `if true {}` is theatre. Rule 2 is inert until #4470 lands. | M4's own probe matrix (`xb_write_in_branch` 0→1) |
| **B1** | **corpus census** — the loan pass enumerates its own migration set: run `HEXA_BORROWCK=1` over compiler(389f)/stdlib(2,249f)/self(1,167f) ≈ 1.11M LOC on aiden/summer (M0's vehicle: `aprime_cc dummy.hexa <f> --emit=asm`). Expected O(dozens) per the M3 volume contract (>100 ⇒ classification failed). Triage each hit: true hazard → fix as ordinary PR (the flip's value proof, captured); intended aliasing → restructure or annotate. Also capture compile-time ON-vs-OFF on the largest closure (`bind.hexa`) — ≤2% wall budget, same as static-types F3. | corpus-clean = 0 HX3014, numbers captured |
| **B2** | **vehicle wiring** (see §vehicle) — without it "default" is a lie on the ship path. | gen2 `hexa build` surfaces HX3014; flag-OFF binary byte-identical |
| **B3** | **default-ON, Warning band**: flip `_bck_on` polarity to `env("HEXA_BORROWCK") != "0"` (opt-OUT retained, never `HEXA_NO_BORROWCK` — polarity rule) + default-invoke the check vehicle in `cmd_build`. Two-step per F4/HX3010 precedent: warn-first, observe a cycle. | B1 corpus-clean · byteeq 3-target + faithful + install smoke GREEN · gen2-vs-native diag parity on the corpus · never x86-only green |
| **B4** | **Warning→Error** (catalog severity flip for HX3014, keep `HEXA_BORROWCK=0` escape + consider a `@grace`-style per-site waiver per the HX8004 precedent). | separate follow-on PR, revert-on-RED |

**Lane A — move-by-default + borrows (each rung opt-in, byteeq-neutral OFF):**

| rung | content | gate |
|---|---|---|
| **A1** | `&T`/`&mut T` **surface** via the two sanctioned frozen-seed-safe routes (census §3): type-position name-fold riding the `*T` precedent (`compiler/parse/parser.hexa:374-399`), expr-position `parse_unary` Amp arm as `UnOp text="&"` — **mirrored in `self/parser.hexa` same PR** (two-backend gate; gen2 already reserves `own/borrow/move` as words, `self/bootstrap.hexa:94-97`). No new TokenKind/ExprKind. Buildable pre-PREREQ-X: it's how the self-host will *say* "shared" before B→A migration. | byteeq trivially GREEN while unused; both frontends |
| **A2** | **would-move census mode** (`HEXA_BORROWCK_CENSUS=1`): the loan pass already records every handle-copy edge (`let b = a`, bare-ident aggregate, let arm :2005-2096) — add a counting mode that reports every site whose group is written through ≥2 names or crosses a call. That output *is* the exact self-host/stdlib migration worklist for move-by-default, measured not guessed. | numbers captured, worklist filed |
| **A3** | `HEXA_MOVE_DEFAULT=1` opt-in: `let b = a` on aggregates invalidates `a` (reuse the Rule-2 machinery — a handle-copy becomes a move event) unless RHS is `&a`/`&mut a` (A1 surface). Migrate the A2 worklist file-by-file (self-host first, since gen3≡gen4 must hold at every commit). | corpus-clean under the flag, byteeq, gen2 parity |
| **PREREQ-X** | free-tree allocator (`HEXA_STREAM_RECLAIM`) default flip — **its own campaign, not an ownership rung**; requires the borrow checker at ≥B4 to be *sound enough to trust frees against*, which is the honest mutual dependency. | separate SSOT |
| **A4** | flip `HEXA_MOVE_DEFAULT` default-ON (static-types F5 mechanics). Only meaningful *after* PREREQ-X; before it, A3-opt-in is the ceiling. Place projections (field-disjoint `&mut x.a`/`&mut x.b`) remain a named schema-add cycle — whole-local granularity is the documented ceiling until then. | all-3-target + faithful + install smoke, revert-on-RED |

## vehicle

The gen2 hexat ship path has no MIR and will report 0 forever — porting the loan pass to gen2 would be permanent dual-frontend drift (rejected by `ownlint_shipping_wiring.md` §2a for good reasons: no per-node line/col on gen2 `LetStmt`, highest-blast-radius surface). The sanctioned route is **option (b), which is already implemented for `HEXA_OWN_LINT` on the unmerged branch `fix/ownlint-shipping-advisory`** (`75a4c3724`):

1. **r1**: rebase/extend that branch so the `cmd_build` advisory block (at the flatten/backend seam, `self/main.hexa:~3148`) triggers on `HEXA_BORROWCK` too, forwarding both env vars into the shipped `build/aprime_cc` child (release.yml:19 ships it on all 3 targets). Companion one-liner: un-swallow `_ne` at `self/main.hexa:4431` under the flag — the linux-x86_64 cold `hexa run` path *already runs* aprime_cc by default; the lint fires today and nobody sees it.
2. **r2**: `--emit=check` in `compiler/main.hexa` (exit 0 after the fatal-gate :724-731; reuse the `--emit=obj` empty-atlas branch :651 to dodge the measured ~1.85GB full-atlas RSS) — cuts the double-compile cost before B3 makes the invocation default.
3. **r3 (B3's vehicle half)**: default-invoke the check in `cmd_build`. **Measured blocker to respect**: aprime rc=1 on 2/10 gen2-valid shipping files (l3_m0) — so a two-frontend parse-parity census is a named prerequisite of B3, and the invocation must stay advisory-rc (never gate the build on aprime's own unrelated errors, only on HX3014-band diags once B4 escalates).
4. Warm-cache `hexa run` never re-lints (cache hit = no compile) — documented gap; the eventual answer is a check-verb or cache-key story, out of ladder scope.

## first rung (implementable now)

**B0 — `HEXA_BORROWCK_STRICT=1`: opt-in fatal HX3014.** One file + catalog text + tests; byteeq-neutral flag-OFF; moves the default one notch (establishes the fatal machinery the B4 flip later re-points).

- **Branch off current main** (must include #4503; your checkout predates it).
- **`compiler/lower/hir_to_mir.hexa`**:
  - next to `pub let mut _bck_on = false` (:456): `pub let mut _bck_strict = false`; at the `lower_hir` entry read (:4828): `_bck_strict = env("HEXA_BORROWCK_STRICT") == "1"`, and `_bck_on = _bck_on || _bck_strict` (strict implies on — one flag for users).
  - in `_emit_hx3014` (:592-607): after `diag_emit(b)` and before the `_lr_diag.push`, if `_bck_strict` override the diagnostic's severity to `Severity::Error`. This is explicitly sanctioned by the builder contract — `compiler/diag/builder.hexa:21-22`: "*severity may be overridden later by the caller*". No new catalog code, no HX-number burn. The existing drain fatal-gate (`compiler/main.hexa:832` `_has_errors(_lrd_only)`) then aborts before codegen with zero new plumbing.
- **`compiler/diag/catalog.hexa:380`**: update HX3014's explain (stale-explain is a recorded defect class, L2 r6 lesson) — add one sentence: warning-band by default; `HEXA_BORROWCK_STRICT=1` escalates to a build-refusing error.
- **`compiler/check/borrowck_test.hexa`**: extend the existing probe matrix (it already switches on `HEXA_BORROWCK` at :96/:332) with the strict leg: `hz_write_alias` under STRICT ⇒ rc≠0 / error-band; `fp_arr_alias_read` + `fp_callarg` under STRICT ⇒ rc=0 (precision must survive escalation); flag-OFF sweep byte-identical.
- **Gates**: flag-OFF adds two env reads and one dead bool — emitted binaries byte-identical; run byteeq 3-target + shipping smoke anyway (governance). CHANGELOG.jsonl same change. Build/verify on aiden/summer, mini stays git/gh. No `hexa --help` lockstep needed unless you document the env var there.
- **Explicitly out of B0**: the polarity flip itself (that's B3, gated on the B1 census), M4 merge, #4470 stack.

## honest walls

1. **The arena-vacuous problem is not solved by any of this** — it is *scheduled*. Every Lane-B artifact is a correctness lint until PREREQ-X (free-tree default) lands; PRs must say so. The one framing that makes this not-theatre: Rust's discipline is worth enforcing for logic-bug prevention on shared-handle semantics *today* (measured hazard class), and it is the **precondition** for ever flipping the allocator — you cannot default a reclaiming allocator without an enforced aliasing discipline first. The dependency is mutual and the ladder encodes it.
2. **Move-by-default before `&`-surface is impossible**: the self-host source *depends* on aliasing (`_add_edge` shared-handle comment; the census's `hir_to_mir.hexa:713-716` citation). A1 must precede A3; A3's migration size is unknown until the A2 census runs — do not estimate it, measure it.
3. **Whole-local granularity ceiling**: no place projections in `Operand` (`mir.hexa:55-62`) — `x.a` vs `x.b` disjointness unrepresentable. Tolerable in warning band; **it becomes a false-positive source the moment B4 makes HX3014 fatal**, so the B1 census must specifically count field-disjoint-shaped hits, and if >0 the projections schema-add gets promoted from "someday" to a B4 blocker.
4. **Deliberate false negatives stay**: aliases via fn returns, struct-field/array-element loads, cross-param aliasing, unknown-typed (`"?"`) locals (M3 spec §5.5 — the HIR elem-type drop makes some of these structural). A default-ON checker with documented quiet gaps is honest; one that flood-warns is #4088's corpse. Precision-first polarity stands through the flip.
5. **Rule 2 is inert until the #4470 stack merges** — "default ownership" marketing before that means Rule 1 only.
6. **Vehicle asymmetry is permanent-ish**: gen2 gets the checker only via the aprime advisory child; warm-cache `hexa run` and non-linux cold paths lag. B3's "default" claim must name exactly which verbs/paths surface diagnostics — measured, in the PR body.
