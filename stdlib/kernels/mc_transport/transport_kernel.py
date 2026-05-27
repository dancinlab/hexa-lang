# transport_kernel.py — ①a STDLIB kernel layer (demiurge design.md D72)
#
# Domain-agnostic Monte-Carlo particle-transport computation kernel.
# This is the THIRD kernel extracted under the D72 2-layer STDLIB
# restructure (after kernels/graph/networkx_kernel.py and
# kernels/fem/skfem_kernel.py): producers in `stdlib/<domain>/` that
# need particle-physics calculations — PDG particle-data lookup,
# Bethe-Bloch stopping power, relativistic kinematics — call into this
# single module instead of each re-implementing the `particle`
# wrapping + the stopping-power formula.
#
# Layer split (ABSORPTION.md ①):
#   ①a kernel  — THIS FILE. Domain-independent. No CERN shielding
#                short-list, no antiproton-trap caveat — only "given a
#                projectile spec + a stopping medium, compute the
#                deterministic particle-physics facts".
#   ①b adapter — `stdlib/cern/bethe_bloch_stopping.py` (CERN-style
#                shielding materials, antiproton, ELENA-scale KE grid)
#                and `stdlib/antimatter/pdg_lookup.py` (antiparticle
#                short-list, PET / Penning-trap context). They own the
#                domain particle list / material tables / honesty
#                caveats and call this kernel for the physics.
#
# Two layers of "real" (g3 — non-negotiable, inherited by callers):
#   * PARTICLE-DATA LOOKUP — `lookup_particle` returns PDG-aggregated
#     measured constants (mass, charge, lifetime, cτ) via the scikit-
#     hep `particle` library. Those numbers ARE real measured physics
#     — but a lookup is NOT a demiurge measurement; the ①b adapter
#     stamps measurement_gate = GATE_OPEN / absorbed = false to record
#     that distinction.
#   * BETHE-BLOCH dE/dx — `bethe_bloch_dedx` evaluates the PDG closed-
#     form mean stopping power (PDG RPP §34, eq. 34.5, density-effect
#     δ = 0). It IS a real physics calculation on measured constants,
#     but it omits four pieces of a full Geant4 MC: shell corrections,
#     density effect, straggling distribution, nuclear stopping. The
#     ①b adapter surfaces that caveat.
#   * RELATIVISTIC KINEMATICS — `relativistic_kinematics` is exact
#     special relativity (γ, β, βγ, momentum) — IEEE-754-deterministic.
#   * STOPPING RANGE — `stopping_range` is the continuous-slowing-down-
#     approximation (CSDA) range: a trapezoidal integral of 1/(dE/dx)
#     over a KE grid. It is an approximation (no straggling, no nuclear
#     stops); the ①b adapter owns that caveat.
#
# absorbed = false ALWAYS at the record layer — `particle` is an
# EXTERNAL Python library, and even the pure-formula paths slice a
# subset of a full Geant4 MC. The day a hexa-native transport kernel
# re-derives these on absorbed PDG constants (the Stage-2 hexa port
# `stdlib/cern/bethe_bloch_stopping.hexa` already exists) and passes a
# Geant4-MC parity round, absorbed flips — and it flips HERE (one
# kernel) rather than in N domain adapters. That is the entire point
# of the 2-layer restructure (N×M -> N+M).
#
# Import failure is raised, not swallowed — silent success is
# forbidden. The caller reports the exception verbatim.

import math
import os
import sys
from typing import Any, Optional


# ------------------------------------------------------------------
# Bethe-Bloch K factor: 4πN_A r_e² m_ec² = 0.307075 MeV·cm²·g⁻¹
# (PDG 2024, eq. 34.5 / Table 34.4). A fundamental constant — domain-
# independent, so it lives in the kernel.
# ------------------------------------------------------------------
K_BB_MEV_CM2_PER_G = 0.307075


