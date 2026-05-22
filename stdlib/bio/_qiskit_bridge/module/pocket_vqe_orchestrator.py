#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
pocket_vqe_orchestrator.py — F-Q-6 Phase A step 2: SMILES → VQE driver.

Thin orchestrator that chains
    ligand_smiles_to_h.build_ligand_hamiltonian
        → quantum_vqe_general.vqe_general
into a single CLI invocation. Both upstream modules already accept
dicts and return JSON-serializable dicts; this orchestrator just
plumbs SMILES through, optionally overrides the reference E0 (so the
delta-vs-reference channel works even though build_ligand_hamiltonian
does not hardcode FCI references for general SMILES), and emits a
provenance-rich result.

Public API
==========

    run_smiles_vqe(smiles: str, *,
                   basis: str = "sto3g",
                   freeze_core: bool = True,
                   ref_e0_ha: float | None = None,
                   max_iter: int = 200,
                   depth: int = 1,
                   use_pool: bool = True,
                   seed: int | None = None,
                   rdkit_seed: int = 7) -> dict

CLI usage
=========

    python3 pocket_vqe_orchestrator.py --smiles "[H][H]" --ref-e0 -1.137 \
        --max-iter 200
    python3 pocket_vqe_orchestrator.py --selftest

Honest caveats
==============

1. The ETKDGv3+UFF SMILES geometry is NOT QM-quality, so the VQE E
   on `[H][H]` will agree with Phase 1's hardcoded H2 path only
   loosely (typically within ±5 mHa given UFF's ~0.74 Å bond length
   vs the ~0.74 Å FCI minimum — coincidentally close for H2). The
   selftest tolerance is set wide (±20 mHa) to absorb basis/UFF drift
   plus NM stochastic init.

2. For ligands beyond ~10 qubits the AerPool wall scales fast: H2O
   (10 qubit, 567 Pauli terms) ≈ several minutes per energy eval, NM
   200 iter ≈ tens of minutes-to-hours. The selftest only runs the
   2-qubit H2 case to keep CI cycles short; H2O / CH4 invocations
   are exposed as CLI runs but not enforced in selftest.

3. nirmatrelvir / pocket-fragment ligands need Phase B's
   pocket_active_space.py to first reduce the active space — this
   orchestrator handles them at the API level but the underlying VQE
   will not converge in reasonable wall.

4. F-Q-6 Phase A sub-falsifier set (this commit lands sub-falsifier 1):
       F-Q-6-A1   SMILES → build → VQE round-trip H2 within 20 mHa
       F-Q-6-A2   first multi-qubit ligand (water) E ≤ HF reference  [deferred]
       F-Q-6-A3   AerPool wall scaling 4× → 10qubit         [deferred]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from typing import Optional

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ligand_smiles_to_h import (  # noqa: E402
    LigandHamiltonianError,
    build_ligand_hamiltonian,
)
from quantum_vqe_general import vqe_general  # noqa: E402


class PocketOrchestratorError(RuntimeError):
    pass


def run_smiles_vqe(
    smiles: str,
    *,
    basis: str = "sto3g",
    freeze_core: bool = True,
    ref_e0_ha: Optional[float] = None,
    max_iter: int = 200,
    depth: int = 1,
    initial_step: float = 0.4,
    use_pool: bool = True,
    seed: Optional[int] = None,
    rdkit_seed: int = 7,
    charge: int = 0,
    spin: int = 0,
    qmirror_root: Optional[str] = None,
) -> dict:
    """SMILES → 3D conformer → Hamiltonian → VQE → result dict."""
    t_total_start = time.time()

    try:
        h = build_ligand_hamiltonian(
            smiles,
            basis=basis,
            freeze_core=freeze_core,
            charge=charge,
            spin=spin,
            rdkit_seed=rdkit_seed,
        )
    except LigandHamiltonianError as exc:
        raise PocketOrchestratorError(f"hamiltonian build failed: {exc}") from exc

    # Inject the user-supplied reference E0 so vqe_general computes the
    # delta channel for general ligands (build_ligand_hamiltonian leaves
    # ref_energy_ha_fci=None for non-hardcoded molecules).
    if ref_e0_ha is not None:
        h = dict(h)
        h["ref_energy_ha_fci"] = float(ref_e0_ha)

    t_build = time.time() - t_total_start

    t_vqe_start = time.time()
    res = vqe_general(
        h,
        seed=seed,
        depth=depth,
        max_iter=max_iter,
        initial_step=initial_step,
        use_pool=use_pool,
        qmirror_root=qmirror_root,
    )
    t_vqe = time.time() - t_vqe_start

    out = dict(res)
    out.update({
        "smiles_input": smiles,
        "canonical_smiles": h["canonical_smiles"],
        "formula": h["formula"],
        "n_atoms": h["n_atoms"],
        "basis_set": h["basis_set"],
        "geometry_source": h["geometry_source"],
        "rdkit_version": h["rdkit_version"],
        "rdkit_seed": h["rdkit_seed"],
        "transformer_chain": h["transformer_chain"],
        "wall_build_seconds": t_build,
        "wall_vqe_seconds": t_vqe,
        "wall_total_seconds": time.time() - t_total_start,
        "ref_e0_ha_user": ref_e0_ha,
    })
    return out


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _emit_json(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload, separators=(",", ":")))
    sys.stdout.write("\n")
    sys.stdout.flush()


