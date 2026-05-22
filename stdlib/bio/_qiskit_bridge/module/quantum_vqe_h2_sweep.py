#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
quantum_vqe_h2_sweep.py — Phase A5 of the qpu_bridge bio integration.

Multi-restart wrapper around A4's vqe_h2() Nelder-Mead optimizer.
Spawns N independent NM runs from independent qrng-seeded random
inits and reports the best energy. The intent is to mitigate NM's
local-minimum sensitivity in 4D ansatz landscape — a single restart
from zero init reaches E ≈ -1.83 (per Phase A3 grid scan), but the
true H2 ground state E0 = -1.9153706 Ha may require a few restarts
to find the basin.

Wall budget reality
===================

Each vqe_h2(max_iter=N) wall ≈ N × 1.8 s (Aer cold-start dominated;
see docs §13.8). N=200 ≈ 6 min per restart. 10 restarts ≈ 1 hour.

Selftest defaults to n_repeats=2, max_iter=10 → ~30 s × 2 = ~60 s
(infrastructure only). Production CLI (`--n-repeats 10 --max-iter 200`)
is a manual smoke test the user runs once and pastes results into
docs §14.

Public API
==========

    vqe_h2_sweep(*, n_repeats=10, max_iter=200, tol=1e-6,
                 live=False, qmirror_root=None, seed_offsets=None)
        -> dict

        Run n_repeats independent vqe_h2 trials, each with a freshly
        drawn qrng seed (or `seed_offsets[i]` if provided as deterministic
        override). Returns:

            {"n_repeats", "results": [vqe_h2 dicts ...],
             "best_energy_Ha", "best_theta", "best_idx",
             "median_energy_Ha", "wall_seconds_total",
             "delta_best_vs_E0"}

CLI usage
=========

    python3 quantum_vqe_h2_sweep.py --n-repeats 3 --max-iter 60
    python3 quantum_vqe_h2_sweep.py --selftest

Selftest emits:

    __HEXA_BIO_QVQE_SWEEP__ F1 PASS    # 2-restart infrastructure
    __HEXA_BIO_QVQE_SWEEP__ ALL PASS

Honest caveats
==============

1. The 10-repeat × 200-iter production sweep is NOT in the selftest
   wall budget — selftest only verifies the multi-restart bookkeeping
   (n_repeats results, best/median computed). Full E0 ±0.05 Ha
   convergence verdict is paste-into-docs from a manual smoke run.
2. Restart inits are independent qrng pulls (live tier disabled by
   default → mock LCG, deterministic per seed). For reproducible
   sweeps pass `seed_offsets=[s0, s1, ...]` instead of fresh qrng.
3. Each restart spawns its own bridge subprocesses; no parallelism.
   Future optimization (qmirror Phase 4 long-lived bridge) would
   collapse this from N×wall to ~wall + N·δ.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import statistics
import sys
import time
from typing import List, Optional, Sequence

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from quantum_pauli_expectation import H2_E0_EXACT  # noqa: E402
from quantum_vqe_h2 import vqe_h2  # noqa: E402
from quantum_ansatz_h2 import AerBridgeError, AnsatzError  # noqa: E402


def vqe_h2_sweep(
    *,
    n_repeats: int = 10,
    max_iter: int = 200,
    tol: float = 1e-6,
    live: bool = False,
    qmirror_root: Optional[str] = None,
    seed_offsets: Optional[Sequence[int]] = None,
    use_pool: bool = False,
) -> dict:
    """Multi-restart wrapper. `use_pool=True` propagates to each vqe_h2
    restart (each spawns + tears down its own AerPool). For production
    sweeps with many restarts × moderate max_iter this gives ~5-10×
    wall reduction; pool spawn ~5s amortizes per restart."""
    if n_repeats < 1:
        raise ValueError(f"n_repeats must be >= 1 (got {n_repeats})")
    if seed_offsets is not None and len(seed_offsets) != n_repeats:
        raise ValueError(
            f"seed_offsets len {len(seed_offsets)} != n_repeats {n_repeats}"
        )

    started = time.time()
    results: List[dict] = []
    for i in range(n_repeats):
        seed = seed_offsets[i] if seed_offsets is not None else None
        r = vqe_h2(
            seed=seed,
            max_iter=max_iter,
            tol=tol,
            live=live,
            qmirror_root=qmirror_root,
            use_pool=use_pool,
        )
        results.append(r)

    energies = [r["energy_Ha"] for r in results]
    best_idx = min(range(n_repeats), key=lambda i: energies[i])
    best_energy = energies[best_idx]
    best_theta = results[best_idx]["theta"]
    median_energy = statistics.median(energies)

    return {
        "n_repeats": n_repeats,
        "max_iter": max_iter,
        "results": results,
        "best_energy_Ha": best_energy,
        "best_theta": best_theta,
        "best_idx": best_idx,
        "median_energy_Ha": median_energy,
        "wall_seconds_total": time.time() - started,
        "delta_best_vs_E0": best_energy - H2_E0_EXACT,
    }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _emit_json(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload, separators=(",", ":")))
    sys.stdout.write("\n")
    sys.stdout.flush()


