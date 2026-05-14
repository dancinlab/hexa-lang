<!-- @absorbed: 2026-05-12 -->
<!-- @sources: exynos.md §15 (canonical mirror) -->
<!-- @scope: structured citation database; zero new external claims -->
<!-- @sister: terafab/sources.md (16 entries, Wave 6.x) — same DB grammar -->
---
type: citation-database
parent: exynos/exynos.md
target_window: Mk.I~Mk.II (2026-Q2 ~ 2027)
status: index (sources frozen at absorption date 2026-05-12)
n6_template: terafab/sources.md (sister citation database)
entries: 14
---

# Exynos — Source Database

> **Purpose**: turn the bullet list of links in `exynos/exynos.md` §15
> into a structured, falsifier-linked, snapshot-traceable citation
> database. Each entry declares **what claim the source supports**,
> **what falsifier it feeds**, and **how fresh the source is** so the
> Mk.II quarterly polling rubric (Samsung quarterly IR, TrendForce
> quarterly tracker, IEDM/VLSI Symposium/ISSCC annual proceedings) can
> operate on a known-quality input set.

## §1 What each source family is good for

The 14 sources cluster into five families with sharply different uses:

- **Primary — Samsung public disclosure** (Samsung Foundry Forum,
  Samsung IR, DART KR filings, Samsung Wikipedia). Load-bearing for
  *roadmap claims* (SF3 / SF2 / SF1.4 / SF1.0 node cadence; Exynos
  generation cadence; HBM3E / HBM4 qualification). Re-checked annually
  at Samsung Foundry Forum and quarterly at Samsung IR.
- **Korean tech press** (The Elec, Korea Herald, Korea Times, ZDNet
  Korea). Load-bearing for *Korean-language-first leaks and
  design-win commentary*. Less authoritative for revenue/capex; tend
  to echo Samsung IR within 24–48 h with local Korean context.
- **Industry trackers** (TrendForce, Counterpoint, IDC). Load-bearing
  for *quantitative market share* numbers — foundry share, smartphone
  SoC share, memory share. These are the primary feeds for F-EXYNOS-1
  (Samsung Foundry rank-#2 threshold) and F-EXYNOS-3 (SF1.4 market
  share).
- **Peer-reviewed device physics** (IEEE IEDM, VLSI Symposium, ISSCC).
  Load-bearing for *physical-device claims* (GAA architecture, Exynos
  NPU specs at on-device gen-AI). Feed F-EXYNOS-7 reformulation
  (Mk.II will replace projection guesses with measured Exynos 2500 +
  SF2 metrics from these venues).
- **Competitor public commentary** (TSMC / Intel earnings calls).
  Load-bearing for *out-side-view-on-Samsung* — TSMC's quarterly
  conference calls explicitly discuss Samsung as a foundry
  competitor; Intel's discuss Samsung as both customer and IDM peer.

## §2 Source × falsifier quality matrix

Reading: rows are the 14 sources, columns are the 7 F-EXYNOS-N
falsifiers from `exynos.md` §7. Cells: `H` = high-relevance (source
directly supplies the signal), `M` = medium (corroborates), `L` = low
(peripheral), `·` = no link.

```
source                          F1  F2  F3  F4  F5  F6  F7
------------------------------- --- --- --- --- --- --- ---
SRC-EXYNOS-001  Samsung Foundry  H   H   H   M   M   H   M
SRC-EXYNOS-002  Samsung IR       H   M   H   H   H   M   ·
SRC-EXYNOS-003  DART (KR)        H   ·   M   M   H   ·   ·
SRC-EXYNOS-004  Wikipedia-Exynos M   M   ·   ·   ·   ·   M
SRC-EXYNOS-005  Wikipedia-Foundry M  H   M   ·   M   H   ·
SRC-EXYNOS-006  The Elec         H   H   M   H   H   M   ·
SRC-EXYNOS-007  Korea Herald     M   M   M   M   H   ·   ·
SRC-EXYNOS-008  Korea Times      M   M   M   M   H   ·   ·
SRC-EXYNOS-009  ZDNet Korea      M   H   M   M   M   M   ·
SRC-EXYNOS-010  TrendForce       H   M   H   H   ·   ·   M
SRC-EXYNOS-011  Counterpoint     H   ·   M   ·   ·   ·   ·
SRC-EXYNOS-012  IEEE IEDM        ·   H   ·   M   ·   M   H
SRC-EXYNOS-013  TSMC earnings    M   M   M   ·   M   M   ·
SRC-EXYNOS-014  Intel earnings   M   M   ·   ·   M   M   ·
```

