#!/usr/bin/env python3
"""
atxn2_pocket_vqe_v7.py — Phase γ closure push (v7.1 loop iter 11, 2026-05-11).

F-Q-6-D 10th pocket cluster QM — atxn2 ATXN2 mRNA + ASO seed mimic.
ALS RB-axis final target. L_BFGS_B paradigm 적용.

cluster: [guanine + cytosine (Watson-Crick G-C pair, 3 H-bonds) +
         methylphosphate (RNA backbone) + methanol (2'-MOE simplified) +
         dimethyl sulfide (PS thiophosphate from ASO)]
  • guanine (target ATXN2 mRNA base)
  • cytosine (ASO complement, 3 H-bond WC pair with G)
  • methylphosphate (RNA backbone P)
  • methanol (2'-OMe / 2'-MOE wing simplification)
  • dimethyl sulfide (PS backbone P=S)

stmn2 (A-U 2 H-bond) 의 G-C 변형 (3 H-bond, 더 강한 binding).
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
from qiskit_algorithms.optimizers import L_BFGS_B


ATXN2_MINI_GEOM = (
    # guanine (purine base, target ATXN2 mRNA)
    "N -2.000 0.000 0.000; "  # N9 attached to ribose
    "C -3.000 1.000 0.000; "  # C8
    "N -4.300 0.500 0.000; "  # N7
    "C -4.000 -0.800 0.000; "  # C5
    "C -2.700 -1.000 0.000; "  # C4
    "C -5.000 -1.800 0.000; "  # C6
    "N -4.500 -3.000 0.000; "  # N1
    "C -3.200 -3.200 0.000; "  # C2
    "N -2.300 -2.250 0.000; "  # N3
    "O -6.200 -1.500 0.000; "  # C6=O (guanine specific)
    "N -2.800 -4.500 0.000; "  # C2-NH2 (guanine specific)
    "H -1.900 -5.000 0.000; "
    "H -3.500 -5.100 0.000; "
    "H -5.250 -3.500 0.000; "  # N1-H
    "H -3.000 1.900 0.000; "
    # cytosine (pyrimidine base, ASO complement)
    "N 2.000 0.000 0.000; "  # N1 attached to ribose
    "C 3.000 1.000 0.000; "  # C2
    "N 4.300 0.500 0.000; "  # N3
    "C 4.500 -0.900 0.000; "  # C4
    "C 3.500 -1.900 0.000; "  # C5
    "C 2.200 -1.500 0.000; "  # C6
    "O 2.700 2.200 0.000; "  # C2=O
    "N 5.800 -1.300 0.000; "  # C4-NH2 (cytosine specific)
    "H 6.500 -0.700 0.000; "
    "H 6.100 -2.250 0.000; "
    "H 3.800 -2.900 0.000; "
    "H 1.500 -2.250 0.000; "
    "H 1.500 0.700 0.000; "  # N1-H attach pt
    # methylphosphate (RNA backbone P)
    "P 0.000 -5.500 0.000; "
    "O 0.000 -4.000 0.000; "
    "O 1.300 -6.200 0.000; "
    "O -1.300 -6.200 0.000; "
    "O 0.000 -5.500 -1.500; "
    "C 1.000 -3.500 0.000; "
    "H 1.500 -3.500 0.870; "
    "H 1.500 -3.500 -0.870; "
    "H 1.300 -2.500 0.000; "
    # methanol (2'-MOE wing mimic)
    "O -2.000 -5.500 0.000; "
    "C -3.000 -6.200 0.000; "
    "H -2.000 -4.500 0.000; "
    "H -3.500 -6.000 0.870; "
    "H -3.500 -6.000 -0.870; "
    "H -3.000 -7.200 0.000; "
    # dimethyl sulfide (PS thiophosphate from ASO)
    "S 0.000 3.500 0.000; "
    "C 1.500 4.000 0.000; "
    "C -1.500 4.000 0.000; "
    "H 2.000 3.500 0.870; "
    "H 2.000 3.500 -0.870; "
    "H 1.700 5.000 0.000; "
    "H -2.000 3.500 0.870; "
    "H -2.000 3.500 -0.870; "
    "H -1.700 5.000 0.000"
)


def main() -> int:
    print("# §15.2.m atxn2 RNA stem-loop G-C cluster QM (Phase γ iter 11, L_BFGS_B)\n")
    print("cluster: [guanine + cytosine (WC G-C 3 H-bond) + PO4 + methanol (2'-MOE) + Me2S (PS thiophos.)]")
    print()
    try:
        from pyscf import gto, scf, mcscf
        working_ch, working_sp = None, None
        for ch, sp in [(0, 0), (-1, 0), (1, 0), (-2, 0), (0, 1)]:
            try:
                m = gto.M(atom=ATXN2_MINI_GEOM, basis="sto3g", charge=ch, spin=sp, verbose=0)
                if m.spin == 0:
                    working_ch, working_sp = ch, sp
                    print(f"  pyscf charge={ch} spin={sp}: nelec={m.nelectron} natoms={m.natm}")
                    break
            except Exception:
                continue
        if working_ch is None:
            print("  no valid charge"); return 1

        t0 = time.time()
        driver = PySCFDriver(atom=ATXN2_MINI_GEOM, basis="sto3g",
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

        mol = gto.M(atom=ATXN2_MINI_GEOM, basis="sto3g", charge=working_ch, spin=working_sp, verbose=0)
        mf = scf.RHF(mol).run()
        casci = mcscf.CASCI(mf, ncas=4, nelecas=4)
        casci.verbose = 0
        casci.kernel()
        e_casci = float(casci.e_tot)
        print(f"  build wall={t_build:.1f}s  n_qubits={sparse_op.num_qubits}  n_pauli={len(sparse_op.paulis)}")
        print(f"  CASCI = {e_casci:+.6f} Ha")

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
        print(f"  VQE L_BFGS_B seed=7 = {e_vqe:+.6f} Ha  delta = {delta_uha:.4f} µHa  "
              f"chem-acc={'PASS' if chem_acc else 'FAIL'}  sub-µHa={'PASS' if sub_uha else 'FAIL'}  "
              f"wall={wall:.1f}s")
    except Exception as exc:
        import traceback
        traceback.print_exc()
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
