#!/usr/bin/env python3
# xsuite_optics.py — `cern + synthesize` producer (D72 ①b thin adapter).
#
# ROI rank 7 from
# `inbox/notes/absorption-empty-cells-research-2026-05-20.md` §3 cern
# block. Xsuite (pure Python beam-physics framework, CERN OSS) does
# integrated optics functions + matched distributions. References:
#   - Xsuite — arxiv:2310.00317 (Iadarola et al., "Xsuite: an integrated
#     beam physics simulation framework", 2023; CERN AB-Note SL-)
#   - MAD-NG — arxiv:2412.16006 (Deniau, "MAD-NG, a standalone linear /
#     non-linear optics design framework", 2024)
#
# D61: substrate SSOT here under `hexa-lang/stdlib/cern/`. Demiurge spawns
#      via `python3 ~/core/hexa-lang/stdlib/cern/xsuite_optics.py <out>`.
# D72: classify FIRST — accelerator-optics is single-domain today (cern
#      only); kept in cern adapter (thin). Promote to
#      `kernels/accelerator_optics/` only at 2nd consumer.
# g3:  honest install-gated. If `xsuite` (or `cpymad`) is not importable
#      this emits a GATE_OPEN / absorbed=false skip record with install
#      hint. Otherwise runs the FODO twiss + tune fit AND an independent
#      Wiedemann/Lee thick-quad closed-form oracle in pure Python; both
#      β_x_max and Q_x must match to rel err ≤ 1e-6 for the record to
#      flip to GATE_CLOSED_MEASURED / absorbed=true. Failing the gate
#      keeps GATE_OPEN. This is an ALGORITHM-level closure (Xsuite ⇄
#      analytic), NOT a measured-lattice closure — scope_caveats spell
#      that out; flipping on a real measured tune still requires a
#      sourced ring optics deck.

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


def _analytic_fodo_twiss(L_d: float, L_q: float, k1: float
                          ) -> tuple[float, float]:
    """Closed-form periodic-cell twiss for thick-quad / drift FODO.

    Reference: Wiedemann *Particle Accelerator Physics* §6.2 + §7.4
    (equivalently Lee *Accelerator Physics* §2.2–§2.4). The 4-element
    sequence QF · D · QD · D gives a 2×2 transfer matrix M; the
    periodic Twiss solution is

        cos(μ) = ½ · tr(M)
        β_max  = M_12 / sin(μ)
        Q_x    = arccos(cos(μ)) / (2π)

    Pure-Python (no NumPy / no Xsuite import) so this is an
    *independent* oracle for the Xsuite twiss emitted by
    _fodo_demo_line.
    """
    import math

    sk = math.sqrt(k1)
    cf, sf = math.cos(sk * L_q), math.sin(sk * L_q)
    ch, sh = math.cosh(sk * L_q), math.sinh(sk * L_q)
    QF = [[cf, sf / sk], [-sk * sf, cf]]
    QD = [[ch, sh / sk], [sk * sh, ch]]
    D = [[1.0, L_d], [0.0, 1.0]]

    def mm(A, B):
        return [
            [A[0][0]*B[0][0] + A[0][1]*B[1][0],
             A[0][0]*B[0][1] + A[0][1]*B[1][1]],
            [A[1][0]*B[0][0] + A[1][1]*B[1][0],
             A[1][0]*B[0][1] + A[1][1]*B[1][1]],
        ]

    M = mm(mm(mm(D, QD), D), QF)
    cos_mu = 0.5 * (M[0][0] + M[1][1])
    sin_mu = math.sqrt(max(0.0, 1.0 - cos_mu * cos_mu))
    beta = M[0][1] / sin_mu
    q_x = math.acos(max(-1.0, min(1.0, cos_mu))) / (2.0 * math.pi)
    return float(beta), float(q_x)


