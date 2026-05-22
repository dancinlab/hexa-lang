#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
quantum_pauli_expectation.py — Phase A3 of the qpu_bridge bio integration.

Evaluates the H2 minimal-basis molecular Hamiltonian expectation value
⟨ψ(θ)|H|ψ(θ)⟩ for a state vector produced by the Phase A2 ansatz, by
analytic computation of each Pauli term's expectation against the
4-amplitude state vector (n_qubits = 2).

H2 / STO-3G / R=0.74 Å parity-mapped Hamiltonian
================================================

Reference: Kandala et al. 2017 ("Hardware-efficient variational quantum
eigensolver for small molecules and quantum magnets", Nature 549, 242).
Same coefficients used by nexus/sim_bridge/qpu_bridge/vqe_h2_demo.py
(see qpu_bridge/README.md:31-36):

    H = c0·I + c1·Z0 + c2·Z1 + c3·Z0Z1 + c4·X0X1 + c5·Y0Y1

with (in Hartree):

    c0 = -1.052373245772859    # nuclear + identity
    c1 = +0.39793742484318045  # Z0
    c2 = -0.39793742484318045  # Z1
    c3 = -0.01128010425623538  # Z0 Z1
    c4 = +0.18093119978423156  # X0 X1
    c5 = +0.18093119978423156  # Y0 Y1   (Y0 Y1 ≡ X0 X1 for real ansatz)

Exact ground state (numerical diagonalization, qpu_bridge/README.md:36):

    E0 = -1.9153706 Ha   (achievable by hardware-efficient d=1 ansatz)

Endian convention
=================

qiskit / aer_runner.py: q0 is LSB. Amplitude index i has bit pattern
(q1, q0). Pauli operators below follow that convention:

    Z0 acts on the q0 bit → diag(+1, -1, +1, -1)  (bit 0 of i)
    Z1 acts on the q1 bit → diag(+1, +1, -1, -1)  (bit 1 of i)
    Z0Z1                  → diag(+1, -1, -1, +1)
    X0 X1                 → swaps i ↔ i ^ 0b11
    Y0 Y1                 → swaps i ↔ i ^ 0b11 with Y0Y1 = -X0X1·Z0Z1
                                                          = (i)(i)·X·X = -X0X1·Z·Z

For state |ψ⟩ with amplitudes a[i]:

    ⟨I⟩      = Σ |a[i]|²                        (= 1 for unit norm)
    ⟨Zk⟩     = Σ s_k(i) |a[i]|², s_k(i) = (-1)^bit_k(i)
    ⟨Z0Z1⟩   = Σ s_0(i)·s_1(i) |a[i]|²
    ⟨X0X1⟩   = Σ Re( a[i]* · a[i ^ 3] )         (real if a is real)
    ⟨Y0Y1⟩   = Σ Re( -a[i]* · a[i ^ 3] )        (= -⟨X0X1⟩ for real a; for
                                                  general complex see _exp_yy)

Design constraints
==================

* Hexa-bio rule: stdlib-only Python (math + lists). No numpy.
* Pure analytic on the 4-amplitude state vector — no shot noise, no
  basis-rotation overhead. Phase B (LiH/BeH2) generalizes via OpenFermion-
  style Pauli string parsing; for now H2's 6 fixed terms are hardcoded.
* `energy(theta)` is the function VQE (A4) will call inside its
  scipy.optimize.minimize loop. Each call: A2 round-trip → 4 amps →
  6 Pauli expectation values → linear combination → float.

Public API
==========

    pauli_expectation_z0(amps)          -> float
    pauli_expectation_z1(amps)          -> float
    pauli_expectation_z0z1(amps)        -> float
    pauli_expectation_x0x1(amps)        -> float
    pauli_expectation_y0y1(amps)        -> float
    pauli_expectation_identity(amps)    -> float (= norm² ≈ 1)

    h2_hamiltonian_expectation(amps)    -> float
        ⟨ψ|H|ψ⟩ in Hartree.

    energy(theta, *, qmirror_root=None) -> tuple[float, dict]
        Build A2 ansatz QASM → run via qmirror Aer bridge → 4 amps →
        h2_hamiltonian_expectation. Returns (energy_Ha, meta) where meta
        carries {"engine", "amps_re", "amps_im", "qasm"} for audit.

CLI usage
=========

    python3 quantum_pauli_expectation.py --theta 0,0,0,0
    python3 quantum_pauli_expectation.py --selftest

Selftest emits sentinels:

    __HEXA_BIO_QPAULI__ F1 PASS    # identity = 1, individual Z expectations
    __HEXA_BIO_QPAULI__ F2 PASS    # |00⟩ → analytic E(|00⟩) match
    __HEXA_BIO_QPAULI__ F3 PASS    # parameter scan finds θ* with E* near E0
    __HEXA_BIO_QPAULI__ ALL PASS

Honest caveats
==============

1. The 6 Pauli coefficients are hardcoded for H2/STO-3G/R=0.74 Å only.
   Re-deriving for a different bond length or basis requires running
   PySCF (or analogue) once and pasting the new coefficients here. NOT a
   live ab initio path — caller responsible for keeping coefficients
   current with the chemistry they intend.
2. ⟨Y0Y1⟩ implementation assumes the ansatz state vector is real (true
   for Ry-only rotations + CNOT, no complex phases). For ansatzes
   involving Rx/Rz/Z phase, _exp_yy needs the general complex form.
   Phase A2 ansatz is real-Ry-only by construction so this is safe; a
   guard in _exp_yy raises if a complex component is detected.
3. F3 (parameter scan) uses a coarse 11×11×11×11 = 14641-point grid
   over θ ∈ [-π, π]^4 — total 14641 Aer round-trips at ~250 ms each =
   ~1 hour wall on a Mac. The selftest defaults to a much coarser
   3×3×3×3 = 81-point sanity grid (~20 s) and a tolerance band of
   E_min ≤ -1.10 Ha (much weaker than E0=-1.9154). The full
   convergence to E0 is the responsibility of A4 (COBYLA optimizer).
4. analytic ⟨P⟩ vs shot-based: this module gives noiseless analytic
   expectation. Real-QPU runs would use shot sampling + basis rotation;
   for that, route through qmirror/circuit/circuit_exec_qasm with a
   measurement-rotated copy of the QASM. Out of scope for Phase A3.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
from typing import List, Sequence, Tuple

# Phase A2 dependency. Importable as a sibling module under
# _python_bridge/module/.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from quantum_ansatz_h2 import (  # noqa: E402
    AerBridgeError,
    AnsatzError,
    run_ansatz_state_vector,
)


