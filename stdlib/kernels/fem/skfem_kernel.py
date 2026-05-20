# skfem_kernel.py — ①a STDLIB kernel layer (demiurge design.md D72)
#
# Domain-agnostic finite-element computation kernel. This is the
# SECOND kernel extracted under the D72 2-layer STDLIB restructure
# (after kernels/graph/networkx_kernel.py): producers in
# `stdlib/<domain>/` that run FEM solves (component+verify today;
# rtsc, fusion, sscb-verify slated per inbox/notes/kernel-extraction-
# pickup.md) call into this single module instead of each re-
# implementing the gmsh + scikit-fem wrapping.
#
# Layer split (ABSORPTION.md ①):
#   ①a kernel  — THIS FILE. Domain-independent. No silicon-die box,
#                no BIPV stack, no plasma chamber — only "given a
#                geometry spec + material + boundary conditions,
#                mesh it and solve the PDE".
#   ①b adapter — `stdlib/component/gmsh_skfem.py` (and future rtsc /
#                fusion / sscb-verify adapters). They own the domain
#                geometry / material constants / load case / honesty
#                caveats and call this kernel for the FEM math.
#
# HONESTY (g3 — non-negotiable, inherited by every caller):
#   * Every value computed here IS a real PDE (Partial Differential
#     Equation) solution on the supplied mesh — physically correct
#     given the inputs. It is NOT a measurement of any real part.
#     Whether the INPUTS (geometry, material, load) are measured or
#     placeholder is a domain question — the honesty gate lives on
#     the *real-world interpretation* in the ①b adapter, NOT here.
#   * absorbed = false ALWAYS at the record layer — gmsh and
#     scikit-fem are EXTERNAL Python libraries, not absorbed into
#     hexa-lang. The day a hexa-native FEM kernel re-solves these
#     PDEs with a numerically-equivalent method, absorbed flips —
#     and it flips HERE (one kernel) rather than in N domain
#     adapters. That is the entire point of the 2-layer restructure
#     (N×M -> N+M). The Stage-2 hexa ports already exist alongside
#     the component adapter (heat_conduction.hexa, linear_elasticity
#     .hexa) — when they reach parity, this kernel is where the
#     switch lands.
#   * Mesh convergence is NOT checked here — a single-element-size
#     solve is a point estimate, not a converged measurement. The
#     ①b adapter must surface that caveat.
#   * Import failure / mesh failure / solve divergence is raised, not
#     swallowed — silent success is forbidden. The caller reports the
#     exception verbatim.

import math
import os
from typing import Any


# ------------------------------------------------------------------
# Version probes — let the ①b adapter pin the libraries in its record
# provenance ("gmsh@<v> + scikit-fem@<v>"). Return 'unknown' if the
# library cannot be imported; the caller decides whether that is a
# hard gap (it is, for FEM producers).
# ------------------------------------------------------------------
def gmsh_version() -> str:
    """Probe the installed gmsh version string."""
    try:
        import gmsh
        gmsh.initialize()
        try:
            return str(gmsh.option.getString("General.Version"))
        finally:
            gmsh.finalize()
    except Exception:
        return "unknown"


def skfem_version() -> str:
    """Probe the installed scikit-fem version."""
    try:
        import skfem
        return str(skfem.__version__)
    except Exception:
        return "unknown"


