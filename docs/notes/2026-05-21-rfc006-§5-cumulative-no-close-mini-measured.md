# rfc_006 §5 — cumulative 5-commit run did NOT close gate (mini-measured)

**Date** : 2026-05-21
**Host** : mini (arm64 Mac, hexa-lang build pool offload target)
**Branch** : worktree-agent-aecab19ae399c6ca1 (head `e4f79e26`)
**Measured commits** (cumulative source under test):
  - `df4ff3f7` — RFC 006 §5 Option I — BLIF .latch per-bit expansion
  - `5c02c24d` — (preceding cumulative)
  - `572de4c4` — (preceding cumulative)
  - `2626bf70` — (preceding cumulative)
  - `56d3c42b` — (preceding cumulative)
  Plus head `e4f79e26` (abc_map stale-blif truncate + combinational-loop stdout detection).

**Status** : `OPEN` — §5 ±5 % gate FAILED. Numerics identical to pre-cumulative
baseline (same Δ values as mini's last measured run before this 5-commit set).

## Approach taken (A → host pivot)

Original plan: ubu-2 Linux x86_64 + zig cc cross-compile to aarch64-linux +
qemu-user-static. Host pivot mid-run:

1. ubu-2 lost SSH ~10 min into the cross-build (multi-minute timeout, persisted
   30+ s; not transient). Pre-pivot evidence captured:
   - `dist/linux-x86_64/hexa_v2` (build_c.hexa-based, **stale**) emits retired
     shim names `hexa_str_trim` / `hexa_str_starts_with` / `hexa_read_file`
     which the current `runtime_core.c` has retired (codegen now emits
     `rt_str_*` directly). Linux x86_64 hexa_v2 + current runtime.c = link skew.
   - `zig cc -target aarch64-linux-musl` blocked by musl header collisions with
     runtime.c's `#define memset/memcpy/sched_*` macro overrides.
   - `zig cc -target aarch64-linux-gnu` compiled cleanly with `-include
     sys/file.h -include stdarg.h -Wno-int-conversion -I /tmp/musl_includes`
     (stubbed `execinfo.h`). Binary built (5 MB ARM64 ELF) BUT qemu-aarch64
     8.2.2 (Ubuntu 24.04) hit internal SIGSEGV after `io_cancel`/`set_robust_
     list` ENOSYS + `Unknown syscall 293` (rseq?) during libc startup. Plain
     hello-world worked, so qemu is OK for simple binaries but fails on
     glibc-2.39 init paths of this size. Cross-compile path technically
     viable; qemu-emulation path blocked by kernel-emulation gap.
2. mini came back online ~30 min into ubu-2 outage. mini is arm64 native +
   has yosys 0.65 (`/opt/homebrew/bin/yosys`, `/opt/homebrew/bin/yosys-abc`)
   + SKY130 lib at `/Users/mini/.pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/
   sky130_fd_sc_hd__tt_025C_1v80.lib`. Authorized per memory
   `reference_mini_build_host.md` (= designated arm64 build offload pool host,
   distinct from `local-Mac no-heavy-build` rule).

## Build chain (mini)

All on `/tmp/hexa-closure-mini` (full worktree rsync, 108 MB).

Env:
```
unset HEXA_LANG
HEXA_MAC_BUILD_OK=1
HEXA_MODULE_LOADER=/tmp/hexa-mloader   # local-Mac build/hexa_module_loader scp'd
PATH=/tmp:/opt/homebrew/bin:$PATH      # /tmp/hexa-build = local-Mac hexa.real scp'd
```

Note: mini did NOT have a pre-built `hexa.real` or `hexa_module_loader`. They
were scp'd from `/Users/ghost/.hx/bin/hexa.real` (601040 B,
`May 21 03:47`) and `/Users/ghost/core/hexa-lang/build/hexa_module_loader`
(434384 B, `May 21 14:09`) — both already-built local-Mac arm64 Mach-O. No
heavy build happened on local Mac for this run; the binaries existed.

`tool/build_aprime.sh -o /tmp/aprime_cc` also ran on mini (1.16 MB Mach-O
arm64, smoke `exit(6*7) == 42` PASS) but the §5 chain uses the bigger
`hexa.real` driver, not aprime_cc.

## Selftests (all PASS on mini)

- `read_verilog.hexa` → `/tmp/rv_test` → `79/79 PASS`
- `passes.hexa` → `/tmp/passes_test` → `35/35 PASS`
- `abc_map.hexa` → `/tmp/abc_test` → `10/10 PASS` (D18 fail-loud OK)

## §5 measurement (mini)

`stdlib/yosys/gate_record.hexa` → `/tmp/gate_test`, ran to completion both
d4 and d6 pipelines. Full pipeline log captured 10/10 stage `[OK]` per route,
no `[FAIL]`.

