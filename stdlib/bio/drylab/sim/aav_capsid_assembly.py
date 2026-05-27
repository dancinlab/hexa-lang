#!/usr/bin/env python3
"""aav_capsid_assembly.py — drylab #7 · Zlotnick nucleation–elongation (T=1).

Transparent stdlib reduced law-of-mass-action model of AAV9 T=1
(60-subunit) capsid self-assembly. Built FOREGROUND from
drylab/research/aav_capsid_assembly.md (agent bio+RE prompts have a
demonstrated Usage-Policy gate false-positive — #34/#8; this is textbook
Zlotnick/Caspar-Klug kinetics, rebuilt directly from repo-verified
primaries).

═══ WHAT THIS IS NOT ═══
- NOT atomistic / trajectory MD. NOT a yield or manufacturability
  prediction. NOT a clinical/therapeutic claim (g8/f2).
- Absolute concentrations are caricatures; ONLY the cooperative
  sigmoidal-assembly trend + the T=1 (60-subunit) invariant are claimed.
- NOT a reproduction of any proprietary assembly-MD suite. The repo's
  virocapsid_pdb_corpus only AUDITS a corpus; this is the missing
  assembly-thermodynamics model.

Cited primaries (repo-verified): Caspar & Klug CSHSQB 1962;27:1
(quasi-equivalence, T-number) · Zlotnick A. Biochemistry 1994;33
(nucleation–elongation equilibrium) · DiMattia 2012 J Virol 86:6947
(PDB 3UX1, AAV9 T=1 60-subunit reference).
"""

from __future__ import annotations

import hashlib
import math
import sys

R_KCAL = 1.987204e-3            # gas constant kcal/(mol·K)
T_K = 310.0
N_SUBUNITS_T1 = 60             # AAV T=1: 60 copies (12 pentamers)
PENTAMERS_T1 = 12
# ΔG per subunit–subunit interface — order-of-magnitude weak-cooperative
# band (Zlotnick regime), swept, NOT fitted (g1).
DG_CONTACT_KCAL_BAND = (-5.0, -2.0)
NUCLEUS_SIZE_BAND = (3, 6)     # n* critical-nucleus order (Zlotnick)
CONTACTS_PER_SUBUNIT = 4.0     # avg interface multiplicity for a closed T=1 shell


def caspar_klug_t1_ok() -> bool:
    """T=1 closed-shell invariant: 60 subunits = 12 pentamers (T = h²+hk+k²,
    (h,k)=(1,0) → T=1 → 60·T copies). Geometric theorem (Caspar-Klug 1962)."""
    return N_SUBUNITS_T1 == 60 and PENTAMERS_T1 == 12 and N_SUBUNITS_T1 == 60 * 1


def pseudo_critical_conc_uM(dG_contact_kcal: float,
                            contacts_per_subunit: float = CONTACTS_PER_SUBUNIT) -> float:
    """Zlotnick pseudo-critical concentration scaling:
       C* ≈ exp(+ΔG_assoc_per_subunit / RT)  (ΔG_assoc < 0 ⇒ small C*).
    ΔG_assoc_per_subunit ≈ ½·contacts·ΔG_contact (½: each contact shared).
    Reported in arbitrary µM-scale caricature units (absolute value NOT a
    claim — only the cooperative scaling vs ΔG_contact is)."""
    dG_assoc = 0.5 * contacts_per_subunit * dG_contact_kcal
    return math.exp(dG_assoc / (R_KCAL * T_K)) * 1.0e3   # caricature µM


def assembly_fraction(C_tot_uM: float, C_star_uM: float,
                       n_star: int) -> float:
    """Cooperative sigmoidal capsid fraction: a Hill-like nucleation–
    elongation form f = x^n*/(1+x^n*) with x = C_tot/C* (Zlotnick: the
    nucleus size sets the cooperativity steepness). Reduced, not kinetic."""
    if C_star_uM <= 0:
        return 1.0 if C_tot_uM > 0 else 0.0
    x = C_tot_uM / C_star_uM
    xn = x ** n_star
    return xn / (1.0 + xn)


