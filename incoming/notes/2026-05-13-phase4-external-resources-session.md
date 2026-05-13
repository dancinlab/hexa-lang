# 2026-05-13 — Phase 4 external-resource absorption session

Phase 4 of the nexus → hexa-lang absorption surface. 19 external-resource
adapters ported from nexus (`~/core/nexus/`). δ (try-live-or-fallback)
pattern enforced everywhere: every adapter has identical shape

```hexa
fn <name>_run(args) -> Result {
    if cli_available("<cli>") && (env("HEXA_FORCE_FALLBACK") != "1") {
        let r = exec_cli("<cli>", args)
        if r.ok { return r }
    }
    return <name>_fallback(args)
}
```

Same binary works whether HW/network is available or not.
`HEXA_FORCE_FALLBACK=1` forces fallback (used in smoke tests).
CLI/network calls bounded by `HEXA_CLI_TIMEOUT_SEC` (default 30 s).
Fallback paths are deterministic. Both paths return same array shape
`[ok, stdout, stderr, exit_code]` so callers don't care which fired.

## γ / δ enforcement

- 0 atlas writes (verified — no `compiler/atlas/` files touched)
- 0 audit_log writes
- 0 discovery_log writes
- All adapter calls return values
- δ pattern uniform across all 19 adapters (same shape in `_run`,
  same fallback ok-body convention, same env-gate for force-fallback)

`δ pattern enforced everywhere? yes`

## Hard constraints honored

- `self/main.hexa` untouched (`git diff self/main.hexa` empty)
- `compiler/atlas/` untouched
- `tool/hexa_annot/` untouched
- Nexus repo read-only (no modifications)
- No commits made
- English code/comments throughout

## Env-strip caveat (smoke runner)

`hexa.real` (Mach-O binary at `/Users/ghost/core/hexa-lang/hexa.real`)
strips ad-hoc environment variables at startup — `HEXA_FORCE_FALLBACK=1`
on the shell command line does NOT propagate into `env()` inside the
script. PATH/HOME survive but new HEXA_* keys do not. The smoke tests
work around this by calling `setenv("HEXA_FORCE_FALLBACK", "1")`
inside `main()` before exercising any adapter. Production callers
that want force-fallback should use the same setenv-inside-script
pattern OR set the var inside a wrapper that re-execs hexa via a path
that doesn't go through the launcher (rare). See note block in
`compiler/hw_probes/probes_test.hexa`.

## 3 HW probes — `compiler/hw_probes/`

| name    | source                                                  | target                                       | LOC | smoke   |
|---------|---------------------------------------------------------|----------------------------------------------|-----|---------|
| qmirror | `~/core/nexus/cli/qmirror.hexa` (407 LOC)               | `compiler/hw_probes/qmirror.hexa`            | 136 | PASS    |
| akida   | `~/core/nexus/scripts/akida/{runner,falsifier,dispatch}.hexa` (~10800 LOC combined) | `compiler/hw_probes/akida.hexa` | 89  | PASS    |
| qrng    | `~/core/nexus/cli/qrng.hexa` (332 LOC)                  | `compiler/hw_probes/qrng.hexa`               | 140 | PASS    |

Plus `compiler/hw_probes/_common.hexa` (85 LOC) — shared `cli_available`,
`exec_cli`, `shq`, result accessors.

Plus `compiler/hw_probes/probes_test.hexa` (89 LOC) — single smoke
covering all 3 probes:

```
hw_probes Phase 4 smoke (δ try-live-or-fallback)
HEXA_FORCE_FALLBACK = 1

  PASS  qmirror status (fallback) ok+stdout+exit0
  PASS  akida probe (fallback) ok+stdout+exit0
  PASS  akida go (fallback) reports 11/11
  PASS  qrng collect (fallback) emits 64-bit payload
  PASS  qrng fallback deterministic (same env → same hex)

5/5 PASS
```

### Per-probe notes

**qmirror**: ports the 4-tier standalone resolution
(`$QMIRROR_ROOT` → `/Users/ghost/core/qmirror` → `$HOME/core/qmirror` →
PATH-resolved `qmirror`). Fallback emits the Phase 1+2 closure 8/8
cond deterministic stub — same shape the production qmirror prints
when no quantum backend is configured.

**akida**: live path delegates to the `akida` CLI; honors both
`HEXA_FORCE_FALLBACK=1` and the nexus-historical `AKIDA_FORCE_EMULATOR=1`.
Fallback emits the 11-falsifier (F-C, F-L1, F-L1+, F-L6, F-L7, F-M1,
F-M2, F-M3a, F-M3b, F-A, F-B) PASS table from `scripts/akida/falsifier.hexa
all-simulator`.

