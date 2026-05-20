# stdlib/kernels/geodesy/geodesy_oracle.py — D80 pilot #13 parity companion
#
# Line-by-line Python `math` libm transliteration of
# stdlib/kernels/geodesy/wgs84_kernel.hexa. Used to capture the bit-exact
# `want` literals embedded in the .hexa parity test.
#
# CLEAN-ROOM provenance — no pyproj / GeographicLib / Proj4 / cartopy /
# geopandas / Skyfield source-code inspection. The three algorithms here
# are textbook closed-form (or textbook iteration) pre-dating every
# modern geodesy library by decades:
#
#   * WGS84 constants               — NIMA TR8350.2 (2000) Table 3.1
#   * Geodetic ↔ ECEF Cartesian     — Heiskanen & Moritz, "Physical
#                                     Geodesy" (Freeman 1967) §5-3
#                                     (forward closed-form); Bowring,
#                                     Survey Review 28(218):202-206
#                                     (1985) — accelerated iteration
#                                     for the inverse.
#   * Haversine great-circle        — Sinnott, "Virtues of the
#                                     Haversine", Sky & Telescope 68
#                                     (1984) 158.
#   * Vincenty inverse (ellipsoid)  — T. Vincenty, "Direct and Inverse
#                                     Solutions of Geodesics on the
#                                     Ellipsoid with Application of
#                                     Nested Equations", Survey Review
#                                     23(176):88-93 (1975).
#
# math.sin / math.cos / math.atan / math.atan2 / math.sqrt delegate to
# the same darwin-arm64 libm as the hexa runtime, so the per-operation
# IEEE-754 result is bit-identical and the composed values match at
# rel_err = 0.

import math


# ── WGS84 constants (NIMA TR8350.2) ───────────────────────────────────


def wgs84_a():
    """Semi-major axis [m]."""
    return 6378137.0


def wgs84_f():
    """Flattening (dimensionless)."""
    return 1.0 / 298.257223563


def wgs84_b():
    """Semi-minor axis [m] = a · (1 − f)."""
    return wgs84_a() * (1.0 - wgs84_f())


def wgs84_e2():
    """First eccentricity squared = 2f − f² = (a² − b²) / a²."""
    f = wgs84_f()
    return 2.0 * f - f * f


def wgs84_ep2():
    """Second eccentricity squared = (a² − b²) / b² = e² / (1 − e²)."""
    e2 = wgs84_e2()
    return e2 / (1.0 - e2)


# ── degree ↔ radian (textbook) ────────────────────────────────────────


def deg2rad(d):
    return d * math.pi / 180.0


def rad2deg(r):
    return r * 180.0 / math.pi


# ── geodetic (lat_rad, lon_rad, h_m) → ECEF (x, y, z) [m] ─────────────
#
# Closed-form, no iteration (Heiskanen & Moritz §5-3):
#   N(φ) = a / √(1 − e² · sin²φ)        prime-vertical radius of curvature
#   X = (N + h) · cosφ · cosλ
#   Y = (N + h) · cosφ · sinλ
#   Z = (N · (1 − e²) + h) · sinφ


def geodetic_to_ecef(lat_rad, lon_rad, h_m):
    a = wgs84_a()
    e2 = wgs84_e2()
    sin_lat = math.sin(lat_rad)
    cos_lat = math.cos(lat_rad)
    sin_lon = math.sin(lon_rad)
    cos_lon = math.cos(lon_rad)
    N = a / math.sqrt(1.0 - e2 * sin_lat * sin_lat)
    x = (N + h_m) * cos_lat * cos_lon
    y = (N + h_m) * cos_lat * sin_lon
    z = (N * (1.0 - e2) + h_m) * sin_lat
    return [x, y, z]


