#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
quantum_vqe_general.py — Phase B1 step 4: generalized VQE optimizer
for arbitrary molecules supported by quantum_h_molecule.

Phase 1 (quantum_vqe_h2.py) hardcoded n=2, 4 params, H2-specific
Pauli expectation. This module composes:

    quantum_h_molecule.build_hamiltonian       → hamiltonian dict
    quantum_ansatz_he.run_ansatz_state_vector  → 2^n amplitudes
    quantum_pauli_expectation_general.energy   → energy_Ha
    quantum_aer_pool.AerPool                   → ~20× wall reduction
    quantum_entropy_qmirror.qrng_seed_int      → reproducible random init
    stdlib Nelder-Mead                         → optimizer

Public API
==========

    vqe_general(hamiltonian: dict, *,
                theta0=None, seed=None,
                depth=1,
                max_iter=300, tol=1e-6, initial_step=0.4,
                live=False, qmirror_root=None,
                use_pool=True) -> dict

        Returns:
          {"molecule", "n_qubits", "depth", "n_params",
           "energy_Ha", "delta_vs_ref_e0_fci",
           "theta", "theta0", "seed", "seed_provenance",
           "n_iter", "converged", "engine",
           "wall_seconds", "bridge_timeouts",
           "constant_shift_ha", "n_pauli_terms",
           "use_pool"}

CLI usage
=========

    python3 quantum_vqe_general.py --molecule h2 --max-iter 80
    python3 quantum_vqe_general.py --molecule lih --depth 1 --max-iter 200
    python3 quantum_vqe_general.py --selftest

Honest caveats
==============

1. depth=1 hardware-efficient ansatz works for H2 (verified Phase 1)
   and is sufficient for LiH active-space-reduced 4-qubit (8 params)
   per Kandala 2017. Larger basis sets / open-shell systems may need
   depth=2+ or alternative ansatze (UCCSD); not in scope this cycle.
2. NM is local; multi-restart sweep (`quantum_vqe_h2_sweep.py`-style)
   is the production pattern for non-trivial landscapes. This module
   exposes only the single-restart kernel; sweep wrapper deferred.
3. n_qubits=4 with 100 Pauli terms costs ~6.4k ops + 1 Aer call per
   energy evaluation. Pool wall ~0.1-0.4 s/call → max_iter=200 ≈
   30-60 s total. Without pool the same run is ~10-30 min.
4. seed_provenance.tier="anu-legacy" (T1.a, 1 req/min throttle) is
   the default with no key provisioned. For sweeps that pull many
   seeds, route through explicit seed_offsets at the caller (ANU paid
   tier or batch fetch is a future cycle).