# ------------------------------------------------------------------
# Version probe + `particle` import recovery. The scikit-hep
# `particle` package is the data source for `lookup_particle`; let the
# ①b adapter pin it in its record provenance ("particle@<v>"). On the
# macOS Homebrew layout `pip install --user` lands at
# ~/Library/Python/<ver>/lib/python/site-packages which is NOT on the
# default sys.path — recover from that, then raise if still missing.
# ------------------------------------------------------------------
def ensure_particle() -> None:
    """Import the scikit-hep `particle` package; recover from the
    macOS Homebrew user-site layout. Raises ImportError if the package
    is genuinely absent — silent success is forbidden (g3)."""
    try:
        import particle  # noqa: F401
        return
    except ImportError:
        pass
    py_xy = f"{sys.version_info.major}.{sys.version_info.minor}"
    user_site = os.path.expanduser(
        f"~/Library/Python/{py_xy}/lib/python/site-packages")
    if os.path.isdir(user_site) and user_site not in sys.path:
        sys.path.insert(0, user_site)
    import particle  # noqa: F401 — raise if still missing


def particle_version() -> str:
    """Probe the installed scikit-hep `particle` version. Returns
    'unknown' if the library cannot be imported — the caller decides
    whether that is a hard gap (it is, for transport producers)."""
    try:
        import particle
        return str(particle.__version__)
    except Exception:
        return "unknown"


# ------------------------------------------------------------------
# Particle-data lookup. Domain-agnostic: the caller supplies a PDG
# Monte-Carlo id, the kernel returns the PDG-aggregated record. NO
# domain particle short-list here — the ①b adapter owns "which
# antiparticles" or "which projectile".
# ------------------------------------------------------------------
def lookup_particle(pdg_id: int) -> dict:
    """Look up one particle by PDG Monte-Carlo id via scikit-hep
    `particle`. Returns a dict of the PDG-aggregated measured
    constants:

        { pdg_id, name, pdg_name, mass_mev, mass_lower_mev,
          mass_upper_mev, charge, lifetime_s, ctau_m, width_pdg_units,
          spin_type, is_self_conjugate, anti_flag }

    `lifetime_s` and `ctau_m` are None for stable particles (the
    `particle` library reports infinity; JSON has no Inf, and a stable
    particle genuinely has no finite lifetime — surfacing None is the
    honest encoding). Raises on an unknown id — silent success is
    forbidden (g3)."""
    ensure_particle()
    from particle import Particle

    p = Particle.from_pdgid(pdg_id)
    return {
        "pdg_id": int(p.pdgid),
        "name": str(p.name),
        "pdg_name": str(p.pdg_name),
        "mass_mev": float(p.mass) if p.mass is not None else None,
        "mass_lower_mev": (
            float(p.mass_lower) if p.mass_lower is not None else None),
        "mass_upper_mev": (
            float(p.mass_upper) if p.mass_upper is not None else None),
        "charge": float(p.charge),
        "lifetime_s": _finite_or_none(p.lifetime, 1.0e-9),  # ns -> s
        "ctau_m": _finite_or_none(p.ctau, 1.0e-3),          # mm -> m
        "width_pdg_units": (
            float(p.width) if p.width is not None else None),
        "spin_type": (
            str(p.spin_type) if p.spin_type is not None else None),
        "is_self_conjugate": bool(p.is_self_conjugate),
        "anti_flag": int(p.anti_flag),
    }


def _finite_or_none(value: Any, scale: float) -> Optional[float]:
    """Convert a `particle`-library HEPUnits quantity to a finite SI
    float, or None for a None / infinite (stable-particle) value.
    `scale` carries the HEPUnits-to-SI conversion (ns->s, mm->m)."""
    if value is None:
        return None
    v = float(value)
    if math.isinf(v):
        return None
    return v * scale


