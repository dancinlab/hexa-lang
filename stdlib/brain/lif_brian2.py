# lif_brian2.py — ①b brain adapter (demiurge design.md D72 2-layer).
#
# THIN adapter over the domain-agnostic ①a LIF kernel
# `stdlib/kernels/neural/lif_kernel.py`. The kernel owns the brian2
# LIF integration + ISI/CV statistics; this adapter owns ONLY the
# brain-domain model — the textbook leaky-integrate-and-fire neuron
# parameter values — and the producer I/O (meta.json / spikes.json /
# the BRAIN_LIF_RESULT stderr line) that demiurge consumes.
#
# SSOT LOCATION (D61 / D17 generalized — hexa-lang owns ALL reusable
# producers; demiurge is a *pointer* consumer): this script lives in
# `~/core/hexa-lang/stdlib/brain/`. demiurge's BrainAnalyzeProducer.swift
# spawns it BY ABSOLUTE PATH but never copies it. cockpit/scripts/*.py
# is FORBIDDEN by AGENTS.tape `g_demiurge_pointer_only`. The D72
# restructure keeps this script at the same path/name, so the Swift
# Producer needs NO change.
#
# Invoked by demiurge Swift's BrainAnalyzeProducer via:
#   /usr/bin/python3 ~/core/hexa-lang/stdlib/brain/lif_brian2.py <output_dir>
#
# 2-layer (ABSORPTION.md ①):
#   ①a kernel  — `stdlib/kernels/neural/lif_kernel.py`. Domain-agnostic
#                LIF integration. brian2 is an EXTERNAL library; the
#                kernel is a `.py` SUBSTRATE — a hexa-native LIF
#                integrator is the future porting target (g3 /
#                hexa-first principle). When it lands, absorbed=true
#                flips in the kernel — once.
#   ①b adapter — THIS FILE. Owns the textbook neuron parameters +
#                producer I/O.
#
# What it does (HONEST scope — single, well-known textbook model):
#   1. Simulates ONE leaky integrate-and-fire (LIF) neuron with constant
#      DC drive for 1 second of biological time, via the ①a LIF kernel
#      (brian2 2.6.0 as the IEEE-754 integrator).
#         tau_m = 10 ms
#         dv/dt = (I - v) / tau     (dimensionless, v_thr = 1, v_reset = 0)
#         I = 2.0  (well above threshold -> tonic firing ~140 Hz)
#         method = 'exact' (analytic for linear ODE — no integration error)
#   2. Counts spikes via brian2's SpikeMonitor. Headline measurement =
#      firing_rate_hz = spike_count / sim_time_s.
#   3. Computes mean ISI (inter-spike interval, seconds) and the CV of
#      ISI (coefficient of variation — exactly 0 for deterministic tonic
#      firing; surfaced as a sanity gate).
#   4. Emits one meta.json with measurements + brian2 version + the
#      equation hash so downstream sweeps can spot drift.
#
# HONESTY (g3 — non-negotiable):
#   • producer = "brian2@<version>" — the SIMULATOR is the instrument.
#     The MODEL is a textbook LIF, NOT a measured neuron — there is no
#     patch-clamp data fit, no Allen Brain Atlas absorption, no compartment
#     model. measurement_gate stays GATE_OPEN ALWAYS for this producer.
#   • absorbed = false — ALWAYS. The numbers are real (brian2's solver
#     output) but the model is plausible-not-fitted. Same BANNED-absorbed
#     stance as sscb/ngspice (D55) and yosys chip-synth (rfc_006 §5).
#   • This is ALGORITHM VERIFICATION (does brian2's LIF integrator
#     produce the textbook firing rate for the textbook drive?), NOT a
#     measurement of any biological brain signal. domains/brain.md §2
#     proprietary gap (Sim4Life MDDT) is untouched.

import json
import os
import sys

# --- Locate the ①a LIF kernel relative to this adapter's own file
# (stdlib/brain/ -> stdlib/kernels/neural/). The Swift spawn sets an
# arbitrary cwd, so a path relative to __file__ is the only robust
# anchor — same convention as stdlib/grid/networkx_basics.py.
_KERNEL_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "kernels", "neural")
if _KERNEL_DIR not in sys.path:
    sys.path.insert(0, _KERNEL_DIR)


