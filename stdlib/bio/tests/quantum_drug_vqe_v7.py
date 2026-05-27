#!/usr/bin/env python3
"""
quantum_drug_vqe_v7.py — v7 land 2026-05-11.

F-Q-6-B3/B4 smoke: 5 CMT/ALS placeholder SMILES → 2e/2o active-space
Hamiltonian build + StatevectorEstimator V2 VQE (EfficientSU2 depth=1)
→ chem-acc delta vs PySCF CASCI reference.

Pre-computed geometry consumed from tests/smiles_geoms.json
(avoids rdkit + qiskit_nature sshfs shared-lib conflict in same process).

Active space = HOMO + LUMO (2e/2o, frontier). NOT a pocket-restricted
active space — these are full-molecule frontier orbitals. For real drug
target binding, F-Q-6-D ramp needs explicit `active_orbital_indices`
matching the catalytic-residue pocket.

Output: stdout summary + JSON. Numbers feed `.roadmap.novel_drugs §12`.
"""

from __future__ import annotations

import json
import sys
import time

import numpy as np

sys.path.insert(0, "/home/summer/mac_home/core/hexa-bio/_qiskit_bridge/module")

from pocket_active_space import build_active_space_hamiltonian  # noqa: E402

from qiskit.circuit.library import efficient_su2
from qiskit.primitives import StatevectorEstimator
from qiskit.quantum_info import SparsePauliOp
from qiskit_algorithms import VQE
from qiskit_algorithms.optimizers import COBYLA


GEOM_FILE = "tests/smiles_geoms.json"


def load_geoms() -> dict:
    with open(GEOM_FILE) as f:
        return json.load(f)


def to_sparse_op(h: dict) -> SparsePauliOp:
    coeffs = np.array(h["coefficients_real"], dtype=float) + 1j * np.array(
        h["coefficients_imag"], dtype=float
    )
    return SparsePauliOp(h["pauli_strings"], coeffs=coeffs)


def run_vqe(sparse_op, constant_shift: float, *, reps: int = 1, maxiter: int = 400) -> dict:
    nq = sparse_op.num_qubits
    ansatz = efficient_su2(num_qubits=nq, reps=reps, entanglement="full")
    estimator = StatevectorEstimator()
    optimizer = COBYLA(maxiter=maxiter, tol=1e-8)
    rng = np.random.default_rng(7)
    x0 = rng.normal(scale=0.1, size=ansatz.num_parameters)

    history: list[float] = []

    def callback(eval_count, params, energy, meta):
        history.append(float(energy))

    vqe = VQE(estimator=estimator, ansatz=ansatz, optimizer=optimizer,
              initial_point=x0, callback=callback)
    t0 = time.time()
    result = vqe.compute_minimum_eigenvalue(sparse_op)
    wall = time.time() - t0
    e_total = float(result.eigenvalue.real) + constant_shift
    return {
        "n_qubits": nq, "ansatz_params": int(ansatz.num_parameters),
        "iterations": len(history),
        "e_vqe_total_ha": e_total, "wall_sec": round(wall, 2),
    }


def main() -> int:
    geoms = load_geoms()
    print(f"# §12 F-Q-6-B3/B4 drug 2e/2o smoke (v7 land 2026-05-11)\n")
    print(f"loaded {len(geoms)} geometries from {GEOM_FILE}\n")

    results = []
    for name, geom in geoms.items():
        if "error" in geom:
            print(f"  {name}: SKIP (geom error: {geom['error']})")
            continue
        print(f"\n=== {name} ({geom['formula']}, heavy={geom['n_heavy']}) ===")
        t0 = time.time()
        try:
            h = build_active_space_hamiltonian(
                geom["pyscf_atom"], is_smiles=False,
                num_active_electrons=2, num_active_spatial_orbitals=2,
                basis="sto3g",
            )
        except Exception as exc:
            print(f"  BUILD FAIL: {exc}")
            results.append({"id": name, "status": "BUILD-FAIL", "error": str(exc)})
            continue
        t_build = time.time() - t0
        nq = h["n_qubits"]
        casci = h["ref_energy_ha_casci"]
        print(f"  build: n_qubits={nq} n_pauli={len(h['pauli_strings'])} "
              f"CASCI={casci:+.6f} Ha  build_wall={t_build:.1f}s")

        sparse_op = to_sparse_op(h)
        vqe = run_vqe(sparse_op, h["constant_shift_ha"], reps=1, maxiter=400)
        delta_ha = abs(vqe["e_vqe_total_ha"] - casci)
        delta_mha = delta_ha * 1000
        chem_acc = delta_ha < 1.6e-3

        print(f"  VQE = {vqe['e_vqe_total_ha']:+.6f} Ha  "
              f"delta = {delta_mha:.4f} mHa  "
              f"chem-acc = {'PASS' if chem_acc else 'FAIL'}  "
              f"iter = {vqe['iterations']}  wall = {vqe['wall_sec']}s")

        results.append({
            "id": name, "status": "BUILD-PASS" + ("/VQE-PASS" if chem_acc else "/VQE-FAIL"),
            "formula": geom["formula"], "heavy": geom["n_heavy"],
            "n_qubits": nq, "n_pauli": len(h["pauli_strings"]),
            "build_wall_sec": round(t_build, 1),
            "casci_e_tot_ha": casci, "vqe_e_tot_ha": vqe["e_vqe_total_ha"],
            "delta_mha": delta_mha, "chem_acc": chem_acc,
            "iter": vqe["iterations"], "vqe_wall_sec": vqe["wall_sec"],
        })

    print("\n=== JSON ===")
    print(json.dumps(results, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
