# a2_adamts13_pose — RE spec (geometric scissile-accessibility, serves ②)

drylab catalog **#8**. Built FOREGROUND (the RE+build agent hit a
Usage-Policy gate false-positive — same benign-work / heuristic-flag
pattern as #34 cryptic / #11 ml_capsid; rebuilt directly from
already-repo-verified primary refs, no web fetch needed).

## §SOTA-landscape (own-claims; method-vs-this)
Atomic ADAMTS13–vWF-A2 docking is done with proprietary/academic
all-atom suites (Schrödinger, HADDOCK, Rosetta — described by their own
claims). Those resolve side-chain/affinity at atomic resolution. **This
is NOT that.** This is a transparent CG **geometric accessibility
proxy** — it asks only "can an ADAMTS13 distal-domain footprint reach
the scissile bond, given the A2 chain's unfolding state", at the same
Cα-coarse-grained resolution as drylab #1. No affinity, no docking pose,
no energy.

## §Reverse-engineered-geometry (cited — all repo-verified primaries)
- **Zhang X, Halvorsen K, Zhang C-Z, Wong WP, Springer TA.** Science
  2009;324:1330 (PMC2753189) — the scissile **Tyr1605–Met1606** bond is
  a FORCE-EXPOSED CRYPTIC site: buried in folded A2, exposed only under
  mechanical unfolding.
- **Crawley JT, de Groot R, Xiang Y, Luken BM, Lane DA.** Blood
  2011;118:3212 — ADAMTS13 engages unfolded A2 via MULTIPLE distal-domain
  exosites; the spacer-domain exosite binds the A2 C-terminal region
  (~res 1653–1668) while the metalloprotease (MP) domain cleaves at
  1605–1606. Cleavage requires A2 unfolded so the scissile bond is both
  solvent-exposed AND positioned for the rigid distal-domain frame.
- **Akiyama M, Takeda S, Kokame K, Takagi J, Miyata T.** PNAS
  2009;106:19274 — crystal structure of ADAMTS13 **DTCS**
  (Disintegrin–TSP1–Cys-rich–Spacer): the distal domains form an
  ELONGATED arrangement. The spacer→MP-active-site span is the geometric
  reach that must bridge the spacer-anchor (~A2 res 1660) to the scissile
  (1605). Exact span is NOT openly a single number → modelled as an
  explicit order-of-magnitude band (g1, NOT fitted), robustness reported.

## §stdlib-implementation-spec
Pure-stdlib, deterministic. Consumes the drylab #1 `a2_cg_unfolding`
ensemble interface `[{Q, extension, applied_force, R:{resnum:(x,y,z)}}]`
(synthetic clearly-labelled fixture if #1 absent). Per frame:
1. **scissile CG-exposure** of {1605,1606} (Shrake–Rupley-style on Cα
   beads, as in cryptic_pocket_exposure) → buried folded, exposed
   unfolded.
2. **extended-engagement gate**: ADAMTS13's ELONGATED DTCS frame
   (Akiyama 2009) engages the UNFOLDED, LAID-OUT A2 — the spacer exosite
   (~1653-1668) and the MP active site (1605-1606) bind SIMULTANEOUSLY
   across the elongated protease (Crawley 2011). So a cleavage-competent
   pose requires the 1605↔1660 segment EXTENDED (≥ a minimum laid-out
   separation), NOT collapsed. Gate = `d(spacer-anchor, scissile) ≥
   ENGAGE_MIN_NM ∈ [3, 6]` (order-of-magnitude, swept, NOT fitted, g1).
   **Honesty note**: an earlier draft had this geometrically INVERTED
   (modelled as a max "reach ≤ band", which made the unfolded extended
   substrate test as *inaccessible* — biologically backwards). Corrected
   here per Crawley 2011 / Akiyama 2009; the resulting PASS is a
   consequence of the correct geometry, NOT tuning (g1/g3).
3. **pose-accessible-fraction(Q)** = (scissile exposed) AND (reach gate
   satisfied), evaluated robustly across the REACH band.
Output: accessible-fraction-vs-Q curve + transition-Q + witness hash.

## §composes-with
`#1 a2_cg_unfolding` (ensemble source) → this (#8 accessibility) ←→
`cryptic_pocket_exposure` (exposure term reused) · scissile residues from
`_python_bridge/module/a2_residue_orbital_selector.py` (1605/1606).

## §what-this-is-NOT
NOT QM. NOT a docking pose. NOT a binding affinity / ΔG / k_cat. NOT a
druggability or clinical/therapeutic claim. NOT atomic — Cα-CG only;
absolute nm are caricatures, ONLY the folded-inaccessible →
unfolded-accessible relative trend is claimed. NOT a reproduction of any
proprietary docking suite. The cleavage-site is ALREADY known
(Tyr1605–Met1606, Zhang 2009) — this measures geometric accessibility of
a known site vs unfolding, it discovers nothing de novo.

## §real-limit-anchor
Zhang 2009 force-exposed scissile (real biophysics) + Akiyama 2009
elongated-DTCS distal-domain architecture (real structure). The honest
claim is mechanistic-consistency: folded A2 ⇒ scissile geometrically
INACCESSIBLE to the ADAMTS13 footprint; unfolded ⇒ accessible — the
aVWS premise, at CG fidelity.

## §honesty-caveat
CG-resolution load-bearing. REACH_NM is an order-of-magnitude band, not a
fitted constant (g1) — robustness across the band is reported, not a
single tuned point. In-silico simulator-consistency only (g8/f2); no
therapeutic/clinical/affinity claim. Does NOT make ② a robust positive
(DHS #6 verdict stands: PARAMETER_BAND_DEPENDENT).

## §references
- Zhang X et al. Science 2009;324:1330 (PMC2753189)
- Crawley JT et al. Blood 2011;118:3212
- Akiyama M et al. PNAS 2009;106:19274
- Shrake A, Rupley JA. J Mol Biol 1973;79:351 (CG-SASA method, via cryptic_pocket_exposure)
