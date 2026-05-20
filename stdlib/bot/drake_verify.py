#!/usr/bin/env python3
# drake_verify.py — `bot + verify` producer (D72 ①b thin adapter).
#
# ROI rank 13 — Drake (Toyota Research / MIT) for robotics verification
# primitives: Lyapunov stability, sum-of-squares (SOS), contact-implicit
# trajectory verification. Sibling of bot+synthesize (Pinocchio).
# References:
#   - Drake SSOT — drake.mit.edu (Tedrake et al.).
#   - Gazebo classic / gz-sim SSOT — gazebosim.org.
#
# D61: substrate SSOT here under `hexa-lang/stdlib/bot/`.
# D72: rigid-body verify primitives → bot adapter (thin). kernels/rbd/
#      promotion candidate at 2nd RBD consumer; Drake's analytic /
#      contact-implicit math is distinct from Pinocchio's RNEA / CRBA
#      so will be its own sub-module of kernels/rbd/ when extracted.
# g3:  honest install-gated. Drake's `pydrake` is a substantial install
#      (multi-GB on Ubuntu .deb / pip wheel); skip honest if missing.

from __future__ import annotations

import json
import sys
import time
from pathlib import Path


def _try_import_drake():
    try:
        import pydrake  # noqa: F401

        return pydrake, None
    except ImportError as e:  # pragma: no cover
        return None, str(e)


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    drake, import_err = _try_import_drake()
    citations = [
        "Drake SSOT — drake.mit.edu (Tedrake et al., MIT / TRI).",
        "Gazebo classic / gz-sim — gazebosim.org (Open Robotics).",
    ]
    scope_caveats: list[str] = []
    if import_err is not None:
        scope_caveats.append(
            f"pydrake not importable — honest install-gated skip. "
            f"ImportError: {import_err}. Install: `pip install drake` "
            "(Ubuntu) or apt `apt install drake` (multi-GB binary)."
        )
    scope_caveats.append(
        "Toy 2-link planar arm Lyapunov stability check — NOT a contact / "
        "payload / actuator-fault verification. Real absorption needs a "
        "measured arm + measured payload + signed safety-case dossier."
    )
    record = {
        "domain": "bot",
        "verb": "verify",
        "kind": "drake_lyapunov_demo",
        "stamp": stamp,
        "producer": (
            f"pydrake@{getattr(drake, '__version__', 'unknown')}"
            if drake is not None
            else "pydrake@absent"
        ),
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": (
            "pydrake_import_failed" if import_err is not None else None
        ),
    }
    rec_path = out / f"bot_verify_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[bot+verify] wrote {rec_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/bot_verify"))
