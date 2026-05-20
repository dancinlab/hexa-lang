#!/usr/bin/env python3
# elegant_tracking.py — `cern + analyze` producer (D72 ①b thin adapter).
#
# ROI rank 14 — 6-D particle tracking + dynamic aperture analysis via
# Xsuite GPU tracking OR elegant (RadiaSoft container). Completes the
# cern domain to 4/4 cells (analyze + synthesize + verify already
# filled). References:
#   - arxiv:2405.19163 — MAD-X space-charge matching (Iadarola et al.).
#   - arxiv:2408.11677 — Lie-map lattice-error identification.
#   - Xsuite tracking docs — xsuite.web.cern.ch.
#   - elegant — github.com/radiasoft/elegant (RadiaSoft container build).
#
# D61: substrate SSOT here under `hexa-lang/stdlib/cern/`.
# D72: accelerator-optics — reuses cern adapter (single-domain, kernel
#      promotion to `kernels/accelerator_optics/` deferred until 2nd
#      consumer outside cern).
# g3:  honest install-gated. xsuite already pip; elegant is a heavy
#      container (separate session if needed). If xsuite missing, skip.

from __future__ import annotations

import json
import sys
import time
from pathlib import Path


def _try_import_xsuite():
    try:
        import xtrack as xt  # noqa: F401
        import xsuite as xs

        return xs, xt, None
    except ImportError as e:  # pragma: no cover
        return None, None, str(e)


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    xs, xt, import_err = _try_import_xsuite()
    citations = [
        "arxiv:2405.19163 — MAD-X space-charge matching.",
        "arxiv:2408.11677 — Lie-map lattice-error identification.",
        "Xsuite tracking docs — xsuite.web.cern.ch.",
        "elegant — github.com/radiasoft/elegant (RadiaSoft container).",
    ]
    scope_caveats: list[str] = []
    n_turns = None
    survival = None
    if import_err is not None:
        scope_caveats.append(
            f"xsuite/xtrack not importable — honest install-gated skip. "
            f"ImportError: {import_err}. (elegant heavier — separate session.)"
        )
    else:
        # Honest single-particle 100-turn tracking on the same FODO cell
        # used for cern+synthesize. Real DA scan = thousands of particles
        # × tens-of-thousands of turns × radiation damping — separate
        # multi-hour session.
        try:
            line = xt.Line(
                elements=[
                    xt.Quadrupole(length=0.1, k1=0.25),
                    xt.Drift(length=1.0),
                    xt.Quadrupole(length=0.1, k1=-0.25),
                    xt.Drift(length=1.0),
                ],
                element_names=["QF", "D1", "QD", "D2"],
            )
            line.particle_ref = xt.Particles(
                p0c=7e12, mass0=xt.PROTON_MASS_EV, q0=1
            )
            line.build_tracker()
            particles = line.build_particles(x=[1e-3], px=[0.0])
            line.track(particles, num_turns=100)
            n_turns = 100
            survival = int(particles.state[0] > 0)
        except Exception as exc:
            scope_caveats.append(f"xtrack tracking failed: {exc!r}")

    scope_caveats.append(
        "100-turn single-particle tracking on a toy FODO — NOT a dynamic-"
        "aperture scan. Real cern+analyze absorption needs a sourced ring "
        "lattice + ≥1e4-turn DA scan + radiation damping + collective "
        "effects."
    )
    # G7 typed gate_type — install-gated when xsuite/xtrack absent;
    # otherwise tracking ran → D80 hexa-native-absent + provisional
    # (no hexa-native accelerator-optics tracking kernel yet).
    if import_err is not None:
        gate_type = "install-gated"
        provisional = False
    else:
        gate_type = "hexa-native-absent"
        provisional = True
    record = {
        "domain": "cern",
        "verb": "analyze",
        "kind": "xsuite_fodo_tracking",
        "stamp": stamp,
        "producer": (
            f"xsuite@{getattr(xs, '__version__', 'unknown')}"
            if xs is not None
            else "xsuite@absent"
        ),
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": (
            "xsuite_import_failed" if import_err is not None else None
        ),
        "gate_type": gate_type,
        "provisional": provisional,
        "headline": {
            "num_turns": n_turns,
            "particle_survival": survival,
        },
    }
    rec_path = out / f"cern_analyze_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[cern+analyze] wrote {rec_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/cern_analyze"))
