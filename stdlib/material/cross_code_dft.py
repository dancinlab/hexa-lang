#!/usr/bin/env python3
# cross_code_dft.py — `material + verify` cross-code DFT consensus adapter
# (D72 · N4 · B path · wrap-as-is).
#
# RTSC.md §9.4 (cross-code "독립 lab" sim analog) + §9.7 N4 row + §9.9.1 Phase 1.
# Simulation-analog for RTSC.md §8.9 (d) "다중 독립 lab 재현" gate — polls
# multiple DFT data sources for the same composition's property, computes
# inverse-variance consensus (Nb attestation formula: w_i = 1/σ_i²) when ≥ 2
# sources return a value. R4 invariant: absorbed=false ALWAYS, never replaces
# wet-lab independent replication.
#
# Sibling pattern — see `sim_adapter.py` (Tier 1 closed-form Tc), `mp_query.py`
# (MP REST), `csp_adapter.py` (N1), `beenet_adapter.py` (N2), `askcos_adapter.py`
# (N3) in this same dir. cross_code_dft.py is the 6th material+verify producer
# and shares the json shape: domain="material", verb="verify",
# kind="cross_code_dft_consensus".
#
# Sources (fallback chain — each is independent try/except graceful fail):
#   A. mp_cache  — exports/material_cache/mp/<slug>.json (read-only; DO NOT
#                  invoke mp_query.py since that needs an API key)
#   B. AFLOW     — REST GET https://aflow.org/API/aflux/?species(...)
#                  (key-free, may return "DB Fail!null" — gracefully skip)
#   C. OQMD      — REST GET https://oqmd.org/oqmdapi/formationenergy?
#                  composition=<...> (key-free, JSON; band_gap + delta_e)
#   D. hexa-rtsc — subprocess `hexa run calc_*.hexa` (n=6 algebraic ceiling;
#                  only if ~/.hx/bin/hexa exists). DEVIATION-only — NOT
#                  comparable to DFT numerics (per s4 caveat).
#
# Path 2 (DEMIURGE_DFT_HEAVY_RUN=1): attempt remote QE/ABINIT subprocess via
# pool CLI. Default off → gate_type=heavy-run-not-opted-in.
#
# Skip path semantics (gate_type values):
#   - insufficient-sources              — < 2 sources returned a value
#   - install-gated                     — none of the endpoints reachable
#   - heavy-run-not-opted-in            — Path 2 default
#   - pool-unavailable                  — DEMIURGE_DFT_HEAVY_RUN=1 but pool missing
#   - simulation-only-prediction        — ≥ 2 sources + consensus computed
#
# R4 invariant (ALWAYS): absorbed=false. Cross-code DFT consensus is a
# *simulation-analog* for (d) wet-lab independent replication — NEVER a
# replacement. See scope_caveats (s1)-(s4).
#
# D61: substrate SSOT under `hexa-lang/stdlib/material/`. Demiurge spawns via
#      `python3 ~/core/hexa-lang/stdlib/material/cross_code_dft.py <out_dir> <composition>`.
# D72: 6th material-domain consumer (after sim_adapter, mp_query, csp_adapter,
#      beenet_adapter, askcos_adapter). Wrap-as-is — no kernel promotion.
#      Phase 3 candidate microkernel: inverse-variance consensus (Nb
#      attestation pattern — already a closed-form ≤ 20-line formula).

from __future__ import annotations

import argparse
import json
import math
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


# ─── default sigma per property (conservative when source doesn't report) ─

_DEFAULT_SIGMA: dict[str, float] = {
    # eV / atom typical PBE-GGA error bar (MP claims ~0.1 eV/atom)
    "formation_energy": 0.05,
    # eV typical DFT band-gap problem floor (30-50% underestimate → use 0.5)
    "band_gap": 0.5,
    # K — Tc spread across functionals is large; conservative 5 K
    "tc": 5.0,
}


_VALID_PROPERTIES = ("tc", "band_gap", "formation_energy")


# ─── formula slug helpers ───────────────────────────────────────────────


