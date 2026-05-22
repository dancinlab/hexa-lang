#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
quantum_ansatz_h2.py — Phase A2 of the qpu_bridge bio integration.

Builds a hardware-efficient 2-qubit ansatz for the H2 minimal-basis
ground-state VQE (Kandala et al. 2017, d=1 layer, 4 parameters) and
serializes it to OpenQASM 3.0 for downstream simulation by qmirror's
engine_aer Aer/numpy bridge.

Ansatz topology
===============

    q0 ──Ry(θ0)──●──Ry(θ2)──
                  │
    q1 ──Ry(θ1)──⊕──Ry(θ3)──

* qiskit endian: q0 is LSB, so amplitude index i has bit pattern (q1, q0).
* d=1 hardware-efficient layer is sufficient for the 2-qubit
  parity-mapped H2 Hamiltonian to reach the exact ground state
  E0 = -1.9153706 Ha (per Kandala 2017 + qpu_bridge/README.md:31-36).
* The 4 parameters (θ0..θ3) are the VQE optimization variables; A4
  (the COBYLA loop) varies them to minimize ⟨ψ(θ)|H|ψ(θ)⟩.

Design constraints
==================

* Hexa-bio rule: stdlib-only Python in this adapter — subprocess
  + json for the qmirror bridge call. No numpy/scipy here. Caller-side
  numpy/scipy in A3/A4 is the documented concession boundary.