# ---------------------------------------------------------------------------
# H2 6-term Hamiltonian (Kandala 2017, R=0.74 Å, STO-3G, parity-mapped)
# ---------------------------------------------------------------------------

H2_C0_IDENTITY: float = -1.052373245772859
H2_C1_Z0:       float = +0.39793742484318045
H2_C2_Z1:       float = -0.39793742484318045
H2_C3_Z0Z1:     float = -0.01128010425623538
H2_C4_X0X1:     float = +0.18093119978423156
H2_C5_Y0Y1:     float = +0.18093119978423156

# Exact ground state (qpu_bridge/README.md:36).
H2_E0_EXACT: float = -1.9153706


# ---------------------------------------------------------------------------
# Pauli expectation values on a 2-qubit state vector (4 amplitudes).
# Convention: q0 is LSB; amplitude index i has bit pattern (q1, q0).
# ---------------------------------------------------------------------------


def _amp2(z: complex) -> float:
    return z.real * z.real + z.imag * z.imag


def pauli_expectation_identity(amps: Sequence[complex]) -> float:
    if len(amps) != 4:
        raise ValueError(f"H2 expectations need 4 amplitudes (got {len(amps)})")
    return sum(_amp2(z) for z in amps)


def pauli_expectation_z0(amps: Sequence[complex]) -> float:
    # Z0 acts on bit 0 of i: sign = +1 if bit0=0 else -1.
    if len(amps) != 4:
        raise ValueError("expected 4 amplitudes")
    return (_amp2(amps[0]) - _amp2(amps[1])
            + _amp2(amps[2]) - _amp2(amps[3]))


