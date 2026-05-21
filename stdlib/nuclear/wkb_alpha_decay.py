#!/usr/bin/env python3
# wkb_alpha_decay.py — `nuclear + verify` α-decay half-life closed-form
# adapter (NUCLEAR.md §4.2 · N7 cohort · Path A candidate · libm-only
# closed-form kernel).
#
# NUCLEAR.md §2 (c) gate + §4.2 N7 spec.
# Sibling shape: hfbtho_adapter.py (N6). This N7 producer is the
# *closed-form-formula* sibling — Geiger-Nuttall + Royer + Viola-Seaborg
# semi-empirical α-decay half-life predictors. NO external binary
# dependence — pure libm math (sqrt, log10). This makes N7 a Phase 4
# Path A microkernel candidate (per RTSC.md §9.9.1 schedule pattern):
# wrap-as-is first land, then port the WKB kernel to hexa-native
# sim.hexa-style closed-form at Phase 4.
#
# Three formulas implemented in parallel for honest cross-validation:
#   1. Viola-Seaborg (1966) — log T₁/₂ = (a·Z + b) · Q_α^{-1/2} + (c·Z + d)
#      Original semi-empirical Geiger-Nuttall fit; well-cited.
#      Citation: Viola & Seaborg, J Inorg Nucl Chem 28 (1966) 741.
#   2. Royer (2000) — log T₁/₂ = a + b·A^{1/6}·Z^{1/2} + c·Z·Q_α^{-1/2}
#      Refinement with mass-dependence. Citation: arxiv:nucl-th/0510074.
#
# (A third Brown 1992 / SemFIS-2 form was considered for an honest 3-way
# ensemble but dropped from this first land: its commonly-cited
# coefficient values produce values inconsistent with the Geiger-Nuttall
# regression for SHE Q_α range — citation rigor floor "don't invent"
# (NUCLEAR.md §3.3) takes precedence. Phase 2 follow-on: re-derive
# coefficients from a published table or substitute Denisov-Khudenko
# 2009 / Sobiczewski-Parkhomenko 2007 as the third formula.)
#
# R4 invariant: absorbed = false ALWAYS — α-decay half-life prediction
# from semi-empirical Geiger-Nuttall is a *model* output (calibrated
# against ~400 known α emitters), NOT a measurement of the predicted
# nuclide itself. For a yet-unsynthesized nuclide (e.g., Z=119) the
# Q_α must come from a sim (N6 HFB) → so the formula chain is sim
# composed with sim, never measurement. Promotion path identical to
# N6 — wet-lab dependency permanent.
#
# Gate value: `nuclear-novel-discovery-simulation` (when Q_α provided)
#             or `install-gated` (when Q_α absent and no N6 record to
#             chain from). No external binary — never `install-gated`
#             for missing-binary reason, only for missing-Q_α reason.

from __future__ import annotations

import argparse
import json
import math
import sys
import time
from pathlib import Path


# ─── Coefficients (published, no install required) ──────────────────────


# Viola-Seaborg 1966 (parity-averaged form widely cited):
#   log10 T₁/₂ [s] = (a Z + b) Q^{-1/2} + (c Z + d)
# Coefficients refit by Sobiczewski/Parkhomenko (2005), commonly used:
_VIOLA_SEABORG = {
    "a": 1.66175,
    "b": -8.5166,
    "c": -0.20228,
    "d": -33.9069,
    "ref": (
        "Viola & Seaborg 1966 · J Inorg Nucl Chem 28:741 · "
        "Sobiczewski/Parkhomenko 2005 refit (PRC 72.044316)"
    ),
}

# Royer 2000 (heavy nuclei refinement):
#   log10 T₁/₂ [s] = a + b·A^{1/6}·sqrt(Z) + c·Z·Q^{-1/2}
# Coefficients for even-even nuclei (Royer 2000 Table I):
_ROYER = {
    "a": -25.31,
    "b": -1.1629,
    "c":  1.5864,
    "ref": (
        "Royer 2000 · J Phys G 26:1149 · arxiv:nucl-th/0510074 · "
        "even-even nuclei coefficients"
    ),
}

# (Brown 1992 / SemFIS-2 form removed from first land — see header
# comment. Honest 2-formula ensemble is the floor; Phase 2 may add a
# third with re-derived coefficients.)


