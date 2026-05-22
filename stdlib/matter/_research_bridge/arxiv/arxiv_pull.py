#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
arxiv_pull.py — arxiv API pull for cond-mat.mtrl-sci and related categories.

Status: FUNCTIONAL (stdlib only). Live mode requires --live + network access.
Selftest mode is offline-replay against bundled fixture XML.

Phase F (2026-05-13): arxiv deep-research ingestion layer.

What it does:
  - LIVE mode (`--live`): hit http://export.arxiv.org/api/query with a search
    query, parse Atom feed, write one JSON line per paper to stdout. Respects
    arxiv's 3-second backoff requirement (Atom-feed rate limit).
  - SELFTEST mode (`--selftest`): replay from arxiv_cache/sample_response.xml
    (a 3-paper synthetic fixture) and validate the parser produces 3 records.

lattice formulas to paper claims. It does not lattice-fit author counts,
publication dates, or category lists.

Sentinel: __HEXA_MATTER_ARXIV_PULL__ PASS / FAIL / PASS (SKIP mode)

License: MIT (hexa-matter Phase F).
"""

from __future__ import annotations
import argparse
import hashlib
import json
import os
import re
import sys
import time
from typing import Iterable, List, Optional
from xml.etree import ElementTree as ET


ARXIV_API = "http://export.arxiv.org/api/query"
ATOM_NS = "{http://www.w3.org/2005/Atom}"

# arxiv categories of interest for hexa-matter (LATTICE_POLICY-compliant subset)
DEFAULT_CATEGORIES = [
    "cond-mat.mtrl-sci",   # primary — materials science
    "cond-mat.supr-con",   # superconductivity (LK-99 watch)
    "cond-mat.dis-nn",     # disorder + non-equilibrium
    "cond-mat.str-el",     # strongly-correlated electrons
    "cond-mat.soft",       # soft matter / polymers
    "cond-mat.mes-hall",   # mesoscale + nanoscale (2D materials, GaN HEMT)
]

# Min 3-second backoff per arxiv API ToS
ARXIV_BACKOFF_SEC = 3.0


def parse_atom_feed(xml_text: str) -> List[dict]:
    """Parse arxiv Atom XML → list of paper records.

    Each record: {arxiv_id, title, authors, abstract, categories, published, md5}
    """
    root = ET.fromstring(xml_text)
    records: List[dict] = []
    for entry in root.iter(f"{ATOM_NS}entry"):
        raw_id = (entry.findtext(f"{ATOM_NS}id") or "").strip()
        # arxiv id is the tail; strip http://arxiv.org/abs/ prefix
        m = re.search(r"abs/([0-9.v]+)", raw_id)
        arxiv_id = m.group(1) if m else raw_id

        title = (entry.findtext(f"{ATOM_NS}title") or "").strip()
        # Collapse internal whitespace
        title = re.sub(r"\s+", " ", title)

        summary = (entry.findtext(f"{ATOM_NS}summary") or "").strip()
        summary = re.sub(r"\s+", " ", summary)

        published = (entry.findtext(f"{ATOM_NS}published") or "").strip()

        authors = []
        for author in entry.iter(f"{ATOM_NS}author"):
            name = author.findtext(f"{ATOM_NS}name")
            if name:
                authors.append(name.strip())

        categories = []
        for cat in entry.iter(f"{ATOM_NS}category"):
            term = cat.attrib.get("term")
            if term:
                categories.append(term)

        # md5 stamp the raw arxiv id + title for cache identity
        h = hashlib.md5()
        h.update(arxiv_id.encode("utf-8"))
        h.update(b"|")
        h.update(title.encode("utf-8"))
        md5 = h.hexdigest()

        records.append({
            "arxiv_id":   arxiv_id,
            "title":      title,
            "authors":    authors,
            "abstract":   summary,
            "categories": categories,
            "published":  published,
            "md5":        md5,
        })
    return records


def pull_live(query: str, max_results: int = 25) -> str:
    """LIVE arxiv API call. Returns raw Atom XML text. Honors 3-sec backoff.

    NOT invoked during --selftest. Requires `--live`.
    """
    from urllib.parse import urlencode
    from urllib.request import urlopen, Request

    params = {
        "search_query": query,
        "start":        "0",
        "max_results":  str(max_results),
        "sortBy":       "submittedDate",
        "sortOrder":    "descending",
    }
    url = f"{ARXIV_API}?{urlencode(params)}"
    req = Request(url, headers={"User-Agent": "hexa-matter-research-bridge/0.1 (Phase F)"})
    # Honor 3-second backoff before the request fires
    time.sleep(ARXIV_BACKOFF_SEC)
    with urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8", errors="replace")


def categories_query(categories: Iterable[str]) -> str:
    """Build OR-joined cat: query string."""
    return "+OR+".join(f"cat:{c}" for c in categories)


def write_jsonl(records: List[dict], path: Optional[str]) -> None:
    """Write one JSON object per line. None = stdout."""
    fh = sys.stdout if path is None else open(path, "w", encoding="utf-8")
    try:
        for r in records:
            fh.write(json.dumps(r, ensure_ascii=False, sort_keys=True))
            fh.write("\n")
    finally:
        if path is not None:
            fh.close()


def _fixture_path() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(here, "arxiv_cache", "sample_response.xml")


def _selftest() -> int:
    fixture = _fixture_path()
    if not os.path.isfile(fixture):
        print(f"  FAIL: fixture missing: {fixture}")
        print("__HEXA_MATTER_ARXIV_PULL__ FAIL  (fixture missing)")
        return 1
    with open(fixture, encoding="utf-8") as f:
        xml_text = f.read()
    records = parse_atom_feed(xml_text)
    if len(records) != 3:
        print(f"  FAIL: expected 3 records, got {len(records)}")
        print("__HEXA_MATTER_ARXIV_PULL__ FAIL  (record count)")
        return 1
    # Field presence check on first record
    r0 = records[0]
    required = {"arxiv_id", "title", "authors", "abstract", "categories", "published", "md5"}
    missing = required - set(r0.keys())
    if missing:
        print(f"  FAIL: required fields missing from record: {missing}")
        print("__HEXA_MATTER_ARXIV_PULL__ FAIL  (schema)")
        return 1
    # md5 must be 32-char hex
    if not (isinstance(r0["md5"], str) and len(r0["md5"]) == 32 and all(c in "0123456789abcdef" for c in r0["md5"])):
        print(f"  FAIL: md5 not 32-char hex: {r0['md5']!r}")
        print("__HEXA_MATTER_ARXIV_PULL__ FAIL  (md5 form)")
        return 1
    # Determinism: re-parse same XML, md5 must be identical
    again = parse_atom_feed(xml_text)
    if again[0]["md5"] != r0["md5"]:
        print(f"  FAIL: md5 not deterministic")
        print("__HEXA_MATTER_ARXIV_PULL__ FAIL  (non-deterministic)")
        return 1
    for r in records:
        print(f"  PASS: {r['arxiv_id']}  md5={r['md5'][:10]}…  cats={','.join(r['categories'][:2])}")
    print("__HEXA_MATTER_ARXIV_PULL__ PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true", help="offline-replay selftest")
    p.add_argument("--live", action="store_true",
                   help="LIVE mode: hit arxiv API (requires network)")
    p.add_argument("--query", default=None,
                   help="custom search_query (default: cond-mat.mtrl-sci OR ...)")
    p.add_argument("--max", type=int, default=25, help="max_results in live mode")
    p.add_argument("--out", default=None, help="output JSONL path (default: stdout)")
    args = p.parse_args()

    if args.selftest:
        return _selftest()

    if args.live:
        query = args.query or categories_query(DEFAULT_CATEGORIES)
        xml_text = pull_live(query, max_results=args.max)
        records = parse_atom_feed(xml_text)
        write_jsonl(records, args.out)
        return 0

    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
