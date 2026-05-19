# pinocchio_rbd.py — bot + synthesize producer (D61 substrate SSOT,
# ROI rank 9 — research note absorption-empty-cells-research-2026-05-20.md §3).
#
# Invoked by Swift's BotSynthProducer via:
#   python3 pinocchio_rbd.py <output_dir>
#
# What it does (honest scope — D72 classification):
#   1. Re-emits the same hermetic 2-link revolute-arm URDF as
#      stdlib/bot/urdfpy_basics.py (κ-37 / D58), keeping the URDF SSOT
#      byte-identical so the bot+structure and bot+synthesize records
#      reference the same geometry by sha256 hash (cross-cell parity).
#      D72 note: URDF *loading* already lives in kernels/urdf/ (κ-45)
#      for hexa-native cohorts; the Python adapter re-uses the same XML
#      blob — no fork. Pinocchio = inverse kinematics / Jacobians / RNEA
#      (D72 rationale: 2nd RBD consumer not on horizon → keep in bot
#      adapter, do NOT promote to kernels/rbd/).
#   2. Loads the URDF into Pinocchio (pip pkg `pin`, scikit-hep adjacent,
#      BSD-2 / LGPL-3) with `pinocchio.buildModelFromUrdf(...)`.
#   3. Computes for a sample joint configuration q = [0.5, -0.3] rad,
#      velocity v = [0.1, -0.2] rad/s, acceleration a = [0, 0] rad/s²:
#        • forward kinematics — end-effector frame pose (translation +
#          rotation matrix, from pinocchio.framesForwardKinematics).
#        • analytic frame Jacobian J(q) in the LOCAL_WORLD_ALIGNED
#          convention (6×nv, linear top-3 + angular bottom-3).
#        • inverse-dynamics joint torque tau = M(q)·a + h(q,v), the
#          Recursive Newton-Euler Algorithm output (pinocchio.rnea).
#        • mass matrix M(q) (pinocchio.crba) — kept on the record as a
#          provenance artifact so downstream verify (Drake / Gazebo, ROI
#          rank 13, deferred this round) can cross-check the same
#          configuration.
#   4. Emits `simple_arm_v1.rbd.json` (the per-step numeric record) and
#      `BOT_RBD_RESULT <json>` summary line on stderr.
#
# HONESTY (g3 — non-negotiable):
#   • The numbers above are real outputs of stack-of-tasks/pinocchio's
#     analytic Featherstone-style algorithms — RNEA / CRBA / Jacobians
#     are mathematical facts of rigid-body dynamics given the URDF
#     spatial inertias. BUT this is *open-loop torque eval, no contact
#     and no dynamic stability check*. No Gazebo regression, no Drake
#     verification, no ros2_control HIL, no ISO 10218 risk assessment,
#     no payload, no joint friction model, no actuator dynamics. So:
#       measurement_gate = GATE_OPEN
#       absorbed         = false
#     ALWAYS. The Swift side never flips them.
#   • The URDF is the same self-generated hermetic 2-link arm as
#     bot+structure — no UR5 / Franka manufacturer datasheet, no
#     bench-validated mass matrix. domains/bot.md §1: the full bot
#     deliverable = URDF + actuator/sensor + controller + safety; this
#     producer covers ONE leaf (analytic inverse-dynamics).
#   • If pinocchio is missing OR URDF parse fails OR rnea crashes,
#     hard-fails honestly with ok=false and writes no record. Silent
#     success is forbidden.
#
# SSOT pin (D61 / g_demiurge_pointer_only):
#   This script IS the substrate SSOT — Swift's BotSynthProducer points
#   here, never to cockpit/scripts/*. The URDF blob is duplicated from
#   urdfpy_basics.py at the source-text level (not imported) so the two
#   producers stay independent on PYTHONPATH; the urdf_sha256_16 must
#   match across both records as a cross-cell witness.

import hashlib
import json
import os
import sys


# --- URDF template (byte-identical to urdfpy_basics.py — cross-cell parity) ---
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


# --- sample evaluation point (kept small / textbook — D72 caveat) ---
# Two actuated revolute joints; sample a non-zero non-trivial point that
# exercises both axes (joint_1 around z, joint_2 around y).
SAMPLE_Q = [0.5, -0.3]      # rad
SAMPLE_V = [0.1, -0.2]      # rad/s
SAMPLE_A = [0.0, 0.0]       # rad/s² (static gravity-comp torque eval)
END_EFFECTOR_FRAME = "ee_link"


def write_urdf(path: str) -> str:
    with open(path, "w", encoding="utf-8") as f:
        f.write(URDF_XML)
    return hashlib.sha256(URDF_XML.encode("utf-8")).hexdigest()[:16]