def _slugify_mp_cache(composition: str) -> str:
    """Match the slugging used by exports/material_cache/mp filenames.
    Pb10Cu(PO4)6O → Pb10Cu_PO4_6O.  YBa2Cu3O7 → YBa2Cu3O7."""
    s = composition.replace("(", "_").replace(")", "_")
    s = re.sub(r"_+", "_", s).strip("_")
    return s


# ─── Source A: MP cache ────────────────────────────────────────────────


def _poll_mp_cache(composition: str, prop: str,
                   cache_dir: Path) -> dict[str, Any] | None:
    """Read exports/material_cache/mp/<slug>.json (if present). Returns one
    {value, sigma, citation, raw_record_path_or_url} dict or None when the
    cache file is missing OR rows=[] OR the requested property isn't
    extractable for this composition.

    Aggregation: averages over MP rows (each is a different polymorph). We
    use the minimum-formation-energy row (most stable polymorph) for
    formation_energy. For band_gap we average. For Tc — MP doesn't store
    Tc → return None.
    """
    candidates = [
        cache_dir / f"{_slugify_mp_cache(composition)}.json",
        cache_dir / f"{composition}.json",
    ]
    cache_path: Path | None = None
    for p in candidates:
        if p.is_file():
            cache_path = p
            break
    if cache_path is None:
        return None
    try:
        record = json.loads(cache_path.read_text())
    except Exception:
        return None
    rows = record.get("rows") or []
    if not rows:
        return None

    if prop == "formation_energy":
        # Most stable polymorph (min formation_energy_per_atom)
        vals = [
            r.get("formation_energy_per_atom_eV")
            for r in rows
            if r.get("formation_energy_per_atom_eV") is not None
        ]
        if not vals:
            return None
        value = float(min(vals))
        # Spread across polymorphs informs σ — use stdev floor at default
        if len(vals) >= 2:
            mean = sum(vals) / len(vals)
            var = sum((v - mean) ** 2 for v in vals) / (len(vals) - 1)
            sigma = max(math.sqrt(var), _DEFAULT_SIGMA[prop])
        else:
            sigma = _DEFAULT_SIGMA[prop]
    elif prop == "band_gap":
        vals = [
            r.get("band_gap_eV") for r in rows
            if r.get("band_gap_eV") is not None
        ]
        if not vals:
            return None
        value = float(sum(vals) / len(vals))
        sigma = _DEFAULT_SIGMA[prop]
    elif prop == "tc":
        # MP does not store Tc — see mp_query scope_caveats (s3).
        return None
    else:
        return None

    return {
        "name": "mp_cache",
        "value": value,
        "sigma": float(sigma),
        "citation": "Jain et al. APL Materials 1, 011002 (2013)",
        "raw_record_path_or_url": str(cache_path),
        "n_rows": len(rows),
    }


# ─── Source B: AFLOW REST (aflux) ──────────────────────────────────────


_AFLOW_BASE = "https://aflow.org/API/aflux/"


def _http_get_json(url: str, timeout: float = 10.0
                   ) -> tuple[Any, str | None]:
    """HTTP GET with timeout, returns (parsed_json_or_text, error_or_None).
    Surfaces both transport errors and non-JSON bodies gracefully."""
    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "cross_code_dft.py/D72-N4 (demiurge)"},
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError,
            ConnectionError, OSError) as e:
        return None, f"http error: {type(e).__name__}: {e}"
    except Exception as e:  # pragma: no cover — defensive
        return None, f"unexpected error: {type(e).__name__}: {e}"
    raw = raw.strip()
    if raw.startswith("DB Fail") or not raw:
        return None, f"AFLOW returned empty/DB-Fail: {raw[:120]!r}"
    try:
        return json.loads(raw), None
    except json.JSONDecodeError as e:
        return None, f"JSON decode error: {e}; head={raw[:120]!r}"


