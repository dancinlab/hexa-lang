#!/usr/bin/env python3
# getdp_hts.py — `rtsc + verify` producer (D72 ①b thin adapter).
#
# ROI rank 16 — GetDP (Gmsh ecosystem, open FEM) for the HTS H-/A-φ
# formulation (Sirois et al.). 3-D EM device verification matching the
# HTS Modelling Workgroup shared model files. References:
#   - arxiv:0811.2883 — 3-D FEM HTS magnetization (Pecher / Sirois) —
#     the GetDP HTS algorithm paper.
#   - HTS Modelling Workgroup shared model files — htsmodelling.com.
#   - GetDP — get-dp.org (Geuzaine, Gmsh-pair).
#
# D61: substrate SSOT under `hexa-lang/stdlib/rtsc/`.
# D72: 3-D EM solver — `kernels/em_2d/` would cover the 2-D pyfemm side
#      (rtsc+analyze); GetDP is 3-D and is a separate ecosystem. With
#      pyfemm (rtsc+analyze, κ-48) this is the 2nd rtsc-EM consumer →
#      promotion of an em / electromagnetic kernel namespace is now a
#      design candidate (note: `inbox/notes/em-kernel-promotion-pickup.md`
#      on demiurge side at κ-49 commit).
# g3:  honest install-gated. GetDP via `brew install getdp` or `apt
#      install getdp`; the H-/A-φ HTS formulation is a multi-week scope.

from __future__ import annotations

import json
import shutil
import sys
import time
from pathlib import Path


def _which_getdp() -> str | None:
    return shutil.which("getdp")


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    getdp = _which_getdp()
    citations = [
        "arxiv:0811.2883 — 3-D FEM HTS magnetization, GetDP H-/A-φ formulation "
        "(Pecher / Sirois).",
        "HTS Modelling Workgroup shared model files — htsmodelling.com.",
        "GetDP — get-dp.org (Geuzaine, U. Liège, Gmsh pair).",
    ]
    scope_caveats: list[str] = []
    if getdp is None:
        scope_caveats.append(
            "getdp binary not on PATH — honest install-gated skip. Install: "
            "macOS `brew install getdp`; Linux `apt install getdp`. "
            "The HTS H-/A-φ formulation is multi-week scope — this producer "
            "lands the gate, not the full benchmark."
        )
    scope_caveats.append(
        "Reference HTS tape cuboid — NOT a sourced coil. Real absorption "
        "needs a measured tape J_c(B,T,θ) + workgroup-shared geometry + "
        "ramp-rate-dependent loss validation."
    )
    # G7 typed gate_type — install-gated when getdp binary missing;
    # otherwise substrate is ready and no hexa-native 3-D EM kernel
    # exists yet → D80 hexa-native-absent + provisional.
    if getdp is None:
        gate_type = "install-gated"
        provisional = False
    else:
        gate_type = "hexa-native-absent"
        provisional = True
    record = {
        "domain": "rtsc",
        "verb": "verify",
        "kind": "getdp_hts_3d_em",
        "stamp": stamp,
        "producer": (
            f"getdp@{getdp}" if getdp is not None else "getdp@absent"
        ),
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": (
            "getdp_binary_not_found" if getdp is None else None
        ),
        "gate_type": gate_type,
        "provisional": provisional,
        "kernel_note": "em-kernel-promotion candidate (2nd rtsc-EM consumer with pyfemm)",
    }
    rec_path = out / f"rtsc_verify_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[rtsc+verify] wrote {rec_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/rtsc_verify"))