# ── ECEF (x, y, z) [m] → geodetic (lat_rad, lon_rad, h_m) ─────────────
#
# Bowring 1985 closed-form (1-iteration parametric latitude), Survey
# Review 28(218):202-206:
#
#   p   = √(X² + Y²)
#   λ   = atan2(Y, X)
#   tan β = (Z / p) · (a / b)   (initial parametric latitude estimate)
#   φ  = atan2(Z + e'² · b · sin³β, p − e² · a · cos³β)
#   N(φ) = a / √(1 − e² · sin²φ)
#   h  = p / cosφ − N         (for non-polar φ)
#
# Bowring's published bound is < 0.1 mm geodetic-latitude error for
# heights up to 10000 km — well below any 1e-10 relative tolerance for
# the (lat, lon, h) range used by satellites and survey work.


def ecef_to_geodetic(x, y, z):
    a = wgs84_a()
    b = wgs84_b()
    e2 = wgs84_e2()
    ep2 = wgs84_ep2()
    p = math.sqrt(x * x + y * y)
    lon = math.atan2(y, x)
    # parametric latitude initial estimate
    beta = math.atan2(z * a, p * b)
    sin_beta = math.sin(beta)
    cos_beta = math.cos(beta)
    lat = math.atan2(z + ep2 * b * sin_beta * sin_beta * sin_beta,
                     p - e2 * a * cos_beta * cos_beta * cos_beta)
    sin_lat = math.sin(lat)
    cos_lat = math.cos(lat)
    N = a / math.sqrt(1.0 - e2 * sin_lat * sin_lat)
    # height: standard formula away from the poles; near the pole use the
    # |z|/sin lat fallback so we don't divide by ≈0 cos_lat.
    if abs(cos_lat) > 1e-12:
        h = p / cos_lat - N
    else:
        h = abs(z) / abs(sin_lat) - N * (1.0 - e2)
    return [lat, lon, h]


# ── haversine great-circle (spherical) distance [m] ───────────────────
#
# Sinnott 1984. Uses the WGS84 mean Earth radius R = (2a + b)/3 to give
# a defensible spherical approximation. NOT ellipsoidal — for ellipsoidal
# distance use vincenty_inverse below.
#
#   Δφ = φ₂ − φ₁
#   Δλ = λ₂ − λ₁
#   a  = sin²(Δφ/2) + cosφ₁ · cosφ₂ · sin²(Δλ/2)
#   c  = 2 · asin(√a)        (asin form avoids the atan2 sign branch)
#   d  = R · c


def wgs84_mean_radius():
    # International Union of Geodesy and Geophysics R₁ = (2a + b) / 3.
    return (2.0 * wgs84_a() + wgs84_b()) / 3.0


def haversine(lat1_rad, lon1_rad, lat2_rad, lon2_rad):
    dphi = lat2_rad - lat1_rad
    dlam = lon2_rad - lon1_rad
    s_dphi = math.sin(dphi / 2.0)
    s_dlam = math.sin(dlam / 2.0)
    a_h = (s_dphi * s_dphi
           + math.cos(lat1_rad) * math.cos(lat2_rad) * s_dlam * s_dlam)
    # asin form: clamp inside [0, 1] before sqrt (numerical guard for
    # the antipodal case where a_h can land at 1.0 + 1ulp).
    if a_h < 0.0:
        a_h = 0.0
    if a_h > 1.0:
        a_h = 1.0
    c = 2.0 * math.asin(math.sqrt(a_h))
    return wgs84_mean_radius() * c


# ── Vincenty inverse (ellipsoidal distance + initial azimuth) ─────────
#
# T. Vincenty, Survey Review 23(176):88-93 (1975). Returns
# [distance_m, azimuth_initial_rad, azimuth_final_rad, iterations].
#
# Convergence: Vincenty proved a few iterations suffice except very
# near antipodal points (where the formula fails to converge). We use
# a max-iter cap of 200 and a λ-change tolerance of 1e-12 rad
# (≈ 6 micrometres at the equator — three orders of magnitude tighter
# than the D80 1e-10 ceiling).


