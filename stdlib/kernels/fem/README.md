# kernels/fem/ — ①a FEM kernel (demiurge design.md D72)

Domain-agnostic finite-element computation kernel. The SECOND kernel
extracted under the D72 2-layer STDLIB restructure (after
`kernels/graph/`).

| file | role |
|---|---|
| `skfem_kernel.py` | `mesh_box` · `mesh_from_step` · `solve_thermal` · `solve_elastic` · `von_mises_max_p1` · `gmsh_version` · `skfem_version` — given a geometry spec + material + boundary conditions, mesh it (gmsh) and solve the PDE (scikit-fem). |

## 2-layer (ABSORPTION.md ①)

- **①a kernel** (here) — domain-independent. No silicon-die box,
  no BIPV stack, no plasma chamber. Pure "geometry + material + BC
  in -> mesh stats + field min/max + solver meta out".
- **①b adapter** — `stdlib/component/gmsh_skfem.py` today (BIPV /
  electronics-package geometry, material constants, load case).
  `rtsc`, `fusion`, `sscb-verify` adapters are slated next per
  `demiurge inbox/notes/kernel-extraction-pickup.md`.

## API

- `mesh_box(out_dir, length_m, width_m, thickness_m, mesh_size_m,
  name)` — uniform-tet mesh of an axis-aligned box. Returns
  `{ mesh, msh_path, gmsh_version, n_nodes, n_elements }`.
- `mesh_from_step(out_dir, step_path, mesh_size_m, name)` — same,
  for an external STEP solid (the path a domain takes when a real
  cited geometry lands).
- `solve_thermal(mesh, conductivity_w_per_mk, body_source_w_per_m3,
  dirichlet_select, dirichlet_value_k)` — steady-state heat
  conduction. Returns `{ t_min_k, t_max_k, t_mean_k, dof_count }`.
- `solve_elastic(mesh, youngs_pa, poissons, body_force,
  dirichlet_select)` — linear elasticity. Returns `{ u_max_m,
  sigma_vm_max_pa, dof_count }`.
- `von_mises_max_p1(mesh, u, youngs_pa, poissons)` — element-wise
  von Mises post-processing on linear tets.

## Why

`component+verify` runs FEM today; `rtsc+analyze`, `fusion+analyze`
and `sscb+verify` are all listed as FEM consumers in demiurge
design.md. Extracting the shared gmsh + scikit-fem kernel means N
domains share 1 kernel (N×M -> N+M). The day a hexa-native FEM
kernel re-solves these PDEs, `absorbed=true` flips HERE — once —
instead of in every domain adapter. The Stage-2 hexa ports already
exist alongside the component adapter (`stdlib/component/
heat_conduction.hexa`, `linear_elasticity.hexa`) — when they reach
parity, this kernel is the switch point.

## Honesty (g3)

Every value is a real IEEE-754-deterministic PDE solution on the
supplied mesh — NOT a measurement of any real part, NOT a model
prediction. Whether the INPUTS are measured or placeholder, and
whether the mesh has been convergence-checked, are domain questions:
the honesty gate (`measurement_gate`, `absorbed`, `scope_caveats`)
lives in the ①b adapter, NOT here. gmsh + scikit-fem are external
libraries, so `absorbed = false` at the record layer always.

## Callers

- `stdlib/component/gmsh_skfem.py` — silicon-die-proxy box,
  thermal + structural verify producer (demiurge `component+verify`).

The adapter locates this kernel by path relative to its own file
(`../kernels/fem/`), so the `python3 <script> <output_dir>` spawn
from demiurge works regardless of cwd.
