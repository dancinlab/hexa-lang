# Cryptic / Scissile-Site Exposure Scorer — vWF A2 ADAMTS13 Bond

Reverse-engineering research for `hexa-bio` `drylab/` simulator
(scissile-site solvent-exposure vs unfolding reaction coordinate).

**Scope (g8 / f2 / g3):** This is an *in-silico algorithm specification* for a
transparent, stdlib relative-solvent-accessibility (RSA) scorer that quantifies
how the buried ADAMTS13 scissile bond of vWF A2 becomes solvent-exposed along a
mechanical-unfolding reaction coordinate. It is software research. It is NOT
wet-lab, NOT clinical, NOT a druggability / therapeutic / efficacy claim. It
does **not** clone or reconstruct any proprietary cryptic-pocket platform's
sampling or scoring method (g3) — those methods are *undisclosed*; we describe
each platform **only** by its own public claims and build an independent
transparent scorer on **our own** open ensemble.

**Why this exists:** Proprietary "motion-based" / "cryptic-pocket discovery"
platforms publicly *claim the FUNCTION* "find druggable pockets revealed by
protein conformational motion" but keep the *sampling/scoring METHOD*
proprietary. The vWF A2 ADAMTS13 scissile bond (Tyr1605–Met1606) is a textbook
**force-exposed cryptic site** — buried in folded A2, exposed only under
mechanical unfolding (Zhang 2009 Science 324:1330). Scoring that site's
exposure against an unfolding reaction coordinate **is** the function those
platforms advertise — and it can be done transparently, from primary-cited
open methodology, on the drylab #1 open CG unfolding ensemble (NOT their
undisclosed sampling). The honesty crux: we reproduce the **publicly stated
function**, never the **undisclosed method**, and we are explicit about the
coarse-grained resolution limit of our open ensemble source.

---

## §SOTA-landscape-undisclosed-method

Each platform described by *its own* public claim — no lattice-fit, no
cross-comparison ranking, no reconstruction of the hidden method (g3). One
honest line each; the proprietary-method flag is explicit.

**Proprietary platforms — FUNCTION public, METHOD undisclosed:**

- **Relay Therapeutics "Dynamo"** — own claim: a "Motion-Based Drug Design"
  platform that puts "protein dynamics at the heart of our drug discovery
  process", generating "virtual simulations (molecular dynamics) of the
  full-length protein moving over long, biologically relevant timescales" to
  "identify potential novel allosteric binding sites" / transient pockets
  revealed by motion. The specific **sampling/enhanced-sampling and pocket
  scoring algorithms are NOT disclosed** — described only as integrated
  "advanced machine learning models and molecular dynamics simulations"
  (proprietary). [verified — relaytx.com/dynamo-platform, own product page;
  METHOD = UNDISCLOSED]
- **OpenEye / Cadence Orion "Cryptic Pocket Detection"** — own claim: uses
  "state-of-the-art enhanced sampling molecular dynamics simulations" /
  "Weighted Ensemble Molecular Dynamics (WE-MD)" to "thoroughly explore a
  protein's conformational space, potentially revealing one or more cryptic
  pockets", with a "ligandability model" to rank pockets. Method *names* are
  given (Exposon Analysis, CoSolvent BFE, Cooperative CoSolvent) but the
  **algorithmic formulation, parameters and scoring model are NOT disclosed**
  (commercial product). [verified — eyesopen.com/cryptic-pocket, own product
  page; METHOD = UNDISCLOSED at formulation level]
- **Redesign Science** — own claim (third-party-reported): a "proprietary
  molecular dynamic simulation process" that builds "millisecond timescale
  protein motion models" by "running hundreds of thousands of atomic
  simulations" to "reveal hidden druggable opportunities" on hard-to-drug
  targets. The **simulation/scoring process is explicitly described by the
  company as proprietary** and is NOT disclosed. [partially verified —
  capability reported via a CoreWeave case write-up, not a primary methods
  paper; METHOD = UNDISCLOSED — flagged, not relied on for any algorithm]

