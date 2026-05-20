#!/usr/bin/env python3
# pyfemm_magnetics.py — `rtsc + analyze` producer (D72 ①b thin adapter).
#
# ROI rank 10 from
# `inbox/notes/absorption-empty-cells-research-2026-05-20.md` §3 rtsc
# block. **rtsc is the highest-leverage empty domain** — whole-domain
# 0 producers before this round. pyfemm drives FEMM (David Meeker's
# 2-D / axisymmetric FEM magnetics solver) for High-Temperature
# Superconductor (HTS) coil B-field maps + magnetisation studies.
#
# Cohort handoff pickup: `inbox/notes/cohort-pickup-rtsc-femm-producer.md`
# (demiurge side). References:
#   - arxiv:0811.2883 — 3-D FEM HTS magnetization, single-time-step
#     iteration (the GetDP HTS algorithm paper, applicable patterns).
#   - HTS Modelling Workgroup shared model files — htsmodelling.com.
#   - FEMM manual — femm.info (David Meeker SSOT, Aladdin Free Public
#     License).
#
# D61: substrate SSOT here under `hexa-lang/stdlib/rtsc/`. Demiurge spawns
#      via `python3 ~/core/hexa-lang/stdlib/rtsc/pyfemm_magnetics.py <out>`.
# D72: classify FIRST — FEMM is a 2-D EM solver with its own ecosystem
#      (NOT skfem). Stays in rtsc adapter (thin) for now; promote to
#      `kernels/em_2d/` only at 2nd consumer.
# g3:  honest install-gated AND platform-gated.
#      - macOS = partly blocked (FEMM is Windows-native; Wine works but
#        is honest-skip by default — `pyfemm` import will fail without
#        FEMM binary present).
#      - Linux = `pyfemm` + xvfb on `ubu` roster (wilson-pool target).
#      Both honest skips emit a GATE_OPEN / absorbed=false record with
#      clear scope_caveats — never silently absorbs.

from __future__ import annotations

import json
import platform
import sys
import time
from pathlib import Path


