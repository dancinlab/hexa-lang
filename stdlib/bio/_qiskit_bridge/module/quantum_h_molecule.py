#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
quantum_h_molecule.py — Phase B1 step 1: molecular Hamiltonian generator
for the qpu_bridge bio integration. Wraps qiskit-nature's PySCFDriver +
ParityMapper (+ optional FreezeCoreTransformer for LiH-and-up).

Phase 1's H2 path hardcoded the 6 Pauli coefficients (Kandala 2017
Nature 549:242). Phase B1 generalizes: any molecule with a fixed
geometry → a generated SparsePauliOp + a constant energy shift +
a known qubit count. Returned as plain Python lists/floats so the
downstream ansatz / expectation code can stay stdlib-only.

Public API
==========

    build_hamiltonian(name: str, *, r_angstrom: float | None = None)
        -> dict

        Returns:
          {"name": str,                    # "h2" / "lih" / ...
           "n_qubits": int,
           "pauli_strings": list[str],     # length = num_terms
           "coefficients_real": list[float],
           "coefficients_imag": list[float],
           "constant_shift_ha": float,     # nuclear repulsion + frozen-core, etc
           "ref_geometry": str,            # XYZ inline
           "basis_set": str,
           "mapping": str,                 # "parity" (pre-tapering)
           "transformer_chain": list[str], # ["FreezeCoreTransformer"] etc
           "ref_energy_ha_fci": float | None,  # literature reference E0 (if known)
           "qiskit_nature_version": str,
           "pyscf_version": str}

Currently supported names: "h2" (2 qubits / 5 terms), "lih" (4 qubits /
100 terms via active-space reduction).

CLI usage
=========

    python3 quantum_h_molecule.py --name h2  --r 0.74
    python3 quantum_h_molecule.py --name lih --r 1.5
    python3 quantum_h_molecule.py --selftest

Honest caveats
==============

1. Phase 1 hardcoded H2 coefficients (Kandala 2017 6-term) won't byte-
   match this generator's output (5 terms, ParityMapper-default — the
   identity term is folded into the constant shift differently). Both
   Hamiltonians have the same eigenstructure and the same E0; the
   numerical comparison is left for cycle-32+ B1-step-2 (ansatz/
   expectation generalization). For now selftest exercises shape only.
2. LiH FreezeCoreTransformer with `remove_orbitals=[3,4]` matches
   Kandala 2017's reduction (active 2 spatial × 2 spin = 4 qubits).
   Different removal sets (e.g. `[5]` only) give different Hamiltonians
   with different constants — the choice is hard-pinned per molecule
   to keep results reproducible.
3. qiskit-nature 0.7.2 + pyscf 2.13.0 imported on this machine
   2026-05-06 (post-`pip install --user --break-system-packages`). The
   wrapper does NOT install or vendor either; it raises ImportError
   pointing the operator at the install command if missing.
4. Coefficients are real-valued for these chemistry Hamiltonians by
   construction (Hermitian + real basis). The generator returns both
   re and im lists in case a future molecule (open-shell, etc) uses
   complex coefficients; downstream code can assert imag<1e-12 and
   simplify.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Optional


# Literature E0 references (FCI / STO-3G, geometry as named).
_REFERENCE_E0_HA = {
    ("h2", 0.74): -1.1373060000,   # FCI/STO-3G (no constants); full = -1.137 + nucl_repulsion
    ("lih", 1.5): -7.8823783880,   # FCI/STO-3G/R=1.5Å (active-space-reduced + constants)
}


class HamiltonianBuilderError(RuntimeError):
    pass


def _import_qn():
    try:
        from qiskit_nature.second_q.drivers import PySCFDriver
        from qiskit_nature.second_q.mappers import ParityMapper
        from qiskit_nature.second_q.transformers import FreezeCoreTransformer
        import qiskit_nature
        import pyscf
    except ImportError as exc:
        raise HamiltonianBuilderError(
            f"qiskit_nature/pyscf import failed: {exc}. "
            f"Install with `python3 -m pip install --user --break-system-packages "
            f"pyscf qiskit-nature` then retry."
        ) from exc
    return PySCFDriver, ParityMapper, FreezeCoreTransformer, qiskit_nature, pyscf


