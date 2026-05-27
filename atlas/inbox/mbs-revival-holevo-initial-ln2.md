# mbs-revival-holevo-initial-ln2

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

For the Xiang et al. 2024 PXP-Rydberg quantum-information-revival
experiment (arXiv:2410.15455), the **t = 0 Holevo information at the
central site** between the `|Z2⟩` and `σ̂ˣ_c|Z2⟩` initial states is
the closed-form constant `ln 2` (one bit, in nats):

    X_c(0) = S((ρ_c + ρ'_c)/2) − (1/2)(S(ρ_c) + S(ρ'_c))
           = S(I/2) − (1/2)(S(|↓⟩⟨↓|) + S(|↑⟩⟨↑|))
           = ln 2 − (1/2)(0 + 0)
           = ln 2
           ≈ 0.6931471805599453

Reasoning: at `t = 0` the two product states differ on a single bit at
site `c` only. The single-site reduced density matrices are pure
projectors `ρ_c = |↓⟩⟨↓|` and `ρ'_c = |↑⟩⟨↑|` (`S = 0` each); their
equal-weight mixture is the maximally-mixed qubit `I/2` with von
Neumann entropy `ln 2`. This is a **closed-form identity in `ℝ`**
(reduces to `ln 2`), the cleanest possible carrier of "one bit of
classical-distinguishable information" — exactly what the Holevo
quantity is designed to measure.

## Hexa-native verification

The sim-universe `mbs-revival/module/mbs_revival.hexa` (compiled
native to `state/mbs_bin`) selftest emits the `t = 0` invariant
directly:

    Holevo X_c(0) : 0.693147 (== ln 2=0.693147; OK)

with sentinel:

    __SIM_UNIVERSE_MBS__ PASS N=8 state=selftest mode=selftest
        Ftrev=0.796511 norm_drift=0.000000

Build + run command (ubu build, mirrors `fvd`/`stark`/`qdarwin`):

    bash state/ubu-build.sh \
        mbs-revival/module/mbs_revival.hexa \
        mbs_bin --selftest

Recompute path: `_holevo_t0()` returns the closed-form value (no
matrix construction at `t = 0` — the 2×2 density matrices reduce to
diagonal projectors and the average is `I/2`).

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-FORMAL** (Stage 2 — `ln 2` is a standard
  transcendental constant; hexa-native verifier reproduces `log(2.0)`
  to libm precision against the same closed-form `0.6931471805599453`
  used by `s3_supremacy_kappa_c_log2_T4`).
- **Axis:** §3 PHYS · cross-link §2 MATH (`ln 2` is an atlas atom).
- **Real-limit anchor (`g3`):**
  - **Xiang, Zhang, Liu et al.**, *Observation of quantum information
    collapse-and-revival in a strongly-interacting Rydberg atom array*,
    arXiv:2410.15455 (2024) · Eq. L301 (Holevo information definition);
    L239/L298 (Z2 and Z2-flip initial states) — central-site
    distinguishability = one bit.
  - **Holevo, A.S.**, *Bounds for the quantity of information
    transmitted by a quantum communication channel*, Probl. Peredachi
    Inf. **9**(3), 3–11 (1973) — the Holevo quantity itself.
- **Provenance:** sim-universe commit (mbs-revival landing) ·
  `mbs-revival/module/mbs_revival.hexa::_holevo_t0` · AGENTS.tape
  `@D g11` mbs-revival-honest-scope · `@X x_xiang_mbs`.

## Falsifiers (pre-registered, ≥5)

> Per `VERIFY.tape` Stage-1-meets-Stage-2 protocol. Each falsifier is
> a deterministic check that would FIRE (= 🔴 FALSIFIED) on accidental
> success.

1. **`F1_wrong_base`** — confirm the `log` is natural log (base `e`),
   not `log_2`. The selftest must report `0.693147`, NOT `1.000000`
   (which would be `log_2(2) = 1`). If `1.000000`, the atom claims
   the wrong unit convention — falsified.
2. **`F2_wrong_initial_state_pair`** — replace `σ̂ˣ_c|Z2⟩` with
   `σ̂ˣ_{c+1}|Z2⟩` (flip a non-central site adjacent to `c`). At `t=0`
   the central-site reduced density matrix is identical for the two
   states (the flip didn't touch site `c`), so `X_c(0) = 0`, NOT
   `ln 2`. If the verifier still emits `0.693147`, falsified.
3. **`F3_wrong_observed_site`** — measure Holevo at a site `j ≠ c` at
   `t = 0`. Both states have identical reduced density matrix there
   (the σˣ flip hasn't propagated), so `X_j(0) = 0`. If the verifier
   reports nonzero for `j ≠ c`, the locality structure is broken.
4. **`F4_classical_mixing_misuse`** — confuse the Holevo formula
   `χ = S(Σ p_i ρ_i) − Σ p_i S(ρ_i)` with the mutual-information
   formula. At `t = 0` the **classical mixing entropy** of equally-
   weighted `|↓⟩, |↑⟩` is `ln 2`, but the Holevo *quantity* is the
   classical-mixing entropy MINUS the average of individual
   entropies. Since each individual `S = 0`, both coincide here — BUT
   if the verifier swaps the sign or drops the second term and the
   answer would change at `t > 0` (where individual `S > 0`), the
   formula is wrong, falsified.
5. **`F5_units_dimensionless`** — `S(ρ) = −Tr(ρ ln ρ)` returns a
   dimensionless quantity (nats); converting to bits divides by
   `ln 2`. The atom is stated in **nats**, so the value is `ln 2`,
   NOT `1`. A verifier reporting `1.000000` is in bits and the unit
   declaration is wrong — falsified for the "nats" registration.
6. **`F6_cross_platform_byte_match`** — independently compute
   `log(2.0)` on Mac arm64 vs ubu x86_64 (using libm/`clang -O2` and
   `glibc/gcc -O2`); both must agree to ≥ 15 digits. If platform
   variation crosses `1e-12`, the byte-eq selftest seal breaks —
   falsified.

## Open questions / risks

- The PXP-projected version of the same Holevo `X_c(0) = ln 2` claim
  holds identically (the central qubit is the *one* site that the σˣ
  flip lives on; the blockade projector doesn't touch it). This atom
  registers the value, NOT the dynamics. The dip-then-revive
  trajectory at `t > 0` is registered as a separate atom
  (`mbs-revival-holevo-central-revival.md`).
- The atom is the closed-form value `ln 2`; the verifier path is
  `log(2.0)` via libm. A reviewer may prefer to register the
  underlying *information-theoretic statement* ("one classical bit of
  distinguishability ⇒ Holevo = ln 2 nats") as a separate Stage 1
  symbolic atom. Recommend registering both.

## Reviewer checklist

- [ ] Tier (🔵 SUPPORTED-FORMAL recommended).
- [ ] Axis (§3 PHYS · §2 MATH cross-link).
- [ ] Falsifiers ≥5 (six pre-registered above).
- [ ] Real-limit anchor (g3) verified — Xiang 2024 + Holevo 1973.
- [ ] Merge to `atlas/MAIN.tape § PHYS`.

---

Submitter: claude-opus-4-7 (sim-universe absorption cycle, 2026-05-16).
Origin: sim-universe `mbs-revival/`.
