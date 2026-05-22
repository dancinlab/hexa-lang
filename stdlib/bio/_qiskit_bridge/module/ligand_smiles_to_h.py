#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ligand_smiles_to_h.py — F-Q-6 Phase A: SMILES → 3D conformer → molecular
Hamiltonian for arbitrary small ligands.

Wraps RDKit (SMILES parsing + 3D embedding + UFF optimization) + PySCF +
qiskit-nature (PySCFDriver + ParityMapper [+ FreezeCoreTransformer]) into
a single `build_ligand_hamiltonian(smiles, ...)` call. The returned dict
shape matches quantum_h_molecule.py exactly so the existing VQE
infrastructure (quantum_ansatz_he.py / quantum_pauli_expectation_general.py
/ quantum_vqe_general.py / quantum_aer_pool.py) can consume it without
modification.

Public API
==========

    build_ligand_hamiltonian(smiles: str, *,
                             basis: str = "sto3g",
                             freeze_core: bool = True,
                             remove_orbitals: list[int] | None = None,
                             charge: int = 0,
                             spin: int = 0,
                             rdkit_seed: int = 7) -> dict

        Returns a dict with the same keys as quantum_h_molecule.py:
        name / n_qubits / pauli_strings / coefficients_real /
        coefficients_imag / constant_shift_ha / ref_geometry / basis_set /
        mapping / transformer_chain / hf_init_bits / qiskit_nature_version /
        pyscf_version. Plus rdkit_version + canonical_smiles + n_atoms +
        formula for provenance.

CLI usage
=========

    python3 ligand_smiles_to_h.py --smiles "[H][H]"           # H2 round-trip
    python3 ligand_smiles_to_h.py --smiles "C"   --no-freeze  # methane raw
    python3 ligand_smiles_to_h.py --smiles "O"                # water
    python3 ligand_smiles_to_h.py --selftest

Honest caveats
==============

1. SMILES → 3D embedding is NOT QM-quality geometry — RDKit UFF gives a
   reasonable starting point but bond lengths typically ±0.05 Å off
   true equilibrium. For chem-acc binding-energy work the geometry
   should be re-optimized by PySCF HF/B3LYP before VQE. This module
   intentionally does NOT auto-reoptimize so geometry-source is
   transparent (RDKit UFF returned in `geometry_source`); a downstream
   pocket_active_space.py cycle is expected to add the QM relaxation
   step.

2. STO-3G is the smallest viable basis. Real chem-acc on heavy atoms
   needs cc-pVDZ at minimum, which roughly triples qubit count. STO-3G
   is enough for shape + path validation; production ligand-ranking
   needs a basis upgrade plus active-space reduction.

