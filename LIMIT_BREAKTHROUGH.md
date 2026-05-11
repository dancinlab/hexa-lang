<!-- @created: 2026-05-12 -->
<!-- @scope: real-limits audit (Wave M) — programming-language design / compiler / type system limits -->
<!-- @authority: applies LATTICE_POLICY.md §1.2 taxonomy verbatim -->
---
type: limit-breakthrough-audit
wave: M
session: 2026-05-12
parent_policy: LATTICE_POLICY.md §1.2
applies_to: hexa-lang — native compiler, atlas-bound type system, multi-target codegen
---

# LIMIT_BREAKTHROUGH.md — hexa-lang real-limits audit (Wave M)

> **Question**: hexa-lang is a native compiler with an atlas-bound type
> system. Its real walls are **computability, parsing complexity classes,
> type-system expressiveness, and toolchain reach**. Which can be broken?

---

## §1 Domain identification

| Layer | Verbs (representative) | Concern |
|-------|------------------------|---------|
| Frontend | `compiler/lex`, `parse`, `resolve`, `bind`, `types`, `domain`, `units`, `citation` | Source-to-AST + typecheck |
| Atlas | `atlas/` (4.2 MB baked-in theorem dictionary) | Citation-mandatory build gate |
| Middle | HIR → mono → MIR (SSA) | Lowering |
| Backend | optimize → regalloc (LIR) → emit (asm) → `hexa_ld` v1.1 | Native binary, no LLVM |
| Targets | ELF64 + Mach-O arm64 static; ESP32, FPGA WGSL | HW-deployable per G3 |
| Proof | SAT solver for "consciousness laws" formal verification | G2 |

The language deliberately rejects LLVM and C-transpile. Every formula
must cite the atlas or the build refuses. This pushes a number of
classical PL limits to the front.

---

## §2 Real limits applicable to hexa-lang

### 2.1 Halting / Rice's theorem (MATHEMATICAL)

Any non-trivial *semantic* property of a hexa program — termination,
side-effect freedom, "consciousness compliance" — is undecidable in
general. The compiler can only verify *syntactic + structural*
properties of source code (cf. `compiler/types`, `compiler/domain`).

### 2.2 Parsing-class complexity (MATHEMATICAL)

Context-free parsers run in O(n³) worst case (CYK/Earley) or O(n) for
deterministic LL(k) / LR(k) subclasses. Adding context-sensitivity
(citation resolution from atlas — `compiler/citation` stage S8)
pushes worst-case beyond CF; full Turing-equivalence is reached when
macros / `comptime` are allowed.

### 2.3 Type-system decidability vs. expressivity (MATHEMATICAL)

Strong type systems trade decidability for expressivity. ML-style
HM is decidable; full dependent types (Coq/Agda/Lean 4) require
proof search that is in general undecidable. hexa-lang's `compiler/types`
+ atlas-citation hybrid sits in a middle band.

### 2.4 PAC-learning sample-complexity (MATHEMATICAL)

For hexa-lang's M0 / wilson-build self-test infrastructure to
*certify* the language is "production-grade", empirical pass rates
need power analysis. With 110 tests in `stdlib/semver.hexa` etc.,
detecting a regression rate < 1% reliably needs ~300 independent
test executions per release.

### 2.5 Atlas size vs. compile-time memory (ENGINEERING)

4.2 MB baked-in atlas → 4.2 MB extra resident-set during compilation,
~100 ms cold-start atlas-load. Scales linearly with atlas growth. At
50 MB atlas, compile-time RSS budget becomes a deployment limit on
embedded targets (ESP32 has 8 MB SPI flash, ~520 KB SRAM — cannot
self-host).

### 2.6 Cross-target toolchain reach (ENGINEERING)

Self-hosting is per-target: ELF64-Linux + Mach-O-arm64 today. Adding
WGSL / FPGA / ESP32 each costs ~3-6 engineer-months for tested
codegen. Windows PE32+ not yet shipped.

### 2.7 SAT solver compute envelope (MATHEMATICAL / ENGINEERING)

G2 "proof-verified consciousness laws" depends on SAT (or SMT)
solving. SAT is NP-complete; modern CDCL solvers handle ~10⁶
variables on tractable instances. Hexa-specific encodings: the
larger the "consciousness law" formula, the steeper the wall —
exponential in adversarial-but-realistic cases.

### 2.8 Community / contributor pool (ENGINEERING)

G6 "Community-alive" depends on the global pool of developers
willing to learn a non-mainstream language. Rust (~3 M devs), Go
(~2 M), Swift (~1 M); novel-lang adoption-curve half-life ≈ 5-10 yr
for languages that *do* take off; ≈ 2 yr for ones that don't.
First-external-contributor milestone (G6) is the leading indicator.

---

## §3 Per-limit breakthrough assessment

### 3.1 Halting / Rice → **HARD_WALL**

