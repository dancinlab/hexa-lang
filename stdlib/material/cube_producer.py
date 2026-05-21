#!/usr/bin/env python3
# cube_producer.py — `material + verify` Tier 1 sim producer.
#
# Stand-alone Python wrapper around the life-hts/cube H-formulation
# benchmark (HTS Modelling Workgroup reference). Spawns gmsh + GetDP
# 4.0.0 to drive a 3-D single-cube SC transient solve with the
# RhoPowerLaw E-J constitutive, and emits a Tier 1 sim record.
#
# ---------------------------------------------------------------------
# Transient-capture approach (RTSC.md §4.2.1.d, captures-all-time-steps):
# ---------------------------------------------------------------------
# `cube.pro`'s `MagDyn_energy` PostOp writes to `res/dummy.txt` with a
# truncate-then-append redirect (`File > "res/dummy.txt"`) so only the
# LAST step's values survive in that file. HOWEVER, `lib/resolution.pro`
# ALSO writes one row per converged time-step to a sibling APPEND file
# (`<outputDir>/power.txt`) via:
#     Print[{$Time, $indicAir, $indicFerro, $indicSuper, $indicDissSuper,
#            $indicDissLin, $Voltage, $Current}, ..., File outputPower];
# This is the {Time, PostOp values} stream we need; `power.txt` already
# captures it for every converged step.
#
# Of the three approaches considered:
#   (a) Parse the existing append-file `power.txt` after the solve.
#   (b) Race the wrapper to read `res/dummy.txt` between steps.
#   (c) Spawn a sibling watcher + per-step snapshot of `res/dummy.txt`.
#
# This producer picks **approach (a)** because life-hts already writes
# the per-step stream to `power.txt` (we don't have to fight the
# `dummy.txt` truncate race), and life-hts content stays untouched
# (license-unclear; READ-ONLY). No watcher subprocess, no race window.
# On a partial-cycle timeout, `power.txt` is flushed line-by-line by
# GetDP's Print[], so a SIGTERM at the budget leaves a valid prefix.
#
# Companion to `~/core/hexa-lang/stdlib/rtsc/h_formulation_adapter.py`:
# - h_formulation_adapter.py = rtsc-domain verify (HTS-grade FIRST STEP);
#   targets life-hts pancakesHPhi / tape benchmarks; lands the GATE_OPEN
#   record after a smoke-grade solve.
# - cube_producer.py (this file) = material-domain Tier 1 record from the
#   cube benchmark specifically — the lightest life-hts benchmark that
#   exercises the full GetDP MagDyn h-φ resolution. Captures time-step
#   count + DOFs + final KSP residual as headline numbers within a
#   bounded wall-budget (partial-cycle allowed; full-cycle is a separate
#   cohort).
#
# References (canonical, from RTSC.md §4.2.1.c + §8.7 Tier 1):
#   - arxiv:1908.02176 — Shen, Grilli, Coombs (2020). Review of the AC
#     Loss Computation for HTS using the H-formulation. SuST 33 033002.
#   - arxiv:0811.2883 — Pecher, Sirois (2008). 3-D FEM HTS magnetization,
#     single-time-step iteration. (GetDP HTS algorithm paper.)
#   - HTS Modelling Workgroup shared model files — https://htsmodelling.com/
#   - GetDP — https://get-dp.org/ (Geuzaine, U. Liège, Gmsh-pair).
#
# g3 (honest):
#   - absorbed = False always. Cube benchmark is a single-cube SC
#     reference — NOT measured REBCO tape Jc(B,T,θ), NOT a real coil
#     layout. provisional=True until benchmark-validated post-processing
#     lands and the upstream license clears.
#   - Default honest skips: GetDP missing → install-gated; life-hts cube
#     source missing → license-unclear. License-unclear path is opt-in via
#     `DEMIURGE_RTSC_USE_LICENSE_UNCLEAR=1` (same env as
#     h_formulation_adapter.py).
#   - Partial-cycle timeout is a first-class gate_type — capturing N
#     time-steps within a 480s wall budget is a legitimate Tier 1 record;
#     full-cycle convergence is a separate cohort.

from __future__ import annotations

import json
import math
import os
import re
import shutil
import statistics
import subprocess
import sys
import time
from pathlib import Path

