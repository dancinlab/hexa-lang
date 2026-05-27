"""3-cohort pocket VQE — alopecia AR + mi HMG-CoA + lung TGF-beta (v7.1 loop iter 15)."""
import json, time, numpy as np
from qiskit.primitives import StatevectorEstimator
from qiskit_algorithms import VQE
from qiskit_algorithms.optimizers import SLSQP, L_BFGS_B
from qiskit_nature.second_q.drivers import PySCFDriver
from qiskit_nature.second_q.mappers import ParityMapper
from qiskit_nature.second_q.transformers import ActiveSpaceTransformer
from qiskit_nature.second_q.circuit.library import HartreeFock, UCCSD
from pyscf import gto, scf, mcscf

# Small <=18-atom cluster mimics (loop-feasible per §15.2.p lesson)
COHORTS = {
  # alopecia hxq-al-ar-001 — AR LBD: phenol(Tyr) + amide(Asn/Gln) + 3-keto-steroid A-ring fragment mimic
  "hxq-al-ar-001": (
    "C 0.0 0.0 0.0; C 1.4 0.0 0.0; C 2.1 1.2 0.0; C 1.4 2.4 0.0; C 0.0 2.4 0.0; C -0.7 1.2 0.0; "
    "O -0.7 3.5 0.0; "  # 3-keto on ring (steroid A-ring mimic)
    "O 3.5 1.2 0.0; H 3.9 0.4 0.0; "  # phenol OH (Tyr mimic) — actually make it Tyr-like substituent
    "H -0.5 -0.9 0.0; H 1.9 -0.9 0.0; H 1.9 3.3 0.0; H -0.5 1.2 -0.9; "
    "N 2.1 -1.2 0.0; H 1.6 -2.0 0.0; H 3.1 -1.2 0.0"  # amide N (Asn mimic)
  ),
  # mi hxq-mi-hmg-001 — HMG-CoA reductase: HMG fragment (3-hydroxy-3-methylglutaryl) + Lys mimic
  "hxq-mi-hmg-001": (
    "C 0.0 0.0 0.0; C 1.5 0.0 0.0; O 1.9 1.3 0.0; C 1.5 -1.4 0.7; C 3.0 0.0 -0.5; "  # 3-OH-3-Me-glutaryl core
    "O 3.4 1.1 -1.0; O 3.7 -1.1 -0.5; "  # carboxylate
    "H -0.4 0.9 0.4; H -0.4 -0.9 0.4; H -0.4 0.0 -1.0; "
    "H 1.4 2.0 0.5; H 1.1 -2.2 0.1; H 1.0 -1.4 1.7; H 2.6 -1.4 0.8; "
    "N -1.4 0.0 0.5; H -1.8 0.8 0.1; H -1.8 -0.8 0.1"  # Lys ammonium mimic (catalytic Lys)
  ),
  # lung hxq-ln-tgf-001 — TGF-beta R1 (ALK5) kinase ATP hinge: adenine mimic + Ser hinge + small fragment
  "hxq-ln-tgf-001": (
    "N 0.0 0.0 0.0; C 1.2 0.5 0.0; N 2.3 -0.3 0.0; C 2.0 -1.6 0.0; C 0.7 -1.9 0.0; C -0.3 -0.9 0.0; "  # purine 6-ring
    "N 1.5 1.8 0.0; H 0.9 2.5 0.0; H 2.5 2.0 0.0; "  # 6-amino (adenine NH2)
    "N -1.6 -1.0 0.0; "  # ring N
    "O 3.0 -2.5 0.0; H 3.9 -2.2 0.0; "  # Ser hinge OH mimic attached
    "H 0.4 -2.9 0.0; "
    "C -2.4 0.1 0.0; H -2.0 1.1 0.0; H -3.4 0.0 0.4; H -2.4 0.0 -1.1"  # N-methyl
  ),
}
NETCHARGE = {"hxq-al-ar-001": 0, "hxq-mi-hmg-001": 0, "hxq-ln-tgf-001": 0}

results = {}
for cid, geom in COHORTS.items():
    t0 = time.time()
    print(f"\n# === {cid} ===", flush=True)
    ch_used = None
    for ch in [NETCHARGE[cid], 0, 1, -1, 2, -2]:
        try:
            m = gto.M(atom=geom, basis="sto3g", charge=ch, spin=0, verbose=0)
            if m.spin == 0:
                ch_used = ch; nbas = m.nao_nr(); nelec = m.nelectron; natm = m.natm
                print(f"natom={natm} charge={ch} nelec={nelec} nbas={nbas}", flush=True); break
        except Exception:
            continue
    if ch_used is None:
        print(f"  {cid}: no valid charge", flush=True); results[cid] = {"status": "FAIL-charge"}; continue
    try:
        driver = PySCFDriver(atom=geom, basis="sto3g", charge=ch_used, spin=0)
        problem = driver.run()
        ast = ActiveSpaceTransformer(num_electrons=4, num_spatial_orbitals=4)
        ap = ast.transform(problem)
        mapper = ParityMapper(num_particles=ap.num_particles)
        sparse_op = mapper.map(ap.hamiltonian.second_q_op())
        shift = float(sum(ap.hamiltonian.constants.values()))
        hf = HartreeFock(num_spatial_orbitals=4, num_particles=ap.num_particles, qubit_mapper=mapper)
        ucc = UCCSD(num_spatial_orbitals=4, num_particles=ap.num_particles, qubit_mapper=mapper, initial_state=hf, reps=1)
        print(f"[t={time.time()-t0:.0f}s] n_qubits={sparse_op.num_qubits} n_pauli={len(sparse_op.paulis)}", flush=True)
        mol = gto.M(atom=geom, basis="sto3g", charge=ch_used, spin=0, verbose=0)
        mf = scf.RHF(mol).run()
        casci = mcscf.CASCI(mf, ncas=4, nelecas=4); casci.verbose = 0; casci.kernel()
        e_casci = float(casci.e_tot)
        print(f"[t={time.time()-t0:.0f}s] CASCI={e_casci:+.6f} Ha", flush=True)
        best = None
        for optname, opt in [("SLSQP", SLSQP(maxiter=300)), ("L_BFGS_B", L_BFGS_B(maxiter=200))]:
            rng = np.random.default_rng(7)
            x0 = rng.normal(scale=0.05, size=ucc.num_parameters)
            vqe = VQE(estimator=StatevectorEstimator(), ansatz=ucc, optimizer=opt, initial_point=x0)
            res = vqe.compute_minimum_eigenvalue(sparse_op)
            e_vqe = float(res.eigenvalue.real) + shift
            delta = abs(e_vqe - e_casci) * 1e6
            print(f"  {optname}: delta={delta:.4f} uHa {'sub-uHa' if delta<1.0 else ('chem-acc' if delta<1600 else 'FAIL')}", flush=True)
            if best is None or delta < best[1]:
                best = (optname, delta)
        results[cid] = {"status": "OK", "n_qubits": sparse_op.num_qubits, "n_pauli": len(sparse_op.paulis),
                        "casci": e_casci, "best_optimizer": best[0], "best_delta_uha": best[1],
                        "chem_acc": best[1] < 1600, "sub_uha": best[1] < 1.0, "wall_sec": round(time.time()-t0, 1)}
    except Exception as exc:
        import traceback; traceback.print_exc()
        results[cid] = {"status": "FAIL", "error": str(exc)}

print("\n## JSON")
print(json.dumps(results, indent=2))