Cannot break. **Mitigation**: structurally restrict the language to
**total** functional fragments where termination is decidable
(à la Agda's well-founded recursion). hexa-lang already does this
partially via the atlas-citation requirement. Trigger for further
narrowing: add `--total` mode that rejects unbounded recursion
without a measure proof. Status: **not implemented**.

### 3.2 Parsing complexity → **SOFT_WALL** (LL(k) / GLR break it)

If the grammar stays in LR(1), parse-time is O(n) — practically
limitless. If `comptime` / macros are added (G4 ecosystem push), the
class shifts. Trigger: keep the **kernel grammar** in LR(1) and
expose macros only via a separate elaboration phase that runs after
the LR(1) parse completes. Status: **already in-place** per
`compiler/parse` stage S1.

### 3.3 Type-system decidability ↔ expressivity → **SOFT_WALL** (gradual typing breaks the trade-off)

The trade-off is real but admits an engineering compromise: **gradual
typing** (Siek & Taha 2006) lets dependent fragments live inside an
otherwise decidable type-checker, with run-time contract checks at
the boundary. Trigger: scaffold a `compiler/types/dependent_island`
that supports inductive families + termination proofs in a contained
sub-language. Status: **research-ready, not designed in**.

### 3.4 PAC sample-complexity → **BREAKABLE_WITH_TECH (mutation testing)**

Add `tests/mutation/` — automated mutant generation. Each mutant is
an independent sample for the test suite's discriminative power.
Standard tooling (mutmut / Pitest) generates 10⁴-10⁵ mutants per
codebase. Trigger: shipped mutation-testing harness producing a
*mutation score* per release. **Engineering-bounded.**

### 3.5 Atlas size → **BREAKABLE_WITH_TECH (lazy-loading + shared-image)**

Trivially: lazy-load atlas sections at compile-time + a shared
memory-mapped image across compiler invocations. Trigger:
`atlas/lazy_load.hexa` + `--atlas-mmap` flag. ~1 engineer-month;
flat win for embedded self-hosting.

### 3.6 Cross-target reach → **BREAKABLE_WITH_TECH**

Pure engineering. Adding Windows PE32+, RISC-V64-Linux, and bare-metal
ARMv7-M each costs ~3 engineer-months. No physics, no math; just
elbow-grease. Trigger: vendor-funded port (common pattern in
new-lang adoption).

### 3.7 SAT/SMT compute envelope → **SOFT_WALL** (portfolio + structure)

NP-complete is HARD in worst case but practically broken by
portfolio solvers + structural decomposition (treewidth-bounded
encodings solvable in linear time). Trigger: hybrid CDCL + tree-DP
encoder for "consciousness law" verification, ~6 engineer-months.
Status: **single-solver today**.

### 3.8 Community pool → **BREAKABLE_WITH_TECH (positioning + docs)**

Languages that broke through (Rust, Go, Swift) shared three
attributes: corporate backer, killer-use-case ("memory-safety", "easy
concurrency", "iOS"), and exceptional docs. hexa-lang's killer-case
is **atlas-binding (citation-mandatory builds)** — uniquely
defensible. Trigger: ship a 200-page *Hexa Book* + 1-day workshop
package by Q4-2026. Status: **partial — G6 at 100% per README, but
external-contributor count not yet visible**.

---

## §4 Top-3 breakthrough opportunities

### #1 — Mutation-testing harness (§3.4)

Largest immediate quality lever. Converts the existing M0 / wilson-build
suites from "passes its own tests" to "passes adversarially-mutated
tests" — closes the PAC-power gap. ~1 engineer-month.

### #2 — Gradual dependent-typing island (§3.3)

Differentiates hexa-lang from Rust / Go / Swift at the type-system
layer without committing to full Lean-class proof obligations on
every program. Aligns with G2 (proof-verified) without sacrificing
G3 (HW-deployable). ~6 months.

### #3 — Windows PE32+ + RISC-V64-Linux backend (§3.6)

Pure adoption lever. Pulls hexa-lang from "ELF + macOS arm64" to
"runs on every laptop a 2026 contributor owns". G6
"first-external-contributor" probability lifts measurably with each
target. ~6 engineer-months total.

---

## §5 Honest caveats

1. **Halting / Rice are HARD_WALLs by definition** (§3.1). No
   imaginable tech breaks them. Mitigation is scoping. Honest.

2. **Atlas-binding is the differentiator, not a limit-breakthrough**.
   It does not violate any of the §2 limits; it *restricts the
   programs you can write* in exchange for citation provenance.

3. **G6 community claim at 100%** in the README is an internal
   self-grading. The §2.8 wall is *external*: first non-lab
   contributor, retention curve, package-registry uptake. These are
   the real metrics.

4. **No NDA / proprietary content** — all limits are general PL theory.

5. **No n=6 lattice in §2** by policy.

6. **Compiler self-hosting is per-target.** Self-hosting on
   ELF64-Linux is not self-hosting on ESP32. The README's 100%
   claim is per-target.

---

## §6 References

- `LATTICE_POLICY.md` §1.2 — taxonomy
- `SPEC.md`, `SPEC.yaml` — language spec
- `PLAN.md` — phase / goal definitions (G1-G6)
- `compiler/` — frontend + middle + backend stages
- `tests/m0/`, `verify/wilson-build/` — current test infrastructure
- External: Rice (1953), Hindley-Milner (1969), Siek & Taha (2006)
  *Gradual Typing for Functional Languages*, Marques-Silva & Sakallah
  (1999) *GRASP CDCL*, Robert Harper *Practical Foundations for
  Programming Languages* (2016).

---

*End of LIMIT_BREAKTHROUGH.md (hexa-lang, Wave M).*
