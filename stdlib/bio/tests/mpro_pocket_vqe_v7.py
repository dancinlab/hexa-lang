"""
mpro_pocket_vqe_v7.py — F-Q-6-D: SARS-CoV-2 Mpro catalytic-dyad + nirmatrelvir
warhead "binding pocket fragment" VQE (Phase γ pocket-VQE closure push, 2026-05-12).

Closes F-Q-6 / L3 (the *explicit pocket supersystem* — not just the isolated
ligand, which already PASSed: nirmatrelvir 2e/2o → sub-µHa 0.557 µHa, ledger
row 78 / cycle 97). Here the quantum-chemistry layer is checked on a minimal
3-fragment cluster mimic of the Mpro active site at the moment of covalent
(reversible) inhibition by nirmatrelvir:

  cluster (net charge 0 — the catalytically competent ion-pair state):
    • Cys145 thiolate          — methylthiolate  CH3-S(-)   (the nucleophile)
    • His41 (general acid)     — 4-methylimidazolium  (C3H3N2H2)+  (Nε2-H ··· S)
    • nirmatrelvir warhead     — acetonitrile  CH3-C#N      (the electrophilic
                                  nitrile carbon, ~3.4 Å from S, side-on attack
                                  trajectory — pre-thioimidate snapshot)

active space 2e/2o (HOMO+LUMO of the cluster) + sto-3g + ParityMapper → 2 qubit;
hardware-efficient depth-1 ansatz RealAmplitudes(reps=1) — exactly the
established F-Q-6-B-real / F-Q-6-C-mini-library path (the 4 Ry/Ry·CX·Ry/Ry
rotations = the n6 τ(6)=4 binding); classical reference = CASCI(2,2) on the
RHF orbitals; chem-acc gate = |ΔE| < 1600 µHa (1 kcal/mol), sub-µHa gate =
|ΔE| < 1.0 µHa. L_BFGS_B + SLSQP cross-comparison. No D3 dispersion
(the loop's "attempt 9 D3 bottleneck" path is avoided — sto-3g HF + CASCI only).

(A 4e/4o UCCSD pocket calc is feasible — KRAS-G12C iter 14 did sto-3g 4e/4o
sub-µHa — but is slow; 2e/2o is the proven loop-feasible real-drug pattern and
is what F-Q-6-D is closed on, mirroring the isolated-nirmatrelvir 2e/2o PASS.)

Honest C3: a hand-built crude cluster mimic (not a PDB QM/MM cutout);
the gate verifies that VQE reproduces the classical CASCI reference in the
chosen active space — it is NOT a binding-affinity or therapeutic claim.
The S1/S2 subpocket residues (His163, Glu166, Gln189) are out of scope here;
extending the cluster or the active space is future work (would only enlarge
the same test).
"""
from __future__ import annotations

import json
import sys
import time
import numpy as np

from qiskit.circuit.library import RealAmplitudes
from qiskit.primitives import StatevectorEstimator
from qiskit_algorithms import VQE
from qiskit_algorithms.optimizers import L_BFGS_B, SLSQP
from qiskit_nature.second_q.drivers import PySCFDriver
from qiskit_nature.second_q.mappers import ParityMapper
from qiskit_nature.second_q.transformers import ActiveSpaceTransformer


# ── Mpro active-site cluster mimic (Å). Net charge 0: CH3-S(-) + (4-MeIm-H)+ + CH3CN ──
MPRO_POCKET_GEOM = (
    # --- Cys145 methylthiolate  CH3-S(-)  : S at origin, Cβ along -x ---
    "S   0.000  0.000  0.000; "
    "C  -1.800  0.000  0.000; "          # Cβ
    "H  -2.200  1.020  0.000; "
    "H  -2.200 -0.510  0.880; "
    "H  -2.200 -0.510 -0.880; "
    # --- His41 4-methylimidazolium  (both ring N protonated) : ring in +z, N3-H toward S ---
    "N   0.300  0.200  3.500; "          # N3  (Nε2 mimic, faces S ~3.5 Å)
    "H   0.200  0.100  2.550; "          #   N3-H  ··· S
    "C   1.550  0.400  3.950; "          # C2
    "H   2.450  0.200  3.500; "          #   C2-H
    "N   1.400  0.550  5.300; "          # N1  (Nδ1 mimic)
    "H   2.200  0.400  5.950; "          #   N1-H
    "C   0.100  0.950  5.550; "          # C5
    "H  -0.300  1.150  6.450; "          #   C5-H
    "C  -0.550  1.050  4.250; "          # C4
    "C  -1.950  1.400  4.050; "          #   4-methyl C
    "H  -2.550  0.550  3.800; "
    "H  -2.350  2.200  3.600; "
    "H  -2.200  1.650  5.050; "
    # --- nirmatrelvir nitrile warhead  CH3-C#N  : nitrile C ~3.4 Å from S, side-on, methyl away ---
    "C   0.900  3.300  0.200; "          # Cw  (electrophilic nitrile carbon)
    "N   1.712  3.462  1.012; "          # #N  (Cw + 1.16*(0.700,0.140,0.700))
    "C  -0.122  3.096 -0.822; "          # methyl C  (Cw - 1.46*(0.700,0.140,0.700))
    "H  -0.620  2.196 -1.322; "
    "H  -1.022  3.396 -1.322; "
    "H  -0.422  2.896 -1.822"
)


