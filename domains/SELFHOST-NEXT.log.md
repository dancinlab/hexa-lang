# SELFHOST-NEXT — log

Append-only history sister of `SELFHOST-NEXT.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-06-02 — in-tree ELF AArch64 .o serializer — NATIVE exit(42) runs rc 42 (no host `as`)

Branch `selfhost-next/elf-arm64-serializer` (cut clean from origin/main d437f3fb4). Removes
the host `aarch64-linux-gnu-as` dependency from the linux-arm64 obj path (continuation of
#2537 cross-EMIT, which still relied on `as` to turn the ELF *assembly* into a `.o`).

- [x] `compiler/emit/elf_arm64.hexa` — `serialize_elf_arm64(ElfArm64Obj)` +
      `pack_lir_arm64_elf(LModule)`. Keyed off `elf_x86_64.hexa`'s ELF model (STN_UNDEF
      index-0 sym, `.rela.text`, Elf64_Rela/Sym, `_ew_*` writers) but with
      `e_machine=ELF_EM_AARCH64(0xb7)`, 4-byte LE instruction words from the SHARED
      `encode_arm64_insn` (reused from `macho_arm64.hexa`), and `R_AARCH64_CALL26` relocs.
      Bare ELF symbol names (no Mach-O `_`). Intra-fn B/BL/CBZ/CBNZ/B.cond resolved at
      pack time (imm26/imm19); cross-fn/extern BL → CALL26 reloc + intra-module pre-patch.
- [x] `compiler/emit/macho_arm64.hexa` — added `SVC #imm16` to `encode_arm64_insn`
      (`0xd4000001 | (imm<<5)`) + lowercase `svc` map, for the freestanding `_start`
      exit(N) syscall sequence. Additive; darwin codegen never emits `svc`.
- [x] `compiler/main.hexa` — import elf_x86_64 + elf_arm64; native obj-emit branch for
      `arm64-linux-gnu` (`pack_lir_arm64_elf` + `serialize_elf_arm64`); `--backend=native`
      default for `arm64-linux-gnu --emit=obj`. Default `arm64-apple-darwin` stays Mach-O
      (guarded), byte-identical (additive branches; SVC rule fires only on op=="SVC").
- [x] `compiler/test/elf_arm64_exit42.hexa` — exit(42) LModule harness.
- [x] VERIFIED on summer (aarch64 cross-binutils + qemu-aarch64-static), via the
      byte-faithful reference of `serialize_elf_arm64`:
      (1) exit(42) main-form: `readelf -h` → Type REL, Machine AArch64; `main` GLOBAL FUNC;
          objdump → `mov x0,#42 ; ret`.
      (2) exit(42) freestanding `_start` (`mov x8,#93; mov x0,#42; svc #0`):
          `aarch64-linux-gnu-ld -static -nostdlib -e _start` → exec; `qemu-aarch64-static`
          → **rc 42**.
      (3) CALL26 reloc: `_start` BL-calls undef extern `helper` → `readelf -r` shows
          `R_AARCH64_CALL26  helper + 0` against an UND symbol.
      Verdict: `.verdicts/selfhost-next/F-ELF-ARM64-NATIVE-OBJ.txt`.
- [ ] NEXT increment — ADRP/ADD page-reloc pairs (`R_AARCH64_ADR_PREL_PG_HI21` +
      `R_AARCH64_ADD_ABS_LO12_NC`) for `.rodata`/`.data` symbol refs, `R_AARCH64_ABS64`,
      and `.rodata`/`.data`/`.bss` section emission (text-only today, matching the x86
      native obj baseline). Reloc-type constants + the Elf64_Rela serializer path already
      handle them; the codegen→reloc mapping for ADRP/ADD pairs is the follow-on.
- [ ] NOTE — full end-to-end through `hexa run compiler/main.hexa` is blocked locally by
      the documented build-floor staleness wall (installed `hexa` runtime lacks
      `__arr_alloc_items_zero`/`HX_MAP_LEN`/LIR struct ctors). Verification used the
      byte-faithful reference; the hexa serializer is structurally identical to the proven
      x86 serializer it is keyed off. On a box with a fresh self-host compiler, run
      `hexa compiler/main.hexa -- T.hexa --target=arm64-linux-gnu --emit=obj -o T.o` and
      byte-diff vs the `as`-object from #2537.

## 2026-06-02 — multi-target: linux-arm64 cross-emit + assemble + RUN (exit(42), rc 42)

