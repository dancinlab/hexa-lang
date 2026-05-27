<!-- @absorbed: 2026-05-12 -->
<!-- @sources: exynos/exynos.md §7, exynos/mk2-observations.md, exynos/sources.md -->
<!-- @scope: operator's manual — how to use the Exynos Mk.II monitoring stack -->
<!-- @sister: terafab/MK2.md (Wave G) -->
---
type: operator-manual
parent: exynos/exynos.md
window: 2026-Q3 → 2027-Q4
status: scaffold-ready (no Mk.II data yet)
runtime_files:
  - exynos/poll_exynos_mk2.py
  - exynos/mk2-observations.md
  - exynos/mk2-poll.log     # gitignored
---

# Exynos — Mk.II Monitoring Operator's Manual

> One-page operator manual for the Exynos Mk.II falsifier monitoring
> stack. If you only read one paragraph: run
> `python3 exynos/poll_exynos_mk2.py` to see the current state;
> `--check` for JSON; `--dry-run` to see what `--poll` would fetch;
> `--poll` once per quarter at quarter end. Everything is append-only
> — observations never get deleted or rewritten, only added beneath the
> SCAFFOLD baseline rows.

## §1 What this stack is for

Until 2026-Q3, the 7 Exynos falsifiers (`F-EXYNOS-1..7`, registered in
[`exynos.md`](./exynos.md) §7) are *bench-only* — they are well-formed
propositions, but the public-source data needed to evaluate them does
not yet exist for the Mk.II window (which opens around Samsung's
2026-Q3 IR release / Samsung Foundry Forum 2026). The Mk.II stack is
the data-arrival pipeline that turns these propositions into evaluable
verdicts once the data does land.

The three files in this stack:

- **`exynos.md`** §7 — source-of-truth: the 7 falsifiers, their numeric
  triggers, the χ² recipe, the Mk.II~VI rollout cadence. Locked.
- **`mk2-observations.md`** — append-only log: SCAFFOLD baseline rows +
  every polled observation. Read by `verify_exynos.py`.
- **`poll_exynos_mk2.py`** — the runner: parses the observation log,
  optionally hits URLs, writes new rows. Logs cycle events to
  `mk2-poll.log`.

## §2 When to run

### Every commit / CI

```
python3 exynos/verify_exynos.py            # 7 HARD + per-falsifier read
python3 terafab/cross_doc_audit.py         # spec ↔ obs ↔ sources cross-check
python3 exynos/poll_exynos_mk2.py          # default no-network summary
```

These three should run on every CI cycle. They make no network calls
and should never fail under normal scaffold conditions. The cross-doc
audit checks both terafab and exynos sister envelopes in one pass; if
it fails with "mk2-observations.md falsifier set mismatch" for
`F-EXYNOS-*`, someone has edited the observation table by hand in a
way that broke the {F-EXYNOS-1..7} invariant — fix the table before
committing.

### Once per quarter (operator action or `mk2-poll.yml` cron)

At the end of each calendar quarter beginning **2026-Q3**, run:

```
python3 exynos/poll_exynos_mk2.py --dry-run     # sanity-check URLs + regexes
python3 exynos/poll_exynos_mk2.py --poll        # actually fetch + append rows
```

The `--poll` mode appends a new row per (falsifier, source) pair where
the registered regex matches the fetched page. Polled rows always
arrive with verdict `PENDING_REVIEW` — a human must read the appended
row, decide whether the extracted value crosses the trigger, and add a
follow-up row with the final verdict (`PASS` / `WEAK_FAIL` /
`HARD_FAIL`). **The poller does not flip verdicts by itself.**

The `.github/workflows/mk2-poll.yml` workflow runs this automatically
on the 1st of Jan/Apr/Jul/Oct at 09:00 UTC. If new rows are written,
the workflow opens a PR titled `Mk.II observation update YYYY-Qn`
labelled `auto-poll`, `falsifier-mk2`.

### Never (do not do this)