def _fodo_demo_line(xt) -> tuple[object, float, float]:
    """Build a tiny FODO cell (Quad–Drift–Quad–Drift) and matched twiss.

    Returns (line, beta_x_max, q_x) — the synth-cell "headline numbers"
    we ship in the record. Honest scope_caveats list flags that the
    parameters are textbook (NOT calibrated to any real ring) and that
    this is optics-only (no space-charge, no IBS, no machine
    impedance).
    """
    L = 1.0  # m drift
    K = 1.0 / (4.0 * L)  # quad focal length proxy
    line = xt.Line(
        elements=[
            xt.Quadrupole(length=0.1, k1=K),
            xt.Drift(length=L),
            xt.Quadrupole(length=0.1, k1=-K),
            xt.Drift(length=L),
        ],
        element_names=["QF", "D1", "QD", "D2"],
    )
    line.particle_ref = xt.Particles(p0c=7e12, mass0=xt.PROTON_MASS_EV, q0=1)
    try:
        tw = line.twiss(method="4d")
        beta_x_max = float(tw.betx.max())
        q_x = float(tw.qx)
    except Exception:
        beta_x_max = float("nan")
        q_x = float("nan")
    return line, beta_x_max, q_x


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    xs, xt, import_err = _try_import_xsuite()
    citations = [
        "arxiv:2310.00317 — Xsuite integrated beam-physics framework "
        "(Iadarola et al., 2023).",
        "arxiv:2412.16006 — MAD-NG standalone linear / non-linear optics "
        "design (Deniau, 2024).",
        "CERN Beam Physics Group — Xsuite docs at xsuite.web.cern.ch.",
    ]
    scope_caveats: list[str] = []

    if import_err is not None:
        scope_caveats.append(
            "xsuite / xtrack not importable — honest install-gated skip. "
            f"ImportError: {import_err}. Install with "
            "`python3 -m pip install --user xsuite` and re-run."
        )
        record = {
            "domain": "cern",
            "verb": "synthesize",
            "kind": "xsuite_fodo_twiss",
            "stamp": stamp,
            "producer": "xsuite@absent",
            "measurement_gate": "GATE_OPEN",
            "absorbed": False,
            "scope_caveats": scope_caveats,
            "citations": citations,
            "skipped_reason": "xsuite_import_failed",
            # G7 typed gate_type — xsuite/xtrack not importable.
            "gate_type": "install-gated",
        }
        rec_path = out / f"cern_synth_{stamp}.json"
        rec_path.write_text(json.dumps(record, indent=2))
        print(f"[cern+synthesize] honest skip — xsuite missing. wrote {rec_path}")
        return 0

    line, beta_x_max, q_x = _fodo_demo_line(xt)
    # Independent parity oracle (Wiedemann/Lee thick-quad twiss).
    beta_ref, q_ref = _analytic_fodo_twiss(L_d=1.0, L_q=0.1, k1=0.25)
    beta_rel_err = abs(beta_x_max - beta_ref) / beta_ref
    q_rel_err = abs(q_x - q_ref) / q_ref
    parity_tol = 1e-6
    parity_pass = (beta_rel_err < parity_tol) and (q_rel_err < parity_tol)

    scope_caveats.append(
        "FODO cell parameters (L_d=1 m drift, L_q=0.1 m quad, k1=0.25) are "
        "textbook NOT calibrated to any real ring (LHC / FCC-ee / SPS). "
        "The absorbed=true flip here is a CLOSURE on the ALGORITHM "
        "(Xsuite ⇄ Wiedemann/Lee thick-quad twiss closed form, rel err "
        f"≤ {parity_tol:.0e}); a flip on a *measured* lattice still needs "
        "a sourced ring optics deck + measured tune. See "
        "inbox/notes/parity_attempt_cern_synth_2026-05-20.md."
    )
    scope_caveats.append(
        "Optics-only — no space charge, IBS, impedance, or beam-beam. "
        "Independent verify (sscb-style breaking-capacity equivalent for "
        "beams) is the cern + verify cell already filled (κ-32 / D54)."
    )
    record = {
        "domain": "cern",
        "verb": "synthesize",
        "kind": "xsuite_fodo_twiss",
        "stamp": stamp,
        "producer": f"xsuite@{getattr(xs, '__version__', 'unknown')}",
        "measurement_gate": (
            "GATE_CLOSED_MEASURED" if parity_pass else "GATE_OPEN"
        ),
        "absorbed": bool(parity_pass),
        "scope_caveats": scope_caveats,
        "citations": citations,
        # G7 typed gate_type — xsuite ran; even when parity_pass closes
        # the algorithm-level gate, there is no hexa-native accelerator-
        # optics kernel yet → D80 hexa-native-absent + provisional.
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "parity": {
            "oracle": "Wiedemann §6.2 + §7.4 thick-quad closed form",
            "tolerance_rel": parity_tol,
            "beta_x_max_m_xsuite": beta_x_max,
            "beta_x_max_m_analytic": beta_ref,
            "beta_x_max_rel_err": beta_rel_err,
            "q_x_xsuite": q_x,
            "q_x_analytic": q_ref,
            "q_x_rel_err": q_rel_err,
            "pass": bool(parity_pass),
        },
        "headline": {
            "beta_x_max_m": beta_x_max,
            "q_x_tune": q_x,
            "p0c_GeV": 7000.0,
            "particle": "proton",
        },
    }
    rec_path = out / f"cern_synth_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[cern+synthesize] wrote {rec_path}  beta_x_max={beta_x_max:.3f} m  q_x={q_x:.4f}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/cern_synth"))
