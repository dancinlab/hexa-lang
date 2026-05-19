# `stdlib/vhdl/` — hexa-native VHDL emit (FIRMWARE.md G-R3)

> **Status: SCAFFOLD-ONLY (2026-05-20) — `.hexa.stub` skeleton only.**
> Body pending RFC 064 G-R3.

Mirror of [`stdlib/yosys/`](../yosys/) for the VHDL dialect.
`stdlib/yosys/read_verilog.hexa` + `write_verilog.hexa` already do the
Verilog round-trip (in flight on branch `s1-step2-codegen-perf`); this
directory holds the VHDL counterpart so the `@target(rtl)` lane
(authored RTL → RTLIL → output dialect) is dialect-symmetric.

## Module index (FIRMWARE.md §4 G-R3)

| file | purpose | FIRMWARE.md gate |
|---|---|---|
| `write_vhdl.hexa.stub` | mapped-RTLIL → VHDL-2008 netlist backend (gate-level emit) | G-R3 |

Read side (VHDL → RTLIL) is **not in scope for v1.** Cross-language
RTL projects typically only need one authoritative source-of-truth
dialect for synthesis; the round-trip-equality fixture (G-R0/G-R1) is
Verilog. VHDL is consumed by downstream EDA tools that require it.

## Exit fixture

- **G-R3** — the counter demo from G-R1 (Verilog emit) also emits to
  `.vhd` via `write_vhdl`, and the result analyses cleanly through
  GHDL (`ghdl -a` / `ghdl -e` round-trip).

## Provenance

VHDL is IEEE Std 1076-2008 standardised. The output written by this
module follows the standard verbatim (no GHDL-specific extensions,
no Vivado-specific pragmas). The synthesis subset matches the same
subset Yosys' Verilog backend uses — see `stdlib/yosys/README.md`
clean-room provenance for the upstream policy.
