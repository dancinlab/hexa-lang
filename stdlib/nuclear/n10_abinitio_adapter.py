#!/usr/bin/env python3
# n10_abinitio_adapter.py — `nuclear + verify` ab-initio drip-line
# adapter for light nuclei A<=30 (NUCLEAR.md §4.5 · N10 cohort · B path
# · wrap-as-is · Phase 5 land).
#
# NUCLEAR.md §2 (a) gate (drip-line slice) + §4.5 N10 spec + §6.3 Phase 5
# land target. Sibling adapter shape — see `hexa-lang/stdlib/nuclear/
# hfbtho_adapter.py` (N6 wrap-as-is presence-only shape, the Phase 1
# reference). N10 predicts the ground-state energy + proton/neutron
# separation energies (Sp/Sn) -> drip-line flag (Sp<0 or Sn<0) for LIGHT
# nuclei from a chiral-EFT NN(+3N) interaction, ab initio. This is the
# first-principles slice of gate (a) for A<=30 where NCSM/CCSD/IM-SRG are
# tractable; it remains a PREDICTION (model + basis truncation), never a
# measurement.
#
# Backends (fallback chain — first present wins; all-missing → install-
# gated honest skip, which IS the PASS verdict per NUCLEAR.md §3.3):
#   1. NCSM     — No-Core Shell Model (Navratil / Barrett). Bare A-body
#                 problem in a harmonic-oscillator basis (Nmax trunc).
#                 e.g. NCSD / pAntoine / MFDn drivers.
#   2. CCSD     — Coupled cluster singles-doubles (Hagen / Papenbrock,
#                 ORNL). Scales to heavier than NCSM via reference state.
#   3. IM-SRG   — In-medium similarity renormalization group (Hergert /
#                 Bogner, MSU). Magnus / flow-equation solvers.
#   4. SympNCSM — Symplectic NCSM (Dytrych / Draayer, LSU). Sp(3,R)
#                 symmetry-adapted basis (deformation-efficient).
#
# Ab-initio codes need a chiral-EFT interaction matrix-element file
# (NN+3N, e.g. EM 1.8/2.0, NNLO_sat) — a large `.bin`/`.h5` weights
# footprint — so `weights-missing` (interaction ME file absent) is a
# distinct honest-skip class from `install-gated` (mirror of N6 BSk
# weights-missing + N9 interaction-file class).
#
# D72 analog: nuclear-domain consumer — single-file thin adapter.
#             NO hexa-native kernel promotion (large-basis many-body
#             solvers are the anti-pattern port target — wrap-as-is
#             forever per NUCLEAR.md §6.2).
# D80 analog: install-gated when no backend found; nuclear-novel-
#             discovery-simulation when a backend ran (presence-only this
#             land — many-body solve run-out is the Phase 5+ follow-on).
# R4 invariant: absorbed = false ALWAYS — gs-energy / Sp / Sn / drip-line
#               flag is a *model prediction* (truncated-basis ab-initio
#               solve), NOT a *measurement*. Promotion to absorbed=true
#               requires beam-time + mass / separation-energy measurement
#               at a rare-isotope facility (FRIB / RIKEN / GSI) + IUPAC-
#               class confirmation. OUT OF SCOPE (NUCLEAR.md §7).
# Gate value: `nuclear-novel-discovery-simulation` (mirror of N6) or
#             `install-gated` (no backend) / weights-missing surfaced in
#             the record's skipped_reason / interaction_probe.

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import time
from pathlib import Path


# --- A<=30 scope guard (NUCLEAR.md §4.5) --------------------------------

# NCSM / CCSD basis explosion bounds the ab-initio reach. NUCLEAR.md §4.5
# nominal scope is A<=30 (light nuclei). Heavier requests are accepted but
# the record carries an out-of-scope honest flag (never a hard refusal —
# @D d2 surfaces breakthrough paths, never "impossible": ab-initio reach
# is actively extending into medium-mass via IM-SRG / CCSD).
_ABINITIO_A_SOFT_CEILING = 30


def _which(name: str) -> str | None:
    """shutil.which wrapper — returns absolute path or None."""
    p = shutil.which(name)
    return p if p else None


