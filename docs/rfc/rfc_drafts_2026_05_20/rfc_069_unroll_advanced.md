# RFC 069 — Advanced loop unroll (factor>2 + non-canonical CFG)

**Status:** DRAFT — Shape-B 1st commit (RFC drafted + RFC-comment-marker
landed; zero behavior change). Multi-cycle phased work. Falsifier
battery defined.

**Author session:** 2026-05-20, off origin/main HEAD `990a9589`.

**Successor to:** PR #117 (`_nvptx_unroll_pass` MVP v2) — landed the
canonical 3-block back-edge loop unroll at factor=2. That pass
recognizes ONE CFG shape: `header → body → header` where header
ends in `STMT_BR_COND(body, exit)` and body ends in
`STMT_BR(header)`. Non-matching CFGs are returned UNCHANGED (honest
passthrough). This RFC defines the cycles that generalize that
pass to multi-factor unroll + multi-shape CFG recognition.

**Predecessor lineage:** RFC 055 (hexa-src → NVPTX codegen backend)
§12 P4+ closure plan. Per the closure note `2026-05-20-rfc055-p4-
followons-v2-closure.md` §"Deferred follow-on follow-ons" item 4
("Unroll factor>2") and item 5 ("Unroll non-canonical CFG shapes"),
both are deferred until this RFC's phases land.

**Scope discipline:** RFC drafted, NOT implementation complete. Per
`@D g3` the closure of THIS RFC requires the P4 numeric falsifier
PASS — none fired here.

---

## §1 Background

PR #117 landed `_nvptx_unroll_pass` with the following recognition
rule (verbatim from the source comment block):

> Pattern recognized:
>   header → body → header   (3-block back-edge)
>
>   Where `header` is a block whose LAST stmt is STMT_BR_COND with
>   `target_block = body.id` (loop-continue arm) and
>   `target_block_else = exit.id` (loop-exit arm); and `body` is a
>   block whose LAST stmt is STMT_BR with `target_block = header.id`
>   (the back-edge).
>
> For factor=2 (start small per the §12 P4+ MVP):
>   ...

Today the pass:
- Recognizes ONE CFG shape (canonical 3-block back-edge).
- Supports ONE factor (2) — the cloning logic and the fresh-LID
  rewriter are hard-coded.
- Returns non-matching CFGs UNCHANGED (honest passthrough).

This RFC keeps those properties as the default while widening the
recognition + factor space.

## §2 Deferred work (carried from #117 closure note)

1. **Unroll factor > 2** — generalize the canonical 3-block matcher
   to factor=N. Requires loop-carried-dependency analysis (or an
   explicit "trust the user" mode) + register renaming per iteration
   unroll.
2. **Unroll non-canonical CFG shapes** — multi-exit (loop with
   `break`), nested (loop-in-loop), while-with-early-return,
   irregular back-edges. Each shape needs a distinct matcher.

## §3 Phasing (4 cycles MIN)

### P0 — Markers (this RFC's scaffold commit)

**This commit's deliverable**, zero behavior change:
- this RFC file
- comment marker at the `_nvptx_unroll_pass` head in
  `compiler/codegen/nvptx_target.hexa` pinning where the
  multi-shape dispatcher will land.

P0 lands no working code.

### P1 — Factor parameterization

**Scope:** the existing pass exposes a `factor: i64` parameter
already (the signature accepts it); P1 extends the cloning logic so
the body is cloned `factor - 1` times (today the hard-coded body
clone runs once for factor=2). Inputs ≥ 5 or negative are clamped
honest-passthrough (no silent garbage).

**Files touched:** `compiler/codegen/nvptx_target.hexa` only.

**Falsifier P1:** `F-RFC069-FACTOR-N` — for the canonical 3-block
fixture from PR #117 Case 10, assert:
- factor=2 PTX byte-identical to the PR #117 output (no regression)
- factor=3 PTX has 3 body bodies + 2 synthetic continue blocks
- factor=4 PTX has 4 body bodies + 3 synthetic continue blocks
- factor=100 (out-of-range) PTX byte-identical to factor=1
  (passthrough — no garbage)

Asserted by substring + count tests in `nvptx_lower_test.hexa`.

### P2 — Multi-exit loop recognition

**Scope:** recognize the CFG shape where `body` has a conditional
break (block ends with `STMT_BR_COND(loop_continue_block, exit)`).
Today this is honest-passthrough; P2 adds a matcher that allows
the break-exit to be a different block than the natural-exit and
clones the body correctly (the break path is per-clone-instance).

**Files touched:** `compiler/codegen/nvptx_target.hexa` only —
add `_nvptx_unroll_multi_exit_match` helper alongside the existing
canonical matcher.

