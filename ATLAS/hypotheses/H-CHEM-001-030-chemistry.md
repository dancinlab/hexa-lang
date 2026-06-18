---
id: H-CHEM-001-030
title: Chemistry Domain Hypotheses
grade: 🟥 (Golden Zone dependent)
domain: chemistry
verified: 2026-03-28
summary: "12 exact, 1 structural, 11 trivial, 6 wrong"
---

# Chemistry Domain Hypotheses (H-CHEM-001 to 030)

## Verification Summary (2026-03-28)

```
  Total: 30 hypotheses
  🟩 Exact/Proven:        12  (chemistry facts correct; TECS mappings ad hoc)
  🟧 Structural match:     1  (numerically close, structurally interesting)
  ⚪ Trivial/Coincidence:  11  (arithmetically correct but numerological)
  ⬛ Wrong/Incorrect:       6  (factually or arithmetically wrong)

  Script: verify/verify_chem_hypotheses.py
  Run:    PYTHONPATH=. python3 verify/verify_chem_hypotheses.py
```

## A. Quantum Chemistry / Orbitals

🟩 **H-CHEM-001: Carbon Electron Count** — Carbon Z=6 is the only element that is both a perfect number and has tau(Z)=4 divisors matching sp3 hybridization. Prediction: Among Z=1-20, only Z=6 simultaneously satisfies perfect number condition and tau(Z)=4.
> Verified: is_perfect(6)=True, tau(6)=4, no other Z in 1-20 satisfies both. Exact. Mapping of tau to sp3 is ad hoc.

🟩 **H-CHEM-002: sp3 Tetrahedral Angle = -1/tau(6)** — The tetrahedral bond angle 109.47deg has cos(theta) = -1/3, where 1/3 is the TECS meta fixed point. Prediction: cos(109.47deg) = -1/3 exactly, verifiable by direct computation.
> Verified: cos(109.4712deg) = -0.33333. Well-known geometry result. 1/3 = TECS meta fixed point connection is coincidental.

⬛ **H-CHEM-003: Benzene MO Energy Gap** — Benzene's 6 pi-electron Huckel MO system has HOMO-LUMO gap = 2|beta|, where 2 = sigma_{-1}(6). Bonding orbital fraction = 4/6 = 2/3. Prediction: Only n=6 annulene has gap exactly 2|beta| with all bonding orbitals filled.
> Refuted: Gap = 2|beta| is correct. But bonding orbital fraction = 3/6 = 1/2 (not 4/6 = 2/3). Huckel energies: {2, 1, 1, -1, -1, -2}. Only 3 orbitals are bonding (positive coefficient). Key numerical claim wrong.

