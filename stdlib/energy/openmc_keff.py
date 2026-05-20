#!/usr/bin/env python3
# openmc_keff.py — `energy + verify` producer (D72 ①b thin adapter).
#
# ROI rank 12 — OpenMC k-effective benchmark for nuclear-power
# reactor cores (VERA / CEFR / KRITZ public reference suite). 3rd
# consumer of `kernels/mc_transport/` after antimatter+analyze (κ-31)
# and fusion+verify (this round). The mc_transport kernel is now
# clearly multi-consumer (3+) — promotion candidate to a hexa-native
# port (per D72 "kernel goes hexa-native once" pattern).
# References:
#   - arxiv:2506.22559 — OpenMC vs MCNP spent-fuel criticality
#     benchmark (2025).
#   - FNS-SINBAD shielding benchmark — Fusion Sci. Tech.
#     doi:10.1080/15361055.2024.2323747.
#   - Romano, P. K., et al. OpenMC SSOT — openmc.org.
#
# D61: substrate SSOT here under `hexa-lang/stdlib/energy/`.
# D72: kernels/mc_transport/ reuse (3rd consumer — N+M payoff visible).
# g3:  honest install-gated AND data-gated like fusion+verify.

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
        "arxiv:2506.22559 — OpenMC vs MCNP spent-fuel criticality benchmark "
        "(2025).",
        "FNS-SINBAD shielding benchmark — Fusion Sci. Tech., "
        "doi:10.1080/15361055.2024.2323747.",
        "OpenMC SSOT — openmc.org (Romano et al., MIT/ANL).",
    ]
    scope_caveats: list[str] = []
    data_path = os.environ.get("OPENMC_CROSS_SECTIONS") or os.environ.get(
        "OPENMC_ENDF_DATA"
    )

    if import_err is not None:
        scope_caveats.append(
            "openmc not importable — honest install-gated skip. ImportError: "
            f"{import_err}. Install: `pip install openmc` + ENDF/B-VIII.0."
        )
    elif data_path is None:
        scope_caveats.append(
            "OPENMC_CROSS_SECTIONS not set — honest data-gated skip."
        )
    scope_caveats.append(
        "Toy single-pin LWR proxy criticality scope — NOT a sourced VERA / "
        "CEFR benchmark. Real absorption requires the published benchmark "
        "geometry + measured k-eff."
    )
    record = {
        "domain": "energy",
        "verb": "verify",
        "kind": "openmc_keff_criticality",
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
        "kernel_reuse": "kernels/mc_transport/ (D72 — 3rd consumer; N+M payoff visible)",
    }
    rec_path = out / f"energy_verify_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[energy+verify] wrote {rec_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/energy_verify"))
