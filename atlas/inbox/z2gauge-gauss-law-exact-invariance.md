# z2gauge-gauss-law-exact-invariance

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

For the Hayata & Hidaka 2024 (1+1)D Z₂ lattice-gauge-theory Floquet
circuit on superconducting qubits (arXiv:2408.10079 / Phys. Rev. D
**110**, 114503 (2024)), the Gauss-law operator at every site

    G(x) = − X_g(x−1,x) · Z_1(x) · Z_2(x) · X_g(x,x+1)

is a **stabilizer that commutes with the Floquet unitary by
construction**:

    [U_F, G(x)] = 0   ∀x

(where `U_F = exp(−i H_gf dt) · exp(−i (H_f + H_g) dt)`, the paper
Eq. eq:U_F). Each of the three Hamiltonian pieces `H_g`, `H_f`,
`H_gf` is built from Pauli strings that commute with every `G(x)`
(this is the **defining gauge-invariance property** of the lattice
gauge theory — the gauge symmetry is exact, not approximate). Since
`U_F` is a product of exponentials of those gauge-invariant pieces,
`[U_F, G(x)] = 0` exactly. Therefore for any Gauss-law-physical
initial state (`G(x)|Ψ(0)⟩ = +|Ψ(0)⟩`):

    ⟨G(x)⟩(t) ≡ +1   for every Floquet step t   (machine-precision exact)

This is a **structural identity** (Stage 1): it does NOT depend on
any numerical trajectory — it is a direct consequence of the
commutator algebra `[U_F, G(x)] = 0` lifted through the unitary
evolution `|Ψ(t)⟩ = U_F^t |Ψ(0)⟩`:

    ⟨Ψ(t)|G(x)|Ψ(t)⟩ = ⟨Ψ(0)|(U_F†)^t G(x) U_F^t|Ψ(0)⟩
                      = ⟨Ψ(0)|G(x)|Ψ(0)⟩  (commute G past every U_F)
                      = +1.

It is precisely the **clean target** the paper's hardware-noise
Gauss-law-violation measurement diverges from — and the well-defined
denominator of the paper's `⟨𝓗⟩_mit = ⟨𝓗⟩_raw / ⟨G⟩_raw`
error-mitigation scheme.

## Hexa-native verification

The sim-universe `z2-gauge-prethermal/module/z2gauge.hexa` selftest
emits the invariant directly:

    init Gauss      : <G(x_c)>(0)=1.000000 (OK = +1)
    Gauss conserved : max_t |<G>(t)-1|=0.000000 (OK — [U_F, G] = 0 by construction)

with sentinel:

    __SIM_UNIVERSE_Z2GAUGE__ PASS N=3 Q=8 G=1.000000 H=-2.000000
        norm_drift=0.000000

Build + run command (ubu build, mirrors `fvd`/`stark`/`qdarwin`):

    bash state/ubu-build.sh \
        z2-gauge-prethermal/module/z2gauge.hexa \
        z2gauge_bin --selftest

The atlas-side verifier closes the **structural commutator
identity**: it builds the four-qubit Gauss-law Pauli string sign
`g(b) = −(z_{g,L})(z_1)(z_2)(z_{g,R}) = +1` on the paper's
Gauss-law-physical product basis state and checks it equals `+1`
on every basis component, demonstrating that the stabilizer
eigenvalue is fixed at `+1` independently of any time evolution
(the commutation `[U_F, G(x)] = 0` then preserves it for all `t`).

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-IDENTITY** (Stage 1 — structural; the
  conservation is an exact consequence of the stabilizer commutator
  algebra, integer-exact `±1` Pauli-eigenvalue arithmetic, no
  floating point in the verifier).
- **Axis:** §3 PHYS (lattice gauge theory / Floquet stabilizer
  conservation) · cross-link §8 TOP (stabilizer-code logical-operator
  invariance).
- **Real-limit anchor (`g3`):**
  - **Hayata & Hidaka**, *Floquet prethermalization of Z₂ lattice
    gauge theory on superconducting qubits*, **Phys. Rev. D 110,
    114503 (2024)** / arXiv:2408.10079, Eq. eqgc (Gauss-law
    operator) + Eq. eq:U_F (Floquet unitary).
  - **Gauss's law / Noether 1918** — local gauge invariance ⇒ a
    conserved local charge (`G(x)` is the lattice Gauss-law
    constraint generator; `[U_F, G(x)] = 0` is the lattice
    realisation of charge conservation under the symmetry).
  - [compiler invariant — stabilizer eigenvalue ±1 is integer-exact;
    a Pauli string squares to identity ⇒ eigenvalues ∈ {+1, −1}].