Branch `selfhost-next/linux-arm64-rebased` (cut clean from origin/main; +97 lines, g4-ok).
First working linux-arm64 emit: the arm64 instruction codegen is target-shared with
arm64-apple-darwin — the only deltas are ELF-vs-Mach-O format, bare-vs-`_` symbol prefix,
and the asm-syntax selectors. Wired the (already host-detected but previously unrouted)
`arm64-linux-gnu` triple end to end.

- [x] inventory: `detect_default_target` already returns `arm64-linux-gnu` for Linux
      aarch64 hosts but the codegen dispatch (main.hexa) had NO branch for it → hit the
      unsupported-target error. ELF emitter `compiler/emit/elf_x86_64.hexa` exists
      (defines ELF_EM_AARCH64=0xb7) but is x86-bound; emit/asm.hexa already had a generic
      ELF text path for non-darwin. Runtime is C (`#ifdef __linux__` gated) — portable.
- [x] main.hexa: route `arm64-linux-gnu` → codegen_arm64_darwin with opts.target_triple
      set; ELF aarch64 link recipe (crt1.o + ld-linux-aarch64.so.1); help/error lists.
- [x] arm64_darwin.hexa: thread `cg_target` so LFunc/LModule carry the ELF target string;
      bare `g<id>` global labels on ELF. Default callers keep "arm64-apple-darwin" →
      Mach-O output byte-identical. stream.hexa (darwin-only) passes the Mach-O target.
- [x] emit/asm.hexa: `_is_elf_arm64`/`_is_arm64` so AArch64 `#N` imm + `[base,#off]` mem +
      `.p2align 2` render on ELF instead of x86 Intel fallthrough; suppress `.intel_syntax`
      for ELF arm64; **comment marker `//` not `#`** (on aarch64 GNU as `#` is the imm
      prefix → trailing `# cmt` errors as operands). Caught by the cross-assemble step.
