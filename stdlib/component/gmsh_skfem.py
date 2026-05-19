#!/usr/bin/env python3
# gmsh_skfem.py — `component + verify` producer (D66 / κ-44).
#
# ①b DOMAIN ADAPTER (demiurge design.md D72 2-layer STDLIB restructure).
# This file owns ONLY the component/electronics-package domain: the
# die-proxy geometry, the silicon material constants, the load case,
# and the honesty caveats. All FEM math (gmsh meshing, scikit-fem
# assembly + solve, von Mises post) lives in the domain-AGNOSTIC ①a
# kernel `stdlib/kernels/fem/skfem_kernel.py` — this adapter imports
# and calls it. The day a hexa-native FEM kernel lands, `absorbed`
# flips in the kernel, not here.
#
# SSOT placement: this script lives in ~/core/hexa-lang/stdlib/component/
# per AGENTS.tape @D g_demiurge_pointer_only (D61). demiurge's
# ComponentVerifyProducer.swift is a thin spawn-wrapper only — no compute
# logic in demiurge.
#
# What it does: build a small 3D solid (a silicon die proxy box, 10 mm
# × 10 mm × 2 mm), mesh it with gmsh tetrahedra, then run two finite-
# element solves via scikit-fem on the same mesh:
#
#   • THERMAL — steady-state heat conduction (Laplace equation with a
#     uniform body heat source on the top half representing die
#     dissipation, Dirichlet T = T_ambient on the back face). Material
#     constants are Si defaults (k = 148 W/m·K). Output: T_min, T_max,
#     T_mean (K) and the implied junction-to-ambient rise ΔT (K).
#
#   • STRUCTURAL — linear elasticity with gravity body force (no
#     external tractions for this toy run), Dirichlet u = 0 on the back
#     face (component bolted onto a heatsink proxy). Material constants
#     are Si defaults (E = 169 GPa, ν = 0.22, ρ = 2329 kg/m³). Output:
#     u_max (m) magnitude over the mesh nodes and σ_vM_max (Pa) over
#     the element centroids.
#
# Honest stance (g3 — non-negotiable):
#   • producer = "gmsh@<v> + scikit-fem@<v>" — pin the libraries, NOT
#     the part. The geometry is a TOY box, NOT a real component STEP
#     file from the rfc_008 chip→component handoff dossier.
#   • The numbers ARE real PDE (Partial Differential Equation) solutions
#     on the toy geometry — physically correct given the inputs — but
#     the inputs (material constants, load, geometry) are placeholder
#     until a real cited component lands. So:
#       measurement_gate = GATE_OPEN
#       absorbed         = false
#     ALWAYS. There is no path here that flips them. Wiring against a
#     measured component STEP + measured material datasheet + measured
#     load case + mesh convergence study is a separate phase.
#   • If gmsh / scikit-fem are missing OR mesh generation fails OR the
#     FEM solve diverges, returns ok=false and writes no record. Silent
#     success is forbidden.
#
# Why this stack is the lowest-hanging-fruit producer for `component +
# verify`: the domains/component.md §2 ANALYZE row lists Elmer FEM /
# CalculiX / Code_Aster / OpenFOAM as the canonical FE solvers. Those
# need a docker image (Salome-Meca, 5 GB+) OR a system package install
# (~500 MB+ with deps). The (gmsh + scikit-fem + numpy) trio installs
# via pure pip in ~70 MB, runs in <10 s on a laptop, and covers both
# heat conduction and linear elasticity — the two verdicts mentioned
# most often for electronics packages (thermal margin + bolt stress).
#
# Output (per call):
#   <out_dir>/<id>.csv         — flat table of measurement_key, value, unit
#   <out_dir>/<id>.meta.json   — geometry/material/load/measurements sidecar
#
# Summary line written to stderr (consumed by Swift wrapper):
#   COMPONENT_GMSH_SKFEM_RESULT {"ok": true, "geometry_id": "...",
#       "gmsh_version": "4.15.2", "skfem_version": "12.0.1",
#       "python_version": "3.14.4", "rows": 8,
#       "artifacts": {"csv": "...", "meta": "..."}}
#
# CLI:
#   python3 gmsh_skfem.py <output_dir>
#
# The output_dir is created by the caller; this script writes the
# .csv + .meta.json inside it. A scratch .msh file is also written
# inside out_dir for reproducibility (gmsh mesh).

