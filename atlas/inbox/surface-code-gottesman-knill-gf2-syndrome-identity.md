# surface-code-gottesman-knill-gf2-syndrome-identity

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

The Acharya et al. 2024 surface-code memory experiment (*Nature*
**638**, 920–926 (2025); arXiv:2408.13687) is, as a simulation
target, a **Clifford circuit + Pauli noise + Pauli measurement**.
The **Gottesman–Knill theorem** states such evolution is exactly,
classically simulable in polynomial time via the binary symplectic
**stabilizer tableau** (Aaronson–Gottesman CHP form). For a memory
experiment this collapses to a *classical GF(2) syndrome-decoding
Markov chain*, and the **structural identity** that closes the
Gottesman–Knill loop is:

    for every Pauli error string `e`,
      symplectic-tableau syndrome `s_T(e) = (S · e)  mod 2`
      ==  classical adjacent-parity syndrome `s_C(e)`
      ==  ( e_j ⊕ e_{j+1} )_{j=0..d-2}        (repetition code)

i.e. the GF(2) inner product of each `Z_j Z_{j+1}` stabilizer row
of the symplectic tableau `S` with the error vector `e` equals the
adjacent-bit parity the classical Monte-Carlo decoder consumes,
**bit-for-bit, for every single- and double-qubit X error**. This
proves the `O(n)`-bit classical syndrome chain *is exactly* the
symplectic-tableau evolution — no `2ⁿ` amplitude object is ever
needed. It is a pure **GF(2) linear-algebra identity** (parity =
XOR = addition mod 2), not a numerical approximation.

## Hexa-native verification

The sim-universe `surface-code/module/surface_code.hexa` selftest
emits the witness directly:

    tableau witness  : d=3,5,7 GF(2) syndrome == symplectic
                        tableau (OK)
    determinism      : d5 re-run byte-eq=OK
                        (entropy_source=deterministic-exact)

with sentinel `__SIM_UNIVERSE_SURFACECODE__ PASS`. Build + run:

    bash state/ubu-build.sh \
        surface-code/module/surface_code.hexa \
        sc_bin --selftest

(or `./state/sc_bin --tableau`). The atlas-side verifier closes
the **GF(2) structural identity**: it builds, for `d ∈ {3,5,7}`,
the `(d−1)×d` repetition-code stabilizer matrix `S` (row `j` =
`Z_j Z_{j+1}`, i.e. bits `j` and `j+1` set), then **exhaustively**
enumerates every single-qubit X error (`d` of them) and every
double-qubit X error (`C(d,2)`) and asserts
`(S·e mod 2) == (e_j ⊕ e_{j+1})_{j}` for **all** of them, with
**zero** mismatches — a finite exhaustive ℤ/GF(2) check, no
floating point, no Monte-Carlo.

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-IDENTITY** (Stage 1 — the symplectic-
  tableau syndrome equals the classical adjacent-parity syndrome
  is an exact GF(2) linear-algebra identity; verified
  *exhaustively* over all weight-1 and weight-2 X errors for
  `d=3,5,7`, zero tolerance).
- **Axis:** §3 PHYS (quantum error correction / stabilizer
  formalism) · cross-link §8 TOP (the logical operator is a
  homology class of the matching graph) · §2 MATH (GF(2) linear
  algebra, parity = addition mod 2).
- **Real-limit anchor (`g3`):**
  - **Acharya et al.**, *Nature* **638**, 920–926 (2025) /
    arXiv:2408.13687 — the below-threshold surface-code memory
    experiment whose exact simulation this identity underpins.
  - **Gottesman 1998** (arXiv:quant-ph/9807006) / **Aaronson–
    Gottesman 2004**, *Phys. Rev. A* **70**, 052328 — the
    Gottesman–Knill theorem and the CHP binary symplectic
    tableau (polynomial-time Clifford simulation).
  - **Fowler et al. 2012**, *Phys. Rev. A* **86**, 032324 —
    surface codes, stabilizer syndromes and MWPM decoding.
  - [compiler invariant — GF(2) (`mod 2`) arithmetic is exact;
    the syndrome equality holds bit-for-bit with **zero**
    tolerance over an *exhaustive* finite error set].
