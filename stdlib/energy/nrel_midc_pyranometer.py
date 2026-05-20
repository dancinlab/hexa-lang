# nrel_midc_pyranometer.py — STUB measured-oracle producer
# (κ-68 G28b · RFC 013 §6.11 · demiurge design.md D109)
#
# SCOPE — STUB ONLY. Emits a synthetic `measured_oracle` block inside
# an Energy/verify record JSON so the demiurge cockpit's new typed
# field (`MeasuredOracleRef`, demiurge commit `4a1a087`) has an end-to-
# end emit→decode path during κ-68 schema-half land. **This is NOT
# real NREL MIDC data and NOT a hexa-native parity claim.**
#
# Real production path (κ-69+ follow-on scope):
#   1. Fetch real NREL MIDC pyranometer GHI from
#      midc.nrel.gov/apps/data_api.pl (SRRL Golden CO, single clear-
#      sky day, 1-min cadence) per design.md D109.
#   2. Compute modeled GHI: hexa-native sun_position_kernel
#      (stdlib/kernels/solar/solar_kernel.hexa) → pvlib clearsky
#      (Haurwitz / Ineichen) → transposition (Hay-Davies). The
#      pvlib clearsky/transposition stack is the trusted bridge
#      (substrate-parity already proven on pvlib_kernel.py).
#   3. PASS gate: mean relative error |measured - modeled| / |measured|
#      ≤ 0.05 over clear-sky daylight hours (D109 PASS criterion).
#   4. Emit EnergyVerifyRecord JSON with `measured_oracle` block
#      populated; `absorbed` stays false until G29's explicit-writer
#      gate runs (D103 dimension-separation · G28b is schema-half).
#
# HONESTY (g3 — non-negotiable):
#   - STUB: synthetic perturbation ε(t) = 0.02·sin(2π t / 30) drives
#     `mean_rel_err` and `max_rel_err`. No real measurement. The
#     numbers are deterministic and hand-tuned to demonstrate the
#     PASS path (≈0.013 mean rel_err vs 0.05 threshold).
#   - `absorbed = false` ALWAYS — G28b producer wire MUST NOT flip
#     stored absorbed; the explicit-writer path is G29's scope.
#   - `oracle_source` field is loudly labeled "STUB" so a downstream
#     reviewer cannot confuse this with real NREL MIDC data.
#   - `dataset_citation = null` — no real DOI; the real producer
#     fills this when it lands.
#
# Invoked by Swift's EnergyVerifyProducer via:
#   python3 ~/core/hexa-lang/stdlib/energy/nrel_midc_pyranometer.py <output_dir>

import datetime as _dt
import json
import math
import os
import platform
import sys


PRODUCER_ID = "nrel_midc_pyranometer_stub"

# Stub window: 60 1-minute samples centered on solar noon.
SAMPLE_COUNT = 60
# Synthetic perturbation amplitude (drives mean / max rel_err).
PERTURBATION_AMPLITUDE = 0.02
# D109 PASS criterion — must match design.md.
PASS_THRESHOLD = 0.05


def _synthetic_samples():
    """Generate 60 (measured, modeled, rel_err) triples.

    Time axis t ∈ [0, 59] one-per-minute. Modeled GHI uses a single
    cosine bell (peak 1000 W/m² at t=29.5). Measured GHI = modeled ×
    (1 + ε(t)) with ε(t) = AMPLITUDE × sin(2π t / 30) — half-cycle
    over the window so the mean of |ε| is well-defined.
    """
    measured = []
    modeled = []
    rel_errs = []
    for t in range(SAMPLE_COUNT):
        # Modeled (peaked cosine bell — synthetic clearsky stand-in)
        x = (t - 29.5) / 29.5  # normalize to [-1, 1] across window
        m = 1000.0 * max(0.0, math.cos(0.5 * math.pi * x))
        # Measured = modeled × (1 + ε(t))
        eps = PERTURBATION_AMPLITUDE * math.sin(2.0 * math.pi * t / 30.0)
        meas = m * (1.0 + eps)
        # Relative error (safe — modeled never zero on the window)
        if m > 0.0:
            rel = abs(meas - m) / abs(meas)
        else:
            rel = 0.0
        measured.append(meas)
        modeled.append(m)
        rel_errs.append(rel)
    return measured, modeled, rel_errs