def _format_summary(s: dict) -> str:
    lines = [
        f"  n_repeats         = {s['n_repeats']}  max_iter = {s['max_iter']}",
        f"  best_energy_Ha    = {s['best_energy_Ha']:+.7f}  "
        f"(E0_exact = {H2_E0_EXACT:+.7f}, delta = {s['delta_best_vs_E0']:+.7f})",
        f"  median_energy_Ha  = {s['median_energy_Ha']:+.7f}",
        f"  best_theta        = [{', '.join(f'{t:+.4f}' for t in s['best_theta'])}]",
        f"  best_idx          = {s['best_idx']}/{s['n_repeats']-1}",
        f"  wall_total        = {s['wall_seconds_total']:.2f}s",
    ]
    energies = [r["energy_Ha"] for r in s["results"]]
    lines.append("  per-restart energies:")
    for i, e in enumerate(energies):
        lines.append(f"    [{i}] E = {e:+.6f} Ha  delta = {e - H2_E0_EXACT:+.6f}")
    return "\n".join(lines)


def _cmd_run(args: argparse.Namespace) -> int:
    seed_offsets = None
    if args.seeds is not None:
        try:
            seed_offsets = [int(s.strip()) for s in args.seeds.split(",")]
        except ValueError as exc:
            _emit_json({"ok": 0, "error": f"--seeds parse failed: {exc}"})
            return 1
        if len(seed_offsets) != args.n_repeats:
            _emit_json({"ok": 0, "error": f"--seeds len {len(seed_offsets)} != n_repeats {args.n_repeats}"})
            return 1
    try:
        s = vqe_h2_sweep(
            n_repeats=args.n_repeats,
            max_iter=args.max_iter,
            tol=args.tol,
            live=args.live,
            qmirror_root=args.qmirror_root,
            use_pool=args.use_pool,
            seed_offsets=seed_offsets,
        )
    except (AerBridgeError, AnsatzError, ValueError) as exc:
        _emit_json({"ok": 0, "error": str(exc)})
        return 1
    print("VQE H2 sweep summary:")
    print(_format_summary(s))
    _emit_json({
        "ok": 1,
        "n_repeats": s["n_repeats"],
        "max_iter": s["max_iter"],
        "best_energy_Ha": s["best_energy_Ha"],
        "median_energy_Ha": s["median_energy_Ha"],
        "delta_best_vs_E0": s["delta_best_vs_E0"],
        "best_theta": s["best_theta"],
        "best_idx": s["best_idx"],
        "wall_seconds_total": s["wall_seconds_total"],
        "per_restart_energies": [r["energy_Ha"] for r in s["results"]],
    })
    return 0


