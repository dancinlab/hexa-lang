#!/usr/bin/env python3
"""
quantum_h2o_vqe_v7.py — v7 land 2026-05-11.

F-Q-6-B sub-falsifier: H2O 2e/2o active-space Hamiltonian build +
StatevectorEstimator V2 VQE (EfficientSU2 depth=1) → chem-acc delta vs
PySCF CASCI reference.

bypass rdkit: pyscf_atom geometry direct (sshfs shared-lib loading flaky
when combined with qiskit_nature in same process).

Output: stdout JSON + markdown excerpt for `.roadmap.novel_drugs §12`.
"""

from __future__ import annotations

import json
import sys
import time

import numpy as np

sys.path.insert(0, "/home/summer/mac_home/core/hexa-bio/_qiskit_bridge/module")

from pocket_active_space import build_active_space_hamiltonian  # noqa: E402

from qiskit.circuit.library import efficient_su2  # function form (Qiskit 2.1+)
from qiskit.primitives import StatevectorEstimator
from qiskit.quantum_info import SparsePauliOp
from qiskit_algorithms import VQE
from qiskit_algorithms.optimizers import COBYLA, SLSQP


# H2O canonical experimental geometry (Å), C2v
H2O_GEOM = (
    "O 0.000000 0.000000 0.000000; "
    "H 0.000000 0.756950 -0.585882; "
    "H 0.000000 -0.756950 -0.585882"
)


def build_h2o_hamiltonian(nelecas: int, ncas: int) -> dict:
    return build_active_space_hamiltonian(
        H2O_GEOM,
        is_smiles=False,
        num_active_electrons=nelecas,
        num_active_spatial_orbitals=ncas,
        basis="sto3g",
    )


def to_sparse_op(h: dict) -> SparsePauliOp:
    coeffs = np.array(h["coefficients_real"], dtype=float) + 1j * np.array(
        h["coefficients_imag"], dtype=float
    )
    return SparsePauliOp(h["pauli_strings"], coeffs=coeffs)


def run_vqe(
    sparse_op: SparsePauliOp, constant_shift: float, *, reps: int = 1, maxiter: int = 400
) -> dict:
    nq = sparse_op.num_qubits
    ansatz = efficient_su2(num_qubits=nq, reps=reps, entanglement="full")
    estimator = StatevectorEstimator()
    optimizer = COBYLA(maxiter=maxiter, tol=1e-8)

    rng = np.random.default_rng(7)
    x0 = rng.normal(scale=0.1, size=ansatz.num_parameters)

    history: list[float] = []

    def callback(eval_count, params, energy, meta):
        history.append(float(energy))

    vqe = VQE(
        estimator=estimator,
        ansatz=ansatz,
        optimizer=optimizer,
        initial_point=x0,
        callback=callback,
    )
    t0 = time.time()
    result = vqe.compute_minimum_eigenvalue(sparse_op)
    wall = time.time() - t0
    e_vqe = float(result.eigenvalue.real) + constant_shift
    return {
        "n_qubits": nq,
        "ansatz_params": int(ansatz.num_parameters),
        "ansatz_reps": reps,
        "optimizer": "COBYLA",
        "maxiter": maxiter,
        "iterations": len(history),
        "e_vqe_active": float(result.eigenvalue.real),
        "constant_shift_ha": constant_shift,
        "e_vqe_total_ha": e_vqe,
        "wall_sec": round(wall, 2),
        "final_iter_energies": [round(e, 8) for e in history[-3:]],
    }


def main() -> int:
    results: list[dict] = []

    cases = [(2, 2, "F-Q-6-B1 H2O 2e/2o"), (4, 4, "F-Q-6-B2 H2O 4e/4o")]
    for nelecas, ncas, label in cases:
        print(f"\n=== {label} ===")
        h = build_h2o_hamiltonian(nelecas, ncas)
        sparse_op = to_sparse_op(h)
        casci = h["ref_energy_ha_casci"]
        shift = h["constant_shift_ha"]
        print(f"  n_qubits={h['n_qubits']}  n_pauli={len(h['pauli_strings'])}  CASCI={casci:+.8f} Ha")

        vqe = run_vqe(sparse_op, shift, reps=1, maxiter=400)
        delta_ha = abs(vqe["e_vqe_total_ha"] - casci)
        delta_mha = delta_ha * 1000
        delta_uha = delta_ha * 1e6
        chem_acc_pass = delta_ha < 1.6e-3  # 1.6 mHa = chemical accuracy threshold
        sub_uha_pass = delta_uha < 1.0

        vqe["e_casci_total_ha"] = casci
        vqe["delta_ha"] = delta_ha
        vqe["delta_mha"] = delta_mha
        vqe["delta_uha"] = delta_uha
        vqe["chem_acc_pass"] = chem_acc_pass
        vqe["sub_uha_pass"] = sub_uha_pass
        vqe["label"] = label
        vqe["nelecas"] = nelecas
        vqe["ncas"] = ncas
        results.append(vqe)

        print(f"  VQE={vqe['e_vqe_total_ha']:+.8f} Ha  "
              f"delta={delta_mha:.4f} mHa  ({delta_uha:.2f} µHa)  "
              f"chem-acc={'PASS' if chem_acc_pass else 'FAIL'}  "
              f"sub-µHa={'PASS' if sub_uha_pass else 'FAIL'}  "
              f"iter={vqe['iterations']}  wall={vqe['wall_sec']}s")

    print("\n=== JSON summary ===")
    print(json.dumps(results, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