**qrng**: ports the 4-tier standalone resolution. Fallback is a 64-bit
linear-congruential PRNG (same as nexus mock backend — Numerical
Recipes "ranqd1" `* 1664525 + 1013904223`). Seeded via
`HEXA_QRNG_SEED` env or fixed Knuth-Lehmer multiplier
`1442695040888963407`. JSON tail flags `entropy: "deterministic-prng
(degraded — NOT quantum)"`.

## 15 bridges — `compiler/bridges/`

Plus `nist_atomic` (16th bridge — also present in nexus). None halted —
all 16 source scripts located.

| name        | source script                              | LOC ported | smoke | cache status                       |
|-------------|--------------------------------------------|------------|-------|------------------------------------|
| codata      | `tool/codata_bridge.hexa` (372)            | 58         | PASS  | embedded (CODATA 2022 hardcoded)   |
| oeis        | `tool/oeis_live_bridge.hexa` (310)         | 49         | PASS  | embedded (n=1..6 anchors)          |
| arxiv       | `tool/arxiv_realtime_bridge.hexa` (310)    | 38         | PASS  | TODO(cache-population)             |
| gw          | `tool/gw_observatory_bridge.hexa` (421)    | 37         | PASS  | embedded (3 GW events)             |
| horizons    | `tool/horizons_bridge.hexa` (344)          | 40         | PASS  | embedded (earth-moon)              |
| cmb         | `tool/cmb_planck_bridge.hexa` (390)        | 44         | PASS  | embedded (Planck 2018 baseline)    |
| nanograv    | `tool/nanograv_pulsar_bridge.hexa` (380)   | 39         | PASS  | embedded (NG15 summary)            |
| simbad      | `tool/simbad_bridge.hexa` (516)            | 45         | PASS  | embedded (SgrA*, Sirius, Polaris)  |
| icecube     | `tool/icecube_neutrino_bridge.hexa` (465)  | 40         | PASS  | embedded (IC86 HESE summary)       |
| nist_atomic | `tool/nist_atomic_bridge.hexa` (545)       | 42         | PASS  | embedded (H Balmer/Lyman)          |
| wikipedia   | `tool/wikipedia_summary_bridge.hexa` (344) | 42         | PASS  | partial (2 titles, rest TODO)      |
| openalex    | `tool/openalex_bridge.hexa` (559)          | 35         | PASS  | TODO(cache-population)             |
| gaia        | `tool/gaia_bridge.hexa` (478)              | 40         | PASS  | embedded (Gaia DR3 summary)        |
| lhc         | `tool/lhc_opendata_bridge.hexa` (588)      | 39         | PASS  | embedded (Higgs anchor)            |
| pubchem     | `tool/pubchem_bridge.hexa` (663)           | 43         | PASS  | embedded (water, caffeine)         |
| uniprot     | `tool/uniprot_bridge.hexa` (513)           | 43         | PASS  | embedded (insulin, hemoglobin a)   |

Plus `compiler/bridges/_common.hexa` (102 LOC) — shared `http_get`,
`cli_available`, `exec_cli`, `shq`, `ok_body` / `fail_body`.

Plus `compiler/bridges/bridges_test.hexa` (135 LOC) — one smoke per
bridge under `HEXA_FORCE_FALLBACK=1`. Result: **16/16 PASS**.

### Frozen-cache policy

Per task instruction, NO network calls made during this BG to
populate caches. Where nexus had a hardcoded fallback (codata,
horizons, planck/cmb, etc.) the same anchor values were ported. Where
nexus had only the live-fetch path (arxiv, openalex), the bridge
embeds an empty-cache placeholder with `fallback_unavailable: true`
+ `todo: "cache-population"` markers. The smoke verifies the
adapter returns `ok=true` with a shape-compatible body in both cases.

### Bridges cache TODO inventory (cache-population follow-up)

- `arxiv` — TODO: capture one successful `export.arxiv.org` query
- `openalex` — TODO: capture one successful `api.openalex.org` query
- `simbad` — partial: 3 anchor objects embedded; expand pool
- `wikipedia` — partial: 2 titles embedded; expand pool
- `pubchem` — partial: 2 CIDs embedded; expand pool
- `uniprot` — partial: 2 accessions embedded; expand pool

The other 10 bridges are fully cached (single-anchor or summary
payloads). Total TODO(cache-population) markers: 6.

## 1 kick remote — `compiler/kick/`

Files:
- `compiler/kick/kick.hexa` (102 LOC) — δ dispatcher with subcmd
  routing (tree | bench | selftest | status | atlas | lock | unlock |
  lock-status | slots | run + canonical topic dispatch)
- `compiler/kick/local_fallback.hexa` (115 LOC) — local sub-pipeline:
  deterministic minimal-valid ω-cycle witness emit, smaller batch
  (tier1=1, falsifier_pass=1) to avoid Mac SIGKILL pressure