- **Provenance:** sim-universe `surface-code/` (Tier-A2) ·
  `surface-code/module/surface_code.hexa` (`_tableau_witness`,
  `_rep_shot`) · AGENTS.tape `@D g16` ·
  `@X x_acharya_surfacecode`.

## Falsifiers (pre-registered, ≥5)

1. **`F1_syndrome_mismatch`** — `(S·e mod 2)` must equal the
   adjacent-parity `(e_j ⊕ e_{j+1})` for **every** error in the
   exhaustive set. If the verifier finds even **one** error
   where the tableau syndrome ≠ the classical syndrome, the
   Gottesman–Knill reduction is not faithful — FIRES. Verifier
   asserts **zero** mismatches over all weight-1 and weight-2 X
   errors, `d=3,5,7`.
2. **`F2_not_mod2`** — the syndrome is GF(2) (parity = XOR =
   `mod 2`), NOT integer-sum. If the verifier uses plain integer
   addition (`s = e_j + e_{j+1}` without `mod 2`, giving `2`
   instead of `0` for a double flip), the field is wrong —
   FIRES. Verifier asserts `(S·e) mod 2` and that a two-adjacent
   flip gives syndrome bit `0` (even parity), not `2`.
3. **`F3_wrong_stabilizer_support`** — repetition-code
   stabilizer `j` is `Z_j Z_{j+1}` (support on bits `j, j+1`
   *only*). If the verifier builds a weight-3 or weight-1 row
   (wrong support), the tableau is not the repetition code —
   FIRES. Verifier asserts each row of `S` has exactly two set
   bits at consecutive positions.
4. **`F4_logical_not_homology`** — a residual `e ⊕ corr` with
   **trivial syndrome** is either the identity or the logical
   `X̄` (all-ones); a logical error is exactly the all-ones
   homology class. If the verifier flags a *non-trivial-syndrome*
   string as a logical error (confusing detectable errors with
   logical failure), FIRES. Verifier asserts a logical error
   requires trivial syndrome AND odd total X weight (the `X̄`
   class).
5. **`F5_needs_2n_state`** — the entire point is **no 2ⁿ
   amplitude object**: the syndrome chain is `O(n)` bits. If the
   verifier silently allocates a `2^d` state vector to "check"
   the syndrome (defeating Gottesman–Knill), the polynomial-
   exactness claim is undermined — FIRES. Verifier uses ONLY the
   `(d−1)×d` GF(2) tableau + `d`-bit error vectors (no `2^d`
   array).
6. **`F6_pauli_only`** — Gottesman–Knill exactness holds for
   **Clifford + Pauli noise** ONLY. Coherent / non-Clifford
   errors would force the `2ⁿ` state vector (the paper folds
   coherent/leakage/crosstalk into *effective Pauli rates* —
   `@D g16` honest scope). If the verifier claims exactness for
   a coherent (non-Pauli) error channel, the over-claim FIRES.
   Verifier closes the **stochastic-Pauli** code-capacity model
   ONLY.

## Honest C3

This atom is the **exact GF(2) structural identity** that the
classical adjacent-parity syndrome equals the binary symplectic-
tableau syndrome (the Gottesman–Knill exactness witness), verified
*exhaustively* over all weight-1 and weight-2 X errors for
`d=3,5,7`. It is a *deliberately different exact technique* — a
polynomial binary tableau / classical syndrome Markov chain, NOT a
`2ⁿ` amplitude state vector. It does **NOT** model coherent /
leakage / crosstalk errors as quantum amplitudes (the paper folds
these into effective Pauli rates; `@D g16`), is **NOT** the real
Willow / 72-qubit hardware budget device-by-device, **NOT** the
real-time decoder latency, **NOT** the cosmic-ray correlated
bursts. The Acharya Λ-suppression (`Λ = ε_d/ε_{d+2} ≈ 2`) is a
*separate* numerical Monte-Carlo result on top of this exact
syndrome reduction. The atom absorbs the exact GF(2) syndrome ==
tableau identity only.

## Provenance

Submitter: claude-opus-4-7 (sim-universe absorption cycle,
2026-05-16). Origin: sim-universe `surface-code/` (Tier-A2).
Paper: Acharya et al., *Nature* **638**, 920–926 (2025) /
arXiv:2408.13687; Aaronson–Gottesman, *Phys. Rev. A* **70**,
052328 (2004). AGENTS.tape `@D g16` / `@X x_acharya_surfacecode`.
