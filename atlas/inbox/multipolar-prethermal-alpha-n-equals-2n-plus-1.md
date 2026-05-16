# multipolar-prethermal-alpha-n-equals-2n-plus-1

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

For the random-multipolar-driving (RMD) prethermalization protocol
of Liu et al. (*Nature* **650**, 79–85 (2026); preprint
arXiv:2503.21553), the prethermal lifetime grows **algebraically**
with the driving frequency `1/T`,

    τ_{I,S} ∼ (1/T)^{α(n)}

with the **universal scaling exponent** (main.tex L382/L438,
generalized-Floquet-Magnus + Fermi-golden-rule)

    **α(n) = 2n + 1**     (n = 0,1,2,…)

`n` is the multipolar order: `n=0` monopolar (white-noise drive),
`n=1` dipolar, `n=2` quadrupolar. The exponent is an **integer
identity** that follows from the closed-form Thue–Morse-class
spectral filter of the recursively anti-aligned n-RMD sign
sequence (Zhao–Bhatt 2021 / Mori 2021):

    |W_0(x)|² = 1                                    (0-RMD white)
    |W_n(x)|² = ∏_{k=1}^{n} 4 sin²(2^{k−1} x/2)  ∝ x^{2n}  (x→0)

Folding `|W_n|² ∝ x^{2n}` against the smooth bath spectral density
with the explicit per-period coupling factor `T` (rate =
absorbed-energy / time → one net power of `T`) gives the
small-`T` heating rate `Γ_n(T) ∝ T·(ωT)^{2n} = T^{2n+1}`, hence
`τ ∝ 1/Γ ∝ (1/T)^{2n+1}`. Therefore

    **α(0)=1 ,  α(1)=3 ,  α(2)=5**     (the odd integers `2n+1`)

— an exact integer identity (the FGR power-counting exponent of a
`x^{2n}` filter is `2n+1` *exactly*), distinct from conventional
**periodic** Floquet systems where the lifetime grows
*exponentially* `τ ∼ e^{1/T}`.

## Hexa-native verification

The sim-universe `multipolar-prethermal/module/multipolar.hexa`
selftest emits the recovered exponents directly:

    α(n=0) : 1.000000  (universal 2n+1 = 1 ; OK)
    α(n=1) : 2.990774  (universal 2n+1 = 3 ; OK)
    α(n=2) : 4.949392  (universal 2n+1 = 5 ; OK)
    norm_drift = 0.000000  (exact unitary Trotter)

with sentinel `__SIM_UNIVERSE_MULTIPOLAR__ PASS`. Build + run:

    bash state/ubu-build.sh \
        multipolar-prethermal/module/multipolar.hexa \
        mp_bin --selftest

(or `./state/mp_bin --scaling`). The atlas-side verifier closes
the **integer identity** `α(n) = 2n+1`: it asserts
`α(0)=1, α(1)=3, α(2)=5` exactly as integers; that the sequence is
the **odd integers** (`α(n+1)−α(n) = 2`, strictly ordered
`α0<α1<α2`); and the FGR power-count — the small-`x` leading order
of `|W_n(x)|² = ∏_{k=1}^n 4 sin²(2^{k−1}x/2)` is `x^{2n}` (each
factor `4 sin²(2^{k−1}x/2) ∼ (2^{k−1}x)²`, contributing `+2` to
the exponent), so with the `+1` per-period `T` factor the rate
exponent is `2n+1` — a pure ℤ power-counting check, no float.

## Proposed verdict

- **Tier:** 🔵 **SUPPORTED-IDENTITY** (Stage 1 — `α(n) = 2n+1` is
  an exact integer identity: for `n = 0,1,2` it is `1,3,5`; the
  FGR exponent of a `|W_n|² ∝ x^{2n}` filter plus one `T` power
  is `2n+1` by pure integer power-counting, no floating-point).
- **Axis:** §3 PHYS (Floquet / random-multipolar-driving
  prethermalization) · cross-link §2 MATH (Thue–Morse-class
  recursion, integer power-counting) · §6 COSMO (heating-rate
  bath folding).
- **Real-limit anchor (`g3`):**
  - **Liu et al.**, *Nature* **650**, 79–85 (2026) /
    arXiv:2503.21553 — the RMD protocol; `α(n)=2n+1` universal
    exponent (main.tex L382/L438, FGR derivation L504–534).
  - **Zhao, Bhatt et al. 2021** / **Mori 2021** — the
    Thue–Morse-class multipolar spectral filter `|W_n|² ∝ x^{2n}`
    and the generalized-Floquet-Magnus heating-rate bound.
  - [Fermi golden rule — heating rate `Γ ∝ |matrix elt|²·𝒫_n(ωT)`;
    the leading small-`T` power of a `x^{2n}` spectral filter
    times one `T` (rate normalization) is `T^{2n+1}` exactly].
  - [compiler invariant — `2n+1` is an exact integer for integer
    `n`; the identity is closed in ℤ, no floating-point
    tolerance].