# ------------------------------------------------------------------
# Mesh generation via gmsh's Python API. Domain-agnostic: the caller
# supplies a box spec (or, in future, a STEP path). We build the
# volume, run gmsh's Delaunay tet mesher, dump a .msh v2.2 file (the
# meshio-compatible legacy format skfem reads directly) and load it
# back into a skfem MeshTet.
# ------------------------------------------------------------------
def mesh_box(out_dir: str,
             length_m: float,
             width_m: float,
             thickness_m: float,
             mesh_size_m: float,
             name: str = "box") -> dict:
    """Mesh an axis-aligned box [0,L]×[0,W]×[0,T] with uniform target
    element size. Returns a dict:
        { "mesh": <skfem.MeshTet>, "msh_path": str,
          "gmsh_version": str, "n_nodes": int, "n_elements": int }

    Domain-agnostic — the caller decides what the box represents
    (silicon die, BIPV layer, chamber wall). All lengths in METERS.
    `out_dir` must already exist (the caller's spawn dir); a scratch
    .msh is written inside it for reproducibility."""
    import gmsh
    from skfem import MeshTet

    msh_path = os.path.join(out_dir, f"{name}.msh")

    gmsh.initialize()
    try:
        gmsh.option.setNumber("General.Terminal", 0)  # silence stdout
        gmsh.model.add(name)

        # geometry — OpenCascade box (x0,y0,z0, dx,dy,dz)
        gmsh.model.occ.addBox(0.0, 0.0, 0.0,
                              length_m, width_m, thickness_m)
        gmsh.model.occ.synchronize()

        # uniform target size
        gmsh.option.setNumber("Mesh.MeshSizeMin", mesh_size_m)
        gmsh.option.setNumber("Mesh.MeshSizeMax", mesh_size_m)

        # 3D mesh (Delaunay)
        gmsh.option.setNumber("Mesh.Algorithm3D", 1)
        gmsh.model.mesh.generate(3)

        # write .msh v2.2 (skfem / meshio read this directly)
        gmsh.option.setNumber("Mesh.MshFileVersion", 2.2)
        gmsh.write(msh_path)

        node_tags, _, _ = gmsh.model.mesh.getNodes()
        n_nodes = len(node_tags)
        elem_types, elem_tags, _ = gmsh.model.mesh.getElements(dim=3)
        n_elements = sum(len(t) for t in elem_tags)
        gver = gmsh.option.getString("General.Version")
    finally:
        gmsh.finalize()

    mesh = MeshTet.load(msh_path)
    return {
        "mesh": mesh,
        "msh_path": msh_path,
        "gmsh_version": gver,
        "n_nodes": int(n_nodes),
        "n_elements": int(n_elements),
    }


def mesh_from_step(out_dir: str,
                   step_path: str,
                   mesh_size_m: float,
                   name: str = "step") -> dict:
    """Mesh an external STEP solid with uniform target element size.
    Same return shape as `mesh_box`. The first body in the STEP is
    meshed; multi-body STEP handling is a future extension. This is
    the path a domain adapter takes the day a *real cited component
    geometry* lands (today component+verify uses the toy `mesh_box`)."""
    import gmsh
    from skfem import MeshTet

    if not os.path.isfile(step_path):
        raise FileNotFoundError(f"STEP file not found: {step_path}")

    msh_path = os.path.join(out_dir, f"{name}.msh")

    gmsh.initialize()
    try:
        gmsh.option.setNumber("General.Terminal", 0)
        gmsh.model.add(name)
        gmsh.model.occ.importShapes(step_path)
        gmsh.model.occ.synchronize()

        gmsh.option.setNumber("Mesh.MeshSizeMin", mesh_size_m)
        gmsh.option.setNumber("Mesh.MeshSizeMax", mesh_size_m)
        gmsh.option.setNumber("Mesh.Algorithm3D", 1)
        gmsh.model.mesh.generate(3)

        gmsh.option.setNumber("Mesh.MshFileVersion", 2.2)
        gmsh.write(msh_path)

        node_tags, _, _ = gmsh.model.mesh.getNodes()
        n_nodes = len(node_tags)
        elem_types, elem_tags, _ = gmsh.model.mesh.getElements(dim=3)
        n_elements = sum(len(t) for t in elem_tags)
        gver = gmsh.option.getString("General.Version")
    finally:
        gmsh.finalize()

    mesh = MeshTet.load(msh_path)
    return {
        "mesh": mesh,
        "msh_path": msh_path,
        "gmsh_version": gver,
        "n_nodes": int(n_nodes),
        "n_elements": int(n_elements),
    }


