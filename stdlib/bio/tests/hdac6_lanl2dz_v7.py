"""
hdac6_lanl2dz_v7.py — Phase γ closure push (v7.1 loop iter 13, 2026-05-12).

§15.2.n ramp option 1 — lanl2dz ECP basis 시도.
- Zn core electron → ECP, valence nbas 18 (sto-3g 동일 수준)
- d-shell 표현은 sto-3g 보다 정확
- loop-feasible 시간 (≤5min) 안에 가능한지 + sub-µHa unlock 가능한지 검증

동일 27-atom cluster + 4e/4o active space + 3 optimizer × 1 seed.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys
import time
import numpy as np

from qiskit.primitives import StatevectorEstimator
from qiskit_algorithms import VQE
from qiskit_algorithms.optimizers import L_BFGS_B, SLSQP, COBYLA
from qiskit_nature.second_q.drivers import PySCFDriver
from qiskit_nature.second_q.mappers import ParityMapper
from qiskit_nature.second_q.transformers import ActiveSpaceTransformer
from qiskit_nature.second_q.circuit.library import HartreeFock, UCCSD

_here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location(
    "_hdac6_mod", os.path.join(_here, "hdac6_pocket_vqe_v7.py")
)
hdac6_mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hdac6_mod)
GEOM = hdac6_mod.HDAC6_MINI_GEOM


def find_charge():
    from pyscf import gto
    for ch, sp in [(0, 0), (-1, 0), (1, 0), (-2, 0), (2, 0)]:
        try:
            m = gto.M(atom=GEOM, basis="lanl2dz", charge=ch, spin=sp, verbose=0)
            if m.spin == 0:
                return ch, sp, m.nelectron, m.nao_nr()
        except Exception:
            continue
    return None, None, None, None


def run(optimizer_name: str, maxiter: int = 300, seed: int = 7):
    t0 = time.time()
    ch, sp, nelec, nbas = find_charge()
    if ch is None:
        return {"status": "FAIL", "error": "no valid charge"}
    print(f"  [{optimizer_name}] charge={ch} spin={sp} nelec={nelec} nbas={nbas}")

    driver = PySCFDriver(atom=GEOM, basis="lanl2dz", charge=ch, spin=sp)
    problem = driver.run()
    ast = ActiveSpaceTransformer(num_electrons=4, num_spatial_orbitals=4)
    ap = ast.transform(problem)
    mapper = ParityMapper(num_particles=ap.num_particles)
    sparse_op = mapper.map(ap.hamiltonian.second_q_op())
    shift = float(sum(ap.hamiltonian.constants.values()))
    hf = HartreeFock(num_spatial_orbitals=4, num_particles=ap.num_particles, qubit_mapper=mapper)
    ucc = UCCSD(num_spatial_orbitals=4, num_particles=ap.num_particles,
                qubit_mapper=mapper, initial_state=hf, reps=1)
    t_build = time.time() - t0
    print(f"  [{optimizer_name}] build wall={t_build:.1f}s n_qubits={sparse_op.num_qubits} n_pauli={len(sparse_op.paulis)}")

    from pyscf import gto, scf, mcscf
    mol = gto.M(atom=GEOM, basis="lanl2dz", charge=ch, spin=sp, verbose=0)
    mf = scf.RHF(mol).run()
    casci = mcscf.CASCI(mf, ncas=4, nelecas=4)
    casci.verbose = 0
    casci.kernel()
    e_casci = float(casci.e_tot)

    opt_map = {"SLSQP": SLSQP(maxiter=maxiter), "L_BFGS_B": L_BFGS_B(maxiter=maxiter), "COBYLA": COBYLA(maxiter=maxiter)}
    optimizer = opt_map[optimizer_name]
    estimator = StatevectorEstimator()
    rng = np.random.default_rng(seed)
    x0 = rng.normal(scale=0.05, size=ucc.num_parameters)
    history = []
    cb = lambda ec, p, e, m: history.append(float(e))
    vqe = VQE(estimator=estimator, ansatz=ucc, optimizer=optimizer, initial_point=x0, callback=cb)
    t_vqe = time.time()
    res = vqe.compute_minimum_eigenvalue(sparse_op)
    e_vqe = float(res.eigenvalue.real) + shift
    delta_uha = abs(e_vqe - e_casci) * 1e6
    wall_vqe = time.time() - t_vqe
    return {
        "optimizer": optimizer_name, "seed": seed,
        "charge": ch, "nelec": nelec, "nbas": nbas,
        "n_qubits": sparse_op.num_qubits, "n_pauli": len(sparse_op.paulis),
        "casci": e_casci, "vqe_total_ha": e_vqe,
        "delta_uha": delta_uha,
        "chem_acc": delta_uha < 1600, "sub_uha": delta_uha < 1.0,
        "iter": len(history), "build_wall_sec": round(t_build, 1),
        "vqe_wall_sec": round(wall_vqe, 1),
    }


def main() -> int:
    print("# §15.2.o HDAC6 lanl2dz ECP basis — Phase γ iter 13\n")
    print("hypothesis: lanl2dz Zn ECP → d-shell improved, loop-feasible (≤5min)")
    print()
    results = []
    for opt in ["L_BFGS_B", "SLSQP", "COBYLA"]:
        try:
            r = run(opt)
            results.append(r)
            sub = "⭐ sub-µHa" if r["sub_uha"] else ("✅ chem-acc" if r["chem_acc"] else "❌ FAIL")
            print(f"  → {opt}: delta = {r['delta_uha']:.3f} µHa  {sub}  vqe-wall={r['vqe_wall_sec']}s")
        except Exception as exc:
            import traceback
            traceback.print_exc()
            results.append({"optimizer": opt, "status": "FAIL", "error": str(exc)})
            print(f"  → {opt}: FAIL {exc}")
    print("\n## JSON")
    print(json.dumps(results, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
