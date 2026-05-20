# kernels/orbital/ — ①a orbital-mechanics kernel (demiurge design.md D72)

Domain-agnostic orbital-mechanics computation kernel. The THIRD kernel
extracted under the D72 2-layer STDLIB restructure (after
`kernels/graph/` and `kernels/fem/`).

| file | role |
|---|---|
| `sgp4_kernel.py` | `propagate_track` · `tle_epoch_utc` · `tle_text_hash` · `skyfield_version` · `sgp4_version` · `versions` — given a TLE + an observer + a sample window, propagate the orbit (SGP4) and reduce it to a topocentric track. |

## 2-layer (ABSORPTION.md ①)

- **①a kernel** (here) — domain-independent. No ISS / HST, no Seoul
  observer, no 24-hour shelf window. Pure "TLE + observer + window in
  -> track rows + visibility aggregates out".
- **①b adapter** — `stdlib/space/skyfield_sgp4.py` today (bundled
  NORAD TLE set, the fixed ground observer, the window shelf, the
  honesty caveats). Any future satellite-domain adapter rides the
  same kernel.

## API

- `propagate_track(line1, line2, name, observer_lat_deg,
  observer_lon_deg, observer_elev_m, t0_utc, sample_count, step_s,
  visibility_alt_deg=10.0)` — SGP4 propagation + topocentric
  reduction for one satellite. Returns `{ rows, aggregates }` —
  `rows` is per-sample track data (NDJSON-ready), `aggregates` is the
  visibility summary (`sample_count`, `visible_count`,
  `visibility_ratio`, `max_alt_deg`, `mean_alt_deg_visible`,
  `max_pass_minutes`, `visible_window_count`).
- `tle_epoch_utc(line1)` — parse the TLE epoch (cols 19-32) to a
  tz-aware UTC datetime.
- `tle_text_hash(tles)` — SHA-256 (16 hex) of the concatenated TLE
  text — input-provenance hash.
- `skyfield_version()` / `sgp4_version()` / `versions()` — propagator
  stack version probes.

## Why

`space+analyze` propagates orbits today; any future satellite domain
(constellation coverage, debris conjunction, ground-station
scheduling) is a candidate consumer. Extracting the shared Skyfield +
SGP4 kernel means N domains share 1 kernel (N×M -> N+M). The day a
hexa-native orbital kernel re-propagates these orbits, `absorbed=true`
flips HERE — once — instead of in every domain adapter.

## Honesty (g3)

Every value is a real SGP4 propagation result — SGP4 is the
NORAD-standard analytic propagator, Vallado-2006-validated against the
NORAD reference (~1 km positional accuracy at epoch). It is NOT a
model prediction. BUT SGP4 accuracy decays with TLE age (~1 km/day);
the kernel surfaces `tle_age_days` (via `tle_epoch_utc`) so the
adapter can gate on it. The honesty gate (`measurement_gate`,
`absorbed`, `scope_caveats`) lives in the ①b adapter, NOT here.
Skyfield + sgp4 are external libraries, so `absorbed = false` at the
record layer always.

## Callers

- `stdlib/space/skyfield_sgp4.py` — ISS + HST NORAD TLEs, Seoul
  ground observer, 24-hour propagation producer (demiurge
  `space+analyze`).

The adapter locates this kernel by path relative to its own file
(`../kernels/orbital/`), so the `python3 <script> <output_dir>` spawn
from demiurge works regardless of cwd.
