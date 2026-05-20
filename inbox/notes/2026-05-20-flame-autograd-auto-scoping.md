# flame autograd-auto cycle — scoping (READ-ONLY)

> **Type**: scoping note (no code changes).
> **Author**: agent, 2026-05-20.
> **Mission**: scope the "autograd auto" cycle for flame (north-star
> ①, gap-b in `project_flame_general_pytorch_replacement_goal`).
> **g3 honesty**: this note is provisional. It clarifies what "auto"
> can mean for flame in concrete terms, and proposes ONE smallest
> first sub-deliverable. It does NOT propose anything unmeasured —
> the first deliverable's gate is byte-eq vs the existing ag_tape.
>
> **Important framing correction (g3)**: the memory pointer
> `project_flame_general_pytorch_replacement_goal.md` lists 5 gaps
> with "autograd수동" as gap-b. The flame SSOT `design.md` Decision
> 6 + 7 + 12 reports **gap(b) FULLY CLOSED** as of 2026-05-19
> (Tests 1-17 PASS; mk2 closure measured PASS step1=139s on A100).
> What is "closed" in design.md = the **generic tape-based replay
> of hand-written vjps** at machine-eps. What memory calls "수동"
> = the next layer — **automatic derivation of the backward
> primitive from the forward primitive**. They are not the same
> "auto". This note treats the user's request as scoping the
> NEXT layer (auto-derivation), not re-opening Decision 6.

## 1. Current state — what flame's autograd looks like today

flame's autograd is a **tape-based reverse-mode runtime with
HAND-WRITTEN per-op vjps**. Two layers:

**Layer 1 — `stdlib/flame/nn_lib.hexa` (~720 lines).** For each
primitive, a hand-derived `nn_<op>_fwd` and `nn_<op>_bwd` pair.
The math is hand-written closed-form vjp. Today: rmsnorm, linear,
rope, lmhead, swiglu, embedding, attn_core, ffn_bf16. Adding a
new primitive ≡ hand-deriving + hand-coding the bwd.

Example (`nn_linear_bwd`, nn_lib.hexa:93-141): three nested loops
implementing the closed-form `dW = xᵀ·dy`, `dx = dy·Wᵀ`,
`db = Σ_rows dy`. ~50 lines of code per primitive.

**Layer 2 — `stdlib/flame/ag_tape.hexa` (~1000 lines).** The
generic reverse-mode tape:

- `ag_<op>(tape, ...)` recorders call `nn_<op>_fwd`, save state,
  append a tape node `{kind, 8 input/state ids, 4 dims}`.
- `ag_backward_reg(tape, out_tid, seed)` walks nodes
  latest→first, looks up the saved state, dispatches the matching
  `nn_<op>_bwd`, and accumulates results into a per-tensor grad
  registry keyed by tensor id (Decision 3, the standard
  reverse-mode design).
- 13 op kinds wired today (`ag_k_*` ids 1..13): rmsnorm, linear,
  rope, lmhead, swiglu, embed, attn, add, rope_mh, slice,
  silu_gate, rmsnorm_mh, attn_dt.

**Layer 3 — `stdlib/flame/ag_spec.hexa` (Decision 7).**
Declarative spec IR — a model is DATA (an array of
`{kind, inputs[], params[], dims[]}` entries), and `ag_run_spec`
walks it dispatching the Layer-2 `ag_<op>` recorders. This means
"add new op kind" requires updating: nn_lib (fwd+bwd) + ag_tape
(recorder + backward case) + ag_spec dispatcher.

**Cost of adding ONE new op today** (measured by source diff
on the existing ops, e.g. mk2-C5's `farr_transpose_2d_gpu`
addition): roughly
- `nn_lib.hexa`: +30..80 LoC (fwd + bwd hand-derived).
- `ag_tape.hexa`: +15..40 LoC (`ag_k_*` id + recorder +
  `ag_backward_reg` case + free state).
- `ag_spec.hexa`: +5 LoC (dispatcher case).
- new oracle in `flame_ag_tape_test.hexa`: +30..50 LoC.

Total ≈ 80..175 LoC + a byte-eq oracle, per primitive. The
verified leaf oracle bar is `max|Δ|=0` (Tests 1-12, Decision 6).
**Backward correctness is the LLM/human-derived math, not
machine-derived.** That is exactly the "manual" the memory note
flags. Decision 6 closure is about the **tape plumbing**; the
**vjp derivation** is still human work per primitive.