# ──────────────────────────────────────────────────────────────────────────
# Anchors.
# ──────────────────────────────────────────────────────────────────────────
_THIS = Path(__file__).resolve()
_STDLIB = _THIS.parent.parent
_RTSC_DIR = _STDLIB / "rtsc"
_HTS_WG = _RTSC_DIR / "templates" / "hts_workgroup"
_LIFE_EXTERNAL = (
    _HTS_WG / "life_hts_pancakes_ref" / "_external" / "life-hts"
)
_LIFE_CUBE = _LIFE_EXTERNAL / "cube"
_LIFE_LIB = _LIFE_EXTERNAL / "lib"

# Wall budgets (seconds). Total task budget is 540s; we reserve 60s for
# mesh + parse + emit, and hand 480s to GetDP. Override the solve budget
# via $DEMIURGE_CUBE_SOLVE_TIMEOUT_S (clamped to [60, 7200]) — used by the
# 600s transient-capture verify cohort (RTSC.md §4.2.1.d).
def _solve_timeout_s() -> int:
    raw = os.environ.get("DEMIURGE_CUBE_SOLVE_TIMEOUT_S", "").strip()
    if not raw:
        return 480
    try:
        v = int(raw)
    except ValueError:
        return 480
    return max(60, min(7200, v))


_MESH_TIMEOUT_S = 60

# Canonical Tier 1 axes (material domain, RTSC.md §8.7 alignment).
_AXES = {
    "device": "cube",
    "conductor": "rebco_hts",
    "solver": "getdp",
    "formulation": "h_formulation_e_j_power_law",
    "dim": "3d_cartesian",
}

_CITATIONS = [
    "arxiv:1908.02176 — Shen, Grilli, Coombs (2020). Review of the AC "
    "Loss Computation for HTS using the H-formulation. SuST 33 033002.",
    "arxiv:0811.2883 — Pecher, Sirois (2008). Numerical simulation of "
    "the magnetization of high-temperature superconductors: 3D FEM "
    "single time-step iteration. (GetDP HTS algorithm paper.)",
    "HTS Modelling Workgroup shared model files — https://htsmodelling.com/",
    "GetDP — https://get-dp.org/ (Geuzaine, U. Liège, Gmsh-pair).",
    "Dular, J., Geuzaine, C., Vanderheyden, B. (2019/2020). Finite "
    "Element Formulations for Systems with High-Temperature "
    "Superconductors. IEEE TASC. DOI 10.1109/TASC.2019.2935429.",
]

# Honest scope caveats — s1..s4 inherit from getdp_hts.py /
# h_formulation_adapter.py; s5..s7 are new and cube-specific.
_BASE_CAVEATS = [
    "(s1) Linear magnetostatic baseline NOT closed — this producer is "
    "an HTS-grade verify step but does not yet replace the A-φ baseline; "
    "absorption requires a full benchmark with measured REBCO tape data.",
    "(s2) 3-D Cartesian single-cube — leads / support / coil winding "
    "topology not modelled.",
    "(s3) μ_r=1 assumed in air regions — HTS magnetization (M ≠ 0) is "
    "handled in the power-law constitutive only; persistent current loop "
    "topology not verified end-to-end.",
    "(s4) Procedural geometry from external benchmark — NOT a sourced "
    "coil design; absorbed=false, GATE_OPEN.",
    "(s5) H-formulation E-J power law per HTS Workgroup; 3-D cube SC, "
    "not real coil layout.",
    "(s6) life-hts cube.pro is single-cube SC reference; ≠ measured "
    "REBCO tape Jc(B,T,θ).",
    "(s7) Partial-cycle results carry timed_out=true and "
    "time_steps_completed < total expected; full-cycle is a separate "
    "cohort.",
]

_RE_ENABLE_HINT = (
    "To re-enable a live solve: (1) install GetDP 4.0.0 locally (e.g. "
    "~/local/getdp/getdp-4.0.0-MacOSARM/bin/getdp) or set $GETDP_BIN; "
    "(2) run the upstream fetch.sh under "
    "templates/hts_workgroup/life_hts_pancakes_ref/ to clone life-hts "
    "into _external/ (license is unclear — local-only inspection, do not "
    "redistribute); (3) opt in to the license-unclear path via env "
    "DEMIURGE_RTSC_USE_LICENSE_UNCLEAR=1; then re-run this producer."
)


# ──────────────────────────────────────────────────────────────────────────
# GetDP detection (mirrors h_formulation_adapter.py pattern).
# ──────────────────────────────────────────────────────────────────────────
_VERSION_RE = re.compile(r"(\d+)\.(\d+)\.(\d+)")


