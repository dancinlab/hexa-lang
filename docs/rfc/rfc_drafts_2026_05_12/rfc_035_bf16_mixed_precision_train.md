# RFC 035 — `farr` bf16/fp16 mixed-precision training (loss scaling)

- **Status**: implemented (2026-05-16)
- **Date**: 2026-05-16
- **Severity**: MEDIUM (FP32 alone suffices for the first anima HEXAD
  fire; bf16 = memory + cloud-cost reduction for Phase 5/6 scale-up)
- **Priority**: P1 (anima PR #80 RFC trigger spec item #2; RFC 034
  Roadmap named follow-up — depends on RFC 034)
- **Source convergence**: `anima/HEXAD/PLAN.md` Phase 5 (D training,
  lower-memory) + RFC 034 §Roadmap "RFC 035 — bf16/fp16 mixed-precision
  training (depends on RFC 034)"
- **Source session**: anima 2026-05-16 — `"hexa-lang upstream 은
  여기서 진행"` + `"worktree 방식 go"` (R4 of the HEXAD run list). The
  forward + FP32 train path landed in RFC 034 (`8793a221`, compiled
  5/5); RFC 035 adds the AMP storage/optimizer surface so the same
  pure-hexa decoder train step can run at lower memory on the eventual
  Phase 6 integration ckpt fire ($1-5 cloud).

## Implementation status (2026-05-16)

**LANDED** as a 3-builtin minimal mixed-precision layer on the RFC 034
reverse-mode AD path. The forward/grad numerics stay packed-double
(the RFC 032/034 contract); RFC 035 adds (1) a deterministic bf16
storage round-trip and (2) a loss-scaled, skip-on-nonfinite AdamW that
keeps an f64-equivalent master weight while consuming a (possibly
bf16-rounded) low-precision gradient — the PyTorch/NVIDIA AMP
master-weight contract.

- `self/runtime.c` — native impl block immediately after the RFC 034
  `hexa_adamw_step`:
  - `_hx_f32_to_bf16` — round an IEEE binary32 to bf16 (top 16 bits,
    1s|8e|7m), **round-to-nearest-even** on the bf16 ulp; NaN/Inf
    preserved (NaN keeps a non-zero bf16 mantissa). Bit-exact; no
    hardware bf16 needed; same rounding PyTorch AMP uses.
  - `hexa_farr_to_bf16(src,dst,n)` / `hexa_farr_from_bf16(src,dst,n)` —
    write bf16-rounded values of `src[0..n]` into `dst`. Both
    length-`n` packed-double farrs. Idempotent: a bf16-representable
    value is a fixed point (`F-RFC035-BF16-ROUNDTRIP`).
  - `hexa_adamw_step_mixed(p,g,m,v,n,lr,b1,b2,eps,wd,t,loss_scale)` —
    12-arg. Unscales the consumed gradient (`g/loss_scale`) before the
    moment update so the f64 master weight sees the *true* gradient.
    Scans the unscaled grad for non-finite (the AMP overflow signal);
    if **any** element is NaN/Inf the **whole step is skipped** (no
    partial mutation) and `0` is returned (caller then halves
    `loss_scale` — the standard dynamic-loss-scale policy, caller-driven
    in v1). Returns `1` if applied. Single fused in-place loop, zero
    HexaVal in the hot path (RFC 032 contract, extended).
- `self/runtime.c` — declaration block after the RFC 034 carriers:
  forward decls + **external-linkage** `HexaVal` carriers for the
  3-arg builtins (`farr_to_bf16` / `farr_from_bf16`) + an external
  `HexaVal adamw_step_mixed(...)` (12-arg) wrapper past the
  `hexa_callN` ceiling — exactly the RFC 034 / RFC 038
  generic-fallback link contract, made link-clean for the runtime.h
  multi-TU split.
- `self/runtime.c::_hexa_init_fn_shims` — `hexa_fn_new` registration
  (arity 3) for the bf16 carriers. A comment notes this draft RFC 035
  (bf16) is **distinct** from the pre-existing 2026-05-13 internal
  "RFC 035" Nelder-Mead `farr_simplex_*` builtins (different
  namespace; no collision).
- `self/runtime.h` — ABI decls for `hexa_farr_to_bf16` /
  `hexa_farr_from_bf16` / `hexa_adamw_step_mixed` + the
  external-linkage fallback symbols (`extern HexaVal farr_to_bf16;`
  etc. + the 12-arg `adamw_step_mixed` proto).
- `self/codegen_c2.hexa` — AOT dispatch entries (3-arg
  `farr_to_bf16` / `farr_from_bf16`; new 12-arg `adamw_step_mixed`
  block). SSOT for a future `hexa cc --regen`; NOT required for the
  compiled smoke, which links via the runtime.c fallback symbols
  (same deferral rationale as RFC 034 — the committed `hexa_cc.c` on
  `stage2-verify` is out-of-sync with `self/parser.hexa`; a faithful
  regen rebaselines ~9 k unrelated parser lines, out of scope for an
  additive RFC commit).
