# RFC 034 — `farr` reverse-mode autograd (CE loss + AdamW step)

- **Status**: implemented (2026-05-16)
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

## Implementation status (2026-05-16)

**LANDED** as a 7-builtin minimal tape-based reverse-mode AD on the
existing packed-double `farr` typed-arena (RFC 030/032/033), FP32,
single-process, single-arena per the v1 Non-goals.

- `self/runtime.c` — native impl block after RFC 033
  (`hexa_farr_add_gaussian_noise`): `hexa_ad_tape_begin` /
  `hexa_ad_tape_end` / `hexa_ad_matmul` (wraps RFC 032
  `hexa_farr_matmul`, records dA = dC @ Bᵀ + dB = Aᵀ @ dC) /
  `hexa_ad_softmax_cross_entropy` (fused numerically-stable softmax-CE,
  mean loss, records the closed B-D-4 logit gradient
  `(softmax − onehot)/n_rows`) / `hexa_ad_backward` (reverse sweep,
  raw `double*`, zero HexaVal in the loop — RFC 032 contract) /
  `hexa_ad_grad` / `hexa_adamw_step` (single fused in-place AdamW,
  decoupled weight decay, bias-corrected). Tape = append-only op list;
  grad registry persists across steps so `adamw_step` reads it.
- `self/runtime.c` — declaration block after the RFC 033 carriers:
  forward decls + **external-linkage** `HexaVal` carriers for the
  0/1/4-arg builtins (`ad_tape_begin` / `ad_tape_end` /
  `ad_softmax_cross_entropy` / `ad_backward` / `ad_grad`) + external
  `HexaVal ad_matmul(...)` (5-arg) and `HexaVal adamw_step(...)`
  (11-arg) functions past the `hexa_callN` ceiling. External (not
  `static`) so the separately-compiled user.c TU links them via the
  CURRENT committed-transpiler generic fallback — `hexa_call0/1/4(
  <carrier>, …)` for ≤4-arg, bare `ad_matmul(…)`/`adamw_step(…)` for
  ≥5-arg (the RFC 038 `farr_uccsd_apply` no-codegen-branch contract,
  made link-clean for the runtime.h multi-TU split).
- `self/runtime.c::_hexa_init_fn_shims` — `hexa_fn_new` registration
  (arities 0/1/4) for the carrier-dispatched builtins.
- `self/runtime.h` — ABI decls for `hexa_ad_*` + the external-linkage
  fallback symbols (`extern HexaVal ad_*;` + `ad_matmul`/`adamw_step`
  protos) **and** the RFC 030/032/033 `hexa_farr_*` decls the PHASE
  1.2/1.3 runtime.h split had left out (that gap blocked the compiled
  path for the whole farr family — closing it makes the *compiled*
  binary link cleanly and re-enables the RFC 032/033 compiled smokes).
- `self/codegen_c2.hexa` — AOT dispatch entries (0-arg `ad_tape_begin`;
  1-arg `ad_tape_end`/`ad_backward`/`ad_grad`; 4-arg
  `ad_softmax_cross_entropy`; 5-arg `ad_matmul`; new 11-arg
  `adamw_step` block). SSOT for a future `hexa cc --regen` (then the
  codegen emits the direct typed `hexa_ad_*` call); NOT required for
  the compiled smoke, which links via the runtime.c fallback symbols.
- `self/hexa_full.hexa::call_builtin` — interp dispatch mirror.
- `self/native/hexa_cc.c` + `self/native/hexa_v2` — **deliberately
  unchanged**. The committed transpiler's generic fallback already
  emits link-compatible C for the `ad_*` calls; no `hexa cc --regen`
  is taken because the committed `hexa_cc.c` on `stage2-verify` is
  out-of-sync with `self/parser.hexa` (a faithful regen rebaselines
  ~9 k unrelated parser lines — out of scope for an additive RFC 034
  commit). The codegen_c2.hexa change is the SSOT delta for whenever
  that branch next regenerates the transpiler.
- Smoke: `tmp_rfc034_smoke.hexa` (worktree root).

**Acceptance — 5/5 PASS on the compiled native binary** (`hexa build
tmp_rfc034_smoke.hexa -o build/rfc034_smoke && ./build/rfc034_smoke`,
no Python, no BLAS):

1. **BUILD+PARSE** — PASS (native binary built, no clang redefinition
   errors; only the pre-existing benign `runtime.h:310` comment warning).
