#!/usr/bin/env python3
# novel_material_funnel.py — `material + discover` N5 cohort orchestrator
# (RTSC.md §9.10 · B path · wrap-as-is).
#
# Compositional-space discovery funnel: takes an element pool + stoichiometry
# bounds, enumerates heuristic-bounded candidate compositions (~hundreds to
# ~thousand, NOT 1.3M like the SOTA Materials-Genome-Initiative paper), filters
# against the local MP cache for novelty, then orchestrates N1-N4 (csp /
# beenet / askcos / cross_code_dft) per candidate via subprocess, computes a
# closed-form composite score, and emits top-K to
# `~/core/demiurge/exports/material_discovery/<stamp>/top_k.json`.
#
# Sibling pattern — see `csp_adapter.py` (N1), `beenet_adapter.py` (N2),
# `askcos_adapter.py` (N3), `cross_code_dft.py` (N4). N5 does NOT reimplement
# their logic — it shells out to them and aggregates JSON records.
#
# R4 invariant (ALWAYS): absorbed=false. The funnel's output is a *wet-lab
# priority candidate list*, NEVER a discovery claim. See scope_caveats
# (s1)-(s4).
#
# Skip path semantics (gate_type values):
#   - novel-discovery-simulation        — at least one candidate scored
#   - no-candidates-stable              — every candidate failed N4 stability
#
# RTSC anchor: RTSC.md §9.10 (N5 cohort spec) + §9.9 (1.3M → 741 SOTA pattern)
# + §8.9 5-gate honest scope (a)(b)(c) sim only · (d)(e) wet-lab永遠.

from __future__ import annotations

import argparse
import itertools
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


# ─── sibling adapter paths (resolved via this file's parent dir) ───────────

_SELF_DIR = Path(__file__).resolve().parent
_N1_CSP = _SELF_DIR / "csp_adapter.py"
_N2_BEENET = _SELF_DIR / "beenet_adapter.py"
_N3_ASKCOS = _SELF_DIR / "askcos_adapter.py"
_N4_DFT = _SELF_DIR / "cross_code_dft.py"

_MP_CACHE_DIR = Path(os.path.expanduser(
    "~/core/demiurge/exports/material_cache/mp"
))
_DISCOVERY_OUT_ROOT = Path(os.path.expanduser(
    "~/core/demiurge/exports/material_discovery"
))


# ─── periodic table — typical oxidation states for charge-balance heuristic ─
#
# Sparse, conservative table. Missing element → falls back to [-2,-1,0,1,2,3].
# Source: standard inorganic chemistry; conservative supersets so the
# enumerator doesn't drop common SC compositions.

_OX_STATES: dict[str, tuple[int, ...]] = {
    "H":  (-1, 1),
    "Li": (1,),
    "Be": (2,),
    "B":  (-3, 3),
    "C":  (-4, -2, 2, 4),
    "N":  (-3, 3, 5),
    "O":  (-2,),
    "F":  (-1,),
    "Na": (1,),
    "Mg": (2,),
    "Al": (3,),
    "Si": (-4, 4),
    "P":  (-3, 3, 5),
    "S":  (-2, 2, 4, 6),
    "Cl": (-1, 1, 5, 7),
    "K":  (1,),
    "Ca": (2,),
    "Sc": (3,),
    "Ti": (2, 3, 4),
    "V":  (2, 3, 4, 5),
    "Cr": (2, 3, 6),
    "Mn": (2, 3, 4, 6, 7),
    "Fe": (2, 3),
    "Co": (2, 3),
    "Ni": (2, 3),
    "Cu": (1, 2, 3),
    "Zn": (2,),
    "Ga": (3,),
    "Ge": (-4, 2, 4),
    "As": (-3, 3, 5),
    "Se": (-2, 4, 6),
    "Br": (-1, 1, 5),
    "Rb": (1,),
    "Sr": (2,),
    "Y":  (3,),
    "Zr": (4,),
    "Nb": (3, 4, 5),
    "Mo": (3, 4, 5, 6),
    "Ru": (2, 3, 4, 8),
    "Rh": (3,),
    "Pd": (2, 4),
    "Ag": (1,),
    "Cd": (2,),
    "In": (3,),
    "Sn": (2, 4),
    "Sb": (-3, 3, 5),
    "Te": (-2, 4, 6),
    "I":  (-1, 1, 5, 7),
    "Cs": (1,),
    "Ba": (2,),
    "La": (3,),
    "Ce": (3, 4),
    "W":  (4, 6),
    "Pt": (2, 4),
    "Au": (1, 3),
    "Hg": (1, 2),
    "Tl": (1, 3),
    "Pb": (2, 4),
    "Bi": (3, 5),
}

