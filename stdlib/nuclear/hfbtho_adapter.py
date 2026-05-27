#!/usr/bin/env python3
# hfbtho_adapter.py — `nuclear + verify` HFB mass/binding/deformation thin
# adapter (NUCLEAR.md §6 · N6 first land · B path · wrap-as-is).
#
# NUCLEAR.md §2 (a) gate + §4.1 N6 spec + §6 Phase 1 land target.
# Sibling adapter pattern — see `hexa-lang/stdlib/material/csp_adapter.py`
# (N1 wrap-as-is shape) and `hexa-lang/stdlib/material/cross_code_dft.py`
# (N4 multi-source consensus shape). hfbtho_adapter.py is the FIRST
# `nuclear+verify`-shaped producer; B path = wrap external HFB code,
# NEVER port (anti-pattern per NUCLEAR.md §3.3 + RTSC.md §9.9.1 — HFBTHO
# is ~50K LOC Fortran 95 + decades of physics validation).
#
# Backends (fallback chain — first present wins; all-missing → install-gated):
#   1. HFBTHO    — Stoitsov / Schunck / Kortelainen / Nazarewicz / Ring /
#                  Werner. Axially-deformed Skyrme HFB, Fortran 95.
#                  Citation: arxiv:1810.10825 (3.00 release).
#                  Source: https://gitlab.com/hfbtho/hfbtho
#   2. HFODD     — Triaxial Skyrme HFB (more general than HFBTHO).
#                  Citation: Dobaczewski / Olbratowski code lineage.
#   3. FRDM2012  — Möller-Nix-Iwamoto-Kratz finite-range droplet model.
#                  Citation: arxiv:1508.06294. Published mass table —
#                  Z=8..110, N=8..250. Openly cited, no install required
#                  (just the .dat file in $FRDM_TABLE_DIR).
#   4. BSk_table — Goriely et al. BSk22/24/27 functional family parameter
#                  files. Citation: arxiv:1607.06961.
#                  Source: http://www-astro.ulb.ac.be/bruslib/
#
# D72 analog: 1st nuclear-domain consumer — single-file thin adapter.
#             NO hexa-native kernel promotion (no shared math with any
#             existing producer; HFB is a self-consistent DFT iteration,
#             not a closed-form formula).
# D80 analog: install-gated when no backend found; simulation-only-
#             prediction when a backend ran. NEVER hexa-native (B path =
#             wrap-as-is; HFBTHO Fortran ecosystem is the anti-pattern
#             port target per NUCLEAR.md §3.3).
# R4 invariant: absorbed = false ALWAYS — HFB output is a *model
#               prediction* (DFT-of-nucleus), NOT a *measurement*.
#               Promotion to absorbed=true requires GSI/JINR/RIKEN
#               heavy-ion accelerator beam-time + SHIP/DGFRS/GARIS
#               recoil-separator detection + IUPAC priority assignment.
#               OUT OF SCOPE for this stack (NUCLEAR.md §7).
# Gate value: `nuclear-novel-discovery-simulation` (mirror of RTSC §9.10
#             N5 `novel-discovery-simulation`, distinct shape value to
#             keep the 2 stacks parallel-but-separate).

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import time
from pathlib import Path


# ─── backend detection (PATH probe + env var + common install layouts) ──


def _which(name: str) -> str | None:
    """shutil.which wrapper — returns absolute path or None."""
    p = shutil.which(name)
    return p if p else None


def _probe_hfbtho() -> tuple[bool, str | None, str | None]:
    """Return (present, primary_bin, detection_note).

    HFBTHO canonical layout: `hfbtho_main` (or `hfbtho`) Fortran 95
    binary. $HFBTHO_BIN env var (explicit path) takes precedence; PATH
    fallback follows.

    For *presence detection only*, we accept either the binary on PATH
    OR $HFBTHO_BIN pointing at a built executable. We do NOT actually
    invoke the binary here — that requires a paired Skyrme parameter
    file under $HFBTHO_PARAM_DIR and tens of seconds of CPU per
    converged (Z, N) point (separate scope).
    """
    env = os.environ.get("HFBTHO_BIN", "").strip()
    if env:
        p = Path(env).expanduser()
        if p.exists():
            return True, str(p), f"HFBTHO_BIN={env}"
    for name in ("hfbtho_main", "hfbtho"):
        p = _which(name)
        if p:
            return True, p, f"PATH:{name}"
    return False, None, None


