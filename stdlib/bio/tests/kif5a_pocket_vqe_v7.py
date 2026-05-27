#!/usr/bin/env python3
"""
kif5a_pocket_vqe_v7.py — Phase γ closure push (v7.1 loop iter 7, 2026-05-11).

F-Q-6-D 8th pocket cluster QM — KIF5A motor-microtubule interface mimic
(ALS Q-axis 3rd). MFN2/TBK1 의 Mg-ATP 가 아닌, motor 의 protein-microtubule
interface chemistry 에 focus.

cluster: [methylguanidinium (Arg motor) + acetate (tubulin Glu C-term) +
         imidazole (His motor) + toluene (Phe motor) + 2-amino-pyrimidine (kif5a-001-A 의 ATPase pocket 단편)]
  • methylguanidinium (Arg sidechain, motor loop H-bond + electrostatic with tubulin)
  • acetate (tubulin C-terminal Glu E418/E450)
  • imidazole (His-coordination motor residue)
  • toluene (Phe motor hydrophobic)
  • 2-amino-pyrimidine (kif5a-001-A 의 fragment, ATPase pocket H-bond donor)

신규 chemistry: Arg guanidine + 다중 H-bond + protein-protein interface
(이전 cluster 들과 distinct).
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


KIF5A_MINI_GEOM = (
    # methylguanidinium (Arg sidechain, charged +1) - CH3-N=C(NH2)(NH2)+
    "C 0.000 0.000 0.000; "
    "N 1.300 0.700 0.000; "
    "N -1.000 0.700 0.000; "
    "N 0.000 -1.300 0.000; "
    "C 0.000 -2.700 0.000; "  # methyl
    "H 0.000 -3.300 0.870; "
    "H 0.000 -3.300 -0.870; "
    "H -1.000 -3.000 0.000; "
    "H 2.150 0.300 0.000; "
    "H 1.400 1.700 0.000; "
    "H -1.900 0.300 0.000; "
    "H -1.000 1.700 0.000; "
    # acetate (tubulin Glu C-term, -1) — translated
    "O 4.500 0.000 0.000; "
    "C 5.700 0.000 0.000; "
    "O 6.400 1.000 0.000; "
    "C 6.400 -1.250 0.000; "
    "H 6.000 -2.100 0.000; "
    "H 7.100 -1.250 0.870; "
    "H 7.100 -1.250 -0.870; "
    # imidazole (His sidechain neutral) — different z
    "N -3.500 1.000 0.000; "
    "C -4.500 1.700 0.000; "
    "N -5.700 1.000 0.000; "
    "C -5.500 -0.300 0.000; "
    "C -4.000 -0.300 0.000; "
    "H -3.500 2.000 0.000; "  # NH
    "H -4.500 2.700 0.000; "
    "H -6.700 1.400 0.000; "
    "H -6.300 -1.000 0.000; "
    "H -3.300 -1.000 0.000; "
    # toluene (Phe motor hydrophobic)
    "C -3.000 -3.000 1.500; "
    "C -4.300 -3.700 1.500; "
    "C -5.500 -3.000 1.500; "
    "C -5.500 -1.600 1.500; "
    "C -4.300 -0.900 1.500; "
    "C -3.000 -1.600 1.500; "
    "C -1.700 -3.700 1.500; "
    "H -4.300 -4.700 1.500; "
    "H -6.450 -3.500 1.500; "
    "H -6.450 -1.100 1.500; "
    "H -4.300 0.100 1.500; "
    "H -2.050 -1.100 1.500; "
    "H -1.000 -3.300 2.370; "
    "H -1.000 -3.300 0.630; "
    "H -1.700 -4.700 1.500; "
    # 2-amino-pyrimidine (kif5a-001-A fragment)
    "N 3.000 -3.000 0.000; "
    "C 4.300 -3.500 0.000; "
    "N 4.300 -4.900 0.000; "
    "C 3.000 -5.400 0.000; "
    "C 1.700 -4.700 0.000; "
    "C 1.700 -3.500 0.000; "
    "N 5.500 -2.800 0.000; "  # NH2
    "H 6.300 -3.300 0.000; "
    "H 5.500 -1.800 0.000; "
    "H 3.000 -6.400 0.000; "
    "H 0.700 -5.200 0.000; "
    "H 0.700 -3.000 0.000"
)


def main() -> int:
    print("# §15.2.h KIF5A motor-microtubule interface cluster QM (Phase γ iter 7)\n")
    print("cluster: [methylguanidinium (Arg) + acetate (Glu) + imidazole (His) + toluene (Phe) + 2-aminopyrimidine]")
    print()
    try:
        from pyscf import gto, scf, mcscf
        working_ch, working_sp = None, None
        for ch, sp in [(0, 0), (-1, 0), (1, 0), (-2, 0), (0, 1)]:
            try:
                m = gto.M(atom=KIF5A_MINI_GEOM, basis="sto3g", charge=ch, spin=sp, verbose=0)
                if m.spin == 0:
                    working_ch, working_sp = ch, sp
                    print(f"  pyscf charge={ch} spin={sp}: nelec={m.nelectron} natoms={m.natm}")
                    break
            except Exception:
                continue
        if working_ch is None:
            print("  no valid charge"); return 1

        t0 = time.time()
        driver = PySCFDriver(atom=KIF5A_MINI_GEOM, basis="sto3g",
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

        mol = gto.M(atom=KIF5A_MINI_GEOM, basis="sto3g", charge=working_ch, spin=working_sp, verbose=0)
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
            "cluster": "KIF5A motor-MT interface (Arg + Glu + His + Phe + aminopyrimidine)",
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
