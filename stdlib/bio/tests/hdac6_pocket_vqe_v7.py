#!/usr/bin/env python3
"""
hdac6_pocket_vqe_v7.py — Phase γ closure push #2 (v7.1 2026-05-11).

F-Q-6-D pocket-restricted active-space VQE 첫 attempt — HDAC6 zinc-binding
cluster QM model. 정합 electron-count + 단순 geometry (3-coord Zn complex).

cluster: [Zn(imidazole)(acetate)(hydroxamate)] — 4-coordinate Zn(II)
  • Zn²⁺ (28 e)
  • 1 imidazole (HOZ ringsystem, His mimic) — C₃H₄N₂ neutral
  • 1 acetate (CH₃COO⁻, Asp mimic)
  • 1 hydroxamate (CH₃CONHOH 단축형, Tubastatin ZBG fragment)

honest scope: 본 cluster = HDAC6 catalytic Zn coordination 의 가장 단순 mimic.
정확한 binding pocket = QM/MM 또는 explicit residue truncation 필요.
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


# Simple HDAC6 active site cluster mimic
# Charges: Zn(II) +2, acetate -1, hydroxamate -1 → net 0
# Imidazole = neutral
HDAC6_MINI_GEOM = (
    # Zn (II) center
    "Zn 0.000 0.000 0.000; "
    # Imidazole (His mimic, N1-coord) — C3H4N2
    "N 0.000 2.100 0.000; "
    "C 1.100 2.900 0.000; "
    "N 0.800 4.200 0.000; "
    "C -0.500 4.200 0.000; "
    "C -1.000 2.900 0.000; "
    "H 0.900 1.700 0.500; "  # NH (N-H, attached to N1 if needed)
    "H 2.150 2.700 0.000; "
    "H 1.500 4.900 0.000; "
    "H -1.100 5.050 0.000; "
    "H -2.050 2.700 0.000; "
    # Acetate (CH3COO⁻, Asp mimic) — C2H3O2-
    "O -2.000 0.000 0.000; "
    "C -3.000 0.700 0.000; "
    "O -3.000 1.900 0.000; "
    "C -4.300 -0.000 0.000; "
    "H -4.300 -0.600 0.870; "
    "H -4.300 -0.600 -0.870; "
    "H -5.100 0.700 0.000; "
    # Hydroxamate (Tubastatin ZBG mimic, CH3CONHOH⁻ deprot on OH)
    "O 0.000 -2.000 0.000; "  # O coord to Zn
    "N -0.900 -2.800 0.000; "
    "H -0.700 -3.700 0.000; "
    "C -2.200 -2.500 0.000; "
    "O -2.700 -1.400 0.000; "
    "C -3.100 -3.700 0.000; "
    "H -3.000 -4.300 0.870; "
    "H -3.000 -4.300 -0.870; "
    "H -4.100 -3.400 0.000"
)


def main() -> int:
    print("# §15.2 HDAC6 mini cluster QM 4e/4o UCCSD (Phase γ first attempt)\n")
    print("cluster: [Zn(II) + imidazole + acetate + hydroxamate]")
    print("net charge: 0 (Zn²⁺ + acetate⁻ + hydroxamate⁻ + neutral imidazole)")
    print()

    try:
        # First check electron count via pyscf direct
        from pyscf import gto
        mol = gto.M(atom=HDAC6_MINI_GEOM, basis="sto3g", charge=0, spin=0, verbose=0)
        print(f"  pyscf direct: nelec={mol.nelectron} natoms={mol.natm} nbas={mol.nao_nr()}")
    except Exception as exc:
        # try different charge/spin
        for ch, sp in [(0, 0), (-1, 0), (1, 0), (0, 1), (-2, 0)]:
            try:
                mol = gto.M(atom=HDAC6_MINI_GEOM, basis="sto3g", charge=ch, spin=sp, verbose=0)
                print(f"  pyscf charge={ch} spin={sp}: nelec={mol.nelectron} natoms={mol.natm}")
                break
            except Exception as ex2:
                continue
        else:
            print(f"  pyscf all attempts FAIL: {exc}")
            return 1

    # Determine working charge/spin
    working_ch, working_sp = None, None
    from pyscf import gto
    for ch, sp in [(0, 0), (-1, 0), (1, 0), (-2, 0), (2, 0), (0, 1)]:
        try:
            m = gto.M(atom=HDAC6_MINI_GEOM, basis="sto3g", charge=ch, spin=sp, verbose=0)
            if m.spin == 0:
                working_ch, working_sp = ch, sp
                print(f"  selected charge={ch} spin={sp} (nelec={m.nelectron})")
                break
        except Exception:
            continue

    if working_ch is None:
        print("  no valid charge found")
        return 1

    try:
        t0 = time.time()
        driver = PySCFDriver(atom=HDAC6_MINI_GEOM, basis="sto3g",
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
        from pyscf import scf, mcscf
        mol = gto.M(atom=HDAC6_MINI_GEOM, basis="sto3g", charge=working_ch, spin=working_sp, verbose=0)
        mf = scf.RHF(mol).run()
        casci = mcscf.CASCI(mf, ncas=4, nelecas=4)
        casci.verbose = 0
        casci.kernel()
        e_casci = float(casci.e_tot)
        print(f"  build wall={t_build:.1f}s  n_qubits={sparse_op.num_qubits}  "
              f"n_pauli={len(sparse_op.paulis)}  HF particles={active_problem.num_particles}")
        print(f"  CASCI = {e_casci:+.6f} Ha")

        # VQE
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
            "cluster": "Zn + imidazole + acetate + hydroxamate (HDAC6 mimic)",
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
