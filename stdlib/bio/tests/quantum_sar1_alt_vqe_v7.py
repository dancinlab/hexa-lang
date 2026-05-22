#!/usr/bin/env python3
"""
quantum_sar1_alt_vqe_v7.py — Phase β #2 follow-up (v7 2026-05-11).

sar1-001 IP-회피 대안 SMILES (orig + alt-A/B/C) 4종 → 2e/2o frontier
active-space Hamiltonian + EfficientSU2 depth=1 + COBYLA → CASCI vs VQE
delta. orig 와 비교해 binding-relevant frontier 보존 여부 정성 평가.

geom JSON 소비: tests/sar1_alt_geoms.json (sar1_alt_audit_v7.py 결과).
"""
from __future__ import annotations

import json
import sys
import time

import numpy as np

sys.path.insert(0, "/home/summer/mac_home/core/hexa-bio/_qiskit_bridge/module")

from pocket_active_space import build_active_space_hamiltonian
from qiskit.circuit.library import efficient_su2
from qiskit.primitives import StatevectorEstimator
from qiskit.quantum_info import SparsePauliOp
from qiskit_algorithms import VQE
from qiskit_algorithms.optimizers import COBYLA


GEOM_FILE = "tests/sar1_alt_geoms.json"


def to_sparse_op(h: dict) -> SparsePauliOp:
    coeffs = np.array(h["coefficients_real"]) + 1j * np.array(h["coefficients_imag"])
    return SparsePauliOp(h["pauli_strings"], coeffs=coeffs)


def run_vqe(sparse_op, shift: float, *, reps=1, maxiter=400) -> dict:
    nq = sparse_op.num_qubits
    ansatz = efficient_su2(num_qubits=nq, reps=reps, entanglement="full")
    estimator = StatevectorEstimator()
    optimizer = COBYLA(maxiter=maxiter, tol=1e-8)
    rng = np.random.default_rng(7)
    x0 = rng.normal(scale=0.1, size=ansatz.num_parameters)
    history: list[float] = []

    def cb(eval_count, params, energy, meta):
        history.append(float(energy))

    vqe = VQE(estimator=estimator, ansatz=ansatz, optimizer=optimizer,
              initial_point=x0, callback=cb)
    t0 = time.time()
    result = vqe.compute_minimum_eigenvalue(sparse_op)
    wall = time.time() - t0
    return {
        "n_qubits": nq, "iter": len(history),
        "e_vqe_total_ha": float(result.eigenvalue.real) + shift,
        "wall_sec": round(wall, 2),
    }


def main() -> int:
    with open(GEOM_FILE) as f:
        geoms = json.load(f)

    print("# §12 sar1 IP-회피 대안 4종 frontier 2e/2o VQE\n")
    results = []
    for name, geom in geoms.items():
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
            results.append({"id": name, "error": str(exc), "status": "BUILD-FAIL"})
            continue
        t_build = time.time() - t0
        nq = h["n_qubits"]
        casci = h["ref_energy_ha_casci"]
        print(f"  build wall={t_build:.1f}s  n_qubits={nq}  n_pauli={len(h['pauli_strings'])}  CASCI={casci:+.6f}")

        sparse_op = to_sparse_op(h)
        vqe = run_vqe(sparse_op, h["constant_shift_ha"])
        delta_mha = abs(vqe["e_vqe_total_ha"] - casci) * 1000
        delta_uha = delta_mha * 1000
        chem_acc = delta_mha < 1.6
        print(f"  VQE={vqe['e_vqe_total_ha']:+.6f}  delta={delta_mha:.4f} mHa ({delta_uha:.2f} µHa)  "
              f"chem-acc={'PASS' if chem_acc else 'FAIL'}  iter={vqe['iter']}  wall={vqe['wall_sec']}s")
        results.append({
            "id": name, "smiles": geom["smiles"], "formula": geom["formula"], "heavy": geom["n_heavy"],
            "n_qubits": nq, "n_pauli": len(h["pauli_strings"]),
            "build_wall_sec": round(t_build, 1),
            "casci": casci, "vqe": vqe["e_vqe_total_ha"],
            "delta_mha": delta_mha, "delta_uha": delta_uha,
            "chem_acc": chem_acc, "iter": vqe["iter"], "vqe_wall_sec": vqe["wall_sec"],
        })

    print("\n=== JSON ===")
    print(json.dumps(results, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
