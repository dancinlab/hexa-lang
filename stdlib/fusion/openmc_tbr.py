#!/usr/bin/env python3
# openmc_tbr.py — `fusion + verify` producer (D72 ①b thin adapter).
#
# ROI rank 11 from
# `inbox/notes/absorption-empty-cells-research-2026-05-20.md` §3 fusion.
# OpenMC tritium-breeding-ratio (TBR) + shutdown-dose-rate neutronics
# benchmark — single producer shared by fusion+verify AND
# energy+verify (which reuses the same OpenMC install — ROI 12).
# References:
#   - OpenMC/Geant4 fusion-blanket TBR benchmark, J. Fusion Energy
#     doi:10.1007/s10894-025-00500-8 (already cited fusion.md §5).
#   - FNS-SINBAD fusion-neutronics validation, Fusion Sci. Tech.
#     doi:10.1080/15361055.2024.2323747.
#
# D61: substrate SSOT here under `hexa-lang/stdlib/fusion/`. Demiurge
#      spawns via `python3 ~/core/hexa-lang/stdlib/fusion/openmc_tbr.py
#      <out_dir>`.
# D72: classify FIRST — OpenMC is Monte-Carlo particle transport →
#      already covered by `kernels/mc_transport/` (κ-45). This is the
#      SECOND consumer of mc_transport (antimatter+analyze was the
#      first), so the kernel-reuse pattern is now visibly load-bearing
#      (N×M → N+M, D72 rationale). Magnetics/CFD pieces of a fusion
#      model are NOT in scope here — that is `fusion+analyze` (already
#      filled, κ-41).
# g3:  honest install-gated. OpenMC needs `pip install openmc` + nuclear
#      data (~GB ENDF/B-VIII.0 download). If openmc is not importable
#      OR the data path is unset, this emits a GATE_OPEN /
#      absorbed=false skip with clear install hint. Never silently
#      absorbs.

from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path


def _try_import_openmc():
    try:
        import openmc  # noqa: F401

        return openmc, None
    except ImportError as e:  # pragma: no cover
        return None, str(e)


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    openmc, import_err = _try_import_openmc()
    citations = [
        "OpenMC/Geant4 fusion-blanket TBR benchmark — J. Fusion Energy, "
        "doi:10.1007/s10894-025-00500-8.",
        "FNS-SINBAD fusion-neutronics validation — Fusion Sci. Tech., "
        "doi:10.1080/15361055.2024.2323747.",
        "OpenMC docs — openmc.org (Romano et al., MIT/ANL SSOT).",
    ]
    scope_caveats: list[str] = []
    data_path = os.environ.get("OPENMC_CROSS_SECTIONS") or os.environ.get(
        "OPENMC_ENDF_DATA"
    )

    if import_err is not None:
        scope_caveats.append(
            "openmc not importable — honest install-gated skip. ImportError: "
            f"{import_err}. Install: `pip install openmc` + download "
            "ENDF/B-VIII.0 (~3 GB) and set OPENMC_CROSS_SECTIONS."
        )
    elif data_path is None:
        scope_caveats.append(
            "openmc importable but OPENMC_CROSS_SECTIONS not set — honest "
            "data-gated skip. Download ENDF/B-VIII.0 (~3 GB) and export the "
            "path."
        )
    scope_caveats.append(
        "Reference DEMO breeder-blanket geometry NOT a sourced engineering "
        "lattice — TBR will be a textbook witness, not a design-grade number."
    )
    # G7 typed gate_type — install-gated when openmc absent; data-gated
    # when openmc importable but ENDF/B-VIII.0 not set; otherwise the
    # benchmark stack is ready and the kernel reuse path is the honest
    # blocker → D80 hexa-native-absent + provisional.
    if import_err is not None:
        gate_type = "install-gated"
        provisional = False
    elif data_path is None:
        gate_type = "data-gated"
        provisional = False
    else:
        gate_type = "hexa-native-absent"
        provisional = True
    record = {
        "domain": "fusion",
        "verb": "verify",
        "kind": "openmc_tbr_neutronics",
        "stamp": stamp,
        "producer": (
            f"openmc@{getattr(openmc, '__version__', 'unknown')}"
            if openmc is not None
            else "openmc@absent"
        ),
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": (
            "openmc_import_failed"
            if import_err is not None
            else ("openmc_data_path_unset" if data_path is None else None)
        ),
        "gate_type": gate_type,
        "provisional": provisional,
        "kernel_reuse": "kernels/mc_transport/ (D72 — 2nd consumer after antimatter+analyze)",
    }
    rec_path = out / f"fusion_verify_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[fusion+verify] wrote {rec_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/fusion_verify"))