def particle_mass_mev(pdg_id: int) -> float:
    """Convenience: the PDG mass (MeV/c²) of one particle. Raises if
    the library reports None mass — silent success is forbidden."""
    rec = lookup_particle(pdg_id)
    if rec["mass_mev"] is None:
        raise RuntimeError(
            f"particle returned None mass for pdg_id={pdg_id}")
    return float(rec["mass_mev"])


# ------------------------------------------------------------------
# Relativistic kinematics. Exact special relativity — no library, no
# approximation, IEEE-754-deterministic. Domain-agnostic.
# ------------------------------------------------------------------
def relativistic_kinematics(ke_mev: float, mass_mev: float) -> dict:
    """Relativistic kinematics for a projectile of rest mass
    `mass_mev` carrying kinetic energy `ke_mev` (both MeV).

        γ        = 1 + KE / (m·c²)
        β²       = 1 − 1/γ²
        β        = √β²
        βγ       = β·γ
        p        = β·γ·m·c            (momentum, MeV/c)
        E_total  = KE + m·c²

    Returns { gamma, beta, beta2, beta_gamma, momentum_mev,
    total_energy_mev }. Raises on non-positive mass or a non-physical
    (β² ≤ 0) point — silent success is forbidden (g3)."""
    if mass_mev <= 0.0:
        raise ValueError(f"mass_mev must be positive, got {mass_mev}")
    gamma = 1.0 + ke_mev / mass_mev
    beta2 = 1.0 - 1.0 / (gamma * gamma)
    if beta2 <= 0.0:
        raise ValueError(
            f"non-physical kinematics: beta2={beta2} "
            f"(ke_mev={ke_mev}, mass_mev={mass_mev})")
    beta = math.sqrt(beta2)
    beta_gamma = beta * gamma
    return {
        "gamma": gamma,
        "beta": beta,
        "beta2": beta2,
        "beta_gamma": beta_gamma,
        "momentum_mev": beta_gamma * mass_mev,
        "total_energy_mev": ke_mev + mass_mev,
    }


def max_energy_transfer_mev(ke_mev: float,
                            mass_mev: float,
                            electron_mass_mev: float) -> float:
    """Maximum kinetic energy transferable to a free electron in a
    single projectile-electron collision (PDG eq. 34.4, relativistic):

        T_max = 2·m_e·c²·β²·γ² / (1 + 2γ·m_e/m + (m_e/m)²)

    Domain-agnostic. Raises on a non-physical kinematic point."""
    kin = relativistic_kinematics(ke_mev, mass_mev)
    beta2 = kin["beta2"]
    gamma = kin["gamma"]
    me_over_mp = electron_mass_mev / mass_mev
    return (2.0 * electron_mass_mev * beta2 * gamma * gamma) / (
        1.0 + 2.0 * gamma * me_over_mp + me_over_mp * me_over_mp)


