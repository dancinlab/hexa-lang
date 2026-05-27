"""iter 22 — M. tuberculosis InhA (enoyl-ACP reductase) / isoniazid pocket VQE.

InhA is the validated isoniazid target: KatG activates INH to an INH-NAD
adduct, and InhA normally uses NADH to reduce the enoyl-ACP double bond
via hydride transfer from the NADH 1,4-dihydronicotinamide C4, with Tyr158
+ NAD 2'-OH stabilizing the enolate intermediate. Cluster mimic = the
1,4-dihydronicotinamide (NADH "business end", hydride donor) + methanol
(Tyr158 phenol-OH proxy, H-bonds the carboxamide). charge 0 / spin 0.
Recipe: timeout 600 + SLSQP maxiter=150 single optimizer (iter 16-21 pattern).
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

# 1,4-dihydronicotinamide ring: N1(H)-C2(H)=C3(-CONH2)-C4(H2 sp3)-C5(H)=C6(H)
#   + methanol O-H ... H-bonds the carboxamide C=O (Tyr158 proxy)
GEOM = (
    "N 0.000 0.000 0.000; "       # N1 (ring, H-bearing)
    "C 1.350 0.150 0.050; "       # C2 (=C3)
    "C 2.050 -1.000 0.000; "      # C3 (bears carboxamide)
    "C 1.350 -2.350 -0.100; "     # C4 (sp3, hydride donor — 2 H)
    "C -0.050 -2.300 0.150; "     # C5 (=C6)
    "C -0.700 -1.150 0.050; "     # C6
    "H -0.500 0.870 0.000; "      # N1-H
    "H 1.880 1.100 0.100; "       # C2-H
    "H 1.550 -2.800 -1.080; H 1.800 -3.000 0.660; "   # C4 H2 (sp3)
    "H -0.620 -3.230 0.200; "     # C5-H
    "H -1.780 -1.100 0.080; "     # C6-H
    # carboxamide on C3:  C(=O)-NH2
    "C 3.550 -0.900 -0.050; "     # carboxamide C
    "O 4.200 -1.950 -0.100; "     # C=O
    "N 4.200 0.300 -0.050; "      # carboxamide N
    "H 5.210 0.380 -0.080; H 3.700 1.170 -0.020; "    # NH2
    # methanol (Tyr158 proxy) H-bonding the carbonyl O
    "O 5.600 -3.000 -0.200; "     # methanol O
    "H 5.350 -2.350 -0.700; "     # methanol O-H (donates to carboxamide C=O)
    "C 6.950 -2.700 0.150; "      # methanol C
    "H 7.200 -1.700 -0.230; H 7.600 -3.450 -0.330; H 7.150 -2.760 1.230"
)
t0 = time.time()
print('# iter22 M.tb InhA / isoniazid — 1,4-dihydronicotinamide(NADH core) + methanol(Tyr158 proxy)', flush=True)

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