_FALLBACK_OX = (-2, -1, 0, 1, 2, 3)


# ─── composition enumeration ───────────────────────────────────────────────


def _format_composition(elems: list[str], counts: list[int]) -> str:
    """Render `[Pb, Cu, P, O] + [10, 1, 6, 26] → 'Pb10CuP6O26'`. Skips
    coefficient when count==1 (matches MP / convention)."""
    parts: list[str] = []
    for e, n in zip(elems, counts):
        if n <= 0:
            continue
        parts.append(e if n == 1 else f"{e}{n}")
    return "".join(parts)


def _slugify(composition: str) -> str:
    """Match the MP-cache slug shape (cross_code_dft._slugify_mp_cache)."""
    s = composition.replace("(", "_").replace(")", "_")
    s = re.sub(r"_+", "_", s).strip("_")
    return s


def _can_charge_balance(elems: list[str], counts: list[int]) -> bool:
    """Return True iff some combination of per-element oxidation states sums
    to zero (i.e., the composition is *potentially* a neutral ionic
    compound or metallic alloy). All elements implicitly have oxidation
    state 0 (metallic / elemental) in addition to their tabulated ionic
    states — this keeps Nb, NbTi, Nb3Sn, MgB2 (intermetallic), etc.

    This is a conservative heuristic — passes some compositions that are
    chemically dubious but won't reject MgB2, YBa2Cu3O7, Pb10Cu(PO4)6O,
    NbTi, Nb3Sn, etc.
    """
    # Always include 0 (metallic) — covers pure metals + intermetallic
    # alloys (NbTi, Nb3Sn, FeSe, etc.) that wouldn't satisfy purely-ionic
    # charge balance.
    ox_lists = [
        tuple(sorted(set(_OX_STATES.get(e, _FALLBACK_OX)) | {0}))
        for e in elems
    ]
    # Bound the search — itertools.product over up to ~6 element pools each
    # ≤ 7 states = ~117k worst case. Cap at this.
    total_states = 1
    for ox in ox_lists:
        total_states *= len(ox)
        if total_states > 200_000:
            # Too many state combos — bail out as "plausible" (don't reject).
            return True
    for combo in itertools.product(*ox_lists):
        s = 0
        for c, n in zip(combo, counts):
            s += c * n
        if s == 0:
            return True
    return False