- `self/hexa_full.hexa::call_builtin` — interp dispatch mirror.
- `self/native/hexa_cc.c` + `self/native/hexa_v2` — **deliberately
  unchanged** (same rationale as RFC 034).
- Smoke: `tmp_rfc035_smoke.hexa` (worktree root).

**Acceptance — 5/5 PASS on the compiled native binary** (`hexa build
tmp_rfc035_smoke.hexa -o build/rfc035_smoke && ./build/rfc035_smoke`,
no Python, no BLAS):

1. **BUILD+PARSE** — PASS (native binary built, no clang redefinition
   errors; only the pre-existing benign `runtime.h:310` comment
   warning, shared with RFC 034).
2. **BF16-ROUNDTRIP** — PASS, `to_bf16` then `to_bf16` is a byte-exact
   fixed point (max idempotent diff = `0.0`) and the bf16 value is
   within `0.00306201` relative error of the f64 original (`< 1%`, the
   8-bit-mantissa bound).
3. **LOSSSCALE-INVARIANT** — PASS, `adamw_step_mixed` with
   `loss_scale = 1024` on a grad pre-multiplied by `1024` produces
   parameters **byte-identical** (max diff = `0.0`) to plain RFC 034
   `adamw_step` on the unscaled grad over 5 steps — the AMP
   master-weight equivalence.
4. **SKIP-NONFINITE** — PASS, a gradient with one `+Inf` element →
   `adamw_step_mixed` returns `0` and the parameter farr is
   byte-unchanged (no partial mutation; the AMP overflow contract).
5. **DETERMINISM** — PASS, two seed=999 runs byte-identical (max
   diff = `0.0`).

Built with the **unmodified committed `stage2-verify` transpiler**
(`HEXA_LANG`→worktree so the worktree `runtime.c`/`runtime.h` link).
Regression: RFC 034 smoke re-built + re-run **5/5 PASS** with the same
committed toolchain (these changes are purely additive).

Honest caveats (AGENTS.tape g3):

- bf16 in v1 is a **value-exact storage round-trip**, not a byte-count
  reduction: the underlying farr arena is still packed-double, so the
  *memory bytes* are unchanged in v1; what is exact is the bf16
  *numerics* (the low 16 mantissa bits are discarded round-to-even),
  which is what training stability/convergence actually depends on. A
  true half-width arena (a `bf16_farr` storage class) is a separate,
  larger follow-up and is **NOT** claimed here. The v1 win is: the
  anima train step can now be run in bf16 *numerics* and AMP
  loss-scaled, validating the policy before a storage-format change.
- The dynamic loss-scale *schedule* (when to halve/grow the scale) is
  **caller-driven** in v1: the builtin only reports overflow via the
  `0` return; it does not maintain a scale state machine. This is the
  minimal surface; a built-in scaler is a follow-up, not a v1 gate.
- The interp (`hexa run`) dispatch mirror is wired in
  `self/hexa_full.hexa` but not exercised here — acceptance is gated
  on the *compiled* path (the interp is deprecating, banned in gates).
- The `codegen_c2.hexa` branches are SSOT for the next
  `hexa cc --regen`; the compiled smoke proves the runtime.c
  external-linkage fallback path (same dual-path validity as RFC 034).
- This closes only the AMP *mechanism* (bf16 round-trip + loss-scaled
  skip-on-nonfinite AdamW exist, are exact and deterministic). Whether
  bf16 numerics *converge as well as* FP32 on anima's real corpus
  remains empirical — true of every AMP run, per anima `B-D-NOTE`. No
  over-claim.

## Problem

