"""iter 16 — HMG-CoA reductase pocket VQE, sp3-heavy mini-mevalonate cluster.

Per §15.2.q lesson: avoid aromatic rings + conjugated carbonyl chains.
Cluster = 3-hydroxy-3-methylbutanoate anion (mevalonate truncation, the
catalytic-relevant carboxyl + 3-OH + quaternary C) H-bonded to an NH3
(Lys ε-amine proxy of the HMGCR catalytic Lys). Single COO- only -> expect
n_pauli ~175 (formate/acetate-class), not 325.
"""
import json, time, numpy as np
from qiskit.primitives import StatevectorEstimator
from qiskit_algorithms import VQE
from qiskit_algorithms.optimizers import SLSQP, L_BFGS_B
from qiskit_nature.second_q.drivers import PySCFDriver
from qiskit_nature.second_q.mappers import ParityMapper
from qiskit_nature.second_q.transformers import ActiveSpaceTransformer
from qiskit_nature.second_q.circuit.library import HartreeFock, UCCSD
from pyscf import gto, scf, mcscf

# 3-hydroxy-3-methylbutanoate (-1)  +  NH3 (neutral) ; total charge -1, spin 0
#  C1(=O1a)(O1b-)  -  C2H2  -  C3(O3H)(C5H3)  -  C4H3        + NH3 near O1b
GEOM = (
    "C 0.000 0.000 0.000; "      # C1 carboxyl
    "O 0.900 0.800 0.000; "      # O1a
    "O -1.150 0.350 0.250; "     # O1b (anionic, accepts NH3)
    "C 0.300 -1.450 -0.200; "    # C2 (CH2)
    "C 1.700 -1.900 0.250; "     # C3 (quaternary, OH + CH3)
    "O 2.650 -1.250 -0.550; "    # O3 hydroxyl
    "C 1.900 -3.420 0.050; "     # C4 (CH3)
    "C 1.850 -1.600 1.760; "     # C5 (CH3 on C3)
    "N -2.300 1.750 -0.350; "    # NH3 nitrogen (Lys proxy)
    "H 0.150 -1.700 -1.270; H -0.420 -2.020 0.400; "          # C2 H2
    "H 2.500 -1.700 -1.480; "                                  # O3 H
    "H 1.200 -3.980 0.690; H 2.930 -3.700 0.300; H 1.700 -3.720 -0.990; "  # C4 H3
    "H 1.150 -2.150 2.400; H 2.870 -1.850 2.090; H 1.680 -0.540 1.980; "   # C5 H3
    "H -1.950 2.700 -0.150; H -2.450 1.700 -1.370; H -3.200 1.600 0.120"   # NH3 H3
)
t0 = time.time()
print('# iter16 HMG-CoA reductase — sp3 mini-mevalonate + NH3 (Lys proxy)', flush=True)

ch_used = -1
m = gto.M(atom=GEOM, basis='sto3g', charge=ch_used, spin=0, verbose=0)
nbas = m.nao_nr(); nelec = m.nelectron; natm = m.natm
print(f'natom={natm} charge={ch_used} nelec={nelec} nbas={nbas}', flush=True)

driver = PySCFDriver(atom=GEOM, basis='sto3g', charge=ch_used, spin=0)
problem = driver.run()
ast = ActiveSpaceTransformer(num_electrons=4, num_spatial_orbitals=4)
ap = ast.transform(problem)
mapper = ParityMapper(num_particles=ap.num_particles)
sparse_op = mapper.map(ap.hamiltonian.second_q_op())
shift = float(sum(ap.hamiltonian.constants.values()))
hf = HartreeFock(num_spatial_orbitals=4, num_particles=ap.num_particles, qubit_mapper=mapper)
ucc = UCCSD(num_spatial_orbitals=4, num_particles=ap.num_particles, qubit_mapper=mapper, initial_state=hf, reps=1)
print(f'[t={time.time()-t0:.0f}s] n_qubits={sparse_op.num_qubits} n_pauli={len(sparse_op.paulis)} n_params={ucc.num_parameters}', flush=True)

mol = gto.M(atom=GEOM, basis='sto3g', charge=ch_used, spin=0, verbose=0)
mf = scf.RHF(mol).run()
casci = mcscf.CASCI(mf, ncas=4, nelecas=4); casci.verbose = 0; casci.kernel()
e_casci = float(casci.e_tot)
print(f'[t={time.time()-t0:.0f}s] CASCI={e_casci:+.6f} Ha. VQE start...', flush=True)

best = None
for name, opt in [('SLSQP', SLSQP(maxiter=150))]:
    rng = np.random.default_rng(7)
    x0 = rng.normal(scale=0.05, size=ucc.num_parameters)
    vqe = VQE(estimator=StatevectorEstimator(), ansatz=ucc, optimizer=opt, initial_point=x0)
    res = vqe.compute_minimum_eigenvalue(sparse_op)
    e_vqe = float(res.eigenvalue.real) + shift
    delta = abs(e_vqe - e_casci) * 1e6
    print(f'[t={time.time()-t0:.0f}s] {name}: delta={delta:.4f} µHa', flush=True)
    if best is None or delta < best[1]:
        best = (name, delta, e_vqe)

name, delta, e_vqe = best
sub = delta < 1.0; chem = delta < 1600
mark = '⭐ sub-µHa' if sub else ('✅ chem-acc' if chem else '❌ FAIL')
print(f'[t={time.time()-t0:.0f}s] BEST {name} delta={delta:.4f} µHa {mark}', flush=True)
print(json.dumps({
    'natom': natm, 'charge': ch_used, 'nelec': nelec, 'nbas': nbas,
    'n_qubits': sparse_op.num_qubits, 'n_pauli': len(sparse_op.paulis),
    'casci': e_casci, 'vqe': e_vqe, 'delta_uha': delta,
    'sub_uha': bool(sub), 'chem_acc': bool(chem),
    'best_optimizer': name, 'wall_sec': round(time.time()-t0, 1)
}, indent=2))
