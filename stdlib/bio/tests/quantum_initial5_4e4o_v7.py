#!/usr/bin/env python3
"""
quantum_initial5_4e4o_v7.py — Phase β #7 (v7 closure 2026-05-11).

cycle 108 initial 5 candidates (hxq-ca-krs/al-ar/mi-hmg/ln-tgf/gen-001)
→ 4e/4o UCCSD reps=1. cycle 111 Phase B 2e/2o (sub-µHa 모두 PASS) 의
4e/4o 확장 검증.

cancer / alopecia / mi / lung_normalization / general 4 disease + 1 scaffold —
v7 양자 paradigm 을 CMT/ALS 외 disease 에도 적용.
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

from rdkit import Chem
from rdkit.Chem import AllChem, rdMolDescriptors


CANDIDATES = [
    ("hxq-ca-krs-001",  "CC(C)Cn1c2c(c(=O)n(c1=O)Cc1ccc(F)cc1)CC(N2)CCl"),
    ("hxq-al-ar-001",   "CC(C)(C)N(C(=O)C1CC(=O)N=C1)C1CCCCC1"),
    ("hxq-mi-hmg-001",  "OC(=O)CC(O)CC(=O)Oc1ccc(C(C)(C)C)cc1"),
    ("hxq-ln-tgf-001",  "Cc1cc(=O)n(-c2ccc(N)cc2)cc1"),
    ("hxq-gen-001",     "OC(=O)c1cc(F)ccc1NC(=O)C(C)C"),
]


def smiles_to_pyscf_atom(smiles: str, seed: int = 7) -> dict:
    mol = Chem.MolFromSmiles(smiles)
    if mol is None:
        raise ValueError(f"rdkit parse fail: {smiles!r}")
    m = Chem.AddHs(mol)
    rc = AllChem.EmbedMolecule(m, randomSeed=seed)
    if rc != 0:
        rc = AllChem.EmbedMolecule(m, randomSeed=seed, useRandomCoords=True)
    AllChem.UFFOptimizeMolecule(m, maxIters=400)
    conf = m.GetConformer()
    parts = []
    for atom in m.GetAtoms():
        pos = conf.GetAtomPosition(atom.GetIdx())
        parts.append(f"{atom.GetSymbol()} {pos.x:.6f} {pos.y:.6f} {pos.z:.6f}")
    return {
        "n_heavy": mol.GetNumHeavyAtoms(),
        "formula": rdMolDescriptors.CalcMolFormula(mol),
        "pyscf_atom": "; ".join(parts),
    }


def build_4e4o(pyscf_atom: str):
    driver = PySCFDriver(atom=pyscf_atom, basis="sto3g", charge=0, spin=0)
    problem_full = driver.run()
    ast = ActiveSpaceTransformer(num_electrons=4, num_spatial_orbitals=4)
    active_problem = ast.transform(problem_full)
    mapper = ParityMapper(num_particles=active_problem.num_particles)
    sparse_op = mapper.map(active_problem.hamiltonian.second_q_op())
    shift = float(sum(active_problem.hamiltonian.constants.values()))
    hf = HartreeFock(num_spatial_orbitals=4, num_particles=active_problem.num_particles, qubit_mapper=mapper)
    ucc = UCCSD(num_spatial_orbitals=4, num_particles=active_problem.num_particles,
                qubit_mapper=mapper, initial_state=hf, reps=1)
    return sparse_op, shift, ucc


def casci_ref(pyscf_atom: str):
    from pyscf import gto, scf, mcscf
    mol = gto.M(atom=pyscf_atom, basis="sto3g", charge=0, spin=0, verbose=0)
    mf = scf.RHF(mol).run()
    casci = mcscf.CASCI(mf, ncas=4, nelecas=4)
    casci.verbose = 0
    casci.kernel()
    return float(casci.e_tot)


def run_uccsd(sparse_op, ansatz, shift: float, maxiter: int = 300) -> dict:
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
    return {"iter": len(history),
            "e_vqe_total_ha": float(result.eigenvalue.real) + shift,
            "wall_sec": round(wall, 2)}


def main() -> int:
    print("# §12.2.j initial 5 cycle 108 candidates 4e/4o UCCSD\n")
    results = []
    for name, smi in CANDIDATES:
        print(f"\n=== {name} ({smi}) ===")
        try:
            geom = smiles_to_pyscf_atom(smi)
        except Exception as exc:
            print(f"  GEOM FAIL: {exc}")
            results.append({"id": name, "status": "GEOM-FAIL", "error": str(exc)})
            continue
        print(f"  geom: heavy={geom['n_heavy']} formula={geom['formula']}")
        t0 = time.time()
        try:
            sparse_op, shift, ucc = build_4e4o(geom["pyscf_atom"])
            casci = casci_ref(geom["pyscf_atom"])
        except Exception as exc:
            print(f"  BUILD FAIL: {exc}")
            results.append({"id": name, "status": "BUILD-FAIL", "error": str(exc)})
            continue
        t_build = time.time() - t0
        print(f"  build wall={t_build:.1f}s  n_qubits={sparse_op.num_qubits}  "
              f"n_pauli={len(sparse_op.paulis)}  CASCI={casci:+.6f}")

        vqe = run_uccsd(sparse_op, ucc, shift)
        delta_uha = abs(vqe["e_vqe_total_ha"] - casci) * 1e6
        chem_acc = delta_uha < 1600
        sub_uha = delta_uha < 1.0
        print(f"  VQE={vqe['e_vqe_total_ha']:+.6f}  delta={delta_uha:.3f} µHa  "
              f"chem-acc={'PASS' if chem_acc else 'FAIL'}  "
              f"sub-µHa={'PASS' if sub_uha else 'FAIL'}  "
              f"iter={vqe['iter']}  wall={vqe['wall_sec']}s")
        results.append({
            "id": name, "smiles": smi, "formula": geom["formula"], "heavy": geom["n_heavy"],
            "n_qubits": sparse_op.num_qubits, "n_pauli": len(sparse_op.paulis),
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
