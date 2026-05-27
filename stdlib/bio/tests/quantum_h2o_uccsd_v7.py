#!/usr/bin/env python3
"""
quantum_h2o_uccsd_v7.py — Phase β #1 (v7 follow-up 2026-05-11).

F-Q-6-B2 closure: H2O 4e/4o UCCSD ansatz + ParityMapper VQE → chem-acc
PASS 목표. (EfficientSU2 depth=1 + COBYLA 400 iter 으로 8.36 mHa 미응축 →
UCCSD 으로 chem-acc 도달 검증).

bypass rdkit: pyscf_atom geometry direct.
"""
from __future__ import annotations

import json
import sys
import time

import numpy as np

sys.path.insert(0, "/home/summer/mac_home/core/hexa-bio/_qiskit_bridge/module")

from qiskit_nature.second_q.drivers import PySCFDriver
from qiskit_nature.second_q.mappers import ParityMapper
from qiskit_nature.second_q.transformers import ActiveSpaceTransformer
from qiskit_nature.second_q.circuit.library import UCCSD, HartreeFock

from qiskit.primitives import StatevectorEstimator
from qiskit.quantum_info import SparsePauliOp
from qiskit_algorithms import VQE
from qiskit_algorithms.optimizers import COBYLA, SLSQP, L_BFGS_B


H2O_GEOM = (
    "O 0.000000 0.000000 0.000000; "
    "H 0.000000 0.756950 -0.585882; "
    "H 0.000000 -0.756950 -0.585882"
)


def build_h2o_4e4o():
    driver = PySCFDriver(atom=H2O_GEOM, basis="sto3g", charge=0, spin=0)
    problem_full = driver.run()
    ast = ActiveSpaceTransformer(num_electrons=4, num_spatial_orbitals=4)
    active_problem = ast.transform(problem_full)
    mapper = ParityMapper(num_particles=active_problem.num_particles)
    sparse_op = mapper.map(active_problem.hamiltonian.second_q_op())
    constant_shift = float(sum(active_problem.hamiltonian.constants.values()))

    hf_state = HartreeFock(
        num_spatial_orbitals=4,
        num_particles=active_problem.num_particles,
        qubit_mapper=mapper,
    )
    ucc = UCCSD(
        num_spatial_orbitals=4,
        num_particles=active_problem.num_particles,
        qubit_mapper=mapper,
        initial_state=hf_state,
        reps=1,
    )
    return {
        "sparse_op": sparse_op,
        "constant_shift": constant_shift,
        "ansatz": ucc,
        "num_particles": active_problem.num_particles,
        "problem_full": problem_full,
    }


def casci_reference():
    from pyscf import gto, scf, mcscf
    mol = gto.M(atom=H2O_GEOM, basis="sto3g", charge=0, spin=0, verbose=0)
    mf = scf.RHF(mol).run()
    casci = mcscf.CASCI(mf, ncas=4, nelecas=4)
    casci.verbose = 0
    casci.kernel()
    return float(casci.e_tot)


def run_vqe(sparse_op, ansatz, shift: float, optimizer_name: str, maxiter: int) -> dict:
    if optimizer_name == "COBYLA":
        opt = COBYLA(maxiter=maxiter, tol=1e-8)
    elif optimizer_name == "SLSQP":
        opt = SLSQP(maxiter=maxiter)
    elif optimizer_name == "L_BFGS_B":
        opt = L_BFGS_B(maxiter=maxiter)
    else:
        raise ValueError(optimizer_name)

    estimator = StatevectorEstimator()
    rng = np.random.default_rng(7)
    x0 = rng.normal(scale=0.05, size=ansatz.num_parameters)

    history: list[float] = []

    def callback(eval_count, params, energy, meta):
        history.append(float(energy))

    vqe = VQE(estimator=estimator, ansatz=ansatz, optimizer=opt, initial_point=x0,
              callback=callback)
    t0 = time.time()
    result = vqe.compute_minimum_eigenvalue(sparse_op)
    wall = time.time() - t0
    return {
        "optimizer": optimizer_name,
        "maxiter": maxiter,
        "iterations": len(history),
        "params": int(ansatz.num_parameters),
        "e_vqe_active": float(result.eigenvalue.real),
        "e_vqe_total_ha": float(result.eigenvalue.real) + shift,
        "wall_sec": round(wall, 2),
        "final_3": [round(e, 8) for e in history[-3:]],
    }


def main() -> int:
    print("# F-Q-6-B2 closure: H2O 4e/4o UCCSD VQE\n")

    print("Building 4e/4o Hamiltonian + UCCSD ansatz ...")
    h = build_h2o_4e4o()
    sparse_op = h["sparse_op"]
    shift = h["constant_shift"]
    ansatz = h["ansatz"]

    casci = casci_reference()
    print(f"  n_qubits = {sparse_op.num_qubits}")
    print(f"  n_pauli = {len(sparse_op.paulis)}")
    print(f"  UCCSD params = {ansatz.num_parameters}")
    print(f"  HF reference + UCCSD reps=1")
    print(f"  CASCI = {casci:+.8f} Ha")
    print(f"  constant_shift = {shift:+.8f} Ha\n")

    results = []
    for opt_name, maxiter in [("COBYLA", 600), ("SLSQP", 300), ("L_BFGS_B", 200)]:
        print(f"=== UCCSD + {opt_name} (maxiter={maxiter}) ===")
        try:
            r = run_vqe(sparse_op, ansatz, shift, opt_name, maxiter)
        except Exception as exc:
            print(f"  FAIL: {exc}\n")
            results.append({"optimizer": opt_name, "error": str(exc)})
            continue
        delta_ha = abs(r["e_vqe_total_ha"] - casci)
        delta_mha = delta_ha * 1000
        delta_uha = delta_ha * 1e6
        chem_acc = delta_ha < 1.6e-3
        sub_uha = delta_uha < 1.0
        r["e_casci"] = casci
        r["delta_mha"] = delta_mha
        r["delta_uha"] = delta_uha
        r["chem_acc_pass"] = chem_acc
        r["sub_uha_pass"] = sub_uha
        results.append(r)
        print(f"  VQE = {r['e_vqe_total_ha']:+.8f} Ha")
        print(f"  delta = {delta_mha:.4f} mHa ({delta_uha:.2f} µHa)")
        print(f"  chem-acc = {'PASS' if chem_acc else 'FAIL'}  sub-µHa = {'PASS' if sub_uha else 'FAIL'}")
        print(f"  iter = {r['iterations']}  wall = {r['wall_sec']}s\n")

    print("=== JSON ===")
    print(json.dumps(results, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
