---
slug: rfc_090_target_firmware_rtl_codegen
kind: rfc_draft
filed_from: cycle-6 lane-4 RFC scan (g7-d-scaffold priority=high promote · codegen lane family)
filed_at: 2026-05-24
priority: high
status: proposed
promoted_from:
  - inbox/rfc_drafts_2026_05_20/rfc_063_target_firmware_codegen.md  # @target(firmware)
  - inbox/rfc_drafts_2026_05_20/rfc_064_target_rtl_codegen.md       # @target(rtl)
unblocks:
  - rfc_063  # @target(firmware) codegen lane (bare-metal · no-libc · linker-script)
  - rfc_064  # @target(rtl)      codegen lane (Verilog · SystemVerilog · VHDL emit)
consumer_demand:
  - FIRMWARE.md §1 금지 규칙 enable — 모든 firmware/RTL deliverable 가 `.c`/`.h`/`.s`/`.v`/`.sv`/`.vhd`
    authored 형태가 아닌 `.hexa` authored + codegen lane lowering 로 전환
  - `stdlib/firmware/{target,mmio,interrupt,asm,startup}.hexa.stub` consumer 가 freestanding
    lowering 을 요구 (G-F0..G-F4)
  - `stdlib/yosys/{read_verilog,write_verilog,rtlil}.hexa` + `stdlib/vhdl/write_vhdl.hexa.stub`
    consumer 가 hexa-source → RTLIL front-end pass 를 요구 (G-R0..G-R4)
external_llm_scope: 없음 (codegen lane + parser attribute recognition + stdlib lowering 작업;
  RFC 080 `hexa loop --dfs` 외 external LLM 호출 금지)
---

# RFC 090 — `@target(firmware)` + `@target(rtl)` codegen lanes (promote RFC 063 + RFC 064)

- **Status**: proposed (design-draft · RFC 063 firmware + RFC 064 rtl 두 draft 의 정식 번호 promote
  + 공통 codegen lane dispatch 표면 통합)
- **Date**: 2026-05-24
- **Severity**: HIGH (FIRMWARE.md §1 금지 규칙의 enabler · `.c`/`.s`/`.v`/`.sv`/`.vhd` authored-as-X
  의 hexa-source 대체)
