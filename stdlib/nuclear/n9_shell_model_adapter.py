#!/usr/bin/env python3
# n9_shell_model_adapter.py — `nuclear + verify` shell-model spectroscopy
# adapter (NUCLEAR.md §4.4 · N9 cohort · B path · wrap-as-is · Phase 5).
#
# NUCLEAR.md §2 (b) gate + §4.4 N9 spec + §6.3 Phase 5 land target.
# Sibling adapter shape — see `hexa-lang/stdlib/nuclear/hfbtho_adapter.py`
# (N6 wrap-as-is presence-only shape, the Phase 1 reference). N9 fills
# the (b) gate: shell-model level structure, B(E2), B(M1) via Lanczos
# diagonalization in a valence space with an effective interaction. This
# is sim-sufficient for valence-space-tractable cases (NUCLEAR.md §2 (b))
# but remains a PREDICTION — never a measurement.
#
# Backends (fallback chain — first present wins; all-missing → install-
# gated honest skip, which IS the PASS verdict per NUCLEAR.md §3.3):
#   1. KSHELL    — Shimizu (Tsukuba). Thick-restart Lanczos M-scheme
#                  shell model. Source: sites.google.com/alumni.tsukuba
#                  .ac.jp/kshell-nuclear .
#   2. NuShellX  — B.A. Brown @ MSU/FRIB. J-scheme proton-neutron
#                  formalism. Source: people.frib.msu.edu/~brown/ .
#   3. BIGSTICK  — Johnson (SDSU). OpenMP/MPI parallel shell model.
#                  Source: github.com/cwjsdsu/BigstickPublick .
#   4. ANTOINE   — Caurier (IPHC/Strasbourg, legacy). Original Lanczos
#                  shell-model code. Source: iphc.cnrs.fr/nutheo/ .
#
# Shell-model codes carry a large _setup/ footprint (interaction files
# USDA/USDB/KB3G/GXPF1 + model-space tables) — typically 1-10 GB
# (NUCLEAR.md §4.4) — so `weights-missing` (interaction .int / .snt
# absent) is a distinct honest-skip class from `install-gated`.
#
# D72 analog: nuclear-domain consumer — single-file thin adapter.
#             NO hexa-native kernel promotion (Lanczos diagonalization of
#             a many-body Hamiltonian in a huge basis is the anti-pattern
#             port target — wrap-as-is forever per NUCLEAR.md §6.2).
# D80 analog: install-gated when no backend found; nuclear-novel-
#             discovery-simulation when a backend ran (presence-only this
#             land — Lanczos run-out is the Phase 5+ follow-on).
# R4 invariant: absorbed = false ALWAYS — level / B(E2) / B(M1) output
#               is a *model prediction* (effective-interaction diagonal-
#               ization), NOT a *measurement*. Promotion to absorbed=true
#               requires GSI/JINR/RIKEN beam-time + gamma-spectroscopy /
#               lifetime measurement + IUPAC-class confirmation. OUT OF
#               SCOPE (NUCLEAR.md §7).
# Gate value: `nuclear-novel-discovery-simulation` (mirror of N6) or
#             `install-gated` (no backend) / weights-missing surfaced in
#             the record's skipped_reason.

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import time
from pathlib import Path


# --- backend detection (PATH probe + env var + common install layouts) --


def _which(name: str) -> str | None:
    """shutil.which wrapper — returns absolute path or None."""
    p = shutil.which(name)
    return p if p else None


def _probe_kshell() -> tuple[bool, str | None, str | None]:
    """KSHELL (Shimizu) — thick-restart Lanczos M-scheme shell model.

    $KSHELL_BIN env var (explicit path) takes precedence; PATH fallback
    follows (`kshell_mpi` / `kshell` / `transit` executables). Presence
    detection only — we do NOT launch a Lanczos diagonalization here
    (needs a model-space + effective-interaction .snt file + minutes-to-
    hours of CPU/MPI; that is the Phase 5+ follow-on, mirror of the N6
    HFBTHO SCF-not-invoked first-land discipline).
    """
    env = os.environ.get("KSHELL_BIN", "").strip()
    if env:
        p = Path(env).expanduser()
        if p.exists():
            return True, str(p), f"KSHELL_BIN={env}"
    for name in ("kshell_mpi", "kshell", "transit"):
        p = _which(name)
        if p:
            return True, p, f"PATH:{name}"
    return False, None, None