def _try_import_pyfemm():
    try:
        import femm  # pyfemm uses the `femm` module name

        return femm, None
    except ImportError as e:  # pragma: no cover
        return None, str(e)


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    citations = [
        "arxiv:0811.2883 — 3-D FEM HTS magnetization, single-time-step "
        "iteration (Pecher / Sirois et al.).",
        "FEMM 4.2 — David Meeker, femm.info (Aladdin Free Public License).",
        "HTS Modelling Workgroup shared model files — htsmodelling.com.",
        "Demiurge cohort handoff: inbox/notes/cohort-pickup-rtsc-femm-"
        "producer.md (existing rtsc+analyze pickup, this lands it).",
    ]
    scope_caveats: list[str] = []
    sysname = platform.system()
    femm, import_err = _try_import_pyfemm()

    if sysname == "Darwin":
        scope_caveats.append(
            "macOS host = partly blocked. FEMM is a Windows-native binary "
            "(Wine only) — honest skip by default. Re-run on a Linux pool "
            "host (ubu-1 / ubu-2) where `pyfemm` + xvfb is supported."
        )
        record = {
            "domain": "rtsc",
            "verb": "analyze",
            "kind": "pyfemm_hts_axisym",
            "stamp": stamp,
            "producer": "pyfemm@macos-skip",
            "measurement_gate": "GATE_OPEN",
            "absorbed": False,
            "scope_caveats": scope_caveats,
            "citations": citations,
            "platform": sysname,
            "skipped_reason": "macos_host_femm_windows_binary_only",
            # G7 typed gate_type — FEMM is Windows-native; macOS host
            # cannot run the binary path natively.
            "gate_type": "platform-gated",
        }
        rec_path = out / f"rtsc_analyze_{stamp}.json"
        rec_path.write_text(json.dumps(record, indent=2))
        print(f"[rtsc+analyze] macOS honest skip. wrote {rec_path}")
        return 0

    if import_err is not None:
        scope_caveats.append(
            "pyfemm / femm module not importable — honest install-gated "
            f"skip. ImportError: {import_err}. Install on Linux: "
            "`python3 -m pip install --user pyfemm` + `apt install xvfb wine`."
        )
        record = {
            "domain": "rtsc",
            "verb": "analyze",
            "kind": "pyfemm_hts_axisym",
            "stamp": stamp,
            "producer": "pyfemm@absent",
            "measurement_gate": "GATE_OPEN",
            "absorbed": False,
            "scope_caveats": scope_caveats,
            "citations": citations,
            "platform": sysname,
            "skipped_reason": "pyfemm_import_failed",
            # G7 typed gate_type — pyfemm/femm not importable on PATH.
            "gate_type": "install-gated",
        }
        rec_path = out / f"rtsc_analyze_{stamp}.json"
        rec_path.write_text(json.dumps(record, indent=2))
        print(f"[rtsc+analyze] honest skip — pyfemm missing. wrote {rec_path}")
        return 0

    # Linux + pyfemm present. Run a tiny axisymmetric solenoid HTS B-field
    # map (honest scope: not a real HTS coil design, just a measurable
    # producer landing the cell).
    femm.openfemm()
    try:
        femm.newdocument(0)  # 0 = magnetics
        femm.mi_probdef(0, "centimeters", "axi", 1e-8, 0, 30)
        # 5 mm × 2 mm rectangular HTS tape proxy at r=10 mm
        femm.mi_drawrectangle(1.0, -0.1, 1.5, 0.1)
        femm.mi_addmaterial("HTS_proxy", 1, 1, 0, 0, 50, 0, 0, 1, 0, 0, 0)
        femm.mi_addblocklabel(1.25, 0)
        femm.mi_selectlabel(1.25, 0)
        femm.mi_setblockprop("HTS_proxy", 1, 0, "<None>", 0, 0, 0)
        femm.mi_clearselected()
        # Bounding box
        femm.mi_drawrectangle(0, -5, 5, 5)
        femm.mi_addblocklabel(3, 3)
        femm.mi_selectlabel(3, 3)
        femm.mi_setblockprop("Air", 1, 0, "<None>", 0, 0, 0)
        femm.mi_clearselected()
        femm.mi_addmaterial("Air", 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0)
        # Save + solve
        fem = out / "rtsc_axisym.fem"
        femm.mi_saveas(str(fem))
        femm.mi_analyze()
        femm.mi_loadsolution()
        bx, by = femm.mo_getb(1.25, 0)
        b_mag = float((bx**2 + by**2) ** 0.5)
        femm.mo_close()
    except Exception as exc:  # pragma: no cover
        b_mag = float("nan")
        scope_caveats.append(f"FEMM run failed: {exc!r}")
    finally:
        femm.closefemm()

    scope_caveats.append(
        "Tiny HTS-tape-proxy axisymmetric demo — NOT a calibrated coil. "
        "Real rtsc analyze needs a sourced HTS tape J_c(B,T,θ) field "
        "dependence + measured V-I tape characteristic to claim "
        "absorption."
    )
    record = {
        "domain": "rtsc",
        "verb": "analyze",
        "kind": "pyfemm_hts_axisym",
        "stamp": stamp,
        "producer": f"pyfemm@{getattr(femm, '__version__', 'unknown')}",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "platform": sysname,
        # G7 typed gate_type — FEMM ran on Linux; no hexa-native 2-D
        # EM kernel exists yet → D80 hexa-native-absent + provisional.
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "headline": {
            "b_magnitude_T_at_centre_of_proxy_tape": b_mag,
        },
    }
    rec_path = out / f"rtsc_analyze_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[rtsc+analyze] wrote {rec_path}  |B|={b_mag:.3e} T")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/rtsc_analyze"))
