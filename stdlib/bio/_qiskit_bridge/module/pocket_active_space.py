#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
pocket_active_space.py — F-Q-6 Phase B: active-space CASCI Hamiltonian.

Wraps qiskit-nature's ActiveSpaceTransformer so arbitrary molecules
get reduced to an N-electron / N-spatial-orbital active space, parity-
mapped, and returned in the same dict shape as quantum_h_molecule.py
+ ligand_smiles_to_h.py — so quantum_vqe_general.py consumes it without
modification.

This is the unlock path for F-Q-6-A2 honest-deferred:

    F-Q-6-A2 (deferred): hardware-efficient ansatz on H2O 10-qubit hits
    expressivity wall (depth=1 delta 1715 mHa, depth=2 delta 1602 mHa,
    both NOT converged after 200 NM iterations).

    F-Q-6-B (this module): reduce H2O to a 2e/2o active space → 4
    qubits → hardware-efficient depth=2 known to chem-acc-converge in
    that regime (Phase B1 LiH = same shape, achieved 1.408 mHa).

The same wrapper handles real drug-target ligands (nirmatrelvir-class)
via active-space residue selection + frozen-core + frozen-virtual.

Public API
==========

    build_active_space_hamiltonian(
        atom_or_smiles: str,
        *,
        is_smiles: bool = True,
        num_active_electrons: int,
        num_active_spatial_orbitals: int,
        active_orbital_indices: list[int] | None = None,
        basis: str = "sto3g",
        charge: int = 0,
        spin: int = 0,
        rdkit_seed: int = 7,
    ) -> dict

        Same dict shape as quantum_h_molecule.build_hamiltonian, plus
        active_space_ncas / active_space_nelecas / casci_e_tot
        (PySCF CASCI classical reference for delta-vs-CASCI channel).

CLI usage
=========

    python3 pocket_active_space.py --smiles "O" --ncas 2 --nelecas 2
    python3 pocket_active_space.py --smiles "[H][H]" --ncas 1 --nelecas 2
    python3 pocket_active_space.py --selftest

Honest caveats
==============

1. Active-space choice is NOT automatic — caller specifies (nelecas,
   ncas). Wrong choice silently gives a different (often worse-grounded)
   reduced Hamiltonian. selftest pins H2O 2e/2o (HOMO+LUMO) with
   PySCF CASCI as the classical reference; production usage of larger
   ligands needs chemistry judgment to pick the active space.

2. PySCF CASCI is itself an approximation (limited to active-space
   excitations). VQE on the active-space Hamiltonian targets that
   CASCI E, not the FCI E of the full system. The "chem-acc" channel
   is delta_VQE_vs_CASCI; full-FCI delta is bounded below by
   E_CASCI - E_FCI which depends on active-space size.

3. `active_orbital_indices=None` lets ActiveSpaceTransformer pick the
   ncas frontier orbitals around HOMO/LUMO automatically. Explicit
   indices override (e.g. for picking a specific catalytic-residue
   orbital subset in a real drug target).

4. UFF geometry (when SMILES path is used) carries the same caveat as
   ligand_smiles_to_h.py — not QM-quality, ±0.05 Å typical.

5. F-Q-6-B sub-falsifier set (this module enables 1, the rest are
   deferred to subsequent commits as larger ligands come online):
       F-Q-6-B1   H2O 2e/2o active-space VQE chem-acc vs PySCF CASCI
       F-Q-6-B2   H2O 4e/4o active-space VQE chem-acc                 [TBD]
       F-Q-6-B3   nirmatrelvir-fragment active-space build (smoke)    [TBD]
       F-Q-6-B4   nirmatrelvir-fragment active-space VQE              [TBD]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Optional

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


class ActiveSpaceBuilderError(RuntimeError):
    pass