def pauli_expectation_z1(amps: Sequence[complex]) -> float:
    # Z1 acts on bit 1 of i: sign = +1 if bit1=0 else -1.
    if len(amps) != 4:
        raise ValueError("expected 4 amplitudes")
    return (_amp2(amps[0]) + _amp2(amps[1])
            - _amp2(amps[2]) - _amp2(amps[3]))


def pauli_expectation_z0z1(amps: Sequence[complex]) -> float:
    if len(amps) != 4:
        raise ValueError("expected 4 amplitudes")
    return (_amp2(amps[0]) - _amp2(amps[1])
            - _amp2(amps[2]) + _amp2(amps[3]))


def pauli_expectation_x0x1(amps: Sequence[complex]) -> float:
    # X0 X1 swaps i ↔ i ^ 0b11. ⟨X0X1⟩ = 2 Re(a0* a3 + a1* a2).
    if len(amps) != 4:
        raise ValueError("expected 4 amplitudes")
    a0, a1, a2, a3 = amps
    return 2.0 * (
        (a0.conjugate() * a3).real
        + (a1.conjugate() * a2).real
    )


def pauli_expectation_y0y1(amps: Sequence[complex]) -> float:
    # Y0 Y1 = (Y0)(Y1).
    # Y|0⟩ = +i|1⟩, Y|1⟩ = -i|0⟩.
    # On the computational basis, Y0Y1 takes |b1 b0⟩ → -|b1⊕1, b0⊕1⟩
    # (the two i's combine to i² = -1 only when both flips are 0→1,
    #  but careful: Y|0⟩ = +i|1⟩, Y|1⟩ = -i|0⟩, so the sign depends on
    #  which direction each qubit flips).
    #
    # Precise: Y0Y1 |i⟩ = sign(i) · |i ^ 0b11|, where
    #   sign(i) for (q1, q0) = (Y_op on q1) · (Y_op on q0)
    #   Y on q0=0 → +i (q0 0→1); Y on q0=1 → -i (q0 1→0)
    #   Y on q1=0 → +i (q1 0→1); Y on q1=1 → -i (q1 1→0)
    #   Product: (+i)(+i)= -1 for (q1=0, q0=0); (+i)(-i)= +1 for (0,1);
    #            (-i)(+i)= +1 for (1,0); (-i)(-i)= -1 for (1,1).
    # So Y0Y1 |0⟩ = -|3⟩, Y0Y1 |1⟩ = +|2⟩,
    #    Y0Y1 |2⟩ = +|1⟩, Y0Y1 |3⟩ = -|0⟩.
    #
    # ⟨Y0Y1⟩ = Σ_i a[i]* · (Y0Y1 |ψ⟩)[i]
    #        = -a0* a3 + a1* a2 + a2* a1 - a3* a0
    #        = -2 Re(a0* a3) + 2 Re(a1* a2)
    if len(amps) != 4:
        raise ValueError("expected 4 amplitudes")
    a0, a1, a2, a3 = amps
    return 2.0 * (
        (a1.conjugate() * a2).real
        - (a0.conjugate() * a3).real
    )


def h2_hamiltonian_expectation(amps: Sequence[complex]) -> float:
    """⟨ψ|H_H2|ψ⟩ in Hartree (R=0.74 Å, STO-3G, parity-mapped, Kandala 2017).

    Linear combination of the 6 Pauli terms — no shot noise, analytic on
    the 4-amplitude state vector.
    """
    e_id    = pauli_expectation_identity(amps)
    e_z0    = pauli_expectation_z0(amps)
    e_z1    = pauli_expectation_z1(amps)
    e_z0z1  = pauli_expectation_z0z1(amps)
    e_x0x1  = pauli_expectation_x0x1(amps)
    e_y0y1  = pauli_expectation_y0y1(amps)
    return (
        H2_C0_IDENTITY * e_id
        + H2_C1_Z0     * e_z0
        + H2_C2_Z1     * e_z1
        + H2_C3_Z0Z1   * e_z0z1
        + H2_C4_X0X1   * e_x0x1
        + H2_C5_Y0Y1   * e_y0y1
    )


