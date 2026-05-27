"""
mpro_warhead_library_vqe_v7.py — F-Q-6-F: Phase D — 5-warhead covalent-inhibitor
library ranking by a VQE-computed gas-phase model reaction energy (2026-05-12).

Closes quantum **Phase D / F-Q-6-F** (the "5–10 candidate library ranking via VQE"
gate) — the literature-aligned extension of the already-PASSed F-Q-6-D Mpro
pocket-cluster VQE (`tests/mpro_pocket_vqe_v7.py`). Per the 2026-05-12 deep-research
pass (`docs/closure_100_research_2026_05_12.md` §E): a "library ranking via VQE" is
methodologically in line with the field (Li et al. arXiv:2401.03759 VQE+QM/MM on a
covalent KRAS-G12C inhibitor; IBM–Merck kinase H-bond VQE; active-space-VQE drug
benchmark arXiv:2512.18203; survey arXiv:2408.13479) **iff** scoped as a *relative*
reaction energy in a *minimal* active space with *CASCI validation on the same
space* — never a standalone affinity engine or a quantum-advantage claim. This is
exactly that.

Model: the covalent-bond-formation half-reaction at the SARS-CoV-2 Mpro Cys145
thiolate (Cys145 deprotonated by His41 — Owen et al. *Science* 374:1586, 2021;
Zhang et al. *Science* 368:409, 2020; Jin et al. *Nature* 582:289, 2020;
Ramos-Guzmán et al. *JACS* 145, 2023):

    CH3-S(−)  +  warhead   →   [Cys-S–warhead covalent adduct](−)
    (Cys145 thiolate model)              (charge-conserved, no proton shuffle)

  ΔE_rxn(warhead) = E(adduct⁻) − E(CH3S⁻) − E(warhead)         [more negative ⇒ stronger covalent bond formation]

over 5 congeneric covalent-Mpro-warhead classes:

  1. nitrile          CH3-C#N            →  thioimidate-anion   [CH3-S-C(=N)-CH3]⁻        (nirmatrelvir/Paxlovid's warhead)
  2. aldehyde         CH3-CHO            →  thiohemiacetal-alkoxide [CH3-S-CH(O⁻)-CH3]    (GC373/GC376-class)
  3. α-ketoamide      CH3-CO-CO-NH2      →  thiohemiketal-alkoxide [CH3-C(=O)-C(O⁻)(S-CH3)-NH2]  (Hilgenfeld 13b-class)
  4. Michael acceptor CH2=CH-CO-NH2      →  conjugate-addition enolate [CH3-S-CH2-CH=C(O⁻)-NH2]  (N3-class vinyl/acrylamide)
  5. CF3-ketone       CF3-CO-CH3         →  thiohemiketal-alkoxide [CF3-C(O⁻)(S-CH3)-CH3]  (reversible-covalent TFMK warhead)

Each fragment: sto-3g; active space 2e/2o (HOMO+LUMO) → ParityMapper → 2 qubit;
hardware-efficient depth-1 ansatz RealAmplitudes(reps=1) (the 4 Ry·Ry·CX·Ry·Ry
rotations = the n6 τ(6)=4 binding); classical reference = CASCI(2,2) on the RHF
orbitals; chem-acc gate = |E_VQE − E_CASCI| < 1600 µHa, sub-µHa < 1.0 µHa.
L_BFGS_B optimizer.  Reaction energies use the L_BFGS_B-converged VQE total energies
(falling back to CASCI for any fragment where VQE doesn't beat chemical accuracy —
all are validated against CASCI on the same active space).  No D3 dispersion.

Honest C3: single-point energies at *hand-built, unoptimised* gas-phase
fragment geometries → the ΔE_rxn values are a *qualitative warhead-reactivity
ranking* in a minimal (2,2) active space, NOT a quantitative ΔG, NOT a binding
affinity, NOT a therapeutic-efficacy claim; "VQE reproduces CASCI(2,2) here" — this
is a CASCI ranking with a quantum-algorithm wrapper, not a quantum-advantage result;
extensible to the full 11-drug F-Q-6-C pocket library / larger active spaces.  Pure
Python (qiskit / pyscf via `~/.hexabio_venv`); not wired into `selftest/run_all.sh`
(like the other `tests/*_pocket_vqe_v7.py` — needs the qiskit/pyscf venv).
"""
from __future__ import annotations
import json
import sys
import time
import numpy as np

