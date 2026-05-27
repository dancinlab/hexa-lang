#!/usr/bin/env python3
"""
hdac6_lbfgs_retry_v7.py — Phase γ closure push (v7.1 loop iter 9, 2026-05-11).

HDAC6 cluster QM L_BFGS_B 단일 재시도 — iter 0 SLSQP 15.0 µHa chem-acc-only
→ L_BFGS_B paradigm (iter 7/8) 으로 sub-µHa 가능 여부 검증 (transition metal Zn²⁺).
"""
from __future__ import annotations

import json
import sys
import time
import importlib.util

import numpy as np

from qiskit_nature.second_q.drivers import PySCFDriver
from qiskit_nature.second_q.mappers import ParityMapper
from qiskit_nature.second_q.transformers import ActiveSpaceTransformer
from qiskit_nature.second_q.circuit.library import UCCSD, HartreeFock

from qiskit.primitives import StatevectorEstimator
from qiskit_algorithms import VQE
from qiskit_algorithms.optimizers import L_BFGS_B


# Load HDAC6 geom from existing script
spec = importlib.util.spec_from_file_location(
    "_hdac6_mod",
    "/home/summer/mac_home/core/hexa-bio/tests/hdac6_pocket_vqe_v7.py",
)
hdac6_mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hdac6_mod)
HDAC6_GEOM = hdac6_mod.HDAC6_MINI_GEOM


def main() -> int:
    print("# §15.2.k HDAC6 L_BFGS_B retry — transition metal Zn²⁺ sub-µHa 검증\n")
    try:
        from pyscf import gto, scf, mcscf
        working_ch = -1  # known from iter 0
        working_sp = 0
        driver = PySCFDriver(atom=HDAC6_GEOM, basis="sto3g",
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

        mol = gto.M(atom=HDAC6_GEOM, basis="sto3g", charge=working_ch, spin=working_sp, verbose=0)
        mf = scf.RHF(mol).run()
        casci = mcscf.CASCI(mf, ncas=4, nelecas=4)
        casci.verbose = 0
        casci.kernel()
        e_casci = float(casci.e_tot)
        print(f"  HDAC6 cluster: charge={working_ch}  n_qubits={sparse_op.num_qubits}  CASCI={e_casci:+.6f} Ha")
        print(f"  iter 0 SLSQP delta = 15.0 µHa (reference)")

        for seed in [7, 42, 123]:
            rng = np.random.default_rng(seed)
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
            tag = ("sub-µHa ⭐" if sub_uha else "chem-acc" if chem_acc else "FAIL")
            print(f"  L_BFGS_B seed={seed}: delta = {delta_uha:.6f} µHa  ({tag})  wall={wall:.1f}s")
    except Exception as exc:
        import traceback
        traceback.print_exc()
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
