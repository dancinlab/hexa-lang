# RFC 068 — Mixed-precision MIR layer (per-Local precision tags + body lowering)

**Status:** DRAFT — Shape-B 1st commit (RFC drafted + RFC-comment-marker
landed; zero behavior change). Multi-cycle phased work. Falsifier
battery defined.

**Author session:** 2026-05-20, off origin/main HEAD `d3f14a59`.

**Successor to:** PR #123 (mixed-precision PTX types scaffold v2) —
landed the `NVPTX_RKIND_F16/_BF16/_F32` register-kind constants,
`_nvptx_reg_{f16,bf16,f32}` helpers (prefixes `%fh` / `%fb` / `%fs`),
classifier rules for the aspirational STMT_BINOP opcodes
`add_f16/_bf16/_f32`, and a smoke test asserting the three reg-decl
banks emit cleanly. That scaffold proves the CLASSIFIER + REG-DECL
pipeline is ready; this RFC defines the cycles that produce the
upstream MIR opcodes those rules consume, and the body lowering
that turns them into real PTX instructions.

**Predecessor lineage:** RFC 055 (hexa-src → NVPTX codegen backend)
§12 P4+ closure plan. Per the closure note `2026-05-20-rfc055-p4-
followons-v2-closure.md` §"Deferred follow-on follow-ons", the
mixed-precision MIR layer + body lowering are 2 deferred items
(items 2 + 3); this RFC bundles them because the MIR layer's
correctness gate inherently requires the body lowering to
produce real PTX.

**Scope discipline:** RFC drafted, NOT implementation complete. Per
`@D g3` (honesty-obligation) the closure of THIS RFC requires the
P4 numeric falsifier PASS on real silicon — none fired here.

---

## §1 Background

PR #123 landed the scaffold seam: `_nvptx_classify_local_for_stmt`
routes STMT_BINOP Locals with op ∈ {`add_f16`, `add_bf16`, `add_f32`}
to the matching RKIND, the reg-name helper emits `%fh<id>` / `%fb<id>`
/ `%fs<id>` with the per-bank prefix, and `_nvptx_kind_to_ptx_ty`
returns `.f16` / `.bf16` / `.f32` for the `.reg` declaration.

The smoke test (Case 13 in `nvptx_lower_test.hexa`) is a single-block
MFunc with three hand-built binops carrying the new op names. The
emitted PTX correctly declares `.reg .f16 %fh3;`, `.reg .bf16 %fb4;`,
`.reg .f32 %fs5;`. The BODY of each binop is currently a 055-P0-style
"unsupported binop" stub — `_nvptx_lower_stmt` STMT_BINOP branch only
knows the f64 mnemonics (`add.f64`, `sub.f64`, `mul.f64`).

Today, NO upstream layer EMITS the new op names. `hir_to_mir.hexa`
classifies every arithmetic source expression as f64 (the RFC 055
§6.6 first-slice baseline). The new op names are reachable only via
hand-built test fixtures. This RFC closes both gaps.

## §2 Deferred work (carried from #123 closure note)

1. **MIR layer that PRODUCES `add_f16/_bf16/_f32` opcodes** —
   `hir_to_mir.hexa` currently emits `add` (untyped, classified as
   f64 downstream). A per-Local precision tag must be threaded
   through HIR → MIR so the lowering knows which suffix to emit.
2. **Body lowering for the new opcodes** — `_nvptx_lower_stmt`
   STMT_BINOP branch must learn `add.f16 / .bf16 / .f32` (and the
   sub / mul / fma siblings) so the body text matches the
   `.reg` decl tag.

## §3 Phasing (4 cycles MIN)

### P0 — Markers (this RFC's scaffold commit)

**This commit's deliverable**, zero behavior change:
- this RFC file
- comment markers at the 2 seams where P1+ will land:
  1. `compiler/lower/hir_to_mir.hexa` near where binop opcodes are
     selected (`add` / `sub` / `mul` etc.) — RFC 068 P1 will add a
     precision-tag dispatcher here.
  2. `compiler/codegen/nvptx_target.hexa` STMT_BINOP body branch —
     RFC 068 P3 will extend the mnemonic emit beyond f64.

P0 lands no working code; it pins the scaffold seams.

### P1 — Per-Local precision tag (HIR → MIR thread)

**Scope:** add a `precision: string` field to `Local` (`compiler/ir/mir.hexa`)
defaulting to `""` (= classifier-driven, i.e. legacy f64-default
behavior). When a HIR expression carries an explicit precision
annotation (`@f16` / `@bf16` / `@f32`), `hir_to_mir.hexa` propagates
it to the Local for the result of that expression.

**Files touched:**
- `compiler/ir/mir.hexa` — Local struct field
- `compiler/lower/hir_to_mir.hexa` — propagation
- `compiler/codegen/nvptx_target.hexa` — `_nvptx_classify_local_for_stmt`
  reads the new field BEFORE falling through to the op-name rules

**Falsifier P1:** `F-RFC068-PRECISION-PROPAGATE` — given an HIR
fixture with one `@f16 a + b` expression, the resulting MIR Local
for the dst must have `precision = ".f16"`. Asserted by a per-Local
inspection test in a new `compiler/lower/hir_to_mir_test.hexa`
fixture (or extension of the existing `mir_test.hexa` if present).

### P2 — STMT_BINOP op-name generation from precision tag

**Scope:** when `hir_to_mir.hexa` materializes a STMT_BINOP whose dst
Local has `precision != ""`, the emitted op-name carries the suffix
(e.g. `add_f16` rather than the plain `add`). This is the seam that
connects RFC 068's HIR/MIR work to RFC 123's existing classifier
rules — once P2 lands, the f16/bf16/f32 reg-banks become reachable
from real source code, not just test fixtures.