def _probe_nushellx() -> tuple[bool, str | None, str | None]:
    """NuShellX@MSU (Brown) — J-scheme proton-neutron shell model.
    $NUSHELLX_BIN env or PATH probe (`shell` / `nushellx` driver)."""
    env = os.environ.get("NUSHELLX_BIN", "").strip()
    if env:
        p = Path(env).expanduser()
        if p.exists():
            return True, str(p), f"NUSHELLX_BIN={env}"
    for name in ("nushellx", "shell"):
        p = _which(name)
        if p:
            return True, p, f"PATH:{name}"
    return False, None, None


def _probe_bigstick() -> tuple[bool, str | None, str | None]:
    """BIGSTICK (Johnson) — OpenMP/MPI parallel shell model. $BIGSTICK_BIN
    env or PATH probe (`bigstick.x` / `bigstick`)."""
    env = os.environ.get("BIGSTICK_BIN", "").strip()
    if env:
        p = Path(env).expanduser()
        if p.exists():
            return True, str(p), f"BIGSTICK_BIN={env}"
    for name in ("bigstick.x", "bigstick"):
        p = _which(name)
        if p:
            return True, p, f"PATH:{name}"
    return False, None, None


def _probe_antoine() -> tuple[bool, str | None, str | None]:
    """ANTOINE (Caurier, legacy) — original Lanczos shell-model code.
    $ANTOINE_BIN env or PATH probe."""
    env = os.environ.get("ANTOINE_BIN", "").strip()
    if env:
        p = Path(env).expanduser()
        if p.exists():
            return True, str(p), f"ANTOINE_BIN={env}"
    for name in ("antoine",):
        p = _which(name)
        if p:
            return True, p, f"PATH:{name}"
    return False, None, None