def _cmd_selftest(args: argparse.Namespace) -> int:
    """F1: 2-restart × max_iter=10 infrastructure check.

    Wall budget: 2 × ~30 fn calls × 1.8 s = ~110 s. Use bash --timeout
    600000 (10 min) for the bg invocation.
    """
    print("hexa-bio quantum_vqe_h2_sweep.py — selftest (infrastructure only)")
    print(f"  H2 E0 (exact, for reference) = {H2_E0_EXACT:+.7f} Ha")
    n_r = args.n_repeats or 2
    m_i = args.max_iter or 10
    print(f"  config: n_repeats={n_r} max_iter={m_i}  (selftest scale)")
    print("")

    try:
        # selftest defaults: use_pool=True (B4 closure 2026-05-06, ~5×
        # wall reduction with byte-identical results) + explicit
        # seed_offsets to skip qrng pull (qmirror cli wall is jittery
        # under contention; selftest wants determinism + minimal
        # external dependence). Production callers omit seed_offsets
        # and pay the qrng pull cost.
        s = vqe_h2_sweep(
            n_repeats=n_r,
            max_iter=m_i,
            tol=args.tol,
            qmirror_root=args.qmirror_root,
            use_pool=True,
            seed_offsets=[42 + 100 * i for i in range(n_r)],
        )
    except (AerBridgeError, AnsatzError, ValueError) as exc:
        print(f"  F1 FAIL: vqe_h2_sweep raised: {exc}")
        print("__HEXA_BIO_QVQE_SWEEP__ ALL FAIL")
        return 1

    print(_format_summary(s))

    required = (
        "n_repeats", "results", "best_energy_Ha", "best_theta",
        "best_idx", "median_energy_Ha", "wall_seconds_total",
        "delta_best_vs_E0",
    )
    for k in required:
        if k not in s:
            print(f"  F1 FAIL: missing key {k!r}")
            print("__HEXA_BIO_QVQE_SWEEP__ F1 FAIL")
            print("__HEXA_BIO_QVQE_SWEEP__ ALL FAIL")
            return 1

    if len(s["results"]) != n_r:
        print(f"  F1 FAIL: results len {len(s['results'])} != n_repeats {n_r}")
        print("__HEXA_BIO_QVQE_SWEEP__ F1 FAIL")
        print("__HEXA_BIO_QVQE_SWEEP__ ALL FAIL")
        return 1

    energies = [r["energy_Ha"] for r in s["results"]]
    if s["best_energy_Ha"] != min(energies):
        print(f"  F1 FAIL: best_energy {s['best_energy_Ha']} != min(energies) {min(energies)}")
        print("__HEXA_BIO_QVQE_SWEEP__ F1 FAIL")
        print("__HEXA_BIO_QVQE_SWEEP__ ALL FAIL")
        return 1
    if not math.isfinite(s["best_energy_Ha"]):
        print(f"  F1 FAIL: best_energy non-finite ({s['best_energy_Ha']})")
        print("__HEXA_BIO_QVQE_SWEEP__ F1 FAIL")
        print("__HEXA_BIO_QVQE_SWEEP__ ALL FAIL")
        return 1
    if not (0 <= s["best_idx"] < n_r):
        print(f"  F1 FAIL: best_idx {s['best_idx']} out of range")
        print("__HEXA_BIO_QVQE_SWEEP__ F1 FAIL")
        print("__HEXA_BIO_QVQE_SWEEP__ ALL FAIL")
        return 1

    print("__HEXA_BIO_QVQE_SWEEP__ F1 PASS")
    print("")
    print("__HEXA_BIO_QVQE_SWEEP__ ALL PASS")
    print("(NOTE: full 10-restart × 200-iter production run is a manual")
    print(" smoke test; results paste into docs/qpu_bridge_bio_application.md §14.)")
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        prog="quantum_vqe_h2_sweep.py",
        description="hexa-bio adapter: H2 VQE multi-restart sweep (Phase A5)",
    )
    p.add_argument("--qmirror-root", default=None)
    p.add_argument("--n-repeats", type=int, default=None)
    p.add_argument("--max-iter", type=int, default=None)
    p.add_argument("--tol", type=float, default=1e-6)
    p.add_argument("--seeds", type=str, default=None,
                   help="comma-separated seed_offsets (skip qrng pulls; "
                        "len must match --n-repeats)")
    p.add_argument("--live", action="store_true")
    p.add_argument("--use-pool", action="store_true",
                   help="route Aer calls through long-lived pool per restart (Phase B4)")
    p.add_argument("--selftest", action="store_true")
    args = p.parse_args(argv)

    if args.selftest:
        return _cmd_selftest(args)

    if args.n_repeats is None:
        args.n_repeats = 10
    if args.max_iter is None:
        args.max_iter = 200
    return _cmd_run(args)


if __name__ == "__main__":
    sys.exit(main())