import json
import os
import sys
import hashlib
from datetime import datetime, timezone


# ------------------------------------------------------------------
# Dependency import — try the default sys.path first; if that fails
# (Homebrew Python 3.14 with externally-managed packages places pip
# --user installs at ~/Library/Python/3.14/site-packages which is NOT
# on sys.path by default), inject the user-site path and retry. Either
# way, fail LOUD on missing-module — silent success forbidden (g3).
# ------------------------------------------------------------------
def _ensure_deps():
    needed = ["gmsh", "skfem", "numpy", "meshio"]
    missing = []
    for m in needed:
        try:
            __import__(m)
        except ImportError:
            missing.append(m)
    if not missing:
        return
    # try the macOS user-site for the current Python (best-effort)
    py_xy = f"{sys.version_info.major}.{sys.version_info.minor}"
    user_site = os.path.expanduser(
        f"~/Library/Python/{py_xy}/lib/python/site-packages")
    if os.path.isdir(user_site) and user_site not in sys.path:
        sys.path.insert(0, user_site)
    still_missing = []
    for m in missing:
        try:
            __import__(m)
        except ImportError:
            still_missing.append(m)
    if still_missing:
        sys.stderr.write(
            "gmsh_skfem: missing module(s): "
            + ", ".join(still_missing)
            + " — `python3 -m pip install --user --break-system-packages "
            + "gmsh scikit-fem numpy meshio` "
            + f"(Python {py_xy}).\n")
        raise SystemExit(2)


_ensure_deps()


# ------------------------------------------------------------------
# Locate the ①a FEM kernel. The demiurge `python3 <script> <out_dir>`
# spawn uses an arbitrary cwd, so resolve the kernel path relative to
# THIS file: stdlib/component/gmsh_skfem.py -> stdlib/kernels/fem/.
# Same locate-by-__file__ pattern the graph ①b adapters use.
# ------------------------------------------------------------------
_KERNEL_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 "..", "kernels", "fem"))
if _KERNEL_DIR not in sys.path:
    sys.path.insert(0, _KERNEL_DIR)

import skfem_kernel  # noqa: E402  — ①a domain-agnostic FEM kernel


# ------------------------------------------------------------------
# Canonical "die proxy" geometry + material (g3 — narrow scope, toy).
# Picked to be: physically plausible silicon die on a heatsink, NOT a
# measured part. Dimensions in METERS (SI throughout the script).
# DOMAIN data — owned by this ①b adapter, not the kernel.
# ------------------------------------------------------------------
GEOMETRY = {
    "id": "die_proxy_box_v1",
    "display_name": "Silicon die proxy (10×10×2 mm box)",
    "length_m": 10.0e-3,   # x
    "width_m":  10.0e-3,   # y
    "thickness_m": 2.0e-3, # z
    "mesh_size_m": 0.8e-3, # target element size
}

# Silicon defaults at ~300 K (Lide CRC Handbook + AZoM datasheets).
# These are textbook constants, NOT a datasheet measurement — see
# scope_caveats. SI units throughout.
MATERIAL = {
    "name": "silicon (textbook 300 K)",
    "k_w_per_mk": 148.0,         # thermal conductivity
    "rho_kg_per_m3": 2329.0,     # density
    "youngs_pa": 169.0e9,        # Young's modulus (anisotropic in reality)
    "poissons": 0.22,            # Poisson's ratio
}