def _enumerate_compositions(
    element_pool: list[str],
    max_atoms: int,
    max_candidates: int = 500,
) -> list[tuple[str, list[str], list[int]]]:
    """Combinatorial enumeration with heuristic bounds.

    Strategy:
      1. For each subset size k in [1, len(pool)] (binary "use element?"
         mask — only consider non-trivial subsets, k >= 2 preferred for
         SC chemistry, but k=1 allowed for elemental metals like Nb).
      2. For each subset, enumerate stoichiometry vectors with
         `1 <= n_i` and `sum(n_i) <= max_atoms`. We restrict per-element
         counts to [1, max_per_element] where max_per_element scales
         with subset size to keep combinatorics manageable.
      3. Charge-balance filter (only kept if `_can_charge_balance`).
      4. Stop at `max_candidates` total.

    Returns list of (formula_string, elements, counts).
    """
    out: list[tuple[str, list[str], list[int]]] = []
    pool = list(element_pool)
    n_pool = len(pool)
    # Per-subset cap on individual-element count — scales DOWN with subset
    # size to keep total enumeration bounded. For singletons (k=1) we allow
    # the full max_atoms; for k=6 we cap each at max_atoms // 2.
    for k in range(1, n_pool + 1):
        # Cap individual count to keep search space bounded
        max_per = max(1, max_atoms // max(1, k - 1)) if k > 1 else max_atoms
        max_per = min(max_per, max_atoms)
        for subset_idx in itertools.combinations(range(n_pool), k):
            elems = [pool[i] for i in subset_idx]
            # Iterate over stoichiometry — use a recursive generator that
            # prunes when running sum exceeds max_atoms.
            for counts in _stoich_iter(k, max_per, max_atoms):
                if len(out) >= max_candidates:
                    return out
                if not _can_charge_balance(elems, list(counts)):
                    continue
                formula = _format_composition(elems, list(counts))
                if not formula:
                    continue
                out.append((formula, list(elems), list(counts)))
                if len(out) >= max_candidates:
                    return out
    return out


def _stoich_iter(k: int, max_per: int, max_atoms: int):
    """Yield count vectors of length k, each entry in [1, max_per], with
    sum <= max_atoms. Prunes branches whose partial sum already exceeds
    max_atoms."""
    def _rec(prefix: list[int], remaining: int, slots: int):
        if slots == 0:
            yield tuple(prefix)
            return
        # Per-slot cap so the remaining slots can still each contribute >=1
        cap = min(max_per, remaining - (slots - 1))
        if cap < 1:
            return
        for c in range(1, cap + 1):
            yield from _rec(prefix + [c], remaining - c, slots - 1)

    yield from _rec([], max_atoms, k)


# ─── novelty filter (MP cache) ─────────────────────────────────────────────


def _mp_novelty(composition: str) -> tuple[str, str | None]:
    """Return (novelty_flag, cache_path_or_None).
    novelty_flag ∈ {"known-in-mp", "novel"}.
    """
    slug = _slugify(composition)
    cands = [
        _MP_CACHE_DIR / f"{slug}.json",
        _MP_CACHE_DIR / f"{composition}.json",
    ]
    for p in cands:
        if p.is_file():
            return ("known-in-mp", str(p))
    return ("novel", None)


# ─── subprocess helpers — call N1/N2/N3/N4 and parse latest JSON ───────────


def _run_subprocess(
    script: Path,
    args: list[str],
    timeout: float = 90.0,
) -> tuple[int, str, str]:
    """Run `python3 <script> <args...>`. Returns (returncode, stdout, stderr).
    On timeout / OS error, returns (-1, "", error_message).
    """
    try:
        result = subprocess.run(
            ["python3", str(script), *args],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", f"timeout after {timeout}s"
    except OSError as e:
        return -1, "", f"OSError: {e}"


def _latest_json_in_dir(dir_path: Path) -> dict[str, Any] | None:
    """Return parsed JSON of the most-recently-modified *.json in dir, or
    None if no JSON file is present."""
    if not dir_path.is_dir():
        return None
    js = sorted(dir_path.glob("*.json"), key=lambda p: p.stat().st_mtime)
    if not js:
        return None
    try:
        return json.loads(js[-1].read_text())
    except Exception:
        return None


def _run_n4_dft(
    composition: str, subdir: Path
) -> tuple[dict[str, Any] | None, float | None, str | None]:
    """N4 cross_code_dft for formation_energy. Returns (record, fe, error).
    `fe` is the consensus formation_energy_per_atom (eV) when computed, else
    None.
    """
    subdir.mkdir(parents=True, exist_ok=True)
    rc, stdout, stderr = _run_subprocess(
        _N4_DFT,
        [str(subdir), composition, "--property", "formation_energy"],
        timeout=45.0,
    )
    if rc != 0 and rc != -1:
        # N4 exits 0 even when insufficient-sources — non-zero is a real
        # problem. Continue but record.
        pass
    record = _latest_json_in_dir(subdir)
    if record is None:
        err = stderr[:200] if stderr else "no JSON written"
        return None, None, f"N4 failed: {err}"
    consensus = record.get("consensus")
    fe: float | None = None
    if isinstance(consensus, dict):
        fe = consensus.get("value")
        if fe is not None:
            try:
                fe = float(fe)
            except (TypeError, ValueError):
                fe = None
    # Fallback: even if no 2-source consensus, scan sources_returned for
    # single-source values (so e.g., mp_cache-only known materials still
    # have a stability estimate).
    if fe is None:
        for r in record.get("sources_returned") or []:
            if r.get("name") == "hexa_rtsc":
                continue
            v = r.get("value")
            if v is not None:
                try:
                    fe = float(v)
                    break
                except (TypeError, ValueError):
                    continue
    return record, fe, None


def _run_n1_csp(
    composition: str, subdir: Path, max_atoms: int
) -> dict[str, Any] | None:
    subdir.mkdir(parents=True, exist_ok=True)
    _rc, _so, _se = _run_subprocess(
        _N1_CSP,
        [str(subdir), composition, "--max-atoms", str(max_atoms)],
        timeout=30.0,
    )
    return _latest_json_in_dir(subdir)


def _run_n2_beenet(
    composition: str, subdir: Path
) -> dict[str, Any] | None:
    subdir.mkdir(parents=True, exist_ok=True)
    _rc, _so, _se = _run_subprocess(
        _N2_BEENET, [str(subdir), composition], timeout=30.0,
    )
    return _latest_json_in_dir(subdir)


def _run_n3_askcos(
    composition: str, subdir: Path
) -> dict[str, Any] | None:
    subdir.mkdir(parents=True, exist_ok=True)
    _rc, _so, _se = _run_subprocess(
        _N3_ASKCOS, [str(subdir), composition], timeout=30.0,
    )
    return _latest_json_in_dir(subdir)


# ─── composite score (closed-form, no ML) ──────────────────────────────────


def _composite_score(
    formation_energy: float | None,
    predicted_tc: float | None,
    tc_threshold: float,
    n_routes: int,
) -> tuple[float, float, float, float]:
    """Return (composite, stability_score, tc_score, synth_score).

    stability_score = 1 / (1 + max(0, fe))  — higher = more stable
    tc_score        = predicted_tc / tc_threshold (or 0 if None)
    synth_score     = 1.0 if n_routes > 0 else 0.3
    composite       = stability * tc * synth
    """
    if formation_energy is None:
        # Unknown stability — neutral default (1.0 / (1 + 0.5) ≈ 0.67)
        stability = 1.0 / (1.0 + 0.5)
    else:
        stability = 1.0 / (1.0 + max(0.0, float(formation_energy)))
    if predicted_tc is None or tc_threshold <= 0:
        tc_score = 0.0
    else:
        tc_score = float(predicted_tc) / float(tc_threshold)
    synth_score = 1.0 if n_routes > 0 else 0.3
    composite = stability * tc_score * synth_score
    return composite, stability, tc_score, synth_score


# ─── main orchestrator ─────────────────────────────────────────────────────


def main(
    out_dir: str,
    element_pool_csv: str,
    max_atoms: int,
    tc_threshold: float,
    top_k: int,
    max_candidates: int,
) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    element_pool = [e.strip() for e in element_pool_csv.split(",") if e.strip()]
    if not element_pool:
        print("error: element_pool is empty", file=sys.stderr)
        return 2

    # ─── enumerate ─────────────────────────────────────────────────────
    enum = _enumerate_compositions(
        element_pool, max_atoms=max_atoms, max_candidates=max_candidates,
    )
    candidate_count_total = len(enum)

    # ─── per-candidate pipeline ────────────────────────────────────────
    candidates_eval: list[dict[str, Any]] = []
    sub_root = out / f"{stamp}_subruns"
    sub_root.mkdir(parents=True, exist_ok=True)

    stable_count = 0
    high_tc_count = 0

    for idx, (formula, _elems, _counts) in enumerate(enum):
        slug = _slugify(formula)
        novelty, mp_cache_path = _mp_novelty(formula)
        per_dir = sub_root / f"{idx:04d}_{slug}"

        # N4 — formation_energy / stability
        n4_dir = per_dir / "n4"
        n4_record, fe, _n4_err = _run_n4_dft(formula, n4_dir)
        n4_record_path: str | None = None
        if n4_record is not None:
            stamp_field = n4_record.get("stamp", "")
            n4_record_path = str(
                n4_dir / f"material_verify_{stamp_field}.json"
            )

        # Stability gate — Tier 1 (Nature s41524-026-01964-8 pattern):
        # formation_energy > 0.5 eV/atom = thermodynamically unstable, drop
        # from downstream. If fe is None (no consensus, no MP, no AFLOW,
        # no OQMD) we treat it as *insufficient information* — we still
        # include the candidate (with neutral stability default), but flag.
        is_stable: bool
        if fe is None:
            is_stable = True  # unknown — keep but downstream synth_score
        else:
            is_stable = (fe <= 0.5)
        if is_stable:
            stable_count += 1

        # N1 / N2 / N3 — call regardless (per spec: "Even if all N1-N4
        # skip, N5 must still produce a record"). For unstable candidates
        # we still record the N4 result but skip downstream subprocess
        # spend.
        n1_record: dict[str, Any] | None = None
        n2_record: dict[str, Any] | None = None
        n3_record: dict[str, Any] | None = None
        n1_record_path: str | None = None
        n2_record_path: str | None = None
        n3_record_path: str | None = None
        n1_skipped_reason: str | None = None
        n2_skipped_reason: str | None = None
        n3_skipped_reason: str | None = None

        if is_stable:
            n1_dir = per_dir / "n1"
            n1_record = _run_n1_csp(formula, n1_dir, max_atoms)
            if n1_record is not None:
                stamp_field = n1_record.get("stamp", "")
                n1_record_path = str(
                    n1_dir / f"material_verify_csp_{stamp_field}.json"
                )
                n1_skipped_reason = n1_record.get("skipped_reason")

            n2_dir = per_dir / "n2"
            n2_record = _run_n2_beenet(formula, n2_dir)
            if n2_record is not None:
                stamp_field = n2_record.get("stamp", "")
                n2_record_path = str(
                    n2_dir / f"material_verify_beenet_{stamp_field}.json"
                )
                n2_skipped_reason = n2_record.get("skipped_reason")

            n3_dir = per_dir / "n3"
            n3_record = _run_n3_askcos(formula, n3_dir)
            if n3_record is not None:
                stamp_field = n3_record.get("stamp", "")
                n3_record_path = str(
                    n3_dir / f"material_verify_{stamp_field}.json"
                )
                n3_skipped_reason = n3_record.get("skipped_reason")
        else:
            n1_skipped_reason = (
                f"skipped: N4 formation_energy={fe:.4f} eV/atom > 0.5 "
                f"(thermodynamically unstable)"
            )
            n2_skipped_reason = n1_skipped_reason
            n3_skipped_reason = n1_skipped_reason

        # Extract predicted properties
        predicted_tc: float | None = None
        if n2_record:
            pred = n2_record.get("predicted") or {}
            v = pred.get("tc_K")
            if v is not None:
                try:
                    predicted_tc = float(v)
                except (TypeError, ValueError):
                    predicted_tc = None

        structure_summary: dict[str, Any] | None = None
        if n1_record:
            cands_list = n1_record.get("candidates_predicted") or []
            if cands_list:
                structure_summary = cands_list[0]

        n_routes = 0
        if n3_record:
            n_routes = len(n3_record.get("routes_predicted") or [])

        if predicted_tc is not None and predicted_tc >= tc_threshold:
            high_tc_count += 1

        composite, s_stab, s_tc, s_synth = _composite_score(
            fe, predicted_tc, tc_threshold, n_routes,
        )

        candidates_eval.append({
            "composition": formula,
            "slug": slug,
            "novelty": novelty,
            "mp_cache_path": mp_cache_path,
            "predicted": {
                "formation_energy_eV_per_atom": fe,
                "structure_summary": structure_summary,
                "tc_K": predicted_tc,
                "synth_routes_count": n_routes,
            },
            "scores": {
                "stability_score": s_stab,
                "tc_score": s_tc,
                "synth_score": s_synth,
                "composite_score": composite,
            },
            "composite_score": composite,
            "source_records": {
                "n1_csp_record": n1_record_path,
                "n2_beenet_record": n2_record_path,
                "n3_askcos_record": n3_record_path,
                "n4_dft_record": n4_record_path,
            },
            "sub_cohort_gates": {
                "n1_gate_type": (n1_record or {}).get("gate_type"),
                "n2_gate_type": (n2_record or {}).get("gate_type"),
                "n3_gate_type": (n3_record or {}).get("gate_type"),
                "n4_gate_type": (n4_record or {}).get("gate_type"),
            },
            "sub_cohort_skipped": {
                "n1": n1_skipped_reason,
                "n2": n2_skipped_reason,
                "n3": n3_skipped_reason,
            },
            "is_stable_tier1": is_stable,
        })

    # ─── rank ──────────────────────────────────────────────────────────
    candidates_eval.sort(key=lambda c: c["composite_score"], reverse=True)
    top_k_list = candidates_eval[:top_k]

    # ─── gate / skipped_reason ─────────────────────────────────────────
    if candidate_count_total == 0:
        gate_type = "no-candidates-stable"
        skipped_reason = (
            f"No candidate compositions survived enumeration. "
            f"element_pool={element_pool!r}, max_atoms={max_atoms}, "
            f"max_candidates={max_candidates}. Try widening max_atoms "
            f"or adding elements with broader oxidation-state ranges."
        )
    elif stable_count == 0:
        gate_type = "no-candidates-stable"
        skipped_reason = (
            f"Enumerated {candidate_count_total} candidates but none passed "
            f"Tier 1 stability (formation_energy_eV_per_atom <= 0.5). "
            f"Common cause: MP/AFLOW/OQMD have no entries for the enumerated "
            f"compositions AND DEMIURGE_DFT_HEAVY_RUN is not set, so N4 "
            f"returns insufficient-sources → fe=None → fallback neutral, "
            f"OR every fe>0.5 was returned. Top-K still emitted by composite "
            f"score (which has neutral defaults)."
        )
    else:
        gate_type = "novel-discovery-simulation"
        skipped_reason = None

    # ─── record dump ───────────────────────────────────────────────────
    record: dict[str, Any] = {
        "domain": "material",
        "verb": "discover",
        "kind": "novel_material_funnel",
        "stamp": stamp,
        "producer": "novel_material_funnel@material-N5",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,        # R4 invariant — ALWAYS false
        "gate_type": gate_type,
        "provisional": True,
        "skipped_reason": skipped_reason,
        "query": {
            "element_pool": element_pool,
            "max_atoms": max_atoms,
            "tc_threshold": tc_threshold,
            "top_k_requested": top_k,
            "max_candidates": max_candidates,
        },
        "candidate_count_total": candidate_count_total,
        "candidate_count_filtered_stable": stable_count,
        "candidate_count_high_tc": high_tc_count,
        "top_k_candidates": top_k_list,
        "scope_caveats": [
            "(s1) Compositional enumeration is heuristic-bounded (~hundreds "
            "to ~thousand candidates), NOT Materials-Genome-Initiative "
            "scale (1.3M). Output is a small wet-lab priority list, not "
            "exhaustive discovery.",
            "(s2) Each candidate's pipeline result depends on N1-N4 "
            "backend availability. install-gated/weights-missing/"
            "insufficient-sources rates are expected on a fresh macOS "
            "host — most candidates will return partial results.",
            "(s3) Composite_score is closed-form heuristic, NOT a measured "
            "property. Top-K ranking is a recommendation, not a discovery "
            "claim.",
            "(s4) R4 invariant: absorbed=false 영원. \"이 후보가 RTSC 일 "
            "가능성\" ≠ \"이 후보가 RTSC 임\". (a)(b)(c) gate sim 영역만 "
            "채움; (d)(e) 는 wet-lab 의존.",
        ],
        "citations": [
            "arxiv:2511.03865 — Materials Genome HTS discovery workflow.",
            "Nature s41524-026-01964-8 — Complete AI-accelerated SC "
            "discovery workflow (1.3M cand → 741 stable funnel).",
            "arxiv:2509.10293 — OpenCSP deep-learning CSP framework.",
            "RTSC.md §9.10 — N5 cohort spec (novel-discovery funnel).",
        ],
        "provenance": {
            "rtsc_anchor": (
                "RTSC.md §9.10 (N5 cohort) + §8.9 5-gate honest scope + "
                "§9.7 N1-N4 delegation targets"
            ),
            "delegates": {
                "n1_csp": str(_N1_CSP),
                "n2_beenet": str(_N2_BEENET),
                "n3_askcos": str(_N3_ASKCOS),
                "n4_cross_code_dft": str(_N4_DFT),
            },
            "mp_cache_dir": str(_MP_CACHE_DIR),
        },
        "recommendation": (
            "top_k_candidates is a wet-lab priority list. Wet-lab "
            "synthesis + RTSC.md §8.9 (d) replicated_by_independent_labs "
            ">= 3 + (e) measurement_oracle (Mössbauer / SQUID / R(T)) is "
            "the ONLY path to absorbed=true. Composite score is a "
            "closed-form HEURISTIC, not a discovery claim."
        ),
    }

    # Emit two artifacts:
    #   1. top_k.json — concise, the canonical N5 output per §9.10 spec
    #   2. material_discover_<stamp>.json — full record (sibling-shape)
    top_k_path = out / "top_k.json"
    top_k_path.write_text(json.dumps(record, indent=2))
    full_path = out / f"material_discover_{stamp}.json"
    full_path.write_text(json.dumps(record, indent=2))

    # ─── headline ──────────────────────────────────────────────────────
    print(f"[material+discover · novel_material_funnel-N5] wrote {top_k_path}")
    print(
        f"  · element_pool={element_pool!r}  max_atoms={max_atoms}  "
        f"tc_threshold={tc_threshold}K  top_k={top_k}"
    )
    print(
        f"  · candidates_enumerated={candidate_count_total}  "
        f"stable_tier1={stable_count}  high_tc={high_tc_count}  "
        f"gate_type={gate_type}"
    )
    if skipped_reason:
        first_line = str(skipped_reason).splitlines()[0]
        print(f"  · skipped_reason: {first_line}")
    for i, c in enumerate(top_k_list[:5]):
        scores = c.get("scores", {})
        pred = c.get("predicted", {})
        print(
            f"    #{i + 1}  {c['composition']!r}  "
            f"composite={scores.get('composite_score', 0.0):.4f}  "
            f"novelty={c['novelty']!r}  "
            f"fe={pred.get('formation_energy_eV_per_atom')}  "
            f"tc={pred.get('tc_K')}"
        )
    if len(top_k_list) > 5:
        print(f"    ... ({len(top_k_list) - 5} more in top_k.json)")
    print(
        "[material+discover · novel_material_funnel-N5] absorbed=false "
        "(R4 invariant; top_k is wet-lab priority list, NEVER a discovery "
        "claim — RTSC.md §9.10 + §8.9 (d)(e) wet-lab 의존永遠)"
    )
    return 0


def _parse_argv(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="novel_material_funnel.py",
        description=(
            "N5 cohort — novel-discovery funnel orchestrator (RTSC.md §9.10, "
            "B path · wrap-as-is). Enumerates compositional candidates from "
            "an element pool, filters against MP cache for novelty, then "
            "orchestrates N1-N4 (csp/beenet/askcos/cross_code_dft) per "
            "candidate and emits top-K by closed-form composite score. "
            "absorbed=false ALWAYS (R4 invariant)."
        ),
    )
    p.add_argument("out_dir", help="output directory for top_k.json")
    p.add_argument(
        "element_pool_csv",
        help='comma-separated element symbols (e.g., "H,Pb,Cu,P,O")',
    )
    p.add_argument(
        "--max-atoms", type=int, default=20,
        help="max sum of stoichiometric coefficients (default 20)",
    )
    p.add_argument(
        "--tc-threshold", type=float, default=50.0,
        help="Tc threshold (K) for high-tc count + tc_score normalization "
             "(default 50)",
    )
    p.add_argument(
        "--top-k", type=int, default=10,
        help="number of top candidates to emit (default 10)",
    )
    p.add_argument(
        "--max-candidates", type=int, default=50,
        help="upper bound on enumerated compositions (default 50; each "
             "candidate spawns 4 subprocesses, ~5-6s each → raise carefully)",
    )
    return p.parse_args(argv)


if __name__ == "__main__":
    ns = _parse_argv(sys.argv[1:])
    sys.exit(main(
        ns.out_dir,
        ns.element_pool_csv,
        ns.max_atoms,
        ns.tc_threshold,
        ns.top_k,
        ns.max_candidates,
    ))