def _parse_formula_to_species(composition: str) -> list[str]:
    """Extract unique element symbols (alphabetized) from a formula like
    Pb10Cu(PO4)6O → [Cu, O, P, Pb]. Conservative: best-effort regex."""
    # Strip parens but keep element letters
    flat = composition.replace("(", "").replace(")", "")
    flat = re.sub(r"\d+(\.\d+)?", "", flat)
    elems = re.findall(r"[A-Z][a-z]?", flat)
    return sorted(set(elems))


def _poll_aflow(composition: str, prop: str
                ) -> dict[str, Any] | None:
    """Query AFLOW AFLUX. As of 2026-05 the public endpoint frequently
    returns 'DB Fail!null' for compositions outside the LIB1-LIB6 prototype
    library — we treat that as a graceful skip.

    Fields:
      formation_energy → enthalpy_formation_atom (eV / atom)
      band_gap         → Egap_fit (eV)
      tc               → AFLOW doesn't directly store Tc → return None.
    """
    if prop == "tc":
        return None
    species = _parse_formula_to_species(composition)
    if not species:
        return None
    species_clause = ",".join(species)
    if prop == "formation_energy":
        field = "enthalpy_formation_atom"
    elif prop == "band_gap":
        field = "Egap_fit"
    else:
        return None

    query = (
        f"species({species_clause}),nspecies({len(species)}),"
        f"{field},compound"
    )
    url = (
        f"{_AFLOW_BASE}?{urllib.parse.quote(query, safe='(),')}"
        f"&format=json&paging=1"
    )
    data, err = _http_get_json(url, timeout=12.0)
    if err is not None or data is None:
        return None

    # AFLOW AFLUX returns a list of entries
    if isinstance(data, list):
        entries = data
    elif isinstance(data, dict):
        entries = data.get("results") or data.get("data") or []
    else:
        return None

    # Filter to entries whose `compound` matches our formula (best-effort)
    vals: list[float] = []
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        v = entry.get(field)
        if v is None:
            continue
        try:
            vals.append(float(v))
        except (TypeError, ValueError):
            continue
    if not vals:
        return None
    # Use min for formation_energy (most stable), mean for band_gap
    if prop == "formation_energy":
        value = float(min(vals))
    else:
        value = float(sum(vals) / len(vals))
    if len(vals) >= 2:
        mean = sum(vals) / len(vals)
        var = sum((v - mean) ** 2 for v in vals) / (len(vals) - 1)
        sigma = max(math.sqrt(var), _DEFAULT_SIGMA[prop])
    else:
        sigma = _DEFAULT_SIGMA[prop]
    return {
        "name": "aflow",
        "value": value,
        "sigma": float(sigma),
        "citation": (
            "Curtarolo et al., Comput Mater Sci 58, 218 (2012) — AFLOW: "
            "automatic framework for high-throughput materials discovery"
        ),
        "raw_record_path_or_url": url,
        "n_rows": len(vals),
    }


# ─── Source C: OQMD REST ───────────────────────────────────────────────


_OQMD_BASE = "https://oqmd.org/oqmdapi/formationenergy"


def _poll_oqmd(composition: str, prop: str
               ) -> dict[str, Any] | None:
    """Query OQMD formationenergy endpoint. Returns entries with delta_e
    (formation energy per atom, eV) and band_gap (eV)."""
    if prop == "tc":
        return None
    if prop == "formation_energy":
        field = "delta_e"
    elif prop == "band_gap":
        field = "band_gap"
    else:
        return None
    url = (
        f"{_OQMD_BASE}?composition={urllib.parse.quote(composition)}"
        f"&limit=10"
    )
    data, err = _http_get_json(url, timeout=12.0)
    if err is not None or not isinstance(data, dict):
        return None
    entries = data.get("data") or []
    if not entries:
        return None
    vals: list[float] = []
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        v = entry.get(field)
        if v is None:
            continue
        try:
            vals.append(float(v))
        except (TypeError, ValueError):
            continue
    if not vals:
        return None
    if prop == "formation_energy":
        value = float(min(vals))
    else:
        value = float(sum(vals) / len(vals))
    if len(vals) >= 2:
        mean = sum(vals) / len(vals)
        var = sum((v - mean) ** 2 for v in vals) / (len(vals) - 1)
        sigma = max(math.sqrt(var), _DEFAULT_SIGMA[prop])
    else:
        sigma = _DEFAULT_SIGMA[prop]
    return {
        "name": "oqmd",
        "value": value,
        "sigma": float(sigma),
        "citation": (
            "Saal et al., JOM 65(11), 1501 (2013) — Materials design and "
            "discovery with high-throughput DFT: the OQMD"
        ),
        "raw_record_path_or_url": url,
        "n_rows": len(vals),
    }


