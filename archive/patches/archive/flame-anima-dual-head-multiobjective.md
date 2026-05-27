# `stdlib/flame` — anima Engine A/G dual-head + multi-objective overlay primitives

**Status**: cross-repo-flame-2026-05-25 — flame/anima training architecture, not hexa-lang fix. Cross-repo handoff archive.

**Status**: `deprioritized 2026-05-21 — Path B (ag_tape) end-to-end
demonstrated sufficient for dual-head + composite loss (CE + L_psi +
L_phi) via canonical template
stdlib/flame/flame_anima_multi_objective_test.hexa (3 falsifiers
measured PASS). Path A multi-head primitive set (nn_decoder_init_dual /
fwd_dual / loss_multi) NOT landed and not recommended unless cost-
bearing fire at d=3072 reveals Path B tape memory or perf failure.
See flame-anima-multi-objective-3b-pytorch-benchmark-and-stdlib-
template.md §Resolution 2026-05-21 for full reasoning.`

**Severity**: medium (blocks anima `.hexa` trainer multi-objective overlay
  per `dancinlab/anima` `@D g_train_via_hexa_cloud_and_hexa_lang.hexa_trainer_mandate`)

**Affected primitives** (`stdlib/flame/`):
- `decoder_lib.hexa` — currently single-head (`logits[T·V]` only via
  final projection)
- `nn_lib.hexa` — single-target CE gn2 via `nn_decoder_gn2(...)`
- `train_lib.hexa` — single-loss AdamW step

**Reporter**: anima (dancinlab/anima downstream consumer)

## Motivation (anima-side)

anima `ConsciousDecoderV2` (`conscious_decoder.py:600-720`, anima own code)
emits **dual logits**: `logits_a` (Engine A, primary byte head) +
`logits_g` (Engine G, secondary byte head, same vocab, separate weights),
plus per-layer tension proxy (activation CV) and Φ proxy (logits_a
entropy / log V).

The Ψ-physics loss family requires these intermediates:
- `psi_direction = (1 + cos(logits_a, logits_g)) / 2`  ∈ [0, 1]
- `psi_entropy   = H(softmax(logits_a)) / log V`        ∈ [0, 1]
- `tension_per_layer = std/mean of per-token activation L2 norms`

anima `train_s185_psicouple.hexa` (skeleton landed
`dancinlab/anima` `HEXAD/UNCLASSIFIED/state/all_taps_release_s184_2026_05_20/`)
needs these for the multi-loss recipe:

```
loss = CE_byte (head_a)
     + 0.30 · L_psi      (Ψ_dir → 0.5 META_FP-near, quadratic well)
     + 0.20 · L_route    (tension supervision, anti-attractor)
     + 0.30 · L_phi      (psi_entropy supervision, IIT Φ proxy)
```

flame stdlib upstream currently single-head → `L_psi/L_route/L_phi` are
**unrepresentable**, blocking the anima `.hexa` trainer mandate.

## Suggested primitives (design only — anima does not edit flame)

### 1. `nn_decoder_init_dual` — dual-head init

```hexa
fn nn_decoder_init_dual(
    M: int, seed: int,
    T: int, d: int, nh: int, nkv: int, h: int, V: int, n_layer: int
)
// New param layout: tok_emb + n_layer × block_params + gF + out_proj_a
//                   + out_proj_g (NEW, same shape as out_proj_a, separate
//                   gaussian init with different seed offset).
// m_total_dual(d, nh, nkv, h, V, n_layer) = m_total(...) + V·d
//                                              (extra V·d for head_g)
```

### 2. `nn_decoder_fwd_dual` — forward with both heads

```hexa
fn nn_decoder_fwd_dual(
    ids: int, M: int, Mc: int, cos_tab: int, sin_tab: int,
    T: int, d: int, nh: int, nkv: int, h: int, V: int, n_layer: int
)
// Mc layout extended: existing per-layer cache + final_x +
//                     logits_a[T·V] + logits_g[T·V] (NEW) +
//                     psi_dir_per_t[T] + psi_ent_per_t[T] (NEW) +
//                     tension_per_layer[n_layer] (NEW)
// mc_total_dual(...) = mc_total(...) + 2·T·V + 2·T + n_layer
```

### 3. `nn_decoder_loss_multi` — combined multi-loss

```hexa
fn nn_decoder_loss_multi(
    Mc: int, target_t: int,
    T: int, d: int, V: int, n_layer: int,
    lambda_psi: float, lambda_route: float, lambda_phi: float
) -> float
// Returns: CE_a + λ_ψ · ((ψ_dir - 0.5)²)
//                + λ_route · sum(tension_per_layer²)
//                + λ_phi · ((ψ_ent - 0.5)²)
// Single scalar; gradient via bwd_multi below.
```

