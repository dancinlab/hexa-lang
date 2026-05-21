#!/usr/bin/env python3
# h_formulation_adapter.py — `rtsc + verify` producer (HTS-grade FIRST STEP).
#
# Stand-alone H-formulation adapter for HTS critical-state verification.
# Distinct from `getdp_hts.py` (intentionally minimal record-only landing
# per user revert) — this adapter actually attempts a GetDP 4.0.0 H-/h-φ
# formulation solve when a license-clear .pro is locally cached.
#
# References (canonical, from D1 cohort INDEX.md + RTSC.md §4.2 Axis E):
#   - arxiv:1908.02176 — Shen, Grilli, Coombs (2020). *Review of the AC
#     Loss Computation for HTS using the H-formulation.* SuST 33 033002.
#   - arxiv:0811.2883 — Pecher, Sirois (2008). *3-D FEM HTS magnetization,
#     single-time-step iteration* (the GetDP HTS algorithm paper).
#   - HTS Modelling Workgroup — https://htsmodelling.com/
#   - GetDP — https://get-dp.org/ (Geuzaine, U. Liège, Gmsh-pair).
#
# RTSC.md §4.2 Axis E: H-formulation is the HTS-grade rung; the existing
# `solenoid_axisym.pro` (linear A-φ magnetostatic) is one rung below
# (Axis E s1 caveat = "Linear magnetostatic — HTS critical-state not
# modelled"). This adapter is the FIRST STEP toward closing that gap.
#
# g3 (honest):
#   - This adapter NEVER claims `absorbed=true`. It lands the GATE_OPEN
#     measurement record; absorption requires a full benchmark-validated
#     run plus measured REBCO tape Jc(B,T,θ) which is out of scope here.
#   - Default path is honest skip (no GetDP / no .pro / license-unclear).
#   - License-unclear is a first-class skip mode per D1's INDEX.md.

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

# Anchors.
_THIS = Path(__file__).resolve()
_RTSC_DIR = _THIS.parent
_HTS_WG = _RTSC_DIR / "templates" / "hts_workgroup"
_BENCH1_README = _HTS_WG / "benchmark1_tape" / "README.md"
_LIFE_README = _HTS_WG / "life_hts_pancakes_ref" / "README.md"
_LIFE_FETCH = _HTS_WG / "life_hts_pancakes_ref" / "fetch.sh"
_LIFE_EXTERNAL = _HTS_WG / "life_hts_pancakes_ref" / "_external" / "life-hts"
_LOCAL_GETDP_CACHE = Path.home() / "local" / "hts_workgroup_cache"

# Canonical Tier-3 axes (D1 cohort INDEX.md alignment).
_AXES = {
    "formulation": "h_formulation_e_j_power_law",
    "conductor": "rebco_hts",
    # solver / dim filled in at emit time.
}

_CITATIONS = [
    "arxiv:1908.02176 — Shen, Grilli, Coombs (2020). Review of the AC Loss "
    "Computation for HTS using the H-formulation. SuST 33 033002.",
    "arxiv:0811.2883 — Pecher, Sirois (2008). Numerical simulation of the "
    "magnetization of high-temperature superconductors: 3D FEM single "
    "time-step iteration. (GetDP HTS algorithm paper.)",
    "HTS Modelling Workgroup shared model files — https://htsmodelling.com/",
    "GetDP — https://get-dp.org/ (Geuzaine, U. Liège, Gmsh-pair).",
    "Dular, J., Geuzaine, C., Vanderheyden, B. (2019/2020). Finite Element "
    "Formulations for Systems with High-Temperature Superconductors. "
    "IEEE TASC. DOI 10.1109/TASC.2019.2935429",
]