**Honest boundary statement:** the function "quantify how a hidden/cryptic
site's exposure changes along a conformational coordinate" is the *publicly
advertised capability* common to the above. The *how* (their sampling
generators, reaction coordinates, ML scoring) is proprietary and **not used,
not inferred, not reconstructed** here. Our scorer is an independent
implementation built only from the primary open literature in
§publicly-documented-methodology-cited, operating on our own open ensemble.

---

## §publicly-documented-methodology-cited

These are primary, citable, open-science methods the scorer *does* implement.
Every entry was reached via a fetched page / verified bibliographic record;
unverifiable items dropped (g3, no fabrication).

### A. Solvent-accessible surface area — the rolling-probe definition

The scorer's exposure quantity is the **solvent-accessible surface area
(SASA)** in the sense of Lee & Richards: the surface traced by the centre of a
spherical solvent probe (radius ≈ 1.4 Å for water) rolled over the union of
atomic van-der-Waals spheres. An atom/residue is *exposed* in proportion to
the fraction of its expanded sphere reachable by the probe without occlusion by
neighbours.

- **Lee & Richards 1971** introduced the accessible-surface concept and the
  expanded-sphere ("static accessibility") construction. [verified — PubMed
  5551392; J. Mol. Biol. 55:379–400.]
- **Shrake & Rupley 1973** gave the numerical estimator used here: place an
  even mesh of test points on each atom's expanded sphere (vdW + probe radius);
  a point is *accessible* iff it lies outside every other atom's expanded
  sphere; SASA contribution = (accessible-point fraction) × sphere area.
  [verified — PubMed 4760134; J. Mol. Biol. 79:351–371.] Modern stdlib
  implementations distribute mesh points by a deterministic golden-spiral
  (Fibonacci) lattice with default probe radius 1.4 Å (verified against the
  Biotite/Biopython Shrake–Rupley documentation — algorithmic parameters
  cross-checked, not the basis of any new claim).
- **Relative SASA (RSA)** = SASA / MaxASA(residue), normalised so that 0 ≈
  fully buried and ≈ 1 ≈ fully exposed; this is the exposure observable plotted
  vs the reaction coordinate. The MaxASA reference scale (Gly-X-Gly tripeptide
  upper bound) is **Tien et al. 2013** [verified — PLoS ONE 8(11):e80635].

### B. Cryptic-site definition (what "exposed-only-under-motion" means)

- **Cimermancic et al. 2016 ("CryptoSite")** — primary definition adopted: a
  *cryptic site* "forms a pocket in a *holo* structure, but not in the *apo*
  structure" and "require[s] a conformational change to become apparent"
  (induced fit / conformational selection). [verified — PMC4794384; J. Mol.
  Biol. 428(4):709–719.] We use this only as the *definition* of the
  exposure transition we score — NOT CryptoSite's own predictor.