def find_charge(basis="sto3g"):
    from pyscf import gto
    for ch, sp in [(0, 0), (1, 0), (-1, 0), (-2, 0), (2, 0)]:
        try:
            m = gto.M(atom=MPRO_POCKET_GEOM, basis=basis, charge=ch, spin=sp, verbose=0)
            if m.spin == 0:
                return ch, sp, m.nelectron, m.nao_nr(), m.natm
        except Exception:
            continue
    return None, None, None, None, None


def run(optimizer_name: str, seed: int = 7, _cache={}):
    t0 = time.time()
    ch, sp, nelec, nbas, natm = find_charge()
    if ch is None:
        return {"optimizer": optimizer_name, "status": "FAIL", "error": "no valid charge"}

    if "ham" not in _cache:
        driver = PySCFDriver(atom=MPRO_POCKET_GEOM, basis="sto3g", charge=ch, spin=sp)
        problem = driver.run()
        ast = ActiveSpaceTransformer(num_electrons=2, num_spatial_orbitals=2)
        ap = ast.transform(problem)
        mapper = ParityMapper(num_particles=ap.num_particles)
        sparse_op = mapper.map(ap.hamiltonian.second_q_op())
        shift = float(sum(ap.hamiltonian.constants.values()))
        from pyscf import gto, scf, mcscf
        mol = gto.M(atom=MPRO_POCKET_GEOM, basis="sto3g", charge=ch, spin=sp, verbose=0)
        mf = scf.RHF(mol).run()
        casci = mcscf.CASCI(mf, ncas=2, nelecas=2)
        casci.verbose = 0
        casci.kernel()
        _cache.update(sparse_op=sparse_op, shift=shift, e_casci=float(casci.e_tot),
                      build_sec=round(time.time() - t0, 1))
    c = _cache
    sparse_op, shift, e_casci = c["sparse_op"], c["shift"], c["e_casci"]
    n_qubits = sparse_op.num_qubits
    print(f"  [{optimizer_name}] natom={natm} charge={ch} nelec={nelec} nbas={nbas} "
          f"| active 2e/2o → {n_qubits} qubit / {len(sparse_op.paulis)} terms | build={c['build_sec']}s", flush=True)

    ansatz = RealAmplitudes(num_qubits=n_qubits, reps=1)   # depth-1 hardware-efficient: Ry·Ry·CX·Ry·Ry
    opt = L_BFGS_B(maxiter=200) if optimizer_name == "L_BFGS_B" else SLSQP(maxiter=300)
    estimator = StatevectorEstimator()
    rng = np.random.default_rng(seed)
    x0 = rng.normal(scale=0.1, size=ansatz.num_parameters)
    vqe = VQE(estimator=estimator, ansatz=ansatz, optimizer=opt, initial_point=x0)
    t_vqe = time.time()
    res = vqe.compute_minimum_eigenvalue(sparse_op)
    e_vqe = float(res.eigenvalue.real) + shift
    delta_uha = abs(e_vqe - e_casci) * 1e6
    return {
        "optimizer": optimizer_name, "seed": seed,
        "natom": natm, "charge": ch, "nelec": nelec, "nbas": nbas,
        "active_space": "2e/2o", "n_qubits": n_qubits, "n_pauli": len(sparse_op.paulis),
        "ansatz": "RealAmplitudes(reps=1)", "n_params": ansatz.num_parameters,
        "casci_ha": e_casci, "vqe_total_ha": e_vqe,
        "delta_uha": delta_uha,
        "chem_acc": bool(delta_uha < 1600), "sub_uha": bool(delta_uha < 1.0),
        "build_wall_sec": c["build_sec"], "vqe_wall_sec": round(time.time() - t_vqe, 2),
    }


def main() -> int:
    print("# F-Q-6-D — SARS-CoV-2 Mpro [Cys145 thiolate + His41 imidazolium + nirmatrelvir nitrile warhead] pocket QM\n", flush=True)
    print("cluster (net charge 0): CH3-S(-)  +  (4-methylimidazol-ium)+  +  CH3-C#N", flush=True)
    print("active space: 2e/2o (HOMO+LUMO) · sto-3g · ParityMapper → 2 qubit · RealAmplitudes(reps=1) · CASCI(2,2) reference\n", flush=True)
    results = []
    for opt in ["L_BFGS_B", "SLSQP"]:
        try:
            r = run(opt)
            results.append(r)
            if r.get("status") == "FAIL":
                print(f"  → {opt}: FAIL {r.get('error')}", flush=True); continue
            tag = "⭐ sub-µHa" if r["sub_uha"] else ("✅ chem-acc" if r["chem_acc"] else "❌ NOT converged")
            print(f"  → {opt}: ΔE = {r['delta_uha']:.4f} µHa vs CASCI(2,2)  {tag}  (VQE {r['vqe_wall_sec']}s)", flush=True)
        except Exception as exc:
            import traceback; traceback.print_exc()
            results.append({"optimizer": opt, "status": "FAIL", "error": str(exc)})
            print(f"  → {opt}: FAIL {exc}", flush=True)

    ok = [r for r in results if r.get("chem_acc")]
    sub = [r for r in results if r.get("sub_uha")]
    verdict = "PASS-SUB-UHA" if sub else ("PASS-CHEM-ACC" if ok else "NOT-CONVERGED")
    print(f"\n## verdict: F-Q-6-D {verdict}  ({len(sub)}/{len(results)} sub-µHa, {len(ok)}/{len(results)} chem-acc)")
    print("__MPRO_POCKET_VQE__ PASS" if ok else "__MPRO_POCKET_VQE__ NOT_CONVERGED")
    print("\n## JSON"); print(json.dumps(results, indent=2))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