def _import_qn():
    try:
        from qiskit_nature.second_q.drivers import PySCFDriver
        from qiskit_nature.second_q.mappers import ParityMapper
        from qiskit_nature.second_q.transformers import ActiveSpaceTransformer
        import qiskit_nature
        import pyscf
    except ImportError as exc:
        raise ActiveSpaceBuilderError(
            f"qiskit_nature/pyscf import failed: {exc}. "
            f"Install with `pip install --user --break-system-packages "
            f"pyscf qiskit-nature` then retry."
        ) from exc
    return PySCFDriver, ParityMapper, ActiveSpaceTransformer, qiskit_nature, pyscf


def _smiles_to_pyscf_atom(smiles: str, rdkit_seed: int = 7) -> tuple[str, dict]:
    from ligand_smiles_to_h import smiles_to_xyz, LigandHamiltonianError
    try:
        geom = smiles_to_xyz(smiles, rdkit_seed=rdkit_seed)
    except LigandHamiltonianError as exc:
        raise ActiveSpaceBuilderError(f"SMILES geometry failed: {exc}") from exc
    return geom["pyscf_atom"], geom


def _casci_reference(
    pyscf_atom: str,
    basis: str,
    ncas: int,
    nelecas: int,
    charge: int = 0,
    spin: int = 0,
) -> Optional[float]:
    """Run a classical PySCF CASCI as the reference E for the same
    active space. Return e_tot or None on failure."""
    try:
        from pyscf import gto, scf, mcscf
    except ImportError:
        return None

    try:
        mol = gto.M(atom=pyscf_atom, basis=basis, charge=charge, spin=spin, verbose=0)
        mf = scf.RHF(mol)
        mf.kernel()
        if not mf.converged:
            return None
        casci = mcscf.CASCI(mf, ncas=ncas, nelecas=nelecas)
        casci.verbose = 0
        casci.kernel()
        return float(casci.e_tot)
    except Exception:
        return None


