# Coarse-Grained Forced-Unfolding Simulator — vWF A2 Domain

Reverse-engineering research for `hexa-bio` `drylab/` simulator #1.

**Scope (g8 / f2):** This is an *in-silico algorithm specification* for a
coarse-grained (CG) forced-unfolding simulator. It is software research. It is
NOT wet-lab, NOT clinical, NOT a therapeutic / efficacy claim. A CG model
produces a *model-dependent* intermediate ensemble that must be refined with
all-atom MD and validated experimentally before any biological conclusion.

**Why this exists:** `LVAD/A2_STABILIZER.tape` repeatedly recorded "A2
unfolding-intermediate ensemble = external SMD, outside repo." That is a false
boundary. A Gō-model / elastic-network CG simulator under a tension ramp is
buildable stdlib-only and generates the extension-vs-force curve and the
populated metastable (intermediate) states *in-repo*. The tape's own §3 anchors
(A2 ≈ 177 aa, contour ≈ 57 nm, ΔG ≈ 3.9 kcal/mol, scissile Tyr1605–Met1606) are
real and citable (see §real-limit-anchor, §references).

---

## §SOTA-landscape

Each tool described by *its own* documented capability — no lattice-fit, no
cross-comparison ranking (g3). One honest line each.

**Open / academic (verified):**

- **NAMD (UIUC TCB)** — ships a first-class Steered Molecular Dynamics (SMD)
  module: center-of-mass of tagged atoms harmonically restrained (force
  constant `SMDk`) to a point translated at constant velocity `SMDVel` along
  `SMDDir`; constant-velocity and Tcl-forces (arbitrary time/position-dependent)
  pulling both supported. [verified — NAMD User Guide §SMD]
- **GROMACS** — has a built-in *pull* code (`mdp` `pull-*` options): COM pull
  geometry with `pull-coord-rate` (e.g. 0.01 nm/ps) and a direction vector
  `pull-coord-vec`; supports constant-velocity (umbrella) and constant-force
  pulling. [verified — GROMACS pull docs / BioExcel]
- **LAMMPS** — general MD engine with `fix smd` and `fix spring` for
  steered/tethered pulling; widely used for CG (e.g. Gō) forced unfolding.
  [partially verified — package known to expose `fix smd`; exact syntax not
  re-fetched here]
- **OpenMM** — Python/C++ MD toolkit; SMD is implemented via a user-defined
  `CustomCentroidBondForce` / `CustomExternalForce` (no single dedicated SMD
  keyword); flexible enough for cv- and cf-pulling. [partially verified —
  CustomForce mechanism documented; SMD is composed, not built-in]
- **HOOMD-blue** — GPU CG/MD engine; pulling is done with a custom external
  potential. [UNVERIFIED — could not fetch HOOMD-blue SMD documentation; do not
  rely on this line]

**Proprietary (verified by vendor docs):**

- **Schrödinger Desmond** — documents *metadynamics* and enhanced-sampling for
  free-energy / conformational mapping; a *dedicated* SMD keyword equivalent to
  NAMD's was **NOT verified** in the fetched vendor pages (Desmond can express
  pulling via biasing/restraints, but the explicit SMD-module claim is
  [UNVERIFIED]).
- **OpenEye toolkits** — primarily cheminformatics / docking / shape; a forced-
  unfolding SMD capability was **NOT verified** and is [UNVERIFIED] — omitted
  from any capability claim.

---

## §Reverse-engineered-algorithm (cited equations)

The simulator composes three published, primary-cited pieces: a structure-based
**Gō-model native-contact potential** (or, simpler, an **elastic-network
spring** topology), a **constant-velocity / constant-force SMD restraint**, and
an **overdamped (Brownian) Langevin integrator**.

### A. Structure-based Gō potential (Clementi–Onuchic; Karanicolas–Brooks)

Cα-bead representation (one bead per residue at the Cα position). The canonical
off-lattice structure-based potential (Clementi, Nymeyer & Onuchic 2000, J Mol
Biol 298:937–953) has the standard form:

```
V_total = Σ_bonds   K_r (r − r0)^2
        + Σ_angles  K_θ (θ − θ0)^2
        + Σ_dihedral [ K_φ^(1) (1 − cos(φ − φ0))
                      + K_φ^(3) (1 − cos 3(φ − φ0)) ]
        + Σ_{native i<j}     ε_ij [ 5 (σ_ij / r_ij)^12 − 6 (σ_ij / r_ij)^10 ]
        + Σ_{non-native i<j}  ε_nn ( σ_nn / r_ij )^12
```