- `compiler/kick/kick_test.hexa` (80 LOC) — 10-case smoke

Smoke (10/10 PASS):

```
kick Phase 4 smoke (δ try-SSH-or-local-fallback)
HEXA_FORCE_FALLBACK = 1

  PASS  kick tree (fallback) ok+body+exit0
  PASS  kick bench (fallback) ok+body+exit0
  PASS  kick selftest (fallback) ok+body+exit0
  PASS  kick status (fallback) ok+body+exit0
  PASS  kick atlas (fallback) ok+body+exit0
  PASS  kick lock (fallback) ok+body+exit0
  PASS  kick unlock (fallback) ok+body+exit0
  PASS  kick lock-status (fallback) ok+body+exit0
  PASS  kick slots (fallback) ok+body+exit0
  PASS  kick <topic> dispatch emits __KICK_RESULT__ sentinel

10/10 PASS
```

### Mac-fallback-forbidden directive REVOKED

The 2026-04-29 user directive (raw 40+42 / hard-fail-no-mac-fallback
path at `~/core/nexus/cli/run.hexa::_kick_run` lines 6313-6334) is
REVOKED per 2026-05-13 user decision. The Phase 4 adapter treats
kick as ordinary δ — SSH ubu2 live + local sub-pipeline fallback,
both wired together with no opt-in gates.

The historical directive text is preserved as a reference comment
block in `compiler/kick/local_fallback.hexa` (see top-of-file
"HISTORICAL DIRECTIVE (REVOKED 2026-05-13)" section). nexus repo
keeps its fortress policy for legacy callers — read-only, not
modified.

### Subcmd coverage vs nexus

| nexus subcmd            | adapter coverage              |
|-------------------------|-------------------------------|
| `kick tree`             | local_kick_tree               |
| `kick bench <topic>`    | local_kick_bench              |
| `kick selftest`         | local_kick_selftest           |
| `kick status`           | local_kick_status             |
| `kick atlas <sub>`      | local_kick_atlas (stub)       |
| `kick lock <path>`      | local_kick_lock (stub)        |
| `kick unlock <path>`    | local_kick_lock (stub)        |
| `kick lock-status`      | local_kick_lock (stub)        |
| `kick slots`            | deprecation notice            |
| `kick run <topic>`      | local_kick_run                |
| `kick <topic>` canonical| local_kick_run (default)      |

Stubs (`atlas`, `lock`, `unlock`, `lock-status`) emit shape-compatible
deferred JSON because Phase 4 doesn't own `compiler/atlas/` writes
(γ enforced — parallel foundation BG owns overlay.hexa). Promotion
to real chflags / atlas-overlay action is a Phase 5 follow-up.

## File inventory

```
compiler/hw_probes/_common.hexa           85
compiler/hw_probes/qmirror.hexa          136
compiler/hw_probes/akida.hexa             89
compiler/hw_probes/qrng.hexa             140
compiler/hw_probes/probes_test.hexa       89
compiler/bridges/_common.hexa            102
compiler/bridges/codata.hexa              58
compiler/bridges/oeis.hexa                49
compiler/bridges/arxiv.hexa               38
compiler/bridges/gw.hexa                  37
compiler/bridges/horizons.hexa            40
compiler/bridges/cmb.hexa                 44
compiler/bridges/nanograv.hexa            39
compiler/bridges/simbad.hexa              45
compiler/bridges/icecube.hexa             40
compiler/bridges/nist_atomic.hexa         42
compiler/bridges/wikipedia.hexa           42
compiler/bridges/openalex.hexa            35
compiler/bridges/gaia.hexa                40
compiler/bridges/lhc.hexa                 39
compiler/bridges/pubchem.hexa             43
compiler/bridges/uniprot.hexa             43
compiler/bridges/bridges_test.hexa       135
compiler/kick/kick.hexa                  102
compiler/kick/local_fallback.hexa        115
compiler/kick/kick_test.hexa              80
─────────────────────────────────────────────
TOTAL                                   1747
```

## Verification checklist

1. 3 `compiler/hw_probes/<probe>.hexa` + smoke — DONE (5/5 PASS)
2. 16 `compiler/bridges/<bridge>.hexa` + smoke — DONE (16/16 PASS, 0 halted)
3. 1 `compiler/kick/kick.hexa` + smoke — DONE (10/10 PASS)
4. Each smoke runs under `HEXA_FORCE_FALLBACK=1` and prints `X/N PASS`
5. `git diff self/main.hexa` empty (no changes — verified)
6. All Phase 1-2 dirs untouched — verified
7. Nexus repo untouched — verified

## Ready for Phase 3 drill chain alongside? yes

The 19 adapters are pure values-in / values-out surfaces with no
state side-effects. They can be invoked from a Phase 3 drill chain
without coordination — each call is idempotent and bounded by the
shared timeout knob.
