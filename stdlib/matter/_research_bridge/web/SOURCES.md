# web SOURCES — hexa-matter research bridge

> **Created**: 2026-05-13 (Phase F)
> **Status**: vendor datasheet + RSS news feeds + patent endpoints

---

## §1 Vendor product / datasheet sources

| Vendor | Product line | URL (root) | Last-verified | Notes |
|---|---|---|---|---|
| Wacker Polysilicon AG | Electronic-grade poly-Si | https://www.wacker.com/cms/en-us/products/product-groups/polysilicon-products/ | 2026-05-13 | Public product pages; PDFs gated |
| GCL Technology | Solar-grade + EG poly-Si | https://www.gcl-poly.com.hk/ | 2026-05-13 | Investor reports + product brochures |
| Hemlock Semiconductor | EG poly-Si | https://www.hscpoly.com/ | 2026-05-13 | Product datasheets public |
| Wolfspeed | 4H-SiC wafer, GaN-on-SiC HEMT | https://www.wolfspeed.com/ | 2026-05-13 | Datasheets public; samples gated |
| Merck KGaA Performance Materials | Liquid crystal mixtures | https://www.merckgroup.com/en/products/performance-materials.html | 2026-05-13 | Material safety data + spec sheets |
| Stora Enso | CLT, glulam, mass timber | https://www.storaenso.com/en/products/wood-products | 2026-05-13 | Product brochures public |
| Element Six (De Beers Group) | CVD diamond | https://www.e6.com/ | 2026-05-13 | Technical data sheets public |
| Hitachi Metals / Proterial | NdFeB, SmCo magnets | https://www.proterial.com/ | 2026-05-13 | Renamed Proterial 2023 |
| TDK | NdFeB, ferrite magnets | https://www.tdk.com/ | 2026-05-13 | Product catalogs public |
| Vacuumschmelze | Metglas, Finemet, Vitrovac | https://vacuumschmelze.com/ | 2026-05-13 | Datasheet PDFs public |
| Toray | PAN carbon fiber, PET film | https://www.toray.com/ | 2026-05-13 | Spec sheets public |
| DuPont | Kevlar, Nomex, Zytel | https://www.dupont.com/ | 2026-05-13 | Spec sheets gated by registration |
| BASF | Ultramid nylon | https://www.basf.com/ | 2026-05-13 | Spec sheets public |
| Honeywell | Spectra UHMWPE | https://www.honeywell.com/ | 2026-05-13 | Defense product line, partial gating |

### Robots.txt + ToS notes

- **All listed vendors** have public product pages that are crawlable per their
  robots.txt as of 2026-05-13. Live-mode pulls in `vendor_datasheet_pull.py`
  fetch ONE page per request with a clear User-Agent. No bulk crawl.
- PDF datasheets are vendor-copyrighted; cache locally for the spec-cross-
  reference but do NOT redistribute the PDFs in the repo. Cache `web_cache/`
  is gitignored for vendor binaries.
- Rate limit: 1 request per 5 seconds per vendor host (vendor-friendly polite
  default; live-mode enforces).

---

## §2 RSS / Atom news feeds

| Outlet | Feed URL | Coverage | Last-verified |
|---|---|---|---|
| Materials Today (Elsevier) | https://www.materialstoday.com/news/rss/ | broad materials science | 2026-05-13 |
| Nature Materials (table of contents) | https://www.nature.com/nmat.rss | high-impact peer-reviewed | 2026-05-13 |
| IEEE Spectrum — materials tag | https://spectrum.ieee.org/topic/materials/feed/ | applied materials + electronics | 2026-05-13 |
| Semiconductor Industry Association | https://www.semiconductors.org/feed/ | compound-semi + silicon | 2026-05-13 |
| AZoM | https://www.azom.com/rss/ | trade press, broad | 2026-05-13 |
| Wood Magazine industry feed | https://www.woodworkingnetwork.com/rss.xml | mass timber, CLT | 2026-05-13 |
| pv-magazine | https://www.pv-magazine.com/feed/ | perovskite + Si PV | 2026-05-13 |

