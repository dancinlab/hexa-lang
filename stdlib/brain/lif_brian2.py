# lif_brian2.py — single LIF spike-rate producer for `brain + analyze`
# (demiurge κ-40 / D62 cohort producer, D61 hexa-lang stdlib SSOT).
#
# SSOT LOCATION (D61 / D17 generalized — hexa-lang owns ALL reusable
# producers; demiurge is a *pointer* consumer): this script lives in
# `~/core/hexa-lang/stdlib/brain/`. demiurge's BrainAnalyzeProducer.swift
# spawns it but never copies it. cockpit/scripts/*.py is FORBIDDEN by
# AGENTS.tape `g_demiurge_pointer_only` — only the demiurge worktree
# would violate ownership by carrying its own copy.
#
# Invoked by demiurge Swift's BrainAnalyzeProducer via:
#   /usr/bin/python3 ~/core/hexa-lang/stdlib/brain/lif_brian2.py <output_dir>
#
# What it does (HONEST scope — single, well-known textbook model):
#   1. Simulates ONE leaky integrate-and-fire (LIF) neuron with constant
#      DC drive for 1 second of biological time, using brian2 2.6.0 as
#      the IEEE-754 integrator.
#         tau_m = 10 ms
#         dv/dt = (I - v) / tau     (dimensionless, v_thr = 1, v_reset = 0)
#         I = 2.0  (well above threshold → tonic firing ~140 Hz)
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

import hashlib
import json
import os
import subprocess
import sys


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


def equation_hash() -> str:
    """SHA-256 of the equation + parameter tuple (truncated 16 hex)."""
    blob = (EQS
            + f"|tau_ms={TAU_MS}"
            + f"|v_thr={V_THR}"
            + f"|v_reset={V_RESET}"
            + f"|I={I_DRIVE}"
            + f"|sim_s={SIM_TIME_S}"
            + f"|method={METHOD}")
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()[:16]


def brian2_version_safe() -> str:
    try:
        import brian2
        return getattr(brian2, "__version__", "unknown")
    except Exception:
        return "unavailable"


def run_lif(output_dir: str) -> dict:
    """Run the LIF simulation and return the measurements dict + raw
    spike-time list (truncated). Honest g3: brian2 IS the instrument,
    and the values are real numerical outputs of the integrator — but
    the *model* is textbook, not fitted to any neuron.
    """
    try:
        import brian2 as b2
    except ImportError as exc:
        return {
            "ok": False,
            "error": f"brian2_import: {exc}",
            "measurements": None,
            "spike_times_s": None,
        }

    b2.start_scope()
    tau = TAU_MS * b2.ms
    G = b2.NeuronGroup(1, EQS, threshold=f"v > {V_THR}",
                       reset=f"v = {V_RESET}", method=METHOD,
                       namespace={"tau": tau})
    G.I = I_DRIVE
    spikes = b2.SpikeMonitor(G)

    try:
        b2.run(SIM_TIME_S * b2.second)
    except Exception as exc:
        return {
            "ok": False,
            "error": f"brian2_run: {exc}",
            "measurements": None,
            "spike_times_s": None,
        }

    n = int(spikes.num_spikes)
    times = [float(t / b2.second) for t in spikes.t]

    # Mean ISI + CV of ISI. Tonic constant-drive LIF → CV ≈ 0
    # (deterministic). Surfaced as a sanity gate downstream.
    mean_isi = None
    cv_isi = None
    if len(times) >= 2:
        isis = [times[i + 1] - times[i] for i in range(len(times) - 1)]
        mean_isi = sum(isis) / len(isis)
        if mean_isi > 0:
            var = sum((x - mean_isi) ** 2 for x in isis) / len(isis)
            cv_isi = (var ** 0.5) / mean_isi

    return {
        "ok": (n > 0),
        "error": None,
        "measurements": {
            "spike_count": n,
            "sim_time_s": SIM_TIME_S,
            "firing_rate_hz": n / SIM_TIME_S,
            "mean_isi_s": mean_isi,
            "cv_isi": cv_isi,
            "first_spike_s": times[0] if times else None,
            "last_spike_s": times[-1] if times else None,
        },
        # Truncate at 200 to keep meta.json bounded; firing_rate is
        # the headline so the full vector is not needed for the record.
        "spike_times_s": times[:200],
    }


def main(argv: list) -> int:
    if len(argv) < 2:
        sys.stderr.write("usage: lif_brian2.py <output_dir>\n")
        return 2
    output_dir = argv[1]
    os.makedirs(output_dir, exist_ok=True)

    meta_path = os.path.join(output_dir, f"{GEOMETRY_ID}.meta.json")
    spikes_path = os.path.join(output_dir, f"{GEOMETRY_ID}.spikes.json")

    eq_hash = equation_hash()
    version = brian2_version_safe()
    sys.stderr.write(f"lif_brian2: brian2={version} eq_sha={eq_hash}\n")

    result = run_lif(output_dir)
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
