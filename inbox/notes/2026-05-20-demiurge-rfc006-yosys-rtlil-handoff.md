# demiurge → hexa-lang handoff: rfc_006 Yosys §4 module-1 (rtlil) PROGRESS

**Date:** 2026-05-20
**Source repo:** `~/core/demiurge/` (audit trail commits pending; design.md D68, PLAN.md κ-45, ABSORPTION.md row "진행")
**Target repo:** `~/core/hexa-lang/` (branch `rfc006-yosys-rtlil-skeleton`, HEAD `ec8a51fc`)
**Status:** PROGRESS — first hexa-native body of the 7-module rfc_006 absorption is GREEN. Six modules + dispatcher integration still raw-91.
**Mode:** D61 (demiurge = pointer / spawn wrapper ONLY) 준수 — demiurge `.swift` 0줄 수정. hexa-lang 측 body landing. Filed from a demiurge session under the user's `/goal "완료시까지 진행"` + "hexa upstream 필요시도 이 세션에서 진행" autonomy.

This continues `~/core/hexa-lang/inbox/notes/2026-05-19-hexa-arch-rfc006-yosys-handoff.md` item ② ("IMPLEMENT rfc_006 Yosys §4 modules") — author chain: hexa-arch (rfc author) → demiurge (this note) → hexa-lang (future implementer).

## 0. TL;DR

Three things a follow-up hexa-lang session needs to know.