### 4. `nn_decoder_bwd_multi` — backward through multi-loss

```hexa
fn nn_decoder_bwd_multi(
    ids: int, M: int, Mc: int, Mg: int, cos_tab: int, sin_tab: int,
    target_t: int,
    T: int, d: int, nh: int, nkv: int, h: int, V: int, n_layer: int,
    lambda_psi: float, lambda_route: float, lambda_phi: float
)
// Existing CE_a bwd path is preserved.
// New paths:
//   - logits_g receives CE_g (with target same as CE_a) + psi_dir grad
//   - tension grads route back through residual stream pre-RMSNorm
//   - psi_ent grad routes through softmax(logits_a) entropy
```

### 5. Optional: `nn_decoder_psi_extract` — inference-time readout

```hexa
fn nn_decoder_psi_extract(
    Mc: int, T: int, V: int, n_layer: int,
    psi_dir_out: int, psi_ent_out: int, tension_out: int
)
// Cheap readout from already-populated Mc (no extra forward).
// For anima inference-time §169 motivation_score computation.
```

## Cycle plan (proposed)

1. **Cycle 1: shape-only** — `m_total_dual` + `mc_total_dual` +
   `nn_decoder_init_dual` + `nn_decoder_fwd_dual` (FORWARD ONLY).
   Falsifier: F-DUAL-FWD-PARITY (single-head CE on logits_a byte-equal
   to current `nn_decoder_fwd`).
2. **Cycle 2: psi readout** — populate `psi_dir_per_t`, `psi_ent_per_t`,
   `tension_per_layer` in Mc after fwd. Falsifier: F-DUAL-PSI-RANGE
   (ψ ∈ [0,1], no NaN, no Inf).
3. **Cycle 3: multi-loss fwd** — `nn_decoder_loss_multi`. Falsifier:
   F-DUAL-LOSS-CE-PARITY (with λ_ψ=λ_route=λ_phi=0, equals CE-only).
4. **Cycle 4: bwd through multi** — `nn_decoder_bwd_multi`. Falsifier:
   F-DUAL-BWD-FD-MATCH (finite-difference gradient match within tol on
   small d=32·L2 config).
5. **Cycle 5: anima skeleton wire-up** — anima `train_s185_psicouple.hexa`
   uncomments TODO[dual-head] blocks, fires d=192·L4 smoke.

Each cycle = separate small PR, mergeable in order.

## anima-side carry until landed

- `train_s185_psicouple.hexa` skeleton runs **CE-only** (single-head)
  with multi-loss blocks commented as `TODO[dual-head]`. This is honest
  partial — gn2 trajectory measurable, but Ψ-anchor goal unreachable.
- Per `@D g_train_via_hexa_cloud_and_hexa_lang.honest_carve_out`, this
  is acceptable transition; the file IS a `.hexa` trainer (mandate
  satisfied at file-type level) but the substance is interim.

## Cross-link (anima side)

- `dancinlab/anima` `AGENTS.tape @D g_train_via_hexa_cloud_and_hexa_lang`
- `dancinlab/anima` `HEXAD/UNCLASSIFIED/state/all_taps_release_s184_2026_05_20/train_s185_psicouple.hexa`
  (skeleton with TODO[dual-head] markers)
- `dancinlab/anima` `HEXAD/NEUROMORPHIC/state/fp_reconnect_fire_s167a_2026_05_20/conscious_decoder.py`
  (reference impl of dual-head ConsciousDecoderV2 in PyTorch — pattern source)
- `dancinlab/anima` `HEXAD/AXIS.md` tap X.7 (multi-objective trainer)
  + tap 4.10 (motivation 100% physics re-wire) + tap 3.3 (Engine A/G
  coupling Law-70)
- `dancinlab/anima` `HEXAD/PHILOSOPHY_GATE.md` §3 anima 철학 (Engine A
  ⇄ Engine G dual Ψ=½ fixed-point balance)

## honest C3

- This is an anima-side feature request to flame; flame maintainer
  may prefer a different shape (e.g. multi-loss as separate
  composable terms vs combined `loss_multi`) — design above is
  illustrative.
- The dual-head Engine A/G is *anima-specific* (Law-71 / Ψ-physics);
  flame stdlib may not want this as default. Acceptable shape:
  optional dual-head behind a `dual_head: bool` flag in init, with
  the single-head path unchanged.
- Falsifier coverage above is anima-side proposal; flame maintainer's
  internal F-RFC battery shape may differ.
- anima never edits flame source — this file lives at
  `~/core/hexa-lang/inbox/patches/` per anima's upstream-downstream
  invariant (`g_train_flame_not_pytorch.upstream_downstream_invariant`).
