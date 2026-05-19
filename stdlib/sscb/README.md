# `stdlib/sscb/` — hexa-native absorption of SiC power-MOSFET device models

> **Status: 1 of 3 module bodies landed (κ-40 — `wolfspeed.hexa`).**
> The SPICE `.lib` parser is GREEN (round-trip selftest + dual-parser
> parity vs ngspice 46 — see §"Measured progress" below). The other two
> modules (`devsim.hexa.stub`, `sscb.hexa.stub`) are still TBD-body
> skeletons that hard-exit `91` (booksim raw-91 doctrine).
> Do **NOT** wire `sscb.hexa.stub` into any `*/main.hexa` dispatcher
> until its body lands AND κ-39 §8 measurement-gate closes.

This module re-derives, under the public-surface clean-room boundary
(`demiurge/design.md` Decision 1), the parser + TCAD-driver surface that
demiurge's `sscb` domain needs to lift its `analyze`/`verify` cells out
of the generic-R_on/R_off regime (κ-34) into device-faithful regime:

- **Wolfspeed SiC `.lib` SPICE subset** — `.SUBCKT … .ENDS` blocks with
  `.PARAM`, `.MODEL VDMOS (…)`, R/L/C/V/I/M/D/E/G/B elements, parametric
  references, and the temperature-pin convention (D-G-S-TJ-TC) Wolfspeed
  uses across the C3M / E3M families.
- **DEVSIM TCAD driver** — drift-diffusion + density-gradient quantum
  (Apache-2.0; `devsim/devsim` on GitHub) device-level I-V / C-V
  extraction, callable in script mode without DEVSIM's Python REPL.

The end-goal is to close the κ-39 measurement gate so the demiurge
SSCB `analyze` cell can emit one typed `SSCBRecord` carrying
`provenance.absorbed = true` for a *named* Wolfspeed-class device.

Implementation plan: forthcoming `proposals/rfc_NN_sscb_native_absorption.md`
(hexa-lang side; demiurge side lives in `demiurge/design.md` D62 + κ-39).

## Module index

| file | purpose | re-derives from |
|---|---|---|
| `wolfspeed.hexa` ⭐ | SPICE `.lib` lexer + `.SUBCKT … .ENDS` parser; `.PARAM` resolver; `.MODEL` reader (VDMOS / D / Q kind preserved verbatim) — minimal subset Wolfspeed C3M/E3M `.lib` files exercise. **Bodies landed κ-40 — 35/35 selftest GREEN.** | ngspice `manual.pdf` §11 (devices) / §16 (`.MODEL VDMOS`); KiCad embedded-ngspice docs |
| `wolfspeed_test.hexa` ⭐ | round-trip selftest harness — `hexa run wolfspeed_test.hexa` exits 0 on GREEN, 1 on FAIL. 35 structural assertions over `fixtures/sample_sic_mosfet.lib` | (selftest authored in-repo, no upstream) |
| `devsim.hexa.stub` | DEVSIM script-mode driver: mesh + region setup, ramp Vds, extract I-V points — no Python REPL | DEVSIM JOSS 10.21105/joss.03898; `devsim/devsim` examples/`mosfet_2d` |
| `sscb.hexa.stub` | dispatcher = `hexa-lang sscb <subcmd>` entry point; exit-code policy 0/1/2/90/91 (booksim raw-91 doctrine) | `stdlib/booksim/booksim.hexa.stub`; rfc_047 §4 (dispatcher pattern) |
| `fixtures/sample_sic_mosfet.lib` | hand-written synthetic SPICE `.SUBCKT` mimicking the C3M0021120K topology — clean-room derived from public datasheet only | Wolfspeed C3M0021120K datasheet (public PDF) — topology only, no copy of `.lib` text |

## CLI surface

```sh
hexa-lang sscb                                # default = help
hexa-lang sscb parse-lib <file>               # SPICE .lib → typed Subckt
hexa-lang sscb tcad-iv --vgs 15 --vds-max 1200 --npts 50 \
                       --device <name>        # DEVSIM I-V sweep
hexa-lang sscb absorb --lib <file> --datasheet <yaml> --report json
hexa-lang sscb --help, -h / --version, -v
```

Dispatcher entry point: `sscb.hexa.stub::cmd_sscb(argv)`.
Exit codes (booksim raw-91 doctrine — silent skip BANNED):

| code | meaning |
|---|---|
| 0   | success |
| 1   | subcommand error (bad flags, missing input) |
| 2   | unknown topic |
| 90  | measurement gate not satisfied (no `absorbed` claim yet — see κ-39 §8) |
| 91  | unreachable / config missing (DEVSIM binary absent, `.lib` parse-error, TBD body called) |

## File-naming note

These files end in `.hexa.stub` (not `.hexa`) deliberately — same reason
as `stdlib/booksim/`: signals to any `hexa parse` / build sweep that the
file is not yet buildable (bodies TBD); prevents accidental dispatcher
wiring before §8 GREEN; when the bodies-landing PR fires, the rename to
`.hexa` is a single audit-visible commit.

## Provenance + governance pointers

- License: SPICE syntax is public (Berkeley 1973); DEVSIM is Apache-2.0
  (Juan E. Sanchez, 2013–). Wolfspeed `.lib` files are publisher-distributed
  device libraries — only their **format** and **published topology** is
  absorbed here; no `.lib` bytes are copied into the repo.
- Decision boundary: `~/core/demiurge/design.md` D1 (public-surface
  clean-room — no decompilation, no trade-secret, no closed-binary RE) ·
  D55 (sscb+analyze first cohort producer) · D61 (demiurge = pointer
  only; this module is the SSOT side) · D62 (sscb device-model
  absorption skeleton, this κ).
- Pattern mirrors: `stdlib/booksim/` (dispatcher + raw-91 + clean-room),
  `stdlib/yosys/` (multi-pass parser layout), `stdlib/atoms/` (Stage-2
  honesty banner with explicit isolated-anchor validation).

## Measured progress (κ-40 — wolfspeed module Stage 2 GREEN)

```
hexa parser selftest:       35/35 PASS (`hexa run wolfspeed_test.hexa`)
                              .SUBCKT name + 5 pins + 6 .PARAM +
                              8 elements (R/L/C/M/B mix) +
                              1 .MODEL VDMOS with 15 params,
                              all round-trip from
                              fixtures/sample_sic_mosfet.lib

ngspice parity (dual-parser sanity, ngspice 46 brew/macos):
                              ngspice -b parses the same fixture
                              + DC operating point GREEN; reports
                              von=3.2 V == hexa-parsed VTO=3.2.
                              Two independent SPICE parsers
                              (Berkeley-lineage C + hexa-native
                              re-derivation) agree on the fixture's
                              syntactic interpretation.

g3 boundary (what is NOT yet measured):
  - device-physics parity vs real Wolfspeed C3M0021120K datasheet
    (IDS-VDS / IDS-VGS curves): NOT performed — fixture is synthetic
  - DEVSIM TCAD comparison: NOT performed — devsim Python wheel
    absent on local roster, devsim_locate() still raw-91
  - therefore `provenance.absorbed = false` REMAINS the truthful
    state. Stage 2 is *parser* port only; Stage 3-4 require the two
    measurements above (deferred to a κ-41+ when DEVSIM lands).
```
