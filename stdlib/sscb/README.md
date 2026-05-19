# `stdlib/sscb/` — hexa-native absorption of SiC power-MOSFET device models

> **Status: all module bodies landed (κ-41) — no `.stub` files remain.**
> `wolfspeed.hexa` (SPICE `.lib` parser), `ngspice.hexa` (transient
> producer), `devsim.hexa` (DEVSIM TCAD bridge) and `sscb.hexa` (CLI
> dispatcher) are all GREEN with selftests. See §"Measured progress".
>
> `provenance.absorbed = false` is still the truthful state: this κ
> delivered the *parser* (Stage 2) + the *substrate / TCAD bridges*,
> not a Wolfspeed-C3M-specific datasheet parity (Stage 4). See the g3
> boundary at the bottom.

This module re-derives, under the public-surface clean-room boundary
(`demiurge/design.md` Decision 1), the parser + driver surface that
demiurge's `sscb` domain needs to lift its `analyze`/`verify` cells out
of the generic-R_on/R_off regime (κ-34) into device-faithful regime:

- **Wolfspeed SiC `.lib` SPICE subset** — `.SUBCKT … .ENDS` blocks with
  `.PARAM`, `.MODEL VDMOS (…)`, R/L/C/V/I/M/D/E/G/B elements, parametric
  references, and the temperature-pin convention (D-G-S-TJ-TC) Wolfspeed
  uses across the C3M / E3M families.
- **DEVSIM TCAD bridge** — drift-diffusion device physics (Apache-2.0;
  `devsim/devsim` on GitHub), driven in script mode: the `.hexa`
  generates a DEVSIM Python script, spawns it, parses the I-V rows.
- **ngspice transient producer** — hexa-native port of the κ-34 SSCB
  hard-switching netlist + transient-measurement pipeline.

## Module index

| file | purpose | re-derives from |
|---|---|---|
| `wolfspeed.hexa` ⭐ | SPICE `.lib` lexer + `.SUBCKT … .ENDS` parser; `.PARAM` resolver; `.MODEL` reader (VDMOS / D / Q kind preserved). **κ-41 — 35/35 selftest GREEN.** | ngspice `manual.pdf` §11 / §16 (`.MODEL VDMOS`) |
| `wolfspeed_test.hexa` ⭐ | round-trip selftest — 35 structural assertions over `fixtures/sample_sic_mosfet.lib`. `hexa run` exits 0 GREEN / 1 FAIL | (in-repo, no upstream) |
| `ngspice.hexa` ⭐ | hexa-native SSCB transient producer — writes a hard-switching netlist, spawns `ngspice -b`, parses the tran table, emits `sscb_v1.meta.json` + an `SSCB_NGSPICE_RESULT` summary. κ-41 port of `ngspice.py` (9/9 measurement parity vs the Python it replaced) | κ-34 `sscb_ngspice.py`; ngspice 46 batch I/O |
| `devsim.hexa` ⭐ | DEVSIM TCAD bridge — generates + spawns a DEVSIM Python script for a real 1-D Si PN-diode drift-diffusion I-V sweep | DEVSIM JOSS 10.21105/joss.03898; `simple_physics` helper API |
| `devsim_test.hexa` ⭐ | DEVSIM-bridge selftest — 7 physics assertions (rectification, monotonic forward I-V, exponential growth). SKIPs cleanly (exit 0) if the devsim wheel is absent | (in-repo, no upstream) |
| `sscb.hexa` ⭐ | dispatcher = `hexa run sscb.hexa <subcmd>` — routes `parse-lib` (wolfspeed) + `diode-iv` (devsim) | `stdlib/booksim/booksim.hexa`; rfc_047 §4 |
| `fixtures/sample_sic_mosfet.lib` | hand-written synthetic SPICE `.SUBCKT` mimicking the C3M0021120K topology — clean-room derived from public datasheet only | Wolfspeed C3M0021120K datasheet (public PDF) — topology only, no `.lib` text copied |

## CLI surface

```sh
hexa run sscb.hexa                          # default = help
hexa run sscb.hexa parse-lib <file>         # SPICE .lib → typed Subckt summary
hexa run sscb.hexa diode-iv <vmax_mv> <step_mv>   # DEVSIM 1-D Si diode I-V
hexa run sscb.hexa --help | -h / --version | -v
```

Exit codes (booksim raw-91 doctrine — silent skip BANNED):

| code | meaning |
|---|---|
| 0   | success |
| 1   | subcommand error (bad flags, missing input) |
| 2   | unknown topic |
| 3   | engine-tool gap (devsim absent — honest return, not a crash) |
| 91  | unreachable / config missing (`.lib` file-not-found / malformed) |

## Provenance + governance pointers

- License: SPICE syntax is public (Berkeley 1973); DEVSIM is Apache-2.0
  (Juan E. Sanchez, 2013–). Wolfspeed `.lib` files are publisher-distributed
  device libraries — only their **format** and **published topology** is
  absorbed here; no `.lib` bytes are copied into the repo.
- Decision boundary: `~/core/demiurge/design.md` D1 (public-surface
  clean-room) · D55 (sscb+analyze first cohort producer) · D61
  (demiurge = pointer only; this module is the SSOT side) · D62 (κ-39
  skeleton) · D67 (κ-41 bodies + "hexa-native 작성 .hexa" directive).
- Pattern mirrors: `stdlib/booksim/` (dispatcher + raw-91 + clean-room),
  `stdlib/atoms/` (Stage-2 honesty banner with explicit anchor validation).

## Measured progress (κ-41 — all bodies GREEN)

```
wolfspeed.hexa parser selftest:   35/35 PASS (hexa run wolfspeed_test.hexa)
                                    .SUBCKT name + 5 pins + 6 .PARAM +
                                    8 elements + 1 .MODEL VDMOS / 15 params,
                                    round-trip from sample_sic_mosfet.lib

ngspice dual-parser parity:        ngspice 46 -b parses the SAME fixture
                                    + DC operating point GREEN; von=3.2 V
                                    == hexa-parsed VTO=3.2.

ngspice.hexa ↔ ngspice.py parity:  9/9 measurements byte-equal (rows=1223,
                                    interrupt_ratio=0.352153,
                                    rise_time=1.53245 µs, v_sw_peak=598.08).
                                    Lossless Python→hexa substrate port.

devsim.hexa bridge selftest:       7/7 PASS (hexa run devsim_test.hexa) —
                                    real 1-D Si PN-diode drift-diffusion
                                    solve: I(0 V)=-2.2 nA reverse,
                                    I(0.6 V)=0.80 A forward, monotonic,
                                    exponential growth >1000× per 0.3 V.

g3 boundary (what is NOT yet measured — Stage 4, absorbed=true):
  - The devsim bridge runs a GENERIC silicon PN-diode, NOT a Wolfspeed
    C3M0021120K 2-D SiC-MOSFET. It proves hexa→DEVSIM works end-to-end;
    it does not yet absorb a named device.
  - device-physics parity vs a real Wolfspeed C3M datasheet (IDS-VDS /
    IDS-VGS curves) is NOT performed — the synthetic fixture is a
    topology mock, and the real datasheet is an external asset the
    user must supply. Fabricating that parity would violate g3.
  - therefore `provenance.absorbed = false` REMAINS truthful. Stage 2
    (parser) + the substrate / TCAD bridges are done; Stage 4 needs the
    real datasheet + a calibrated SiC-MOSFET mesh (a later κ).
```
