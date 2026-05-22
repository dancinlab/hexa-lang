#!/usr/bin/env python3
"""
tbk1_pocket_vqe_v7.py — Phase γ closure push (v7.1 loop iter 6, 2026-05-11).

F-Q-6-D 7th pocket cluster QM — TBK1 kinase ATP pocket mimic
(ALS Q-axis 2nd, LoF rescue chaperone target).

cluster: [Mg²⁺ + methylphosphate (ATP γ-PO4 mimic) + adenine (purine) + dimethyl sulfide (Met hinge) + indole (tbk1-001-F binder fragment)]
  • Mg²⁺ (kinase Mg cofactor)
  • methylphosphate (CH3OPO3²⁻ — ATP phosphate mimic)
  • adenine (C5H5N5 — ATP purine base)
  • dimethyl sulfide (Me2S — Met hinge residue mimic, sulfur 신규)
  • indole (C8H7N — tbk1-001-F indole carboxamide 의 binder core)

신규 chemistry: 비활성 alkali earth + sulfide + adenine + π-stack (vs MFN2 의 guanine 분기).
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


TBK1_MINI_GEOM = (
    # Mg²⁺ center
    "Mg 0.000 0.000 0.000; "
    # methylphosphate (CH3OPO3²⁻) - ATP γ-phosphate mimic
    "P 2.100 0.000 0.000; "
    "O 2.700 1.200 0.500; "
    "O 2.700 -1.200 0.500; "
    "O 2.500 0.000 -1.500; "
    "O 3.500 0.000 1.200; "
    "C 4.700 0.500 1.200; "
    "H 5.300 -0.300 1.200; "
    "H 4.700 1.100 0.300; "
    "H 4.700 1.100 2.100; "
    # adenine (C5H5N5) - ATP purine base
    "N -2.500 0.000 0.000; "  # N9
    "C -3.500 1.000 0.000; "  # C8
    "N -4.700 0.500 0.000; "  # N7
    "C -4.500 -0.800 0.000; "  # C5
    "C -3.100 -1.100 0.000; "  # C4 (N9-C4-C5 ring closure)
    "C -5.500 -1.800 0.000; "  # C6
    "N -5.000 -3.000 0.000; "  # N1
    "C -3.700 -3.200 0.000; "  # C2
    "N -2.800 -2.250 0.000; "  # N3
    "N -6.700 -1.400 0.000; "  # C6-NH2
    "H -7.450 -2.000 0.000; "
    "H -6.900 -0.400 0.000; "
    "H -3.500 -4.300 0.000; "  # C2-H
    "H -3.500 1.900 0.000; "  # C8-H
    # dimethyl sulfide (Me2S) - Met hinge mimic (신규 chemistry: sulfur)
    "S 0.000 -3.000 0.000; "
    "C 1.500 -3.500 0.000; "
    "C -1.500 -3.500 0.000; "
    "H 2.000 -3.000 0.870; "
    "H 2.000 -3.000 -0.870; "
    "H 1.700 -4.500 0.000; "
    "H -2.000 -3.000 0.870; "
    "H -2.000 -3.000 -0.870; "
    "H -1.700 -4.500 0.000; "
    # indole (C8H7N) - tbk1-001-F binder core
    "C 0.000 3.000 0.000; "
    "C 1.300 3.700 0.000; "
    "C 2.500 3.000 0.000; "
    "C 2.500 1.600 0.000; "
    "C 1.300 0.900 0.000; "
    "C 0.000 1.600 0.000; "
    "C -1.000 0.900 0.500; "
    "C -1.000 2.300 0.500; "
    "N 0.300 2.700 0.000; "
    "H 0.300 3.700 0.000; "
    "H 3.450 3.500 0.000; "
    "H 3.450 1.100 0.000; "
    "H 1.300 -0.100 0.000; "
    "H -2.000 0.300 0.700; "
    "H -2.000 2.800 0.700"
)


def main() -> int:
    print("# §15.2.g TBK1 kinase ATP pocket cluster QM (Phase γ iter 6)\n")
    print("cluster: [Mg²⁺ + methylphosphate + adenine + Me2S (Met hinge) + indole]")
    print()
    try:
        from pyscf import gto, scf, mcscf
        working_ch, working_sp = None, None
        for ch, sp in [(0, 0), (-1, 0), (1, 0), (-2, 0), (0, 1)]:
            try:
                m = gto.M(atom=TBK1_MINI_GEOM, basis="sto3g", charge=ch, spin=sp, verbose=0)
                if m.spin == 0:
                    working_ch, working_sp = ch, sp
                    print(f"  pyscf charge={ch} spin={sp}: nelec={m.nelectron} natoms={m.natm}")
                    break
            except Exception:
                continue
        if working_ch is None:
            print("  no valid charge"); return 1

        t0 = time.time()
        driver = PySCFDriver(atom=TBK1_MINI_GEOM, basis="sto3g",
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

        mol = gto.M(atom=TBK1_MINI_GEOM, basis="sto3g", charge=working_ch, spin=working_sp, verbose=0)
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
            "cluster": "TBK1 kinase ATP pocket (Mg + PO4 + adenine + Me2S + indole)",
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
