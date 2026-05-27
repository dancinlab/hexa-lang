#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
arxiv_digest.py — verb-keyword tagging + per-verb digest for arxiv records.

Status: FUNCTIONAL (stdlib only).

Phase F (2026-05-13): consumes JSONL produced by arxiv_pull.py and groups
records by which hexa-matter verb each paper most likely informs.

Verb-keyword index (subset; covers 29 verbs):
  silicon          — silicon, poly-Si, polysilicon, Czochralski, FZ refining, dopant
  compound-semi    — GaN, SiC, GaAs, InP, HEMT, wide-bandgap, MOCVD
  perovskite       — perovskite, MAPbI3, ABX3, halide perovskite, oxide perovskite
  2d-materials     — 2D, graphene, MoS2, hBN, phosphorene, MXene, TMD
  magnetic-mat.    — NdFeB, SmCo, Curie, ferrite, BHmax, Metglas, Finemet
  mof              — MOF, metal-organic framework, HKUST, ZIF-8, UiO-66
  superalloy       — Inconel, single-crystal, CMSX, turbine blade, superalloy
  carbon           — CNT, carbon nanotube, diamond, fullerene, glassy carbon, pyrolytic
  …

It performs simple keyword tagging on titles + abstracts.

Honest C3: an arxiv preprint that claims something speculative (LK-99-style
RTSC, magic-MOF DAC economics, ambient metallic hydrogen) is surfaced WITH
the UNPROVEN flag attached. The digest carries the flag forward to whoever
reads it. Preprint != reproduced result.

Sentinel: __HEXA_MATTER_ARXIV_DIGEST__ PASS / FAIL

License: MIT (hexa-matter Phase F).
"""

from __future__ import annotations
import argparse
import json
import os
import re
import sys
from typing import Dict, List


# Per-verb keyword index. ORDER MATTERS only mildly; multi-tag is fine.
# Keys are hexa-matter verb names (matching hexa.toml [verbs] tail leaves).
VERB_KEYWORDS: Dict[str, List[str]] = {
    "silicon":               ["polysilicon", "poly-si", "czochralski",
                              "float-zone", "fz refining", "dopant ceiling",
                              "silicon wafer", "boron solubility", "si crystal"],
    "compound-semi":         ["gan", "sic", "gaas", "inp", "hemt", "wide-bandgap",
                              "wide bandgap", "mocvd", "4h-sic", "6h-sic",
                              "compound semiconductor"],
    "perovskite":            ["perovskite", "mapbi", "mapbbr", "abx3",
                              "halide perovskite", "oxide perovskite", "lk-99"],
    "2d-materials":          ["graphene", "mos2", "hbn", "phosphorene", "mxene",
                              "transition metal dichalcogenide", "tmd",
                              "2d material", "2d-material"],
    "magnetic-materials":    ["ndfeb", "smco", "curie", "ferrite", "bhmax",
                              "metglas", "finemet", "permanent magnet",
                              "magnetocrystalline"],
    "mof":                   ["mof ", "metal-organic framework", "hkust",
                              "zif-8", "uio-66", "mil-101", "porous coordination"],
    "superalloy":            ["inconel", "single-crystal turbine", "cmsx",
                              "ni-based superalloy", "single crystal turbine blade"],
    "carbon":                ["carbon nanotube", "cnt", "diamond film",
                              "fullerene", "glassy carbon", "pyrolytic graphite",
                              "carbon fiber"],
    "elastomer":             ["natural rubber", "sbr", "epdm", "fluoroelastomer",
                              "silicone rubber", "vulcaniz"],
    "adhesive":              ["pressure-sensitive adhesive", "cyanoacrylate",
                              "anaerobic adhesive", "structural adhesive"],
    "liquid-crystal":        ["nematic", "smectic", "cholesteric", "blue phase",
                              "liquid crystal"],
    "biodegradable-plastics":["polylactic", "pla biodegradable", "pha ",
                              "polyhydroxyalkanoate", "marine biodegradable"],
    "wood-cellulose":        ["nanocellulose", "cnf", "cnc", "mass timber", "clt",
                              "lignocellulose"],
    "epoxy":                 ["dgeba", "epoxy cure", "diglycidyl ether of bisphenol"],
    "nylon":                 ["nylon-6,6", "nylon-66", "caprolactam", "polyamide-6"],
    "aramid":                ["aramid", "kevlar", "nomex", "para-aramid"],
    "pet_film":              ["pet film", "polyethylene terephthalate film"],
    "glass":                 ["fused silica", "borosilicate glass", "glass tg"],
    "concrete":              ["uhpc", "ultra-high-performance concrete",
                              "concrete compressive"],
    "metallurgy":            ["austenite", "martensite", "ttt diagram", "bainite",
                              "ti-6al-4v"],
    "gemology":              ["corundum", "ruby fluorescence", "cvd diamond"],
    "paper":                 ["pulp tappi", "paper tensile"],
    "fabric":                ["woven fabric", "textile thread count"],
    "synthesis":             ["sol-gel", "hydrothermal synthesis", "teos hydrolysis"],
    "recycling":             ["chemical recycling", "depolymerization"],
}

# Speculative-claim flags. If any of these substrings appears, the record is
# tagged UNPROVEN in the digest output (honest C3 preservation).
UNPROVEN_FLAGS = [
    "lk-99", "room-temperature superconduct", "room temperature superconduct",
    "ambient metallic hydrogen", "metallic hydrogen ambient",
    "magic-mof", "$100/t co2", "25-year operational lifetime",
    "infinite recycle", "100% recyclable",
]


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text.lower())


def classify_record(rec: dict) -> Dict[str, object]:
    """Tag a single record by verb keyword + speculative-claim flag.

    Returns: {arxiv_id, title, verbs: [list], unproven_flags: [list]}
    """
    haystack = normalize(rec.get("title", "") + " " + rec.get("abstract", ""))
    verbs = []
    for verb, kws in VERB_KEYWORDS.items():
        for kw in kws:
            if kw in haystack:
                verbs.append(verb)
                break
    flags = []
    for flag in UNPROVEN_FLAGS:
        if flag in haystack:
            flags.append(flag)
    return {
        "arxiv_id":       rec.get("arxiv_id", ""),
        "title":          rec.get("title", ""),
        "published":      rec.get("published", ""),
        "verbs":          sorted(set(verbs)),
        "unproven_flags": flags,
    }


def digest(records: List[dict]) -> Dict[str, list]:
    """Group records by verb. A multi-verb paper appears in each verb's bucket."""
    grouped: Dict[str, list] = {}
    for rec in records:
        c = classify_record(rec)
        if not c["verbs"]:
            grouped.setdefault("__unclassified__", []).append(c)
            continue
        for v in c["verbs"]:
            grouped.setdefault(v, []).append(c)
    return grouped