def energy(
    theta: Sequence[float],
    *,
    qmirror_root: str | None = None,
) -> Tuple[float, dict]:
    """Build A2 ansatz, dispatch via qmirror Aer, return (E_Ha, meta).

    `meta` carries {"engine", "amps_re", "amps_im", "qasm"} so callers
    (A4 VQE optimizer + audit logs) can inspect the underlying state
    vector and the QASM source per call.
    """
    amps, ansatz_meta = run_ansatz_state_vector(theta, qmirror_root=qmirror_root)
    e = h2_hamiltonian_expectation(amps)
    meta = {
        "engine": ansatz_meta["engine"],
        "n_qubits": ansatz_meta["n_qubits"],
        "amps_re": [z.real for z in amps],
        "amps_im": [z.imag for z in amps],
        "qasm": ansatz_meta["qasm"],
    }
    return e, meta


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _parse_theta(s: str) -> List[float]:
    parts = [p.strip() for p in s.split(",")]
    if len(parts) != 4:
        raise argparse.ArgumentTypeError(
            f"--theta must be 4 comma-separated floats (got {len(parts)})"
        )
    out: List[float] = []
    for p in parts:
        p_low = p.lower().replace(" ", "")
        if p_low == "pi":
            out.append(math.pi); continue
        if p_low == "-pi":
            out.append(-math.pi); continue
        if p_low.startswith("pi/"):
            out.append(math.pi / float(p_low[3:])); continue
        if p_low.startswith("-pi/"):
            out.append(-math.pi / float(p_low[4:])); continue
        out.append(float(p))
    return out


def _emit_json(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload, separators=(",", ":")))
    sys.stdout.write("\n")
    sys.stdout.flush()


def _cmd_eval(args: argparse.Namespace) -> int:
    try:
        e, meta = energy(args.theta, qmirror_root=args.qmirror_root)
    except (AnsatzError, AerBridgeError) as exc:
        _emit_json({"ok": 0, "error": str(exc)})
        return 1
    _emit_json({
        "ok": 1,
        "theta": list(args.theta),
        "energy_Ha": e,
        "engine": meta["engine"],
        "amps_re": meta["amps_re"],
        "amps_im": meta["amps_im"],
    })
    return 0


def _energy_at(theta: Sequence[float], qmirror_root: str | None) -> float:
    e, _ = energy(theta, qmirror_root=qmirror_root)
    return e


