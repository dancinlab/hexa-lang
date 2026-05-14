<!-- @absorbed: 2026-05-12 -->
<!-- @sources: exynos/exynos.md §7 (locked triggers); exynos/sources.md (14-URL set) -->
<!-- @scope: data-arrival log; one row per (falsifier, quarter); pending until 2026-Q3 -->
<!-- @sister: terafab/mk2-observations.md (Wave G) — same grammar -->
---
type: mk2-observation-log
parent: exynos/exynos.md
target_window: 2026-Q3 ~ 2027-Q4
status: pending — SCAFFOLD (no data yet; all verdicts DEFERRED)
populated_by: exynos/poll_exynos_mk2.py (append-only)
consumed_by: exynos/verify_exynos.py (read_mk2_observations)
entries_per_falsifier: 1 SCAFFOLD row + 0..N polled rows
---

# Exynos — Mk.II Observations Log

> **Purpose**: append-only record of public-source observations against the
> `F-EXYNOS-1..7` falsifier register (`exynos/exynos.md` §7). Every
> trigger value here is **read** from the spec — no values are invented
> in this file. Until 2026-Q3 data lands, every row is `pending —
> SCAFFOLD — DEFERRED` and `verify_exynos.py` continues to report each
> falsifier as DEFERRED.
>
> **Goalpost-move protection**: rows are append-only. When a poll
> produces a new observation, `poll_exynos_mk2.py` appends a row beneath
> the SCAFFOLD row — it never deletes or rewrites history. The audit
> script (`terafab/cross_doc_audit.py` §E6) checks that the full set
> {F-EXYNOS-1, ..., F-EXYNOS-7} appears here and that every URL in
> §Source registry also lives in `exynos/sources.md`.

## Observations table

Columns:

- `Falsifier` — F-EXYNOS-N (1..7).
- `Quarter` — calendar quarter the observation belongs to (or `Mk.I` for
  the SCAFFOLD baseline row).
- `Public source URL` — the URL polled. `n/a (scaffold)` for the baseline.
- `Observation` — the extracted value (`pending` if no poll has landed).
- `Trigger value` — the locked threshold copied from
  `exynos/exynos.md` §7. **Do not edit in this file.**
- `Verdict` — `DEFERRED` | `WEAK_FAIL` | `HARD_FAIL` | `PASS` | `PENDING_REVIEW`.
- `Date logged` — ISO-8601 date the row was appended.

| Falsifier | Quarter | Public source URL | Observation | Trigger value | Verdict | Date logged |
|---|---|---|---|---|---|---|
| F-EXYNOS-1 | Mk.I | n/a (scaffold) | pending | Foundry quarterly revenue < ₩4 T KRW for 2 consecutive quarters by 2027-Q4 → HARD_FAIL | DEFERRED | 2026-05-12 |
| F-EXYNOS-2 | Mk.I | n/a (scaffold) | pending | SF2 HVM slips past 2027-Q2 (explicit roadmap pivot in public Forum keynote) → HARD_FAIL | DEFERRED | 2026-05-12 |
| F-EXYNOS-3 | Mk.I | n/a (scaffold) | pending | TrendForce / Counterpoint report < 10 % SF1.4 share through 2028-Q4 → HARD_FAIL | DEFERRED | 2026-05-12 |
| F-EXYNOS-4 | Mk.I | n/a (scaffold) | pending | SK hynix sustains > 2× Samsung HBM4 monthly bit-output through 2028-Q4 → HARD_FAIL | DEFERRED | 2026-05-12 |
| F-EXYNOS-5 | Mk.I | n/a (scaffold) | pending | Samsung Electronics announces foundry hive-down before 2029-Q4 → HARD_FAIL | DEFERRED | 2026-05-12 |
| F-EXYNOS-6 | Mk.I | n/a (scaffold) | pending | SF1.0 HVM slips past 2031-Q4 (public Forum confirmation) → HARD_FAIL | DEFERRED | 2026-05-12 |
| F-EXYNOS-7 | Mk.I | n/a (scaffold) | χ²=0.080 p=0.9081 (Mk.I weak) | reformulated p < 0.05 → PASS; p ≥ 0.5 → HARD_FAIL | DEFERRED | 2026-05-12 |