def _probe_hfodd() -> tuple[bool, str | None, str | None]:
    """HFODD canonical layout: `hfodd` Fortran binary (triaxial Skyrme
    HFB, more general than HFBTHO).  $HFODD_BIN env or PATH probe."""
    env = os.environ.get("HFODD_BIN", "").strip()
    if env:
        p = Path(env).expanduser()
        if p.exists():
            return True, str(p), f"HFODD_BIN={env}"
    for name in ("hfodd",):
        p = _which(name)
        if p:
            return True, p, f"PATH:{name}"
    return False, None, None


def _probe_frdm_table() -> tuple[bool, str | None, str | None]:
    """FRDM2012 published mass table (arxiv:1508.06294).

    No binary required — just the .dat file. Canonical locations:
      $FRDM_TABLE_DIR/FRDM2012.dat
      $FRDM_TABLE_DIR/frdm2012.dat
      ~/.local/share/frdm2012/FRDM2012.dat
    """
    env = os.environ.get("FRDM_TABLE_DIR", "").strip()
    candidates = []
    if env:
        d = Path(env).expanduser()
        candidates.extend([d / "FRDM2012.dat", d / "frdm2012.dat"])
    candidates.append(
        Path.home() / ".local/share/frdm2012/FRDM2012.dat"
    )
    for c in candidates:
        if c.exists():
            return True, str(c), f"FRDM_TABLE_DIR or default → {c.name}"
    return False, None, None


def _probe_bsk_table() -> tuple[bool, str | None, str | None]:
    """BSk22/24/27 parameter tables (arxiv:1607.06961). Bruslib
    distribution: http://www-astro.ulb.ac.be/bruslib/

    Canonical layout: $BRUSLIB_DIR contains BSk22.dat / BSk24.dat /
    BSk27.dat or similar.
    """
    env = os.environ.get("BRUSLIB_DIR", "").strip()
    if env:
        d = Path(env).expanduser()
        if d.is_dir():
            for fname in ("BSk22.dat", "BSk24.dat", "BSk27.dat",
                          "bsk22.dat", "bsk24.dat", "bsk27.dat"):
                f = d / fname
                if f.exists():
                    return True, str(f), f"BRUSLIB_DIR → {fname}"
    return False, None, None


# Fallback chain order — HFBTHO first (most-mature open-source HFB),
# HFODD second (more general but heavier install), FRDM table third
# (no install — published reference), BSk table fourth (cross-validation).
_BACKENDS = (
    ("hfbtho", _probe_hfbtho),
    ("hfodd", _probe_hfodd),
    ("frdm_table", _probe_frdm_table),
    ("bsk_table", _probe_bsk_table),
)


def _detect_backend() -> tuple[str | None, str | None, str | None, dict]:
    """Walk the fallback chain. Return (name, bin_path, detection_note,
    full_probe_map). full_probe_map captures the per-backend present/
    absent state for the record's `backend_probe` field — honest
    visibility into *why* each fallback didn't fire."""
    probe_map: dict = {}
    chosen: tuple[str, str | None, str | None] | None = None
    for name, probe in _BACKENDS:
        present, bin_path, note = probe()
        probe_map[name] = {
            "present": present,
            "bin_path": bin_path,
            "detection_note": note,
        }
        if present and chosen is None:
            chosen = (name, bin_path, note)
    if chosen is None:
        return None, None, None, probe_map
    return chosen[0], chosen[1], chosen[2], probe_map


