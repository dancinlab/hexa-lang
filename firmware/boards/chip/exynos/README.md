# exynos — Meta-Domain (Samsung Korean-Fab Heritage Envelope)

> **Outer envelope wrapping the 6 hexa-chip groups under the Samsung
> Exynos / Samsung Foundry heritage pattern; not a verb;
> 29-verb / 6-group counts unchanged.**

[![Type: meta-domain](https://img.shields.io/badge/type-meta--domain-purple.svg)](exynos.md)
[![Wraps: 6 groups](https://img.shields.io/badge/wraps-6%20groups-blue.svg)](#cross-link)
[![Falsifiers: 7](https://img.shields.io/badge/falsifiers-7-orange.svg)](#falsifier-register-summary)
[![Sources: public (no NDA)](https://img.shields.io/badge/sources-public%20%28no%20NDA%29-brightgreen.svg)](exynos.md#15-references)
[![Closure: SPEC_PLUS_RUNNABLE](https://img.shields.io/badge/closure-SPEC__PLUS__RUNNABLE-brightgreen.svg)](CLOSURE.md)
[![Sister: terafab](https://img.shields.io/badge/sister-terafab-purple.svg)](../terafab/README.md)

> **Status (2026-05-12, Wave 7)**: meta-domain at
> **`SPEC_PLUS_RUNNABLE` closure** (see [`CLOSURE.md`](CLOSURE.md)).
> 5 files in `exynos/` + cross-doc audit shared with `terafab/`. Verb
> surface (29-verb / 6-group) and v1.0.0 closure verdict unchanged —
> Exynos is an *outer envelope*, not a new verb.

---

## Why this directory exists

Exynos is the second **meta-domain** in `hexa-chip` (sister to Wave 6's
`terafab/`). It anchors hexa-chip to the **Korean-fab heritage**:
40 years of Samsung Electronics IDM at scale (architecture · design ·
process · packaging · accelerator · consciousness), publicly disclosed
through Samsung Foundry Forum, Samsung IR, IEEE IEDM / VLSI Symposium
/ ISSCC, and Korean tech press. Zero NDA / proprietary content; every
claim traces to the `exynos.md` §15 source list and `sources.md`
citation database.

The two envelopes are **complementary**, not redundant:

- **Terafab** (Wave 6) = greenfield vertical megafab (Tesla/xAI/SpaceX +
  Intel 14A, announced 2026, $55–119 B prototype, zero-yield baseline
  at Mk.I).
- **Exynos** (Wave 7, this envelope) = brownfield IDM heritage (Samsung
  Electronics 40 years, ≈ ₩50 T 2024 capex, ≈ 11 % global foundry
  share, real-yield data, real revenue).

Both wrap the same 6 hexa-chip groups; both ship with a stdlib-only
Python verify harness; both register a falsifier preregister.
**hexa-chip's 29-verb spec surface is currently ≈ 2 maturity tiers
below the real Samsung Foundry surface, regardless of which envelope
you read** — this is the honest baseline.

---

## Files in this directory

Wave 7 landed. 5 files; aggregate ≈ 1,200 lines.

| File | Lines | Scope | Wave |
|---|---:|---|---|
| `exynos.md`         | ~580 | Main 15-section meta-domain document (WHY · COMPARE · REQUIRES · STRUCT · FLOW · VERIFY · EVOLVE · IDEAS · METRICS · RISKS · DEPENDENCIES · TIMELINE · TOOLS · TEAM · REFERENCES) | 7 |
| `verify_exynos.py`  | ~210 | Runnable falsifier checker — 7/7 HARD PASS + 6 DEFERRED, stdlib-only | 7 |
| `sources.md`        | ~280 | 14-source public citation database (SRC-EXYNOS-001..014) with key-claims + falsifier links | 7 |
| `CLOSURE.md`        | ~155 | Closure declaration — verdict `SPEC_PLUS_RUNNABLE`, 7-section honesty audit | 7 |
| `README.md`         | this | This navigation index | 7 |

**Out-of-directory cross-link artifacts**:

| File | Role |
|---|---|
| `../terafab/cross_doc_audit.py` | Extended at Wave 7 to also audit `[meta_domains.exynos]` (both envelopes share one harness) |
| `../hexa.toml`                  | `[meta_domains.exynos]` (Wave 7) + `[meta_domain_closure]` (Wave 7, envelopes 1→2 / falsifiers 10→17) |
| `../CATALOG.md`                 | T2 ENVELOPE table: exynos row upgraded `SPEC_FIRST` → `SPEC_PLUS_RUNNABLE` |

---

## Quick-recall facts

Condensed from `exynos.md` §1 "Headline anchors (sourced)" — public
Samsung disclosures only.

| key fact | value |
|---|---|
| Exynos brand launch        | 2010 (Galaxy S, Exynos 3110) |
| Current flagship           | Exynos 2400 (Galaxy S24, 2024-Q1) |
| Samsung Foundry rank       | #2 worldwide (TrendForce 2024-Q4, ≈ 11 %) |
| 2024 Samsung DS capex      | ≈ ₩50 T KRW (≈ $37 B USD) |
| SF2 GAA HVM target         | 2025-Q4 → 2026 |
| SF1.4 HVM target           | 2027 |
| Galaxy flagship cadence    | 24 mo (S24 2024-Q1 → S26 2026-Q1, J₂ = 24) |
| Advanced packaging family  | I-Cube (2021) / X-Cube (2020) / H-Cube |
| HBM line (Samsung Memory)  | HBM3E qualified 2024-Q4 |
| Terminal claim (Mk.VI)     | Galaxy-AI on-device gen-AI ≥ 10× cost-parity vs cloud (2033 audit) |

---

## Falsifier register summary

7 falsifiers total — F-EXYNOS-1..7 (in `exynos.md` §7).

▶ See `exynos.md` §7 for the full register and stdlib-only honesty
check; see `verify_exynos.py` for the dispatcher.

| ID | one-line claim | tier |
|---|---|---|
| F-EXYNOS-1 | Samsung Foundry remains a top-2 worldwide foundry through 2027 | Mk.I (IR/TrendForce) |
| F-EXYNOS-2 | SF2 GAA reaches HVM by 2026-Q4 per public roadmap | Mk.I (Forum) |
| F-EXYNOS-3 | Samsung captures ≥ 15 % foundry market share at SF1.4 by 2028-Q4 | Mk.II (long-horizon) |
| F-EXYNOS-4 | HBM4 ramp parity vs SK hynix at Samsung Memory DS by 2028 | Mk.II |
| F-EXYNOS-5 | Samsung Foundry not spun-off through 2029 | Mk.I (announcement) |
| F-EXYNOS-6 | SF1.0 HVM by 2030 per public node-shrink cadence | Mk.III (long-horizon) |
| F-EXYNOS-7 | n=6 lattice projection on Exynos figures beats chance (currently p ≈ 0.97 → reformulate Mk.II) | Mk.I → Mk.II |

---

## Runnable verification

Re-verify the meta-domain at any time (all stdlib-only, ~< 1 s each):

```
python3 exynos/verify_exynos.py                       # 7/7 HARD PASS, 6 DEFERRED
python3 terafab/cross_doc_audit.py                    # extended to also assert [meta_domains.exynos]
python3 verify_catalog.py                             # CATALOG.md ↔ hexa.toml ↔ filesystem agreement
```

`verify_exynos.py` reproduces:

- **Master identity** `σ·φ = n·τ = J₂ = 24` (n=6 perfectness).
- **Egyptian split** `1/2 + 1/3 + 1/6 = 1` (Fraction equality).
- **Samsung Foundry capex didactic** `₩50 T = ₩25 + ₩16.67 + ₩8.33`
  (Egyptian split applied to public 2024 capex).
- **Galaxy flagship cadence** S24 → S26 = `J₂ = 24` mo.
- **Node cadence** SF1.4 / SF2 = 0.7 (Moore's-law traditional ratio).
- **F-EXYNOS-1..7** register with documented numeric triggers
  (Mk.I → DEFERRED; F-EXYNOS-7 reports χ² ≈ 0.085 / p ≈ 0.97).

---

## Cross-link

- **Parent**: [`../README.md`](../README.md) — hexa-chip 29-verb /
  6-group baseline. The meta-domain does **not** add a verb; it wraps
  the 6 groups as an outer envelope.
- **Sister**: [`../terafab/README.md`](../terafab/README.md) — Musk
  vertical-megafab envelope (Wave 6.x). Same 15-section grammar,
  different anchor.
- **Counter-strategy**: [`../proposals/samsung-foundry-hexa-6stage.md`](../proposals/samsung-foundry-hexa-6stage.md)
  — Samsung counter-offer for which this envelope provides the
  historical-precedent context.
- **Manifest**: `../hexa.toml` `[meta_domains.exynos]` (envelope) +
  `[meta_domain_closure]` (verdict `SPEC_PLUS_RUNNABLE`,
  envelopes 1→2, falsifiers 10→17) — meta-domain registration
  (no verb addition; 29-verb / 6-group counts preserved).
- **Closure declaration**: [`CLOSURE.md`](CLOSURE.md) — full inventory,
  invariants asserted, honest caveats, what-not-claimed.
- **SSCB outreach dossier**: `~/core/ticket-out/07_outreach/_projects/hexa-chip-exynos.{en,ko}.md`
  — D-option full-source-coverage outreach dossier
  (built at Wave 7 via `build/tools/build_full_repo_en.sh` +
  `build_full_repo.sh`; forbidden-token redaction PASS; Korean residue
  in `.en.md` = 0). Target recipient: Samsung Foundry Forum / Samsung
  Electronics Memory Business / SK hynix / Korean academia
  (KAIST/SNU/POSTECH device labs) / IEEE EDS Korea Chapter.

---

## License

MIT — see [`../LICENSE`](../LICENSE).

Copyright (c) 2026 dancinlab (박민우 <nerve011235@gmail.com>).

---

## Provenance

Public-source absorption 2026-05-12. Wave 7 single commit:
- Wave 7 meta-domain absorption: exynos.md (15-section) + verify_exynos.py
  + sources.md + README.md + CLOSURE.md + `[meta_domains.exynos]` +
  `[meta_domain_closure]` envelopes 1→2 + extended `terafab/cross_doc_audit.py`
  + CATALOG.md T2 row update.

**Zero NDA / proprietary / Samsung-internal content.** Every numeric /
date traces to the `exynos.md` §15 reference list (Samsung Foundry
Forum public keynotes, Samsung IR public filings, DART KR public
filing portal, Wikipedia, The Elec, Korea Herald, Korea Times,
ZDNet Korea, TrendForce, Counterpoint, IDC, IEEE IEDM, VLSI Symposium,
ISSCC, TSMC/Intel public earnings-call competitor commentary).
Structured citation database in [`sources.md`](sources.md)
(14 entries, `SRC-EXYNOS-001..014`). Korean editorial tone is
heritage framing only — **no Samsung partnership, no NDA, no
proprietary data**.
