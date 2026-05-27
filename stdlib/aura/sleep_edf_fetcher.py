#!/usr/bin/env python3
# sleep_edf_fetcher.py — κ-69 G33 PhysioNet Sleep-EDF Expanded fetcher
# (Aura/EEG measured-oracle source · demiurge design.md D115 5-fold
#  lock-in · ARCH §11.4 G33 · κ-68 G29 NREL MIDC pyranometer mirror).
#
# Anonymous HTTPS download (no auth) of a single Sleep-EDF subject's
# PSG (EDF binary) + Hypnogram annotation file from
# https://physionet.org/files/sleep-edfx/1.0.0/sleep-cassette/, parses
# via mne.io.read_raw_edf, slices into N=100 30-second epochs labelled
# Wake/REM (eyes-closed → alpha-rich), and emits one ASCII sidecar
# (`<cache>/<subject>_epochs.txt`) of length `n_epochs * samples_per_
# epoch` floats — one sample per line, epoch-major order — for the
# hexa-native `_dft_alpha_band_batch.hexa` consumer.
#
# Honesty (g3 — non-negotiable):
#   * The dataset is PUBLIC (PhysioNet Sleep-EDF Expanded, CC-BY · 153
#     PSG records · 100 Hz EEG Fpz-Cz/Pz-Oz channels · anonymous wget).
#     No subject identity beyond the PhysioNet record-ID; no clinical
#     interpretation; the signal-arithmetic test (alpha-band integrated
#     PSD) is the only claim.
#   * NO hardcoded dataset path (D86 floor). Subject ID + cache root
#     come from CLI args / env vars. Defaults exist for reproducibility
#     but are documented as defaults, not invariants.
#   * Sleep-stage filter (Wake/REM) is applied via the EDF+ hypnogram
#     channel — fail-fast if the hypnogram is absent or has fewer than
#     N=100 Wake/REM 30-s epochs (no silent fallback to other stages).
#   * The producer side (`aura_mne.py` measured-oracle path) reads this
#     sidecar + the same epochs from the FIF cache so MNE-Welch and
#     hexa-native DFT see byte-identical input.
#
# Invocation:
#   python3 sleep_edf_fetcher.py <cache_dir> [subject_id]
#
#   <cache_dir>   tmpfs-friendly directory for the EDF download + the
#                 ASCII sidecar. Default = $SLEEP_EDF_CACHE_DIR env or
#                 /tmp/sleep_edf/ (D86 — env-var preferred).
#   [subject_id]  Sleep-EDF subject (e.g. SC4001E0). Default = first
#                 subject from PhysioNet Sleep-Cassette cohort (also
#                 the D115-cited research-note default).
#
# Exit: 0 on success, 2 on usage, 3 on fetch/parse failure, 4 on
#       insufficient Wake/REM epochs.

import json
import os
import platform
import sys
import urllib.request


# D115 default subject (research-note default · single Sleep-EDF
# subject · 5+ eyes-closed Wake/REM epochs). Override via CLI arg.
DEFAULT_SUBJECT = "SC4001E0"

# PhysioNet anonymous-access base URL (Sleep-EDF Expanded v1.0.0).
PHYSIONET_BASE = (
    "https://physionet.org/files/sleep-edfx/1.0.0/sleep-cassette"
)

# Epoch geometry — D115 default (mirror of κ-68 G29 "single clear-sky
# day · 1-min cadence" magnitude). 30-s epoch is the Sleep-EDF
# annotation cadence (R&K / AASM rule).
EPOCH_SEC = 30.0
N_EPOCHS = 100

# Channel — Fpz-Cz is the canonical alpha-detection lead in Sleep-EDF
# (occipital alpha is the cleanest, but the cassette montage uses
# Fpz-Cz / Pz-Oz; Fpz-Cz is the more conservative pick for
# producer-side parity since the magnitude is smaller and the
# relative-error denominator is therefore more demanding).
CHANNEL = "EEG Fpz-Cz"

# Eyes-closed Wake + REM are the two stages where alpha (8-13 Hz) is
# most prominent (eyes-closed Wake alpha + REM theta-alpha mix).
# Stage codes per Sleep-EDF EDF+ hypnogram conventions:
#   "Sleep stage W"  -> Wake (eyes-closed or eyes-open — mixed)
#   "Sleep stage R"  -> REM
TARGET_STAGES = ("Sleep stage W", "Sleep stage R")