# ------------------------------------------------------------------
# Thermal FEM: steady-state heat conduction.
#
#     -∇·(k ∇T) = q_v   in volume (q_v from `body_source`)
#      T = T_dirichlet   where `dirichlet_select` is true
#
# The natural (Neumann) BC on all other faces is zero flux
# (adiabatic). Domain-agnostic — the caller passes the conductivity,
# the volumetric source as a callable of position, the Dirichlet
# face selector and its prescribed value.
# ------------------------------------------------------------------
def solve_thermal(mesh: Any,
                  conductivity_w_per_mk: float,
                  body_source_w_per_m3,
                  dirichlet_select,
                  dirichlet_value_k: float) -> dict:
    """Steady-state heat conduction on `mesh` (a skfem MeshTet).

    Arguments
      conductivity_w_per_mk : isotropic thermal conductivity k.
      body_source_w_per_m3  : callable z-coord-array -> W/m^3 array,
                              OR a scalar applied uniformly. Receives
                              the global coordinate array `w.x`
                              (shape (3, nelems, nqp)) and must return
                              a broadcastable volumetric source. A
                              plain float means a uniform source.
      dirichlet_select      : callable coord-array -> bool array
                              picking the prescribed-temperature
                              nodes (skfem `get_dofs`-style selector).
      dirichlet_value_k     : prescribed temperature on those nodes.

    Returns { t_min_k, t_max_k, t_mean_k, dof_count } — the caller
    derives any domain-specific delta (e.g. ΔT = t_max - t_ambient).
    All deterministic IEEE-754 PDE outputs, NOT model predictions."""
    import numpy as np
    from skfem import (Basis, ElementTetP1, BilinearForm, LinearForm,
                       asm, condense, solve)
    from skfem.helpers import dot, grad

    basis = Basis(mesh, ElementTetP1())
    k_si = float(conductivity_w_per_mk)

    @BilinearForm
    def conduction(u, v, w):
        return k_si * dot(grad(u), grad(v))

    if callable(body_source_w_per_m3):
        _src = body_source_w_per_m3
    else:
        _q = float(body_source_w_per_m3)

        def _src(x):
            return _q

    @LinearForm
    def body_source(v, w):
        # w.x is the global coordinate array (3, nelems, nqp).
        q = _src(w.x)
        return q * v

    K = asm(conduction, basis)
    f = asm(body_source, basis)

    # Dirichlet DOFs: node ids ARE dof ids for ElementTetP1 (one
    # scalar dof per node). `dirichlet_select` receives mesh.p.
    D = basis.get_dofs(dirichlet_select)

    x = basis.zeros()
    x[D] = float(dirichlet_value_k)
    x = solve(*condense(K, f, x=x, D=D))

    return {
        "t_min_k": float(np.min(x)),
        "t_max_k": float(np.max(x)),
        "t_mean_k": float(np.mean(x)),
        "dof_count": int(x.size),
    }


# ------------------------------------------------------------------
# Structural FEM: linear elasticity.
#
#     -∇·σ = f_body    in volume
#      u = 0           where `dirichlet_select` is true
#     σ·n = 0          on the remaining faces (traction-free)
#
# σ = λ tr(ε) I + 2 μ ε,  ε = (∇u + ∇u^T)/2,
# λ = E ν / ((1+ν)(1-2ν)),  μ = E / (2 (1+ν))
#
# Domain-agnostic — the caller passes E, ν, the body-force callable
# (gravity, thermal expansion equivalent load, …) and the clamp-face
# selector.
# ------------------------------------------------------------------
def solve_elastic(mesh: Any,
                  youngs_pa: float,
                  poissons: float,
                  body_force,
                  dirichlet_select) -> dict:
    """Linear-elastic solve on `mesh` (a skfem MeshTet).

    Arguments
      youngs_pa       : Young's modulus E.
      poissons        : Poisson's ratio ν.
      body_force      : callable v-array -> form contribution, applied
                        as a skfem LinearForm integrand. Receives the
                        vector test function `v` (shape (3,nelems,nqp))
                        and must return `f · v`. A 3-tuple/list of
                        scalars (fx,fy,fz) in N/m^3 is also accepted
                        and applied as a uniform body force.
      dirichlet_select: callable coord-array -> bool array picking the
                        clamped (u=0, all 3 components) nodes.

    Returns { u_max_m, sigma_vm_max_pa, dof_count }. u_max is the max
    nodal displacement magnitude; sigma_vm_max is the max element-wise
    von Mises stress over the linear-tet centroids. Deterministic PDE
    outputs.

    NOTE on the elasticity form (hexa-first / g3): this uses
    scikit-fem's BUILT-IN `linear_elasticity` model, NOT a hand-rolled
    `ddot(sigma(u), sym_grad(v))`. κ-44 debugging found a hand-rolled
    form ~44× too soft against the closed-form uniaxial check
    u = T·L/E; the built-in passes it (ratio ≈ 1.1 on a coarse P1
    mesh). The audited absorbed-stdlib form is the correct one."""
    import numpy as np
    from skfem import (Basis, ElementTetP1, ElementVector, LinearForm,
                       asm, condense, solve)
    from skfem.models.elasticity import (linear_elasticity,
                                         lame_parameters)

    E = float(youngs_pa)
    nu = float(poissons)
    lam, mu = lame_parameters(E, nu)

    basis = Basis(mesh, ElementVector(ElementTetP1()))
    elasticity = linear_elasticity(lam, mu)

    if callable(body_force):
        _bf = body_force
    else:
        fx, fy, fz = (float(c) for c in body_force)

        def _bf(v):
            return fx * v[0] + fy * v[1] + fz * v[2]

    @LinearForm
    def load_form(v, w):
        # v has shape (3, nelems, nqp); _bf returns f · v.
        return _bf(v)

    K = asm(elasticity, basis)
    f = asm(load_form, basis)

    # ElementVector(ElementTetP1) lays its DOFs NODE-major /
    # interleaved: the DOF for node i, component c is at index 3*i+c.
    # A manual `fixed_nodes + c*n_nodes` expansion is WRONG — use the
    # canonical `basis.get_dofs()` helper, which resolves the layout.
    D = basis.get_dofs(dirichlet_select)

    x = solve(*condense(K, f, D=D))

    # x[basis.nodal_dofs] gathers component c of node i straight from
    # the interleaved solution — shape (3, n_nodes).
    u = x[basis.nodal_dofs]
    u_mag = np.sqrt(u[0] ** 2 + u[1] ** 2 + u[2] ** 2)
    u_max = float(np.max(u_mag))

    sigma_vm_max = von_mises_max_p1(mesh, u, E, nu)

    return {
        "u_max_m": u_max,
        "sigma_vm_max_pa": float(sigma_vm_max),
        "dof_count": int(x.size),
    }


