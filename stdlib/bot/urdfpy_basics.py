# urdfpy_basics.py — ①b domain adapter (demiurge design.md D72)
# yourdfpy URDF-meta producer for `bot + structure`.
#
# D72 2-layer restructure: this file is now a THIN domain adapter.
# It owns ONLY the domain-specific URDF document (the hermetic 2-link
# revolute-arm XML) and the domain honesty caveats. All URDF parsing
# + kinematic-tree math is delegated to the shared ①a kernel
# `kernels/urdf/urdf_kernel.py`.
#
# SSOT location: `~/core/hexa-lang/stdlib/bot/urdfpy_basics.py` (D61 —
# producer scripts live under hexa-lang/stdlib/<domain>/).
#
# Invoked by Swift's BotStructureProducer via:
#   python3 ~/core/hexa-lang/stdlib/bot/urdfpy_basics.py <output_dir>
#
# What it does (honest scope):
#   1. Writes a hermetic 2-link revolute-arm URDF to <output_dir>/
#      simple_arm_v1.urdf — kept inline (no external mesh deps, no
#      `git clone` at runtime) so the producer is reproducible on any
#      host where yourdfpy installs cleanly. — this URDF is the ①b
#      domain knowledge.
#   2. Delegates the URDF parse + kinematic-tree extraction (link /
#      joint counts by type, DOF, total mass, visual bbox) to the ①a
#      kernel `urdf_kernel.kinematic_metrics`. The kernel uses
#      yourdfpy v0.0.60 (the maintained successor to the deprecated
#      urdfpy — see inbox note).
#   3. Emits simple_arm_v1.meta.json with the measurements + URDF
#      sha256 so downstream record cross-checks drift.
#
# HONESTY (g3 — non-negotiable, domain caveats stay HERE):
#   • The numbers are real measurements of the URDF spec — the ①a
#     kernel's yourdfpy parse + trimesh bounds are deterministic
#     IEEE-754 outputs. BUT this is *URDF spec metadata*, NOT a real
#     robot platform. No actuator dynamics, no controller, no
#     payload, no contact, no Gazebo regression, no Drake
#     verification. measurement_gate stays GATE_OPEN and absorbed =
#     false ALWAYS.
#   • The URDF is a self-generated plausible 2-link arm, NOT pulled
#     from a manufacturer datasheet (no UR5/Franka mass-matrix
#     oracle). That gap is the honest scope, mirrored in scope_caveats.
#   • absorbed = false ALWAYS — yourdfpy is EXTERNAL. The day a
#     hexa-native URDF parser re-extracts this topology, absorbed
#     flips in the ①a kernel — not in this adapter.

import json
import os
import sys

# --- Locate the ①a URDF kernel relative to this adapter's own file
# (stdlib/bot/ -> stdlib/kernels/urdf/). The Swift spawn sets an
# arbitrary cwd, so a path relative to __file__ is the only robust
# anchor.
_KERNEL_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "kernels", "urdf")
if _KERNEL_DIR not in sys.path:
    sys.path.insert(0, _KERNEL_DIR)


# --- URDF template (hermetic 2-link revolute arm, no external meshes)
# --- this is the ①b domain knowledge.
GEOMETRY_ID = "simple_arm_v1"

URDF_XML = """<?xml version="1.0"?>
<robot name="simple_arm_v1">
  <link name="base_link">
    <inertial>
      <origin xyz="0 0 0.05" rpy="0 0 0"/>
      <mass value="2.0"/>
      <inertia ixx="0.01" ixy="0" ixz="0" iyy="0.01" iyz="0" izz="0.01"/>
    </inertial>
    <visual>
      <origin xyz="0 0 0.05" rpy="0 0 0"/>
      <geometry><box size="0.2 0.2 0.1"/></geometry>
    </visual>
  </link>

  <link name="link_1">
    <inertial>
      <origin xyz="0 0 0.15" rpy="0 0 0"/>
      <mass value="1.0"/>
      <inertia ixx="0.0083" ixy="0" ixz="0" iyy="0.0083" iyz="0" izz="0.0001"/>
    </inertial>
    <visual>
      <origin xyz="0 0 0.15" rpy="0 0 0"/>
      <geometry><cylinder length="0.3" radius="0.03"/></geometry>
    </visual>
  </link>

  <link name="link_2">
    <inertial>
      <origin xyz="0 0 0.125" rpy="0 0 0"/>
      <mass value="0.5"/>
      <inertia ixx="0.0042" ixy="0" ixz="0" iyy="0.0042" iyz="0" izz="0.00005"/>
    </inertial>
    <visual>
      <origin xyz="0 0 0.125" rpy="0 0 0"/>
      <geometry><cylinder length="0.25" radius="0.02"/></geometry>
    </visual>
  </link>

  <link name="ee_link">
    <inertial>
      <origin xyz="0 0 0.025" rpy="0 0 0"/>
      <mass value="0.1"/>
      <inertia ixx="0.00001" ixy="0" ixz="0" iyy="0.00001" iyz="0" izz="0.00001"/>
    </inertial>
    <visual>
      <origin xyz="0 0 0.025" rpy="0 0 0"/>
      <geometry><box size="0.05 0.05 0.05"/></geometry>
    </visual>
  </link>

  <joint name="joint_1" type="revolute">
    <parent link="base_link"/>
    <child link="link_1"/>
    <origin xyz="0 0 0.1" rpy="0 0 0"/>
    <axis xyz="0 0 1"/>
    <limit lower="-3.14159" upper="3.14159" effort="100" velocity="1.5"/>
  </joint>

  <joint name="joint_2" type="revolute">
    <parent link="link_1"/>
    <child link="link_2"/>
    <origin xyz="0 0 0.3" rpy="0 0 0"/>
    <axis xyz="0 1 0"/>
    <limit lower="-1.57" upper="1.57" effort="50" velocity="2.0"/>
  </joint>

  <joint name="joint_ee" type="fixed">
    <parent link="link_2"/>
    <child link="ee_link"/>
    <origin xyz="0 0 0.25" rpy="0 0 0"/>
  </joint>
</robot>
"""