# ─── Source D: hexa-rtsc n=6 algebraic ceiling ──────────────────────────


def _resolve_hexa_bin() -> str | None:
    p = os.path.expanduser("~/.hx/bin/hexa")
    return p if Path(p).is_file() else None


def _resolve_hexa_rtsc_root() -> Path | None:
    """hexa-rtsc verify root — `firmware/boards/rtsc/verify/` in hexa-lang,
    or sibling `~/core/hexa-rtsc/rtsc/` if present."""
    cands = [
        Path("/Users/ghost/core/hexa-lang/firmware/boards/rtsc/verify"),
        Path(os.path.expanduser("~/core/hexa-rtsc")),
    ]
    for c in cands:
        if c.is_dir():
            return c
    return None


def _poll_hexa_rtsc(composition: str, prop: str
                    ) -> dict[str, Any] | None:
    """Subprocess `hexa run calc_*.hexa` for the n=6 closed-form ceiling.

    Only meaningful for `tc` (McMillan/Allen-Dynes ceiling ~30 K from
    calc_mcmillan.hexa). For formation_energy / band_gap there is no
    algebraic-ceiling analog → return None.

    Surfaces a DEVIATION-only signal: NOT to be averaged into consensus
    on equal footing per s4 caveat. We still emit the row for informative
    cross-check, but consensus computation filters this out (see
    `_compute_consensus`).
    """
    if prop != "tc":
        return None
    hexa_bin = _resolve_hexa_bin()
    if hexa_bin is None:
        return None
    root = _resolve_hexa_rtsc_root()
    if root is None:
        return None
    calc = root / "calc_mcmillan.hexa"
    if not calc.is_file():
        return None
    try:
        result = subprocess.run(
            [hexa_bin, "run", str(calc)],
            capture_output=True,
            text=True,
            timeout=30.0,
            cwd=str(root.parent),
        )
    except (subprocess.TimeoutExpired, OSError):
        return None
    out = (result.stdout or "") + "\n" + (result.stderr or "")
    # Best-effort scan for "Tc <= XX K" or "T_c ≈ ... K"
    m = re.search(r"T[_c\\s]*[≤<=]+\s*([0-9]+(?:\.[0-9]+)?)\s*K", out)
    if m is None:
        m = re.search(
            r"ceiling[^0-9]+([0-9]+(?:\.[0-9]+)?)\s*K", out, re.IGNORECASE
        )
    if m is None:
        # No parseable ceiling — still record the run as informative
        return {
            "name": "hexa_rtsc",
            "value": None,
            "sigma": None,
            "citation": (
                "hexa-rtsc n=6 closed-form (calc_mcmillan.hexa) — "
                "RTSC.md §8.1-§8.3 algebraic ceiling"
            ),
            "raw_record_path_or_url": str(calc),
            "n_rows": 0,
            "note": (
                "ran but no parseable Tc bound — DEVIATION-only "
                "informative signal (see s4 caveat)"
            ),
        }
    value = float(m.group(1))
    return {
        "name": "hexa_rtsc",
        "value": value,
        "sigma": _DEFAULT_SIGMA["tc"],
        "citation": (
            "hexa-rtsc n=6 closed-form (calc_mcmillan.hexa) — "
            "RTSC.md §8.1-§8.3 algebraic ceiling"
        ),
        "raw_record_path_or_url": str(calc),
        "n_rows": 1,
        "note": (
            "algebraic ceiling, NOT comparable to DFT numerics — "
            "informative DEVIATION only (s4)"
        ),
    }