def von_mises_max_p1(mesh: Any, u: Any,
                     youngs_pa: float, poissons: float) -> float:
    """Max von Mises stress over the mesh elements, computed from the
    constant displacement gradient on each linear tet. `u` is the
    (3, n_nodes) nodal-displacement array (as returned by
    `solve_elastic` internally). Domain-agnostic post-processing."""
    import numpy as np

    E = float(youngs_pa)
    nu = float(poissons)
    lam = E * nu / ((1.0 + nu) * (1.0 - 2.0 * nu))
    mu = E / (2.0 * (1.0 + nu))

    p = mesh.p              # (3, n_nodes) coords
    t = mesh.t              # (4, n_elems) tet node ids
    n_elems = t.shape[1]

    # P1 shape-function gradients are constant over each tet; compute
    # them via the inverse Jacobian. Reference-simplex gradients:
    # N0=(-1,-1,-1), N1=(1,0,0), N2=(0,1,0), N3=(0,0,1).
    grad_ref = np.array([[-1.0, -1.0, -1.0],
                         [1.0, 0.0, 0.0],
                         [0.0, 1.0, 0.0],
                         [0.0, 0.0, 1.0]])    # (4,3)

    sigma_vm = np.empty(n_elems)
    for e in range(n_elems):
        nodes = t[:, e]
        x = p[:, nodes]            # (3, 4)
        J = np.column_stack([x[:, 1] - x[:, 0],
                             x[:, 2] - x[:, 0],
                             x[:, 3] - x[:, 0]])  # (3,3)
        Jinv = np.linalg.inv(J)
        grad_phys = grad_ref @ Jinv               # (4,3)
        u_e = u[:, nodes]                          # (3, 4)
        grad_u = u_e @ grad_phys                   # (3, 3)
        eps_e = 0.5 * (grad_u + grad_u.T)
        sigma_e = 2.0 * mu * eps_e + lam * np.trace(eps_e) * np.eye(3)
        # von Mises: σ_vm = sqrt(3/2 · s':s'),  s' = s - tr(s)/3 · I
        s_dev = sigma_e - (np.trace(sigma_e) / 3.0) * np.eye(3)
        sigma_vm[e] = math.sqrt(1.5 * np.tensordot(s_dev, s_dev))
    return float(np.max(sigma_vm))