# Fallback chain order — KSHELL first (modern, actively maintained,
# Lanczos M-scheme), NuShellX second (widely-used J-scheme), BIGSTICK
# third (parallel scaling for large basis), ANTOINE fourth (legacy).
_BACKENDS = (
    ("kshell", _probe_kshell),
    ("nushellx", _probe_nushellx),
    ("bigstick", _probe_bigstick),
    ("antoine", _probe_antoine),
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


def _probe_interaction(valence_space: str, interaction: str) -> dict:
    """Probe for the effective-interaction file (`.snt` / `.int`) under
    $SHELL_MODEL_INT_DIR. Returns a dict for the record's
    `interaction_probe` field — when a backend is present but the
    interaction file is absent, this surfaces `weights-missing` honestly
    (mirror of N6 BSk `weights-missing` skip class)."""
    env = os.environ.get("SHELL_MODEL_INT_DIR", "").strip()
    candidates = []
    if env:
        d = Path(env).expanduser()
        for ext in (".snt", ".int"):
            candidates.append(d / f"{interaction}{ext}")
            candidates.append(d / f"{interaction.lower()}{ext}")
    for c in candidates:
        if c.exists():
            return {
                "present": True,
                "path": str(c),
                "note": f"SHELL_MODEL_INT_DIR -> {c.name}",
            }
    return {
        "present": False,
        "path": None,
        "note": (
            f"interaction '{interaction}' for valence space "
            f"'{valence_space}' not found under $SHELL_MODEL_INT_DIR "
            f"(weights-missing class)"
        ),
    }


# Install hints surfaced in the skip record when no backend is found.
_INSTALL_HINTS = {
    "kshell": (
        "KSHELL — Shimizu thick-restart Lanczos M-scheme shell model. "
        "Source: sites.google.com/alumni.tsukuba.ac.jp/kshell-nuclear "
        "— build (gfortran + MPI + OpenMP) + set $KSHELL_BIN. "
        "Interaction files (.snt) under $SHELL_MODEL_INT_DIR."
    ),
    "nushellx": (
        "NuShellX@MSU — B.A. Brown J-scheme proton-neutron shell "
        "model. Source: people.frib.msu.edu/~brown/resources/"
        "resources.html — install + set $NUSHELLX_BIN. Interaction "
        "files (.int) under $SHELL_MODEL_INT_DIR."
    ),
    "bigstick": (
        "BIGSTICK — Johnson OpenMP/MPI parallel shell model. Source: "
        "github.com/cwjsdsu/BigstickPublick — build + set "
        "$BIGSTICK_BIN. Scales to large model spaces."
    ),
    "antoine": (
        "ANTOINE — Caurier original Lanczos shell-model code "
        "(legacy). Source: iphc.cnrs.fr/nutheo/code_antoine/ — build "
        "+ set $ANTOINE_BIN."
    ),
}


# --- per-backend run stub (B path · wrap-as-is presence-only) -----------
#
# Mirror of N6 `_run_backend_stub`: when a backend is present we
# acknowledge the binary and emit an empty spectroscopy prediction with
# a `backend_present_but_not_run` note. ACTUAL Lanczos run-out (model-
# space build + effective-interaction load + diagonalization + E2/M1
# transition-density evaluation + output parse) is the NUCLEAR.md §6.2
# Phase 5+ follow-on. R4 invariant holds either way.


def _run_backend_stub(
    backend: str,
    bin_path: str | None,
    Z: int,
    N: int,
    valence_space: str,
    interaction: str,
    interaction_present: bool,
) -> tuple[dict, str]:
    """Acknowledge the backend without launching a Lanczos
    diagonalization. Returns (prediction_dict, run_note)."""
    A = Z + N
    weights_note = (
        "interaction file present"
        if interaction_present
        else "interaction file MISSING (weights-missing) — even with "
        "the binary present, a Lanczos run cannot proceed without the "
        "effective interaction"
    )
    note = (
        f"backend={backend} detected at {bin_path!r}; first-land "
        f"adapter is wrap-as-is presence-only — Lanczos "
        f"diagonalization NOT invoked. query=(Z={Z}, N={N}, A={A}) "
        f"valence_space={valence_space!r} interaction={interaction!r} "
        f"({weights_note}). Follow-on cohort: build model space + load "
        f"interaction + diagonalize + evaluate B(E2)/B(M1) + parse."
    )
    prediction = {
        "level_energies_MeV": None,
        "B_E2_e2fm4": None,
        "B_M1_muN2": None,
        "uncertainty_2sigma_cross_interaction": None,
        "backend_present_but_not_run": True,
        "interaction_present": interaction_present,
    }
    return prediction, note


# --- record emit --------------------------------------------------------


def main(
    out_dir: str,
    Z: int,
    N: int,
    valence_space: str,
    interaction: str,
) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    A = Z + N

    citations = [
        "KSHELL — Shimizu et al., 'Thick-restart block Lanczos method "
        "for large-scale shell-model calculations' (Comput Phys "
        "Commun 244:372, 2019). Source: sites.google.com/alumni."
        "tsukuba.ac.jp/kshell-nuclear .",
        "NuShellX@MSU — B.A. Brown / W.D.M. Rae, 'The Shell-Model "
        "Code NuShellX@MSU' (Nucl Data Sheets 120:115, 2014). "
        "Source: people.frib.msu.edu/~brown/ .",
        "BIGSTICK — C.W. Johnson et al., 'BIGSTICK: A flexible "
        "configuration-interaction shell-model code' "
        "(arxiv:1801.08432). Source: github.com/cwjsdsu/"
        "BigstickPublick .",
        "ANTOINE — E. Caurier / F. Nowacki, 'Present status of shell "
        "model techniques' (Acta Phys Pol B 30:705, 1999). Source: "
        "iphc.cnrs.fr/nutheo/code_antoine/ .",
        "Effective interactions: USDA/USDB (Brown-Richter sd-shell), "
        "KB3G / GXPF1 (pf-shell) — published parameter tables; "
        "cross-interaction spread is the honest 2-sigma band source.",
        "IAEA NSDC live evaluated nuclear data — https://nds.iaea.org/"
        "relnsd/ (level / B(E2) / B(M1) cross-validation corpus).",
        "NUCLEAR.md §2 (b) gate + §4.4 (N9 cohort spec) + §5.4 "
        "(external lib survey) + §6.3 (Phase 5 N9 land target) + §7 "
        "(R4 invariant block — wet-lab dependency permanent).",
    ]

    scope_caveats = [
        "(s1) Shell-model level energies / B(E2) / B(M1) are MODEL "
        "outputs from effective-interaction diagonalization, NOT "
        "measurements. The result depends on the chosen valence space "
        "(sd / pf / sdpfm) and the effective interaction (USDA vs "
        "USDB vs KB3G vs GXPF1). 'predicted 2+ level' != 'observed "
        "level'. R4 invariant blocks any absorbed=true promotion for "
        "nuclear-novel-discovery-simulation records (NUCLEAR.md §7).",
        "(s2) 5-gate evaluation (NUCLEAR.md §2): this record fills "
        "ONLY the (b) gate (spectroscopy). The other 4 gates ((a) "
        "mass, (c) decay, (d) production sigma, (e) detection) are "
        "NOT addressed. Even with all 5 sim gates PASS, (d) and (e) "
        "remain wet-lab dependent permanently — gamma-spectroscopy / "
        "level-lifetime measurement requires the synthesized nucleus "
        "+ a detector array, never substituted by sim.",
        "(s3) Backend / valence-space limits: shell-model "
        "tractability is bounded by the M-scheme / J-scheme basis "
        "dimension, which explodes combinatorially with valence "
        "nucleons. KSHELL / NuShellX / BIGSTICK / ANTOINE handle "
        "different basis-size regimes (BIGSTICK scales furthest via "
        "MPI). Cases outside the valence-space-tractable window "
        "(NUCLEAR.md §2 (b)) are honestly out of scope for the "
        "shell-model approach — ab-initio (N10) or HFB (N6) applies "
        "there instead.",
        "(s4) Interaction-file dependency (weights-missing class): "
        "even with a binary present, a Lanczos run cannot proceed "
        "without the effective-interaction file (.snt / .int) under "
        "$SHELL_MODEL_INT_DIR. The _setup/ footprint of a full "
        "shell-model install is typically 1-10 GB (NUCLEAR.md §4.4). "
        "This adapter surfaces `weights-missing` in interaction_probe "
        "rather than fabricating a level scheme (NUCLEAR.md §3.3 "
        "'Don't invent').",
        "(s5) First-land wrap-as-is: when a backend is detected on "
        "this host, this adapter records the presence but does NOT "
        "launch a Lanczos diagonalization (model-space build + "
        "interaction load + diagonalize + E2/M1 transition densities "
        "+ output parse). Follow-on cohort: real backend invocation "
        "+ parse -> populated level_energies / B(E2) / B(M1) + "
        "cross-interaction 2-sigma band. Mirror of NUCLEAR.md §6.2 "
        "Phase 5+ schedule. Wet-lab dependency unchanged (§3.2)."
    ]

    chosen, bin_path, detection_note, probe_map = _detect_backend()
    interaction_probe = _probe_interaction(valence_space, interaction)

    record: dict = {
        "domain": "nuclear",
        "verb": "verify",
        "kind": "shell_model_spectroscopy_prediction",
        "stamp": stamp,
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,  # R4 invariant — ALWAYS false (NUCLEAR §7)
        "provisional": True,
        "query": {
            "Z": Z,
            "N": N,
            "A": A,
            "valence_space": valence_space,
            "interaction": interaction,
        },
        "backend_probe": probe_map,
        "interaction_probe": interaction_probe,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "provenance": {
            "source_citation": (
                "NUCLEAR.md §2 (b) + §4.4 + §5.4 + §6.3 + §7 (this "
                "paper)"
            ),
            "primary_refs": [
                "KSHELL — Shimizu CPC 244:372 (2019).",
                "NuShellX@MSU — Brown/Rae NDS 120:115 (2014).",
                "BIGSTICK — Johnson arxiv:1801.08432.",
                "USDA/USDB · KB3G/GXPF1 effective interactions.",
            ],
            "fallback_chain": [
                "kshell", "nushellx", "bigstick", "antoine"
            ],
        },
        "nuclear_anchor": (
            "NUCLEAR.md §2 (b) gate + §4.4 (N9 cohort spec) + §6.3 "
            "(Phase 5 land target) + §7 (R4 invariant block)"
        ),
    }

    if chosen is None:
        # Honest skip — no shell-model backend installed at all.
        install_hint_lines = [
            f"  · {name}: {_INSTALL_HINTS[name]}"
            for name, _ in _BACKENDS
        ]
        skipped_reason = (
            "No shell-model backend found on host. Probed (in "
            "fallback order) kshell -> nushellx -> bigstick -> "
            "antoine; all absent. Install one of:\n"
            + "\n".join(install_hint_lines)
        )
        record["producer"] = "n9_shell_model_adapter.py@all-skipped"
        record["backend"] = "all-skipped"
        record["gate_type"] = "install-gated"
        record["skipped_reason"] = skipped_reason
        record["prediction"] = None
        headline = (
            "skip: no shell-model backend present (install-gated · "
            "honest-skip = PASS per §3.3)"
        )
    else:
        # Backend present — first-land wrap-as-is acknowledges presence
        # without launching a Lanczos diagonalization. R4 still holds.
        prediction, run_note = _run_backend_stub(
            chosen, bin_path, Z, N, valence_space, interaction,
            interaction_probe["present"],
        )
        record["producer"] = f"n9_shell_model_adapter.py@{chosen}"
        record["backend"] = chosen
        record["backend_bin"] = bin_path
        record["backend_detection_note"] = detection_note
        record["gate_type"] = "nuclear-novel-discovery-simulation"
        record["skipped_reason"] = (
            None
            if interaction_probe["present"]
            else (
                "Backend present but interaction file MISSING "
                "(weights-missing) — see interaction_probe. Lanczos "
                "run cannot proceed; honest skip per §3.3 'Don't "
                "invent'."
            )
        )
        record["prediction"] = prediction
        record["run_note"] = run_note
        wm = "" if interaction_probe["present"] else " · weights-missing"
        headline = (
            f"ok: {chosen} present at {bin_path} — presence-only "
            f"(wrap-as-is first land; spectroscopy=stub{wm})"
        )

    rec_path = (
        out / f"nuclear_verify_n9_shellmodel_{Z}_{N}_{stamp}.json"
    )
    rec_path.write_text(json.dumps(record, indent=2))

    print(f"[nuclear+verify · n9_shellmodel] wrote {rec_path}")
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
        f"  query: Z={Z}  N={N}  A={A}  "
        f"valence={valence_space!r}  interaction={interaction!r}"
    )
    print(
        "[nuclear+verify · n9_shellmodel] absorbed=false (R4 "
        "invariant; shell-model diagonalization is a prediction, "
        "NEVER measurement — NUCLEAR.md §7 wet-lab dependency "
        "permanent)"
    )
    return 0


