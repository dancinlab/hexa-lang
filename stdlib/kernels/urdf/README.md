# kernels/urdf/ — ①a URDF kinematic-tree kernel (demiurge design.md D72)

Domain-agnostic URDF parsing + kinematic-tree computation kernel.
Extracted under the D72 2-layer STDLIB restructure alongside the
aura/bot/energy domain recovery.

| file | role |
|---|---|
| `urdf_kernel.py` | `kinematic_metrics(urdf_path)` · `joint_breakdown` · `urdf_sha256_16` · `yourdfpy_version` — given any URDF file, parse it and reduce the kinematic tree to deterministic facts (link / joint counts, DOF, mass, bbox). |
| `fk_2link_kernel.hexa` | D80 g_hexa_only pilot #3 — clean-room hexa-native 2-link planar revolute-arm forward kinematics (closed form + SE(3) 4×4 transform). Substrate parity vs numpy 2.0.x at machine epsilon (≤ 1e-15 absolute / ≤ 1.5e-16 relative on the one operation-order-sensitive SE(3) translation channel) across 5 joint configurations (test below). Heavier substrates (general-tree URDF walk in hexa-native) still live in `urdf_kernel.py` / yourdfpy until follow-on ports land. |
| `fk_2link_kernel_test.hexa` | Substrate parity check for `fk_2link_kernel.hexa` — 28 assertions across 5 joint configurations spanning zero / 90° / fold / right-angle / asymmetric. Run: `hexa run stdlib/kernels/urdf/fk_2link_kernel_test.hexa`. |

## 2-layer (ABSORPTION.md ①)

- **①a kernel** (here) — domain-independent. No specific robot, no
  arm geometry. Pure "URDF in -> kinematic facts out".
- **①b adapter** — `stdlib/bot/urdfpy_basics.py`. It owns the 2-link
  arm URDF XML document / robot name / honesty caveats and calls
  this kernel for the parse + tree math.

## Why

`bot + structure` re-implemented yourdfpy wrapping inline. Extracting
the shared kernel means any future robotics domain (mobile base,
manipulator, humanoid) shares 1 kernel (N×M -> N+M). The day a
hexa-native URDF parser lands, `absorbed=true` flips HERE — once —
instead of in every domain adapter.

## Callers

- `stdlib/bot/urdfpy_basics.py` — hermetic 2-link revolute-arm URDF

Adapters locate this kernel by path relative to their own file
(`../kernels/urdf/`), so the `python3 <script> <output_dir>` spawn
from demiurge works regardless of cwd.