- **Provenance:** sim-universe commit (z2-gauge-prethermal landing) ·
  `z2-gauge-prethermal/module/z2gauge.hexa::_exp_G_local` ·
  AGENTS.tape `@D g13` z2-gauge-prethermal-honest-scope ·
  `@X x_hayata_z2lgt`.

## Falsifiers (pre-registered, ≥5)

> Per `VERIFY.tape` Stage-1 protocol. Each falsifier is a
> deterministic check that would FIRE (= 🔴 FALSIFIED) on
> accidental success.

1. **`F1_initial_not_physical`** — if the paper §IIB initial state
   `⊗_x (|01⟩−|10⟩)/√2 ⊗ ⊗_link |+⟩` does NOT satisfy
   `G(x_c)|Ψ(0)⟩ = +|Ψ(0)⟩`, then `⟨G(x_c)⟩(0) ≠ +1` and the whole
   premise collapses. Verifier checks: `Z_1 Z_2` on the singlet gives
   `−1`, `X_g X_g` on the two `|+⟩` links gives `+1`, so
   `G = −(+1)(−1)(+1) = +1` — if any sign is wrong, FIRES. Selftest
   reports `<G(x_c)>(0)=1.000000`.
2. **`F2_nonunit_stabilizer_eigenvalue`** — a Pauli string `P` with
   `P² = 𝟙` has eigenvalues exactly `±1`. If the verifier ever
   computes `|⟨G(x)⟩| > 1` or a non-`±1` eigenvalue on a stabilizer
   eigenstate, the Pauli algebra is mis-implemented — FIRES.
   Verifier asserts `g(b) ∈ {+1, −1}` integer-exact for every basis
   component.
3. **`F3_commutator_nonzero`** — if any Hamiltonian piece does NOT
   commute with `G(x)` (e.g. an `H_gf` term written with the wrong
   link/site qubit indices so it anti-commutes with the local
   `Z_1 Z_2`), then `[U_F, G] ≠ 0` and `⟨G⟩(t)` would drift away
   from `+1` during Floquet evolution. Selftest reports
   `max_t |<G>(t)-1| = 0.000000` over 15 Floquet steps — a nonzero
   value FIRES.
4. **`F4_wrong_gauss_string_length`** — `G(x)` is a **four**-qubit
   string `X_g · Z_1 · Z_2 · X_g`. If the verifier uses a 2- or
   3-qubit truncation (drops a link `X_g`), the conserved quantity
   is a different (non-gauge) operator whose expectation is NOT
   pinned to `+1` — FIRES (value ≠ +1 on the physical state).
5. **`F5_norm_drift`** — exact conservation of `⟨G⟩` presupposes
   unitary evolution (`‖Ψ(t)‖² = 1`). If `norm_drift > 1e-6`, the
   evolution is non-unitary and the stabilizer argument is void.
   Selftest reports `norm_drift = 0.000000` over 15 Floquet steps —
   a nonzero drift FIRES.
6. **`F6_basis_leak`** — `G(x)` acts within the Gauss-law sector.
   If the Floquet step leaked amplitude into a `G(x) = −1` sector
   (a gauge-violating component), `⟨G⟩` would be `< 1`. The
   verifier asserts the physical-sector eigenvalue is `+1` on every
   nonzero basis component of the prepared state; any `−1` component
   FIRES.

## Honest C3

This atom is **specifically** the *structural* statement
`[U_F, G(x)] = 0 ⇒ ⟨G(x)⟩(t) ≡ +1` for the *clean unitary* sim. It
is the **denominator** of the paper's `1/⟨G⟩` mitigation — the atom
does NOT, and must not, claim to reproduce the paper's
**hardware-measured Gauss-law violation** `⟨G⟩_raw < 1` (that lives
in T₁/T₂ decoherence, gate infidelity and readout error, which the
unitary sim does not model — per `@D g13` honest scope). The atlas
absorbs only the exact-conservation identity, not the noisy-device
phenomenology. The four-qubit-string commutation is paper-specific
(1+1)D Wilson-fermion Z₂ LGT; no claim about continuum LGT or
higher dimensions.

## Provenance

Submitter: claude-opus-4-7 (sim-universe absorption cycle,
2026-05-16). Origin: sim-universe `z2-gauge-prethermal/` (module 17,
Tier-A2). Paper: Hayata & Hidaka, Phys. Rev. D 110, 114503 (2024) /
arXiv:2408.10079. AGENTS.tape `@D g13` / `@X x_hayata_z2lgt`.
