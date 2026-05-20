#!/usr/bin/env python3
# calculix.py — `component + analyze` producer (D72 ①b thin adapter).
#
# ROI rank 6 from
# `inbox/notes/absorption-empty-cells-research-2026-05-20.md` §3
# component block. CalculiX (ccx) is a free 3-D structural /
# thermomechanical FEA solver — extends κ-44 fem kernel (component+verify
# is filled with gmsh+skfem; analyze is an INDEPENDENT cited measurement
# using a different FEM backend so the two cells cross-check rather than
# duplicate). Cited workflow: OpenAM-SimCCX framework — PMC PMC12608665,
# 2025 (Additive-manufacturing CalculiX verification pipeline).
#
# D61: substrate SSOT lives here under `hexa-lang/stdlib/component/`,
#      NEVER in demiurge/cockpit/scripts/. Demiurge spawns this via
#      `python3 ~/core/hexa-lang/stdlib/component/calculix.py <out_dir>`.
# D72: classify FIRST — CalculiX is a FEM solver. The mesh layer is shared
#      with `kernels/fem/skfem_kernel.py` (mesh_box geometry primitive).
#      Solving stays adapter-local until either a 2nd CalculiX consumer
#      lands OR a hexa-native FEM kernel reaches parity — then a
#      `kernels/fem/calculix_kernel.py` extraction is the right next move
#      (note flagged in PLAN κ-48).
# g3:  honest install-gated. If `ccx` is not on PATH, this emits a
#      GATE_OPEN / absorbed=false skip record with a clear
#      "install ccx" hint in scope_caveats — never silently absorbs.

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path


def _which_ccx() -> str | None:
    """Return path to a CalculiX `ccx` binary, or None if not installed.

    macOS: usually a Homebrew tap (`brew install -s freecad` ships ccx in
    /Applications/FreeCAD.app/..., or `brew tap erickaa/CalculiX`).
    Ubuntu / Debian: `apt install calculix-ccx`.
    """
    for name in ("ccx", "ccx_2.21", "ccx_2.20"):
        p = shutil.which(name)
        if p:
            return p
    return None


def _ccx_version(ccx: str) -> str:
    """Probe ccx --help for a version string (best-effort, never crash)."""
    try:
        out = subprocess.run(
            [ccx, "-v"], capture_output=True, text=True, timeout=10
        ).stdout
        for line in out.splitlines():
            if "Version" in line or "version" in line:
                return line.strip()
    except Exception:
        pass
    return "unknown"


def _die_proxy_inp(out_dir: Path) -> Path:
    """Write the 10×10×2 mm die-proxy CalculiX .inp deck (silicon, 5 W top
    surface, fixed base) to disk and return the path.

    Geometry parity with component+verify (gmsh+skfem) — same domain box,
    same material constants, so the two cells can be cross-checked at the
    field level once both records are GATE_CLOSED_MEASURED.
    """
    inp = out_dir / "die_proxy.inp"
    # 8 nodes of a 10×10×2 mm box (mm units for CalculiX convention).
    # Single C3D8 hex element — minimal mesh; a real run uses gmsh ->
    # 2nd-order tets (see future kernels/fem/calculix_kernel.py extraction).
    deck = """*HEADING
component analyze — die-proxy 10x10x2 mm (Si), 5 W top-face heat load
*NODE
1, 0., 0., 0.
2, 10., 0., 0.
3, 10., 10., 0.
4, 0., 10., 0.
5, 0., 0., 2.
6, 10., 0., 2.
7, 10., 10., 2.
8, 0., 10., 2.
*ELEMENT, TYPE=C3D8, ELSET=DIE
1, 1,2,3,4,5,6,7,8
*MATERIAL, NAME=Si
*ELASTIC
130000., 0.27
*CONDUCTIVITY
148.
*EXPANSION
2.6e-6
*DENSITY
2.33e-9
*SOLID SECTION, ELSET=DIE, MATERIAL=Si
*BOUNDARY
1,1,3,0.
2,2,3,0.
3,3,3,0.
4,1,3,0.
*STEP
*HEAT TRANSFER, STEADY STATE
*DFLUX
DIE, S5, 50000.
*NODE FILE
NT,U
*EL FILE
S,E
*END STEP
"""
    inp.write_text(deck)
    return inp


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    ccx = _which_ccx()
    citations = [
        "OpenAM-SimCCX (PMC PMC12608665, 2025) — CalculiX verification "
        "workflow for additive manufacturing process simulation.",
        "CalculiX manual (Dhondt G., dhondt.de) — ccx solver SSOT.",
    ]
    scope_caveats: list[str] = []

    if ccx is None:
        scope_caveats.append(
            "CalculiX `ccx` binary not on PATH — honest install-gated skip. "
            "Install: macOS via Homebrew tap or FreeCAD-bundled ccx; Linux "
            "via `apt install calculix-ccx`. Re-run after install for real "
            "measurement."
        )
        scope_caveats.append(
            "Geometry / material / load are textbook silicon-die placeholders "
            "(10x10x2 mm, k=148 W/m·K, 5 W top face) — not a measured part."
        )
        record = {
            "domain": "component",
            "verb": "analyze",
            "kind": "calculix_thermomech",
            "stamp": stamp,
            "producer": "calculix_ccx@absent",
            "measurement_gate": "GATE_OPEN",
            "absorbed": False,
            "scope_caveats": scope_caveats,
            "citations": citations,
            "skipped_reason": "ccx_binary_not_found",
        }
        rec_path = out / f"component_analyze_{stamp}.json"
        rec_path.write_text(json.dumps(record, indent=2))
        print(f"[component+analyze] honest skip — ccx missing. wrote {rec_path}")
        return 0

    # ccx is present — run the deck.
    inp = _die_proxy_inp(out)
    job = out / "die_proxy"
    try:
        cp = subprocess.run(
            [ccx, str(job)], capture_output=True, text=True, timeout=120, cwd=out
        )
    except subprocess.TimeoutExpired:
        scope_caveats.append("ccx run timed out at 120s — placeholder mesh.")
        cp = None

    ccx_ok = cp is not None and cp.returncode == 0
    scope_caveats.append(
        "Single-element C3D8 mesh — illustrative scope, NOT a converged "
        "field. A real component analyze uses a gmsh-driven tet mesh from "
        "kernels/fem/skfem_kernel.py for cross-cell parity with "
        "component+verify."
    )
    record = {
        "domain": "component",
        "verb": "analyze",
        "kind": "calculix_thermomech",
        "stamp": stamp,
        "producer": f"calculix_ccx@{_ccx_version(ccx)}",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "ccx_returncode": cp.returncode if cp else None,
        "ccx_stderr_tail": (cp.stderr.splitlines()[-5:] if cp else None),
        "inp_path": str(inp.name),
    }
    rec_path = out / f"component_analyze_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[component+analyze] ccx_ok={ccx_ok} wrote {rec_path}")
    return 0 if ccx_ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/component_analyze"))