- **Source**:
  - `inbox/rfc_drafts_2026_05_20/rfc_063_target_firmware_codegen.md` (status `DRAFT (scaffolded, codegen pending)`)
  - `inbox/rfc_drafts_2026_05_20/rfc_064_target_rtl_codegen.md` (status `DRAFT (scaffolded, codegen pending)`)
  - `da9c197e feat(self/codegen_c2): RFC 063/064 annotation placeholder` (annotation 인식만 land,
    lowering body 는 미구현 — commit message 자체에 "deferred to RFC 063 (firmware) and
    RFC 064 (rtl) dedicated cycles" 명시)
- **Implements**: 본 RFC = 통합 design + lane dispatch 표면 + 잔여 phase 정의. 구현은 phase 별
  별도 측정 사이클 (G-F0..G-F4 firmware · G-R0..G-R4 rtl · 각 PR 1개씩).

> **번호 promote 안내**: RFC 063 슬롯은 main 의 commit log 상 두 가지 work 가 공존한다 —
> (a) `S7 native assembler+linker campaign` (commit `019aecb6` / `446dcc45` / `7f18b5ea` /
> `774f2d56` · P0+P1+P2+P3 CLOSED, 머지 완료), (b) `@target(firmware) codegen lane` draft
> (`inbox/rfc_drafts_2026_05_20/rfc_063_target_firmware_codegen.md` · 미구현). 동일하게 RFC 064
> 슬롯은 `@target(rtl)` draft 만 존재한다. cycle-6 lane-4 RFC scan 이 priority=high 로 surface
> 한 것은 (b) 의 codegen lane 두 draft 다. 본 RFC 090 은 두 codegen lane 을 통합 번호로 묶고,
> 공통 lane dispatch 표면 (`@target(...)` attribute + `--target=...` driver flag) 을 한 곳에
> 정의한다. firmware lane / rtl lane 의 §-별 G-gate 는 원본 draft 의 텍스트를 그대로 inherit
> 하며, 본 RFC 는 그 위에 lane dispatch + 공통 falsifier + cross-link 만 추가한다.

---

## §1 Motivation

### 1.1 두 lane 의 공통 design surface

RFC 063 (firmware) 와 RFC 064 (rtl) 은 별개 draft 로 scaffold 되었지만, 다음 design surface 를
**완전히 공유**한다:

1. **target attribute** — `@target(<lane>, <kw=v>, ...)` 형태의 module/fn-scope annotation.
   `lane` ∈ {`firmware`, `rtl`} (현재) · 향후 확장 (`wasm`, `cuda`, `ptx`, ...) 가능.
2. **driver flag** — `hexa build --target=<lane>,<kw=v>,...` 형태. lane string 으로 codegen lane
   선택; `kw=v` 는 lane-specific (firmware: `arch`/`core`/`float`/`layout` · rtl: `dialect`/`version`/`clock`/`reset`).
3. **lane dispatch in codegen** — `self/codegen_c2.hexa` 의 emit 진입점이 `@target` attribute 를
   인식하여 lane-specific profile (freestanding for firmware · rtlil-lowering for rtl) 로 분기.
4. **emit dir convention** — `build/<lane>/<sub>/...` (firmware: `build/firmware/<arch>/` · rtl:
   `build/rtl/<dialect>/`).
5. **falsifier 형태** — lane-specific deterministic fixture + tool oracle (qemu / yosys / GHDL /
   arm-none-eabi-gcc) 의 PASS/FAIL.

두 RFC 를 별개로 진행하면 lane dispatch 표면 (1)(2)(3) 이 두 곳에서 독립 진화 → 차후 통합 시
schema drift 위험. 본 RFC 가 그 표면을 한 곳에서 정의한다.

### 1.2 FIRMWARE.md §1 금지 규칙 enable

FIRMWARE.md §1 은 `.c`/`.h`/`.cpp`/`.s`/`.v`/`.sv`/`.vhd` authored 형태를 금지한다. 그러나 현재
이 규칙은 **enable 안 됨** — `firmware/boards/<board>/firmware/{hdl,src}/...` 의 모든 deliverable
이 그대로 authored-as-C/HDL 이다. 본 RFC 의 두 lane 이 land 하면, §1 금지 규칙이 비로소 enforce
가능해진다 (`stdlib/firmware/*.hexa` + `stdlib/yosys/*.hexa` + `stdlib/vhdl/*.hexa` 가 authored
source 가 되고, `.c`/`.v` 등은 codegen output 으로만 존재).

### 1.3 authored-as-C 회피 → hexa-source lowering

두 lane 의 핵심 동기는 동일하다 — **"toolchain 은 C/HDL 을 원하지만, 인간은 hexa 를 author 한다"**.
arm-none-eabi-gcc / yosys / GHDL 의 input contract 는 그대로 유지 (각 tool 의 substrate 는
absorbed-subprocess 로 호출), 단지 그 input 이 hexa AOT 로 emit 된 결과물이라는 점이 달라진다.
RFC 070 → RFC 089 promote 가 정의한 "compile-and-load no-relink" 와는 직교 (089 는 host binary
의 runtime extension, 090 은 cross-compile target 의 cold emit).

---

## §2 Design

### 2.1 lane catalog

| lane       | scope                              | substrate (absorbed)              | output extension(s)   |
|------------|------------------------------------|-----------------------------------|------------------------|
| `firmware` | bare-metal MCU (ARM Cortex-M, RISC-V) | arm-none-eabi-gcc / riscv64-elf-gcc | `.c` (intermediate) → `.elf` |
| `rtl`      | hardware RTL (Verilog/SV/VHDL)    | yosys (verilog/sv) · GHDL (vhdl)  | `.v` / `.sv` / `.vhd` |

두 lane 모두 codegen 의 출력은 substrate 가 원하는 형태 (`.c` / `.v` / `.sv` / `.vhd`); substrate
호출은 absorbed-subprocess 보더 (`abc_map.hexa.stub` 같은 패턴). 향후 lane 확장 (e.g. `wasm`,
`cuda`, `ptx`) 은 본 RFC 의 lane dispatch 표면을 그대로 따른다.

### 2.2 `@target(firmware)` lane (RFC 063 inherit)

원본 draft (`inbox/rfc_drafts_2026_05_20/rfc_063_target_firmware_codegen.md`) §2-§7 을 그대로
inherit:

- annotation grammar: `@target(firmware, arch=..., core=..., layout=?, float=...)` ·
  `@mmio(addr, width, ordering)` · `@interrupt(vector, number)` · `@asm(arch, clobbers)`
- driver dispatch: `hexa build --target=firmware,arch=<arch>,core=<core>` →
  codegen `freestanding profile` + emit `build/firmware/<arch>/<file>.c` + `link.ld` →
  toolchain `<arm-none-eabi|riscv64-unknown-elf>-{gcc,ld} -nostdlib -T link.ld`.
- codegen contract: ①freestanding profile (no `<stdlib.h>`/`<stdio.h>`, no `malloc`/`free`)
  ②`@mmio` lowering (`volatile` + memory barrier) ③`@interrupt` lowering
  (`__attribute__((interrupt))` + vector-table inject) ④`@asm` lowering (`__asm__ volatile`
  + clobbers translate) ⑤`link.ld` template emit (per-arch).
- phasing: G-F0 → G-F1 → G-F2 → G-F3 → G-F4 (FIRMWARE.md §4 critical path).

### 2.3 `@target(rtl)` lane (RFC 064 inherit)

원본 draft (`inbox/rfc_drafts_2026_05_20/rfc_064_target_rtl_codegen.md`) §2-§7 을 그대로
inherit:

- annotation grammar: `@target(rtl, dialect=..., version=..., clock=?, reset=?)` ·
  `@clock(name, freq_mhz)` · `@reset(name, active, sync)` · `@async`
- driver dispatch: `hexa build --target=rtl,dialect=<verilog|systemverilog|vhdl>,version=<...>` →
  front-end pass (RFC 064 G-R1) → `rtlil::Design` → `stdlib/yosys/write_verilog.hexa` (verilog/sv)
  or `stdlib/vhdl/write_vhdl.hexa` (vhdl) → emit `build/rtl/<dialect>/`.
- codegen contract: ①front-end pass walks AST, recognises `@target(rtl)` on module-like decls,
  lowers body into `rtlil::Design` ②dialect dispatch (`write_verilog` vs `write_vhdl`) ③timing
  pragmas (`@clock`/`@reset`/`@async`) thread into `build/rtl/<dialect>/timing.sdc` ④reference
  netlist comparison (yosys `equiv_make`/`equiv_induct`) as G-R1 exit.
- phasing: G-R0 → G-R1 → {G-R2, G-R3, G-R4} (G-R0 is the round-trip invariant prerequisite).

### 2.4 stdlib/kernels/logic_synth 정렬

`stdlib/yosys/{read_verilog,write_verilog,rtlil}.hexa` + `stdlib/vhdl/write_vhdl.hexa.stub` 은
이미 작성 중 (RFC 064 §8 참조). 본 RFC 의 lane dispatch 는 그 stdlib 모듈들을 호출하는
**driver-side** 표면이다 — stdlib 쪽은 호환 변경 없이 RTLIL constructor + dialect writer 만
제공하면 lane dispatch 가 그 위에서 동작. logic_synth substrate (abc / yosys) 는 absorbed-
subprocess 경계 유지.

---

## §3 Dispatch (codegen lane selection)

codegen lane 선택은 **두 layer** 로 동작:

### 3.1 driver flag layer (`hexa build`)

```
hexa build --target=firmware,arch=cortex-m4,core=armv7e-m,float=soft  blinky.hexa
hexa build --target=rtl,dialect=verilog,version=2005                   counter.hexa
```

`--target=<lane>,<kw=v>,...` parsing 은 `self/cli.hexa` 의 `parse_build_opts` 에 1개의 새 case
(`--target=...`) 추가; lane string + kw map 을 `BuildCtx.target_lane` / `BuildCtx.target_opts` 로
attach.

### 3.2 codegen layer (`self/codegen_c2.hexa`)

각 FnDecl / ModuleDecl 의 attribute list 에서 `@target(<lane>, ...)` 를 찾아 lane-specific
profile dispatch. 현재 `da9c197e` placeholder 는 attribute 인식만 한다 (no-op). 본 RFC 의 작업:

1. `recognize_target_attr(attrs) -> Option[(lane, kwmap)]` helper.
2. `emit_fn_decl` / `emit_module_decl` 진입점에 lane dispatch — `lane == "firmware"` →
   freestanding profile; `lane == "rtl"` → front-end pass + RTLIL lowering.
3. lane dispatch 표는 `lane_dispatch.hexa` 같은 단일 파일에 모음 (lane 확장 시 한 곳만 수정).

### 3.3 driver flag ↔ codegen attribute 정합

- driver flag (`--target=firmware,arch=...`) 와 source attribute (`@target(firmware, arch=...)`)
  는 **둘 다 필수** — driver flag 는 빌드 디렉토리 + toolchain 선택, source attribute 는
  per-fn lowering profile.
- 두 곳의 lane string 이 mismatch (`--target=firmware` + `@target(rtl)` on a fn) → compile-time
  error (`E_TARGET_LANE_MISMATCH`).
- 일부 fn 만 lane-specific 인 경우 (e.g. `@target(firmware) fn isr(...)` in a hosted module) →
  module-scope lane = driver flag 의 default; per-fn lane override 만 lowering 변경. (이는
  G-F3 ISR + G-F4 asm 의 mixed-mode 시나리오를 cover.)

---

## §4 Falsifiers

본 RFC 가 정식 번호로 promote 한 두 lane 에 대해, 각각 5 개의 falsifier (총 10 개) 를 정의한다.
구현 PR 은 해당 falsifier 의 PASS 측정을 동반해야 land.

### 4.1 firmware lane (G-F0..G-F4)

- **F-FIRMWARE-NO-LIBC** — `@target(firmware) fn ...` 의 emit 결과 `.c` 가
  `<stdlib.h>` 나 `<stdio.h>` 를 include 하면 fail. 또한 emit 된 `.c` 를
  `arm-none-eabi-gcc -nostdlib -ffreestanding` 로 compile 했을 때 link error
  (undefined symbol `malloc` / `printf` 등) 가 나면 fail (G-F0).
- **F-LINKER-SCRIPT** — `--target=firmware,arch=cortex-m0` 으로 build 했을 때
  `build/firmware/cortex-m0/link.ld` 가 emit 되고, 그 link.ld 의 `MEMORY` 섹션이 per-arch
  template 과 byte-eq 매치하지 않으면 fail. layout=<symbol> override 했을 때 override 가
  반영 안 되면 fail (G-F0).
- **F-MMIO-ORDERING** — `@mmio(addr=0x4000_0000, width=32, ordering=preserve)` 에 두 번
  연속 write 한 hexa source 가 emit 후 optimiser 에 의해 한 번으로 merge 되면 fail. (qemu
  oracle: 두 write 의 second 가 MMIO 에 도달하지 않으면 trace 에서 빠짐) (G-F2).
- **F-INTERRUPT-ABI** — `@interrupt(vector="SysTick", number=15) fn tick()` 의 emit 결과가
  `__attribute__((interrupt))` 없이 normal fn 으로 emit 되거나, vector-table 의 slot 15 에
  symbol 이 inject 안 되면 fail (G-F3).
- **F-ELF-DETERMINISM** — clean rebuild 두 번 했을 때 emit 된 `.elf` 의 `.text` section md5
  가 mismatch 면 fail (G-F0 codegen determinism claim).

### 4.2 rtl lane (G-R0..G-R4)

- **F-COMPILE-RTL-VERILOG** — `--target=rtl,dialect=verilog,version=2005` build 했을 때
  emit 된 `build/rtl/verilog/counter.v` 가 yosys 의 `read_verilog` 로 syntax-error 없이
  load 되지 않으면 fail (G-R1).
- **F-DIALECT-SV** — `--target=rtl,dialect=systemverilog,version=2017` 의 emit 결과가
  Verilog-2005 only construct 만 사용하면 (i.e. `logic` / `always_ff` / `always_comb` 가
  안 나오면) fail. 반대로 SystemVerilog-only construct 가 `dialect=verilog` emit 에서 나오면
  fail (G-R2).
- **F-DIALECT-VHDL** — `--target=rtl,dialect=vhdl,version=2008` emit 결과 `.vhd` 가
  `ghdl -a` 에 의해 analyze 실패하면 fail. 또한 `ghdl -e <top>` elaboration 까지 success
  안 하면 fail (G-R3).
- **F-EQUIV-NETLIST** — G-R1 의 counter demo 의 yosys `synth -top counter` 후 ABC 매핑된
  netlist 가 reference netlist 와 `equiv_make` / `equiv_induct` 으로 동치 증명 실패하면 fail
  (G-R1 main exit).
- **F-TIMING-SDC** — `@clock(name="clk", freq_mhz=100)` annotation 이 있는 module 의 emit
  결과 `build/rtl/<dialect>/timing.sdc` 가 100 MHz constraint 를 포함하지 않거나, synth tool
  의 STA 가 100 MHz 에서 violation 을 보고하면 fail (G-R4).

---

## §5 Cross-link

### 5.1 RFC family

- **RFC 063 (firmware)** — 본 RFC 의 lane (a). 원본 draft 텍스트 §1-§8 inherit. 구현 PR 은
  본 RFC 의 §3 dispatch + §4.1 falsifier 를 통과해야 land. 슬롯 중복 주의 (`019aecb6` 등
  `S7 native assembler+linker` 가 동명 RFC 063 으로 머지된 history 존재) — 본 RFC 가
  promote 한 firmware lane 은 **codegen** 측면, S7 는 **assembler+linker** 측면으로 직교한다.
- **RFC 064 (rtl)** — 본 RFC 의 lane (b). 원본 draft 텍스트 §1-§8 inherit. 구현 PR 은
  본 RFC 의 §3 dispatch + §4.2 falsifier 를 통과해야 land. `stdlib/yosys/*.hexa` +
  `stdlib/vhdl/*.hexa.stub` 의 in-flight work 와 정렬.
- **RFC 089 (ld/dlopen)** — `hexa_ld --shared` + runtime `dlopen` (host-binary runtime
  extension). 본 RFC 와 직교 — 089 는 host binary 의 plugin 동적 로드, 090 은 cross-compile
  target 의 cold emit. lane dispatch 표면 (`@target(...)`) 은 090 이 정의, plugin loading
  표면 (`@shared`/`@plugin`) 은 089 의 후속에서 별도 정의 가능.
- **RFC 055 (hexa-NVPTX)** — GPU codegen. 본 RFC 의 lane catalog 에 `cuda` / `ptx` 추가는
  RFC 055 의 후속 work; 본 RFC 는 그 확장 path 만 reserve (`§2.1 lane catalog` 의 향후 확장
  주석).
- **RFC 080 (`hexa loop --dfs`)** — external LLM gateway. 본 RFC 작업은 LLM 호출 없음
  (codegen + parser + stdlib 작업).

### 5.2 stdlib 정렬

- `stdlib/firmware/{target,mmio,interrupt,asm,startup}.hexa.stub` — firmware lane consumer.
  본 RFC 의 codegen lowering 이 land 하면 stub → 실제 module 로 promote 가능.
- `stdlib/yosys/{read_verilog,write_verilog,rtlil}.hexa` — rtl lane substrate (writer 측).
  RFC 064 의 in-flight branch (`s1-step2-codegen-perf`) 와 정렬.
- `stdlib/vhdl/write_vhdl.hexa.stub` — rtl lane VHDL writer. 본 RFC 의 G-R3 exit fixture
  의 consumer.
- `stdlib/kernels/logic_synth` — abc / yosys absorbed-substrate 경계. 본 RFC 의 lane
  dispatch 와 직교 (lane dispatch 는 codegen emit 까지; substrate 호출은 별도 layer).

### 5.3 메모리 cross-link

- `[[project_rfc006_s5_d4_final_route_xy_blocker]]` — RFC 006 §5 의 router_d4 closure 가
  hexa-source RTL DSL 의 first concrete consumer. RFC 090 의 rtl lane (G-R1) 이 land 하면,
  router_d4.v 의 authored form 이 hexa-source 로 마이그레이션 가능 (현재는 `.v` authored).
- `[[reference_yosys_gate5_substrate_paths]]` — rtl lane 의 yosys / abc substrate 경로 정의.
  본 RFC 의 G-R1 exit fixture 가 그 paths 를 그대로 사용.
- `[[project_hexa_native_no_sh_py_writes]]` — `.sh`/`.py` writes 가 거부됨. 본 RFC 의 작업은
  `.hexa` only (코드 변경 0, inbox doc only).
- `[[feedback_hexa_lang_shared_worktree_branch_hazard]]` — 8-session shared tree hazard.
  본 RFC 는 inbox doc only 이므로 shared worktree wipe risk 없음.
- `[[feedback_inbox_dup_race_precheck]]` — dup-race precheck. 본 RFC 작성 전 grep 으로
  `self/codegen_c2.hexa` 의 `@target(firmware)`/`@target(rtl)` 인식 상태를 확인 →
  `da9c197e` placeholder 만 존재, lowering body 는 미구현 → 본 RFC 는 lowering 의 design
  contract 만 정의 (구현 0).

---

## §6 Phasing 요약

| phase     | lane     | scope                                            | falsifier                  |
|-----------|----------|--------------------------------------------------|-----------------------------|
| P1.G-F0   | firmware | freestanding profile + linker-script emit       | F-FIRMWARE-NO-LIBC · F-LINKER-SCRIPT · F-ELF-DETERMINISM |
| P1.G-F1   | firmware | startup vector + reset + .bss/.data             | (qemu boot exit fixture)   |
| P1.G-F2   | firmware | `@mmio` ordering lowering                       | F-MMIO-ORDERING            |
| P1.G-F3   | firmware | `@interrupt` lowering + vector-table inject     | F-INTERRUPT-ABI            |
| P1.G-F4   | firmware | `@asm` escape hatch                             | (≤5 sites discipline)      |
| P2.G-R0   | rtl      | `read_verilog` round-trip 12/12                 | (byte-eq fixtures)         |
| P2.G-R1   | rtl      | front-end pass `@target(rtl)` → RTLIL           | F-COMPILE-RTL-VERILOG · F-EQUIV-NETLIST |
| P2.G-R2   | rtl      | SystemVerilog dialect emit                      | F-DIALECT-SV               |
| P2.G-R3   | rtl      | VHDL `write_vhdl` mirror                        | F-DIALECT-VHDL             |
| P2.G-R4   | rtl      | `@clock`/`@reset`/`@async` SDC emit             | F-TIMING-SDC               |

각 phase 는 별개 PR. P1.G-F0 + P2.G-R1 이 critical path (각 lane 의 첫 measured PASS).

---

## §7 References

- `inbox/rfc_drafts_2026_05_20/rfc_063_target_firmware_codegen.md` (원본 firmware draft)
- `inbox/rfc_drafts_2026_05_20/rfc_064_target_rtl_codegen.md` (원본 rtl draft)
- `inbox/rfc_drafts_2026_05_24/rfc_089_ld_shared_dlopen.md` (sibling promote — runtime
  extension lane)
- `da9c197e feat(self/codegen_c2): RFC 063/064 annotation placeholder` (current state —
  attribute recognition only, lowering deferred)
- `FIRMWARE.md` §1 (forbidden source classes) · §4 (G-F0..G-F4 + G-R0..G-R4) · §5
  (≤5 `@asm` sites discipline)
- `HEXA-NATIVE-ONLY.md` §4 G-0..G-11 (sibling ML lane — axes A1/A2/A5/A6 share)
- AGENTS.tape `@D g5 hexa-native-only` · `@D g_stdlib_ownership` · `@D g_atlas_binary_builtin`
- IEEE Std 1364-2005 (Verilog) · IEEE Std 1800-2017 (SystemVerilog) · IEEE Std 1076-2008 (VHDL)
- ARM Cortex-M0 Devices Generic User Guide · RISC-V Volume I: Unprivileged ISA
- 메모리 `[[project_rfc006_s5_d4_final_route_xy_blocker]]` · `[[reference_yosys_gate5_substrate_paths]]` ·
  `[[feedback_inbox_dup_race_precheck]]` · `[[project_hexa_native_no_sh_py_writes]]`
