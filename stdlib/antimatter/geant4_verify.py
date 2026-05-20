#!/usr/bin/env python3
# geant4_verify.py — `antimatter + verify` producer (D72 ①b thin adapter).
#
# ROI rank 18 — Geant4 antiproton stopping / annihilation benchmark.
# 4th consumer of `kernels/mc_transport/` (after antimatter+analyze,
# fusion+verify, energy+verify) — mc_transport is now the load-bearing
# example of D72 N+M payoff (1 kernel · 4 domain adapters).
# References:
#   - arxiv:2407.06721 — antiproton annihilation at rest in thin solid
#     targets vs Geant4/FLUKA MC (2024).
#   - arxiv:2503.04868 — low-energy antiproton annihilation on nuclei,
#     Geant4 v11.2.1 FTFP_INCLXX_EMZ (2025).
#   - arxiv:2604.21173 — positronium source modelling for Geant4 PET.
#
# D61: substrate SSOT under `hexa-lang/stdlib/antimatter/`.
# D72: kernels/mc_transport/ reuse (4th consumer — N+M kernel-payoff
#      visibly load-bearing). Geant4 build itself is multi-hour C++ —
#      separate session for the shared `transport` producer that
#      ABSORPTION.md README synthesis point 3 mentions (Geant4 + OpenMC
#      built once on pool).
# g3:  honest install-gated. Geant4 = multi-hour build on a multi-core
#      Linux host. Skip honest until that session lands.

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import time
from pathlib import Path


def _which_geant4() -> str | None:
    # geant4 ships a `geant4-config` (or `geant4.sh` env script) — both
    # are sentinels for an installed Geant4 toolkit.
    for name in ("geant4-config", "geant4.sh"):
        p = shutil.which(name)
        if p:
            return p
    return None


def _geant4_version(g4: str) -> str:
    try:
        out = subprocess.run(
            [g4, "--version"], capture_output=True, text=True, timeout=5
        ).stdout
        return out.strip().splitlines()[0] if out else "unknown"
    except Exception:
        return "unknown"


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    g4 = _which_geant4()
    citations = [
        "arxiv:2407.06721 — antiproton annihilation at rest in thin solid "
        "targets vs Geant4/FLUKA MC (2024).",
        "arxiv:2503.04868 — low-energy antiproton annihilation on nuclei, "
        "Geant4 v11.2.1 FTFP_INCLXX_EMZ (2025).",
        "arxiv:2604.21173 — positronium source modelling for Geant4 PET.",
        "Geant4 SSOT — geant4.web.cern.ch (CERN / KEK / SLAC collaboration).",
    ]
    scope_caveats: list[str] = []
    if g4 is None:
        scope_caveats.append(
            "Geant4 not installed — honest install-gated skip. Geant4 is a "
            "multi-hour C++ build on a multi-core Linux host. Recommended: "
            "single shared `transport` producer (Geant4 + OpenMC) built once "
            "on the pool — separate session per ABSORPTION.md synthesis "
            "point 3."
        )
    scope_caveats.append(
        "Reference antiproton-on-Al benchmark — NOT a sourced CERN AD / "
        "ELENA experimental geometry. Real absorption needs measured "
        "annihilation cross-section + sourced geometry + measured "
        "secondary-particle spectra."
    )
    # G7 typed gate_type — install-gated when Geant4 not installed;
    # otherwise substrate is ready and no hexa-native MC-transport
    # kernel has parity yet → D80 hexa-native-absent + provisional.
    if g4 is None:
        gate_type = "install-gated"
        provisional = False
    else:
        gate_type = "hexa-native-absent"
        provisional = True
    record = {
        "domain": "antimatter",
        "verb": "verify",
        "kind": "geant4_antiproton_stopping",
        "stamp": stamp,
        "producer": (
            f"geant4@{_geant4_version(g4)}" if g4 is not None else "geant4@absent"
        ),
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": (
            "geant4_not_installed" if g4 is None else None
        ),
        "gate_type": gate_type,
        "provisional": provisional,
        "kernel_reuse": "kernels/mc_transport/ (D72 — 4th consumer; clearest N+M payoff)",
    }
    rec_path = out / f"antimatter_verify_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[antimatter+verify] wrote {rec_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/antimatter_verify"))
