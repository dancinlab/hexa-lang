#!/usr/bin/env python3
"""
pocket_lbfgs_retry_v7.py — Phase γ closure push (v7.1 loop iter 8, 2026-05-11).

L_BFGS_B paradigm 검증 (KIF5A iter 7 발견 적용):
4 chem-acc-only pocket targets (HDAC6/SARM1/MFN2/c9orf72) 의 sub-µHa 가능성.

각 target × 3 seed (7/42/123) × L_BFGS_B(maxiter=200).
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


# Load geom strings from existing cluster scripts
def load_geom(module_path: str, attr: str) -> str:
    spec = importlib.util.spec_from_file_location("_geom_mod", module_path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return getattr(mod, attr)


BASE = "/home/summer/mac_home/core/hexa-bio/tests"
TARGETS = [
    ("HDAC6",    "hdac6_pocket_vqe_v7.py",    "HDAC6_MINI_GEOM"),
    ("SARM1",    "sarm1_pocket_vqe_v7.py",    "SARM1_MINI_GEOM"),
    ("MFN2",     "mfn2_pocket_vqe_v7.py",     "MFN2_MINI_GEOM"),
    ("c9orf72",  "c9orf72_pocket_vqe_v7.py",  "C9ORF72_MINI_GEOM"),
]
SEEDS = [7, 42, 123]


def build_4e4o(geom: str):
    from pyscf import gto
    working_ch, working_sp = None, None
    for ch, sp in [(0, 0), (-1, 0), (1, 0), (-2, 0), (2, 0), (0, 1)]:
        try:
            m = gto.M(atom=geom, basis="sto3g", charge=ch, spin=sp, verbose=0)
            if m.spin == 0:
                working_ch, working_sp = ch, sp
                break
        except Exception:
            continue
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
    return sparse_op, shift, ucc, working_ch, working_sp


def casci_ref(geom: str, ch: int, sp: int):
    from pyscf import gto, scf, mcscf
    mol = gto.M(atom=geom, basis="sto3g", charge=ch, spin=sp, verbose=0)
    mf = scf.RHF(mol).run()
    casci = mcscf.CASCI(mf, ncas=4, nelecas=4)
    casci.verbose = 0
    casci.kernel()
    return float(casci.e_tot)


def main() -> int:
    print("# §15.2.i L_BFGS_B retry batch (4 chem-acc-only targets, 3 seeds each)\n")
    results = []
    for name, scriptname, attr in TARGETS:
        print(f"\n=== {name} ===")
        geom = load_geom(f"{BASE}/{scriptname}", attr)
        try:
            sparse_op, shift, ucc, ch, sp = build_4e4o(geom)
            e_casci = casci_ref(geom, ch, sp)
            print(f"  charge={ch} spin={sp}  n_qubits={sparse_op.num_qubits}  CASCI={e_casci:+.6f}")
        except Exception as exc:
            print(f"  BUILD FAIL: {exc}")
            results.append({"target": name, "status": "BUILD-FAIL", "error": str(exc)})
            continue

        for seed in SEEDS:
            rng = np.random.default_rng(seed)
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
            print(f"  seed={seed}: delta = {delta_uha:.3f} µHa  ({tag})  wall={wall:.1f}s")
            results.append({
                "target": name, "seed": seed, "optimizer": "L_BFGS_B",
                "e_casci": e_casci, "e_vqe": e_vqe,
                "delta_uha": delta_uha, "chem_acc": chem_acc, "sub_uha": sub_uha,
                "wall_sec": round(wall, 2),
            })

    print("\n## Summary")
    cols = ["target", "best seed", "best delta (µHa)", "sub-µHa", "vs SLSQP"]
    by_target = {}
    for r in results:
        if "target" not in r or "delta_uha" not in r:
            continue
        cur = by_target.get(r["target"])
        if cur is None or r["delta_uha"] < cur["delta_uha"]:
            by_target[r["target"]] = r
    for t in ["HDAC6", "SARM1", "MFN2", "c9orf72"]:
        r = by_target.get(t)
        if r is None:
            continue
        print(f"  {t}: seed={r['seed']}  delta={r['delta_uha']:.3f} µHa  sub-µHa={'PASS' if r['sub_uha'] else 'FAIL'}")
    print("\n## JSON")
    print(json.dumps(results, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
