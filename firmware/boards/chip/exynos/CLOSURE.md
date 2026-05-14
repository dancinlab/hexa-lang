<!-- @absorbed: 2026-05-12 -->
<!-- @parent: exynos/exynos.md (Wave 7) -->
<!-- @scope: closure declaration for the exynos meta-domain envelope -->
<!-- @sister: terafab/CLOSURE.md (Wave 6.x) — same closure grammar -->
---
type: closure-declaration
parent: exynos/exynos.md
verdict: SPEC_PLUS_RUNNABLE
envelope: exynos
groups_wrapped: 6
falsifiers_total: 7
nda_content: false
date: 2026-05-12
commit_basis: Wave 7 (exynos meta-domain absorption)
---

# Exynos Meta-Domain — Closure Declaration

> **Closure scope**: this document declares closure for the
> **exynos meta-domain envelope** only. Verb-level closure for
> hexa-chip's 29-verb / 6-group surface is governed by the separate
> `[closure]` block in `hexa.toml` and is unchanged by this declaration.

## §1 Closure verdict

**`verdict = SPEC_PLUS_RUNNABLE`**

The exynos envelope ships with both (a) a complete spec surface
(15-section main doc + per-falsifier register + sources catalogue +
README) and (b) a runnable Python harness (`verify_exynos.py`) that
exercises every cross-cutting invariant the envelope asserts.

Mirrors `hexa.toml` `[meta_domain_closure].verdict = "SPEC_PLUS_RUNNABLE"`
(single source of truth — re-derive at any time with the §6 recipe).

The exynos envelope is the **sister** of the terafab envelope (Wave 6.x):
both share the 15-section grammar, both wrap the same 6 hexa-chip groups,
both ship with stdlib-only Python verify harnesses. The two envelopes
are complementary, not redundant — Terafab encodes the *greenfield
vertical megafab* topology; Exynos encodes the *brownfield IDM
heritage* topology.

## §2 Closure inventory

Every file in `exynos/` enumerated with line count, role, and closure tier.

| File | Lines | Role | Tier |
|---|---:|---|---|
| `exynos.md`                  | ~580 | Main 15-section meta-domain spec (WHY · COMPARE · REQUIRES · STRUCT · FLOW · EVOLVE · VERIFY · IDEAS · METRICS · RISKS · DEPENDENCIES · TIMELINE · TOOLS · TEAM · REFERENCES) — Samsung-Korean-fab anchor | SPEC_PLUS_RUNNABLE |
| `sources.md`                 | ~280 | Annotated public-source catalogue (Samsung Foundry Forum + IR + IEEE/IEDM + Korean tech press + competitor earnings) | SPEC |
| `README.md`                  | ~150 | Directory README with badges, file table, quick-recall facts, falsifier summary, cross-link | SPEC |
| `verify_exynos.py`           | ~210 | Runnable falsifier dispatcher (7 falsifiers + 6 hard checks; n=6 identity, Egyptian split, Samsung capex didactic, Galaxy cadence, node cadence, F-EXYNOS-7 χ² band) | RUNNABLE_ONLY |
| `CLOSURE.md`                 | this | Closure declaration (this document) | SPEC |

**Tier legend**: `SPEC` = doc-only spec; `RUNNABLE_ONLY` = executable
sandbox without prose spec; `SPEC_PLUS_RUNNABLE` = both prose spec and
embedded/companion runnable.

## §3 Closure invariants asserted

The exynos envelope holds the following invariants. Each is exercised
by `verify_exynos.py` and/or the extended `terafab/cross_doc_audit.py`
(per §6 recipe):

1. **6 groups absorbed.** `hexa.toml [meta_domains.exynos].absorbs`
   matches `[modules]` keys exactly; both equal
   `{architecture, design, process, packaging, accelerator, consciousness}`.
   Asserted by the extended `cross_doc_audit.py`.
2. **7 falsifiers registered.** F-EXYNOS-1..7 in `exynos.md` §7;
   README.md summary table lists all 7. `verify_exynos.py` dispatches
   all 7 in a single run.