- Do not edit `mk2-observations.md` to delete a SCAFFOLD baseline row.
- Do not edit the `Trigger value` column — those are locked from
  `exynos.md` §7; changing them is goalpost-moving.
- Do not commit `exynos/mk2-poll.log` (it is gitignored).
- Do not invent observation rows for falsifiers without a registered
  regex (F-EXYNOS-7 stays DEFERRED-locked at Mk.II — its χ² is
  evaluated inside `verify_exynos.py` against the `exynos.md` §4
  lattice slots, not from a URL poll).

## §3 Reading the output

### Default mode

```
 falsifier      verdict    sources  regex?
 ------------------------------------------------------------
 F-EXYNOS-1     DEFERRED   6        yes
 F-EXYNOS-2     DEFERRED   5        yes
 ...
 F-EXYNOS-7     DEFERRED   3        no (DEFERRED-locked)
```

- `verdict` — the latest verdict for this falsifier (last row wins).
  Mk.I state: all `DEFERRED`.
- `sources` — how many URLs in the registry inform this falsifier.
- `regex?` — `yes` if a regex was registered; `no (DEFERRED-locked)`
  if not (F-EXYNOS-7 is the χ² aggregate evaluated in
  `verify_exynos.py`).

### `--check` mode (JSON)

Emits `{schema, generated, verdicts, row_count}`. Use this for piping
into other tools (dashboards, alerting). Schema version is
`exynos.mk2.verdict.v1`.

### `--dry-run` mode

Lists every URL + regex that `--poll` would use, grouped by falsifier.
Marked `[FETCH]` if both URL and regex exist; `[SKIP]` otherwise. Run
this **before** every quarterly `--poll` to catch typos / dead URLs.

### `--poll` mode (live)

Fetches each `[FETCH]` URL with `urllib.request`, applies the
registered regex, and appends a row to `mk2-observations.md` for
every match. Failures are logged to `mk2-poll.log` (timestamped). Does
not raise on network errors — the next quarter's poll will retry.

### `--smoke` mode (CI infra test)

Gated behind `HEXA_EXYNOS_MK2_SMOKE=1` env var. Appends ONE synthetic
`F-EXYNOS-1` row labelled `SMOKE — DO NOT TREAT AS REAL` so the
`mk2-poll.yml` git-diff detector can be exercised end-to-end before
2026-Q3 real data lands. Always revert the synthetic row before
merging to main.

## §4 Per-falsifier interpretation cheat-sheet

| ID | What "PASS" means | What "FAIL" means | Earliest testable | Goalpost-move guard |
|---|---|---|---|---|
| F-EXYNOS-1 | Samsung Foundry quarterly revenue ≥ ₩4 T KRW through 2027 | < ₩4 T KRW for 2 consecutive quarters by 2027-Q4 | 2026-Q3 (Samsung IR) | trigger must read `<₩4T` — any softer threshold breaks the audit |
| F-EXYNOS-2 | SF2 GAA HVM declared on schedule (2026-Q4) | SF2 HVM slips past 2027-Q2 (Forum keynote) | 2026-Q3 (Forum 2026) | regex must match "HVM" / "slip" wording exactly |
| F-EXYNOS-3 | SF1.4 share ≥ 15 % by 2028-Q4 | TrendForce reports < 10 % SF1.4 share through 2028-Q4 | 2027-Q1 (first SF1.4 tape-out) | TrendForce / Counterpoint only; rumour-tracker doesn't count |
| F-EXYNOS-4 | HBM4 ramp parity vs SK hynix by 2028 | SK hynix sustains > 2× monthly bit-output through 2028-Q4 | 2027-Q2 (Samsung Memory IR) | "monthly bit-output" must be the metric — not revenue |
| F-EXYNOS-5 | No foundry spin-off announced through 2029 | Samsung Electronics announces hive-down before 2029-Q4 | 2026-Q4 (announcement event) | announcement-event-driven — regex matches "spin-off"/"hive-down"/"분사" |
| F-EXYNOS-6 | SF1.0 HVM on schedule (2030) | SF1.0 HVM slips past 2031-Q4 (Forum confirmation) | 2027-Q4 (Forum 2027) | long-horizon — Mk.II only logs trajectory, not terminal verdict |
| F-EXYNOS-7 | χ² p < 0.05 (lattice beats chance) | χ² p ≥ 0.5 (retire lattice as coincidence) | 2027-Q3 (IEDM 2026 publication) | run via `verify_exynos.py` against `exynos.md` §4 slots only |