def _probe_ncsm() -> tuple[bool, str | None, str | None]:
    """NCSM (Navratil/Barrett) — No-Core Shell Model. $NCSM_BIN env or
    PATH probe (`ncsd` / `mfdn` / `pantoine` drivers). Presence
    detection only — we do NOT launch a many-body solve here (needs a
    chiral-EFT interaction ME file + Nmax basis build + minutes-to-hours
    of CPU/MPI; Phase 5+ follow-on, mirror of N6 SCF-not-invoked)."""
    env = os.environ.get("NCSM_BIN", "").strip()
    if env:
        p = Path(env).expanduser()
        if p.exists():
            return True, str(p), f"NCSM_BIN={env}"
    for name in ("ncsd", "mfdn", "pantoine", "ncsm"):
        p = _which(name)
        if p:
            return True, p, f"PATH:{name}"
    return False, None, None


def _probe_ccsd() -> tuple[bool, str | None, str | None]:
    """CCSD coupled cluster (Hagen/Papenbrock, ORNL). $CCSD_BIN env or
    PATH probe (`ccsd` / `nucleus_cc`)."""
    env = os.environ.get("CCSD_BIN", "").strip()
    if env:
        p = Path(env).expanduser()
        if p.exists():
            return True, str(p), f"CCSD_BIN={env}"
    for name in ("nucleus_cc", "ccsd"):
        p = _which(name)
        if p:
            return True, p, f"PATH:{name}"
    return False, None, None


def _probe_imsrg() -> tuple[bool, str | None, str | None]:
    """IM-SRG in-medium SRG (Hergert/Bogner, MSU). $IMSRG_BIN env or
    PATH probe (`imsrg++` / `imsrg`)."""
    env = os.environ.get("IMSRG_BIN", "").strip()
    if env:
        p = Path(env).expanduser()
        if p.exists():
            return True, str(p), f"IMSRG_BIN={env}"
    for name in ("imsrg++", "imsrg"):
        p = _which(name)
        if p:
            return True, p, f"PATH:{name}"
    return False, None, None


def _probe_symp_ncsm() -> tuple[bool, str | None, str | None]:
    """Symplectic NCSM (Dytrych/Draayer, LSU). $SYMP_NCSM_BIN env or
    PATH probe (`lsu3shell` / `symp_ncsm`)."""
    env = os.environ.get("SYMP_NCSM_BIN", "").strip()
    if env:
        p = Path(env).expanduser()
        if p.exists():
            return True, str(p), f"SYMP_NCSM_BIN={env}"
    for name in ("lsu3shell", "symp_ncsm"):
        p = _which(name)
        if p:
            return True, p, f"PATH:{name}"
    return False, None, None


# Fallback chain order — NCSM first (most-established light-nuclei ab
# initio), CCSD second (extends reach via reference state), IM-SRG third
# (medium-mass extension), symplectic NCSM fourth (deformed light nuclei).
_BACKENDS = (
    ("ncsm", _probe_ncsm),
    ("ccsd", _probe_ccsd),
    ("imsrg", _probe_imsrg),
    ("symp_ncsm", _probe_symp_ncsm),
)


def _detect_backend() -> tuple[str | None, str | None, str | None, dict]:
    """Walk the fallback chain. Return (name, bin_path, detection_note,
    full_probe_map)."""
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


def _probe_interaction() -> dict:
    """Probe for the chiral-EFT interaction ME file under
    $CHIRAL_INT_DIR. Surfaces `weights-missing` when the binary is
    present but the NN(+3N) matrix elements are absent (mirror of N6 BSk
    + N9 interaction-file weights-missing class)."""
    env = os.environ.get("CHIRAL_INT_DIR", "").strip()
    if env:
        d = Path(env).expanduser()
        if d.is_dir():
            for f in d.iterdir():
                if f.suffix.lower() in (".bin", ".h5", ".dat", ".me2j"):
                    return {
                        "present": True,
                        "path": str(f),
                        "note": f"CHIRAL_INT_DIR -> {f.name}",
                    }
    return {
        "present": False,
        "path": None,
        "note": (
            "chiral-EFT NN(+3N) interaction ME file not found under "
            "$CHIRAL_INT_DIR (.bin/.h5/.dat/.me2j) — weights-missing "
            "class"
        ),
    }