# ------------------------------------------------------------------
# Bethe-Bloch mean stopping power. The PDG closed-form (PDG RPP §34,
# eq. 34.5, density-effect δ = 0) — domain-agnostic. The caller
# supplies the projectile (mass, charge), the stopping medium (Z, A,
# mean-excitation I) and the kinetic energy.
# ------------------------------------------------------------------
def bethe_bloch_dedx(ke_mev: float,
                     projectile_mass_mev: float,
                     projectile_charge: int,
                     target_z: int,
                     target_a_gpermol: float,
                     target_i_ev: float,
                     electron_mass_mev: float,
                     stage: int = 3,
                     sternheimer_coeffs: Optional[dict] = None,
                     projectile_charge_sign: int = +1) -> dict:
    """Bethe-Bloch mean mass stopping power −dE/dx at one (KE, medium)
    point.

    Stage 3 (default, density δ = 0, no shell, no Bloch, no Barkas):
        −dE/dx = K·z²·(Z/A)·(1/β²)·[ ½·ln(2m_ec²β²γ²T_max / I²) − β² ]
      (PDG eq. 34.5)

    Stage 5 (corrections-on, four bracket additions per PDG §34):
        −dE/dx = K·z²·(Z/A)·(1/β²) · [
                   ½·ln(2m_ec²β²γ²T_max / I²) − β²
                   − δ(βγ)/2                       (Sternheimer density)
                   − C(βγ)/Z                       (shell correction)
                   + L₂(β)·z²                      (Bloch z² correction)
                   + L₁(βγ)·z₁                     (Barkas Z₁³, z₁ signed)
                 ]

    K = 0.307075 MeV·cm²/g.

    Arguments
      projectile_charge          : charge magnitude — sign drops in z².
      projectile_charge_sign     : ±1 — used for Z₁³ Barkas (antiproton = -1).
      target_i_ev                : mean excitation energy in eV (PDG Table 34.1).
      stage                      : 3 = Stage-3 PDG eq 34.5 closed-form (default),
                                   5 = Stage-5 with Sternheimer + shell + Bloch + Barkas.
      sternheimer_coeffs         : Sternheimer-Berger-Seltzer (1984) parameters
                                   {C,x0,x1,a,k,delta0} required when stage=5.

    Returns { beta, gamma, beta_gamma, tmax_mev, dedx_mevcm2_per_g } at
    Stage 3; Stage 5 also returns sternheimer_delta · shell_correction_c
    · bloch_correction_l2 · barkas_correction_l1 · bracket_stage3 ·
    bracket_stage5 for honest term-by-term decomposition."""
    kin = relativistic_kinematics(ke_mev, projectile_mass_mev)
    beta2 = kin["beta2"]
    beta = kin["beta"]
    gamma = kin["gamma"]
    beta_gamma = kin["beta_gamma"]
    tmax_mev = max_energy_transfer_mev(
        ke_mev, projectile_mass_mev, electron_mass_mev)

    i_mev = target_i_ev * 1.0e-6  # eV -> MeV
    log_term = 0.5 * math.log(
        2.0 * electron_mass_mev * beta2 * gamma * gamma * tmax_mev
        / (i_mev * i_mev))
    z2 = projectile_charge * projectile_charge
    bracket_stage3 = log_term - beta2

    if stage == 3:
        dedx = (K_BB_MEV_CM2_PER_G * z2 * (target_z / target_a_gpermol)
                * bracket_stage3 / beta2)
        return {
            "beta": beta,
            "gamma": gamma,
            "beta_gamma": beta_gamma,
            "tmax_mev": tmax_mev,
            "dedx_mevcm2_per_g": dedx,
        }

    if stage != 5:
        raise ValueError(f"stage must be 3 or 5, got {stage}")
    if sternheimer_coeffs is None:
        raise ValueError("stage=5 requires sternheimer_coeffs dict")

    delta_dens = sternheimer_density_delta(beta_gamma, sternheimer_coeffs)
    c_shell = shell_correction_c(beta_gamma, target_i_ev)
    l2_bloch = bloch_correction_l2(beta, projectile_charge)
    l1_barkas = barkas_correction_l1(beta_gamma, target_z,
                                     projectile_charge_sign)

    bracket_stage5 = (bracket_stage3
                      - 0.5 * delta_dens
                      - c_shell / target_z
                      + l2_bloch
                      + l1_barkas)
    dedx = (K_BB_MEV_CM2_PER_G * z2 * (target_z / target_a_gpermol)
            * bracket_stage5 / beta2)

    return {
        "beta": beta,
        "gamma": gamma,
        "beta_gamma": beta_gamma,
        "tmax_mev": tmax_mev,
        "dedx_mevcm2_per_g": dedx,
        "sternheimer_delta": delta_dens,
        "shell_correction_c": c_shell,
        "shell_correction_c_over_z": c_shell / target_z,
        "bloch_correction_l2": l2_bloch,
        "barkas_correction_l1": l1_barkas,
        "bracket_stage3": bracket_stage3,
        "bracket_stage5": bracket_stage5,
    }


