# mne_psd_kernel.py — ①a STDLIB kernel layer (demiurge design.md D72)
#
# Domain-agnostic spectral signal-processing computation kernel. This
# kernel is extracted under the D72 2-layer STDLIB restructure: any
# producer in `stdlib/<domain>/` that reduces a multi-channel
# time-series to power-spectral facts calls into this single module
# instead of re-implementing the MNE Welch wrapping.
#
# Layer split (ABSORPTION.md ①):
#   ①a kernel  — THIS FILE. Domain-independent. No EEG, no 10-20
#                montage, no mains-hum proxy — only "given a
#                (n_channels, n_samples) array + a sample rate + a
#                set of frequency bands, compute the deterministic
#                Welch-PSD facts about it".
#   ①b adapter — `stdlib/aura/aura_mne.py` (EEG channels / montage /
#                synthetic stimulus / honesty caveats), and any
#                future spectral-domain adapter (vibration, acoustics).
#                They own the domain signal + caveats and call this
#                kernel for the math.
#
# HONESTY (g3 — non-negotiable, inherited by every caller):
#   * Every value computed here IS a real MNE Welch-PSD result —
#     MNE's `psd_array_welch` is a deterministic numerical estimator
#     (no random tapers). It is NOT a model prediction.
#   * The honesty gate (measurement_gate, scope_caveats, the
#     synthetic-vs-acquired distinction) lives in the ①b adapter,
#     NOT here. This kernel does pure "signal in -> spectrum out".
#   * absorbed = false ALWAYS at the record layer — MNE is an
#     EXTERNAL Python library, not absorbed into hexa-lang. The day a
#     hexa-native Welch-PSD kernel re-computes these spectra with a
#     numerically-equivalent method, absorbed flips — and it flips
#     HERE (one kernel) rather than in N domain adapters.
#   * Import failure / compute failure is raised, not swallowed —
#     silent success is forbidden. The caller reports it verbatim.

import hashlib
from typing import Any


def mne_version() -> str:
    """Probe the installed MNE version string. Returns 'unknown' if
    the library cannot be imported — the caller decides whether that
    is a hard gap (it is, for spectral producers)."""
    try:
        import mne
        return str(mne.__version__)
    except Exception:
        return "unknown"


def signal_sha256_16(data) -> str:
    """SHA-256 (16 hex) of the raw signal bytes — cross-host drift
    sentinel. Same hash <-> byte-identical signal."""
    return hashlib.sha256(data.tobytes()).hexdigest()[:16]


def welch_psd(data, sfreq: float, fmin: float = 0.5, fmax: float = 80.0,
              n_fft_cap: int = 512):
    """Compute the Welch power-spectral density of a multi-channel
    signal via MNE's deterministic `psd_array_welch`.

    Args:
        data    — (n_channels, n_samples) float array.
        sfreq   — sample rate in Hz.
        fmin/fmax — frequency window to retain.
        n_fft_cap — upper bound on the FFT length (clamped to the
                    signal length).

    Returns (psd, freqs) — psd shape (n_channels, n_freqs), units of
    the input squared per Hz; freqs shape (n_freqs,).

    Raises on import / compute failure (g3 — silent success forbidden).
    """
    from mne.time_frequency import psd_array_welch
    n_fft = min(data.shape[1], n_fft_cap)
    psd, freqs = psd_array_welch(
        data, sfreq=sfreq, fmin=fmin, fmax=fmax,
        n_fft=n_fft, n_overlap=n_fft // 2,
        n_per_seg=n_fft, verbose=False)
    return psd, freqs


def band_power(psd, freqs, bands: dict) -> dict:
    """Integrate the PSD over named frequency bands (trapezoidal).

    Args:
        psd   — (n_channels, n_freqs) PSD array from `welch_psd`.
        freqs — (n_freqs,) frequency axis.
        bands — {name: (lo_hz, hi_hz)} band-edge dict.

    Returns {"per_channel": {name: [float, ...]},
             "grand_avg": {name: float}} — power in each band
    (input-units²), one list per band over channels plus the
    channel-mean grand average.
    """
    import numpy as np
    per_channel = {}
    grand_avg = {}
    df = float(freqs[1] - freqs[0]) if len(freqs) > 1 else 0.0
    for name, (lo, hi) in bands.items():
        mask = (freqs >= lo) & (freqs < hi)
        ch_power = np.trapezoid(psd[:, mask], dx=df, axis=1)
        per_channel[name] = [float(x) for x in ch_power]
        grand_avg[name] = float(np.mean(ch_power))
    return {"per_channel": per_channel, "grand_avg": grand_avg}


def line_noise_ratio(psd, freqs, line_hz: float,
                      baseline_lo: float = 1.0,
                      baseline_hi: float = 49.0):
    """Ratio of PSD power at a line-noise frequency vs a baseline
    band — the domain-agnostic "interference rejection" figure (the
    ①b adapter interprets it, e.g. mains-hum for EEG).

    Returns (ratio, db) — both `None` if the baseline is non-positive.
    Higher = WORSE (more line contamination).
    """
    import numpy as np
    idx = int(np.argmin(np.abs(freqs - line_hz)))
    line_power = float(np.mean(psd[:, idx]))
    band_mask = (freqs >= baseline_lo) & (freqs < baseline_hi)
    baseline = float(np.median(psd[:, band_mask]))
    if baseline <= 0:
        return None, None
    ratio = line_power / baseline
    db = 10.0 * float(np.log10(ratio)) if ratio > 0 else None
    return ratio, db


def total_power_per_channel(psd, freqs) -> list:
    """Per-channel total power = trapezoidal integral of the PSD over
    the full retained frequency axis. A simple QC figure."""
    import numpy as np
    return [float(np.trapezoid(psd[ch, :], freqs))
            for ch in range(psd.shape[0])]


def spectral_metrics(data, sfreq: float, bands: dict, line_hz: float,
                     fmin: float = 0.5, fmax: float = 80.0,
                     n_fft_cap: int = 512) -> dict:
    """One-shot reduction: Welch PSD -> band power + line-noise ratio
    + total power. The ①b adapter calls this and wraps the result in
    its domain meta. Returns a dict mirroring the legacy aura
    `measurements` shape (band keys are caller-supplied)."""
    psd, freqs = welch_psd(data, sfreq, fmin=fmin, fmax=fmax,
                           n_fft_cap=n_fft_cap)
    bp = band_power(psd, freqs, bands)
    ratio, db = line_noise_ratio(psd, freqs, line_hz)
    total = total_power_per_channel(psd, freqs)
    return {
        "n_channels": int(psd.shape[0]),
        "n_freqs": int(psd.shape[1]),
        "freq_min_hz": float(freqs[0]),
        "freq_max_hz": float(freqs[-1]),
        "band_power_per_channel_v2": bp["per_channel"],
        "band_power_grand_avg_v2": bp["grand_avg"],
        "line_noise_ratio": ratio,
        "line_noise_db": db,
        "total_power_per_channel_v2": total,
    }