- `r0, θ0, φ0` = bond length / angle / dihedral taken from the **native
  (reference) structure** (PDB) — this is what makes it a Gō model: the native
  state is the global minimum by construction.
- `σ_ij` = native Cα–Cα distance of native contact pair (i,j); the 12-10 well
  has its minimum exactly at `r_ij = σ_ij`.
- `ε_ij` = native-contact well depth (energy scale). In the
  Karanicolas–Brooks variant (Protein Sci 2002, 11:2351–2361; J Mol Biol 2003,
  334:309–325) `ε_ij` is residue-type weighted (Miyazawa–Jernigan), bond
  force-constant ≈ 200 ε_res, angle ≈ 40 ε_res, with a desolvation-barrier term
  added to the native-contact potential; non-native ε set to 1.5×10⁻³ ε_res.
- `ε_nn (σ_nn/r)^12` = soft excluded-volume repulsion for all non-native pairs.
- Native contacts defined by a heavy-atom / Cα cutoff on the reference
  structure (commonly a CSU contact map or an 8 Å Cα cutoff for Cα-only models).

The **simplest valid reduction** (recommended for the stdlib build) is the
**Tirion / ANM elastic-network** topology: replace the 12-10 well by a single
Hookean spring on every native contact pair —

```
V_ENM = (γ / 2) Σ_{|R0_ij| < R_c} ( |R_ij| − |R0_ij| )^2
```

(Tirion 1996, Phys Rev Lett 77:1905–1908 — single uniform force constant γ;
Atilgan et al. 2001, Biophys J 80:505–515 — Anisotropic Network Model: same
spring on Cα beads within cutoff `R_c`, typically 13–15 Å for Cα ANM). `R0_ij`
is the native Cα–Cα vector, `R_ij` the instantaneous one. The ENM is harmonic
(no bond-breaking), so for *forced unfolding* the 12-10 Gō well (which can
rupture as the pulling force exceeds the well-escape barrier) is the
scientifically correct primary choice; the ENM is the honest fallback used to
report linear elastic response only.

### B. SMD pulling restraint (Izrailev & Schulten — verified verbatim)

From Izrailev, Stepaniants, Isralewitz, Kosztin, Lu, Molnar, Wriggers &
Schulten, "Steered Molecular Dynamics," in *Computational Molecular Dynamics:
Challenges, Methods, Ideas*, Lect. Notes Comput. Sci. Eng. **4**, pp. 39–65,
Springer (1998), §2 "Methods" (equations transcribed from the fetched PDF):

External harmonic restraint, single reaction coordinate `x`:

```
U = K (x − x0)^2 / 2
```

**Constant-velocity pulling (cv-SMD), Eq. (1):**

```
F = K ( x0 + v t − x )
```

> "This force corresponds to the ligand being pulled by a harmonic spring of
> stiffness K with its end moving with velocity v."

**Constant-force / linearly-ramped stiffness (cf-SMD), Eq. (2):** fixed
restraint point, stiffness increased linearly `K = α t`:

```
F = α t ( x0 − x )
```

Verified example parameters from the same chapter: `K = 10 k_B T / Å² ≈ 414
pN/Å`, `v = 0.125 Å/ps`, `T = 300 K` (retinal/bR §3.2); biotin–avidin used
`K = α t` ramped 0 → 120 pN/Å. NAMD's SMD module implements exactly Eq. (1) on
a center of mass [verified — NAMD User Guide].

For A2 the **tension ramp** is the `K = α t` (cf-SMD, Eq. 2) protocol or a slow
cv-SMD ramp, chosen so the effective applied force sweeps the physiological /
single-molecule window (A2 unfolds at ≈ 7–14 pN, most-probable ≈ 11 pN — Zhang
et al. 2009 Science).

### C. Overdamped Langevin (Brownian dynamics) integrator

