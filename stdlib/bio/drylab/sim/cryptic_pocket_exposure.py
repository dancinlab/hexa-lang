#!/usr/bin/env python3
"""cryptic_pocket_exposure.py — drylab · scissile-site exposure vs unfolding.

Function-level, transparent, stdlib scorer of how the vWF A2 ADAMTS13
scissile bond (Tyr1605-Met1606) — a textbook FORCE-EXPOSED CRYPTIC SITE
(buried folded, exposed only under mechanical unfolding; Zhang X 2009
Science 324:1330) — changes solvent exposure ALONG an unfolding reaction
coordinate. Built from the committed spec drylab/research/
cryptic_pocket_exposure.md (RE-wave2, commit 806e49e).

═══ WHAT THIS IS NOT (verbatim from the spec §what-this-is-NOT) ═══
- NOT a clone/reconstruction of any proprietary platform. Relay Dynamo,
  OpenEye Orion Cryptic Pocket Detection, Redesign Science are described
  ONLY by their own public claims; their sampling generators, reaction
  coordinates and ML scoring are undisclosed and are NOT used, inferred,
  approximated, or reverse-engineered (g3).
- NOT an atomic SASA. The estimator runs on Cα coarse-grained beads, not
  atoms. Absolute Å² values are model-dependent caricatures; ONLY the
  relative buried→exposed trend vs the reaction coordinate Q is the claim.
- NOT a druggability/binding prediction. Geometric exposure only — NO
  ligandability, binding free energy, efficacy, or clinical claim (g8/f2).
- NOT a pocket-finding search. The cryptic site is ALREADY known
  (Tyr1605-Met1606, Zhang 2009); this measures exposure of a known site.
- NOT a new ensemble. It strictly CONSUMES the drylab #1 a2_cg_unfolding
  open CG ensemble interface; it generates no trajectory and fabricates
  no atomic structure. (Here #1's sim/.py is not yet merged, so the
  selftest uses a clearly-labelled SYNTHETIC fixture conforming to the
  #1 interface — NOT real A2 coordinates.)

Open methodology only: Shrake & Rupley 1973 JMB 79:351 (sphere-point SASA)
· Lee & Richards 1971 JMB 55:379 (rolling-probe concept) · Tien 2013 PLoS
ONE 8:e80635 (RSA-normaliser CONCEPT only — NOT applied as an atomic
MaxASA to CG beads; the normaliser here is the ensemble's own unfolded-max,
self-consistent and explicit). Real-limit anchor: Zhang X 2009 Science
324:1330 (PMC2753189) — scissile Tyr1605-Met1606 force-exposed cryptic
site; Zhang Q 2009 PNAS 106:9226 (PMC2695068) — A2 ≈177 aa, β4 strand.

CG-resolution limit is LOAD-BEARING and explicit (per spec §honesty-caveat).
"""

from __future__ import annotations

import hashlib
import math
import sys

PROBE_RADIUS_A = 1.4          # water (Lee-Richards / Shrake-Rupley default)
BEAD_RADIUS_A = 4.0           # Cα effective CG radius — model choice, NOT an atom
N_SPHERE_POINTS = 192         # deterministic golden-spiral mesh (spec default 256)
SCISSILE_P1_RESNUM = 1605     # Tyr1605 (a2_residue_orbital_selector convention)
SCISSILE_P1PRIME_RESNUM = 1606  # Met1606
A2_FIRST_RESNUM = 1495        # Met1495 (Zhang Q 2009 numbering)
A2_LAST_RESNUM = 1671         # Ser1671 → N = 177 beads


def fibonacci_sphere(n: int) -> list:
    """Deterministic golden-angle unit-sphere point set (no RNG)."""
    pts = []
    ga = math.pi * (3.0 - math.sqrt(5.0))      # golden angle
    for i in range(n):
        y = 1.0 - 2.0 * (i + 0.5) / n
        r = math.sqrt(max(0.0, 1.0 - y * y))
        t = ga * i
        pts.append((math.cos(t) * r, y, math.sin(t) * r))
    return pts