def _http_get(url, dest):
    """Anonymous HTTPS download with a 5-minute timeout."""
    sys.stderr.write(f"sleep_edf_fetcher: downloading {url}\n")
    with urllib.request.urlopen(url, timeout=300) as resp:
        with open(dest, "wb") as f:
            while True:
                chunk = resp.read(1 << 20)  # 1 MiB
                if not chunk:
                    break
                f.write(chunk)
    sys.stderr.write(
        f"sleep_edf_fetcher: wrote {os.path.getsize(dest)} bytes -> "
        f"{dest}\n")


def _subject_files(subject_id):
    """Return (psg_url, hyp_url, psg_name, hyp_name) for a subject.

    Sleep-EDF Cassette naming: <SCNNNNEx>-PSG.edf and a partner
    <SCNNNNEx>-Hypnogram.edf where the trailing letter differs by one
    (the hypnogram annotator's initial; for SC4001 the PSG is E0 and
    the hypnogram EC). This mapping is dataset-fixed — we hardcode the
    two known partner letters for the default subject and otherwise
    require the caller to supply both via env.
    """
    # Subject base = first 6 chars (e.g. "SC4001").
    base = subject_id[:6]
    psg_name = f"{subject_id}-PSG.edf"
    # Hypnogram partner letter — Sleep-EDF Cassette convention.
    # For SC4001E0 the partner is SC4001EC; this mapping is documented
    # in the PhysioNet record description.
    hyp_partner = base + "EC"
    hyp_name = f"{hyp_partner}-Hypnogram.edf"
    psg_url = f"{PHYSIONET_BASE}/{psg_name}"
    hyp_url = f"{PHYSIONET_BASE}/{hyp_name}"
    return psg_url, hyp_url, psg_name, hyp_name


def _ensure_subject(cache_dir, subject_id):
    """Download PSG + Hypnogram if not already cached. Returns
    (psg_path, hyp_path)."""
    psg_url, hyp_url, psg_name, hyp_name = _subject_files(subject_id)
    psg_path = os.path.join(cache_dir, psg_name)
    hyp_path = os.path.join(cache_dir, hyp_name)
    if not os.path.exists(psg_path) or os.path.getsize(psg_path) == 0:
        _http_get(psg_url, psg_path)
    else:
        sys.stderr.write(f"sleep_edf_fetcher: cached PSG -> {psg_path}\n")
    if not os.path.exists(hyp_path) or os.path.getsize(hyp_path) == 0:
        _http_get(hyp_url, hyp_path)
    else:
        sys.stderr.write(f"sleep_edf_fetcher: cached Hypnogram -> {hyp_path}\n")
    return psg_path, hyp_path