def write_urdf(path: str) -> str:
    """Write the URDF and return its SHA-256 hex digest (truncated).
    The hash is delegated to the ①a kernel so the algorithm is shared."""
    import urdf_kernel as kernel
    with open(path, "w", encoding="utf-8") as f:
        f.write(URDF_XML)
    return kernel.urdf_sha256_16(URDF_XML)


def main(argv: list) -> int:
    if len(argv) < 2:
        sys.stderr.write("usage: urdfpy_basics.py <output_dir>\n")
        return 2
    output_dir = argv[1]
    os.makedirs(output_dir, exist_ok=True)

    urdf_path = os.path.join(output_dir, f"{GEOMETRY_ID}.urdf")
    meta_path = os.path.join(output_dir, f"{GEOMETRY_ID}.meta.json")

    # Import the ①a kernel — honest gap if the kernel module is missing.
    try:
        import urdf_kernel as kernel
    except ImportError as exc:
        sys.stderr.write(
            f"urdfpy_basics: ①a URDF kernel import failed — {exc}. "
            "Expected at stdlib/kernels/urdf/urdf_kernel.py (g3 — "
            "silent success forbidden).\n")
        summary = {"ok": False, "geometry_id": GEOMETRY_ID,
                   "error": "urdf_kernel_import_failed"}
        sys.stderr.write("BOT_URDF_RESULT "
                         + json.dumps(summary, sort_keys=True) + "\n")
        return 3

    urdf_hash = write_urdf(urdf_path)
    sys.stderr.write(f"bot_urdf: wrote {urdf_path} (sha256:{urdf_hash})\n")

    version = kernel.yourdfpy_version()
    if version == "missing":
        summary = {"ok": False, "geometry_id": GEOMETRY_ID,
                   "error": "yourdfpy_not_installed",
                   "urdf_sha256_16": urdf_hash}
        sys.stderr.write("BOT_URDF_RESULT "
                         + json.dumps(summary, sort_keys=True) + "\n")
        return 3

    # --- Delegate ALL URDF parse + kinematic-tree math to the ①a kernel.
    meas = kernel.kinematic_metrics(urdf_path)
    ok = (meas["link_count"] > 0
          and meas["joint_count"] > 0
          and meas["dof"] >= 0
          and meas["total_mass_kg"] is not None
          and meas["bbox_size_m"] is not None)

    meta = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "urdf_sha256_16": urdf_hash,
        "yourdfpy_version": version,
        "topology": {
            "robot_name": "simple_arm_v1",
            "kind": "2_link_revolute_arm",
            "source": "self_generated_hermetic",
        },
        "measurements": meas,
        "artifacts": {
            "urdf": f"{GEOMETRY_ID}.urdf",
        },
    }

    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(f"bot_urdf: wrote {meta_path} (ok={ok}, "
                     f"links={meas['link_count']}, joints={meas['joint_count']}, "
                     f"dof={meas['dof']})\n")

    artifacts_with_meta = dict(meta["artifacts"])
    artifacts_with_meta["meta"] = f"{GEOMETRY_ID}.meta.json"
    summary = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "urdf_sha256_16": urdf_hash,
        "yourdfpy_version": version,
        "link_count": meas["link_count"],
        "joint_count": meas["joint_count"],
        "dof": meas["dof"],
        "total_mass_kg": meas["total_mass_kg"],
        "bbox_size_m": meas["bbox_size_m"],
        "artifacts": artifacts_with_meta,
    }
    sys.stderr.write("BOT_URDF_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    return 0 if ok else 5


if __name__ == "__main__":
    sys.exit(main(sys.argv))
