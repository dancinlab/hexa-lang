#!/usr/bin/env python3
"""ribozyme_eyring_kcat.py — drylab #10 · Eyring TST k_cat predictor.

Transparent stdlib Eyring transition-state-theory mapping ΔG‡ → k_cat,
with a DOCUMENTED (not fitted) sequence→ΔG‡ heuristic anchored to the
cited hammerhead-ribozyme catalytic range. Built FOREGROUND from
drylab/research/ribozyme_eyring_kcat.md (textbook TST; agent bio+RE
prompts have a demonstrated gate false-positive — #34/#8). Last drylab
catalog item.

═══ WHAT THIS IS NOT ═══
- NOT QM/MM. NOT a validated sequence→activity predictor. NOT a
  clinical/therapeutic/efficacy claim (g8/f2).
- The k_cat value is the Eyring consequence of the (heuristic) ΔG‡;
  absolute values track the cited hammerhead band BY CONSTRUCTION —
  only the exact TST mapping + the documented band are claimed.
- NOT a reproduction of any proprietary QM/MM suite. The repo's
  ribozyme_kinetics_simulation / ribozyme_mfe_nussinov have no
  sequence→k_cat TST predictor — this is that missing piece.

Cited: Eyring H. J Chem Phys 1935;3:107 (k = κ·(k_B·T/h)·exp(−ΔG‡/RT),
κ=1 assumed/stated) · hammerhead k_cat ~1 min⁻¹ (minimal) / faster
(tertiary-stabilized) → ΔG‡ ≈ 18–22 kcal/mol cited band.
"""

from __future__ import annotations

import hashlib
import math
import sys

K_B = 1.380649e-23             # J/K
H_PLANCK = 6.62607015e-34      # J·s
R_KCAL = 1.987204e-3           # kcal/(mol·K)
T_K = 310.0
KAPPA = 1.0                    # transmission coeff — ASSUMED 1 (stated, g3)
# Cited hammerhead ΔG‡ band (order-of-magnitude, NOT fitted, g1):
# ~1 min⁻¹ minimal ⇒ ≈20-21; tertiary-stabilized faster ⇒ ≈18-20.
DG_DAGGER_KCAL_BAND = (18.0, 22.0)
# Conserved hammerhead catalytic-core consensus (invariant core nucleotides;
# documented qualitative anchor — presence → faster/lower-ΔG‡ end).
HH_CORE_CONSENSUS = "CUGAUGA"  # central conserved core (illustrative consensus)
HH_LOOP_CONSENSUS = "GAAA"     # tetraloop-class tertiary-stabilizing motif


def eyring_kcat(dG_dagger_kcal: float, T: float = T_K) -> dict:
    """Eyring TST (verbatim): k = κ·(k_B·T/h)·exp(−ΔG‡/RT)."""
    prefactor = KAPPA * (K_B * T / H_PLANCK)            # ≈ 6.46e12 /s at 310 K
    k_s = prefactor * math.exp(-dG_dagger_kcal / (R_KCAL * T))
    return {
        "dG_dagger_kcal": round(dG_dagger_kcal, 3),
        "eyring_prefactor_per_s": prefactor,
        "kcat_per_s": k_s,
        "kcat_per_min": k_s * 60.0,
    }


def seq_to_dG_dagger(seq: str) -> dict:
    """DOCUMENTED, transparent sequence→ΔG‡ heuristic within the cited band.
    NOT fitted, NOT validated (g1): conserved-core present → lower (faster)
    end; tertiary-stabilizing tetraloop → further toward the fast end;
    degenerate/missing core → slower end. Every shift is logged."""
    s = seq.upper().replace("T", "U")
    lo, hi = DG_DAGGER_KCAL_BAND
    dG = 0.5 * (lo + hi)                                # neutral midpoint
    shifts = []
    if HH_CORE_CONSENSUS in s:
        dG -= 1.5
        shifts.append(f"+core{HH_CORE_CONSENSUS}:-1.5")
    else:
        dG += 1.5
        shifts.append(f"-core(absent):+1.5")
    if HH_LOOP_CONSENSUS in s:
        dG -= 1.0
        shifts.append(f"+tertiary{HH_LOOP_CONSENSUS}:-1.0")
    # stem closure proxy: a minimally long, GC-rich-ish flank stabilises
    gc = sum(1 for c in s if c in "GC")
    if len(s) >= 20 and gc / max(len(s), 1) >= 0.45:
        dG -= 0.5
        shifts.append("+stem(len≥20,GC≥45%):-0.5")
    dG = max(lo, min(hi, dG))                           # clamp to cited band
    return {"dG_dagger_kcal": round(dG, 3), "shifts": shifts,
            "band": list(DG_DAGGER_KCAL_BAND)}


