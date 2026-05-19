<!-- @created: 2026-05-20 -->
<!-- @scope: roadmap — eliminate firmware/RTL non-hexa source classes; reach parity in pure hexa AOT -->
<!-- @authority: HEXA-NATIVE-ONLY.md (ML/runtime sibling) · AGENTS.tape §3 @D g5 hexa-native-only -->
<!-- @sibling: HEXA-NATIVE-ONLY.md (ML hot-path C-kernel retirement) -->
---
type: native-only-roadmap
session: 2026-05-20
target: every byte that ships to a device or fabric is generated FROM `.hexa` — no human-authored firmware C, no human-authored RTL Verilog/VHDL, no glue Python/shell
blocks: future PRs that introduce `.c`/`.h`/`.cpp`/`.hpp`/`.cc`/`.hh`/`.s`/`.S`/`.v`/`.sv`/`.vhd`/`.vhdl`/`.py`/`.sh` source under `self/` `stdlib/` `compiler/` `tool/` (artifacts under `build/` `dist/` are not source)
---

# FIRMWARE.md — single-source firmware & RTL from `.hexa`

> **Question (sibling to HEXA-NATIVE-ONLY.md)**: ML hot-paths used to land
> as C kernels in `self/runtime.c`; that doc plans their retirement to pure
> hexa AOT. Can the **same retirement** be applied one ring outward — to
> the firmware (CPU/MCU/GPU device code) and the RTL (Verilog/SystemVerilog/
> VHDL) that the project will increasingly emit and consume?

> **Answer (this roadmap)**: yes, by **forbidding the source classes** and
> routing every device byte / every netlist line through a `.hexa` emitter
> in `stdlib/`. `stdlib/yosys/{read,write}_verilog.hexa` already proves the
> read+write side; this document extends the same pattern to firmware and
> the other RTL dialects, and to the glue languages (Python/shell) that
> historically slip in alongside.

---

## §1 Forbidden source classes (write-deny — same status as `@F f2 llvm-c-transpile-backend`)

The classifier below applies to **new** source files added under
`self/` `stdlib/` `compiler/` `tool/` `inbox/` (and any future top-level
directory other than `build/` `dist/` `target/` `out/` and any path under
`.git/`). Existing files predating this roadmap are tombstoned per §3 and
retired per §4 — they are **not** grand-fathered as a license to add more.

| ext | territory | rationale | replacement (this roadmap) |
|---|---|---|---|
| `.py` | scripts / glue | hexa absorbs subprocess + http + json + sqlite + argparse equivalents | `stdlib/<domain>/*.hexa` + `tool/<name>/main.hexa` |
| `.sh` | scripts | hexa absorbs `exec_capture` + `[str]` argv quoting (see `stdlib/cloud`) | `tool/<name>/main.hexa` |
| `.c` `.h` | firmware C / runtime kernels | hexa AOT lowers to `.c` artifact under `build/`, never as authored source | `.hexa` + `@target(firmware)` |
| `.cpp` `.hpp` `.cc` `.hh` | firmware C++ | same — no firmware uses C++ class semantics that hexa structs+traits cannot express | `.hexa` |
| `.s` `.S` | hand assembly | hexa `@asm(...)` escape hatch covers the irreducible per-CPU peaks; everything else is codegen output, not authored | `.hexa` + `@asm` (rare) |
| `.v` `.sv` | Verilog / SystemVerilog | `stdlib/yosys/{read,write}_verilog.hexa` is the round-trip; new RTL is authored as `.hexa` and lowered by `stdlib/yosys/write_verilog.hexa` to a `build/` artifact | `.hexa` + `@target(rtl)` → `stdlib/yosys/write_verilog` |
| `.vhd` `.vhdl` | VHDL | same shape; a `stdlib/vhdl/write_vhdl.hexa` mirror of the yosys path | `.hexa` + `@target(rtl)` → `stdlib/vhdl/write_vhdl` |

Out of scope (allowed):

- `build/` `dist/` `target/` `out/` artifacts — these are **emitter
  output**, not authored source. `.c` under `build/` from hexa AOT is the
  intended steady state, exactly as today.
- Vendored 3rd-party tarballs that the project does not edit (the build
  consumes them as binary inputs). If a vendored source is patched, the
  patch lives in `inbox/patches/` as `.hexa`-codegen instructions, not as
  a sidecar `.c` diff.