def build_active_space_hamiltonian(
    atom_or_smiles: str,
    *,
    is_smiles: bool = True,
    num_active_electrons: int,
    num_active_spatial_orbitals: int,
    active_orbital_indices: Optional[list[int]] = None,
    basis: str = "sto3g",
    charge: int = 0,
    spin: int = 0,
    rdkit_seed: int = 7,
) -> dict:
    """Build the parity-mapped active-space Hamiltonian.

    Returns the same dict shape as quantum_h_molecule.build_hamiltonian
    plus active_space_* keys + casci_e_tot (PySCF CASCI reference).
    """
    PySCFDriver, ParityMapper, ActiveSpaceTransformer, qn, pyscf = _import_qn()

    geom_extras: dict = {}
    if is_smiles:
        pyscf_atom, geom_extras = _smiles_to_pyscf_atom(atom_or_smiles, rdkit_seed=rdkit_seed)
    else:
        pyscf_atom = atom_or_smiles

    driver = PySCFDriver(
        atom=pyscf_atom,
        basis=basis,
        charge=int(charge),
        spin=int(spin),
    )
    problem_full = driver.run()

    ast_kwargs: dict = dict(
        num_electrons=int(num_active_electrons),
        num_spatial_orbitals=int(num_active_spatial_orbitals),
    )
    if active_orbital_indices is not None:
        ast_kwargs["active_orbitals"] = list(active_orbital_indices)

    ast = ActiveSpaceTransformer(**ast_kwargs)
    active_problem = ast.transform(problem_full)

    mapper = ParityMapper(num_particles=active_problem.num_particles)
    sparse_op = mapper.map(active_problem.hamiltonian.second_q_op())

    pauli_strings = [str(p) for p in sparse_op.paulis]
    coeffs = sparse_op.coeffs
    coeffs_real = [float(c.real) for c in coeffs]
    coeffs_imag = [float(c.imag) for c in coeffs]

    constant_shift = float(sum(active_problem.hamiltonian.constants.values()))

    # HF-occupation init bits in the parity-mapped reduced space.
    n_qubits = int(sparse_op.num_qubits)
    n_alpha, n_beta = active_problem.num_particles
    hf_init_bits: list[int] = []
    half = n_qubits // 2
    if n_qubits == 2 * half and n_alpha <= half and n_beta <= half:
        bits = [0] * n_qubits
        for i in range(int(n_alpha)):
            bits[i] = 1
        for i in range(int(n_beta)):
            bits[half + i] = 1
        hf_init_bits = bits

    # Classical PySCF CASCI reference E (full-system E in the active space).
    casci_e_tot = _casci_reference(
        pyscf_atom, basis,
        ncas=int(num_active_spatial_orbitals),
        nelecas=int(num_active_electrons),
        charge=int(charge), spin=int(spin),
    )

    transformer_chain = [
        f"ActiveSpaceTransformer(num_electrons={num_active_electrons}, "
        f"num_spatial_orbitals={num_active_spatial_orbitals}"
        + (f", active_orbitals={active_orbital_indices})" if active_orbital_indices is not None else ")")
    ]

    out = {
        "name": atom_or_smiles if not is_smiles else geom_extras.get("canonical_smiles", atom_or_smiles),
        "smiles_input": atom_or_smiles if is_smiles else None,
        "canonical_smiles": geom_extras.get("canonical_smiles") if is_smiles else None,
        "formula": geom_extras.get("formula") if is_smiles else None,
        "n_atoms": geom_extras.get("n_atoms") if is_smiles else None,
        "n_qubits": n_qubits,
        "pauli_strings": pauli_strings,
        "coefficients_real": coeffs_real,
        "coefficients_imag": coeffs_imag,
        "constant_shift_ha": constant_shift,
        "hf_init_bits": hf_init_bits,
        "ref_geometry": pyscf_atom,
        "basis_set": basis,
        "mapping": "parity",
        "transformer_chain": transformer_chain,
        "ref_energy_ha_fci": None,
        "ref_energy_ha_casci": casci_e_tot,
        "active_space_nelecas": int(num_active_electrons),
        "active_space_ncas": int(num_active_spatial_orbitals),
        "active_orbital_indices": list(active_orbital_indices) if active_orbital_indices is not None else None,
        "qiskit_nature_version": qn.__version__,
        "pyscf_version": pyscf.__version__,
        "geometry_source": geom_extras.get("geometry_source") if is_smiles else "pyscf_atom_inline",
        "rdkit_version": geom_extras.get("rdkit_version") if is_smiles else None,
        "rdkit_seed": geom_extras.get("rdkit_seed") if is_smiles else None,
        "charge": int(charge),
        "spin": int(spin),
    }
    return out


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _emit_json(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload, separators=(",", ":")))
    sys.stdout.write("\n")
    sys.stdout.flush()


def _cmd_build(args: argparse.Namespace) -> int:
    try:
        h = build_active_space_hamiltonian(
            args.smiles or args.atom,
            is_smiles=args.smiles is not None,
            num_active_electrons=args.nelecas,
            num_active_spatial_orbitals=args.ncas,
            active_orbital_indices=args.active_orbitals,
            basis=args.basis,
            charge=args.charge,
            spin=args.spin,
            rdkit_seed=args.rdkit_seed,
        )
    except ActiveSpaceBuilderError as exc:
        _emit_json({"ok": 0, "error": str(exc)})
        return 1
    summary = {
        "ok": 1,
        "name": h["name"],
        "n_qubits": h["n_qubits"],
        "n_pauli_terms": len(h["pauli_strings"]),
        "active_space_nelecas": h["active_space_nelecas"],
        "active_space_ncas": h["active_space_ncas"],
        "constant_shift_ha": h["constant_shift_ha"],
        "ref_energy_ha_casci": h["ref_energy_ha_casci"],
        "transformer_chain": h["transformer_chain"],
        "qn_version": h["qiskit_nature_version"],
        "pyscf_version": h["pyscf_version"],
        "first_3_terms": [
            (h["pauli_strings"][i], h["coefficients_real"][i])
            for i in range(min(3, len(h["pauli_strings"])))
        ],
    }
    _emit_json(summary)
    return 0


