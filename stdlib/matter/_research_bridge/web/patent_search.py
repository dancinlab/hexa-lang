#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
patent_search.py — USPTO PatFT / AppFT / EPO Espacenet open patent search.

Status: PARTIAL (stdlib JSON parsing FUNCTIONAL; live mode requires `--live` +
network access).

Phase F (2026-05-13): the patent-deep-research arm. Issues queries against
the USPTO PatFT (granted) / AppFT (application) public endpoints OR the EPO
Espacenet public API, parses the result list, and emits a JSONL stream with
patent_no / title / assignee / filing_date / abstract.

apply n=6 lattice formulas to patent content. It does not arithmetic-verify
patent claims. The patent abstract is exactly what the patentee wrote; readers
must apply UNPROVEN judgement based on whether the claim has been reproduced
in peer-reviewed work.

OFFLINE-REPLAY: --selftest reads web/web_cache/sample_patent.json (a synthetic
3-record fixture) and validates parsing + verb-hint tagging. No network call.

Sentinel: __HEXA_MATTER_PATENT_SEARCH__ PASS / FAIL / PASS (SKIP mode)

License: MIT (hexa-matter Phase F).
"""

from __future__ import annotations
import argparse
import json
import os
import re
import sys
from typing import Dict, List


# Verb keyword index for patent verb-hint refinement
VERB_KEYWORDS: Dict[str, List[str]] = {
    "perovskite":            ["perovskite", "mapbi", "abx3", "halide perovskite"],
    "mof":                   ["metal-organic framework", "mof ", "direct air capture"],
    "superalloy":            ["superalloy", "single-crystal turbine", "inconel", "bridgman"],
    "compound-semi":         ["sic wafer", "gan-on-sic", "4h-sic", "hemt"],
    "silicon":               ["polysilicon", "czochralski", "float-zone"],
    "magnetic-materials":    ["ndfeb", "smco", "permanent magnet"],
    "2d-materials":          ["graphene", "mos2", "hbn", "mxene"],
    "carbon":                ["carbon nanotube", "diamond film", "cvd diamond"],
    "biodegradable-plastics":["polylactic", "biodegradable polymer"],
    "wood-cellulose":        ["mass timber", "clt panel", "nanocellulose"],
}

UNPROVEN_FLAGS = [
    "25-year lifetime", "25-year operational", "magic-mof", "$100/t co2",
    "room-temperature superconduct", "ambient metallic hydrogen",
    "infinite recycle", "100% recyclable",
]


def parse_patent_jsonish(blob: dict) -> List[dict]:
    """Parse a JSON blob (USPTO PatFT-style or our internal fixture shape) into records.

    Required fields per result: patent_no, title, assignee, filing_date, abstract.
    Optional: grant_date, verb_hint.
    """
    results = blob.get("results", [])
    out: List[dict] = []
    for r in results:
        rec = {
            "patent_no":   r.get("patent_no", ""),
            "title":       r.get("title", ""),
            "assignee":    r.get("assignee", ""),
            "filing_date": r.get("filing_date", ""),
            "grant_date":  r.get("grant_date", ""),
            "abstract":    r.get("abstract", ""),
        }
        # Apply our own verb tagging (don't trust patentee's verb_hint blindly)
        haystack = re.sub(r"\s+", " ",
                          (rec["title"] + " " + rec["abstract"]).lower())
        verbs = []
        for v, kws in VERB_KEYWORDS.items():
            for kw in kws:
                if kw in haystack:
                    verbs.append(v)
                    break
        rec["verbs"] = sorted(set(verbs))
        # UNPROVEN flag preservation
        flags = [f for f in UNPROVEN_FLAGS if f in haystack]
        rec["unproven_flags"] = flags
        out.append(rec)
    return out


def query_live(endpoint: str, query: str) -> dict:
    """LIVE patent search. NOT invoked in --selftest. Implementation depends on
    endpoint; this is a thin wrapper that returns the parsed JSON response."""
    from urllib.parse import urlencode
    from urllib.request import urlopen, Request
    url = f"{endpoint}?{urlencode({'q': query})}"
    req = Request(url, headers={"User-Agent": "hexa-matter-research-bridge/0.1 (Phase F)"})
    with urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8", errors="replace"))


def _fixture_path() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(here, "web_cache", "sample_patent.json")


def _selftest() -> int:
    fixture = _fixture_path()
    if not os.path.isfile(fixture):
        print(f"  FAIL: fixture missing: {fixture}")
        print("__HEXA_MATTER_PATENT_SEARCH__ FAIL  (fixture missing)")
        return 1
    with open(fixture, encoding="utf-8") as f:
        blob = json.load(f)
    recs = parse_patent_jsonish(blob)
    if len(recs) != 3:
        print(f"  FAIL: expected 3 patent records, got {len(recs)}")
        print("__HEXA_MATTER_PATENT_SEARCH__ FAIL  (record count)")
        return 1

    # Verbs must include perovskite, mof, superalloy
    all_verbs = set()
    for r in recs:
        all_verbs.update(r["verbs"])
    expected = {"perovskite", "mof", "superalloy"}
    missing = expected - all_verbs
    if missing:
        print(f"  FAIL: expected verbs missing: {sorted(missing)}; got: {sorted(all_verbs)}")
        print("__HEXA_MATTER_PATENT_SEARCH__ FAIL  (verbs)")
        return 1

    # UNPROVEN flag must trip on at least one record (perovskite 25-yr or mof $100/t)
    has_unproven = any(r["unproven_flags"] for r in recs)
    if not has_unproven:
        print(f"  FAIL: no UNPROVEN flag triggered on fixture patents")
        print("__HEXA_MATTER_PATENT_SEARCH__ FAIL  (unproven untagged)")
        return 1

    for r in recs:
        flag = " [UNPROVEN: " + ",".join(r["unproven_flags"]) + "]" if r["unproven_flags"] else ""
        print(f"  PASS: {r['patent_no']}  verbs={r['verbs']}  assignee={r['assignee']}{flag}")
    print("__HEXA_MATTER_PATENT_SEARCH__ PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    p.add_argument("--live", action="store_true",
                   help="LIVE mode: hit USPTO/EPO endpoint")
    p.add_argument("--endpoint", default=None,
                   help="USPTO/EPO public-API endpoint (live mode)")
    p.add_argument("--query", default=None, help="search query (live mode)")
    p.add_argument("--in", dest="infile", default=None,
                   help="parse a locally-cached JSON file instead of fetching")
    args = p.parse_args()

    if args.selftest:
        return _selftest()

    if args.live and args.endpoint and args.query:
        blob = query_live(args.endpoint, args.query)
    elif args.infile:
        with open(args.infile, encoding="utf-8") as f:
            blob = json.load(f)
    else:
        p.print_help()
        return 0

    for r in parse_patent_jsonish(blob):
        print(json.dumps(r, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
