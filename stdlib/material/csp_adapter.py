#!/usr/bin/env python3
# csp_adapter.py — `material + verify` crystal structure prediction thin adapter (D72 · B path · wrap-as-is).
#
# RTSC.md §9.1 (CSP libraries) + §9.7 N1 row + §9.9.1 Phase 1 (wrap-as-is).
# Sibling adapter pattern — see `sim_adapter.py` (Tier 1 closed-form Tc) and
# `mp_query.py` (MP REST API) in this same dir. csp_adapter.py is the third
# `material+verify`-shaped producer; B path = wrap external CSP code, NEVER
# port (anti-pattern per RTSC.md §9.9.1 — USPEX/AIRSS/CALYPSO/OpenCSP each
# represent 10K+ LOC + decades of empirical tuning).
#
# Backends (fallback chain — first present wins; all-missing → install-gated):
#   1. AIRSS  — Pickard & Needs (Ab Initio Random Structure Searching).
#               GPL2 open, Fortran + Bash. Smallest install footprint.
#               Citation: Pickard & Needs, J Phys: Condens Matter 23 (2011)
#               053201 ("Ab initio random structure searching").
#   2. USPEX  — Oganov & Glass (Universal Structure Predictor: Evolutionary
#               Xtallography). Academic free.
#               Citation: Oganov & Glass, J Chem Phys 124 (2006) 244704.
#   3. CALYPSO — Wang, Lv, Zhu, Ma (Crystal structure AnaLYsis by Particle
#               Swarm Optimization). Academic free.
#               Citation: Wang et al., Phys Rev B 82 (2010) 094116.
#   4. OpenCSP — 2025 deep-learning CSP framework (ambient → high pressure).
#               Citation: arxiv:2509.10293.
#
# D72: 3rd material-domain consumer (after sim_adapter, mp_query) — still a
#      single-file thin adapter. NO kernel promotion (no shared math with the
#      other two; CSP is a sampling/search problem, not a closed-form formula).
# D80: install-gated when no backend found; simulation-only-prediction when
#      a backend ran. NEVER hexa-native (B path = wrap-as-is).
# R4:  absorbed = false ALWAYS — CSP output is a *model prediction*, NOT a
#      *measurement*. "Stable predict ≠ synthesis succeeded ≠ material exists."
#      RTSC.md §8.9 5-gate evaluation: this record fills only the (a) candidate
#      list aspect, NOT the full 5-gate stack.

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


def _probe_airss() -> tuple[bool, str | None, str | None]:
    """Return (present, primary_bin, detection_note).

    AIRSS canonical layout: `airss.pl` driver + `buildcell` random-structure
    generator + an external DFT engine (CASTEP / VASP / QE) under $AIRSS_PP.
    For *presence detection only*, we accept either `airss.pl` or `buildcell`
    on PATH, OR $AIRSS_DIR pointing at a checkout. We do NOT try to actually
    run a search here — that would require a CASTEP/VASP/QE license too.
    """
    env = os.environ.get("AIRSS_DIR", "").strip()
    if env and Path(env).expanduser().is_dir():
        cand = Path(env).expanduser() / "bin" / "airss.pl"
        if cand.exists():
            return True, str(cand), f"AIRSS_DIR={env}"
    for name in ("airss.pl", "buildcell"):
        p = _which(name)
        if p:
            return True, p, f"PATH:{name}"
    return False, None, None


def _probe_uspex() -> tuple[bool, str | None, str | None]:
    """USPEX canonical layout: `USPEX` driver script (matlab + python +
    external DFT). $USPEXPATH points at the install tree. Distributed via
    a Matlab-based runner historically; recent versions also Python."""
    env = os.environ.get("USPEXPATH", "").strip()
    if env and Path(env).expanduser().is_dir():
        cand = Path(env).expanduser() / "USPEX"
        if cand.exists():
            return True, str(cand), f"USPEXPATH={env}"
    for name in ("USPEX", "uspex", "uspex.py"):
        p = _which(name)
        if p:
            return True, p, f"PATH:{name}"
    return False, None, None


def _probe_calypso() -> tuple[bool, str | None, str | None]:
    """CALYPSO canonical layout: `calypso.x` PSO driver + `input.dat` config
    + external DFT (VASP). $CALYPSO_PATH points at install tree."""
    env = os.environ.get("CALYPSO_PATH", "").strip()
    if env and Path(env).expanduser().is_dir():
        cand = Path(env).expanduser() / "calypso.x"
        if cand.exists():
            return True, str(cand), f"CALYPSO_PATH={env}"
    for name in ("calypso.x", "calypso"):
        p = _which(name)
        if p:
            return True, p, f"PATH:{name}"
    return False, None, None


def _probe_opencsp() -> tuple[bool, str | None, str | None]:
    """OpenCSP (arxiv:2509.10293) — 2025 deep-learning CSP framework. Python
    package; expects to be importable. We probe via `import opencsp`."""
    try:
        import opencsp  # noqa: F401
        try:
            from opencsp import __file__ as _of  # type: ignore[attr-defined]
            return True, str(_of), "python:import opencsp"
        except Exception:
            return True, None, "python:import opencsp"
    except ImportError:
        return False, None, None
    except Exception as e:  # pragma: no cover — unexpected import error
        return False, None, f"opencsp import error: {e}"