Reading the matrix: F-EXYNOS-1 (rank-#2 revenue threshold) and
F-EXYNOS-5 (foundry spin-off watch) have the densest source support —
Samsung IR, DART, every Korean press outlet, every tracker.
F-EXYNOS-7 (n=6 χ² reformulation) has the thinnest — only IEDM
(SRC-EXYNOS-012) plus Wikipedia-Exynos gesture at process/architecture
parameters in a peer-reviewed form. The Mk.II reformulation will pull
Exynos 2500 + SF2 GAA metrics from IEDM 2027 / ISSCC 2027 proceedings.

## §3 Source entries

### Primary — Samsung public disclosure

```yaml
---
id: SRC-EXYNOS-001
title: "Samsung Foundry — annual Forum keynote archive"
url: https://semiconductor.samsung.com/foundry/
access_date: 2026-05-12
publisher: Samsung Foundry
type: vendor-keynote
key_claims:
  - SF3 / SF2 / SF1.4 / SF1.0 / SF0.7 public node-shrink roadmap
  - GAA from SF3 onward (publicly disclosed)
  - I-Cube / X-Cube / H-Cube advanced packaging product family
  - Backside-power-delivery target SF2/SF1.4 (publicly hinted)
  - High-NA EUV evaluation publicly underway
freshness: annual (Forum is yearly; deck mirrored publicly)
falsifier_links: [F-EXYNOS-1, F-EXYNOS-2, F-EXYNOS-3, F-EXYNOS-6]
archive: https://web.archive.org/web/2026*/semiconductor.samsung.com/foundry/
note: |
  Forum keynotes are the canonical public source for the Samsung Foundry
  roadmap. Mirrored across Samsung's own site + media coverage. No NDA.
---

---
id: SRC-EXYNOS-002
title: "Samsung Electronics — Investor Relations (quarterly + semiannual)"
url: https://www.samsung.com/global/ir/
access_date: 2026-05-12
publisher: Samsung Electronics
type: ir-filing
key_claims:
  - Samsung DS 2024 capex ≈ ₩50 T KRW (≈ $37 B USD)
  - Samsung DS 2024 R&D ≈ ₩30 T KRW
  - Foundry revenue line-item (per segment)
  - Memory DS HBM3E qualification timing
freshness: quarterly
falsifier_links: [F-EXYNOS-1, F-EXYNOS-3, F-EXYNOS-4, F-EXYNOS-5]
archive: https://web.archive.org/web/2026*/www.samsung.com/global/ir/
---

---
id: SRC-EXYNOS-003
title: "DART (KR public filing portal) — Samsung Electronics filings"
url: https://dart.fss.or.kr
access_date: 2026-05-12
publisher: Korea Financial Supervisory Service (FSS)
type: regulatory-filing
key_claims:
  - Samsung Electronics audited annual + semiannual reports
  - segment-level revenue + capex disclosures
freshness: semiannual (audited)
falsifier_links: [F-EXYNOS-1, F-EXYNOS-5]
archive: (DART is the canonical archive)
note: |
  Korean equivalent of US SEC EDGAR; all filings are public-by-law.
---

---
id: SRC-EXYNOS-004
title: "Exynos — Wikipedia"
url: https://en.wikipedia.org/wiki/Exynos
access_date: 2026-05-12
publisher: Wikipedia
type: encyclopedia
key_claims:
  - Exynos brand launch 2010
  - per-generation spec table
  - Mongoose custom core retired 2019
freshness: community-edited (high)
falsifier_links: [F-EXYNOS-2, F-EXYNOS-7]
archive: https://web.archive.org/web/2026*/en.wikipedia.org/wiki/Exynos
---

---
id: SRC-EXYNOS-005
title: "Samsung Foundry — Wikipedia"
url: https://en.wikipedia.org/wiki/Samsung_Foundry
access_date: 2026-05-12
publisher: Wikipedia
type: encyclopedia
key_claims:
  - Samsung Foundry global rank summary
  - process-node roadmap mirror of vendor decks
  - design-win history (Google Tensor, IBM Power, Qualcomm S8G2)
freshness: community-edited (high)
falsifier_links: [F-EXYNOS-2, F-EXYNOS-3, F-EXYNOS-6]
archive: https://web.archive.org/web/2026*/en.wikipedia.org/wiki/Samsung_Foundry
---
```

### Korean tech press

```yaml
---
id: SRC-EXYNOS-006
title: "The Elec — Samsung Foundry coverage"
url: https://www.thelec.kr
access_date: 2026-05-12
publisher: The Elec
type: tech-press
key_claims:
  - Korean-first design-win leaks
  - Pyeongtaek P3/P4 buildout commentary
  - SF2 GAA ramp commentary
freshness: high (daily)
falsifier_links: [F-EXYNOS-1, F-EXYNOS-2, F-EXYNOS-4, F-EXYNOS-5]
archive: https://web.archive.org/web/2026*/www.thelec.kr
---

---
id: SRC-EXYNOS-007
title: "Korea Herald — Tech section"
url: https://www.koreaherald.com/Tech
access_date: 2026-05-12
publisher: Korea Herald
type: tech-press
key_claims:
  - English daily; Samsung Electronics beat
  - foundry-vs-memory share commentary
freshness: high (daily)
falsifier_links: [F-EXYNOS-5]
archive: https://web.archive.org/web/2026*/www.koreaherald.com/Tech
---

---
id: SRC-EXYNOS-008
title: "Korea Times — Tech section"
url: https://www.koreatimes.co.kr/www/tech/index.asp
access_date: 2026-05-12
publisher: Korea Times
type: tech-press
key_claims:
  - English daily; corroborating outlet
freshness: high (daily)
falsifier_links: [F-EXYNOS-5]
archive: https://web.archive.org/web/2026*/www.koreatimes.co.kr/www/tech/index.asp
---

---
id: SRC-EXYNOS-009
title: "ZDNet Korea — Semiconductor"
url: https://zdnet.co.kr
access_date: 2026-05-12
publisher: ZDNet Korea
type: tech-press
key_claims:
  - Korean daily; deep semi coverage
  - Exynos 2500 rumour-tracker
freshness: high (daily)
falsifier_links: [F-EXYNOS-2]
archive: https://web.archive.org/web/2026*/zdnet.co.kr
---
```

### Industry trackers

```yaml
---
id: SRC-EXYNOS-010
title: "TrendForce — Foundry quarterly tracker"
url: https://www.trendforce.com
access_date: 2026-05-12
publisher: TrendForce
type: market-tracker
key_claims:
  - quarterly foundry-share (TSMC ~ 61 %, Samsung ~ 11 %, other ~ 28 %)
  - HBM market-share (SK hynix vs Samsung vs Micron)
  - quarterly memory bit-output
freshness: quarterly
falsifier_links: [F-EXYNOS-1, F-EXYNOS-3, F-EXYNOS-4, F-EXYNOS-7]
archive: (TrendForce reports paywalled; key facts mirrored in press)
---

---
id: SRC-EXYNOS-011
title: "Counterpoint Research — Smartphone SoC tracker"
url: https://www.counterpointresearch.com
access_date: 2026-05-12
publisher: Counterpoint Research
type: market-tracker
key_claims:
  - smartphone SoC shipments (Exynos vs Snapdragon vs Apple vs Dimensity)
  - quarterly Galaxy device split
freshness: quarterly
falsifier_links: [F-EXYNOS-1]
archive: (Counterpoint reports paywalled; press echoes free)
---
```

### Peer-reviewed device physics

```yaml
---
id: SRC-EXYNOS-012
title: "IEEE IEDM 2023 / 2024 / 2025 proceedings — Samsung + KR papers"
url: https://ieee-iedm.org
access_date: 2026-05-12
publisher: IEEE
type: peer-reviewed
key_claims:
  - Samsung Foundry GAA device-physics papers
  - Exynos NPU public disclosure venue
  - KR-academia (KAIST/SNU/POSTECH/Hanyang) device papers
freshness: annual (December)
falsifier_links: [F-EXYNOS-2, F-EXYNOS-7]
archive: (IEEE Xplore canonical archive)
note: |
  Primary feed for the Mk.II reformulation of F-EXYNOS-7: replaces
  projection guesses with measured Exynos 2500 / SF2 GAA device metrics.
---
```

### Competitor public commentary

```yaml
---
id: SRC-EXYNOS-013
title: "TSMC Earnings Calls — Samsung-as-competitor commentary"
url: https://investor.tsmc.com/
access_date: 2026-05-12
publisher: TSMC
type: earnings-call
key_claims:
  - quarterly TSMC public conf-call mentions of Samsung as foundry competitor
  - implicit corroboration of Samsung Foundry rank-#2 status
freshness: quarterly
falsifier_links: [F-EXYNOS-1, F-EXYNOS-3, F-EXYNOS-6]
archive: https://web.archive.org/web/2026*/investor.tsmc.com/
---

---
id: SRC-EXYNOS-014
title: "Intel Earnings Calls — IDM 2.0 vs Samsung commentary"
url: https://www.intc.com/news-events/
access_date: 2026-05-12
publisher: Intel
type: earnings-call
key_claims:
  - quarterly Intel public conf-call mentions of Samsung as IDM peer
  - Intel 14A vs Samsung SF1.4 framing
freshness: quarterly
falsifier_links: [F-EXYNOS-5, F-EXYNOS-6]
archive: https://web.archive.org/web/2026*/www.intc.com/news-events/
---
```

## §4 Refresh policy

- **Primary Samsung** (001, 002, 003): re-fetch every Samsung IR
  quarter (typically late January / April / July / October); re-fetch
  Samsung Foundry Forum keynote (annually, typically June).
- **Korean press** (006-009): re-fetch quarterly at IR cycle; cherry-pick
  per major rumour event (Exynos 2500 launch, SF2 HVM declaration, etc.).
- **Trackers** (010, 011): re-fetch quarterly; promote any rank /
  share delta into a Mk.II addendum entry.
- **IEEE** (012): re-fetch annually at IEDM proceedings publication
  (typically late December / early January).
- **Competitor** (013, 014): re-fetch quarterly at TSMC / Intel
  earnings cadence.

## §5 Sources NOT yet in this database (Mk.II additions expected)

The following are not yet entries here because no Exynos-specific
recent disclosure has landed against them at Mk.I:

- KAIST PIM Center publication index (F-EXYNOS-7 reformulation feed)
- SNU AI Center on-device LLM benchmark suite (F-EXYNOS-7 reformulation)
- POSTECH MEMS 3-D packaging papers (F-EXYNOS-7 reformulation)
- Korea Advanced Nano Fab Center (KANC) shared clean room usage stats
- Samsung Foundry Forum 2026 keynote (deck not yet published as of 2026-05-12)
- IEDM 2026 proceedings (publication December 2026)

These will be added as `SRC-EXYNOS-015+` once an Exynos-specific
document is publicly available against any of them.

---

**Provenance**: Citation database derived 1:1 from `exynos.md` §15.
Zero new external claims. Archive URLs are speculative Wayback Machine
templates for snapshots that may or may not exist at access date; the
canonical mirrors are the publisher sites themselves. **No NDA, no
proprietary process kits, no Samsung-internal data.** Korean editorial
tone is heritage framing only.