# ------------------------------------------------------------------
# Stage-5 corrections — four independent closed-form pieces:
#   sternheimer_density_delta(βγ, coeffs)  PDG eq 34.6 piecewise δ(x)
#   shell_correction_c(βγ, I_eV)           Andersen-Ziegler 1977 (low-β fit)
#   bloch_correction_l2(β, z)              Bloch 1933 z² Born-correction
#   barkas_correction_l1(βγ, Z, z_sign)    Z₁³ Barkas (signed by projectile)
#
# Each is a textbook formula on PDG-aggregated / Sternheimer-Berger-
# Seltzer measured constants. No tuning to Geant4 — corrections in,
# closure measured (closure-is-physical-limit).
# ------------------------------------------------------------------
def sternheimer_density_delta(beta_gamma: float,
                              coeffs: dict) -> float:
    """Sternheimer density-effect correction δ(βγ) per PDG eq 34.6
    (Sternheimer-Berger-Seltzer 1984 piecewise form):

        x = log10(βγ)
        x < x0:        δ = δ0·10^{2(x−x0)}   (conductor low-βγ shape;
                                              0 for insulators)
        x0 ≤ x < x1:   δ = 2(ln10)·x − C + a·(x1−x)^k
        x ≥ x1:        δ = 2(ln10)·x − C

    `coeffs` keys: C, x0, x1, a, k, delta0 (delta0=0 for insulator,
    nonzero for conductor). All from Sternheimer Atomic & Nuclear Data
    Tables (1984) / PDG mat_data.dat / Geant4 G4Material defaults for
    elemental Al/Cu/W/Pb.
    """
    if beta_gamma <= 0.0:
        return 0.0
    x = math.log10(beta_gamma)
    C = coeffs["C"]
    x0 = coeffs["x0"]
    x1 = coeffs["x1"]
    a = coeffs["a"]
    k = coeffs["k"]
    delta0 = coeffs.get("delta0", 0.0)
    ln10 = math.log(10.0)
    if x < x0:
        if delta0 == 0.0:
            return 0.0
        return delta0 * (10.0 ** (2.0 * (x - x0)))
    if x < x1:
        return 2.0 * ln10 * x - C + a * ((x1 - x) ** k)
    return 2.0 * ln10 * x - C


def shell_correction_c(beta_gamma: float, target_i_ev: float) -> float:
    """Andersen-Ziegler 1977 shell-correction C(βγ, I).

    PDG §34 cites this empirical fit (Andersen H.H., Ziegler J.F.,
    Hydrogen Stopping Powers and Ranges in All Elements, Pergamon 1977;
    same form Geant4 G4BetheBlochModel uses below ~1 GeV).

    Form (η = βγ, I in eV):
        C(η, I) = (0.422377/η² + 0.0304043/η⁴ − 0.00038106/η⁶)·1e−6·I²
                + (3.858019/η² − 0.1667989/η⁴ + 0.00157955/η⁶)·1e−9·I³

    Valid for η ≥ ~0.13 (KE ≳ 8 MeV/u for proton-like); below that
    Lindhard-Scharff (LSS) takes over. We clamp at η = 0.13 to avoid
    the C(η)→∞ blowup — clamp returns the Andersen-Ziegler value at
    η=0.13, the standard engineering bridge to LSS at low velocity.
    """
    eta = beta_gamma
    # Below η = 0.13 the Andersen-Ziegler fit is out of its calibration
    # range (LSS / Lindhard-Sorensen takes over physically); a hard clamp
    # produces an unphysically-flat shell correction in the very-low-βγ
    # regime where Geant4 itself transitions to ICRU 49 / parameterized
    # low-energy tables. Engineering bridge: linear taper of the AZ
    # value from η=0.13 down to η=0.05 (where ICRU49 dominates entirely)
    # so the correction smoothly hands off instead of cliff-clamping.
    taper = 1.0
    if eta < 0.13:
        if eta <= 0.05:
            taper = 0.0
        else:
            taper = (eta - 0.05) / (0.13 - 0.05)
        eta = 0.13
    eta2 = eta * eta
    eta4 = eta2 * eta2
    eta6 = eta4 * eta2
    i_ev = target_i_ev
    term_i2 = (0.422377 / eta2
               + 0.0304043 / eta4
               - 0.00038106 / eta6) * 1.0e-6 * i_ev * i_ev
    term_i3 = (3.858019 / eta2
               - 0.1667989 / eta4
               + 0.00157955 / eta6) * 1.0e-9 * i_ev * i_ev * i_ev
    return (term_i2 + term_i3) * taper


