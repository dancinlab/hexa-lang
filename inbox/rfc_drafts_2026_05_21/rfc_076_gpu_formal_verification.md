# RFC 076 — GPU.md §6b Formal-Verification Closure Plan (PTX equivalence · regalloc · loop-unroll)

- status: **DRAFT — research + scoped plan only · zero proof code in this cycle**
- created: 2026-05-21
- category: formal methods / GPU codegen
- authority:
  - `GPU.md` §6b "Formal / semantic" — 3 unchecked boxes
  - `AGENTS.tape` `@F f2` (hexa-native-only — no LLVM dependency)
  - `AGENTS.tape` `@D g3` (honesty obligation — real-limit anchor, no over-claim)
  - `AGENTS.tape` `@D g6` (citation-enforced strict-lint — `@cite` on every theorem)
- supersedes / extends: RFC 055 (hexa-src → NVPTX), RFC 067 (WMMA emit),
  RFC 068 (mixed-precision MIR), RFC 069 (advanced unroll) — this RFC adds
  the formal-semantics tier above their byte-eq testing tier.
- non-goal: producing any Coq / Lean / Idris proof code in this cycle.
  This RFC is research + planning only. Proof-code commits land in
  successor RFCs (per-row).

---

## 1 — Problem

`GPU.md` §6b carries three unchecked formal-verification boxes:

```
- [ ] PTX emit semantic equivalence proof — Coq/Lean proof that codegen preserves MIR semantics
- [ ] Register allocation correctness — formal proof that allocation never aliases live ranges
- [ ] Loop-unroll preservation — proof that unrolled CFG ≡ original CFG semantically
```

Each box already has **testing evidence**:

- **PTX emit**: `compiler/codegen/nvptx_emit_test.hexa` byte-eq corpus,
  `compiler/codegen/nvptx_lower_test.hexa` Case 1–N MIR→PTX fixtures,
  silicon-fire results on RTX 5070 (10 fires through 2026-05-20).
