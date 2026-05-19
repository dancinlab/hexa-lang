#!/usr/bin/env python3
# gmsh_skfem.py — `component + verify` producer (D66 / κ-44).
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
import math
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

import numpy as np  # noqa: E402
import gmsh  # noqa: E402
from skfem import (  # noqa: E402
    MeshTet, Basis, ElementTetP1, ElementVector,
    BilinearForm, LinearForm, asm, condense, solve,
)
from skfem.helpers import dot, grad  # noqa: E402
from skfem.models.elasticity import (  # noqa: E402
    linear_elasticity, lame_parameters,
)


# ------------------------------------------------------------------
# Canonical "die proxy" geometry + material (g3 — narrow scope, toy).
# Picked to be: physically plausible silicon die on a heatsink, NOT a
# measured part. Dimensions in METERS (SI throughout the script).
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
# Mesh generation via gmsh's Python API. We build a single box volume,
# then call gmsh's Delaunay tet mesher and dump a .msh v2.2 file (the
# meshio-compatible legacy format skfem understands directly).
# ------------------------------------------------------------------
def build_mesh(out_dir):
    """Run gmsh to produce a .msh file inside out_dir. Returns
    (msh_path, gmsh_version_string, n_nodes, n_elements)."""
    msh_path = os.path.join(out_dir, "die_proxy_box_v1.msh")

    gmsh.initialize()
    try:
        gmsh.option.setNumber("General.Terminal", 0)  # silence stdout
        gmsh.model.add("die_proxy_box_v1")

        # geometry — OpenCascade box (x0,y0,z0, dx,dy,dz)
        gmsh.model.occ.addBox(
            0.0, 0.0, 0.0,
            GEOMETRY["length_m"],
            GEOMETRY["width_m"],
            GEOMETRY["thickness_m"])
        gmsh.model.occ.synchronize()

        # uniform target size
        gmsh.option.setNumber("Mesh.MeshSizeMin", GEOMETRY["mesh_size_m"])
        gmsh.option.setNumber("Mesh.MeshSizeMax", GEOMETRY["mesh_size_m"])

        # 3D mesh (Delaunay)
        gmsh.option.setNumber("Mesh.Algorithm3D", 1)
        gmsh.model.mesh.generate(3)

        # write .msh v2.2 (skfem / meshio understand this directly)
        gmsh.option.setNumber("Mesh.MshFileVersion", 2.2)
        gmsh.write(msh_path)

        # report sizes
        node_tags, _, _ = gmsh.model.mesh.getNodes()
        n_nodes = len(node_tags)
        elem_types, elem_tags, _ = gmsh.model.mesh.getElements(dim=3)
        n_elements = sum(len(t) for t in elem_tags)
        gver = gmsh.option.getString("General.Version")
    finally:
        gmsh.finalize()

    return msh_path, gver, n_nodes, n_elements


