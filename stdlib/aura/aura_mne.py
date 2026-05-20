# aura_mne.py — ①b domain adapter (demiurge design.md D72)
# MNE-Python EEG signal-processing producer for `aura + analyze`.
#
# D72 2-layer restructure: this file is now a THIN domain adapter.
# It owns ONLY the domain-specific signal (synthetic EEG epoch, 10-20
# channel names, montage tag) and the domain honesty caveats. All
# spectral math is delegated to the shared ①a kernel
# `kernels/signal_proc/mne_psd_kernel.py`.
#
# SSOT location: `~/core/hexa-lang/stdlib/aura/aura_mne.py` (D61 —
# producer scripts live under hexa-lang/stdlib/<domain>/ rather than
# the legacy `cockpit/scripts/`).
#
# Invoked by Swift's AuraAnalyzeProducer via:
#   /opt/homebrew/bin/python3.12 ~/core/hexa-lang/stdlib/aura/aura_mne.py \
#       <output_dir>
#
# What it does (honest scope):
#   1. Generates a *deterministic* synthetic EEG epoch (fixed RNG seed,
#      8 channels × 4 s @ 256 Hz) that mixes a 10 Hz alpha sinusoid,
#      pink-spectrum background, and a 60 Hz mains line — a controlled
#      stimulus where the band-powers + line-noise can be checked
#      analytically. The output is plausible-not-clinical (no real
#      subject, no electrode placement). — this is the ①b domain
#      knowledge.
#   2. Wraps the array in an MNE `RawArray` with standard 10-20 channel
#      names (post-aural montage subset: F3 F4 C3 C4 P3 P4 T7 T8).
#   3. Delegates the Welch PSD + per-band power + 60 Hz line-noise
#      rejection figure to the ①a kernel `mne_psd_kernel.spectral_metrics`.
#   4. Reports a `mains_60_hz_db` figure (the kernel's generic
#      line-noise figure, interpreted here as mains hum — IEC
#      60601-1-2 relevance, domains/aura.md §2 VERIFY row).
#   5. Writes `aura_eeg_v1_eeg.fif` (MNE-native binary) +
#      `aura_eeg_v1.meta.json` and prints `AURA_MNE_RESULT <json>`
#      summary line on stderr.
#
# HONESTY (g3 — non-negotiable, domain caveats stay HERE):
#   • The signal is *synthesized* — there is no subject, no electrode,
#     no clinical recording. MNE IS the instrument doing the PSD math
#     (its Welch implementation, delegated to the ①a kernel), but the
#     substrate is plausible-not-absorbed. `absorbed=true` is NEVER
#     set by this producer.
#   • measurement_gate stays GATE_OPEN downstream — to flip closed we'd
#     need (a) a real subject + IRB-approved acquisition or (b) a public
#     PhysioNet dataset pinned by commit hash + bench-validated
#     spectrum check. Single synthetic epoch is the P-⑧ "can we make a
#     record at all?" answer, not a clinical claim.
#   • The Sim4Life MRI-safety gap (domains/aura.md §4) is orthogonal —
#     MNE is signal processing, not EM simulation. We don't pretend
#     this is wearable safety.
#   • absorbed = false ALWAYS — MNE is EXTERNAL. The day a hexa-native
#     Welch-PSD kernel re-computes these spectra, absorbed flips in
#     the ①a kernel — not in this adapter.

import json
import os
import platform
import sys

# --- Locate the ①a signal-processing kernel relative to this
# adapter's own file (stdlib/aura/ -> stdlib/kernels/signal_proc/).
# The Swift spawn sets an arbitrary cwd, so a path relative to
# __file__ is the only robust anchor.
_KERNEL_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "kernels", "signal_proc")
if _KERNEL_DIR not in sys.path:
    sys.path.insert(0, _KERNEL_DIR)

GEOMETRY_ID = "aura_eeg_v1"

# Deterministic stimulus parameters (these are the SSOT — drift on these
# changes the SHA, and the Swift side rejects the record).
SFREQ = 256.0                         # Hz — sampling rate
DURATION_S = 4.0                      # s — epoch length
N_CHANNELS = 8                        # post-aural-friendly subset
CHANNEL_NAMES = ["F3", "F4", "C3", "C4", "P3", "P4", "T7", "T8"]
RNG_SEED = 314159                     # fixed — deterministic stimulus
ALPHA_HZ = 10.0                       # peak in alpha band
ALPHA_AMP_UV = 25.0                   # µV — typical eyes-closed alpha
MAINS_HZ = 60.0                       # NA / KR mains line
MAINS_AMP_UV = 3.0                    # µV — small line contamination
PINK_AMP_UV = 10.0                    # µV — background scale