def _candidate_getdp_bins() -> list[Path]:
    """Ordered: $GETDP_BIN, ~/local/getdp/*/bin/getdp, PATH."""
    cands: list[Path] = []
    env = os.environ.get("GETDP_BIN", "").strip()
    if env:
        cands.append(Path(env).expanduser())
    local_root = Path.home() / "local" / "getdp"
    if local_root.is_dir():
        for sub in sorted(local_root.iterdir()):
            cand = sub / "bin" / "getdp"
            if cand.exists():
                cands.append(cand)
    # PATH fallback (last).
    on_path = shutil.which("getdp")
    if on_path:
        cands.append(Path(on_path))
    seen: set[str] = set()
    out: list[Path] = []
    for c in cands:
        k = str(c)
        if k not in seen:
            seen.add(k)
            out.append(c)
    return out


def _getdp_version(bin_path: Path) -> tuple[int, int, int] | None:
    try:
        proc = subprocess.run(
            [str(bin_path), "-version"],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    blob = (proc.stdout or "") + "\n" + (proc.stderr or "")
    m = _VERSION_RE.search(blob)
    if m is None:
        return None
    return (int(m.group(1)), int(m.group(2)), int(m.group(3)))


def _pick_getdp() -> tuple[Path | None, tuple[int, int, int] | None, str]:
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


def _which_gmsh() -> Path | None:
    p = shutil.which("gmsh")
    return Path(p) if p else None


# ──────────────────────────────────────────────────────────────────────────
# Work-dir staging.
# ──────────────────────────────────────────────────────────────────────────

def _stage_workdir(root: Path) -> tuple[Path, Path]:
    """Materialise cube/ + lib/ into matching layout for cube.pro.

    cube.pro does `Include "../lib/..."` so we need:
        <root>/cube_solve/    (cwd for getdp; cube.pro lives here)
        <root>/lib/           (sibling, found via ../lib/)

    We additionally create <root>/cube/res/cube_model/ since
    outputDirectory = ../cube/res/cube_model relative to cube_solve.

    Returns (solve_dir, res_dir).
    """
    solve_dir = root / "cube_solve"
    lib_dir = root / "lib"
    cube_res_dir = root / "cube" / "res" / "cube_model"

    # Wipe stale (per memory: stale temp files mask exec failures).
    if root.exists():
        shutil.rmtree(root)
    solve_dir.mkdir(parents=True)
    cube_res_dir.mkdir(parents=True)
    # resolution.pro emits a few `File "res/dummy.txt"` lines relative to
    # GetDP's cwd (= solve_dir), separate from outputDirectory's
    # ../cube/res/cube_model/ tree. Both must pre-exist.
    (solve_dir / "res").mkdir(parents=True, exist_ok=True)

    # Copy cube/* files into solve_dir.
    for src in sorted(_LIFE_CUBE.iterdir()):
        if src.is_file():
            shutil.copy2(src, solve_dir / src.name)

    # Copy lib/ as a sibling.
    shutil.copytree(_LIFE_LIB, lib_dir)

    return solve_dir, cube_res_dir


# ──────────────────────────────────────────────────────────────────────────
# Spawn gmsh + getdp.
# ──────────────────────────────────────────────────────────────────────────

def _run_mesh(gmsh_bin: Path, solve_dir: Path) -> tuple[bool, str, Path | None]:
    """Run `gmsh -3 cube.geo -o cube.msh`. Return (ok, msg, msh_path)."""
    msh = solve_dir / "cube.msh"
    if msh.exists():
        msh.unlink()
    log = solve_dir / "gmsh.log"
    try:
        proc = subprocess.run(
            [str(gmsh_bin), "-3", "cube.geo", "-o", "cube.msh"],
            capture_output=True,
            text=True,
            timeout=_MESH_TIMEOUT_S,
            cwd=str(solve_dir),
        )
    except subprocess.TimeoutExpired:
        log.write_text(f"gmsh meshing timed out after {_MESH_TIMEOUT_S}s\n")
        return False, f"gmsh_timeout_{_MESH_TIMEOUT_S}s", None
    except OSError as exc:
        return False, f"gmsh_exec_failed: {exc!r}", None
    log.write_text((proc.stdout or "") + "\n" + (proc.stderr or ""))
    if proc.returncode != 0 or not msh.exists():
        return False, f"gmsh_returncode_{proc.returncode}", None
    return True, "gmsh_ok", msh


# Stdout markers we parse from a GetDP -v 3 cube.pro solve.
#
# Format reference (life-hts cube.pro + lib/resolution.pro):
#   - "Info    : System 1/1: 3601 Dofs"              → solver_n_dofs
#   - "Time <t> saved."                              → 1 completed step
#   - per-Newton-iteration column 2 is the absolute nonlinear residual;
#     when the inner loop converges its tail value (often ~1e-16) is our
#     "ksp_final_residual" proxy. We pick the last numeric token from
#     the last Newton-iteration row inside the last completed step.
_RE_N_DOFS = re.compile(
    r"System\s+\d+/\d+\s*:\s*(\d+)\s*Dofs", re.IGNORECASE
)
_RE_TIME_SAVED = re.compile(r"^\s*Time\s+[0-9eE+\-.]+\s+saved\.", re.MULTILINE)
# Inner Newton iteration row: integer iter index, then 5+ floats.
# e.g.  "18 7.129000747706e-17 1.008206345712e-17 5.909205883837e+00 ..."
_RE_NEWTON_ROW = re.compile(
    r"^\s*\d+\s+([+-]?\d+\.\d+e[+-]?\d+)\s+([+-]?\d+\.\d+e[+-]?\d+)"
    r"(?:\s+[+-]?\d+\.\d+e[+-]?\d+){3,}\s*$",
    re.MULTILINE,
)
# A step-header row marks the start of a time step:
#   "<step_idx> <dt> <t>"  — 1 int + 2 floats only (no scientific notation
#   on the first two values from cube.pro at default dt).
_RE_STEP_HEADER = re.compile(
    r"^\s*\d+\s+[0-9eE+\-.]+\s+[0-9eE+\-.]+\s*$", re.MULTILINE
)


def _run_solve(
    getdp_bin: Path, solve_dir: Path
) -> tuple[bool, str, Path, bool]:
    """Run getdp with `-solve MagDyn`. Returns (ok, msg, log_path, timed_out).

    ok=True iff process exited 0 within budget.
    timed_out=True iff we killed it at the budget.
    """
    log_path = solve_dir / "getdp_solve.log"
    cmd = [
        str(getdp_bin), "cube.pro",
        "-msh", "cube.msh",
        "-solve", "MagDyn",
        "-v", "3",
    ]
    budget = _solve_timeout_s()
    t0 = time.monotonic()
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=budget,
            cwd=str(solve_dir),
        )
    except subprocess.TimeoutExpired as exc:
        # Persist whatever we captured before the kill.
        out = exc.stdout if isinstance(exc.stdout, str) else (
            exc.stdout.decode("utf-8", "replace") if exc.stdout else ""
        )
        err = exc.stderr if isinstance(exc.stderr, str) else (
            exc.stderr.decode("utf-8", "replace") if exc.stderr else ""
        )
        log_path.write_text((out or "") + "\n" + (err or ""))
        return False, "getdp_timeout_budget_hit", log_path, True
    except OSError as exc:
        log_path.write_text(f"exec_failed: {exc!r}\n")
        return False, f"getdp_exec_failed: {exc!r}", log_path, False
    _ = time.monotonic() - t0
    log_path.write_text((proc.stdout or "") + "\n" + (proc.stderr or ""))
    if proc.returncode != 0:
        first_err = ""
        for line in (proc.stderr or "").splitlines():
            if "error" in line.lower():
                first_err = line.strip()
                break
        return (
            False,
            f"getdp_returncode_{proc.returncode}"
            + (f":{first_err}" if first_err else ""),
            log_path,
            False,
        )
    return True, "getdp_ok", log_path, False


