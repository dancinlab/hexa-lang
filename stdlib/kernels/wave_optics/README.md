# kernels/wave_optics/ — ①a wave-optics kernel (demiurge design.md D72)

Domain-agnostic wave-optics (diffractive PSF) computation kernel. The
FOURTH kernel extracted under the D72 2-layer STDLIB restructure
(after `kernels/graph/`, `kernels/fem/` and `kernels/orbital/`).

| file | role |
|---|---|
| `poppy_kernel.py` | `build_multihex_aperture` · `aperture_diameter_m` · `propagate_psf` · `compute_psf_metrics` · `poppy_version` — given an aperture + a wavelength + a detector spec, propagate the wavefront (Fraunhofer/Fresnel) and reduce it to PSF facts. |

## 2-layer (ABSORPTION.md ①)

- **①a kernel** (here) — domain-independent. No JWST 18-segment
  shelf, no 1.32 m flat-to-flat default, no 550 nm green-visible
  band. Pure "aperture + wavelength + detector in -> PSF + Strehl +
  encircled energy out".
- **①b adapter** — `stdlib/scope/scope_poppy.py` today (JWST-class
  segment geometry, the 550 nm band, the FOV shelf, the honesty
  caveats). Any future photonics-domain adapter rides the same kernel.

## API

- `build_multihex_aperture(segments, segment_flat_to_flat_m,
  gap_m=0.007, name)` — parametric `MultiHexagonAperture`. Maps the
  requested segment count to the nearest ring config. Returns
  `{ aperture, rings }`.
- `aperture_diameter_m(ap, fallback_flat_to_flat_m)` — effective
  tip-to-tip collecting diameter for a MultiHexagonAperture.
- `propagate_psf(aperture, wavelength_m, fov_arcsec,
  pixscale_arcsec, oversample=2, name)` — Fraunhofer/Fresnel
  propagation of a monochromatic point source. Returns
  `{ psf, psf_sha256_16 }`.
- `compute_psf_metrics(psf_hdulist, aperture_diameter_m,
  wavelength_m, default_pixscale_arcsec, ee_radii_arcsec)` — Strehl
  proxy, FWHM, encircled energy. Returns the measurements dict.
- `poppy_version()` — POPPY version probe.

## Why

`scope+analyze` computes diffractive PSFs today; any future photonics
domain (coronagraph contrast, fibre-coupling efficiency, wavefront
sensing) is a candidate consumer. Extracting the shared POPPY kernel
means N domains share 1 kernel (N×M -> N+M). The day a hexa-native
wave-optics kernel re-propagates these wavefronts, `absorbed=true`
flips HERE — once — instead of in every domain adapter.

## Honesty (g3)

Every value is a real Fraunhofer/Fresnel diffraction calculation on
the supplied aperture — deterministic ndarray IEEE-754 output, NOT a
measurement of any real polished primary. `strehl_proxy` is a proxy
(peak / diffraction-limited-peak estimate), NOT a strict Code V /
Zemax Strehl from a second reference propagation — a ~2 % discrepancy
the adapter must surface. Whether the aperture is parametric or a
measured wavefront map is a domain question: the honesty gate
(`measurement_gate`, `absorbed`, `scope_caveats`) lives in the ①b
adapter, NOT here. POPPY is an external library, so `absorbed = false`
at the record layer always.

## Callers

- `stdlib/scope/scope_poppy.py` — JWST-class segmented-primary PSF
  producer (demiurge `scope+analyze`).

The adapter locates this kernel by path relative to its own file
(`../kernels/wave_optics/`), so the `python3 <script> <output_dir>`
spawn from demiurge works regardless of cwd.
