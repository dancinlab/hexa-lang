# `_research_bridge/` — hexa-matter external-literature absorption

> **Created**: 2026-05-13 (Phase F) · **Status**: 8 modules (arxiv 2 + web 3 + selftest 3), offline-replay
> **Pattern reference**: `_python_bridge/` (Phase E) — same `--selftest` + stdlib-fallback discipline
> **Selftest wiring**: `selftest/research_bridge_smoke.sh` → `selftest/run_all.sh` (gate 22)

---

## Purpose

External-literature absorption layer for hexa-matter. Pulls signals from:

- **arxiv deep research** — cond-mat.mtrl-sci API for current research papers
- **web deep research** — vendor datasheets (Wacker, GCL, Wolfspeed, …),
  materials industry news feeds (RSS/Atom), USPTO/EPO patent search

Per user directive (2026-05-13):
> "web deep research & arxiv deep research"

Each subsystem ingests external signals, caches them locally (md5-stamped),
and produces a hexa-matter-compatible digest (per-verb keyword tagging).

This bridge is the **ingestion layer**. It does NOT replace SPEC_FIRST —
external signals INFORM specs, they do not REPLACE them.

---

## Layout

```
_research_bridge/
  README.md                                  # this file
  pyproject.toml                             # optional deps (requests / feedparser / beautifulsoup4)
  arxiv/
    arxiv_pull.py                            # arxiv API pull (cond-mat.mtrl-sci primary)
    arxiv_digest.py                          # filter + verb-keyword tagging + dedupe
    arxiv_cache/                             # md5-stamped JSON snapshots
      sample_response.xml                    # offline-replay fixture (3 papers)
    SOURCES.md                               # arxiv categories + keyword strategy
  web/
    vendor_datasheet_pull.py                 # vendor PDF/HTML datasheet pull
    materials_news_feed.py                   # RSS/Atom industry news
    patent_search.py                         # USPTO/EPO public patent search
    web_cache/                               # md5-stamped snapshots
      sample_vendor.html                     # offline-replay fixture
      sample_rss.xml                         # offline-replay fixture
      sample_patent.json                     # offline-replay fixture
    SOURCES.md                               # vendor URLs + RSS feeds + patent endpoints
  selftest/
    arxiv_smoke.py                           # offline replay (arxiv_pull + arxiv_digest)
    web_smoke.py                             # offline replay (vendor + news + patent)
    sources_audit.py                         # SOURCES.md validity check
```

---

## Live capability vs offline-replay matrix

| Module | Live mode | Offline-replay (--selftest) | Optional dep |
|---|---|---|---|
| `arxiv/arxiv_pull.py` | hits `export.arxiv.org/api/query` (3-sec backoff) | replay from `arxiv_cache/sample_response.xml` | none (stdlib urllib) |
| `arxiv/arxiv_digest.py` | parse JSONL → per-verb digest | embedded 3-paper fixture | none (stdlib) |
| `web/vendor_datasheet_pull.py` | fetch vendor PDF/HTML (robots.txt aware) | replay from `web_cache/sample_vendor.html` | stdlib urllib (BS4 optional) |
| `web/materials_news_feed.py` | poll RSS/Atom feeds | replay from `web_cache/sample_rss.xml` | feedparser optional (stdlib fallback) |
| `web/patent_search.py` | USPTO/EPO public-API call | replay from `web_cache/sample_patent.json` | stdlib urllib |
| `selftest/arxiv_smoke.py` | n/a (selftest-only) | offline aggregator | stdlib |
| `selftest/web_smoke.py` | n/a (selftest-only) | offline aggregator | stdlib |
| `selftest/sources_audit.py` | n/a (selftest-only) | validate SOURCES.md form | stdlib |

**Live mode is INVOKED ONLY when the user explicitly passes `--live`.**
`--selftest` is offline-by-default and air-gap-safe. No live network call is

---

## `--selftest` convention

Same as Phase E `_python_bridge/`:

```
__HEXA_MATTER_<MODULE_UPPER>__ PASS
```

or