def format_markdown(grouped: Dict[str, list]) -> str:
    out = ["# arxiv digest — hexa-matter verb groups\n"]
    out.append("> Generated by `_research_bridge/arxiv/arxiv_digest.py`.\n")
    out.append("> When marked UNPROVEN, the claim has NOT been reproduced/verified.\n\n")

    for verb in sorted(grouped):
        recs = grouped[verb]
        out.append(f"## `{verb}`  ({len(recs)} record{'s' if len(recs) != 1 else ''})\n")
        for r in recs[:3]:  # top-3 per verb in digest
            flag = ""
            if r["unproven_flags"]:
                flag = "  **UNPROVEN** (flags: " + ", ".join(r["unproven_flags"]) + ")"
            out.append(f"- `{r['arxiv_id']}` — {r['title']}{flag}\n")
        out.append("\n")
    return "".join(out)


def _selftest() -> int:
    # Embedded 3-paper fixture matches the arxiv_pull sample
    fixture_records = [
        {
            "arxiv_id":  "2405.00001v1",
            "title":     "FIXTURE: Boron solubility in silicon at high temperature",
            "abstract":  "Synthetic abstract. Reports boron solubility in silicon "
                         "single crystals between 1200 and 1450 K. Compares "
                         "Czochralski-grown samples with float-zone refined ingots.",
            "published": "2024-05-01T00:00:00Z",
        },
        {
            "arxiv_id":  "2405.00002v1",
            "title":     "FIXTURE: GaN-on-SiC HEMT epitaxy advances for wide-bandgap power devices",
            "abstract":  "Synthetic abstract. Reviews 4H-SiC substrate and GaN epitaxy "
                         "for high-electron-mobility transistors. HEMT applications.",
            "published": "2024-05-02T00:00:00Z",
        },
        {
            "arxiv_id":  "2405.00003v1",
            "title":     "FIXTURE: Perovskite solar cell long-term stability",
            "abstract":  "Synthetic abstract. Studies perovskite halide MAPbI3 films. "
                         "25-year operational lifetime is UNVERIFIED at commercial scale.",
            "published": "2024-05-03T00:00:00Z",
        },
    ]
    grouped = digest(fixture_records)
    # Expect at least 1 verb match. silicon + compound-semi + perovskite expected.
    expected_verbs = {"silicon", "compound-semi", "perovskite"}
    matched = set(grouped.keys()) - {"__unclassified__"}
    missing = expected_verbs - matched
    if missing:
        print(f"  FAIL: expected verbs missing: {sorted(missing)}; got: {sorted(matched)}")
        print("__HEXA_MATTER_ARXIV_DIGEST__ FAIL  (verb match)")
        return 1
    # Perovskite record should carry the 25-year flag
    perov = grouped.get("perovskite", [])
    if not perov:
        print("  FAIL: no perovskite record in digest")
        print("__HEXA_MATTER_ARXIV_DIGEST__ FAIL  (no perovskite)")
        return 1
    has_unproven = any(r["unproven_flags"] for r in perov)
    if not has_unproven:
        print("  FAIL: perovskite record should carry UNPROVEN flag (25-year lifetime)")
        print("__HEXA_MATTER_ARXIV_DIGEST__ FAIL  (unproven not flagged)")
        return 1
    for verb in sorted(matched):
        print(f"  PASS: verb={verb}  records={len(grouped[verb])}")
    print(f"  PASS: UNPROVEN flag correctly attached to perovskite record")
    print("__HEXA_MATTER_ARXIV_DIGEST__ PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    p.add_argument("--in", dest="infile", default=None,
                   help="input JSONL (default: stdin)")
    p.add_argument("--md", action="store_true", help="emit markdown digest")
    args = p.parse_args()

    if args.selftest:
        return _selftest()

    if args.infile is None:
        records = [json.loads(line) for line in sys.stdin if line.strip()]
    else:
        if not os.path.isfile(args.infile):
            print(f"input not found: {args.infile}", file=sys.stderr)
            return 1
        with open(args.infile, encoding="utf-8") as f:
            records = [json.loads(line) for line in f if line.strip()]

    grouped = digest(records)
    if args.md:
        print(format_markdown(grouped))
    else:
        for verb in sorted(grouped):
            for r in grouped[verb]:
                print(json.dumps({"verb": verb, **r}, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
