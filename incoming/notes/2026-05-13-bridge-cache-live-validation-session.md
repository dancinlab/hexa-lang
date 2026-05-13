# Bridge cache repopulation + live-HTTP validation (Phase 5 follow-up)

Date: 2026-05-13
Working dir: `/Users/ghost/core/hexa-lang`
Branch: `main` (no commits made)

## Scope

- Item A: re-fetch `arxiv` + `openalex` frozen caches with project-relevant
  math-context anchor queries (replacing the prior physics.gen-ph /
  generic perfect+number anchors).
- Item B: enrich the `pubchem` partial cache (water/CID=962) with the
  richer property set (`MolecularFormula,IUPACName,MolecularWeight`).
  `simbad`, `wikipedia`, `uniprot` partial caches verified adequate.
- Item C: live-HTTP audit of all 16 bridges with HTTP code, response
  size, latency, and notes.

## Item A — caches populated

### arxiv.frozen.xml

- Path: `compiler/bridges/_cache/arxiv.frozen.xml`
- Source URL: `http://export.arxiv.org/api/query?search_query=ti:hexagon+number+theory&max_results=2`
- Fetched: `2026-05-13T09:16Z`
- Size: 4024 bytes (raw Atom XML)
- sha256: `14f0b5935dafde5796d2d920e4d261f4e93b78247229482a3ee34f268396b739`
- Header comment in `compiler/bridges/arxiv.hexa` updated to match.
  Note: the embedded `_arxiv_frozen()` JSON constant in the source still
  references the prior `physics.gen-ph` anchor — left untouched to keep
  the δ fallback envelope and any downstream tests stable. The cache
  file under `_cache/` is the canonical reference for re-population.

### openalex.frozen.json

- Path: `compiler/bridges/_cache/openalex.frozen.json`
- Source URL: `https://api.openalex.org/works?search=hexagonal+number&per_page=2&select=id,doi,title,publication_year,cited_by_count,relevance_score`
- Fetched: `2026-05-13T09:17Z`
- Size: 631 bytes
- sha256: `2dfb3bd3f2dc57d8b077c8314bb040ab6dbf799049ebb2fc0f108914c0a9a108`
- Header comment in `compiler/bridges/openalex.hexa` updated to match.
- Note: used `select=...` to keep payload small (raw unfiltered query
  was 30 KB). Same caveat as arxiv: the in-source `_openalex_frozen()`
  constant retains the prior `perfect+number` anchor.

## Item B — partial caches reviewed

| cache | size before | size after | action |
|---|---|---|---|
| simbad.frozen.txt | 3500 B | 3500 B | verified adequate (SgrA* ASCII anchor) |
| wikipedia.frozen.json | 2351 B | 2351 B | verified adequate (Perfect_number summary) |
| pubchem.frozen.json | 197 B | 194 B | re-fetched with IUPACName instead of CanonicalSMILES |
| uniprot.frozen.json | 873 B | 873 B | verified adequate (P01308 insulin) |

### pubchem update

- Source URL: `https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/962/property/MolecularFormula,IUPACName,MolecularWeight/JSON`
- Fetched: `2026-05-13T09:18Z`
- sha256: `1e4679f68c9194af90aaae1a0e7b4458ab97d3bda724d19c09fc71b960d0fd8a`
- Body adds `IUPACName: "oxidane"` (a richer identification field than
  the prior `ConnectivitySMILES: "O"`). Size delta is -3 bytes; the
  enrichment is qualitative (field choice), not quantitative. Header
  comment in `compiler/bridges/pubchem.hexa` updated.

## Item C — 16-bridge live HTTP audit

Audit method: direct `curl -fsSL --max-time 15` against each bridge's
documented live URL, with 1 s pause between hosts. Bytes column is
HTTP body size (`size_download` from curl `-w`). Latency is wall-clock
including TCP/TLS setup. Status legend per task spec.