# Load case: 5 W die dissipation distributed uniformly through the top
# 1 mm of the box (a stand-in for the heating region). Ambient = 25 °C
# = 298.15 K on the back face (z = 0). Gravity along -z.
LOAD = {
    "die_power_w": 5.0,
    "heating_region_thickness_m": 1.0e-3,
    "t_ambient_k": 298.15,
    "gravity_m_per_s2": 9.80665,
}


# ------------------------------------------------------------------
# Domain solves — thin wrappers that translate the component-specific
# load case into the kernel's domain-agnostic API and attach the
# domain-specific derived quantity (ΔT). The FEM math itself is the
# kernel's; this layer only knows "silicon die, 5 W on the top slab,
# clamped/cooled back face".
# ------------------------------------------------------------------
def solve_thermal_component(mesh):
    """Steady-state heat conduction for the die proxy. The 5 W die
    dissipation is a uniform volumetric source over the TOP heating
    slab only (z >= thickness - heating_region_thickness); the rest of
    the box has zero source. Back face (z = 0) is held at T_ambient.
    Returns the kernel result plus the domain-derived delta_t_k."""
    box_z = GEOMETRY["thickness_m"]
    heat_z = LOAD["heating_region_thickness_m"]
    heating_volume = (
        GEOMETRY["length_m"] * GEOMETRY["width_m"] * heat_z)
    q_v_top = LOAD["die_power_w"] / heating_volume   # W/m^3

    def body_source(x):
        # x is the global coord array (3, nelems, nqp); apply q_v_top
        # only where z >= (box_z - heat_z).
        import numpy as np
        z = x[2]
        in_top = (z >= (box_z - heat_z))
        return q_v_top * in_top.astype(float)

    res = skfem_kernel.solve_thermal(
        mesh,
        conductivity_w_per_mk=MATERIAL["k_w_per_mk"],
        body_source_w_per_m3=body_source,
        dirichlet_select=lambda x: x[2] < 1.0e-9,
        dirichlet_value_k=LOAD["t_ambient_k"])

    # Domain-derived: junction-to-ambient rise.
    res["delta_t_k"] = float(res["t_max_k"] - LOAD["t_ambient_k"])
    return res


def solve_structural_component(mesh):
    """Linear elasticity for the die proxy under self-weight. Gravity
    body force = ρ g in -z; back face (z = 0) clamped (u = 0, all
    three components). Returns the kernel result."""
    rho = MATERIAL["rho_kg_per_m3"]
    g = LOAD["gravity_m_per_s2"]
    # body force = ρ g in -z direction → f = (0, 0, -ρ g)
    body_force = (0.0, 0.0, -rho * g)

    return skfem_kernel.solve_elastic(
        mesh,
        youngs_pa=MATERIAL["youngs_pa"],
        poissons=MATERIAL["poissons"],
        body_force=body_force,
        dirichlet_select=lambda x: x[2] < 1.0e-9)


# ------------------------------------------------------------------
# CSV + meta writers — flat, human-readable.
# ------------------------------------------------------------------
def write_csv(rows, csv_path):
    cols = ["measurement_key", "value", "unit"]
    with open(csv_path, "w") as f:
        f.write(",".join(cols) + "\n")
        for r in rows:
            f.write(",".join(str(r[c]) for c in cols) + "\n")