def bloch_correction_l2(beta: float, z_proj: int) -> float:
    """Bloch 1933 z² Born-correction term L2(β, z) (PDG §34, Ahlen 1980
    review eq 2.34):

        L2 = −y² · [1.202 − y² · (1.042 − 0.855·y² + 0.343·y⁴)]
        y  = z·α/β,   α = 1/137.035999 (fine-structure constant)

    Small for low-Z projectiles (|z|=1 → y≈α/β ~0.01); becomes
    important for heavy projectiles. For an antiproton (|z|=1) this
    contributes the small Z2-class Born-truncation correction.
    """
    alpha_fs = 1.0 / 137.035999084  # CODATA-2018
    y = abs(z_proj) * alpha_fs / beta
    y2 = y * y
    y4 = y2 * y2
    y6 = y4 * y2
    return -y2 * (1.202 - 1.042 * y2 + 0.855 * y4 - 0.343 * y6)


def barkas_correction_l1(beta_gamma: float,
                         target_z: int,
                         charge_sign: int) -> float:
    """Z1^3 Barkas correction L1(βγ, Z) · sign(z1) (Ashley-Ritchie-Brandt
    1972 / Jackson-McCarthy 1972 phenomenological; Sigmund 2006 §3.4).

    For an antiproton (z1 = -1) the term is NEGATIVE — antiprotons
    stop LESS than protons at the same βγ, the well-known Barkas
    effect / particle-antiparticle stopping difference measured by
    e.g. LEAR / AD experiments. At βγ ~ 0.05-2 the magnitude is
    ~1-5% in low-Z, ~0.5-2% in high-Z.

    Engineering form (Sigmund 2006 §3.4.3 universal-curve fit):
        L1(βγ) = 1.29 · F(βγ) · sign(z1) / √Z
        F(βγ)  = (βγ/βγ_peak) · exp(-(ln(βγ/βγ_peak))² / (2·σ²))

    Log-normal peak shape with βγ_peak ≈ 1, σ = 0.5 reproduces the
    Sigmund 2006 Fig 3.10 universal curve in the βγ window 0.05-2 we
    touch. The 1.29 amplitude is the canonical textbook coefficient
    (Ashley-Ritchie-Brandt). 1/√Z scaling comes from Andersen-Ziegler
    1989 fits to LEAR antiproton data.
    """
    if beta_gamma <= 0.0:
        return 0.0
    z_sqrt = math.sqrt(target_z)
    eta = beta_gamma
    peak_eta = 1.0
    width = 0.5
    f_val = (eta / peak_eta) * math.exp(
        -((math.log(eta / peak_eta) ** 2)) / (2.0 * width * width))
    l1 = 1.29 * f_val / z_sqrt
    return charge_sign * l1


