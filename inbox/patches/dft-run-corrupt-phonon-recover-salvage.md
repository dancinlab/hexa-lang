# dft-run: CORRUPT phonon-recover state → full pod teardown (loses completed q-points)

**Source:** demiurge RTSC QFORGE-migration-gate campaign, 2026-06-01 (host mini).
**Component:** `stdlib/cloud/dft_dispatch.hexa` — the `--resume` phon `__DFT_FAILED__` crash-classifier.
**Severity:** campaign-blocking; a single mid-write interrupt nukes the pod + every completed q-point → forced full rerun (SCF from scratch).

This is the **SECOND** dft-run robustness gap after `dft-run-direct-endpoint-scp255.md`.

## Symptom

LaH10's `hexa cloud dft-run <deck> --resume` re-entered a live pod whose phonon (ph.x)
run had been interrupted mid-write. q1–3 were complete (good nonzero `<prefix>.dynN`),
but q4's per-q `.save` XML was half-written (no closing tag) by the original run's
teardown-kill. A `recover=.true.` ph.x then read that partial XML and died:

```
     Bands found: reading from ./out/_ph0/lah10.q_4/
     Reading xml data from directory: ./out/_ph0/lah10.q_4/lah10.save/
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
     Error in routine qexsd_readschema (1):
     PARSE_ERR
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    81 runParser
```

→ SIGABRT (signal 6). The crash-classifier (`_dft_stage_probe_cmd` → `__DFT_FAILED__`,
then the walltime-vs-crash split) treated this as a GENUINE crash → **full pod teardown**,
losing q1–3 + the pod → a fresh full rerun. Adjacent signatures seen on the same class:
`PARTIAL_EL_PHON not found` · `closing tag not found` · `cannot open file` reading a
`_ph0/<prefix>.q_*/<prefix>.save`. (CaAuH3 5/10q and MgBeH8 4/8q hit the same wall earlier
— see the demiurge `rtsc-startq-recover-plan.md` manual recipe.)

## Root cause

`__DFT_FAILED__` collapsed THREE disjoint conditions into one teardown verdict:
1. a NORMAL walltime cap (`Maximum CPU time exceeded` / `max_seconds`) — already split out
   (`_dft_failure_is_walltime`, recover-relaunch, no teardown);
2. a CORRUPT phonon-recover state — the in-flight q's per-q `.save` is half-written, but the
   COMPLETED q's (`<prefix>.dynN`) AND the SCF ground state (`<prefix>.save/`) are intact, so
   it is recoverable WITHOUT a fresh SCF — yet it was being torn down as if genuine;
3. a GENUINE numerical/OOM/segfault fault (`Error in routine` / `STOP [1-9]` / NaN / OOM /
   Segmentation) — teardown/defer is correct.

Tearing down on (2) destroys a healthy pod plus all its accumulated q-point progress.

## Fix (LANDED) — classify + salvage on the SAME pod

Two stacked PRs in `stdlib/cloud/dft_dispatch.hexa`:

- **PR1 #2459 — classifier** (`_dft_failure_is_corrupt_recover`): a PURE sub-classifier that
  recognizes the corrupt-recover class by its ph.out signatures (`PARSE_ERR` / `runParser` /
  `PARTIAL_EL_PHON not found` / `closing tag not found` / `cannot open file` WITH a `_ph0`
  co-signature), distinct from BOTH walltime and a genuine crash. A bare `cannot open file`
  on a deck input (e.g. a missing pseudo) is NOT misread as salvageable. d19 reuse — same
  `__DFT_FAILED__` taxonomy, no new oracle.

- **PR2 #2460 — salvage relaunch + one-attempt guard:** on that class the `--resume` controller
  SALVAGES on the same pod instead of teardown.
  - `_dft_salvage_cmd` (pod-side, GENERIC — no slug hardcode): derive prefix + nq_total from
    `*.dyn0`; `start_q` = first q lacking a good nonzero `<prefix>.dynN`; DELETE the corrupt
    `_ph0/<prefix>.q_<start_q>/` + stale recover scratch; write `ph_salvage.in`
    (`recover=.false. start_q last_q`); relaunch ph.x APPENDING to ph.out. Completed dynN +
    the SCF `.save` are PRESERVED (only the unrecoverable partial q is recomputed).
  - `_dft_corrupt_recover_q` parses the failing q from the `_ph0/<prefix>.q_<N>/` line;
    `_dft_salvage_marker` / `_dft_salvage_already_tried` are the durable ONE-attempt-per-q
    guard (deck-local, survives a session restart) — a SAME-q re-PARSE_ERR after a clean
    recompute is a GENUINE fault → teardown/defer (NEVER an infinite re-fire loop).
  - Integration in the phon `FAILED` branch, ordered AFTER walltime, BEFORE genuine-crash.

g5: `hexa run stdlib/cloud/dft_dispatch_test.hexa` → `dft_dispatch_test PASS` — corrupt-recover
signatures classified distinctly + disjoint from walltime; salvage cmd shape (deletes the right
`_ph0/q_N`, start_q=first-missing-dyn, recover=.false., preserves dynN, appends ph.out); q-parse
(last `.q_N` wins, stops at non-digit); one-attempt guard (2nd salvage of the same q blocked,
a different q still fresh).

## Relation

Sibling of `dft-run-direct-endpoint-scp255.md` — the FIRST dft-run robustness gap (direct-vs-proxy
data transfer). This one is about the `--resume` crash-classifier wrongly tearing down a salvageable
pod. Together they harden the dft-run rent→upload→resume→harvest lifecycle against both transport
and recover-state corruption.

Kept (not deleted) per the demiurge campaign reference (d8).
