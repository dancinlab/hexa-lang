#!/usr/bin/env python3
"""
quantum_uccsd_reps2_v7.py — Phase β #7 (v7 closure 2026-05-11).

stuck 4e/4o 후보 (chem-acc PASS but sub-µHa FAIL) → UCCSD reps=2 ramp.
F-Q-6-B/C cumulative sub-µHa closure 시도.

target IDs (4e/4o chem-acc PASS, sub-µHa FAIL or near):
  - hxq-als-c9orf72-001-C (12.9 µHa @ reps=1)
  - hxq-als-kif5a-001-A   (1.48 µHa @ reps=1, near sub-µHa)
  - hxq-cmt-clc1-001-orig (3.19 µHa @ reps=1)
  - hxq-cmt-clc1-alt      (1.33 µHa @ reps=1, near sub-µHa)
  - hxq-cmt-sar1-001-orig (26.8 µHa @ reps=1)
"""
from __future__ import annotations

import json
import sys
import time

import numpy as np

from qiskit_nature.second_q.drivers import PySCFDriver
from qiskit_nature.second_q.mappers import ParityMapper
from qiskit_nature.second_q.transformers import ActiveSpaceTransformer
from qiskit_nature.second_q.circuit.library import UCCSD, HartreeFock

from qiskit.primitives import StatevectorEstimator
from qiskit_algorithms import VQE
from qiskit_algorithms.optimizers import SLSQP


TARGET_IDS = [
    "hxq-als-c9orf72-001-C",
    "hxq-als-kif5a-001-A",
    "hxq-cmt-clc1-001-orig",
    "hxq-cmt-clc1-alt",
    "hxq-cmt-sar1-001-orig",
]


def build_4e4o(pyscf_atom: str, reps: int):
    driver = PySCFDriver(atom=pyscf_atom, basis="sto3g", charge=0, spin=0)
    problem_full = driver.run()
    ast = ActiveSpaceTransformer(num_electrons=4, num_spatial_orbitals=4)
    active_problem = ast.transform(problem_full)
    mapper = ParityMapper(num_particles=active_problem.num_particles)
    sparse_op = mapper.map(active_problem.hamiltonian.second_q_op())
    shift = float(sum(active_problem.hamiltonian.constants.values()))
    hf = HartreeFock(num_spatial_orbitals=4, num_particles=active_problem.num_particles, qubit_mapper=mapper)
    ucc = UCCSD(num_spatial_orbitals=4, num_particles=active_problem.num_particles,
                qubit_mapper=mapper, initial_state=hf, reps=reps)
    return sparse_op, shift, ucc


def casci_ref(pyscf_atom: str, ncas=4, nelecas=4):
    from pyscf import gto, scf, mcscf
    mol = gto.M(atom=pyscf_atom, basis="sto3g", charge=0, spin=0, verbose=0)
    mf = scf.RHF(mol).run()
    casci = mcscf.CASCI(mf, ncas=ncas, nelecas=nelecas)
    casci.verbose = 0
    casci.kernel()
    return float(casci.e_tot)


def run_uccsd(sparse_op, ansatz, shift: float, maxiter: int = 400) -> dict:
    estimator = StatevectorEstimator()
    optimizer = SLSQP(maxiter=maxiter)
    rng = np.random.default_rng(7)
    x0 = rng.normal(scale=0.05, size=ansatz.num_parameters)
    history: list[float] = []

    def cb(eval_count, params, energy, meta):
        history.append(float(energy))

    vqe = VQE(estimator=estimator, ansatz=ansatz, optimizer=optimizer,
              initial_point=x0, callback=cb)
    t0 = time.time()
    result = vqe.compute_minimum_eigenvalue(sparse_op)
    wall = time.time() - t0
    return {
        "iter": len(history), "params": int(ansatz.num_parameters),
        "e_vqe_total_ha": float(result.eigenvalue.real) + shift,
        "wall_sec": round(wall, 2),
    }


def main() -> int:
    pool = {}
    for fname in [
        "tests/sar1_alt_geoms.json",
        "tests/smallmol_alt_geoms.json",
        "tests/als_sar1_002_c9orf72_geoms.json",
        "tests/schematic_3_scaffold_geoms.json",
    ]:
        try:
            with open(fname) as f:
                pool.update(json.load(f))
        except FileNotFoundError:
            pass

    geoms = {k: pool[k] for k in TARGET_IDS if k in pool}
    print(f"# §12.2.i UCCSD reps=2 ramp ({len(geoms)}/{len(TARGET_IDS)} entry)\n")
    results = []
    for name, geom in geoms.items():
        print(f"\n=== {name} ({geom['formula']}, heavy={geom['n_heavy']}) ===")
        t0 = time.time()
        try:
            sparse_op, shift, ucc = build_4e4o(geom["pyscf_atom"], reps=2)
            casci = casci_ref(geom["pyscf_atom"])
        except Exception as exc:
            print(f"  BUILD FAIL: {exc}")
            results.append({"id": name, "status": "BUILD-FAIL", "error": str(exc)})
            continue
        t_build = time.time() - t0
        print(f"  build wall={t_build:.1f}s  n_qubits={sparse_op.num_qubits}  "
              f"n_pauli={len(sparse_op.paulis)}  UCCSD reps=2 params={ucc.num_parameters}  "
              f"CASCI={casci:+.6f}")

        vqe = run_uccsd(sparse_op, ucc, shift, maxiter=400)
        delta_uha = abs(vqe["e_vqe_total_ha"] - casci) * 1e6
        chem_acc = delta_uha < 1600
        sub_uha = delta_uha < 1.0
        print(f"  VQE={vqe['e_vqe_total_ha']:+.6f}  delta={delta_uha:.3f} µHa  "
              f"chem-acc={'PASS' if chem_acc else 'FAIL'}  "
              f"sub-µHa={'PASS' if sub_uha else 'FAIL'}  "
              f"iter={vqe['iter']}  wall={vqe['wall_sec']}s")
        results.append({
            "id": name, "smiles": geom["smiles"], "formula": geom["formula"], "heavy": geom["n_heavy"],
            "n_qubits": sparse_op.num_qubits, "params": int(ucc.num_parameters),
            "build_wall_sec": round(t_build, 1),
            "casci": casci, "vqe": vqe["e_vqe_total_ha"],
            "delta_uha": delta_uha, "chem_acc": chem_acc, "sub_uha": sub_uha,
            "iter": vqe["iter"], "vqe_wall_sec": vqe["wall_sec"],
        })

    print("\n=== JSON ===")
    print(json.dumps(results, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
