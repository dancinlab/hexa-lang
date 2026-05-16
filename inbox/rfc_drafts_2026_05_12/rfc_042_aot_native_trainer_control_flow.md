# RFC 042 — AOT-native trainer control-flow execution (the LM-scale ceiling breaker)

- **Status**: design-draft (2026-05-16) — DESIGN ONLY, no implementation
- **Date**: 2026-05-16
- **Severity**: HIGH (this is the *proven* — not speculative —
  structural ceiling that prevents hexa-native LM-scale
  training-to-convergence; with GPU routing DONE+correct and a fat host
  ADEQUATE, the pure-hexa bytecode interpreter executing the training
  control flow is the remaining wall)
- **Priority**: P1 for the hexa-native LM ceiling (it is the one
  upstream change that eventually removes anima's interim `.py`
  dependency; RFC 040/041 close the GPU-substrate ceiling, RFC 042
  closes the *control-flow execution* ceiling — both are required for
  hexa-native d=768·12L training-to-convergence)
- **Source convergence**: anima RFC 040 GPU campaign, Phase E2 — the
  campaign's *deepest* finding, isolated only after GPU routing and
  host fatness were both eliminated as the bottleneck.
- **Source evidence (g3 — the ceiling is MEASURED, not hypothesized)**:
  - anima `state/hexad_gpu_fire_phaseE2_2026_05_16/result.json`
    `headline` + `honest_C3` C3-1 / C3-4 — *"NO scale reached a
    captured FINAL gn2: pure-hexa GRAD-EXACT + 80-step AdamW is
    substrate-bound beyond the 75-min watchdog at d>=384 (GRAD-EXACT
    alone >5min at d>=512) … substrate ceiling NAMED — GRAD-EXACT +
    80-step AdamW are pure-hexa CPU-bound (n_layer × T scalar loops);
    GPU GEMMs are microseconds (⇒ ≤2% sampled util, documented
    physical limit). Real engineering ceiling at d>=384, **independent
    of routing (done+correct) or host fatness (adequate)**."*
  - anima `docs/anima_rfc040_phase_e2_backward_fathost_2026_05_16.md`
    §4.3 (the captured ladder: d=768·12L init gn2=7.98162,
    d=512·8L 7.96517, d=384·6L 7.97898 + GRAD-EXACT PASS; **no FINAL
    gn2 at any scale**) + §5 C3-1/C3-4/C3-6 (the ceiling is
    CPU-control-flow, and the full-descent correctness is independently
    carried by the Mac CPU-equivalence bit-equality — so the unmet
    part is *only* the on-box wall, not numeric correctness).
  - anima `docs/anima_rfc040_phase_e_d_train5_gpu_routed_2026_05_16.md`
    §4 C3-4 — the same effect first observed under a thin host
    (microsecond GEMMs vs CPU-bound pure-hexa wall), Phase E2 then
    proved it persists on a 251 GB / 128-vCPU fat host.

## Scope of this RFC — DESIGN DRAFT, honest framing

This is a **design document only**. It specifies a path for hexa to
**AOT-compile / native-execute the training control loop** rather than
*interpret* it, so hexa-native LM-scale training-to-convergence becomes
feasible. It lands **zero implementation**, modifies no compiler /
runtime source, and builds nothing. This is explicitly a **large,
multi-cycle** effort — the RFC is the design entry point, not a small
patch.

The RFC is deliberately conservative and honest about the scope: the
gap is not "missing an op" (RFC 040/041 cover the GPU ops) — it is the
*execution model* of the heavy training-driver loop. That is a deep
change and the RFC names it as such.

## Problem — the ceiling, PROVEN by the campaign (g3)

The anima RFC 040 GPU campaign systematically eliminated every
candidate bottleneck and isolated the real one:

1. **GPU routing — DONE and numerically CORRECT.** Phase E2 routed
   *both* forward and backward GEMM-dominant FLOPs through the one
   verified cuBLAS Dgemm kernel. The d=384·6L GRAD-EXACT PASS on a
   real A100 (`analytic=-0.00311269 fd=-0.000706787 |Δ|=0.0024059`)
   and the Mac CPU-equivalence bit-equality (`gn2 7.97116 →
   3.73374e-07, acc 0/8 → 8/8`, *exactly* equal to the boxed baseline)
   prove the routed trainer's full gn2 descent is correct. **Routing
   is not the bottleneck.**