# Standard EEG band edges (Hz).
BANDS = {
    "delta": (1.0, 4.0),
    "theta": (4.0, 8.0),
    "alpha": (8.0, 13.0),
    "beta":  (13.0, 30.0),
    "gamma": (30.0, 45.0),
}


def synthesize_epoch():
    """Build the deterministic (n_channels, n_samples) µV array. Returns
    (data_volts, n_samples) — MNE expects V, hence the 1e-6 scaling.
    This is the ①b domain stimulus — the kernel never sees EEG.
    """
    import numpy as np
    rng = np.random.default_rng(RNG_SEED)
    n_samples = int(SFREQ * DURATION_S)
    t = np.arange(n_samples) / SFREQ

    # Common alpha component — shared across channels with small phase
    # offset per channel so they aren't byte-identical.
    data = np.zeros((N_CHANNELS, n_samples), dtype=np.float64)
    for ch in range(N_CHANNELS):
        phase = 0.1 * ch
        alpha = ALPHA_AMP_UV * np.sin(2.0 * np.pi * ALPHA_HZ * t + phase)
        mains = MAINS_AMP_UV * np.sin(2.0 * np.pi * MAINS_HZ * t)
        # Pink-ish background = white through a 1/sqrt(f) filter in
        # frequency space — cheap, deterministic, no SciPy dep.
        white = rng.standard_normal(n_samples).astype(np.float64)
        fft = np.fft.rfft(white)
        freqs = np.fft.rfftfreq(n_samples, d=1.0 / SFREQ)
        # Avoid div-by-zero at DC.
        scale = np.zeros_like(freqs)
        scale[1:] = 1.0 / np.sqrt(freqs[1:])
        pink = np.fft.irfft(fft * scale, n=n_samples)
        # Re-normalize pink to have target RMS amplitude.
        pink_rms = float(np.sqrt(np.mean(pink ** 2)))
        if pink_rms > 0:
            pink = pink * (PINK_AMP_UV / pink_rms)
        data[ch, :] = alpha + mains + pink
    # µV → V
    return data * 1.0e-6, n_samples


