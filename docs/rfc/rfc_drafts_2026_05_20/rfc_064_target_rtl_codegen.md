# RFC 064 — `@target(rtl)` codegen lane (Verilog + SystemVerilog + VHDL)

- status: DRAFT (scaffolded, codegen pending)
- created: 2026-05-20
- authority: `FIRMWARE.md` §4 gates G-R0..G-R4 + `@D g5 hexa-native-only`
- consumer: `stdlib/yosys/{read_verilog,write_verilog,rtlil}.hexa` (in
  flight on branch `s1-step2-codegen-perf`) + `stdlib/vhdl/write_vhdl.hexa.stub`
- consumer fixture: `stdlib/yosys/test/round_trip.hexa`
- sibling RFC: 063 (`@target(firmware)` codegen lane)

---

## §1 Problem

Today, RTL (Verilog / SystemVerilog / VHDL) in the repo is **authored**
as `.v` / `.sv` / `.vhd` files under `firmware/boards/<board>/firmware/
hdl/...`, `comb/rtl/...`, etc. FIRMWARE.md §1 forbids that pattern; the
authored form goes forward as `.hexa` with a `@target(rtl)` annotation,
lowered by `stdlib/yosys/write_verilog.hexa` (or `stdlib/vhdl/write_
vhdl.hexa` for VHDL output) to a `build/rtl/<flavour>/` artifact.

`stdlib/yosys/read_verilog.hexa` already parses Verilog into RTLIL on
this branch (commits `da6badba`, `82748da6`, `36bbdfc6`, `aa489cfe`).
This RFC's `@target(rtl)` work is the **other direction** — a hexa
front-end pass that lowers a hexa-source RTL DSL into RTLIL, plus the
output-dialect choice (Verilog vs SystemVerilog vs VHDL).

## §2 Goals (FIRMWARE.md G-R0..G-R4)

- **G-R0** — `stdlib/yosys/read_verilog.hexa` round-trip parses 12
  reference Verilog modules byte-eq.
  - Exit fixture: `stdlib/yosys/test/round_trip.hexa` (this RFC
    inherits whatever shape that fixture lands).
- **G-R1** — `@target(rtl)` annotation on a hexa module is parsed into
  RTLIL by a new front-end pass.
  - Exit fixture: `stdlib/yosys/test/counter.hexa` (TBD) emits a
    Verilog `counter.v` whose synthesis (yosys → ABC) matches a
    reference netlist.
- **G-R2** — SystemVerilog dialect emit (`.sv`) from the same RTLIL.
  - Exit fixture: a 2-of-3 voter demo emitted as `.sv` matches a
    reference netlist under `yosys`.
- **G-R3** — `stdlib/vhdl/write_vhdl.hexa` mirror.
  - Exit fixture: counter demo from G-R1 also emits to `.vhd`, and
    GHDL (`ghdl -a counter.vhd && ghdl -e counter`) succeeds.
- **G-R4** — timing pragma annotations: `@clock`, `@reset`, `@async`.
  - Exit fixture: counter demo passes static timing at 100 MHz on a
    reference part (the tool is the oracle, not hexa).

## §3 Non-goals

- **Not formal verification.** Equivalence-check vs a hand-written
  reference is the G-R1 exit, not full formal proof.
- **Not a HLS (high-level synthesis) tool.** `@target(rtl)` is for
  hardware authoring at the RTL level — register transfer is explicit,
  not inferred. Behavioural-to-RTL transformation is out of scope.
- **Not a simulator.** Simulation is the existing tool oracles
  (Verilator, GHDL, iverilog) over the codegen output.
- **Not a backend replacement for Yosys.** ABC is invoked as an
  absorbed-substrate subprocess per `stdlib/yosys/abc_map.hexa.stub` —
  that boundary stands.

## §4 Surface (hexa-side)

### Annotation grammar

```
@target(rtl,
        dialect = "verilog" | "systemverilog" | "vhdl",
        version = "2005" | "2017" | "2008",         // dialect-specific
        clock   = <symbol>?,                          // optional — names the implicit clock wire
        reset   = <symbol>?                           // optional — names the implicit reset wire
)
module ... { ... }

@clock(name = "clk", freq_mhz = 100)
let clk: u1 = 0

@reset(name = "rst_n", active = "low", sync = "async")
let rst_n: u1 = 1

@async
fn combinational_logic(...) -> ... { ... }   // no clock dependency
```