GEOMETRY_ID = "lif_brian2_v1"

# Physical / model parameters (NOT pulled from any experimental dataset).
TAU_MS = 10.0          # ms — membrane time constant (Dayan & Abbott textbook)
V_THR = 1.0            # — dimensionless threshold
V_RESET = 0.0          # — dimensionless reset
I_DRIVE = 2.0          # — constant DC drive (2× threshold → tonic firing)
SIM_TIME_S = 1.0       # s — simulation window
METHOD = "exact"       # brian2 integrator — analytic for linear ODE

# The equation string (kept verbatim so we can hash it for drift detection).
EQS = """\
dv/dt = (I - v) / tau : 1
I : 1
"""


def main(argv: list) -> int:
    # Import the ①a kernel — honest gap if the kernel module is missing.
    try:
        import lif_kernel as kernel
    except Exception as exc:
        sys.stderr.write(
            f"lif_brian2: ①a LIF kernel import failed — {exc}. "
            "Expected at stdlib/kernels/neural/lif_kernel.py (g3 — "
            "structural gap, not an engine gap).\n")
        return 4

    if len(argv) < 2:
        sys.stderr.write("usage: lif_brian2.py <output_dir>\n")
        return 2
    output_dir = argv[1]
    os.makedirs(output_dir, exist_ok=True)

    meta_path = os.path.join(output_dir, f"{GEOMETRY_ID}.meta.json")
    spikes_path = os.path.join(output_dir, f"{GEOMETRY_ID}.spikes.json")

    eq_hash = kernel.equation_hash(
        EQS, TAU_MS, V_THR, V_RESET, I_DRIVE, SIM_TIME_S, METHOD)
    version = kernel.brian2_version()
    sys.stderr.write(f"lif_brian2: brian2={version} eq_sha={eq_hash}\n")

    # --- Delegate ALL LIF integration to the ①a kernel.
    result = kernel.simulate_lif(
        EQS, TAU_MS, V_THR, V_RESET, I_DRIVE, SIM_TIME_S, METHOD,
        spike_truncate=200)
    ok = bool(result.get("ok"))

    meta = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "equation_sha256_16": eq_hash,
        "brian2_version": version,
        "model": {
            "kind": "leaky_integrate_and_fire",
            "tau_ms": TAU_MS,
            "v_threshold": V_THR,
            "v_reset": V_RESET,
            "i_drive": I_DRIVE,
            "sim_time_s": SIM_TIME_S,
            "integrator_method": METHOD,
            "equation": EQS.strip(),
        },
        "measurements": result.get("measurements"),
        "error": result.get("error"),
        "artifacts": {
            "meta": f"{GEOMETRY_ID}.meta.json",
            "spikes": f"{GEOMETRY_ID}.spikes.json",
        },
    }

    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    # Persist truncated spike-train so the record is reproducible-ish
    # (full reproducibility comes from equation_sha256_16 + version).
    spikes_payload = {
        "geometry_id": GEOMETRY_ID,
        "spike_times_s": result.get("spike_times_s") or [],
        "truncated_at": 200,
    }
    with open(spikes_path, "w", encoding="utf-8") as f:
        json.dump(spikes_payload, f, indent=2, sort_keys=True)
        f.write("\n")

    meas = result.get("measurements") or {}
    sys.stderr.write(
        f"lif_brian2: wrote {meta_path} (ok={ok}, "
        f"spikes={meas.get('spike_count')}, "
        f"rate_hz={meas.get('firing_rate_hz')})\n")

    summary = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "equation_sha256_16": eq_hash,
        "brian2_version": version,
        "spike_count": meas.get("spike_count"),
        "firing_rate_hz": meas.get("firing_rate_hz"),
        "mean_isi_s": meas.get("mean_isi_s"),
        "cv_isi": meas.get("cv_isi"),
        "artifacts": meta["artifacts"],
        "error": result.get("error"),
    }
    sys.stderr.write("BRAIN_LIF_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    return 0 if ok else 5


if __name__ == "__main__":
    sys.exit(main(sys.argv))