| route | area µm² | oracle µm² | Δ % | within ±5 %? |
|-------|---------:|-----------:|-----:|:-------------|
| `router_d4.v` | **32829.0** | 61763 | **46.8468 %** | **FAIL** |
| `router_d6.v` | **45936.6** | 93608.5 | **50.927 %** | **FAIL** |

**Both areas IDENTICAL to pre-cumulative baseline** (d4=32829, d6=45937 in
the prompt's pre-cumulative line). The 5-commit cumulative did not move the
needle.

## Histogram diagnostics (root cause)

Output BLIF `_const0_` placeholder dominance — the techmap is failing to
cover the bulk of the logic; what's left are constant-zero placeholders.

`/tmp/_hexa_yosys_gate_d4_out.blif`:
```
1638  _const0_              ← placeholder, no real cell
   5  sky130_fd_sc_hd__nor2_1
   5  sky130_fd_sc_hd__nand2_1
   5  _const1_              ← placeholder, no real cell
```

`/tmp/_hexa_yosys_gate_d6_out.blif`:
```
2292  _const0_              ← placeholder
   7  sky130_fd_sc_hd__nor2_1
   7  sky130_fd_sc_hd__nand2_1
   7  _const1_              ← placeholder
```

`_const0_` drop: NOT achieved. The const-fold or post-techmap drop pass
isn't eliminating them. Only 10 (d4) / 14 (d6) real SKY130 cells emitted —
two cell types only (nor2, nand2). This is the missing-cell-coverage
phenomenon the memory `project_stdlib_cloud_cycle_a.md` flagged as next
blocker after PR #125: `passes.hexa::pass_techmap_sky130` cell coverage
needs `$add · $mod · $mux · $logic_*` mapping, and `_const0_`/`_const1_`
need a const-drop pass.

The cumulative 5 commits (`df4ff3f7`+ predecessors) addressed BLIF
`.latch` per-bit expansion (sequential modeling correctness) — orthogonal
to combinational cell-coverage. Hence: identical area numerics → expected
honest negative for §5 closure-by-cumulative.

## Critical verdict

**§5 ±5 % closure: NO**. The 5-commit cumulative under measurement does
NOT close §5. Root cause is unchanged from pre-cumulative state: techmap
cell-coverage gap + const-cell drop pass missing. Numerics are byte-stable
across the cumulative range on this measurement host (mini).

## Deliverables checklist

1. ✅ Approach chosen: **A → host pivot to mini** (ubu-2 dropped; zig cc /
   qemu path blocked by qemu glibc-init SIGSEGV; mini = sanctioned arm64 build
   pool host).
2. ✅ Build result: mini build OK (read_verilog/passes/abc_map/gate_record
   all built via `hexa-build` arm64 native, no qemu).
3. ✅ Selftests: read_verilog 79/79 · passes 35/35 · abc_map 10/10.
4. ✅ §5 numerics: d4=32829.0 µm² (Δ=46.85 %) · d6=45936.6 µm² (Δ=50.93 %).
5. ✅ `_const0_` count: 1638 (d4) · 2292 (d6) — drop NOT achieved.
6. ✅ Histogram: 2 SKY130 cell types only (nor2_1, nand2_1) — cell coverage
   gap is the dominant blocker.
7. ✅ Verdict: §5 ±5 % NOT closed by this cumulative.
8. ✅ Branch: `worktree-agent-aecab19ae399c6ca1` · this note's commit SHA
   recorded in commit message.

## Hazards encountered

- ubu-2 SSH outage (multi-minute, no recovery in 30+ s polling). Pre-pivot
  artifacts left at `ubu-2:/tmp/hexa-closure-arm64/` and `/tmp/hexa_v2_arm64*`
  (when host returns).
- `dist/linux-x86_64/hexa_v2` is build_c.hexa-vintage (emits retired shim
  names) — not usable against current runtime.c. Filing: rebuild dist linux
  hexa_v2 from current `self/native/hexa_cc.c` next time ubu-2 stable.
- Pre-existing `/Users/ghost/core/hexa-lang/comb/rtl/router_d{4,6}.v`
  symlinks on mini pointed to defunct `/tmp/hexa-lang-closure/` — re-pointed
  to `/tmp/hexa-closure-mini/comb/rtl/`. `/Users/ghost/.pdk/...sky130_fd_sc_hd
  __tt_025C_1v80.lib` was already a working symlink.

## Honest scope of this run

This is a measurement run only. No source under measurement was modified;
no codegen seam touched. The negative result is consistent with the
pre-cumulative baseline value reported in the prompt. The 5-commit cumulative
is orthogonal to §5 closure's remaining blockers (techmap cell coverage +
const-cell drop pass).