- **Vajda, Beglov, Wakefield, Egbert & Whitty 2018** — review confirming the
  definition ("a site that forms a pocket in a ligand-bound structure, but not
  in the unbound protein structure") and that MD / conformational-dynamics
  trajectories are the standard *open* route to expose such sites. [verified —
  PMC6088748; Curr. Opin. Chem. Biol. 44:1–8.] Used for the definition and
  the open-methodology framing only.

### C. The A2 force-exposed scissile-site evidence (domain anchor)

- **Zhang X et al. 2009** — the ADAMTS13 scissile bond Tyr1605–Met1606 is
  **buried in folded A2 and exposed only by mechanical unfolding**; A2 unfolds
  at ≈ 7–14 pN (most-probable ≈ 11 pN), ΔG = 6.6 ± 1.5 k_BT (3.9 ± 0.9
  kcal/mol), unfolded contour ≈ 57 nm; ADAMTS13 single-molecule k_cat on
  unfolded A2 = 0.14 s⁻¹. [verified verbatim via fetched PMC2753189; Science
  324:1330–1334.] This is the textbook force-exposed cryptic-site instance.
- **Zhang Q et al. 2009** — A2 ≈ 177 aa (Met1495–Ser1671), scissile
  Tyr1605–Met1606 in the central β4 strand of the A2 fold (3GXB). [verified
  verbatim via fetched PMC2695068; PNAS 106:9226–9231.]
- **Crawley et al. 2011** — ADAMTS13 cleaves vWF A2 at Tyr1605–Met1606;
  exosite-mediated mechanism. [verified bibliographic record; Blood
  118:3212–3221 — already cross-cited in `a2_residue_orbital_selector.py`.]

---

## §function-level-stdlib-spec

Pure-stdlib (Python `math` only), deterministic, no network, no I/O of
fabricated structures. The scorer **consumes the drylab #1 CG ensemble** and
emits an **exposure-vs-reaction-coordinate curve** for the scissile-bond
residues. It is a Shrake–Rupley-*style* relative-SASA estimator adapted to the
**Cα coarse-grained resolution** of the open ensemble — the CG limit is
explicit and load-bearing (see §honesty-caveat).

**Inputs**
- `ensemble`: the drylab #1 `a2_cg_unfolding` trajectory — a sequence of frames
  `{ Q, extension, applied_force, R[i]=(x,y,z) }` where `R[i]` is the Cα bead
  of residue `i` (A2 numbering, Met1495..Ser1671; N ≈ 177) and `Q` = fraction
  of native contacts (the natural unfolding reaction coordinate; Q≈1 folded,
  Q≈0 unfolded). No atomic detail is read or invented — only the CG bead
  positions and contact-state the #1 simulator already produced.
- `scissile_residues`: the two scissile Cα beads, default
  `{Tyr1605, Met1606}` (from `a2_residue_orbital_selector.py`'s
  `SCISSILE_P1_RESNUM=1605 / SCISSILE_P1PRIME_RESNUM=1606`), optionally
  widened to the documented ±3 flank window `[1602..1609]`.
- `probe_radius` = 1.4 Å (water; Lee–Richards / Shrake–Rupley default).
- `bead_radius` = a single documented Cα effective radius (model choice,
  e.g. ≈ 4 Å — the CG bead is **not** an atom; this is stated, not hidden).
- `n_sphere_points` = deterministic golden-spiral mesh count (default 256).

**Per-frame CG relative-exposure estimator** (Shrake–Rupley-style on beads):
```
for each frame f in ensemble:
    for each scissile bead s in scissile_residues:
        mesh = fibonacci_sphere(n_sphere_points)            # deterministic
        accessible = 0
        for p in mesh:
            x = R_f[s] + (bead_radius + probe_radius) * p    # probe-centre pt
            occluded = any( |x - R_f[j]| < (bead_radius + probe_radius)
                            for j != s in beads )            # neighbour test
            if not occluded: accessible += 1
        cg_sasa[s,f]  = (accessible / n_sphere_points) * sphere_area
        cg_rsa[s,f]   = cg_sasa[s,f] / cg_sasa_max[s]        # 0..1, normalised
    # reaction coordinate of the frame = Q (native-contact fraction)
    record( Q_f, mean_scissile_cg_rsa = mean(cg_rsa[s,f] over s) )
```
- `cg_sasa_max[s]` is the per-bead reference taken as the **maximum CG-SASA of
  that bead over the fully-unfolded frames** of *this same ensemble* (an
  internal, ensemble-defined normaliser — honest because it is self-consistent
  and explicitly NOT the Tien-2013 atomic MaxASA; Tien-2013 is cited as the
  *concept* of an RSA normaliser, not applied at atomic resolution to CG
  beads).
- `fibonacci_sphere` = deterministic golden-angle point set (no RNG); identical
  ensemble ⇒ bitwise-identical exposure curve.

**Output: exposure-vs-reaction-coordinate curve**
1. **Curve**: `(Q, mean_scissile_CG_RSA)` for every recorded frame — a
   monotone-trending exposure profile: low CG-RSA at Q≈1 (scissile bond
   *buried* in the folded CG topology), rising CG-RSA as Q→0 (scissile bond
   *exposed* by unfolding). This is the function the proprietary platforms
   advertise, computed transparently.
2. **Exposure-transition midpoint**: the Q at which mean scissile CG-RSA
   crosses the midpoint of its [folded, unfolded] range — the CG-model
   estimate of *where along the unfolding coordinate the cryptic site opens*.
3. **Witness row**: ensemble SEED/hash (from #1), probe & bead radii,
   n_sphere_points, scissile residue set, folded-vs-unfolded CG-RSA endpoints,
   transition-midpoint Q, monotonicity flag, and the CG-resolution caveat
   string. Deterministic — same #1 ensemble ⇒ same witness.

**Acceptance gate (g1 — anchored to a real limit, not the lattice):** the
curve must (i) start *buried* (folded-end mean scissile CG-RSA below a
documented buried threshold, consistent with Zhang Q 2009 / 3GXB: scissile
Tyr–Met in the central β4 strand, sterically occluded) and (ii) end *exposed*
(unfolded-end CG-RSA at the ensemble maximum), with the transition occurring
within the same Q-window the #1 simulator's force–extension rip falls in (the
7–14 pN single-molecule unfolding window, Zhang X 2009). A scissile site that
does NOT become exposed across the #1 ensemble's unfolding range FAILS the
gate (the model would contradict the measured force-exposed-cryptic-site
biology).

---

## §composes-with

This scorer is a **pure downstream consumer** of two existing open in-repo
artefacts — it adds no new ensemble, no new structure, no new sampling:

- **drylab #1 `a2_cg_unfolding`** (`drylab/research/a2_cg_unfolding.md`;
  `drylab/sim/a2_cg_unfolding.py` when built) — supplies the *open*
  forced-unfolding ensemble: frames with `Q`, `extension`, `applied_force`,
  Cα bead coords, and the metastable-state populations. **This is the honest
  open ensemble source that replaces the proprietary platforms' undisclosed
  sampling.** Their generator is secret; #1's Gō/ENM + Ermak–McCammon
  propagator is fully cited (Clementi–Onuchic, Karanicolas–Brooks, Tirion,
  Ermak–McCammon) and reproducible. The scorer reads #1's output frames; it
  does not re-simulate.
