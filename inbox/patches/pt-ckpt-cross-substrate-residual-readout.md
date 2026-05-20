# PyTorch `.pt` ckpt cross-substrate import + per-step residual readout

**Filed by**: anima (downstream consumer) — §168 PHI-THRESHOLD-POSTHOC
probe (2026-05-20). anima edits NO flame / hexa-lang source per
`g_train_flame_not_pytorch upstream_downstream_invariant`. Patch-request
only, distinct from §71 inbox patch (RFC 059 training-time complement)
— this one is **post-hoc inference-time** measurement on already-
trained PyTorch checkpoints.

## Problem

anima's `§161-FIRE` / `§167-A` ckpts (1.13 GB `.pt`, ConsciousDecoderV2
d768·12L·283.72M) were trained on the Python lane. The hexa-runtime
`c_lib.hexa::c_measure_phi` (RFC 036 `phi_spatial` builtin, LANDED +
byte-equal to `phi_rs` oracle) needs a `farr` handle of last-layer
residual states — but there is no hexa-runtime path to:

1. **Load a PyTorch `.pt` state_dict into flame Path-A device-resident
   layout** (`m_total` / `mc_total`). RFC 031 (`farr_load_bf16_to_f32`)
   exists for single BF16 buffers — no one-shot import for a whole
   nn.Module tree.

2. **Read per-step intermediate residual state during forward**.
   Path-A `_agt_decoder_step` is structurally fused; no exposed
   `state_readout(layer_idx)` to grab the residual `x` between
   `self.ln_f(x)` and `self.head_a(x)` (the natural Φ measurement
   point per `conscious_decoder.py:724-725`).

The minimal need is **post-hoc**: one ckpt forward over N≤32 stimulus
contexts, dump residual snapshots, feed them to `c_measure_phi`. NOT
live training-time integration (that lives in RFC 059 / §71).

## Two clauses, one concept

### Clause A — `flame_load_pt_state_dict(path) -> mc_total handle`

One-shot loader that reads a PyTorch `.pt` state_dict pickle and
populates the Path-A device-resident `mc_total` buffer for a config
matching anima's d768·12L·V256·nh12·nkv4 layout. MoE / non-mappable
layers (PureFieldFFN-vs-SwiGLU, dual head_a/head_g) skipped with
explicit diagnostics.

### Clause B — `flame_decode_step_with_readout(state, ctx, layer_idx) -> (logits, residual_farr)`

`_agt_decoder_step` variant returning residual `farr` handle at
`layer_idx ∈ {0..n_layer-1, "final"}`. anima will call with `"final"`
for Φ measurement at the post-`ln_f` pre-head_a residual.

## Why a single patch

Both clauses are pre-conditions of one anima-side flow (load →
forward-with-readout → `c_measure_phi`); separating yields zero
independent value.

## Honest non-blockers

- Some keys won't map (PureFieldFFN, dual head_g, MoE) — anima accepts
  the probe is on the SwiGLU-mapped backbone with unmapped tails noted
  (mirrors §71 honest-scope carry).
- Probe is **necessary-not-sufficient** for GOAL (B-EMERGE-7); a
  passing post-hoc Φ does not claim emergence, only that Φ-axis
  35%-weight (per `HEXAD/CONNECTION_CRITIQUE.md`) is measurable.

## Pre-registered anima-side falsifiers (when patch lands)

- F-PTLOAD-1: loaded `mc_total` byte-equal `.pt` for mappable backbone
  subset.
- F-PTLOAD-2: backbone-only forward reproduces Python lane logits
  within fp64 rounding (max|Δ| < 1e-3 per HEXA_NATIVE Phase 5 ledger
  cumulative-drift extrapolation).
- F-PHIREAD-3: `c_measure_phi(residual_farr, n_cells=12, dim=64,
  n_bins=*)` returns Φ ≥ 0 ∀ contexts (F-C-PORT-3 invariant).
- F-PHIREAD-4: Φ probe deterministic per (ckpt, ctx_seed) — 3× run
  bit-identical.
- F-PHIREAD-5: NO weight mutation across N probe forwards (`mc_total`
  byte-equal pre/post — read-only contract).

## Out of scope

- Training-time integration of `c_measure_phi` into gradient path:
  §71 / RFC 059 territory.
- Per-token RoPE-rotated KV-cached multi-token decode: probe uses
  single-pass forward over 128-byte noise context.
- Live `phi_signal` consciousness feedback: training-time, out of
  post-hoc scope.

## Cross-link

- `~/core/anima/HEXAD/UNCLASSIFIED/state/phi_threshold_posthoc_probe_2026_05_20/DESIGN.md`
- `~/core/anima/HEXAD/CONNECTION_CRITIQUE.md` (the diagnosis that
  surfaced the Φ-axis 35%-weight measurement gap).
- §71 inbox patch `flame-path-a-dual-head-and-multiterm-grad.md`
  (RFC 059 training-time complement; this patch is inference-time
  half).
- RFC 036 `c_lib.hexa::c_measure_phi → phi_spatial` (consumer this
  patch unblocks).
- RFC 031 `farr_load_bf16_to_f32` (closest existing primitive, scope-
  extended by Clause A).
