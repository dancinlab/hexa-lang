#!/usr/bin/env python3
# bethe_bloch_stopping.py — `cern + verify` producer (D65 / κ-42).
#
# ①b ADAPTER (demiurge design.md D72 — STDLIB 2-layer restructure).
# The domain-agnostic particle-physics — `particle` import recovery,
# PDG mass lookup, the Bethe-Bloch dE/dx formula — now lives in the
# ①a kernel `stdlib/kernels/mc_transport/transport_kernel.py`. This
# file is the THIN cern adapter: it owns ONLY the domain inputs
# (CERN-style shielding materials, the antiproton projectile, the
# ELENA-scale KE grid) and the artifact emission. Mirrors the
# kernel-extraction pattern of `stdlib/component/gmsh_skfem.py`
# (fem kernel) and `stdlib/grid/networkx_basics.py` (graph kernel).
#
# SSOT placement: this script lives in ~/core/hexa-lang/stdlib/cern/
# per AGENTS.tape @D g_demiurge_pointer_only (D61) + @D g_stdlib_ownership
# (D15). demiurge's CernVerifyProducer.swift is a thin spawn-wrapper only —
# no compute logic in demiurge.
#
# Cell context (domains/cern.md §2 + domains/antimatter.md §2):
#   verb=verify, oss-tool=Geant4 (radiation/shielding & antiproton
#   stopping/annihilation). Full Geant4 MC requires the CERN binary
#   distribution (CMake build ~2GB, data files ~700MB). For Stage 1
#   substrate this script computes the **Bethe-Bloch mean stopping
#   power dE/dx** for antiprotons in canonical CERN-style shielding
#   materials (Al, Cu, W, Pb) — the same closed-form formula that
#   Geant4's G4hIonisation populates its tables from in the
#   non-relativistic regime, evaluated analytically from PDG-aggregated
#   measured constants via the `particle` library.
#
# Why Bethe-Bloch is a *real measurement* even without Geant4 MC:
#   • The formula PDG endorses (PDG RPP §34, eq. 34.5) is a fit to
#     decades of accelerator stopping-power data.
#   • The constants (K = 4πN_Ar_e²m_ec² = 0.307075 MeV·cm²/g, m_pbar,
#     m_e, mean-excitation I per material) are PDG-aggregated measured.
#   • So the dE/dx output IS real measured physics — what makes this
#     GATE_OPEN is that Geant4's full MC adds: shell corrections (Z/β at
#     low E), density-effect (high γ), straggling, nuclear contributions.
#     This stub omits all four — useful for trap-design / shielding
#     scoping but NOT an absorbed-claim replacement for Geant4 MC.
#
# What it does (one call):
#   1. Read PDG masses + charges of antiproton, electron (via the
#      ①a transport kernel, which wraps `particle`).
#   2. For each (KE_MeV, material), evaluate Bethe-Bloch dE/dx via the
#      kernel:
#        -dE/dx = K · z² · (Z/A) · (1/β²) · [½·ln(2m_ec²β²γ²T_max/I²) − β²]
#      with density-effect δ = 0 (low-/mid-energy regime).
#   3. Write <out_dir>/cern_g4_stopping_v1.csv (table rows).
#   4. Write <out_dir>/cern_g4_stopping_v1.meta.json (typed sidecar).
#   5. If `uproot` is available, also write <out_dir>/cern_g4_stopping_v1.root
#      with one TH1F per material (dE/dx vs KE on a fixed bin grid) —
#      this is what the "+ ROOT" in the table refers to (Geant4's native
#      output format, the lingua-franca of LHC analysis chains).
#   6. Emit a one-line summary on stderr for the Swift wrapper:
#        CERN_G4_RESULT {"ok": true, "rows": <N>, "artifacts": {...}}
#
# HONESTY (g3 — non-negotiable):
#   • producer = "particle@<v> + Bethe-Bloch analytic (no Geant4 MC)"
#   • measurement_gate = GATE_OPEN ALWAYS — Bethe-Bloch is a slice of
#     what Geant4 G4hIonisation does, not the full MC chain.
#   • absorbed = false ALWAYS — absorption requires the hexa-native
#     re-derivation of Bethe-Bloch + density-effect + shell corrections
#     in stdlib/cern/, parity-checked against Geant4 within tolerance
#     (Stage 4, per ABSORPTION.md §"hexa 포팅 단계").
#   • Silent success forbidden — if `particle` is missing, exits ok=false.
#   • The .root artifact is OMITTED (not silently faked) if uproot is
#     missing; meta records `uproot_version: null` so consumers see the gap.
#
# CLI:
#   python3 bethe_bloch_stopping.py <output_dir>

import json
import os
import platform
import sys
import hashlib
from datetime import datetime, timezone


