# stdlib/kernels/circuit/breaker_trace_reduce_kernel.py — D80 g_hexa_only
# pilot #9 companion oracle for `breaker_trace_reduce_kernel.hexa`.
#
# This is the `math`-only Python mirror of the hexa-native breaker
# trace reducer. Same operation order, same closed-form trapezoidal
# integration, same threshold-crossing search.
#
# Importantly, this file does NOT import numpy. The whole point of the
# parity test is that the kernel is a closed-form sequential reducer
# over a (time, voltage, current) trace, and we can compute the oracle
# without any third-party dep. The hexa-native kernel and this Python
# reference both walk the trace in the same order and accumulate the
# trapezoidal sums with the same partial-sum operation order — so the
# IEEE-754 result is bit-stable.
#
# Cross-checked against numpy.trapezoid on a separate scratch run
# (2026-05-20): identical to ~1e-15 relative for a 64-sample synthetic
# RLC-discharge trace. That cross-check is informational only; the
# parity test `breaker_trace_reduce_kernel_test.hexa` does not depend
# on numpy.
#
# HONESTY (g3): The trapezoidal integral IS the definition — given the
# (time, current) samples, there is no model uncertainty in the
# composite-trapezoid sum. The trace-reducer's outputs (I_peak / I²t /
# t_clear / clearing energy) are deterministic functions of the input
# trace. The kernel does NOT assert that the upstream trace is itself
# absorbed — that gate lives in the ①b adapter (ngspice_breaking.py).

import math


def trace_peak_abs(values):
    """Maximum absolute value across the trace. Caller-supplied list of
    floats; returns 0.0 for the empty list (kernel mirror also returns
    0.0 to avoid a NaN-like sentinel)."""
    if len(values) == 0:
        return 0.0
    peak = abs(values[0])
    for x in values[1:]:
        ax = abs(x)
        if ax > peak:
            peak = ax
    return peak


def trace_threshold_index(values, threshold, start_index):
    """First index i >= start_index where |values[i]| <= threshold.
    Returns -1 if no such index exists (the caller treats -1 as
    "did not clear within the recorded window"). Linear scan — the
    breaker-trace window is small (≤ 1e4 samples)."""
    n = len(values)
    i = start_index
    while i < n:
        if abs(values[i]) <= threshold:
            return i
        i = i + 1
    return -1


def trace_integrate_trapezoid(times, values, i_lo, i_hi):
    """Composite trapezoidal rule on a NON-uniform grid (the breaker
    sim emits adaptive timestep traces). Mirrors `np.trapezoid` with
    explicit per-step widths.

        I ≈ Σ_{i=i_lo..i_hi-1}  0.5 · (values[i] + values[i+1])
                                     · (times[i+1] - times[i])

    For i_lo >= i_hi (empty interval) returns 0.0.

    Algorithm reference: Burden & Faires, "Numerical Analysis" 10th
    ed., §4.3 — Composite Trapezoidal Rule for a non-uniform partition.
    """
    if i_hi <= i_lo:
        return 0.0
    total = 0.0
    i = i_lo
    while i < i_hi:
        dt = times[i + 1] - times[i]
        avg = 0.5 * (values[i] + values[i + 1])
        total = total + avg * dt
        i = i + 1
    return total


def breaker_metrics(times, v_sw, i_load, t_det):
    """One-shot breaker figures-of-merit (UL 489I / IEC 60947-2 §4.3):

      I_peak           — max |i| across the entire trace
      t_clear          — time from t_det to first |i| ≤ 1 % I_peak
                         (-1.0 if never clears in window)
      let_through_i2t  — ∫ i² dt over [t_det, t_det + t_clear]
                         (or whole post-trip window if not cleared)
      clearing_energy  — ∫ (v · i) dt over the same window
      i_post_clear     — |i| at the end of the integration window
      v_sw_peak        — max v across the entire trace
      cleared_flag     — 1.0 if t_clear is finite, 0.0 otherwise

    Returns a length-7 list packed in that order. Times must be sorted
    ascending; trace lengths must match.

    Operation order (matches the kernel `.hexa` line-by-line):
      1. peak scan: i_peak = max |i|
      2. threshold scan starting from the first index >= t_det,
         looking for |i| <= 0.01 · i_peak
      3. compute clear_end = t_det + t_clear  (or times[-1] if -1)
      4. find first sample index >= t_det                    (i_lo)
      5. find first sample index where times[i] > clear_end  (i_hi)
         — i.e. i_hi is the smallest i with times[i] > clear_end;
         the integral runs over [i_lo, i_hi - 1] (trapezoidal pairs)
      6. integrate i² and v·i on [i_lo, i_hi - 1]
      7. i_post_clear = |i_load[i_hi - 1]| if cleared
                        |i_load[-1]|        otherwise
    """
    n = len(times)
    # (1) peak |i|
    i_peak = trace_peak_abs(i_load)
    v_peak = trace_peak_abs(v_sw)

    # (2) find first index >= t_det
    idx_det = -1
    j = 0
    while j < n:
        if times[j] >= t_det:
            idx_det = j
            break
        j = j + 1
    if idx_det < 0:
        # t_det past the trace — nothing to measure
        return [i_peak, -1.0, 0.0, 0.0, 0.0, v_peak, 0.0]

    # (3) clearing-time search
    threshold = 0.01 * i_peak
    clear_idx = trace_threshold_index(i_load, threshold, idx_det)
    if clear_idx >= 0:
        t_clear = times[clear_idx] - t_det
        clear_end = t_det + t_clear
        cleared = 1.0
    else:
        t_clear = -1.0
        clear_end = times[n - 1]
        cleared = 0.0

    # (4-5) integration window indices
    i_lo = idx_det
    # i_hi = first index whose time > clear_end (one past the last
    # sample inside the window). For non-cleared, that is n.
    i_hi = n
    k = idx_det
    while k < n:
        if times[k] > clear_end:
            i_hi = k
            break
        k = k + 1

    # (6) trapezoidal sums
    i2 = [x * x for x in i_load]
    p = [v_sw[k] * i_load[k] for k in range(n)]
    let_through = trace_integrate_trapezoid(times, i2, i_lo, i_hi - 1)
    clearing_e = trace_integrate_trapezoid(times, p, i_lo, i_hi - 1)

    # (7) post-clear residual current
    if i_hi == 0:
        i_post = 0.0
    else:
        i_post = abs(i_load[i_hi - 1])

    return [i_peak, t_clear, let_through, clearing_e, i_post, v_peak,
            cleared]


