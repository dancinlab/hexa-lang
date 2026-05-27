# Clay 7 Millennium Problems — overview

Each of the 7 verbs in `hexa-millennium` ships a **closed-form candidate
spec** (n=6 invariant lattice: σ=12, τ=4, φ=2, sopfr=5) plus a **falsifier
preregister**. None of these constitutes a formal proof. Poincaré was
solved by Perelman (2003); the corresponding verb is an n=6 closed-form
verification-side spec, not a re-solution.

| Verb            | Clay problem                            | n=6 closed-form angle                                                    | Status                          |
|-----------------|------------------------------------------|--------------------------------------------------------------------------|---------------------------------|
| `bsd`           | Birch–Swinnerton-Dyer Conjecture         | Elliptic curve modular skeleton + L-function rank lemma via σ-φ          | CANDIDATE (open)                |
| `hodge`         | Hodge Conjecture                         | σ(6)=12 algebraic cycle / cohomology classes                             | CANDIDATE (open)                |
| `navier_stokes` | Navier–Stokes existence & smoothness     | τ(6)=4 regime smoothness ladder                                          | CANDIDATE (open)                |
| `p_vs_np`       | P vs NP                                  | σ²(6)=144 complexity-class separation candidate                          | CANDIDATE (open)                |
| `poincare`      | Poincaré Conjecture                      | n=6 geometrization simplification (verification-side; Perelman 2003)     | VERIFICATION SPEC (solved)      |
| `riemann`       | Riemann Hypothesis                       | σ-φ critical-line zero distribution candidate                            | CANDIDATE (open)                |
| `yang_mills`    | Yang–Mills mass gap                      | β₀ = σ - sopfr = 12 - 5 = 7 mass-gap derivation candidate                | CANDIDATE (open)                |

## Per-problem one-paragraph summaries

### BSD — `bsd/`
The Birch–Swinnerton-Dyer Conjecture relates the rank of the Mordell–Weil
group of an elliptic curve to the order of vanishing of its Hasse–Weil
L-function at s=1. The HEXA-BSD candidate threads n=6 perfect-number
arithmetic (σ=12, τ=4, φ=2, sopfr=5) through the elliptic curve modular
skeleton and posits a **Sel_6 condition lemma** plus a **j=σ³ classification**
to organize the rank-1 partial results. Status: open.

### Hodge — `hodge/`
The Hodge Conjecture asserts that on a smooth projective complex variety,
every Hodge class is a rational linear combination of cohomology classes
of complex subvarieties. The HEXA-Hodge candidate maps the n=6 invariant
lattice to σ(6)=12 algebraic-cycle representatives. Status: open.

### Navier–Stokes — `navier_stokes/`
The Navier–Stokes existence-and-smoothness problem asks whether smooth
solutions to the 3D incompressible Navier–Stokes equations always exist
globally. The HEXA-NS candidate uses τ(6)=4 to organize regime transitions
on a smoothness ladder. Status: open.

### P vs NP — `p_vs_np/`
The P vs NP problem asks whether every problem whose solution can be
verified in polynomial time can also be solved in polynomial time. The
HEXA-PnP candidate proposes a σ²(6)=144 separation indicator over a
restricted circuit family. Status: open.

### Poincaré — `poincare/`
The Poincaré Conjecture (every simply connected closed 3-manifold is
homeomorphic to S³) was **resolved by Perelman in 2003** via Ricci flow
with surgery. The HEXA-Poincaré entry is a **verification-side spec**:
an n=6 closed-form simplification meant to ride alongside Perelman's
proof, not to re-derive it. Status: solved (verification spec only).

### Riemann — `riemann/`
The Riemann Hypothesis asserts that all non-trivial zeros of the Riemann
zeta function lie on the critical line ℜ(s) = 1/2. The HEXA-Riemann
candidate proposes a σ-φ-indexed critical-line zero distribution. Status:
open.

### Yang–Mills — `yang_mills/`
The Yang–Mills mass-gap problem asks whether the quantum Yang–Mills
theory on R⁴ has a mass gap Δ > 0. The HEXA-YM candidate derives
β₀ = σ - sopfr = 12 - 5 = 7 as the leading β-function coefficient and
posits an n=6 mass-spacing law. Status: open.

## Honest disclaimer

The Clay Mathematics Institute Millennium Prize Problems are open
problems of central importance. **None of the candidate specs in
`hexa-millennium` constitute a formal proof.** They are organizing
hypotheses anchored to the n=6 perfect-number lattice, with falsifier
preregister entries documenting how each candidate could be refuted by
counterexample or independent calculation. See each verb's
`millennium-<slug>.md` for the per-problem candidate spec and falsifier
table.
