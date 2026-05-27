# hofstadter-exactly-q-bands-at-phi-p-over-q

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

For the Harper–Hofstadter model (D. R. Hofstadter, *Phys. Rev. B*
**14**, 2239 (1976), Fig. 1; Harper, *Proc. Phys. Soc. A* **68**,
874 (1955)) at rational flux `φ = p/q` (`p, q` coprime integers),
Bloch's theorem closes the Harper difference equation on a
`q`-component vector, producing a **`q × q` Harper matrix**. Its
spectrum splits into **exactly `q` magnetic sub-bands**, separated
by `q − 1` gaps (one of which is closed at `E = 0` when `q` is even
— the two central bands touch):

    φ = p/q  (gcd(p,q)=1)   ⟹   #bands = **q**   (exactly)

This is a **combinatorial structural invariant**: the number of
magnetic sub-bands equals the flux denominator `q` after reducing
`p/q` to lowest terms — a pure integer identity, the skeleton of
the Hofstadter butterfly and the substrate for the TKNN
gap-labelling Diophantine equation `r = q·s_r + p·t_r`.

## Hexa-native verification

The sim-universe `hofstadter/module/hofstadter.hexa` selftest emits
the invariant directly:

    (b) #bands at φ=p/q equals q (e.g. 1/3→3, 2/5→5, 1/2→2) (OK)
    (a) spectrum symmetric E↔−E, max|E_i+E_{q-1-i}| < 1e-9 (OK)

with sentinel:

    __SIM_UNIVERSE_HOFSTADTER__ PASS ... mode=selftest

Build + run command:

    bash state/ubu-build.sh \
        hofstadter/module/hofstadter.hexa hof_bin --selftest

(or `./state/hof_bin --bands 2 5`). The atlas-side verifier closes
this as the **closed-form integer identity**: for a sweep of
coprime `(p, q)` pairs it asserts the Harper-matrix dimension is
`q` (so the number of sub-bands is exactly `q`), that reducing a
*non-coprime* `(p', q')` by `g = gcd(p', q')` gives `q = q'/g`
sub-bands (the flux is the reduced fraction), and the `E ↔ −E`
mirror pairing `band[i] ↔ band[q−1−i]` (bipartite-lattice chiral
symmetry) — pure ℤ checks, no floating point.

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-IDENTITY** (Stage 1 — "#sub-bands `= q`
  for `φ = p/q` in lowest terms" is an exact combinatorial integer
  identity; the `gcd` reduction and the `E↔−E` index pairing are
  ℤ-exact, no tolerance).
- **Axis:** §3 PHYS (Harper–Hofstadter / magnetic Bloch bands) ·
  cross-link §8 TOP (`q−1` gaps carry TKNN Chern integers) · §2
  MATH (coprime-fraction `gcd` reduction, integer band count).
- **Real-limit anchor (`g3`):**
  - **D. R. Hofstadter**, *Phys. Rev. B* **14**, 2239 (1976),
    DOI `10.1103/PhysRevB.14.2239` — `φ = p/q` ⇒ `q`-fold band
    splitting (Fig. 1, the butterfly).
  - **Harper**, *Proc. Phys. Soc. A* **68**, 874 (1955) — the
    `q`-periodic difference equation underlying the `q×q` matrix.
  - **TKNN — Thouless, Kohmoto, Nightingale, den Nijs**,
    *Phys. Rev. Lett.* **49**, 405 (1982),
    DOI `10.1103/PhysRevLett.49.405` — the `q−1` gaps each carry
    an integer Hall conductance via `r = q·s_r + p·t_r`.
  - [compiler invariant — the band count `q` is an exact integer
    fixed by `gcd(p,q)=1`; the identity is closed in ℤ, no
    floating-point tolerance].
- **Provenance:** sim-universe `hofstadter/` (Tier-A2) ·
  `hofstadter/module/hofstadter.hexa` (`_count_bands`,
  `_build_harper`, `_mirror_error`, `_dio_label`) · AGENTS.tape
  `@D g18` · `@X x_hofstadter_1976` / `@X x_tknn_1982`.

## Falsifiers (pre-registered, ≥5)

1. **`F1_not_q_bands`** — `φ = p/q` (lowest terms) ⇒ **exactly
   `q`** sub-bands. If the verifier reports `q+1`, `q−1`, or `2q`
   bands for any coprime `(p,q)`, the Harper-matrix dimension is
   wrong — FIRES. Verifier asserts #bands `== q` for a sweep of
   coprime pairs.
2. **`F2_not_reduced`** — the count is the denominator of `p/q`
   **in lowest terms**: `φ = 2/4` is `1/2` ⇒ `q = 2` bands, NOT
   4. If the verifier counts `4` for `2/4` (failing to reduce by
   `gcd`), FIRES. Verifier asserts #bands `= q'/gcd(p',q')` for
   non-coprime inputs.
3. **`F3_no_mirror`** — the square lattice is bipartite, so the
   spectrum is symmetric `E ↔ −E`: `band[i]` pairs with
   `band[q−1−i]`. If the verifier finds an unpaired band (chiral
   symmetry broken), FIRES. Verifier asserts the mirror pairing
   over all `i` (`max|E_i + E_{q-1-i}| < 1e-9`).
4. **`F4_even_q_central_gap`** — for **even** `q` the two central
   bands **touch at `E = 0`** (a closed gap); there are still `q`
   bands but only `q−1` *open* gaps minus one. If the verifier
   reports `q` open gaps for even `q` (missing the central
   degeneracy), FIRES. Verifier asserts even-`q` ⇒ `E=0` in the
   spectrum.
5. **`F5_diophantine_label`** — the `q−1` gaps carry TKNN
   integers solving `r = q·s_r + p·t_r` with `|t_r| ≤ q/2`. If
   the verifier's gap labels are non-integer or violate the
   Diophantine constraint, the gap-labelling skeleton is wrong —
   FIRES. Verifier asserts integer `(s_r, t_r)` solving the
   equation for each `r = 1 … q−1`.
6. **`F6_irrational_phi`** — "exactly `q` bands" requires an
   **exact rational** `φ = p/q`. An irrational flux is never
   represented exactly (it is approached by rational
   approximants whose `q → ∞` gives the zero-measure Cantor
   spectrum — `@D g18` honest scope). If the verifier claims a
   finite band count for an *irrational* φ, FIRES. Verifier
   closes rational `φ = p/q` ONLY and states the irrational
   limit is the (separate) bandwidth-collapse witness.

## Honest C3

This atom is the **exact combinatorial integer identity "#magnetic
sub-bands `= q` for `φ = p/q` in lowest terms"** of the **idealized**
single-particle Harper–Hofstadter model, plus the `E↔−E` mirror
symmetry and the TKNN Diophantine gap-labelling. It is NOT a claim
about irrational flux (never represented exactly — the
zero-measure Cantor spectrum is the separate bandwidth-collapse
witness, `@D g18`), NOT about interacting electrons, disorder, or a
real material / cold-atom realization. The atom absorbs the exact
band-count combinatorial invariant only.

## Provenance

Submitter: claude-opus-4-7 (sim-universe absorption cycle,
2026-05-16). Origin: sim-universe `hofstadter/` (Tier-A2). Papers:
D. R. Hofstadter, *Phys. Rev. B* **14**, 2239 (1976); Harper,
*Proc. Phys. Soc. A* **68**, 874 (1955); TKNN, *Phys. Rev. Lett.*
**49**, 405 (1982). AGENTS.tape `@D g18` / `@X x_hofstadter_1976` /
`@X x_tknn_1982`.