# ------------------------------------------------------------------
# Sternheimer-Berger-Seltzer (1984) density-effect coefficients for
# the four CERN-style stopping materials. Values from PDG mat_data.dat
# (atomic-properties.html Density Effect table) — same set Geant4 s
# G4MaterialPropertiesTable defaults to for elemental Al/Cu/W/Pb.
# Schema: {C, x0, x1, a, k, delta0}.
# ------------------------------------------------------------------
STERNHEIMER_COEFFS = {
    # Al (Z=13)
    "Al": {"C": 4.2395, "x0": 0.1708, "x1": 3.0127,
           "a": 0.0802, "k": 3.6345, "delta0": 0.12},
    # Cu (Z=29) — conductor, delta0 nonzero per Sternheimer 1984
    "Cu": {"C": 4.4190, "x0": -0.0254, "x1": 3.2792,
           "a": 0.1434, "k": 2.9044, "delta0": 0.08},
    # W (Z=74)
    "W":  {"C": 5.4059, "x0": 0.2167, "x1": 3.4960,
           "a": 0.1551, "k": 2.8447, "delta0": 0.14},
    # Pb (Z=82)
    "Pb": {"C": 6.2023, "x0": 0.3776, "x1": 3.8073,
           "a": 0.0936, "k": 3.1610, "delta0": 0.14},
}


# ------------------------------------------------------------------
# CSDA stopping range. The continuous-slowing-down-approximation range
# is the integral of the reciprocal stopping power:
#
#     R(KE) = ∫₀^KE  dE / (−dE/dx)(E)
#
# Domain-agnostic: the caller supplies the projectile + medium + a KE
# grid. This is an approximation — it assumes the projectile loses
# energy continuously (no straggling, no nuclear-stopping channel,
# no δ-ray escape). The ①b adapter owns that caveat.
# ------------------------------------------------------------------
def stopping_range(ke_mev: float,
                   projectile_mass_mev: float,
                   projectile_charge: int,
                   target_z: int,
                   target_a_gpermol: float,
                   target_i_ev: float,
                   electron_mass_mev: float,
                   n_steps: int = 256,
                   ke_floor_mev: float = 1.0) -> dict:
    """CSDA stopping range — trapezoidal integral of 1/(dE/dx) from
    `ke_floor_mev` up to `ke_mev`.

        R = ∫  dE / (−dE/dx)(E)

    The integral starts at `ke_floor_mev` (default 1 MeV), NOT 0:
    Bethe-Bloch diverges as β → 0 (the low-energy regime is exactly
    where shell corrections, which this kernel omits, dominate). The
    returned `range_g_per_cm2` is therefore the range ABOVE the floor;
    `ke_floor_mev` is echoed back so the caller can state the caveat.

    Arguments
      n_steps      : trapezoidal-rule subdivisions (≥ 2).
      ke_floor_mev : lower integration bound (Bethe-Bloch low-E cutoff).

    Returns { range_g_per_cm2, ke_mev, ke_floor_mev, n_steps }. The
    range is a MASS range (g/cm²); divide by material density for a
    length. Raises if `ke_mev` ≤ `ke_floor_mev` or n_steps < 2 —
    silent success is forbidden (g3)."""
    if n_steps < 2:
        raise ValueError(f"n_steps must be >= 2, got {n_steps}")
    if ke_mev <= ke_floor_mev:
        raise ValueError(
            f"ke_mev ({ke_mev}) must exceed ke_floor_mev "
            f"({ke_floor_mev}) — nothing to integrate")

    step = (ke_mev - ke_floor_mev) / n_steps

    def _inv_dedx(e_mev: float) -> float:
        d = bethe_bloch_dedx(
            e_mev, projectile_mass_mev, projectile_charge,
            target_z, target_a_gpermol, target_i_ev,
            electron_mass_mev)["dedx_mevcm2_per_g"]
        return 1.0 / d

    # Trapezoidal rule over [ke_floor, ke].
    total = 0.5 * (_inv_dedx(ke_floor_mev) + _inv_dedx(ke_mev))
    for i in range(1, n_steps):
        total += _inv_dedx(ke_floor_mev + i * step)
    range_g_per_cm2 = total * step

    return {
        "range_g_per_cm2": range_g_per_cm2,
        "ke_mev": ke_mev,
        "ke_floor_mev": ke_floor_mev,
        "n_steps": n_steps,
    }