⚪ **H-CHEM-004: p-Orbital Filling at Z=6** — Carbon 2p2 fills 2 of 3 degenerate orbitals (Hund's rule), giving ratio 2/3 = phi(6)/3. Prediction: The p-orbital filling fraction at Z=6 equals 2/3 = 1 - 1/3 (meta fixed point complement).
> Verified: 2/3 is correct. But 2/3 is a trivially common fraction; phi(6)/3 mapping is numerological.

⚪ **H-CHEM-005: Carbon IE Ratio approx sigma_{-1}(6)** — Carbon IE2/IE1 = 2352.6/1086.5 = 2.166 approx sigma_{-1}(6) = 2. Prediction: Among Period 2 elements, carbon's IE2/IE1 is closest to 2 (within 9%).
> Partially wrong: IE2/IE1 = 2.166 is within 8.3% of 2 (correct). But carbon is NOT closest to 2: F(2.007) and Be(1.953) are both closer. "Closest" claim is false. Arithmetic itself is correct.

## B. Periodic Trends

⚪ **H-CHEM-006: Period 2 Electronegativity Ratio** — Pauling EN max/min for Period 2 p-block: F(3.98)/B(2.04) = 1.95 approx sigma_{-1}(6) = 2. Prediction: Ratio equals 2 within 3%.
> Verified: 3.98/2.04 = 1.951, error 2.5% from 2. Within 3%. But 2 is a trivial target.

⚪ **H-CHEM-007: Carbon Atomic Radius at GZ Upper** — Carbon's normalized covalent radius C/Li = 0.76/1.28 = 0.594 approx GZ upper + ln(4/3)/pi. Prediction: Carbon's normalized radius falls at the Golden Zone boundary region [0.5, 0.6].
> Verified: 0.76/1.28 = 0.594, in [0.5, 0.6]. Covalent radii vary by source. Range is broad.

⬛ **H-CHEM-008: CHNOPS Electron Affinity** — Mean EA of {C,N,O,P,S} / max(EA_O) approx 1/e = Golden Zone center. Prediction: The ratio lies within [0.3, 0.4].
> Refuted: EAs (kJ/mol): C=121.8, N=-7.0, O=141.0, P=72.0, S=200.4. Mean/EA(O) = 0.749. Using max(all)=S: 0.527. Neither falls in [0.3, 0.4]. N's negative EA invalidates the premise.

⬛ **H-CHEM-009: Carbon-Phosphorus Diagonal** — Z_P - Z_C = 15-6 = 9 = 3^2, where 3 | 6. Their Allred-Rochow electronegativities differ by <15%. Prediction: C-P electronegativity difference < 15%, testable from standard tables.
> Refuted: Z difference = 9 = 3^2 is correct. But Allred-Rochow EN: C=2.50, P=2.06, difference = 17.6% > 15%. The <15% claim fails.

⚪ **H-CHEM-010: Carbon at Half-Shell** — Carbon is element 4 of 8 in Period 2, position 4/8 = 1/2 = Golden Zone upper = Riemann critical line. Prediction: Only perfect-number element at exact half-shell position.
> Verified: 4/8 = 1/2. Exact. But 1/2 is the most common fraction; not structurally deep.

## C. Molecular Geometry / VSEPR

⚪ **H-CHEM-011: Benzene D6h Order = sigma(6) x sigma_{-1}(6)** — D6h symmetry order = 24 = 12x2 = sigma(6) x sigma_{-1}(6). Prediction: Exact arithmetic identity, verifiable from character tables.
> Verified: D6h order = 24. sigma(6)=12, sigma_{-1}(6)=2. 12x2=24. Exact but trivial factorization (24=12x2).

🟩 **H-CHEM-012: Octahedral Edges = sigma(6)** — Octahedral complexes [ML6] have 12 edges = sigma(6). Coordination number 6 = n. Prediction: Octahedron edges = sigma(6) = 12, exact.
> Verified: Octahedron: 6 vertices, 12 edges, 8 faces. Coordination = 6. Both exact geometric facts.

⚪ **H-CHEM-013: Water Angle Deviation** — H2O 104.5deg deviates from tetrahedral 109.47deg by 4.97deg. Fraction 4.97/109.47 x tau(6) = 0.182 approx phi(6)/sigma(6) = 1/6 = 0.167. Prediction: Deviation fraction x tau(6) approx 1/6 within 9%.
> Verified: 4.97/109.47 x 4 = 0.1816, target 1/6 = 0.1667. Error 9.0%. Borderline within 9% tolerance. Mapping is forced.

🟩 **H-CHEM-014: Methane Symmetry = sigma(6) x sigma_{-1}(6)** — CH4 Td order = 24, bond count = tau(6) = 4. Prediction: Both exact arithmetic identities.
> Verified: Td order = 24, tau(6) = 4 bonds in CH4. Both exact. Same 24=12x2 as H-CHEM-011.

🟩 **H-CHEM-015: Cyclohexane H-count = sigma(6)** — C6H12 has 12 hydrogen atoms = sigma(6). Zero ring strain from perfect 6-member ring. Prediction: sigma(6) = 12 hydrogens, exact.
> Verified: C6H12 has 12 H = sigma(6). Exact. But 12 = 2x6 follows directly from CnH2n formula.

## D. Reaction Kinetics / Thermodynamics

🟩 **H-CHEM-016: Arrhenius 1/e Fraction** — At T* = Ea/R, Boltzmann fraction = exp(-1) = 1/e = Golden Zone center. Prediction: Exact to arbitrary precision.
> Verified: exp(-Ea/(R*Ea/R)) = exp(-1) = 1/e. Exact tautology by definition.

🟩 **H-CHEM-017: Equilibrium Forward Fraction** — At K_eq = 1 (DG=0), k_f/(k_f+k_r) = 1/2 = Golden Zone upper. Prediction: Exact thermodynamic identity.
> Verified: K=1 implies kf=kr, fraction=1/2. Exact tautology.

⚪ **H-CHEM-018: Temperature Factor 4/3** — A 4/3 temperature ratio (300K to 400K) corresponds to Golden Zone width origin ln(4/3). Prediction: For Ea=50 kJ/mol at 300K, delta_ln(k) = 5.01, testable by Arrhenius plot.
> Verified: (50000/8.314)*(1/300-1/400) = 5.012. Claimed 5.01 matches. But T2/T1=4/3 chosen to match GZ; connection is forced.

⬛ **H-CHEM-019: Hexamer Hill Coefficient** — Cooperative hexameric assemblies (insulin hexamer) have Hill coefficient n approx 6. Prediction: n in [5.5, 6.5] for true hexamers, from published binding data.
> Refuted: Hill coefficient != subunit count. Insulin hexamer binding Hill coefficients are typically 2-4 in published data. n=6 would require perfect cooperativity, which does not occur. Conflates stoichiometry with cooperativity.

⬛ **H-CHEM-020: Cyclohexane C-C Energy in GZ** — C-C bond energy fraction in cyclohexane combustion = 6x346/(6x346+12x411) = 0.421, in Golden Zone. Prediction: 0.421 in [0.212, 0.500], from bond enthalpy tables.
> Refuted: 6x346/(6x346+12x411) = 2076/7008 = 0.296, NOT 0.421. The stated arithmetic is wrong. (Actual 0.296 does fall in GZ, but the claimed value is incorrect.)

## E. Biochemistry / Life Chemistry

⚪ **H-CHEM-021: CHNOPS = 6 Elements** — Life's 6 essential bulk elements {C,H,N,O,P,S} = n = first perfect number. Prediction: Count equals 6, and no other 6-element subset from Z=1-20 has higher bonding versatility.
> Verified: CHNOPS = 6 elements. Well-known biochemistry fact. Perfect number connection is numerological.

⚪ **H-CHEM-022: DNA H-bond Counts = Divisors of 6** — A-T has 2, G-C has 3 H-bonds; {2,3} are the non-trivial proper divisors of 6, and 2x3 = 6. Prediction: Exact match to divisor set.
> Verified: {2,3} = proper divisors of 6 (excluding 1,6). Exact. But 2 and 3 are ubiquitous small numbers.

⚪ **H-CHEM-023: Maximum Codon Degeneracy = 6** — Three amino acids (Leu, Ser, Arg) have 6-fold codon degeneracy, the maximum. Prediction: Max degeneracy = 6 = n, from genetic code table.
> Verified: Leu, Ser, Arg each have 6 codons (the maximum). Well-known genetic code fact.

⬛ **H-CHEM-024: Carbon Allotropes = tau(6)** — 4 major carbon allotropes (diamond, graphite, fullerene, nanotube) = tau(6) = 4. Prediction: More than any element Z<20.
> Refuted: Carbon has 5+ recognized allotropes (diamond, graphite, fullerenes, nanotubes, graphene, amorphous carbon, lonsdaleite, etc.). Claiming exactly 4 is cherry-picked. Graphene alone (2004 Nobel Prize) makes it at least 5.

⚪ **H-CHEM-025: ATP Energy / RT approx sigma(6)** — |DG_ATP|/(RT_body) = 30500/(8.314x310) = 11.83 approx sigma(6) = 12. Prediction: Within 1.4% of sigma(6).
> Deep review (H-CHEM-025-deep-atp-energy.md): Downgraded 🟧 to ⚪. Standard DG gives 1.4% match, but physiological DG is -50 to -65 kJ/mol giving ratio ~20, not 12. The match is an artifact of choosing the standard-state reference value. See deep analysis for F1 hexamer (6 subunits, genuinely exact) and electron pair count (12, tautological from C6 sugar).

## F. Materials / Crystallography

🟩 **H-CHEM-026: Graphene Unit Cell = phi(6)** — Graphene has 2 atoms per unit cell = phi(6), coordination number 3 (divisor of 6). Prediction: Both exact.
> Verified: 2 atoms/cell = phi(6) = 2. Coordination = 3, and 3|6. Both exact. phi(6)=2 is trivial.

🟩 **H-CHEM-027: Diamond 2nd Neighbors = sigma(6)** — Each carbon in diamond has 12 second-nearest neighbors = sigma(6). Prediction: Exact, from crystallography.
> Verified: Diamond: 4 nearest, 12 second-nearest neighbors. sigma(6) = 12. Exact crystallographic fact.

🟩 **H-CHEM-028: HCP Void Fraction in GZ** — HCP void fraction = 1 - pi/(3sqrt(2)) = 0.2595, in Golden Zone [0.212, 0.500]. Coordination = 12 = sigma(6). Prediction: 0.2595 in GZ, exact calculation.
> Verified: Void = 0.2595, GZ = [0.212, 0.500]. Coordination = 12 = sigma(6). Both correct. GZ is 29% wide.

🟩 **H-CHEM-029: C60 Pentagons = sigma(6)** — Buckminsterfullerene has 12 pentagons = sigma(6). Euler characteristic V-E+F = 60-90+32 = 2 = sigma_{-1}(6). Prediction: Both exact.
> Verified: 12 pentagons = sigma(6). V-E+F = 2 = sigma_{-1}(6). Both exact. Note: Euler characteristic = 2 for ALL convex polyhedra (not C60-specific).

🟩 **H-CHEM-030: Ice Residual Entropy in GZ** — Pauling entropy S0 = R*ln(3/2), and ln(3/2) = 0.405 lies in Golden Zone. Prediction: 0.405 in [0.212, 0.500], from Pauling (1935).
> Verified: ln(3/2) = 0.4055, in GZ [0.212, 0.500]. Exact. GZ spans 29% of [0,1].
