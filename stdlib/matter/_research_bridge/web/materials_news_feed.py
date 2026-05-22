#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
materials_news_feed.py — RSS/Atom industry news poll with verb-keyword tagging.

Status: PARTIAL (stdlib parsing FUNCTIONAL; feedparser optional for richer
extraction; live mode requires `--live` + network access).

Phase F (2026-05-13): the materials industry news arm of web deep research.
Polls RSS/Atom feeds, deduplicates by GUID, tags by hexa-matter verb keyword,
and emits a JSONL stream.

Target feeds (from `web/SOURCES.md`):
  - Materials Today RSS
  - Nature Materials feed
  - IEEE Spectrum materials tag
  - Semiconductor Industry Association news
  - Wood Magazine industry feed (mass timber updates)
  - etc.

apply n=6 lattice formulas to news content. Verb tagging is keyword-based,
deterministic, and never modifies the underlying claim.

OFFLINE-REPLAY: --selftest reads web/web_cache/sample_rss.xml (a synthetic
3-item RSS fixture) and validates parsing + verb tagging. No network call.

Sentinel: __HEXA_MATTER_MATERIALS_NEWS_FEED__ PASS / FAIL / PASS (SKIP mode)

License: MIT (hexa-matter Phase F).
"""

from __future__ import annotations
import argparse
import hashlib
import json
import os
import re
import sys
from typing import Dict, List
from xml.etree import ElementTree as ET


# Verb keyword index — mirrors arxiv_digest.py but expressed as substring set.
VERB_KEYWORDS: Dict[str, List[str]] = {
    "compound-semi":         ["sic", "gan", "wide-bandgap", "wide bandgap", "hemt"],
    "perovskite":            ["perovskite", "mapbi", "lk-99", "halide perovskite"],
    "mof":                   ["mof", "metal-organic framework", "direct air capture"],
    "superalloy":            ["inconel", "superalloy", "single-crystal turbine"],
    "magnetic-materials":    ["ndfeb", "smco", "ferrite", "permanent magnet"],
    "silicon":               ["polysilicon", "poly-si", "czochralski", "wafer"],
    "wood-cellulose":        ["mass timber", "clt", "nanocellulose"],
    "biodegradable-plastics":["polylactic", "pla", "biodegradable plastic"],
    "carbon":                ["carbon nanotube", "diamond film", "graphene"],
    "2d-materials":          ["mxene", "mos2", "hbn", "phosphorene"],
}

# Speculative-claim flags (same as arxiv_digest.py)
UNPROVEN_FLAGS = [
    "lk-99", "room-temperature superconduct", "room temperature superconduct",
    "ambient metallic hydrogen", "metallic hydrogen ambient",
    "magic-mof", "$100/t co2", "25-year operational lifetime",
    "infinite recycle", "100% recyclable",
]


def _have_feedparser() -> bool:
    try:
        import feedparser  # noqa: F401
        return True
    except ImportError:
        return False


def parse_rss_stdlib(xml_text: str) -> List[dict]:
    """Stdlib RSS 2.0 parser. Returns list of items with title/link/desc/guid/pubdate."""
    root = ET.fromstring(xml_text)
    items: List[dict] = []
    for item in root.iter("item"):
        title = (item.findtext("title") or "").strip()
        link = (item.findtext("link") or "").strip()
        desc = (item.findtext("description") or "").strip()
        guid = (item.findtext("guid") or "").strip()
        pub = (item.findtext("pubDate") or "").strip()
        items.append({
            "title": title, "link": link, "description": desc,
            "guid": guid, "pubDate": pub,
        })
    return items


def parse_rss_feedparser(xml_text: str) -> List[dict]:
    """feedparser RSS/Atom parser. Returns same shape as stdlib version."""
    import feedparser
    feed = feedparser.parse(xml_text)
    items = []
    for e in feed.entries:
        items.append({
            "title":       getattr(e, "title", ""),
            "link":        getattr(e, "link", ""),
            "description": getattr(e, "description", getattr(e, "summary", "")),
            "guid":        getattr(e, "id", getattr(e, "guid", "")),
            "pubDate":     getattr(e, "published", getattr(e, "updated", "")),
        })
    return items


def tag_item(item: dict) -> dict:
    """Add verbs[] and unproven_flags[] to an item based on title+description."""
    haystack = (item.get("title", "") + " " + item.get("description", "")).lower()
    haystack = re.sub(r"\s+", " ", haystack)
    verbs = []
    for v, kws in VERB_KEYWORDS.items():
        for kw in kws:
            if kw in haystack:
                verbs.append(v)
                break
    flags = []
    for flag in UNPROVEN_FLAGS:
        if flag in haystack:
            flags.append(flag)
    return {
        **item,
        "verbs":          sorted(set(verbs)),
        "unproven_flags": flags,
    }


def deduplicate(items: List[dict]) -> List[dict]:
    """Dedup by guid, fall back to (link or title) when guid empty."""
    seen = set()
    out = []
    for it in items:
        key = it.get("guid") or it.get("link") or it.get("title", "")
        if not key:
            # Hash full record as last resort
            h = hashlib.md5(json.dumps(it, sort_keys=True).encode("utf-8")).hexdigest()
            key = h
        if key in seen:
            continue
        seen.add(key)
        out.append(it)
    return out


def _fixture_path() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(here, "web_cache", "sample_rss.xml")


def _selftest() -> int:
    fixture = _fixture_path()
    if not os.path.isfile(fixture):
        print(f"  FAIL: fixture missing: {fixture}")
        print("__HEXA_MATTER_MATERIALS_NEWS_FEED__ FAIL  (fixture missing)")
        return 1
    with open(fixture, encoding="utf-8") as f:
        xml_text = f.read()
    items = parse_rss_stdlib(xml_text)
    if len(items) != 3:
        print(f"  FAIL: expected 3 items, got {len(items)}")
        print("__HEXA_MATTER_MATERIALS_NEWS_FEED__ FAIL  (item count)")
        return 1

    # Tag and check verbs
    tagged = [tag_item(it) for it in items]
    all_verbs = set()
    for t in tagged:
        all_verbs.update(t["verbs"])
    expected = {"compound-semi", "perovskite", "mof"}
    missing = expected - all_verbs
    if missing:
        print(f"  FAIL: expected verbs missing: {sorted(missing)}; got: {sorted(all_verbs)}")
        print("__HEXA_MATTER_MATERIALS_NEWS_FEED__ FAIL  (verb tag)")
        return 1

    # UNPROVEN flag must trip on at least one item (perovskite 25-yr OR MOF $100/t)
    has_unproven = any(t["unproven_flags"] for t in tagged)
    if not has_unproven:
        print(f"  FAIL: no UNPROVEN flag triggered (expected on perovskite or mof item)")
        print("__HEXA_MATTER_MATERIALS_NEWS_FEED__ FAIL  (unproven untagged)")
        return 1

    # Dedup smoke: doubling input must collapse back to 3
    doubled = items + items
    deduped = deduplicate(doubled)
    if len(deduped) != 3:
        print(f"  FAIL: dedup failed: doubled→{len(doubled)} deduped→{len(deduped)} (expected 3)")
        print("__HEXA_MATTER_MATERIALS_NEWS_FEED__ FAIL  (dedup)")
        return 1

    for t in tagged:
        flag = " [UNPROVEN: " + ",".join(t["unproven_flags"]) + "]" if t["unproven_flags"] else ""
        print(f"  PASS: verbs={t['verbs']}  guid={t['guid']}{flag}")
    print(f"  PASS: dedup 6→3")

    if _have_feedparser():
        items2 = parse_rss_feedparser(xml_text)
        print(f"  PASS: feedparser parse → {len(items2)} entries")
    else:
        print("  INFO: feedparser not installed; richer parser SKIPPED (stdlib parse covers selftest)")

    print("__HEXA_MATTER_MATERIALS_NEWS_FEED__ PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    p.add_argument("--live", action="store_true",
                   help="LIVE mode: poll RSS URLs (requires network)")
    p.add_argument("--feed", default=None, help="RSS/Atom feed URL")
    p.add_argument("--in", dest="infile", default=None,
                   help="parse a locally-cached feed XML file instead of fetching")
    args = p.parse_args()

    if args.selftest:
        return _selftest()

    xml_text = None
    if args.live and args.feed:
        from urllib.request import urlopen, Request
        req = Request(args.feed,
                      headers={"User-Agent": "hexa-matter-research-bridge/0.1 (Phase F)"})
        with urlopen(req, timeout=30) as resp:
            xml_text = resp.read().decode("utf-8", errors="replace")
    elif args.infile:
        with open(args.infile, encoding="utf-8") as f:
            xml_text = f.read()

    if xml_text is None:
        p.print_help()
        return 0

    items = parse_rss_feedparser(xml_text) if _have_feedparser() else parse_rss_stdlib(xml_text)
    items = deduplicate(items)
    for t in (tag_item(it) for it in items):
        print(json.dumps(t, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
