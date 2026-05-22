"""iter 17 — lung TGF-beta / ALK5 (TGFBR1) kinase ATP-hinge pocket VQE.

Cluster mimic = imidazole (His283 side chain, the canonical ALK5 hinge
H-bond residue) + formamide (hinge backbone peptide-bond proxy, the
N-H / C=O that type-1 inhibitors like galunisertib/SB-431542 read).
charge 0 / spin 0. Aromatic ring present -> n_pauli 325 expected
(per §15.2 paradigm); use the iter-16 dedicated-run recipe:
timeout 600 + SLSQP maxiter=150, single optimizer.
"""
import json, time, numpy as np
from qiskit.primitives import StatevectorEstimator
from qiskit_algorithms import VQE
from qiskit_algorithms.optimizers import SLSQP
from qiskit_nature.second_q.drivers import PySCFDriver
from qiskit_nature.second_q.mappers import ParityMapper
from qiskit_nature.second_q.transformers import ActiveSpaceTransformer
from qiskit_nature.second_q.circuit.library import HartreeFock, UCCSD
from pyscf import gto, scf, mcscf

# imidazole (N1H, C2H, N3, C4H, C5H)  ...H-bond...  formamide (HC(=O)NH2)
# imidazole N1-H donates to formamide O; formamide N-H donates to imidazole N3
GEOM = (
    "N 0.000 0.000 0.000; "      # N1 (imidazole, H-bearing)
    "C 1.130 0.760 0.000; "      # C2
    "N 2.230 0.000 0.000; "      # N3 (imidazole, pyridine-like)
    "C 1.800 -1.280 0.000; "     # C4
    "C 0.430 -1.300 0.000; "     # C5
    "H -0.920 0.380 0.000; "     # N1-H
    "H 1.150 1.840 0.000; "      # C2-H
    "H 2.440 -2.130 0.000; "     # C4-H
    "H -0.230 -2.150 0.000; "    # C5-H
    "C -3.050 1.450 0.100; "     # formamide carbonyl C
    "O -2.350 0.420 0.150; "     # formamide O (accepts N1-H of imidazole)
    "N -4.400 1.400 0.050; "     # formamide N
    "H -2.560 2.430 0.100; "     # formamide C-H
    "H -4.900 0.520 0.000; "     # formamide N-H (donates toward N3 region)
    "H -4.950 2.250 0.050"       # formamide N-H'
)
t0 = time.time()
print('# iter17 lung TGF-beta / ALK5 ATP-hinge — imidazole(His283) + formamide(backbone)', flush=True)

ch_used = 0
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

rng = np.random.default_rng(7)
x0 = rng.normal(scale=0.05, size=ucc.num_parameters)
vqe = VQE(estimator=StatevectorEstimator(), ansatz=ucc, optimizer=SLSQP(maxiter=150), initial_point=x0)
res = vqe.compute_minimum_eigenvalue(sparse_op)
e_vqe = float(res.eigenvalue.real) + shift
delta = abs(e_vqe - e_casci) * 1e6
sub = delta < 1.0; chem = delta < 1600
mark = '⭐ sub-µHa' if sub else ('✅ chem-acc' if chem else '❌ FAIL')
print(f'[t={time.time()-t0:.0f}s] DONE delta={delta:.4f} µHa {mark}', flush=True)
print(json.dumps({
    'natom': natm, 'charge': ch_used, 'nelec': nelec, 'nbas': nbas,
    'n_qubits': sparse_op.num_qubits, 'n_pauli': len(sparse_op.paulis),
    'casci': e_casci, 'vqe': e_vqe, 'delta_uha': delta,
    'sub_uha': bool(sub), 'chem_acc': bool(chem),
    'optimizer': 'SLSQP/150', 'wall_sec': round(time.time()-t0, 1)
}, indent=2))