# Honest scope caveats — s1..s4 inherit from solenoid_axisym / getdp_hts;
# s5/s6 are new and specific to H-formulation step.
_BASE_CAVEATS = [
    "(s1) Linear magnetostatic baseline NOT closed — this adapter is the "
    "first step toward HTS-grade verify but does not yet replace the "
    "A-φ baseline; absorption still requires a full benchmark.",
    "(s2) 2-D Cartesian or 2-D axisym — leads / support / 3-D return path "
    "not modelled.",
    "(s3) μ_r=1 assumed in air regions — HTS magnetization (M ≠ 0) is "
    "handled in the power-law constitutive only; persistent current loop "
    "topology not verified end-to-end.",
    "(s4) Procedural geometry / external benchmark geometry — NOT a "
    "sourced coil design; absorbed=false, GATE_OPEN.",
    "(s5) H-formulation E-J power law — captures critical state + AC "
    "loss, but still 2-D Cartesian (not axisymmetric); not real coil "
    "layout.",
    "(s6) References HTS Modelling Workgroup benchmark; ≠ measured REBCO "
    "tape Jc(B,T,θ).",
]

_RE_ENABLE_HINT = (
    "To re-enable a live solve: (1) install GetDP 4.0.0 locally (e.g. "
    "~/local/getdp/getdp-4.0.0-MacOSARM/bin/getdp); (2) run the upstream "
    "fetch.sh under templates/hts_workgroup/life_hts_pancakes_ref/ to "
    "clone life-hts into _external/ (license is unclear — local-only "
    "inspection, do not redistribute); OR drop a license-clear .pro + .msh "
    "pair into ~/local/hts_workgroup_cache/ ; then re-run this adapter."
)


# ---------------------------------------------------------------------------
# GetDP detection
# ---------------------------------------------------------------------------

def _candidate_getdp_bins() -> list[Path]:
    """Ordered candidates: $GETDP_BIN, ~/local/getdp/*/bin/getdp, PATH."""
    cands: list[Path] = []
    env = os.environ.get("GETDP_BIN", "").strip()
    if env:
        cands.append(Path(env).expanduser())
    # Common local install layout.
    local_root = Path.home() / "local" / "getdp"
    if local_root.is_dir():
        for sub in sorted(local_root.iterdir()):
            cand = sub / "bin" / "getdp"
            if cand.exists():
                cands.append(cand)
    # PATH fallback.
    on_path = shutil.which("getdp")
    if on_path:
        cands.append(Path(on_path))
    # De-dupe (preserve order).
    seen: set[str] = set()
    out: list[Path] = []
    for c in cands:
        k = str(c)
        if k not in seen:
            seen.add(k)
            out.append(c)
    return out


_VERSION_RE = re.compile(r"(\d+)\.(\d+)\.(\d+)")