def vincenty_inverse(lat1_rad, lon1_rad, lat2_rad, lon2_rad):
    a = wgs84_a()
    b = wgs84_b()
    f = wgs84_f()
    L = lon2_rad - lon1_rad
    U1 = math.atan((1.0 - f) * math.tan(lat1_rad))
    U2 = math.atan((1.0 - f) * math.tan(lat2_rad))
    sin_U1 = math.sin(U1)
    cos_U1 = math.cos(U1)
    sin_U2 = math.sin(U2)
    cos_U2 = math.cos(U2)
    lam = L
    iters = 0
    max_iters = 200
    tol = 1.0e-12
    sin_sig = 0.0
    cos_sig = 0.0
    sig = 0.0
    cos_2sig_m = 0.0
    cos_sq_alpha = 0.0
    while iters < max_iters:
        sin_lam = math.sin(lam)
        cos_lam = math.cos(lam)
        sin_sig = math.sqrt((cos_U2 * sin_lam) * (cos_U2 * sin_lam)
                            + (cos_U1 * sin_U2
                               - sin_U1 * cos_U2 * cos_lam)
                            * (cos_U1 * sin_U2
                               - sin_U1 * cos_U2 * cos_lam))
        if sin_sig == 0.0:
            # coincident points
            return [0.0, 0.0, 0.0, iters]
        cos_sig = sin_U1 * sin_U2 + cos_U1 * cos_U2 * cos_lam
        sig = math.atan2(sin_sig, cos_sig)
        sin_alpha = cos_U1 * cos_U2 * sin_lam / sin_sig
        cos_sq_alpha = 1.0 - sin_alpha * sin_alpha
        if cos_sq_alpha == 0.0:
            cos_2sig_m = 0.0
        else:
            cos_2sig_m = cos_sig - 2.0 * sin_U1 * sin_U2 / cos_sq_alpha
        C = f / 16.0 * cos_sq_alpha * (4.0 + f * (4.0 - 3.0 * cos_sq_alpha))
        lam_prev = lam
        lam = L + (1.0 - C) * f * sin_alpha * (
            sig + C * sin_sig * (
                cos_2sig_m + C * cos_sig * (
                    -1.0 + 2.0 * cos_2sig_m * cos_2sig_m)))
        iters += 1
        if abs(lam - lam_prev) < tol:
            break
    u_sq = cos_sq_alpha * (a * a - b * b) / (b * b)
    A = 1.0 + u_sq / 16384.0 * (
        4096.0 + u_sq * (-768.0 + u_sq * (320.0 - 175.0 * u_sq)))
    B = u_sq / 1024.0 * (256.0 + u_sq * (-128.0 + u_sq * (74.0 - 47.0 * u_sq)))
    delta_sig = B * sin_sig * (
        cos_2sig_m + B / 4.0 * (
            cos_sig * (-1.0 + 2.0 * cos_2sig_m * cos_2sig_m)
            - B / 6.0 * cos_2sig_m
            * (-3.0 + 4.0 * sin_sig * sin_sig)
            * (-3.0 + 4.0 * cos_2sig_m * cos_2sig_m)))
    s = b * A * (sig - delta_sig)
    sin_lam_final = math.sin(lam)
    cos_lam_final = math.cos(lam)
    alpha1 = math.atan2(cos_U2 * sin_lam_final,
                        cos_U1 * sin_U2 - sin_U1 * cos_U2 * cos_lam_final)
    alpha2 = math.atan2(cos_U1 * sin_lam_final,
                        -sin_U1 * cos_U2 + cos_U1 * sin_U2 * cos_lam_final)
    return [s, alpha1, alpha2, iters]


