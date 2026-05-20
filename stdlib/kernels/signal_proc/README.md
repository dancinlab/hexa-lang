# kernels/signal_proc/ — ①a spectral signal-processing kernel (demiurge design.md D72)

Domain-agnostic Welch power-spectral-density kernel. Extracted under
the D72 2-layer STDLIB restructure alongside the aura/bot/energy
domain recovery.

| file | role |
|---|---|
| `mne_psd_kernel.py` | `welch_psd` · `band_power` · `line_noise_ratio` · `total_power_per_channel` · `spectral_metrics` · `signal_sha256_16` · `mne_version` — given any `(n_channels, n_samples)` array + a sample rate + frequency bands, compute the deterministic PSD facts. |

## 2-layer (ABSORPTION.md ①)

- **①a kernel** (here) — domain-independent. No EEG, no 10-20
  montage, no mains-hum proxy. Pure "signal in -> spectrum out".
- **①b adapter** — `stdlib/aura/aura_mne.py`. It owns the EEG
  channel set / montage tag / synthetic stimulus / honesty caveats
  and calls this kernel for the spectral math.

## Why

`aura + analyze` re-implemented MNE Welch wrapping inline. Extracting
the shared kernel means any future spectral domain (vibration,
acoustics, structural modal analysis) shares 1 kernel (N×M -> N+M).
The day a hexa-native Welch-PSD kernel lands, `absorbed=true` flips
HERE — once — instead of in every domain adapter.

## Callers

- `stdlib/aura/aura_mne.py` — synthetic EEG epoch, 10-20 montage subset

Adapters locate this kernel by path relative to their own file
(`../kernels/signal_proc/`), so the `python3 <script> <output_dir>`
spawn from demiurge works regardless of cwd.
