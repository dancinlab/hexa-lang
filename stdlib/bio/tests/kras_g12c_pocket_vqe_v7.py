"""
kras_g12c_pocket_vqe_v7.py — Phase γ closure push (v7.1 loop iter 14, 2026-05-12).

§15.2.o pivot — non-CMT disease pocket VQE 확장 첫 entry.
hxq-ca-krs-001 (cancer cohort, KRAS-G12C 표적) 의 양자 chemistry layer 검증.

cluster: KRAS-G12C switch-II pocket mimic (sotorasib/adagrasib paradigm)
  • cysteine thiol (Cys12-G12C mutant, electrophile target)
  • methylguanidinium (Lys16 sidechain)
  • acetate (Asp33 sidechain)
  • toluene (Tyr-Phe aromatic stack)
  • acrylamide-methyl (covalent warhead fragment, Michael acceptor)

active space 4e/4o frontier + sto-3g (loop-feasible 검증된 baseline).
L_BFGS_B + SLSQP cross-comparison (iter 7 paradigm 적용).
"""
from __future__ import annotations

import json
import sys
import time
import numpy as np

from qiskit.primitives import StatevectorEstimator
from qiskit_algorithms import VQE
from qiskit_algorithms.optimizers import L_BFGS_B, SLSQP
from qiskit_nature.second_q.drivers import PySCFDriver
from qiskit_nature.second_q.mappers import ParityMapper
from qiskit_nature.second_q.transformers import ActiveSpaceTransformer
from qiskit_nature.second_q.circuit.library import HartreeFock, UCCSD


# KRAS-G12C switch-II pocket cluster mimic
# Cys-SH + Lys-NH3+ + Asp-COO- + Tyr/Phe aromatic + covalent acrylamide
KRAS_G12C_GEOM = (
    # Cys-12 thiol (cysteine sidechain, S-H electrophile target)
    "S 0.000 0.000 0.000; "
    "C 1.500 0.500 0.500; "  # Cβ
    "H 0.300 1.000 0.000; "  # SH
    "H 1.700 1.500 0.700; "
    "H 2.200 0.000 1.000; "
    # Lys-16 methylguanidinium (CH3-NH-C(NH2)2+ simplified to CH3NH3+)
    "C 4.000 1.500 0.000; "
    "N 3.500 2.800 0.500; "
    "H 4.700 1.300 -0.800; H 4.500 1.700 0.900; H 3.300 0.700 -0.100; "
    "H 2.700 2.600 1.000; H 4.200 3.500 0.900; H 3.000 3.200 -0.300; "
    # Asp-33 acetate (CH3COO-)
    "O -2.500 -1.500 0.000; "
    "C -3.500 -2.200 0.500; "
    "O -3.500 -3.400 0.500; "
    "C -4.800 -1.500 1.000; "
    "H -5.300 -2.100 1.700; H -5.500 -1.300 0.200; H -4.500 -0.500 1.400; "
    # Tyr aromatic (simplified as toluene CH3-C6H5, no -OH)
    "C 2.500 -2.500 -1.500; "
    "C 3.700 -2.000 -1.800; "
    "C 4.500 -2.700 -2.500; "
    "C 4.100 -3.900 -2.900; "
    "C 2.900 -4.400 -2.600; "
    "C 2.100 -3.700 -1.900; "
    "C 1.700 -1.700 -0.700; "  # methyl C
    "H 4.000 -1.100 -1.500; H 5.400 -2.300 -2.700; H 4.700 -4.400 -3.400; "
    "H 2.600 -5.300 -2.900; H 1.200 -4.100 -1.700; "
    "H 0.700 -2.000 -0.600; H 1.700 -0.700 -1.000; H 2.100 -1.700 0.300; "
    # Acrylamide warhead (CH2=CH-C(=O)-NH2, covalent Michael acceptor)
    "C -0.500 -3.000 1.500; "  # =CH2
    "C -1.500 -2.400 2.300; "  # =CH-
    "C -2.000 -1.000 2.200; "  # C(=O)
    "O -1.500 -0.200 1.400; "  # =O
    "N -3.000 -0.700 3.100; "  # NH2
    "H -0.300 -4.000 1.700; H 0.000 -2.500 0.700; "  # =CH2 H's
    "H -2.000 -3.000 3.000; "  # =CH H
    "H -3.500 -1.300 3.700; H -3.300 0.200 3.000"  # NH2 H's
)


