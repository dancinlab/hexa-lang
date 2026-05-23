# flame: 3 spiking-substrate primitives (event-threshold, refractory, STDP-pair)

**Filed by**: anima (downstream consumer) — LEGO arc §138 hexa-native engine
design (2026-05-20). anima edits NO flame/hexa-lang source per
`g_train_flame_not_pytorch upstream_downstream_invariant`; this is a
patch-request only. Precedent: `flame-path-a-dual-head-and-multiterm-grad.md`
(§71, same downstream-consumer posture).

**Status**: `resolved-ssot 2026-05-20 — 3 primitives + 4 falsifier landed; parse-gate clean; binary promote = standard separate deploy step per 22c27a05 pattern.`

> **VERIFIED-CLOSED 2026-05-20**: stdlib/flame/spiking_lib.hexa + flame_spiking_test.hexa landed on origin/main via commit `4426d4e4` (F-SPIKE-1..4 4/4 PASS). status flipped from "PR on branch flame-spiking-substrate-primitives" to "resolved-ssot 2026-05-20 — 3 primitives + 4 falsifier landed; parse-gate clean; binary promote = standard separate deploy step per 22c27a05 pattern."

## Problem

The flame stdlib (`~/core/hexa-lang/stdlib/flame/`) was built for **dense
gradient-descent NN training** — the d768·12L decoder, RFC 043 hexa-torch.
Its `farr` array primitives cover matmul (`farr_matmul`, RFC 032),
element-wise add, Gaussian noise (`farr_add_gaussian_noise`, RFC 033),
copy/slice, reductions, and the `dt_*` hand-Taylor transcendentals.

anima's LEGO arc (§115–§137, the §96 Loihi spiking-substrate re-derivation)
runs a **Leaky-Integrate-and-Fire (LIF) spiking substrate**, not a dense
GD-NN. The canonical engine is `HEXAD/LEGO/lego_engine.py` (Python+numpy
reference). Every numerical op in it maps to existing flame/`farr`
primitives **except three** — and those three cannot be worked around
downstream because they are *event-driven dynamics* with no `farr`
equivalent:

1. **`flame_event_threshold(farr v, scalar v_th) -> farr`**
   Boolean spike mask: `1.0` where `v >= v_th`, else `0.0`. A spiking
   substrate's defining operation. `farr` is float-typed with no
   element-conditional comparison primitive.

2. **`flame_refractory_step(farr refr, farr spiked, int refrac, int floor) -> farr`**
   Per-unit integer countdown: units that spiked are set to `refrac`,
   others decrement by 1, clamped at `floor`. Stateful per-unit counters —
   `farr` has no integer-countdown-with-clamp primitive.

3. **`flame_stdp_pair(farr W, farr tr_pre, farr tr_post, farr spike,`**
   **`scalar A_plus, scalar A_minus, scalar w_max) -> farr`**
   Local pair-based STDP weight update:
   `ΔW = A_plus·outer(spike, tr_pre) − A_minus·outer(tr_post, spike)`,
   diagonal zeroed, result clipped to `[−w_max, w_max]`. This is a LOCAL
   learning rule — depends only on pre/post eligibility traces, NEVER on
   a loss gradient. flame's gradient path (`nn_decoder_grad`) is the wrong
   shape — it is backprop-CE, not local STDP.

These three are exactly the hexa-bio `NEURO.tape` mechanisms
`mech_action_potential` (membrane threshold) + `mech_plasticity` (cortical
co-adaptation = local STDP) expressed as `flame`-callable array ops.
hexa-bio **describes** them; flame does not yet **expose** them.

## Why anima cannot work around it downstream

A hand-rolled spiking layer on top of raw `farr` (boolean masking via
arithmetic tricks, manual countdown loops, hand-coded outer products) is
exactly the "fork the stdlib / hand-roll" anti-pattern the `hexa-first`
mandate warns against. The honest path is the one `hexa-first` prescribes:
"when the constraint lives in hexa-lang itself, fix it there — PR-only."

The constraint here lives in flame's stdlib (no spiking primitives), not in
anima. So anima files this request and stays a downstream consumer.

## Requested API surface

```
flame_event_threshold(farr v, scalar v_th)              -> farr   # 0.0 / 1.0 mask
flame_refractory_step(farr refr, farr spiked,
                      int refrac, int floor)             -> farr   # integer countdown
flame_stdp_pair(farr W, farr tr_pre, farr tr_post,
                farr spike, scalar A_plus, scalar A_minus,
                scalar w_max)                            -> farr   # local ΔW + clip
```

## Pre-registered falsifiers

```
F-SPIKE-1  THRESHOLD-BOOLEAN     mask ∈ {0.0, 1.0} ∀; monotone non-decreasing in v;
                                 v=v_th boundary → 1.0 (>= semantics).
F-SPIKE-2  REFRACTORY-CLAMP      refr never below floor; spiked units → refrac
                                 exactly; non-spiked decrement by exactly 1.
F-SPIKE-3  STDP-LOCALITY         ΔW depends only on {tr_pre, tr_post, spike};
                                 structural audit confirms no loss/grad term;
                                 diagonal of ΔW is 0; result ∈ [−w_max, w_max].
F-SPIKE-4  BYTE-EQUAL-VS-NUMPY   on seed 1337, matches HEXAD/LEGO/lego_engine.py
                                 numpy reference (LIFNet.step) byte-equal over
                                 an 80-step run (N=256: n_a=96/n_g=96/n_rec=64).
```

## anima-side reference

`HEXAD/LEGO/lego_engine.py` (anima repo, §134 byte-equal §117 restore) is the
**numpy reference oracle**. Its `LIFNet.step` is the canonical semantics for
all three primitives. Once they land in flame, `HEXAD/LEGO/lego_engine.hexa`
is a mechanical port verified byte-equal against the `.py` reference via
F-SPIKE-4. The LEGO arc §138 DESIGN.md
(`HEXAD/LEGO/state/lego_hexa_native_design_s138_2026_05_20/DESIGN.md`)
records the full anima-side analysis.

## Scope note

One concept per file (per `inbox-patches-pipeline`): this file is *only* the
3 spiking primitives. The Loihi-2 hardware mapping (which uses these same
mechanisms as native silicon) is a separate anima-side design
(`HEXAD/LEGO/state/lego_loihi_spec_s121_2026_05_20/`) and needs no flame
change — it targets Intel Lava, not flame.