# ──────────────────────────────────────────────────────────────────────
# Capture the want-literals for the .hexa parity test.
# ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    def fmt(x):
        return f"{x:.17e}"

    print("# WGS84 constants")
    print(f"a   = {fmt(wgs84_a())}")
    print(f"f   = {fmt(wgs84_f())}")
    print(f"b   = {fmt(wgs84_b())}")
    print(f"e2  = {fmt(wgs84_e2())}")
    print(f"ep2 = {fmt(wgs84_ep2())}")
    print(f"Rm  = {fmt(wgs84_mean_radius())}")
    print()

    print("# Geodetic → ECEF reference points")
    points = [
        ("equator-Greenwich (0,0,0)",        0.0,        0.0,    0.0),
        ("North Pole (90,0,0)",              90.0,       0.0,    0.0),
        ("NIST Boulder (39.9931, -105.2624, 1650)",
                                             39.9931, -105.2624, 1650.0),
        ("CERN Geneva (46.2333, 6.0500, 432)",
                                             46.2333,    6.0500, 432.0),
        ("Sydney Opera (-33.8568, 151.2153, 10)",
                                            -33.8568, 151.2153,   10.0),
        ("ISS-altitude over equator (0, 0, 400e3)",
                                             0.0,        0.0, 400000.0),
    ]
    for name, lat_d, lon_d, h in points:
        lat = deg2rad(lat_d)
        lon = deg2rad(lon_d)
        xyz = geodetic_to_ecef(lat, lon, h)
        print(f"# {name}")
        print(f"#   lat_d={lat_d}  lon_d={lon_d}  h_m={h}")
        print(f"x   = {fmt(xyz[0])}")
        print(f"y   = {fmt(xyz[1])}")
        print(f"z   = {fmt(xyz[2])}")
        # round-trip
        rt = ecef_to_geodetic(xyz[0], xyz[1], xyz[2])
        print(f"rt_lat_d = {fmt(rad2deg(rt[0]))}")
        print(f"rt_lon_d = {fmt(rad2deg(rt[1]))}")
        print(f"rt_h_m   = {fmt(rt[2])}")
        print()

    print("# Haversine pairs (great-circle, spherical with R_mean)")
    pairs = [
        ("equator quarter (0,0) → (0,90)",
            (0.0, 0.0), (0.0, 90.0)),
        ("equator antipode (0,0) → (0,180)",
            (0.0, 0.0), (0.0, 180.0)),
        ("pole-equator (90,0) → (0,0)",
            (90.0, 0.0), (0.0, 0.0)),
        ("Boulder → CERN",
            (39.9931, -105.2624), (46.2333, 6.0500)),
        ("Boulder → Sydney Opera",
            (39.9931, -105.2624), (-33.8568, 151.2153)),
    ]
    for name, (lat1_d, lon1_d), (lat2_d, lon2_d) in pairs:
        d = haversine(deg2rad(lat1_d), deg2rad(lon1_d),
                      deg2rad(lat2_d), deg2rad(lon2_d))
        print(f"# {name}")
        print(f"d_m = {fmt(d)}")

    print()
    print("# Vincenty inverse pairs (ellipsoidal)")
    vpairs = [
        ("Boulder → CERN",
            (39.9931, -105.2624), (46.2333, 6.0500)),
        ("Boulder → Sydney Opera",
            (39.9931, -105.2624), (-33.8568, 151.2153)),
        ("equator quarter (0,0) → (0,90)",
            (0.0, 0.0), (0.0, 90.0)),
        ("pole-equator (90,0) → (0,0)",
            (89.999999, 0.0), (0.000001, 0.0)),  # avoid exact pole singularity in tan
    ]
    for name, (lat1_d, lon1_d), (lat2_d, lon2_d) in vpairs:
        res = vincenty_inverse(deg2rad(lat1_d), deg2rad(lon1_d),
                               deg2rad(lat2_d), deg2rad(lon2_d))
        print(f"# {name}")
        print(f"s_m   = {fmt(res[0])}")
        print(f"az1   = {fmt(res[1])}")
        print(f"az2   = {fmt(res[2])}")
        print(f"iters = {res[3]}")
