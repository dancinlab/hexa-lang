#!/usr/bin/env python3
# mp_batch_ingest.py — MP.md Phase 1.2 batch-ingest orchestrator (D72 sibling).
#
# Wraps mp_query.py over a hard-coded RTSC.md §8.2 8-family candidate matrix.
# For each compound:
#   - skip if cache <slug>.json already exists (cache-hit semantics)
#   - else: spawn `mp_query.py <tmp_out> <formula>` in a subprocess and read
#           back the freshly-written record file
#   - normalize into a compact cache row and write to:
#           ~/core/demiurge/exports/material_cache/mp/<formula_slug>.json
#   - prepend CC-BY-4.0 attribution header (MP license requirement)
#   - rate-limit 0.5s between API calls (courtesy; MP allows ~50/s)
#
# Honest g3:
#   - absorbed=false carried through from mp_query.py (DFT ≠ measurement)
#   - gate_type=external-api preserved on hit, api-key-missing on skip
#   - API key resolved via `secret get flat.mp_api_key` (never embedded)
#   - LK-99 family + heavy hydrides are expected misses — recorded as
#     row_count=0 entries, not as failures
#
# RTSC.md §8.2 anchor + MP.md Phase 1.2.

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


# ─── candidate matrix (RTSC.md §8.2 — 8 family) ─────────────────────────


CANDIDATE_MATRIX: dict[str, list[str]] = {
    "lts": [
        "Nb", "NbTi", "Nb3Sn", "Nb3Ge", "V3Si", "V3Ga", "Nb3Al",
    ],
    "mgb2": [
        "MgB2",
    ],
    "fesc": [
        "LaFeAsO", "BaFe2As2", "FeSe", "FeTe", "LiFeAs", "SrFe2As2",
        "NaFeAs", "BaKFe2As2",
    ],
    "hts_cuprate": [
        "YBa2Cu3O7", "Bi2Sr2CaCu2O8", "Bi2Sr2Ca2Cu3O10",
        "HgBa2Ca2Cu3O8", "Tl2Ba2CaCu2O8", "La2CuO4", "Nd2CuO4",
    ],
    "heavy_hydride": [
        "H3S", "LaH10", "CaH6", "YH6",
    ],
    "tbg": [
        # TBG itself is configuration, not stoichiometry. Carbon allotropes
        # only — no clean MP entry for twisted bilayer.
        "C",  # graphite/graphene (MP has multiple C polytypes)
    ],
    "lk99_family": [
        "Pb10(PO4)6O", "Pb10Cu(PO4)6O", "Pb9Cu(PO4)6O",
    ],
    # hexa-rtsc n=6: closed-form only per RTSC.md §8.2 — intentionally skipped.
}


MP_QUERY_SCRIPT = Path(__file__).parent / "mp_query.py"
CACHE_DIR = Path.home() / "core/demiurge/exports/material_cache/mp"
RATE_LIMIT_S = 0.5


ATTRIBUTION = (
    "Cached from Materials Project (materialsproject.org). "
    "Licensed CC-BY-4.0. "
    "Cite: Jain et al. APL Materials 1, 011002 (2013)."
)


# ─── helpers ─────────────────────────────────────────────────────────────


def _slugify(formula: str) -> str:
    """Map a pretty-formula to a filesystem-safe slug.

    Examples:
      Pb10(PO4)6O   → Pb10_PO4_6O
      Bi2Sr2CaCu2O8 → Bi2Sr2CaCu2O8
      MgB2          → MgB2
    """
    s = formula.replace("(", "_").replace(")", "_")
    s = re.sub(r"[^A-Za-z0-9_-]", "_", s)
    s = re.sub(r"_+", "_", s).strip("_")
    return s


def _resolve_api_key() -> str | None:
    """Fetch MP API key via `secret get flat.mp_api_key`. Returns None on
    failure (so the script can still emit honest-skip cache rows)."""
    try:
        out = subprocess.run(
            ["secret", "get", "flat.mp_api_key"],
            capture_output=True, text=True, timeout=10,
        )
        if out.returncode != 0:
            return None
        key = out.stdout.strip()
        return key if key else None
    except Exception:
        return None


def _ingest_one(formula: str, family: str, api_key: str) -> dict:
    """Spawn mp_query.py for one formula, read the produced record, and
    return a compact cache row (with CC-BY-4.0 attribution + family tag).
    Caller is responsible for writing it to disk."""
    with tempfile.TemporaryDirectory(prefix="mp_batch_") as tmp:
        env = os.environ.copy()
        env["MP_API_KEY_NEW"] = api_key  # 32-char new API
        env["MP_API_KEY"] = api_key      # also set legacy for robustness
        try:
            proc = subprocess.run(
                ["python3", str(MP_QUERY_SCRIPT), tmp, formula],
                capture_output=True, text=True, timeout=60, env=env,
            )
        except subprocess.TimeoutExpired:
            return {
                "_attribution": ATTRIBUTION,
                "_batch_family": family,
                "_batch_formula": formula,
                "_batch_status": "timeout",
                "_batch_error": "mp_query.py subprocess > 60s timeout",
                "row_count": 0,
                "rows": [],
                "absorbed": False,
                "gate_type": "external-api",
            }

        # Locate the freshly-written material_query_*.json
        files = sorted(Path(tmp).glob("material_query_*.json"))
        if not files:
            return {
                "_attribution": ATTRIBUTION,
                "_batch_family": family,
                "_batch_formula": formula,
                "_batch_status": "no_record_written",
                "_batch_error": (proc.stderr or "").strip()[:500],
                "row_count": 0,
                "rows": [],
                "absorbed": False,
                "gate_type": "external-api",
            }
        rec = json.loads(files[-1].read_text())

    # Inject attribution + batch metadata at the top of the cached row.
    cache_row = {
        "_attribution": ATTRIBUTION,
        "_batch_family": family,
        "_batch_formula": formula,
        "_batch_status": "hit" if rec.get("row_count", 0) > 0 else "miss",
    }
    cache_row.update(rec)
    return cache_row


