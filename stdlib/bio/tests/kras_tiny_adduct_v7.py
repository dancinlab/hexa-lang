"""KRAS-G12C tiny cluster — Cys-acrylamide covalent fragment only."""
import json, time, numpy as np
from qiskit.primitives import StatevectorEstimator
from qiskit_algorithms import VQE
from qiskit_algorithms.optimizers import SLSQP
from qiskit_nature.second_q.drivers import PySCFDriver
from qiskit_nature.second_q.mappers import ParityMapper
from qiskit_nature.second_q.transformers import ActiveSpaceTransformer
from qiskit_nature.second_q.circuit.library import HartreeFock, UCCSD
from pyscf import gto, scf, mcscf

# Cys-acrylamide covalent adduct mimic — minimal Michael addition product
# CH3-S-CH2-CH2-C(=O)-NH2  (thioether + propanamide = post-warhead adduct)
GEOM = (
    "C 0.000 0.000 0.000; "
    "S 1.700 0.000 0.000; "
    "C 2.500 1.500 0.000; "
    "C 3.900 1.500 0.000; "
    "C 4.700 2.700 0.000; "
    "O 4.200 3.800 0.000; "
    "N 6.100 2.700 0.000; "
    "H -0.400 -1.000 0.000; H -0.400 0.500 0.870; H -0.400 0.500 -0.870; "
    "H 2.100 2.000 0.870; H 2.100 2.000 -0.870; "
    "H 4.300 1.000 0.870; H 4.300 1.000 -0.870; "
    "H 6.600 3.500 0.000; H 6.600 1.900 0.000"
)
t0 = time.time()
print('# §15.2.p KRAS-G12C tiny — Cys-acrylamide adduct (covalent Michael)', flush=True)
for ch in [0, 1, -1]:
    try:
        m = gto.M(atom=GEOM, basis='sto3g', charge=ch, spin=0, verbose=0)
        if m.spin == 0:
            ch_used=ch; nbas=m.nao_nr(); nelec=m.nelectron; natm=m.natm
            print(f'natom={natm} charge={ch} nelec={nelec} nbas={nbas}', flush=True); break
    except: pass

driver = PySCFDriver(atom=GEOM, basis='sto3g', charge=ch_used, spin=0)
problem = driver.run()
ast = ActiveSpaceTransformer(num_electrons=4, num_spatial_orbitals=4)
ap = ast.transform(problem)
mapper = ParityMapper(num_particles=ap.num_particles)
sparse_op = mapper.map(ap.hamiltonian.second_q_op())
shift = float(sum(ap.hamiltonian.constants.values()))
hf = HartreeFock(num_spatial_orbitals=4, num_particles=ap.num_particles, qubit_mapper=mapper)
ucc = UCCSD(num_spatial_orbitals=4, num_particles=ap.num_particles, qubit_mapper=mapper, initial_state=hf, reps=1)
print(f'[t={time.time()-t0:.0f}s] n_qubits={sparse_op.num_qubits} n_pauli={len(sparse_op.paulis)}', flush=True)

mol = gto.M(atom=GEOM, basis='sto3g', charge=ch_used, spin=0, verbose=0)
mf = scf.RHF(mol).run()
casci = mcscf.CASCI(mf, ncas=4, nelecas=4); casci.verbose=0; casci.kernel()
e_casci = float(casci.e_tot)
print(f'[t={time.time()-t0:.0f}s] CASCI={e_casci:+.6f} Ha. VQE start...', flush=True)

rng = np.random.default_rng(7)
x0 = rng.normal(scale=0.05, size=ucc.num_parameters)
vqe = VQE(estimator=StatevectorEstimator(), ansatz=ucc, optimizer=SLSQP(maxiter=300), initial_point=x0)
res = vqe.compute_minimum_eigenvalue(sparse_op)
e_vqe = float(res.eigenvalue.real) + shift
delta = abs(e_vqe - e_casci) * 1e6
sub = delta < 1.0
chem = delta < 1600
mark = '⭐ sub-µHa' if sub else ('✅ chem-acc' if chem else '❌ FAIL')
print(f'[t={time.time()-t0:.0f}s] DONE delta={delta:.4f} µHa {mark}', flush=True)
print(json.dumps({
    'natom': natm, 'charge': ch_used, 'nelec': nelec, 'nbas': nbas,
    'n_qubits': sparse_op.num_qubits, 'n_pauli': len(sparse_op.paulis),
    'casci': e_casci, 'vqe': e_vqe, 'delta_uha': delta,
    'sub_uha': bool(sub), 'chem_acc': bool(chem),
    'wall_sec': round(time.time()-t0, 1), 'optimizer': 'SLSQP'
}, indent=2))
