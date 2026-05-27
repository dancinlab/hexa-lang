#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
quantum_ansatz_uccsd.py — F-Q-6 Phase B step 3: UCCSD chemistry-aware ansatz.

Wraps qiskit-nature's UCCSD circuit + HartreeFock initial state for the
hardware-efficient ansatz expressivity wall (measured 2026-05-07: H2O
4e/4o 6-qubit hits 41.8 mHa best with depth=3 + multi-restart 5 seeds —
see registry raw_77_ansatz_expressivity_diagnosis_v1).

UCCSD = Unitary Coupled-Cluster Singles-and-Doubles. Built from the
fermionic single + double excitation operators of the cluster operator
T = T1 + T2, then Trotterised once. The resulting circuit has chemistry-
aware structure that hardware-efficient RY-CNOT-RY ansatze lack.

Public API
==========

    UCCSDAnsatz(active_problem, mapper) — owns the parameterised circuit
    .num_parameters
    .energy(theta, observable_sparse_op, constant_shift)  -> float
        statevector-mode evaluation; returns E in Hartrees.

    energy_uccsd(theta, hamiltonian_dict, *,
                 active_problem=None, mapper=None) -> tuple[float, dict]
        higher-level entry that pulls active_problem + mapper from the
        hamiltonian dict's metadata if available. Compatible with
        quantum_vqe_general.py's `_fn(theta) -> float` contract.

    vqe_uccsd(hamiltonian, *, theta0=None, seed=None,
              max_iter=300, tol=1e-6, initial_step=0.05) -> dict
        thin Nelder-Mead optimiser around energy_uccsd. UCCSD circuit
        evaluation is statevector-only (qiskit Statevector) so AerPool
        is NOT used (small n_qubits → statevector is sub-ms).

CLI usage
=========

    python3 quantum_ansatz_uccsd.py --molecule h2 --max-iter 200
    python3 quantum_ansatz_uccsd.py --smiles "O" --nelecas 4 --ncas 4 \
        --max-iter 200
    python3 quantum_ansatz_uccsd.py --selftest

Honest caveats
==============

1. UCCSD parameter count grows like O(N_occ × N_virt) for singles and
   O((N_occ × N_virt)^2 / 4) for doubles. H2O 4e/4o (n_occ=2, n_virt=2)
   has ~ 8-12 parameters. nirmatrelvir-class fragments will need
   careful active-space sizing.

2. statevector evaluation is exact (no shot noise) but limited to
   small active spaces (≲ 16 qubits). Above that, switching to
   AerSimulator + the same parameter binding is straightforward but
   not in this module.

3. NM optimiser is local. UCCSD landscape near HF is well-conditioned
   for small molecules (HF reference is a near-optimum starting point);
   theta0=0 is the default which corresponds to |HF⟩ unmodified.

4. Trotter steps default to 1 (qiskit-nature default). For higher
   accuracy (sub-µHa) reps=2 or full UCCSDT is the next ramp.

5. F-Q-6 sub-falsifier set this module enables:
       F-Q-6-B2-uccsd   H2O 4e/4o UCCSD chem-acc (was hardware-eff FAIL)
       F-Q-6-B-real     nirmatrelvir-class active-space + UCCSD VQE