"""

from __future__ import annotations

import argparse
import json
import math
import os
import random
import sys
import time
from typing import Callable, List, Optional, Sequence, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from quantum_ansatz_he import (  # noqa: E402
    AerBridgeError,
    AnsatzHEError,
    n_params_for,
)
from quantum_pauli_expectation_general import energy as _energy_general  # noqa: E402


# Reuse Phase 1's NM (copied to avoid hard import dep cycle)
def _nelder_mead(
    fn: Callable[[List[float]], float],
    x0: List[float],
    *,
    initial_step: float = 0.5,
    max_iter: int = 300,
    tol: float = 1e-6,
) -> dict:
    n = len(x0)
    f0 = fn(list(x0))
    simplex = [(list(x0), f0)]
    for i in range(n):
        v = list(x0)
        v[i] = v[i] + initial_step
        simplex.append((v, fn(v)))

    history: List[Tuple[int, float]] = []
    converged = False
    n_iter = 0
    alpha, gamma, rho, sigma = 1.0, 2.0, 0.5, 0.5

    for it in range(1, max_iter + 1):
        n_iter = it
        simplex.sort(key=lambda p: p[1])
        history.append((it, simplex[0][1]))
        if simplex[-1][1] - simplex[0][1] < tol:
            converged = True
            break
        worst_x, _ = simplex[-1]
        centroid = [sum(p[0][i] for p in simplex[:-1]) / n for i in range(n)]
        x_r = [centroid[i] + alpha * (centroid[i] - worst_x[i]) for i in range(n)]
        f_r = fn(x_r)
        if simplex[0][1] <= f_r < simplex[-2][1]:
            simplex[-1] = (x_r, f_r)
            continue
        if f_r < simplex[0][1]:
            x_e = [centroid[i] + gamma * (x_r[i] - centroid[i]) for i in range(n)]
            f_e = fn(x_e)
            simplex[-1] = (x_e, f_e) if f_e < f_r else (x_r, f_r)
            continue
        if f_r < simplex[-1][1]:
            x_c = [centroid[i] + rho * (x_r[i] - centroid[i]) for i in range(n)]
            f_c = fn(x_c)
            if f_c < f_r:
                simplex[-1] = (x_c, f_c)
                continue
        else:
            x_c = [centroid[i] + rho * (worst_x[i] - centroid[i]) for i in range(n)]
            f_c = fn(x_c)
            if f_c < simplex[-1][1]:
                simplex[-1] = (x_c, f_c)
                continue
        best_x_only = simplex[0][0]
        new_simplex = [simplex[0]]
        for v, _f in simplex[1:]:
            v_new = [best_x_only[i] + sigma * (v[i] - best_x_only[i]) for i in range(n)]
            new_simplex.append((v_new, fn(v_new)))
        simplex = new_simplex

    simplex.sort(key=lambda p: p[1])
    return {
        "x": list(simplex[0][0]),
        "fx": simplex[0][1],
        "n_iter": n_iter,
        "converged": converged,
        "history": history,
    }


def _draw_qrng_seed(qmirror_root: Optional[str], live: bool) -> Tuple[int, dict]:
    from quantum_entropy_qmirror import qrng_seed_int  # noqa: E402
    return qrng_seed_int(32, live=live, qmirror_root=qmirror_root)


def _random_theta0(seed_int: int, n_params: int) -> List[float]:
    rng = random.Random(seed_int)
    return [rng.uniform(-math.pi, math.pi) for _ in range(n_params)]


def vqe_general(
    hamiltonian: dict,
    *,
    theta0: Optional[Sequence[float]] = None,
    seed: Optional[int] = None,
    depth: int = 1,
    max_iter: int = 300,
    tol: float = 1e-6,
    initial_step: float = 0.4,
    live: bool = False,
    qmirror_root: Optional[str] = None,
    use_pool: bool = True,
) -> dict:
    started = time.time()

    n_qubits = hamiltonian["n_qubits"]
    n_params = n_params_for(n_qubits, depth)

    seed_provenance: Optional[dict] = None
    if theta0 is None:
        if seed is None:
            seed_int, seed_provenance = _draw_qrng_seed(qmirror_root, live)
            seed = seed_int
        theta0 = _random_theta0(seed, n_params)
    theta0_list = [float(t) for t in theta0]
    if len(theta0_list) != n_params:
        raise ValueError(
            f"theta0 len {len(theta0_list)} != n_params {n_params}"
        )

    last_engine = ["unknown"]
    timeout_count = [0]
    PENALTY_HA = 100.0  # safe upper bound for any chemistry Hamiltonian

    if use_pool:
        from quantum_aer_pool import AerPool, AerPoolError  # noqa: E402
        with AerPool() as pool:
            def _fn(theta: List[float]) -> float:
                for attempt in (1, 2):
                    try:
                        e_val, meta = _energy_general(
                            theta, hamiltonian,
                            depth=depth, qmirror_root=qmirror_root, pool=pool,
                        )
                        last_engine[0] = meta["engine"]
                        return e_val
                    except (AerBridgeError, AerPoolError):
                        timeout_count[0] += 1
                        if attempt == 1:
                            time.sleep(0.2)
                            continue
                        return PENALTY_HA
            result = _nelder_mead(
                _fn, theta0_list,
                initial_step=initial_step, max_iter=max_iter, tol=tol,
            )
    else:
        def _fn(theta: List[float]) -> float:
            for attempt in (1, 2):
                try:
                    e_val, meta = _energy_general(
                        theta, hamiltonian,
                        depth=depth, qmirror_root=qmirror_root,
                    )
                    last_engine[0] = meta["engine"]
                    return e_val
                except AerBridgeError:
                    timeout_count[0] += 1
                    if attempt == 1:
                        time.sleep(1.0)
                        continue
                    return PENALTY_HA
        result = _nelder_mead(
            _fn, theta0_list,
            initial_step=initial_step, max_iter=max_iter, tol=tol,
        )

    wall = time.time() - started
    ref_e0 = hamiltonian.get("ref_energy_ha_fci")
    delta = (result["fx"] - ref_e0) if ref_e0 is not None else None

    return {
        "molecule": hamiltonian.get("name"),
        "n_qubits": n_qubits,
        "depth": depth,
        "n_params": n_params,
        "n_pauli_terms": len(hamiltonian["pauli_strings"]),
        "constant_shift_ha": hamiltonian["constant_shift_ha"],
        "ref_energy_ha_fci": ref_e0,
        "energy_Ha": result["fx"],
        "delta_vs_ref_e0_fci": delta,
        "theta": result["x"],
        "theta0": theta0_list,
        "seed": seed,
        "seed_provenance": seed_provenance,
        "n_iter": result["n_iter"],
        "converged": result["converged"],
        "engine": last_engine[0],
        "wall_seconds": wall,
        "bridge_timeouts": timeout_count[0],
        "use_pool": use_pool,
    }


# ---------------------------------------------------------------------------
# CLI / selftest
# ---------------------------------------------------------------------------


def _emit_json(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload, separators=(",", ":")))
    sys.stdout.write("\n")
    sys.stdout.flush()


def _format_result(r: dict) -> str:
    delta_line = ""
    if r["delta_vs_ref_e0_fci"] is not None:
        delta_line = f"  delta_FCI = {r['delta_vs_ref_e0_fci']*1e6:+.3f} µHa  ({r['delta_vs_ref_e0_fci']*1e3:+.4f} mHa)"
    return (
        f"VQE [{r['molecule']}] result:\n"
        f"  n_qubits={r['n_qubits']} depth={r['depth']} n_params={r['n_params']} "
        f"n_pauli_terms={r['n_pauli_terms']}\n"
        f"  energy_Ha = {r['energy_Ha']:+.7f}  "
        f"(FCI ref = {r['ref_energy_ha_fci']})\n"
        f"{delta_line}\n"
        f"  n_iter={r['n_iter']} converged={r['converged']} engine={r['engine']}\n"
        f"  wall={r['wall_seconds']:.2f}s  bridge_timeouts={r['bridge_timeouts']}  "
        f"use_pool={r['use_pool']}"
    )


def _cmd_run(args: argparse.Namespace) -> int:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from quantum_h_molecule import build_hamiltonian, HamiltonianBuilderError
    try:
        h = build_hamiltonian(args.molecule, r_angstrom=args.r)
    except HamiltonianBuilderError as exc:
        _emit_json({"ok": 0, "error": str(exc)})
        return 1
    try:
        r = vqe_general(
            h,
            theta0=args.theta0,
            seed=args.seed,
            depth=args.depth,
            max_iter=args.max_iter,
            tol=args.tol,
            live=args.live,
            qmirror_root=args.qmirror_root,
            use_pool=args.use_pool,
        )
    except (AnsatzHEError, AerBridgeError, ValueError) as exc:
        _emit_json({"ok": 0, "error": str(exc)})
        return 1
    print(_format_result(r))
    _emit_json({
        "ok": 1,
        "molecule": r["molecule"],
        "energy_Ha": r["energy_Ha"],
        "delta_uHa": (r["delta_vs_ref_e0_fci"] * 1e6) if r["delta_vs_ref_e0_fci"] is not None else None,
        "n_iter": r["n_iter"],
        "converged": r["converged"],
        "engine": r["engine"],
        "wall_seconds": r["wall_seconds"],
        "bridge_timeouts": r["bridge_timeouts"],
        "seed": r["seed"],
        "seed_provenance": r["seed_provenance"],
    })
    return 0


def _cmd_selftest(args: argparse.Namespace) -> int:
    """Infrastructure-only selftest. Verifies the optimizer composes
    h_molecule + ansatz_he + pauli_expectation_general + (optionally)
    AerPool + qrng_seed_int correctly. Does NOT verify FCI convergence
    (that's the production smoke's job; LiH 200-iter NM ≈ 30-60s
    wall and lands separately as B1 step 5)."""
    print("hexa-bio quantum_vqe_general.py — selftest (Phase B1 step 4 infrastructure)")
    print()

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from quantum_h_molecule import build_hamiltonian

    # F1: H2 explicit theta0 small-iter — sanity that NM runs
    print(f"  F1: H2 vqe_general(theta0=[0]*4, max_iter={args.max_iter}, use_pool={args.use_pool}) ...")
    try:
        h_h2 = build_hamiltonian("h2", r_angstrom=0.74)
    except Exception as exc:
        print(f"  F1 FAIL: build_hamiltonian: {exc}")
        print("__HEXA_BIO_QVQEGEN__ ALL FAIL")
        return 1
    try:
        r1 = vqe_general(
            h_h2,
            theta0=[0.0] * 4, max_iter=args.max_iter, tol=args.tol,
            use_pool=args.use_pool,
        )
    except Exception as exc:
        print(f"  F1 FAIL: vqe_general: {exc}")
        print("__HEXA_BIO_QVQEGEN__ F1 FAIL")
        print("__HEXA_BIO_QVQEGEN__ ALL FAIL")
        return 1
    if r1["n_iter"] < 1 or not math.isfinite(r1["energy_Ha"]):
        print(f"  F1 FAIL: shape: n_iter={r1['n_iter']} E={r1['energy_Ha']}")
        print("__HEXA_BIO_QVQEGEN__ F1 FAIL")
        print("__HEXA_BIO_QVQEGEN__ ALL FAIL")
        return 1
    print(_format_result(r1))
    print("__HEXA_BIO_QVQEGEN__ F1 PASS")
    print()

    # F2: LiH explicit theta0 small-iter — sanity for n=4
    print(f"  F2: LiH vqe_general(theta0=[0]*8, max_iter={args.max_iter}, use_pool={args.use_pool}) ...")
    try:
        h_lih = build_hamiltonian("lih", r_angstrom=1.5)
    except Exception as exc:
        print(f"  F2 FAIL: build_hamiltonian: {exc}")
        print("__HEXA_BIO_QVQEGEN__ F2 FAIL")
        print("__HEXA_BIO_QVQEGEN__ ALL FAIL")
        return 1
    try:
        r2 = vqe_general(
            h_lih,
            theta0=[0.0] * 8, max_iter=args.max_iter, tol=args.tol,
            use_pool=args.use_pool,
        )
    except Exception as exc:
        print(f"  F2 FAIL: vqe_general: {exc}")
        print("__HEXA_BIO_QVQEGEN__ F2 FAIL")
        print("__HEXA_BIO_QVQEGEN__ ALL FAIL")
        return 1
    if r2["n_iter"] < 1 or not math.isfinite(r2["energy_Ha"]):
        print(f"  F2 FAIL: shape: n_iter={r2['n_iter']} E={r2['energy_Ha']}")
        print("__HEXA_BIO_QVQEGEN__ F2 FAIL")
        print("__HEXA_BIO_QVQEGEN__ ALL FAIL")
        return 1
    print(_format_result(r2))
    print("__HEXA_BIO_QVQEGEN__ F2 PASS")

    print()
    print("__HEXA_BIO_QVQEGEN__ ALL PASS")
    print("(NOTE: full FCI convergence verified separately via")
    print(" production smoke runs — see docs §17/§19/§21/§23 for H2,")
    print(" §24 (forthcoming) for LiH B1 step 5.)")
    return 0


def _parse_theta(s: str) -> List[float]:
    return [float(p.strip()) for p in s.split(",")]


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="quantum_vqe_general.py")
    p.add_argument("--qmirror-root", default=None)
    p.add_argument("--molecule", choices=["h2", "lih"], default="h2")
    p.add_argument("--r", type=float, default=None)
    p.add_argument("--depth", type=int, default=1)
    p.add_argument("--theta0", type=_parse_theta, default=None)
    p.add_argument("--seed", type=int, default=None)
    p.add_argument("--max-iter", type=int, default=300)
    p.add_argument("--tol", type=float, default=1e-6)
    p.add_argument("--live", action="store_true")
    p.add_argument("--use-pool", action="store_true", default=True)
    p.add_argument("--no-pool", dest="use_pool", action="store_false")
    p.add_argument("--selftest", action="store_true")
    args = p.parse_args(argv)

    if args.selftest:
        if args.max_iter == 300:
            args.max_iter = 20
        return _cmd_selftest(args)
    return _cmd_run(args)


if __name__ == "__main__":
    sys.exit(main())