def _synthetic_a2_cg_ensemble(n_frames: int = 9) -> list:
    """SYNTHETIC TEST FIXTURE — NOT real A2 coordinates.

    Conforms to the drylab #1 a2_cg_unfolding ensemble interface:
    frames = [{ 'Q', 'extension', 'applied_force', 'R': {resnum:(x,y,z)} }].
    Folded frames pack the chain into a compact globule (scissile beads
    surrounded → buried); unfolded frames extend it along x (scissile
    beads solvent-facing → exposed). Intermediates interpolate. This
    exercises the estimator; it asserts NOTHING about real A2 geometry.
    """
    resnums = list(range(A2_FIRST_RESNUM, A2_LAST_RESNUM + 1))
    n = len(resnums)
    frames = []
    for f in range(n_frames):
        Q = 1.0 - f / (n_frames - 1)                  # 1.0 folded → 0.0 unfolded
        ext = 2.0 + Q * 0.0 + (1.0 - Q) * 55.0        # nm-ish, monotone in unfold
        R = {}
        for idx, rn in enumerate(resnums):
            s = idx / (n - 1)
            # Folded: tight 3-period helix-ish globule (radius ~ a few beads).
            fold_r = 9.0
            fx = fold_r * math.cos(2.0 * math.pi * 3.0 * s)
            fy = fold_r * math.sin(2.0 * math.pi * 3.0 * s)
            fz = (s - 0.5) * 12.0
            # Unfolded: near-linear extended chain along x (3.5 Å/bead spacing).
            ux = idx * 7.0 - (n - 1) * 3.5
            uy = 0.6 * math.sin(idx * 0.7)            # tiny ripple, mostly solvent
            uz = 0.6 * math.cos(idx * 0.7)
            R[rn] = (fx * Q + ux * (1.0 - Q),
                     fy * Q + uy * (1.0 - Q),
                     fz * Q + uz * (1.0 - Q))
        frames.append({"Q": Q, "extension": ext,
                       "applied_force": 8.75 * (1.0 - Q),  # pN-ish ramp
                       "R": R, "synthetic_fixture": True})
    return frames


def _cg_sasa(R: dict, target: int, others: list) -> float:
    """Shrake-Rupley-style CG-SASA (caricature units) for one bead."""
    cx, cy, cz = R[target]
    reach = BEAD_RADIUS_A + PROBE_RADIUS_A
    occ2 = reach * reach
    mesh = fibonacci_sphere(N_SPHERE_POINTS)
    acc = 0
    for px, py, pz in mesh:
        x, y, z = cx + reach * px, cy + reach * py, cz + reach * pz
        blocked = False
        for j in others:
            jx, jy, jz = R[j]
            dx, dy, dz = x - jx, y - jy, z - jz
            if dx * dx + dy * dy + dz * dz < occ2:
                blocked = True
                break
        if not blocked:
            acc += 1
    return (acc / N_SPHERE_POINTS) * (4.0 * math.pi * reach * reach)


def exposure_curve(ensemble: list,
                    scissile=(SCISSILE_P1_RESNUM, SCISSILE_P1PRIME_RESNUM)) -> dict:
    """Per-frame mean scissile CG-RSA vs reaction coordinate Q."""
    raw = {s: [] for s in scissile}
    Qs, exts = [], []
    for fr in ensemble:
        R = fr["R"]
        all_res = list(R.keys())
        Qs.append(fr["Q"])
        exts.append(fr["extension"])
        for s in scissile:
            others = [j for j in all_res if j != s]
            raw[s].append(_cg_sasa(R, s, others))
    # Per-bead normaliser = max CG-SASA over the fully-unfolded frames of
    # THIS ensemble (self-consistent; explicitly NOT a Tien atomic MaxASA).
    unfolded_idx = [i for i, q in enumerate(Qs) if q <= 0.15] or [len(Qs) - 1]
    curve = []
    for i, q in enumerate(Qs):
        rsas = []
        for s in scissile:
            ref = max(raw[s][k] for k in unfolded_idx) or 1.0
            rsas.append(raw[s][i] / ref)
        curve.append((q, sum(rsas) / len(rsas)))
    folded_end = min(curve, key=lambda c: -c[0])[1]      # at max Q (most folded)
    unfolded_end = min(curve, key=lambda c: c[0])[1]      # at min Q (most unfolded)
    lo, hi = min(folded_end, unfolded_end), max(folded_end, unfolded_end)
    mid = 0.5 * (lo + hi)
    # transition-midpoint Q: first frame (folded→unfolded order) crossing mid
    ordered = sorted(curve, key=lambda c: -c[0])
    trans_Q = ordered[-1][0]
    for q, r in ordered:
        if r >= mid:
            trans_Q = q
            break
    rsa_seq = [r for _, r in ordered]
    monotone = all(rsa_seq[i] <= rsa_seq[i + 1] + 1e-9
                    for i in range(len(rsa_seq) - 1))
    h = hashlib.sha256(repr([(round(q, 6), round(r, 6))
                             for q, r in curve]).encode()).hexdigest()[:16]
    return {
        "curve_Q_to_meanRSA": curve,
        "folded_end_RSA": round(folded_end, 4),
        "unfolded_end_RSA": round(unfolded_end, 4),
        "transition_midpoint_Q": round(trans_Q, 4),
        "monotone_buried_to_exposed": monotone,
        "scissile_residues": list(scissile),
        "probe_radius_A": PROBE_RADIUS_A,
        "bead_radius_A": BEAD_RADIUS_A,
        "n_sphere_points": N_SPHERE_POINTS,
        "witness_hash": h,
        "cg_resolution_caveat": ("Cα coarse-grained beads, NOT atoms; absolute "
                                 "Å² are caricatures — only the relative "
                                 "buried→exposed trend vs Q is claimed (g3/g8)."),
    }