- **Regalloc**: `_nvptx_classify_locals` (`compiler/codegen/nvptx_target.hexa:1164`)
  + the `ptxas -v` register-count scan integrated into `hexa gpu lint`
  (PR #221, 2026-05-20).
- **Unroll**: `F-RFC069-PASSTHROUGH-PRESERVED` byte-eq regression
  (`compiler/codegen/nvptx_lower_test.hexa:1729`), `F-RFC069-LOAD-STORE-EQ`,
  the RFC 069 P1–P3 unroll-pass test corpus.

Per `@D g3` (honesty obligation), **testing evidence ≠ formal proof**.
Byte-eq + silicon-fire establish **sound-but-unverified** confidence;
they cannot rule out an adversarial input that hits a codegen path the
test corpus missed. The §6b boxes ask for the next tier:
**universally-quantified proofs** that all well-typed MIR programs
preserve semantics through the relevant codegen step.

This RFC scopes that work realistically, names the minimum-viable closure
contract per row, and identifies the **cheapest row to close first**.

---

## 2 — Scope

**In:**
- Survey of existing GPU / PTX formal-verification work (§3).
- Per-row minimum-viable closure contract — exactly which lemma flips
  the `[ ]` to `[x]` (§5).
- Effort estimate (LoC + person-months) per row, honest, drawing on
  the surveyed prior art (§6).
- Proof-tool selection rubric — Coq / Lean 4 / Isabelle / spec-only-no-prover (§7).
- Cheapest-row-first ordering for incremental closure (§8).

**Out:**
- Writing any actual Coq / Lean source code. Successor RFCs (one per row)
  handle that, after this scoping RFC has been reviewed.
- Memory-consistency model proofs (Alglave-style axiomatic relaxed memory).
  Those are an ORDER OF MAGNITUDE more work than equivalence proofs and
  are already on §6b's `[ ]` race-detection / memory-ordering rows under
  §6c, not §6b. This RFC stays inside §6b's three boxes.
- Bit-exact floating-point equivalence (deferred to §6a's IEEE 754 row;
  the §6b row asks for *semantic* equivalence, not bit-identity).

---

## 3 — Prior-art survey (literature 2019 – 2025)

### 3a — PTX formal semantics (most-cited works)

| year | work | scope | proof tool | proof effort | applicability to hexa-emit |
|------|------|-------|------------|--------------|-----------------------------|
| 2019 | **CUDA au Coq** (Ferrell · Hamlen, DATE'19, [pdf](https://personal.utdallas.edu/~hamlen/ferrell19date.pdf)) | PTX pseudo-assembly operational semantics as inductive Coq types | Coq | not published as LoC; described as "tractable proofs for hand-written kernels" | **HIGH** — gives a ground-truth PTX semantics we can target; predates RFC 055's PTX subset so requires extension for `wmma.*`, `cp.async`, `bar.sync` (none of which CUDA au Coq covers). |
| 2019 | **A Formal Analysis of the NVIDIA PTX Memory Consistency Model** (Lustig et al., ASPLOS'19, [pdf](https://d1qx31qr3h6wln.cloudfront.net/publications/ASPLOS_2019_PTXMemoryModel.pdf)) | Axiomatic relaxed-memory model for PTX, validated by NVIDIA's architecture team. Empirically tested via Alloy, machine-checked via Coq. | Alloy + Coq | months — small team, single paper | **MEDIUM** — the relaxed-memory part is overkill for §6b equivalence (which is per-thread); but the per-instruction effect rules in §4 of the paper are reusable as the operational semantics for `ld.*` / `st.*` / `bar.*`. Hexa's emitted kernels currently use `.sys` scope only → falls inside the paper's "one scope" sweet spot. |
| 2025 | **Cuq — MIR-to-Coq Framework Targeting PTX for Formal Semantics and Verified Translation of Rust GPU Kernels** ([GitHub](https://github.com/neelsomani/cuq), [HN](https://news.ycombinator.com/item?id=45674126)) | Rust MIR → Coq + a PTX-flavored event layer aligned with Lustig 2019; PTX subset = global mem only, no shared mem, no FP NaN/rounding reasoning, one acquire/release pair at SYS scope | Coq | undisclosed; "per-event and per-trace shape correctness" proved as "stepping stones"; load_ok / store_ok lemmas incomplete | **VERY HIGH** as an architectural template — Cuq's MIR-event abstraction is structurally the same shape as hexa's MIR→PTX lower; hexa is in the same boat (subset of PTX, similar event surface). Cuq's incomplete state honestly anchors our effort estimate: even a well-funded research project has not closed end-to-end soundness after multiple iterations. |

### 3b — Verified general-purpose compilers (analogy tier)

| year | work | relevance | proof effort |
|------|------|-----------|--------------|
| 2009 → present | **CompCert** (Leroy et al., [main](https://compcert.org/), [backend pdf](https://xavierleroy.org/publi/compcert-backend.pdf)) | Verified C → x86/ARM/RISC-V/PowerPC backend in Coq; **no GPU target** but the CFG-equivalence + simulation-relation pattern is the canonical recipe | Total compiler ~100,000 LoC of Coq; **register allocation alone = 4,300 lines** for the validator + **10,000 lines** for graph-coloring lemma ([INRIA blog](https://cambium.inria.fr/blog/register-allocation/)) |
| 2013 → present | **Vellvm / Verified LLVM** ([UPenn site](https://www.cis.upenn.edu/~stevez/vellvm/), [NFM'25](https://www.cis.upenn.edu/~stevez/papers/nfm25.pdf)) | LLVM IR formal semantics in Coq using interaction trees; gives us an analogy template for SSA-IR semantics if we ever lift MIR to SSA | "covers most of the core sequential fragment of LLVM IR 14.0.0" — multi-person-year effort across 10+ years; explicit "informal LLVM remains informal" honesty box in the 2025 paper |
| 2014 | **Fully Verified SSA-based Middle-end for CompCert** ([ResearchGate](https://www.researchgate.net/publication/262311695_Formal_Verification_of_an_SSA-based_Middle-end_for_CompCert)) | Verifies SSA-form middle-end optimization passes including a sparse SSA-based register allocator | comparable to CompCert RA: thousands of Coq LoC per pass |
| 2021 | **Alive2 — Bounded Translation Validation for LLVM** (Lopes · Lee · Hur · Regehr, PLDI'21, [pdf](https://users.cs.utah.edu/~regehr/alive2-pldi21.pdf)) | SMT-based translation validation, not full proof. Found 47 LLVM bugs unit-test sweep, 21 memory-opt bugs | NOT a Coq proof; uses Z3. Tool itself ~50k C++ LoC. But the *idea* — per-transformation SMT refinement check — is portable to hexa-emit at much lower cost than Coq. |
| 2024 | **Verifying Peephole Rewriting in SSA Compiler IRs** (Bhat et al., ITP'24, [arxiv](https://arxiv.org/pdf/2407.03685)) | Lean 4 framework for verifying SSA peephole rewrites; covers regions; semantic refinement w.r.t. poison values | Lean 4 + MLIR import; "scaffolding" published; example rewrites in the paper's appendix |

### 3c — Loop-unroll formal verification

| year | work | relevance |
|------|------|-----------|
| 2009 | **Verified Validation of Lazy Code Motion** (Tristan · Leroy, PLDI'09, [pdf](https://jtristan.github.io/papers/pldi09.pdf)) | Translation-validator pattern: validator small + verified, transformation big + unverified. Exactly the pragmatic template for §6b loop-unroll. |
| 2025 | **Loop unrolling: formal definition and application to testing** (Isabelle, [arxiv 2502.15535](https://arxiv.org/pdf/2502.15535)) | Isabelle-mechanized formal properties of unrolling; proves unrolled-loop ≡ original-loop equivalence as a meta-theorem. **Directly applicable** if we accept Isabelle. |

### 3d — Register-allocation correctness

CompCert's RA proof effort (§3b row 1) is the canonical reference.
Two architectural choices visible in the literature:

- **Direct verification** — prove the allocator itself correct.
  CompCert IRC = 4,800 lines (10k lemma + 4.3k pass).
- **Validator pattern** — write any allocator, then check its output
  with a verified validator. Substantially cheaper; CompCert uses it
  for the graph-coloring step.

For hexa's current `_nvptx_classify_locals` (single-pass type-based
classifier — each MIR Local picks exactly one PReg kind from
`{U32, U64, F32, F64, B16x16}` based on use sites), the validator
pattern is overkill: **hexa's regalloc isn't a graph-coloring problem
yet**. It's a syntax-directed classifier. This dramatically lowers
the proof bar — see §5b.

---

## 4 — Architectural constraints (the hexa-lang context)

- **No LLVM** (`@F f2`) → CompCert's LLVM-IR bridge is unavailable.
  Vellvm and Alive2 are inspirations, not dependencies.
- **No C-transpile architecture** (`@F f2`) → cannot reuse CompCert's
  C front-end. But CompCert's `RTL` / `LTL` / `Mach` back-end pass
  structure IS reusable as an analogy — hexa's MIR → PTX is structurally
  closer to CompCert's RTL → Mach than to its C → Clight.
- **Hexa-native-only** (`@D g5`) → the proof artifact lives in a proof
  assistant (Coq / Lean / Isabelle), NOT inside the hexa compiler.
  The proof artifact is an *external claim* that the compiler — written
  in hexa — implements a specified MIR-to-PTX function. It does not
  need to be re-implemented in hexa. The `@cite` strict-lint policy
  (`@D g6`) is honored by citing the proof file from the relevant
  codegen line, exactly as we cite atlas theorems today.
- **Citation-enforced strict-lint** (`@D g6`) → once a row's proof
  lands, the corresponding codegen lines get `@cite RFC076::ptx_eq_thm`
  markers; strict-lint stage 4 enforces presence.
- **Real-limit anchor** (`@D g3`) → the verification anchor here is
  IEEE 754 binary32 arithmetic well-definedness (§5a) + SSA dominance
  well-definedness (§5b) + small-step operational semantics
  termination (§5c). All three are real-math limits, not lattice
  tautologies.

---

## 5 — Per-row minimum-viable closure contracts

For each `GPU.md` §6b row, this section defines **exactly** what
theorem statement makes the `[ ]` flip to `[x]`. The theorem must be
machine-checked (Coq / Lean / Isabelle accepted). The statement is
NARROW on purpose — full equivalence is multi-person-year work; we
scope to the minimum that retires the box without over-claiming.

### 5a — PTX emit semantic equivalence proof

**Honest scope:** universal equivalence over ALL MIR programs is
multi-person-year (Cuq has not closed it after multiple iterations,
§3a row 3). We pick a SINGLE-OPCODE-CLASS theorem.

**Minimum-viable theorem (`MVT-5a`):**

> For every MIR program `P` of the shape
>   `ld(addr_a) → reg_t0`
>   `ld(addr_b) → reg_t1`
>   `add f32 reg_t0 reg_t1 → reg_t2`
>   `st(reg_t2) → addr_c`
> and every input memory `M` mapping `addr_a, addr_b` to IEEE 754
> binary32 values, the emitted PTX kernel (using `_nvptx_lower_stmt`
> on this MIR shape), executed under the per-instruction PTX
> operational semantics of Lustig 2019 §4 + Ferrell-Hamlen 2019 §3,
> produces a final memory `M'` such that `M'(addr_c) = M(addr_a) ⊕_f32 M(addr_b)`,
> where `⊕_f32` is IEEE 754 binary32 addition.

**Why this scope:** it is the simplest non-trivial @gpu kernel shape
(the very vec-add fixture we have silicon-measured), it touches the
three core operand classes (memory, register, immediate), and it
exercises the `_nvptx_classify_locals` → `_nvptx_lower_stmt` →
PTX text-emit pipeline end-to-end on the FP path. Closing it
demonstrates the proof architecture works; subsequent successor RFCs
extend per-opcode-class (one RFC per `{int, fp, mma, ld/st-shared}`).

**Real-limit anchor (`@D g3`):** IEEE 754-2019 binary32 + Lustig 2019
PTX per-instruction semantics. No lattice tautology.

**Effort estimate (§6 detail):** 1–2 person-months Coq once the PTX
opcode subset is formalized; 4–6 person-months if PTX opcode subset
formalization is included (it is — `wmma`, `cp.async`, `bar.sync`
are NOT in Ferrell-Hamlen 2019).

### 5b — Register-allocation correctness

**Honest scope:** hexa's `_nvptx_classify_locals` is a syntax-directed
classifier, not a graph-coloring allocator. The classifier rule is
roughly:

> For each MIR Local `L`, walk the function body once; classify `L`
> by inspecting the first use site that fixes its kind (operand class
> + dtype). Emit one PReg row per Local. If multiple use sites disagree,
> the LAST classification wins (and this is the bug surface).

**Minimum-viable theorem (`MVT-5b`):**

> Let `C : MFunc → [PReg]` be the function `_nvptx_classify_locals`.
> For every well-typed MFunc `mfn`, `C(mfn)` is a function (in the
> mathematical sense) from `Local.id` to `PReg.kind` — i.e. each
> `Local.id` appearing in `C(mfn)` maps to exactly one `PReg.kind`,
> never two distinct kinds.

**Why this scope:** this is "the classifier rule is well-defined,"
which is the live-range-no-alias property phrased in hexa's actual
representation. Note this is much weaker than CompCert's graph-coloring
correctness (4.3k LoC) precisely because hexa's allocator is much
weaker than CompCert's. **This is the cheapest row to close.**

**Real-limit anchor:** function well-definedness (every input maps
to one output) — basic set-theoretic real limit, not a lattice rule.

**Effort estimate:** 1–3 person-weeks in Lean 4 (assuming we model
MFunc / Stmt / Local / PReg as inductive types, define `_nvptx_classify_locals`
as a Lean function mirror, and prove well-definedness by structural
induction). Could be done as a single-RFC sprint.

**Honesty box:** closing MVT-5b retires §6b row 2 by the proof's
literal statement. It does NOT prove anything about the broader
allocator we'd build LATER if we grow into graph-coloring. That
follow-on work spawns a NEW RFC at the time and re-opens the box.

### 5c — Loop-unroll preservation

**Honest scope:** the existing `F-RFC069-PASSTHROUGH-PRESERVED` byte-eq
test is one direction (non-loop MFunc unchanged). The §6b row asks for
the other direction: unrolled CFG semantically equivalent to original.

**Minimum-viable theorem (`MVT-5c`):**

> Let `U : MFunc × ℕ → MFunc` be the function `_nvptx_unroll_pass`.
> For every MFunc `mfn` carrying the canonical RFC 069 3-block CFG
> (header + body + exit with a single back-edge body→header), and
> every factor `k ∈ {2, 3, 4, 5, 6, 7, 8}`, the small-step operational
> semantics of `U(mfn, k)` and `mfn` (interpreted as functions from
> initial memory + thread-id to final memory) coincide on all inputs
> for which both programs terminate.

**Why this scope:** the canonical 3-block CFG is the exact shape
RFC 069 P1–P3 implements; the factor range matches the test corpus;
the "both terminate" qualifier is the standard CompCert simulation
qualifier (avoids the always-true case of nontermination matching
nontermination).

**Real-limit anchor:** small-step operational semantics ⇒ standard
forward simulation diagram (CompCert pattern). No lattice rule.

**Effort estimate:** 2–4 person-months — leverages the Isabelle
mechanization from [arxiv 2502.15535](https://arxiv.org/pdf/2502.15535)
which already proves general unrolled-loop ≡ original-loop equivalence
for a high-level loop construct. Work is in lifting that theorem
across the MFunc → MFunc concrete CFG shape we use.

**Honesty box:** the byte-eq `F-RFC069-PASSTHROUGH-PRESERVED` gate is
ONE direction (non-loop preserved). MVT-5c is the OTHER direction
(loop body N×) and the two together close §6b row 3.

---

## 6 — Effort estimates (honest, no over-claim)

| row | theorem | proof tool (preferred) | LoC est. | calendar time | confidence |
|-----|---------|-----------------------|----------|---------------|-----------|
| 5a — PTX emit eq | MVT-5a (single vec-add shape, IEEE 754 f32) | Coq (anchors on Ferrell-Hamlen 2019 inductive PTX types) | 800–2000 | **4–6 person-months** (incl. PTX opcode subset Coq formalization for `ld.f32 / st.f32 / add.f32`) | medium — Cuq's incomplete state (§3a row 3) is the cautionary base rate |
| 5b — regalloc | MVT-5b (classifier well-definedness) | Lean 4 (mathlib gives set/function machinery) | 200–500 | **1–3 person-weeks** | high — narrow, structural-induction proof; trivial compared to CompCert's 4.3k-line graph-coloring effort because hexa's allocator is correspondingly trivial |
| 5c — loop-unroll | MVT-5c (3-block CFG factor 2..8) | Isabelle (reuses arxiv 2502.15535 mechanization) | 500–1500 | **2–4 person-months** | medium — lifting from "general unrolled-loop" to "our concrete MFunc shape" is mechanical but tedious |

**Combined ceiling:** ~6–13 person-months for the cheapest plausible
path to all three boxes flipped.

**Combined floor (cheapest-row-only):** 1–3 person-weeks to flip
§6b row 2 alone.

These are calendar months of focused proof engineering — they assume
a person doing primarily this work, not background grind during other
RFCs. Half-time work doubles the calendar.

---

## 7 — Proof-tool selection rubric

| candidate | pros | cons | recommended for |
|-----------|------|------|-----------------|
| **Coq** | matches Ferrell-Hamlen 2019 + Lustig 2019 PTX semantics; widest GPU prior art; CompCert template directly imports | steeper learning curve; older tactic language | 5a (PTX-eq) — reuse existing PTX-in-Coq encodings |
| **Lean 4 + mathlib** | modern; mathlib has set / function / induction machinery; SSA peephole paper (§3b row 5) gives Lean MLIR pattern | smaller GPU formal-methods community; no existing PTX Coq-in-Lean port | 5b (regalloc) — proof is small enough that "small + modern" wins over "GPU prior art" |
| **Isabelle** | the loop-unroll mechanization arxiv 2502.15535 is in Isabelle | adds a third proof assistant to the project — fragmentation cost | 5c (unroll) — only if we accept the import cost; otherwise re-do in Coq |
| **spec-only-no-prover** | zero proof-engineering cost; write a formal English-or-pseudo-math spec and stop | does NOT satisfy "Coq/Lean proof" wording in §6b; would have to either change the §6b wording or accept honest non-closure | NONE of the three rows under current §6b wording |

**Recommendation:** start with **5b in Lean 4** (cheapest first, builds
team familiarity), then evaluate whether to do 5a + 5c in the same
tool or split. The fragmentation cost of multiple provers is non-trivial;
if 5b succeeds well in Lean, push 5a + 5c into Lean too (porting
arxiv 2502.15535 from Isabelle costs less than maintaining two
toolchains in this repo).

---

## 8 — Cheapest-row-first ordering (recommended execution order)

1. **Row 5b first** (1–3 person-weeks).
   - Lean 4 + mathlib.
   - Closes §6b row 2 with the smallest credible work.
   - Builds team / repo familiarity with the proof toolchain.
   - Lands as a SUCCESSOR RFC (call it RFC 076-A · "regalloc well-definedness").
   - Adds `@cite RFC076A::classify_locals_well_defined` strict-lint
     markers on `_nvptx_classify_locals` / `_nvptx_classify_local_for_stmt`.

2. **Row 5c second** (2–4 person-months).
   - Either continue in Lean (port arxiv 2502.15535) or accept Isabelle.
   - Closes §6b row 3.
   - Lands as RFC 076-B.

3. **Row 5a last** (4–6 person-months).
   - Coq (most prior art) or Lean (if we committed to Lean in 5b/5c).
   - Closes §6b row 1.
   - Lands as RFC 076-C.
   - This is the largest, most-likely-to-encounter-honest-failure row.
     If it fails (e.g. we can't formalize a needed PTX opcode tractably),
     we honestly leave §6b row 1 unchecked and document the failure
     mode in a follow-up audit RFC — per `@D g3`, no overclaim.

**Cumulative calendar:** ~6–13 person-months for all three. If only
the first row lands (1–3 person-weeks), §6b is **partial closure**:
1 of 3 boxes flipped, 2 of 3 documented as honest-deferred.

---

## 9 — Honesty boundary (`@D g3` enforcement)

What this RFC is **NOT** doing and what we must **NOT** claim:

- **Not closing any §6b box in this cycle.** This RFC is research +
  plan. The boxes remain `[ ]` until a successor RFC lands actual
  proof artifacts.
- **Not super-claiming that existing testing evidence is formal proof.**
  The byte-eq gates (`F-RFC069-PASSTHROUGH-PRESERVED`,
  `F-RFC067-WMMA-EMIT`, ptxas `-v` audit) are SOUND testing under the
  assumption that test inputs cover the codegen surface. They are NOT
  universally-quantified proofs. The `[ ]` vs `[x]` flip is real:
  byte-eq tests give `[x]` for the testing checkbox (where it exists),
  but §6b explicitly asks for a separate proof checkbox.
- **Not promising silver-bullet timelines.** Cuq (§3a row 3) is a
  recent, well-resourced research project that has not closed
  end-to-end PTX-equivalence soundness. Our row 5a is in the same
  genre and carries the same risk of honest failure. The §6 estimates
  are best-case planning numbers, not commitments.
- **Not extending §6b's wording to lower the bar.** If the §6b row
  says "Coq/Lean proof", we close with a Coq/Lean proof or honestly
  leave it `[ ]`. We do not silently downgrade row 1 to
  "Coq spec, no proof" without an RFC amending §6b.

What testing evidence DOES contribute (per `@D g3` honest scope):

- High-confidence sound-but-unverified status on the **observed**
  codegen paths. The existing test corpus + silicon fires are the
  best argument for spending the proof-engineering budget at all —
  if we hadn't already established empirical soundness on the
  vec-add / HGEMM / unroll-by-3 corpus, the formal-proof investment
  would be on shakier ground.

---

## 10 — Successor-RFC layout

| RFC | scope | start condition |
|-----|-------|-----------------|
| RFC 076-A | Row 5b proof — Lean 4, `_nvptx_classify_locals` well-definedness | this RFC reviewed + Lean 4 toolchain added to repo (or accepted as external dep) |
| RFC 076-B | Row 5c proof — unroll preservation, MFunc 3-block CFG factor 2..8 | RFC 076-A landed (toolchain proven viable) |
| RFC 076-C | Row 5a proof — vec-add MVT-5a, IEEE 754 f32 add | RFC 076-A + B landed; PTX opcode subset Coq encoding chosen (Ferrell-Hamlen vs port-to-Lean decision) |
| RFC 076-AUDIT | Honest-failure audit if any of the above fails | triggered by RFC 076-{A,B,C} explicit "proof did not close" outcome |

---

## 11 — Falsifiers (this RFC itself)

This RFC is research + plan, so its falsifiers are about plan validity,
not proof outcomes:

- **F-RFC076-PRIOR-ART-COMPLETE** — the §3 survey covers Ferrell-Hamlen
  2019, Lustig 2019, Cuq 2025, CompCert, Vellvm, Alive2, the SSA peephole
  paper, and the Isabelle unroll paper. If any of these are missing or
  mis-summarized, this RFC ships an erratum, NOT a successor proof.
- **F-RFC076-EFFORT-FLOOR** — the cheapest-row floor (5b, 1–3 person-weeks
  for ~200–500 Lean LoC) must be defensible against the CompCert RA
  reference (4.3k LoC for a vastly larger allocator). The 10–20× LoC
  ratio matches the 10–20× scope ratio (CompCert's allocator is graph-coloring;
  ours is syntax-directed type classifier).
- **F-RFC076-ROW-SCOPE-MATCH** — each MVT-5x must literally close the
  exact wording of the corresponding §6b row, not a weaker substitute.
- **F-RFC076-HONESTY-BOX-VISIBLE** — §9 honesty boundary must be present
  before any successor RFC lands a proof.

---

## 12 — Cross-references

- `GPU.md` §6b (the boxes this RFC plans to close)
- `inbox/rfc_drafts_2026_05_12/rfc_055_hexa_nvptx_codegen_backend.md`
  (the codegen pipeline this RFC verifies)
- `inbox/rfc_drafts_2026_05_20/rfc_067_wmma_real_emit.md`,
  `rfc_068_mixed_precision_mir_layer.md`,
  `rfc_069_unroll_advanced.md` (the recent codegen surface area whose
  formal closure this RFC scopes)
- `inbox/rfc_drafts_2026_05_20/rfc_075_multi_vendor_codegen.md` — the
  multi-vendor scaffold; once ROCm + Metal codegen lands, this RFC's
  proofs may need a parallel ROCm / Metal series. Out of scope here,
  flagged as a known follow-on.
- `compiler/codegen/nvptx_target.hexa:1164` (`_nvptx_classify_locals`)
  — the function row 5b proves correct.
- `compiler/codegen/nvptx_lower_test.hexa:1720..1750`
  (`F-RFC069-PASSTHROUGH-PRESERVED` byte-eq gate) — the testing
  evidence row 5c complements with a proof.
- `AGENTS.tape` `@D g3` (real-limit-first), `@D g5` (hexa-native-only),
  `@D g6` (citation-enforced strict-lint), `@F f2` (no-LLVM,
  no-C-transpile architecture).

---

## 13 — Decision required (gate)

Before any successor RFC (076-A/B/C) can spend proof-engineering time:

1. **Tool choice gate** — Coq vs Lean vs Isabelle vs mixed.
   Recommendation §7: start Lean 4 with row 5b, reassess after.
2. **Cheapest-first ordering gate** — confirm 5b → 5c → 5a is the
   intended sequence.
3. **Honest-failure acceptance gate** — accept up front that row 5a
   may not close in this lifetime of the codebase, and that a partial
   §6b closure (1 or 2 of 3 boxes flipped) is a legitimate honest
   outcome under `@D g3`.

These three gates close as USER-facing decisions, not as in-RFC
authority. Successor RFC 076-A blocks on these.
