#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
vendor_datasheet_pull.py — vendor product page / datasheet retrieval and parsing.

Status: PARTIAL (stdlib parsing FUNCTIONAL; beautifulsoup4 optional for richer
extraction; live mode requires `--live` + network access).

Phase F (2026-05-13): the web-deep-research arm for vendor data. Pulls a
vendor product page (HTML, occasionally PDF), caches the raw bytes md5-stamped
with retrieval date, and extracts vendor name + product code via regex.

Target vendors (from `web/SOURCES.md`):
  - Wacker Polysilicon AG (electronic-grade poly-Si)
  - GCL Technology (poly-Si)
  - Hemlock Semiconductor (poly-Si)
  - Wolfspeed (4H-SiC wafer, GaN-on-SiC HEMT)
  - Merck KGaA (liquid crystal mixtures)
  - Stora Enso (mass timber, CLT)
  - Element Six (CVD diamond)
  - Hitachi Metals / TDK (NdFeB / SmCo magnets)

apply n=6 lattice formulas to those numbers. Vendor data is quoted as-is in
hexa-matter spec docs; the spec then carries an `@vendor-informed:` cross-
link to the cache entry.

OFFLINE-REPLAY: --selftest reads web/web_cache/sample_vendor.html (a synthetic
HTML fixture) and extracts the vendor name + product code. No network call
ever occurs in --selftest.

Sentinel: __HEXA_MATTER_VENDOR_DATASHEET_PULL__ PASS / FAIL / PASS (SKIP mode)

