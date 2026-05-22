#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
quantum_h2_scan.py — Phase B2: H2 bond-length scan for the qpu_bridge bio
integration. Reproduces the H2 / STO-3G / FCI dissociation curve via VQE
at multiple R values. Uses pyscf for the FCI reference per R, vqe_general
for the VQE estimate, and reports delta(VQE - FCI) per point.

Phase B1 closed F-Q-2 (LiH chemical accuracy 1.408 mHa). Phase B2 (F-Q-3)
closes when VQE reproduces the H2 dissociation curve within chemical
accuracy at every R, with the equilibrium bond length R_eq predicted
within ±0.05 Å.

Public API
==========

    scan_h2(r_values, *, depth=1, max_iter=200, seed=42, use_pool=True)
        -> list[dict]

        For each R in r_values: build the H2 Hamiltonian at that R,
        compute FCI ground state via pyscf, run vqe_general, and record
        (R, E_VQE, E_FCI, delta_mHa, n_iter, converged, wall).

CLI usage
=========

    python3 quantum_h2_scan.py --r-list 0.4,0.5,0.6,0.74,0.9,1.0,1.2,1.5,1.8,2.0,2.5

Honest caveats
==============

1. FCI in STO-3G is exact within that basis but not in real life — STO-3G
   is a minimal basis. Larger basis sets (cc-pVDZ etc) shift the curve
   and require more qubits — out of B2 scope.
2. R_eq prediction precision is limited by R-grid resolution. The
   default 11-point grid gives R_eq ± 0.05 Å. A finer grid + spline
   interpolation could improve, but adds wall.
3. For very large R (> 2.0 Å) the parity-mapped 2-qubit Hamiltonian
   handles dissociation but the 4-param ansatz may need depth=2 to
   represent the open-shell limit accurately.
4. VQE per-point seeded by seed=42 (deterministic). For statistical
   bands use multi-restart per R (sweep) — separate cycle.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from typing import List, Optional, Sequence

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def _fci_energy_h2(r_angstrom: float) -> float:
    """FCI/STO-3G ground state for H2 at bond length R."""
    from pyscf import gto, scf, fci
    mol = gto.M(atom=f"H 0 0 0; H 0 0 {r_angstrom}", basis="sto-3g", verbose=0)
    mf = scf.RHF(mol)
    mf.verbose = 0
    mf.run()
    e_fci, _ = fci.FCI(mf).kernel()
    return float(e_fci)


def scan_h2(
    r_values: Sequence[float],
    *,
    depth: int = 1,
    max_iter: int = 200,
    seed: int = 42,
    use_pool: bool = True,
) -> List[dict]:
    from quantum_h_molecule import build_hamiltonian
    from quantum_vqe_general import vqe_general

    out: List[dict] = []
    for r in r_values:
        # FCI reference (exact for STO-3G).
        e_fci = _fci_energy_h2(r)

        # VQE estimate.
        h = build_hamiltonian("h2", r_angstrom=r)
        # Override the cached ref to the just-computed FCI value.
        h["ref_energy_ha_fci"] = e_fci

        t0 = time.time()
        res = vqe_general(
            h,
            seed=seed,
            max_iter=max_iter,
            depth=depth,
            use_pool=use_pool,
        )
        wall = time.time() - t0

        e_vqe = res["energy_Ha"]
        delta_mHa = (e_vqe - e_fci) * 1e3
        out.append({
            "r_angstrom": r,
            "e_fci_ha": e_fci,
            "e_vqe_ha": e_vqe,
            "delta_mHa": delta_mHa,
            "n_iter": res["n_iter"],
            "converged": res["converged"],
            "wall_seconds": wall,
            "n_pauli": res["n_pauli_terms"],
            "n_qubits": res["n_qubits"],
            "depth": res["depth"],
        })
    return out


def _emit_curve(results: List[dict]) -> None:
    print()
    print(f"{'R(Å)':>6}  {'E_FCI(Ha)':>13}  {'E_VQE(Ha)':>13}  {'Δ(mHa)':>10}  {'iter':>5}  {'conv':>5}  {'wall(s)':>7}")
    print("─" * 78)
    for r in results:
        flag = "*" if abs(r["delta_mHa"]) <= 1.6 else " "
        print(f"{r['r_angstrom']:>6.3f}  {r['e_fci_ha']:>+13.7f}  "
              f"{r['e_vqe_ha']:>+13.7f}  {r['delta_mHa']:>+9.4f}{flag} "
              f"{r['n_iter']:>5}  {str(r['converged']):>5}  {r['wall_seconds']:>7.2f}")
    print("─" * 78)
    e_fci_min_idx = min(range(len(results)), key=lambda i: results[i]["e_fci_ha"])
    e_vqe_min_idx = min(range(len(results)), key=lambda i: results[i]["e_vqe_ha"])
    print(f"R_eq (FCI) = {results[e_fci_min_idx]['r_angstrom']:.3f} Å  "
          f"E_min(FCI) = {results[e_fci_min_idx]['e_fci_ha']:+.7f} Ha")
    print(f"R_eq (VQE) = {results[e_vqe_min_idx]['r_angstrom']:.3f} Å  "
          f"E_min(VQE) = {results[e_vqe_min_idx]['e_vqe_ha']:+.7f} Ha")
    deltas = [r["delta_mHa"] for r in results]
    in_chem_acc = sum(1 for d in deltas if abs(d) <= 1.6)
    print(f"Chemical accuracy: {in_chem_acc}/{len(deltas)} points within 1.6 mHa")
    print(f"Max |Δ|: {max(abs(d) for d in deltas):.4f} mHa  "
          f"Mean |Δ|: {sum(abs(d) for d in deltas)/len(deltas):.4f} mHa")


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="quantum_h2_scan.py")
    p.add_argument("--r-list", type=str,
                   default="0.4,0.5,0.6,0.74,0.9,1.0,1.2,1.5,1.8,2.0,2.5")
    p.add_argument("--depth", type=int, default=1)
    p.add_argument("--max-iter", type=int, default=200)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--no-pool", dest="use_pool", action="store_false")
    p.set_defaults(use_pool=True)
    args = p.parse_args(argv)

    r_values = [float(x.strip()) for x in args.r_list.split(",")]
    results = scan_h2(
        r_values,
        depth=args.depth,
        max_iter=args.max_iter,
        seed=args.seed,
        use_pool=args.use_pool,
    )
    _emit_curve(results)
    print()
    print(json.dumps({"results": results}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