def _build_measured_oracle():
    """Compose the `measured_oracle` block per MeasuredOracleRef
    (demiurge commit 4a1a087 · MeasuredOracleRef.swift)."""
    _, _, rel_errs = _synthetic_samples()
    mean_rel_err = sum(rel_errs) / float(len(rel_errs))
    max_rel_err = max(rel_errs)
    return {
        "oracle_source": (
            "STUB · synthetic 60-sample clear-sky · ε(t)=0.02·sin(2π t/30) "
            "· κ-68 G28b schema-half (NOT real NREL MIDC data)"
        ),
        "unit": "W/m^2",
        "sample_count": SAMPLE_COUNT,
        "mean_rel_err": mean_rel_err,
        "max_rel_err": max_rel_err,
        "threshold": PASS_THRESHOLD,
        "dataset_caveats": (
            "STUB producer — synthetic perturbation, no real measurement. "
            "Real path = NREL MIDC SRRL Golden CO pyranometer GHI (κ-69+)."
        ),
        "dataset_citation": None,
    }


def main(argv):
    if len(argv) < 2:
        sys.stderr.write(
            "usage: nrel_midc_pyranometer.py <output_dir>\n")
        return 2

    output_dir = argv[1]
    os.makedirs(output_dir, exist_ok=True)

    measured_oracle = _build_measured_oracle()
    stamp = _dt.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    record = {
        "domain": "energy",
        "verb": "verify",
        "kind": "solar_clearsky_ghi_measured_oracle_stub",
        "stamp": stamp,
        "producer": PRODUCER_ID,
        "measurement_gate": "GATE_OPEN",
        # D103 + D109 — stored absorbed STAYS false. G29 explicit-
        # writer gate has NOT run; this producer is schema-half only.
        "absorbed": False,
        "scope_caveats": [
            "STUB producer — synthetic clear-sky samples, no real "
            "measurement (κ-68 G28b schema-half · real NREL MIDC "
            "fetch is κ-69+).",
            "absorbed stays false (D103 dimension-separation · G29 "
            "explicit-writer gate has not run).",
        ],
        "citations": [
            "demiurge commit 4a1a087 — MeasuredOracleRef.swift schema",
            "demiurge design.md D109 — Energy/solar cell + NREL MIDC "
            "direction (κ-68 G27)",
            "demiurge ARCH.md §11.4 Round 7 G28 — producer wire scope",
        ],
        "skipped_reason": None,
        "kernel_reuse": None,
        # κ-68 G28b: measured-oracle axis (D103 measured dimension)
        "measured_oracle": measured_oracle,
        # κ-67 land: hexa-native parity axis (D103 substrate dimension)
        # left null here — the stub doesn't make a substrate-parity
        # claim; that would be wired by a separate producer path.
        "hexa_native_parity": None,
    }

    out_path = os.path.join(
        output_dir,
        f"energy_verify_{stamp}_{PRODUCER_ID}.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2, sort_keys=True)
        f.write("\n")

    summary = {
        "ok": True,
        "producer": PRODUCER_ID,
        "stamp": stamp,
        "sample_count": SAMPLE_COUNT,
        "mean_rel_err": measured_oracle["mean_rel_err"],
        "max_rel_err": measured_oracle["max_rel_err"],
        "threshold": PASS_THRESHOLD,
        "would_pass": (
            measured_oracle["mean_rel_err"] <= PASS_THRESHOLD),
        "absorbed": False,  # D103 — never flipped from this producer
        "artifact": os.path.basename(out_path),
        "python_version": platform.python_version(),
    }
    sys.stderr.write(
        "ENERGY_VERIFY_MEASURED_ORACLE_STUB_RESULT "
        + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
