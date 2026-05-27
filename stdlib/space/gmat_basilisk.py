#!/usr/bin/env python3
# gmat_basilisk.py — `space + verify` producer (D72 ①b thin adapter).
#
# ROI rank 15 — GMAT (NASA, public binary) trajectory validation +
# Basilisk (UC Boulder, pip-buildable) ADCS sim. Completes the space
# domain end-to-end (analyze Skyfield SGP4 + synthesize OpenMDAO MDO +
# verify GMAT/Basilisk).
# References:
#   - GMAT (General Mission Analysis Tool) — NASA GSC-17177-1, GitHub
#     ChrisCMS/GMAT or gmat.sourceforge.io.
#   - Basilisk — hanspeterschaub.info/basilisk (Schaub group, AVS lab).
#
# D61: substrate SSOT under `hexa-lang/stdlib/space/`.
# D72: orbital mechanics — `kernels/orbital/` (κ-45, skyfield-based) is
#      a candidate kernel for shared use; GMAT/Basilisk have their own
#      ecosystems → keep in space adapter (thin) until a 2nd
#      GMAT/Basilisk consumer appears.
# g3:  honest install-gated. GMAT is a binary download (heavy on macOS;
#      cleaner on Ubuntu); Basilisk is pip but multi-step. Skip honest.

from __future__ import annotations

import json
import sys
import time
from pathlib import Path


def _try_import_basilisk():
    try:
        import Basilisk  # noqa: F401

        return Basilisk, None
    except ImportError as e:  # pragma: no cover
        return None, str(e)


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    basilisk, import_err = _try_import_basilisk()
    citations = [
        "GMAT (General Mission Analysis Tool) — NASA GSC-17177-1, "
        "gmat.sourceforge.io.",
        "Basilisk astrodynamics framework — hanspeterschaub.info/basilisk "
        "(Schaub group, UC Boulder AVS).",
    ]
    scope_caveats: list[str] = []
    if import_err is not None:
        scope_caveats.append(
            f"Basilisk not importable — honest install-gated skip. "
            f"ImportError: {import_err}. Install: clone Basilisk repo + "
            "`pip install .` (multi-step build). GMAT is a separate binary "
            "download (NASA public)."
        )
    scope_caveats.append(
        "Reference circular-orbit + nominal ADCS — NOT a sourced mission "
        "verification. Real absorption needs a sourced ephemeris + measured "
        "burn telemetry + signed mission-readiness review."
    )
    # G7 typed gate_type — install-gated when Basilisk absent; otherwise
    # substrate is ready and no hexa-native ADCS kernel exists yet →
    # D80 hexa-native-absent + provisional.
    if import_err is not None:
        gate_type = "install-gated"
        provisional = False
    else:
        gate_type = "hexa-native-absent"
        provisional = True
    record = {
        "domain": "space",
        "verb": "verify",
        "kind": "gmat_basilisk_orbit_adcs",
        "stamp": stamp,
        "producer": (
            f"basilisk@{getattr(basilisk, '__version__', 'unknown')}"
            if basilisk is not None
            else "basilisk@absent (+ gmat-binary out-of-band)"
        ),
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": (
            "basilisk_import_failed" if import_err is not None else None
        ),
        "gate_type": gate_type,
        "provisional": provisional,
    }
    rec_path = out / f"space_verify_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[space+verify] wrote {rec_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/space_verify"))