from qiskit.circuit.library import RealAmplitudes
from qiskit.primitives import StatevectorEstimator
from qiskit_algorithms import VQE
from qiskit_algorithms.optimizers import L_BFGS_B
from qiskit_nature.second_q.drivers import PySCFDriver
from qiskit_nature.second_q.mappers import ParityMapper
from qiskit_nature.second_q.transformers import ActiveSpaceTransformer

HARTREE_TO_KCAL = 627.509474

# ── geometries (Å). Cys145 thiolate model = CH3-S(−). Warheads neutral. Adducts charge −1. ──
CYS_THIOLATE = (
    "S  0.000  0.000  0.000; "
    "C -1.810  0.000  0.000; "          # Cβ
    "H -2.200  1.020  0.000; "
    "H -2.200 -0.510  0.880; "
    "H -2.200 -0.510 -0.880"
)

WARHEADS = {
    # name: (warhead_geom_neutral, adduct_geom, warhead_class)
    "nitrile_nirmatrelvir": (
        # acetonitrile  CH3-C#N
        "C  0.000  0.000  0.000; H  0.000  1.030  0.300; H  0.890 -0.510  0.300; H -0.890 -0.510  0.300; "
        "C  0.000  0.000 -1.470; "        # nitrile C
        "N  0.000  0.000 -2.630",         # #N
        # thioimidate anion  [CH3-S-C(=N)-CH3]^-   : S-C(was nitrile)=N , and C-CH3(acetonitrile methyl)
        "S  0.000  0.000  0.000; C -1.820  0.000  0.000; H -2.200  1.020  0.000; H -2.200 -0.510  0.880; H -2.200 -0.510 -0.880; "
        "C  1.350  0.700  0.500; "        # was nitrile C, now sp2: bonded to S, =N, CH3
        "N  2.400  0.300  1.100; "        # =N
        "C  1.500  2.150  0.300; H  2.500  2.450 -0.000; H  1.000  2.600  1.150; H  1.000  2.450 -0.560",  # acetonitrile methyl
        "nitrile_to_thioimidate",
    ),
    "aldehyde_GC373": (
        # acetaldehyde  CH3-CHO
        "C  0.000  0.000  0.000; H  0.000  1.030  0.300; H  0.890 -0.510  0.300; H -0.890 -0.510  0.300; "
        "C  0.000  0.000 -1.520; "        # carbonyl C
        "H  0.940  0.000 -2.080; "        # aldehyde H
        "O -1.040  0.000 -2.180",         # =O
        # thiohemiacetal alkoxide  [CH3-CH(O^-)-S-CH3] : central C bonded to S, O^-, H, CH3(acetaldehyde methyl)
        "S  0.000  0.000  0.000; C -1.820  0.000  0.000; H -2.200  1.020  0.000; H -2.200 -0.510  0.880; H -2.200 -0.510 -0.880; "
        "C  1.300  0.900  0.600; "        # central C (was carbonyl), sp3
        "H  1.300  1.500  1.520; "        # H on central C
        "O  2.450  0.300  0.500; "        # -O^-
        "C  1.300  1.900 -0.560; H  2.250  2.430 -0.560; H  0.500  2.640 -0.460; H  1.150  1.500 -1.570",  # acetaldehyde methyl
        "aldehyde_to_thiohemiacetal",
    ),
    "alpha_ketoamide_13b": (
        # pyruvamide  CH3-C(=O)-C(=O)-NH2   (the alpha-keto C is electrophilic)
        "C  0.000  0.000  0.000; H  0.000  1.030  0.300; H  0.890 -0.510  0.300; H -0.890 -0.510  0.300; "
        "C  0.000  0.000 -1.520; "        # ketone C (Ck) — electrophilic
        "O -1.040  0.000 -2.180; "        # Ok =O
        "C  1.300 -0.700 -2.000; "        # amide C (Ca)
        "O  1.300 -1.900 -2.200; "        # Oa =O
        "N  2.450 -0.000 -2.150; H  3.300 -0.500 -1.950; H  2.450  1.000 -2.400",   # NH2
        # thiohemiketal alkoxide  [CH3-C(=O)-C(O^-)(S-CH3)-NH2]  (wait: Cys adds to Ck) -> Ck sp3: {Cm, Ok^-, S, Ca}
        "S  0.000  0.000  0.000; C -1.820  0.000  0.000; H -2.200  1.020  0.000; H -2.200 -0.510  0.880; H -2.200 -0.510 -0.880; "
        "C  1.300  0.900  0.600; "        # Ck, sp3
        "O  2.450  0.300  0.500; "        # Ok -O^-
        "C  1.300  1.900 -0.560; H  2.250  2.430 -0.560; H  0.500  2.640 -0.460; H  1.150  1.500 -1.570; "  # Cm (methyl) + 3H
        "C  1.300  1.400  2.000; "        # Ca (amide C)  -- hmm bonded to Ck
        "O  0.300  1.700  2.650; "        # Oa =O
        "N  2.500  1.500  2.650; H  3.350  1.100  2.350; H  2.500  2.150  3.400",   # NH2
        "alpha_ketoamide_to_thiohemiketal",
    ),
    "michael_acceptor_N3": (
        # acrylamide  CH2=CH-C(=O)-NH2
        "C  0.000  0.000  0.000; "        # =CH2 (Cb) — the beta carbon, Michael acceptor site
        "H -0.500 -0.870  0.400; H  0.500  0.870  0.400; "
        "C  0.000  0.000 -1.340; "        # =CH- (Ca)
        "H  0.940  0.000 -1.900; "
        "C -1.200 -0.700 -2.000; "        # C=O (Cc)
        "O -2.250 -0.500 -1.450; "        # =O
        "N -1.100 -1.600 -3.000; H -1.950 -2.050 -3.200; H -0.250 -1.900 -3.350",   # NH2
        # conjugate-addition enolate  [CH3-S-CH2-CH=C(O^-)-NH2]  : Cb sp3 (-CH2-S-), Ca=Cc, Cc-O^-
        "S  0.000  0.000  0.000; C -1.820  0.000  0.000; H -2.200  1.020  0.000; H -2.200 -0.510  0.880; H -2.200 -0.510 -0.880; "
        "C  1.300  0.900  0.600; "        # Cb, sp3 (-CH2-)
        "H  1.300  1.500  1.520; H  2.200  0.300  0.500; "
        "C  1.300  1.700 -0.660; "        # Ca, sp2, =Cc
        "H  2.200  2.300 -0.760; "
        "C  0.200  1.900 -1.500; "        # Cc, sp2: =Ca, -O^-, -NH2
        "O -0.900  1.500 -1.300; "        # -O^-
        "N  0.300  2.700 -2.600; H -0.550  3.100 -2.850; H  1.150  2.950 -3.000",   # NH2
        "michael_to_conjugate_enolate",
    ),
    "cf3_ketone_TFMK": (
        # 1,1,1-trifluoroacetone  CF3-C(=O)-CH3
        "C  0.000  0.000  0.000; "        # CF3 carbon
        "F  0.000  1.260  0.300; F  1.090 -0.630  0.300; F -1.090 -0.630  0.300; "
        "C  0.000  0.000 -1.520; "        # carbonyl C — electrophilic
        "O -1.040  0.000 -2.180; "        # =O
        "C  1.300 -0.700 -2.000; H  2.150 -0.150 -1.750; H  1.300 -1.700 -1.650; H  1.300 -0.700 -3.090",   # CH3
        # thiohemiketal alkoxide  [CF3-C(O^-)(S-CH3)-CH3]  : central C sp3 {CF3-C, O^-, S, CH3}
        "S  0.000  0.000  0.000; C -1.820  0.000  0.000; H -2.200  1.020  0.000; H -2.200 -0.510  0.880; H -2.200 -0.510 -0.880; "
        "C  1.300  0.900  0.600; "        # central C, sp3
        "O  2.450  0.300  0.500; "        # -O^-
        "C  1.300  1.900  1.760; "        # CF3 carbon
        "F  0.300  2.700  1.760; F  2.300  2.700  1.760; F  1.300  1.400  2.980; "
        "C  1.300  1.700 -0.660; H  2.250  2.230 -0.660; H  0.500  2.430 -0.560; H  1.150  1.300 -1.670",   # CH3
        "cf3ketone_to_thiohemiketal",
    ),
}