# Install hints surfaced in the skip record when no backend is found.
_INSTALL_HINTS = {
    "hfbtho": (
        "HFBTHO — Stoitsov/Schunck/Kortelainen/Nazarewicz/Ring/Werner "
        "(open-source). Source: https://gitlab.com/hfbtho/hfbtho — "
        "clone + Fortran 95 build (gfortran + OpenMP + LAPACK). "
        "Set $HFBTHO_BIN to the built executable. Citation: "
        "arxiv:1810.10825 (3.00 release paper)."
    ),
    "hfodd": (
        "HFODD — Dobaczewski/Olbratowski (triaxial Skyrme HFB, more "
        "general than HFBTHO; heavier compute). Distribution: "
        "github.com/skyrme-hfb/hfodd (active mirror). Set $HFODD_BIN."
    ),
    "frdm_table": (
        "FRDM2012 — Möller/Nix/Iwamoto/Kratz openly-published mass "
        "table. Download from arxiv:1508.06294 supplementary or "
        "https://t2.lanl.gov/nis/molleretal/publications/ . Place "
        "FRDM2012.dat under $FRDM_TABLE_DIR or "
        "~/.local/share/frdm2012/ . Lightest install — table only."
    ),
    "bsk_table": (
        "BSk22/24/27 — Goriely/Chamel/Pearson Brussels-Skyrme "
        "functional family. Source: http://www-astro.ulb.ac.be/"
        "bruslib/ — place BSk22.dat / BSk24.dat / BSk27.dat under "
        "$BRUSLIB_DIR. Citation: arxiv:1607.06961."
    ),
}


# ─── per-backend run stubs (B path · wrap-as-is) ────────────────────────
#
# These are intentionally minimal: when a backend is present we acknowledge
# the binary/table and emit an empty prediction with a `backend_present_
# but_not_run` note. ACTUAL run-out (which requires a paired parameter
# file + per-(Z,N) seconds-to-minutes of HFB self-consistent-field
# iteration + a fragile output parser) is NOT in scope for the first
# land — that's the NUCLEAR.md §6.2 Phase 2/3 follow-on.
#
# R4 invariant holds either way (absorbed=false always).


def _run_backend_stub(
    backend: str,
    bin_path: str | None,
    Z: int,
    N: int,
) -> tuple[dict, str]:
    """Acknowledge the backend without actually invoking an HFB SCF
    iteration / table lookup parse. Returns (prediction_dict, run_note).

    For the wrap-as-is first land we emit an empty prediction with a
    clear note that the binary/table was found but no run was launched.
    Follow-on cohort: spawn the backend (or parse the .dat file),
    populate {mass_excess_MeV, BE_per_nucleon, beta2, beta4}.
    """
    note = (
        f"backend={backend} detected at {bin_path!r}; first-land "
        f"adapter is wrap-as-is presence-only — HFB SCF / table parse "
        f"not invoked. query=(Z={Z}, N={N}). Follow-on cohort: "
        f"actually spawn {backend} + parse output for mass_excess + "
        f"binding_energy_per_nucleon + beta2 + beta4."
    )
    prediction = {
        "mass_excess_MeV": None,
        "binding_energy_per_nucleon_MeV": None,
        "beta2_quadrupole": None,
        "beta4_hexadecapole": None,
        "uncertainty_2sigma_MeV": None,
        "backend_present_but_not_run": True,
    }
    return prediction, note


# ─── record emit ────────────────────────────────────────────────────────


