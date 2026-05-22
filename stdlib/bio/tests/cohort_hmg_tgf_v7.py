"""HMG-CoA + TGF-beta pocket VQE — SLSQP-only, smaller saturated geoms (v7.1 loop iter 15b)."""
import json, time, numpy as np
from qiskit.primitives import StatevectorEstimator
from qiskit_algorithms import VQE
from qiskit_algorithms.optimizers import SLSQP
from qiskit_nature.second_q.drivers import PySCFDriver
from qiskit_nature.second_q.mappers import ParityMapper
from qiskit_nature.second_q.transformers import ActiveSpaceTransformer
from qiskit_nature.second_q.circuit.library import HartreeFock, UCCSD
from pyscf import gto, scf, mcscf

COHORTS = {
  # mi hxq-mi-hmg-001 — HMG fragment (3-OH-3-Me-glutaryl, saturated) + Lys ammonium mimic — aim n_pauli ~175
  "hxq-mi-hmg-001": (
    "C 0.0 0.0 0.0; C 1.5 0.0 0.0; O 1.9 1.3 0.0; C 1.5 -1.4 0.7; C 3.0 0.0 -0.5; "
    "O 3.4 1.1 -1.0; O 3.7 -1.1 -0.5; "
    "H -0.4 0.9 0.4; H -0.4 -0.9 0.4; H -0.4 0.0 -1.0; "
    "H 1.4 2.0 0.5; H 1.1 -2.2 0.1; H 1.0 -1.4 1.7; H 2.6 -1.4 0.8; "
    "N -1.4 0.0 0.5; H -1.8 0.8 0.1; H -1.8 -0.8 0.1; H -1.8 0.0 1.4"
  ),
  # lung hxq-ln-tgf-001 — ALK5 ATP hinge: small saturated fragment (no full purine) — Ser-OH + Asn amide + methyl ether
  "hxq-ln-tgf-001": (
    "C 0.0 0.0 0.0; O 1.4 0.0 0.0; C 2.1 1.2 0.0; "
    "C 0.0 1.5 0.0; O -1.3 1.7 0.0; "
    "C -0.7 -1.3 0.0; O 0.0 -2.4 0.0; N -2.0 -1.4 0.0; "
    "H -0.4 -0.5 0.9; H -0.4 -0.5 -0.9; "
    "H 1.7 1.8 0.85; H 1.7 1.8 -0.85; H 3.2 1.1 0.0; "
    "H 0.5 2.1 0.8; H -1.7 1.0 0.0; "
    "H -2.5 -0.6 0.0; H -2.5 -2.2 0.0"
  ),
}
results = {}
for cid, geom in COHORTS.items():
    t0 = time.time()
    print(f"\n# === {cid} ===", flush=True)
    ch_used = None
    for ch in [0, 1, -1, 2, -2]:
        try:
            m = gto.M(atom=geom, basis="sto3g", charge=ch, spin=0, verbose=0)
            if m.spin == 0:
                ch_used = ch; print(f"natom={m.natm} charge={ch} nelec={m.nelectron} nbas={m.nao_nr()}", flush=True); break
        except Exception: continue
    if ch_used is None:
        results[cid] = {"status": "FAIL-charge"}; print("  no charge", flush=True); continue
    try:
        driver = PySCFDriver(atom=geom, basis="sto3g", charge=ch_used, spin=0)
        ap = ActiveSpaceTransformer(num_electrons=4, num_spatial_orbitals=4).transform(driver.run())
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
        rng = np.random.default_rng(7)
        x0 = rng.normal(scale=0.05, size=ucc.num_parameters)
        vqe = VQE(estimator=StatevectorEstimator(), ansatz=ucc, optimizer=SLSQP(maxiter=250), initial_point=x0)
        res = vqe.compute_minimum_eigenvalue(sparse_op)
        e_vqe = float(res.eigenvalue.real) + shift
        delta = abs(e_vqe - e_casci) * 1e6
        tag = "sub-uHa" if delta < 1.0 else ("chem-acc" if delta < 1600 else "FAIL")
        print(f"[t={time.time()-t0:.0f}s] SLSQP delta={delta:.4f} uHa {tag}", flush=True)
        results[cid] = {"status": "OK", "n_qubits": sparse_op.num_qubits, "n_pauli": len(sparse_op.paulis),
                        "casci": e_casci, "delta_uha": delta, "chem_acc": delta < 1600, "sub_uha": delta < 1.0,
                        "wall_sec": round(time.time()-t0, 1)}
    except Exception as exc:
        import traceback; traceback.print_exc()
        results[cid] = {"status": "FAIL", "error": str(exc)}
print("\n## JSON")
print(json.dumps(results, indent=2))
