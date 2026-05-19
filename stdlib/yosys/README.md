# `stdlib/yosys/` — chip-domain logic-synth adapter (①b layer; demiurge D72)

> **D72 2-layer restructure:** the six domain-agnostic logic-synthesis
> engine modules (`rtlil` · `read_verilog` · `passes` · `liberty` ·
> `abc_map` · `write_verilog`, listed in the table below) were
> relocated to `stdlib/kernels/logic_synth/` — the ①a kernel layer
> (see `stdlib/kernels/logic_synth/README.md`). This directory now
> holds only the chip-domain ①b adapter:
>
> | file | role |
> |---|---|
> | `yosys.hexa` | `hexa yosys` CLI dispatcher (demiurge `chip+synthesize`). |
> | `gate_record.hexa` | rfc_006 §5 gate-runner — SKY130 router_d4/d6 area oracle. |
>
> Both adapters import the engine via `use "stdlib/kernels/
> logic_synth/<module>"`. The adapter file paths are unchanged — the
> demiurge `hexa run yosys.hexa` spawn is transparent to the move.
>
> **Provenance — shared-worktree-hazard re-land (2026-05-19):** an
> initial commit of this scaffold was silently dropped when a parallel
> session's history rewrite (commit `f880c425` → `a6e5ac95` re-SHA)
> excluded these files. Re-created in a separate commit to preserve the
> work cleanly. See `inbox/notes/2026-05-19-shared-worktree-hazard-yosys-drop.md`.

This module re-derives the public surface of
[Yosys](https://github.com/YosysHQ/yosys) (ISC license; YosysHQ;
re-derivation tracks main branch as of 2026-05-19) under the
public-surface clean-room boundary (`design.md` Decision 1, same as
booksim). The ABC technology mapper is **NOT** clean-room re-derived
— per hexa-arch D18 it is invoked as an absorbed-substrate
subprocess with provenance + fail-loud (rfc_048/D14 hybrid g5
exception, same idiom as `AGENTS.tape` g5).

Implementation plan source: `~/core/hexa-arch/proposals/
rfc_006_yosys_absorption.md` §4 (module list) + §5 (measurement gate).
Filed handoff: `inbox/notes/2026-05-19-hexa-arch-rfc006-yosys-handoff.md`.

## Module index (rfc_006 §4)

| file | purpose | re-derives from |
|---|---|---|
| `rtlil.hexa.stub`         | Yosys' internal RTLIL IR (Register-Transfer-Level Intermediate Language) — module / wire / cell / process typed data model | `kernel/rtlil.h`, `kernel/rtlil.cc` |
| `read_verilog.hexa.stub`  | Verilog-2005 subset frontend → RTLIL — synthesizable subset only (no behavioral simulation constructs) | `frontends/verilog/verilog_*.y`, `frontends/verilog/verilog_*.cc` |
| `passes.hexa.stub`        | core pass library — `proc`, `opt`, `flatten`, `synth_generic` style passes operating on RTLIL | `passes/cmds/*`, `passes/opt/*`, `passes/proc/*`, `passes/techmap/*` |
| `liberty.hexa.stub`       | Liberty (`.lib`) cell-library parser — gate types · area · timing · power · pin info for the target standard-cell library | `passes/techmap/libparse.cc`, `passes/techmap/libparse.h` |
| `abc_map.hexa.stub`       | **D18 bounded-subprocess wrapper for ABC** — emit AIG/BLIF, invoke `abc` binary, parse mapped result back to RTLIL · fail-loud on missing binary / non-zero exit | `passes/techmap/abc.cc` (Yosys side); ABC = <https://github.com/berkeley-abc/abc> |
| `write_verilog.hexa.stub` | mapped-RTLIL → gate-level Verilog netlist backend | `backends/verilog/verilog_backend.cc` |
| `yosys.hexa.stub`         | dispatcher — `hexa yosys <subcmd>` entry, exit-code policy 0/1/2/90/91 (rfc_001 §7.3 / rfc_006 §4) | `kernel/yosys.cc` (main loop); `frontends/script/script.cc` (script driver) |

Each module carries a `#!hexa strict` shebang, a clean-room provenance
header citing upstream file + license + branch-stable identifier, per-fn
`// CLEAN-ROOM` markers (when bodies land), and a `fn main()` self-test
that currently `exit(91)` (skeleton phase per rfc_048 raw-91 doctrine).

## CLI surface (rfc_006 §4 dispatcher)

```sh
hexa yosys                       # default = help
hexa yosys --help                # subcmd + flag listing
hexa yosys --version             # 0.0.1-skeleton
hexa yosys selftest              # run all module fn main() self-tests
hexa yosys read-verilog <file>   # Verilog → RTLIL JSON dump
hexa yosys synth <opts>          # full flow: read_verilog → passes → abc_map → write_verilog
hexa yosys write-verilog <out>   # last RTLIL → gate netlist
```

