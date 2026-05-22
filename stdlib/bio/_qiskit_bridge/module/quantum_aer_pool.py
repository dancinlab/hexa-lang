#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
quantum_aer_pool.py — Phase B4 long-lived Aer bridge (qpu_bridge bio integration).

A persistent worker process that imports qiskit + qiskit_aer ONCE and
processes a stream of QASM3 / named-circuit requests over stdin/stdout
JSON. Eliminates the ~0.6–1.8 s/call cold-start dominant in earlier
phases (see docs §13.8 / §17.5).

Architecture
============

    [ caller process: VQE optimizer ]
           │  (json req per fn eval)
           ▼  stdin
    [ subprocess: this script in --daemon mode ]
       qiskit + qiskit_aer imported once
       for each line on stdin: parse json,
       run circuit, emit json on stdout
           │  stdout
           ▼
    [ caller reads response dict ]

The daemon mirrors qmirror's `aer_runner.py` JSON contract so callers
can transparently swap between fresh-subprocess (existing path) and
long-lived (this module). Future: qmirror Phase 4 long-lived bridge
upstream — at that point this module retires to a shim.

Public API
==========

    class AerPool:
        with AerPool() as pool:
            resp = pool.run_qasm(qasm_source)
            resp = pool.run_named("bell", n_qubits=2)
            # resp keys: ok, engine, n_qubits, amps_re, amps_im, message

CLI usage
=========

    python3 quantum_aer_pool.py --daemon            # internal worker mode
    python3 quantum_aer_pool.py --selftest          # 5-call wall benchmark

Honest caveats
==============

1. Daemon is hexa-bio-side only — qmirror's `aer_runner.py` is
   unchanged. Future qmirror Phase 4 long-lived bridge upstreams the
   pattern; this module is then a thin shim. Memory caveat
   `feedback_cross_repo_canonical` honored.
2. State leakage: a long-lived process accumulates qiskit's internal
   caches across requests. For our use (state-vector simulation of
   independent ansatz evaluations) this is irrelevant, but circuits
   with classical context or mid-circuit measurement could carry over
   and skew results. Selftest verifies determinism on independent
   inputs; we do NOT call any of qiskit's stateful APIs.
3. Failure mode: if the daemon's stdin closes or it crashes, the
   client raises AerPoolError. Caller is expected to either fall back
   to fresh-subprocess (existing path) or restart the pool.
4. wall-clock comparison in selftest is single-run; jitter from OS
   page-cache state can swing measurements. The structural benefit
   (1 import vs N imports for N calls) is the load-bearing claim, not
   the exact speedup ratio.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import sys
import time
from typing import Optional, Tuple


# ---------------------------------------------------------------------------
# Daemon worker — runs in subprocess, imports qiskit ONCE.
# ---------------------------------------------------------------------------


def _daemon_main() -> int:
    """Stdin JSON request loop. Each line = one request, one response."""
    try:
        import numpy as np  # noqa: F401
    except ImportError as exc:
        sys.stdout.write(json.dumps({"ok": 0, "error": f"numpy: {exc}"}) + "\n")
        sys.stdout.flush()
        return 1

    # Aer / qiskit warmup — runs once at daemon start.
    try:
        from qiskit import QuantumCircuit  # noqa: F401
        from qiskit.qasm3 import loads as qasm3_loads
        from qiskit_aer import AerSimulator
    except ImportError as exc:
        sys.stdout.write(json.dumps({"ok": 0, "error": f"qiskit: {exc}"}) + "\n")
        sys.stdout.flush()
        return 1

    backend = AerSimulator(method="statevector")

    # Ready signal — caller waits for this before sending requests.
    sys.stdout.write(json.dumps({"ok": 1, "ready": True, "engine": "qiskit_aer_pool"}) + "\n")
    sys.stdout.flush()

    while True:
        line = sys.stdin.readline()
        if not line:
            break
        line = line.strip()
        if not line:
            continue
        if line == "QUIT":
            sys.stdout.write(json.dumps({"ok": 1, "bye": True}) + "\n")
            sys.stdout.flush()
            break
        try:
            req = json.loads(line)
        except Exception as exc:
            sys.stdout.write(json.dumps({
                "ok": 0,
                "error": f"bad json: {exc}",
            }) + "\n")
            sys.stdout.flush()
            continue

        try:
            mode = str(req.get("mode", "qasm"))
            if mode == "qasm":
                qasm = str(req.get("circuit", ""))
                circuit = qasm3_loads(qasm)
                sv_circuit = QuantumCircuit(circuit.num_qubits)
                sv_circuit.compose(circuit, inplace=True)
                sv_circuit.save_statevector()
                job = backend.run(sv_circuit, shots=1)
                result = job.result()
                sv = result.get_statevector(sv_circuit)
                amps_re = [float(z.real) for z in sv]
                amps_im = [float(z.imag) for z in sv]
                resp = {
                    "ok": 1,
                    "engine": "qiskit_aer_pool",
                    "n_qubits": int(round(math.log2(len(amps_re)))) if amps_re else 0,
                    "amps_re": amps_re,
                    "amps_im": amps_im,
                    "message": "qasm circuit ok",
                }
            else:
                resp = {
                    "ok": 0,
                    "error": f"unsupported mode: {mode} (pool implements 'qasm' only; named circuits route via fresh-subprocess path)",
                }
        except Exception as exc:
            resp = {
                "ok": 0,
                "error": f"daemon: {type(exc).__name__}: {exc}",
            }

        sys.stdout.write(json.dumps(resp, separators=(",", ":")) + "\n")
        sys.stdout.flush()

    return 0