# Fallback chain order — AIRSS first per task spec (GPL2 + smallest install).
_BACKENDS = (
    ("airss", _probe_airss),
    ("uspex", _probe_uspex),
    ("calypso", _probe_calypso),
    ("opencsp", _probe_opencsp),
)


def _detect_backend() -> tuple[str | None, str | None, str | None, dict]:
    """Walk the fallback chain. Return (name, bin_path, detection_note,
    full_probe_map). full_probe_map captures the per-backend present/absent
    state for the record's `backend_probe` field — honest visibility into
    *why* each fallback didn't fire."""
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
    "airss": (
        "AIRSS — Pickard & Needs (GPL2). Source: "
        "https://www.mtg.msm.cam.ac.uk/Codes/AIRSS — clone + `make install`. "
        "Set $AIRSS_DIR or put `airss.pl`/`buildcell` on PATH. (No Homebrew "
        "formula known as of 2026-05.)"
    ),
    "uspex": (
        "USPEX — Oganov & Glass (academic free). Register + download at "
        "https://uspex-team.org/en/uspex/downloads — set $USPEXPATH and put "
        "the `USPEX` driver on PATH. Requires Matlab runtime for legacy "
        "versions, Python for recent releases."
    ),
    "calypso": (
        "CALYPSO — Wang et al. (academic free). Register + download at "
        "http://www.calypso.cn — set $CALYPSO_PATH and put `calypso.x` on "
        "PATH. Requires external DFT (typically VASP)."
    ),
    "opencsp": (
        "OpenCSP — arxiv:2509.10293 (2025 DL framework). pip-installable "
        "(when upstream publishes the package). Source: see arxiv:2509.10293 "
        "supplementary. Importable as `opencsp`."
    ),
}


# ─── per-backend run stubs (B path · wrap-as-is) ────────────────────────
#
# These are intentionally minimal: when a backend is present we acknowledge
# the binary and emit an empty candidates list with a `backend_present_but_
# not_run` note. ACTUAL run-out (which requires a paired DFT engine + hours
# of compute + a fragile parser per backend) is NOT in scope for the first
# land — that's the §9.9.1 Phase 2/3 follow-on. R4 invariant holds either
# way (absorbed=false always).


def _run_backend_stub(
    backend: str,
    bin_path: str | None,
    composition: str,
    max_atoms: int,
    pressure_gpa: float,
) -> tuple[list[dict], str]:
    """Acknowledge the backend without actually invoking a multi-hour
    search. Returns (candidates_list, run_note). For the wrap-as-is first
    land we emit candidates=[] + a clear note that the binary was found
    but no search was launched. Future cohort: spawn the backend, parse
    its output (CIF / POSCAR / res files), populate candidates_predicted.
    """
    note = (
        f"backend={backend} detected at {bin_path!r}; first-land adapter "
        f"is wrap-as-is presence-only — search not invoked. "
        f"query={composition!r} max_atoms={max_atoms} pressure_gpa={pressure_gpa}. "
        f"Follow-on cohort: actually spawn {backend} + parse output."
    )
    return [], note


# ─── record emit ────────────────────────────────────────────────────────