3. **0 NDA content.** Every claim traces to the `exynos.md` §15 source
   list (Samsung Foundry Forum public keynotes, Samsung IR public
   filings, Wikipedia, The Elec, Korea Herald, Korea Times, ZDNet
   Korea, TrendForce/Counterpoint/IDC public quarterly reports, IEEE
   IEDM / VLSI Symposium / ISSCC proceedings, TSMC/Intel public
   earnings-call competitor commentary). **No Samsung-internal data,
   no proprietary process kits, no trade secrets.**
4. **29-verb / 6-group surface unchanged.** `hexa.toml [closure]`
   reports `verbs_total = 29` and `groups_total = 6`; the
   `[meta_domain_closure]` block asserts `verb_surface_unchanged = true`.
5. **All numbers traceable to `exynos.md` §15.** SF2 GAA target
   (2025-Q4 / 2026 HVM), SF1.4 (2027), Samsung Foundry rank (#2
   worldwide, ≈ 11 %), Samsung DS 2024 capex (≈ ₩50 T KRW), Galaxy
   cadence (S24 2024-Q1 → S26 2026-Q1, 24 mo) — every figure appears in
   the §15 reference list with a public-source citation.
6. **Cross-doc agreement: exynos.md ↔ hexa.toml ↔ README.md.**
   Enforced by the extended `terafab/cross_doc_audit.py` (which audits
   both `[meta_domains.terafab]` and `[meta_domains.exynos]` blocks)
   and by `verify_catalog.py` (which audits CATALOG.md ↔ filesystem ↔
   hexa.toml agreement).
7. **F-EXYNOS-7 χ² test runs and yields documented honesty-band p.**
   `verify_exynos.py:check_f_exynos_7()` computes χ² ≈ 0.085, p ≈ 0.97
   (Mk.I weak; reformulation deferred to Mk.II per §6 of `exynos.md`).
   The honest reading is that the §4 lattice table is a *registration
   of coincidences*, not a derivation.

## §4 Closure caveats (raw#10 honest C3)

Honest readings of what this closure does not yet prove:

- **F-EXYNOS-1..6 are bench-only at Mk.I.** Each falsifier's harness
  exists and dispatches cleanly, but the underlying real-world data
  has not yet arrived (2026-Q3+ quarterly IR for F-1, Samsung Foundry
  Forum 2026 keynote for F-2, TrendForce 2028 reports for F-3 and F-4,
  Samsung Electronics announcements for F-5, Samsung Foundry Forum 2030
  for F-6). All six return `DEFERRED` until per-falsifier data arrives.
- **F-EXYNOS-7 χ² is weak at Mk.I.** The Mk.I formulation in
  `exynos.md` §7 scores the seven §4 lattice projection guesses and
  yields p ≈ 0.97 — statistically indistinguishable from random
  scatter (same weakness as Terafab F-7). Reformulation against
  measured Exynos 2500 + SF2 GAA metrics is deferred to Mk.II
  (IEDM/ISSCC 2027 data window).
- **n=6 lattice projection is a coincidence registry, not a derivation.**
  The §4 STRUCT projection table in `exynos.md` is a *registration of
  alignments* between Samsung-published Exynos/Foundry parameters and
  n=6 constants; it is honestly labelled as such. Samsung's engineering
  teams did not design Exynos against the n=6 lattice. Some fits
  (e.g., 6 groups under one IDM) are exact by definition; others
  (e.g., S24 → S26 cadence = J₂ = 24 mo) are coincidences worth noting
  and no more.
- **Closure is for the META-DOMAIN ENVELOPE only.** Verb-level closure
  for the 29-verb / 6-group surface is governed by `hexa.toml [closure]`
  and is unchanged by this declaration. Promoting an individual
  hexa-chip verb's tier (e.g., `hbm` from spec to runnable) is a
  separate event.