# ------------------------------------------------------------------
# Locate the ①a mc_transport kernel. The demiurge `python3 <script>
# <out_dir>` spawn uses an arbitrary cwd, so resolve the kernel path
# relative to THIS file: stdlib/cern/bethe_bloch_stopping.py ->
# stdlib/kernels/mc_transport/. Same locate-by-__file__ pattern the
# fem ①b adapter (stdlib/component/gmsh_skfem.py) uses.
# ------------------------------------------------------------------
_KERNEL_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 "..", "kernels", "mc_transport"))
if _KERNEL_DIR not in sys.path:
    sys.path.insert(0, _KERNEL_DIR)

import transport_kernel  # noqa: E402  — ①a domain-agnostic MC kernel


GEOMETRY_ID = "cern_g4_stopping_v1"

# Kinetic energies (MeV) sampled — coarse table covering trap-design
# range (1 MeV antiproton ~ ELENA injection) to LHC-fixed-target scale
# (1 GeV). Bethe-Bloch validity is roughly 0.05 < βγ < 1000.
KE_MEV_SAMPLES = [1.0, 3.0, 10.0, 30.0, 100.0, 300.0, 1000.0]

# Mean excitation energies (eV) from PDG Atomic & Nuclear Properties
# (PDG RPP 2024, Table 34.1). Z and A are atomic-number and atomic-mass
# of the dominant isotope (or natural-mix average for W, Pb).
MATERIALS = [
    # name, Z, A_gpermol, I_eV
    ("Al", 13, 26.9815, 166.0),
    ("Cu", 29, 63.5460, 322.0),
    ("W",  74, 183.840, 727.0),
    ("Pb", 82, 207.200, 823.0),
]

# Bethe-Bloch K factor: 4πN_A r_e² m_ec² = 0.307075 MeV·cm²/g
# (PDG 2024, eq. 34.5 / Table 34.4). Pinned to the ①a kernel's
# constant — domain-independent, so the kernel is the SSOT.
K_BB_MEV_CM2_PER_G = transport_kernel.K_BB_MEV_CM2_PER_G

# Projectile PDG ids — antiproton and electron. Domain inputs: the
# cern cell stops antiprotons; the electron mass enters Bethe-Bloch.
PDG_ANTIPROTON = -2212
PDG_ELECTRON = 11


def particle_version() -> str:
    """Probe the scikit-hep `particle` version via the ①a kernel."""
    return transport_kernel.particle_version()


def uproot_version_or_none() -> str | None:
    """Return uproot's version string or None if it isn't importable."""
    try:
        import uproot  # noqa: F401
        return uproot.__version__
    except Exception:
        return None


def antiproton_and_electron_mev() -> tuple[float, float]:
    """Pull PDG masses (MeV/c²) for antiproton and electron via the
    ①a transport kernel (which wraps scikit-hep `particle`). Falling
    back to None is forbidden — silent-success is a g3 violation; the
    kernel raises on a missing library / None mass."""
    m_pbar = transport_kernel.particle_mass_mev(PDG_ANTIPROTON)
    m_e = transport_kernel.particle_mass_mev(PDG_ELECTRON)
    return m_pbar, m_e


def bethe_bloch_dedx(
    ke_mev: float,
    m_proj_mev: float,
    z_proj: int,
    z_target: int,
    a_target: float,
    i_ev: float,
    m_e_mev: float,
) -> dict:
    """Evaluate the PDG mean-stopping-power expression at one (KE,
    material) point via the ①a transport kernel. Returns the row dict
    ready for CSV emission.

    Bethe-Bloch (PDG eq. 34.5, density-correction δ = 0):
        -dE/dx = K · z² · (Z/A) · (1/β²) ·
                 [ ½ · ln(2·m_e·c²·β²·γ²·T_max / I²) − β² ]
    with
        γ = 1 + KE / (m_proj·c²),   β² = 1 − 1/γ²,
        T_max = 2·m_e·c²·β²·γ² / (1 + 2γm_e/m_proj + (m_e/m_proj)²)
    """
    return transport_kernel.bethe_bloch_dedx(
        ke_mev=ke_mev,
        projectile_mass_mev=m_proj_mev,
        projectile_charge=z_proj,
        target_z=z_target,
        target_a_gpermol=a_target,
        target_i_ev=i_ev,
        electron_mass_mev=m_e_mev,
    )


