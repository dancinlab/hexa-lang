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
                     electron_mass_mev: float) -> dict:
    """Bethe-Bloch mean mass stopping power −dE/dx at one (KE, medium)
    point (PDG eq. 34.5, density-correction δ = 0):

        −dE/dx = K·z²·(Z/A)·(1/β²)·[ ½·ln(2m_ec²β²γ²T_max / I²) − β² ]

    with γ, β² from `relativistic_kinematics` and T_max from
    `max_energy_transfer_mev`. K = 0.307075 MeV·cm²/g.

    Arguments
      projectile_charge : charge magnitude — the sign drops out in z².
      target_i_ev       : mean excitation energy in eV (PDG Table 34.1).

    Returns { beta, gamma, beta_gamma, tmax_mev, dedx_mevcm2_per_g }.
    `dedx_mevcm2_per_g` is the mass stopping power (MeV·cm²/g). Raises
    on a non-physical kinematic point — silent success is forbidden."""
    kin = relativistic_kinematics(ke_mev, projectile_mass_mev)
    beta2 = kin["beta2"]
    gamma = kin["gamma"]
    tmax_mev = max_energy_transfer_mev(
        ke_mev, projectile_mass_mev, electron_mass_mev)

    i_mev = target_i_ev * 1.0e-6  # eV -> MeV
    log_term = 0.5 * math.log(
        2.0 * electron_mass_mev * beta2 * gamma * gamma * tmax_mev
        / (i_mev * i_mev))
    z2 = projectile_charge * projectile_charge
    dedx = (K_BB_MEV_CM2_PER_G * z2 * (target_z / target_a_gpermol)
            * (log_term - beta2) / beta2)
    return {
        "beta": kin["beta"],
        "gamma": gamma,
        "beta_gamma": kin["beta_gamma"],
        "tmax_mev": tmax_mev,
        "dedx_mevcm2_per_g": dedx,
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
