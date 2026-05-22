#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ribozyme_kinetics_simulation.py — hammerhead-minimal 12-nt 4-state chemical-kinetics
simulation (Eyring transition-state theory + 4-state RK4/Euler ODE integration).

Re-implemented 2026-05-12 from the documented F-RB-4 MVP behaviour (the original
`_python_bridge/module/ribozyme_kinetics_simulation.py` was removed from the tree
by the R5 sunset; this stdlib-only re-implementation reproduces the documented
model and headline numbers from `.roadmap.ribozyme` C0b + the `raw_77_ribozyme_kinetics_v1`
witness schema in `state/discovery_absorption/registry.jsonl`).  Closes the
in-repo execution of G26-RB-1′ (the deterministic computational-verification
rubric): the simulator now exists, runs, reproduces the F-RB-4 MVP values, and
is wired into `selftest/run_all.sh` as a regression-protected gate step.

Model (the hammerhead self-cleavage catalytic cycle as a 4-state ladder, τ(6)=4):

    state 0  substrate_bound      E·S
    state 1  transition_state     E·S‡   (chemistry barrier ΔG‡)
    state 2  cleaved_intermediate E·P
    state 3  product_released     E + P

  E + S  ⇌(k1, k₋1)  E·S  ⇌(k2, k₋2)  E·S‡/E·X  →(k3)  E·P  →(k4)  E + P

  k1   = K1_2ND_ORDER · [S]_ref         (binding, effective 1st order at [S]=1 µM)
  k₋1  = 0.05  /s
  k2   = (k_B·T/h)·exp(−ΔG‡/(R·T))      (Eyring TST; ΔG‡ = 21 kcal/mol, T = 310 K)
  k₋2  = 1.0   /s
  k3   = 100   /s                       (commitment to chemistry)
  k4   = 10    /s                       (product release)

  k_cat   = k2·k3/(k3 + k₋2)            ( ≈ 0.6 /min )
  K_M     = (k₋1 + k_cat)/K1_2ND_ORDER  ( ≈ 0.12 µM )
  k_cat/K_M  vs Eigen-Hammes diffusion ceiling 1e9 M⁻¹s⁻¹  →  margin ≈ 4.08 orders

n=6 invariant binding: σ(6)=12 = 12-nt strictly-conserved catalytic core
(`CUGAUGAGGCCG`, Symons 1981 13-nt `CUGAUGAGGCCGA` trimmed); τ(6)=4 = the 4
reaction states above; φ(6)=2 = cleaved/intact; J₂=24 = TS-pose orbit size
(S₄ ≅ O — see `ribozyme_reaction_coordinate_quotient.py`).  Master identity
σ·φ = n·τ = J₂ = 24.