**Files touched:** `compiler/lower/hir_to_mir.hexa` only.

**Falsifier P2:** `F-RFC068-OPCODE-SUFFIX` — same fixture as F1, but
asserts the MIR STMT_BINOP statement's `op` field is `add_f16` (not
`add`). Substring assert.

### P3 — Body lowering (`_nvptx_lower_stmt` STMT_BINOP mnemonic emit)

**Scope:** extend the STMT_BINOP body emit beyond `add.f64`. The
mnemonic dispatcher reads the dst Local's precision tag (or, equivalently,
its classified RKIND) and emits the matching PTX op:

| precision | add | sub | mul | fma |
|---|---|---|---|---|
| `.f16` | `add.f16` | `sub.f16` | `mul.f16` | `fma.rn.f16` |
| `.bf16` | `add.bf16` | `sub.bf16` | `mul.bf16` | `fma.rn.bf16` |
| `.f32` | `add.f32` | `sub.f32` | `mul.f32` | `fma.rn.f32` |
| (default `.f64`) | `add.f64` | `sub.f64` | `mul.f64` | `fma.rn.f64` |

**Files touched:** `compiler/codegen/nvptx_target.hexa` only.

**Falsifier P3:** `F-RFC068-BODY-MNEMONIC` — extend the existing
Case 13 in `nvptx_lower_test.hexa`: assert the body emits `add.f16
%fh3, %fh1, %fh2;` (not the current "unsupported binop" stub).
Substring assert × 3 (one per dtype).

### P4 — Real-silicon numeric falsifier

**Scope:** build an end-to-end hexa source program that adds two
f16 arrays element-wise, lower through HIR → MIR → PTX → ptxas →
real-silicon execute (ubu-2 RTX 5070 sm_120 driver JIT). Compare
output against a hexa-emit f64-baseline computation on the same
inputs (input arrays first cast to f64 outside the kernel).

**Numeric tolerance:** f16 add has ≤1 ULP error per operation. For
the smoke kernel (single add per element), assert max absolute
error ≤ 2× f16-ULP ≈ 2 · 2^-10 · max(|out|) — a defensible bound for
an f16-FMA-free single-add fixture.

**Files touched:** new fixture in `test/rfc068_f16_vec_add.hexa` +
host driver in `tool/dispatch_r068_f16_smoke.sh` (mirror of
`tool/dispatch_r055_p2_gemm.sh` from PR #82).

**Falsifier P4:** `F-RFC068-NUMERIC-EQ` — first GPU-fire falsifier.
Closes THIS RFC.

### P5 — Mixed-family arithmetic (deferred)

After P4 closes, add fp16-multiply-with-f32-accumulator and the
type-conversion ops (`cvt.f32.f16` etc.) as separate mnemonic-table
extensions. Not in P0-P4 scope.

## §4 Falsifier battery

| # | id | phase | type | tooling |
|---|---|---|---|---|
| F1 | F-RFC068-PRECISION-PROPAGATE | P1 | per-Local field assert | hir_to_mir test |
| F2 | F-RFC068-OPCODE-SUFFIX | P2 | substring | hir_to_mir test |
| F3 | F-RFC068-BODY-MNEMONIC | P3 | 3× substring | nvptx_lower_test.hexa |
| F4 | F-RFC068-NUMERIC-EQ | P4 | numeric, real GPU | ubu-2 ssh fire |
| F5 | F-RFC068-NO-LLVM-NO-CTRANS | (all) | grep | repo-wide |
| F6 | F-RFC068-CPU-CODEGEN-UNTOUCHED | (all) | git stat | byte-identical |

F5 and F6 are continuous gates (per RFC 055 §7 + RFC 067 §4).

## §5 Non-goals

- **Source-level mixed-precision autotuning** — picking which Locals
  should be f16 vs f32 is an optimizer concern, not a codegen one.
  RFC 068 only delivers the emit/lower side; the picker is a future
  RFC.
- **CPU-side mixed-precision lowering** — F6 explicitly forbids
  changes to the CPU codegen backends. f16/bf16 on CPU targets is a
  separate RFC.
- **8-bit / 4-bit dtypes (int8, int4, fp8 e4m3 / e5m2)** — different
  reg-bank story (typically packed into u32 with masking). Future
  RFCs.
- **NaN / Inf handling parity with FP64** — f16 has a much narrower
  exponent range; numerically-divergent edges (overflow → Inf,
  underflow → 0, denormal flush) are out of scope for the P4
  smoke fixture.

## §6 Cross-link

- RFC 055 §12 P4+ closure plan
- PR #123 (mixed-precision scaffold v2) — landed `NVPTX_RKIND_F16/
  _BF16/_F32` + classifier rules + reg-name helpers
- PR #138 (RFC 067 draft) — sibling Shape-B for WMMA emit
- `inbox/notes/2026-05-20-rfc055-p4-followons-v2-closure.md`
- `compiler/codegen/nvptx_target.hexa` — scaffold seams (this
  RFC adds upstream HIR-side seams)
- `compiler/lower/hir_to_mir.hexa` — RFC 068 P1 seam
- NVIDIA PTX ISA §9.7.4 (FP arithmetic) for the mnemonic table

## §7 Honest-scope tag (`@D g3`)

This RFC drafted ≠ mixed-precision implemented. Closure of THIS
RFC = P4 numeric falsifier PASS on real silicon. Until that fires,
the f16/bf16/f32 reg-banks landed in PR #123 remain test-fixture-
only reachable. Sub-cycles MAY ship partial PTX (e.g. P1 lands the
HIR→MIR precision-tag thread without changing any emitted PTX)
— each such commit explicitly reports "P<N> scaffold landed, F<N>
measured, F<later> deferred" and never claims "mixed-precision
implemented".
