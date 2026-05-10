# Numerics methodology — hexa-rtsc T1 / T2 / T3 ladder narrative

> Recipe `~/core/bedrock/docs/runnable_surface_recipe.md` §1 slot #13 +
> §3 closure-progress contract. Reader-facing narrative companion to
> `verify/{calc,numerics,empirical}_*.hexa`. Prose only — no new
> predicate, no falsifier movement. For predicate-bearing scripts see
> `verify/falsifier_check.hexa` + `verify/saturation_check.hexa`.

This document tells a future reader (or future agent picking up the
repo cold) **why** every script in `verify/` is shaped the way it is,
**what tier of evidence it carries**, and **what a passing exit code
proves vs. does NOT prove**. It is intentionally honest about the
gap between bookkeeping closure and physics-settled empirical truth
(see closure-honesty contract in `verify/falsifier_check.hexa`
header + `RELEASE_NOTES_v1.1.0.md` §"Honesty contract").

---

## §1 The 3-tier ladder

Every preregistered falsifier (F-RTSC-{1,2,3} + F-SC-{1,2,3}, see
`.roadmap.hexa_rtsc §A.4`) closes against a sequence of evidence
tiers. The closure pct rendering in `falsifier_check.hexa::_closure_pct`
is the bookkeeping tracker; the prose below explains the methodology
behind each rung.

### T1 — Algebraic (closed-form derivation)

**Where**: `verify/calc_*.hexa` (4 scripts: BCS / McMillan / Hc2 / LK99)
plus the cross-cutters `verify/lattice_check.hexa` and
`verify/cross_doc_audit.hexa`.

**What it asserts**: starting from divisor functions on n=6
(σ(6)=12, τ(6)=4, φ(6)=2, J₂=24) and the master identity
σ·φ = n·τ = J₂ = 24, the pillar's signature ratio (Tc, Hc2,
ΔC/γTc, …) reduces to a closed-form expression in those lattice
constants alone — no fitted parameter, no empirical input.

**What a PASS proves**: the integer / divisor algebra is
self-consistent. If a future PR mutates σ from 12 to 11, T1
breaks immediately because the master identity loses its
24-RHS.

**What a PASS does NOT prove**: that nature actually obeys the
closed-form. T1 is a coherence proof on the formal system, not on
physical reality.

### T2 — Numerical (math_pure float reproduction)

**Where**: 17 `verify/numerics_*.hexa` scripts.

**Sub-tiers**:

- **Closed-form numerics** (4): `numerics_{bcs,mcmillan,hc2_48t,lk99}`.
  Reproduce the T1 algebraic closed-form via `self/runtime/math_pure`
  float arithmetic, asserting `rel_err < 1e-9` between the algebraic
  and numerical answers.
- **Parity scripts** (4): `numerics_*_parity`. Compare math_pure
  reproductions against published reference points (e.g. McMillan
  prediction for Pb at λ≈1.55, BCS prediction for Al at N(0)V≈0.18).
  These scripts hold ratios from the literature, not raw lab data —
  they are **archival proxies**, hence promoted to T3 in iter 19
  (see `RELEASE_NOTES_v1.1.0.md` §"100% closure").
- **Solver scripts** (4): `numerics_*_solver`. Newton / bisection
  inversions of the same closed-forms — given Tc, recover λ; given
  Hc2(0), recover ξ_GL. Provides redundancy: the closed-form must
  be invertible AND match.
- **Extended numerics** (3): `numerics_lk99_dft` (4 published DFT
  band-structure points), `numerics_tdgl_vortex` (CN=6 hexagonal
  vortex packing energy), `numerics_whh_full` (Tinkham WHH integral
  truncated polynomial). Added during §A.6.1 Phase B as
  Stage-1-readiness proof.
