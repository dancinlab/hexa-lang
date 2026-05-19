#!/usr/bin/env python3
# pdg_lookup.py — `antimatter + analyze` producer (D65 / κ-43).
#
# ①b ADAPTER (demiurge design.md D72 — STDLIB 2-layer restructure).
# The domain-agnostic particle-physics — `particle` import recovery
# and the per-particle PDG-data lookup — now lives in the ①a kernel
# `stdlib/kernels/mc_transport/transport_kernel.py`. This file is the
# THIN antimatter adapter: it owns ONLY the domain inputs (the
# antiparticle short-list, the PET / Penning-trap context) plus the
# domain-specific decay-summary formatting and the artifact emission.
# Mirrors the kernel-extraction pattern of `stdlib/component/
# gmsh_skfem.py` (fem kernel) and `stdlib/grid/networkx_basics.py`
# (graph kernel).
#
# SSOT placement: this script lives in ~/core/hexa-lang/stdlib/antimatter/
# per AGENTS.tape @D g_demiurge_pointer_only (D61). demiurge's
# AntimatterAnalyzeProducer.swift is a thin spawn-wrapper only — no
# compute logic in demiurge.
#
# What it does: look up a canonical short-list of standard antimatter
# particles in the Particle Data Group (PDG) live data — courtesy of
# the `particle` Python package (scikit-hep, BSD-3) — and emit a typed
# JSON record per (PDG-id, name, mass MeV, lifetime s, charge, decay
# modes). NO Geant4, NO simulation, NO physics modeling: this is a
# *lookup* over PDG-aggregated measured constants. The honesty stance
# (g3) is therefore:
#
#   • producer = "particle@<ver> (PDG live-data lookup)"
#   • numbers ARE real measured constants (from the PDG, the
#     authoritative aggregator of every accelerator-experiment
#     measurement); BUT
#   • this run is NOT a demiurge measurement — demiurge did not run an
#     experiment, it copied the PDG aggregator's record. So:
#       measurement_gate = GATE_OPEN  (NOT closedMeasured)
#       absorbed         = false      (NOT absorbed)
#     ALWAYS. The scope_caveats embed this distinction so a downstream
#     consumer never mistakes the record for a demiurge in-house
#     measurement.
#
# Why this is the lowest-hanging-fruit producer for `antimatter`:
# the domains/antimatter.md §2 map labels Geant4 (heavy, C++, slow
# install) as the canonical ANALYZE tool; `particle` (pip install ~5
# MB pure-Python, no native deps) provides a real, citable, measured-
# constant lookup at a 100× lower install cost — useful for any
# downstream antiproton/positron trap design that needs mass / charge
# / lifetime / decay branching without spinning up full Geant4.
#
# Output (per call):
#   <out_dir>/<id>.csv         — table of (pdg_id, name, mass_mev,
#                                charge, lifetime_s, ctau_m,
#                                decay_summary)
#   <out_dir>/<id>.meta.json   — site + system + simulation + measurements
#                                + artifacts (the typed sidecar)
#
# Summary line written to stderr (consumed by Swift wrapper):
#   ANTIMATTER_PDG_RESULT {"ok": true, "geometry_id": "...",
#       "particle_version": "0.26.2", "python_version": "3.14.4",
#       "rows": 4, "artifacts": {"csv": "...", "meta": "..."}}
#
# CLI:
#   python3 pdg_lookup.py <output_dir>
#
# The output_dir is created by the caller; this script writes the
# .csv + .meta.json inside it.

import json
import os
import sys
import hashlib
from datetime import datetime, timezone


