# lif_kernel.py — ①a STDLIB kernel layer (demiurge design.md D72)
#
# Domain-agnostic leaky-integrate-and-fire (LIF) neuron-simulation
# kernel. Extracted under the D72 2-layer STDLIB restructure — the
# kernel mirror of `kernels/graph/networkx_kernel.py`,
# `kernels/mc_transport/transport_kernel.py`, `kernels/fem/`,
# `kernels/circuit/`. Producers in `stdlib/<domain>/` that need a LIF
# spike-train call into this single module instead of re-implementing
# the brian2 wrapping + ISI/CV statistics.
#
# Layer split (ABSORPTION.md ①):
#   ①a kernel  — THIS FILE. Domain-independent. No textbook neuron
#                parameter values, no GEOMETRY_ID, no meta.json schema
#                — only "given an LIF parameter set, integrate it with
#                brian2 and return the deterministic spike statistics".
#   ①b adapter — `stdlib/brain/lif_brian2.py`. Owns the textbook
#                neuron parameter values (tau_m, v_thr, drive), the
#                producer I/O (meta.json / spikes.json), the
#                GEOMETRY_ID, and the honesty caveats. The Swift
#                BrainAnalyzeProducer spawns the ADAPTER, never this
#                kernel.
#
# HEXA-NATIVE PORTING (g3 / wilson principle #2 hexa-first — explicit):
#   This kernel is a `.py` SUBSTRATE. brian2 is an EXTERNAL Python
#   library — it is NOT hexa-native. Per the first principle
#   (hexa-first), a hexa-native re-derivation of the LIF integrator
#   (a single linear ODE, dv/dt = (I-v)/tau, with an analytic exact
#   solution per timestep) is the FUTURE PORTING TARGET. When that
#   hexa-native kernel lands and passes a parity round against this
#   brian2 substrate, `absorbed=true` flips HERE — once — in the
#   kernel, not in the brain adapter. Until then this `.py` kernel is
#   the honest substrate. See the brain adapter README + inbox note.
#
# HONESTY (g3 — non-negotiable, inherited by every caller):
#   * The SIMULATOR (brian2) is the instrument. The values returned
#     here are real numerical outputs of its integrator.
#   * The kernel takes ANY LIF parameter set — it does not assert the
#     parameters describe a real neuron. The honesty gate (the model
#     is textbook-not-fitted, measurement_gate = GATE_OPEN,
#     absorbed = false) lives on the *domain interpretation* and stays
#     in the ①b adapter, NOT here.
#   * Import failure is reported verbatim (the kernel returns an error
#     dict rather than raising) so the caller can surface an honest
#     engine-tool gap.

import hashlib


def brian2_version() -> str:
    """Probe the installed brian2 version. Returns 'unavailable' if the
    library cannot be imported — the caller decides whether that is a
    hard gap (it is, for LIF producers)."""
    try:
        import brian2
        return getattr(brian2, "__version__", "unknown")
    except Exception:
        return "unavailable"


def equation_hash(eqs: str, tau_ms: float, v_thr: float, v_reset: float,
                  i_drive: float, sim_time_s: float, method: str) -> str:
    """SHA-256 of the equation string + parameter tuple (truncated to
    16 hex). Same digest <-> byte-identical model, so downstream
    sweeps can spot drift across hosts / versions."""
    blob = (eqs
            + f"|tau_ms={tau_ms}"
            + f"|v_thr={v_thr}"
            + f"|v_reset={v_reset}"
            + f"|I={i_drive}"
            + f"|sim_s={sim_time_s}"
            + f"|method={method}")
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()[:16]


def simulate_lif(eqs: str, tau_ms: float, v_thr: float, v_reset: float,
                 i_drive: float, sim_time_s: float, method: str,
                 spike_truncate: int = 200) -> dict:
    """Integrate ONE leaky-integrate-and-fire neuron with constant DC
    drive using brian2 and return the deterministic spike statistics.

    Domain-agnostic: the caller supplies every parameter — this kernel
    asserts nothing about whether the parameters describe a real
    neuron (that caveat belongs to the ①b adapter).

    Returns a flat dict:
      ok            — bool, True iff brian2 ran AND produced >=1 spike
      error         — None, or a verbatim import/run failure string
      measurements  — None on failure, else a dict with spike_count,
                      sim_time_s, firing_rate_hz, mean_isi_s, cv_isi,
                      first_spike_s, last_spike_s
      spike_times_s — None on failure, else the spike-time list
                      truncated at `spike_truncate`
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
    tau = tau_ms * b2.ms
    G = b2.NeuronGroup(1, eqs, threshold=f"v > {v_thr}",
                       reset=f"v = {v_reset}", method=method,
                       namespace={"tau": tau})
    G.I = i_drive
    spikes = b2.SpikeMonitor(G)

    try:
        b2.run(sim_time_s * b2.second)
    except Exception as exc:
        return {
            "ok": False,
            "error": f"brian2_run: {exc}",
            "measurements": None,
            "spike_times_s": None,
        }

    n = int(spikes.num_spikes)
    times = [float(t / b2.second) for t in spikes.t]

    # Mean ISI + CV of ISI. Tonic constant-drive LIF -> CV ~ 0
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
            "sim_time_s": sim_time_s,
            "firing_rate_hz": n / sim_time_s,
            "mean_isi_s": mean_isi,
            "cv_isi": cv_isi,
            "first_spike_s": times[0] if times else None,
            "last_spike_s": times[-1] if times else None,
        },
        # Truncate to keep the record bounded; firing_rate is the
        # headline so the full vector is not needed for the record.
        "spike_times_s": times[:spike_truncate],
    }