- Existing `self/runtime.c` and the `self/native/` C frontend — these are
  the **bootstrap** layer, retired by HEXA-NATIVE-ONLY.md gates G-0..G-11
  (ML side) and §4 below (firmware/RTL side). They are not a license to
  add new C sources.
- `compiler/atlas/embedded.gen.hexa` and other `.gen.hexa` files —
  generator output that happens to be `.hexa`. They are checked in per
  `@D g_atlas_binary_builtin` but never hand-edited.

---

## §2 Why each class is forbidden (one paragraph each)

### `.py` / `.sh` — glue rot

Glue scripts are the canonical drift surface: they accumulate
domain-specific behaviour (retry, secrets, env, quoting) outside the type
checker, the citation lint, and the @cite atlas. Every `tool/dispatch_*.sh`
that was ported to `dispatch_*.hexa` measured the same win — fewer LoC,
no quoting bugs, structured `[str]` argv (`stdlib/cloud` cycle A, MERGED
hexa-lang main PR #81). The hexa side already covers `exec_capture` /
`exec_argv_with_status` / http + json + sqlite. **No new `.py` or `.sh`
goes into the repo;** existing ones get a `.hexa` rewrite or a tombstone.

### `.c` / `.h` / `.cpp` etc. — firmware C class

Firmware C exists for two reasons: (a) the toolchain (clang / gcc /
arm-none-eabi-gcc / xtensa-esp32-gcc) wants C as input, and (b) hand-tuned
intrinsics. (a) is solved by hexa AOT emitting `.c` to `build/` — the
toolchain still gets C, just not from a human. (b) is solved by the same
`@asm` escape that `HEXA-NATIVE-ONLY.md §F10` already lists. The thing
forbidden is **`.c` as an authored source file** alongside `.hexa`, which
re-creates the C-kernel anti-pattern the ML side is currently retiring.

### `.s` / `.S` — hand assembly class

If a routine genuinely needs a hand-written instruction sequence, it
lives **inside** a `.hexa` function as `@asm(arch=arm64, ...) { ... }`,
not as a sibling `.s` file linked at the end of the build. The `@asm`
form keeps the call site visible to the type checker, the citation lint,
and the dead-code analyser; a standalone `.s` is invisible to all three.

### `.v` / `.sv` / `.vhd` / `.vhdl` — RTL class

`stdlib/yosys/read_verilog.hexa` already parses Verilog into the project's
RTLIL representation. `stdlib/yosys/write_verilog.hexa` emits it back. The
**authored** form is therefore not Verilog — it is `.hexa` with a
`@target(rtl)` annotation that the yosys pass set lowers. VHDL gets the
mirror module (`stdlib/vhdl/`, scaffolded by §4 G-R3) by the same shape.
Hand-authored RTL re-introduces the very thing we just absorbed.

---

## §3 Tombstone policy — pre-existing source under the ban

Files that already exist and match the ext list above on `2026-05-20`
fall into one of three buckets:

1. **bootstrap** — `self/runtime.c` `self/native/*.c` `self/native/*.h`
   `self/native/*.cu` `self/native/*.m` `self/native/*.metal`
   `self/cuda/*.c`. These are the existing C bootstrap + GPU substrate;
   their retirement is owned by HEXA-NATIVE-ONLY.md gates G-0..G-11 (ML
   axes) and §4 G-F1..G-F4 below (firmware axes). They stay in-tree until
   the bench fixture proves parity per the sibling doc.
2. **vendored / generated** — anything matching `compiler/atlas/*.gen.*`,
   `dist/**`, `build/**`, third-party tarballs. Untouched.
3. **legacy authored** — anything else (e.g. `stdlib/freecad/bipv.py`,
   stray `.sh` scripts in `tool/`). These are **tombstone candidates**:
   - within the cycle that adds this doc: each gets a one-line entry in
     this section's table (path · why-it-exists · replacement plan).
   - within the next 2 cycles: each is either rewritten as `.hexa` or
     moved to `archive_<name>/` (mirroring the qrng / qmirror /
     sim-universe absorption pattern — `@D g_atlas_binary_builtin`-class
     "frozen archive" treatment).

| legacy file | why it exists | replacement plan |
|---|---|---|
| `stdlib/freecad/bipv.py` | one-off Building-Integrated-PV CAD helper, predates `stdlib/freecad` being declared hexa-only | rewrite as `stdlib/freecad/bipv.hexa` driving FreeCAD via `exec_capture`; or move to `archive_freecad_bipv/` if not consumed in-tree |
| _(populate during cycle)_ | _grep `'\.(py|sh|c|h|cpp|hpp|cc|hh|s|S|v|sv|vhd|vhdl)$'` for non-bootstrap, non-vendored matches_ | _one row per file_ |

The grep that populates the rest of this table runs in §4 G-T0 (the very
first gate); the table above is the **shape**, not the final list.

---

## §4 Phased gates — capability + retirement, mirroring HEXA-NATIVE-ONLY.md §4

Each gate ships one capability and immediately retires a slice of the ban
list behind a bench / round-trip fixture in `self/bench/firmware/` or
`stdlib/yosys/test/` (or the per-domain test dir). Order is rough cost,
ascending. Gate IDs use **G-T** (tombstone/glue), **G-F** (firmware), and
**G-R** (RTL) prefixes so they do not collide with the ML side's G-0..G-11.

### Tombstone + glue lane

| Gate | Capability shipped | Replaces | Exit fixture |
|------|--------------------|----------|--------------|
| **G-T0** | populate §3 legacy-authored table by repo-wide grep (excluding bootstrap + vendored + generated) | n/a (audit) | `tool/audit_forbidden_exts.hexa` runs in CI, output stable |
| **G-T1** | port `stdlib/freecad/bipv.py` → `bipv.hexa` (or tombstone to `archive_freecad_bipv/`) | one row in §3 table | parse-clean + `hexa run stdlib/freecad/bipv.hexa --smoke` matches the old `.py` output byte-for-byte on one fixture |
| **G-T2** | port remaining authored `.sh` under `tool/` to `tool/<name>/main.hexa` | each row in §3 table tagged `kind=sh` | each ported tool has a byte-eq fixture vs the old `.sh` on at least one input |
| **G-T3** | `tool/audit_forbidden_exts.hexa` becomes a **pre-push hook** (warn) and a strict-lint stage opt-in (fail) | enforces the ban going forward | hook fires on a synthetic `.py` add; CI green on clean tree |

### Firmware lane

`@target(firmware)` is the proposed hexa annotation. A function or a
module annotated with it is lowered by the AOT codegen into a `.c`
artifact under `build/firmware/<target>/` and then handed to the
toolchain (clang / arm-none-eabi-gcc / xtensa-esp32-gcc / riscv64-unknown-
elf-gcc). The hexa surface stays the same — only the lowering target
changes. ML-side gates A1+A2+A5+A6 (HEXA-NATIVE-ONLY.md §2A) are the
same axes the firmware lane needs.

| Gate | Capability shipped | Replaces | Exit fixture |
|------|--------------------|----------|--------------|
| **G-F0** | `@target(firmware, arch=<cortex-m0/m4/m33, riscv32, xtensa, ...>)` annotation parsed; codegen emits a `.c` artifact + a per-arch `link.ld` template | hand-authored bare-metal `.c` files | one Cortex-M0 blinky in `stdlib/firmware/test/blinky.hexa` builds with arm-none-eabi-gcc and produces a `.elf` whose `.text` is byte-stable across rebuilds |
| **G-F1** | startup vector / reset handler / `.bss` zero / `.data` copy emit | startup `.s` files | the `.elf` from G-F0 boots in qemu-system-arm and reaches `main()` |
| **G-F2** | MMIO `volatile`-equivalent — a `@mmio` annotation that codegen lowers without optimisation reorder | `volatile uint32_t * = 0x40000000` C idioms | a UART-echo demo on qemu-system-arm using only `.hexa` MMIO accesses |
| **G-F3** | `@interrupt(handler=...)` annotation, vector-table injection | hand-coded IRQ stubs | a SysTick-tick demo, hexa-only |
| **G-F4** | `@asm(arch=..., clobbers=...)` escape (the irreducible peaks) | last-resort hand `.s` | one ISR-fastpath that needs a `bx lr` writes through `@asm` |

### RTL lane

`@target(rtl)` is the proposed hexa annotation. A module annotated with
it is lowered by `stdlib/yosys/write_verilog.hexa` (or
`stdlib/vhdl/write_vhdl.hexa` — G-R3) into Verilog/SV/VHDL under
`build/rtl/<flavour>/`. The hexa surface for combinational + sequential
logic is the existing `stdlib/yosys/rtlil.hexa` RTLIL representation
exposed as a typed `.hexa` DSL.

| Gate | Capability shipped | Replaces | Exit fixture |
|------|--------------------|----------|--------------|
| **G-R0** | `stdlib/yosys/read_verilog.hexa` parses 12 reference Verilog modules round-trip (already in flight on this branch per commits `da6badba`, `82748da6`, `36bbdfc6`, `aa489cfe`) | hand-authored Verilog as input | `.v` → RTLIL → `.v` byte-eq on 12 fixtures |
| **G-R1** | `@target(rtl)` annotation on a hexa module is parsed into RTLIL by a new front-end pass | the **authoring** of `.v`/`.sv` files | one `stdlib/yosys/test/counter.hexa` emits a Verilog `counter.v` whose synthesis (yosys → ABC) matches a reference netlist |
| **G-R2** | SystemVerilog dialect emit (`.sv`) from the same RTLIL | hand-authored `.sv` | a 2-of-3 voter demo emitted as `.sv` matches a reference |
| **G-R3** | `stdlib/vhdl/write_vhdl.hexa` mirror of `write_verilog.hexa` | hand-authored `.vhd`/`.vhdl` | counter demo from G-R1 also emits to `.vhd`, synthesises through GHDL |
| **G-R4** | timing pragma annotations (`@clock`, `@reset`, `@async`) | RTL-side hand-tuned constraints | the counter demo passes static timing at 100 MHz on the reference part |

### Critical path

```
G-T0 → G-T1/G-T2 → G-T3                      ← shuts the door on new .py/.sh
G-F0 → G-F1 → G-F2 → G-F3 → G-F4             ← firmware authoring fully hexa-side
G-R0 (in flight) → G-R1 → G-R2 → G-R3 → G-R4 ← RTL authoring fully hexa-side
G-T3 ∥ G-F4 ∥ G-R4                            ← all three lanes can land independently
```

Exit criterion per gate: a measured fixture (byte-eq for round-trip,
synthesis match for RTL, `.elf` `.text` stability for firmware) and a
`@D` governance entry in `AGENTS.tape` § 3 forbidding the source class
that the gate just retired.

---

## §5 Anti-patterns — what NOT to do

- **Do not author `.c` "just for the bootstrap"** if the bootstrap already
  has a `.hexa` source. The bootstrap C layer (`self/native/hexa_cc.c`)
  is **generated** from `self/codegen_c2.hexa` per `@D g_commit_push_deploy`.
  Authoring a sibling `.c` re-creates the source/binary drift that rule
  exists to prevent.
- **Do not author `.v` "for synthesis"** when `stdlib/yosys/write_verilog`
  is the canonical lowering. Synthesis consumes the lowered `build/rtl/*.v`,
  not the authored sibling.
- **Do not bundle G-T (glue) with G-F (firmware) into one cycle.** They
  have completely different review surfaces — glue rewrites are byte-eq
  against the old `.sh`/`.py`; firmware authoring is a fresh capability
  with a qemu fixture.
- **Do not skip the audit gate (G-T0).** A complete legacy-authored list
  is a precondition for the ban; without it the ban is aspirational.
- **Do not write `.cpp` instead of `.c`** to dodge the rule. Both are
  banned by the same row in §1.
- **Do not let the `@asm` escape balloon.** It exists for genuine ISR
  fastpaths and per-CPU intrinsic peaks, not as a "well, this is faster
  in asm" backdoor. If `@asm` usage rises past ~5 sites across the
  firmware stdlib, that is a signal that the codegen lane has a missing
  axis — file an inbox patch, do not normalise `@asm`.

---

## §6 Verification anchors (LATTICE_POLICY.md §1.2 alignment)

This roadmap is bounded by real limits, not lattice fit:

- **Round-trip equality** (lossless emit ↔ parse) — `stdlib/yosys`
  fixtures: `.v` → RTLIL → `.v` byte-eq on 12+ reference modules. A
  fixture that diverges falsifies G-R0/G-R1.
- **Synthesis equality** (netlist-eq under yosys + ABC) — G-R1/G-R2
  exit: counter / voter demo netlist matches a reference. Limit-bound
  by RTL semantics, not by the hexa surface.
- **Cross-rebuild binary stability** (`.elf` `.text` md5 stable) — G-F0
  exit. A varying `.text` falsifies the codegen determinism claim.
- **Static-timing closure** (Fmax measured by the synth tool, not by
  hexa) — G-R4 exit. The tool is the oracle; hexa just generates the
  input.
- **Toolchain reachability** (qemu boot, ghdl analyse, yosys synth) —
  every firmware/RTL exit fixture must actually run, not just type-check.
  No "looks right" passes.

Per `LATTICE_POLICY.md §1.2`, every claim above is falsifiable by a
fixture that fails the equality / stability / closure check. The lattice
n=6 does not enter the verification — only the tool oracles do.

---

## §7 Inventory of in-flight evidence (status quo, 2026-05-20)

- `stdlib/yosys/read_verilog.hexa` — branch `s1-step2-codegen-perf`,
  commits `da6badba` (function-decl parsing, RFC 006 §4 m2), `82748da6`
  (expression elaboration → RTLIL cell tree), `36bbdfc6` (SymTab
  propagation + array indexing). This is **G-R0 in flight** — the lane
  exists, not just the plan.
- `stdlib/yosys/write_verilog.hexa` — present, `.stub` sibling shows the
  shape; the writer side is the natural G-R0 round-trip closer.
- `stdlib/cloud/*.hexa` (PR #81 MERGED main) — proof that `.sh` glue is
  fully replaceable; `dispatch_s126.hexa` is the worked example
  (anima repo, cycle A complete).
- `stdlib/freecad/bipv.py` — the **one** legacy `.py` currently in tree
  under `stdlib/`. G-T1 target.
- `self/native/gpu_codegen_stub.c` (per `@N native_dir`) — the existing
  `@gpu` codegen skeleton; G-F0/G-F2 (MMIO + `@target(firmware)`) can
  reuse the same annotation shape for the device-codegen back-end seam,
  reconciling with RFC 055 (hexa-src → NVPTX).

---

## §8 References

- Sibling roadmap (ML lane) — [`HEXA-NATIVE-ONLY.md`](HEXA-NATIVE-ONLY.md)
- Governance — `AGENTS.tape` §3 `@D g5 hexa-native-only`, `@D g7
  inbox-patches-pipeline`, `@D g_atlas_binary_builtin`,
  `@D g_commit_push_deploy`, `@D g_stdlib_ownership`
- Forbidden pattern siblings — `@F f2 llvm-c-transpile-backend`, `@F f3
  consumer-direct-edit`
- Real-limits policy — [`LATTICE_POLICY.md`](LATTICE_POLICY.md) §1.2
- Existing RTL absorption — `stdlib/yosys/{read_verilog,write_verilog,
  rtlil,abc_map,liberty,passes}.hexa`
- Existing glue replacement — `stdlib/cloud/` (cycle A, PR #81)
- Bootstrap retirement (ML side, ongoing) — HEXA-NATIVE-ONLY.md §4 gates
  G-0..G-11
- GPU codegen seam (firmware-adjacent) — `self/native/gpu_codegen_stub.c`,
  RFC 055 (hexa-src → NVPTX)

---

## Log

- 2026-05-20 — file created. Captures the firmware/RTL extension of
  HEXA-NATIVE-ONLY.md: bans `.py`/`.sh`/`.c`/`.h`/`.cpp`/`.hpp`/`.cc`/
  `.hh`/`.s`/`.S`/`.v`/`.sv`/`.vhd`/`.vhdl` as **authored** source under
  `self/` `stdlib/` `compiler/` `tool/` `inbox/`; phased gates G-T0..G-T3
  (tombstone + glue), G-F0..G-F4 (firmware lane via `@target(firmware)`),
  G-R0..G-R4 (RTL lane via `@target(rtl)` + `stdlib/yosys/write_verilog`).
  In-flight evidence: `stdlib/yosys/read_verilog.hexa` round-trip work
  (commits `da6badba`, `82748da6`, `36bbdfc6`, `aa489cfe` on branch
  `s1-step2-codegen-perf`) is **G-R0 in flight**, not just a plan.
  Single legacy `.py` under `stdlib/` (`stdlib/freecad/bipv.py`) is the
  G-T1 target. Pending: `@D` governance entries in `AGENTS.tape` will
  follow the gate-exit pattern — added only after each gate's fixture
  passes (not pre-emptively). No code change in this cycle.