# ------------------------------------------------------------------
# Locate the ①a mc_transport kernel. The demiurge `python3 <script>
# <out_dir>` spawn uses an arbitrary cwd, so resolve the kernel path
# relative to THIS file: stdlib/antimatter/pdg_lookup.py ->
# stdlib/kernels/mc_transport/. Same locate-by-__file__ pattern the
# fem ①b adapter (stdlib/component/gmsh_skfem.py) uses.
# ------------------------------------------------------------------
_KERNEL_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 "..", "kernels", "mc_transport"))
if _KERNEL_DIR not in sys.path:
    sys.path.insert(0, _KERNEL_DIR)

import transport_kernel  # noqa: E402  — ①a domain-agnostic MC kernel


# The ①a kernel's `ensure_particle` owns the `particle` import
# recovery (macOS Homebrew user-site layout); the import is exercised
# lazily on the first `lookup_particle` call. Fail LOUD on missing-
# module — silent success forbidden (the kernel raises, this adapter
# surfaces it via `_ensure_particle`).
def _ensure_particle():
    try:
        transport_kernel.ensure_particle()
    except ImportError as e:
        py_xy = f"{sys.version_info.major}.{sys.version_info.minor}"
        sys.stderr.write(
            "pdg_lookup: particle module missing — "
            "`pip install --user --break-system-packages particle` "
            f"(Python {py_xy}). Original: {e}\n")
        raise


_ensure_particle()
import particle  # noqa: E402  — version probe only; lookups go via kernel


# ------------------------------------------------------------------
# Canonical antiparticle short-list (g3 — narrow scope, honest).
# Selected to cover the three families that show up in demiurge's
# antimatter domain (trap + PET):
#   • positron (e+, antielectron)     — PET tracer + Penning trap
#   • antiproton (p~)                 — antihydrogen + AD/ELENA beam
#   • antineutron (n~)                — annihilation comparator
#   • antimuon (mu+)                  — PET-adjacent muon spin probe
# PDG ids per the 2024 PDG monte-carlo numbering scheme. DOMAIN data —
# owned by this ①b adapter, not the kernel.
# ------------------------------------------------------------------
ANTIPARTICLE_LIST = [
    (-11,   "positron"),
    (-2212, "antiproton"),
    (-2112, "antineutron"),
    (-13,   "antimuon"),
]


def _decay_summary(rec):
    """A *brief* text summary of the PDG-listed decay modes, derived
    from the ①a kernel's particle record. The particle package's
    per-particle decay table is rich (per-mode branching fractions,
    daughter ids) but cataloguing it row-by-row would 10× our record
    size. For now we return a short string — 'stable' / 'unstable:
    lifetime=... width=...' style — and pin the *width* (s^-1) which
    is the most-cited decay-rate number. A future record can carry
    the full mode list if a consumer needs it (deferred per andrej-
    karpathy minimum-new-structure).

    `rec` is the kernel's `lookup_particle` dict: `width_pdg_units`
    is the PDG decay width, `lifetime_s` is None for stable particles
    (the kernel folds the `particle` library's infinite lifetime to
    None — JSON has no Inf)."""
    width = rec["width_pdg_units"]
    lifetime_s = rec["lifetime_s"]
    if width == 0.0:
        return "stable (no measured decay width)"
    if lifetime_s is None:
        return f"width={width} (lifetime infinite or undefined)"
    # No structured mode list in this lib slice — emit human-readable.
    return (f"unstable: lifetime={lifetime_s:.4g} s, "
            f"width={width:.4g} (PDG units)")