- **`_python_bridge/module/a2_residue_orbital_selector.py`** — supplies the
  canonical scissile-residue numbering (`SCISSILE_P1_RESNUM=1605`,
  `SCISSILE_P1PRIME_RESNUM=1606`, window `[1602..1609]`) and the UniProt
  P04275 / PDB 3GXB citation context, so the scorer targets exactly the same
  Tyr1605–Met1606 region the QUANTUM-axis active-space selector targets. The
  exposure-vs-Q curve becomes a *physically motivated weighting input* for
  which unfolded metastable basin a downstream QM active-space carve-out should
  consume (the most-exposed-scissile basin) — composing the open ensemble (#1)
  + the exposure scorer (this) + the active-space seed (selector) into one
  transparent, fully-cited chain, with the proprietary platforms' method
  nowhere in it.

Composition direction: `#1 ensemble → (this) exposure scorer → basin weight →
a2_residue_orbital_selector active-space seed`. Each arrow is open and cited.

---

## §what-this-is-NOT

- **NOT a clone / reconstruction of any proprietary platform.** Relay Dynamo,
  OpenEye Orion Cryptic Pocket Detection, and Redesign Science are described
  *only* by their own public claims; their sampling generators, reaction
  coordinates and ML scoring are undisclosed and are **not** used, inferred,
  approximated, or reverse-engineered (g3).
- **NOT an atomic SASA.** The estimator runs on **Cα coarse-grained beads**,
  not atoms. It is a *topology-level* exposure proxy. It does NOT resolve
  side-chain rotamers, backbone carbonyl geometry, solvent structure, or true
  atomic SASA. The Lee–Richards / Shrake–Rupley algorithm is *adapted* to the
  CG bead radius; absolute Å² values are model-dependent caricatures, only the
  *relative buried→exposed trend vs Q* is the claim.
- **NOT a druggability or binding-affinity prediction.** It quantifies
  geometric solvent exposure of a known scissile site vs an unfolding
  coordinate. It makes **no** statement about ligandability, binding free
  energy, drug efficacy, or clinical relevance (g8 / f2).
- **NOT a pocket-finding search.** The cryptic site here is *already known*
  (Tyr1605–Met1606, Zhang 2009). The scorer measures *exposure of a known
  site*, it does not discover new pockets de novo.
- **NOT a new ensemble.** It strictly consumes the drylab #1 open CG ensemble;
  it generates no trajectory and fabricates no atomic structure.

---

## §real-limit-anchor

Verification-anchored to **real biophysical limits** (g1), all from primary
single-molecule / structural literature — NOT the n=6 lattice:

| Real limit | Value | Primary source |
|---|---|---|
| Scissile bond is force-exposed cryptic (buried folded → exposed unfolded) | qualitative, but measured: cleavage requires mechanical unfolding | Zhang X et al. 2009 Science 324:1330 |
| A2 unfolding force (most-probable) | ≈ 11 pN (range 7–14 pN, loading-rate dependent) | Zhang X et al. 2009 Science 324:1330 |
| A2 unfolding free energy ΔG | 3.9 ± 0.9 kcal/mol (6.6 ± 1.5 k_BT) | Zhang X et al. 2009 Science 324:1330 |
| Scissile bond identity & fold location | Tyr1605–Met1606, central β4 strand of A2 (3GXB) | Zhang Q et al. 2009 PNAS 106:9226 |
| ADAMTS13 cleavage site | Tyr1605–Met1606 | Crawley et al. 2011 Blood 118:3212 |
| Solvent probe radius | 1.4 Å (water) | Lee & Richards 1971 JMB 55:379; Shrake & Rupley 1973 JMB 79:351 |
| RSA normalisation concept | SASA / MaxASA, 0–1 | Tien et al. 2013 PLoS ONE 8:e80635 |

Acceptance gate (restated): the scissile-site CG-RSA must transition from
*buried* (folded end) to *exposed* (unfolded end) within the #1 ensemble's
unfolding Q-window, consistent with the measured force-exposed-cryptic-site
biology (Zhang 2009). The gate is a real-limit consistency check, never a
lattice-tautology.

---

## §honesty-caveat

- **CG resolution is the dominant limit.** The estimator operates on Cα beads,
  not atoms. It captures *topology-driven* burial/exposure of the scissile
  region as the fold opens, NOT atomic SASA, NOT side-chain-resolved exposure,
  NOT solvent structure. Absolute Å² are model-dependent; only the *relative
  buried→exposed trend along Q* is asserted. An atomistic re-evaluation on an
  all-atom-refined intermediate is required before any quantitative exposure
  claim — explicitly out of stdlib scope here.
- **Ensemble inherits #1's CG caveats.** The exposure curve is only as valid
  as the drylab #1 Gō/ENM forced-unfolding ensemble feeding it (model-
  dependent intermediate ensemble, no crystallographically-resolved A2
  unfolding intermediate to validate against — see
  `a2_cg_unfolding.md` §honesty-caveat). This scorer adds no validation it
  does not inherit.