## 2. What "autograd auto" can mean concretely — three options

Three distinct mechanisms are all called "auto" in the AD
literature. Picking one matters because their gates are
different. Pre-registering scope choice:

**Option A — operator overloading / tracing (PyTorch-style).**
Define forward in a special `dual` type that records grads as it
runs. Per-op user supplies only fwd; the bwd is derived from
recorded primitives' vjps. **In flame this is what ag_tape
ALREADY does** — `ag_<op>` recorders trace the forward call and
the registry walks the trace in reverse. Decision 6 closes this
to machine-eps. **Not a new layer; not the gap.**

**Option B — source-to-source reverse-mode AD (Tapenade /
JAX `jit(grad)` / Zygote-style).** Take a `pub fn <op>_fwd` in
hexa-lang source, analyze its AST/IR, emit a `<op>_bwd` whose
body is the symbolic vjp of the fwd. The compiler does what a
human does today by hand. **This is the "auto" the memory note
implies** — eliminates the hand-derived bwd per primitive. New
infrastructure; affects the hexa-lang compiler (or a stdlib
preprocessor stage) and cites the atlas (g6).

**Option C — JVP composition (forward-mode AD).** Express bwd
as transposed forward-mode. Cheaper to implement (no graph
reversal) but inefficient for many-input-1-output (the common
NN case). **Wrong tool for flame's GOAL** (LM training =
1-output many-input).

**Pick: Option B (source-to-source reverse-mode AD).**
Rationale:
- B is the only one that ELIMINATES per-primitive hand-derivation
  — the actual gap-b cost. A is the existing layer; C is the
  wrong shape for LM bwd.
- B is hexa-native + atlas-citable. The vjp rules ARE atlas
  theorems (chain rule, transpose of linear, etc.) — strict-lint
  stage 4 (g6) provides the citation enforcement substrate.
  Mature AD systems (Tapenade, Zygote, Enzyme) prove the
  approach is feasible at compile-time.
- B can be staged: scope a tiny op subset first, prove byte-eq
  vs the existing hand-written bwd, expand from there. Each
  expansion has the existing `nn_<op>_bwd` as a byte-eq oracle.

**What B is NOT (g3 carve-outs)**:
- NOT magic. The vjp rules are still hand-encoded — but ONCE per
  vjp **rule** (e.g. "vjp of matmul = transpose × upstream"),
  not once per layer instance. The economy is in re-use.
- NOT a replacement for forge GPU kernels. The generated bwd
  bodies are CPU hexa loops by default; routing to
  `farr_matmul_gpu` / `farr_*_gpu` is gap(d), separate cycle.
- NOT bit-equivalent to existing hand-fused decoder bwd. Per
  Decision 6, machine-eps is the correct bar for any real
  autograd; bit-equivalence to hand-fused was over-spec.

## 3. Sub-deliverable 1 — smallest concrete first PR

**SD1: `stdlib/flame/ag_derive.hexa` — vjp-rule registry +
single-rule prototype for `farr_matmul`.**

Concretely:
- New file `stdlib/flame/ag_derive.hexa`. Contains a vjp-rule
  registry data structure (farr-backed, ag_tape idiom): each
  rule = `{op_kind, fn_pointer_to_bwd_body}`.
- ONE rule registered: `farr_matmul` → emits the standard vjp
  pair `dW = xᵀ·dy`, `dx = dy·Wᵀ`. The "emit" is at
  COMPILE-TIME via a hexa stdlib function called from a thin
  pre-pass — NO compiler core changes (mirrors Decision 2
  "C-무수정 + hexa-side tape").
- A new test file `flame_ag_derive_test.hexa` with ONE test:
  given a 1-op forward `y = matmul(x, W)`, derived bwd must be
  **byte-identical** to `nn_linear_bwd`'s output (existing hand-
  written reference). Same idiom as the existing 17-test
  `flame_ag_tape_test`.

LoC budget (estimate, to be validated when the cycle opens):
- `ag_derive.hexa`: ~150 LoC (rule registry + 1 rule).
- `flame_ag_derive_test.hexa`: ~80 LoC (1 byte-eq oracle).
- `design.md`: +1 Decision section (Decision 13 — autograd-auto
  scope).
