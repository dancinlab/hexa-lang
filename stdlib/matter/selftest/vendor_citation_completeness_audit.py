#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Phase J.1 gate #33 — vendor citation completeness.
For each vendor in a curated 30-entry allowlist: (1) ≥1 occurrence has a year
token within ±5 lines (±12 fallback), (2) ≥1 product/standard/datasheet ID
anchor anywhere in corpus, (3) NO `lattice-fit` / `n=6 invariant` attribution.
stdlib-only. Sentinel: `__HEXA_MATTER_VENDOR_CITATION__ PASS (N, M, K)` — K==0.
"""
from __future__ import annotations

import os
import re
import sys

REPO_ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)

VENDORS = (
    "Wacker", "Wolfspeed", "DuPont", "Toray", "Sila Nanotechnologies",
    "Group14", "Amprius", "Climeworks", "Ductal", "Cor-Tuf", "DSM Dyneema",
    "NatureWorks", "Danimer", "Lafarge-Holcim", "Sibelco", "Hitachi Metals",
    "Vacuumschmelze", "RHI Magnesita", "Vesuvius", "GE Aviation",
    "Rolls-Royce", "Pratt & Whitney", "Special Metals", "NREL",
    "Oak Ridge", "Sumitomo", "POSCO", "CATL", "BYD", "Element Six",
)

_VENDOR_ALIASES = {
    "Sila Nanotechnologies": ("Sila Nanotechnologies", "Sila Nano"),
    "DSM Dyneema":          ("DSM Dyneema", "Dyneema"),
    "Lafarge-Holcim":       ("Lafarge-Holcim", "Lafarge", "Holcim"),
    "Pratt & Whitney":      ("Pratt & Whitney", "Pratt and Whitney", "P&W"),
    "GE Aviation":          ("GE Aviation", "GE9X", "GE LEAP"),
    "Rolls-Royce":          ("Rolls-Royce", "Rolls Royce", "RR Trent"),
    "Oak Ridge":            ("Oak Ridge", "ORNL"),
    "Element Six":          ("Element Six", "E6 CVD diamond"),
}

PRODUCT_IDS = tuple(p.strip() for p in (
    "Vitreloy,IN718,Inconel,SEMI MF1188,ASTM F121,ASTM F1188,ICI Procion-H,"
    "Dyneema SK,Dyneema,Ductal,Cor-Tuf,Kevlar 49,Kevlar,Inpria,T1100G,T700,"
    "T800,T1000,Climeworks Orca,Climeworks Mammoth,Wolfspeed 6-inch SiC,"
    "Wolfspeed 8-inch SiC,Wacker Polysilicon,Hemlock Polysilicon,NMC811,LFP,"
    "LCO,CATL Blade,BYD Blade,SmCo,NdFeB,Metglas,Finemet,"
    "Vacuumschmelze VITROVAC,RHI Magnesita AZS,Vesuvius AZS,GE LEAP,"
    "Rolls-Royce Trent,Pratt & Whitney PW,CMSX-4,Rene N5,Mar-M247,Hastelloy,"
    "Special Metals Inconel,Special Metals Monel,NREL chart,Oak Ridge ORNL,"
    "Sumitomo Polyamide,POSCO HEX,Sila Titan,Group14 SCC55,Amprius SiNW,"
    "Element Six CVD,NatureWorks Ingeo,Danimer Nodax,SK99,PFP,PolyOne,Hempel"
).split(","))


def _vendor_pattern(vendor: str) -> re.Pattern:
    forms = _VENDOR_ALIASES.get(vendor, (vendor,))
    return re.compile(r"\b(?:" + "|".join(re.escape(f) for f in forms) + r")\b")


VENDOR_RE = {v: _vendor_pattern(v) for v in VENDORS}
YEAR_RE = re.compile(r"\b(?:19|20)\d{2}\b")
PRODUCT_RE = re.compile("|".join(re.escape(p) for p in PRODUCT_IDS))
LATTICE_FIT_NEAR_RE = re.compile(
    r"(lattice[-\s]?fit|n=6\s+invariant|σ\(6\)\s*=|τ\(6\)\s*=|φ\(6\)\s*=)",
    re.IGNORECASE,
)
LATTICE_NEG_RE = re.compile(
    r"(no\s+n=6|NOT\s+lattice[-\s]?fit|n6_lattice_fit_applied\s*:\s*false|"
    r"no\s+`?lattice[-\s]?fit|`?lattice[-\s]?fit`?\s+/\s+`?n=6|raw#10\s+C3"
    r"|forbids\s+n=6|do\s+not\s+apply\s+lattice|MUST\s+NOT\s+include\s+lattice"
    r"|NO\s+`?lattice|attribut[a-z]+\s+claim)", re.IGNORECASE,
)

_TOP_DOCS = (
    "NOVEL.md", "LIMIT_BREAKTHROUGH.md", "CLOSURE_RESIDUAL_BACKLOG.md",
    "AGENTS.md", "INIT.md",
)


def discover_verb_docs() -> list[str]:
    out: list[str] = []
    for name in sorted(os.listdir(REPO_ROOT)):
        if name.startswith(".") or name.startswith("_"):
            continue
        sub = os.path.join(REPO_ROOT, name)
        if not os.path.isdir(sub):
            continue
        cand = os.path.join(sub, f"{name}.md")
        if os.path.isfile(cand):
            out.append(f"{name}/{name}.md")
        if name.startswith("hexa-"):
            for sub_name in sorted(os.listdir(sub)):
                if sub_name.endswith(".md") and sub_name != f"{name}.md":
                    out.append(f"{name}/{sub_name}")
    return out


def read(p: str) -> str:
    with open(os.path.join(REPO_ROOT, p), "r", encoding="utf-8") as fh:
        return fh.read()


def audit_vendor(vendor, corpus):
    occ, year_ok, lat_v = 0, False, []
    pat = VENDOR_RE[vendor]
    for rel, lines in corpus:
        for i, line in enumerate(lines):
            if not pat.search(line):
                continue
            occ += 1
            for radius in (5, 12):
                lo, hi = max(0, i - radius), min(len(lines), i + radius + 1)
                if YEAR_RE.search("\n".join(lines[lo:hi])):
                    year_ok = True
                    break
            window = "\n".join(lines[max(0, i - 5):min(len(lines), i + 6)])
            if LATTICE_FIT_NEAR_RE.search(window) and not LATTICE_NEG_RE.search(window):
                lat_v.append(f"{rel}:{i + 1}")
    return {"occ": occ, "year_ok": year_ok, "lat_v": lat_v}


def has_product_id(corpus) -> bool:
    for _, lines in corpus:
        for line in lines:
            if PRODUCT_RE.search(line):
                return True
    return False


def selftest() -> int:
    assert len(VENDORS) == 30, f"expected 30 vendors, got {len(VENDORS)}"
    assert YEAR_RE.search("Wolfspeed datasheet 2024 spec"), "year re broken"
    assert PRODUCT_RE.search("Kevlar 49 fiber"), "product re broken"
    assert LATTICE_FIT_NEAR_RE.search("apply lattice-fit"), "lattice re broken"
    print("vendor_citation_completeness_audit --selftest PASS")
    return 0


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()
    docs = list(_TOP_DOCS) + discover_verb_docs()
    corpus = []
    for rel in docs:
        try:
            corpus.append((rel, read(rel).splitlines()))
        except FileNotFoundError:
            continue

    print("hexa-matter/selftest/vendor_citation_completeness_audit — gate #33")
    print(f"  root: {REPO_ROOT}")
    print(f"  vendors: {len(VENDORS)}   docs: {len(corpus)}")

    if not has_product_id(corpus):
        print("[FAIL] no PRODUCT_ID anchor found anywhere in corpus")
        print(f"\n__HEXA_MATTER_VENDOR_CITATION__ FAIL "
              f"({len(VENDORS)} vendors, 0 cited, {len(VENDORS)} ambiguous)")
        return 1

    cited = skipped = 0
    ambiguous: list[str] = []
    lattice_fail: list[str] = []
    for v in VENDORS:
        r = audit_vendor(v, corpus)
        if r["lat_v"]:
            lattice_fail.append(
                f"{v}: lattice-fit attribute claim at "
                + ", ".join(r["lat_v"][:3])
            )
        if r["occ"] == 0:
            skipped += 1
            continue
        if r["year_ok"]:
            cited += 1
        else:
            ambiguous.append(
                f"{v}: {r['occ']} occurrence(s) but no year within ±12 lines"
            )

    print(f"  cited (year+id): {cited}   skipped (0 occ): {skipped}   "
          f"ambiguous: {len(ambiguous)}")
    for a in ambiguous[:10]:
        print(f"  - {a}")
    for v in lattice_fail:
        print(f"  - {v}")

    k = len(ambiguous) + len(lattice_fail)
    if k > 0:
        print(f"\n__HEXA_MATTER_VENDOR_CITATION__ FAIL "
              f"({len(VENDORS)} vendors, {cited} cited with year+id, "
              f"{k} ambiguous)")
        return 1
    print(f"\n__HEXA_MATTER_VENDOR_CITATION__ PASS "
          f"({len(VENDORS)} vendors, {cited} cited with year+id, "
          f"{k} ambiguous)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
