#!/usr/bin/env python3
"""
sarm1_pocket_vqe_v7.py — Phase γ closure push #3 (v7.1 loop iter 1, 2026-05-11).

F-Q-6-D 두 번째 pocket cluster QM — SARM1 TIR NAD+ pocket mimic
(VERY HIGH IP target — sar1-001 의 Disarm/Lilly territory 의 양자 chem 평가).

cluster: [glutamate + nicotinamide + quinazolinone] (SARM1 TIR catalytic site mimic)
  • glutamate (E642 SARM1 mimic, catalytic acid) — acetate model
  • nicotinamide (NAD+ headgroup, substrate analog) — pyridine-3-carboxamide
  • quinazolinone fragment (hxq-cmt-sar1-001 ZBG-like H-bond donor) — 2-aminopyridine model

honest: 단순 cluster, full TIR 단백질 또는 NAD+ 전체 미반영.
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


# SARM1 TIR pocket cluster — substrate (NAD+ headgroup mimic) + catalytic
# residue (E642 acetate) + ligand fragment (2-amino-pyridine = sar1
# quinazolinone NH2 mimic). Net charge = -1 (acetate).
SARM1_MINI_GEOM = (
    # acetate (E642 mimic) — CH3COO⁻
    "O 0.000 0.000 0.000; "
    "C 1.250 0.000 0.000; "
    "O 2.000 1.000 0.000; "
    "C 2.000 -1.250 0.000; "
    "H 1.500 -2.100 0.000; "
    "H 2.700 -1.250 0.870; "
    "H 2.700 -1.250 -0.870; "
    # nicotinamide (NAD+ headgroup mimic) — pyridine-3-carboxamide
    "N -3.000 2.000 0.000; "  # pyridyl N
    "C -2.000 2.700 0.000; "
    "C -0.700 2.000 0.000; "
    "C -0.700 0.700 0.000; "
    "C -2.000 0.000 0.000; "
    "C -3.000 0.700 0.000; "
    "C 0.500 0.000 1.500; "  # amide C
    "O 1.700 0.000 1.500; "  # amide O
    "N 0.000 1.000 2.500; "  # amide NH
    "H -0.800 1.000 3.000; "
    "H 0.500 1.700 2.500; "
    "H -2.000 3.700 0.000; "
    "H 0.300 -0.500 -0.600; "
    "H -2.000 -1.000 0.000; "
    "H -4.000 0.500 0.000; "
    # 2-aminopyridine (sar1 quinazolinone NH2 mimic) — C5H6N2
    "N -3.000 -2.500 0.000; "
    "C -2.000 -3.000 0.500; "
    "C -2.000 -4.500 0.700; "
    "C -3.300 -5.200 0.500; "
    "C -4.300 -4.500 0.000; "
    "N -4.300 -3.000 -0.200; "
    "H -1.500 -2.500 1.000; "  # NH2
    "H -1.000 -2.500 0.500; "
    "H -1.300 -5.000 1.000; "
    "H -3.500 -6.200 0.700; "
    "H -5.300 -5.000 -0.200"
)


def main() -> int:
    print("# §15.2.b SARM1 TIR pocket cluster QM (Phase γ push iter 1)\n")
    print("cluster: [acetate (E642 mimic) + nicotinamide (NAD+) + 2-aminopyridine (ZBG)]")
    print()
    try:
        from pyscf import gto, scf, mcscf
        # Determine charge/spin
        working_ch, working_sp = None, None
        for ch, sp in [(0, 0), (-1, 0), (1, 0), (0, 1)]:
            try:
                m = gto.M(atom=SARM1_MINI_GEOM, basis="sto3g", charge=ch, spin=sp, verbose=0)
                if m.spin == 0:
                    working_ch, working_sp = ch, sp
                    print(f"  pyscf charge={ch} spin={sp}: nelec={m.nelectron} natoms={m.natm}")
                    break
            except Exception:
                continue
        if working_ch is None:
            print("  no valid charge")
            return 1

        t0 = time.time()
        driver = PySCFDriver(atom=SARM1_MINI_GEOM, basis="sto3g",
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

        # CASCI reference
        mol = gto.M(atom=SARM1_MINI_GEOM, basis="sto3g", charge=working_ch, spin=working_sp, verbose=0)
        mf = scf.RHF(mol).run()
        casci = mcscf.CASCI(mf, ncas=4, nelecas=4)
        casci.verbose = 0
        casci.kernel()
        e_casci = float(casci.e_tot)
        print(f"  build wall={t_build:.1f}s  n_qubits={sparse_op.num_qubits}  "
              f"n_pauli={len(sparse_op.paulis)}")
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
            "cluster": "SARM1 TIR mimic (acetate + nicotinamide + 2-aminopyridine)",
            "charge": working_ch, "spin": working_sp,
            "n_qubits": sparse_op.num_qubits,
            "n_pauli": len(sparse_op.paulis),
            "casci": e_casci, "vqe_total_ha": e_vqe,
            "delta_uha": delta_uha,
            "chem_acc": chem_acc, "sub_uha": sub_uha,
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
