# `stdlib/sscb/` — SiC power-MOSFET / SSCB domain adapter

> **D72 2-layer restructure:** the domain-agnostic circuit engine
> (`wolfspeed.hexa` SPICE parser, `vdmos.hexa` VDMOS DC model,
> `devsim.hexa` DEVSIM bridge) now lives in `stdlib/kernels/circuit/`
> (①a kernel). This directory keeps the ①b SSCB-domain adapter:
> `sscb.hexa` (CLI dispatcher), `ngspice.hexa` (SSCB hard-switching
> transient producer — demiurge `SSCBProducer.swift` spawn target,
> path unchanged), `wolfspeed_parity.hexa` (C3M0021120K datasheet
> parity), the `fixtures/` datasheet models, and the engine selftests.
>
> **Status: all module bodies landed (κ-41) — no `.stub` files remain.**
> The kernel modules + `ngspice.hexa` + `sscb.hexa` are all GREEN with
> selftests. See §"Measured progress".
>
> `absorbed=true` is earned for the **sscb DC device model**:
> `vdmos.hexa` reproduces the Wolfspeed C3M0021120K data sheet R_DS(on)
> / V_GS(th) with hexa-native arithmetic, zero external simulator
> (D17 matter pattern). It does NOT extend to transient circuit
> simulation — see the absorbed=true scope note at the bottom.

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

_①a circuit kernel — relocated to `stdlib/kernels/circuit/` (D72):_

| file | purpose | re-derives from |
|---|---|---|
| `kernels/circuit/wolfspeed.hexa` ⭐ | SPICE `.lib` lexer + `.SUBCKT … .ENDS` parser; `.PARAM` resolver; `.MODEL` reader (VDMOS / D / Q kind preserved). **κ-41 — 35/35 selftest GREEN.** | ngspice `manual.pdf` §11 / §16 (`.MODEL VDMOS`) |
| `kernels/circuit/devsim.hexa` ⭐ | DEVSIM TCAD bridge — generates + spawns a DEVSIM Python script for a real 1-D Si PN-diode drift-diffusion I-V sweep | DEVSIM JOSS 10.21105/joss.03898; `simple_physics` helper API |
| `kernels/circuit/vdmos.hexa` ⭐ | **hexa-native VDMOS Level-1 DC device model** — square-law I-D + channel-length modulation + series RS/RD, with 1-D Newton solvers for R_DS(on) and V_GS(th). ZERO subprocess — pure hexa arithmetic. This is the `absorbed=true` engine for the sscb DC device model. | Shichman-Hodges Level-1 MOSFET model (IEEE JSSC 1968; Sedra/Smith) |

_①b SSCB-domain adapter — this directory:_

| file | purpose | re-derives from |
|---|---|---|
| `wolfspeed_test.hexa` ⭐ | round-trip selftest for `kernels/circuit/wolfspeed` — 35 structural assertions over `fixtures/sample_sic_mosfet.lib`. `hexa run` exits 0 GREEN / 1 FAIL | (in-repo, no upstream) |
| `ngspice.hexa` ⭐ | hexa-native SSCB transient producer — writes a hard-switching netlist, spawns `ngspice -b`, parses the tran table, emits `sscb_v1.meta.json` + an `SSCB_NGSPICE_RESULT` summary. κ-41 port of `ngspice.py` (9/9 measurement parity vs the Python it replaced) | κ-34 `sscb_ngspice.py`; ngspice 46 batch I/O |
| `devsim_test.hexa` ⭐ | selftest for `kernels/circuit/devsim` — 7 physics assertions (rectification, monotonic forward I-V, exponential growth). SKIPs cleanly (exit 0) if the devsim wheel is absent | (in-repo, no upstream) |
| `vdmos_test.hexa` ⭐ | hexa-native datasheet parity selftest — parses `c3m0021120k.lib`, runs `kernels/circuit/vdmos` solvers, checks R_DS(on)/V_GS(th) vs the data sheet within ±10 %, **no ngspice in the loop**. PASS = absorbed-eligible. | (in-repo) |
| `wolfspeed_parity.hexa` ⭐ | ngspice substrate cross-check — generates ngspice decks at the datasheet test conditions, confirms `vdmos.hexa` independently | Wolfspeed C3M0021120K data sheet Rev.4 (public PDF) — spec table only |
| `sscb.hexa` ⭐ | dispatcher = `hexa run sscb.hexa <subcmd>` — routes `parse-lib` (wolfspeed) + `diode-iv` (devsim) + `datasheet-parity` (wolfspeed_parity) | `stdlib/booksim/booksim.hexa`; rfc_047 §4 |
| `fixtures/sample_sic_mosfet.lib` | hand-written synthetic SPICE `.SUBCKT` (parser unit-test fixture) — clean-room, topology mock | (in-repo) |
| `fixtures/c3m0021120k.lib` ⭐ | **datasheet-calibrated** clean-room C3M0021120K model — every parameter traces to a cited cell of the Wolfspeed data sheet Rev.4 spec table | Wolfspeed C3M0021120K data sheet Rev.4 (public PDF) — spec table only, no vendor `.lib` bytes |

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

C3M0021120K datasheet parity — hexa-native (vdmos_test.hexa):
                                    PASS — the hexa-native VDMOS
                                    Level-1 DC solver reproduces the
                                    Wolfspeed C3M0021120K data sheet
                                    Rev.4 spec table with ZERO ngspice
                                    / ZERO subprocess:
                                      R_DS(on)  21.23 mΩ vs 21 mΩ → 1.08 %
                                      V_GS(th)  2.554 V  vs 2.5 V → 2.15 %
                                    => absorbed=true criterion met for
                                       the sscb DC device model
                                       (ABSORPTION.md ⑤ / D17 pattern:
                                        hexa-lang reproduces the result
                                        on its own arithmetic).

C3M0021120K datasheet parity — ngspice cross-check (wolfspeed_parity.hexa):
                                    PASS — independent confirmation via
                                    ngspice 46: R_DS(on) 1.08 %,
                                    V_GS(th) 1.36 %. The hexa-native
                                    and ngspice R_DS(on) agree to 5
                                    decimals (0.0212265 Ω) — triple
                                    agreement hexa = ngspice = datasheet.

absorbed=true SCOPE (honest — g3):
  - absorbed=true holds for the **sscb DC device model**: the static
    data sheet specs (R_DS(on), V_GS(th)) are now reproduced by
    hexa-native code with no external simulator.
  - absorbed=true does NOT extend to full transient circuit
    simulation — the SSCB hard-switching netlist (ngspice.hexa) still
    spawns ngspice. A hexa-native transient SPICE engine (MNA matrix +
    sparse LU + trapezoidal L/C integration) is a separate future
    effort; the DC device model did not need it.
  - The Wolfspeed-distributed `.lib` file is form-gated and was never
    accessed — only the PUBLIC data sheet spec table is absorbed
    (D1 clean-room, fully compliant).
  - Honest circularity note: VTO is set to the data sheet V_GS(th) and
    RD/RS are sized toward R_DS(on); the parity is a consistency check
    (the model + the independently-implemented Level-1 equations land
    on the data sheet), confirmed by hexa↔ngspice agreement. See the
    headers of vdmos.hexa / wolfspeed_parity.hexa.
```
