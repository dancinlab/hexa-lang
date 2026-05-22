#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
quantum_ansatz_he.py — Phase B1 step 2: hardware-efficient ansatz
generalized for arbitrary n_qubits and depth.

Phase 1 (quantum_ansatz_h2.py) hardcoded n=2 / d=1 / 4 params. This
module exposes the same shape for any (n, d):

    n_params = n_qubits * (depth + 1)

Topology (Kandala 2017-style with linear-chain CNOT entangler):

    initial Ry layer        : θ_0..n-1
    for layer l in 1..d:
        entangle CNOT chain  : q0-q1, q1-q2, ..., q(n-2)-q(n-1)
        Ry layer             : θ_(l*n)..((l+1)*n - 1)

For H2 (n=2, d=1): 4 params, exactly matches Phase 1 ansatz topology
under the same θ ordering.

For LiH (n=4, d=1): 8 params (initial 4 + post-entangle 4); active-space
ground state reachable from generic init within ~50-150 NM iterations
on the 16-amplitude state vector (4 qubits → 2^4 = 16).

Public API
==========

    build_ansatz_qasm(theta: Sequence[float], n_qubits: int,
                      depth: int = 1) -> str

    run_ansatz_state_vector(theta, n_qubits, depth=1, *,
                            qmirror_root=None, pool=None)
        -> tuple[list[complex], dict]

        If `pool` (an AerPool instance) is given, dispatch through it;
        else fresh-subprocess via the qmirror aer_runner. The pool path
        is what production VQE uses (~20× wall reduction).

Honest caveats
==============

1. The linear-chain CNOT entangler is a common but not the only
   topology. Kandala 2017 used either linear or all-to-all depending on
   the QPU. For our state-vector simulator any connectivity gives the
   same Hilbert space coverage, so linear is the simplest + minimum
   2Q gates.
2. The layer convention (initial Ry → entangle → Ry → ... → Ry, no
   final entangle) matches Phase 1's H2 ansatz at n=2, d=1. Some
   references put Ry-Rz pairs per layer; we keep Ry-only because for
   real Hamiltonians (chemistry without spin-orbit) the optimal state
   is real-valued and Ry suffices.
3. State-vector simulator scales as 2^n in amplitudes. n=10
   (un-reduced LiH) = 1024 amps × 631 Pauli terms is borderline
   feasible (~10 ms / energy() call). The active-space-reduced n=4
   (16 amps × 100 terms) is comfortable (~1 ms / call).