# ──────────────────────────────────────────────────────────────────────────
# Output parsing.
# ──────────────────────────────────────────────────────────────────────────

def _count_iteration_file(root: Path) -> int:
    """Count time-steps from `<root>/cube/res/cube_model/iteration.txt`.

    The resolution writes one row per completed time step. Falls back to
    0 if the file is absent.
    """
    f = root / "cube" / "res" / "cube_model" / "iteration.txt"
    if not f.exists():
        return 0
    try:
        text = f.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return 0
    # Each non-empty line corresponds to one converged step.
    return sum(1 for line in text.splitlines() if line.strip())


# Per-step PostOp column labels — order matches lib/resolution.pro line 340:
#   Print[{$Time, $indicAir, $indicFerro, $indicSuper, $indicDissSuper,
#          $indicDissLin, $Voltage, $Current}, ..., File outputPower];
# The first float is $Time; the remaining seven are PostOp values.
_POWER_COLS = (
    "indicAir",
    "indicFerro",
    "indicSuper",
    "indicDissSuper",
    "indicDissLin",
    "Voltage",
    "Current",
)


def _parse_power_file(root: Path) -> list[dict]:
    """Parse the per-step append-stream at `<outputDir>/power.txt`.

    Returns a list of {"t": float, "postop_values": [float, ...]} dicts —
    one per converged time-step that GetDP flushed to disk. Rows whose
    column count doesn't match the expected 1+len(_POWER_COLS) tokens are
    skipped (defensive; partial-flush at SIGTERM could land a truncated
    final row).
    """
    f = root / "cube" / "res" / "cube_model" / "power.txt"
    if not f.exists():
        return []
    try:
        text = f.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    expected = 1 + len(_POWER_COLS)
    rows: list[dict] = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        toks = line.split()
        if len(toks) != expected:
            continue
        try:
            vals = [float(tok) for tok in toks]
        except ValueError:
            continue
        rows.append({"t": vals[0], "postop_values": vals[1:]})
    return rows