- **Proprietary methods untouched.** No Relay Dynamo / OpenEye / Redesign
  sampling, reaction coordinate, or scoring model was used, fitted, or
  reconstructed. Their *function* is reproduced from independent open
  literature; their *method* is and remains undisclosed and out of scope (g3).
  The "Redesign Science" line is third-party-reported (no primary methods
  paper) and is flagged, not relied on.
- **g8 / f2:** a PASS verifies in-silico simulator+metadata internal
  consistency and consistency with the cited real limits ONLY. It is NOT a
  druggability, therapeutic, clinical, regulatory, or efficacy claim. The
  scissile site's *biological* druggability and any downstream therapeutic
  inference are out of repo scope and require wet-lab validation.

---

## §references

Every reference below was reached via a fetched page or anchored to a verified
bibliographic record during this research. Unverifiable items were dropped
(g3, no fabrication).

1. **Lee B, Richards FM.** "The interpretation of protein structures:
   estimation of static accessibility." *J. Mol. Biol.* **55**, 379–400
   (1971). — *accessible-surface / expanded-sphere (rolling-probe) concept;
   verified via PubMed 5551392, DOI 10.1016/0022-2836(71)90324-X.*
2. **Shrake A, Rupley JA.** "Environment and exposure to solvent of protein
   atoms. Lysozyme and insulin." *J. Mol. Biol.* **79**, 351–371 (1973). —
   *sphere-point (mesh) numerical SASA estimator built on Lee–Richards
   assumptions; verified via PubMed 4760134, DOI
   10.1016/0022-2836(73)90011-9.*
