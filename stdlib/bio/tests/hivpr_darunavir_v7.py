"""iter 20 — HIV-1 protease / darunavir catalytic-dyad pocket VQE.

HIV-1 PR is an aspartic protease: the Asp25/Asp25' dyad (one protonated,
one deprotonated) activates a water for peptide-bond hydrolysis. Darunavir
(2nd-gen PI) places its central (hydroxyethyl)sulfonamide OH between the
two Asp carboxyls (the transition-state-mimic interaction) + bis-THF group
H-bonds the flap/backbone. Cluster mimic = two acetic-acid/acetate units
(Asp25 = CH3COOH protonated, Asp25' = CH3COO- deprotonated) bridged by a
methanol (the darunavir central OH transition-state mimic). total charge -1
/ spin 0. Single localized H-bond network -> hope for n_pauli ~175.
Recipe: timeout 600 + SLSQP maxiter=150 single optimizer.
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

# Asp25 (CH3-COOH, protonated)  ...  CH3-OH (darunavir central OH)  ...  Asp25' (CH3-COO-)
GEOM = (
    # Asp25 acetic acid: C1(=O)(O-H) - C(H3)
    "C 0.000 0.000 0.000; "      # carboxyl C (Asp25)
    "O 0.700 1.050 0.150; "      # C=O
    "O -1.250 0.250 -0.300; "    # C-O(H)
    "H -1.500 -0.500 -0.800; "   # O-H (donates toward methanol O)
    "C -0.450 -1.420 0.350; "    # CH3 (Asp25)
    "H -1.530 -1.520 0.300; H -0.080 -1.580 1.360; H -0.030 -2.200 -0.280; "
    # darunavir central CH3-OH bridging
    "O -2.700 -0.900 -1.700; "   # methanol O (accepts Asp25 OH, donates to Asp25')
    "H -2.500 -1.500 -2.420; "   # methanol O-H
    "C -4.100 -0.700 -1.600; "   # methanol C
    "H -4.350 -0.100 -0.730; H -4.600 -1.660 -1.540; H -4.480 -0.180 -2.470; "
    # Asp25' acetate (-1): C(=O)(O-) - C(H3)
    "C -2.900 -3.350 -2.900; "   # carboxyl C (Asp25')
    "O -1.700 -3.500 -3.100; "   # C-O- (accepts methanol O-H)
    "O -3.750 -4.250 -3.050; "   # C=O
    "C -3.500 -2.000 -2.500; "   # CH3 (Asp25')
    "H -4.580 -2.000 -2.420; H -3.150 -1.250 -3.200; H -3.130 -1.730 -1.510"
)
t0 = time.time()
print('# iter20 HIV-1 protease / darunavir — Asp25/Asp25 dyad + central OH bridge', flush=True)

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