### Feed ToS notes

- All listed feeds are public RSS/Atom; consumers are explicitly welcomed.
- Headline + 1-3 line excerpt may be cached for the digest; full article body
  remains at the publisher and is NOT mirrored in the repo.
- Polite poll cadence: once per day per feed, off-peak hours.

---

## §3 Patent endpoints

| Office | Endpoint | Search type | Last-verified |
|---|---|---|---|
| USPTO PatFT (granted) | https://patft.uspto.gov/ | Boolean + bib + abstract + claims | 2026-05-13 |
| USPTO AppFT (applications) | https://appft.uspto.gov/ | Boolean + bib + abstract | 2026-05-13 |
| EPO Espacenet | https://worldwide.espacenet.com/ | Worldwide + classifications (CPC/IPC) | 2026-05-13 |
| EPO Open Patent Services (OPS) | http://ops.epo.org/ | REST API (free tier; rate-limited) | 2026-05-13 |
| Google Patents (search) | https://patents.google.com/ | Search UI + bulk dataset (BigQuery) | 2026-05-13 |

### Patent endpoint ToS notes

- USPTO public-facing endpoints are free for individual queries; bulk scraping
  is discouraged but not blocked. We target individual lookups, not bulk.
- EPO OPS has a free tier (~4 GB/week); the bridge stays well under.
- Patent ABSTRACTS are publication content — no IP issue with caching. The
  patent CLAIMS themselves are scraping-cautioned but also public.
- Polite query cadence: 1 query per 10 seconds per office (live-mode default).

---


**Critical**: when a vendor datasheet says "9N purity", the spec markdown
quotes that EXACTLY:
```
Wacker EG poly-Si: 9N purity (vendor: Wacker datasheet 2024-Q3)
```

It does NOT lattice-fit, average-with-other-vendors, or de-rate the value.
The hexa-matter spec carries the vendor number AS-IS with provenance, and
the spec-level interpretation (Si-L1 SOFT wall claim) is anchored against
the vendor number plus a NIST/CRC/SEMI reference, not against a lattice
identity.

The same discipline applies to ALL sources in this file:
- Vendor PDFs: quote as-is, never re-derive.
- News headlines: surface as-is, tag UNPROVEN if speculative.
- Patent claims: surface as-is, tag UNPROVEN if unreproduced.

---

## §5 Speculative-claim trip list

The following substrings, if found in vendor / news / patent content, trip the
UNPROVEN flag in `vendor_datasheet_pull.py`, `materials_news_feed.py`, and
`patent_search.py`:

- `lk-99`, `room-temperature superconductor`
- `ambient metallic hydrogen`
- `magic-mof`, `$100/t co2` (honest baseline: Climeworks amine $600–1000/t)
- `25-year operational lifetime` (perovskite watch)
- `infinite recycle`, `100% recyclable`

The trip list mirrors `arxiv_digest.py`. When extended, extend in all four
places (see `selftest/sources_audit.py`).

---

## §6 Cache discipline

- Vendor pages: md5-stamped HTML/PDF written to `web_cache/vendor/<md5>.html`
  with a sidecar `<md5>.meta.json` containing URL + retrieved_date.
- RSS feeds: md5-stamped XML written to `web_cache/feeds/<feed-slug>-<date>.xml`.
- Patent results: JSON written to `web_cache/patents/<endpoint>-<date>.json`.

Cache is gitignored for vendor binaries (raw PDFs). The selftest fixtures
(`sample_*.html`, `sample_*.xml`, `sample_*.json`) ARE checked in — they're
synthetic, not vendor IP.

---

## §7 Honest C3

- This file lists URLs as **research-bridge targets**, not as endorsements.
- All values pulled from these sources are SOFT walls in `LIMIT_BREAKTHROUGH.md`
  classification unless they cross-reference a NIST/CRC/ASM/SEMI/ASTM HARD wall.
  fails the repo if any spec markdown applies n=6 lattice formulas to data
  pulled via this bridge.

---

*Document authored 2026-05-13 by 박민우 <nerve011235@gmail.com> as Phase F elevation.*