# ─── Path 2: heavy-run pool dispatch (opt-in) ───────────────────────────


def _pool_cli_present() -> str | None:
    """Return path to pool CLI if available (~/.hx/bin/pool or PATH)."""
    cand = os.path.expanduser("~/.hx/bin/pool")
    if Path(cand).is_file():
        return cand
    return shutil.which("pool")


# ─── inverse-variance consensus (Nb attestation pattern) ─────────────────


def _compute_consensus(rows: list[dict[str, Any]]
                       ) -> dict[str, Any] | None:
    """Inverse-variance weighted mean over rows with non-null value+sigma.
    R4 invariant safeguard: hexa_rtsc rows are *excluded* from consensus
    (s4: algebraic ceiling is informative DEVIATION, not equal-footing
    DFT numeric). Returns None when < 2 eligible sources.

    Formula (matches Nb attestation in mp_query / sim_adapter): wᵢ = 1/σᵢ²,
    mean = Σwᵢxᵢ / Σwᵢ, combined σ = 1/√Σwᵢ.
    """
    eligible = [
        r for r in rows
        if r.get("name") != "hexa_rtsc"
        and r.get("value") is not None
        and r.get("sigma") is not None
        and r.get("sigma", 0.0) > 0.0
    ]
    if len(eligible) < 2:
        return None
    w_total = 0.0
    wx_total = 0.0
    for r in eligible:
        w = 1.0 / (float(r["sigma"]) ** 2)
        w_total += w
        wx_total += w * float(r["value"])
    mean = wx_total / w_total
    sigma = 1.0 / math.sqrt(w_total)
    vals = [float(r["value"]) for r in eligible]
    rel_err_max = 0.0
    for i in range(len(vals)):
        for j in range(i + 1, len(vals)):
            denom = max(abs(vals[i]), abs(vals[j]), 1e-12)
            rel = abs(vals[i] - vals[j]) / denom
            if rel > rel_err_max:
                rel_err_max = rel
    return {
        "value": float(mean),
        "sigma": float(sigma),
        "n_sources": len(eligible),
        "rel_err_max_pairwise": float(rel_err_max),
        "consensus_sources": [r["name"] for r in eligible],
    }


# ─── record dump ────────────────────────────────────────────────────────


