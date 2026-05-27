# urdf_kernel.py — ①a STDLIB kernel layer (demiurge design.md D72)
#
# Domain-agnostic URDF parsing + kinematic-tree computation kernel.
# Extracted under the D72 2-layer STDLIB restructure: any producer in
# `stdlib/<domain>/` that reduces a URDF document to spec-level
# topology facts calls into this single module instead of
# re-implementing the yourdfpy wrapping.
#
# Layer split (ABSORPTION.md ①):
#   ①a kernel  — THIS FILE. Domain-independent. No specific robot, no
#                arm geometry — only "given a URDF file path, parse it
#                and reduce the kinematic tree to deterministic facts".
#   ①b adapter — `stdlib/bot/urdfpy_basics.py` (the 2-link arm URDF
#                XML / robot-name / honesty caveats), and any future
#                robotics-domain adapter. They own the URDF document
#                + caveats and call this kernel for the parse + math.
#
# HONESTY (g3 — non-negotiable, inherited by every caller):
#   * Every value computed here IS a real measurement of the URDF
#     spec — yourdfpy parses the XML and trimesh computes the visual
#     bounds; both are deterministic IEEE-754 outputs. BUT this is
#     *URDF spec metadata*, NOT a real robot platform. The honesty
#     gate (measurement_gate, scope_caveats, the spec-vs-platform
#     distinction) lives in the ①b adapter, NOT here.
#   * absorbed = false ALWAYS at the record layer — yourdfpy is an
#     EXTERNAL Python library, not absorbed into hexa-lang. The day a
#     hexa-native URDF parser re-extracts this topology, absorbed
#     flips — and it flips HERE (one kernel) rather than in N domain
#     adapters.
#   * Import failure / parse failure is raised, not swallowed —
#     silent success is forbidden. The caller reports it verbatim.

import hashlib
from typing import Any


def yourdfpy_version() -> str:
    """Probe the installed yourdfpy version string. Returns 'missing'
    if the library cannot be imported — the caller decides whether
    that is a hard gap (it is, for URDF producers)."""
    try:
        import yourdfpy
        return getattr(yourdfpy, "__version__", "unknown")
    except Exception:
        return "missing"


def urdf_sha256_16(urdf_text: str) -> str:
    """Hash a URDF document so cross-host drift is visible — same
    hash <-> byte-identical URDF."""
    return hashlib.sha256(urdf_text.encode("utf-8")).hexdigest()[:16]


def joint_breakdown(robot) -> dict:
    """Count joints by URDF joint type (revolute / fixed / prismatic /
    continuous / floating / planar). Missing types report 0."""
    out = {"revolute": 0, "fixed": 0, "prismatic": 0,
           "continuous": 0, "floating": 0, "planar": 0}
    for j in robot.joints:
        t = (j.type or "").lower()
        out[t] = out.get(t, 0) + 1
    return out


def kinematic_metrics(urdf_path: str) -> dict:
    """Load a URDF with yourdfpy and extract spec-level topology
    facts: link / joint counts, joint-type breakdown, DOF (actuated
    joints), total mass (sum of <inertial><mass>), base link, and the
    zero-cfg visual-scene bounding box.

    Returns a dict with the kinematic facts. On yourdfpy import
    failure or URDF.load failure, returns the `empty` skeleton so the
    ①b adapter can report an honest gap.

    Raised exceptions are confined to within-function and converted to
    the empty skeleton + stderr note (g3 — the caller still sees a
    non-ok result, never a silent success).
    """
    import sys
    empty = {
        "link_count": 0,
        "joint_count": 0,
        "joint_types": {},
        "dof": 0,
        "actuated_joint_names": [],
        "total_mass_kg": None,
        "base_link": None,
        "bbox_min_m": None,
        "bbox_max_m": None,
        "bbox_size_m": None,
    }
    try:
        import yourdfpy
    except Exception as exc:
        sys.stderr.write(f"urdf_kernel: yourdfpy import failed — {exc}\n")
        return empty

    try:
        u = yourdfpy.URDF.load(
            urdf_path,
            load_meshes=False,
            build_collision_scene_graph=False)
    except Exception as exc:
        sys.stderr.write(f"urdf_kernel: URDF.load failed — {exc}\n")
        return empty

    robot = u.robot
    types = joint_breakdown(robot)
    total_mass = 0.0
    have_mass = False
    for link in robot.links:
        inertial = getattr(link, "inertial", None)
        if inertial is not None and getattr(inertial, "mass", None) is not None:
            total_mass += float(inertial.mass)
            have_mass = True

    bbox_min = bbox_max = bbox_size = None
    try:
        u.update_cfg(u.zero_cfg)
        bounds = u.scene.bounds  # 2x3 numpy array (min, max)
        if bounds is not None:
            bbox_min = [float(x) for x in bounds[0]]
            bbox_max = [float(x) for x in bounds[1]]
            bbox_size = [bbox_max[i] - bbox_min[i] for i in range(3)]
    except Exception as exc:
        sys.stderr.write(f"urdf_kernel: scene.bounds skipped — {exc}\n")

    return {
        "link_count": len(robot.links),
        "joint_count": len(robot.joints),
        "joint_types": types,
        "dof": int(u.num_dofs),
        "actuated_joint_names": list(u.actuated_joint_names),
        "total_mass_kg": total_mass if have_mass else None,
        "base_link": u.base_link,
        "bbox_min_m": bbox_min,
        "bbox_max_m": bbox_max,
        "bbox_size_m": bbox_size,
    }