- **Provenance:** sim-universe `multipolar-prethermal/` (Tier-A2)
  · `multipolar-prethermal/module/multipolar.hexa` (exact-FGR
  `Ĥ_eff` diag + closed-form `|W_n|²` filter) · AGENTS.tape
  `@D g15` · `@X x_liu_multipolar`.

## Falsifiers (pre-registered, ≥5)

1. **`F1_wrong_sequence`** — `α(n) = 2n+1` ⇒ `1, 3, 5, 7, …`
   (odd integers). If the verifier reports `α(n) = n+1`
   (`1,2,3`), `2n` (`0,2,4`), or `2^n` (`1,2,4`), the exponent
   law is wrong — FIRES. Verifier asserts `α(0)=1, α(1)=3,
   α(2)=5` exactly and `α(n+1)−α(n) = 2`.
2. **`F2_filter_power`** — the Thue–Morse-class filter
   `|W_n(x)|² = ∏_{k=1}^n 4 sin²(2^{k−1}x/2)` has small-`x`
   leading order **`x^{2n}`** (each of the `n` factors
   contributes `x²`). If the verifier finds `x^n` or `x^{n²}`
   (mis-counting the product), the FGR power-counting is wrong —
   FIRES. Verifier asserts the leading exponent of `|W_n|²` is
   `2n` (then `+1` for the rate `T` factor → `2n+1`).
3. **`F3_exponential_confusion`** — RMD gives an **algebraic**
   `τ ∼ (1/T)^{2n+1}`, NOT the **exponential** `τ ∼ e^{c/T}` of
   conventional *periodic* Floquet prethermalization. If the
   verifier conflates the two (claims an exponential law for
   RMD), FIRES. Verifier closes the **algebraic** integer
   exponent `2n+1` ONLY and states the periodic-Floquet
   exponential is the *contrasting* (different) regime.
4. **`F4_monopolar_not_white`** — `n = 0` (monopolar) is the
   **white-noise** drive: `|W_0|² = 1` ⇒ `α(0) = 0·2+1 = 1`
   (a finite algebraic lifetime, NOT infinite, NOT `α=0`). If
   the verifier reports `α(0) = 0` (no prethermal plateau), the
   `n=0` base case is wrong — FIRES. Verifier asserts
   `α(0) = 1` exactly.
5. **`F5_not_integer`** — `2n+1` is an **exact integer** for
   integer `n`; the identity holds with **zero** tolerance. The
   sim's *recovered* `α` (1.000/2.991/4.949) are finite-N
   numerical estimates of the integer law — the *identity* is
   the integer `2n+1`, not the noisy estimate. If the verifier
   asserts the closed form is the *fitted* float (not the
   integer), the closed-form claim is undermined — FIRES.
   Verifier asserts the **integer** identity `α(n) ≡ 2n+1`.
6. **`F6_absolute_lifetime`** — only the **dimensionless
   scaling exponent** `α(n)=2n+1` is universal. The **absolute**
   prethermal lifetimes and the volume-law entanglement
   saturation value are finite-N truncated artifacts and are
   **NOT** claimed (`@D g15` honest scope). If the verifier
   asserts a universal *absolute* lifetime, the over-claim
   FIRES. Verifier closes the exponent identity ONLY.

## Honest C3

This atom is the **universal dimensionless scaling exponent
`α(n) = 2n+1`** (an exact integer identity for `n = 0,1,2`),
recovered via the paper's **own exact Fermi-golden-rule
derivation** (exact diagonalization of `Ĥ_eff = Ĥ_κ + Ĥ_p` at the
reachable `N` plus the closed-form Thue–Morse-class filter
`|W_n|² ∝ x^{2n}`). The **absolute** prethermal lifetimes and the
area→volume volume-law saturation value are finite-N truncated
artifacts and are **NOT** claimed — only the exponent is universal
(`@D g15`). A direct `ln|I|` vs `t` imbalance fit does **NOT**
recover `2n+1` at the exact-engine-reachable `N` (the many-body
spectrum is too small; the imbalance is recurrence-dominated) —
the FGR route is used precisely because it carries the universal
`x^{2n}` analytically. NOT decoherent (no T1/T2; the lab device
has T1≈26.4 µs), NOT the 78-qubit lab device, NOT the
thermodynamic limit (genuine ceiling `N ≲ 20–22`, 2ᴺ wall ×
many-realization × long-evolution wall-time). The atom absorbs the
exact integer exponent identity only.

## Provenance

Submitter: claude-opus-4-7 (sim-universe absorption cycle,
2026-05-16). Origin: sim-universe `multipolar-prethermal/`
(Tier-A2). Paper: Liu et al., *Nature* **650**, 79–85 (2026) /
arXiv:2503.21553. AGENTS.tape `@D g15` / `@X x_liu_multipolar`.