CG beads in implicit solvent are integrated with the Ermak–McCammon Brownian
dynamics scheme (Ermak & McCammon, "Brownian dynamics with hydrodynamic
interactions," J Chem Phys **69**, 1352–1360 (1978)) — overdamped Langevin, no
inertia. With diagonal mobility (no hydrodynamic coupling, `D_i = k_B T / γ_i`),
the Euler–Maruyama update for bead i is:

```
r_i(t + Δt) = r_i(t) + (D_i / k_B T) F_i(t) Δt + sqrt(2 D_i Δt) · ξ_i
```

- `F_i(t) = −∇_i V_total + F_SMD,i` — conservative CG force plus the SMD
  restraint force from §B applied to the pulled bead (and the anchored bead
  held fixed / strongly restrained).
- `D_i` = bead diffusion coefficient (Stokes: `D_i = k_B T / (6 π η a)`,
  with bead radius `a`, solvent viscosity `η`).
- `ξ_i` = vector of independent standard normal random deviates,
  `⟨ξ⟩ = 0`, `⟨ξ_α ξ_β⟩ = δ_αβ`; the `sqrt(2 D_i Δt)` prefactor is the
  fluctuation–dissipation noise amplitude.

This is the standard Ermak–McCammon first-order (Euler–Maruyama) Brownian
propagator with the noise term reproducing the correct equilibrium Boltzmann
distribution in the Δt → 0 limit.

---

## §stdlib-implementation-spec

Pure-stdlib (Python `math`/`random`, or equivalent), deterministic.

**State variables**
- `N` beads; positions `R[i] = (x,y,z)`, i = 0..N−1, init = native Cα coords
  parsed from a PDB (A2 ≈ 177 residues → N ≈ 177).
- Native contact list `C = {(i,j, σ_ij)}` built once from the reference
  structure: pair (i,j) with |i−j| ≥ 3 and native Cα distance < `R_c` (default
  `R_c = 8.0 Å` for Gō; 13 Å for ENM fallback).
- Bonded reference geometry: `r0`, `θ0`, `φ0` from native structure.

**Potential** (choose at config):
- `model = "go"` → 12-10 native term + `(σ_nn/r)^12` non-native repulsion +
  harmonic bond/angle + dihedral (§A).
- `model = "enm"` → single-spring `(γ/2)Σ(|R_ij|−|R0_ij|)^2` (§A, honest
  linear-elastic fallback only).

**Tension-ramp protocol**
- Anchor bead `i_anchor` (N-terminal Cα) held by a stiff harmonic restraint
  (or fixed).
- Pulled bead `i_pull` (C-terminal Cα) gets the SMD force.
- cf-SMD ramp (Izrailev Eq. 2): `K(t) = α·t`; or cv-SMD (Eq. 1):
  `F = K (x0 + v·t − x)` projected on the anchor→pull axis.
- Ramp `α`/`v` chosen so applied force sweeps 0 → ~25 pN, straddling the
  experimental 7–14 pN A2 window.

**Integrator** — Ermak–McCammon Euler–Maruyama (§C):
```
for step in range(n_steps):
    F = forces(R)                       # −∇V + SMD restraint
    for i in beads:
        for d in (x,y,z):
            R[i][d] += (D[i]/kT)*F[i][d]*dt + sqrt(2*D[i]*dt)*gauss()
    if step % stride == 0: record(extension, applied_force, energy, R)
```

**Determinism** — seed the PRNG once (`random.seed(SEED)`, default
`SEED = 20260516`); identical inputs ⇒ bitwise-identical trajectory and
ensemble. Record `SEED`, `dt`, ramp params, contact-map hash in the output
header.

**"Intermediate ensemble" output**
1. **Extension-vs-force curve**: end-to-end distance `|R[i_pull] − R[i_anchor]|`
   vs instantaneous applied force — the sawtooth/plateau signature; the force
   at the major rip ≈ the model's unfolding force.
2. **Metastable-state populations**: cluster trajectory frames by fraction of
   native contacts `Q` (Q≈1 folded, Q≈0 unfolded, plateaus at intermediate Q =
   partially-unfolded intermediates). Histogram of dwell time per Q-bin = the
   *intermediate ensemble*. Emit representative coordinate snapshots per
   populated metastable basin (these are the structures a downstream QM
   active-space carve-out around Tyr1605–Met1606 would consume).
3. Witness row: SEED, model, ramp, N, contact count, unfolding-force estimate,
   ΔG-anchor comparison, populated-state count.

---

## §real-limit-anchor

The simulator is verification-anchored to **real biophysical limits** (g1), all
from primary single-molecule / structural literature — NOT the n=6 lattice:

| Real limit | Value | Primary source |
|---|---|---|
| A2 unfolding force (most-probable) | ≈ 11 pN (range 7–14 pN, loading-rate dependent) | Zhang X et al. 2009 Science 324:1330 |
| A2 unfolding free energy ΔG | 6.6 ± 1.5 k_BT = **3.9 ± 0.9 kcal/mol** | Zhang X et al. 2009 Science 324:1330 |
| A2 unfolded contour length | **57 ± 5 nm** (persistence length 1.1 ± 0.4 nm) | Zhang X et al. 2009 Science 324:1330 |
| A2 domain size | ≈ 177 residues (161 ± 14 from unfolding) | Zhang Q et al. 2009 PNAS 106:9226; Zhang X 2009 Science |
| ADAMTS13 scissile bond | Tyr1605–Met1606 | Zhang X 2009 Science; Zhang Q 2009 PNAS; Crawley 2011 Blood 118:3212 |
| ADAMTS13 single-molecule k_cat (on unfolded A2) | 0.14 s⁻¹ | Zhang X et al. 2009 Science 324:1330 |

Acceptance gate: the simulator's force-extension rip force must fall within the
7–14 pN single-molecule window *and* the unfolded extension must approach the
57 nm contour limit, with the well-depth scale tuned so the model
folding/unfolding free energy is consistent with ≈ 3.9 kcal/mol. (The earlier
tape estimate of "ΔG ≈ 7–10 kcal/mol" is an older bulk/low-force-regime figure;
the single-molecule mechanical ΔG from Zhang 2009 is 3.9 ± 0.9 kcal/mol — both
recorded for honesty; the *measured single-molecule* value is the harder
anchor.)

---

## §honesty-caveat

- **CG model — refine with all-atom MD.** A Cα Gō / elastic-network model is a
  topology-based caricature: it reproduces native-topology-driven mechanical
  response and the *existence/order* of unfolding intermediates, but NOT
  chemically-specific side-chain interactions, solvent structure, or absolute
  energetics. Any intermediate ensemble it emits is model-dependent and a
  *hypothesis generator*, not a structure determination.
- The A2 unfolding intermediate is **not crystallographically resolved**
  (recorded in `A2_STABILIZER.tape` §6) — the CG ensemble cannot be validated
  against an experimental intermediate structure; only its end-state observables
  (contour length, rip force, ΔG) are anchored to measurement.
- Brownian dynamics with diagonal mobility ignores hydrodynamic interactions
  (the *with*-HI Ermak–McCammon variant exists but is out of stdlib scope here).
- **g8 / f2:** a PASS of this simulator verifies in-silico simulator+metadata
  internal consistency and consistency with the cited real limits ONLY. It is
  NOT a therapeutic, clinical, regulatory, or efficacy claim. Downstream
  wet-lab validation is required and is out of repo scope.
- SOTA lines marked [UNVERIFIED] (HOOMD-blue SMD, Desmond dedicated-SMD,
  OpenEye forced-unfolding) were **not** confirmed against fetched primary
  documentation and must not be cited as fact.

---

## §references

Every reference below was reached via a fetched page or is anchored to a
verified bibliographic record during this research. Unverifiable items were
dropped (g3, no fabrication).

1. **Izrailev S, Stepaniants S, Isralewitz B, Kosztin D, Lu H, Molnar F,
   Wriggers W, Schulten K.** "Steered Molecular Dynamics." In *Computational
   Molecular Dynamics: Challenges, Methods, Ideas* (Deuflhard et al., eds.),
   Lecture Notes in Computational Science and Engineering, vol. 4, pp. 39–65,
   Springer-Verlag, Berlin (1998). — *cv-SMD Eq. (1) `F = K(x0+vt−x)`, cf-SMD
   Eq. (2) `F = αt(x0−x)`; verified verbatim from fetched PDF
   (ks.uiuc.edu/Publications/Papers/PDF/IZRA98/IZRA98.pdf).*
2. **Clementi C, Nymeyer H, Onuchic JN.** "Topological and energetic factors:
   what determines the structural details of the transition state ensemble and
   'en-route' intermediates for protein folding? An investigation for small
   globular proteins." *J. Mol. Biol.* **298**, 937–953 (2000). — *canonical
   off-lattice Cα structure-based Gō model; citation verified via fetched
   PMC6976017 reference list.*
3. **Karanicolas J, Brooks CL III.** "The origins of asymmetry in the folding
   transition states of protein L and protein G." *Protein Science* **11**,
   2351–2361 (2002). — *MJ-weighted Gō variant + desolvation barrier; bond
   200 ε_res, angle 40 ε_res; verified via fetched PMC2373711 / PMC2672008.*
4. **Karanicolas J, Brooks CL III.** "Improved Gō-like models demonstrate the
   robustness of protein folding mechanisms towards non-native interactions."
   *J. Mol. Biol.* **334**, 309–325 (2003). — *citation verified via fetched
   PMC2672008 (Hills & Brooks review reference list).*
5. **Tirion MM.** "Large Amplitude Elastic Motions in Proteins from a
   Single-Parameter, Atomic Analysis." *Phys. Rev. Lett.* **77**, 1905–1908
   (1996). — *single-parameter harmonic (elastic-network) potential; verified
   via PubMed 10063201.*
6. **Atilgan AR, Durell SR, Jernigan RL, Demirel MC, Keskin O, Bahar I.**
   "Anisotropy of fluctuation dynamics of proteins with an elastic network
   model." *Biophys. J.* **80**, 505–515 (2001). — *Anisotropic Network Model
   (Cα Hookean springs within cutoff); verified via PubMed 11159421 /
   anm.csb.pitt.edu.*
7. **Ermak DL, McCammon JA.** "Brownian dynamics with hydrodynamic
   interactions." *J. Chem. Phys.* **69**, 1352–1360 (1978). — *overdamped
   Langevin / Brownian-dynamics propagator; verified via ADS
   1978JChPh..69.1352E.*
8. **Zhang X, Halvorsen K, Zhang C-Z, Wong WP, Springer TA.**
   "Mechanoenzymatic cleavage of the ultralarge vascular protein von Willebrand
   factor." *Science* **324**, 1330–1334 (2009). — *A2 unfolding force ≈ 11 pN,
   ΔG = 6.6 ± 1.5 k_BT (3.9 ± 0.9 kcal/mol), contour 57 ± 5 nm, persistence
   1.1 nm, ADAMTS13 k_cat 0.14 s⁻¹; verified verbatim via fetched PMC2753189.*
9. **Zhang Q, Zhou Y-F, Zhang C-Z, Zhang X, Lu C, Springer TA.** "Structural
   specializations of A2, a force-sensing domain in the ultralarge vascular
   protein von Willebrand factor." *PNAS* **106**, 9226–9231 (2009). — *A2 ≈
   177 aa (Met1495–Ser1671), β3-β2-β1-β4-β5-β6 central sheet, Tyr1605–Met1606
   scissile bond; verified verbatim via fetched PMC2695068.*
10. **Aponte-Santamaría C, Huck V, Posch S, Bronowska AK, Grässle S, Brehm MA,
    Obser T, Schneppenheim R, Hinterdorfer P, Schneider SW, Baldauf C,
    Gräter F.** "Force-sensitive autoinhibition of the von Willebrand factor is
    mediated by interdomain interactions." *Biophys. J.* **108**, 2312–2321
    (2015). — *force-probe MD of A1A2: stretching force dissociates the A1A2
    complex coupled to A2 unfolding; bibliographic record + methodology
    confirmed via PubMed 25954888 / ScienceDirect listing (full text
    paywalled — methodology summary verified, equations not re-derived from
    this source).*

Background hub pages used for cross-checking (not primary): Hills & Brooks,
"Insights from Coarse-Grained Gō Models for Protein Folding and Dynamics," *Int.
J. Mol. Sci.* **10**, 889–905 (2009) (PMC2672008); "Gō model revisited"
(PMC6976017); NAMD User Guide §Steered Molecular Dynamics
(ks.uiuc.edu/Research/namd); GROMACS pull-code documentation (BioExcel).

Dropped / not cited (could not verify primary equations or capability):
HOOMD-blue SMD docs; Schrödinger Desmond dedicated-SMD module; OpenEye
forced-unfolding capability; Interlandi/Thomas and Chen/Springer A2-specific
MD papers (not fetched in this pass — left for a follow-up rather than cited
unverified, per g3).