2. **Host fatness — ADEQUATE.** Phase E died on a 2 GB / 1-slow-vCPU
   H200 host (couldn't even finish the d=768·12L init epoch). Phase E2
   provisioned a 251 GB RAM / 128-vCPU A100-SXM4 fat host; the
   d=768·12L init epoch *completed* (init gn2=7.98162 — the
   first-ever captured d=768·12L scalar for this trainer; Phase E's
   exact blocker BROKEN). **Host fatness is not the bottleneck.**
3. **The remaining wall — the pure-hexa bytecode INTERPRETER executing
   the training control flow.** Even with (1) and (2) resolved, **no
   scale reached a captured FINAL gn2.** The substrate-bound part is
   the *interpreter orchestrating the training driver*: the 3 composed
   GRAD-EXACT passes + the 80-step AdamW loop. Measured: GRAD-EXACT
   alone took **>5 min at d≥512** (never cleared at d=768/512); at
   d=384 it PASSED (~182 s) but the 80-step loop (80 × full
   fwd+bwd+AdamW orchestration) projects to **>60 min**, exceeding the
   75-min orphan watchdog. The GPU GEMMs themselves are microseconds
   (hence the documented ≤2% sampled SM-util — a *physical* limit, not
   idleness); the wall clock is the **CPU-bound pure-hexa scalar
   control flow between GEMMs** — RoPE / softmax / RMSNorm / residual /
   AdamW scalar loops over `n_layer × T`, plus the central-difference
   GRAD-EXACT triple-pass orchestration, all driven by
   `hexa_interp` bytecode dispatch.

This is the campaign's honest, *measured* conclusion (Phase E2
result.json C3-4, verbatim): *"This is the real engineering ceiling
for a pure-hexa exact-AdamW trainer at d≥384 — independent of GPU
routing (which IS done + proven correct) or host fatness (which IS
adequate)."* — i.e. the ceiling is the interpreter, and it is **proven,
not speculative.**

### Why the existing `hexa build` path does not already solve this

hexa-lang already has a `hexa build` **compiled-native** path for
modules — anima `HEXAD/build_verify.sh` compiles 24/24 entrypoints +
16/16 libs to native ELF and they pass. The Mac CPU-equivalence gate
itself ran *compiled-native*. So the issue is **not** "hexa has no
compiled path."

The gap is specifically the **heavy training-driver loop**: the d_train5
step loop (`d5_grad` / GRAD-EXACT central-difference triple-pass /
80-step AdamW orchestration over `n_layer × T`) is the part whose
*control-flow execution* — the loop bodies, the per-step orchestration,
the composed-grad passes — is the wall. The campaign ran *compiled-
native* and the loop still did not converge within the cost-bounded
window at d≥384. The structural fix is a compiled-native / interpreter-
bypass path for **that specific heavy driver loop**, not just for the
module entrypoints (which already compile).

## Proposal — design space (DESIGN ONLY, multi-cycle)

RFC 042 proposes specifying — not implementing — a path so the heavy
training-driver loop is **natively executed, not bytecode-interpreted**.
The design must cover:

### 1. A compiled training-driver entrypoint

A way to mark the d_train5 step-loop driver (the
`d5_epoch_gn2` / `d5_grad` / GRAD-EXACT / 80-step AdamW orchestration)
as an **AOT-compiled native entrypoint** whose loop bodies and
per-step orchestration are emitted as native code (not walked by
`hexa_interp`), while the existing module compile path (`hexa build`,
24/24+16/16) is the proven precedent the design extends. The design
question: what is the boundary of "the driver loop" and how is it
expressed (a compiled-entrypoint attribute? a `hexa build`-driver
mode? a native loop-body codegen for the hot training closure?).

### 2. Interpreter-bypass for the step loop

