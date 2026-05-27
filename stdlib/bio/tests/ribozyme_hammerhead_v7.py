"""iter 21 — hammerhead ribozyme catalytic-core pocket VQE (quantum x ribozyme axis bridge).

The hammerhead ribozyme cleaves its backbone by an in-line SN2(P) attack:
the 2'-O(-) of C17 attacks the adjacent scissile phosphate, with G12 as
general base (deprotonates the 2'-OH) and G8 2'-OH / hydrated metal as
general acid (protonates the 5'-O leaving group). Minimal hammerheads work
without divalent metals, so a metal-free cluster is mechanistically valid.

Cluster mimic = dimethyl phosphate anion (CH3O)2P(=O)O(-)  (the scissile
phosphodiester)  +  methanol CH3OH  (the C17 2'-OH nucleophile, placed
in-line opposite a bridging O for near-attack conformation)  +  NH3
(G12 general-base proxy, H-bonds the methanol O-H). total charge -1 / spin 0.
Recipe: timeout 600 + SLSQP maxiter=150 single optimizer (iter 16-20 pattern).
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

# dimethyl phosphate (-1):  P with =O, -O(-), and two -O-CH3 (one of which is the "leaving" 5'-O)
#   methanol O attacks P in-line opposite one O-CH3 bridge; NH3 H-bonds methanol O-H
GEOM = (
    "P 0.000 0.000 0.000; "       # phosphorus
    "O 0.000 1.500 0.300; "       # P=O (non-bridging)
    "O -1.300 -0.700 0.700; "     # P-O(-) (non-bridging anionic)
    "O 1.200 -0.600 -0.900; "     # bridging O -> CH3 'a' (5'-O leaving-group side)
    "C 2.500 -0.200 -1.300; "     # CH3 'a'
    "H 3.150 -0.350 -0.430; H 2.550 0.870 -1.530; H 2.880 -0.770 -2.160; "
    "O -0.500 -0.900 -1.250; "    # bridging O -> CH3 'b' (other 3' side)
    "C -0.300 -2.300 -1.550; "    # CH3 'b'
    "H -0.950 -2.600 -2.380; H -0.560 -2.900 -0.670; H 0.750 -2.500 -1.800; "
    # methanol nucleophile (in-line, opposite bridging-O-'a'): O comes from the -z,+? side toward P
    "O -1.200 1.000 -1.500; "     # methanol O (the C17 2'-O nucleophile, near P)
    "H -0.900 1.450 -2.300; "     # methanol O-H (donates to NH3)
    "C -2.600 1.300 -1.350; "     # methanol C
    "H -2.850 2.330 -1.620; H -3.200 0.650 -1.990; H -2.880 1.130 -0.300; "
    # NH3 (G12 general-base proxy) accepting the methanol O-H
    "N -0.100 1.900 -3.300; "     # NH3 N
    "H 0.850 1.650 -3.100; H -0.250 2.890 -3.150; H -0.300 1.700 -4.290"
)
t0 = time.time()
print('# iter21 hammerhead ribozyme core — (CH3O)2PO2(-) + MeOH nucleophile + NH3(G12 base proxy)', flush=True)

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