Exit codes (rfc_001 §7.3): `0`=ok · `1`=user error · `2`=runtime error ·
`90`=measurement gate OPEN (no absorbed claim) · `91`=TBD stub hit
(rfc_048 raw-91 doctrine).

## Measurement gate (rfc_006 §5, g3 — REQUIRED for "absorbed" claim)

`stdlib/yosys absorbed` may be claimed **only** when the flow:

1. Reads `~/core/hexa-lang/comb/rtl/router_d4.v` and `router_d6.v`
   (Verilog-2005, already iverilog-PASS per
   `comb/COMB.tape::x_comb_artifacts.t2_cycle_accurate_func`).
2. Synthesizes against the SKY130 `sky130_fd_sc_hd` standard-cell
   library (Liberty + Verilog cell models).
3. Reproduces the cited area oracle within ±5%:
   - **d4 router** ≈ 61,763 µm²
   - **d6 router** ≈ 93,609 µm²
   - **ratio** ≈ 1.516× (d6/d4)
4. Files the numbers + provenance into `comb/rtl/synth_comparison.md`
   or successor.

Until **all four** items file, GATE-style: no "absorbed" claim, no
`PATCHES.yaml` `applied` flip, no claim of rfc_006 closure. The 1.516×
oracle is the d4-vs-d6 area ratio committed by comb T2 closure (
`x_comb_artifacts.t2_yosys_synth = "cell ratio 1.80×"` was generic
synth without PDK; this gate requires the PDK-bound number).

## Boundaries (g5 / g7 / D19)

- **D18 ABC bounded-subprocess (hexa-arch D18 = `AGENTS.tape` g5
  hybrid exception):** `abc_map.hexa` invokes the system `abc` binary
  as documented absorbed-substrate. Provenance recorded to stderr on
  every call (cited URL + binary version + exit code). NOT a full ABC
  clean-room re-derivation (hexa-arch D18 rejected 7b explicitly).
- **NOT a default codegen backend (g5):** Yosys is a synthesis tool
  for HDL → gate-level netlist, NOT a compiler backend. `AGENTS.tape`
  g5 "no LLVM · no C-transpile" stays; this stdlib is for RTL→gate
  synthesis only.
- **SSOT placement (D15/D19):** `stdlib/yosys/` is hexa-lang's
  exclusively (same pattern as `stdlib/booksim/`). hexa-arch
  *references*; does not carry its own `stdlib/` copy.
- **Inbox flow (g7):** downstream consumers (e.g. hexa-arch chip
  domain) file gaps to `inbox/patches/` — never inline-edit this
  tree.

## cited sources

- Yosys — <https://github.com/YosysHQ/yosys> (ISC license)
- Yosys manual — <https://yosyshq.readthedocs.io/projects/yosys/>
- ABC — <https://github.com/berkeley-abc/abc> (Apache-2 / MIT, invoked
  as D18 subprocess only)
- SKY130 PDK — <https://github.com/google/skywater-pdk>
  (`sky130_fd_sc_hd` high-density stdcell)
- rfc_006 (hexa-arch) — `~/core/hexa-arch/proposals/
  rfc_006_yosys_absorption.md` (referenced via handoff note;
  hexa-arch repo not present locally as of 2026-05-19)
- Handoff note — `inbox/notes/2026-05-19-hexa-arch-rfc006-yosys-handoff.md`
- booksim sibling pattern — `stdlib/booksim/README.md` (rfc_001/rfc_003)

## Toolchain limits to expect (rfc_003 finding, carried forward)

- No `match` keyword — use `if`/`else if` chains
- enum-equality broken in some cases — compare via int payload
- No tuples — use struct + multi-return convention

These constraints shape the module surface (typed structs over tuples,
int-payload-tagged variants over enums-with-eq).

## Status row

```
status: BODIES-LANDED (all 7 modules; selftests 57/57 PASS)
gate:   OPEN (rfc_006 §5 SKY130 area oracle d4≈61,763 d6≈93,609 1.516×)
absorbed: NO (g3 — three substrate gaps: ABC binary, SKY130 lib,
            read_verilog subset; honest record at
            ~/core/demiurge/exports/chip/yosys/2026-05-19-gate-§5-record.md)
since:  2026-05-19 (skeleton) / 2026-05-19 (bodies)
next:   (a) read_verilog SCOPE expand (params/generate/always/case),
        (b) install berkeley-abc, (c) install skywater-pdk,
        (d) re-run gate_record.hexa, verify ±5 %.
```
