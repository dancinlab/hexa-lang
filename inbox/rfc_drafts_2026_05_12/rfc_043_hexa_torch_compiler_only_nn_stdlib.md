# RFC 043 — `hexa-torch`: a compiler-only, farr-native tensor / autograd / NN training stdlib

- **Status**: design-draft (2026-05-16) — DESIGN ONLY, no implementation
- **Date**: 2026-05-16
- **Severity**: HIGH (the consolidating north-star RFC for hexa-native
  LM-scale training: it folds the GPU-substrate work — RFC 040/041 — and
  the control-flow execution work — RFC 042 — into ONE
  `hexa build`-native stdlib, the path by which hexa-native eventually
  removes anima's interim `.py` LM-scale training dependency)
- **Priority**: P1 (umbrella over RFC 040/041/042; the long-horizon
  hexa-native answer in anima `HEXAD/PLAN.md` §9 — "진짜 d=768·12L
  언어 fire" via a hexa-native, not Python, training stack)
- **Source convergence**: anima 2026-05-16 user directive — *"PyTorch
  같은 stdlib 를 만들고 싶어. 단 컴파일러 전용 … 그건 pytorch 보다 더
  뛰어나게 하고 싶어 궁극적으로는"* (a compiler-only PyTorch-equivalent
  stdlib whose ULTIMATE goal is to exceed eager-PyTorch). RFC 043 is the
  hexa-lang-side design realization of that directive, grounded in the
  anima RFC 040 GPU campaign's REAL measured findings.
- **Source evidence (g3 — every claim anchored to a capture, no
  fabricated metric)**:
  - cuBLAS FP64 Dgemm real-H100 roofline: anima
    `docs/anima_rfc040_phase_d_h100_cublas_2026_05_16.md` §2.1 —
    **51.24 TFLOPS FP64 peak at 1024³ = 76 % of the H100 SXM ~67 TFLOPS
    theoretical FP64 peak on stock cuBLAS Dgemm**, ~13 000× over the CPU
    `ikj` oracle on the d_train5 MLP-representative shapes; §2.2
    measurement-calibrated `TOL_MATMUL ≈ 2e-9` relative (NOT bit-equal).
  - the verified-trainer correctness oracle: anima
    `docs/anima_rfc040_phase_e2_backward_fathost_2026_05_16.md` §3 +
    `state/hexad_gpu_fire_phaseE2_2026_05_16/result.json`
    `cpu_equivalence_gate` — d=32·3L·8win·80-AdamW, seed=42,
    `corpus_consciousness_v1.jsonl`: **`gn2 7.97116 → 3.73374e-07,
    acc 0/8 → 8/8`, BIT-EQUAL to the boxed baseline**, GRAD-EXACT PASS.
  - the proven ceiling that is NOT GPU and NOT host: same result.json
    `honest_C3` C3-4 + `headline` — *"substrate ceiling NAMED —
    GRAD-EXACT + 80-step AdamW are pure-hexa CPU-bound (n_layer × T
    scalar loops); GPU GEMMs are microseconds (⇒ ≤2 % sampled util,
    documented physical limit). Real engineering ceiling at d≥384,
    independent of routing (done+correct) or host fatness (adequate)."*
  - the landed autograd-tape foundation: RFC 034 (LANDED 2026-05-16,
    compiled-native 5/5 PASS) — the tape-based reverse-mode AD
    (matmul → CE-softmax) RFC 043 generalizes.

## Scope of this RFC — DESIGN DRAFT, honest framing

This is a **design document only**. It specifies the architecture of a
PyTorch-equivalent, **compiler-only** (`hexa build`-native, zero
interpreter dispatch) tensor / autograd / NN-training stdlib for
hexa-lang. It lands **zero implementation**: no `self/runtime.c` edit,
no `.cu` kernel, no codegen change, no build. It defines the surface,
the consolidation of the existing RFC 040/041/042/034 work into one
coherent stdlib, the verification battery, the staged plan, and — most
importantly — the **honest performance thesis** (the framing this RFC
exists to get right). Implementation is a large, multi-cycle effort
strictly gated on this design's acceptance and on RFC 040/041/042/034
landing first; RFC 043 is the *consolidating design entry point*, not a
patch.

The RFC is deliberately conservative. AGENTS.tape `g3`
(verification-anchor-real-limit), `f1`/`f2` (no lattice-fit / no
lattice-tautology), and `g_blue_closed_mandate` (§0 — every artifact
*and connection point* 🔵 closed-verified) forbid over-claiming. A
"beat PyTorch" north-star is exactly the kind of claim those directives
exist to discipline; this RFC therefore states the performance thesis
with a named real mechanism, a named honest floor, an explicit
forbidden, and qualitative-staged (never numeric-fabricated) targets.

## Problem — three ceilings, one stack

The anima RFC 040 GPU campaign systematically isolated what stands
between hexa-lang and hexa-native LM-scale training-to-convergence. The
campaign found **three** distinct ceilings, currently addressed by
**three** separate RFCs:

1. **The GPU-substrate ceiling** — pure-hexa `farr_matmul` is a
   single-thread scalar CPU loop; a d=768·12L step is days-to-weeks on
   CPU. RFC 040 designs the device-farr + cuBLAS path; RFC 041 designs
   the remaining real CUDA kernels (elementwise / softmax / reduction /
   AdamW — RFC 040 Phase B). **Status**: RFC 040 Phase D PROVED the
   cuBLAS substrate on real H100 (51.24 TFLOPS FP64, byte-equal CPU
   oracle within `≈2e-9` rel); Phase E/E2 PROVED the routed
   forward+backward trainer is CPU-bit-equal correct.
2. **The control-flow execution ceiling** — Phase E2's *deepest*
   finding (C3-4): even with GPU routing done+correct and a 251 GB /
   128-vCPU fat host, **no scale reached a captured FINAL gn2** because
   the pure-hexa bytecode INTERPRETER executing the training driver
   (GRAD-EXACT triple-pass + 80-step AdamW + the `n_layer × T` RoPE /
   softmax / RMSNorm / residual scalar loops between GEMMs) is the wall
   — the GPU GEMMs are microseconds (≤2 % sampled SM-util, a *physical*
   limit, not idleness). RFC 042 designs the AOT-native driver path.
3. **The "no PyTorch-equivalent surface" gap** — even with (1) and (2)
   solved at the primitive level, anima still has no hexa-native
   *stdlib* that presents the building blocks (Tensor, autograd tape,
   nn layers, optimizer, training-step) as a coherent PyTorch-shaped
   API. RFC 034 landed the *minimal* autograd tape (one matmul → one
   CE-softmax — explicitly a v1 scope, "general op set is mechanical
   follow-up"). The verified architecture it must serve
   (ConsciousDecoderV2 — anima `HEXAD/INDEX.md`: Linear / RMSNorm /
   RoPE / GQA-attention / SwiGLU / embedding / tied LM head) needs the
   full surface.

These three are not independent problems to solve three ways — they are
**one stack** with one consumer (the verified d_train5 /
ConsciousDecoderV2 trainer) and one correctness oracle (the campaign's
CPU-bit-equal descent). RFC 043 consolidates them into a single
compiler-only stdlib so the design is coherent rather than three
overlapping point-RFCs.

## Proposal — `hexa-torch`, a compiler-only NN stdlib

### The consolidation map (explicit — this is the core of RFC 043)

| Prior RFC | Role in `hexa-torch` (RFC 043) |
|---|---|
| **RFC 040** (device-farr + cuBLAS Dgemm) | becomes **the `Tensor` backend** — device residence model + the GEMM kernel under `tensor @ tensor`. **NOT superseded** — RFC 043 *consumes* it as its tensor substrate. |
| **RFC 041** (Phase B/B2 real CUDA kernels: elementwise / softmax / row-reduction / fused AdamW / bf16 pack) | becomes **the `hexa-torch` op-kernel backend** — the kernels behind the nn-layer / loss / optimizer ops. **NOT superseded** — RFC 043 *consumes* it as its kernel set. |
| **RFC 042** (AOT-native trainer control-flow execution) | **SUBSUMED into RFC 043.** RFC 042's heavy "compile the training-driver loop as a special native entrypoint / interpreter-bypass execution model" framing is replaced by RFC 043's lighter, structurally cleaner answer: a **fat native stdlib + thin hexa orchestration**. When the per-step body (every layer fwd/bwd, the autograd tape replay, AdamW) lives in compiled native stdlib code, the hexa-side training loop is a thin driver with negligible per-iteration interpreter cost — *and the whole stdlib is `hexa build`-native anyway* (zero interpreter, per the interpreter-deprecation directive). RFC 042's ceiling is closed not by a special driver-loop execution mode but by there being almost no interpreted work left to execute. **042 → folded into 043.** |
| **RFC 034** (landed tape-based reverse-mode AD: matmul → CE-softmax) | **the autograd-tape FOUNDATION RFC 043 generalizes** — RFC 034's landed `ad_tape_begin/end` / `ad_matmul` (records `dA=dC@Bᵀ`, `dB=Aᵀ@dC`) / `ad_softmax_cross_entropy` (closed B-D-4 logit Jacobian) / `ad_backward` / `adamw_step` is the proven seed; RFC 043 extends that *same tape* from "one matmul feeding one CE-softmax" (RFC 034's honest v1 scope) to a general reverse-mode tape over the ConsciousDecoderV2 op set. RFC 034 is NOT re-designed; it is the tape kernel RFC 043 builds the nn layers on top of. |

Stated plainly, as the directive requires: **042 → folded into 043;
041 → 043's kernel backend; 040 → 043's tensor backend; 034 → 043's
autograd-tape foundation.**

### Surface — a PyTorch-shaped, compiler-only API

`hexa-torch` is a hexa-lang stdlib module (`std/hexa_torch.hexa` or the
agreed stdlib path) whose every op compiles via `hexa build` to native
code with **zero `hexa_interp` dispatch** — the compiler-only constraint
is structural, not a flag. The surface mirrors the PyTorch building
blocks the verified ConsciousDecoderV2 actually uses (anima
`HEXAD/INDEX.md` 7-module arch), no more:

```hexa
// ── Tensor (RFC 040 device-farr residence model is the backend) ────
//   a Tensor is a farr_id + shape metadata + (RFC 040) residence.
pub fn t_zeros(shape: ...) -> int           // new tensor, host or device
pub fn t_from_farr(id: int, shape: ...) -> int
pub fn t_to_device(t: int) -> int           // RFC 040 farr_to_device
pub fn t_to_host(t: int) -> int             // RFC 040 farr_to_host
pub fn t_matmul(a: int, b: int) -> int      // RFC 040 farr_matmul[_gpu]
pub fn t_add(a: int, b: int) -> int         // RFC 041 elementwise kernel
pub fn t_mul(a: int, b: int) -> int         // RFC 041 elementwise kernel

// ── autograd tape (RFC 034 landed tape is the foundation; general) ──
pub fn ag_tape_begin() -> int               // = RFC 034 ad_tape_begin
pub fn ag_tape_end(tape: int)               // = RFC 034 ad_tape_end
//   the differentiable ops record onto the open tape (RFC 034 pattern,
//   generalized over the layer set below).
pub fn ag_backward(loss_tape: int)          // = RFC 034 ad_backward
pub fn ag_grad(param: int) -> int           // = RFC 034 ad_grad

// ── nn layers (the ConsciousDecoderV2 building blocks) ─────────────
pub fn nn_linear(x: int, w: int, b: int) -> int           // fwd+tape
pub fn nn_rmsnorm(x: int, w: int, eps: float) -> int
pub fn nn_rope(q: int, k: int, pos: int) -> int            // rotary
pub fn nn_gqa_attention(q: int, k: int, v: int,
                        n_head: int, n_kv: int) -> int      // GQA
pub fn nn_swiglu(x: int, w_gate: int, w_up: int,
                 w_down: int) -> int                        // SwiGLU MLP
pub fn nn_embedding(ids: int, table: int) -> int
pub fn nn_tied_lm_head(h: int, embed_table: int) -> int     // tied head

// ── loss + optimizer (RFC 034 landed; RFC 041 fused AdamW kernel) ──
pub fn loss_cross_entropy(logits: int, n_rows: int,
                          n_cols: int, targets: int) -> float
pub fn opt_adamw_step(param: int, grad: int, m: int, v: int,
                      n: int, lr: float, beta1: float,
                      beta2: float, eps: float, wd: float,
                      t: int)               // = RFC 034 adamw_step,
                                            //   RFC 041 fused GPU kernel

// ── training step (thin hexa orchestration over the fat stdlib) ────
pub fn train_step(model: int, batch: int,
                  opt_state: int) -> float  // one fwd+CE+bwd+AdamW;
                                            //   compiled-native body
```

Each layer's forward records onto the autograd tape (RFC 034 pattern)
and the matching backward closure is part of the *compiled native
stdlib*, not interpreted hexa. `train_step` is the only thing the
hexa-side training loop calls per iteration — and `train_step` itself is
compiled native — so the per-iteration interpreter cost RFC 042
identified as the wall is structurally eliminated: there is no
interpreted per-step orchestration left (this is the RFC 042 subsumption,
made concrete).

### Why "fat native stdlib + thin hexa orchestration" subsumes RFC 042

RFC 042's problem statement is precise (Phase E2 C3-4): the wall is the
*interpreter executing the training-driver loop* — the per-step
orchestration, the composed-grad passes, the `n_layer × T` scalar inner
loops. RFC 042's proposed answer was a special "AOT-compiled native
entrypoint for the driver loop" / "interpreter-bypass for the step
loop". RFC 043 reaches the same end by a structurally lighter route:
**if every layer fwd/bwd, the tape replay, and AdamW are compiled native
stdlib functions, and `train_step` (which composes them) is itself
compiled native, then there is no heavy interpreted driver loop to
bypass** — the only interpreted thing left is a thin `while step < N {
train_step(...) }` whose per-iteration cost is one native call, not a
walk of the GRAD-EXACT triple-pass + 80-step orchestration. RFC 042's
ceiling is closed by *eliminating the interpreted work*, not by a
special execution mode for it. This is why RFC 043 states **042 is
subsumed**: its goal is met by RFC 043's stdlib structure, and its
heavier execution-model framing is no longer needed.

## Performance thesis (HONEST — g1/g3/f1/f2, the crux of this RFC)

This section is the reason RFC 043 exists as a *design* doc and not a
benchmark. The user's directive is explicit: *ultimately exceed
PyTorch*. AGENTS.tape `g3`/`f1`/`f2` are equally explicit: no
over-claim, no fabricated speedup, no lattice-fit performance assertion.
The thesis is stated below with the four mandatory parts — real
mechanism, honest floor, explicit forbidden, qualitative-staged targets
— and nothing else.

### North-star (stated exactly, as an ULTIMATE goal)

The north-star is to **ultimately exceed eager-PyTorch (and
torch.compile in specialized regimes) on END-TO-END training throughput
for the fixed, verified ConsciousDecoderV2 architecture.** This is
explicitly an **ULTIMATE, multi-cycle goal — NOT a near-term claim and
NOT a measured result.** RFC 043 lands no benchmark; it asserts a
*direction* with a *named real mechanism*, not a number.

### The real mechanism (named — the JAX/XLA · tinygrad · Mojo thesis)

The edge, where it exists, is real and named — the same structural edge
JAX/XLA, tinygrad, and Mojo pursue, and it is a *compiler* edge, which
is exactly why the "compiler-only" constraint is the weapon and not a
limitation:

1. **Whole-program AOT compilation** — no interpreter, no Python
   dispatch, no GIL. The hexa-torch stdlib is `hexa build`-native by
   construction (the interpreter-deprecation directive aligns: the
   interpreter is being removed anyway). PyTorch eager pays a
   Python-dispatch + framework-overhead tax per op; a whole-program AOT
   binary does not. *This is the exact ceiling RFC 042 / Phase E2 C3-4
   measured from the other side: the campaign's wall was interpreter
   dispatch — removing it is the named win.*
2. **Compile-time kernel fusion minimizing memory traffic** — the
   transformer training bottleneck at these shapes is **memory
   bandwidth, not FLOPs** (Phase E/E2: the cuBLAS GEMMs are
   *microseconds*, ≤2 % sampled SM-util — the FLOPs are nearly free; the
   cost is everything around them). A whole-program compiler can fuse
   RMSNorm / activation / residual / bias into the matmul epilogue and
   the autograd-tape backward into the same pass, cutting the
   round-trips to device memory that dominate the wall. PyTorch eager
   materializes intermediates between ops; a fusing AOT compiler does
   not.
3. **Static-shape specialization for the KNOWN architecture** — anima's
   target is ONE fixed verified architecture (ConsciousDecoderV2,
   d=768·12L, the exact shapes in
   `docs/anima_rfc040_phase_d_h100_cublas_2026_05_16.md` §2.1). PyTorch
   pays a general-shape, dynamic-dispatch tax for being a general
   framework; a compiler that knows the shapes at build time can
   specialize kernel selection, tiling, and memory layout with no
   runtime branch. This is the tinygrad/XLA static-shape advantage,
   available *because* hexa-torch is compiler-only and single-arch.

### The honest floor + the explicit forbidden (stated plainly)

- **Honest floor — raw dense GEMM is the cuBLAS/NVIDIA roofline;
  hexa-torch MATCHES it, does NOT beat it.** Phase D measured stock
  cuBLAS FP64 Dgemm at **51.24 TFLOPS = 76 % of the H100 SXM ~67 TFLOPS
  theoretical FP64 peak** — that *is* the hardware roofline for dense
  f64 GEMM. hexa-torch calls cuBLAS (or an equivalent vendor GEMM); it
  does **not** out-compute NVIDIA's own tuned GEMM and does not claim
  to. The win is **above GEMM** — in fusion, memory-traffic reduction,
  and dispatch-overhead elimination — never *at* the GEMM roofline. A
  hand-written competitive GEMM is an explicit non-goal (RFC 040 already
  named this; RFC 043 inherits it).
- **Explicit forbidden (AGENTS.tape f1/f2) — NO n=6 lattice numerology
  in any performance assertion.** Performance anchors are, and only are,
  **Shannon entropy floor**, **the arithmetic-intensity / memory-
  bandwidth roofline**, and **the cuBLAS-measured FP64 roofline** (real
  math/physics/engineering limits). No `σ(6)=12 / τ(6)=4 / φ(6)=2 /
  J₂(6)=24` value is ever a derivation or a justification for any
  throughput, speedup, or layer-count performance claim. Any lattice-fit
  performance assertion in any future implementation, doc, or falsifier
  is a **hard fail** of this RFC, not a stylistic issue (f1/f2 are
  `deny:write`).
- **PyTorch has years of kernel engineering — catching, then exceeding,
  it is honestly large and multi-cycle.** PyTorch's eager path is backed
  by Triton, FlashAttention, cuDNN, and years of tuning. RFC 043 does
  not pretend the gap is small. The honest position: the *mechanism* for
  exceeding it (AOT whole-program fusion + static-arch specialization)
  is real and named, but realizing it to the point of beating a tuned
  eager-PyTorch on end-to-end throughput is a multi-cycle effort, and
  the near-term target is far more modest (below).

### Staged targets (qualitative — NO fabricated speedup multiple)

No speedup number is asserted anywhere in this RFC. The targets are
qualitative and staged:

- **Near-term**: *feasible + correct at LM scale, hexa-native
  self-sufficient* — the stdlib exists, every op is byte-equal (or the
  RFC-040-measured fp-tolerance) to the verified hexa/boxed reference, a
  full training-step is CPU-bit-equal to the campaign oracle, and a
  d=768·12L train reaches a captured FINAL loss compiled-native **with
  no `.py` dependency** (the deliverable the pure-hexa interpreted path
  could not reach — Phase E2 captured only init gn2).
- **Mid-term**: *match eager-PyTorch on this architecture* — end-to-end
  training throughput for the fixed ConsciousDecoderV2 is in the same
  band as eager-PyTorch on the same GPU (qualitative parity, measured
  the way the campaign measures — captured wall, not a fabricated
  ratio).
- **Ultimate**: *exceed eager-PyTorch via whole-program fusion +
  static-arch specialization* — the north-star; multi-cycle; the win is
  above GEMM (fusion / memory-traffic / overhead-elimination), never at
  the GEMM roofline, never via lattice numerology.

## Verification — §8 / `g_blue_closed_mandate` (the critical section)

Every falsifier runs the **compiled-native** path (`hexa build`, no
Python, no interpreter — matching anima `HEXAD/build_verify.sh` and the
RFC 034 / 040 acceptance convention). Every numeric falsifier compares
against an *existing verified reference*, never a fabricated target. The
stdlib-↔-verified-reference boundary is a `g_blue_closed_mandate`
connection point: verified only when both ends are 🔵 and the transfer
invariant (numerical equivalence within a measured bound) is itself
closed-form checked.

### Falsifier battery (F-RFC043-*)

- **F-RFC043-BUILD** — `hexa build` produces a native binary for the
  full `hexa-torch` stdlib with zero clang redefinition errors; **zero
  `hexa_interp` dispatch** is reachable from any stdlib op (the
  compiler-only constraint is verified structurally, not assumed).
- **F-RFC043-LAYER-EQ** — for **every** nn layer (Linear, RMSNorm,
  RoPE, GQA-attention, SwiGLU, embedding, tied LM head), forward AND
  backward are byte-equal (or the RFC-040 measured `TOL_MATMUL ≈ 2e-9`
  rel where a cuBLAS reduction is involved) to the existing verified
  hexa/boxed `HEXAD/D/d_train5_lib.hexa` reference for that layer. This
  is the per-layer connection-point closed check; it may NOT be replaced
  by a structural "the layer ran" check.
- **F-RFC043-AG-EQ** — the generalized autograd tape reproduces RFC
  034's landed exact result on RFC 034's own reference (the closed B-D-4
  CE-softmax Jacobian `max|grad − (softmax − onehot)| = 0.0`), and the
  generalized tape over the full layer set produces gradients that pass
  a central-difference GRAD-EXACT check (the campaign's
  `GRAD-EXACT(L0.Wg[5])` PASS is the reference; the AOT path must not
  break exact-grad correctness).
- **F-RFC043-STEP-EQ** — one full `train_step` (fwd + CE + bwd + AdamW)
  is **BIT-EQUAL** to the campaign's existing CPU-equivalence oracle:
  d=32·3L·8win·80-AdamW, seed=42, `corpus_consciousness_v1.jsonl`,
  init **gn2 7.97116 → final 3.73374e-07, acc 0/8 → 8/8**
  (`state/hexad_gpu_fire_phaseE2_2026_05_16/cpu_equiv_e2.log`). **Do not
  invent a new target** — the campaign proved this descent is exactly
  reproducible at $0; the hexa-torch path must match it bit-equal. This
  is the mandatory `g_blue_closed_mandate` end-to-end connection-point
  closed check.
- **F-RFC043-WALL-IMPROVED** — the headline acceptance, *qualitative and
  evidence-anchored* (no fabricated speedup): a scale that did **not**
  reach a captured FINAL gn2 under the pure-hexa interpreted path (the
  campaign's d=384·6L: GRAD-EXACT ~182 s, 80-step loop projected
  >60 min, exceeded the 75-min watchdog — Phase E2 §4.3) **does** reach
  a captured FINAL gn2 under the compiler-only `hexa-torch` stack within
  the same cost-bounded window, AND the e2e acceptance: **d=768·12L
  trains to a real captured FINAL loss compiled-native** (Phase E2
  captured only the d=768·12L *init* gn2=7.98162; the goal the pure-hexa
  interpreted path could not reach). The acceptance is "the Phase E2
  C3-4 interpreter ceiling is broken," measured the same way the
  campaign measured it — not a multiple.
- **F-RFC043-MODULE-REGRESSION-0** — the existing `hexa build`
  compiled-module path (anima `HEXAD/build_verify.sh` 24/24 entrypoints
  + 16/16 libs) is **byte-identical** after the hexa-torch stdlib lands
  — no regression to the proven compiled-module path.
- **F-RFC043-DETERMINISM** — `train_step` run twice (seed-fixed):
  byte-identical (the campaign's training is deterministic; hexa-torch
  must preserve that — cuBLAS fixed-algorithm + atomic-free reductions
  per RFC 040).
- **F-RFC043-INVARIANT-PRESERVED** — the HEXAD math/physics invariants
  the d_train5 step must preserve still PASS on the hexa-torch path:
  **CE Shannon-entropy floor** (loss ≥ entropy floor — the g3 real-limit
  anchor) and **Law-70 Ψ-coupling bridge clamp** (`HEXAD/PLAN.md` §8).
  A stdlib swap must NOT change which closed-form invariants hold. The
  real-limit anchor is the Shannon floor + bit-exact reference
  equivalence — **NOT** any lattice tautology (f2).

(≥3 per AGENTS.tape directive; this RFC specifies 8. F-RFC043-STEP-EQ
is the mandatory `g_blue_closed_mandate` connection-point closed check —
the hexa-torch ↔ campaign-oracle bit-equality — and may not be waived.)

The acceptance gate: each phase's falsifier subset PASS on the
compiled-native binary before that phase is counted LANDED. The `*-EQ`
falsifiers are the connection-point closed checks and are mandatory.

## Phasing

Strictly sequential; each phase is its own cycle with its own falsifier
subset and LANDED gate. Effort estimates are honest and deliberately
wide — this is a large multi-cycle effort that *consumes* RFC
040/041/034 (which must land first) and *subsumes* RFC 042.

- **Phase 0 — RFC 040/041/034 landed (prerequisite, not part of 043).**
  hexa-torch's Tensor backend (040), kernel backend (041), and
  autograd-tape foundation (034) must be landed-and-verified first.
  Phase 0 is the dependency gate, not 043 work.
- **Phase 1 — Tensor + generalized autograd tape.** `t_*` over the RFC
  040 device-farr model; generalize RFC 034's tape from "one matmul →
  one CE-softmax" to the general reverse-mode tape over the layer set.
  Falsifiers: F-RFC043-BUILD, -AG-EQ. **Effort: ~1 large cycle.**
- **Phase 2 — nn layers (the ConsciousDecoderV2 building blocks).**
  Linear / RMSNorm / RoPE / GQA-attention / SwiGLU / embedding / tied
  LM head, each fwd+bwd byte-equal to the verified `d_train5_lib.hexa`
  reference. Falsifiers: F-RFC043-LAYER-EQ. **Effort: ~1–2 cycles**
  (each layer small; the per-layer EQ harness pattern is reused).
- **Phase 3 — loss + optimizer + `train_step` (the RFC 042
  subsumption).** `loss_cross_entropy` (RFC 034 landed), `opt_adamw_step`
  (RFC 034 / RFC 041 fused kernel), and the compiled-native
  `train_step` whose existence is what closes RFC 042's interpreter
  ceiling. Falsifiers: F-RFC043-STEP-EQ, -DETERMINISM,
  -MODULE-REGRESSION-0, -INVARIANT-PRESERVED. **Effort: ~1 cycle.**
- **Phase 4 — real d=768·12L compiler-only fire.** vast.ai GPU
  dispatch (`g_fire_autonomous` + `g_fire_dispatch_robust`), the
  d=768·12L train to a captured FINAL loss, fully compiler-only and
  `.py`-free. Falsifiers: F-RFC043-WALL-IMPROVED. **Effort: 1 fire
  cycle; cost ~$2–30/GPU-hr × train hours** (per anima `HEXAD/PLAN.md`
  §9 honest cost envelope).

## Honest caveats (AGENTS.tape g3 / f1 / f2 — no over-claim)

- **Design-only, and it reuses landed work.** RFC 043 lands zero code.
  Its near-term feasibility rests entirely on RFC 034 (LANDED autograd
  tape, compiled 5/5), RFC 040 (Phase D-proven cuBLAS substrate, Phase
  E/E2-proven CPU-bit-equal trainer), RFC 041 (the remaining kernels),
  and the existing verified ConsciousDecoderV2 arch + the Phase E/E2
  CPU-equivalence oracle. RFC 043 is the *consolidating design*, not new
  numeric machinery — the correctness is carried by the campaign's
  already-proven bit-equal descent, not by anything RFC 043 invents.
- **"Beat PyTorch" is an ULTIMATE, mechanism-named, floor-bounded,
  lattice-free, qualitative-staged direction — never a number.** The
  performance thesis section states it exactly that way and that is the
  *only* admissible framing: real mechanism (AOT whole-program fusion +
  static-arch specialization + dispatch-overhead elimination), honest
  floor (cuBLAS GEMM = match not beat — 51.24 TFLOPS = 76 % H100 FP64
  roofline is NVIDIA's, not hexa-torch's), explicit forbidden (no n=6
  lattice perf assertion — f1/f2 `deny:write`, a hard fail), staged
  (near/mid/ultimate, qualitative). Any implementation cycle that states
  a speedup multiple it has no measured basis for, or anchors a
  performance claim on lattice numerology, FAILS this RFC.
- **The ceiling RFC 043 closes is PROVEN, not speculative.** Phase E2
  *measured* (not hypothesized) that the wall is interpreter control
  flow, after eliminating GPU routing (done+correct, on-A100 GRAD-EXACT
  PASS + Mac bit-equal) and host fatness (251 GB / 128 vCPU let
  d=768·12L init complete) as the bottleneck. RFC 043's RFC-042
  subsumption is anchored to that measured C3-4 conclusion.
- **Numeric correctness is NOT the open problem.** The campaign's Mac
  CPU-equivalence gate already proves the full gn2 descent is *exactly*
  correct (`7.97116 → 3.73374e-07`, bit-equal, reproducible at $0). RFC
  043 is a *stdlib-structure + execution-model* consolidation, not a
  correctness fix; F-RFC043-STEP-EQ references the existing exact oracle
  precisely so no new correctness target is fabricated.
- **GPU/CUDA is an environment assumption (inherited from RFC 040).**
  The compiler-only stdlib's no-CUDA build is byte-identical to the CPU
  path (RFC 040's `#ifndef HEXA_CUDA` fallback); the GPU path builds and
  falsifier-verifies only on a CUDA host (Phase 4 = vast.ai dispatch).
- **cuBLAS dependency, not a from-scratch GEMM.** hexa-torch's GEMM is
  cuBLAS `Dgemm` (RFC 040 Phase A path). A hand-tuned competitive GEMM
  is an explicit non-goal — the win is above GEMM, never at it.
- **Large, multi-cycle, dependency-gated.** anima `HEXAD/PLAN.md` §9
  names this class "대형 다-사이클 프로젝트". RFC 043 is the design
  entry point that *unifies* the three campaign-isolated ceilings; it
  does not pretend the implementation is small or near-term.

## Non-goals (v1 / this RFC)

- No implementation — no `runtime.c` / codegen / `.cu` / build edit.
  Design draft only.
- No benchmark, no fabricated speedup multiple, no asserted
  throughput ratio. The performance thesis is mechanism + floor +
  forbidden + qualitative-staged only.
- No hand-written competitive CUDA GEMM (cuBLAS `Dgemm` per RFC 040).
- No interpreter path for any stdlib op — the constraint is
  compiler-only by construction (aligns with the interpreter-deprecation
  directive); `hexa run` support is explicitly out of scope.
- No general autograd beyond the ConsciousDecoderV2 op set (the same
  scoping discipline RFC 034 applied — only the layers the verified arch
  uses).
- No multi-GPU / distributed, no CUDA-graph capture (inherited RFC 040
  non-goals).
- No re-design of RFC 040/041/034 — they are *consumed*, not
  re-specified; only RFC 042 is subsumed (its goal met by 043's stdlib
  structure).
- No replacement of the RFC 032 CPU `farr_matmul` — it stays the
  bit-exact oracle and the no-GPU fallback.

## Cross-RFC dependency

- **RFC 040** (device-farr + cuBLAS Dgemm) — **the `Tensor` backend**.
  Consumed, not superseded. hexa-torch `t_matmul` / device residence =
  RFC 040.
- **RFC 041** (Phase B/B2 real CUDA kernels) — **the op-kernel
  backend**. Consumed, not superseded. The kernels behind
  nn-layer/loss/optimizer ops.
- **RFC 042** (AOT-native trainer control-flow) — **SUBSUMED**. Its
  interpreter-ceiling goal is met by hexa-torch's fat-native-stdlib +
  thin-hexa-orchestration structure; its heavier driver-loop execution-
  model framing is no longer needed. 042 → folded into 043.
- **RFC 034** (landed reverse-mode AD tape) — **the autograd-tape
  FOUNDATION**. Generalized (not re-designed) from "one matmul → one
  CE-softmax" to the full ConsciousDecoderV2 op-set tape.
- **RFC 035** (bf16 mixed-precision) — hexa-torch's bf16 training path
  reuses RFC 035's `adamw_step_mixed` (byte-identical to RFC 034
  `adamw_step` per RFC 035's LOSSSCALE-INVARIANT falsifier).
- **RFC 025 / 031 / 032 / 033** — the farr substrate (mmap handle
  table, bf16→f32 reader, matmul, copy/noise) RFC 040 already extends;
  hexa-torch inherits transitively.
- **RFC 026 / 028** — the `HEXA_CUDA=0` force-CPU env convention RFC
  040 follows; hexa-torch's no-CUDA build inherits it.

## Cross-link (campaign evidence — g3)

- anima `docs/anima_rfc040_phase_d_h100_cublas_2026_05_16.md` §2.1/§2.2
  — the real-H100 cuBLAS FP64 roofline (51.24 TFLOPS = 76 % H100 peak;
  `TOL_MATMUL ≈ 2e-9` measurement-calibrated) — the honest GEMM floor.
- anima `docs/anima_rfc040_phase_e2_backward_fathost_2026_05_16.md` §3
  / §4.3 / §5 + `state/hexad_gpu_fire_phaseE2_2026_05_16/result.json`
  `headline` / `honest_C3` C3-1/C3-4/C3-6 — the CPU-bit-equal oracle
  (`7.97116 → 3.73374e-07`) + the PROVEN interpreter ceiling
  (independent of routing/host) RFC 043 closes.
- anima `docs/anima_rfc040_phase_e_d_train5_gpu_routed_2026_05_16.md`
  §4 — the same ceiling first observed (thin host), Phase E2 proved it
  persists on a fat host.
- anima `HEXAD/PLAN.md` §9 — the GPU-substrate / d=768·12L hexa-native
  roadmap; RFC 043 is its long-term hexa-native consolidation (042
  subsumed, backed by 041 kernels + 040 tensor + 034 autograd).
- anima `HEXAD/INDEX.md` — the verified 7-module ConsciousDecoderV2
  architecture whose layer set hexa-torch's nn surface mirrors exactly.
- anima `AGENTS.tape` §0 `g_blue_closed_mandate` — every artifact AND
  connection point 🔵 closed; F-RFC043-STEP-EQ / -LAYER-EQ are the
  connection-point closed checks.
- anima `AGENTS.tape` `g3` / `f1` / `f2` — the real-limit anchor
  (Shannon floor + cuBLAS roofline + bit-exact reference equivalence);
  the explicit no-lattice-fit / no-lattice-tautology performance
  constraint (a hard fail, `deny:write`).
- anima `g_fire_autonomous` + `g_fire_dispatch_robust` — Phase 4
  vast.ai GPU dispatch governance.