### Toolchain dispatch

`hexa build --target=rtl,dialect=verilog,version=2005` resolves to:
- codegen lane: new front-end pass (RFC 064 G-R1) → RTLIL → existing
  `stdlib/yosys/write_verilog.hexa` (Verilog) /
  `stdlib/vhdl/write_vhdl.hexa` (VHDL);
- output dir: `build/rtl/<dialect>/`;
- consumer tools (yosys / GHDL / Vivado) invoked over the output, same
  shape as today, only the **authoring** side is now hexa.

## §5 Codegen contract

1. **front-end pass (G-R1)** — a new pass in `self/` walks the AST,
   recognises `@target(rtl)` on module-like declarations, and lowers
   the body into an `rtlil::Design` value (using `stdlib/yosys/rtlil.
   hexa` constructors). The pass is enabled only when the `--target=rtl`
   driver flag is set.
2. **dialect dispatch** — `write_verilog` (existing) for `dialect=
   verilog|systemverilog`, `write_vhdl` (new, stub today) for
   `dialect=vhdl`. SystemVerilog vs Verilog is a flag inside
   `write_verilog` that toggles `logic` vs `wire`/`reg` and a few
   constructs (`always_ff` / `always_comb`).
3. **timing pragmas (G-R4)** — `@clock` / `@reset` / `@async` are
   metadata threaded into the emitted SDC (synthesis-design
   constraint) file at `build/rtl/<dialect>/timing.sdc`. The hexa
   side does NOT close timing — the synth tool does.
4. **reference netlist comparison (exit fixture)** — for G-R1, the
   counter demo's `yosys synth -top counter` output (post-ABC mapped
   netlist) is compared against a checked-in reference netlist by
   netlist-equivalence (yosys `equiv_make` / `equiv_induct` pass set).

## §6 Phasing

1. **G-R0** lands once `stdlib/yosys/read_verilog.hexa` reaches 12/12
   round-trip-equal on the fixtures in `stdlib/yosys/test/round_trip.
   hexa` (currently 5 inline fixtures sketched; expand to 12).
2. **G-R1** depends on G-R0 — the round-trip is the invariant against
   which the front-end pass is verified.
3. **G-R2** is a small extension of G-R1 (`write_verilog` already
   parameterised for SV).
4. **G-R3** is independent of G-R1 once the RTLIL intermediate is
   stable — it's a new backend on the same IR.
5. **G-R4** is the SDC emit on top of any of G-R1/G-R2/G-R3.

## §7 Falsifier

- A fixture in `stdlib/yosys/test/round_trip.hexa` that diverges
  byte-eq falsifies G-R0.
- A counter demo whose post-ABC netlist diverges from the reference
  netlist (equiv_make fails) falsifies G-R1.
- A VHDL emit that GHDL refuses to analyse falsifies G-R3.
- Counter demo failing static timing at 100 MHz on the reference part
  falsifies G-R4 (and would point to either the codegen, the SDC, or
  the timing-pragma semantics — the failure cause is investigated
  per-instance, but it's a falsifier nonetheless).

## §8 References

- FIRMWARE.md §4 G-R0..G-R4
- `stdlib/yosys/README.md` (clean-room provenance for the Yosys-side
  re-derivation)
- `stdlib/yosys/{read_verilog,write_verilog,rtlil}.hexa` (in flight)
- `stdlib/vhdl/{README.md, write_vhdl.hexa.stub}` (this RFC's
  authoring of the VHDL output side)
- IEEE Std 1364-2005 (Verilog) · IEEE Std 1800-2017 (SystemVerilog) ·
  IEEE Std 1076-2008 (VHDL)
- `~/core/hexa-arch/proposals/rfc_006_yosys_absorption.md` (the
  upstream RFC that scaffolded `stdlib/yosys/`)
- AGENTS.tape `@D g5 hexa-native-only` · `@D g_stdlib_ownership`