def _compute_transient_analytics(per_step_data: list[dict]) -> dict | None:
    """Derive physically meaningful summaries from the per-step time-series.

    Input: list of {"t": float, "postop_values": [indicAir, indicFerro,
    indicSuper, indicDissSuper, indicDissLin, Voltage, Current]} dicts,
    one per converged time-step (as emitted by _parse_power_file).

    Returns a struct of summary scalars, or None if per_step_data is empty.
    Trapezoidal integration is hand-rolled (no numpy dependency added).
    """
    if not per_step_data:
        return None

    ts: list[float] = []
    indic_super: list[float] = []
    indic_diss_super: list[float] = []
    indic_diss_lin: list[float] = []
    voltage: list[float] = []
    current: list[float] = []
    for row in per_step_data:
        vals = row.get("postop_values") or []
        if len(vals) != len(_POWER_COLS):
            continue
        ts.append(float(row.get("t", 0.0)))
        # _POWER_COLS order: indicAir, indicFerro, indicSuper,
        # indicDissSuper, indicDissLin, Voltage, Current.
        indic_super.append(float(vals[2]))
        indic_diss_super.append(float(vals[3]))
        indic_diss_lin.append(float(vals[4]))
        voltage.append(float(vals[5]))
        current.append(float(vals[6]))

    if not ts:
        return None

    def _trapz(xs: list[float], ys: list[float]) -> float:
        """Hand-rolled trapezoidal rule (no numpy dependency)."""
        n = len(xs)
        if n < 2:
            return 0.0
        acc = 0.0
        for i in range(1, n):
            dx = xs[i] - xs[i - 1]
            acc += 0.5 * (ys[i] + ys[i - 1]) * dx
        return acc

    def _rms(xs: list[float]) -> float:
        if not xs:
            return 0.0
        sq_mean = statistics.fmean(x * x for x in xs)
        return math.sqrt(sq_mean) if sq_mean > 0.0 else 0.0

    def _zero_crossings(xs: list[float]) -> int:
        """Count strict sign changes (exact zeros do not double-count)."""
        count = 0
        prev = 0
        for x in xs:
            sign = 1 if x > 0.0 else (-1 if x < 0.0 else 0)
            if sign == 0:
                continue
            if prev != 0 and sign != prev:
                count += 1
            prev = sign
        return count

    diss_lin_any_nonzero = any(v != 0.0 for v in indic_diss_lin)

    return {
        "t_start": ts[0],
        "t_end": ts[-1],
        "t_span": ts[-1] - ts[0],
        "peak_indic_super_abs": max((abs(v) for v in indic_super), default=0.0),
        "peak_indic_diss_super": max(indic_diss_super, default=0.0),
        "total_loss_super_integral": _trapz(ts, indic_diss_super),
        "total_loss_lin_integral": (
            _trapz(ts, indic_diss_lin) if diss_lin_any_nonzero else 0.0
        ),
        "voltage_rms": _rms(voltage),
        "current_rms": _rms(current),
        "indic_super_zero_crossings": _zero_crossings(indic_super),
    }