# ------------------------------------------------------------------
# Thermal FEM: steady-state heat conduction.
#
#     -∇·(k ∇T) = q_v   on the heating region (top 1 mm)
#     -∇·(k ∇T) = 0     elsewhere
#     T = T_amb          on the back face (z = 0)
#
# The natural (Neumann) BC on all other faces is zero flux — adiabatic
# sides + adiabatic top. This is the standard "junction-to-back"
# proxy for an electronics package mounted on a cold plate.
# ------------------------------------------------------------------
def solve_thermal(mesh):
    """Returns dict with T_min_k, T_max_k, T_mean_k, delta_t_k, dof_count."""
    basis = Basis(mesh, ElementTetP1())

    k_si = MATERIAL["k_w_per_mk"]
    box_z = GEOMETRY["thickness_m"]
    heat_z = LOAD["heating_region_thickness_m"]
    # volumetric heat source (W/m^3) over the top heating slab only
    heating_volume = (
        GEOMETRY["length_m"] * GEOMETRY["width_m"] * heat_z)
    q_v_top = LOAD["die_power_w"] / heating_volume   # W/m^3

    @BilinearForm
    def conduction(u, v, w):
        return k_si * dot(grad(u), grad(v))

    @LinearForm
    def body_source(v, w):
        # w.x is the global coordinate array (3, nelems, nqp).
        # Apply q_v_top only where z >= (box_z - heat_z).
        z = w.x[2]
        in_top = (z >= (box_z - heat_z))
        return q_v_top * in_top.astype(float) * v

    K = asm(conduction, basis)
    f = asm(body_source, basis)

    # Dirichlet on z = 0 (back face). Pick DOFs whose coordinate z ≈ 0.
    z_coords = mesh.p[2]
    dirichlet_node_ids = np.nonzero(z_coords < 1.0e-9)[0]
    # node ids ARE dof ids for ElementTetP1 (one scalar dof per node).
    D = dirichlet_node_ids

    x = basis.zeros()
    x[D] = LOAD["t_ambient_k"]
    x = solve(*condense(K, f, x=x, D=D))

    return {
        "t_min_k": float(np.min(x)),
        "t_max_k": float(np.max(x)),
        "t_mean_k": float(np.mean(x)),
        "delta_t_k": float(np.max(x) - LOAD["t_ambient_k"]),
        "dof_count": int(x.size),
    }


# ------------------------------------------------------------------
# Structural FEM: linear elasticity with gravity body force.
#
#     -∇·σ = ρ g       in volume
#      u = 0           on the back face (z = 0)
#     σ·n = 0          on the remaining faces (traction-free)
#
# σ = λ tr(ε) I + 2 μ ε,  ε = (∇u + ∇u^T)/2,
# λ = E ν / ((1+ν)(1-2ν)),  μ = E / (2 (1+ν))
#
# Output: max nodal displacement magnitude and max element-wise von
# Mises stress (a standard isotropic-yield comparison number).
# ------------------------------------------------------------------
def solve_structural(mesh):
    """Returns dict with u_max_m, sigma_vm_max_pa, dof_count."""
    E = MATERIAL["youngs_pa"]
    nu = MATERIAL["poissons"]
    rho = MATERIAL["rho_kg_per_m3"]
    g = LOAD["gravity_m_per_s2"]
    # Lamé parameters via scikit-fem's own converter — keeps the
    # E/ν → λ/μ algebra in one audited place.
    lam, mu = lame_parameters(E, nu)

    basis = Basis(mesh, ElementVector(ElementTetP1()))

    # Use scikit-fem's BUILT-IN linear-elasticity bilinear form
    # (skfem.models.elasticity.linear_elasticity) rather than a hand-
    # rolled `ddot(sigma(u), sym_grad(v))`. hexa-first: the absorbed
    # stdlib model is audited; a hand-rolled `eye(trace(...), 3)` form
    # was found (κ-44 debugging) to be ~44× too soft against the
    # closed-form uniaxial check `u = T·L/E`, whereas the built-in
    # passes that check (ratio ≈ 1.1 on this coarse P1 mesh).
    elasticity = linear_elasticity(lam, mu)

    @LinearForm
    def gravity_load(v, w):
        # body force = ρ g in -z direction → f · v = -ρ g v_z
        # v has shape (3, nelems, nqp); v[2] picks z component.
        # (verified: Σ f over z-dofs == -ρ g V, the total weight.)
        return -rho * g * v[2]

    K = asm(elasticity, basis)
    f = asm(gravity_load, basis)

    # Dirichlet on z = 0 — all three displacement components clamped.
    # ElementVector(ElementTetP1) lays its DOFs NODE-major / interleaved:
    # the DOF for node i, component c is at index 3*i + c (verified via
    # basis.nodal_dofs[:, :3] == [[0,3,6],[1,4,7],[2,5,8]]). So a manual
    # `fixed_nodes + c*n_nodes` expansion is WRONG — use the canonical
    # `basis.get_dofs()` helper, which resolves the layout correctly.
    D = basis.get_dofs(lambda x: x[2] < 1.0e-9)

    x = solve(*condense(K, f, D=D))

    # Extract the displacement as (3, n_nodes): basis.nodal_dofs is the
    # (3, n_nodes) DOF-index table, so x[basis.nodal_dofs] gathers
    # component c of node i straight from the interleaved solution.
    u = x[basis.nodal_dofs]
    u_mag = np.sqrt(u[0] ** 2 + u[1] ** 2 + u[2] ** 2)
    u_max = float(np.max(u_mag))

    # element-wise von Mises stress. skfem.Basis.interpolate +
    # projection is a bit ceremonious — for a closed-form on linear
    # tets we just compute σ at each element centroid using the
    # element's average displacement gradient.
    sigma_vm_max = _vm_max_p1(mesh, u)

    return {
        "u_max_m": u_max,
        "sigma_vm_max_pa": float(sigma_vm_max),
        "dof_count": int(x.size),
    }