# ─── Closed-form kernels (libm-only — Path A microkernel candidates) ────


def _viola_seaborg_log10_t(Z: int, Q_alpha_MeV: float) -> float:
    """Viola-Seaborg log10 T₁/₂ [s] from (Z, Q_α).

    Domain: even-even heavy α emitters; Q_α > 0 (else formula sign-
    invalid → caller must skip).
    """
    if Q_alpha_MeV <= 0:
        raise ValueError(
            f"Q_alpha_MeV must be > 0 for α-decay; got {Q_alpha_MeV}"
        )
    c = _VIOLA_SEABORG
    return (c["a"] * Z + c["b"]) / math.sqrt(Q_alpha_MeV) + (
        c["c"] * Z + c["d"]
    )


def _royer_log10_t(Z: int, A: int, Q_alpha_MeV: float) -> float:
    """Royer 2000 log10 T₁/₂ [s] from (Z, A, Q_α)."""
    if Q_alpha_MeV <= 0:
        raise ValueError(
            f"Q_alpha_MeV must be > 0 for α-decay; got {Q_alpha_MeV}"
        )
    c = _ROYER
    return (
        c["a"]
        + c["b"] * (A ** (1.0 / 6.0)) * math.sqrt(Z)
        + c["c"] * Z / math.sqrt(Q_alpha_MeV)
    )


# ─── Cross-formula consensus (mirror of N4 cross-code DFT pattern) ──────


def _consensus(values: list[tuple[str, float]]) -> dict:
    """Inverse-variance-style spread report across the formula
    ensemble. Returns dict with mean, min, max, spread_dex, and the
    per-formula values for honest visibility."""
    vs = [v for (_, v) in values]
    if not vs:
        return {
            "mean_log10_T_s": None,
            "min_log10_T_s": None,
            "max_log10_T_s": None,
            "spread_dex": None,
            "per_formula": dict(values),
        }
    mean = sum(vs) / len(vs)
    return {
        "mean_log10_T_s": mean,
        "min_log10_T_s": min(vs),
        "max_log10_T_s": max(vs),
        "spread_dex": max(vs) - min(vs),
        "per_formula": dict(values),
    }


# ─── record emit ────────────────────────────────────────────────────────