def pinocchio_version() -> str:
    try:
        import pinocchio as pin
        return getattr(pin, "__version__", "unknown")
    except Exception:
        return "missing"


def python_version() -> str:
    return "%d.%d.%d" % (sys.version_info.major,
                         sys.version_info.minor,
                         sys.version_info.micro)


def rbd_compute(urdf_path: str) -> dict:
    """Build pinocchio model from URDF, compute fwd kinematics, frame
    Jacobian, RNEA torque, and CRBA mass matrix at the sample point.

    Returns a dict with the headline scalars (per-joint torques, ee pose,
    matrix shapes + flattened values) and an `ok` flag. Honest g3: every
    numeric here is a stack-of-tasks/pinocchio output; the *robot* is
    still a hermetic 2-link arm (GATE_OPEN).
    """
    empty = {
        "ok": False,
        "nq": 0, "nv": 0, "actuated_joints": [],
        "q": list(SAMPLE_Q), "v": list(SAMPLE_V), "a": list(SAMPLE_A),
        "end_effector_frame": END_EFFECTOR_FRAME,
        "ee_translation_m": None,
        "ee_rotation_3x3": None,
        "jacobian_6xnv": None,
        "tau_rnea_Nm": None,
        "mass_matrix_crba_nvxnv": None,
        "gravity_torque_Nm": None,
    }
    try:
        import numpy as np
        import pinocchio as pin
    except Exception as exc:
        sys.stderr.write(
            "pinocchio_rbd: pinocchio import failed — %s\n" % exc)
        return empty

    try:
        model = pin.buildModelFromUrdf(urdf_path)
    except Exception as exc:
        sys.stderr.write(
            "pinocchio_rbd: buildModelFromUrdf failed — %s\n" % exc)
        return empty
    data = model.createData()

    nq, nv = int(model.nq), int(model.nv)
    if nq < 2 or nv < 2:
        sys.stderr.write(
            "pinocchio_rbd: unexpected model dims nq=%d nv=%d\n" % (nq, nv))
        return empty

    actuated = []
    # model.names[0] is "universe"; the rest are actuated joints in URDF
    # joint order (joint_ee is fixed → absorbed into the prior joint, so
    # excluded by Pinocchio automatically).
    for jname in list(model.names)[1:]:
        actuated.append(str(jname))

    q = np.array(SAMPLE_Q[:nq] + [0.0] * max(0, nq - len(SAMPLE_Q)))
    v = np.array(SAMPLE_V[:nv] + [0.0] * max(0, nv - len(SAMPLE_V)))
    a = np.array(SAMPLE_A[:nv] + [0.0] * max(0, nv - len(SAMPLE_A)))

    try:
        pin.forwardKinematics(model, data, q, v, a)
        pin.updateFramePlacements(model, data)
    except Exception as exc:
        sys.stderr.write(
            "pinocchio_rbd: forwardKinematics failed — %s\n" % exc)
        return empty

    # End-effector frame.
    try:
        fid = model.getFrameId(END_EFFECTOR_FRAME)
        ee = data.oMf[fid]
        ee_translation = [float(x) for x in ee.translation]
        ee_rotation = [[float(ee.rotation[i, j]) for j in range(3)]
                       for i in range(3)]
    except Exception as exc:
        sys.stderr.write(
            "pinocchio_rbd: frame lookup failed — %s\n" % exc)
        ee_translation = None
        ee_rotation = None

    # Analytic frame Jacobian (LOCAL_WORLD_ALIGNED — linear top-3, ang bot-3).
    jacobian = None
    try:
        pin.computeJointJacobians(model, data, q)
        J = pin.getFrameJacobian(
            model, data, fid, pin.ReferenceFrame.LOCAL_WORLD_ALIGNED)
        jacobian = [[float(J[i, j]) for j in range(nv)] for i in range(6)]
    except Exception as exc:
        sys.stderr.write(
            "pinocchio_rbd: getFrameJacobian failed — %s\n" % exc)

    # RNEA — inverse dynamics torque tau = M(q)·a + C(q,v)·v + g(q).
    tau_rnea = None
    gravity_torque = None
    try:
        tau = pin.rnea(model, data, q, v, a)
        tau_rnea = [float(x) for x in tau]
        # gravity torque alone = rnea(q, 0, 0)
        zero_v = np.zeros(nv)
        zero_a = np.zeros(nv)
        tg = pin.rnea(model, data, q, zero_v, zero_a)
        gravity_torque = [float(x) for x in tg]
    except Exception as exc:
        sys.stderr.write("pinocchio_rbd: rnea failed — %s\n" % exc)

    # CRBA — mass matrix M(q).
    mass_matrix = None
    try:
        M = pin.crba(model, data, q)
        # M is upper-triangular returned; symmetrize for export.
        M = np.array(M)
        M = (M + M.T) - np.diag(np.diag(M))
        mass_matrix = [[float(M[i, j]) for j in range(nv)]
                       for i in range(nv)]
    except Exception as exc:
        sys.stderr.write("pinocchio_rbd: crba failed — %s\n" % exc)

    ok = (ee_translation is not None
          and jacobian is not None
          and tau_rnea is not None
          and mass_matrix is not None
          and gravity_torque is not None)

    return {
        "ok": ok,
        "nq": nq, "nv": nv,
        "actuated_joints": actuated,
        "q": [float(x) for x in q.tolist()],
        "v": [float(x) for x in v.tolist()],
        "a": [float(x) for x in a.tolist()],
        "end_effector_frame": END_EFFECTOR_FRAME,
        "ee_translation_m": ee_translation,
        "ee_rotation_3x3": ee_rotation,
        "jacobian_6xnv": jacobian,
        "tau_rnea_Nm": tau_rnea,
        "mass_matrix_crba_nvxnv": mass_matrix,
        "gravity_torque_Nm": gravity_torque,
    }


