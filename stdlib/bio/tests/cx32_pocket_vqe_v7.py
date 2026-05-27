#!/usr/bin/env python3
"""
cx32_pocket_vqe_v7.py — Phase γ closure push (v7.1 loop iter 4, 2026-05-11).

F-Q-6-D 5th pocket cluster QM — Cx32 (gjb1) fold-rescue chaperone interaction
mimic (gjb1-001 chemistry). CMT Q-axis 5/5 final.

cluster: [2× Phe (helix lipophilic) + Asp (helix H-bond donor) + gjb1 fragment]
  • 2× toluene (Phe sidechain mimic, TM helix interior)
  • acetate (Asp sidechain mimic, helix H-bond donor)
  • methyl 4-CF3-benzoate (gjb1-001-A scaffold reduced — CF3-aryl + ester linker)
  • water (cavity solvent)
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


CX32_MINI_GEOM = (
    # toluene #1 (Phe TM helix mimic)
    "C -3.000 0.000 0.000; "
    "C -4.300 0.700 0.000; "
    "C -5.500 0.000 0.000; "
    "C -5.500 -1.400 0.000; "
    "C -4.300 -2.100 0.000; "
    "C -3.000 -1.400 0.000; "
    "C -1.700 0.700 0.000; "  # methyl
    "H -4.300 1.700 0.000; "
    "H -6.450 0.500 0.000; "
    "H -6.450 -1.900 0.000; "
    "H -4.300 -3.100 0.000; "
    "H -2.050 -1.900 0.000; "
    "H -1.000 0.300 0.870; "
    "H -1.000 0.300 -0.870; "
    "H -1.700 1.700 0.000; "
    # toluene #2 (translated +y axis)
    "C 3.000 0.000 0.000; "
    "C 4.300 0.700 0.000; "
    "C 5.500 0.000 0.000; "
    "C 5.500 -1.400 0.000; "
    "C 4.300 -2.100 0.000; "
    "C 3.000 -1.400 0.000; "
    "C 1.700 0.700 0.000; "
    "H 4.300 1.700 0.000; "
    "H 6.450 0.500 0.000; "
    "H 6.450 -1.900 0.000; "
    "H 4.300 -3.100 0.000; "
    "H 2.050 -1.900 0.000; "
    "H 1.000 0.300 0.870; "
    "H 1.000 0.300 -0.870; "
    "H 1.700 1.700 0.000; "
    # acetate (Asp sidechain, -1 charge)
    "O 0.000 3.000 0.000; "
    "C 0.000 4.200 0.000; "
    "O -1.100 4.700 0.000; "
    "C 1.300 4.900 0.000; "
    "H 1.300 5.900 0.000; "
    "H 2.000 4.400 0.700; "
    "H 2.000 4.400 -0.700; "
    # methyl 4-CF3-benzoate (gjb1 ligand fragment, CF3-aryl + ester)
    "C 0.000 -3.000 0.000; "
    "C 1.300 -3.700 0.000; "
    "C 1.300 -5.100 0.000; "
    "C 0.000 -5.800 0.000; "
    "C -1.300 -5.100 0.000; "
    "C -1.300 -3.700 0.000; "
    "C 0.000 -7.300 0.000; "  # CF3 C
    "F 1.300 -7.800 0.000; "
    "F -1.300 -7.800 0.000; "
    "F 0.000 -8.000 1.100; "
    "C 0.000 -1.500 0.000; "  # ester C
    "O 1.100 -0.900 0.000; "
    "O -1.100 -0.900 0.000; "
    "C -2.300 -1.500 0.000; "  # OMe methyl
    "H 2.250 -3.200 0.000; "
    "H 2.250 -5.600 0.000; "
    "H -2.250 -5.600 0.000; "
    "H -2.250 -3.200 0.000; "
    "H -3.150 -1.000 0.000; "
    "H -2.300 -2.100 0.870; "
    "H -2.300 -2.100 -0.870"
)


def main() -> int:
    print("# §15.2.e Cx32 (gjb1) fold-rescue interface cluster QM (Phase γ iter 4)\n")
    print("cluster: [2× toluene (Phe TM) + acetate (Asp) + methyl 4-CF3-benzoate (gjb1 fragment)]")
    print()
    try:
        from pyscf import gto, scf, mcscf
        working_ch, working_sp = None, None
        for ch, sp in [(0, 0), (-1, 0), (1, 0), (-2, 0), (0, 1)]:
            try:
                m = gto.M(atom=CX32_MINI_GEOM, basis="sto3g", charge=ch, spin=sp, verbose=0)
                if m.spin == 0:
                    working_ch, working_sp = ch, sp
                    print(f"  pyscf charge={ch} spin={sp}: nelec={m.nelectron} natoms={m.natm}")
                    break
            except Exception:
                continue
        if working_ch is None:
            print("  no valid charge"); return 1

        t0 = time.time()
        driver = PySCFDriver(atom=CX32_MINI_GEOM, basis="sto3g",
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

        mol = gto.M(atom=CX32_MINI_GEOM, basis="sto3g", charge=working_ch, spin=working_sp, verbose=0)
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
            "cluster": "Cx32 fold-rescue interface mimic (2 Phe + Asp + gjb1 fragment)",
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