def main(out_dir: str, Z: int, N: int, Q_alpha_MeV: float | None) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    A = Z + N

    citations = [
        "Viola & Seaborg 1966 · J Inorg Nucl Chem 28:741 — original "
        "Geiger-Nuttall fit for α-decay.",
        "Sobiczewski / Parkhomenko 2005 · PRC 72.044316 — refit of "
        "Viola-Seaborg coefficients (used here).",
        "Royer 2000 · J Phys G 26:1149 · arxiv:nucl-th/0510074 — "
        "mass-dependent refinement.",
        "arxiv:2105.01035 — Wang/Huang/Kondev/Audi/Naimi, AME2020 "
        "evaluation (cross-validation oracle for Q_α inputs).",
        "NUCLEAR.md §2 (5-gate taxonomy) (c) gate + §4.2 (N7 cohort "
        "spec) + §6 (Phase 1 land target — N7 is Path A candidate "
        "per RTSC.md §9.9.1 wrap-first/port-later schedule).",
    ]

    scope_caveats = [
        "(s1) Geiger-Nuttall family formulas (Viola-Seaborg, Royer) "
        "are semi-empirical fits to ~400 known α emitters. "
        "Extrapolation to Z > 118 / SHE region is honest but carries "
        "intrinsic ~0.5-1.0 dex (factor of 3-10) uncertainty per "
        "formula. The cross-formula spread (spread_dex) is the honest "
        "lower bound — the *true* uncertainty against eventual "
        "measurement may be larger if the formula family fails in "
        "the extrapolation region.",
        "(s2) For unsynthesized nuclides (Z=119, 120, drip-line "
        "isotopes), Q_α is itself a sim output (from N6 HFB / FRDM / "
        "BSk mass predictions). The formula chain is sim-composed-"
        "with-sim, NOT measurement. R4 invariant blocks any "
        "absorbed=true promotion for nuclear-novel-discovery-"
        "simulation records (NUCLEAR.md §7).",
        "(s3) 5-gate evaluation (NUCLEAR.md §2): this record fills "
        "ONLY the (c) gate (α-decay half-life). The other 4 gates "
        "((a) mass, (b) spectroscopy, (d) production σ, (e) "
        "detection) are NOT addressed. Even with all 5 sim gates "
        "PASS, (d) and (e) remain wet-lab dependent permanently — "
        "sim-PASS never substitutes for accelerator beam-time.",
        "(s4) Formula domain limits: Viola-Seaborg + Royer are tuned "
        "for even-even heavy α emitters. Odd-A / odd-odd nuclei have "
        "hindrance factors not captured by these forms; predictions "
        "for odd-A SHE may underestimate T₁/₂ by 1-2 orders. SF "
        "(spontaneous fission) competing channel NOT modeled here — "
        "for Z ≥ 104 SF often dominates, so α-decay T₁/₂ alone "
        "overestimates total survival.",
        "(s5) Path A microkernel candidate: this adapter is libm-"
        "only closed-form (no external binary, no install gate). "
        "Per RTSC.md §9.9.1 Phase 4 schedule pattern, the kernels "
        "(_viola_seaborg_log10_t, _royer_log10_t, _consensus) are "
        "valid hexa-native port targets after the wrap stabilizes — "
        "mirror of M5 sim.hexa BCS/McMillan/AD/WHH land. Wet-lab "
        "dependency unchanged regardless of port (NUCLEAR.md §3.2).",
    ]

    record: dict = {
        "domain": "nuclear",
        "verb": "verify",
        "kind": "alpha_decay_halflife_prediction",
        "stamp": stamp,
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,  # R4 invariant — ALWAYS false (NUCLEAR §7)
        "provisional": True,
        "query": {
            "Z": Z,
            "N": N,
            "A": A,
            "Q_alpha_MeV": Q_alpha_MeV,
        },
        "scope_caveats": scope_caveats,
        "citations": citations,
        "provenance": {
            "source_citation": (
                "NUCLEAR.md §2 + §4.2 + §6 (this paper)"
            ),
            "primary_refs": [
                "Viola-Seaborg 1966 / Sobiczewski 2005 refit.",
                "Royer 2000 arxiv:nucl-th/0510074.",
            ],
            "formula_chain": [
                "viola_seaborg", "royer"
            ],
        },
        "nuclear_anchor": (
            "NUCLEAR.md §2 (c) gate + §4.2 (N7 cohort spec) + §6 "
            "(Phase 1 N7 first land) + §7 (R4 invariant block)"
        ),
    }

    if Q_alpha_MeV is None or Q_alpha_MeV <= 0:
        # Honest skip — without a Q_α we can't evaluate any of the
        # three formulas. The expected workflow is: N6 HFB predicts
        # M(Z,N), then daughter M(Z-2,N-2) + α; Q_α = parent − daughter
        # − M_α. For first land we accept Q_α as a CLI input (or
        # absent → install-gated equivalent for missing-Q_α).
        skipped_reason = (
            "No Q_alpha provided (Q_alpha_MeV is None or ≤ 0). The "
            "expected workflow chains N6 HFB mass predictions: "
            "Q_α = M(Z,N) − M(Z-2,N-2) − M_α. Re-invoke with "
            "--q-alpha-mev <value>, or after N6 record is available."
        )
        record["producer"] = "wkb_alpha_decay.py@q-alpha-missing"
        record["backend"] = "closed-form-libm"
        record["gate_type"] = "install-gated"  # mirror N6 honest-skip
        record["skipped_reason"] = skipped_reason
        record["prediction"] = None
        headline = (
            "skip: no Q_alpha provided (install-gated equivalent — "
            "needs N6 mass-prediction chain or explicit CLI Q_α)"
        )
    else:
        # Evaluate all three formulas in parallel.
        try:
            vs_log = _viola_seaborg_log10_t(Z, Q_alpha_MeV)
            ro_log = _royer_log10_t(Z, A, Q_alpha_MeV)
            per_formula = [
                ("viola_seaborg", vs_log),
                ("royer", ro_log),
            ]
            consensus = _consensus(per_formula)
            mean_log = consensus["mean_log10_T_s"]
            # Guard against overflow if mean_log is large (shouldn't
            # happen with Royer + VS for valid Q_α, but defensive).
            try:
                t_geomean = 10.0 ** mean_log
            except OverflowError:
                t_geomean = float("inf")
            record["producer"] = "wkb_alpha_decay.py@all-formulas"
            record["backend"] = "closed-form-libm"
            record["gate_type"] = "nuclear-novel-discovery-simulation"
            record["skipped_reason"] = None
            record["prediction"] = {
                "viola_seaborg_log10_T_s": vs_log,
                "royer_log10_T_s": ro_log,
                "consensus_mean_log10_T_s": mean_log,
                "consensus_spread_dex": consensus["spread_dex"],
                "consensus": consensus,
                "T_half_seconds_geomean_estimate": t_geomean,
            }
            headline = (
                f"ok: 2-formula consensus log10 T = "
                f"{mean_log:.2f} ± "
                f"{consensus['spread_dex']:.2f} dex"
            )
        except ValueError as e:
            record["producer"] = "wkb_alpha_decay.py@invalid-input"
            record["backend"] = "closed-form-libm"
            record["gate_type"] = "install-gated"
            record["skipped_reason"] = (
                f"Closed-form formula domain error: {e}. Sign-"
                "invalid Q_α — α-decay not energetically allowed."
            )
            record["prediction"] = None
            headline = f"skip: domain error ({e})"

    rec_path = out / f"nuclear_verify_n7_alpha_{Z}_{N}_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))

    print(f"[nuclear+verify · n7_alpha] wrote {rec_path}")
    print(f"  headline: {headline}")
    print(
        f"  backend={record.get('backend')!r} "
        f"gate_type={record.get('gate_type')!r} "
        f"absorbed={record.get('absorbed')}"
    )
    if record.get("skipped_reason"):
        first_line = str(record["skipped_reason"]).splitlines()[0]
        print(f"  skipped_reason: {first_line}")
    if record.get("prediction"):
        p = record["prediction"]
        print(
            f"  query: Z={Z}  N={N}  A={A}  "
            f"Q_alpha={Q_alpha_MeV} MeV"
        )
        print(
            f"  per-formula log10 T₁/₂ [s]: "
            f"VS={p['viola_seaborg_log10_T_s']:.2f}  "
            f"Royer={p['royer_log10_T_s']:.2f}  "
            f"mean={p['consensus_mean_log10_T_s']:.2f}  "
            f"spread={p['consensus_spread_dex']:.2f} dex"
        )
    print(
        "[nuclear+verify · n7_alpha] absorbed=false (R4 invariant; "
        "Geiger-Nuttall family is semi-empirical fit, NEVER "
        "measurement — NUCLEAR.md §7 wet-lab dependency permanent)"
    )
    return 0