def _parse_log(log_path: Path) -> dict:
    """Extract headline numbers from a GetDP solve log."""
    try:
        text = log_path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}
    out: dict = {}

    # Solver DOFs — "Info    : System 1/1: 3601 Dofs"
    m = _RE_N_DOFS.search(text)
    if m:
        out["solver_n_dofs"] = int(m.group(1))

    # Count completed time-step markers seen in stdout.
    out["log_time_steps_seen"] = len(_RE_TIME_SAVED.findall(text))

    # KSP-residual proxy: last absolute-residual value from the last
    # Newton-iteration row. resolution.pro emits one row per inner
    # iteration with format "iter |dE| |dE/E| E_total ... ". Column 2 is
    # the absolute energy/residual; we take the last one.
    newton_hits = _RE_NEWTON_ROW.findall(text)
    if newton_hits:
        try:
            out["ksp_final_residual"] = float(newton_hits[-1][0])
        except (ValueError, IndexError):
            pass

    # MagDyn_energy post-op runs = one per converged time step in the
    # cube.pro resolution flow. Use the "Time X saved." stamp as proxy
    # (it follows each successful MagDyn_energy post-op).
    out["magdyn_energy_postops_completed"] = out["log_time_steps_seen"]

    return out


# ──────────────────────────────────────────────────────────────────────────
# Record emit.
# ──────────────────────────────────────────────────────────────────────────

_KIND = "cube_h_formulation_e_j_power_law"