def _selfcheck() -> int:
    print("cryptic_pocket_exposure — drylab · scissile-site exposure vs Q\n")
    sph = fibonacci_sphere(64)
    norm_ok = all(abs(math.sqrt(x * x + y * y + z * z) - 1.0) < 1e-9
                  for x, y, z in sph)
    print(f"  [PASS] fibonacci_sphere unit-norm (64 pts): {norm_ok}")
    assert norm_ok

    ens = _synthetic_a2_cg_ensemble()
    assert all(fr.get("synthetic_fixture") for fr in ens), "fixture must self-label"
    print(f"  [PASS] synthetic fixture labelled (NOT real A2); "
          f"{len(ens)} frames, Q {ens[0]['Q']:.2f}→{ens[-1]['Q']:.2f}")

    r1 = exposure_curve(ens)
    r2 = exposure_curve(ens)
    det = (r1 == r2)
    print(f"  [{'PASS' if det else 'FAIL'}] deterministic (witness "
          f"{r1['witness_hash']} == {r2['witness_hash']})")

    g = r1
    print(f"\n  exposure curve (Q → mean scissile CG-RSA):")
    for q, rsa in sorted(g["curve_Q_to_meanRSA"], key=lambda c: -c[0]):
        bar = "#" * int(rsa * 40)
        print(f"    Q={q:4.2f}  RSA={rsa:5.3f}  {bar}")
    print(f"\n  folded-end RSA   = {g['folded_end_RSA']}  (Q≈1, should be BURIED/low)")
    print(f"  unfolded-end RSA = {g['unfolded_end_RSA']}  (Q≈0, should be EXPOSED/high)")
    print(f"  transition-midpoint Q = {g['transition_midpoint_Q']}")
    print(f"  monotone buried→exposed = {g['monotone_buried_to_exposed']}")
    print(f"  witness = {g['witness_hash']}")
    print(f"  [caveat] {g['cg_resolution_caveat']}")

    # Acceptance gate (g1 — anchored to Zhang-2009 force-exposed-cryptic-site
    # reality, NOT the lattice): folded buried < unfolded exposed, with a
    # clear separation, and the trend monotone buried→exposed.
    buried_lt_exposed = g["folded_end_RSA"] < g["unfolded_end_RSA"] - 0.15
    folded_is_buried = g["folded_end_RSA"] < 0.5
    unfolded_is_exposed = g["unfolded_end_RSA"] > 0.7
    ok = (norm_ok and det and buried_lt_exposed and folded_is_buried
          and unfolded_is_exposed and g["monotone_buried_to_exposed"])
    print(f"\n  gate: folded buried(<0.5)={folded_is_buried} · "
          f"unfolded exposed(>0.7)={unfolded_is_exposed} · "
          f"separation(>0.15)={buried_lt_exposed} · monotone="
          f"{g['monotone_buried_to_exposed']}")
    print("  [honesty] in-silico CG topology-exposure consistency only "
          "(g8/f2); NOT atomic SASA, NOT druggability, NOT a proprietary "
          "reproduction. See ../research/cryptic_pocket_exposure.md.")
    print("\n__DRYLAB_CRYPTIC_POCKET_EXPOSURE__ PASS" if ok
          else "\n__DRYLAB_CRYPTIC_POCKET_EXPOSURE__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(_selfcheck())