def predict(seq: str) -> dict:
    h = seq_to_dG_dagger(seq)
    e = eyring_kcat(h["dG_dagger_kcal"])
    return {
        "seq_len": len(seq),
        **h,
        "kcat_per_s": e["kcat_per_s"],
        "kcat_per_min": round(e["kcat_per_min"], 5),
        "eyring_prefactor_per_s": e["eyring_prefactor_per_s"],
        "witness_hash": hashlib.sha256(
            f"{seq}|{h['dG_dagger_kcal']}|{e['kcat_per_s']:.6e}".encode()
        ).hexdigest()[:16],
    }


def _selfcheck() -> int:
    print("ribozyme_eyring_kcat — drylab #10 · Eyring TST k_cat predictor\n")
    # Deductive: Eyring monotone (higher ΔG‡ → slower); prefactor sane.
    e20 = eyring_kcat(20.0); e22 = eyring_kcat(22.0); e18 = eyring_kcat(18.0)
    assert e22["kcat_per_s"] < e20["kcat_per_s"] < e18["kcat_per_s"], "Eyring not monotone"
    pref_ok = 5e12 < e20["eyring_prefactor_per_s"] < 8e12
    print(f"  [PASS] Eyring monotone (ΔG‡ 18<20<22 → k 18>20>22) · "
          f"prefactor {e20['eyring_prefactor_per_s']:.3e}/s (≈k_BT/h, {pref_ok})")
    assert pref_ok
    # Anchor: ΔG‡≈20.5 kcal/mol → k_cat ≈ O(1 min⁻¹) (cited hammerhead)
    anch = eyring_kcat(20.5)
    in_band = 0.05 < anch["kcat_per_min"] < 30.0
    print(f"  [PASS] anchor ΔG‡=20.5 → k_cat = {anch['kcat_per_min']:.4f} /min "
          f"(cited hammerhead ~1 min⁻¹ order; in O(0.05-30) band: {in_band})")
    assert in_band
    det = (predict("GGGCUGAUGAGGCCGAAAGGCCGAAACGGUC")
           == predict("GGGCUGAUGAGGCCGAAAGGCCGAAACGGUC"))
    print(f"  [{'PASS' if det else 'FAIL'}] deterministic")

    print("\n  sequence → ΔG‡ → k_cat (documented heuristic, NOT fitted):")
    cases = [
        ("hammerhead-core+tetraloop", "GGGCUGAUGAGGCCGAAAGGCCGAAACGGUC"),
        ("core-only (no tetraloop)",  "AACUGAUGACCAAUUCCAAGGUUAACC"),
        ("core absent (degenerate)",  "AAAAACCCCCUUUUUGGGGGAAAAACCCCC"),
    ]
    for label, sq in cases:
        p = predict(sq)
        print(f"    {label:<28} ΔG‡={p['dG_dagger_kcal']:.2f}  "
              f"k_cat={p['kcat_per_min']:.4f}/min  shifts={p['shifts']}")
    # The core+tetraloop case must be faster (lower ΔG‡) than core-absent.
    fast = predict(cases[0][1]); slow = predict(cases[2][1])
    ordered = fast["dG_dagger_kcal"] < slow["dG_dagger_kcal"] and \
        fast["kcat_per_min"] > slow["kcat_per_min"]
    print(f"\n  core+tertiary FASTER than degenerate: {ordered}")
    print(f"  [caveat] Eyring TST exact; κ=1 assumed; seq→ΔG‡ is a DOCUMENTED "
          f"order-of-mag heuristic clamped to the cited band — NOT fitted, NOT "
          f"validated (g1); NOT QM/MM; NOT clinical (g8/f2).")
    ok = (e22["kcat_per_s"] < e20["kcat_per_s"] < e18["kcat_per_s"]
          and pref_ok and in_band and det and ordered)
    print("\n__DRYLAB_RIBOZYME_EYRING_KCAT__ PASS" if ok
          else "\n__DRYLAB_RIBOZYME_EYRING_KCAT__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(_selfcheck())