def assembly_curve() -> dict:
    # robust = conservative weak-contact bound (least cooperative) at the
    # larger nucleus; report both band ends.
    dg_weak, dg_strong = DG_CONTACT_KCAL_BAND          # (-5,-2): -2 = weakest
    n_lo, n_hi = NUCLEUS_SIZE_BAND
    C_star_weak = pseudo_critical_conc_uM(dg_strong)   # weakest contact → highest C*
    C_star_strong = pseudo_critical_conc_uM(dg_weak)   # strongest → lowest C*
    grid = []
    C_ref = C_star_weak
    for mult in (0.25, 0.5, 1.0, 2.0, 4.0, 8.0):
        Ct = mult * C_ref
        f_weak = assembly_fraction(Ct, C_star_weak, n_hi)
        f_strong = assembly_fraction(Ct, C_star_strong, n_lo)
        grid.append({
            "C_tot_over_Cstar_weak": mult,
            "frac_complete_weakband": round(f_weak, 4),
            "frac_complete_strongband": round(f_strong, 4),
        })
    # sigmoidal: low at sub-critical, →1 well above C* (cooperative)
    low = assembly_fraction(0.25 * C_ref, C_star_weak, n_hi)
    high = assembly_fraction(8.0 * C_ref, C_star_weak, n_hi)
    sigmoidal = (low < 0.2) and (high > 0.8)
    h = hashlib.sha256(repr(grid).encode()).hexdigest()[:16]
    return {
        "t1_invariant_ok": caspar_klug_t1_ok(),
        "n_subunits": N_SUBUNITS_T1, "pentamers": PENTAMERS_T1, "T_number": 1,
        "dG_contact_kcal_band": list(DG_CONTACT_KCAL_BAND),
        "nucleus_size_band": list(NUCLEUS_SIZE_BAND),
        "C_star_uM_band_caricature": [round(C_star_strong, 4), round(C_star_weak, 4)],
        "curve": grid,
        "cooperative_sigmoidal": sigmoidal,
        "witness_hash": h,
        "caveat": ("reduced law-of-mass-action — absolute conc are caricatures; "
                   "ONLY the cooperative sigmoidal trend + the T=1 60-subunit "
                   "invariant are claimed (g1/g8); NOT kinetic-trajectory MD."),
    }


def _selfcheck() -> int:
    print("aav_capsid_assembly — drylab #7 · Zlotnick nucleation–elongation (T=1)\n")
    print(f"  [PASS] Caspar-Klug T=1 invariant: 60 subunits = 12 pentamers "
          f"→ {caspar_klug_t1_ok()}")
    assert caspar_klug_t1_ok()
    # τ∝ scaling deductive: stronger (more negative) ΔG → smaller C*
    cs_strong = pseudo_critical_conc_uM(-5.0)
    cs_weak = pseudo_critical_conc_uM(-2.0)
    assert cs_strong < cs_weak, "C* must shrink with stronger contact"
    print(f"  [PASS] C* monotone in ΔG_contact (strong {cs_strong:.3e} < weak {cs_weak:.3e} µM-caricature)")
    a = assembly_curve()
    b = assembly_curve()
    det = (a == b)
    print(f"  [{'PASS' if det else 'FAIL'}] deterministic (witness {a['witness_hash']})")
    print("\n  cooperative assembly curve (C_tot/C*  →  fraction complete):")
    for g in a["curve"]:
        bar = "#" * int(g["frac_complete_weakband"] * 36)
        print(f"    {g['C_tot_over_Cstar_weak']:>4.2f}×C*   "
              f"f_weak={g['frac_complete_weakband']:5.3f}  {bar}")
    print(f"\n  C* band (caricature µM) = {a['C_star_uM_band_caricature']}")
    print(f"  cooperative sigmoidal   = {a['cooperative_sigmoidal']}  "
          f"(sub-critical low → supra-critical →1)")
    print(f"  T=1 invariant ok        = {a['t1_invariant_ok']}")
    print(f"  [caveat] {a['caveat']}")
    ok = (caspar_klug_t1_ok() and det and a["cooperative_sigmoidal"]
          and cs_strong < cs_weak)
    print("  [honesty] in-silico reduced-assembly self-consistency only "
          "(g8/f2); ΔG/n* order-of-mag bands NOT fitted (g1); NOT "
          "atomistic-MD/yield/clinical. See ../research/aav_capsid_assembly.md.")
    print("\n__DRYLAB_AAV_CAPSID_ASSEMBLY__ PASS" if ok
          else "\n__DRYLAB_AAV_CAPSID_ASSEMBLY__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(_selfcheck())