def _getdp_version(bin_path: Path) -> tuple[int, int, int] | None:
    """Return (maj, min, patch) or None on parse failure / exec failure."""
    try:
        proc = subprocess.run(
            [str(bin_path), "-version"],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    # GetDP prints "4.0.0" on stderr (or stdout depending on build).
    blob = (proc.stdout or "") + "\n" + (proc.stderr or "")
    m = _VERSION_RE.search(blob)
    if m is None:
        return None
    return (int(m.group(1)), int(m.group(2)), int(m.group(3)))


def _pick_getdp() -> tuple[Path | None, tuple[int, int, int] | None, str]:
    """Return (bin_or_None, version_or_None, reason).

    reason ∈ {"ok", "absent", "version_too_old"}.
    """
    cands = _candidate_getdp_bins()
    if not cands:
        return None, None, "absent"
    best_old: tuple[Path, tuple[int, int, int]] | None = None
    for c in cands:
        v = _getdp_version(c)
        if v is None:
            continue
        if v >= (4, 0, 0):
            return c, v, "ok"
        if best_old is None:
            best_old = (c, v)
    if best_old is not None:
        return best_old[0], best_old[1], "version_too_old"
    return None, None, "absent"


# ---------------------------------------------------------------------------
# .pro discovery
# ---------------------------------------------------------------------------

def _read_text_safe(p: Path) -> str:
    try:
        return p.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def _benchmark_license_status() -> str:
    """Return 'license_unclear' | 'clear' | 'unknown' from D1 READMEs."""
    txt = _read_text_safe(_BENCH1_README) + "\n" + _read_text_safe(_LIFE_README)
    if "[skipped: license unclear]" in txt or "license unclear" in txt.lower():
        return "license_unclear"
    if not txt:
        return "unknown"
    return "clear"


def _find_local_pro() -> tuple[Path | None, Path | None, str]:
    """Look for an H-formulation .pro + .msh pair.

    Search order:
      1. ~/local/hts_workgroup_cache/ — explicit license-clear drop site.
      2. templates/.../_external/life-hts/pancakesHPhi/pancakes_ref/
         (gitignored cache from fetch.sh; license still unclear → only
         used if explicitly opted-in via DEMIURGE_RTSC_USE_LICENSE_UNCLEAR=1).
      3. templates/.../_external/life-hts/tape/tape.pro
         (same gating — closest match to HTS Workgroup Benchmark #1).

    Returns (pro_path, msh_path_or_None, source_label).
    """
    # 1) license-clear local cache.
    if _LOCAL_GETDP_CACHE.is_dir():
        for pro in sorted(_LOCAL_GETDP_CACHE.rglob("*.pro")):
            msh = next(iter(sorted(pro.parent.glob("*.msh"))), None)
            return pro, msh, f"local_cache:{pro}"

    # 2/3) Opt-in license-unclear path (per D1's honest stance, default OFF).
    if os.environ.get("DEMIURGE_RTSC_USE_LICENSE_UNCLEAR", "") == "1":
        candidates = [
            _LIFE_EXTERNAL / "pancakesHPhi" / "pancakes_ref" / "pancakes_ref.pro",
            _LIFE_EXTERNAL / "tape" / "tape.pro",
        ]
        for pro in candidates:
            if pro.exists():
                msh = next(iter(sorted(pro.parent.glob("*.msh"))), None)
                return pro, msh, f"license_unclear_external:{pro}"

    return None, None, "no_pro_found"


# ---------------------------------------------------------------------------
# Solve attempt
# ---------------------------------------------------------------------------

def _attempt_solve(
    getdp_bin: Path,
    pro: Path,
    msh: Path | None,
    out: Path,
) -> tuple[bool, str, dict]:
    """Try to run GetDP. Returns (ok, message, extra_record_fields)."""
    cmd: list[str] = [str(getdp_bin), str(pro)]
    if msh is not None:
        cmd += ["-msh", str(msh)]
    cmd += ["-solve", "MagDyn", "-v", "3"]
    log_path = out / "getdp_solve.log"
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=180,
            cwd=str(pro.parent),
        )
    except subprocess.TimeoutExpired:
        log_path.write_text(
            "GetDP solve timed out after 180s — long-running benchmark; "
            "this adapter only attempts a smoke-grade run.\n"
        )
        return False, "getdp_solve_timeout_180s", {
            "solve_log": str(log_path),
        }
    except OSError as exc:
        return False, f"getdp_exec_failed: {exc!r}", {}

    blob = (proc.stdout or "") + "\n" + (proc.stderr or "")
    log_path.write_text(blob)
    if proc.returncode != 0:
        # Surface a compact head of the error for the record.
        first_err = ""
        for line in blob.splitlines():
            if "error" in line.lower():
                first_err = line.strip()
                break
        return False, (
            f"getdp_solve_returncode_{proc.returncode}"
            + (f":{first_err}" if first_err else "")
        ), {"solve_log": str(log_path)}

    return True, "getdp_solve_ok", {"solve_log": str(log_path)}


# ---------------------------------------------------------------------------
# Record emit
# ---------------------------------------------------------------------------