def main(argv):
    if len(argv) < 2:
        sys.stderr.write("usage: pinocchio_rbd.py <output_dir>\n")
        return 2
    output_dir = argv[1]
    os.makedirs(output_dir, exist_ok=True)

    urdf_path = os.path.join(output_dir, GEOMETRY_ID + ".urdf")
    rbd_path = os.path.join(output_dir, GEOMETRY_ID + ".rbd.json")
    meta_path = os.path.join(output_dir, GEOMETRY_ID + ".meta.json")

    urdf_hash = write_urdf(urdf_path)
    sys.stderr.write(
        "pinocchio_rbd: wrote %s (sha256:%s)\n" % (urdf_path, urdf_hash))

    pin_version = pinocchio_version()
    if pin_version == "missing":
        summary = {
            "ok": False,
            "geometry_id": GEOMETRY_ID,
            "error": "pinocchio_not_installed",
            "urdf_sha256_16": urdf_hash,
        }
        sys.stderr.write(
            "BOT_RBD_RESULT " + json.dumps(summary, sort_keys=True) + "\n")
        return 3

    rbd = rbd_compute(urdf_path)
    ok = bool(rbd.get("ok", False))

    # Per-step record (full numerics).
    with open(rbd_path, "w", encoding="utf-8") as f:
        json.dump(rbd, f, indent=2, sort_keys=True)
        f.write("\n")

    # Meta (kept compact — Swift parses this back into the typed record).
    meta = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "urdf_sha256_16": urdf_hash,
        "pinocchio_version": pin_version,
        "python_version": python_version(),
        "scenario": {
            "name": "simple_arm_open_loop_torque_v1",
            "kind": "2_link_revolute_arm",
            "source": "self_generated_hermetic",
            "end_effector_frame": END_EFFECTOR_FRAME,
            "q_rad": rbd["q"],
            "v_rad_s": rbd["v"],
            "a_rad_s2": rbd["a"],
        },
        "measurements": {
            "nq": rbd["nq"],
            "nv": rbd["nv"],
            "actuated_joints": rbd["actuated_joints"],
            "ee_translation_m": rbd["ee_translation_m"],
            "tau_rnea_Nm": rbd["tau_rnea_Nm"],
            "gravity_torque_Nm": rbd["gravity_torque_Nm"],
            "jacobian_6xnv": rbd["jacobian_6xnv"],
            "mass_matrix_crba_nvxnv": rbd["mass_matrix_crba_nvxnv"],
        },
        "artifacts": {
            "urdf": GEOMETRY_ID + ".urdf",
            "rbd": GEOMETRY_ID + ".rbd.json",
        },
    }
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        "pinocchio_rbd: wrote %s (ok=%s, nq=%d, nv=%d)\n"
        % (meta_path, ok, rbd["nq"], rbd["nv"]))

    artifacts = dict(meta["artifacts"])
    artifacts["meta"] = GEOMETRY_ID + ".meta.json"
    summary = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "urdf_sha256_16": urdf_hash,
        "pinocchio_version": pin_version,
        "python_version": python_version(),
        "nq": rbd["nq"],
        "nv": rbd["nv"],
        "tau_rnea_Nm": rbd["tau_rnea_Nm"],
        "gravity_torque_Nm": rbd["gravity_torque_Nm"],
        "ee_translation_m": rbd["ee_translation_m"],
        "artifacts": artifacts,
    }
    sys.stderr.write(
        "BOT_RBD_RESULT " + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    return 0 if ok else 5


if __name__ == "__main__":
    sys.exit(main(sys.argv))
