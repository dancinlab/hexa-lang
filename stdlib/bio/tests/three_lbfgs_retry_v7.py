#!/usr/bin/env python3
"""
three_lbfgs_retry_v7.py — Phase γ closure push (v7.1 loop iter 10, 2026-05-11).

3 stuck pocket VQE targets (MFN2 + SARM1 + c9orf72) L_BFGS_B 단일 seed 재시도.
cluster-class hypothesis 검증:
  - MFN2: Mg²⁺ alkaline earth (vs HDAC6 Zn²⁺ transition metal)
  - SARM1: TIR conjugated heterocycle
  - c9orf72: K⁺ alkali + G4 π-stack

각 target → L_BFGS_B seed=7 + maxiter=200 만 (시간 단축, 3 cluster × ~2 min).
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


def load_geom(module_path: str, attr: str) -> str:
    spec = importlib.util.spec_from_file_location("_geom_mod", module_path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return getattr(mod, attr)


BASE = "/home/summer/mac_home/core/hexa-bio/tests"
TARGETS = [
    ("MFN2",    f"{BASE}/mfn2_pocket_vqe_v7.py",     "MFN2_MINI_GEOM",     11.3),
    ("SARM1",   f"{BASE}/sarm1_pocket_vqe_v7.py",    "SARM1_MINI_GEOM",    192.6),
    ("c9orf72", f"{BASE}/c9orf72_pocket_vqe_v7.py",  "C9ORF72_MINI_GEOM",  1.376),
]


def main() -> int:
    print("# §15.2.l 3 stuck targets L_BFGS_B retry (MFN2/SARM1/c9orf72)\n")
    for name, path, attr, slsqp_ref in TARGETS:
        print(f"\n=== {name} ===")
        print(f"  SLSQP reference: {slsqp_ref:.3f} µHa")
        try:
            from pyscf import gto, scf, mcscf
            geom = load_geom(path, attr)
            # Determine charge/spin
            working_ch, working_sp = None, None
            for ch, sp in [(0, 0), (-1, 0), (1, 0), (-2, 0), (2, 0), (0, 1)]:
                try:
                    m = gto.M(atom=geom, basis="sto3g", charge=ch, spin=sp, verbose=0)
                    if m.spin == 0:
                        working_ch, working_sp = ch, sp
                        break
                except Exception:
                    continue
            if working_ch is None:
                print("  no valid charge"); continue
            driver = PySCFDriver(atom=geom, basis="sto3g", charge=working_ch, spin=working_sp)
            problem_full = driver.run()
            ast = ActiveSpaceTransformer(num_electrons=4, num_spatial_orbitals=4)
            active_problem = ast.transform(problem_full)
            mapper = ParityMapper(num_particles=active_problem.num_particles)
            sparse_op = mapper.map(active_problem.hamiltonian.second_q_op())
            shift = float(sum(active_problem.hamiltonian.constants.values()))
            hf = HartreeFock(num_spatial_orbitals=4, num_particles=active_problem.num_particles, qubit_mapper=mapper)
            ucc = UCCSD(num_spatial_orbitals=4, num_particles=active_problem.num_particles,
                        qubit_mapper=mapper, initial_state=hf, reps=1)
            mol = gto.M(atom=geom, basis="sto3g", charge=working_ch, spin=working_sp, verbose=0)
            mf = scf.RHF(mol).run()
            casci = mcscf.CASCI(mf, ncas=4, nelecas=4); casci.verbose=0; casci.kernel()
            e_casci = float(casci.e_tot)

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
            tag = ("sub-µHa ⭐" if sub_uha else "chem-acc" if chem_acc else "FAIL")
            change = "🔻" if delta_uha < slsqp_ref else "🔺" if delta_uha > slsqp_ref else "="
            print(f"  L_BFGS_B seed=7: delta = {delta_uha:.4f} µHa  ({tag})  {change}  wall={wall:.1f}s")
        except Exception as exc:
            import traceback
            traceback.print_exc()
            print(f"  FAIL: {exc}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