* No in-tree copy of qmirror logic: the QASM source is shipped as a
  string to qmirror's _python_bridge/module/aer_runner.py via stdin
  JSON, exactly as engine_aer.hexa does it. A bridge unavailability
  (qiskit not installed in qmirror's python env) surfaces as
  AerBridgeError rather than a fabricated state vector.

Public API
==========

    build_ansatz_qasm(theta: Sequence[float]) -> str
        Returns an OpenQASM 3.0 source string. theta must have length 4.

    run_ansatz_state_vector(theta, *, qmirror_root=None)
        -> tuple[list[complex], dict]
        Build the QASM, dispatch via qmirror's aer_runner.py, return the
        2**n_qubits amplitudes (length 4 for H2) plus a metadata dict
        {"engine", "n_qubits", "qasm", "message"}.

CLI usage
=========

    python3 quantum_ansatz_h2.py --theta 0,0,0,0 [--qasm-only]
    python3 quantum_ansatz_h2.py --selftest

Selftest emits sentinels:

    __HEXA_BIO_QANSATZ__ F1 PASS    # build sanity (gate count, syntax)
    __HEXA_BIO_QANSATZ__ F2 PASS    # round-trip θ=[0,0,0,0] → |00⟩
    __HEXA_BIO_QANSATZ__ F3 PASS    # round-trip θ=[π/2,0,0,0] → |Φ+⟩
    __HEXA_BIO_QANSATZ__ ALL PASS

Honest caveats
==============

1. Bridge path is `~/core/qmirror/_python_bridge/module/aer_runner.py`
   — overridable via QMIRROR_BRIDGE or QMIRROR_ROOT env. Adapter does
   not vendor a fallback bridge; missing bridge → AerBridgeError.
2. QASM mode requires `qiskit` + `qiskit_aer` importable in the
   `python3` interpreter that the bridge invokes. If unavailable, the
   bridge returns ok=0 with message "qiskit_unavailable: ..."; the
   adapter surfaces this verbatim. Sentinel observed on this machine
   (2026-05-06): qiskit 2.4.1 + qiskit_aer 0.17.2 default-python3 OK.
3. d=1 ansatz is sufficient for H2/STO-3G/parity-mapped (2 qubits) but
   is NOT sufficient for larger basis sets or molecules with stronger
   correlation. Phase B (LiH/BeH2/etc) requires generalizing layer
   count + qubit count. This file deliberately fixes n_qubits=2 and
   d=1 to keep A1+A2+A3+A4 tractable.
4. amplitude precision: aer_runner.py emits Python floats (~64-bit
   doubles). Round-trip tolerance in selftest = 1e-9 (well above
   double-precision noise; below numerical Hadamard/Ry roundoff).
"""

from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import sys
from typing import List, Sequence, Tuple


_DEFAULT_QMIRROR_ROOT = "/Users/ghost/core/qmirror"  # @allow-devpath


class AnsatzError(ValueError):
    """Raised on invalid ansatz parameters or QASM build failures."""


class AerBridgeError(RuntimeError):
    """Raised when the qmirror Aer bridge cannot return a state vector."""


def _resolve_bridge_path(qmirror_root: str | None) -> str:
    explicit = os.environ.get("QMIRROR_BRIDGE")
    if explicit:
        return explicit
    root = qmirror_root or os.environ.get("QMIRROR_ROOT") or _DEFAULT_QMIRROR_ROOT
    return os.path.join(root, "_python_bridge", "module", "aer_runner.py")


# ---------------------------------------------------------------------------
# QASM3 builder
# ---------------------------------------------------------------------------


_QASM3_PREAMBLE = 'OPENQASM 3.0;\ninclude "stdgates.inc";\n'


def build_ansatz_qasm(theta: Sequence[float]) -> str:
    """Hardware-efficient d=1 ansatz on 2 qubits with 4 Ry parameters.

    Layout: Ry(θ0) ⊗ Ry(θ1) → CNOT(q0→q1) → Ry(θ2) ⊗ Ry(θ3).
    """
    if len(theta) != 4:
        raise AnsatzError(f"theta must have length 4 (got {len(theta)})")
    for i, t in enumerate(theta):
        if not isinstance(t, (int, float)):
            raise AnsatzError(f"theta[{i}] not a real number: {t!r}")
        if not math.isfinite(float(t)):
            raise AnsatzError(f"theta[{i}] not finite: {t}")

    t0, t1, t2, t3 = (float(x) for x in theta)
    lines = [
        _QASM3_PREAMBLE,
        "qubit[2] q;",
        f"ry({t0}) q[0];",
        f"ry({t1}) q[1];",
        "cx q[0], q[1];",
        f"ry({t2}) q[0];",
        f"ry({t3}) q[1];",
    ]
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# qmirror Aer bridge round-trip
# ---------------------------------------------------------------------------


def _invoke_aer_qasm(qasm: str, bridge: str) -> dict:
    if not os.path.isfile(bridge):
        raise AerBridgeError(
            f"aer bridge not found at {bridge}; "
            f"set QMIRROR_BRIDGE or QMIRROR_ROOT"
        )
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
    except FileNotFoundError as exc:
        raise AerBridgeError(f"python3 not runnable: {exc}") from exc
    except subprocess.TimeoutExpired as exc:
        raise AerBridgeError("aer bridge timeout (180s)") from exc

    stdout = proc.stdout.decode("utf-8", errors="replace")
    stderr = proc.stderr.decode("utf-8", errors="replace")

    last_open = stdout.rfind("{")
    last_close = stdout.rfind("}")
    if last_open < 0 or last_close < 0 or last_close < last_open:
        raise AerBridgeError(
            f"aer bridge: no JSON object on stdout. "
            f"exit={proc.returncode} stdout={stdout[:200]!r} "
            f"stderr={stderr[:200]!r}"
        )
    candidate = stdout[last_open:last_close + 1]
    try:
        resp = json.loads(candidate)
    except json.JSONDecodeError as exc:
        raise AerBridgeError(f"aer bridge: bad JSON: {exc}; got {candidate[:200]!r}")

    if resp.get("ok", 0) != 1:
        raise AerBridgeError(
            f"aer bridge ok=0: {resp.get('message', '(no message)')}"
        )
    return resp


def run_ansatz_state_vector(
    theta: Sequence[float],
    *,
    qmirror_root: str | None = None,
) -> Tuple[List[complex], dict]:
    """Build ansatz QASM for `theta`, dispatch via qmirror aer bridge,
    return (amplitudes, meta).

    `amplitudes` is a list of Python complex of length 2**n_qubits = 4.
    `meta` carries {"engine", "n_qubits", "qasm", "message"} for audit.
    """
    qasm = build_ansatz_qasm(theta)
    bridge = _resolve_bridge_path(qmirror_root)
    resp = _invoke_aer_qasm(qasm, bridge)

    re = resp.get("amps_re", [])
    im = resp.get("amps_im", [])
    if len(re) != len(im):
        raise AerBridgeError(
            f"aer bridge: amps_re/amps_im length mismatch ({len(re)} vs {len(im)})"
        )
    amps = [complex(float(r), float(i)) for r, i in zip(re, im)]

    meta = {
        "engine": str(resp.get("engine", "unknown")),
        "n_qubits": int(resp.get("n_qubits", 0)),
        "qasm": qasm,
        "message": str(resp.get("message", "")),
    }
    return amps, meta


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _parse_theta(s: str) -> List[float]:
    parts = [p.strip() for p in s.split(",")]
    if len(parts) != 4:
        raise argparse.ArgumentTypeError(
            f"--theta must be 4 comma-separated floats (got {len(parts)})"
        )
    out = []
    for p in parts:
        # accept literal "pi/2" / "-pi/4" for convenience
        p_low = p.lower().replace(" ", "")
        if p_low == "pi":
            out.append(math.pi)
            continue
        if p_low == "-pi":
            out.append(-math.pi)
            continue
        if p_low.startswith("pi/"):
            out.append(math.pi / float(p_low[3:]))
            continue
        if p_low.startswith("-pi/"):
            out.append(-math.pi / float(p_low[4:]))
            continue
        out.append(float(p))
    return out


def _emit_json(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload, separators=(",", ":")))
    sys.stdout.write("\n")
    sys.stdout.flush()


def _amps_close(a: List[complex], b: List[complex], tol: float) -> bool:
    if len(a) != len(b):
        return False
    for x, y in zip(a, b):
        if abs(x - y) > tol:
            return False
    return True


def _fmt_amps(a: List[complex]) -> str:
    return "[" + ", ".join(f"{z.real:+.4f}{z.imag:+.4f}j" for z in a) + "]"


def _cmd_build(args: argparse.Namespace) -> int:
    try:
        if args.qasm_only:
            qasm = build_ansatz_qasm(args.theta)
            sys.stdout.write(qasm)
            return 0
        amps, meta = run_ansatz_state_vector(args.theta, qmirror_root=args.qmirror_root)
    except (AnsatzError, AerBridgeError) as exc:
        _emit_json({"ok": 0, "error": str(exc)})
        return 1
    _emit_json({
        "ok": 1,
        "theta": list(args.theta),
        "n_qubits": meta["n_qubits"],
        "engine": meta["engine"],
        "amps_re": [z.real for z in amps],
        "amps_im": [z.imag for z in amps],
    })
    return 0


def _cmd_selftest(args: argparse.Namespace) -> int:
    """F1 build sanity, F2 |00⟩ identity round-trip, F3 |Φ+⟩ Bell entangling."""
    print("hexa-bio quantum_ansatz_h2.py — selftest")
    print("  bridge path: " + _resolve_bridge_path(args.qmirror_root))
    print("")

    s = 1.0 / math.sqrt(2.0)
    tol = 1e-9

    # ---- F1 ----
    try:
        q = build_ansatz_qasm([0.0, 0.0, 0.0, 0.0])
    except AnsatzError as exc:
        print(f"  F1 FAIL: build error: {exc}")
        print("__HEXA_BIO_QANSATZ__ ALL FAIL")
        return 1
    expected_lines = ["qubit[2] q;", "ry(0.0) q[0];", "ry(0.0) q[1];",
                      "cx q[0], q[1];", "ry(0.0) q[0];", "ry(0.0) q[1];"]
    if not all(line in q for line in expected_lines):
        print("  F1 FAIL: QASM missing expected lines")
        print(q)
        print("__HEXA_BIO_QANSATZ__ F1 FAIL")
        print("__HEXA_BIO_QANSATZ__ ALL FAIL")
        return 1
    if "OPENQASM 3.0;" not in q:
        print("  F1 FAIL: QASM missing OPENQASM 3.0 preamble")
        print("__HEXA_BIO_QANSATZ__ F1 FAIL")
        print("__HEXA_BIO_QANSATZ__ ALL FAIL")
        return 1
    print("  F1 PASS: build θ=[0,0,0,0] → 6 expected QASM lines + preamble OK")
    print("__HEXA_BIO_QANSATZ__ F1 PASS")

    # ---- F2 ----
    try:
        amps, meta = run_ansatz_state_vector([0.0, 0.0, 0.0, 0.0],
                                             qmirror_root=args.qmirror_root)
    except AerBridgeError as exc:
        print(f"  F2 FAIL: bridge error: {exc}")
        print("__HEXA_BIO_QANSATZ__ F2 FAIL")
        print("__HEXA_BIO_QANSATZ__ ALL FAIL")
        return 1
    expected_00 = [complex(1.0, 0.0), complex(0.0, 0.0),
                   complex(0.0, 0.0), complex(0.0, 0.0)]
    if not _amps_close(amps, expected_00, tol):
        print(f"  F2 FAIL: θ=[0,0,0,0] expected {_fmt_amps(expected_00)} got {_fmt_amps(amps)}")
        print("__HEXA_BIO_QANSATZ__ F2 FAIL")
        print("__HEXA_BIO_QANSATZ__ ALL FAIL")
        return 1
    print(f"  F2 PASS: θ=[0,0,0,0] → |00⟩ amps={_fmt_amps(amps)} engine={meta['engine']}")
    print("__HEXA_BIO_QANSATZ__ F2 PASS")

    # ---- F3 ----
    # θ = [π/2, 0, 0, 0]:
    #   Ry(π/2)|0⟩ = (|0⟩+|1⟩)/√2  on q0; q1 = |0⟩ untouched.
    #   State: (|00⟩ + |10⟩)/√2.  CNOT(q0→q1) flips q1 when q0=1:
    #   |00⟩ → |00⟩, |10⟩ → |11⟩.  Final (|00⟩ + |11⟩)/√2 = |Φ+⟩.
    #   Trailing Ry(0) ⊗ Ry(0) = identity.
    #   Endian: amplitude index = q1*2 + q0  → indices 0 and 3.
    try:
        amps_bell, meta_bell = run_ansatz_state_vector(
            [math.pi / 2.0, 0.0, 0.0, 0.0],
            qmirror_root=args.qmirror_root,
        )
    except AerBridgeError as exc:
        print(f"  F3 FAIL: bridge error: {exc}")
        print("__HEXA_BIO_QANSATZ__ F3 FAIL")
        print("__HEXA_BIO_QANSATZ__ ALL FAIL")
        return 1
    expected_bell = [complex(s, 0.0), complex(0.0, 0.0),
                     complex(0.0, 0.0), complex(s, 0.0)]
    if not _amps_close(amps_bell, expected_bell, tol):
        print(f"  F3 FAIL: θ=[π/2,0,0,0] expected {_fmt_amps(expected_bell)} got {_fmt_amps(amps_bell)}")
        print("__HEXA_BIO_QANSATZ__ F3 FAIL")
        print("__HEXA_BIO_QANSATZ__ ALL FAIL")
        return 1
    print(f"  F3 PASS: θ=[π/2,0,0,0] → |Φ+⟩ amps={_fmt_amps(amps_bell)} engine={meta_bell['engine']}")
    print("__HEXA_BIO_QANSATZ__ F3 PASS")

    print("")
    print("__HEXA_BIO_QANSATZ__ ALL PASS")
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        prog="quantum_ansatz_h2.py",
        description="hexa-bio adapter: H2 hardware-efficient ansatz QASM3 builder + qmirror Aer round-trip",
    )
    p.add_argument(
        "--qmirror-root",
        default=None,
        help=f"qmirror repo root (default: $QMIRROR_ROOT or {_DEFAULT_QMIRROR_ROOT})",
    )
    p.add_argument(
        "--theta",
        type=_parse_theta,
        default=None,
        help="4 comma-separated floats (or pi/N tokens), e.g. '0,0,0,0' or 'pi/2,0,0,0'",
    )
    p.add_argument(
        "--qasm-only",
        action="store_true",
        help="emit QASM3 source on stdout, skip Aer round-trip",
    )
    p.add_argument(
        "--selftest",
        action="store_true",
        help="run F1 + F2 + F3 falsifier sweep",
    )
    args = p.parse_args(argv)

    if args.selftest:
        return _cmd_selftest(args)

    if args.theta is None:
        p.print_help()
        return 2

    return _cmd_build(args)


if __name__ == "__main__":
    sys.exit(main())