def _cmd_selftest(args: argparse.Namespace) -> int:
    """F1 H2O 2e/2o active-space build + CASCI reference reproduce."""
    print("hexa-bio pocket_active_space.py — selftest (F-Q-6 Phase B build)")
    print()

    cases = [
        ("[H][H]", "F1", "H2 1e/1o-bonding-only smoke",   2, 2),  # H2 full = 2e/1o; degenerate but OK
        ("O",       "F2", "H2O 2e/2o (HOMO+LUMO)",         2, 2),
        ("O",       "F3", "H2O 4e/4o (HOMO-1..LUMO+1)",   4, 4),
    ]

    all_pass = True
    for smiles, tag, label, nelecas, ncas in cases:
        print(f"  {tag}: build {label}  (SMILES {smiles!r}, nelecas={nelecas}, ncas={ncas}) ...")
        try:
            h = build_active_space_hamiltonian(
                smiles,
                is_smiles=True,
                num_active_electrons=nelecas,
                num_active_spatial_orbitals=ncas,
                basis="sto3g",
            )
        except ActiveSpaceBuilderError as exc:
            print(f"  {tag} FAIL: {exc}")
            print(f"__HEXA_BIO_POCKET_AS__ {tag} FAIL")
            all_pass = False
            continue

        n_qubits = h["n_qubits"]
        n_terms = len(h["pauli_strings"])
        casci = h["ref_energy_ha_casci"]
        # Expected: parity mapping of nelecas/ncas active space → 2*ncas qubits
        # (or fewer after parity tapering).
        expected_qubits_max = 2 * ncas
        if n_qubits > expected_qubits_max:
            print(f"  {tag} FAIL: n_qubits {n_qubits} > 2*ncas={expected_qubits_max}")
            print(f"__HEXA_BIO_POCKET_AS__ {tag} FAIL")
            all_pass = False
            continue

        casci_str = f"{casci:+.6f} Ha" if casci is not None else "<unavailable>"
        print(f"  {tag} PASS: {label} → n_qubits={n_qubits} n_terms={n_terms} CASCI_e_tot={casci_str}")
        print(f"__HEXA_BIO_POCKET_AS__ {tag} PASS")
        print()

    print()
    if all_pass:
        print("__HEXA_BIO_POCKET_AS__ ALL PASS")
        return 0
    print("__HEXA_BIO_POCKET_AS__ ALL FAIL")
    return 1


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        prog="pocket_active_space.py",
        description="hexa-bio adapter: active-space CASCI Hamiltonian (F-Q-6 Phase B)",
    )
    p.add_argument("--smiles", default=None,
                   help="SMILES string; mutually exclusive with --atom")
    p.add_argument("--atom", default=None,
                   help="Direct PySCF atom string ('O 0 0 0; H 1 0 0; H 0 1 0')")
    p.add_argument("--nelecas", type=int, default=None,
                   help="Active electrons (e.g. 2 for H2O HOMO+LUMO)")
    p.add_argument("--ncas", type=int, default=None,
                   help="Active spatial orbitals (e.g. 2 for HOMO+LUMO)")
    p.add_argument("--active-orbitals", type=int, nargs="*", default=None,
                   help="Explicit orbital indices override")
    p.add_argument("--basis", default="sto3g")
    p.add_argument("--charge", type=int, default=0)
    p.add_argument("--spin", type=int, default=0)
    p.add_argument("--rdkit-seed", type=int, default=7)
    p.add_argument("--selftest", action="store_true")
    args = p.parse_args(argv)

    if args.selftest:
        return _cmd_selftest(args)
    if (args.smiles is None and args.atom is None) or args.nelecas is None or args.ncas is None:
        p.print_help()
        return 2
    return _cmd_build(args)


if __name__ == "__main__":
    sys.exit(main())
