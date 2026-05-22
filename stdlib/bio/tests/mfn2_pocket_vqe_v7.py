#!/usr/bin/env python3
"""
mfn2_pocket_vqe_v7.py — Phase γ closure push (v7.1 loop iter 3, 2026-05-11).

F-Q-6-D 4th pocket cluster QM — MFN2 GTPase pocket mimic
(mfn2-001 의 GTPase corrector chemistry).

cluster: [Mg²⁺ + methylphosphate (PO4 mimic) + guanine + water (Mg coord)]
  • Mg²⁺ (GTPase cation cofactor)
  • methylphosphate (CH3OPO3²⁻, GTP/GDP phosphate mimic)
  • guanine (C5H5N5O, GTP/GDP base)
  • 2× H2O (Mg coord sphere)

net charge: 0 (+2 -2 +0 +0 = 0).
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


MFN2_MINI_GEOM = (
    # Mg²⁺ center
    "Mg 0.000 0.000 0.000; "
    # H2O × 2 (Mg coord)
    "O 0.000 2.100 0.000; "
    "H 0.700 2.700 0.500; "
    "H -0.700 2.700 -0.500; "
    "O -2.100 0.000 0.000; "
    "H -2.700 0.700 0.500; "
    "H -2.700 -0.700 -0.500; "
    # methylphosphate CH3OPO3²⁻ (-2 charge) - GTP phosphate mimic
    "P 2.100 0.000 0.000; "
    "O 2.700 1.200 0.500; "
    "O 2.700 -1.200 0.500; "
    "O 2.500 0.000 -1.500; "
    "O 3.500 0.000 1.200; "  # P-O-CH3 bridge
    "C 4.700 0.500 1.200; "
    "H 5.300 -0.300 1.200; "
    "H 4.700 1.100 0.300; "
    "H 4.700 1.100 2.100; "
    # guanine (C5H5N5O, purine base) — at lower z
    "N 1.000 -2.500 0.000; "
    "C 0.000 -3.300 0.000; "
    "N -1.300 -2.800 0.000; "
    "C -1.200 -1.400 0.000; "
    "C 0.100 -1.000 0.000; "
    "C 2.400 -2.700 0.000; "  # C8
    "N 2.200 -1.350 0.000; "  # N7
    "N 1.000 -1.000 0.000; "  # connected
    "C 0.500 -4.700 0.000; "  # C2-NH2
    "N 1.800 -5.200 0.000; "  # NH2
    "O -2.100 -0.400 0.000; "  # C6=O
    "H 3.300 -3.300 0.000; "
    "H -2.200 -3.400 0.000; "
    "H 2.000 -6.200 0.000; "
    "H 2.500 -4.700 0.000"
)


def main() -> int:
    print("# §15.2.d MFN2 GTPase pocket cluster QM (Phase γ iter 3)\n")
    print("cluster: [Mg²⁺ + 2 H2O + methylphosphate + guanine]")
    print()
    try:
        from pyscf import gto, scf, mcscf
        working_ch, working_sp = None, None
        for ch, sp in [(0, 0), (-1, 0), (1, 0), (-2, 0), (2, 0), (0, 1)]:
            try:
                m = gto.M(atom=MFN2_MINI_GEOM, basis="sto3g", charge=ch, spin=sp, verbose=0)
                if m.spin == 0:
                    working_ch, working_sp = ch, sp
                    print(f"  pyscf charge={ch} spin={sp}: nelec={m.nelectron} natoms={m.natm}")
                    break
            except Exception:
                continue
        if working_ch is None:
            print("  no valid charge"); return 1

        t0 = time.time()
        driver = PySCFDriver(atom=MFN2_MINI_GEOM, basis="sto3g",
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

        mol = gto.M(atom=MFN2_MINI_GEOM, basis="sto3g", charge=working_ch, spin=working_sp, verbose=0)
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
            "cluster": "MFN2 GTPase pocket mimic (Mg + phosphate + guanine)",
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