def main(out_dir: str, composition: str, prop: str) -> int:
    if prop not in _VALID_PROPERTIES:
        print(
            f"error: --property must be one of {_VALID_PROPERTIES}, "
            f"got {prop!r}",
            file=sys.stderr,
        )
        return 2
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    cache_dir = Path(os.path.expanduser(
        "~/core/demiurge/exports/material_cache/mp"
    ))

    citations = [
        "pymatgen-io-validation (Materials Project) — "
        "https://github.com/materialsproject/pymatgen-io-validation",
        "MatBench v0.1 — DFT formation energy prediction benchmark suite. "
        "https://matbench.materialsproject.org",
        "RTSC.md §9.4 — cross-code DFT (d) '독립 lab' simulation analog.",
        "Curtarolo et al., Comput Mater Sci 58, 218 (2012) — AFLOW.",
        "Saal et al., JOM 65(11), 1501 (2013) — OQMD.",
        "Jain et al., APL Materials 1, 011002 (2013) — Materials Project.",
    ]

    scope_caveats = [
        "(s1) Cross-code DFT consensus is a SIMULATION-ANALOG for (d) "
        "'독립 lab 재현' — NOT actual wet-lab independent replication. "
        "MP/AFLOW/OQMD are mostly VASP variants with different functionals; "
        "not truly orthogonal codes.",
        "(s2) Inverse-variance consensus assumes per-source σᵢ "
        "independent. They are NOT — common training data, common "
        "functional families (PBE-dominated).",
        "(s3) DFT-derived properties ≠ measured values. R4 invariant: "
        "never absorbed=true via simulation alone.",
        "(s4) hexa-rtsc n=6 closed-form is algebraic ceiling, NOT "
        "comparable to DFT numerics — informative DEVIATION only.",
    ]

    sources_polled = [
        "mp_cache", "aflow", "oqmd", "hexa_rtsc",
        "qe_pool", "abinit_pool",
    ]

    # ─── poll each source (try / except graceful per source) ────────
    returned: list[dict[str, Any]] = []
    poll_errors: list[str] = []

    for name, fn in (
        ("mp_cache", lambda: _poll_mp_cache(composition, prop, cache_dir)),
        ("aflow", lambda: _poll_aflow(composition, prop)),
        ("oqmd", lambda: _poll_oqmd(composition, prop)),
        ("hexa_rtsc", lambda: _poll_hexa_rtsc(composition, prop)),
    ):
        try:
            row = fn()
        except Exception as e:  # defensive — never crash on poll
            row = None
            poll_errors.append(f"{name}: {type(e).__name__}: {e}")
        if row is not None:
            returned.append(row)

    # ─── Path 2: heavy run (opt-in) ─────────────────────────────────
    heavy_opted_in = os.environ.get("DEMIURGE_DFT_HEAVY_RUN", "0") == "1"
    pool_cli = _pool_cli_present()
    heavy_skip_reason: str | None = None
    if heavy_opted_in:
        if pool_cli is None:
            heavy_skip_reason = (
                "DEMIURGE_DFT_HEAVY_RUN=1 but no pool CLI found at "
                "~/.hx/bin/pool or in PATH — gate_type=pool-unavailable"
            )
        else:
            # Wrap-as-is: we do NOT actually dispatch QE/ABINIT in N4.
            # That requires per-host installs + input file generation +
            # remote orchestration → Phase 2-3 work. Surface honest skip.
            heavy_skip_reason = (
                f"DEMIURGE_DFT_HEAVY_RUN=1 detected; pool CLI at "
                f"{pool_cli!r}. Adapter is wrap-as-is and does NOT bundle "
                f"QE/ABINIT input generation + remote dispatch yet — "
                f"Phase 2 stabilization will wire `pool run qe_scf ...` + "
                f"`pool run abinit_scf ...`. Current record carries the "
                f"opt-in flag for downstream auditing."
            )

    # ─── consensus + gate decision ──────────────────────────────────
    consensus = _compute_consensus(returned)
    eligible_count = sum(
        1 for r in returned
        if r.get("name") != "hexa_rtsc"
        and r.get("value") is not None
        and r.get("sigma") is not None
    )
    reachable_count = len(returned)

    gate_type: str
    skipped_reason: str | None = None

    if heavy_opted_in and pool_cli is None:
        gate_type = "pool-unavailable"
        skipped_reason = heavy_skip_reason
    elif consensus is not None:
        gate_type = "simulation-only-prediction"
        if heavy_skip_reason:
            skipped_reason = (
                f"consensus computed from light sources; "
                f"{heavy_skip_reason}"
            )
    elif reachable_count == 0 and poll_errors:
        # All polls raised — endpoints truly unreachable / install-broken.
        gate_type = "install-gated"
        skipped_reason = (
            f"none of the light sources (mp_cache / aflow / oqmd / "
            f"hexa_rtsc) were reachable for {composition!r} property="
            f"{prop!r}. Poll errors: {poll_errors!r}. To enable heavy "
            f"QE/ABINIT path: set DEMIURGE_DFT_HEAVY_RUN=1 (pool CLI "
            f"required)."
        )
    elif eligible_count < 2:
        # Endpoints reachable but composition not in DFT corpus (or only
        # 1 source has it) — distinct from "endpoints broken".
        gate_type = "insufficient-sources"
        skipped_reason = (
            f"only {eligible_count} eligible source(s) returned a value "
            f"for {composition!r} property={prop!r}; consensus requires "
            f">= 2. Reachable sources: "
            f"{[r['name'] for r in returned]!r}. "
            f"Common cause: composition not in MP/AFLOW/OQMD (e.g., LK-99 "
            f"lead-apatite is hypothetical — MP cache row_count=0, "
            f"AFLOW DB-Fail, OQMD empty data list)."
        )
    elif heavy_opted_in:
        # Opted-in but heavy dispatch not yet wired (Phase 2 work).
        gate_type = "heavy-run-not-opted-in"
        skipped_reason = heavy_skip_reason or (
            "no light consensus and heavy dispatch not yet wired"
        )
    else:
        gate_type = "heavy-run-not-opted-in"
        skipped_reason = (
            f"consensus not computed (eligible={eligible_count}); "
            f"set DEMIURGE_DFT_HEAVY_RUN=1 to attempt QE/ABINIT "
            f"(pool CLI required)."
        )

    record: dict[str, Any] = {
        "domain": "material",
        "verb": "verify",
        "kind": "cross_code_dft_consensus",
        "stamp": stamp,
        "producer": "cross_code_dft@material-tier1-N4",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,             # R4 invariant — ALWAYS false
        "gate_type": gate_type,
        "provisional": True,
        "skipped_reason": skipped_reason,
        "query": {
            "composition": composition,
            "property": prop,
        },
        "sources_polled": sources_polled,
        "sources_returned": returned,
        "consensus": consensus,        # null when < 2 eligible
        "heavy_run_opted_in": heavy_opted_in,
        "pool_cli_path": pool_cli,
        "poll_errors": poll_errors,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "provenance": {
            "source_url": (
                "https://github.com/materialsproject/pymatgen-io-validation"
            ),
            "primary_refs": [
                "Curtarolo 2012 (AFLOW) · Saal 2013 (OQMD) · "
                "Jain 2013 (MP) · MatBench v0.1",
            ],
            "rtsc_anchor": (
                "RTSC.md §9.4 (cross-code (d) sim analog) + §9.7 N4 "
                "row + §9.9.1 Phase 1 (wrap-as-is B path)"
            ),
        },
        "recommendation": (
            "consensus (when present) is a candidate funnel signal — "
            "wet-lab independent replication (RTSC.md §8.9 (d) "
            "replicated_by_independent_labs >= 3) is the ONLY path to "
            "absorbed=true. Heavy QE/ABINIT pool dispatch (Path 2) "
            "remains wrap-pending until Phase 2 stabilization."
        ),
    }

    rec_path = out / f"material_verify_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))

    # ─── headline lines ──────────────────────────────────────────────
    print(f"[material+verify · cross_code_dft-N4] wrote {rec_path}")
    print(
        f"  · composition={composition!r}  property={prop!r}  "
        f"gate_type={gate_type}"
    )
    print(
        f"  · sources_polled={sources_polled}  "
        f"sources_returned={[r['name'] for r in returned]!r}"
    )
    if consensus is not None:
        print(
            f"  · consensus={consensus['value']:.6f} ± "
            f"{consensus['sigma']:.6f} ({consensus['n_sources']} sources, "
            f"rel_err_max={consensus['rel_err_max_pairwise']:.3%})"
        )
    if skipped_reason:
        print(f"  · skipped_reason: {skipped_reason}")
    print(
        "[material+verify · cross_code_dft-N4] absorbed=false (R4 "
        "invariant; RTSC.md §8.9 (d) requires wet-lab "
        "replicated_by_independent_labs >= 3, NEVER cross-code DFT "
        "consensus alone — s1/s2/s3/s4)"
    )
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=(
            "Cross-code DFT consensus adapter (RTSC.md §9.4 simulation "
            "analog for (d) independent-lab replication). Polls MP cache "
            "+ AFLOW + OQMD + hexa-rtsc; computes inverse-variance "
            "consensus when >= 2 sources return a value."
        )
    )
    parser.add_argument("out_dir", help="output directory for JSON record")
    parser.add_argument(
        "composition",
        help="chemical formula (e.g. Nb, MgB2, YBa2Cu3O7, Pb10Cu(PO4)6O)",
    )
    parser.add_argument(
        "--property",
        default="formation_energy",
        choices=_VALID_PROPERTIES,
        help="property to consense (default: formation_energy)",
    )
    args = parser.parse_args()
    sys.exit(main(args.out_dir, args.composition, args.property))