<!-- POLL-APPEND-MARKER: rows below this line are added by poll_exynos_mk2.py --><!-- never delete -->

## Polling schedule

Verbatim from `exynos/exynos.md` §11 (Mk.II~VI rollout cadence).
Do not edit this section directly; if the upstream cadence changes, copy
the updated table here in a *new* commit so history shows the move.

```
quarter  | falsifiers newly testable        | sources to monitor
---------+----------------------------------+----------------------------------------------
2026-Q3  | F-EXYNOS-1 (Foundry revenue Q3)  | Samsung IR Q3 release (typically late Oct),
         | F-EXYNOS-2 (SF2 Forum keynote)   |   Samsung Foundry Forum 2026 keynote (June)
2026-Q4  | F-EXYNOS-1 (Foundry revenue Q4)  | Samsung IR Q4 release (late Jan 2027),
         | F-EXYNOS-2 (SF2 HVM declaration) |   DART KR audited annual filing
2027-Q1  | F-EXYNOS-1 (refresh)             | TrendForce 2026-Q4 foundry-share tracker;
         | F-EXYNOS-3 (SF1.4 early share)   |   Korea Herald + The Elec + ZDNet Korea
2027-Q2  | F-EXYNOS-4 (HBM4 ramp parity)    | Samsung Memory DS IR + SK hynix IR;
         | F-EXYNOS-5 (spin-off watch)      |   Korean press rumour-tracker; DART filings
2027-Q3  | F-EXYNOS-7 (chi^2 first run)     | IEDM 2026 proceedings (Dec 2026) Exynos +
         |                                  |   SF2 GAA device papers; once ≥ 7 measured
         |                                  |   parameters land, run §4 chi^2 reformulation
2027-Q4  | F-EXYNOS-6 (SF1.0 long-horizon)  | Samsung Foundry Forum 2027; Intel earnings
         | F-EXYNOS-7 (chi^2 full run)      |   call SF1.0 vs Intel 14A framing; ISSCC
         |                                  |   2028 abstract list (Nov 2027 release)
```

## Source registry

Every URL the Mk.II poller knows about, tagged with which falsifier(s)
it informs. URLs are mirrored from `exynos/sources.md`
(`SRC-EXYNOS-001..014` `falsifier_links` field). New IR / DART / IEDM
targets land here as `SRC-EXYNOS-015+` once an Exynos-specific document
is publicly available against them (see `sources.md` §5).

```
src_id           | falsifiers informed              | url
-----------------+----------------------------------+--------------------------------------------------------------------------------
SRC-EXYNOS-001   | F1, F2, F3, F6                   | https://semiconductor.samsung.com/foundry/
SRC-EXYNOS-002   | F1, F3, F4, F5                   | https://www.samsung.com/global/ir/
SRC-EXYNOS-003   | F1, F5                           | https://dart.fss.or.kr
SRC-EXYNOS-004   | F2, F7                           | https://en.wikipedia.org/wiki/Exynos
SRC-EXYNOS-005   | F2, F3, F6                       | https://en.wikipedia.org/wiki/Samsung_Foundry
SRC-EXYNOS-006   | F1, F2, F4, F5                   | https://www.thelec.kr
SRC-EXYNOS-007   | F5                               | https://www.koreaherald.com/Tech
SRC-EXYNOS-008   | F5                               | https://www.koreatimes.co.kr/www/tech/index.asp
SRC-EXYNOS-009   | F2                               | https://zdnet.co.kr
SRC-EXYNOS-010   | F1, F3, F4, F7                   | https://www.trendforce.com
SRC-EXYNOS-011   | F1                               | https://www.counterpointresearch.com
SRC-EXYNOS-012   | F2, F7                           | https://ieee-iedm.org
SRC-EXYNOS-013   | F1, F3, F6                       | https://investor.tsmc.com/
SRC-EXYNOS-014   | F5, F6                           | https://www.intc.com/news-events/
```

## Extraction regex registry