def main(out_dir: str, Z: int, N: int) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    A = Z + N

    citations = [
        "arxiv:1810.10825 — Stoitsov et al., 'Axially Deformed "
        "Solution of the Skyrme-Hartree-Fock-Bogoliubov Equations "
        "Using the Transformed Harmonic Oscillator Basis (III) HFBTHO "
        "(v3.00)' (HFBTHO primary citation).",
        "arxiv:1607.06961 — Goriely et al., 'Further explorations of "
        "Skyrme-Hartree-Fock-Bogoliubov mass formulas' (BSk22/24/27 "
        "functional family).",
        "arxiv:1508.06294 — Möller / Sierk / Ichikawa / Sagawa, "
        "'Nuclear ground-state masses and deformations: FRDM(2012)' "
        "(FRDM2012 published mass table).",
        "arxiv:2105.01035 — Wang / Huang / Kondev / Audi / Naimi, "
        "'The AME 2020 atomic mass evaluation' (AME2020 — cross-"
        "validation oracle for sim predictions).",
        "arxiv:2004.06135 — UNEDF program review (Universal Nuclear "
        "Energy Density Functional consortium results).",
        "IAEA NSDC live evaluated nuclear data — https://nds.iaea.org/"
        "relnsd/ (cross-validation corpus).",
        "NUCLEAR.md §2 (5-gate taxonomy) + §4.1 (N6 cohort spec) + "
        "§6 (Phase 1 N6 land target) + §7 (R4 invariant block — wet-"
        "lab dependency permanent).",
    ]

    scope_caveats = [
        "(s1) HFB mass / binding-energy / deformation prediction is a "
        "model output, NOT a measurement. 'Z=119 후보일 가능성' ≠ "
        "'Z=119 후보임' ≠ 'Z=119 atom exists'. R4 invariant blocks "
        "any absorbed=true promotion for nuclear-novel-discovery-"
        "simulation records (NUCLEAR.md §7).",
        "(s2) 5-gate evaluation (NUCLEAR.md §2): this record fills "
        "ONLY the (a) gate (mass + structure). The other 4 gates "
        "((b) spectroscopy, (c) decay, (d) production cross-section, "
        "(e) detection signature) are NOT addressed by this adapter. "
        "Even with all 5 gates simulated, (d) and (e) remain wet-lab "
        "dependent permanently — sim-PASS never substitutes for "
        "heavy-ion accelerator beam-time at GSI / JINR / RIKEN.",
        "(s3) HFBTHO / HFODD / FRDM / BSk each use different "
        "functional choices (SLy4 / UNEDF1 / FRDM finite-range / "
        "BSk22 vs 24 vs 27) and different basis truncations. "
        "Mass-excess predictions typically scatter ±0.5-1.5 MeV "
        "across functionals — cross-functional ensemble would be "
        "needed for honest σ band (NUCLEAR.md §4.1 cross-validation "
        "via BSk22/24/27).",
        "(s4) First-land wrap-as-is: when a backend is detected on "
        "this host, this adapter records the presence but does NOT "
        "spawn an HFB SCF iteration (which requires per-(Z,N) "
        "seconds-to-minutes of CPU + a fragile parameter-file + "
        "output parser). Follow-on cohort: real backend invocation "
        "+ output parse → populated mass_excess / binding_energy / "
        "beta2 / beta4 prediction. Mirror of RTSC.md §9.9.1 Phase 2 "
        "stabilization audit.",
        "(s5) Wet-lab dependency permanent (NUCLEAR.md §3.2): even a "
        "fully-converged HFB output ranks the nuclide as 'accelerator "
        "beam-time priority candidate', NEVER 'discovered'. Promotion "
        "to absorbed=true would require (i) heavy-ion accelerator "
        "beam, (ii) recoil-separator detection (SHIP / DGFRS / GARIS), "
        "(iii) decay-chain identification, (iv) independent "
        "replication at a second laboratory, (v) IUPAC / IUPAP "
        "priority assignment — none achievable from sim.",
    ]

    chosen, bin_path, detection_note, probe_map = _detect_backend()

    record: dict = {
        "domain": "nuclear",
        "verb": "verify",
        "kind": "hfb_mass_prediction",
        "stamp": stamp,
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,  # R4 invariant — ALWAYS false (NUCLEAR §7)
        "provisional": True,
        "query": {
            "Z": Z,
            "N": N,
            "A": A,
        },
        "backend_probe": probe_map,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "provenance": {
            "source_citation": (
                "NUCLEAR.md §2 + §4.1 + §6 + §7 (this paper)"
            ),
            "primary_refs": [
                "arxiv:1810.10825 — HFBTHO 3.00 release.",
                "arxiv:1607.06961 — BSk22/24/27 functional family.",
                "arxiv:1508.06294 — FRDM2012 mass table.",
                "arxiv:2105.01035 — AME2020 evaluation oracle.",
            ],
            "fallback_chain": [
                "hfbtho", "hfodd", "frdm_table", "bsk_table"
            ],
        },
        "nuclear_anchor": (
            "NUCLEAR.md §2 (5-gate taxonomy) + §4.1 (N6 cohort spec) "
            "+ §6 (Phase 1 land target) + §7 (R4 invariant block)"
        ),
    }

    if chosen is None:
        # Honest skip — no backend installed at all.
        install_hint_lines = [
            f"  · {name}: {_INSTALL_HINTS[name]}"
            for name, _ in _BACKENDS
        ]
        skipped_reason = (
            "No HFB backend / mass table found on host. Probed (in "
            "fallback order) hfbtho → hfodd → frdm_table → bsk_table; "
            "all absent. Install one of:\n"
            + "\n".join(install_hint_lines)
        )
        record["producer"] = "hfbtho_adapter.py@all-skipped"
        record["backend"] = "all-skipped"
        record["gate_type"] = "install-gated"
        record["skipped_reason"] = skipped_reason
        record["prediction"] = None
        headline = (
            "skip: no HFB backend / mass table present "
            "(install-gated)"
        )
    else:
        # Backend present — first-land wrap-as-is acknowledges presence
        # without spawning an HFB SCF / table parse. R4 still holds.
        prediction, run_note = _run_backend_stub(chosen, bin_path, Z, N)
        record["producer"] = f"hfbtho_adapter.py@{chosen}"
        record["backend"] = chosen
        record["backend_bin"] = bin_path
        record["backend_detection_note"] = detection_note
        record["gate_type"] = "nuclear-novel-discovery-simulation"
        record["skipped_reason"] = None
        record["prediction"] = prediction
        record["run_note"] = run_note
        headline = (
            f"ok: {chosen} present at {bin_path} — presence-only "
            f"(wrap-as-is first land; prediction=stub)"
        )

    rec_path = out / f"nuclear_verify_n6_hfb_{Z}_{N}_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))

    print(f"[nuclear+verify · n6_hfb] wrote {rec_path}")
    print(f"  headline: {headline}")
    print(
        f"  backend={record.get('backend')!r} "
        f"gate_type={record.get('gate_type')!r} "
        f"absorbed={record.get('absorbed')}"
    )
    if record.get("skipped_reason"):
        # Truncated print — full reason in JSON.
        first_line = str(record["skipped_reason"]).splitlines()[0]
        print(f"  skipped_reason: {first_line}")
    print(f"  query: Z={Z}  N={N}  A={A}")
    print(
        "[nuclear+verify · n6_hfb] absorbed=false (R4 invariant; HFB "
        "is prediction, NEVER measurement — NUCLEAR.md §7 wet-lab "
        "dependency permanent)"
    )
    return 0


def _parse_argv(argv: list[str]) -> tuple[str, int, int]:
    p = argparse.ArgumentParser(
        prog="hfbtho_adapter.py",
        description=(
            "Thin adapter for nuclear HFB mass / binding-energy / "
            "deformation prediction (NUCLEAR.md §4.1 N6 cohort · "
            "B path · wrap-as-is). Fallback chain: HFBTHO → HFODD → "
            "FRDM2012-table → BSk-table. R4 invariant: absorbed=false "
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
        "out_dir",
        help="Output directory for JSON record.",
    )
    ns = p.parse_args(argv)
    if ns.Z < 1:
        p.error(f"Z must be ≥ 1, got Z={ns.Z}")
    if ns.N < 0:
        p.error(f"N must be ≥ 0, got N={ns.N}")
    return ns.out_dir, ns.Z, ns.N


if __name__ == "__main__":
    out_dir, Z, N = _parse_argv(sys.argv[1:])
    sys.exit(main(out_dir, Z, N))