RFC 034 landed pure-hexa **FP32** training (CE + AdamW). For the anima
HEXAD Phase 6 integration ckpt fire ($1-5 cloud), FP32 master weights +
FP32 activations double the activation/gradient memory versus a
mixed-precision (bf16 forward, f32 master) run. Every modern training
stack (PyTorch AMP, NVIDIA Apex, JAX) uses bf16/fp16 compute with f32
master weights + loss scaling to halve memory and roughly double
throughput. anima's pure-hexa path has no such surface: there is no
`farr` op that rounds to bf16 and no optimizer that unscales a
loss-scaled gradient or skips an overflow step. Without it the Phase 5
lower-memory directive (`HEXAD/PLAN.md`) cannot be met in hexa-native
code, forcing a Python AMP fallback the project rejects (PR #80).

## Proposal

A minimal mixed-precision layer on the RFC 034 AD path. Scope is
intentionally minimal: **bf16 storage round-trip + loss-scaled AdamW
with skip-on-nonfinite**, exactly what an AMP anima decoder train step
needs.

### Surface

```hexa
// --- bf16/fp16 storage round-trip (deterministic, RNE rounding) ---
pub fn farr_to_bf16(src: int, dst: int, n: int) -> int    // 1 ok / 0 err
pub fn farr_from_bf16(src: int, dst: int, n: int) -> int   // 1 ok / 0 err

// --- loss-scaled mixed-precision optimizer ---
//   master weight stays f64; consumed grad is the low-prec tensor;
//   grad is unscaled by loss_scale before the moment update; if any
//   unscaled grad element is non-finite the WHOLE step is skipped.
pub fn adamw_step_mixed(param: int, grad: int, m: int, v: int, n: int,
                        lr: float, beta1: float, beta2: float,
                        eps: float, wd: float, t: int,
                        loss_scale: float) -> int   // 1 applied / 0 skip
```

### Why bf16 RNE + AMP-skip are builtins, not composed

bf16 round-to-nearest-even and the unscale-then-overflow-check are the
two numerically load-bearing AMP operations. Composing them in hexa
from bit ops would (a) be slow per element and (b) risk a rounding
mismatch with the PyTorch reference anima compares against. One fused
native op per concern gives the acceptance test a deterministic oracle
(byte-identical to plain `adamw_step` under the loss-scale invariant).

### Algorithm

- bf16: `x32 → round-to-nearest-even on bit 15 → keep top 16 bits →
  reconstruct float`. NaN/Inf class preserved.
- `adamw_step_mixed`: pass 1 scans `g_i / loss_scale` for non-finite →
  if any, return 0 (no mutation). Pass 2 = RFC 034 AdamW on the
  unscaled gradient, f64 master weight, decoupled weight decay,
  bias-corrected.

## Acceptance criteria (falsifier-ready)

`tmp_rfc035_smoke.hexa` must, via the **compiled** path (`hexa build …
&& ./<bin>`, no Python, no BLAS — the interpreter `hexa run` is
deprecating, gated on the native binary, matching anima
`HEXAD/build_verify.sh`):

1. **BUILD+PARSE** — `hexa build` produces a native binary with no
   clang redefinition errors.
2. **BF16-ROUNDTRIP** — `to_bf16∘to_bf16` is a byte-exact fixed point
   and `|bf16 − f64| / |f64| < 1%` (8-bit mantissa bound).
3. **LOSSSCALE-INVARIANT** — `adamw_step_mixed(loss_scale=S)` on a
   grad×S equals plain RFC 034 `adamw_step` on the unscaled grad,
   byte-identical, over a multi-step loop.
4. **SKIP-NONFINITE** — a grad with one Inf → step skipped (return 0,
   params byte-unchanged).
5. **DETERMINISM** — same seed → byte-identical param trajectory twice.

5/5 PASS → RFC 035 landable; anima `HEXAD/PLAN.md` Phase 5
lower-memory D-training is hexa-native-expressible.

## Downstream consumer

- `anima/HEXAD/D/d.hexa` — AMP variant of the RFC 034 train step.
- `anima/HEXAD/hexad.hexa` — lower-memory 6-module train step for the
  Phase 6 integration ckpt fire ($1-5 cloud, bf16 = cost save).
- anima `HEXAD/PLAN.md` Phase 5 (D training, lower-memory).

## Roadmap (follow-up — lower priority)

- A true half-width `bf16_farr` storage class (actual byte halving, not
  just value-exact rounding) — larger arena change, separate RFC.
- A built-in dynamic loss-scaler state machine (grow/backoff schedule)
  so the caller need not drive it.

## Non-goals (v1)

- No half-width storage arena — v1 is value-exact bf16 numerics on the
  existing packed-double arena (memory bytes unchanged in v1).
- No built-in loss-scale schedule — caller-driven (the `0` return is
  the overflow signal).
- No fp8 / tf32 / other formats. bf16 only (the anima/PyTorch default).
- No distributed / multi-device. Single-process, single-arena
  (inherits RFC 034 Non-goals).

## Cross-link

- RFC 034 `farr` reverse-mode autograd (the AD path this layers on;
  `adamw_step` is the FP32 twin the loss-scale invariant checks
  against)
- RFC 031 bf16→f32 safetensors load (RFC 034 named this RFC's bf16
  dependency; the *load* direction — RFC 035 adds the *train-round-trip*
  direction)
- anima `HEXAD/PLAN.md` Phase 5 (lower-memory D training)
- anima PR #80 RFC trigger spec item #2
- anima `state/verify_hexad_blue_2026_05_15/blue_falsifier.py`
  `B-D-NOTE` (SGD/AMP convergence OUTCOME = honest empirical carve-out)