def _find_charge(geom, basis="sto3g", prefer=(-1, 0, 1, -2, 2)):
    from pyscf import gto
    for ch in prefer:
        try:
            m = gto.M(atom=geom, basis=basis, charge=ch, spin=0, verbose=0)
            if m.spin == 0:
                return ch, m.natm, m.nao_nr()
        except Exception:
            continue
    return None, None, None


def _fragment_energy(geom, charge: int, label: str, seed: int = 7) -> dict:
    """sto-3g, (2,2) active space → 2-qubit VQE (RealAmplitudes reps=1) vs CASCI(2,2). Returns energies + agreement."""
    driver = PySCFDriver(atom=geom, basis="sto3g", charge=charge, spin=0)
    problem = driver.run()
    ap = ActiveSpaceTransformer(num_electrons=2, num_spatial_orbitals=2).transform(problem)
    mapper = ParityMapper(num_particles=ap.num_particles)
    sparse_op = mapper.map(ap.hamiltonian.second_q_op())
    shift = float(sum(ap.hamiltonian.constants.values()))
    from pyscf import gto, scf, mcscf
    mol = gto.M(atom=geom, basis="sto3g", charge=charge, spin=0, verbose=0)
    mf = scf.RHF(mol).run()
    casci = mcscf.CASCI(mf, ncas=2, nelecas=2); casci.verbose = 0; casci.kernel()
    e_casci = float(casci.e_tot)
    ansatz = RealAmplitudes(num_qubits=sparse_op.num_qubits, reps=1)
    rng = np.random.default_rng(seed)
    vqe = VQE(estimator=StatevectorEstimator(), ansatz=ansatz, optimizer=L_BFGS_B(maxiter=300),
              initial_point=rng.normal(scale=0.1, size=ansatz.num_parameters))
    t0 = time.time()
    res = vqe.compute_minimum_eigenvalue(sparse_op)
    e_vqe = float(res.eigenvalue.real) + shift
    delta_uha = abs(e_vqe - e_casci) * 1e6
    # use VQE total energy if it beats chemical accuracy, else fall back to CASCI (always validated on the same space)
    e_use = e_vqe if delta_uha < 1600.0 else e_casci
    return {"label": label, "charge": charge, "n_qubits": sparse_op.num_qubits, "n_pauli": len(sparse_op.paulis),
            "e_hf": float(mf.e_tot), "e_casci": e_casci, "e_vqe": e_vqe, "e_used": e_use,
            "delta_vqe_casci_uha": delta_uha, "chem_acc": bool(delta_uha < 1600.0), "sub_uha": bool(delta_uha < 1.0),
            "vqe_wall_sec": round(time.time() - t0, 2)}