def main(argv: list) -> int:
    if len(argv) < 2:
        sys.stderr.write("usage: aura_mne.py <output_dir>\n")
        return 2
    output_dir = argv[1]
    os.makedirs(output_dir, exist_ok=True)

    # MNE expects raw files to end with `_eeg.fif` (or similar) — see
    # the runtime check inside `mne.io.Raw.save`.
    fif_path = os.path.join(output_dir, f"{GEOMETRY_ID}_eeg.fif")
    meta_path = os.path.join(output_dir, f"{GEOMETRY_ID}.meta.json")

    # Import the ①a kernel — honest gap if the kernel module is missing.
    try:
        import mne_psd_kernel as kernel
    except ImportError as exc:
        sys.stderr.write(
            f"aura_mne: ①a signal-processing kernel import failed — {exc}. "
            "Expected at stdlib/kernels/signal_proc/mne_psd_kernel.py "
            "(g3 — silent success forbidden).\n")
        sys.stderr.write("AURA_MNE_RESULT "
                         + json.dumps({"ok": False,
                                       "geometry_id": GEOMETRY_ID,
                                       "error": "signal_proc_kernel_import_failed"},
                                      sort_keys=True)
                         + "\n")
        return 3

    # numpy + mne import is the only "heavy" cost — keep it inside main
    # so the usage line works even if the deps aren't installed.
    try:
        import numpy as np  # noqa: F401
        import mne
    except ImportError as exc:
        sys.stderr.write(f"aura_mne: missing dependency — {exc}\n"
                         "AURA_MNE_RESULT "
                         + json.dumps({"ok": False,
                                       "geometry_id": GEOMETRY_ID,
                                       "error": f"import: {exc}"},
                                      sort_keys=True)
                         + "\n")
        return 3

    data, n_samples = synthesize_epoch()
    s_hash = kernel.signal_sha256_16(data)

    info = mne.create_info(ch_names=CHANNEL_NAMES,
                           sfreq=SFREQ, ch_types="eeg")
    raw = mne.io.RawArray(data, info, verbose=False)

    try:
        raw.save(fif_path, overwrite=True, verbose=False)
    except Exception as exc:
        sys.stderr.write(f"aura_mne: fif write failed — {exc}\n")
        sys.stderr.write("AURA_MNE_RESULT "
                         + json.dumps({"ok": False,
                                       "geometry_id": GEOMETRY_ID,
                                       "error": f"fif_write: {exc}"},
                                      sort_keys=True)
                         + "\n")
        return 4

    # --- Delegate ALL spectral math to the ①a kernel. The kernel
    # returns a generic `line_noise_*` figure; the ①b adapter re-labels
    # it as the domain-specific `mains_60_hz_*` (EEG mains-hum proxy).
    raw_data = raw.get_data()             # (n_channels, n_samples) in V
    sfreq = float(raw.info["sfreq"])
    try:
        km = kernel.spectral_metrics(
            raw_data, sfreq, bands=BANDS, line_hz=MAINS_HZ,
            fmin=0.5, fmax=80.0, n_fft_cap=512)
    except Exception as exc:
        sys.stderr.write(
            f"aura_mne: kernel spectral computation failed — {exc} (g3).\n")
        sys.stderr.write("AURA_MNE_RESULT "
                         + json.dumps({"ok": False,
                                       "geometry_id": GEOMETRY_ID,
                                       "error": f"compute_failed: {exc}"},
                                      sort_keys=True)
                         + "\n")
        return 4

    # Re-label kernel's generic line-noise figure as the domain
    # mains-rejection proxy — the meta byte-shape stays identical to
    # the pre-D72 producer (Swift reads `mains_60_hz_*`).
    measurements = {
        "n_channels": km["n_channels"],
        "n_freqs": km["n_freqs"],
        "freq_min_hz": km["freq_min_hz"],
        "freq_max_hz": km["freq_max_hz"],
        "band_power_per_channel_v2": km["band_power_per_channel_v2"],
        "band_power_grand_avg_v2": km["band_power_grand_avg_v2"],
        "mains_60_hz_ratio": km["line_noise_ratio"],
        "mains_60_hz_db": km["line_noise_db"],
        "total_power_per_channel_v2": km["total_power_per_channel_v2"],
    }

    version = kernel.mne_version()
    ok = (measurements["n_freqs"] > 0
          and measurements["band_power_grand_avg_v2"]["alpha"] > 0)

    meta = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "signal_sha256_16": s_hash,
        "mne_version": version,
        "python_version": platform.python_version(),
        "stimulus": {
            "sfreq_hz": SFREQ,
            "duration_s": DURATION_S,
            "n_channels": N_CHANNELS,
            "channel_names": CHANNEL_NAMES,
            "rng_seed": RNG_SEED,
            "alpha_hz": ALPHA_HZ,
            "alpha_amp_uV": ALPHA_AMP_UV,
            "mains_hz": MAINS_HZ,
            "mains_amp_uV": MAINS_AMP_UV,
            "pink_amp_uV": PINK_AMP_UV,
        },
        "bands_hz": {k: list(v) for k, v in BANDS.items()},
        "measurements": measurements,
        "artifacts": {
            "fif": f"{GEOMETRY_ID}_eeg.fif",
        },
    }
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(f"aura_mne: wrote {meta_path} (ok={ok}, "
                     f"n_freqs={measurements['n_freqs']}, "
                     f"alpha={measurements['band_power_grand_avg_v2']['alpha']:.3e})\n")

    artifacts_with_meta = dict(meta["artifacts"])
    artifacts_with_meta["meta"] = f"{GEOMETRY_ID}.meta.json"
    summary = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "signal_sha256_16": s_hash,
        "mne_version": version,
        "alpha_power_v2": measurements["band_power_grand_avg_v2"]["alpha"],
        "mains_60_hz_db": measurements["mains_60_hz_db"],
        "n_samples": n_samples,
        "artifacts": artifacts_with_meta,
    }
    sys.stderr.write("AURA_MNE_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    return 0 if ok else 5


if __name__ == "__main__":
    sys.exit(main(sys.argv))