def _parse_argv(
    argv: list[str],
) -> tuple[str, int, int, str, str]:
    p = argparse.ArgumentParser(
        prog="n9_shell_model_adapter.py",
        description=(
            "Thin adapter for nuclear shell-model spectroscopy "
            "(levels, B(E2), B(M1)) prediction (NUCLEAR.md §4.4 N9 "
            "cohort · B path · wrap-as-is). Fallback chain: KSHELL "
            "-> NuShellX -> BIGSTICK -> ANTOINE. R4 invariant: "
            "absorbed=false always."
        ),
    )
    p.add_argument("Z", type=int, help="Proton number (atomic number).")
    p.add_argument("N", type=int, help="Neutron number.")
    p.add_argument(
        "valence_space",
        help="Valence model space (e.g., sd, pf, sdpfm).",
    )
    p.add_argument(
        "interaction",
        help="Effective interaction (e.g., USDB, KB3G, GXPF1).",
    )
    p.add_argument("out_dir", help="Output directory for JSON record.")
    ns = p.parse_args(argv)
    if ns.Z < 1:
        p.error(f"Z must be >= 1, got Z={ns.Z}")
    if ns.N < 0:
        p.error(f"N must be >= 0, got N={ns.N}")
    return ns.out_dir, ns.Z, ns.N, ns.valence_space, ns.interaction


if __name__ == "__main__":
    out_dir, Z, N, valence_space, interaction = _parse_argv(sys.argv[1:])
    sys.exit(main(out_dir, Z, N, valence_space, interaction))