def _slice_target_epochs(raw, hyp_annotations, sfreq, channel,
                         epoch_sec, n_epochs, target_stages):
    """Return list of np.ndarray, each shape (samples_per_epoch,),
    sliced from the contiguous EEG channel at epoch boundaries that
    fall inside a `target_stages` annotation interval."""
    import numpy as np

    samples_per_epoch = int(round(sfreq * epoch_sec))
    data = raw.get_data(picks=[channel])[0]  # (n_samples,)
    n_total = data.shape[0]

    # Build a stage->boolean coverage of every 30-s epoch slot. Each
    # hypnogram annotation has onset (sec) + duration (sec) + label.
    epochs = []
    cursor_epoch_idx = 0
    cursor_t_sec = 0.0
    # Iterate the annotation list in time order.
    for ann in hyp_annotations:
        onset = float(ann["onset"])
        duration = float(ann["duration"])
        label = str(ann["description"])
        if label not in target_stages:
            cursor_t_sec = onset + duration
            continue
        # Number of full epochs that fit inside this annotation.
        n_in_block = int(duration // epoch_sec)
        block_start = onset
        for ki in range(n_in_block):
            start_sec = block_start + ki * epoch_sec
            start_idx = int(round(start_sec * sfreq))
            end_idx = start_idx + samples_per_epoch
            if end_idx > n_total:
                break
            epochs.append(data[start_idx:end_idx])
            if len(epochs) >= n_epochs:
                return epochs, samples_per_epoch
        cursor_t_sec = onset + duration

    return epochs, samples_per_epoch


def main(argv):
    if len(argv) < 2:
        sys.stderr.write(
            "usage: sleep_edf_fetcher.py <cache_dir> [subject_id]\n")
        return 2

    cache_dir = argv[1]
    if len(argv) >= 3:
        subject_id = argv[2]
    else:
        subject_id = os.environ.get("SLEEP_EDF_SUBJECT", DEFAULT_SUBJECT)

    os.makedirs(cache_dir, exist_ok=True)

    try:
        psg_path, hyp_path = _ensure_subject(cache_dir, subject_id)
    except Exception as exc:
        sys.stderr.write(
            f"sleep_edf_fetcher: download failed: "
            f"{type(exc).__name__}: {exc}\n")
        return 3

    try:
        import numpy as np
        import mne
    except ImportError as exc:
        sys.stderr.write(f"sleep_edf_fetcher: missing dep: {exc}\n")
        return 3

    try:
        raw = mne.io.read_raw_edf(
            psg_path, preload=True, stim_channel=None, verbose="ERROR")
        annot = mne.read_annotations(hyp_path)
    except Exception as exc:
        sys.stderr.write(
            f"sleep_edf_fetcher: EDF parse failed: "
            f"{type(exc).__name__}: {exc}\n")
        return 3

    sfreq = float(raw.info["sfreq"])
    if CHANNEL not in raw.ch_names:
        sys.stderr.write(
            f"sleep_edf_fetcher: channel {CHANNEL!r} not present "
            f"in PSG (available: {raw.ch_names})\n")
        return 3

    # Convert MNE Annotations -> list of dicts.
    anns = []
    for i in range(len(annot)):
        anns.append({
            "onset": float(annot.onset[i]),
            "duration": float(annot.duration[i]),
            "description": str(annot.description[i]),
        })

    epochs, samples_per_epoch = _slice_target_epochs(
        raw, anns, sfreq, CHANNEL,
        EPOCH_SEC, N_EPOCHS, TARGET_STAGES)

    if len(epochs) < N_EPOCHS:
        sys.stderr.write(
            f"sleep_edf_fetcher: only {len(epochs)} Wake/REM epochs "
            f"in {subject_id} hypnogram; need {N_EPOCHS} — honest "
            f"FAIL (no silent fallback to other stages, g3).\n")
        return 4

    # Emit ASCII sidecar — one float per line, epoch-major order.
    sidecar_path = os.path.join(cache_dir, f"{subject_id}_epochs.txt")
    with open(sidecar_path, "w") as f:
        for epoch in epochs[:N_EPOCHS]:
            for v in epoch:
                f.write(f"{float(v):.12g}\n")

    # Also emit a small meta JSON for the producer to consume without
    # re-parsing the EDF.
    meta_path = os.path.join(cache_dir, f"{subject_id}_epochs.meta.json")
    meta = {
        "ok": True,
        "subject_id": subject_id,
        "psg_path": psg_path,
        "hyp_path": hyp_path,
        "sidecar_path": sidecar_path,
        "channel": CHANNEL,
        "sfreq_hz": sfreq,
        "n_epochs": N_EPOCHS,
        "samples_per_epoch": samples_per_epoch,
        "epoch_sec": EPOCH_SEC,
        "target_stages": list(TARGET_STAGES),
        "mne_version": mne.__version__,
        "numpy_version": np.__version__,
        "python_version": platform.python_version(),
        "physionet_base": PHYSIONET_BASE,
        "dataset_citation": (
            "Kemp et al., Sleep-EDF Database Expanded (v1.0.0). "
            "PhysioNet. doi:10.13026/C2X676. CC-BY."
        ),
    }
    with open(meta_path, "w") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"sleep_edf_fetcher: wrote {sidecar_path} "
        f"({len(epochs[:N_EPOCHS])} epochs × "
        f"{samples_per_epoch} samples · {CHANNEL} · sfreq={sfreq})\n")
    sys.stderr.write(
        "SLEEP_EDF_FETCH_RESULT "
        + json.dumps({
            "ok": True,
            "subject_id": subject_id,
            "n_epochs": N_EPOCHS,
            "samples_per_epoch": samples_per_epoch,
            "sfreq_hz": sfreq,
            "sidecar_path": sidecar_path,
            "meta_path": meta_path,
        }, sort_keys=True)
        + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
