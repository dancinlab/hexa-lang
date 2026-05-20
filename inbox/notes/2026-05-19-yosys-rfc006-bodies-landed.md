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

1. **~~Cheap & local — `read_verilog` SCOPE expansion~~ — LANDED** in 12+
   subsequent commits (head 19ea268e via PR #115). 34/34 selftests PASS
   covering all 6 features below. Status flip 2026-05-20 after a
   dup-race precheck sub-agent (a00e698b...) confirmed against origin/main.
   - `localparam` / `parameter` — commit `83e8953d` (declaration parse + symbol table)
   - constant-expression evaluator — commit `d9b5d328`
   - `[W-1:0]` ANSI-style width elaboration — commit `03028695`
   - `function automatic` (declaration parse) — commit `59cebf47`
   - `always @(posedge clk)` → `$dff` lift — commit `0fe6ddc9`
   - `generate for` static unroll + LHS indexing — commit `6d96a3cc`
   - if/else / for inside always (case/casez precursor) — commits `a93b707b` · `c320e795` · `64b4290d`
   - multi-statement always body + 2-level index + integer body decl — commits `28554a64` · `3bbc82b8` · `847f3875`

   §5 gate's real blockers (2026-05-20 §5-measurement agent finding):
   - (a) `passes.hexa::pass_techmap_sky130` covers only 5 cell types; need `$eq/$ne/$add/$mod/$mux/$logic_*` lowering rules.
   - (b) `abc_map.hexa` ABC script orders `read_blif` before `read_lib` → "library not available". **FIX IN FLIGHT** (PR via agent a1e5cb88...).
   - (c) `gate_record.hexa` placeholder verdict; needs real `lib_total_area` call. **FIX IN FLIGHT** (same PR).

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