def find_charge(basis="sto3g"):
    from pyscf import gto
    for ch, sp in [(0, 0), (1, 0), (-1, 0), (-2, 0), (2, 0)]:
        try:
            m = gto.M(atom=KRAS_G12C_GEOM, basis=basis, charge=ch, spin=sp, verbose=0)
            if m.spin == 0:
                return ch, sp, m.nelectron, m.nao_nr(), m.natm
        except Exception:
            continue
    return None, None, None, None, None


def run(optimizer_name: str, seed: int = 7):
    t0 = time.time()
    ch, sp, nelec, nbas, natm = find_charge()
    if ch is None:
        return {"status": "FAIL", "error": "no valid charge"}
    print(f"  [{optimizer_name}] natom={natm} charge={ch} nelec={nelec} nbas={nbas}", flush=True)

    driver = PySCFDriver(atom=KRAS_G12C_GEOM, basis="sto3g", charge=ch, spin=sp)
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
    print(f"  [{optimizer_name}] build={t_build:.1f}s n_qubits={sparse_op.num_qubits} n_pauli={len(sparse_op.paulis)}", flush=True)

    from pyscf import gto, scf, mcscf
    mol = gto.M(atom=KRAS_G12C_GEOM, basis="sto3g", charge=ch, spin=sp, verbose=0)
    mf = scf.RHF(mol).run()
    casci = mcscf.CASCI(mf, ncas=4, nelecas=4)
    casci.verbose = 0
    casci.kernel()
    e_casci = float(casci.e_tot)

    opt = L_BFGS_B(maxiter=200) if optimizer_name == "L_BFGS_B" else SLSQP(maxiter=300)
    estimator = StatevectorEstimator()
    rng = np.random.default_rng(seed)
    x0 = rng.normal(scale=0.05, size=ucc.num_parameters)
    vqe = VQE(estimator=estimator, ansatz=ucc, optimizer=opt, initial_point=x0)
    t_vqe = time.time()
    res = vqe.compute_minimum_eigenvalue(sparse_op)
    e_vqe = float(res.eigenvalue.real) + shift
    delta_uha = abs(e_vqe - e_casci) * 1e6
    wall_vqe = time.time() - t_vqe
    return {
        "optimizer": optimizer_name, "seed": seed,
        "natom": natm, "charge": ch, "nelec": nelec, "nbas": nbas,
        "n_qubits": sparse_op.num_qubits, "n_pauli": len(sparse_op.paulis),
        "casci": e_casci, "vqe_total_ha": e_vqe,
        "delta_uha": delta_uha,
        "chem_acc": bool(delta_uha < 1600), "sub_uha": bool(delta_uha < 1.0),
        "build_wall_sec": round(t_build, 1), "vqe_wall_sec": round(wall_vqe, 1),
    }


def main() -> int:
    print("# §15.2.p KRAS-G12C switch-II pocket cluster QM (Phase γ iter 14)\n", flush=True)
    print("cluster: [Cys-SH (G12C electrophile) + Lys-NH3+ + Asp-COO- + Tyr (toluene) + acrylamide warhead]", flush=True)
    print()
    results = []
    for opt in ["L_BFGS_B", "SLSQP"]:
        try:
            r = run(opt)
            results.append(r)
            sub = "⭐ sub-µHa" if r["sub_uha"] else ("✅ chem-acc" if r["chem_acc"] else "❌ FAIL")
            print(f"  → {opt}: delta = {r['delta_uha']:.3f} µHa  {sub}  vqe-wall={r['vqe_wall_sec']}s", flush=True)
        except Exception as exc:
            import traceback; traceback.print_exc()
            results.append({"optimizer": opt, "status": "FAIL", "error": str(exc)})
            print(f"  → {opt}: FAIL {exc}", flush=True)
    print("\n## JSON")
    print(json.dumps(results, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
