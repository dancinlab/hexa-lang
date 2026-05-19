# yosys/rfc_006 — all 7 module bodies landed (next-pickup note)

date: 2026-05-19
worktree: /private/tmp/wt-yosys-rfc006 (branch yosys-rfc006, unpushed)
spec: ~/core/demiurge/proposals/rfc_006_yosys_absorption.md §4/§5/§7
D-decisions: D15 · D17 · D18 · D19

## What landed

7/7 module bodies in `stdlib/yosys/` (replaces `.hexa.stub` skeletons):

| module              | selftest | notes |
|---------------------|---------:|-------|
| `rtlil.hexa`        | 10/10 PASS | typed Design/Module/Wire/Cell/Process + invariants |
| `read_verilog.hexa` | 10/10 PASS | **minimum synth-subset only**; expand for router_d{4,6}.v |
| `passes.hexa`       |  9/9 PASS  | proc/flatten/opt/techmap_sky130/dfflibmap/opt_clean/hierarchy |
| `liberty.hexa`      |  8/8 PASS  | cell area + pin dir + sequential category |
| `abc_map.hexa`      |  5/5 PASS  | D18 bounded-subprocess; fail-loud (exit 127) when `abc` missing |
| `write_verilog.hexa`|  7/7 PASS  | byte-stable mapped-Verilog emitter |
| `yosys.hexa`        |  8/8 PASS  | dispatcher; `synth` flow wired through all modules |

Total: **57/57 selftest PASS**.

Plus: `gate_record.hexa` runner — honest §5 gate measurement record.

## Gate §5 state (g3 honest)

**PARTIAL — gate OPEN. No `Yosys absorbed` claim.**

Filed: `~/core/demiurge/exports/chip/yosys/2026-05-19-gate-§5-record.md`

Blockers:
1. `abc` binary absent (D18 substrate) — install berkeley-abc.
2. SKY130 `sky130_fd_sc_hd__tt_025C_1v80.lib` absent — install skywater-pdk.
3. `read_verilog` subset too small for `comb/rtl/router_d{4,6}.v` —
   needs `localparam`, `parameter`, `generate-for`, `always @(*)`,
   multi-dim arrays, `function automatic`. (Honest gap, documented in
   `read_verilog.hexa` SCOPE block.)

## Next pickup (suggested order)

1. **Cheap & local — `read_verilog` SCOPE expansion** (no extra
   substrate needed). For each construct, one new fn + one new
   selftest:
   - `localparam` / `parameter` declarations (constant-folded)
   - `always @(*)` block → comb-process (passes.proc lifts it)
   - `always @(posedge clk)` → sync-process → $dff (already wired)
   - `case/casez` → mux-tree
   - `generate for (i = …) begin … end` → loop unrolling
   - `[W-1:0]` multi-bit wires (treat as vector)
   - `function automatic` → inline lookup
   This unlocks the §5 trace beyond `:read_verilog`.

2. **Substrate install (manual, parallel)** — `brew install
   berkeley-abc` (or build from source). Without ABC, the D18
   boundary cannot exercise.

3. **PDK install** — clone https://github.com/google/skywater-pdk
   and point `--lib` at `libraries/sky130_fd_sc_hd/latest/lib/
   sky130_fd_sc_hd__tt_025C_1v80.lib`.

4. **§5 oracle measurement** — once 1+2+3 are in place,
   `hexa run stdlib/yosys/gate_record.hexa` should produce the area
   numbers; verify ±5 % of (61762.99, 93608.53, 1.5156).

5. **Push** — after main-merge review (booksim precedent
   `d5a63a82`/`61866308` lives in `~/core/hexa-lang/inbox/`
   tracking).

## Toolchain notes (carry forward)

- Underscore-prefixed top-level struct names parse-fail in hexa-lang
  current build (`struct _RvStep { … }` → "unexpected token LBrace");
  use `RvStep` (no leading underscore). hexa-lang issue worth filing.
- `match` unsupported (rfc_003 known); used if/else chains everywhere.
- Multi-line struct literals work AFTER `return` as long as the type
  name has no leading underscore (see above).
- `time_format` codegen path broken (rfc_003); used static dates.
- `exec("…")` returns combined stdout/stderr; no separate exit-code
  channel — we infer via `find("Error:")` heuristic. Fragile —
  proper exit-code capture would harden D18.

## Cross-refs

- pattern: `stdlib/booksim/` (rfc_003)
- spec: rfc_006 (this) · rfc_003 (booksim) · rfc_048 (raw-91)
- gate record: `~/core/demiurge/exports/chip/yosys/2026-05-19-gate-§5-record.md`
