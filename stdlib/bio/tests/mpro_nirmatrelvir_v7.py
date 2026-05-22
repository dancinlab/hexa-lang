"""iter 18 — SARS-CoV-2 Mpro (3CLpro) / nirmatrelvir covalent adduct pocket VQE.

F-Q-6 named target (5-axis quantum-axis). nirmatrelvir (Paxlovid) inhibits
Mpro by its nitrile warhead being attacked by the Cys145 thiolate ->
reversible covalent thioimidate (S-C(=NH)-), with His41 the general base.
Cluster mimic = S-methyl thioacetimidate CH3-S-C(=NH)-CH3 (the Cys145
side-chain methylene-S + the warhead-derived thioimidate carbon) +
imidazole (His41 catalytic base, H-bonds the =NH). charge 0 / spin 0.
Recipe: timeout 600 + SLSQP maxiter=150 single optimizer (iter 16/17 pattern).
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

# CH3-S-C(=NH)-CH3  (S-methyl thioacetimidate, Cys145+warhead adduct)
#   ...=NH H-bonds to imidazole N3 (His41)...  imidazole N1-H free
GEOM = (
    "C 0.000 0.000 0.000; "      # C1 (S-CH3 of Cys145 proxy)
    "S 1.760 0.200 0.300; "      # S (Cys145 thioether sulfur)
    "C 2.400 1.850 -0.200; "     # C2 (thioimidate carbon, ex-nitrile of nirmatrelvir)
    "N 3.700 2.050 -0.450; "     # N (=NH imine nitrogen)
    "C 1.550 3.050 -0.450; "     # C3 (acyl-side CH3 proxy, the P1 ketoamide stub)
    "H 4.150 1.250 -0.850; "     # =N-H (donates to imidazole N3)
    "H -0.350 -1.030 0.150; H -0.480 0.430 -0.890; H -0.350 0.560 0.880; "  # C1 H3
    "H 0.480 2.920 -0.250; H 1.700 3.220 -1.530; H 1.900 3.940 0.090; "     # C3 H3
    "N 6.050 2.300 -0.700; "     # imidazole N3 (accepts =N-H)
    "C 6.950 1.350 -0.350; "     # C5
    "C 8.250 1.800 -0.620; "     # C4
    "N 8.150 3.080 -1.160; "     # N1 (H-bearing)
    "C 6.830 3.380 -1.200; "     # C2 (imidazole)
    "H 6.650 0.380 0.050; "      # C5-H
    "H 9.190 1.310 -0.430; "     # C4-H
    "H 8.910 3.700 -1.430; "     # N1-H
    "H 6.380 4.300 -1.560"       # C2-H
)
t0 = time.time()
print('# iter18 SARS-CoV-2 Mpro / nirmatrelvir — Cys145-thioimidate adduct + imidazole(His41)', flush=True)

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
vqe = VQE(estimator=StatevectorEstimator(), ansatz=ucc, optimizer=L_BFGS_B(maxiter=200), initial_point=x0)
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
    'optimizer': 'L_BFGS_B/200', 'wall_sec': round(time.time()-t0, 1)
}, indent=2))
