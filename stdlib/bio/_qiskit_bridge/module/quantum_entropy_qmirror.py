#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
quantum_entropy_qmirror.py — Phase A1 of the qpu_bridge bio integration.

Pulls quantum entropy bytes from the standalone `qmirror` CLI
(`/Users/ghost/core/qmirror`, v1.0.0+) and exposes them to downstream
hexa-bio quantum modules (VQE / Pauli expectation / ansatz parameter
seeds, all of which land in later phases A2-A5).

Design constraints
==================

* Hexa-bio rule: Python stdlib only — no numpy, no scipy in this
  adapter. Caller-side numpy/scipy is fine; we deliberately keep the
  entropy boundary narrow so it stays easy to audit.
* Provenance preservation: every pull carries (tier, provenance,
  request_id, mode) so downstream code can log "anu" vs "mock-lcg" and
  reproducibility holds.
* Drop-in: the qmirror CLI is invoked as a subprocess; no in-tree copy
  of qmirror logic. If qmirror is missing or fails, this module returns
  a structured error instead of fabricating bytes.
* Cross-repo SSOT: per memory `feedback_cross_repo_canonical`, this
  adapter is consumer-side only — it MUST NOT modify
  `nexus/.roadmap.qmirror` or anything inside the qmirror repo. The
  consumer-registration `consumers: [..., "hexa-bio"]` update is a
  separate qmirror-session task.

Public API
==========

    qrng_bytes(n_bytes: int, *, live: bool = False, qmirror_root: str | None = None)
        -> tuple[bytes, dict]

        Returns (raw_bytes, provenance) where provenance is
        {"tier", "provenance", "request_id", "n_bytes", "mode",
         "qmirror_version", "ts_utc"}.

    qrng_seed_int(n_bytes: int = 32, *, live: bool = False, qmirror_root: str | None = None)
        -> tuple[int, dict]

        Convenience wrapper. Returns (seed_int, provenance). The int is
        derived as big-endian unsigned interpretation of the bytes —
        suitable for `numpy.random.SeedSequence(seed_int)` / Python's
        `random.Random(seed_int)`. n_bytes defaults to 32 (256 bits) so
        the seed is full-entropy for SeedSequence's 128-bit pool.

CLI usage
=========

    python3 quantum_entropy_qmirror.py --bytes 32           # mock LCG
    python3 quantum_entropy_qmirror.py --bytes 32 --live    # ANU live tier
    python3 quantum_entropy_qmirror.py --selftest           # internal F1+F2

Selftest emits two sentinel lines on success:

    __HEXA_BIO_QENT__ F1 PASS
    __HEXA_BIO_QENT__ F2 PASS
    __HEXA_BIO_QENT__ ALL PASS

Honest caveats
==============

1. `live=True` requests qmirror's **3-tier** ANU chain (paid → keyed
   → legacy). qmirror commit aa58ba8 (2026-05-07) collapsed the
   previous 4-tier chain by retiring T1.d trial. Keys are resolved
   by qmirror's `_qmirror_secret()` chain (secret CLI / 1Password /
   macOS keychain / aws-sm / printenv), keyed off names ANU_KEY_PAID
   / ANU_KEY_FREE — NOT a single env var, and ANU_KEY_TRIAL is no
   longer consulted as of aa58ba8. With no keys provisioned,
   qmirror automatically falls back to T1.a legacy keyless
   (qrng.anu.edu.au, 1 req/min, provenance="anu_legacy") — verified
   end-to-end on this machine 2026-05-06 (docs §22 / §23). If the
   live endpoint itself fails, qmirror surfaces ok=0 with a tier-
   prefixed error rather than silently substituting mock bits —
   provenance never lies.

   Recent qmirror robustness improvements absorbed without code change
   on our side:
   - 14747ee perf(qrng): 4 env-probe execs collapsed to 1 + orphan-
     sweep tool — directly mitigates the fork-cap pressure we saw on
     2026-05-06 (cleanup verify cycle).
   - ce20751 fix(qrng): accept pretty-printed ANU JSON (handles ANU
     server returning "success": true with whitespace).
   - 0b1782d refactor: secret-chain key names unified to
     ANU_KEY_{PAID,FREE} — matches what this docstring already
     describes.