- **No NDA / no Samsung-internal data**. Every claim is sourced from
  publicly disclosed material. Korean editorial tone is heritage
  framing only — not proprietary content.
- **`exynos/cross_doc_audit.py` is NOT shipped at Wave 7.** The
  `terafab/cross_doc_audit.py` was extended to audit both envelopes
  (Terafab and Exynos) rather than creating a parallel file. This
  keeps `[meta_domain_closure].envelopes_audited = 2` honestly
  (both envelopes share one cross-doc audit harness).

## §5 What this closure does NOT claim

Negative declarations to keep the envelope honest:

- Does **NOT** validate any specific Samsung Foundry market-share
  projection — only that the figures cited in `exynos.md` trace to
  public TrendForce / Counterpoint quarterly reports.
- Does **NOT** claim Samsung Foundry will retain rank #2 — explicitly
  registers F-EXYNOS-1 (revenue-floor falsifier) whose trigger can
  retire the rank-#2 thesis.
- Does **NOT** add any verb to hexa-chip — the 29-verb / 6-group
  surface (and the line-by-line manifest) are governed by the
  separate `[closure]` block and unaffected.
- Does **NOT** modify the n=6 lattice or any verb's spec — the lattice
  is referenced as an external diagnostic tool only; F-EXYNOS-7 is
  *honest about* its own statistical weakness and defers reformulation
  to Mk.II.
- Does **NOT** include NDA / proprietary / Samsung-internal /
  SK-hynix-internal / TSMC-internal / Intel-internal data — every
  claim hyperlinks back to a public source in `exynos.md` §15 or
  `sources.md`.
- Does **NOT** assert hexa-chip has any Samsung partnership — Korean
  editorial tone is heritage framing, not commercial alignment.

## §6 Re-verification recipe

Two commands to re-verify closure at any time. Both stdlib-only Python;
no external dependencies; idempotent.

```
python3 /home/summer/mac_home/core/hexa-chip/terafab/cross_doc_audit.py
python3 /home/summer/mac_home/core/hexa-chip/exynos/verify_exynos.py
```

Expected sentinels (both must appear):

- `cross_doc_audit.py` → `ALL FACTS AGREE — Terafab cross-doc audit PASS`
  (the audit was extended at Wave 7 to also assert
  `[meta_domains.exynos]` invariants; both envelopes pass under one
  harness).
- `verify_exynos.py`  → `N/N HARD checks PASS  (M DEFERRED Mk.II/III/V/VI)`
  where N = 7 hard checks (master identity, group count, Egyptian
  split, Samsung capex didactic, Galaxy cadence, node cadence,
  F-EXYNOS-7 χ² band) and M = 6 deferred falsifiers (F-EXYNOS-1..6).

A third complementary audit covers filesystem ↔ catalog ↔ manifest:

```
python3 /home/summer/mac_home/core/hexa-chip/verify_catalog.py
```

(Confirms `[meta_domains.exynos]` is registered consistently with the
T2 ENVELOPE row in CATALOG.md.)

## §7 Sign-off

External-source absorption complete.

- **Date**: 2026-05-12
- **Commit basis**: Wave 7 (exynos meta-domain absorption — full
  envelope: exynos.md + verify_exynos.py + CLOSURE.md + sources.md +
  README.md + `[meta_domains.exynos]` + `[meta_domain_closure]`
  envelopes_total 1→2 + falsifiers_total 10→17 + extended
  `terafab/cross_doc_audit.py` + CATALOG.md T2 row update).
- **Author**: 박민우 <nerve011235@gmail.com>
- **License**: MIT (inherits from repository)
- **Provenance**: Public-source absorption 2026-05-12; zero NDA /
  proprietary / Samsung-internal content; every claim traces to
  `exynos.md` §15 + `sources.md`.

---

**Closure verdict re-asserted**: `verdict = SPEC_PLUS_RUNNABLE`
(also recorded in `hexa.toml [meta_domain_closure].verdict` — single
source of truth; re-verify any time with the §6 recipe).