def _cmd_run(args: argparse.Namespace) -> int:
    try:
        out = run_smiles_vqe(
            args.smiles,
            basis=args.basis,
            freeze_core=not args.no_freeze,
            ref_e0_ha=args.ref_e0,
            max_iter=args.max_iter,
            depth=args.depth,
            initial_step=args.initial_step,
            use_pool=not args.no_pool,
            seed=args.seed,
            rdkit_seed=args.rdkit_seed,
            charge=args.charge,
            spin=args.spin,
            qmirror_root=args.qmirror_root,
        )
    except PocketOrchestratorError as exc:
        _emit_json({"ok": 0, "error": str(exc)})
        return 1
    _emit_json({"ok": 1, **out})
    return 0


def _cmd_selftest(args: argparse.Namespace) -> int:
    """F1: SMILES "[H][H]" → VQE → E within ±20 mHa of -1.137 Ha (Phase 1)."""
    print("hexa-bio pocket_vqe_orchestrator.py — selftest (F-Q-6 Phase A step 2)")
    print()

    smiles = "[H][H]"
    ref_e0 = -1.137306  # Phase 1 hardcoded H2 reference (FCI/STO-3G/0.74 Å)
    max_iter = args.max_iter or 200

    print(f"  F1: SMILES {smiles!r} → build → VQE  (ref E0 = {ref_e0:+.6f} Ha)")
    print(f"      max_iter={max_iter} depth=1 use_pool=True")

    t0 = time.time()
    try:
        out = run_smiles_vqe(
            smiles,
            basis="sto3g",
            freeze_core=True,
            ref_e0_ha=ref_e0,
            max_iter=max_iter,
            depth=1,
            use_pool=True,
            seed=42,  # deterministic for selftest
        )
    except PocketOrchestratorError as exc:
        print(f"  F1 FAIL: orchestrator error — {exc}")
        print("__HEXA_BIO_POCKET_VQE__ F1 FAIL")
        print("__HEXA_BIO_POCKET_VQE__ ALL FAIL")
        return 1
    wall = time.time() - t0

    print(f"      n_qubits={out['n_qubits']} n_pauli_terms={out['n_pauli_terms']}")
    print(f"      n_iter={out['n_iter']} converged={out['converged']} engine={out['engine']}")
    print(f"      energy_Ha       = {out['energy_Ha']:+.8f}")
    print(f"      delta_vs_ref    = {out['delta_vs_ref_e0_fci']*1e6:+.3f} µHa  ({out['delta_vs_ref_e0_fci']*1e3:+.4f} mHa)")
    print(f"      wall_total      = {out['wall_total_seconds']:.2f} s  (build={out['wall_build_seconds']:.2f} s vqe={out['wall_vqe_seconds']:.2f} s)")
    print(f"      bridge_timeouts = {out['bridge_timeouts']}")
    print(f"      formula={out['formula']} canonical={out['canonical_smiles']}")

    # Tolerance: ±20 mHa given UFF geometry vs FCI minimum drift + NM init.
    tol_mha = 20.0
    delta_mha = abs(out["delta_vs_ref_e0_fci"]) * 1e3
    if delta_mha > tol_mha:
        print(f"  F1 FAIL: |delta| {delta_mha:.4f} mHa > tol {tol_mha:.1f} mHa")
        print("__HEXA_BIO_POCKET_VQE__ F1 FAIL")
        print("__HEXA_BIO_POCKET_VQE__ ALL FAIL")
        return 1
    if out["n_qubits"] != 2:
        print(f"  F1 FAIL: H2 SMILES n_qubits {out['n_qubits']} != 2")
        print("__HEXA_BIO_POCKET_VQE__ F1 FAIL")
        print("__HEXA_BIO_POCKET_VQE__ ALL FAIL")
        return 1
    print(f"  F1 PASS: H2 SMILES → VQE within {delta_mha:.4f} mHa of FCI ref (tol {tol_mha:.0f} mHa); wall {wall:.1f} s")
    print("__HEXA_BIO_POCKET_VQE__ F1 PASS")
    print()

    print("__HEXA_BIO_POCKET_VQE__ ALL PASS")
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        prog="pocket_vqe_orchestrator.py",
        description="hexa-bio adapter: SMILES → VQE driver (F-Q-6 Phase A step 2)",
    )
    p.add_argument("--smiles", default=None,
                   help="SMILES string (e.g. '[H][H]', 'O', 'CC(=O)O')")
    p.add_argument("--basis", default="sto3g")
    p.add_argument("--no-freeze", action="store_true")
    p.add_argument("--ref-e0", type=float, default=None,
                   help="Override ref_energy_ha_fci to enable delta channel")
    p.add_argument("--max-iter", type=int, default=200)
    p.add_argument("--depth", type=int, default=1)
    p.add_argument("--initial-step", type=float, default=0.4)
    p.add_argument("--no-pool", action="store_true",
                   help="Disable AerPool (slow; only for diagnostics)")
    p.add_argument("--seed", type=int, default=None,
                   help="Optimizer θ0 seed; if None, qmirror QRNG draws one")
    p.add_argument("--rdkit-seed", type=int, default=7)
    p.add_argument("--charge", type=int, default=0)
    p.add_argument("--spin", type=int, default=0)
    p.add_argument("--qmirror-root", type=str, default=None)
    p.add_argument("--selftest", action="store_true")
    args = p.parse_args(argv)

    if args.selftest:
        return _cmd_selftest(args)
    if args.smiles is None:
        p.print_help()
        return 2
    return _cmd_run(args)


if __name__ == "__main__":
    sys.exit(main())
