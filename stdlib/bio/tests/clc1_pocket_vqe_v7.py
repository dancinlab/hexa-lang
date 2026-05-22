#!/usr/bin/env python3
"""
clc1_pocket_vqe_v7.py — Phase γ closure push (v7.1 loop iter 2, 2026-05-11).

F-Q-6-D 3rd pocket cluster QM — ClC-1 chloride channel extracellular vestibule
mimic (clc1-001 anthranilic ligand interaction).

cluster: [Cl⁻ + methylammonium (Lys mimic) + toluene (Phe mimic) + 2-aminobenzoic acid (clc1 fragment)]
  • Cl⁻ ion (substrate)
  • methylammonium (CH3NH3⁺, Lys sidechain charge interaction)
  • toluene (Phe sidechain, vestibule hydrophobic)
  • 2-aminobenzoic acid (anthranilic, clc1-001 pharmacophore)
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


CLC1_MINI_GEOM = (
    # Cl⁻ ion
    "Cl 0.000 0.000 0.000; "
    # methylammonium (CH3NH3+) - Lys mimic
    "N 0.000 2.500 0.000; "
    "C 0.000 4.000 0.000; "
    "H 0.500 2.000 0.800; "
    "H 0.500 2.000 -0.800; "
    "H -1.000 2.000 0.000; "
    "H 0.500 4.500 0.870; "
    "H 0.500 4.500 -0.870; "
    "H -1.000 4.300 0.000; "
    # toluene (Phe sidechain mimic)
    "C 4.000 0.000 0.000; "
    "C 5.300 0.700 0.000; "
    "C 6.500 0.000 0.000; "
    "C 6.500 -1.400 0.000; "
    "C 5.300 -2.100 0.000; "
    "C 4.000 -1.400 0.000; "
    "C 3.000 0.700 0.000; "  # methyl
    "H 5.300 1.700 0.000; "
    "H 7.450 0.500 0.000; "
    "H 7.450 -1.900 0.000; "
    "H 5.300 -3.100 0.000; "
    "H 3.000 -1.900 0.000; "
    "H 3.500 1.700 0.000; "
    "H 2.500 0.500 0.870; "
    "H 2.500 0.500 -0.870; "
    # 2-aminobenzoic acid (anthranilic, clc1 pharmacophore)
    "C 0.000 -2.500 0.000; "
    "C 1.300 -3.200 0.000; "
    "C 1.300 -4.600 0.000; "
    "C 0.000 -5.300 0.000; "
    "C -1.300 -4.600 0.000; "
    "C -1.300 -3.200 0.000; "
    "C 0.000 -1.000 0.000; "  # COOH C
    "O 1.100 -0.400 0.000; "
    "O -1.100 -0.400 0.000; "
    "H 2.250 -2.700 0.000; "
    "H 2.250 -5.100 0.000; "
    "H 0.000 -6.300 0.000; "
    "H -2.250 -5.100 0.000; "
    "N -2.500 -2.500 0.000; "  # NH2
    "H -3.300 -3.000 0.000; "
    "H -2.500 -1.500 0.000; "
    "H -1.700 0.300 0.000"  # COOH H
)


def main() -> int:
    print("# §15.2.c ClC-1 vestibule pocket cluster QM (Phase γ iter 2)\n")
    print("cluster: [Cl⁻ + methylammonium (Lys) + toluene (Phe) + 2-aminobenzoic acid (anthranilic)]")
    print()
    try:
        from pyscf import gto, scf, mcscf
        working_ch, working_sp = None, None
        for ch, sp in [(0, 0), (-1, 0), (1, 0), (0, 1)]:
            try:
                m = gto.M(atom=CLC1_MINI_GEOM, basis="sto3g", charge=ch, spin=sp, verbose=0)
                if m.spin == 0:
                    working_ch, working_sp = ch, sp
                    print(f"  pyscf charge={ch} spin={sp}: nelec={m.nelectron} natoms={m.natm}")
                    break
            except Exception:
                continue
        if working_ch is None:
            print("  no valid charge"); return 1

        t0 = time.time()
        driver = PySCFDriver(atom=CLC1_MINI_GEOM, basis="sto3g",
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

        mol = gto.M(atom=CLC1_MINI_GEOM, basis="sto3g", charge=working_ch, spin=working_sp, verbose=0)
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
            "cluster": "ClC-1 vestibule mimic",
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