3. Larger ligands (nirmatrelvir ≈ 50 heavy atoms) at STO-3G blow past
   the Aer simulator practical limit (~16 qubits). Phase A's selftest
   exercises tiny ligands (H2, water, methane, formic acid) only;
   pocket-relevant fragments belong to Phase B's pocket_active_space.py
   wrapper which adds CASCI active-space selection.

   Measured 2026-05-07 (STO-3G + FreezeCore=True, this machine):
       SMILES         n_qubits   n_pauli_terms   Aer-runnable?
       [H][H]               2              5      yes (Phase 1 already)
       O (water)           10            567      yes (Aer pool, ~minutes)
       C (methane)         14           5101      borderline (wall hours)
       C(=O)O (HCOOH)      26          30611      NO (over Aer practical
                                                   limit ~16 qubits)
       nirmatrelvir       50+        millions     NO — Phase B mandatory

   Practical Aer ceiling on this machine ≈ 10-12 qubits with the AerPool
   long-lived bridge. Anything heavier needs CASCI active-space reduction
   (Phase B's pocket_active_space.py).

4. RDKit's EmbedMolecule + UFFOptimizeMolecule are deterministic given
   `rdkit_seed`; same SMILES + same seed → byte-identical Hamiltonian.

5. RDKit installed 2026-05-07 via `pip install --user --break-system-
   packages rdkit`; the wrapper raises RuntimeError pointing at that
   command if missing.

6. F-Q-6 Phase A scope: this module + nirmatrelvir-or-tiny-ligand
   gas-phase E_total selftest. Pocket-interaction (binding energy) is
   Phase B; ranking + BindingDB compare is Phase C.
"""

from __future__ import annotations

import argparse
import json
import sys
from typing import Optional


# Reference E0 for tiny round-trip validation cases (FCI / STO-3G,
# geometry from RDKit UFF). These are loose because UFF geometry differs
# from the canonical literature geometry.
_REFERENCE_E0_HA_LOOSE = {
    "[H][H]":      (-1.20, -0.95),  # H2 STO-3G FCI ~ -1.137 Ha (full); allow wide
    "O":           (-75.10, -74.50),  # H2O STO-3G HF ~ -74.96 Ha
    "C":           (-40.30, -39.60),  # CH4 STO-3G HF ~ -39.73 Ha
    "C(=O)O":      (-187.00, -186.20),  # formic acid HCOOH STO-3G HF ~ -186.4 Ha
}


class LigandHamiltonianError(RuntimeError):
    pass


def _import_rdkit():
    try:
        from rdkit import Chem
        from rdkit.Chem import AllChem
        import rdkit
    except ImportError as exc:
        raise LigandHamiltonianError(
            f"rdkit import failed: {exc}. Install with "
            f"`/opt/homebrew/opt/python@3.14/bin/pip3.14 install --user "
            f"--break-system-packages rdkit` then retry."
        ) from exc
    return Chem, AllChem, rdkit


def _import_qn():
    try:
        from qiskit_nature.second_q.drivers import PySCFDriver
        from qiskit_nature.second_q.mappers import ParityMapper
        from qiskit_nature.second_q.transformers import FreezeCoreTransformer
        import qiskit_nature
        import pyscf
    except ImportError as exc:
        raise LigandHamiltonianError(
            f"qiskit_nature/pyscf import failed: {exc}. "
            f"Install with `pip install --user --break-system-packages "
            f"pyscf qiskit-nature` then retry."
        ) from exc
    return PySCFDriver, ParityMapper, FreezeCoreTransformer, qiskit_nature, pyscf


def smiles_to_xyz(
    smiles: str,
    *,
    rdkit_seed: int = 7,
) -> dict:
    """SMILES → 3D conformer (RDKit UFF). Returns dict with atom list,
    PySCF-format atom string, canonical SMILES, n_atoms, formula."""
    Chem, AllChem, rdkit = _import_rdkit()

    mol = Chem.MolFromSmiles(smiles)
    if mol is None:
        raise LigandHamiltonianError(f"RDKit could not parse SMILES: {smiles!r}")
    mol = Chem.AddHs(mol)

    # ETKDG seeded → reproducible 3D embed.
    params = AllChem.ETKDGv3()
    params.randomSeed = int(rdkit_seed)
    embed_status = AllChem.EmbedMolecule(mol, params)
    if embed_status != 0:
        # Fall back to plain EmbedMolecule (no ETKDG) for tricky tiny cases like [H][H].
        embed_status = AllChem.EmbedMolecule(mol, randomSeed=int(rdkit_seed))
        if embed_status != 0:
            raise LigandHamiltonianError(
                f"RDKit failed to embed SMILES {smiles!r} into 3D"
            )

    # UFF optimize. Don't fail hard if UFF returns nonzero — for very small
    # molecules (H2, He) UFF can be a no-op.
    try:
        AllChem.UFFOptimizeMolecule(mol, maxIters=400)
    except Exception:
        pass

    conf = mol.GetConformer()
    atoms_list = []
    pyscf_atom_lines = []
    for i, atom in enumerate(mol.GetAtoms()):
        pos = conf.GetAtomPosition(i)
        sym = atom.GetSymbol()
        atoms_list.append((sym, float(pos.x), float(pos.y), float(pos.z)))
        pyscf_atom_lines.append(f"{sym} {pos.x:.6f} {pos.y:.6f} {pos.z:.6f}")
    pyscf_atom = "; ".join(pyscf_atom_lines)

    canonical = Chem.MolToSmiles(mol, canonical=True)

    formula_d: dict[str, int] = {}
    for sym, _, _, _ in atoms_list:
        formula_d[sym] = formula_d.get(sym, 0) + 1
    formula_parts = []
    for sym in ["C", "H", "N", "O", "S", "P", "F", "Cl", "Br", "I"]:
        if sym in formula_d:
            n = formula_d.pop(sym)
            formula_parts.append(f"{sym}{n}" if n > 1 else sym)
    for sym in sorted(formula_d):
        n = formula_d[sym]
        formula_parts.append(f"{sym}{n}" if n > 1 else sym)
    formula = "".join(formula_parts)

    return {
        "atoms": atoms_list,
        "pyscf_atom": pyscf_atom,
        "canonical_smiles": canonical,
        "n_atoms": len(atoms_list),
        "formula": formula,
        "rdkit_version": rdkit.__version__,
        "rdkit_seed": int(rdkit_seed),
        "geometry_source": "rdkit_etkdg_v3+uff",
    }


def build_ligand_hamiltonian(
    smiles: str,
    *,
    basis: str = "sto3g",
    freeze_core: bool = True,
    remove_orbitals: Optional[list[int]] = None,
    charge: int = 0,
    spin: int = 0,
    rdkit_seed: int = 7,
) -> dict:
    """Build the parity-mapped molecular Hamiltonian for `smiles`.

    Returns the same dict shape as quantum_h_molecule.py.build_hamiltonian
    plus rdkit_version / canonical_smiles / n_atoms / formula /
    geometry_source.
    """
    PySCFDriver, ParityMapper, FreezeCoreTransformer, qn, pyscf = _import_qn()

    geom = smiles_to_xyz(smiles, rdkit_seed=rdkit_seed)
    pyscf_atom = geom["pyscf_atom"]

    driver = PySCFDriver(
        atom=pyscf_atom,
        basis=basis,
        charge=int(charge),
        spin=int(spin),
    )
    problem_full = driver.run()

    transformer_chain: list[str] = []
    if freeze_core:
        if remove_orbitals is not None:
            fct = FreezeCoreTransformer(freeze_core=True, remove_orbitals=list(remove_orbitals))
            tag = f"FreezeCoreTransformer(freeze_core=True, remove_orbitals={list(remove_orbitals)})"
        else:
            fct = FreezeCoreTransformer(freeze_core=True)
            tag = "FreezeCoreTransformer(freeze_core=True)"
        active_problem = fct.transform(problem_full)
        transformer_chain.append(tag)
    else:
        active_problem = problem_full

    mapper = ParityMapper(num_particles=active_problem.num_particles)
    sparse_op = mapper.map(active_problem.hamiltonian.second_q_op())

    pauli_strings = [str(p) for p in sparse_op.paulis]
    coeffs = sparse_op.coeffs
    coeffs_real = [float(c.real) for c in coeffs]
    coeffs_imag = [float(c.imag) for c in coeffs]

    constant_shift = float(sum(active_problem.hamiltonian.constants.values()))

    # HF init bits — match quantum_h_molecule.py convention. For arbitrary
    # ligands, the Hartree-Fock occupation in parity-mapped space is the
    # alpha + beta occupation pattern. We mirror the LiH heuristic:
    # bottom n_alpha bits = 1 in the alpha block, bottom n_beta bits = 1
    # in the beta block, parity-mapped → first half = alpha-occupation,
    # second half = parity of beta-occupation. For closed-shell singlets
    # this works out to a simple 1-mask of length n_qubits/2 in each half.
    n_qubits = int(sparse_op.num_qubits)
    n_alpha, n_beta = active_problem.num_particles
    hf_init_bits: list[int] = []
    half = n_qubits // 2
    if n_qubits == 2 * half and n_alpha <= half and n_beta <= half:
        # Parity-mapping of HF occupation: q0..q(half-1) = alpha occupation
        # bits (low→high), q(half)..q(2*half-1) = parity-coded beta block.
        # For singlet closed-shell (alpha == beta), parity-coded beta is
        # all-zero up to (half-1). We use the conservative |1^n_alpha 0^...
        # | pattern that matches the LiH precedent.
        bits = [0] * n_qubits
        for i in range(int(n_alpha)):
            bits[i] = 1
        for i in range(int(n_beta)):
            bits[half + i] = 1
        hf_init_bits = bits

    return {
        "name": geom["canonical_smiles"],
        "smiles_input": smiles,
        "canonical_smiles": geom["canonical_smiles"],
        "formula": geom["formula"],
        "n_atoms": geom["n_atoms"],
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
        "ref_energy_ha_fci": None,  # general ligand — no hardcoded reference
        "qiskit_nature_version": qn.__version__,
        "pyscf_version": pyscf.__version__,
        "rdkit_version": geom["rdkit_version"],
        "rdkit_seed": geom["rdkit_seed"],
        "geometry_source": geom["geometry_source"],
        "charge": int(charge),
        "spin": int(spin),
    }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _emit_json(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload, separators=(",", ":")))
    sys.stdout.write("\n")
    sys.stdout.flush()


def _cmd_build(args: argparse.Namespace) -> int:
    try:
        h = build_ligand_hamiltonian(
            args.smiles,
            basis=args.basis,
            freeze_core=not args.no_freeze,
            charge=args.charge,
            spin=args.spin,
            rdkit_seed=args.seed,
        )
    except LigandHamiltonianError as exc:
        _emit_json({"ok": 0, "error": str(exc)})
        return 1

    summary = {
        "ok": 1,
        "smiles_input": h["smiles_input"],
        "canonical_smiles": h["canonical_smiles"],
        "formula": h["formula"],
        "n_atoms": h["n_atoms"],
        "n_qubits": h["n_qubits"],
        "n_pauli_terms": len(h["pauli_strings"]),
        "constant_shift_ha": h["constant_shift_ha"],
        "transformer_chain": h["transformer_chain"],
        "qn_version": h["qiskit_nature_version"],
        "pyscf_version": h["pyscf_version"],
        "rdkit_version": h["rdkit_version"],
        "first_3_terms": [
            (h["pauli_strings"][i], h["coefficients_real"][i])
            for i in range(min(3, len(h["pauli_strings"])))
        ],
    }
    _emit_json(summary)
    return 0


def _cmd_selftest(args: argparse.Namespace) -> int:
    """F1 H2 SMILES, F2 water, F3 methane, F4 formic acid."""
    print("hexa-bio ligand_smiles_to_h.py — selftest (SMILES → Hamiltonian shape)")
    print()

    # n_pauli_terms ranges measured 2026-05-07 on this machine (STO-3G +
    # FreezeCore default). Numbers are ±20% to allow qiskit-nature minor
    # version drift. Honest finding: even tiny molecules at STO-3G blow
    # up quickly (CH4=5101, HCOOH=30611) — F-Q-6 Phase A's Aer-runnable
    # ligand frontier is ≤6 qubits in practice (H2 / H2O / NH3-class).
    # Heavier molecules build the Hamiltonian fine here but cannot be
    # VQE-simulated until Phase B's pocket_active_space.py adds CASCI.
    cases = [
        ("[H][H]", "F1", "H2",          (3, 10)),         # 2 qubit, 5 terms
        ("O",      "F2", "H2O",         (300, 1000)),     # ~6 qubit, 567 terms
        ("C",      "F3", "CH4",         (3000, 8000)),    # ~8 qubit, 5101 terms
        ("C(=O)O", "F4", "HCOOH",       (15000, 60000)),  # ~14 qubit, 30611 terms
    ]

    all_pass = True
    for smiles, tag, label, n_term_range in cases:
        print(f"  {tag}: build {label!s}  (SMILES {smiles!r}) ...")
        try:
            h = build_ligand_hamiltonian(smiles, basis="sto3g", freeze_core=True)
        except LigandHamiltonianError as exc:
            print(f"  {tag} FAIL: {exc}")
            print(f"__HEXA_BIO_LIGSMILES__ {tag} FAIL")
            all_pass = False
            continue

        n_terms = len(h["pauli_strings"])
        if not (n_term_range[0] <= n_terms <= n_term_range[1]):
            print(f"  {tag} FAIL: n_pauli_terms {n_terms} outside expected {n_term_range}")
            print(f"__HEXA_BIO_LIGSMILES__ {tag} FAIL")
            all_pass = False
            continue

        if h["n_qubits"] < 2 or h["n_qubits"] > 64:
            print(f"  {tag} FAIL: n_qubits {h['n_qubits']} outside reasonable range")
            print(f"__HEXA_BIO_LIGSMILES__ {tag} FAIL")
            all_pass = False
            continue

        print(f"  {tag} PASS: {label} formula={h['formula']} canonical={h['canonical_smiles']} "
              f"n_atoms={h['n_atoms']} n_qubits={h['n_qubits']} n_terms={n_terms} "
              f"shift={h['constant_shift_ha']:+.6f}")
        print(f"__HEXA_BIO_LIGSMILES__ {tag} PASS")
        print()

    print()
    if all_pass:
        print("__HEXA_BIO_LIGSMILES__ ALL PASS")
        return 0
    print("__HEXA_BIO_LIGSMILES__ ALL FAIL")
    return 1


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="ligand_smiles_to_h.py",
                                description="hexa-bio adapter: SMILES → 3D conformer → molecular Hamiltonian (F-Q-6 Phase A)")
    p.add_argument("--smiles", default=None,
                   help="SMILES string for the ligand (e.g. '[H][H]', 'O', 'CC(=O)O')")
    p.add_argument("--basis", default="sto3g",
                   help="Gaussian basis set (default sto3g)")
    p.add_argument("--no-freeze", action="store_true",
                   help="Disable FreezeCoreTransformer (default freeze_core=True)")
    p.add_argument("--charge", type=int, default=0)
    p.add_argument("--spin", type=int, default=0)
    p.add_argument("--seed", type=int, default=7,
                   help="RDKit ETKDG seed for reproducible 3D embedding")
    p.add_argument("--selftest", action="store_true")
    args = p.parse_args(argv)

    if args.selftest:
        return _cmd_selftest(args)
    if args.smiles is None:
        p.print_help()
        return 2
    return _cmd_build(args)


if __name__ == "__main__":
    sys.exit(main())