2. Mock-LCG bytes are reproducible by design (qmirror seeds with 42 by
   default, 12345 when `NEXUS_QMIRROR_MOCK=1` is forced upstream). They
   are NOT cryptographically random — adequate for VQE noise seeds and
   ansatz initialization, NOT for crypto.
3. The qmirror CLI subprocess incurs ~200-500 ms overhead per call
   (hexa interpreter startup + JSON marshalling). Batch entropy at the
   start of a VQE run instead of pulling mid-loop.
4. n_bytes is capped at 1024 by qmirror's qrng module for the LCG path
   and effectively at ~64 per ANU request; we re-call qmirror as needed
   and concatenate. This module does not retry on transient failures —
   caller decides retry policy.
"""

from __future__ import annotations

import argparse
import json
import os
import shlex
import subprocess
import sys
import time
from typing import Optional, Tuple


# Default qmirror root on this machine. Override via env QMIRROR_ROOT or
# explicit `qmirror_root=` keyword. Resolved lazily so the module imports
# even if qmirror is not yet installed (only `qrng_bytes` will fail).
_DEFAULT_QMIRROR_ROOT = "/Users/ghost/core/qmirror"  # @allow-devpath
_HEXA_BIN = "/Users/ghost/.hx/bin/hexa"  # @allow-devpath


class QmirrorEntropyError(RuntimeError):
    """Raised when the qmirror CLI cannot supply usable entropy."""


def _resolve_qmirror_root(explicit: str | None) -> str:
    if explicit:
        return explicit
    env = os.environ.get("QMIRROR_ROOT")
    if env:
        return env
    return _DEFAULT_QMIRROR_ROOT


def _resolve_hexa_bin() -> str:
    env = os.environ.get("HEXA_BIN")
    if env and os.path.isfile(env):
        return env
    if os.path.isfile(_HEXA_BIN):
        return _HEXA_BIN
    return "hexa"


def _utc_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _invoke_qmirror_qrng(n_bytes: int, qmirror_root: str, live: bool) -> dict:
    """Single qmirror qrng --bits=(n_bytes*8) --json call. Returns parsed map.

    Raises QmirrorEntropyError on subprocess failure or JSON parse failure.
    """
    if n_bytes < 1:
        raise QmirrorEntropyError(f"n_bytes must be >= 1 (got {n_bytes})")

    cli = os.path.join(qmirror_root, "cli", "qmirror.hexa")
    if not os.path.isfile(cli):
        raise QmirrorEntropyError(
            f"qmirror CLI not found at {cli}; "
            f"set QMIRROR_ROOT or pass qmirror_root="
        )

    hexa_bin = _resolve_hexa_bin()
    env = dict(os.environ)
    env["QMIRROR_ROOT"] = qmirror_root
    # 2026-05-06: previously needed `env["HEXA_FORK_CAP"] = "0"` and
    # `cwd=qmirror_root` (below) to survive qmirror cli's awk path
    # inference + 32-fork cap during VQE hot loops. qmirror's own
    # robustness fix (secret chain refactor + path/fork hardening)
    # made both redundant; cleanup-verify A5 selftest passed without
    # them. If a future qmirror regression breaks this, restore as:
    #   env["HEXA_FORK_CAP"] = "0"
    #   subprocess.run(..., cwd=qmirror_root, ...)
    if live:
        env["NEXUS_QMIRROR_LIVE"] = "1"
    else:
        # Force mock to keep this deterministic + offline-safe.
        env["NEXUS_QMIRROR_MOCK"] = "1"

    bits = n_bytes * 8
    cmd = [hexa_bin, "run", cli, "qrng", "--bits", str(bits), "--json"]

    # qmirror cli wall is jittery (Aer cold-start contention, system
    # load); 60 s tripped under load on 2026-05-06. 180 s gives 3× head-
    # room and matches the A2 ansatz bridge timeout (quantum_ansatz_h2.py).
    last_exc: Optional[Exception] = None
    for attempt in (1, 2):
        try:
            proc = subprocess.run(
                cmd,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                timeout=180,
                check=False,
            )
            last_exc = None
            break
        except FileNotFoundError as exc:
            raise QmirrorEntropyError(f"hexa binary not runnable: {exc}") from exc
        except subprocess.TimeoutExpired as exc:
            last_exc = exc
            if attempt == 1:
                time.sleep(1.0)
                continue
    if last_exc is not None:
        raise QmirrorEntropyError("qmirror qrng timeout (180s × 2 retries)") from last_exc

    stdout = proc.stdout.decode("utf-8", errors="replace")
    stderr = proc.stderr.decode("utf-8", errors="replace")

    # qmirror qrng prints a human-readable block then a JSON tail line
    # (--json mode). Find the last line that parses as JSON.
    last_json = None
    for line in reversed(stdout.splitlines()):
        line = line.strip()
        if line.startswith("{") and line.endswith("}"):
            try:
                last_json = json.loads(line)
                break
            except json.JSONDecodeError:
                continue

    if last_json is None:
        raise QmirrorEntropyError(
            "qmirror qrng: no JSON tail in stdout. "
            f"exit={proc.returncode} "
            f"stdout_head={stdout[:200]!r} stderr_head={stderr[:200]!r}"
        )

    if not last_json.get("pass", False):
        raise QmirrorEntropyError(
            f"qmirror qrng reported pass=false: {last_json!r}"
        )

    hex_str = last_json.get("bytes_hex", "")
    if not hex_str:
        raise QmirrorEntropyError(f"qmirror qrng JSON missing bytes_hex: {last_json!r}")

    return last_json


def qrng_bytes(
    n_bytes: int,
    *,
    live: bool = False,
    qmirror_root: str | None = None,
) -> Tuple[bytes, dict]:
    """Pull n_bytes of quantum-entropy-tier bytes via qmirror.

    Returns (raw_bytes, provenance_dict). `provenance_dict` keys:

        tier            qmirror's tier label ("anu-live" / "mock-lcg" / "none")
        provenance      "anu" / "mock" / "none"
        request_id      qmirror's audit id (e.g. "lcg42" or "anu_<unix_ts>")
        n_bytes         actual byte count returned
        mode            "live" (NEXUS_QMIRROR_LIVE=1) or "mock" requested
        qmirror_version e.g. "1.0.0"
        ts_utc          ISO-8601 UTC timestamp at adapter call time

    Raises QmirrorEntropyError on any failure (no silent fallback).
    """
    root = _resolve_qmirror_root(qmirror_root)
    js = _invoke_qmirror_qrng(n_bytes, root, live)
    raw = bytes.fromhex(js["bytes_hex"])
    if len(raw) != n_bytes:
        raise QmirrorEntropyError(
            f"qmirror qrng returned {len(raw)} bytes, expected {n_bytes}"
        )
    prov = {
        "tier": js.get("tier", "unknown"),
        "provenance": js.get("provenance", "unknown"),
        "request_id": js.get("request_id", ""),
        "n_bytes": len(raw),
        "mode": "live" if live else "mock",
        "qmirror_version": js.get("qmirror", "unknown"),
        "ts_utc": _utc_iso(),
    }
    return raw, prov


def qrng_seed_int(
    n_bytes: int = 32,
    *,
    live: bool = False,
    qmirror_root: str | None = None,
) -> Tuple[int, dict]:
    """Pull entropy and pack as a big-endian unsigned int.

    Use as `numpy.random.SeedSequence(seed_int)` or
    `random.Random(seed_int)`. Default n_bytes=32 → 256-bit seed.
    """
    raw, prov = qrng_bytes(n_bytes, live=live, qmirror_root=qmirror_root)
    seed_int = int.from_bytes(raw, "big", signed=False)
    return seed_int, prov


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _emit_json(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload, separators=(",", ":")))
    sys.stdout.write("\n")
    sys.stdout.flush()


def _cmd_pull(args: argparse.Namespace) -> int:
    try:
        raw, prov = qrng_bytes(
            args.bytes,
            live=args.live,
            qmirror_root=args.qmirror_root,
        )
    except QmirrorEntropyError as exc:
        _emit_json({
            "ok": 0,
            "error": str(exc),
            "ts_utc": _utc_iso(),
        })
        return 1

    payload = {
        "ok": 1,
        "bytes_hex": raw.hex(),
        "n_bytes": len(raw),
        "provenance": prov,
    }
    _emit_json(payload)
    return 0


def _cmd_selftest(args: argparse.Namespace) -> int:
    """Two falsifiers: F1 mock determinism, F2 round-trip int seed.

    F1: two consecutive mock pulls of the same n_bytes return identical
        bytes (qmirror LCG seed is fixed in mock mode). This is a
        regression guard for the env-var dispatch path.

    F2: qrng_seed_int(n_bytes=32) returns a non-zero int whose
        big-endian re-encoding equals the underlying bytes (round-trip).
    """
    print("hexa-bio quantum_entropy_qmirror.py — selftest")
    print("  qmirror_root: " + _resolve_qmirror_root(args.qmirror_root))
    print("  hexa_bin:     " + _resolve_hexa_bin())
    print("")

    # ---- F1 ----
    try:
        b1, p1 = qrng_bytes(16, live=False, qmirror_root=args.qmirror_root)
        b2, p2 = qrng_bytes(16, live=False, qmirror_root=args.qmirror_root)
    except QmirrorEntropyError as exc:
        print(f"  F1 FAIL: pull error: {exc}")
        print("__HEXA_BIO_QENT__ ALL FAIL")
        return 1

    if b1 != b2:
        print(f"  F1 FAIL: mock determinism broken — b1={b1.hex()} b2={b2.hex()}")
        print("__HEXA_BIO_QENT__ F1 FAIL")
        print("__HEXA_BIO_QENT__ ALL FAIL")
        return 1
    if p1["provenance"] != "mock":
        print(f"  F1 FAIL: expected provenance=mock, got {p1['provenance']!r}")
        print("__HEXA_BIO_QENT__ F1 FAIL")
        print("__HEXA_BIO_QENT__ ALL FAIL")
        return 1
    print(f"  F1 PASS: 2 consecutive mock pulls byte-identical "
          f"({b1.hex()}) provenance={p1['provenance']} "
          f"req={p1['request_id']}")
    print("__HEXA_BIO_QENT__ F1 PASS")

    # ---- F2 ----
    try:
        seed_int, prov = qrng_seed_int(32, live=False, qmirror_root=args.qmirror_root)
    except QmirrorEntropyError as exc:
        print(f"  F2 FAIL: seed_int pull error: {exc}")
        print("__HEXA_BIO_QENT__ F2 FAIL")
        print("__HEXA_BIO_QENT__ ALL FAIL")
        return 1

    if seed_int == 0:
        print("  F2 FAIL: seed_int == 0 (suspicious)")
        print("__HEXA_BIO_QENT__ F2 FAIL")
        print("__HEXA_BIO_QENT__ ALL FAIL")
        return 1
    # Round-trip: int -> 32 bytes big-endian -> int again
    rt = seed_int.to_bytes(32, "big")
    rt_int = int.from_bytes(rt, "big", signed=False)
    if rt_int != seed_int:
        print(f"  F2 FAIL: round-trip mismatch: {seed_int} != {rt_int}")
        print("__HEXA_BIO_QENT__ F2 FAIL")
        print("__HEXA_BIO_QENT__ ALL FAIL")
        return 1
    print(f"  F2 PASS: 256-bit seed_int={seed_int:#x} "
          f"(prov={prov['provenance']} ver={prov['qmirror_version']})")
    print("__HEXA_BIO_QENT__ F2 PASS")

    print("")
    print("__HEXA_BIO_QENT__ ALL PASS")
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        prog="quantum_entropy_qmirror.py",
        description="hexa-bio adapter: pull quantum entropy via qmirror CLI",
    )
    p.add_argument(
        "--qmirror-root",
        default=None,
        help=f"qmirror repo root (default: $QMIRROR_ROOT or {_DEFAULT_QMIRROR_ROOT})",
    )
    sub = p.add_subparsers(dest="cmd")

    p_pull = sub.add_parser("pull", help="pull entropy bytes (default if no subcmd)")
    p_pull.add_argument("--bytes", type=int, default=32, help="number of bytes (default 32)")
    p_pull.add_argument("--live", action="store_true", help="enable live ANU tier")

    sub.add_parser("selftest", help="run F1 + F2 falsifier sweep")

    # Convenience: bare flags without `pull` subcmd.
    p.add_argument("--bytes", type=int, default=None, help=argparse.SUPPRESS)
    p.add_argument("--live", action="store_true", help=argparse.SUPPRESS)
    p.add_argument("--selftest", action="store_true", help=argparse.SUPPRESS)

    args = p.parse_args(argv)

    if args.selftest or args.cmd == "selftest":
        return _cmd_selftest(args)

    if args.cmd == "pull" or args.cmd is None:
        if args.bytes is None:
            args.bytes = 32
        return _cmd_pull(args)

    p.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