License: MIT (hexa-matter Phase F).
"""

from __future__ import annotations
import argparse
import hashlib
import os
import re
import sys
from typing import Dict, Optional


def _have_bs4() -> bool:
    try:
        import bs4  # noqa: F401
        return True
    except ImportError:
        return False


def _have_requests() -> bool:
    try:
        import requests  # noqa: F401
        return True
    except ImportError:
        return False


def parse_html_stdlib(html: str) -> Dict[str, Optional[str]]:
    """Stdlib-only extractor. Uses regex on <meta>/<dd>/<class> markers.

    Returns dict with: vendor_name, product_code, purity_grade, bulk_density (if found).
    """
    out: Dict[str, Optional[str]] = {
        "vendor_name":   None,
        "product_code":  None,
        "purity_grade":  None,
        "bulk_density":  None,
    }
    # <meta name="vendor" content="...">
    m = re.search(r'<meta\s+name=["\']vendor["\']\s+content=["\']([^"\']+)["\']',
                  html, flags=re.IGNORECASE)
    if m:
        out["vendor_name"] = m.group(1).strip()
    # <meta name="product-code" content="...">
    m = re.search(r'<meta\s+name=["\']product-code["\']\s+content=["\']([^"\']+)["\']',
                  html, flags=re.IGNORECASE)
    if m:
        out["product_code"] = m.group(1).strip()
    # Fallback: <h1 class="vendor-name">...</h1>
    if not out["vendor_name"]:
        m = re.search(r'<h1[^>]*class=["\'][^"\']*vendor-name[^"\']*["\'][^>]*>([^<]+)</h1>',
                      html, flags=re.IGNORECASE)
        if m:
            out["vendor_name"] = m.group(1).strip()
    # Datasheet <dl><dt>Purity grade</dt><dd>9N (...)</dd></dl>
    dl_pairs = re.findall(r'<dt>([^<]+)</dt>\s*<dd[^>]*>([^<]+)</dd>',
                          html, flags=re.IGNORECASE)
    for label, value in dl_pairs:
        key = label.strip().lower().replace(" ", "_")
        if key == "product_code" and not out["product_code"]:
            out["product_code"] = value.strip()
        elif key == "purity_grade":
            out["purity_grade"] = value.strip()
        elif key == "bulk_density":
            out["bulk_density"] = value.strip()
    return out


def parse_html_bs4(html: str) -> Dict[str, Optional[str]]:
    """beautifulsoup4 extractor. Richer than stdlib regex but optional."""
    from bs4 import BeautifulSoup
    soup = BeautifulSoup(html, "html.parser")
    out: Dict[str, Optional[str]] = {
        "vendor_name":   None,
        "product_code":  None,
        "purity_grade":  None,
        "bulk_density":  None,
    }
    meta_vendor = soup.find("meta", attrs={"name": "vendor"})
    if meta_vendor and meta_vendor.get("content"):
        out["vendor_name"] = meta_vendor["content"].strip()
    meta_pc = soup.find("meta", attrs={"name": "product-code"})
    if meta_pc and meta_pc.get("content"):
        out["product_code"] = meta_pc["content"].strip()
    if not out["vendor_name"]:
        h1 = soup.find("h1", class_="vendor-name")
        if h1:
            out["vendor_name"] = h1.get_text(strip=True)
    for dt in soup.find_all("dt"):
        dd = dt.find_next_sibling("dd")
        if not dd:
            continue
        key = dt.get_text(strip=True).lower().replace(" ", "_")
        value = dd.get_text(strip=True)
        if key == "product_code" and not out["product_code"]:
            out["product_code"] = value
        elif key == "purity_grade":
            out["purity_grade"] = value
        elif key == "bulk_density":
            out["bulk_density"] = value
    return out


def stamp_cache(content: bytes, retrieved_date: str) -> str:
    """Return md5 hex stamp for cache identity."""
    h = hashlib.md5()
    h.update(retrieved_date.encode("utf-8"))
    h.update(b"|")
    h.update(content)
    return h.hexdigest()


def fetch_live(url: str, user_agent: str = "hexa-matter-research-bridge/0.1 (Phase F)") -> bytes:
    """LIVE fetch. NOT invoked in --selftest. Honors User-Agent + robots.txt
    expectations (caller responsibility to pre-check robots.txt).
    """
    if _have_requests():
        import requests
        r = requests.get(url, headers={"User-Agent": user_agent}, timeout=30)
        r.raise_for_status()
        return r.content
    # stdlib fallback
    from urllib.request import urlopen, Request
    req = Request(url, headers={"User-Agent": user_agent})
    with urlopen(req, timeout=30) as resp:
        return resp.read()


def _fixture_path() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(here, "web_cache", "sample_vendor.html")


def _selftest() -> int:
    fixture = _fixture_path()
    if not os.path.isfile(fixture):
        print(f"  FAIL: fixture missing: {fixture}")
        print("__HEXA_MATTER_VENDOR_DATASHEET_PULL__ FAIL  (fixture missing)")
        return 1
    with open(fixture, "rb") as f:
        raw = f.read()
    html = raw.decode("utf-8", errors="replace")

    # md5 stamp determinism
    md5 = stamp_cache(raw, "2026-05-13")
    if len(md5) != 32:
        print(f"  FAIL: md5 not 32 chars: {md5!r}")
        print("__HEXA_MATTER_VENDOR_DATASHEET_PULL__ FAIL  (md5 form)")
        return 1
    md5_again = stamp_cache(raw, "2026-05-13")
    if md5 != md5_again:
        print(f"  FAIL: md5 non-deterministic")
        print("__HEXA_MATTER_VENDOR_DATASHEET_PULL__ FAIL  (non-deterministic)")
        return 1

    # Parse with stdlib path (always available)
    rec = parse_html_stdlib(html)
    if rec["vendor_name"] != "SAMPLE-VENDOR-CORP":
        print(f"  FAIL: stdlib parse vendor_name={rec['vendor_name']!r}")
        print("__HEXA_MATTER_VENDOR_DATASHEET_PULL__ FAIL  (stdlib vendor)")
        return 1
    if rec["product_code"] != "SV-PSI-9N-001":
        print(f"  FAIL: stdlib parse product_code={rec['product_code']!r}")
        print("__HEXA_MATTER_VENDOR_DATASHEET_PULL__ FAIL  (stdlib product code)")
        return 1
    print(f"  PASS: stdlib parse vendor={rec['vendor_name']}  code={rec['product_code']}")
    print(f"  PASS: stdlib parse purity={rec['purity_grade']}  density={rec['bulk_density']}")
    print(f"  PASS: md5={md5[:12]}…")

    # If bs4 available, also exercise the richer extractor
    if _have_bs4():
        rec2 = parse_html_bs4(html)
        if rec2["vendor_name"] != "SAMPLE-VENDOR-CORP":
            print(f"  FAIL: bs4 parse vendor_name={rec2['vendor_name']!r}")
            print("__HEXA_MATTER_VENDOR_DATASHEET_PULL__ FAIL  (bs4 vendor)")
            return 1
        print(f"  PASS: bs4 parse vendor={rec2['vendor_name']}  code={rec2['product_code']}")
    else:
        print("  INFO: beautifulsoup4 not installed; richer extractor SKIPPED (stdlib parse covers selftest)")

    print("__HEXA_MATTER_VENDOR_DATASHEET_PULL__ PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    p.add_argument("--live", action="store_true",
                   help="LIVE mode: fetch URL (requires network + robots.txt pre-check)")
    p.add_argument("--url", default=None, help="vendor product page URL (live mode)")
    p.add_argument("--in", dest="infile", default=None,
                   help="parse a locally-cached HTML file instead of fetching")
    args = p.parse_args()

    if args.selftest:
        return _selftest()

    if args.live and args.url:
        raw = fetch_live(args.url)
        rec = parse_html_bs4(raw.decode("utf-8", errors="replace")) if _have_bs4() \
              else parse_html_stdlib(raw.decode("utf-8", errors="replace"))
        for k, v in rec.items():
            print(f"  {k}: {v}")
        return 0

    if args.infile:
        with open(args.infile, "rb") as f:
            raw = f.read()
        rec = parse_html_bs4(raw.decode("utf-8", errors="replace")) if _have_bs4() \
              else parse_html_stdlib(raw.decode("utf-8", errors="replace"))
        for k, v in rec.items():
            print(f"  {k}: {v}")
        return 0

    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
