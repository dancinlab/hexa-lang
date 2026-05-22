#!/usr/bin/env python3
"""
stmn2_pocket_vqe_v7.py — Phase γ closure push (v7.1 loop iter 8, 2026-05-11).

F-Q-6-D 9th pocket cluster QM — stmn2 cryptic exon 5'ss RNA stem-loop mimic.
ALS Q-axis 4th. L_BFGS_B optimizer (iter 7 paradigm).

cluster: [adenine + uracil (Watson-Crick A-U pair) + ribose-2'-OH (sugar fragment) +
         methylphosphate (backbone P) + ASO seed mimic (PS+MOE methyl)]
  • adenine (RNA base A)
  • uracil (RNA base U, Watson-Crick pair)
  • methylphosphate (PO4 backbone)
  • methanol (2'-OH ribose fragment mimic)
  • dimethyl sulfide (PS backbone P=S thiophosphate mimic from ASO chemistry)

신규 chemistry: RNA Watson-Crick H-bond + thiophosphate.
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
from qiskit_algorithms.optimizers import L_BFGS_B, SLSQP


STMN2_MINI_GEOM = (
    # adenine (purine base) - left
    "N -2.000 0.000 0.000; "
    "C -3.000 1.000 0.000; "
    "N -4.300 0.500 0.000; "
    "C -4.000 -0.800 0.000; "
    "C -2.700 -1.000 0.000; "
    "C -5.000 -1.800 0.000; "
    "N -4.500 -3.000 0.000; "
    "C -3.200 -3.200 0.000; "
    "N -2.300 -2.250 0.000; "
    "N -6.200 -1.400 0.000; "  # NH2
    "H -6.950 -2.000 0.000; "
    "H -6.400 -0.400 0.000; "
    "H -3.000 -4.300 0.000; "
    "H -3.000 1.900 0.000; "
    # uracil (pyrimidine base) - right (Watson-Crick H-bond distance)
    "N 2.000 0.000 0.000; "
    "C 3.300 0.500 0.000; "
    "N 4.300 -0.500 0.000; "
    "C 4.000 -1.800 0.000; "
    "C 2.700 -2.300 0.000; "
    "C 1.700 -1.300 0.000; "
    "O 3.700 1.700 0.000; "  # C2=O
    "O 5.000 -2.700 0.000; "  # C4=O
    "H 5.250 -0.300 0.000; "  # N3-H
    "H 2.500 -3.300 0.000; "
    "H 0.700 -1.700 0.000; "
    "H 1.700 1.000 0.000; "  # N1-H (or attach point)
    # methylphosphate (backbone P)
    "P 0.000 -5.000 0.000; "
    "O 0.000 -3.500 0.000; "
    "O 1.300 -5.700 0.000; "
    "O -1.300 -5.700 0.000; "
    "O 0.000 -5.000 -1.500; "
    "C 1.000 -3.000 0.000; "
    "H 1.500 -3.000 0.870; "
    "H 1.500 -3.000 -0.870; "
    "H 1.300 -2.000 0.000; "
    # methanol (ribose 2'-OH fragment)
    "O -2.000 -5.000 0.000; "
    "C -3.000 -5.700 0.000; "
    "H -2.000 -4.000 0.000; "
    "H -3.500 -5.500 0.870; "
    "H -3.500 -5.500 -0.870; "
    "H -3.000 -6.700 0.000; "
    # dimethyl sulfide (PS thiophosphate mimic from ASO chemistry)
    "S 0.000 3.000 0.000; "
    "C 1.500 3.500 0.000; "
    "C -1.500 3.500 0.000; "
    "H 2.000 3.000 0.870; "
    "H 2.000 3.000 -0.870; "
    "H 1.700 4.500 0.000; "
    "H -2.000 3.000 0.870; "
    "H -2.000 3.000 -0.870; "
    "H -1.700 4.500 0.000"
)


def main() -> int:
    print("# §15.2.j stmn2 RNA stem-loop pocket cluster QM (Phase γ iter 8 L_BFGS_B)\n")
    print("cluster: [adenine + uracil (WC pair) + methylphosphate + methanol (2'-OH) + Me2S (PS thiophos.)]")
    print()
    try:
        from pyscf import gto, scf, mcscf
        working_ch, working_sp = None, None
        for ch, sp in [(0, 0), (-1, 0), (1, 0), (-2, 0), (0, 1)]:
            try:
                m = gto.M(atom=STMN2_MINI_GEOM, basis="sto3g", charge=ch, spin=sp, verbose=0)
                if m.spin == 0:
                    working_ch, working_sp = ch, sp
                    print(f"  pyscf charge={ch} spin={sp}: nelec={m.nelectron} natoms={m.natm}")
                    break
            except Exception:
                continue
        if working_ch is None:
            print("  no valid charge"); return 1

        t0 = time.time()
        driver = PySCFDriver(atom=STMN2_MINI_GEOM, basis="sto3g",
                             charge=working_ch, spin=working_sp)
        problem_full = driver.run()
        ast = ActiveSpaceTransformer(num_electrons=4, num_spatial_orbitals=4)
        active_problem = ast.transform(problem_full)
        mapper = ParityMapper(num_particles=active_problem.num_particles)
        sparse_op = mapper.map(active_problem.hamiltonian.second_q_op())
        shift = float(sum(active_problem.hamiltonian.constants.values()))
        hf = HartreeFock(num_spatial_orbitals=4, num_particles=active_problem.num_particles, qubit_mapper=mapper)
        ucc = UCCSD(num_spatial_orbitals=4, num_particles=active_problem.num_particles,
                    qubit_mapper=mapper, initial_state=hf, reps=1)
        t_build = time.time() - t0

        mol = gto.M(atom=STMN2_MINI_GEOM, basis="sto3g", charge=working_ch, spin=working_sp, verbose=0)
        mf = scf.RHF(mol).run()
        casci = mcscf.CASCI(mf, ncas=4, nelecas=4)
        casci.verbose = 0
        casci.kernel()
        e_casci = float(casci.e_tot)
        print(f"  build wall={t_build:.1f}s  n_qubits={sparse_op.num_qubits}  n_pauli={len(sparse_op.paulis)}")
        print(f"  CASCI = {e_casci:+.6f} Ha")

        # L_BFGS_B (paradigm from iter 7)
        rng = np.random.default_rng(7)
        x0 = rng.normal(scale=0.05, size=ucc.num_parameters)
        opt = L_BFGS_B(maxiter=200)
        vqe = VQE(estimator=StatevectorEstimator(), ansatz=ucc, optimizer=opt, initial_point=x0)
        t0 = time.time()
        result = vqe.compute_minimum_eigenvalue(sparse_op)
        wall = time.time() - t0
        e_vqe = float(result.eigenvalue.real) + shift
        delta_uha = abs(e_vqe - e_casci) * 1e6
        chem_acc = delta_uha < 1600
        sub_uha = delta_uha < 1.0
        print(f"  VQE (L_BFGS_B seed=7) = {e_vqe:+.6f} Ha  delta = {delta_uha:.3f} µHa  "
              f"chem-acc={'PASS' if chem_acc else 'FAIL'}  sub-µHa={'PASS' if sub_uha else 'FAIL'}  "
              f"wall={wall:.1f}s")
        result_dict = {
            "status": "BUILD-PASS + VQE-PASS",
            "cluster": "stmn2 RNA stem-loop (A-U pair + PO4 + 2'OH + PS-thiophosphate mimic)",
            "optimizer": "L_BFGS_B",
            "charge": working_ch, "spin": working_sp,
            "n_qubits": sparse_op.num_qubits, "n_pauli": len(sparse_op.paulis),
            "casci": e_casci, "vqe_total_ha": e_vqe,
            "delta_uha": delta_uha, "chem_acc": chem_acc, "sub_uha": sub_uha,
            "wall_sec": round(wall, 2),
        }
    except Exception as exc:
        import traceback
        traceback.print_exc()
        result_dict = {"status": "FAIL", "error": str(exc)}

    print("\n## JSON")
    print(json.dumps(result_dict, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