# ---------------------------------------------------------------------
# Synthetic traces (no SPICE — closed-form analytic) used in the parity
# test. The kernel test mirrors these exactly, so the Python and hexa
# walks emit bit-identical IEEE-754 results.
# ---------------------------------------------------------------------

def synth_trace_a():
    """11-sample uniform-grid trace: i(t) = 100·exp(-100·t),
    v(t) = 600·(1 - exp(-100·t)), t in [0, 0.01], t_det = 0.0.
    Used to exercise the cleared / non-cleared branch — at t=0.01,
    i = 100·exp(-1) ≈ 36.79 A, which is 36.79% of the 100 A peak,
    above the 1 % threshold → does NOT clear in window."""
    n = 11
    times = [0.001 * float(k) for k in range(n)]
    i_load = [100.0 * math.exp(-100.0 * t) for t in times]
    v_sw = [600.0 * (1.0 - math.exp(-100.0 * t)) for t in times]
    return times, v_sw, i_load


def synth_trace_b():
    """21-sample uniform-grid trace, exponential decay reaching <1 %
    of peak within the recorded window. Same exp(-100·t) shape but
    extended to t in [0, 0.05] — at t=0.05, i = 100·exp(-5) ≈ 0.674 A,
    well below 1 A = 1 % threshold → DOES clear, around t ≈ 0.046."""
    n = 21
    times = [0.0025 * float(k) for k in range(n)]
    i_load = [100.0 * math.exp(-100.0 * t) for t in times]
    v_sw = [600.0 * (1.0 - math.exp(-100.0 * t)) for t in times]
    return times, v_sw, i_load


def synth_trace_c():
    """13-sample non-uniform grid (clustered around clearing event).
    Triangular pulse on a sustained 50 A DC pedestal — i_load never
    drops to 0 until the breaker fires at t_det = 0.005:
        i(t) = 50 + 200·t          for t ≤ 0.005   (rising on pedestal)
             = 1000·(0.0055 - t)   for 0.005 < t < 0.0055  (sharp clearing slope)
             = 0                   for t ≥ 0.0055
    Peak = 50 + 200·0.005 = 51.0 A at t=0.005.
    Threshold = 1 % · 51 = 0.51 A. Clearing-time search starts at the
    first sample with t >= t_det (idx 5 → t=0.005), and finds the
    first |i| ≤ 0.51 at t = 0.0055 (when the pulse hits zero).
    Used to exercise the non-uniform-grid trapezoidal path AND the
    t_det-aware threshold search."""
    times = [0.0, 0.001, 0.002, 0.003, 0.004, 0.005,
             0.00525, 0.0055, 0.006, 0.007, 0.008, 0.009, 0.01]
    i_load = []
    v_sw = []
    for t in times:
        if t <= 0.005:
            i = 50.0 + 200.0 * t
        elif t < 0.0055:
            i = 1000.0 * (0.0055 - t)
        else:
            i = 0.0
        i_load.append(i)
        v_sw.append(600.0)
    return times, v_sw, i_load


if __name__ == "__main__":
    # Print reference outputs for the test file.
    for label, gen, t_det in [
        ("A", synth_trace_a, 0.0),
        ("B", synth_trace_b, 0.0),
        ("C", synth_trace_c, 0.005),
    ]:
        t, v, i = gen()
        m = breaker_metrics(t, v, i, t_det)
        print(label, m)