def main(out_dir: str, composition: str, max_atoms: int,
         pressure_gpa: float) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    citations = [
        "Pickard & Needs 2011, J Phys: Condens Matter 23 053201 — 'Ab "
        "initio random structure searching' (AIRSS primary citation).",
        "Oganov & Glass 2006, J Chem Phys 124 244704 — 'Crystal structure "
        "prediction using ab initio evolutionary techniques' (USPEX).",
        "Wang, Lv, Zhu, Ma 2010, Phys Rev B 82 094116 — 'CALYPSO: A method "
        "for crystal structure prediction'.",
        "arxiv:2509.10293 (2025) — 'OpenCSP: Deep Learning Framework for "
        "Crystal Structure Prediction from Ambient to High Pressure'.",
        "RTSC.md §9.1 (CSP libraries table) + §9.7 N1 row + §9.9.1 Phase 1 "
        "(wrap-as-is launch principle) — this paper.",
    ]

    scope_caveats = [
        "(s1) Crystal structure prediction is a model output, NOT a "
        "measurement. Stable predict ≠ synthesis succeeded ≠ material "
        "exists. R4 invariant blocks any absorbed=true promotion for "
        "csp_simulation_prediction records.",
        "(s2) 5-gate evaluation (RTSC.md §8.9): this record fills only the "
        "(a) candidate-list aspect — proposed compositions / spacegroups. "
        "The other 4 gates (Tc prediction, dynamic stability under target "
        "conditions, cross-code parity, oracle parity) are NOT addressed "
        "by this adapter. R4 invariant blocks absorbed=true claim.",
        "(s3) AIRSS / USPEX / CALYPSO / OpenCSP each use different sampling "
        "strategies (random + symmetry constraints / evolutionary GA / "
        "particle swarm / deep-learning generative). Results across "
        "backends are NOT directly comparable — cohort fingerprints differ "
        "and convergence-to-ground-state guarantees differ.",
        "(s4) First-land wrap-as-is: when a backend is detected on this "
        "host, this adapter records the presence but does NOT spawn a "
        "search (which would require a paired DFT engine + hours of "
        "compute). Follow-on cohort: real backend invocation + output "
        "parse → populated candidates_predicted list.",
    ]

    chosen, bin_path, detection_note, probe_map = _detect_backend()

    record: dict = {
        "domain": "material",
        "verb": "verify",
        "kind": "csp_simulation_prediction",
        "stamp": stamp,
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,  # R4 invariant — ALWAYS false for CSP
        "provisional": True,
        "query": {
            "composition": composition,
            "max_atoms": max_atoms,
            "pressure_gpa": pressure_gpa,
        },
        "backend_probe": probe_map,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "provenance": {
            "source_citation": "RTSC.md §9.1 + §9.7 + §9.9.1 (this paper)",
            "primary_refs": [
                "J Phys Condens Matter 23 053201 (Pickard 2011) — AIRSS.",
                "J Chem Phys 124 244704 (Oganov 2006) — USPEX.",
                "Phys Rev B 82 094116 (Wang 2010) — CALYPSO.",
                "arxiv:2509.10293 (2025) — OpenCSP.",
            ],
            "fallback_chain": ["airss", "uspex", "calypso", "opencsp"],
        },
        "rtsc_anchor": (
            "RTSC.md §9.1 (CSP library table) + §9.7 N1 row "
            "(csp_adapter cohort) + §9.9.1 Phase 1 (wrap-as-is)"
        ),
    }

    if chosen is None:
        # Honest skip — no backend installed at all.
        install_hint_lines = [
            f"  · {name}: {_INSTALL_HINTS[name]}"
            for name, _ in _BACKENDS
        ]
        skipped_reason = (
            "No CSP backend found on host. Probed (in fallback order) "
            "airss → uspex → calypso → opencsp; all absent. Install one of:\n"
            + "\n".join(install_hint_lines)
        )
        record["producer"] = "csp_adapter.py@all-skipped"
        record["backend"] = "all-skipped"
        record["gate_type"] = "install-gated"
        record["skipped_reason"] = skipped_reason
        record["candidates_predicted"] = []
        headline = "skip: no CSP backend present (install-gated)"
    else:
        # Backend present — first-land wrap-as-is acknowledges presence
        # without spawning a multi-hour search. R4 still holds.
        candidates, run_note = _run_backend_stub(
            chosen, bin_path, composition, max_atoms, pressure_gpa
        )
        record["producer"] = f"csp_adapter.py@{chosen}"
        record["backend"] = chosen
        record["backend_bin"] = bin_path
        record["backend_detection_note"] = detection_note
        record["gate_type"] = "simulation-only-prediction"
        record["skipped_reason"] = None
        record["candidates_predicted"] = candidates
        record["run_note"] = run_note
        headline = (
            f"ok: {chosen} present at {bin_path} — presence-only "
            f"(wrap-as-is first land; candidates=[])"
        )

    rec_path = out / f"material_verify_csp_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))

    print(f"[material+verify · csp] wrote {rec_path}")
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
    print(
        f"  query: composition={composition!r}  "
        f"max_atoms={max_atoms}  pressure_gpa={pressure_gpa}"
    )
    print(
        "[material+verify · csp] absorbed=false (R4 invariant; CSP is "
        "prediction, NEVER measurement — RTSC.md §8.9 5-gate · §9.1 "
        "honest scope)"
    )
    return 0


def _parse_argv(argv: list[str]) -> tuple[str, str, int, float]:
    p = argparse.ArgumentParser(
        prog="csp_adapter.py",
        description=(
            "Thin adapter for crystal structure prediction (B path · "
            "wrap-as-is). Fallback chain: AIRSS → USPEX → CALYPSO → "
            "OpenCSP. R4 invariant: absorbed=false always."
        ),
    )
    p.add_argument("out_dir", help="Output directory for JSON record.")
    p.add_argument(
        "composition",
        help="Composition string, e.g. 'Pb10Cu1(PO4)6O', 'Nb1', 'MgB2'.",
    )
    p.add_argument(
        "--max-atoms",
        type=int,
        default=24,
        help="Maximum atoms per primitive cell to search (default: 24).",
    )
    p.add_argument(
        "--pressure-gpa",
        type=float,
        default=0.0,
        help="Target pressure in GPa for the search (default: 0.0 = ambient).",
    )
    ns = p.parse_args(argv)
    return ns.out_dir, ns.composition, ns.max_atoms, ns.pressure_gpa


if __name__ == "__main__":
    out_dir, composition, max_atoms, pressure_gpa = _parse_argv(sys.argv[1:])
    sys.exit(main(out_dir, composition, max_atoms, pressure_gpa))