3. **Tien MZ, Meyer AG, Sydykova DK, Spielman SJ, Wilke CO.** "Maximum allowed
   solvent accessibilities of residues in proteins." *PLoS ONE* **8**(11),
   e80635 (2013). — *RSA = SASA / MaxASA normalisation reference (concept
   only; not applied at atomic resolution to CG beads); verified via PLoS ONE
   article record, DOI 10.1371/journal.pone.0080635.*
4. **Cimermancic P, Weinkam P, Rettenmaier TJ, Bichmann L, Keedy DA, Woldeyes
   RA, Schneidman-Duhovny D, Demerdash ON, Mitchell JC, Wells JA, Fraser JS,
   Sali A.** "CryptoSite: Expanding the druggable proteome by characterization
   and prediction of cryptic binding sites." *J. Mol. Biol.* **428**(4),
   709–719 (2016). — *cryptic-site definition (pocket in holo not apo;
   requires conformational change); definition adopted, predictor NOT used;
   verified verbatim via fetched PMC4794384.*
5. **Vajda S, Beglov D, Wakefield AE, Egbert M, Whitty A.** "Cryptic binding
   sites on proteins: definition, detection, and druggability." *Curr. Opin.
   Chem. Biol.* **44**, 1–8 (2018). — *confirms cryptic-site definition and
   MD/conformational-dynamics as the standard open detection route; verified
   verbatim via fetched PMC6088748, DOI 10.1016/j.cbpa.2018.05.003.*
6. **Zhang X, Halvorsen K, Zhang C-Z, Wong WP, Springer TA.**
   "Mechanoenzymatic cleavage of the ultralarge vascular protein von
   Willebrand factor." *Science* **324**, 1330–1334 (2009). — *Tyr1605–Met1606
   is force-exposed: cleavage requires mechanical unfolding; A2 unfolds ≈ 11 pN
   (7–14 pN), ΔG 3.9 ± 0.9 kcal/mol, contour 57 nm, ADAMTS13 k_cat 0.14 s⁻¹;
   verified verbatim via fetched PMC2753189 (in drylab #1).*
7. **Zhang Q, Zhou Y-F, Zhang C-Z, Zhang X, Lu C, Springer TA.** "Structural
   specializations of A2, a force-sensing domain in the ultralarge vascular
   protein von Willebrand factor." *PNAS* **106**, 9226–9231 (2009). — *A2 ≈
   177 aa (Met1495–Ser1671); scissile Tyr1605–Met1606 in the central β4
   strand of the A2 fold (3GXB); verified verbatim via fetched PMC2695068
   (in drylab #1 / a2_residue_orbital_selector.py).*
8. **Crawley JTB, de Groot R, Xiang Y, Luken BM, Lane DA.** "Unraveling the
   scissile bond: how ADAMTS13 recognizes and cleaves von Willebrand factor."
   *Blood* **118**, 3212–3221 (2011). — *ADAMTS13 cleaves vWF A2 at
   Tyr1605–Met1606 (exosite-mediated); bibliographic record cross-cited in
   `a2_residue_orbital_selector.py`.*

Proprietary-platform pages used for *own-claim* SOTA description only (NOT
methodology sources; method undisclosed): Relay Therapeutics Dynamo platform
page (relaytx.com/dynamo-platform — fetched); OpenEye / Cadence Orion Cryptic
Pocket Detection product page (eyesopen.com/cryptic-pocket — fetched);
Redesign Science capability (third-party CoreWeave write-up — partially
verified, flagged, not relied on for any algorithm).

Algorithmic-parameter cross-check (NOT a new claim): Biotite/Biopython
Shrake–Rupley documentation (golden-spiral mesh, 1.4 Å default probe) — used
only to confirm the standard parameterisation of the cited Shrake–Rupley
estimator.

Dropped / not cited (could not verify a primary source, per g3): any specific
Relay/OpenEye/Redesign sampling or scoring algorithm (undisclosed by design);
the Redesign "millisecond / hundreds of thousands of simulations" figures
(reported third-party, not a primary methods paper — recorded as an own-claim
only, not used).
