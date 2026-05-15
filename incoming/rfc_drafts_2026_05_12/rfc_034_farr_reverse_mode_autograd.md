# RFC 034 — `farr` reverse-mode autograd (CE loss + AdamW step)

- **Status**: proposed (2026-05-16)
- **Date**: 2026-05-16
- **Severity**: HIGH (blocks pure-hexa training — anima HEXAD 6-module integration fire)
- **Priority**: P0 (anima `HEXAD/PLAN.md` Phase 5 BLOCKER; PR #80 RFC trigger spec #1)
- **Source convergence**: `anima/HEXAD/PLAN.md` §2026-05-16 task (c) DEFERRED — RFC trigger spec
- **Source session**: anima 2026-05-16 — user directive `"fire 연기 · hexa-native
  autograd RFC 먼저 열어달라"` + `"PLAN.md 진행 hexa-lang upstream go"`. anima
  inference path is pure-hexa (RFC 025/030/031/032/033 landed; `anima_chat.hexa`
  v0.3 24L byte-parity 21/21 PASS), but **training** (CE backprop + optimizer)
  still has no hexa-native path — `HEXAD/D/d.hexa` carries `TODO[pytorch]`,
  `B-D-NOTE` honestly carves out "SGD convergence OUTCOME = empirical" because
  there is no closed-form *and* no hexa-native autograd to run it.

## Problem

anima's `HEXAD/` hexa-native canonical tree (PR #78/#79) reaches the
integration fire gate on the **forward** side only:

- forward: pure-hexa ✓ (RFC 032 `farr_matmul` + RFC 031 bf16→f32 + RFC 033
  `farr_copy`/`farr_add_gaussian_noise` → 24-layer real-ckpt byte-parity).
- training: ✗ — no `farr` op produces a gradient, no optimizer step exists
  in hexa. The only path today is Python (`torch.autograd`), which violates
  the anima governance directive *"코드는 hexa-native"* and forces the
  6-module integration ckpt fire (`HEXAD/PLAN.md` Phase 5-6) into a mixed
  Python/hexa mode that the project explicitly rejected (PR #80).

A pure-hexa training step needs reverse-mode automatic differentiation
over the same packed-double `farr` buffers that RFC 032 matmul already
operates on, plus one optimizer update. Scope is intentionally minimal:
**cross-entropy loss + AdamW**, which is exactly what
`state/verify_hexad_we_2026_05_15/we_falsifier.py` F-D-3 and the integration
harness `state/verify_hexad_integ_2026_05_16/integ_harness.py` F-INTEG-5
exercise on the Python side today.

## Proposal

A minimal tape-based reverse-mode AD layered on the existing `farr`
typed-arena contract (no HexaVal boxing in the hot loop — same constraint
RFC 032 solved for matmul).

### Surface

```hexa
// --- gradient tape ---
pub fn ad_tape_begin() -> int                       // open a tape, returns tape_id
pub fn ad_tape_end(tape_id: int)                    // close + free tape

// --- differentiable ops (record onto the open tape) ---
//   each returns an out farr_id and records the backward closure.
pub fn ad_matmul(A: int, Ar: int, Ac: int, B: int, Bc: int) -> int   // wraps RFC 032
pub fn ad_add(a: int, b: int, n: int) -> int
pub fn ad_mul(a: int, b: int, n: int) -> int
pub fn ad_relu(x: int, n: int) -> int
pub fn ad_softmax_cross_entropy(logits: int, n_rows: int, n_cols: int,
                                targets: int) -> float   // returns scalar loss,
                                                         // records ∂L/∂logits

// --- backward + optimizer ---
pub fn ad_backward(loss_tape: int)                  // reverse sweep, fills grads
pub fn ad_grad(param_farr: int) -> int              // grad farr_id for a leaf
pub fn adamw_step(param: int, grad: int, m: int, v: int, n: int,
                  lr: float, beta1: float, beta2: float,
                  eps: float, wd: float, t: int)     // in-place AdamW update
```

### Why CE-softmax is a builtin, not composed

The exact softmax-cross-entropy logit-Jacobian is closed-form
`∂CE/∂z_i = softmax(z)_i − [i = t]` (sympy-verified in anima
`state/verify_hexad_blue_2026_05_15/blue_falsifier.py` B-D-4). Implementing
it as one fused native op (forward scalar loss + the closed backward) avoids
a deep composed tape for the single most common training loss and gives the
acceptance test a deterministic gradient to check.

### Algorithm

- Tape = append-only list of `(op, in_farr_ids, out_farr_id, backward_fn)`.
- Forward records; `ad_backward` walks the tape in reverse, each
  `backward_fn` is a native C closure reading/writing packed-double `farr`
  via `double*` (zero HexaVal in the sweep — RFC 032 pattern).
- `adamw_step` is a single fused native loop over the param/grad/m/v farrs.
- FP32 only in v1 (bf16 training = follow-up RFC 035, see Roadmap).

## Acceptance criteria (falsifier-ready)

A `tmp_rfc034_smoke.hexa` must, via `hexa run` (no Python, no BLAS):

1. **PARSE** — file parses cleanly (`hexa parse`).
2. **GRAD-EXACT** — for `ad_softmax_cross_entropy` on a fixed small logits
   farr + target, `ad_grad(logits)` equals `softmax(logits) − onehot(t)`
   element-wise within `1e-9` (matches anima B-D-4 sympy identity).
3. **LOSS-DECREASES** — a 20-step loop (`ad_*` forward → `ad_backward` →
   `adamw_step`) on a fixed-seed random linear layer reduces CE:
   `loss[19] < loss[0]` (anima `B-D-NOTE` SGD-outcome empirical witness).
4. **PARAM-MUTATED** — parameter farr hash after 20 steps ≠ hash before
   (training actually happened, not a no-op).
5. **DETERMINISM** — same seed → byte-identical loss trajectory across two
   runs (no nondeterministic kernel).

5/5 PASS → RFC 034 landable; anima `HEXAD/PLAN.md` Phase 5 unblocks and the
6-module integration ckpt fire ($1-5 cloud) re-gates.

## Downstream consumer

- `anima/HEXAD/D/d.hexa` — replaces `TODO[pytorch]` training markers.
- `anima/HEXAD/hexad.hexa` — single-hexa-process 6-module **train** step
  (currently forward + falsifier only).
- `anima/state/verify_hexad_integ_2026_05_16/integ_harness.py` — its
  F-INTEG-5 CE-descent gets a pure-hexa twin (`F-INTEG-FIRE-2`).
- anima `HEXAD/PLAN.md` Phase 5 (D training) → Phase 6 (통합 fire).

## Roadmap (follow-up RFCs, lower priority — anima PR #80 spec items 2–3)

- **RFC 035** — bf16/fp16 mixed-precision training (depends on RFC 034;
  medium priority — FP32 alone suffices for first fire, bf16 = cost save).
- **RFC 036** — Rust FFI binding so hexa-native C-engine can call
  `phi_rs.compute_phi(states, n_groups)` byte-equal to Python (medium;
  anima `HEXAD/PLAN.md` Phase 4 Φ measurement, not a fire-entry blocker).

## Non-goals (v1)

- No general N-d broadcasting AD — only the ops listed (matmul/add/mul/relu/
  CE-softmax) needed by the anima 6-module decoder train step.
- No graph optimization / fusion beyond the fused CE-softmax + AdamW.
- No distributed / multi-device. Single-process, single-arena.

## Cross-link

- anima `HEXAD/PLAN.md` §2026-05-16 RFC trigger spec #1 (this RFC = its
  upstream realization)
- anima `state/verify_hexad_blue_2026_05_15/blue_falsifier.py` B-D-4
  (closed-form CE Jacobian — acceptance #2 oracle)
- RFC 032 `farr_matmul` (forward primitive this AD wraps)
- RFC 031 bf16→f32 (RFC 035 follow-up dependency)
- RFC 033 `farr_copy` / `farr_add_gaussian_noise` (tape leaf init helpers)