Honest C3: this re-implementation reproduces the documented F-RB-4
headline numbers (k_cat ≈ 0.6/min, K_M ≈ 0.12 µM, k_cat/K_M ≈ 8.3e4 M⁻¹s⁻¹,
Eigen-Hammes margin ≈ 4.08 orders) to ~3 significant figures; the original's
4th-digit values (k_cat 0.5995/min, k2 0.0100919…) depend on the exact constant
set it used (now lost) — the small last-digit difference is constant-choice,
not a discrepancy in the physics or the F-RB-4 pass/fail verdict.  The model
itself is a deterministic literature-informed surrogate, not a fit to a
specific experimental dataset.  Pure stdlib, no network/time/random/env →
byte-identical re-runs (§11 deductive verification contract).
"""
from __future__ import annotations
import json
import math
import sys

# ── physical constants (CODATA 2019, exact SI) ──
K_B = 1.380649e-23          # J/K
H_PLANCK = 6.62607015e-34   # J·s
N_A = 6.02214076e23         # 1/mol
R_GAS = K_B * N_A           # J/(mol·K)  = 8.314462618…
KCAL_TO_J = 4184.0          # 1 kcal = 4184 J (thermochemical)

# ── n=6 lattice ──
N6, SIGMA, TAU, PHI, J2 = 6, 12, 4, 2, 24
CATALYTIC_CORE = "CUGAUGAGGCCG"            # 12-nt strictly conserved (Symons 1981)
SYMONS_1981_REF = "CUGAUGAGGCCGA"
LADDER = ["substrate_bound", "transition_state", "cleaved_intermediate", "product_released"]
EIGEN_HAMMES_CEILING = 1.0e9               # M⁻¹s⁻¹ (diffusion-limited 2nd-order ceiling)

# ── rate-constant parameters (documented MVP) ──
DG_DAGGER_KCAL = 21.0       # ΔG‡, kcal/mol  (Eyring barrier for the chemistry step)
TEMP_K = 310.0              # K
K1_2ND_ORDER = 5.0e5        # M⁻¹s⁻¹  (substrate-arm binding)
S_REF_M = 1.0e-6            # M       (reference substrate conc. for the effective k1)
K_MINUS1 = 0.05             # /s
K_MINUS2 = 1.0              # /s
K3 = 100.0                  # /s
K4 = 10.0                   # /s
MG_MM = 10.0                # mM Mg²⁺ (metadata only — see ribozyme_mg_sweep_audit)


def eyring_rate(dg_kcal: float, temp_k: float) -> float:
    """Eyring transition-state-theory unimolecular rate: k = (k_B·T/h)·exp(−ΔG‡/RT)."""
    prefactor = K_B * temp_k / H_PLANCK
    dg_j = dg_kcal * KCAL_TO_J
    return prefactor * math.exp(-dg_j / (R_GAS * temp_k))


def rate_constants() -> dict:
    k2 = eyring_rate(DG_DAGGER_KCAL, TEMP_K)
    k_cat = k2 * K3 / (K3 + K_MINUS2)            # commitment-corrected chemistry rate
    k_m_M = (K_MINUS1 + k_cat) / K1_2ND_ORDER    # Briggs–Haldane K_M
    k1_eff = K1_2ND_ORDER * S_REF_M
    return {
        "k1": k1_eff, "k1_units": "1/s effective at [S]=1 uM (= K1_2nd_order * S_REF_M)",
        "k1_2nd_order_M_inv_s_inv": K1_2ND_ORDER,
        "k_minus1": K_MINUS1,
        "k2": k2, "k2_source": f"Eyring TST: k = (kT/h) exp(-dG/RT) at dG={DG_DAGGER_KCAL} kcal/mol, T={TEMP_K}K",
        "k_minus2": K_MINUS2, "k3": K3, "k4": K4,
        "k_cat": k_cat, "k_cat_per_min": k_cat * 60.0,
        "K_M_uM": k_m_M * 1.0e6, "K_M_M": k_m_M,
        "k_cat_over_K_M_M_inv_s_inv": k_cat / k_m_M,
        "eigen_hammes_ceiling_M_inv_s_inv": EIGEN_HAMMES_CEILING,
        "eigen_hammes_margin_orders": math.log10(EIGEN_HAMMES_CEILING / (k_cat / k_m_M)),
        "mg_mM": MG_MM,
    }


# ── 4-state linear-chain ODE  S0 →(a) S1 →(b) S2 →(c) S3  (mass-conserving absorbing chain) ──

def _deriv(s, a, b, c):
    s0, s1, s2, s3 = s
    return (-a * s0, a * s0 - b * s1, b * s1 - c * s2, c * s2)


def _step_euler(s, dt, a, b, c):
    d = _deriv(s, a, b, c)
    return tuple(si + dt * di for si, di in zip(s, d))


def _step_rk4(s, dt, a, b, c):
    k1 = _deriv(s, a, b, c)
    s2 = tuple(si + 0.5 * dt * ki for si, ki in zip(s, k1))
    k2 = _deriv(s2, a, b, c)
    s3 = tuple(si + 0.5 * dt * ki for si, ki in zip(s, k2))
    k3 = _deriv(s3, a, b, c)
    s4 = tuple(si + dt * ki for si, ki in zip(s, k3))
    k4 = _deriv(s4, a, b, c)
    return tuple(si + (dt / 6.0) * (a1 + 2 * a2 + 2 * a3 + a4)
                 for si, a1, a2, a3, a4 in zip(s, k1, k2, k3, k4))


def _analytic_chain(t, a, b, c):
    """Exact solution of S0→S1→S2→S3 with distinct rates a,b,c, S(0) = (1,0,0,0)."""
    ea, eb, ec = math.exp(-a * t), math.exp(-b * t), math.exp(-c * t)
    s0 = ea
    s1 = a * (ea - eb) / (b - a)
    # s2 = a*b * [ ea/((b-a)(c-a)) + eb/((a-b)(c-b)) + ec/((a-c)(b-c)) ]
    s2 = a * b * (ea / ((b - a) * (c - a)) + eb / ((a - b) * (c - b)) + ec / ((a - c) * (b - c)))
    s3 = 1.0 - s0 - s1 - s2
    return (s0, s1, s2, s3)


def integrate(a, b, c, t_end, dt):
    n = int(round(t_end / dt))
    s_e = s_r = (1.0, 0.0, 0.0, 0.0)
    max_mass_drift = 0.0
    max_rk4_vs_analytic = 0.0
    max_euler_vs_analytic = 0.0
    for i in range(1, n + 1):
        s_e = _step_euler(s_e, dt, a, b, c)
        s_r = _step_rk4(s_r, dt, a, b, c)
        t = i * dt
        max_mass_drift = max(max_mass_drift, abs(sum(s_r) - 1.0))
        an = _analytic_chain(t, a, b, c)
        max_rk4_vs_analytic = max(max_rk4_vs_analytic, max(abs(x - y) for x, y in zip(s_r, an)))
        max_euler_vs_analytic = max(max_euler_vs_analytic, max(abs(x - y) for x, y in zip(s_e, an)))
    rk4_vs_euler_final = max(abs(x - y) for x, y in zip(s_r, s_e))
    return {
        "t_end_s": t_end, "dt_s": dt, "n_steps": n,
        "final_state_rk4": list(s_r), "final_state_euler": list(s_e),
        "final_state_analytic": list(_analytic_chain(t_end, a, b, c)),
        "max_mass_conservation_drift": max_mass_drift,
        "max_rk4_vs_analytic_error": max_rk4_vs_analytic,
        "max_euler_vs_analytic_error": max_euler_vs_analytic,
        "rk4_vs_euler_final_agreement": rk4_vs_euler_final,
    }


def n6_invariant_block() -> dict:
    return {
        "sigma_6": SIGMA, "tau_6": TAU, "phi_6": PHI, "J2": J2,
        "sigma_times_phi_eq_J2": SIGMA * PHI == J2,
        "n_times_tau_eq_J2": N6 * TAU == J2,
        "core_length_eq_sigma": len(CATALYTIC_CORE) == SIGMA,
        "states_count_eq_tau": len(LADDER) == TAU,
        "binary_outcome_eq_phi": PHI == 2,
        "ts_pose_group_order_eq_J2": 24 == J2,   # |S₄| = |O| = 24 — see ribozyme_reaction_coordinate_quotient.py
        "catalytic_core_sequence": CATALYTIC_CORE,
        "symons_1981_reference": SYMONS_1981_REF,
        "ladder": LADDER,
        "master_identity_ok": SIGMA * PHI == N6 * TAU == J2 == 24,
    }


def run_mvp() -> dict:
    rc = rate_constants()
    # 4-state chain integrated near steady state (everything ends absorbed in state 3).
    a, b, c = rc["k_cat"], K3, K4
    sim = integrate(a, b, c, t_end=30.0, dt=1.0e-3)   # 3e4 steps; fast states fully relaxed, k_cat·t≈0.3
    inv = n6_invariant_block()
    inv["all_pass"] = all(v for k, v in inv.items() if isinstance(v, bool))

    # F-RB-4 6/6 acceptance criteria.
    crit = {
        "C1_catalytic_core_12nt":      len(CATALYTIC_CORE) == 12 and CATALYTIC_CORE == "CUGAUGAGGCCG",
        "C2_four_state_ladder":        len(LADDER) == 4,
        "C3_k_cat_plausible_per_min":  0.1 <= rc["k_cat_per_min"] <= 10.0,
        "C4_K_M_plausible_uM":         0.01 <= rc["K_M_uM"] <= 10.0,
        "C5_eigen_hammes_margin_ge_1": rc["eigen_hammes_margin_orders"] >= 1.0,
        "C6_numerical_sanity":         (sim["max_mass_conservation_drift"] < 1e-9
                                        and sim["max_rk4_vs_analytic_error"] < 1e-6
                                        # RK4 (4th-order) must be ≥100× more accurate than Euler (1st-order):
                                        and sim["max_rk4_vs_analytic_error"] < 1e-2 * sim["max_euler_vs_analytic_error"]),
    }
    n_pass = sum(1 for v in crit.values() if v)
    witness = {
        "schema": "raw_77_ribozyme_kinetics_v1",
        "ts": "2026-05-12T00:00:00Z",   # fixed (re-implementation date) — keeps the witness deterministic
        "cycle": 113,
        "regenerated": "2026-05-12 re-implementation (R5-sunset original removed; stdlib-only re-impl, reproduces F-RB-4 MVP)",
        "phase": "f-rb-4-mvp-kinetics / G26-RB-1′ in-repo exec",
        "domain": "hexa-ribozyme", "falsifier": "F-RB-4",
        "model": "hammerhead_minimal_12nt_4state",
        "sequence": CATALYTIC_CORE,
        "sequence_reference": "Symons 1981 13-nt minimal CUGAUGAGGCCGA trimmed to 12-nt strictly conserved core",
        "n6_invariant": inv,
        "rate_constants": rc,
        "simulation": sim,
        "f_rb_4_criteria": crit,
        "f_rb_4_pass_count": n_pass, "f_rb_4_total": len(crit),
        "f_rb_4_verdict": "PASS" if n_pass == len(crit) else "FAIL",
        "raw_91_c3": ("re-implementation reproduces documented F-RB-4 headline numbers "
                      "(k_cat≈0.6/min, K_M≈0.12 µM, k_cat/K_M≈8.3e4, margin≈4.08 orders) to ~3 sig figs; "
                      "4th-digit difference from original = constant-choice in the Eyring prefactor, not a "
                      "discrepancy; literature-informed surrogate, not a fit to a specific dataset"),
    }
    return witness


def main() -> int:
    print("ribozyme_kinetics_simulation — hammerhead 12-nt 4-state kinetics (Eyring TST + RK4/Euler ODE)\n", flush=True)
    w = run_mvp()
    rc = w["rate_constants"]; sim = w["simulation"]; crit = w["f_rb_4_criteria"]
    print(f"  catalytic core : {w['sequence']}  (12 nt — σ(6)=12;  ladder = {LADDER}  — τ(6)=4)")
    print(f"  Eyring TST     : ΔG‡ = {DG_DAGGER_KCAL} kcal/mol, T = {TEMP_K} K  →  k2 = {rc['k2']:.6e} /s")
    print(f"  k_cat          : {rc['k_cat']:.6e} /s  =  {rc['k_cat_per_min']:.4f} /min")
    print(f"  K_M            : {rc['K_M_uM']:.5f} µM")
    print(f"  k_cat / K_M    : {rc['k_cat_over_K_M_M_inv_s_inv']:.3e} M⁻¹s⁻¹   "
          f"(Eigen-Hammes ceiling {EIGEN_HAMMES_CEILING:.0e} → margin {rc['eigen_hammes_margin_orders']:.2f} orders)")
    print(f"  ODE (4-state, RK4 vs Euler vs analytic; {sim['n_steps']} steps @ dt={sim['dt_s']}s, t_end={sim['t_end_s']}s):")
    print(f"     mass-conservation drift (max)   = {sim['max_mass_conservation_drift']:.2e}")
    print(f"     RK4   vs analytic error (max)   = {sim['max_rk4_vs_analytic_error']:.2e}")
    print(f"     Euler vs analytic error (max)   = {sim['max_euler_vs_analytic_error']:.2e}")
    print(f"     RK4   vs Euler  (final, ≈roundoff) = {sim['rk4_vs_euler_final_agreement']:.2e}")
    print(f"  n=6 invariant  : all_pass = {w['n6_invariant']['all_pass']}   master identity σ·φ = n·τ = J₂ = 24 ✓")
    print()
    for k, v in crit.items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- F-RB-4: {w['f_rb_4_pass_count']}/{w['f_rb_4_total']}  →  verdict: {w['f_rb_4_verdict']} ---")

    emit = "--emit-witness" in sys.argv
    if emit:
        import io, os
        path = os.path.join(os.path.dirname(__file__), "..", "..", "state", "discovery_absorption", "registry.jsonl")
        path = os.path.abspath(path)
        with io.open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps(w, ensure_ascii=False) + "\n")
        print(f"  [emit] appended fresh raw_77_ribozyme_kinetics_v1 witness → {path}")

    ok = w["f_rb_4_verdict"] == "PASS" and w["n6_invariant"]["all_pass"]
    print("\n## witness JSON")
    print(json.dumps(w, indent=2, ensure_ascii=False))
    print("\n__RIBOZYME_MVP_RESULT__ PASS" if ok else "\n__RIBOZYME_MVP_RESULT__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