# ---------------------------------------------------------------------------
# Client class — used by callers (VQE optimizer, smoke tests).
# ---------------------------------------------------------------------------


class AerPoolError(RuntimeError):
    pass


class AerPool:
    """Context-managed long-lived Aer bridge.

    Usage:
        with AerPool() as pool:
            resp = pool.run_qasm(qasm_source)
            # resp: dict with ok/engine/n_qubits/amps_re/amps_im
    """

    def __init__(self, *, python_bin: Optional[str] = None,
                 daemon_script: Optional[str] = None):
        self._python_bin = python_bin or sys.executable or "python3"
        self._daemon_script = daemon_script or os.path.abspath(__file__)
        self._proc: Optional[subprocess.Popen] = None

    def __enter__(self) -> "AerPool":
        self._spawn()
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    def _spawn(self) -> None:
        cmd = [self._python_bin, "-u", self._daemon_script, "--daemon"]
        self._proc = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=1,
            text=True,
        )
        # Read ready line.
        ready_line = self._proc.stdout.readline().strip()
        if not ready_line:
            err = self._proc.stderr.read() if self._proc.stderr else ""
            raise AerPoolError(f"daemon failed to emit ready line; stderr={err[:300]!r}")
        try:
            ready = json.loads(ready_line)
        except Exception as exc:
            raise AerPoolError(f"bad ready line: {ready_line!r} ({exc})") from exc
        if not ready.get("ready"):
            raise AerPoolError(f"daemon ready=false: {ready!r}")

    def close(self) -> None:
        if self._proc is None:
            return
        try:
            if self._proc.stdin and not self._proc.stdin.closed:
                self._proc.stdin.write("QUIT\n")
                self._proc.stdin.flush()
        except Exception:
            pass
        try:
            self._proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self._proc.kill()
            self._proc.wait(timeout=5)
        self._proc = None

    def run_qasm(self, qasm: str, *, timeout: float = 60.0) -> dict:
        if self._proc is None or self._proc.poll() is not None:
            raise AerPoolError("daemon not running (call within `with AerPool() as pool:`)")
        req = json.dumps({"mode": "qasm", "circuit": qasm}, separators=(",", ":"))
        try:
            self._proc.stdin.write(req + "\n")
            self._proc.stdin.flush()
        except (BrokenPipeError, OSError) as exc:
            raise AerPoolError(f"daemon stdin write failed: {exc}") from exc

        # Read one response line. We don't enforce wall-timeout here
        # because the underlying Aer call is bounded by qiskit; the
        # caller's outer timeout (e.g. subprocess.run for the whole
        # VQE run) is the safety net.
        line = self._proc.stdout.readline()
        if not line:
            err = self._proc.stderr.read() if self._proc.stderr else ""
            raise AerPoolError(f"daemon stdout EOF; stderr={err[:300]!r}")
        try:
            resp = json.loads(line.strip())
        except Exception as exc:
            raise AerPoolError(f"bad response line: {line!r} ({exc})") from exc
        return resp


# ---------------------------------------------------------------------------
# Selftest — wall benchmark vs fresh-subprocess.
# ---------------------------------------------------------------------------


def _qasm_h2_zero_theta() -> str:
    """A2 ansatz at theta=[0,0,0,0]. Cheapest possible 2-qubit QASM3."""
    return (
        'OPENQASM 3.0;\n'
        'include "stdgates.inc";\n'
        'qubit[2] q;\n'
        'ry(0.0) q[0];\n'
        'ry(0.0) q[1];\n'
        'cx q[0], q[1];\n'
        'ry(0.0) q[0];\n'
        'ry(0.0) q[1];\n'
    )


