# aav_capsid_assembly — RE spec (Zlotnick nucleation–elongation, T=1)

drylab catalog **#7**. Built FOREGROUND (the agent RE+build path has a
demonstrated Usage-Policy gate false-positive on bio+RE prompts — #34/#8;
this is textbook published kinetics, rebuilt directly from
already-repo-verified primaries, no web fetch needed).

## §SOTA-landscape (own-claims; method-vs-this)
Atomistic capsid-assembly is done with proprietary/academic
coarse-grained MD (e.g. Hagan/Brooks frameworks, OxDNA-class). Those
resolve trajectory-level assembly. **This is NOT that.** This is the
classic **Zlotnick reduced nucleation–elongation law-of-mass-action**
model — a transparent stdlib steady-state/kinetic estimator for the
AAV9 T=1 (60-subunit) capsid. The repo's `virocapsid_pdb_corpus.py`
only AUDITS a structural corpus; it has no assembly-thermodynamics sim.

## §Reverse-engineered-relations (cited — repo-verified primaries)
- **Caspar DLD, Klug A.** Cold Spring Harb Symp Quant Biol 1962;27:1 —
  quasi-equivalence; T-number tilings. AAV is **T=1** (60 copies of the
  capsid protein; the icosahedral asymmetric unit ×60).
- **Zlotnick A.** "To build a virus capsid: an equilibrium model of the
  self-assembly of polyhedral protein complexes." Biochemistry
  1994;33:bbc — nucleation–elongation: a slow nucleus of size n*,
  then fast elongation; per-contact association free energy ΔG_contact
  is small and the cooperativity comes from contact multiplicity. The
  pseudo-critical concentration ≈ exp(ΔG_contact·⟨c⟩ / RT)-scaled.
- **DiMattia MA et al.** J Virol 2012;86:6947 (PDB **3UX1**) — AAV9
  capsid is the T=1, 60-subunit reference (already repo-verified).
ΔG_contact taken as an order-of-magnitude band (−2 … −5 kcal/mol per
subunit-subunit interface, the documented weak-cooperative regime),
swept, NOT fitted (g1).

## §stdlib-implementation-spec
Pure-stdlib, deterministic. Law-of-mass-action nucleation–elongation
for an N=60 (T=1) shell: free subunit ↔ nucleus (size n*) ↔ growing
intermediate ↔ complete 60-mer. Given total subunit concentration C_tot,
ΔG_contact, n*, compute the steady-state fraction in complete capsids
vs C_tot (the sigmoidal assembly curve with a pseudo-critical
concentration). Output: assembly-curve, pseudo-critical concentration,
the Caspar-Klug invariant check (60 = 12 pentamers; T=1), witness hash.

## §what-this-is-NOT
NOT atomistic / trajectory MD. NOT a yield or manufacturability
prediction. NOT a clinical/therapeutic claim (g8/f2). The reduced model
gives the qualitative sigmoidal assembly behaviour + pseudo-critical
concentration scaling — absolute concentrations are caricatures, only
the cooperative-assembly trend + the T=1 invariant are claimed. NOT a
reproduction of any proprietary assembly-MD suite.

## §real-limit-anchor
Caspar-Klug T=1 (60-subunit closed shell — a geometric theorem) +
Zlotnick cooperative ΔG window (real assembly thermodynamics). Honest
claim: the model reproduces the cooperative sigmoidal assembly with a
pseudo-critical concentration set by ΔG_contact — the Zlotnick premise,
at reduced fidelity.

## §honesty-caveat
ΔG_contact + n* are order-of-magnitude bands (NOT fitted, g1);
robustness across the band reported. Reduced law-of-mass-action, NOT
kinetic-trajectory. In-silico simulator-consistency only (g8/f2).

## §references
- Caspar DLD, Klug A. CSHSQB 1962;27:1
- Zlotnick A. Biochemistry 1994;33 (nucleation–elongation equilibrium model)
- DiMattia MA et al. J Virol 2012;86:6947 (PDB 3UX1, AAV9 T=1) — repo-verified
