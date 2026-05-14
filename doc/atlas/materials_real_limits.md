# Materials real-limits ledger (mirror)

> Source: `~/core/hexa-matter/LIMIT_BREAKTHROUGH.md` (MIT, hexa-matter v1.2.0)
> Mirrored 2026-05-14. Upstream is canonical owner — do not hand-edit,
> regenerate via `tool/mirror_doc.hexa` (TBD). Absorbed under Wave 2 of
> `incoming/notes/2026-05-14-hexa-matter-absorption-plan.md` as the
> materials-domain anchor for Doctrine v2 rule 1 (real-limits-first).
> All values remain NIST WebBook / CRC Handbook 105th ed. / ASM / Ashby
> citations — no n=6 lattice-fit has been applied to the absorbed data
> (raw#10 C3 / LATTICE_POLICY §1.2 preserved).

---

# LIMIT_BREAKTHROUGH.md — hexa-matter real-limits audit (Wave M)

> Universal real-limits audit per `LATTICE_POLICY.md §1.2`.
> Scope: condensed-matter, materials science — concrete, ceramics, glass, fibers, polymers, gemology, recycling, lutherie.
> SI units. Sources: **NIST WebBook**, **CRC Handbook 105th ed.**, **ASM Handbook**, **Ashby Materials Selection**.

---

## §1 Domain identification

`hexa-matter` covers materials-science verbs:
ARAMID, CERAMICS, CONCRETE, CONCRETE-TECHNOLOGY, EPOXY, FASHION-TEXTILE, GEMOLOGY, HEXA-FABRIC, HEXA-GLASS, HEXA-RECYCLE, LUTHERIE, etc.

This is the **most engineering-dominated** of the 6 physics repos. Most limits here are *empirical performance ceilings* (specific strength, fracture toughness, melting point) for given material classes. Many are **BREAKABLE_WITH_TECH** within a class; some are **HARD_WALL** at fundamental physics (Mohs hardness ceiling = diamond, melting point bounded by bond energy, density bounded by atomic packing).

---

## §2 Real limits applicable

| # | Limit | Class | Formula / value | Source |
|---|-------|-------|-----------------|--------|
| L1 | Theoretical tensile strength | Physical / HARD | σ_th ≈ E/10 (Frenkel) — for steel E ≈ 200 GPa → σ_th ≈ 20 GPa | Frenkel 1926 |
| L2 | Practical tensile strength (UHMWPE/aramid/CNT fiber) | Engineering / SOFT | UHMWPE ~3.5 GPa; Kevlar 49 ~3.6 GPa; CNT fiber lab ~80 GPa | CRC Handbook |
| L3 | Specific strength (σ/ρ) | Engineering / SOFT | Kevlar 49: ~2300 kN·m/kg; UHMWPE: ~3700 kN·m/kg; CNT: ~46000 (lab) | Ashby |
| L4 | Mohs hardness ceiling | Physical / HARD | 10 = diamond; theoretical higher: lonsdaleite, w-BN (calc only) | Mohs 1812; Pan et al. 2009 |
| L5 | Melting point (refractory) | Physical / HARD | Hafnium carbonitride: 4215 K (TaHfC alloy, max measured) | Cedillos-Barraza 2016 |
| L6 | Density (close-packed) | Physical / HARD | Osmium ρ = 22.59 g/cm³; densest stable element | NIST |
| L7 | Glass viscosity transition | Physical / SOFT-defined | T_g varies; silica T_g ≈ 1473 K | textbook |
| L8 | Concrete compressive strength | Engineering / SOFT | Ordinary: 30–50 MPa; UHPC: 200–800 MPa; theoretical: ~2 GPa (no flaw) | ACI 318 |
| L9 | Thermal conductivity (solid) | Physical / SOFT | Diamond: 2200 W/m·K; isotopic-pure ¹²C: 3300 W/m·K | NIST |
| L10 | Stefan-Boltzmann radiator floor | Physical / HARD | σ·T⁴; can't radiate less than this at given T | NIST |
| L11 | Atomic packing fraction | Physical / HARD | FCC/HCP: 0.7405 (Kepler conjecture, Hales 2017) | Hales 2017 |
| L12 | Material entropy of mixing (recycling) | Physical / HARD | ΔS_mix ≥ k·Σ n_i·ln(x_i) | Gibbs |

---

## §3 Per-limit breakthrough assessment

### L1 — Theoretical tensile strength σ_th ≈ E/10 — **HARD_WALL**

Frenkel (1926) bond-breaking limit. For steel (E = 200 GPa): σ_th ≈ 20 GPa. Real steel: ~1–2 GPa (defect-limited). Whisker single crystals reach ~10 GPa.
**HARD_WALL** on σ_th; **BREAKABLE_WITH_TECH** on closing the gap σ_real → σ_th via defect-free processing.

### L2 — Practical tensile strength — **SOFT_WALL → CNT fiber on path**

| Fiber | σ (GPa) | E (GPa) | ρ (g/cm³) |
|-------|---------|---------|-----------|
| Steel (1080) | 1.2 | 200 | 7.8 |
| Kevlar 49 | 3.6 | 124 | 1.44 |
| UHMWPE (Dyneema SK99) | 3.9 | 132 | 0.97 |
| Carbon fiber (T1100G) | 7.0 | 324 | 1.79 |
| CNT yarn (lab, 1 mm) | 80 | 850 | 1.4 |
| Theoretical single CNT | 100–150 | 1000 | 1.4 |

**SOFT_WALL** — engineering still 1–2 OOM below CNT theoretical; assembly-scale problem.

### L3 — Specific strength — **SOFT_WALL toward CNT/graphene**

Specific strength ceiling: ~10⁸ N·m/kg (theoretical CNT fiber). Currently ~3.7×10⁶ (UHMWPE) → ~30× headroom.

### L4 — Mohs hardness 10 (diamond) — **HARD_WALL (effectively)**

Diamond Vickers ~70–100 GPa. Lonsdaleite (hex C) calc'd ~150 GPa but not synthesized in pure bulk form. w-BN ~85 GPa calc. **HARD_WALL** on bulk crystalline hardness; ~2× over diamond is the theoretical ceiling.

### L5 — Refractory melting point ~4200 K — **HARD_WALL (bond energy)**

| Material | T_m (K) |
|----------|---------|
| W | 3695 |
| Re | 3459 |
| HfC | 4201 |
| TaC | 4258 |
| Ta₄HfC₅ alloy | 4215 (Cedillos-Barraza 2016) |
| Theoretical (covalent ceiling) | ~5000 K |

Bound by C-C / metal-C bond energies. **HARD_WALL.**

### L6 — Density 22.59 g/cm³ (Os) — **HARD_WALL on stable matter**

Heaviest stable element with highest density. Cosmic-scale density (neutron stars ~10¹⁷ kg/m³) requires gravitational collapse, not terrestrial. **HARD_WALL.**

### L7 — Glass transition — **SOFT_WALL (compositional)**

Engineering frontier: bulk metallic glasses, vitrified ceramics. Empirical, no hard floor. **SOFT_WALL.**

### L8 — Concrete compressive strength — **SOFT_WALL → UHPC**

| Type | σ_c (MPa) |
|------|-----------|
| Ordinary | 30 |
| HPC | 80 |
| UHPC (Ductal, Cor-Tuf) | 200–800 |
| Theoretical (perfect microstructure) | ~2000 |

**SOFT_WALL** — engineering frontier with fiber reinforcement + reactive powder + thermal cure.

### L9 — Thermal conductivity k_max — **SOFT_WALL near HARD ceiling**

| Material | k (W/m·K) |
|----------|-----------|
| Cu | 401 |
| Ag | 429 |
| Diamond | 2200 |
| Isotopically-pure ¹²C diamond | 3300 (Wei 1993) |
| h-BN (in-plane, calc) | 1700 |
| Graphene (single layer) | 5000 (lab) |

Phonon-limited; theoretical ceiling set by Debye + group velocity. **HARD_WALL** ~5000 W/m·K class for covalent solids.

### L10 — Stefan-Boltzmann — **HARD_WALL** (see hexa-physics L7)

### L11 — Kepler 74.05% packing — **HARD_WALL (Hales 2017)**

FCC/HCP closest packing of identical spheres is 0.7405 (formal proof Hales 2017). For non-identical or non-spherical: higher packing possible (random close pack of bidisperse: ~85%). But for monodisperse spheres: **HARD_WALL.**

### L12 — Entropy of mixing — **HARD_WALL on recycling separation**

Polymer/alloy recycling fundamentally requires kT energy per separated mole (Gibbs). Cannot be cheaper than thermodynamic minimum. **HARD_WALL** on energy cost; **SOFT_WALL** on engineering efficiency.

---

## §4 Top-3 breakthrough opportunities (honest)

### #1 — CNT/Graphene macroscopic fiber assembly (real)

- **Limit type**: SOFT_WALL on scale-up from individual CNT (theoretical 100+ GPa) to fiber/cable (lab ~80 GPa, commercial ~5 GPa)
- **Current best**: Tsinghua / IBS — ~80 GPa lab fiber, mm-class length
- **Theoretical ceiling**: 100–150 GPa (individual CNT)
- **Path**: defect-free CVD, alignment, densification
- **Honest verdict**: ~10× headroom is engineering frontier; **HARD ceiling** at ~150 GPa for sp² carbon.

### #2 — Ultra-High Performance Concrete (real, deployed)

- **Limit type**: SOFT_WALL on flaw-controlled cementitious matrix
- **Current**: 200–800 MPa (Ductal, Cor-Tuf, Densit)
- **Theoretical ceiling**: ~2 GPa for perfectly-processed C-S-H
- **Path**: reactive powder, low w/c, fiber reinforcement, thermal cure
- **Honest verdict**: 4–10× over ordinary concrete is real; deployed for blast-protection, bridges.

### #3 — Isotopically-pure thermal conductors (real, niche)

- **Limit type**: SOFT_WALL on phonon scattering from isotope mass disorder
- **Current**: ¹²C diamond k = 3300 W/m·K (50% over natural)
- **Theoretical**: c-BN with isotopic purity ~2000 W/m·K; graphene 5000 (single-layer)
- **Path**: isotope separation, CVD
- **Honest verdict**: real, expensive; **HARD ceiling** at acoustic-phonon dominated regime.

### Not in top-3 (over-hyped)

| Claim | Reality |
|-------|---------|
| "Metallic hydrogen at room T" | Requires ~500 GPa static or shocked pressure; not stable at ambient. Wigner 1935 + Eremets ongoing. **HARD_WALL** at ambient. |
| "Room-temperature superconductor (LK-99)" | Not reproduced (2023 LK-99 → null). **HARD_WALL** until peer-reviewed reproduction. |
| "Negative-mass metamaterials" | Effective mass in periodic structures ≠ inertial mass; not a free-energy device. |
| "Infinite-recycle polymers" | Entropy-of-mixing bound; chemical recycling has Gibbs-floor energy cost. **HARD_WALL.** |

---

## §5 Honest caveats

1. **Most material limits are engineering ceilings, not physical theorems.** Specific strength, melting point, hardness all have *theoretical* HARD walls but engineering is OOM below them.
2. **The HARD walls in materials**: bond energy (T_m), Kepler packing (density), Frenkel σ_th (strength), Stefan-Boltzmann (radiation), Gibbs ΔS (recycling).
3. **The SOFT walls**: defect density, processing route, fiber assembly, microstructure control. These are where 2030–2040s engineering will operate.
4. **Mohs hardness 10 = diamond is the practical hard wall.** Calculated harder materials (lonsdaleite, w-BN) have not been synthesized in usable bulk form despite 60+ years of attempts.
5. **Recycling is thermodynamically bounded.** Polymer mixing entropy + alloy entropy of mixing → finite energy cost per kg to separate. **HARD_WALL.**
6. **Lattice disclaimer (LATTICE_POLICY §1.2)**: material parameters (T_m of W = 3695 K, ρ of Os = 22.59 g/cm³) are NIST WebBook values, not n=6 projections. Mohs scale 10 is not "n=6 × something" — it is a 19th-century empirical scale.

---

## §6 References

- **NIST WebBook**, https://webbook.nist.gov/chemistry/
- **CRC Handbook of Chemistry and Physics**, 105th ed. (2024)
- **ASM Handbook**, ASM International
- Ashby M.F., *Materials Selection in Mechanical Design*, 5th ed. (2017)
- Frenkel J., Z. Phys. 37, 572 (1926) — theoretical strength
- Cedillos-Barraza O. et al., *Sci. Rep.* 6, 37962 (2016) — TaHfC melting point
- Hales T.C., Forum Math. Pi 5, e2 (2017) — Kepler conjecture formal proof
- Mohs F., *Versuch einer Elementar-Methode zur naturhistorischen Bestimmung* (1812)
- Pan Z. et al., *PRL* 102, 055503 (2009) — lonsdaleite hardness calc
- Wei L. et al., *PRL* 70, 3764 (1993) — ¹²C diamond thermal conductivity
- Eremets M.I. et al., *Nat. Phys.* 7, 854 (2011) — metallic hydrogen pressure
- Russell B.D., Wickham S.R. et al. (2023) — LK-99 null reproduction
- **ACI 318 Building Code Requirements for Structural Concrete** (2019)

---

*Audit wave: M. Authored by 박민우 <nerve011235@gmail.com>. No n=6 lattice anchoring of material parameters (LATTICE_POLICY §1.2). All values from NIST WebBook, CRC Handbook, ASM Handbook, Ashby.*