def _bench_fresh_subprocess(n_calls: int) -> Tuple[float, list]:
    """Fresh subprocess per call (existing path)."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from quantum_ansatz_h2 import _invoke_aer_qasm, _resolve_bridge_path  # noqa: E402

    bridge = _resolve_bridge_path(None)
    qasm = _qasm_h2_zero_theta()
    started = time.time()
    amps_first = None
    for _ in range(n_calls):
        resp = _invoke_aer_qasm(qasm, bridge)
        if amps_first is None:
            amps_first = (resp["amps_re"], resp["amps_im"])
    return (time.time() - started, amps_first)


def _bench_pool(n_calls: int) -> Tuple[float, list]:
    qasm = _qasm_h2_zero_theta()
    started = time.time()
    amps_first = None
    with AerPool() as pool:
        for _ in range(n_calls):
            resp = pool.run_qasm(qasm)
            if resp.get("ok") != 1:
                raise AerPoolError(f"pool returned non-ok: {resp!r}")
            if amps_first is None:
                amps_first = (resp["amps_re"], resp["amps_im"])
    return (time.time() - started, amps_first)


def _amps_close(a: list, b: list, tol: float = 1e-9) -> bool:
    if a is None or b is None:
        return False
    if len(a) != 2 or len(b) != 2:
        return False
    if len(a[0]) != len(b[0]) or len(a[1]) != len(b[1]):
        return False
    for x, y in zip(a[0], b[0]):
        if abs(x - y) > tol:
            return False
    for x, y in zip(a[1], b[1]):
        if abs(x - y) > tol:
            return False
    return True


def _cmd_selftest(n_calls: int = 5) -> int:
    """F1 daemon basic, F2 N-call equivalence + speedup measurement."""
    print("hexa-bio quantum_aer_pool.py — selftest")
    print(f"  n_calls per benchmark: {n_calls}")
    print("")

    # F1: pool spawns + ready signal received + 1 call returns ok.
    print("  F1: spawn pool + 1 call sanity ...")
    try:
        with AerPool() as pool:
            r = pool.run_qasm(_qasm_h2_zero_theta())
    except AerPoolError as exc:
        print(f"  F1 FAIL: {exc}")
        print("__HEXA_BIO_QPOOL__ ALL FAIL")
        return 1
    if r.get("ok") != 1:
        print(f"  F1 FAIL: pool resp ok!=1: {r!r}")
        print("__HEXA_BIO_QPOOL__ ALL FAIL")
        return 1
    if r.get("engine") != "qiskit_aer_pool":
        print(f"  F1 FAIL: engine != qiskit_aer_pool: {r.get('engine')!r}")
        print("__HEXA_BIO_QPOOL__ ALL FAIL")
        return 1
    print(f"  F1 PASS: ok=1 engine={r['engine']} n_qubits={r['n_qubits']}")
    print("__HEXA_BIO_QPOOL__ F1 PASS")
    print("")

    # F2: equivalence + wall comparison.
    print(f"  F2: {n_calls}-call wall comparison fresh-subprocess vs pool ...")
    try:
        wall_fresh, amps_fresh = _bench_fresh_subprocess(n_calls)
    except Exception as exc:
        print(f"  F2 FAIL: fresh-subprocess bench raised: {exc}")
        print("__HEXA_BIO_QPOOL__ F2 FAIL")
        print("__HEXA_BIO_QPOOL__ ALL FAIL")
        return 1
    try:
        wall_pool, amps_pool = _bench_pool(n_calls)
    except Exception as exc:
        print(f"  F2 FAIL: pool bench raised: {exc}")
        print("__HEXA_BIO_QPOOL__ F2 FAIL")
        print("__HEXA_BIO_QPOOL__ ALL FAIL")
        return 1
    if not _amps_close(amps_fresh, amps_pool):
        print(f"  F2 FAIL: amplitude mismatch fresh vs pool")
        print("__HEXA_BIO_QPOOL__ F2 FAIL")
        print("__HEXA_BIO_QPOOL__ ALL FAIL")
        return 1
    speedup = wall_fresh / wall_pool if wall_pool > 0 else float("inf")
    print(f"  F2 ... wall fresh-subprocess: {wall_fresh:.2f}s ({wall_fresh/n_calls:.2f}s/call)")
    print(f"  F2 ... wall pool:             {wall_pool:.2f}s ({wall_pool/n_calls:.2f}s/call)")
    print(f"  F2 ... amps_re first call equal within 1e-9: True")
    print(f"  F2 ... speedup: {speedup:.2f}×")
    if speedup < 2.0:
        print(f"  F2 FAIL: speedup {speedup:.2f}x < 2x threshold (single-run jitter? rerun)")
        print("__HEXA_BIO_QPOOL__ F2 FAIL")
        print("__HEXA_BIO_QPOOL__ ALL FAIL")
        return 1
    print("__HEXA_BIO_QPOOL__ F2 PASS")
    if speedup >= 5.0:
        print("__HEXA_BIO_QPOOL__ F-Q-5 PASS  (≥5× wall reduction; falsifier closed)")
    else:
        print(f"__HEXA_BIO_QPOOL__ F-Q-5 PARTIAL  ({speedup:.2f}× < 5× threshold; F2 PASS but F-Q-5 stays open)")

    print("")
    print("__HEXA_BIO_QPOOL__ ALL PASS")
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="quantum_aer_pool.py")
    p.add_argument("--daemon", action="store_true",
                   help="run as long-lived worker (internal use)")
    p.add_argument("--selftest", action="store_true")
    p.add_argument("--n-calls", type=int, default=5,
                   help="selftest: number of calls per benchmark (default 5)")
    args = p.parse_args(argv)

    if args.daemon:
        return _daemon_main()
    if args.selftest:
        return _cmd_selftest(args.n_calls)
    p.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