Per `exynos/exynos.md` §7 trigger text: each F-EXYNOS-N falsifier maps to
a regex that pulls the headline number / phrase the trigger is gated on.
Falsifiers without a regex-extractable signal (F-EXYNOS-7, the χ²
aggregate) stay DEFERRED-locked at Mk.II — F-EXYNOS-7 is evaluated
inside `verify_exynos.py` against the §4 lattice slots, not from a URL
poll. Likewise F-EXYNOS-5 (foundry spin-off) and F-EXYNOS-6 (SF1.0 long-
horizon) become testable only on a *specific public announcement event*
— the regex matches the announcement phrasing, not a numeric threshold.

The columns are separated by `::` (not `|`) because Python regex bodies
contain `|` (alternation); using `::` keeps the table machine-parseable
without escape gymnastics.

```
falsifier    :: regex (Python re; case-insensitive)                          :: extracts
F-EXYNOS-1   :: r"(foundry|파운드리)[^.]{0,120}(?:KRW\s*)?(\d+(?:[.,]\d+)?)\s*(?:trillion|T)\b" :: Samsung Foundry quarterly revenue (₩T KRW)
F-EXYNOS-2   :: r"(SF2|2\s*nm)[^.]{0,80}(HVM|high.?volume|mass.?production|slip|delay)" :: SF2 HVM / slip wording
F-EXYNOS-3   :: r"(SF1\.4|1\.4\s*nm)[^.]{0,80}(\d{1,2}(?:\.\d+)?)\s*%"        :: SF1.4 foundry share (%)
F-EXYNOS-4   :: r"(HBM4)[^.]{0,80}(SK\s*hynix|Samsung)[^.]{0,40}(\d+(?:\.\d+)?)\s*(?:×|x|times)" :: HBM4 bit-output ratio
F-EXYNOS-5   :: r"(spin[-\s]?off|hive[-\s]?down|carve[-\s]?out|분사|독립법인)" :: foundry spin-off announcement phrasing
F-EXYNOS-6   :: r"(SF1\.0|1\.0\s*nm)[^.]{0,80}(HVM|mass.?production|2030|2031|slip|delay)" :: SF1.0 HVM / slip wording
F-EXYNOS-7   :: n/a (chi^2 in verify_exynos.py against exynos.md §4 slots)   :: residual array
```

## Honest caveats

- **Data may never arrive for some falsifiers in their current shape**.
  F-EXYNOS-5 (foundry spin-off watch) only flips on a *specific
  announcement event* — until 2029-Q4 the natural verdict is `pending —
  DEFERRED`, even with a healthy poll cadence. If Samsung announces a
  different corporate restructuring (e.g., memory hive-down rather than
  foundry), the honest response is to *retire F-EXYNOS-5 as
  scope-undefined*, **not** to invent a substitute trigger.
- **F-EXYNOS-6 (SF1.0 HVM by 2030) cannot resolve inside the Mk.II
  window**. SF1.0 is a 2030–2031 milestone; Mk.II only logs
  *trajectory* (Forum keynote phrasing, Intel earnings-call framing) —
  never a terminal verdict.
- **Korean-press URLs (006-009) are community / editorial sources**.
  The Mk.II poller treats Korean tech press as *corroborating*, not
  primary. Revenue / share / ramp claims in Korean press must be
  corroborated by at least one primary source (Samsung IR, DART, IEDM,
  TrendForce) before flipping a verdict.
- **Goalpost-move ratchet**: if a future commit attempts to *raise* a
  trigger threshold (e.g., move F-EXYNOS-1's HARD_FAIL from `<₩4T` to
  `<₩3T`) without a corresponding `exynos.md` §7 edit, the audit script
  (`terafab/cross_doc_audit.py`) MUST FAIL. Trigger text in this file
  is intended to be byte-identical to `exynos.md` §7.

---

**Provenance**: spec-locked; URLs mirrored from `sources.md`; no new
external claims. The Mk.II window opens 2026-Q3; until then every
verdict reads DEFERRED through `read_mk2_observations()` in
`verify_exynos.py`.