- **① module-1 `rtlil` body landed.** `stdlib/yosys/rtlil.hexa` (280 lines) — Wire + Module + Design minimum data model. `hexa run stdlib/yosys/rtlil.hexa` → **16/16 PASS**. Commit `ec8a51fc` on branch `rfc006-yosys-rtlil-skeleton` (cut from `t4-emt-calc` HEAD `0626febc`).
- **② Six modules + dispatcher integration still raw-91.** `read_verilog` · `passes` · `liberty` · `abc_map` · `write_verilog` (+ `yosys.hexa` dispatcher's `use` lines still commented per phase-g header). Module-2 (read_verilog) is the natural next pickup — the Verilog-2005 synth-subset frontend that converts comb `router_d{4,6}.v` into a `Design` instance.
- **③ rfc_006 §5 area-oracle gate REMAINS OPEN.** SKY130 area parity (d4 ≈61,763 µm² · d6 ≈93,609 µm² · ratio 1.516× ±5%) cannot be measured until all 7 modules + ABC bounded-subprocess (rfc_006 D18) are wired. `absorbed=true` is BANNED until that gate closes (g3).

## 1. Item ① — module-1 `rtlil` body landed

`ec8a51fc` `feat(stdlib/yosys): rtlil.hexa minimum body — Wire+Module+Design (rfc_006 §4 module-1)` lands the typed in-memory data model that `read_verilog` produces and `write_verilog` consumes (rfc_006 §4 lifecycle). Phase scope is the **Design ⇄ Module ⇄ Wire** surface only — no Cell, SigSpec, Process, or Memory yet.

**Public types**:

- `Wire { name: str, width: int, port: int }` — `port` is one of `PORT_NONE/INPUT/OUTPUT/INOUT` (int constants; the int-tagged idiom from rfc_003 because hexa enum-equality is broken).
- `Module { name: str, wires: [Wire] }` — linear ordered list of wires (RTLIL retains declaration order).
- `Design { modules: [Module] }` — linear ordered list of modules.

**Public fns** (all immutable, return new struct):

- `design_new() · design_add_module(d, name) · design_get_module_idx(d, name) → -1|idx · design_has_module(d, name) · design_module_count(d)`
- `module_new(name) · module_add_wire(m, w) · module_get_wire_idx(m, name) → -1|idx · module_has_wire(m, name) · module_wire_count(m)`

**Selftest** (16 invariants, all GREEN as measured):

1. empty design has 0 modules · 2-3. lookup-miss returns `-1` sentinel · 4-6. `add_module` + count + lookup hit + has_module hit · 7. 3-wire roundtrip (clk/rst/q) · 8-10. clk wire idx/width/port classification · 11-13. q wire idx/width/port (OUTPUT, 8-bit) · 14. has_wire miss · 15-16. Design ⇄ Module composability (wires recoverable through Design index).

**Toolchain limits applied** (rfc_003 finding):

- No `match` → `if/else` dispatcher.
- No tuples → fields are flat struct members.
- No nullable → `-1` sentinel for lookup-miss.
- No enum equality → int-tagged `PORT_*` constants.
- Immutable arrays → `xs.push(x)` returns new array (booksim convention, see `stdlib/booksim/iq_router.hexa` for sibling idiom).

**Clean-room provenance**: kernel/rtlil.h + yosyshq.readthedocs.io rtlil_rep.html — public surface only, no upstream code copied, ISC license boundary respected.

## 2. Item ② — Next pickups (in dependency order)

A follow-up hexa-lang session can take any of these in order. Each is its own commit on (or branched off) `rfc006-yosys-rtlil-skeleton`. The order respects rfc_006 §4 module dependencies.

**Module-2 `read_verilog`** (the largest single piece — ⭐⭐⭐⭐ of the 7):

- Spec: `stdlib/yosys/read_verilog.hexa.stub` lines 36-43 — the synth-subset (module/parameter/input/output/wire/reg/assign/always-comb/always-ff/if-else/case/casez/for-unroll/generate-for/instance/operators/concat).
- Output: an `rtlil.Design` (now available via `import "stdlib/yosys/rtlil.hexa"`).
- Acceptance: parse `~/core/demiurge/archive/comb/rtl/router_d{4,6}.v` end-to-end + a hand-written 30-line synth-subset corpus, assert module count + wire count + topology match.
- Will surface the need for **Cell** (instances) and **SigSpec** (RHS expressions on connections) — module-1 may need a follow-up commit to add those next. Keep the body purely-Design-Module-Wire here was the deliberate scope-narrow for this phase.

**Module-3 `passes`**, **Module-4 `liberty`**, **Module-5 `abc_map`** (rfc_006 D18 `(7a) bounded-subprocess` — invoke ABC as documented absorbed-substrate subprocess, fail-loud; do NOT clean-room re-derive ABC), **Module-6 `write_verilog`**, and **Module-7 dispatcher wiring** in `yosys.hexa` (uncomment the `use` of read_verilog/passes/abc_map/write_verilog once their bodies are GREEN).

**§5 area-oracle gate close (rfc_006 §5)** — only after the above 6 modules land and ABC bounded-subprocess + SKY130 `sky130_fd_sc_hd` lib are wired. Acceptance per rfc_006: `router_d4.v` synthesizes to ≈61,763 µm² · `router_d6.v` to ≈93,609 µm² · ratio 1.516× within ±5% of the cited area oracle. ONLY THEN may `absorbed=true` be claimed.

## 3. Branch policy + PR target

- Current branch: `rfc006-yosys-rtlil-skeleton` (this branch, HEAD `ec8a51fc`).
- Cut from: `t4-emt-calc` HEAD `0626febc` (NOT `rfc043-hexa-torch` — the t4-emt-calc working tree has 9 in-flight untracked stdlib/* directories from sibling cohort work; keeping yosys-rtlil on its own branch isolates the audit-visible diff).
- Final PR target on hexa-lang side per the 2026-05-19 hexa-arch handoff: `rfc043-hexa-torch` (the booksim absorb sibling — same `stdlib/<topic>/` namespace, same clean-room idiom). A follow-up session can rebase or cherry-pick `ec8a51fc` onto `rfc043-hexa-torch` once that branch is the working target.

## 4. Provenance / boundary (g3)

This session touched these hexa-lang files only:

- `stdlib/yosys/rtlil.hexa` (new, 280 lines — commit `ec8a51fc`)
- `inbox/notes/2026-05-20-demiurge-rfc006-yosys-rtlil-handoff.md` (this note)
- `inbox/PATCHES.yaml` (one entry appended — see commit)

No other hexa-lang files modified. No `self/`, `compiler/`, or sibling `stdlib/*` directories touched. The 9 untracked sibling stdlib directories (`stdlib/antimatter/`, `stdlib/aura/`, `stdlib/bot/`, `stdlib/cern/`, `stdlib/energy/`, `stdlib/freecad/`, `stdlib/fusion/`, `stdlib/grid/`, `stdlib/scope/`, `stdlib/space/`, `stdlib/sscb/`) on the t4-emt-calc parent branch are unmodified by this work and remain the responsibility of their own sessions.

g3 honesty distance for "Yosys absorbed=true": **(1/7 modules body landed) → six modules + ABC subprocess + SKY130 lib + area-oracle ±5% parity** — every component must be record-pinned before `absorbed=true` may be claimed. Until then, every yosys-related measurement_gate stays `GATE_OPEN` and the dispatcher selftest's PASS line means "routing works", not "Yosys absorbed".

## 5. cross-link

- demiurge `design.md` Decision 68 — Yosys rtlil hexa-native body landing 시작 (rfc_006 §4 module-1, κ-45)
- demiurge `PLAN.md` κ-45 — progress log entry with measurement facts
- demiurge `ABSORPTION.md` 178행 — Yosys row marked "진행"
- preceding handoff: `~/core/hexa-lang/inbox/notes/2026-05-19-hexa-arch-rfc006-yosys-handoff.md` (item ② is now PROGRESS, not OPEN — author chain hexa-arch → demiurge → hexa-lang)
- rfc_006 spec: `~/core/demiurge/proposals/rfc_006_yosys_absorption.md` §4 (module list) + §5 (the measured gate)
- rfc_003 toolchain limits (rfc_003 §3 — "no match, enum-eq broken, no tuples")
- AGENTS.tape `@D g_demiurge_pointer_only` (D61) · `@D g_stdlib_ownership` (D15)
