#!/usr/bin/env python3
"""
hdac6_def2svp_v7.py — Phase γ closure push (v7.1 loop iter 12, 2026-05-11).

HDAC6 cluster QM def2-svp basis 시도 — transition metal Zn²⁺ chem-acc ceiling
의 진짜 cause (basis set vs active space) 검증.

sto-3g (Zn nbas=18) → def2-svp (Zn nbas=31) — Zn d-orbital 더 정확
4e/4o active space 동일 유지, basis 만 확장.
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
from qiskit_algorithms.optimizers import L_BFGS_B, SLSQP


import os
_here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location(
    "_hdac6_mod",
    os.path.join(_here, "hdac6_pocket_vqe_v7.py"),
)
hdac6_mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hdac6_mod)
HDAC6_GEOM = hdac6_mod.HDAC6_MINI_GEOM


def main() -> int:
    print("# §15.2.n HDAC6 def2-svp basis test (transition metal Zn²⁺ ceiling 검증)\n")
    print("sto-3g (reference iter 0/9): 14.5 µHa (basis-bound 추정)")
    print("def2-svp 시도: Zn nbas 18→31, 다른 atom basis 도 증가\n")
    try:
        from pyscf import gto, scf, mcscf
        for basis in ["def2-svp"]:
            print(f"\n=== basis: {basis} ===")
            t0 = time.time()
            try:
                driver = PySCFDriver(atom=HDAC6_GEOM, basis=basis, charge=-1, spin=0)
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

                mol = gto.M(atom=HDAC6_GEOM, basis=basis, charge=-1, spin=0, verbose=0)
                mf = scf.RHF(mol).run()
                casci = mcscf.CASCI(mf, ncas=4, nelecas=4)
                casci.verbose = 0
                casci.kernel()
                e_casci = float(casci.e_tot)
                print(f"  build wall={t_build:.1f}s  natoms={mol.natm}  nbas={mol.nao_nr()}  n_qubits={sparse_op.num_qubits}")
                print(f"  CASCI = {e_casci:+.6f} Ha")

                # L_BFGS_B + SLSQP 비교
                for opt_name, opt in [
                    ("L_BFGS_B", L_BFGS_B(maxiter=200)),
                    ("SLSQP", SLSQP(maxiter=300)),
                ]:
                    rng = np.random.default_rng(7)
                    x0 = rng.normal(scale=0.05, size=ucc.num_parameters)
                    vqe = VQE(estimator=StatevectorEstimator(), ansatz=ucc, optimizer=opt, initial_point=x0)
                    t0 = time.time()
                    result = vqe.compute_minimum_eigenvalue(sparse_op)
                    wall = time.time() - t0
                    e_vqe = float(result.eigenvalue.real) + shift
                    delta_uha = abs(e_vqe - e_casci) * 1e6
                    chem_acc = delta_uha < 1600
                    sub_uha = delta_uha < 1.0
                    tag = ("sub-µHa ⭐" if sub_uha else "chem-acc" if chem_acc else "FAIL")
                    print(f"  {opt_name}: delta = {delta_uha:.4f} µHa  ({tag})  wall={wall:.1f}s")
            except Exception as exc:
                import traceback
                print(f"  basis {basis} FAIL: {exc}")
                traceback.print_exc()
    except Exception as exc:
        import traceback
        traceback.print_exc()
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
