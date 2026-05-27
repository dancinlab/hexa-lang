#!/usr/bin/env python3
# geant4_verify.py — `antimatter + verify` producer (D72 ①b thin adapter).
#
# ROI rank 18 — Geant4 antiproton stopping / annihilation benchmark.
# 4th consumer of `kernels/mc_transport/` (after antimatter+analyze,
# fusion+verify, energy+verify) — mc_transport is now the load-bearing
# example of D72 N+M payoff (1 kernel · 4 domain adapters).
#
# References:
#   - Geant4 v11.x — geant4.web.cern.ch (CERN / KEK / SLAC).
#   - PDG RPP 2024 §34 Passage of Particles through Matter (eq. 34.5
#     Bethe-Bloch mean stopping power; oracle for the substrate-vs-
#     kernel parity comparison).
#   - arxiv:2407.06721 — antiproton annihilation at rest in thin solid
#     targets vs Geant4/FLUKA MC (2024). NOTE: annihilation-at-rest
#     experiment, NOT a stopping-range oracle.
#   - arxiv:2503.04868 — low-energy antiproton annihilation on nuclei,
#     Geant4 v11.2.1 FTFP_INCLXX_EMZ (2025). Same caveat.
#
# D61: substrate SSOT under `hexa-lang/stdlib/antimatter/`.
# D72: kernels/mc_transport/ reuse (4th consumer — N+M kernel-payoff
#      visibly load-bearing).
# D80 (g_hexa_only): absorbed=true reserved for the day a hexa-native
#      MC-transport port (kernels/mc_transport/*.hexa) lands AND passes
#      this same parity round. Until then provisional=true,
#      absorbed=false — the closed-form Bethe-Bloch CSDA in
#      transport_kernel.py is Python, not hexa-native.
# g3:  the substrate is install-gated. If neither the geant4-config
#      binary nor the geant4_pybind wheel is importable, the producer
#      writes an honest skip record with skipped_reason.

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
import traceback
from pathlib import Path
from typing import Any


# ------------------------------------------------------------------
# Geant4 installation detection. Three independent signals:
#   1. geant4-config binary on PATH (C++ Geant4 build).
#   2. geant4.sh env script on PATH (same).
#   3. geant4_pybind Python wheel importable (PyPI bindings — does not
#      require a Geant4 build on PATH).
# Any one suffices.
# ------------------------------------------------------------------
def _which_geant4_binary() -> str | None:
    for name in ("geant4-config", "geant4.sh"):
        p = shutil.which(name)
        if p:
            return p
    return None


def _have_pybind() -> bool:
    try:
        import importlib

        importlib.import_module("geant4_pybind")
        return True
    except Exception:
        return False


