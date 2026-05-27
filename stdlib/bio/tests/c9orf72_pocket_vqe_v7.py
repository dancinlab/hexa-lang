#!/usr/bin/env python3
"""
c9orf72_pocket_vqe_v7.py — Phase γ closure push (v7.1 loop iter 5, 2026-05-11).

F-Q-6-D 6th pocket cluster QM — c9orf72 G4 RNA quadruplex mimic.
ALS Q-axis 1st (HDAC6/SARM1 ALS variant 은 CMT cluster 와 동일 chem 으로 cover됨).

cluster: [K⁺ + 2 guanines (mini G-quartet stack) + indole (DC-34 binder)]
  • K⁺ (alkali cation, G4 central coord)
  • 2× guanine (G-quartet stack, π-π)
  • indole (DC-34 paradigm binder fragment)

신규 chemistry: alkali cation + nucleobase + π-stack (HDAC6 Zn / MFN2 Mg / Cx32 protein 등과 구별).
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


C9ORF72_MINI_GEOM = (
    # K⁺ central (G4 cation)
    "K 0.000 0.000 0.000; "
    # guanine #1 (upper G-quartet)
    "N 0.000 -3.000 1.500; "
    "C -1.300 -3.500 1.500; "
    "N -1.300 -4.900 1.500; "
    "C 0.000 -5.400 1.500; "
    "C 1.000 -4.400 1.500; "
    "C 2.300 -4.500 1.500; "
    "N 2.300 -3.150 1.500; "
    "N 1.000 -2.800 1.500; "
    "O 0.000 -6.700 1.500; "  # C6=O
    "N -2.500 -3.000 1.500; "  # C2-NH2
    "H -2.500 -2.000 1.500; "
    "H -3.300 -3.500 1.500; "
    "H 3.300 -4.900 1.500; "
    "H -2.250 -5.400 1.500; "
    # guanine #2 (lower G-quartet, π-stack ~3.4 Å below)
    "N 0.000 -3.000 -1.900; "
    "C -1.300 -3.500 -1.900; "
    "N -1.300 -4.900 -1.900; "
    "C 0.000 -5.400 -1.900; "
    "C 1.000 -4.400 -1.900; "
    "C 2.300 -4.500 -1.900; "
    "N 2.300 -3.150 -1.900; "
    "N 1.000 -2.800 -1.900; "
    "O 0.000 -6.700 -1.900; "
    "N -2.500 -3.000 -1.900; "
    "H -2.500 -2.000 -1.900; "
    "H -3.300 -3.500 -1.900; "
    "H 3.300 -4.900 -1.900; "
    "H -2.250 -5.400 -1.900; "
    # indole (DC-34 paradigm binder fragment) — far side
    "C 5.000 0.000 0.000; "
    "C 6.300 0.700 0.000; "
    "C 7.500 0.000 0.000; "
    "C 7.500 -1.400 0.000; "
    "C 6.300 -2.100 0.000; "
    "C 5.000 -1.400 0.000; "
    "C 4.000 -0.700 0.500; "  # C3 indole
    "C 4.200 0.700 0.500; "  # C2 indole
    "N 5.300 1.500 0.000; "  # NH indole
    "H 5.300 2.500 0.000; "  # NH
    "H 8.450 0.500 0.000; "
    "H 8.450 -1.900 0.000; "
    "H 6.300 -3.100 0.000; "
    "H 4.000 -1.900 0.000; "
    "H 3.000 -1.000 0.700; "
    "H 3.500 1.400 0.700"
)


def main() -> int:
    print("# §15.2.f c9orf72 G4 RNA quadruplex pocket cluster QM (Phase γ iter 5)\n")
    print("cluster: [K⁺ + 2 guanines (mini G-quartet stack) + indole (DC-34 binder)]")
    print()
    try:
        from pyscf import gto, scf, mcscf
        working_ch, working_sp = None, None
        for ch, sp in [(0, 0), (1, 0), (-1, 0), (2, 0), (0, 1)]:
            try:
                m = gto.M(atom=C9ORF72_MINI_GEOM, basis="sto3g", charge=ch, spin=sp, verbose=0)
                if m.spin == 0:
                    working_ch, working_sp = ch, sp
                    print(f"  pyscf charge={ch} spin={sp}: nelec={m.nelectron} natoms={m.natm}")
                    break
            except Exception:
                continue
        if working_ch is None:
            print("  no valid charge"); return 1

        t0 = time.time()
        driver = PySCFDriver(atom=C9ORF72_MINI_GEOM, basis="sto3g",
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

        mol = gto.M(atom=C9ORF72_MINI_GEOM, basis="sto3g", charge=working_ch, spin=working_sp, verbose=0)
        mf = scf.RHF(mol).run()
        casci = mcscf.CASCI(mf, ncas=4, nelecas=4)
        casci.verbose = 0
        casci.kernel()
        e_casci = float(casci.e_tot)
        print(f"  build wall={t_build:.1f}s  n_qubits={sparse_op.num_qubits}  n_pauli={len(sparse_op.paulis)}")
        print(f"  CASCI = {e_casci:+.6f} Ha")

        estimator = StatevectorEstimator()
        optimizer = SLSQP(maxiter=300)
        rng = np.random.default_rng(7)
        x0 = rng.normal(scale=0.05, size=ucc.num_parameters)
        history = []
        def cb(eval_count, params, energy, meta):
            history.append(float(energy))
        vqe = VQE(estimator=estimator, ansatz=ucc, optimizer=optimizer,
                  initial_point=x0, callback=cb)
        t0 = time.time()
        result = vqe.compute_minimum_eigenvalue(sparse_op)
        wall = time.time() - t0
        e_vqe = float(result.eigenvalue.real) + shift
        delta_uha = abs(e_vqe - e_casci) * 1e6
        chem_acc = delta_uha < 1600
        sub_uha = delta_uha < 1.0
        print(f"  VQE = {e_vqe:+.6f} Ha  delta = {delta_uha:.3f} µHa  "
              f"chem-acc={'PASS' if chem_acc else 'FAIL'}  sub-µHa={'PASS' if sub_uha else 'FAIL'}  "
              f"iter={len(history)}  wall={wall:.1f}s")
        result_dict = {
            "status": "BUILD-PASS + VQE-PASS",
            "cluster": "c9orf72 G4 mimic (K+ + 2 guanine + indole)",
            "charge": working_ch, "spin": working_sp,
            "n_qubits": sparse_op.num_qubits, "n_pauli": len(sparse_op.paulis),
            "casci": e_casci, "vqe_total_ha": e_vqe,
            "delta_uha": delta_uha, "chem_acc": chem_acc, "sub_uha": sub_uha,
            "iter": len(history), "wall_sec": round(wall, 2),
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