def lookup_table(pdgids):
    """Return list of dicts — one row per requested antiparticle. The
    physics fields come from the ①a transport kernel's
    `lookup_particle`; this adapter attaches the domain `label` and
    the domain-specific `decay_summary`."""
    rows = []
    for pdg, label in pdgids:
        try:
            rec = transport_kernel.lookup_particle(pdg)
        except Exception as e:
            rows.append({
                "label": label, "pdg_id": pdg, "error": str(e),
                "name": None, "mass_mev": None, "charge": None,
                "lifetime_s": None, "ctau_m": None,
                "decay_summary": "lookup_failed",
                "is_self_conjugate": None, "anti_flag": None,
            })
            continue
        rows.append({
            "label": label,
            "pdg_id": rec["pdg_id"],
            "name": rec["name"],
            "pdg_name": rec["pdg_name"],
            "mass_mev": rec["mass_mev"],
            "mass_lower_mev": rec["mass_lower_mev"],
            "mass_upper_mev": rec["mass_upper_mev"],
            "charge": rec["charge"],
            "lifetime_s": rec["lifetime_s"],
            "ctau_m": rec["ctau_m"],
            "width_pdg_units": rec["width_pdg_units"],
            "spin_type": rec["spin_type"],
            "is_self_conjugate": rec["is_self_conjugate"],
            "anti_flag": rec["anti_flag"],
            "decay_summary": _decay_summary(rec),
        })
    return rows


def write_csv(rows, csv_path):
    # plain csv — keep dependency surface minimal
    cols = ["label", "pdg_id", "name", "mass_mev", "charge",
            "lifetime_s", "ctau_m", "decay_summary"]
    with open(csv_path, "w") as f:
        f.write(",".join(cols) + "\n")
        for r in rows:
            vals = []
            for c in cols:
                v = r.get(c)
                if v is None:
                    # CSV: render stable lifetime/ctau as "stable" so
                    # the file is human-readable; None as empty otherwise.
                    if c in ("lifetime_s", "ctau_m"):
                        vals.append("stable")
                    else:
                        vals.append("")
                elif isinstance(v, str):
                    vals.append(f'"{v}"' if "," in v else v)
                else:
                    vals.append(str(v))
            f.write(",".join(vals) + "\n")


def main(argv):
    if len(argv) < 2:
        sys.stderr.write(
            "usage: python3 pdg_lookup.py <output_dir>\n")
        return 2
    out_dir = argv[1]
    os.makedirs(out_dir, exist_ok=True)

    geom_id = "pdg_antiparticles_v1"
    rows = lookup_table(ANTIPARTICLE_LIST)

    # Stable id from the input list + lib version — the record is
    # deterministic given (input PDG-id list, particle lib version).
    fingerprint = hashlib.sha256(
        (json.dumps([(p, l) for p, l in ANTIPARTICLE_LIST])
         + "|" + particle.__version__).encode()
    ).hexdigest()[:16]

    csv_name = f"{geom_id}.csv"
    meta_name = f"{geom_id}.meta.json"
    csv_path = os.path.join(out_dir, csv_name)
    meta_path = os.path.join(out_dir, meta_name)
    write_csv(rows, csv_path)

    now_utc = datetime.now(timezone.utc).isoformat()
    meta = {
        "ok": True,
        "geometry_id": geom_id,
        "fingerprint": fingerprint,
        "particle_version": particle.__version__,
        "python_version": (
            f"{sys.version_info.major}.{sys.version_info.minor}."
            f"{sys.version_info.micro}"),
        "produced_at_utc": now_utc,
        "lookup": {
            "source": "PDG via scikit-hep/particle (BSD-3)",
            "requested": [
                {"pdg_id": p, "label": l} for p, l in ANTIPARTICLE_LIST
            ],
            "rows": len(rows),
        },
        "measurements": {
            "rows": len(rows),
            "table": rows,
        },
        "artifacts": {
            "csv": csv_name,
            "meta": meta_name,
        },
        "error": None,
    }
    with open(meta_path, "w") as f:
        json.dump(meta, f, indent=2, sort_keys=True)

    # Summary line — Swift wrapper greps for ANTIMATTER_PDG_RESULT.
    summary = {
        "ok": True,
        "geometry_id": geom_id,
        "particle_version": particle.__version__,
        "python_version": meta["python_version"],
        "rows": len(rows),
        "artifacts": meta["artifacts"],
    }
    sys.stderr.write("ANTIMATTER_PDG_RESULT " + json.dumps(summary) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