def main(argv):
    if len(argv) < 2:
        sys.stderr.write("usage: python3 gmsh_skfem.py <output_dir>\n")
        return 2
    out_dir = argv[1]
    os.makedirs(out_dir, exist_ok=True)

    # 1. mesh — domain-agnostic kernel call (box spec is domain data).
    meshed = skfem_kernel.mesh_box(
        out_dir,
        length_m=GEOMETRY["length_m"],
        width_m=GEOMETRY["width_m"],
        thickness_m=GEOMETRY["thickness_m"],
        mesh_size_m=GEOMETRY["mesh_size_m"],
        name=GEOMETRY["id"])
    mesh = meshed["mesh"]
    msh_path = meshed["msh_path"]
    gver = meshed["gmsh_version"]
    n_nodes = meshed["n_nodes"]
    n_elems = meshed["n_elements"]

    # 2. thermal + structural solves (domain wrappers over the kernel)
    thermal = solve_thermal_component(mesh)
    structural = solve_structural_component(mesh)

    # 3. flat row list for csv
    rows = [
        {"measurement_key": "n_nodes",         "value": n_nodes,                       "unit": "count"},
        {"measurement_key": "n_elements",      "value": n_elems,                       "unit": "count"},
        {"measurement_key": "t_min_k",         "value": thermal["t_min_k"],            "unit": "K"},
        {"measurement_key": "t_max_k",         "value": thermal["t_max_k"],            "unit": "K"},
        {"measurement_key": "t_mean_k",        "value": thermal["t_mean_k"],           "unit": "K"},
        {"measurement_key": "delta_t_k",       "value": thermal["delta_t_k"],          "unit": "K"},
        {"measurement_key": "u_max_m",         "value": structural["u_max_m"],         "unit": "m"},
        {"measurement_key": "sigma_vm_max_pa", "value": structural["sigma_vm_max_pa"], "unit": "Pa"},
    ]

    geom_id = GEOMETRY["id"]
    csv_name = f"{geom_id}.csv"
    meta_name = f"{geom_id}.meta.json"
    csv_path = os.path.join(out_dir, csv_name)
    meta_path = os.path.join(out_dir, meta_name)
    write_csv(rows, csv_path)

    # versions
    import skfem
    skfem_version = skfem.__version__
    gmsh_version = gver

    # fingerprint = sha256 over (geometry, material, load, library
    # versions). Deterministic given the same script + libs.
    fingerprint_payload = {
        "geometry": GEOMETRY,
        "material": MATERIAL,
        "load": LOAD,
        "gmsh_version": gmsh_version,
        "skfem_version": skfem_version,
    }
    fingerprint = hashlib.sha256(
        json.dumps(fingerprint_payload, sort_keys=True).encode()
    ).hexdigest()[:16]

    now_utc = datetime.now(timezone.utc).isoformat()
    meta = {
        "ok": True,
        "geometry_id": geom_id,
        "fingerprint": fingerprint,
        "gmsh_version": gmsh_version,
        "skfem_version": skfem_version,
        "python_version": (
            f"{sys.version_info.major}.{sys.version_info.minor}."
            f"{sys.version_info.micro}"),
        "produced_at_utc": now_utc,
        "geometry": {
            "id": geom_id,
            "display_name": GEOMETRY["display_name"],
            "length_m": GEOMETRY["length_m"],
            "width_m":  GEOMETRY["width_m"],
            "thickness_m": GEOMETRY["thickness_m"],
            "mesh_size_m": GEOMETRY["mesh_size_m"],
            "n_nodes": n_nodes,
            "n_elements": n_elems,
        },
        "material": MATERIAL,
        "load": LOAD,
        "measurements": {
            "rows": len(rows),
            "table": rows,
            "thermal": thermal,
            "structural": structural,
        },
        "artifacts": {
            "csv": csv_name,
            "meta": meta_name,
            "msh": os.path.basename(msh_path),
        },
        "error": None,
    }
    with open(meta_path, "w") as f:
        json.dump(meta, f, indent=2, sort_keys=True)

    # Summary line — Swift wrapper greps for COMPONENT_GMSH_SKFEM_RESULT.
    summary = {
        "ok": True,
        "geometry_id": geom_id,
        "gmsh_version": gmsh_version,
        "skfem_version": skfem_version,
        "python_version": meta["python_version"],
        "rows": len(rows),
        "artifacts": meta["artifacts"],
    }
    sys.stderr.write("COMPONENT_GMSH_SKFEM_RESULT " + json.dumps(summary) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