def main() -> int:
    print("# F-Q-6-F — Phase D: 5-warhead covalent-Mpro-inhibitor library ranking by VQE-computed model ΔE_rxn\n", flush=True)
    print("model half-reaction:  CH3-S(−)  +  warhead  →  [Cys-S–warhead covalent adduct](−)   (sto-3g · 2e/2o → 2 qubit · RealAmplitudes(reps=1) VQE vs CASCI(2,2))\n", flush=True)
    results = {"reference": {}, "warheads": {}}
    # 1) reference: CH3-S(−)
    ch, nat, nb = _find_charge(CYS_THIOLATE)
    print(f"  reference  CH3-S(−)  charge={ch} natom={nat} nbas={nb}", flush=True)
    ref = _fragment_energy(CYS_THIOLATE, ch, "CH3S(-)")
    results["reference"] = ref
    print(f"     E_used = {ref['e_used']:.8f} Ha   (VQE vs CASCI Δ = {ref['delta_vqe_casci_uha']:.3f} µHa, {'sub-µHa' if ref['sub_uha'] else 'chem-acc' if ref['chem_acc'] else 'NOT CONV'})", flush=True)
    e_thiolate = ref["e_used"]

    # 2) per-warhead: E(warhead), E(adduct), ΔE_rxn
    for name, (wgeom, agem, wclass) in WARHEADS.items():
        try:
            chw, natw, nbw = _find_charge(wgeom, prefer=(0, 1, -1, -2, 2))
            cha, nata, nba = _find_charge(agem, prefer=(-1, 0, -2, 1, 2))
            if chw is None or cha is None:
                results["warheads"][name] = {"status": "FAIL", "error": "no valid charge"}
                print(f"  [{name}] FAIL: no valid charge", flush=True); continue
            print(f"  [{name}]  warhead(charge={chw}, {natw}at)  adduct(charge={cha}, {nata}at)  class={wclass}", flush=True)
            w = _fragment_energy(wgeom, chw, f"{name}.warhead")
            a = _fragment_energy(agem, cha, f"{name}.adduct")
            dE = a["e_used"] - e_thiolate - w["e_used"]
            results["warheads"][name] = {
                "warhead_class": wclass,
                "warhead": {k: w[k] for k in ("charge", "n_qubits", "n_pauli", "e_used", "delta_vqe_casci_uha", "chem_acc", "sub_uha")},
                "adduct":  {k: a[k] for k in ("charge", "n_qubits", "n_pauli", "e_used", "delta_vqe_casci_uha", "chem_acc", "sub_uha")},
                "dE_rxn_Ha": dE, "dE_rxn_kcal_per_mol": dE * HARTREE_TO_KCAL,
                "vqe_validates_casci": w["chem_acc"] and a["chem_acc"] and ref["chem_acc"],
            }
            tagw = "⭐" if w["sub_uha"] else ("✓" if w["chem_acc"] else "✗")
            taga = "⭐" if a["sub_uha"] else ("✓" if a["chem_acc"] else "✗")
            print(f"     ΔE_rxn = {dE:.6f} Ha = {dE*HARTREE_TO_KCAL:.2f} kcal/mol   (warhead VQE-vs-CASCI {tagw} {w['delta_vqe_casci_uha']:.2f}µHa · adduct {taga} {a['delta_vqe_casci_uha']:.2f}µHa)", flush=True)
        except Exception as exc:
            import traceback; traceback.print_exc()
            results["warheads"][name] = {"status": "FAIL", "error": str(exc)}
            print(f"  [{name}] FAIL: {exc}", flush=True)

    # 3) ranking (most negative ΔE_rxn = strongest covalent-bond formation in this gas-phase model)
    ok = {n: r for n, r in results["warheads"].items() if "dE_rxn_Ha" in r}
    ranked = sorted(ok.items(), key=lambda kv: kv[1]["dE_rxn_Ha"])
    print(f"\n## ranking — model covalent-bond-formation ΔE_rxn (CH3S⁻ + warhead → adduct⁻); most negative = strongest:")
    for i, (n, r) in enumerate(ranked, 1):
        print(f"  {i}. {n:<26} ΔE_rxn = {r['dE_rxn_Ha']:.6f} Ha = {r['dE_rxn_kcal_per_mol']:8.2f} kcal/mol   [{r['warhead_class']}]  (VQE validates CASCI: {r['vqe_validates_casci']})")
    results["ranking"] = [{"rank": i, "warhead": n, "dE_rxn_kcal_per_mol": r["dE_rxn_kcal_per_mol"],
                           "dE_rxn_Ha": r["dE_rxn_Ha"], "warhead_class": r["warhead_class"]} for i, (n, r) in enumerate(ranked, 1)]
    n_ranked = len(ranked)
    all_validate = all(r.get("vqe_validates_casci") for _, r in ranked) and len(ranked) >= 5

    print(f"\n## verdict: F-Q-6-F {'PASS' if (n_ranked >= 5 and all_validate) else 'PARTIAL' if n_ranked >= 3 else 'FAIL'}  "
          f"({n_ranked}/5 warheads ranked; VQE validates CASCI(2,2) on all fragments: {all_validate})")
    print("  C3: single-point energies at hand-built unoptimised gas-phase geometries → a QUALITATIVE warhead-reactivity")
    print("  ranking in a minimal (2,2) active space, NOT a quantitative ΔG / binding affinity / therapeutic claim;")
    print("  'VQE reproduces CASCI(2,2) here' — a CASCI ranking with a quantum-algorithm wrapper, not a quantum-advantage result.")
    if n_ranked >= 5 and all_validate:
        print("__MPRO_WARHEAD_LIBRARY_VQE__ PASS")
    else:
        print("__MPRO_WARHEAD_LIBRARY_VQE__ PARTIAL" if n_ranked >= 3 else "__MPRO_WARHEAD_LIBRARY_VQE__ FAIL")
    print("\n## JSON")
    print(json.dumps(results, indent=2))
    return 0 if n_ranked >= 3 else 1


if __name__ == "__main__":
    sys.exit(main())