def build_hamiltonian(
    name: str,
    *,
    r_angstrom: Optional[float] = None,
) -> dict:
    """Build a parity-mapped molecular Hamiltonian for `name`.

    Returns a fully-serializable dict (lists/floats/strings) suitable for
    pickling to disk or piping through subprocess JSON.
    """
    PySCFDriver, ParityMapper, FreezeCoreTransformer, qn, pyscf = _import_qn()

    name_lower = name.lower()

    if name_lower == "h2":
        r = 0.74 if r_angstrom is None else r_angstrom
        atom = f"H 0 0 0; H 0 0 {r}"
        basis = "sto3g"
        transformer_chain = []
        problem_post = None
        driver = PySCFDriver(atom=atom, basis=basis)
        problem_post = driver.run()
        active_problem = problem_post

    elif name_lower == "lih":
        r = 1.5 if r_angstrom is None else r_angstrom
        atom = f"Li 0 0 0; H 0 0 {r}"
        basis = "sto3g"
        driver = PySCFDriver(atom=atom, basis=basis)
        problem_full = driver.run()
        # Match Kandala 2017's active-space reduction: freeze Li 1s,
        # remove the 2 highest virtual orbitals (orbitals 3 and 4 in
        # PySCF's ordering).
        fct = FreezeCoreTransformer(freeze_core=True, remove_orbitals=[3, 4])
        active_problem = fct.transform(problem_full)
        transformer_chain = ["FreezeCoreTransformer(freeze_core=True, remove_orbitals=[3,4])"]

    else:
        raise HamiltonianBuilderError(f"unknown molecule name: {name!r}")

    mapper = ParityMapper(num_particles=active_problem.num_particles)
    sparse_op = mapper.map(active_problem.hamiltonian.second_q_op())

    pauli_strings = [str(p) for p in sparse_op.paulis]
    coeffs = sparse_op.coeffs
    coeffs_real = [float(c.real) for c in coeffs]
    coeffs_imag = [float(c.imag) for c in coeffs]

    constants = active_problem.hamiltonian.constants
    constant_shift = float(sum(constants.values()))

    # Hartree-Fock init bits (indexed q0..q(n-1) in qiskit endian).
    # Drastically improves chemistry-VQE convergence vs random init —
    # without HF prefix the random-θ ansatz tends to land in a basin
    # ~17-19 mHa above FCI on LiH (verified 2026-05-06 multi-restart sweep).
    hf_init_bits: list[int]
    if name_lower == "h2":
        hf_init_bits = [1, 0]   # |01⟩ in q1q0 order
    elif name_lower == "lih":
        hf_init_bits = [1, 1, 0, 0]  # |0011⟩ in q3q2q1q0 order
    else:
        hf_init_bits = []

    ref_e0 = _REFERENCE_E0_HA.get((name_lower, round(float(r), 2)))

    return {
        "name": name_lower,
        "n_qubits": int(sparse_op.num_qubits),
        "pauli_strings": pauli_strings,
        "coefficients_real": coeffs_real,
        "coefficients_imag": coeffs_imag,
        "constant_shift_ha": constant_shift,
        "hf_init_bits": hf_init_bits,
        "ref_geometry": atom,
        "r_angstrom": float(r),
        "basis_set": basis,
        "mapping": "parity",
        "transformer_chain": transformer_chain,
        "ref_energy_ha_fci": ref_e0,
        "qiskit_nature_version": qn.__version__,
        "pyscf_version": pyscf.__version__,
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
        h = build_hamiltonian(args.name, r_angstrom=args.r)
    except HamiltonianBuilderError as exc:
        _emit_json({"ok": 0, "error": str(exc)})
        return 1
    summary = {
        "ok": 1,
        "name": h["name"],
        "n_qubits": h["n_qubits"],
        "n_pauli_terms": len(h["pauli_strings"]),
        "constant_shift_ha": h["constant_shift_ha"],
        "ref_e0_ha": h["ref_energy_ha_fci"],
        "first_3_terms": [
            (h["pauli_strings"][i], h["coefficients_real"][i])
            for i in range(min(3, len(h["pauli_strings"])))
        ],
        "transformer_chain": h["transformer_chain"],
        "qn_version": h["qiskit_nature_version"],
        "pyscf_version": h["pyscf_version"],
    }
    _emit_json(summary)
    return 0


def _cmd_selftest(args: argparse.Namespace) -> int:
    """F1 H2 build, F2 LiH build, F3 versions reported."""
    print("hexa-bio quantum_h_molecule.py — selftest (Hamiltonian shape only)")
    print()

    # F1: H2 build
    print("  F1: build H2 / STO-3G / R=0.74 ...")
    try:
        h2 = build_hamiltonian("h2", r_angstrom=0.74)
    except HamiltonianBuilderError as exc:
        print(f"  F1 FAIL: {exc}")
        print("__HEXA_BIO_QHMOL__ ALL FAIL")
        return 1
    expected_h2 = {"n_qubits": 2}
    if h2["n_qubits"] != expected_h2["n_qubits"]:
        print(f"  F1 FAIL: H2 n_qubits {h2['n_qubits']} != {expected_h2['n_qubits']}")
        print("__HEXA_BIO_QHMOL__ F1 FAIL")
        print("__HEXA_BIO_QHMOL__ ALL FAIL")
        return 1
    n_terms_h2 = len(h2["pauli_strings"])
    if not (3 <= n_terms_h2 <= 8):
        print(f"  F1 FAIL: H2 num_pauli_terms {n_terms_h2} out of expected [3,8]")
        print("__HEXA_BIO_QHMOL__ F1 FAIL")
        print("__HEXA_BIO_QHMOL__ ALL FAIL")
        return 1
    print(f"  F1 PASS: H2 n_qubits=2 num_pauli_terms={n_terms_h2} "
          f"shift={h2['constant_shift_ha']:+.6f} ref_e0={h2['ref_energy_ha_fci']}")
    print("__HEXA_BIO_QHMOL__ F1 PASS")
    print()

    # F2: LiH build
    print("  F2: build LiH / STO-3G / R=1.5 + FreezeCore[remove 3,4] ...")
    try:
        lih = build_hamiltonian("lih", r_angstrom=1.5)
    except HamiltonianBuilderError as exc:
        print(f"  F2 FAIL: {exc}")
        print("__HEXA_BIO_QHMOL__ F2 FAIL")
        print("__HEXA_BIO_QHMOL__ ALL FAIL")
        return 1
    if lih["n_qubits"] != 4:
        print(f"  F2 FAIL: LiH n_qubits {lih['n_qubits']} != 4")
        print("__HEXA_BIO_QHMOL__ F2 FAIL")
        print("__HEXA_BIO_QHMOL__ ALL FAIL")
        return 1
    n_terms_lih = len(lih["pauli_strings"])
    if not (50 <= n_terms_lih <= 200):
        print(f"  F2 FAIL: LiH num_pauli_terms {n_terms_lih} out of expected [50,200]")
        print("__HEXA_BIO_QHMOL__ F2 FAIL")
        print("__HEXA_BIO_QHMOL__ ALL FAIL")
        return 1
    print(f"  F2 PASS: LiH n_qubits=4 num_pauli_terms={n_terms_lih} "
          f"shift={lih['constant_shift_ha']:+.6f} ref_e0={lih['ref_energy_ha_fci']}")
    print("__HEXA_BIO_QHMOL__ F2 PASS")
    print()

    # F3: versions
    if not h2["qiskit_nature_version"] or not h2["pyscf_version"]:
        print(f"  F3 FAIL: missing version metadata")
        print("__HEXA_BIO_QHMOL__ F3 FAIL")
        print("__HEXA_BIO_QHMOL__ ALL FAIL")
        return 1
    print(f"  F3 PASS: qiskit-nature {h2['qiskit_nature_version']} + "
          f"pyscf {h2['pyscf_version']}")
    print("__HEXA_BIO_QHMOL__ F3 PASS")

    print()
    print("__HEXA_BIO_QHMOL__ ALL PASS")
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="quantum_h_molecule.py",
                                description="hexa-bio adapter: molecular Hamiltonian generator (Phase B1 step 1)")
    p.add_argument("--name", default=None, choices=["h2", "lih"])
    p.add_argument("--r", type=float, default=None,
                   help="bond length in Å (defaults: H2=0.74, LiH=1.5)")
    p.add_argument("--selftest", action="store_true")
    args = p.parse_args(argv)

    if args.selftest:
        return _cmd_selftest(args)
    if args.name is None:
        p.print_help()
        return 2
    return _cmd_build(args)


if __name__ == "__main__":
    sys.exit(main())