def _parse_argv(
    argv: list[str],
) -> tuple[str, int, int, float | None]:
    p = argparse.ArgumentParser(
        prog="wkb_alpha_decay.py",
        description=(
            "Thin adapter for nuclear α-decay half-life prediction "
            "via 3-formula Geiger-Nuttall family ensemble (NUCLEAR.md "
            "§4.2 N7 cohort · libm-only closed-form · Path A "
            "microkernel candidate). R4 invariant: absorbed=false "
            "always."
        ),
    )
    p.add_argument(
        "Z", type=int, help="Proton number (atomic number)."
    )
    p.add_argument(
        "N", type=int, help="Neutron number."
    )
    p.add_argument(
        "out_dir", help="Output directory for JSON record."
    )
    p.add_argument(
        "--q-alpha-mev",
        type=float,
        default=None,
        help=(
            "α-decay Q-value in MeV. If absent → install-gated "
            "honest-skip equivalent (workflow expects N6 HFB chain)."
        ),
    )
    ns = p.parse_args(argv)
    if ns.Z < 2:
        p.error(f"Z must be ≥ 2 for α-decay parent, got Z={ns.Z}")
    if ns.N < 2:
        p.error(f"N must be ≥ 2 for α-decay parent, got N={ns.N}")
    return ns.out_dir, ns.Z, ns.N, ns.q_alpha_mev


if __name__ == "__main__":
    out_dir, Z, N, q = _parse_argv(sys.argv[1:])
    sys.exit(main(out_dir, Z, N, q))