def _geant4_version_str() -> str:
    """Single 'geant4@<version>' producer string. Prefer geant4-config;
    fall back to the pybind G4VERSION_NUMBER constant."""
    binp = _which_geant4_binary()
    if binp is not None:
        try:
            out = subprocess.run(
                [binp, "--version"], capture_output=True, text=True, timeout=5
            ).stdout
            first = out.strip().splitlines()[0] if out else "unknown"
            return f"geant4-cpp@{first}"
        except Exception:
            return "geant4-cpp@unknown"
    if _have_pybind():
        try:
            import geant4_pybind  # type: ignore

            n = int(geant4_pybind.G4VERSION_NUMBER)
            # G4VERSION_NUMBER packs MM*100 + m*10 + p as a 4-digit int
            # (e.g. 1141 = Geant4 11.4.1; 1110 = 11.1.0).
            major = n // 100
            minor = (n // 10) % 10
            patch = n % 10
            return f"geant4-pybind@{major}.{minor}.{patch}"
        except Exception:
            return "geant4-pybind@unknown"
    return "geant4@absent"


# ------------------------------------------------------------------
# Kernel CSDA oracle. Calls into the ①a kernel `kernels/mc_transport/
# transport_kernel.py` (D72 — 4th consumer of the shared kernel).
# Returns the PDG Bethe-Bloch closed-form CSDA range for an antiproton
# at the given KE in Al. This is the oracle the substrate parity
# compares against.
# ------------------------------------------------------------------
def _kernel_csda_g_per_cm2(ke_mev: float, n_steps: int = 2048) -> dict[str, Any]:
    here = Path(__file__).resolve().parent
    kernel_dir = here.parent / "kernels" / "mc_transport"
    if str(kernel_dir) not in sys.path:
        sys.path.insert(0, str(kernel_dir))
    from transport_kernel import lookup_particle, stopping_range  # type: ignore

    pbar = lookup_particle(-2212)
    electron = lookup_particle(11)

    # Aluminum 13Al27, mean excitation I = 166 eV (PDG/NIST Al value).
    rng = stopping_range(
        ke_mev=ke_mev,
        projectile_mass_mev=pbar["mass_mev"],
        projectile_charge=int(abs(pbar["charge"])),
        target_z=13,
        target_a_gpermol=26.9815385,
        target_i_ev=166.0,
        electron_mass_mev=electron["mass_mev"],
        n_steps=n_steps,
        ke_floor_mev=1.0,
    )
    return {
        "ke_mev": ke_mev,
        "range_g_per_cm2": rng["range_g_per_cm2"],
        "ke_floor_mev": rng["ke_floor_mev"],
        "n_steps": rng["n_steps"],
        "antiproton_mass_mev": pbar["mass_mev"],
        "electron_mass_mev": electron["mass_mev"],
        "target_z": 13,
        "target_a_gpermol": 26.9815385,
        "target_i_ev": 166.0,
    }


# ------------------------------------------------------------------
# Geant4 simulation driver. Imports the internal sim module (which
# pulls in geant4_pybind) and runs the KE sweep within a single
# G4RunManager lifecycle (Geant4 forbids re-creating G4RunManager).
# ------------------------------------------------------------------
def _run_geant4_sweep(
    ke_mev_list: list[float], n_events: int
) -> list[dict[str, Any]]:
    here = Path(__file__).resolve().parent
    if str(here) not in sys.path:
        sys.path.insert(0, str(here))
    from _geant4_antiproton_al_sim import run_simulation_sweep  # type: ignore

    return run_simulation_sweep(ke_mev_list, n_events)


# ------------------------------------------------------------------
# Tolerance policy. The substrate value (Geant4 mean stopping depth)
# is bounded above by the kernel CSDA (no annihilation, no nuclear
# stopping). The difference IS physics — in-flight antiproton
# annihilation removes the projectile before it completes its CSDA
# range. Tolerance "one-sided" captures: substrate must never exceed
# kernel CSDA + 1*stdev (that would violate the energy budget).
# Substrate UNDER the kernel CSDA is honest physics.
# ------------------------------------------------------------------
def _within_tolerance(
    substrate_g_per_cm2: float,
    substrate_stdev_g_per_cm2: float,
    kernel_g_per_cm2: float,
) -> tuple[bool, str]:
    """Return (pass, reason). One-sided: substrate ≤ kernel + 1*stdev.
    Substrate < kernel is *expected* (annihilation in flight)."""
    upper = kernel_g_per_cm2 + substrate_stdev_g_per_cm2
    if substrate_g_per_cm2 <= upper:
        return (
            True,
            (
                f"substrate_g_per_cm2 ({substrate_g_per_cm2:.4f}) "
                f"<= kernel_csda + 1*stdev ({upper:.4f}); "
                "under-shoot reflects in-flight annihilation channel "
                "the closed-form CSDA omits."
            ),
        )
    return (
        False,
        (
            f"substrate_g_per_cm2 ({substrate_g_per_cm2:.4f}) "
            f"> kernel_csda + 1*stdev ({upper:.4f}) — would violate "
            "energy-budget upper bound. Re-check material density, "
            "KE, or physics list."
        ),
    )


# ------------------------------------------------------------------
# Producer entrypoint.
# ------------------------------------------------------------------
def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    citations = [
        "PDG RPP 2024 §34 (eq. 34.5 Bethe-Bloch mean stopping power) — "
        "oracle of record for the substrate-vs-kernel parity comparison.",
        "Geant4 v11.x — geant4.web.cern.ch (CERN / KEK / SLAC).",
        "geant4_pybind 0.1.3 PyPI wheel — HaarigerHarald/geant4_pybind.",
        "scikit-hep `particle` library — PDG-aggregated measured constants.",
        "arxiv:2407.06721 — antiproton annihilation at rest in thin solid "
        "targets vs Geant4/FLUKA MC (2024). NOTE: annihilation-at-rest "
        "experiment (ASACUSA), NOT an antiproton-on-Al stopping-distance "
        "oracle; cited here for substrate pedigree only.",
        "arxiv:2503.04868 — low-energy antiproton annihilation on nuclei, "
        "Geant4 v11.2.1 FTFP_INCLXX_EMZ (2025). Same pedigree caveat.",
    ]

    binp = _which_geant4_binary()
    pybind_ok = _have_pybind()

    # ----- INSTALL GATE -----------------------------------------------
    if binp is None and not pybind_ok:
        record = {
            "domain": "antimatter",
            "verb": "verify",
            "kind": "geant4_antiproton_stopping",
            "stamp": stamp,
            "producer": "geant4@absent",
            "measurement_gate": "GATE_OPEN",
            "gate_type": "install-gated",
            "absorbed": False,
            "provisional": True,
            "skipped_reason": "geant4_not_installed",
            "scope_caveats": [
                "Geant4 not installed — honest install-gated skip. "
                "Install path: `pip install geant4-pybind` (PyPI wheel; "
                "downloads ~7 GB datasets on first import) OR the "
                "multi-hour C++ build from geant4.web.cern.ch.",
                "Reference antiproton-on-Al benchmark — NOT a sourced "
                "CERN AD / ELENA experimental geometry.",
            ],
            "citations": citations,
            "kernel_reuse": (
                "kernels/mc_transport/ (D72 — 4th consumer; clearest "
                "N+M payoff)"
            ),
        }
        rec_path = out / f"antimatter_verify_{stamp}.json"
        rec_path.write_text(json.dumps(record, indent=2))
        print(f"[antimatter+verify] wrote {rec_path} (install-gated skip)")
        return 0

    # ----- REAL MEASUREMENT -------------------------------------------
    # KE sweep — three energies; production override via env var
    # GEANT4_VERIFY_KE_LIST="50,100,200".
    ke_list_env = os.environ.get("GEANT4_VERIFY_KE_LIST", "50,100,200")
    ke_list = [float(x) for x in ke_list_env.split(",") if x.strip()]
    n_events = int(os.environ.get("GEANT4_VERIFY_N_EVENTS", "500"))

    parity_block: list[dict[str, Any]] = []
    overall_pass = True
    pass_reasons: list[str] = []
    fail_reasons: list[str] = []
    try:
        sim_results = _run_geant4_sweep(ke_list, n_events)
        for ke, sim in zip(ke_list, sim_results):
            kernel = _kernel_csda_g_per_cm2(ke)
            substrate_g = sim["mean_depth_g_per_cm2"]
            substrate_stdev_g = sim["stdev_depth_cm"] * sim["density_g_per_cm3"]
            kernel_g = kernel["range_g_per_cm2"]
            rel_err = (
                (substrate_g - kernel_g) / kernel_g if kernel_g != 0 else 0.0
            )
            (ok, reason) = _within_tolerance(
                substrate_g, substrate_stdev_g, kernel_g
            )
            (pass_reasons if ok else fail_reasons).append(
                f"ke={ke} MeV — {reason}"
            )
            overall_pass = overall_pass and ok
            parity_block.append(
                {
                    "ke_mev": ke,
                    "substrate_g_per_cm2": substrate_g,
                    "substrate_stdev_g_per_cm2": substrate_stdev_g,
                    "substrate_mean_depth_cm": sim["mean_depth_cm"],
                    "substrate_stdev_depth_cm": sim["stdev_depth_cm"],
                    "substrate_n_events": sim["n_events"],
                    "substrate_n_recorded": sim["n_recorded"],
                    "kernel_csda_g_per_cm2": kernel_g,
                    "rel_err": rel_err,
                    "tolerance_pass": ok,
                    "tolerance_reason": reason,
                    "density_g_per_cm3": sim["density_g_per_cm3"],
                    "physics_list": sim["physics_list"],
                    "wall_seconds": sim["wall_seconds"],
                }
            )
    except Exception as exc:
        tb = traceback.format_exc()
        record = {
            "domain": "antimatter",
            "verb": "verify",
            "kind": "geant4_antiproton_stopping",
            "stamp": stamp,
            "producer": _geant4_version_str(),
            "measurement_gate": "GATE_OPEN",
            "gate_type": "measurement_FAIL",
            "absorbed": False,
            "provisional": True,
            "scope_caveats": [
                f"simulation_failed: {type(exc).__name__}: {exc}",
                f"traceback: {tb}",
            ],
            "citations": citations,
        }
        rec_path = out / f"antimatter_verify_{stamp}.json"
        rec_path.write_text(json.dumps(record, indent=2))
        print(f"[antimatter+verify] FAIL — wrote {rec_path}")
        return 91

    # ----- GATE STATE -------------------------------------------------
    # D80 (g_hexa_only): absorbed=true is reserved for the day a hexa-
    # native MC-transport port lands AND passes this round. Today
    # transport_kernel.py is Python — so even on a clean parity PASS,
    # the record stays absorbed=false, provisional=true.
    measurement_gate = (
        "GATE_CLOSED_MEASURED (substrate)" if overall_pass else "GATE_OPEN"
    )
    # G7 typed gate_type — Geant4 substrate IS installed (we got here);
    # substrate ran a measured parity pass, but no hexa-native MC-
    # transport kernel exists yet → D80 hexa-native-absent + provisional.
    # If the parity loop failed, surface measurement_FAIL instead.
    if overall_pass:
        gate_type = "hexa-native-absent"
    else:
        gate_type = "measurement_FAIL"

    scope_caveats: list[str] = [
        "D80 g_hexa_only — hexa-native MC-transport port "
        "(kernels/mc_transport/*.hexa) does NOT yet exist; "
        "transport_kernel.py is Python. provisional=true, "
        "absorbed=false until that port lands and passes this same "
        "parity round.",
        "Closed-form CSDA oracle (PDG eq. 34.5, density-effect δ=0) "
        "omits four physics channels Geant4 includes: shell "
        "corrections, density effect δ, energy-loss straggling, "
        "nuclear stopping. Antiproton-specific: in-flight "
        "annihilation removes the projectile before completing "
        "CSDA — under-shoot is expected.",
        "Tolerance is one-sided: substrate ≤ kernel_CSDA + 1*stdev. "
        "Under-shoot magnitude IS the annihilation-channel signature, "
        "NOT a parity failure.",
        "Cited arxiv:2407.06721 / arxiv:2503.04868 are annihilation-"
        "AT-REST experiments (ASACUSA 250 eV slow extraction), NOT "
        "antiproton-on-Al stopping-distance oracles. Oracle of "
        "record for THIS measurement is PDG eq. 34.5 (kernel "
        "closed-form).",
        "Reference geometry is a 5×5×50 cm Al block — NOT a sourced "
        "CERN AD / ELENA experimental geometry.",
        "geant4_pybind 0.1.3 is the PyPI wheel; producer pin string "
        "captures G4VERSION_NUMBER (e.g. 1141 = Geant4 11.4.1).",
    ]

    record = {
        "domain": "antimatter",
        "verb": "verify",
        "kind": "geant4_antiproton_stopping",
        "stamp": stamp,
        "producer": _geant4_version_str(),
        "measurement_gate": measurement_gate,
        "gate_type": gate_type,
        "absorbed": False,
        "provisional": True,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "parity_block": parity_block,
        "parity_pass_reasons": pass_reasons,
        "parity_fail_reasons": fail_reasons,
        "tolerance_policy": (
            "one-sided: substrate ≤ kernel_CSDA + 1*stdev. Under-shoot "
            "is the annihilation-channel signature (physics finding, "
            "not parity failure)."
        ),
        "target_material": {
            "name": "G4_Al",
            "z": 13,
            "a_gpermol": 26.9815385,
            "mean_excitation_i_ev": 166.0,
        },
        "kernel_reuse": (
            "kernels/mc_transport/ (D72 — 4th consumer; clearest N+M payoff)"
        ),
    }
    rec_path = out / f"antimatter_verify_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(
        f"[antimatter+verify] wrote {rec_path}  gate={measurement_gate}  "
        f"absorbed={record['absorbed']}  provisional={record['provisional']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(
        main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/antimatter_verify")
    )