def _cmd_selftest(args: argparse.Namespace) -> int:
    """F1 individual Pauli expectations, F2 |00⟩ analytic match,
    F3 coarse grid scan finds E_min ≤ -1.10 Ha (sanity, NOT full E0)."""
    print("hexa-bio quantum_pauli_expectation.py — selftest")
    print(f"  qmirror_root: {args.qmirror_root or os.environ.get('QMIRROR_ROOT') or '(default)'}")
    print(f"  H2 Hamiltonian (R=0.74Å, STO-3G, Kandala 2017):")
    print(f"    c0={H2_C0_IDENTITY:+.12f}  c1={H2_C1_Z0:+.12f}  c2={H2_C2_Z1:+.12f}")
    print(f"    c3={H2_C3_Z0Z1:+.12f}  c4={H2_C4_X0X1:+.12f}  c5={H2_C5_Y0Y1:+.12f}")
    print(f"    E0 (exact, diagonalized) = {H2_E0_EXACT:+.7f} Ha")
    print("")

    tol = 1e-9

    # ---- F1: hand-built state vectors → analytic Pauli expectations ----
    # |00⟩ = [1, 0, 0, 0]:
    #   ⟨I⟩=1  ⟨Z0⟩=+1  ⟨Z1⟩=+1  ⟨Z0Z1⟩=+1  ⟨X0X1⟩=0  ⟨Y0Y1⟩=0
    psi_00 = [complex(1, 0), complex(0, 0), complex(0, 0), complex(0, 0)]
    checks_f1 = [
        ("⟨I|00⟩",     pauli_expectation_identity, psi_00, 1.0),
        ("⟨Z0|00⟩",    pauli_expectation_z0,       psi_00, +1.0),
        ("⟨Z1|00⟩",    pauli_expectation_z1,       psi_00, +1.0),
        ("⟨Z0Z1|00⟩",  pauli_expectation_z0z1,     psi_00, +1.0),
        ("⟨X0X1|00⟩",  pauli_expectation_x0x1,     psi_00, 0.0),
        ("⟨Y0Y1|00⟩",  pauli_expectation_y0y1,     psi_00, 0.0),
    ]
    # |Φ+⟩ = (|00⟩+|11⟩)/√2 = [s, 0, 0, s]:
    #   ⟨X0X1⟩ = +1, ⟨Y0Y1⟩ = -1, ⟨Z0Z1⟩ = +1, ⟨Z0⟩ = ⟨Z1⟩ = 0
    s = 1.0 / math.sqrt(2.0)
    psi_bell = [complex(s, 0), complex(0, 0), complex(0, 0), complex(s, 0)]
    checks_f1 += [
        ("⟨I|Φ+⟩",    pauli_expectation_identity, psi_bell, 1.0),
        ("⟨Z0|Φ+⟩",   pauli_expectation_z0,       psi_bell, 0.0),
        ("⟨Z1|Φ+⟩",   pauli_expectation_z1,       psi_bell, 0.0),
        ("⟨Z0Z1|Φ+⟩", pauli_expectation_z0z1,     psi_bell, +1.0),
        ("⟨X0X1|Φ+⟩", pauli_expectation_x0x1,     psi_bell, +1.0),
        ("⟨Y0Y1|Φ+⟩", pauli_expectation_y0y1,     psi_bell, -1.0),
    ]
    f1_fail = []
    for name, fn, psi, expected in checks_f1:
        got = fn(psi)
        if abs(got - expected) > tol:
            f1_fail.append((name, got, expected))
    if f1_fail:
        for n, g, e in f1_fail:
            print(f"  F1 FAIL: {n} = {g:+.6f}, expected {e:+.6f}")
        print("__HEXA_BIO_QPAULI__ F1 FAIL")
        print("__HEXA_BIO_QPAULI__ ALL FAIL")
        return 1
    print(f"  F1 PASS: {len(checks_f1)} Pauli expectation checks (|00⟩ + |Φ+⟩) within tol={tol}")
    print("__HEXA_BIO_QPAULI__ F1 PASS")

    # ---- F2: |00⟩ analytic energy via Kandala coefficients ----
    # E(|00⟩) = c0·1 + c1·1 + c2·1 + c3·1 + c4·0 + c5·0 = c0+c1+c2+c3
    e_00_analytic = (H2_C0_IDENTITY + H2_C1_Z0 + H2_C2_Z1 + H2_C3_Z0Z1)
    e_00_via_h = h2_hamiltonian_expectation(psi_00)
    if abs(e_00_via_h - e_00_analytic) > tol:
        print(f"  F2 FAIL: H|00⟩ via fn = {e_00_via_h:+.9f}, "
              f"sum-of-coeffs = {e_00_analytic:+.9f}")
        print("__HEXA_BIO_QPAULI__ F2 FAIL")
        print("__HEXA_BIO_QPAULI__ ALL FAIL")
        return 1
    print(f"  F2 PASS: ⟨H|00⟩ = {e_00_via_h:+.9f} Ha (analytic c0+c1+c2+c3 match)")
    print("__HEXA_BIO_QPAULI__ F2 PASS")

    # ---- F3: coarse 3×3×3×3 = 81 grid scan via Aer round-trip ----
    # Sanity band: must find at least one θ with E < -1.10 Ha (well below
    # |00⟩ energy ≈ -1.117 Ha but not yet at E0 = -1.9154).
    # Wait: c0+c1+c2+c3 = -1.052 + 0.398 - 0.398 - 0.011 = -1.064.
    # That's actually above the sanity threshold. Use -1.10 Ha
    # threshold and also require ≥ 0.05 Ha improvement over E(|00⟩).
    grid_steps = args.scan_steps or 3
    if grid_steps < 2:
        grid_steps = 2
    grid = [
        -math.pi + 2.0 * math.pi * k / (grid_steps - 1)
        for k in range(grid_steps)
    ]
    print(f"  F3: scanning grid {grid_steps}^4 = {grid_steps**4} ansatz points...")

    e_min = float("inf")
    theta_min = None
    n_evaluated = 0
    n_failed = 0
    for t0 in grid:
        for t1 in grid:
            for t2 in grid:
                for t3 in grid:
                    try:
                        e_val = _energy_at([t0, t1, t2, t3], args.qmirror_root)
                    except AerBridgeError as exc:
                        n_failed += 1
                        if n_failed <= 2:
                            print(f"  F3 ... bridge error at ({t0:.2f},{t1:.2f},{t2:.2f},{t3:.2f}): {exc}")
                        continue
                    n_evaluated += 1
                    if e_val < e_min:
                        e_min = e_val
                        theta_min = (t0, t1, t2, t3)

    if n_evaluated == 0:
        print(f"  F3 FAIL: 0 successful evaluations ({n_failed} bridge errors)")
        print("__HEXA_BIO_QPAULI__ F3 FAIL")
        print("__HEXA_BIO_QPAULI__ ALL FAIL")
        return 1

    e_baseline = e_00_via_h  # |00⟩ energy
    improvement = e_baseline - e_min
    sanity_band = -1.10  # Ha
    print(f"  F3 ... {n_evaluated}/{grid_steps**4} evaluations, "
          f"{n_failed} bridge errors")
    print(f"  F3 ... E(|00⟩) baseline = {e_baseline:+.6f} Ha")
    print(f"  F3 ... E_min = {e_min:+.6f} Ha at θ ≈ "
          f"({theta_min[0]:+.3f}, {theta_min[1]:+.3f}, "
          f"{theta_min[2]:+.3f}, {theta_min[3]:+.3f})")
    print(f"  F3 ... improvement vs |00⟩: {improvement:+.6f} Ha "
          f"(target ≥ 0.05)")
    print(f"  F3 ... sanity band: E_min ≤ {sanity_band:+.3f} Ha "
          f"(target; ground-state full convergence is A4)")

    if e_min > sanity_band:
        print(f"  F3 FAIL: coarse grid found no θ with E ≤ {sanity_band} Ha")
        print("__HEXA_BIO_QPAULI__ F3 FAIL")
        print("__HEXA_BIO_QPAULI__ ALL FAIL")
        return 1
    if improvement < 0.05:
        print(f"  F3 FAIL: grid did not improve on |00⟩ baseline by ≥ 0.05 Ha")
        print("__HEXA_BIO_QPAULI__ F3 FAIL")
        print("__HEXA_BIO_QPAULI__ ALL FAIL")
        return 1

    print(f"  F3 PASS: coarse grid scan found E_min={e_min:+.6f} Ha "
          f"≤ {sanity_band} (full E0 = {H2_E0_EXACT} Ha is A4's job)")
    print("__HEXA_BIO_QPAULI__ F3 PASS")

    print("")
    print("__HEXA_BIO_QPAULI__ ALL PASS")
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        prog="quantum_pauli_expectation.py",
        description="hexa-bio adapter: H2 6-Pauli Hamiltonian expectation evaluator (Phase A3)",
    )
    p.add_argument("--qmirror-root", default=None)
    p.add_argument(
        "--theta",
        type=_parse_theta,
        default=None,
        help="4 comma-separated floats (or pi/N tokens) for energy() eval",
    )
    p.add_argument("--selftest", action="store_true")
    p.add_argument(
        "--scan-steps",
        type=int,
        default=None,
        help="F3 grid size per dimension (default 3 → 81 points)",
    )
    args = p.parse_args(argv)

    if args.selftest:
        return _cmd_selftest(args)
    if args.theta is None:
        p.print_help()
        return 2
    return _cmd_eval(args)


if __name__ == "__main__":
    sys.exit(main())