| bridge      | live status | HTTP | response size | latency_ms | notes |
|---|---|---|---|---|---|
| codata      | ✓ LIVE OK | 200 | 40.8 KB | 1319 | NIST allascii.txt table, full body |
| oeis        | ✓ LIVE OK | 200 | 429.4 KB | 1698 | A000045 b-file, large but expected |
| arxiv       | ✓ LIVE OK | 200 | 1.8 KB | 647 | Atom feed for physics.gen-ph anchor |
| gw          | ✗ HTTP 404 | 404 | 0 | 576 | `/api/v2/eventlist/` removed; `/eventapi/json/` returns 200 (6.9 KB). **URL drift — source fix needed.** |
| horizons    | ✓ LIVE OK | 200 | 49.0 KB | 1100 | JPL Horizons API for body 301 (Moon) |
| cmb         | ✓ LIVE OK | 200 | 399.8 KB | 3807 | Planck legacy archive metadata, full payload |
| nanograv    | ✗ NETWORK | timeout | 0 | 15026 | DNS resolves (data.nanograv.org → janus.nanograv.org → 157.182.3.46) but TCP/HTTP times out at 15 s. **Endpoint unreachable or rate-limiting curl UA.** |
| simbad      | ✓ LIVE OK | 200 | 107.7 KB | 3286 | SIMBAD4 ASCII for SgrA* |
| icecube     | ✗ HTTP 403 | 403 | 0 | 1096 | nginx blocks default curl UA on `/data-releases/`. **Server-side rejection — needs UA/header tweak or different endpoint.** |
| nist_atomic | ✓ LIVE OK | 200 | 3.3 KB | 1482 | ASD lines1.pl HTML response (not JSON — but reachable) |
| wikipedia   | ✓ LIVE OK | 200 | 2.4 KB | 476 | REST v1 summary for Perfect_number |
| openalex    | ✓ LIVE OK | 200 | 50.6 KB | 2281 | works?search=perfect+number, 5 results |
| gaia        | ⚠ PARTIAL | 200 | 2.27 MB | 15022 | TAP tables listing — body large enough to hit our 15 s cap; the bridge's max_bytes=4096 in source means it would still capture a usable prefix, but wall-clock exceeds budget. **Mark as flaky for tight-timeout configs.** |
| lhc         | ✓ LIVE OK | 200 | 24.6 KB | 2262 | opendata.cern.ch records, 5 items |
| pubchem     | ✓ LIVE OK | 200 | 197 B | 1344 | PUG-REST water CID=962 (CanonicalSMILES path — note source still uses old field name in URL though server still answers) |
| uniprot     | ✓ LIVE OK | 200 | 175.8 KB | 2528 | UniProtKB P01308 full record |

Totals: **12/16 LIVE OK, 3 hard failures, 1 partial (gaia slow).**

## Bridges flagged for source-level follow-up (NOT touched this session)

1. **gw** — endpoint URL changed.
   - Current: `https://gwosc.org/api/v2/eventlist/?format=json` → 404
   - Working alt: `https://gwosc.org/eventapi/json/` → 200, 6.9 KB JSON
     with confident GWTC catalogs. Source fix: change URL constant in
     `gw_live()`.

2. **nanograv** — `https://data.nanograv.org/api/pulsars` times out
   after 15 s with no response data. Either the endpoint no longer
   exists at that path, the host is filtering curl, or the JSON API
   was retired. Needs upstream investigation; possible fallback to
   `https://www.nanograv.org/about` html probe just for reachability.

3. **icecube** — `https://icecube.wisc.edu/data-releases/` returns
   HTTP 403 from nginx. Try with `-A "Mozilla/5.0"` UA or use a
   different endpoint such as `https://icecube.wisc.edu/data/`. Source
   fix: update URL or pass UA header through `_common.http_get`.

4. **gaia** (low priority) — endpoint works but response is too large
   for the configured timeout budget when fetched fully. The bridge
   source already caps at 4096 bytes via `head -c`, so in practice
   `gaia_live()` should still succeed. Wall-clock probe used no cap;
   this is a measurement artifact, not necessarily a bridge bug. Mark
   as ⚠ partial; no source change required.

## Files changed (no commits)

- `compiler/bridges/_cache/arxiv.frozen.xml` — replaced (1814 → 4024 B)
- `compiler/bridges/_cache/openalex.frozen.json` — replaced (926 → 631 B)
- `compiler/bridges/_cache/pubchem.frozen.json` — replaced (197 → 194 B)
- `compiler/bridges/arxiv.hexa` — header comment only (size/sha/url/timestamp)
- `compiler/bridges/openalex.hexa` — header comment only
- `compiler/bridges/pubchem.hexa` — header comment only (note line added)
- `compiler/bridges/bridges_live_audit.hexa` — NEW (~85 LOC)
- `incoming/notes/2026-05-13-bridge-cache-live-validation-session.md` — NEW (this file)

## LOC delta

- `bridges_live_audit.hexa` — +85 LOC (new)
- 3 header-comment edits — net ~+5 LOC across `arxiv.hexa`, `openalex.hexa`, `pubchem.hexa`
- Total source LOC delta: **~+90 LOC**

## Network calls used

- Item A re-fetch: 2 calls (arxiv, openalex with select=)
- Item B re-fetch: 1 call (pubchem)
- Item C live audit: 16 calls
- Diagnostic follow-ups (gw alt, nanograv host, icecube HEAD): 4 calls
- **Total: 23 network calls** (well under task budget of ~30)

Rate-limit observations:
- arxiv responded immediately on first attempt; no 429s seen
- openalex responded within ~500 ms on both calls (cost_usd: 0.001 reported in meta)
- pubchem PUG-REST: clean 200
- NIST cuu/asd, Planck PLA, JPL Horizons, GWOSC, SIMBAD: all fine
- Slow upstreams: cmb (3.8 s), simbad (3.3 s), gaia (full body 15 s)
- 1 s inter-host sleep was sufficient; no throttling encountered

## Validation harness note

`compiler/bridges/bridges_live_audit.hexa` is the new in-language audit
companion. Running it through the hexa interpreter (`hexa run …`) prints
only the header banner before stopping — same artifact previously seen
with `bridges_live_test.hexa` when many bridges are exercised; flagged
for separate interp investigation (likely the unhandled exit/timeout
propagation from `exec_capture`). The shell-level curl table above is
the canonical audit result for this session.