- `FLAME.tape`: +1 falsifier entry.
- `PLAN.md`: +1 progress-log entry.

**What SD1 is NOT** (to keep it small + measurable):
- No second rule. matmul only.
- No integration into ag_tape — the derived bwd is verified
  standalone vs `nn_linear_bwd`. Integration is SD2.
- No model-level test. Only the one matmul-vjp byte-eq.
- No forge routing.

**Stop-condition / "scope unclear, blocks on X" honest carve-out**:
SD1 assumes hexa-lang has a stdlib mechanism for inspecting an
existing function's call graph at compile time (or that ag_derive
encodes rules manually keyed by op_kind, NOT extracted from AST).
If neither is feasible, SD1 collapses to "manually-keyed rule
registry" (the second option) — same bytes, narrower claim.
Either way the SD1 gate (byte-eq vs nn_linear_bwd) is valid.

## 4. Gates — how each sub-cycle is known done

**SD1 gate (this scoping closes when SD1 is filed as a separate
PR with these passing)**:
- `F-RFC043-AUTOGRAD-AUTO-MATMUL-BYTE-EQ`: derived
  `matmul_bwd_auto(x, W, dy)` output {dW, dx} byte-identical
  (max|Δ|=0) to `nn_linear_bwd`'s {dW, dx} on a fixed seed input
  (B=4·D=8·C=6 or similar; same shape pattern as Test 2 in
  `flame_ag_tape_test`).
- `F-RFC043-MODULE-REGRESSION-0`: existing 17/17 flame_ag_tape
  tests + RFC 034 5/5 + RFC 040 B2 9/9 all PASS unchanged
  (g3 minimal blast-radius; ag_derive is additive).
- Build: `hexa parse stdlib/flame/ag_derive.hexa` and
  `flame_ag_derive_test.hexa` parse-clean; `hexa build` of
  `flame_ag_derive_test.hexa` compiles. CPU-only, $0.

Measurable. byte-eq or PASS/FAIL. No GPU spend.

**Future sub-cycles (out of scope for this scoping; named for
sequencing only)**:
- SD2: add 2 more rules (`farr_add`, elementwise `silu`) — same
  byte-eq oracle vs existing hand-written counterparts.
- SD3: rules for the remaining 10 ag_k_* primitives (rmsnorm,
  rope, lmhead, swiglu, embed, attn, attn_dt, rope_mh, slice,
  silu_gate, rmsnorm_mh).
- SD4: ag_tape integration — `ag_<op>` recorder accepts
  ag_derive's generated bwd in place of `nn_<op>_bwd`; full
  17-test byte-eq.
- SD5 (open question, NOT pre-committed): true AST-driven
  derivation from a hexa-lang `fn`'s source — requires compiler
  hook. Decide AFTER SD2/SD3 establish the rule-table baseline.

Each SD has its own falsifier registered in `FLAME.tape` before
work starts; each SD is a separate user-gated PR (per
`g_plan_consolidation` + flame Phase Gating).

## 5. References

- `stdlib/flame/design.md` Decision 1, 2, 3, 6, 7, 12 (gap(b)
  closure history).
- `stdlib/flame/ag_tape.hexa` (Layer-2 generic tape, 1000 LoC).
- `stdlib/flame/nn_lib.hexa` (Layer-1 hand-derived vjps, 720
  LoC).
- `stdlib/flame/ag_spec.hexa` (Layer-3 declarative spec IR).
- `inbox/rfc_drafts_2026_05_12/rfc_043_hexa_torch_compiler_only_nn_stdlib.md`
  (RFC 043, design SSOT).
- Memory: `project_flame_general_pytorch_replacement_goal.md`
  (gap-b naming origin).
- Memory: `project_flame_mk2_cycle_2026_05_19.md` (mk2 closure
  measured PASS, defines current "machine-eps" baseline).

## 6. One-line summary

Pick **Option B (source-to-source reverse-mode AD via rule
registry)**, start with **SD1 = ONE rule for `farr_matmul`**,
**gate = byte-eq vs `nn_linear_bwd` (max|Δ|=0) + 17/17 +
RFC 034/040 regression PASS**.
