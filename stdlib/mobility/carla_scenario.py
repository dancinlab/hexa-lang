#!/usr/bin/env python3
# carla_scenario.py — `mobility + verify` producer (D72 ①b thin adapter).
#
# ROI rank 17 — CARLA + ScenarioRunner regression with OpenSCENARIO
# 2.1 scenarios. **macOS = hard-blocked** (no maintained CARLA macOS
# build, Unreal Engine + multi-GB GPU). Linux pool only — honest skip
# on macOS host. References:
#   - arxiv:2311.09784 — VIVAS: System-level simulation-based V&V of
#     automated driving with CARLA/ScenarioRunner (2023).
#   - arxiv:2604.16452 — OpenSCENARIO 2.1 → CARLA compiler.
#   - CARLA SSOT — carla.org.
#
# D61: substrate SSOT under `hexa-lang/stdlib/mobility/`.
# D72: AD simulation framework single-domain (mobility); adapter-only.
# g3:  hard-blocked on macOS — honest skip. Linux pool routing via
#      wilson-pool when running on ubu hosts. Otherwise import attempt.

from __future__ import annotations

import json
import platform
import sys
import time
from pathlib import Path


def _try_import_carla():
    try:
        import carla  # noqa: F401

        return carla, None
    except ImportError as e:  # pragma: no cover
        return None, str(e)


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    sysname = platform.system()
    citations = [
        "arxiv:2311.09784 — VIVAS: System-level V&V of automated driving "
        "with CARLA/ScenarioRunner (2023).",
        "arxiv:2604.16452 — OpenSCENARIO 2.1 → CARLA compiler.",
        "CARLA SSOT — carla.org (CARLA team, CVC / Intel).",
    ]
    scope_caveats: list[str] = []
    if sysname == "Darwin":
        scope_caveats.append(
            "macOS host = hard-blocked. CARLA has no maintained macOS build "
            "(Unreal Engine + multi-GB GPU). Re-run on a Linux pool host "
            "(ubu-1 / ubu-2) with NVIDIA GPU + CARLA installed."
        )
        record = {
            "domain": "mobility",
            "verb": "verify",
            "kind": "carla_scenariorunner",
            "stamp": stamp,
            "producer": "carla@macos-blocked",
            "measurement_gate": "GATE_OPEN",
            "absorbed": False,
            "scope_caveats": scope_caveats,
            "citations": citations,
            "platform": sysname,
            "skipped_reason": "macos_host_hard_blocked",
            # G7 typed gate_type — CARLA has no maintained macOS build
            # (Unreal + multi-GB GPU); Linux pool only.
            "gate_type": "platform-gated",
        }
        rec_path = out / f"mobility_verify_{stamp}.json"
        rec_path.write_text(json.dumps(record, indent=2))
        print(f"[mobility+verify] macOS hard-block. wrote {rec_path}")
        return 0

    carla, import_err = _try_import_carla()
    if import_err is not None:
        scope_caveats.append(
            f"carla module not importable — honest install-gated skip. "
            f"ImportError: {import_err}. Install via CARLA Linux release "
            "package + `pip install carla`."
        )
    scope_caveats.append(
        "Single OpenSCENARIO regression — NOT a calibrated test matrix. "
        "Real absorption needs a sourced ODD (operational design domain) + "
        "≥1000 scenarios + measured KPIs (TTC, dispersion, NCAP-style)."
    )
    # G7 typed gate_type — Linux path: install-gated when carla not
    # importable; otherwise no hexa-native AD-sim kernel exists yet →
    # D80 hexa-native-absent + provisional.
    if import_err is not None:
        gate_type = "install-gated"
        provisional = False
    else:
        gate_type = "hexa-native-absent"
        provisional = True
    record = {
        "domain": "mobility",
        "verb": "verify",
        "kind": "carla_scenariorunner",
        "stamp": stamp,
        "producer": (
            f"carla@{getattr(carla, '__version__', 'unknown')}"
            if carla is not None
            else "carla@absent"
        ),
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "platform": sysname,
        "skipped_reason": (
            "carla_import_failed" if import_err is not None else None
        ),
        "gate_type": gate_type,
        "provisional": provisional,
    }
    rec_path = out / f"mobility_verify_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[mobility+verify] wrote {rec_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/mobility_verify"))
