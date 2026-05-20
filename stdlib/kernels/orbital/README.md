# kernels/orbital/ — ①a orbital-mechanics kernel (demiurge design.md D72)

Domain-agnostic orbital-mechanics computation kernel. The THIRD kernel
extracted under the D72 2-layer STDLIB restructure (after
`kernels/graph/` and `kernels/fem/`).

| file | role |
|---|---|
| `sgp4_kernel.py` | `propagate_track` · `tle_epoch_utc` · `tle_text_hash` · `skyfield_version` · `sgp4_version` · `versions` — given a TLE + an observer + a sample window, propagate the orbit (SGP4) and reduce it to a topocentric track. |
| `kepler_2body_kernel.hexa` | D80 g_hexa_only pilot #3 — clean-room hexa-native closed-form Kepler 2-body propagator (`propagate(mu, a, ecc, t) -> [E, ν, r, x, y]`). Newton-Raphson 5-step on M = E − e·sin(E); textbook half-angle ν / r reduction. <1e-12 relative parity vs Python `math` libm on a 5-sample × 4-ecc LEO test grid (`kepler_2body_kernel_test.hexa`, 27/27 PASS). |

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

## D80 hexa-native pilot (`kepler_2body_kernel.hexa`)

`kepler_2body_kernel.hexa` follows the D80 `g_hexa_only`
ultimate-form pattern alongside `stdlib/kernels/solar/`,
`stdlib/kernels/mc_transport/`, `stdlib/kernels/graph/`,
`stdlib/kernels/neural/`, and `stdlib/kernels/urdf/`. Scope is
*deliberately small*: the unperturbed two-body closed form
(Kepler equation + half-angle ν reduction + perifocal cartesian) —
not the full SGP4 mean-element propagation. That keeps the first
orbital `.hexa` port reviewable; a future hexa-native SGP4 port
would call this kernel as its inner closed-form solver.

API (hexa):

```hexa
use "stdlib/kernels/orbital/kepler_2body_kernel"
let r = propagate(mu, a, ecc, t)   // -> [E, ν, r, x, y]
```

- `kepler_solve_E(M, ecc, n_iters)` — fixed-count Newton-Raphson on
  M = E − e·sin(E). 5 iterations saturate double precision for
  e ≤ 0.7 from the seed E₀ = M (quadratic convergence).
- `mean_anomaly(mu, a, t)` — M = sqrt(μ/a³)·t (unwrapped; the
  internal `wrap_pi` in `kepler_solve_E` reduces to (-π, π]).
- `true_anomaly(E, ecc)` — ν = 2·atan2(√(1+e)·sin(E/2),
  √(1−e)·cos(E/2)).
- `radius(a, ecc, E)` — r = a·(1 − e·cos E).
- `propagate(mu, a, ecc, t)` — full pipeline; returns 5-float
  `[E, ν, r, x, y]` in perifocal (P-Q) coordinates.

Parity (`kepler_2body_kernel_test.hexa`, 27/27 PASS):
LEO orbit (a=7000 km, μ=GM_earth) sampled at 5 (e, t/T) picks
covering circular, near-circular, moderate, and high (e=0.7)
eccentricity — including apoapsis (M=π boundary) and post-π
wrap (negative-M Newton-Raphson seed). On all 5 picks the
hexa-native and Python `math` libm closed-form values agree
bit-for-bit (rel = 0.0 measured; assertion ceiling 1e-10
exceeds the actual gap by ~12 orders). Two invariant checks
(ν = E at e=0; conic r(ν) = a(1−e²)/(1+e·cos ν)) round out the
suite.

Scope / honesty (g3):
- elliptical only (0 ≤ e < 1). Parabolic / hyperbolic Kepler is
  a separate solve (M = e·sinh F − F) — not in scope here.
- two-body point-mass model — no J2, no drag, no third-body, no
  SRP. SGP4 (`sgp4_kernel.py`) is still the ①a kernel for real
  satellite work; this is the *unperturbed baseline* + future-port
  inner solver.
- Substrate parity proves the PORT PATTERN; D80 record-layer
  `absorbed=true` flip on a real measurement cell still requires
  the demiurge `HexaNativeParityRef` schema + a measured ephemeris
  oracle (out of scope here).