The d_train5 step loop is the specific hot path. The design must
specify how the loop's control flow (the 80-step AdamW iteration, the
3 composed GRAD-EXACT passes, the per-layer `n_layer × T` scalar
inner loops) executes as native code rather than per-iteration
bytecode dispatch — i.e. the structural removal of the `hexa_interp`
per-instruction overhead from the training driver, not from the whole
language.

### 3. Equivalence preservation (mandatory, g_blue_closed_mandate)

Whatever the mechanism, the AOT-native driver must produce a result
**numerically identical to the interpreted/compiled-module path** —
the campaign's exact-equal Mac CPU-equivalence reference
(`gn2 7.97116 → 3.73374e-07, acc 0/8 → 8/8`) is the closed reference
the AOT path must reproduce. This connection point (interpreted-driver
↔ AOT-native-driver) is a first-class verification target, not an
afterthought.

## Acceptance falsifiers (F-RFC042-*) — referenced to existing evidence

Each falsifier runs against the **existing verified reference**, not a
fabricated target:

- **F-RFC042-DESCENT-EQ** — the AOT-native driver reproduces the
  campaign's exact CPU-equivalence descent: init gn2=7.97116 →
  final gn2=3.73374e-07, acc 0/8 → 8/8, on the d=32·3L·8win·80-AdamW
  reference config (seed=42, `corpus_consciousness_v1.jsonl`). This is
  the *existing verified oracle*
  (`state/hexad_gpu_fire_phaseE2_2026_05_16/cpu_equiv_e2.log`) —
  **do not invent a new target**; the AOT path must match it
  bit-equal (the campaign proved that descent is exactly reproducible
  at $0).
- **F-RFC042-GRADEXACT-PASS** — the AOT-native driver's GRAD-EXACT
  central-difference check still PASSES (the campaign's
  `GRAD-EXACT(L0.Wg[5])` PASS is the reference); the AOT path must not
  break the exact-grad correctness.
- **F-RFC042-WALL-IMPROVED** — the headline acceptance: a scale that
  did **not** reach a captured FINAL gn2 under the interpreted path
  (the campaign's d=384·6L: GRAD-EXACT ~182 s, 80-step loop projected
  >60 min, exceeded the 75-min watchdog) **does** reach a captured
  FINAL gn2 under the AOT-native driver within the same cost-bounded
  window. The acceptance is *qualitative and evidence-anchored*
  (interpreted: no FINAL; AOT: FINAL captured) — not a fabricated
  speedup multiple. The honest target is "the interpreter ceiling
  named in Phase E2 C3-4 is broken," measured the same way the
  campaign measured it.
- **F-RFC042-MODULE-REGRESSION-0** — the existing `hexa build`
  module-compile path (anima `HEXAD/build_verify.sh` 24/24
  entrypoints + 16/16 libs) is **byte-identical** after the AOT-driver
  change — no regression to the proven compiled-module path.
- **F-RFC042-DETERMINISM** — the AOT-native driver run twice:
  byte-identical (the campaign's training is seed-fixed and
  deterministic; the AOT path must preserve that).

(≥3 per AGENTS.tape directive; this RFC specifies 5. F-RFC042-DESCENT-EQ
is the `g_blue_closed_mandate` connection-point closed check — the
interpreted↔AOT-native equivalence — and is mandatory.)

## Honest caveats (AGENTS.tape g3 / f2 — no over-claim)

- **The ceiling is PROVEN, not speculative.** This is the single most
  important honesty point. Phase E2 *eliminated* GPU routing
  (done+correct, on-A100 GRAD-EXACT PASS + Mac bit-equal) and host
  fatness (251 GB / 128 vCPU let d=768·12L init complete) as the
  bottleneck before isolating the interpreter control flow. The
  ceiling is the campaign's measured C3-4 conclusion, not a hypothesis
  RFC 042 invents.
- **Numeric correctness is NOT the open problem.** The campaign's Mac
  CPU-equivalence gate independently proves the full gn2 descent is
  *exactly* correct (bit-equal to the boxed baseline,
  `7.97116 → 3.73374e-07`, reproducible at $0 — Phase E2 §3 / C3-6).
  The ONLY unmet part is the on-box *wall* of the interpreted driver
  loop. RFC 042 is a *performance/execution-model* fix, not a
  correctness fix — and the acceptance falsifiers reference the
  existing exact oracle precisely so no new correctness target is
  fabricated.