# Install hints surfaced in the skip record when no backend is found.
_INSTALL_HINTS = {
    "ncsm": (
        "NCSM — No-Core Shell Model (Navratil / Barrett). Drivers: "
        "NCSD / MFDn / pAntoine. Published parameters; chiral-EFT "
        "NN(+3N) interaction ME file under $CHIRAL_INT_DIR. Build + "
        "set $NCSM_BIN. See Navratil group releases."
    ),
    "ccsd": (
        "CCSD — coupled cluster singles-doubles (Hagen / Papenbrock, "
        "ORNL). Reference-state expansion; scales beyond NCSM. Build "
        "+ set $CCSD_BIN. Chiral-EFT interaction under $CHIRAL_INT_DIR."
    ),
    "imsrg": (
        "IM-SRG — in-medium similarity renormalization group "
        "(Hergert / Bogner, MSU). Source: github.com/ragnarstroberg/"
        "imsrg (imsrg++). Build + set $IMSRG_BIN. Chiral-EFT "
        "interaction under $CHIRAL_INT_DIR."
    ),
    "symp_ncsm": (
        "Symplectic NCSM — Sp(3,R) symmetry-adapted basis (Dytrych / "
        "Draayer, LSU). Driver: LSU3shell. Build + set "
        "$SYMP_NCSM_BIN. Deformation-efficient light-nuclei ab initio."
    ),
}


# --- per-backend run stub (B path · wrap-as-is presence-only) -----------


def _run_backend_stub(
    backend: str,
    bin_path: str | None,
    Z: int,
    N: int,
    interaction_present: bool,
    in_scope: bool,
) -> tuple[dict, str]:
    """Acknowledge the backend without launching a many-body solve.
    Returns (prediction_dict, run_note). gs-energy / Sp / Sn / drip-line
    flag are None placeholders so the record schema is stable from first
    land."""
    A = Z + N
    weights_note = (
        "chiral-EFT interaction present"
        if interaction_present
        else "chiral-EFT interaction MISSING (weights-missing) — even "
        "with the binary present, the many-body solve cannot proceed "
        "without the NN(+3N) matrix elements"
    )
    scope_note = (
        f"A={A} within ab-initio scope (A<={_ABINITIO_A_SOFT_CEILING})"
        if in_scope
        else f"A={A} exceeds the ab-initio soft ceiling "
        f"(A<={_ABINITIO_A_SOFT_CEILING}) — NCSM/CCSD basis explosion; "
        f"breakthrough paths surfaced (@D d2): IM-SRG / CCSD medium-"
        f"mass extension, symmetry-adapted bases — out-of-scope != "
        f"impossible"
    )
    note = (
        f"backend={backend} detected at {bin_path!r}; first-land "
        f"adapter is wrap-as-is presence-only — many-body solve NOT "
        f"invoked. query=(Z={Z}, N={N}, A={A}). {weights_note}. "
        f"{scope_note}. Follow-on cohort: build basis + load chiral-"
        f"EFT interaction + solve gs energy + neighbor masses -> "
        f"Sp/Sn -> drip-line flag."
    )
    prediction = {
        "ground_state_energy_MeV": None,
        "Sp_MeV": None,
        "Sn_MeV": None,
        "drip_line_flag": None,  # Sp<0 (proton) or Sn<0 (neutron)
        "uncertainty_basis_truncation_MeV": None,
        "backend_present_but_not_run": True,
        "interaction_present": interaction_present,
        "within_abinitio_scope": in_scope,
    }
    return prediction, note


# --- record emit --------------------------------------------------------