```
__HEXA_MATTER_<MODULE_UPPER>__ PASS (SKIP mode)   # optional dep missing
__HEXA_MATTER_<MODULE_UPPER>__ FAIL  (<reason>)
```

Selftests are:
- **Offline** — fixtures only, no network calls.
- **Deterministic** — same fixture → byte-identical output.
- **Tiny** — sample fixtures are 3-item / single-page.
- **Rate-limit aware** — live mode (not exercised in selftest) respects
  arxiv 3-sec backoff, vendor robots.txt, USPTO open-access limits.

---

## Install (optional deps)

Stdlib-only modules work out of the box on a stock Python 3.9+ install.

For richer parsing / live-mode capabilities:

```bash
# all optional deps
pip install -e "_research_bridge[all]"

# or per-stack
pip install -e "_research_bridge[web]"        # requests + beautifulsoup4
pip install -e "_research_bridge[feeds]"      # feedparser
```

If a module's optional dep is missing, it SKIPs cleanly with a clear reason
and exits 0 — same discipline as Phase E.

---

## Hard constraints (per `INIT.md`)

This bridge **must NOT**:

1. Apply n=6 lattice formulas to vendor / arxiv / patent data
   at the repo level).
2. Replace SPEC_FIRST verdicts. Research signals INFORM specs; the per-verb
   spec markdown remains the source of truth.
3. Make live network calls during `--selftest` (air-gap CI discipline).
4. Lose the UNPROVEN / UNVERIFIED stamps. When surfacing an arxiv preprint
   that claims something speculative (e.g. LK-99-style RTSC, GNoME-discovered
   stable material), the digest MUST tag it UNPROVEN.
5. Strip vendor-published numbers. Vendor datasheet values are THE VENDOR'S
   numbers — quote them as-is, never lattice-fit, never average across vendors
   without provenance.

This bridge **may**:
- Cache external responses locally with md5 + retrieval-date.
- Filter / dedupe / tag by hexa-matter verb keyword.
- Cross-link an arxiv paper to a spec entry via `@arxiv-informed: <id> <date>`.
- Cross-link a patent to a spec entry via `@patent-informed: <no> <date>`.
- Surface vendor SOFT-wall claims while preserving the HARD-wall ceilings from
  `LIMIT_BREAKTHROUGH.md`.

---

## Cross-linking convention

When a research signal informs a hexa-matter spec update:

```markdown
## Si-L8 — doping concentration ceiling

@arxiv-informed: 2402.12345 (2024-02-19) — "Boron solubility in Si at 1300 K…"
@patent-informed: US11,123,456 (2023-08-15) — "Method for B-doped Si crystal growth"

… spec text …
```

Markers are tracked by `selftest/sources_audit.py` to ensure cross-links don't
drift (the arxiv ID / patent no. resolves to a row in the local cache).

---

## Wiring

`selftest/research_bridge_smoke.sh` (lives in repo-level `selftest/`, not in
this directory) invokes every `_research_bridge/selftest/*.py --selftest`
and aggregates PASS / FAIL / SKIP. It emits:

```
__HEXA_MATTER_RESEARCH_BRIDGE__ PASS  (N/N modules, M skipped)
```

`selftest/run_all.sh` runs it as gate 22 (after Phase E `pyproject_smoke.sh`
at gate 21). The full selftest scoreboard becomes `__HEXA_MATTER_SELFTEST__
PASS (22/22)` after Phase F.

---

## Cross-link

- `INIT.md` §"Phase F" — phase scope + commit log
- `V1_2_0_HANDOFF.md` §5 — Phase F original target list
- `_python_bridge/README.md` — Phase E sister bridge (compute side)
- `_absorption_bridge/README.md` — Phase G sister bridge (MaterialsProject/GNoME/…)
- `LATTICE_POLICY.md` §1.2 + §1.3 — real-limits-first + lattice auxiliary
- `LIMIT_BREAKTHROUGH.md` — HARD / SOFT wall classification

---

*Document authored 2026-05-13 by 박민우 <nerve011235@gmail.com> as Phase F elevation.*