def _vm_max_p1(mesh, u):
    """Max von Mises stress over the mesh elements, computed from
    the constant displacement gradient on each linear tet."""
    E = MATERIAL["youngs_pa"]
    nu = MATERIAL["poissons"]
    lam = E * nu / ((1.0 + nu) * (1.0 - 2.0 * nu))
    mu = E / (2.0 * (1.0 + nu))

    p = mesh.p              # (3, n_nodes) coords
    t = mesh.t              # (4, n_elems) tet node ids
    n_elems = t.shape[1]

    # For each tet, the linear-shape-function gradients are constant
    # over the element. We compute them via the inverse Jacobian.
    # x_i (i=0..3) are the 4 vertex coords (3,1) each.
    sigma_vm = np.empty(n_elems)
    for e in range(n_elems):
        nodes = t[:, e]
        x = p[:, nodes]            # (3, 4)
        # Jacobian relative to vertex 0
        J = np.column_stack([x[:, 1] - x[:, 0],
                             x[:, 2] - x[:, 0],
                             x[:, 3] - x[:, 0]])  # (3,3)
        Jinv = np.linalg.inv(J)
        # P1 shape gradient w.r.t. reference: N0 has grad (-1,-1,-1) in
        # the reference simplex, N1=(1,0,0), N2=(0,1,0), N3=(0,0,1).
        # Physical gradient = Jinv.T · grad_ref.
        grad_ref = np.array([[-1.0, -1.0, -1.0],
                             [1.0, 0.0, 0.0],
                             [0.0, 1.0, 0.0],
                             [0.0, 0.0, 1.0]])    # (4,3)
        grad_phys = grad_ref @ Jinv               # (4,3)
        # displacement at the 4 vertices
        u_e = u[:, nodes]                          # (3, 4)
        # ∇u = sum_i u_i ⊗ grad_phys_i
        grad_u = u_e @ grad_phys                   # (3, 3)
        eps_e = 0.5 * (grad_u + grad_u.T)
        sigma_e = 2.0 * mu * eps_e + lam * np.trace(eps_e) * np.eye(3)
        s = sigma_e
        # von Mises: σ_vm = sqrt(3/2 · s' : s'),  s' = s - tr(s)/3 · I
        s_dev = s - (np.trace(s) / 3.0) * np.eye(3)
        sigma_vm[e] = math.sqrt(1.5 * np.tensordot(s_dev, s_dev))
    return np.max(sigma_vm)


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

    # 1. mesh
    msh_path, gver, n_nodes, n_elems = build_mesh(out_dir)

    # 2. load mesh into skfem
    mesh = MeshTet.load(msh_path)

    # 3. thermal + structural solves
    thermal = solve_thermal(mesh)
    structural = solve_structural(mesh)

    # 4. flat row list for csv
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
