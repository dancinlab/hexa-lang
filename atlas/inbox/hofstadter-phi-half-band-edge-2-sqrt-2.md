# hofstadter-phi-half-band-edge-2-sqrt-2

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

For the Harper–Hofstadter model — a 2D tight-binding electron on a
square lattice in a uniform magnetic flux `φ = p/q` per plaquette
(D. R. Hofstadter, *Phys. Rev. B* **14**, 2239 (1976); Harper,
*Proc. Phys. Soc. A* **68**, 874 (1955)) — at flux `φ = 1/2`
(`p=1, q=2`) the Harper matrix is `2×2`:

    H = [ +2 cos k_y          1 + e^{−2 i k_x} ]
        [ 1 + e^{+2 i k_x}    −2 cos k_y        ]

with eigenvalues

    E = ± √( 4 cos² k_y + |1 + e^{−2 i k_x}|² )
      = ± √( 4 cos² k_y + 2 + 2 cos 2k_x ).

The band **extrema** over the magnetic Brillouin zone are at
`k_y = 0`, `2k_x = 0`, giving the **closed-form outer band edges**

    |E|_max = √(4 + 4) = √8 = **2 √2 ≈ 2.8284271247461903**

with an inner touching point at `E = 0` (the two central bands meet
— the even-`q` central degeneracy). So the `φ = 1/2` spectrum is two
bands whose outer edges are exactly `E = ± 2√2`. This is the
module's exact closed-form anchor on the Hofstadter butterfly.

## Hexa-native verification

The sim-universe `hofstadter/module/hofstadter.hexa` selftest emits
the invariant directly:

    (c) φ=1/2 outer band edge |E|_max vs 2√2 to < 1e-9 (OK)

with sentinel:

    __SIM_UNIVERSE_HOFSTADTER__ PASS ... mode=selftest

Build + run command:

    bash state/ubu-build.sh \
        hofstadter/module/hofstadter.hexa hof_bin --selftest

(or `./state/hof_bin --bands 1 2`). The atlas-side verifier closes
this as the **Stage 2 libm closed form**: it computes
`√8 = 2·√2` via libm `sqrt` and asserts
`|2√2 − 2.8284271247461903| < 1e-12`, and that
`(2√2)² = 8` exactly (the band-edge condition
`4 cos²k_y + 2 + 2 cos 2k_x = 8` at `k_y = 0, k_x = 0`).

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-FORMAL** (Stage 2 — `2√2 = √8` is a
  surd; the value is computed via libm `sqrt` with `|err| < 1e-12`
  vs the reference, and `(2√2)² = 8` is the underlying exact
  algebraic band-edge condition).
- **Axis:** §3 PHYS (Harper–Hofstadter / magnetic Bloch bands) ·
  cross-link §8 TOP (the integer-quantum-Hall butterfly carries
  TKNN Chern labels) · §2 MATH (`√8 = 2√2` surd identity).
- **Real-limit anchor (`g3`):**
  - **D. R. Hofstadter**, *Phys. Rev. B* **14**, 2239 (1976),
    DOI `10.1103/PhysRevB.14.2239` — the recursive Harper-equation
    analysis and the fractal butterfly `E` vs `φ = p/q`.
  - **Harper**, *Proc. Phys. Soc. A* **68**, 874 (1955) — the
    tight-binding (almost-Mathieu) difference equation Hofstadter
    diagonalizes.
  - **TKNN — Thouless, Kohmoto, Nightingale, den Nijs**,
    *Phys. Rev. Lett.* **49**, 405 (1982),
    DOI `10.1103/PhysRevLett.49.405` — the integer Hall / Chern
    gap labelling that the `φ=1/2` two-band structure anchors.
  - [compiler invariant — `(2√2)² = 8` is an exact algebraic
    identity; the libm `sqrt` evaluation is deterministic to
    `< 1e-12`].