def _emit(out: Path, stamp: str, record: dict, headline: str) -> int:
    rec_path = out / f"material_verify_h_formulation_cube_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))
    print(f"[material+verify · cube_h_formulation] wrote {rec_path}")
    print(f"  headline: {headline}")
    print(
        f"  gate_type={record.get('gate_type')!r} "
        f"absorbed={record.get('absorbed')} "
        f"provisional={record.get('provisional')}"
    )
    hl = record.get("headline") or {}
    if hl:
        tc = hl.get("transient_capture") or {}
        print(
            "  steps={s} dofs={d} ksp={k} energy_postops={e} "
            "wall={w:.1f}s timed_out={t} captured={c}/{n}".format(
                s=hl.get("time_steps_completed"),
                d=hl.get("solver_n_dofs"),
                k=hl.get("ksp_final_residual"),
                e=hl.get("magdyn_energy_postops_completed"),
                w=float(hl.get("wall_time_s") or 0.0),
                t=hl.get("timed_out"),
                c=tc.get("captured_step_count", 0),
                n=tc.get("time_step_count", 0),
            )
        )
        ta = hl.get("transient_analytics")
        if ta:
            print(
                "  analytics: peak_diss_super={p:.3e} "
                "total_loss_super_integral={i:.3e} "
                "zero_crossings={z}".format(
                    p=float(ta.get("peak_indic_diss_super") or 0.0),
                    i=float(ta.get("total_loss_super_integral") or 0.0),
                    z=int(ta.get("indic_super_zero_crossings") or 0),
                )
            )
    return 0


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    record: dict = {
        "domain": "material",
        "verb": "verify",
        "kind": _KIND,
        "stamp": stamp,
        "axes": dict(_AXES),
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "provisional": True,
        "scope_caveats": list(_BASE_CAVEATS),
        "citations": list(_CITATIONS),
        "headline": {
            "time_steps_completed": 0,
            "solver_n_dofs": None,
            "ksp_final_residual": None,
            "magdyn_energy_postops_completed": 0,
            "wall_time_s": 0.0,
            "timed_out": False,
        },
    }

    # ---- GetDP detection.
    getdp_bin, getdp_ver, getdp_reason = _pick_getdp()
    if getdp_bin is None or getdp_reason == "absent":
        record["axes"]["solver"] = "skipped"
        record["producer"] = "getdp@absent"
        record["gate_type"] = "install-gated"
        record["skipped_reason"] = (
            "getdp_4_0_0_required_for_h_formulation_rho_power_law"
        )
        record["re_enable_hint"] = _RE_ENABLE_HINT
        return _emit(out, stamp, record, "skip: GetDP binary not found")
    if getdp_reason == "version_too_old":
        ver_s = ".".join(str(x) for x in (getdp_ver or (0, 0, 0)))
        record["axes"]["solver"] = "skipped"
        record["producer"] = f"getdp@{getdp_bin}({ver_s})"
        record["gate_type"] = "install-gated"
        record["skipped_reason"] = (
            "getdp_4_0_0_required_for_h_formulation_rho_power_law"
        )
        record["scope_caveats"].append(
            f"GetDP {ver_s} present at {getdp_bin} but life-hts cube.pro "
            "requires RhoPowerLaw built-in introduced in GetDP 4.0.0."
        )
        record["re_enable_hint"] = _RE_ENABLE_HINT
        return _emit(
            out, stamp, record, f"skip: GetDP {ver_s} < 4.0.0 required"
        )
    ver_s = ".".join(str(x) for x in (getdp_ver or (4, 0, 0)))
    record["producer"] = f"getdp@{getdp_bin}({ver_s})"

    # ---- life-hts cube source detection.
    cube_present = (
        _LIFE_CUBE.is_dir()
        and (_LIFE_CUBE / "cube.pro").exists()
        and (_LIFE_CUBE / "cube.geo").exists()
        and _LIFE_LIB.is_dir()
    )
    if not cube_present:
        record["axes"]["solver"] = "skipped"
        record["gate_type"] = "license-unclear"
        record["skipped_reason"] = "life_hts_cube_source_not_fetched"
        record["scope_caveats"].append(
            "life-hts upstream not present at "
            f"{_LIFE_EXTERNAL} — run fetch.sh under "
            "templates/hts_workgroup/life_hts_pancakes_ref/ first (note: "
            "license is unclear; local-only inspection)."
        )
        record["re_enable_hint"] = _RE_ENABLE_HINT
        return _emit(out, stamp, record, "skip: life-hts cube source absent")

    # ---- License-unclear opt-in gate.
    if os.environ.get("DEMIURGE_RTSC_USE_LICENSE_UNCLEAR", "") != "1":
        record["axes"]["solver"] = "skipped"
        record["gate_type"] = "license-unclear"
        record["skipped_reason"] = "license_unclear_opt_in_required"
        record["scope_caveats"].append(
            "life-hts cube/ source is present locally but its license is "
            "unclear (per templates/hts_workgroup/INDEX.md). Live solve "
            "requires explicit opt-in: set DEMIURGE_RTSC_USE_LICENSE_UNCLEAR=1."
        )
        record["re_enable_hint"] = _RE_ENABLE_HINT
        return _emit(
            out,
            stamp,
            record,
            "skip: license-unclear opt-in required",
        )

    # ---- Mesh.
    gmsh_bin = _which_gmsh()
    if gmsh_bin is None:
        record["axes"]["solver"] = "skipped"
        record["gate_type"] = "install-gated"
        record["skipped_reason"] = "gmsh_binary_not_found"
        record["scope_caveats"].append(
            "gmsh not on PATH — required to mesh cube.geo before getdp solve."
        )
        record["re_enable_hint"] = _RE_ENABLE_HINT
        return _emit(out, stamp, record, "skip: gmsh missing")

    # Stage temp work tree.
    work_root = Path(
        os.environ.get("DEMIURGE_CUBE_WORKROOT") or f"/tmp/cube_producer_{stamp}"
    )
    try:
        solve_dir, _res_dir = _stage_workdir(work_root)
    except OSError as exc:
        record["gate_type"] = "install-gated"
        record["skipped_reason"] = f"workdir_stage_failed: {exc!r}"
        record["re_enable_hint"] = _RE_ENABLE_HINT
        return _emit(out, stamp, record, "skip: workdir staging failed")
    record["work_root"] = str(work_root)

    mesh_ok, mesh_msg, _ = _run_mesh(gmsh_bin, solve_dir)
    if not mesh_ok:
        record["axes"]["solver"] = "getdp_attempted"
        record["gate_type"] = "install-gated"
        record["skipped_reason"] = mesh_msg
        record["scope_caveats"].append(
            "gmsh meshing of cube.geo did not produce cube.msh — see "
            "work_root/cube_solve/gmsh.log."
        )
        record["re_enable_hint"] = _RE_ENABLE_HINT
        return _emit(out, stamp, record, f"skip: mesh failed ({mesh_msg})")

    # ---- Solve.
    t0 = time.monotonic()
    solve_ok, solve_msg, log_path, timed_out = _run_solve(
        getdp_bin, solve_dir
    )
    wall = time.monotonic() - t0
    record["headline"]["wall_time_s"] = round(wall, 2)
    record["headline"]["timed_out"] = bool(timed_out)
    record["solve_log"] = str(log_path)

    # Parse whatever we have, regardless of exit (partial-cycle counts).
    n_steps = _count_iteration_file(work_root)
    log_facts = _parse_log(log_path)
    record["headline"]["time_steps_completed"] = n_steps
    if "solver_n_dofs" in log_facts:
        record["headline"]["solver_n_dofs"] = log_facts["solver_n_dofs"]
    if "ksp_final_residual" in log_facts:
        record["headline"]["ksp_final_residual"] = log_facts[
            "ksp_final_residual"
        ]
    record["headline"]["magdyn_energy_postops_completed"] = log_facts.get(
        "magdyn_energy_postops_completed", 0
    )
    record["headline"]["log_time_steps_seen"] = log_facts.get(
        "log_time_steps_seen", 0
    )

    # ---- Transient capture (approach (a)) --------------------------------
    # power.txt is the per-step append-stream emitted by lib/resolution.pro;
    # it pre-exists for ALL completed steps regardless of dummy.txt's
    # truncate behaviour. No watcher subprocess needed.
    per_step = _parse_power_file(work_root)
    captured = len(per_step)
    record["headline"]["transient_capture"] = {
        "time_step_count": n_steps,
        "captured_step_count": captured,
        "column_labels": ["t", *_POWER_COLS],
        "source_file": "<work_root>/cube/res/cube_model/power.txt",
        "capture_approach": "a_append_file_parse",
        "per_step_data": per_step,
    }
    # Derived summaries over the 191-step series — turn the raw time-series
    # into a handful of physically interpretable scalars on the headline.
    analytics = _compute_transient_analytics(per_step)
    record["headline"]["transient_analytics"] = analytics
    if analytics is not None:
        record["scope_caveats"].append(
            "(s9) Transient analytics computed from "
            f"{captured} captured steps (out of {n_steps} total — see s8). "
            "Integrals use trapezoidal rule on partial-cycle data → "
            "magnitudes are not full-cycle losses, only partial-cycle "
            "proxies. indicSuper/DissSuper columns reflect numerical "
            "solver indicators (life-hts lib/resolution.pro), NOT measured "
            "physical quantities — interpret as solver-internal diagnostics."
        )
    # Honest g3 — if our captured rows undershoot the iteration.txt count,
    # GetDP probably flushed a partial final row at SIGTERM that we rejected
    # for the column-count guard, or iteration.txt counts non-converged
    # attempts. Either way, surface as a scope_caveat.
    if captured < n_steps:
        record["scope_caveats"].append(
            "(s8) transient_capture: captured_step_count "
            f"({captured}) < time_step_count ({n_steps}) — likely a "
            "partial final-row flush on solve termination; "
            "per_step_data is a strict prefix of the converged-step series."
        )

    if solve_ok:
        record["gate_type"] = "hexa-native-absent"
        record["scope_caveats"].append(
            "GetDP 4.0.0 cube H-formulation solve completed within wall "
            "budget — post-processing (Jc, AC loss per cycle, current "
            "penetration profile) NOT yet parsed by this producer. "
            "absorbed=false until benchmark-validated post-processing lands."
        )
        headline = (
            f"ok: GetDP 4.0.0 cube solve completed ({n_steps} time-steps, "
            f"{wall:.1f}s wall)"
        )
    elif timed_out:
        # Partial-cycle is a legitimate Tier 1 record so long as ≥1 step ran.
        if n_steps > 0:
            record["gate_type"] = "partial-cycle-timeout"
            record["scope_caveats"].append(
                f"GetDP 4.0.0 cube H-formulation solve captured {n_steps} "
                f"time-steps within {_solve_timeout_s()}s wall budget. "
                "Full-cycle convergence is a separate cohort; (s7) applies."
            )
            headline = (
                f"partial-cycle: {n_steps} time-steps in "
                f"{_solve_timeout_s()}s budget"
            )
        else:
            record["gate_type"] = "install-gated"
            record["skipped_reason"] = (
                "getdp_timeout_no_steps_completed"
            )
            record["scope_caveats"].append(
                f"GetDP 4.0.0 cube solve hit {_solve_timeout_s()}s budget "
                "before completing any time-step — see solve_log."
            )
            headline = "skip: solve timeout before first step"
    else:
        record["axes"]["solver"] = "getdp_attempted"
        record["gate_type"] = "install-gated"
        record["skipped_reason"] = solve_msg
        record["scope_caveats"].append(
            "GetDP 4.0.0 was present and life-hts cube source was located, "
            "but the solve did not complete successfully. See solve_log "
            "for details."
        )
        headline = f"skip: solve failed ({solve_msg})"

    return _emit(out, stamp, record, headline)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/cube_test"))