# ─── main batch ──────────────────────────────────────────────────────────


def main() -> int:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

    api_key = _resolve_api_key()
    if api_key is None:
        print(
            "[mp_batch_ingest] FATAL: `secret get flat.mp_api_key` returned "
            "empty. Phase 1.2 requires the key to bootstrap the cache. "
            "Set the secret or run later when key is available.",
            file=sys.stderr,
        )
        return 1

    print(f"[mp_batch_ingest] cache_dir={CACHE_DIR}")
    print(f"[mp_batch_ingest] families={list(CANDIDATE_MATRIX.keys())}")

    t0 = time.time()
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    per_family_stats: dict[str, dict] = {}
    total_queried = 0
    total_hit = 0
    total_miss = 0
    api_calls_made = 0  # tracks subprocess spawns (cache-hit skips don't count)
    hits: list[tuple[str, str, str]] = []   # (formula, family, mp_id)
    misses: list[tuple[str, str, str]] = [] # (formula, family, reason)

    for family, compounds in CANDIDATE_MATRIX.items():
        stats = {"queried": 0, "hit": 0, "miss": 0, "cached_skip": 0}
        for formula in compounds:
            stats["queried"] += 1
            total_queried += 1
            slug = _slugify(formula)
            cache_path = CACHE_DIR / f"{slug}.json"
            if cache_path.exists():
                print(
                    f"[mp_batch_ingest] {family}/{formula} → cache hit "
                    f"({cache_path.name}); skip API call"
                )
                stats["cached_skip"] += 1
                # Re-count toward family hit/miss from the existing cache
                try:
                    existing = json.loads(cache_path.read_text())
                    if existing.get("row_count", 0) > 0:
                        stats["hit"] += 1
                        total_hit += 1
                        first_mp_id = (
                            existing.get("rows", [{}])[0].get("mp_id") or "?"
                        )
                        hits.append((formula, family, first_mp_id))
                    else:
                        stats["miss"] += 1
                        total_miss += 1
                        misses.append(
                            (formula, family,
                             existing.get("skipped_reason")
                             or existing.get("_batch_error")
                             or "row_count=0")
                        )
                except Exception as e:
                    stats["miss"] += 1
                    total_miss += 1
                    misses.append((formula, family, f"cache parse error: {e}"))
                continue

            # Cache miss → fetch
            print(
                f"[mp_batch_ingest] {family}/{formula} → fetching "
                f"(api_call #{api_calls_made + 1}) ..."
            )
            row = _ingest_one(formula, family, api_key)
            api_calls_made += 1
            cache_path.write_text(json.dumps(row, indent=2))
            if row.get("row_count", 0) > 0:
                stats["hit"] += 1
                total_hit += 1
                first_mp_id = (
                    row.get("rows", [{}])[0].get("mp_id") or "?"
                )
                hits.append((formula, family, first_mp_id))
                print(f"  → HIT mp_id={first_mp_id}  row_count={row['row_count']}")
            else:
                stats["miss"] += 1
                total_miss += 1
                reason = (
                    row.get("skipped_reason")
                    or row.get("_batch_error")
                    or "row_count=0 (no MP entry for this formula)"
                )
                misses.append((formula, family, reason))
                print(f"  → MISS  reason={reason[:120]}")
            time.sleep(RATE_LIMIT_S)
        per_family_stats[family] = stats

    duration_s = time.time() - t0

    summary = {
        "batch_stamp": stamp,
        "total_queried": total_queried,
        "total_hit": total_hit,
        "total_miss": total_miss,
        "api_calls_made": api_calls_made,
        "cached_skips": total_queried - api_calls_made,
        "per_family_stats": per_family_stats,
        "duration_s": round(duration_s, 2),
        "license": "CC-BY-4.0",
        "attribution": ATTRIBUTION,
        "rtsc_anchor": "RTSC.md §8.2 (8 family matrix) + MP.md Phase 1.2",
        "absorbed": False,
        "gate_type": "external-api",
        "provisional": True,
        "top_hits_sample": [
            {"formula": f, "family": fam, "mp_id": mid}
            for f, fam, mid in hits[:5]
        ],
        "top_misses_sample": [
            {"formula": f, "family": fam, "reason": reason[:160]}
            for f, fam, reason in misses[:5]
        ],
    }

    summary_path = CACHE_DIR / "_batch_summary.json"
    summary_path.write_text(json.dumps(summary, indent=2))

    print()
    print(f"[mp_batch_ingest] summary → {summary_path}")
    print(
        f"  total_queried={total_queried}  hit={total_hit}  "
        f"miss={total_miss}  api_calls={api_calls_made}  "
        f"duration={duration_s:.1f}s"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