"""

from __future__ import annotations

import argparse
import json
import math
import os
import random
import sys
import time
from typing import Callable, List, Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


class UCCSDAnsatzError(RuntimeError):
    pass


def _import_qn():
    try:
        from qiskit_nature.second_q.drivers import PySCFDriver
        from qiskit_nature.second_q.mappers import ParityMapper
        from qiskit_nature.second_q.transformers import (
            ActiveSpaceTransformer,
            FreezeCoreTransformer,
        )
        from qiskit_nature.second_q.circuit.library import UCCSD, HartreeFock
        from qiskit.quantum_info import Statevector, SparsePauliOp
        import qiskit_nature
        import pyscf
    except ImportError as exc:
        raise UCCSDAnsatzError(
            f"qiskit_nature/qiskit/pyscf import failed: {exc}. "
            f"Install with `pip install --user --break-system-packages "
            f"pyscf qiskit-nature` then retry."
        ) from exc
    return (
        PySCFDriver, ParityMapper, ActiveSpaceTransformer, FreezeCoreTransformer,
        UCCSD, HartreeFock, Statevector, SparsePauliOp, qiskit_nature, pyscf,
    )


class UCCSDAnsatz:
    """Owns a UCCSD parameterised circuit + parity-mapped Hamiltonian."""

    def __init__(self, active_problem, mapper, sparse_op, constant_shift):
        (PySCFDriver, ParityMapper, _AST, _FCT, UCCSD, HartreeFock,
         Statevector, SparsePauliOp, qn, pyscf) = _import_qn()

        n_spatial = active_problem.num_spatial_orbitals
        n_particles = active_problem.num_particles

        initial_state = HartreeFock(
            num_spatial_orbitals=n_spatial,
            num_particles=n_particles,
            qubit_mapper=mapper,
        )
        ansatz = UCCSD(
            num_spatial_orbitals=n_spatial,
            num_particles=n_particles,
            qubit_mapper=mapper,
            initial_state=initial_state,
            reps=1,
        )

        self._ansatz = ansatz
        self._sparse_op = sparse_op
        self._constant_shift = float(constant_shift)
        self._n_qubits = ansatz.num_qubits
        self._n_params = ansatz.num_parameters
        self._initial_state = initial_state
        self._Statevector = Statevector

    @property
    def num_parameters(self) -> int:
        return self._n_params

    @property
    def n_qubits(self) -> int:
        return self._n_qubits

    def energy(self, theta: List[float]) -> float:
        if len(theta) != self._n_params:
            raise UCCSDAnsatzError(
                f"theta len {len(theta)} != n_params {self._n_params}"
            )
        bound = self._ansatz.assign_parameters(list(theta))
        sv = self._Statevector.from_instruction(bound)
        exp_val = sv.expectation_value(self._sparse_op).real
        return float(exp_val) + self._constant_shift


def build_uccsd_for_h_or_smiles(
    *,
    h2_or_lih: Optional[str] = None,
    smiles: Optional[str] = None,
    num_active_electrons: Optional[int] = None,
    num_active_spatial_orbitals: Optional[int] = None,
    basis: str = "sto3g",
    charge: int = 0,
    spin: int = 0,
    rdkit_seed: int = 7,
) -> Tuple[UCCSDAnsatz, dict]:
    """Build UCCSD ansatz for either a named molecule (h2 / lih), a SMILES
    full system, or a SMILES + active-space spec. Returns (ansatz, meta)."""
    (PySCFDriver, ParityMapper, ActiveSpaceTransformer, FreezeCoreTransformer,
     UCCSD, HartreeFock, Statevector, SparsePauliOp, qn, pyscf) = _import_qn()

    if h2_or_lih is not None:
        if h2_or_lih.lower() == "h2":
            atom = "H 0 0 0; H 0 0 0.74"
        elif h2_or_lih.lower() == "lih":
            atom = "Li 0 0 0; H 0 0 1.5"
        else:
            raise UCCSDAnsatzError(f"unknown molecule name: {h2_or_lih!r}")
        driver = PySCFDriver(atom=atom, basis=basis, charge=charge, spin=spin)
        problem_full = driver.run()
        if h2_or_lih.lower() == "lih":
            fct = FreezeCoreTransformer(freeze_core=True, remove_orbitals=[3, 4])
            active_problem = fct.transform(problem_full)
        else:
            active_problem = problem_full
        molecule_name = h2_or_lih.lower()
    elif smiles is not None:
        from ligand_smiles_to_h import smiles_to_xyz, LigandHamiltonianError
        try:
            geom = smiles_to_xyz(smiles, rdkit_seed=rdkit_seed)
        except LigandHamiltonianError as exc:
            raise UCCSDAnsatzError(f"SMILES geometry failed: {exc}") from exc
        driver = PySCFDriver(atom=geom["pyscf_atom"], basis=basis, charge=charge, spin=spin)
        problem_full = driver.run()

        if num_active_electrons is not None and num_active_spatial_orbitals is not None:
            ast = ActiveSpaceTransformer(
                num_electrons=int(num_active_electrons),
                num_spatial_orbitals=int(num_active_spatial_orbitals),
            )
            active_problem = ast.transform(problem_full)
        else:
            active_problem = problem_full
        molecule_name = geom["canonical_smiles"]
    else:
        raise UCCSDAnsatzError("either h2_or_lih or smiles must be given")

    mapper = ParityMapper(num_particles=active_problem.num_particles)
    sparse_op = mapper.map(active_problem.hamiltonian.second_q_op())
    constant_shift = float(sum(active_problem.hamiltonian.constants.values()))

    ansatz = UCCSDAnsatz(active_problem, mapper, sparse_op, constant_shift)

    meta = {
        "molecule": molecule_name,
        "n_qubits": ansatz.n_qubits,
        "n_parameters": ansatz.num_parameters,
        "n_pauli_terms": len(sparse_op),
        "constant_shift_ha": constant_shift,
        "active_space_nelecas": list(active_problem.num_particles),
        "active_space_ncas": int(active_problem.num_spatial_orbitals),
        "basis": basis,
        "qiskit_nature_version": qn.__version__,
        "pyscf_version": pyscf.__version__,
    }
    return ansatz, meta


# ---------------------------------------------------------------------------
# Local Nelder-Mead (no AerPool needed; statevector is exact + sub-ms)
# ---------------------------------------------------------------------------


def _nelder_mead(
    fn: Callable[[List[float]], float],
    x0: List[float],
    *,
    initial_step: float = 0.05,
    max_iter: int = 300,
    tol: float = 1e-7,
) -> dict:
    n = len(x0)
    f0 = fn(list(x0))
    simplex = [(list(x0), f0)]
    for i in range(n):
        v = list(x0)
        v[i] = v[i] + initial_step
        simplex.append((v, fn(v)))

    converged = False
    for it in range(max_iter):
        simplex.sort(key=lambda pair: pair[1])
        best_x, best_f = simplex[0]
        worst_x, worst_f = simplex[-1]
        if abs(worst_f - best_f) < tol:
            converged = True
            break
        # centroid of all but worst
        centroid = [sum(simplex[i][0][j] for i in range(n)) / n for j in range(n)]
        # reflection
        refl = [centroid[j] + (centroid[j] - worst_x[j]) for j in range(n)]
        f_refl = fn(refl)
        if simplex[0][1] <= f_refl < simplex[-2][1]:
            simplex[-1] = (refl, f_refl)
        elif f_refl < simplex[0][1]:
            # expansion
            exp = [centroid[j] + 2.0 * (centroid[j] - worst_x[j]) for j in range(n)]
            f_exp = fn(exp)
            simplex[-1] = (exp, f_exp) if f_exp < f_refl else (refl, f_refl)
        else:
            # contraction
            contr = [centroid[j] + 0.5 * (worst_x[j] - centroid[j]) for j in range(n)]
            f_contr = fn(contr)
            if f_contr < worst_f:
                simplex[-1] = (contr, f_contr)
            else:
                # shrink
                best_x_now = simplex[0][0]
                shrunk = []
                for vv, _ in simplex:
                    new_v = [best_x_now[j] + 0.5 * (vv[j] - best_x_now[j]) for j in range(n)]
                    shrunk.append((new_v, fn(new_v)))
                simplex = shrunk

    simplex.sort(key=lambda pair: pair[1])
    return {"x": simplex[0][0], "fx": simplex[0][1], "n_iter": it + 1, "converged": converged}


def vqe_uccsd(
    *,
    h2_or_lih: Optional[str] = None,
    smiles: Optional[str] = None,
    num_active_electrons: Optional[int] = None,
    num_active_spatial_orbitals: Optional[int] = None,
    basis: str = "sto3g",
    charge: int = 0,
    spin: int = 0,
    theta0: Optional[List[float]] = None,
    seed: Optional[int] = None,
    max_iter: int = 300,
    tol: float = 1e-7,
    initial_step: float = 0.05,
    rdkit_seed: int = 7,
) -> dict:
    """End-to-end: build UCCSD ansatz + run NM. Default theta0 = zeros
    (|HF⟩ initial state)."""
    started = time.time()
    ansatz, meta = build_uccsd_for_h_or_smiles(
        h2_or_lih=h2_or_lih, smiles=smiles,
        num_active_electrons=num_active_electrons,
        num_active_spatial_orbitals=num_active_spatial_orbitals,
        basis=basis, charge=charge, spin=spin, rdkit_seed=rdkit_seed,
    )
    n_params = ansatz.num_parameters

    if theta0 is None:
        if seed is not None:
            random.seed(int(seed))
            theta0 = [random.uniform(-0.05, 0.05) for _ in range(n_params)]
        else:
            theta0 = [0.0] * n_params

    res = _nelder_mead(
        ansatz.energy, list(theta0),
        initial_step=initial_step, max_iter=max_iter, tol=tol,
    )

    out = dict(meta)
    out.update({
        "n_iter": res["n_iter"],
        "converged": res["converged"],
        "energy_Ha": res["fx"],
        "theta": res["x"],
        "theta0": theta0,
        "wall_seconds": time.time() - started,
        "engine": "qiskit_statevector",
        "ansatz": "UCCSD",
        "max_iter": max_iter,
        "seed": seed,
    })
    return out


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _emit_json(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload, separators=(",", ":")))
    sys.stdout.write("\n")
    sys.stdout.flush()


def _format_result(r: dict, ref: Optional[float] = None) -> str:
    line1 = (
        f"  molecule={r['molecule']!r}  n_qubits={r['n_qubits']}  "
        f"n_params={r['n_parameters']}  n_pauli={r['n_pauli_terms']}"
    )
    line2 = (
        f"  energy_Ha = {r['energy_Ha']:+.8f}  n_iter={r['n_iter']}  "
        f"converged={r['converged']}  wall={r['wall_seconds']:.2f}s  "
        f"engine={r['engine']}"
    )
    delta_line = ""
    if ref is not None:
        delta = r["energy_Ha"] - ref
        delta_line = (
            f"  ref_E0_Ha = {ref:+.8f}  delta = {delta*1e6:+.3f} µHa  "
            f"({delta*1e3:+.4f} mHa)"
        )
    return "\n".join(filter(None, [line1, line2, delta_line]))


def _cmd_run(args: argparse.Namespace) -> int:
    try:
        out = vqe_uccsd(
            h2_or_lih=args.molecule,
            smiles=args.smiles,
            num_active_electrons=args.nelecas,
            num_active_spatial_orbitals=args.ncas,
            basis=args.basis,
            charge=args.charge,
            spin=args.spin,
            seed=args.seed,
            max_iter=args.max_iter,
            initial_step=args.initial_step,
            rdkit_seed=args.rdkit_seed,
        )
    except UCCSDAnsatzError as exc:
        _emit_json({"ok": 0, "error": str(exc)})
        return 1
    _emit_json({"ok": 1, **out})
    return 0


def _cmd_selftest(args: argparse.Namespace) -> int:
    """F1: H2 UCCSD reproduces FCI -1.137306 Ha within 1 mHa.
       F2: H2O 4e/4o UCCSD chem-acc vs CASCI ref."""
    print("hexa-bio quantum_ansatz_uccsd.py — selftest (F-Q-6 Phase B step 3)")
    print()

    all_pass = True

    # F1 H2
    print("  F1: H2 STO-3G/0.74Å UCCSD VQE  (ref FCI = -1.137306 Ha)")
    try:
        h2 = vqe_uccsd(h2_or_lih="h2", basis="sto3g", max_iter=200)
    except UCCSDAnsatzError as exc:
        print(f"  F1 FAIL: {exc}")
        print("__HEXA_BIO_UCCSD__ F1 FAIL")
        all_pass = False
    else:
        print(_format_result(h2, ref=-1.137306))
        delta_mha = abs(h2["energy_Ha"] - (-1.137306)) * 1e3
        if delta_mha > 1.0:
            print(f"  F1 FAIL: |delta| {delta_mha:.4f} mHa > 1.0 mHa")
            print("__HEXA_BIO_UCCSD__ F1 FAIL")
            all_pass = False
        else:
            print(f"  F1 PASS: H2 UCCSD within {delta_mha:.4f} mHa of FCI ref")
            print("__HEXA_BIO_UCCSD__ F1 PASS")
    print()

    # F2 H2O 4e/4o (the F-Q-6-B2 unlock target)
    print("  F2: H2O 4e/4o UCCSD VQE  (vs CASCI(4,4) classical ref)")
    try:
        # First grab the CASCI reference via pocket_active_space.
        from pocket_active_space import build_active_space_hamiltonian
        h_ref = build_active_space_hamiltonian(
            "O", is_smiles=True,
            num_active_electrons=4, num_active_spatial_orbitals=4,
            basis="sto3g",
        )
        casci_ref = h_ref["ref_energy_ha_casci"]
        print(f"      CASCI(4,4) ref = {casci_ref:+.8f} Ha")
    except Exception as exc:
        print(f"  F2 FAIL (CASCI ref load): {exc}")
        print("__HEXA_BIO_UCCSD__ F2 FAIL")
        all_pass = False
        casci_ref = None

    if casci_ref is not None:
        try:
            h2o = vqe_uccsd(
                smiles="O",
                num_active_electrons=4, num_active_spatial_orbitals=4,
                basis="sto3g",
                max_iter=300, initial_step=0.05,
            )
        except UCCSDAnsatzError as exc:
            print(f"  F2 FAIL: {exc}")
            print("__HEXA_BIO_UCCSD__ F2 FAIL")
            all_pass = False
        else:
            print(_format_result(h2o, ref=casci_ref))
            delta_mha = abs(h2o["energy_Ha"] - casci_ref) * 1e3
            if delta_mha > 1.6:
                print(f"  F2 FAIL: |delta| {delta_mha:.4f} mHa > 1.6 mHa (chem-acc)")
                print("__HEXA_BIO_UCCSD__ F2 FAIL")
                all_pass = False
            else:
                print(f"  F2 PASS: H2O 4e/4o UCCSD within {delta_mha:.4f} mHa of CASCI ref")
                print("__HEXA_BIO_UCCSD__ F2 PASS")
    print()

    if all_pass:
        print("__HEXA_BIO_UCCSD__ ALL PASS")
        return 0
    print("__HEXA_BIO_UCCSD__ ALL FAIL")
    return 1


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        prog="quantum_ansatz_uccsd.py",
        description="hexa-bio adapter: UCCSD chemistry-aware ansatz + VQE (F-Q-6 Phase B step 3)",
    )
    p.add_argument("--molecule", default=None, choices=["h2", "lih"])
    p.add_argument("--smiles", default=None)
    p.add_argument("--nelecas", type=int, default=None)
    p.add_argument("--ncas", type=int, default=None)
    p.add_argument("--basis", default="sto3g")
    p.add_argument("--charge", type=int, default=0)
    p.add_argument("--spin", type=int, default=0)
    p.add_argument("--max-iter", type=int, default=300)
    p.add_argument("--initial-step", type=float, default=0.05)
    p.add_argument("--seed", type=int, default=None)
    p.add_argument("--rdkit-seed", type=int, default=7)
    p.add_argument("--selftest", action="store_true")
    args = p.parse_args(argv)

    if args.selftest:
        return _cmd_selftest(args)
    if args.molecule is None and args.smiles is None:
        p.print_help()
        return 2
    return _cmd_run(args)


if __name__ == "__main__":
    sys.exit(main())