- **This is a large, multi-cycle effort.** A native execution path for
  the training-driver loop touches the compiler, the bytecode/native
  boundary, the loop-body codegen, and the build system. RFC 042 is
  the *design entry point* only; it lands no code. The effort is
  honestly wide-banded and explicitly multi-cycle — comparable in
  scope to RFC 040 itself.
- **Don't invent acceptance numbers.** F-RFC042-WALL-IMPROVED is
  deliberately *qualitative* (interpreted: no FINAL captured at d≥384;
  AOT: FINAL captured) and anchored to the campaign's actually-measured
  behaviour (`docs/anima_rfc040_phase_e2_backward_fathost_2026_05_16.md`
  §4.3 ladder + §5 C3-1). RFC 042 does NOT assert a speedup multiple
  it has no measured basis for — the bound is the existing evidence,
  never asserted by hope.
- **Complements, does not replace, RFC 040/041.** RFC 040/041 close
  the GPU-substrate ceiling (matmul + Phase B/B2 ops). RFC 042 closes
  the *control-flow execution* ceiling. Both are required for
  hexa-native d=768·12L training-to-convergence — neither alone
  suffices (Phase E2 proved GPU routing alone, even fat-hosted, does
  not).
- **No lattice-tautology (f2).** The real-limit verification anchor is
  *numerical equivalence to the campaign's bit-exact CPU reference
  descent* + the CE Shannon-entropy floor preserved across the AOT
  path — real math, not `σ·φ=24`.

## Non-goals (this RFC)

- No implementation — no compiler / runtime / codegen edit, no build.
  Design draft only.
- Not a re-architecture of `hexa_interp` for the whole language — the
  scope is the **training-driver loop** specifically (the proven hot
  path), not a general interpreter rewrite.
- Not a numeric/correctness change — the descent is already proven
  exactly correct; RFC 042 is purely an execution-model path so the
  proven-correct descent finishes within a cost-bounded window at
  d≥384.
- Does not subsume RFC 040/041 — the GPU substrate is a separate
  (and complementary) ceiling.

## Cross-RFC dependency

- **RFC 040 / RFC 041** (`farr` GPU/CUDA backend + Phase B/B2
  kernels) — the *substrate* ceiling. RFC 042 is the *control-flow
  execution* ceiling. Phase E2 proved both are real and independent;
  hexa-native d=768·12L training-to-convergence needs all three.
- **The existing `hexa build` compiled-native module path** — anima
  `HEXAD/build_verify.sh` 24/24 entrypoints + 16/16 libs is the
  proven precedent RFC 042 extends from "module compile" to "heavy
  training-driver loop native execution"; F-RFC042-MODULE-REGRESSION-0
  protects it.

## Cross-link (campaign evidence — g3)

- anima `state/hexad_gpu_fire_phaseE2_2026_05_16/result.json`
  `headline` + `honest_C3` C3-1/C3-4/C3-6 — the proven ceiling
  (interpreter control flow, independent of routing/host) + the
  exact-equal CPU reference.
- anima `docs/anima_rfc040_phase_e2_backward_fathost_2026_05_16.md`
  §4.3 (captured ladder, no FINAL at any scale) + §5 C3-1/C3-4/C3-6.
- anima `docs/anima_rfc040_phase_e_d_train5_gpu_routed_2026_05_16.md`
  §4 C3-4 — the same effect first observed (thin host), Phase E2
  proved it persists on a fat host.
- anima `HEXAD/PLAN.md` §9 (GPU 기질 substrate roadmap) + the §9
  dual-track note — RFC 042 is the upstream item that eventually
  removes anima's interim `.py` LM-scale executor dependency.
- anima `AGENTS.tape` §0 `g_blue_closed_mandate` / `g3` / `f2` — the
  interpreted↔AOT-native connection-point closed-equivalence + the
  real-limit (CPU-reference numeric equivalence + Shannon floor)
  anchor; no lattice tautology.