## §5 Failure modes + recovery

- **Samsung IR site restructured** — SRC-EXYNOS-002 layout changes.
  Recovery: poll DART (SRC-EXYNOS-003) which is government-regulated
  and structurally stable. F-EXYNOS-1 / F-EXYNOS-4 / F-EXYNOS-5 lose
  their fastest mirror but stay testable.
- **TrendForce paywall hardens** (SRC-EXYNOS-010) — F-EXYNOS-1/3/4
  lose the canonical foundry-share signal. Recovery: cross-reference
  Counterpoint (SRC-EXYNOS-011) plus Korean press echoes (006-009)
  for the same quarterly delta; require both for verdict flip.
- **Foundry spin-off announced with NDA terms** — F-EXYNOS-5 trigger
  fires but with public-source-only confirmation. The Mk.II stack
  records the announcement; any NDA-tier detail stays out of the
  observation log per project policy (`nda_content: False` invariant).
- **Korean press takedown / paywall** — non-fatal; primary Samsung IR
  + DART + TrendForce/Counterpoint + IEDM cover every falsifier
  without Korean press. Korean press is *corroboration*, not primary.
- **Network unavailable during `--poll`** — non-fatal; logged as
  `fetch fail` per URL. Run again at next quarter end.
- **`gh pr create` fails inside `mk2-poll.yml`** — the workflow has
  already committed the polled rows to a feature branch (`mk2-poll/
  YYYY-Qn`); fix the PR creation issue (token permissions, label
  presence) and re-run `workflow_dispatch`, or open the PR manually.

## §6 PASS vs FAIL vs goalpost-move

| signal | what it looks like | how the stack treats it |
|---|---|---|
| **PASS** | observation falls clearly inside the trigger | operator appends row with verdict `PASS`; `verify_exynos.py` surfaces as `OK` |
| **WEAK_FAIL** | observation crosses a weaker threshold but not the hard | operator appends row with verdict `WEAK_FAIL`; surfaces as `DEFERRED` (not yet decisive) |
| **HARD_FAIL** | observation crosses the hard threshold | operator appends row with verdict `HARD_FAIL`; surfaces as `FAIL` and breaks CI |
| **goalpost-move (NOT ALLOWED)** | someone edits the `Trigger value` column in `mk2-observations.md` after data has landed | `terafab/cross_doc_audit.py` MUST detect via the {F-EXYNOS-1..7} invariant check; if it doesn't, that's an audit bug to fix |

## §7 Cross-references

- [`exynos.md`](./exynos.md) §7 — locked trigger thresholds + χ² recipe.
- [`mk2-observations.md`](./mk2-observations.md) — the append-only log
  this manual operates on.
- [`sources.md`](./sources.md) — `SRC-EXYNOS-001..014` URL registry.
- [`verify_exynos.py`](./verify_exynos.py) — reads
  `mk2-observations.md` via `read_mk2_observations()` (Wave H).
- [`../terafab/cross_doc_audit.py`](../terafab/cross_doc_audit.py) —
  enforces spec ↔ observations ↔ sources agreement (Wave H §E6).
- [`../terafab/MK2.md`](../terafab/MK2.md) — sister envelope's
  operator's manual.

---

**Provenance**: operator's manual; zero new external claims. All
thresholds, regexes, and source URLs in this document mirror their
locked counterparts in `exynos.md` §7 and `sources.md`.