def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    getdp_bin, getdp_ver, getdp_reason = _pick_getdp()
    license_status = _benchmark_license_status()
    pro, msh, pro_source = _find_local_pro()

    record: dict = {
        "domain": "rtsc",
        "verb": "verify",
        "kind": "solenoid_h_formulation_e_j_power_law",
        "stamp": stamp,
        "axes": dict(_AXES),
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "provisional": True,
        "scope_caveats": list(_BASE_CAVEATS),
        "citations": list(_CITATIONS),
    }
    record["axes"]["dim"] = "2d_cartesian"

    headline: str

    # ---- Skip path 1: no GetDP at all.
    if getdp_bin is None or getdp_reason == "absent":
        record["axes"]["solver"] = "skipped"
        record["producer"] = "getdp@absent"
        record["gate_type"] = "install-gated"
        record["skipped_reason"] = (
            "getdp_4_0_0_required_for_h_formulation_rho_power_law"
        )
        record["re_enable_hint"] = _RE_ENABLE_HINT
        headline = "skip: GetDP binary not found"
        return _emit(out, stamp, record, headline)

    # ---- Skip path 2: GetDP present but too old (<4.0.0).
    if getdp_reason == "version_too_old":
        ver_s = ".".join(str(x) for x in (getdp_ver or (0, 0, 0)))
        record["axes"]["solver"] = "skipped"
        record["producer"] = f"getdp@{getdp_bin}({ver_s})"
        record["gate_type"] = "install-gated"
        record["skipped_reason"] = (
            "getdp_4_0_0_required_for_h_formulation_rho_power_law"
        )
        record["scope_caveats"].append(
            f"GetDP {ver_s} present at {getdp_bin} but H-formulation "
            "upstream (life-hts) requires RhoPowerLaw built-in introduced "
            "in GetDP 4.0.0."
        )
        record["re_enable_hint"] = _RE_ENABLE_HINT
        headline = f"skip: GetDP {ver_s} < 4.0.0 required"
        return _emit(out, stamp, record, headline)

    # GetDP ≥4.0.0 — record version for record.
    ver_s = ".".join(str(x) for x in (getdp_ver or (4, 0, 0)))
    record["producer"] = f"getdp@{getdp_bin}({ver_s})"

    # ---- Skip path 3: license-unclear AND no license-clear local .pro.
    if pro is None:
        record["axes"]["solver"] = "skipped"
        if license_status == "license_unclear":
            record["gate_type"] = "license-unclear"
            record["skipped_reason"] = "hts_workgroup_license_unclear"
            record["scope_caveats"].append(
                "HTS Modelling Workgroup benchmarks and life-hts upstream "
                "have unclear licenses (per templates/hts_workgroup/INDEX.md "
                "and per-benchmark README — no LICENSE file upstream as of "
                "2026-05-21). This adapter does NOT vendor third-party .pro "
                "files. Drop a license-clear .pro + .msh into "
                f"{_LOCAL_GETDP_CACHE} to enable a live solve."
            )
        else:
            record["gate_type"] = "install-gated"
            record["skipped_reason"] = "no_local_pro_file_found"
        record["re_enable_hint"] = _RE_ENABLE_HINT
        headline = f"skip: GetDP {ver_s} present but no usable .pro"
        return _emit(out, stamp, record, headline)

    # ---- Attempt a live solve.
    record["axes"]["solver"] = "getdp"
    record["pro_source"] = pro_source
    if msh is not None:
        record["msh_source"] = str(msh)
    ok, msg, extra = _attempt_solve(getdp_bin, pro, msh, out)
    record.update(extra)
    if not ok:
        record["axes"]["solver"] = "getdp_attempted"
        record["gate_type"] = "install-gated"
        record["skipped_reason"] = msg
        record["scope_caveats"].append(
            "GetDP 4.0.0 was present and a .pro was located, but the solve "
            "did not complete successfully. See solve_log for details."
        )
        headline = f"skip: solve failed ({msg})"
        return _emit(out, stamp, record, headline)

    # Live solve completed. We do NOT parse Jc / AC-loss / penetration here —
    # that's a full benchmark scope; this adapter only lands the gate.
    record["gate_type"] = "hexa-native-absent"
    record["scope_caveats"].append(
        "GetDP 4.0.0 H-formulation solve ran end-to-end (smoke-grade) — "
        "output parsing (Jc, AC loss per cycle, current penetration profile) "
        "is NOT yet implemented in this adapter. absorbed=false until "
        "benchmark-validated post-processing lands."
    )
    headline = "ok: GetDP 4.0.0 H-formulation smoke solve completed"
    return _emit(out, stamp, record, headline)


def _emit(out: Path, stamp: str, record: dict, headline: str) -> int:
    rec_path = out / f"rtsc_verify_h_formulation_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[rtsc+verify · h_formulation] wrote {rec_path}")
    print(f"  headline: {headline}")
    print(f"  gate_type={record.get('gate_type')!r} "
          f"skipped_reason={record.get('skipped_reason')!r} "
          f"absorbed={record.get('absorbed')}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/rtsc_verify_h"))