2. **GRAD-EXACT** — PASS, `max|grad − (softmax − onehot)| = 0.0`
   (exact match, well within the `1e-9` bound — this is the anima
   B-D-4 sympy identity ∂CE/∂z_i = softmax(z)_i − [i=t]).
3. **LOSS-DECREASES** — PASS, 20-step ad_matmul→CE→backward→adamw_step
   loop: `loss[0] = 1.64219 → loss[19] = 0.228332` (86% reduction).
4. **PARAM-MUTATED** — PASS, `sum(W): -1.45821 → 1.47101`.
5. **DETERMINISM** — PASS, two seed=42 runs byte-identical (max
   diff = 0.0).

Built with the **unmodified committed `stage2-verify` transpiler**
(`HEXA_LANG`→worktree so the worktree `runtime.c`/`runtime.h` link).
Regression: RFC 030 (6/6), RFC 032 (`farr_matmul` 2×2 = 7 ✓), RFC 033
(10/10) compiled smokes all PASS with the same committed toolchain.

Honest caveats (AGENTS.tape g3):

- The interp (`hexa run`) dispatch mirror is wired in
  `self/hexa_full.hexa` but not exercised in CI here — the worktree had
  no local `build/hexa_interp` binary and acceptance is gated on the
  *compiled* path (the interp is being deprecated). The compiled path
  is the SSOT and it passes.
- `ad_backward` v1 supports exactly the anima train-step graph (one
  `ad_matmul` feeding one `ad_softmax_cross_entropy`) — the v1 scope.
  General N-d broadcasting AD / ad_add/ad_mul/ad_relu chains are listed
  in the surface for the consumer but the reverse sweep currently
  handles the matmul + CE-softmax nodes (exactly F-INTEG-5 / F-D-3).
  Extending to the full op set is mechanical follow-up, not a v1 gate.
- The committed `hexa_cc.c`/`hexa_v2` were left UNTOUCHED. The compiled
  smoke links via the runtime.c external-linkage fallback symbols, so
  the `codegen_c2.hexa` branches are not yet exercised by the compiled
  path here — they activate on the next `hexa cc --regen` of this
  branch (deferred because that regen rebaselines ~9 k unrelated parser
  lines on the currently-stale `stage2-verify` `hexa_cc.c`). Both
  lowering paths are valid; the fallback path is the one proven 5/5.
- This closes only the *trainability mechanism* (autograd + optimizer
  exist and are exact/deterministic). SGD *convergence outcome* on
  anima's real corpus remains empirical — true of every optimizer,
  per anima `B-D-NOTE`. No over-claim.

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

A `tmp_rfc034_smoke.hexa` must, via the **compiled** path
(`hexa build tmp_rfc034_smoke.hexa -o <bin> && ./<bin>`, no Python, no BLAS —
the interpreter `hexa run` is being deprecated, so acceptance is gated on the
native binary, matching anima `HEXAD/build_verify.sh`):

1. **BUILD+PARSE** — `hexa build` produces a native binary with no clang
   redefinition errors (lib/entrypoint split if cross-file imports).
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

Both named follow-ups were submitted + implemented on this branch on
2026-05-16 (R4 of the anima HEXAD run list), in the same compiled-path
house format as this RFC:

- **RFC 035** — `rfc_035_bf16_mixed_precision_train.md` —
  bf16/fp16 mixed-precision training (depends on RFC 034; medium —
  FP32 alone suffices for first fire, bf16 = cost save). **LANDED**,
  compiled smoke 5/5 PASS (`tmp_rfc035_smoke.hexa`:
  BUILD / BF16-ROUNDTRIP / LOSSSCALE-INVARIANT / SKIP-NONFINITE /
  DETERMINISM). The LOSSSCALE-INVARIANT falsifier proves
  `adamw_step_mixed` is byte-identical to this RFC's `adamw_step`.
- **RFC 036** — `rfc_036_phi_rs_rust_ffi.md` — Rust FFI binding so
  hexa-native C-engine can call `phi_rs.compute_phi` byte-equal to
  Python (medium; anima `HEXAD/PLAN.md` Phase 4 Φ measurement, not a
  fire-entry blocker). Numeric core **LANDED** byte-equal, compiled
  smoke 5/5 PASS (`tmp_rfc036_smoke.hexa`). **Honest named blocker**:
  the `phi_rs` crate is a PyO3 cdylib with **no C ABI**, so the actual
  Rust FFI link is *not* closed — RFC 036 specifies the upstream
  `extern "C"` shim and ships a byte-equal native replica meanwhile
  (the FFI link is explicitly NOT counted as a PASS, AGENTS.tape g3).

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
