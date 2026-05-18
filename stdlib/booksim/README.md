# `stdlib/booksim/` — hexa-native re-derivation of BookSim2 (minimal subset)

> **Status: skeleton, no bodies — pending rfc_001 §8 GREEN.**
> No body returns a useful value yet. Every function is a TBD stub that
> hard-exits `91` (rfc_048 raw-91 doctrine) when called. This directory
> exists as the typed-interface scaffold the bodies will land into.
> Do **NOT** wire this into `self/main.hexa` until §8 GREEN.

This module re-derives the rfc_001 §3 minimal subset of
[BookSim2](https://github.com/booksim/booksim2) (BSD-2-Clause; Stanford
2007-2015; commit `28f43299f1706a3160ffac721ca461d74eb6e618`) under the
public-surface clean-room boundary (`design.md` Decision 1). No code is
copy-pasted from upstream; each function carries an inline
`// CLEAN-ROOM` comment naming the upstream file + line-range it was
re-derived from by inspection only.

The end-goal is to close `proposals/rfc_001_booksim2_noc_absorption.md`
§8's measurement gate so the `F1F2-record` artifact
(`proposals/rfc_002_f1f2_export_interface.md` §3) can be emitted with
`provenance.absorbed = true` for `comb` (hexa-lang `comb/RFC.md`
F1/F2 falsifiers).

Implementation plan: `proposals/rfc_003_booksim_native_rederivation_plan.md`.

## Module index

| file | purpose | re-derives from |
|---|---|---|
| `anynet.hexa.stub`     | topology loader — parses BookSim2 `anynet` file format into a typed `AnynetTopology` | `src/networks/anynet.cpp:80-207`; `doc/manual.tex §anynet` |
| `iq_router.hexa.stub`  | 4-knob IQ-router pipeline (`routing_delay·vc_alloc_delay·sw_alloc_delay·credit_delay`) + zero-load min-latency formula | `src/routers/iq_router.cpp:50-220` |
| `traffic.hexa.stub`    | synthetic traffic generators: `uniform · transpose · tornado` (rfc_001 §3) | `src/traffic.cpp:230-308, 380-396, 48-194` |
| `sweep.hexa.stub`      | latency-vs-injection-rate measurement loop + saturation-knee detection (Dally & Towles PPIN §25) | `src/trafficmanager.cpp:1417-1610` |
| `wire_delay.hexa.stub` | per-link cycle-latency model from physical length × public-literature wire-delay-per-mm at named modern node — **new**, NOT BookSim2 | Krishna et al. 2013 SMART §3; Kwon & Krishna 2017 OpenSMART §IV |
| `leighton.hexa.stub`   | analytic Bhatt–Leighton bisection / diameter lower-bound oracle (rfc_001 §5 no-over-claim gate) — **new**, NOT BookSim2 | Leighton 1984 Thm 2 (DOI 10.1007/BF01744433); Bhatt–Leighton 1984 |
| `booksim.hexa.stub`    | dispatcher = `hexa-arch booksim <subcmd>` entry point; exit-code policy 0/1/2/90/91 (rfc_001 §7.3) | rfc_001 §7.2 (CLI surface); rfc_047 §4 (dispatcher pattern) |

## CLI surface (mirror of rfc_001 §7.2)

```sh
hexa-arch booksim                       # default = help
hexa-arch booksim topology load <file>  # anynet topology file → typed AnynetTopology
hexa-arch booksim sweep --topology <f> --traffic uniform --rate 0.05..0.5
hexa-arch booksim wire-delay --node 22nm --topology <f>
hexa-arch booksim oracle --degree 6 --bisection --diameter
hexa-arch booksim measure --baseline degree-4 --candidate degree-6 \
                          --node 22nm --traffic tornado --report json
hexa-arch booksim --help, -h / --version, -v
```

Dispatcher entry point: `booksim.hexa.stub::cmd_booksim(argv)`.
Exit codes (rfc_001 §7.3, rfc_048 raw-91 doctrine):

| code | meaning |
|---|---|
| 0   | success |
| 1   | subcommand error (bad flags, missing input) |
| 2   | unknown topic |
| 90  | measurement gate not satisfied (no `absorbed` claim yet — see §8) |
| 91  | unreachable / config missing (wire-delay node profile absent, Leighton oracle violated, TBD body called) |

Silent skip BANNED.

## File-naming note

These files end in `.hexa.stub` (not `.hexa`) deliberately:

- Signals to any `hexa parse` / build sweep that the file is not yet
  buildable (bodies TBD).
- Prevents accidental `self/main.hexa` dispatcher wiring before §8
  GREEN.
- When the bodies-landing RFC fires, the rename to `.hexa` is a single
  audit-visible commit — there is no in-place "what changed" question.

## Provenance + governance pointers

- License: BookSim2 is BSD-2-Clause (Stanford 2007-2015). See
  `/tmp/hexa-arch-rfc001-measurement/booksim2/LICENSE.md` for the
  upstream source tree this re-derivation was inspected against.
- Decision boundary: `~/core/hexa-arch/design.md` D1 (public-surface
  clean-room — no decompilation, no trade-secret, no
  closed-binary RE).
- CHARTER: `~/core/hexa-arch/CHARTER.md` — hexa-native-only (Python-0,
  shell-out-0).
- Pattern mirrors: `~/core/hexa-lang/proposals/rfc_047_mc_integrate_absorption.md`
  (engine + dispatcher split) and `rfc_048_xeno_absorption.md` (raw-91
  fail-loud doctrine).

## Status banner (until §8 GREEN)

```
status:                    SKELETON
gate:                      rfc_001 §8 measurement-gate OPEN
provenance.absorbed:       false (default until measured parity)
do not import from outside this directory yet
```