**Falsifier P2:** `F-RFC069-MULTI-EXIT-MATCH` — hand-built MFunc
with a body block carrying `if early_exit_cond { break }`. Assert
the unrolled output preserves the early-exit semantics (each clone
instance's break path goes to the same exit block).

### P3 — Nested loop recognition (1-level depth)

**Scope:** when `body` itself contains a loop matching the canonical
3-block shape, the outer pass leaves the inner loop alone and only
clones the outer body (inner loop included verbatim in each clone).
P3 lands the inner-loop-preservation logic; deeper nesting (2+
levels) is deferred to P5.

**Files touched:** `compiler/codegen/nvptx_target.hexa` only —
add `_nvptx_unroll_contains_loop` helper for the "inner loop
present" check.

**Falsifier P3:** `F-RFC069-NESTED-PRESERVE` — hand-built outer +
inner loop pair. Assert the unrolled output contains the inner
loop's PTX (the `setp.lt.f64` + `bra` instructions) `factor` times,
each instance pointing at a freshly-renamed inner-header label.

### P4 — Real-silicon numeric falsifier

**Scope:** build an end-to-end hexa source program that runs a
factor=4 unrolled kernel + a factor=1 baseline of the same shape +
a multi-exit kernel with early-break + a nested-loop kernel. All
four kernels compute the same output; compare against a hexa-emit
unoptimized baseline (factor=1 + no recognition) on real silicon
(ubu-2 RTX 5070 sm_120 driver JIT).

**Numeric tolerance:** byte-eq on the output buffer (unroll +
shape recognition MUST NOT alter numeric result for in-tolerance
inputs — the optimizer is a perf transform, not a semantic one).

**Files touched:** new fixture `test/rfc069_unroll_e2e.hexa` + host
driver `tool/dispatch_r069_unroll_e2e.sh`.

**Falsifier P4:** `F-RFC069-NUMERIC-EQ` — first GPU-fire falsifier.
Closes THIS RFC.

### P5 — Deferred (deeper nesting, while-with-early-return,
irregular back-edges)

After P4 closes, add deeper-nesting (2+ levels), while-with-early-
return, and irregular back-edge matchers as separate sub-cycles.
Not in P0-P4 scope.

## §4 Falsifier battery

| # | id | phase | type | tooling |
|---|---|---|---|---|
| F1 | F-RFC069-FACTOR-N | P1 | substring + count × 4 | nvptx_lower_test.hexa |
| F2 | F-RFC069-MULTI-EXIT-MATCH | P2 | semantic | nvptx_lower_test.hexa |
| F3 | F-RFC069-NESTED-PRESERVE | P3 | substring + count | nvptx_lower_test.hexa |
| F4 | F-RFC069-NUMERIC-EQ | P4 | byte-eq output, real GPU | ubu-2 ssh fire |
| F5 | F-RFC069-NO-LLVM-NO-CTRANS | (all) | grep | repo-wide |
| F6 | F-RFC069-CPU-CODEGEN-UNTOUCHED | (all) | git stat | byte-identical |
| F7 | F-RFC069-PASSTHROUGH-PRESERVED | (all) | byte-eq | non-matching-CFG case from PR #117 Case 11 MUST remain byte-identical pre-vs-post-RFC-069 (regression guard) |

F5, F6, F7 are continuous gates. F7 is RFC 069-specific (the unroll
pass MUST NOT regress the passthrough guarantee landed by PR #117).

## §5 Non-goals

- **Loop-carried dependency analysis** — the current pass assumes
  the user wrote a loop where unrolling is safe (no aliasing between
  iterations through pointer writes). A real LCD analysis is a
  separate RFC, not in P0-P4 scope.
- **Register pressure analysis** — unrolling factor=N can blow the
  PTX register window. P0-P4 does NOT model register pressure;
  oversized unrolls produce PTX that ptxas may reject. Documented
  honestly as a known limitation.
- **Software pipelining** — interleaving across iterations beyond
  basic body cloning is out of scope.
- **Polyhedral / affine loop transformation** — way beyond this
  RFC's scope.

## §6 Cross-link

- RFC 055 §12 P4+ closure plan
- PR #117 (`_nvptx_unroll_pass` MVP v2) — landed canonical 3-block
  unroll at factor=2 + passthrough guarantee
- PR #138 (RFC 067 draft) + PR #140 (RFC 068 draft) — sibling
  Shape-B RFCs
- `docs/notes/2026-05-20-rfc055-p4-followons-v2-closure.md`
- `compiler/codegen/nvptx_target.hexa` — `_nvptx_unroll_pass` seam

## §7 Honest-scope tag (`@D g3`)

This RFC drafted ≠ advanced unroll implemented. Closure of THIS
RFC = P4 numeric falsifier PASS on real silicon. Until that fires,
the unroll pass landed in PR #117 remains factor=2 + canonical-
shape only. Sub-cycles MAY ship partial PTX (e.g. P1 lands factor=N
without touching the canonical matcher) — each such commit
explicitly reports "P<N> scaffold landed, F<N> measured, F<later>
deferred" and never claims "advanced unroll implemented".

The PR #117 passthrough guarantee (F7 above) is a STRICT regression
gate: every commit on the RFC 069 series MUST keep PR #117's Case 11
output byte-identical.