- **Provenance:** sim-universe `hofstadter/` (Tier-A2) ·
  `hofstadter/module/hofstadter.hexa` (`_band_edges`,
  `_build_harper`) · AGENTS.tape `@D g18` ·
  `@X x_hofstadter_1976` / `@X x_tknn_1982`.

## Falsifiers (pre-registered, ≥5)

1. **`F1_wrong_value`** — the outer edge is `2√2 ≈ 2.828427`,
   NOT `√2 ≈ 1.414` nor `2 ≈ 2.0` nor `4`. If the verifier
   reports any value whose square ≠ 8, FIRES. Verifier asserts
   `|E|_max² = 8` exactly and `|E|_max = 2.8284271247461903` to
   libm precision.
2. **`F2_not_at_extremum`** — the band edge is at
   `k_y = 0, 2k_x = 0` (where `4cos²k_y + 2 + 2cos2k_x` is
   maximal `= 8`). If the verifier evaluates at a generic `k`
   (e.g. `k_y = π/2`, giving `√(0+2+2cos2k_x) ≤ 2 < 2√2`) and
   still claims `2√2`, the extremal momentum is wrong — FIRES.
   Verifier asserts the maximum over the magnetic BZ is at
   `cos k_y = 1, cos 2k_x = 1`.
3. **`F3_central_touch`** — the `q = 2` (even) spectrum has its
   two central bands **touching at `E = 0`**; the gap is at the
   outer edges, not the centre. If the verifier reports an inner
   gap (treating `φ=1/2` as fully gapped), FIRES. Verifier
   asserts `E = 0` is in the spectrum (`q` even ⇒ central
   degeneracy) and the outer edges are `±2√2`.
4. **`F4_wrong_q`** — `φ = 1/2` ⇒ `q = 2` ⇒ exactly **2 bands**
   (sibling combinatorial atom). If the verifier uses `q = 1`
   (single trivial band, edges `±2`) or `q = 3` and still claims
   `2√2`, the flux denominator is wrong — FIRES. Verifier
   asserts the Harper matrix dimension is `q = 2` for `φ = 1/2`.
5. **`F5_rational_phi_only`** — `2√2` is the band edge at the
   **exact rational** `φ = 1/2`. An irrational flux is never
   represented exactly (it is approached by rational
   approximants — `@D g18` honest scope). If the verifier claims
   `2√2` for an *irrational* φ, the rational-flux restriction is
   violated — FIRES. Verifier closes `φ = 1/2` (`p/q` exact)
   ONLY.
6. **`F6_tolerance_too_loose`** — the libm reference is
   `2.8284271247461903`; the closed form must match to
   `< 1e-12`. If the verifier passes only with a loose epsilon
   `1e-3` (suggesting a numerical-diagonalization artifact rather
   than the exact `√8` closed form), the formal-closed claim is
   undermined — FIRES. Verifier asserts `|2√2 − reference| <
   1e-12` AND the exact algebraic `(2√2)² == 8`.

## Honest C3

This atom is the **exact closed-form outer band edge `±2√2` at the
single rational flux `φ = 1/2`** of the **idealized** single-
particle Harper–Hofstadter model. It is NOT a claim about the full
fractal butterfly (whose richness at general `φ = p/q` is exact
dense ED, not closed-form), NOT about irrational flux (never
represented exactly — approached by continued-fraction approximants,
`@D g18`), NOT about interacting electrons, disorder, or a real
material / cold-atom realization. The atom absorbs the single
exact band-edge surd identity only.

## Provenance

Submitter: claude-opus-4-7 (sim-universe absorption cycle,
2026-05-16). Origin: sim-universe `hofstadter/` (Tier-A2). Papers:
D. R. Hofstadter, *Phys. Rev. B* **14**, 2239 (1976); Harper,
*Proc. Phys. Soc. A* **68**, 874 (1955); TKNN, *Phys. Rev. Lett.*
**49**, 405 (1982). AGENTS.tape `@D g18` / `@X x_hofstadter_1976` /
`@X x_tknn_1982`.
