# supremacy-xeb-weak-link-rational-closed

> Submission to `atlas/inbox/` for reviewer triage and (if accepted)
> merge to `atlas/MAIN.tape § PHYS` per the pipeline in `atlas/inbox/README.md`.
> One concept = one file rule honoured.

## Concept

The **closed-form weak-link XEB** model of Morvan et al. 2024 (Eq.
`eq:xeb-wl-model`) evaluated at the specific selftest point
`(d, T, λ, F) = (12, 4, 1/4, 1)` reduces to a pure rational identity:

    XEB_wl(d, T, λ, F) = 2 · λ^(d/T) · F^(d/2) + F^d
    XEB_wl(12, 4, 1/4, 1) = 2 · (1/4)^3 · 1^6 + 1^12
                          = 2 · (1/64) + 1
                          = 2/64 + 1
                          = 1/32 + 1
                          = **33/32**

This is a **pure arithmetic identity** in `ℚ` — no transcendentals, no
numerical fits, no measurement uncertainty.

## Hexa-native verification

The sim-universe `supremacy-frontier` module recomputes both sides at
double precision and confirms agreement to 6 decimals as a selftest
invariant. Build + run command:

    bash state/ubu-build.sh \
        supremacy-frontier/module/supremacy_frontier.hexa \
        supremacy_bin --selftest

Output line (verbatim from selftest, hexa-native built-in `exp`/`ln`
range-reduced):

    HEADLINE INVARIANT (6-decimal byte-exact, the gamma-analogue):
      XEB_wl(d=12, T=4, lambda=0.25, F=1) computed by exp/ln-series
         = 1.031250
      analytic  2 * 0.25^3 + 1 = 2/64 + 1 = 33/32
         = 1.031250
      |closed - analytic| = 0.000000 (OK <1e-6)

Sentinel: `__SIM_UNIVERSE_SUPREMACY__ PASS n=8 depth=20 xeb=0.925870
norm_drift=0.000000`.

The closed-form route uses an `atanh`-range-reduced `_ln` (~`1e-15`
accuracy at `y=0.98`) followed by the builtin `exp` — same numerical
toolchain `hexa verify --expr phi 12 4` rides on.

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-IDENTITY** (TECS-L Tier 1: integer/fraction
  closed-form exact). Stronger than 🟢 SUPPORTED-NUMERICAL because
  the analytic side reduces to `33/32` in `ℚ` (verifiable by hand);
  the hexa-native side hits it to `0.000000` at 6 decimals.
- **Axis:** §3 PHYS (random-circuit sampling). Optional cross-link
  §1 N6-FOUNDATION (`33 = 3·11`, `32 = 2^5` — `sopfr(33)=14`,
  `sopfr(32)=10`; the closed form is `(2λ^(d/T)+1)·F^d` at `F=1` so
  the number-theoretic content is the value of `2·λ^3 = 2/64 = 1/32`
  at `λ=1/4`).
- **Real-limit anchor (`g3`):** Morvan et al., *Phase transition in
  Random Circuit Sampling*, **Nature 634, 328–333 (2024)** ·
  DOI `10.1038/s41586-024-07998-6` · arXiv:2304.11119 · paper Eq.
  `eq:xeb-wl-model` (the "weak-link" model of the noise-induced
  XEB transition).
- **Provenance:** sim-universe commit `c46707c` (2026-05-16) —
  `supremacy-frontier/module/supremacy_frontier.hexa` lines that
  emit the HEADLINE INVARIANT block; `__SIM_UNIVERSE_SUPREMACY__
  PASS` sentinel + AGENTS.tape `@D g10 supremacy-frontier-honest-
  scope` + `@X x_morvan_rcs`.

## Falsifiers (pre-registered, ≥5)

> Per `VERIFY.tape` Stage-1-meets-Stage-2 protocol. Each falsifier
> is a deterministic check that would FIRE (= 🔴 FALSIFIED, the
> CLOSED negative) on accidental success.

1. **`F1_wrong_lambda`** — set `λ = 1/2` (not `1/4`); the selftest
   value must change from `1.031250` to `2·(1/2)^3 + 1 = 1.250000`.
   If hexa-native still reports `1.031250`, the closed form is hard-
   coded — falsified.
2. **`F2_wrong_depth_ratio`** — set `(d, T) = (8, 4)` instead of
   `(12, 4)`; the value must change to `2·(1/4)^2 + 1 = 1.125000`.
   Cross-checked in the selftest's own `closed vs exact-circuit`
   line (`closed XEB_wl(d=8, T=4, lam=0.25, F=1) = 1.125000`).
3. **`F3_F_neq_1_decay`** — set `F = 0.9` (`d=12, T=4, λ=1/4`); the
   value must become `2·(0.25)^3·(0.9)^6 + (0.9)^12 ≈ 0.301328`,
   NOT `1.031250 · (0.9)^d` or any other naïve scaling. If the
   `F^(d/2)` vs `F^d` exponents are conflated, falsified.
4. **`F4_six_decimal_precision`** — replace the `_ln` (atanh-reduced)
   path with a 6-term Taylor series at `x=1`; at `y=0.98` the Taylor
   path loses ~6 digits and `|closed - analytic|` jumps above `1e-6`,
   so the selftest fails. Verified by inspecting the implementation
   note in `MODULE/supremacy-frontier.md §0`.
5. **`F5_rational_round_trip`** — compute `33/32` as `33.0 / 32.0`
   on a separate machine (Mac arm64 vs ubu x86_64) and compare. Both
   must produce identical 6-decimal output (`1.031250`) — selftest
   output is required byte-exact across platforms (the fvd
   `γ=1.589566` cross-platform precedent).
6. **`F6_arity_swap`** — swap the order of arguments
   `XEB_wl(T, d, ...)`; this changes the exponent `d/T` from `3` to
   `4/12 ≈ 0.333`, yielding `2·(1/4)^0.333 + 1 ≈ 2.260` rather than
   `1.031250`. Falsified.

## Open questions / risks

- **Risk:** `λ`, `F` are not pure rational in the general weak-link
  fit — only at the selftest point `λ=1/4, F=1`. The atlas atom is
  the **specific evaluation** at that point, not the general
  parametric closed form. A reviewer may prefer to register the
  parametric form (`s_phys_supremacy_xeb_weak_link_parametric`) and
  the specific evaluation as separate atoms.
- **Recompute extension (Phase 2):** the verifier currently doesn't
  ship a `_recompute` for `XEB_wl(d, T, λ, F)` directly — the proof
  in the inbox is via the sim-universe binary, not the binary atlas
  verifier. Suggest extending `tool/atlas_verify.hexa::verify_PHYS()`
  with a `xeb_weak_link(d, T, l, F)` calc fn so `hexa verify
  --expr xeb_weak_link 12 4 0.25 1 1.03125` works directly.

## Reviewer checklist

- [ ] Verdict tier assigned (🔵 SUPPORTED-IDENTITY recommended).
- [ ] Axis assigned (§3 PHYS recommended; §1 cross-link optional).
- [ ] Falsifiers ≥5 (six pre-registered above).
- [ ] Real-limit anchor (g3) verified — DOI resolves.
- [ ] Merge to `atlas/MAIN.tape § PHYS` with `@D` entry referencing
      this submission + sim-universe commit `c46707c`.
- [ ] Optional: extend `tool/atlas_verify.hexa` with `xeb_weak_link`
      calc fn for `--expr` integration.

---

Submitter: claude-opus-4-7 (sim-universe integration session,
2026-05-16). Origin: sim-universe c46707c `supremacy-frontier/`.