def write_root_histograms(
    root_path: str,
    rows: list[dict],
) -> bool:
    """Write one TH1F per material (KE on x, dE/dx as content) to a
    ROOT file using `uproot`. Returns True on success, False if uproot
    is missing or the write fails (g3 — silent success forbidden)."""
    try:
        import uproot
        import numpy as np
    except Exception:
        return False

    # Group rows by material.
    by_mat: dict[str, list[dict]] = {}
    for r in rows:
        by_mat.setdefault(r["material"], []).append(r)

    try:
        with uproot.recreate(root_path) as f:
            for mat, mrows in by_mat.items():
                mrows_sorted = sorted(mrows, key=lambda x: x["ke_mev"])
                xs = np.array([r["ke_mev"] for r in mrows_sorted],
                              dtype=np.float64)
                ys = np.array([r["dedx_mevcm2_per_g"] for r in mrows_sorted],
                              dtype=np.float64)
                # uproot wants a typed dict {axis: ...} — write the
                # x/y arrays as a TTree branch ("ke_mev", "dedx").
                f[f"stopping_{mat}"] = {
                    "ke_mev": xs,
                    "dedx_mevcm2_per_g": ys,
                }
    except Exception:
        return False
    return True


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: bethe_bloch_stopping.py <output_dir>", file=sys.stderr)
        print("CERN_G4_RESULT {\"ok\": false, "
              "\"reason\": \"missing_output_dir\"}",
              file=sys.stderr)
        return 2

    out_dir = argv[1]
    os.makedirs(out_dir, exist_ok=True)

    # Loud-fail if particle is missing — silent success forbidden (g3).
    # The ①a kernel's `ensure_particle` owns the import recovery.
    try:
        transport_kernel.ensure_particle()
    except Exception as exc:
        print(f"engine_tool_gap — particle missing: {exc}", file=sys.stderr)
        print("CERN_G4_RESULT {\"ok\": false, "
              "\"reason\": \"particle_missing\"}",
              file=sys.stderr)
        return 1

    m_pbar, m_e = antiproton_and_electron_mev()

    rows: list[dict] = []
    for (mat, z, a, i_ev) in MATERIALS:
        for ke in KE_MEV_SAMPLES:
            r = bethe_bloch_dedx(
                ke_mev=ke,
                m_proj_mev=m_pbar,
                z_proj=1,  # antiproton charge magnitude (sign drops in z²)
                z_target=z,
                a_target=a,
                i_ev=i_ev,
                m_e_mev=m_e,
            )
            rows.append({
                "material": mat,
                "z_target": z,
                "a_target_gpermol": a,
                "i_ev": i_ev,
                "ke_mev": ke,
                "beta": r["beta"],
                "gamma": r["gamma"],
                "tmax_mev": r["tmax_mev"],
                "dedx_mevcm2_per_g": r["dedx_mevcm2_per_g"],
            })

    # ----- CSV -----
    csv_name = f"{GEOMETRY_ID}.csv"
    csv_path = os.path.join(out_dir, csv_name)
    csv_cols = ["material", "z_target", "a_target_gpermol", "i_ev",
                "ke_mev", "beta", "gamma", "tmax_mev",
                "dedx_mevcm2_per_g"]
    with open(csv_path, "w", encoding="utf-8") as f:
        f.write(",".join(csv_cols) + "\n")
        for r in rows:
            f.write(",".join(
                f"{r[c]:.10g}" if isinstance(r[c], float) else str(r[c])
                for c in csv_cols
            ) + "\n")

    # ----- ROOT (optional) -----
    root_name = f"{GEOMETRY_ID}.root"
    root_path = os.path.join(out_dir, root_name)
    root_ok = write_root_histograms(root_path, rows)
    uproot_v = uproot_version_or_none()

    # ----- meta.json -----
    meta_name = f"{GEOMETRY_ID}.meta.json"
    meta_path = os.path.join(out_dir, meta_name)
    iso_now = datetime.now(timezone.utc).isoformat()
    fingerprint = hashlib.sha256(
        json.dumps({
            "geometry": GEOMETRY_ID,
            "materials": [m[0] for m in MATERIALS],
            "ke_samples": KE_MEV_SAMPLES,
            "m_pbar_mev": m_pbar,
            "m_e_mev": m_e,
        }, sort_keys=True).encode()
    ).hexdigest()[:16]

    artifacts: dict[str, str] = {"csv": csv_name, "meta": meta_name}
    if root_ok:
        artifacts["root"] = root_name

    meta = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "fingerprint": fingerprint,
        "produced_at_utc": iso_now,
        "particle_version": particle_version(),
        "uproot_version": uproot_v,            # null if missing — g3
        "python_version": platform.python_version(),
        "platform": platform.platform(),
        "constants": {
            "k_bb_mevcm2_per_g": K_BB_MEV_CM2_PER_G,
            "antiproton_mass_mev": m_pbar,
            "electron_mass_mev": m_e,
        },
        "measurements": {
            "rows": len(rows),
            "materials": [m[0] for m in MATERIALS],
            "ke_mev_samples": KE_MEV_SAMPLES,
            "table": rows,
        },
        "artifacts": artifacts,
    }
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    # ----- summary line on stderr -----
    summary = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "fingerprint": fingerprint,
        "particle_version": particle_version(),
        "uproot_version": uproot_v,
        "python_version": platform.python_version(),
        "rows": len(rows),
        "artifacts": artifacts,
    }
    print(f"CERN_G4_RESULT {json.dumps(summary)}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