- [x] VERIFY: aprime_cc built from THIS branch on ghost → emit asm (arm64-linux-gnu) →
      cross-assemble on summer (aarch64-linux-gnu-as): `ELF 64-bit LSB relocatable, ARM
      aarch64`, Machine AArch64, Type REL, `R_AARCH64_CALL26` relocs for hexa_exit/
      hexa_set_args → freestanding-stub link (`ld -static -nostdlib`, svc #0 exit) → RUN
      under qemu-aarch64-static: **rc 42**. Verdict: .verdicts/selfhost-next-linux-arm64/.
- [ ] GAP — full linux-arm64 SELF-HOST (compile the compiler for linux-arm64) is the
      remaining milestone: needs (a) ELF arm64 `.o` produced IN-TREE (today the asm→.o
      step uses the host `as`; native `--backend=native` obj path is Mach-O-only — an ELF
      arm64 serializer keyed off elf_x86_64.hexa is the next increment), and (b) the C
      runtime cross-compiled for aarch64-linux + the full compiler-source emit/link there.
- [ ] GAP — no native arm64-linux RUN host in the pool unrestricted (summer/aiden are
      x86_64; pi5-akida is native arm64 but anima-only). Verified via x86_64 cross-binutils
      + qemu-aarch64; native-host bare-metal run is the remaining run-verification axis.

## 2026-06-02 — promote-toolchain: reproducible recipe + parity gate + gated promotion

Scoped + implemented the "promote self-hosted gen to default `hx`/hexa_v2, PARITY-GATED"
milestone. Branch `selfhost-next/promote-toolchain`. Three committed `tool/` deliverables
turn the ad-hoc ghost byte-eq build into a one-command reproducible + safely-promotable path.

- [x] `tool/build_selfhost.sh` — full bootstrap ladder from current main:
      restore_frozen_seeds → hexat → build_aprime.sh (stage0) → hexa_ld (from
      tool/hexa_ld.hexa, __literal8 fix on main) → rt.o → aprime emit→gen2 →
      gen2 emit→gen3 → gen3 emit→gen4 → GATE cmp cc-gen3.o==cc-gen4.o. `-j` fast
      path (stage0 only), `--detached MARK` for the 3×~68min self-emits. NO /tmp.
- [x] `tool/selfhost_parity_gate.sh` — parity precondition: per-program BEHAVIOUR
      parity (compile+link+run gen3, exit==`// expect:`) + 42-smoke + optional asm
      byte-match vs shipped ref (`--strict`). PASS authorizes promotion.
- [x] `tool/promote_selfhost.sh` — gated, reversible promotion. tier1 `install` =
      side-by-side slot + `hx-selfhost` launcher (default UNTOUCHED); tier2
      `--default --i-have-reviewed-parity` = backup hexa.real + symlink flip,
      `--revert`. Parity gate is a HARD precondition for both tiers. NO blind replace.
- [x] `tool/SELFHOST_PROMOTE_RUNBOOK.md` — one-command recipe + the precise
      final-flip checklist + why the default-flip is host-local manual (not a PR-carryable change).
- [ ] HONEST g63: default-flip NOT auto-landed — it mutates an on-disk launcher in
      $HX_HOME outside the repo + needs a host-local green parity + human ack. tier-1
      opt-in delivers the capability now at zero risk; flip is one gated command when ready.
- [ ] heavy ghost build re-verification from a clean main checkout = follow-up (detached).


## 2026-06-03 — x86_64 codegen path: SCOPE + smallest-increment (object layer PROVEN)

Milestone: "multi-target bootstrap: x86_64 codegen path (new backend surface — scope first)".

INVENTORY — x86_64 is FAR more present in-tree than the milestone assumed.
PRESENT:
  - Instruction encoder (TWO forms):
    * `self/codegen/x86_64.hexa` (304 L) — typed emitters: mov/add/sub/imul/
      cmp/test/setcc/jcc/call/ret/push/pop + REX.W/R/B, movabs imm64, Linux
      syscall (write/exit). Tested: `self/codegen/test_x86_encoders.hexa`
      (byte-golden vs Intel SDM / objdump).
    * `compiler/emit/elf_x86_64.hexa` (1420 L) — `encode_x86_64_insn(op, ops)`
      string-mnemonic assembler + ModRM/SIB/disp mem operands + REL8/REL32
      branch patching.
  - IR→x86 bridge: `self/codegen/ir_to_x86.hexa` (830 L) + linear regalloc;
    tested `self/codegen/test_ir_to_x86.hexa` (load/add/jump/backward-jump/
    movabs-neg/syscall byte-golden).
  - MIR→LIR backend: `compiler/codegen/x86_64_linux.hexa` (1361 L) —
    `codegen_x86_64_linux(MModule, opts) -> LModule`: linear-scan regalloc +
    spilling + System V arg regs + arith/bit/cmp/setcc/div/call lowering.
  - ELF emit: `serialize_elf_x86_64` (REL object, ET_REL/EM_X86_64) +
    `serialize_elf_exec_x86_64` (static PT_LOAD executable) + `pack_lir_x86_64`
    (LModule→ELF obj) + `link_elf_x86_64`. In-tree linker `compiler/link/hexa_ld.hexa`.
  - Driver: `compiler/main.hexa` accepts `--target=x86_64-linux-gnu`, dispatches
    to codegen_x86_64_linux (L868-869) + wires ld w/ crt1.o + ld-linux-x86-64
    (L1022-1027). asm-text emit via `emit_asm` (compiler/emit/asm.hexa).
  - Cross plan: `self/crosscompile.hexa` darwin-arm64 → linux-x86_64 triple +
    linker argv. P2 falsifier corpus: compiler/test/macho_p0_corpus/run_F_P2_X86_*.
GAP (missing / unproven):
  - Native OBJ fast-path in main.hexa (pack_lir_x86_64+serialize, no system `as`)
    is gated `target=="arm64-apple-darwin"` ONLY (main.hexa L900) → x86_64 falls
    back to emit_asm → system `as`/`ld`.
  - Full SOURCE→x86_64-binary correctness NOT proven end-to-end here: running
    `hexa run compiler/main.hexa -- … --target=x86_64-linux-gnu` fails at the
    BOOTSTRAP layer (clang: undeclared `__raw_add_f`/`__raw_cmp3` transpiling
    main.hexa itself under `hexa run`) — a known runtime-extern gap, NOT x86
    codegen. Needs the BUILT native compiler with a --target front-door.

SMALLEST VERIFIABLE INCREMENT (produced + verified):
  `compiler/test/macho_p0_corpus/run_F_P2_X86_EXIT42_SCRATCH.hexa` — emits an
  exit(42) ELF64 x86-64 static executable via the in-tree encoder + serializer
  (no external assembler), writes to scratch (NOT /tmp), structural self-check.
  VERIFIED on TWO real x86_64 Linux hosts (summer + aiden):
    readelf → ELF64 / LE / EXEC / X86-64 ; ./exit42.elf → REMOTE_RC=42 (both).
    text @0x78 = b8 3c 00 00 00 bf 2a 00 00 00 0f 05 (mov eax,60;mov edi,42;syscall).
    Deterministic byte-identical re-emit (cmp == 0).
  Verdict: .verdicts/selfhost-next-x86_64-scope/F-P2-X86-EXIT42-SCRATCH.txt 🟢
  Harness: ~/dancinlab/selfhost-work/x86-64/run.sh

NAMED NEXT BIG PIECE: NOT a new instruction encoder (it exists + is byte-tested).
The next piece is END-TO-END SOURCE→x86_64-BINARY via the BUILT native compiler:
(1) build compiler/main.hexa to a native binary that exposes --target, then
(2) either fall through emit_asm→`as`/`ld` on a linux host, or (3) wire the
native pack_lir_x86_64+serialize OBJ fast-path for x86_64 in main.hexa L900
(mirroring the arm64-darwin branch) — guarding arm64-darwin byte-identical.

## ELF AArch64 .o — ADRP/ADD page relocs + .rodata/.data/.bss sections (2026-06-03)

MILESTONE: complete the in-tree ELF AArch64 `.o` serializer beyond text-only
exit(42) (#2539) — page-relocation pairs + data/rodata sections so real programs
(string literals, module globals) emit a native linux-arm64 `.o` with NO host `as`.

LANDED (compiler/emit/elf_arm64.hexa):
  - reloc kinds: R_AARCH64_ADR_PREL_PG_HI21 (ADRP @PAGE) + R_AARCH64_ADD_ABS_LO12_NC
    (ADD @PAGEOFF) — the page-relative pair the codegen lowers string/global refs to.
    GOT-suffixed operands fold to the same non-GOT pair (static/non-PIE obj for now).
  - sections: `.rodata` (string/const literal pool, one LOCAL `.LCstrN` sym per
    lm.rodata LSection) · `.data` (16-byte zero HexaVal slot per lm.globals `g<id>`,
    LOCAL) · `.bss` (SHT_NOBITS, sh_size, no file bytes — plumbed, 0 unless requested).
  - symbol ORDER fix: ELF requires LOCAL before GLOBAL — `.LCstrN`/`g<id>` locals
    now precede fn globals; `.symtab` sh_info = nlocal+1 (was hardcoded 1).
  - walker: _pack_fn_arm64_elf captures one `@PAGE`/`@PAGEOFF` operand per insn
    (sanitized to imm=0 base word), Pass-3 emits the ADRP/ADD reloc vs the local sym.
  - serializer: all new sections GATED on presence → text-only exit(42) path stays
    BYTE-IDENTICAL to the #2539 baseline (verified: 6 sections, no .rodata/.data/.bss).

VERIFIED (built native aprime_cc from source; ELF on summer @ readelf 2.42 + qemu-aarch64-static):
  1. `fn main(){ print("hi"); exit(7) }` → ELF aarch64 .o (968B).
     readelf -r: R_AARCH64_ADR_PREL_PG_HI21 + R_AARCH64_ADD_ABS_LO12_NC vs .LCstr0
     (in .rodata, sec 3) + 3× R_AARCH64_CALL26. readelf -s: LOCAL .LCstr0 then GLOBAL main.
     Linked (aarch64-linux-gnu-ld, minimal write/exit stubs) → qemu STDOUT="hi" rc 7.
     objdump: `adrp x1,400000` + `add x1,x1,#0x1a8` = 0x4001a8 = exact .rodata addr. ✅
  2. module global `let mut counter=0; counter=5; exit(counter+2)` → .data section with
     16B `g0` LOCAL slot; ADRP/ADD reloc pairs vs g0. Linked + qemu → rc 7. ✅
  3. exit(42) baseline: still 6 sections (no .rodata/.data/.bss), linked + qemu → rc 42.
     text-only path byte-structure UNCHANGED. ✅
  Mach-O darwin: UNAFFECTED — main.hexa routes arm64-apple-darwin through pack_lir +
  serialize (macho_arm64.hexa); my edits touch ONLY pack_lir_arm64_elf / serialize_elf_arm64.

GAP (named, honest): R_AARCH64_ABS64 — constant + generic Elf64_Rela path are present,
  but NO codegen operand currently lowers to a 64-bit absolute data pointer (the arm64
  backend uses the ADRP/ADD page-relative form for both string + global refs, which is
  PIE-friendly). ABS64 will wire when a codegen path emits an absolute `.quad sym`
  (e.g. a data-section pointer table). Not blocking real programs today.