def main(out_dir: str, Z: int, N: int) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    A = Z + N
    in_scope = A <= _ABINITIO_A_SOFT_CEILING

    citations = [
        "NCSM — Barrett / Navratil / Vary, 'Ab initio no core shell "
        "model' (Prog Part Nucl Phys 69:131, 2013). No-core shell "
        "model for light nuclei.",
        "CCSD — Hagen / Papenbrock / Hjorth-Jensen / Dean, 'Coupled-"
        "cluster computations of atomic nuclei' (Rep Prog Phys "
        "77:096302, 2014).",
        "IM-SRG — Hergert / Bogner / Morris / Schwenk / Tsukiyama, "
        "'The In-Medium Similarity Renormalization Group' (Phys Rep "
        "621:165, 2016). Source: github.com/ragnarstroberg/imsrg .",
        "Symplectic NCSM — Dytrych / Launey / Draayer et al., "
        "Sp(3,R) symmetry-adapted no-core shell model (LSU3shell).",
        "Chiral-EFT interactions: Entem-Machleidt / EM 1.8-2.0 / "
        "NNLO_sat NN+3N — the ab-initio Hamiltonian input; basis-"
        "truncation (Nmax) convergence is the honest uncertainty axis.",
        "arxiv:2105.01035 — Wang / Huang / Kondev / Audi / Naimi, AME "
        "2020 (separation-energy / drip-line cross-validation oracle). "
        "IAEA NSDC — https://nds.iaea.org/relnsd/ .",
        "NUCLEAR.md §2 (a) gate (drip-line slice) + §4.5 (N10 cohort "
        "spec) + §5.5 (external lib survey) + §6.3 (Phase 5 N10 land "
        "target) + §7 (R4 invariant block — wet-lab dependency "
        "permanent).",
    ]

    scope_caveats = [
        "(s1) Ab-initio ground-state energy / Sp / Sn / drip-line flag "
        "are MODEL outputs from a truncated-basis many-body solve, NOT "
        "measurements. The result depends on the chiral-EFT "
        "interaction (EM 1.8/2.0 vs NNLO_sat), the 3N-force "
        "treatment, and the basis truncation (NCSM Nmax / CCSD "
        "model space). 'predicted drip-line at Sn<0' != 'observed "
        "unbound nucleus'. R4 invariant blocks any absorbed=true "
        "promotion for nuclear-novel-discovery-simulation records "
        "(NUCLEAR.md §7).",
        "(s2) 5-gate evaluation (NUCLEAR.md §2): this record fills the "
        "drip-line slice of the (a) gate (mass / separation energy) "
        "ab initio. The (b) spectroscopy, (c) decay, (d) production "
        "sigma, (e) detection gates are NOT addressed. Even with all "
        "5 sim gates PASS, (d) and (e) remain wet-lab dependent "
        "permanently — a mass / separation-energy measurement at a "
        "rare-isotope facility (FRIB / RIKEN / GSI) is required, never "
        "substituted by sim.",
        "(s3) Scope limit A<=30 (NUCLEAR.md §4.5): NCSM / CCSD basis "
        "dimension explodes combinatorially with A and Nmax, bounding "
        "the tractable ab-initio reach to light nuclei. Heavier "
        "requests are accepted with an out-of-scope flag (within_"
        "abinitio_scope=false) but NEVER a hard refusal — per @D d2 "
        "breakthrough paths stay surfaced (IM-SRG / CCSD medium-mass "
        "extension, symmetry-adapted bases): out-of-scope != "
        "impossible.",
        "(s4) Interaction-file dependency (weights-missing class): "
        "even with a binary present, the many-body solve cannot "
        "proceed without the chiral-EFT NN(+3N) matrix-element file "
        "(.bin/.h5/.me2j) under $CHIRAL_INT_DIR. This adapter "
        "surfaces `weights-missing` in interaction_probe rather than "
        "fabricating an energy / separation energy (NUCLEAR.md §3.3 "
        "'Don't invent').",
        "(s5) First-land wrap-as-is: when a backend is detected on "
        "this host, this adapter records the presence but does NOT "
        "launch a many-body solve (basis build + chiral-EFT "
        "interaction load + solve + neighbor-mass differencing for "
        "Sp/Sn + output parse). Follow-on cohort: real backend "
        "invocation + parse -> populated gs-energy / Sp / Sn / drip-"
        "line flag + Nmax-extrapolation uncertainty. Mirror of "
        "NUCLEAR.md §6.2 Phase 5+ schedule. Wet-lab dependency "
        "unchanged regardless of run-out (§3.2)."
    ]

    chosen, bin_path, detection_note, probe_map = _detect_backend()
    interaction_probe = _probe_interaction()

    record: dict = {
        "domain": "nuclear",
        "verb": "verify",
        "kind": "abinitio_dripline_prediction",
        "stamp": stamp,
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,  # R4 invariant — ALWAYS false (NUCLEAR §7)
        "provisional": True,
        "query": {
            "Z": Z,
            "N": N,
            "A": A,
            "within_abinitio_scope": in_scope,
            "abinitio_A_soft_ceiling": _ABINITIO_A_SOFT_CEILING,
        },
        "backend_probe": probe_map,
        "interaction_probe": interaction_probe,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "provenance": {
            "source_citation": (
                "NUCLEAR.md §2 (a) + §4.5 + §5.5 + §6.3 + §7 (this "
                "paper)"
            ),
            "primary_refs": [
                "NCSM — Barrett/Navratil/Vary PPNP 69:131 (2013).",
                "CCSD — Hagen et al. RPP 77:096302 (2014).",
                "IM-SRG — Hergert et al. Phys Rep 621:165 (2016).",
                "arxiv:2105.01035 — AME2020 drip-line oracle.",
            ],
            "fallback_chain": [
                "ncsm", "ccsd", "imsrg", "symp_ncsm"
            ],
        },
        "nuclear_anchor": (
            "NUCLEAR.md §2 (a) gate (drip-line slice) + §4.5 (N10 "
            "cohort spec) + §6.3 (Phase 5 land target) + §7 (R4 "
            "invariant block)"
        ),
    }

    if chosen is None:
        # Honest skip — no ab-initio backend installed at all.
        install_hint_lines = [
            f"  · {name}: {_INSTALL_HINTS[name]}"
            for name, _ in _BACKENDS
        ]
        skipped_reason = (
            "No ab-initio many-body backend found on host. Probed (in "
            "fallback order) ncsm -> ccsd -> imsrg -> symp_ncsm; all "
            "absent. Install one of:\n"
            + "\n".join(install_hint_lines)
        )
        record["producer"] = "n10_abinitio_adapter.py@all-skipped"
        record["backend"] = "all-skipped"
        record["gate_type"] = "install-gated"
        record["skipped_reason"] = skipped_reason
        record["prediction"] = None
        headline = (
            "skip: no ab-initio backend present (install-gated · "
            "honest-skip = PASS per §3.3)"
        )
    else:
        prediction, run_note = _run_backend_stub(
            chosen, bin_path, Z, N, interaction_probe["present"],
            in_scope,
        )
        record["producer"] = f"n10_abinitio_adapter.py@{chosen}"
        record["backend"] = chosen
        record["backend_bin"] = bin_path
        record["backend_detection_note"] = detection_note
        record["gate_type"] = "nuclear-novel-discovery-simulation"
        record["skipped_reason"] = (
            None
            if interaction_probe["present"]
            else (
                "Backend present but chiral-EFT interaction file "
                "MISSING (weights-missing) — see interaction_probe. "
                "Many-body solve cannot proceed; honest skip per §3.3 "
                "'Don't invent'."
            )
        )
        record["prediction"] = prediction
        record["run_note"] = run_note
        wm = "" if interaction_probe["present"] else " · weights-missing"
        sc = "" if in_scope else " · A out-of-scope (flagged, not refused)"
        headline = (
            f"ok: {chosen} present at {bin_path} — presence-only "
            f"(wrap-as-is first land; drip-line=stub{wm}{sc})"
        )

    rec_path = (
        out / f"nuclear_verify_n10_abinitio_{Z}_{N}_{stamp}.json"
    )
    rec_path.write_text(json.dumps(record, indent=2))

    print(f"[nuclear+verify · n10_abinitio] wrote {rec_path}")
    print(f"  headline: {headline}")
    print(
        f"  backend={record.get('backend')!r} "
        f"gate_type={record.get('gate_type')!r} "
        f"absorbed={record.get('absorbed')}"
    )
    if record.get("skipped_reason"):
        first_line = str(record["skipped_reason"]).splitlines()[0]
        print(f"  skipped_reason: {first_line}")
    print(
        f"  query: Z={Z}  N={N}  A={A}  in_scope={in_scope} "
        f"(ceiling A<={_ABINITIO_A_SOFT_CEILING})"
    )
    print(
        "[nuclear+verify · n10_abinitio] absorbed=false (R4 "
        "invariant; ab-initio many-body solve is a prediction, NEVER "
        "measurement — NUCLEAR.md §7 wet-lab dependency permanent)"
    )
    return 0


def _parse_argv(argv: list[str]) -> tuple[str, int, int]:
    p = argparse.ArgumentParser(
        prog="n10_abinitio_adapter.py",
        description=(
            "Thin adapter for nuclear ab-initio drip-line prediction "
            "(gs energy, Sp/Sn, drip-line flag) for light nuclei "
            "A<=30 (NUCLEAR.md §4.5 N10 cohort · B path · wrap-as-is). "
            "Fallback chain: NCSM -> CCSD -> IM-SRG -> symplectic "
            "NCSM. R4 invariant: absorbed=false always."
        ),
    )
    p.add_argument("Z", type=int, help="Proton number (atomic number).")
    p.add_argument("N", type=int, help="Neutron number.")
    p.add_argument("out_dir", help="Output directory for JSON record.")
    ns = p.parse_args(argv)
    if ns.Z < 1:
        p.error(f"Z must be >= 1, got Z={ns.Z}")
    if ns.N < 0:
        p.error(f"N must be >= 0, got N={ns.N}")
    return ns.out_dir, ns.Z, ns.N


if __name__ == "__main__":
    out_dir, Z, N = _parse_argv(sys.argv[1:])
    sys.exit(main(out_dir, Z, N))