"""

from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import sys
from typing import List, Optional, Sequence, Tuple


_DEFAULT_QMIRROR_ROOT = "/Users/ghost/core/qmirror"  # @allow-devpath
_QASM3_PREAMBLE = 'OPENQASM 3.0;\ninclude "stdgates.inc";\n'


class AnsatzHEError(ValueError):
    pass


class AerBridgeError(RuntimeError):
    pass


def n_params_for(n_qubits: int, depth: int = 1) -> int:
    if n_qubits < 1:
        raise AnsatzHEError(f"n_qubits must be >= 1 (got {n_qubits})")
    if depth < 0:
        raise AnsatzHEError(f"depth must be >= 0 (got {depth})")
    return n_qubits * (depth + 1)


def build_ansatz_qasm(
    theta: Sequence[float],
    n_qubits: int,
    depth: int = 1,
    *,
    init_bits: Optional[Sequence[int]] = None,
) -> str:
    """Hardware-efficient ansatz QASM3. params = n_qubits × (depth + 1).

    `init_bits` (optional, length n_qubits) prefixes X gates for any qubit
    whose entry is 1. Used to start from the Hartree-Fock state in
    chemistry VQE (drastically improves convergence vs random init).
    Bits are indexed q0..q(n-1) (qiskit endian: qubit 0 is the rightmost
    in basis-state strings like |q(n-1)..q0⟩).
    """
    expected = n_params_for(n_qubits, depth)
    if len(theta) != expected:
        raise AnsatzHEError(
            f"theta length {len(theta)} != n_qubits*(depth+1) = {expected}"
        )
    for i, t in enumerate(theta):
        if not isinstance(t, (int, float)):
            raise AnsatzHEError(f"theta[{i}] not a number: {t!r}")
        if not math.isfinite(float(t)):
            raise AnsatzHEError(f"theta[{i}] not finite: {t}")
    if init_bits is not None:
        if len(init_bits) != n_qubits:
            raise AnsatzHEError(
                f"init_bits length {len(init_bits)} != n_qubits {n_qubits}"
            )
        for q, b in enumerate(init_bits):
            if b not in (0, 1):
                raise AnsatzHEError(
                    f"init_bits[{q}] must be 0 or 1, got {b!r}"
                )

    t = [float(x) for x in theta]
    lines: List[str] = [_QASM3_PREAMBLE, f"qubit[{n_qubits}] q;"]
    # HF / explicit init prefix
    if init_bits is not None:
        for q, b in enumerate(init_bits):
            if b == 1:
                lines.append(f"x q[{q}];")
    # Initial Ry layer
    for q in range(n_qubits):
        lines.append(f"ry({t[q]}) q[{q}];")
    # Subsequent depth layers
    for layer in range(depth):
        # Linear-chain CNOT
        for q in range(n_qubits - 1):
            lines.append(f"cx q[{q}], q[{q + 1}];")
        # Ry layer
        for q in range(n_qubits):
            lines.append(f"ry({t[(layer + 1) * n_qubits + q]}) q[{q}];")
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# Aer dispatch — fresh-subprocess (legacy) or pool (preferred for VQE)
# ---------------------------------------------------------------------------


def _resolve_bridge_path(qmirror_root: Optional[str]) -> str:
    explicit = os.environ.get("QMIRROR_BRIDGE")
    if explicit:
        return explicit
    root = qmirror_root or os.environ.get("QMIRROR_ROOT") or _DEFAULT_QMIRROR_ROOT
    return os.path.join(root, "_python_bridge", "module", "aer_runner.py")


def _invoke_aer_qasm_fresh(qasm: str, bridge: str) -> dict:
    if not os.path.isfile(bridge):
        raise AerBridgeError(f"aer bridge not found at {bridge}")
    payload = {"mode": "qasm", "circuit": qasm, "n_qubits": 0}
    try:
        proc = subprocess.run(
            ["python3", bridge],
            input=json.dumps(payload).encode("utf-8"),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=180,
            check=False,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        raise AerBridgeError(f"fresh-bridge spawn/timeout: {exc}") from exc

    stdout = proc.stdout.decode("utf-8", errors="replace")
    last_open = stdout.rfind("{")
    last_close = stdout.rfind("}")
    if last_open < 0 or last_close < last_open:
        raise AerBridgeError(f"no JSON in stdout: {stdout[:200]!r}")
    resp = json.loads(stdout[last_open:last_close + 1])
    if resp.get("ok") != 1:
        raise AerBridgeError(f"bridge ok=0: {resp.get('message', '?')}")
    return resp


def run_ansatz_state_vector(
    theta: Sequence[float],
    n_qubits: int,
    depth: int = 1,
    *,
    init_bits: Optional[Sequence[int]] = None,
    qmirror_root: Optional[str] = None,
    pool=None,  # quantum_aer_pool.AerPool or None
) -> Tuple[List[complex], dict]:
    qasm = build_ansatz_qasm(theta, n_qubits, depth, init_bits=init_bits)
    if pool is not None:
        resp = pool.run_qasm(qasm)
        if resp.get("ok") != 1:
            raise AerBridgeError(f"pool ok=0: {resp.get('error', '?')}")
    else:
        bridge = _resolve_bridge_path(qmirror_root)
        resp = _invoke_aer_qasm_fresh(qasm, bridge)

    re = resp.get("amps_re", [])
    im = resp.get("amps_im", [])
    if len(re) != len(im):
        raise AerBridgeError(f"amps len mismatch: {len(re)} vs {len(im)}")
    expected_dim = 1 << n_qubits
    if len(re) != expected_dim:
        raise AerBridgeError(
            f"amps len {len(re)} != 2^n_qubits = {expected_dim}"
        )
    amps = [complex(float(r), float(i)) for r, i in zip(re, im)]
    meta = {
        "engine": str(resp.get("engine", "unknown")),
        "n_qubits": int(resp.get("n_qubits", n_qubits)),
        "qasm": qasm,
        "depth": depth,
    }
    return amps, meta


# ---------------------------------------------------------------------------
# CLI / selftest
# ---------------------------------------------------------------------------


def _emit_json(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload, separators=(",", ":")))
    sys.stdout.write("\n")
    sys.stdout.flush()


def _cmd_selftest(args: argparse.Namespace) -> int:
    """F1 H2 (n=2) zero theta = |00⟩ ; F2 LiH (n=4) zero theta = |0000⟩ ;
    F3 H2 entangled (recovers Phase 1's |Φ+⟩ Bell at θ=[π/2,0,0,0])."""
    print("hexa-bio quantum_ansatz_he.py — selftest (Phase B1 step 2)")
    print()

    tol = 1e-9

    # F1: H2 / n=2 / depth=1 / θ=[0,0,0,0] → |00⟩
    print("  F1: n_qubits=2 depth=1 theta=[0,0,0,0] → |00⟩ ...")
    try:
        amps, meta = run_ansatz_state_vector([0.0, 0.0, 0.0, 0.0], 2, 1)
    except (AnsatzHEError, AerBridgeError) as exc:
        print(f"  F1 FAIL: {exc}")
        print("__HEXA_BIO_QHE__ ALL FAIL")
        return 1
    expected = [complex(1, 0), complex(0, 0), complex(0, 0), complex(0, 0)]
    if not all(abs(a - b) < tol for a, b in zip(amps, expected)):
        print(f"  F1 FAIL: amps={amps} expected={expected}")
        print("__HEXA_BIO_QHE__ F1 FAIL")
        print("__HEXA_BIO_QHE__ ALL FAIL")
        return 1
    print(f"  F1 PASS: H2 ansatz n_qubits=2 reproduces Phase 1 |00⟩ "
          f"(engine={meta['engine']})")
    print("__HEXA_BIO_QHE__ F1 PASS")
    print()

    # F2: LiH / n=4 / depth=1 / θ=[0]*8 → |0000⟩
    print("  F2: n_qubits=4 depth=1 theta=[0]*8 → |0000⟩ ...")
    try:
        amps4, meta4 = run_ansatz_state_vector([0.0] * 8, 4, 1)
    except (AnsatzHEError, AerBridgeError) as exc:
        print(f"  F2 FAIL: {exc}")
        print("__HEXA_BIO_QHE__ F2 FAIL")
        print("__HEXA_BIO_QHE__ ALL FAIL")
        return 1
    expected4 = [complex(0, 0)] * 16
    expected4[0] = complex(1, 0)
    if not all(abs(a - b) < tol for a, b in zip(amps4, expected4)):
        diffs = [(i, abs(a - b)) for i, (a, b) in enumerate(zip(amps4, expected4)) if abs(a - b) >= tol]
        print(f"  F2 FAIL: amplitude mismatch at indices {diffs[:5]}")
        print("__HEXA_BIO_QHE__ F2 FAIL")
        print("__HEXA_BIO_QHE__ ALL FAIL")
        return 1
    print(f"  F2 PASS: LiH ansatz n_qubits=4 produces |0000⟩ from zero theta "
          f"(engine={meta4['engine']})")
    print("__HEXA_BIO_QHE__ F2 PASS")
    print()

    # F3: Phase 1 |Φ+⟩ recovery at n=2 / depth=1 / θ=[π/2, 0, 0, 0]
    s = 1.0 / math.sqrt(2.0)
    print("  F3: n_qubits=2 depth=1 theta=[π/2,0,0,0] → |Φ+⟩ (Phase 1 byte-match) ...")
    try:
        amps_b, meta_b = run_ansatz_state_vector([math.pi / 2.0, 0.0, 0.0, 0.0], 2, 1)
    except (AnsatzHEError, AerBridgeError) as exc:
        print(f"  F3 FAIL: {exc}")
        print("__HEXA_BIO_QHE__ F3 FAIL")
        print("__HEXA_BIO_QHE__ ALL FAIL")
        return 1
    expected_b = [complex(s, 0), complex(0, 0), complex(0, 0), complex(s, 0)]
    if not all(abs(a - b) < tol for a, b in zip(amps_b, expected_b)):
        print(f"  F3 FAIL: amps={amps_b} expected={expected_b}")
        print("__HEXA_BIO_QHE__ F3 FAIL")
        print("__HEXA_BIO_QHE__ ALL FAIL")
        return 1
    print(f"  F3 PASS: Phase 1 |Φ+⟩ recovered with generalized ansatz "
          f"(byte-identical to A2 §12.3)")
    print("__HEXA_BIO_QHE__ F3 PASS")

    print()
    print("__HEXA_BIO_QHE__ ALL PASS")
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="quantum_ansatz_he.py")
    p.add_argument("--selftest", action="store_true")
    args = p.parse_args(argv)
    if args.selftest:
        return _cmd_selftest(args)
    p.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