- **Cross-cutters** (2): `numerics_lattice_arithmetic` (vertical
  lock — math_pure reproduces every n=6 anchor to 1e-9 rel-err) +
  `numerics_cross_pillar` (horizontal lock — all 4 pillars agree
  on the SSOT lattice when each derives independently; added in
  심화 봉쇄 iter #2, see CHANGELOG).

**5 invariants enforced by `lint_numerics.hexa`** on every numerics
script (recipe §4):

1. `use "self/runtime/math_pure"` import — no raw `f64::sqrt`.
2. `__HEXA_RTSC_<NAME>__ PASS` sentinel.
3. `FALSIFIERS` array declared.
4. `exit(0)` on PASS path.
5. `let mut RUN = 0` + `let mut FAIL = 0` counters.

Plus invariant (6): the registered `NUMERICS_SCRIPTS` array length
must equal the on-disk `verify/numerics_*.hexa` glob length —
bidirectional drift-lock.

### T3 — Empirical archival (published-data corpus parity)

**Where**: 6 `verify/empirical_*_arxiv.hexa` scripts (one per
falsifier — F-RTSC-1/2/3 + F-SC-1/2/3).

**What it asserts**: for each falsifier, an archived published-data
corpus EXISTS and contains the predicted ratio. The script verifies
arXiv-id metadata + cached fixture XML (under `verify/fixtures/`)
without re-querying the network on each run (so the test stays
reproducible offline).

**What a PASS proves**:

1. The published corpus that the falsifier rests on has been read,
   logged, and counted.
2. The integer count of supporting papers is at-or-above the
   threshold the falsifier preregister demanded.
3. The archive lookup pipeline still works (a regression here means
   either fixtures rotted or arXiv API broke).

**What a PASS does NOT prove**:

- That **this** lab has reproduced the published claim. Live raw-
  data is T4, see §3.
- That every paper in the corpus is right. archival ≠ truth.
- That the closed-form fit is unique. Other closed-forms might also
  fit the same corpus; T3 proves consistency, not identification.

### T4 — Live empirical (Stage-1+ hardware)

**Where**: NOT in this repo. `.roadmap.hexa_rtsc §A.6` Step 4 +
RELEASE_NOTES §"Next steps".

**What would close it**: running real synthesis (LK-99 or successor
candidate) on a real bench, energising a real 48 T REBCO coil at
4.2 K, measuring real ΔC/γTc on a real calorimeter — and the result
matching the closed-form prediction within published error bars.

**Funding gate**: ~$26k procurement, ~14-20 mo end-to-end (PCB
fabrication + cold-test logistics + 1-2 weeks of beam-time on a
high-field magnet facility). Out of code-layer scope.

**Why we ship without T4**: per recipe §9, `sat-1 + sat-2`
saturation = 100% **bookkeeping** closure. The repo is regression-
locked at the code-layer; when funding lands, the bench team can
compare measurements against `verify/numerics_*.hexa` predictions
without re-deriving anything. The math is shipped; the lab is not.

---

## §2 Per-pillar methodology

### 2.1 BCS (`calc_bcs.hexa` + `numerics_bcs*.hexa`)

Closes 3 falsifiers (F-SC-1 / F-SC-2 / F-SC-3) sharing the BCS T1
script. Anchors:

- **Universal Cooper** (sc/superconductor.md §8.1):
  `kBTc = (ℏω₀/n) · exp[−(n/φ)/λ_eff]`. With n=6, φ=2:
  `kBTc = (ℏω₀/6) · exp[−3/λ_eff]`.
- **2Δ/kTc ≈ 3.528** (s-wave BCS) — bounded by `[φ, σ/φ] = [2, 6]`
  via n=6 divisor closure.
- **λ regime tiers** (calc_bcs §8.3): weak `≤ 1/φ = 1/2`, mid
  `≤ 1`, strong `≤ σ/J₂·n = 2 = φ`, upper bound `λ_max = φ = 2`.
- **μ\*** (Morel–Anderson) ≤ `1/sopfr(6) = 1/5 = 0.2`.

Numerics tier reproduces (1) Tc(λ, ωD) from `numerics_bcs.hexa`
and inverts via Newton's method in `numerics_bcs_solver.hexa`
(given Tc, recover λ_eff). Parity script compares against Al, Sn,
In, Pb measured Tc/ωD ratios from Ashcroft & Mermin Table 34.1.

### 2.2 McMillan (`calc_mcmillan.hexa` + `numerics_mcmillan*.hexa`)

Closes F-RTSC-2 (BCS λ ceiling). Anchors the strong-coupling
correction (1+λ) factor that lifts BCS Tc above the McMillan
ceiling Tc ≤ 30 K when λ > 1.

- **McMillan formula**:
  `Tc = (ωD/1.2) · exp[−1.04(1+λ) / (λ − μ*(1+0.62λ))]`.
- **Weak-coupling limit** (numerics_cross_pillar I5): as λ → 0
  with μ\*=0, the exponent argument 1.04(1+λ)/λ → 1.04/λ
  (diverges), matching BCS exponent 1/N(0)V = 1/λ_BCS. The
  Allen-Dynes 1975 prefactor 1.04 is the cross-pillar consistency
  ratio.

Parity script checks Pb (λ≈1.55, Tc≈7.2 K), Nb (λ≈1.0, Tc≈9.2 K),
Hg (λ≈1.6, Tc≈4.15 K), MgB₂ (λ≈0.7-0.9, Tc≈39 K — boundary case).

### 2.3 Hc2 / 48 T coil (`calc_hc2_48t.hexa` + `numerics_hc2_48t*.hexa`)

Closes F-RTSC-3 (48 T SC coil realisation gates 3 sister deps).
Anchors the master gate `Hc2 = σ·τ = 48 T` directly from lattice
constants (no fitting).

- **WHH dirty limit**: `Hc2(0) = 0.69 · |dHc2/dT|_{Tc} · Tc`
  (Werthamer-Helfand-Hohenberg 1966).
- **Clean limit**: 0.55 prefactor.
- **REBCO target**: σ·τ = 48 T at 4.2 K, sustained 1+ hour without
  quench. Real-bench evaluation: §A.6 Step 4.

Parity script compares against published REBCO coil records
(NHMFL 32 T 2017, Jefferson Lab 36 T tape-stack 2020, KEK J-PARC
HTS test 28 T 2021).

### 2.4 LK-99 (`calc_lk99.hexa` + `numerics_lk99*.hexa`)

Closes F-RTSC-1 (LK-99 reproduction failure). Holds the **negative-
result** row inside σ=12 substrate molecule. Methodology specifics:

- **Substrate-class enumeration** (sc/superconductor.md): σ=12
  candidate families. LK-99 (Pb₁₀₋ₓCuₓ(PO₄)₆O) demoted in 2023
  multiple-failure cycle → 11 candidates remain (numerics_cross_pillar
  I6 verifies σ−1=11).
- **DFT cross-check** (`numerics_lk99_dft.hexa`, §A.6.1 Phase B):
  band-structure overlap with 4 published DFT studies (Si, Liu,
  Griffin, Korotin 2023). Each predicts insulator ground state, not
  superconductor — consistent with negative result.
- **Methodology lesson**: a negative-result falsifier is closed
  when (a) the catalog row is demoted AND (b) the σ-molecule
  itself is preserved (i.e. lattice intact, only one row gone).
  This distinguishes "candidate failed" from "molecule wrong".

---

## §3 What's NOT covered by any tier

The honest answer to "is RT-SC settled?" — the closure ladder cannot
deliver any of:

1. **Mechanism uniqueness**. Multiple closed-forms might fit the
   same archival corpus. T1+T2+T3 closure proves consistency with a
   chosen form, not that no other form fits.
2. **Out-of-distribution prediction**. T3 only verifies parity on
   published data points. New regimes (e.g. ambient-pressure 350 K
   superconductor) are extrapolations and ARE T4.
3. **Material-specific synthesis route**. The closed-forms predict
   ratios but not how to grow the sample.
4. **Falsifier coverage completeness**. F-RTSC-{1,2,3} + F-SC-{1,2,3}
   are the 6 preregistered. The actual physics surface has more
   (e.g. iron-pnictide pairing symmetry, interface SC, twisted-bilayer
   moiré). Future preregistration is recipe §A.4 surface, not in-
   scope here.

---

## §4 How to add a new pillar (forward-compat)

If a future cycle adds a 5th pillar (say, hydride high-pressure
H₃S / LaH₁₀ family — currently a row inside the σ=12 catalog, not
its own pillar):

1. Add a row to `.roadmap.hexa_rtsc §A.4` with a new F-XX-N
   falsifier ID + status=OPEN.
2. Author `verify/calc_<pillar>.hexa` (T1) — divisor-only derivation.
3. Author `verify/numerics_<pillar>{,_parity,_solver}.hexa` (T2).
4. Author `verify/empirical_<pillar>_arxiv.hexa` (T3 archival).
5. Update `verify/falsifier_check.hexa` Fk_T*_SCRIPTS arrays.
6. Update `verify/saturation_check.hexa` per-falsifier arrays
   (drift-lock will fail otherwise).
7. Update `verify/numerics_cross_pillar.hexa` PILLAR_LABELS +
   PILLAR_*_FILES — re-derive the cross-pillar invariants for
   the new pillar.
8. Bump counts in `tests/test_verify.hexa`,
   `firmware/build/verification_matrix.md`, README.

7 steps = recipe §2 7-step iteration cycle, scaled to new-pillar
introduction. Adding a pillar is itself one big recipe iter.

---

## §5 Cross-references

- `~/core/bedrock/docs/runnable_surface_recipe.md` — the recipe
  this methodology implements.
- `verify/falsifier_check.hexa` header — closure-progress contract,
  authoritative sentinel format.
- `verify/saturation_check.hexa` header — sat-1 / sat-2 predicate.
- `verify/numerics_cross_pillar.hexa` — 6 inter-pillar invariants
  with full Allen-Dynes ratio derivation.
- `RELEASE_NOTES_v1.1.0.md` §"Honesty contract" — bookkeeping vs
  empirical closure split.
- `.roadmap.hexa_rtsc §A.4` — falsifier preregister SSOT.
- `.roadmap.hexa_rtsc §A.5` — pending-decisions list (unresolved
  methodology questions: BCS-너머 family fix, cross-link priority,
  negative-result granularity, §A.6 Step-1 collab partner).
- `.roadmap.hexa_rtsc §A.6` — Stage-1+ hardware path = T4 surface.

---

— Methodology narrative is non-predicate-bearing prose. It does not
move closure pct, does not advance any falsifier status, and does not
introduce new lint rules. Its purpose is reader cognition, not
regression coverage. For predicate-bearing artefacts see verify/.
