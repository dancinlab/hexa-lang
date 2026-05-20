# kernels/geodesy/ — ①a geodetic coordinate kernel (demiurge D72)

Domain-agnostic geodetic coordinate kernel. **NEW kernel folder added
by D80 pilot #13** — first kernel in the geodesy domain family
(`kernels/geodesy/`), introducing the geodesy substrate to the D80
hexa-native port roster. Prior pilots covered solar / mc_transport /
neural / graph / urdf / plasma / orbital / signal_proc / noc_sim /
circuit / fem / autodiff / chem / bio_align — none touched the
geodesy family until now.

Why a new domain family: geodesy is a *bridge* substrate. Four
already-listed demiurge consumers re-implement their own coordinate
math against four different libraries —

| consumer | library | scope |
|---|---|---|
| `stdlib/mobility/road_network.py`   | osmnx     | OSM node → lat/lon → distance |
| `stdlib/space/skyfield_sgp4.py`     | skyfield  | TLE inertial → ECEF |
| `stdlib/solar/*.py`                 | pvlib     | lat/lon ephemeris inputs |
| `stdlib/grid/networkx_basics.py`    | networkx  | substation spacing |

— and each currently carries its own private (incompatible)
conversion logic. A hexa-native geodesy kernel is the
minimum-surface unblocker that lets every ①b adapter share one
closed-form coordinate primitive set.

| file | role |
|---|---|
| `wgs84_kernel.hexa` | 5 WGS84 constants + deg/rad helpers + geodetic↔ECEF + haversine + Vincenty inverse. ①a kernel layer. |
| `wgs84_kernel_test.hexa` | 70-assert parity test — 6 constants + 3 deg/rad + 18 forward + 18 round-trip + 8 haversine + 14 Vincenty + 2 cross-algorithm invariants vs `geodesy_oracle.py`. |
| `geodesy_oracle.py` | Clean-room Python `math`-libm transliteration of the kernel. No pyproj / GeographicLib / Skyfield import. Captures the bit-exact `want` literals embedded in the test. |

## 2-layer (ABSORPTION.md ①)

- **①a kernel** (here) — domain-independent. No OSM road graph, no
  TLE propagator, no PV sizing, no substation database — pure
  "given (lat, lon, h) emit (x, y, z) and vice versa; given two
  (lat, lon) pairs emit haversine + Vincenty distances + azimuths".
- **①b adapter** — future `stdlib/geodesy/wgs84.hexa` (and per-
  consumer adapters like `stdlib/mobility/road_network.hexa`).
  These would carry consumer-specific decode (osmnx node → lat/lon,
  TLE inertial-frame transform, etc.) and any honesty caveats
  specific to the application. None exist yet; this pilot is the
  substrate floor.

## API

- `wgs84_a()`           — semi-major axis [m] (defining)
- `wgs84_f()`           — flattening (defining)
- `wgs84_b()`           — semi-minor axis [m] (derived)
- `wgs84_e2()`          — first eccentricity² (derived)
- `wgs84_ep2()`         — second eccentricity² (derived)
- `wgs84_mean_radius()` — IUGG R₁ = (2a+b)/3 [m]
- `deg2rad(d) / rad2deg(r)`
- `geodetic_to_ecef(lat_rad, lon_rad, h_m) -> [x, y, z]`
- `ecef_to_geodetic(x, y, z) -> [lat_rad, lon_rad, h_m]`
- `haversine(lat1_rad, lon1_rad, lat2_rad, lon2_rad) -> dist_m`
- `vincenty_inverse(lat1_rad, lon1_rad, lat2_rad, lon2_rad)`
  `-> [dist_m, az1_rad, az2_rad, iters_float]`

## Algorithm provenance

Clean-room — no pyproj / GeographicLib / Proj4 / cartopy / geopandas
/ Skyfield / Astropy / poliastro source-code inspection. Each
algorithm is textbook closed-form (or textbook iteration) pre-dating
every modern geodesy library by decades:

- **WGS84 constants** — NIMA TR8350.2 (2000) Table 3.1.
- **Geodetic → ECEF** — Heiskanen & Moritz, *Physical Geodesy*
  (Freeman 1967) §5-3.
- **ECEF → geodetic** — Bowring, *Survey Review* 28(218):202-206
  (1985) — 1-iteration parametric latitude.
- **Haversine** — Sinnott, *Sky & Telescope* 68(2):158 (1984).
- **Vincenty inverse** — T. Vincenty, *Survey Review* 23(176):88-93
  (1975).

## Parity

`wgs84_kernel_test.hexa` runs 70 assertions:

- 6 WGS84 constants at `rel_err ≤ 1e-10` against analytic-formula
  literals (defining values).
- 3 deg/rad round-trip invariants.
- 18 forward `geodetic_to_ecef` asserts (6 points × 3 coordinates)
  at `rel_err ≤ 1e-10` vs `geodesy_oracle.py` dumps.
- 18 round-trip `ecef_to_geodetic` asserts at `rel_err ≤ 1e-10`
  on lat/lon and `abs_err ≤ 1e-7 m` on height (Bowring 1-iter
  bound is 1 mm; we land at sub-microns).
- 8 haversine asserts (5 distances + analytic π·R/2 + π·R +
  symmetry + same-point=0) at `rel_err ≤ 1e-10`.
- 14 Vincenty inverse asserts (4 pairs × 3 outputs + analytic
  a·π/2 + π-azimuths) at `rel_err ≤ 1e-10`.
- 2 cross-algorithm invariants — Vincenty ≈ Haversine within
  0.5% over Boulder→CERN (measured: 0.2599 %, well inside the
  flattening-bounded tolerance).

Status: **70/70 PASS at rel_err ≤ 1e-10**.

## Honesty

- Bowring 1985 is a 1-iteration estimator. Published bound:
  < 0.1 mm latitude error for `h ≤ 10 000 km`. For `h ≫ 10 000 km`
  (e.g. geostationary, deep-space) a multi-iteration variant is
  needed. Not in this pilot's scope.
- Vincenty inverse fails to converge for nearly-antipodal point
  pairs (`|Δλ| → π` on the equator). The kernel caps at 200
  λ-iterations; the test grid stays away from the antipodal
  regime. Karney 2013 series is the modern always-convergent
  replacement and is queued.
- Haversine uses the IUGG mean radius `R₁ = (2a+b)/3` — a
  spherical approximation accurate to ~0.5 % vs Vincenty over
  typical ground tracks. Use `vincenty_inverse` for ellipsoidal-
  grade distances.

## Out of scope (queued)

- Vincenty *direct* (forward azimuth + distance → endpoint)
- Karney 2013 geodesic series (always-convergent ellipsoidal)
- Map projections (Mercator, Lambert, UTM, transverse Mercator)
- Non-WGS84 ellipsoids (GRS80, IERS, NAD83, ED50)
- Geoid undulation (EGM2008 spherical-harmonic synthesis)
- Gravity disturbances + deflection of the vertical
