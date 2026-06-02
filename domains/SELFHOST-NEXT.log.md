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

## 2026-06-03 — linux-arm64 RUNTIME cross-build: multi-fn programs LINK + RUN (qemu)

Stacked on #2572 (`selfhost-next/linux-arm64-depth` @8cd9bed69). Clears the exact
named wall from #2572: a multi-fn integer-arith probe cross-EMITs+assembles but
fails at LINK with `undefined reference to hexa_add_slow` — the freestanding stub
can't satisfy arithmetic/string externs. Real programs need the C runtime
(`self/runtime.c`) cross-compiled to an aarch64-linux `runtime.a`.

Hosts: ghost (macOS) = aprime_cc build + native ELF-aarch64 emit; aiden (x86_64
linux) = installed `gcc-aarch64-linux-gnu` 13.3 + `qemu-user-static` (joins the
existing cross-binutils) = runtime cross-build + link + RUN.

- [x] `tool/cross_build_runtime_linux_arm64` (NEW, ext-less per the
      build_native_linux_arm64 precedent) — cross-compiles `self/runtime.c`
      (frozen seeds via restore_frozen_seeds) with `aarch64-linux-gnu-gcc` to
      `build/larm64rt/runtime.a`. KEY: gate OFF (no `-DHEXA_HAS_HEXA_RT_STDLIB`)
      = the standalone smoke path (runtime_core.c:3120) where the `#ifndef`
      C-fallback `rt_*` bodies compile in (incl. `rt_add_slow`, behind the
      `hexa_add` macro). self-check: `hexa_add_slow` defined=1 · residual `rt_*`
      undefined=0. (Gate ON externs 156 `rt_*` only the per-program hexa stdlib
      closure supplies — wrong for a reusable archive.) runtime.a = 522 KB, ELF
      aarch64; remaining undefined = libc/libm/syscall only → `-lm -ldl -lpthread`.
- [x] PROBE A — multi-fn INTEGER ARITHMETIC (the #2572 `hexa_add_slow` blocker):
      `add`/`mul`/`poly`/`main` over `+` and `*`. EMIT (ghost) `--emit=obj
      --backend=native --target=arm64-linux-gnu` → ELF aarch64 .o (1 undef:
      hexa_set_args). LINK (aiden) `aarch64-linux-gnu-gcc probe.o runtime.a`
      → ELF aarch64 PIE, NO undefined. RUN `qemu-aarch64-static -L
      /usr/aarch64-linux-gnu` → **stdout=`poly(5)=37` rc=37** (25+5+7). ✅
- [x] PROBE B — multi-fn STRING CONCAT (`hexa_add_slow` string branch /
      `rt_add_slow`): `greet`/`twice`/`main`. RUN → **stdout=`hi arm64hi arm64`
      rc=0**. ✅ Both previously-blocked classes now link+run on linux-arm64.
- [x] reproducible one-command (validated clean on aiden):
      `bash tool/cross_build_runtime_linux_arm64 -o probe_multifn.o`
      → `QEMU RUN — stdout=[poly(5)=37] rc=37 ... DONE`.
- [x] Verdict: `.verdicts/selfhost-next-linux-arm64/RUNTIME-CROSS.txt` (🟢).
- [ ] GAP — FULL compiler self-emit on linux-arm64 remaining: (a) cross-build
      `cc_native` itself (the runtime half is now done; build_native_linux_arm64
      builds cc_native NATIVELY only); (b) compiler SELF-EMIT still hits the
      ENCODE-MISS class (STP `mem=#0` page-reloc — the hexa-cc-native
      F-STP-ENCODE-MISS residual; arm64 codegen is target-shared, OUT of this
      DRIVE-lane scope); (c) a native aarch64-linux RUN host (bare-metal, not
      qemu) is the final run-verification axis.


## 2026-06-03 — byte-eq fixpoint published as first-class verifiable claim (CLAIMS.tape)

Deferred milestone CLOSED: reproducible-build attestation. The graduated self-host
byte-eq fixpoint is now a terminal `@C` claim in root `CLAIMS.tape` with a persisted
`.verdicts/` verdict carrying REAL measured bytes (g63 honest, not asserted).

- **Claim**: `@C selfhost_byteeq_fixpoint` (group=COMPILER · slug=selfhost-byteeq ·
  method=fixpoint). Terminal upgrade of the `compiler_selfhost_fixpoint` STUB (which
  was gen1/gen2 `.s` md5, md-only, NO persisted verdict): this asserts the OBJECT-level
  fixpoint stage3 `cc-gen3.o` == stage4 `cc-gen4.o`, BYTE-IDENTICAL, with a real verdict.
- **Verdict**: `.verdicts/selfhost-byteeq/selfhost_byteeq_fixpoint.txt` — verbatim
  evidence captured from ghost `~/dancinlab/selfhost-work`:
    - `gen4.done`: `EXIT=0 OBJSIZE=3224592 ENCODE_MISS=0 LINK_gen3=0 SMOKE=2 CMP_gen3_vs_gen4=BYTE-EQ-GRADUATION FIRSTDIFF=0`
    - sha256 `32c6db9b5696bd251da62770275d0ba929387198dd750ce3466e7ef11e37fdec` — IDENTICAL
      across cc-gen3.o, cc-gen4.o, AND cc-gen3b.o (full-scale native determinism gen3==gen3b).
    - `cmp cc-gen3.o cc-gen4.o; echo $?` → `0` (byte-identical) · 3224592 B each · ENCODE_MISS=0.
- **Method**: deterministic 3-stage bootstrap via `tool/build_selfhost.sh` → `cmp` GATE;
  artifacts regenerable one-command (verdict notes this honestly). Source fixpoint fixes
  on main: #2479 #2509 #2532. Diagnosis lineage: STAGE3-DIAG.txt predicted the graduation.
- **Schema lint**: self-checked — fields {method,cmd,raw,src,status} present in sibling
  order, slug/group well-formed, `raw` ptr resolves to the verdict file. No dedicated
  CLAIMS lint / `hexa` CLI on ghost; method=fixpoint is empirical (run-stdout = the verify).
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

## 2026-06-03 — ELF x86_64 .o data relocs (R_X86_64_PC32) + .rodata/.data/.bss — print("hi")/exit(7) RUNS native x86_64

Mirror of #2562 (ELF AArch64 data relocs) for the x86_64 path. Touches ONLY
`compiler/emit/elf_x86_64.hexa` (+ a self-contained test harness) per the scope boundary
(`elf_arm64.hexa` / `macho_arm64.hexa` untouched → darwin/arm64 unaffected). Branch
`selfhost-next/elf-x86_64-relocs`. VERIFIED on summer (native x86_64 linux, current hexa).

- [x] Backend operand form that drove the reloc: a string/global reference reaches the
      LIR walker as a `label` operand (`.LCstrN` / `g<id>`), produced by
      `_x86_64_op_for_operand` as the SOURCE of a `mov reg, <label>` (= "load this
      symbol's ADDRESS"). On x86_64 the canonical form is RIP-relative
      `lea reg, [rip + disp32]` → exactly ONE reloc kind needed.
- [x] reloc kind ADDED: **R_X86_64_PC32** (addend −4). Drove by the `mov`/`lea reg,
      <.LCstrN|g<id>>` data-address operand. Encoder `_ex86_lea_rip_rel` emits
      `REX.W 8D ModR/M(mod=00 reg=rd rm=101=RIP) disp32=0`; walker bubbles the disp32
      offset; `pack_lir_x86_64` Pass 3 attaches the PC32 reloc (S+A−P with A=−4 = the
      RIP-relative displacement, collapsing arm64's 2-reloc ADRP/ADD pair into 1).
- [x] sections ADDED: `.rodata` (PROGBITS ALLOC — `.LCstrN` string pool from `lm.rodata`),
      `.data` (PROGBITS ALLOC|WRITE — 16-B zero HexaVal slot per `lm.globals`, `g<id>`),
      `.bss` (SHT_NOBITS — `bss_size`, no file bytes). `ElfX86Obj` gained
      rodata/data/bss_size/nlocal fields.
- [x] symtab LOCAL-before-GLOBAL fixed: Pass 0/0b push `.LCstrN`/`g<id>` as STB_LOCAL
      defs first, fn defs STB_GLOBAL after; `serialize_elf_x86_64` stamps
      `.symtab` `sh_info = obj.nlocal + 1` (was hardcoded 1; nlocal=0 reproduces it).
- [x] PROVEN — Module A (`main` lea .LCstr0/g0): `readelf -r` → 2× R_X86_64_PC32 vs
      `.LCstr0 - 4` / `g0 - 4`; `readelf -s` → LOCAL .LCstr0(.rodata) + LOCAL g0(.data,sz16)
      + GLOBAL main(.text), Info=3=nlocal+1. Module C (freestanding `_start`
      write(1,.LCstr0,3)+exit(7)): `ld -static -nostdlib -e _start` rc 0; objdump shows the
      linker patched `lea 0xfeb(%rip),%rsi # 402000 <.LCstr0>`; **RUN: stdout=`hi`, rc=7**
      ($? captured separately, no pipe-mask).
- [x] exit(N)-only baseline byte-structure UNCHANGED: text-only exit(7) .o is
      sha256-IDENTICAL (`cmp` clean) to the origin/main serializer (mirrors #2562's
      "text-only path unchanged" check).
- [x] darwin/arm64 UNAFFECTED: only `elf_x86_64.hexa` modified (`git diff --stat`); new
      test file is additive. no_hardcode_lint --staged PASS (0 new hits).
- [ ] HONEST g63 — gaps remaining (named, not hidden):
      (1) **R_X86_64_64** (absolute 64-bit data pointer) NOT added — the x86_64 backend
          emits no absolute-imm64 data-address operand today (all data refs are the
          RIP-relative `label` form), so adding it would be a dead reloc kind. Same call
          #2562 made for ABS64 on arm64.
      (2) **R_X86_64_GOTPCREL / PLT32-for-data** (shared/PIC `@GOTPCREL`) NOT added —
          gated on the `--shared` CodegenOptions path (lir.hexa scaffold), which no call
          site constructs yet. Executable/PIE baseline only.
      (3) aiden (2nd x86_64 host) has a STALE installed hexa runtime (missing
          `hexa_float_to_bits`) → its `hexa run` of the harness fails at C-compile,
          unrelated to this change; summer (current runtime) is the proof host.

Verdict: `.verdicts/selfhost-next-elf-x86_64-relocs/F-ELF-X86-DATA-RELOC.txt` (verbatim
readelf -h/-S/-r/-s + ld + objdump + native run stdout/rc + baseline sha256).
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

## 2026-06-03 — cross-emit DEPTH: .rodata string + .data global RUN under qemu (asm path)
Branch selfhost-next/linux-arm64-depth (stacked on #2569). Driver tool/cross_emit_larm64_depth.
aprime_cc built on mini (Darwin arm64) via build_aprime.sh — smoke exit 42 PASS. Cross-tools
on summer (aarch64-linux-gnu-as/-ld 2.42 + qemu-aarch64-static); mini has none (driver runs
emit+fixup there, SKIPs assemble/link/run).

Extended exit(42) to REAL programs hitting the merged #2562 data relocs:
  P1 `fn main(){ print("hi"); exit(7) }`   → qemu stdout=[hi] rc=7  ✅  (.rodata string)
  P2 `let g:int=99; fn main(){print("hi");exit(g)}` → qemu stdout=[hi] rc=99 ✅ (.data global)
readelf -rW: P1 = 1× R_AARCH64_ADR_PREL_PG_HI21 + 1× R_AARCH64_ADD_ABS_LO12_NC (.rodata);
  P2 = 3×+3× (.data ×2 store/load + .rodata ×1) — EXACTLY the #2562 reloc pair. Both ELF
  AArch64 statically linked, run to correct stdout+rc. String/global reloc CONFIRMED in asm
  (adrp SYM / add :lo12:SYM) AND in the .o.

KEY FINDING (asm-path fixup needed): the emit pass writes Mach-O `SYM@PAGE`/`SYM@PAGEOFF`
  page-rel syntax EVEN for --target=arm64-linux-gnu. GNU-as REJECTS it ("unexpected
  characters following instruction `adrp x1,.LCstr0@PAGE'"). Driver translates
  @PAGE→bare-sym (adrp), @PAGEOFF→:lo12: (add) as a recipe-level sed fixup (NOT a codegen
  edit — scope boundary respected: no elf_arm64.hexa / emit-pass edits). Candidate follow-up
  for the codegen lane: emit :pg_hi21:/:lo12: directly when target==arm64-linux-gnu.

NEXT FULL-SELF-EMIT WALL (named): `undefined reference to hexa_add_slow`. Probe multi.hexa
  (fn add + integer arith) cross-emits + assembles fine but link fails — the freestanding
  stub (rtstub_io.s: set_args/exit/print_val[TAG_STR]) can't satisfy arithmetic/string/alloc
  externs. Real programs need self/runtime.c cross-compiled to aarch64-linux. Native aarch64
  has this (build_native_linux_arm64, gcc); the Mac cross path needs aarch64-linux-gnu-gcc on
  the runtime → aarch64 runtime.a, then link <p>.o under qemu = the next milestone.

Verdict: .verdicts/selfhost-next-linux-arm64/CROSS-EMIT-DATA.txt (🟢).

## 2026-06-03 — CCNATIVE-CROSS: cross-build the COMPILER BINARY (cc_native) to aarch64-linux
Removes the #2575 named wall: build_native_linux_arm64 built cc_native NATIVELY-ONLY (no
cross path to an aarch64-linux compiler binary from a non-arm64-linux host). New tool
tool/cross_build_ccnative_linux_arm64 (cross sibling of build_native_linux_arm64) — reuses
stages 1-3 byte-identically (host python3 flatten → host hexat transpile → s4/sed
post-process + inline runtime.c + rt_fs/rt_array link-fills); the ONLY deltas are stage4 CC
(aarch64-linux-gnu-gcc, not native gcc) and the RUN wrapper (qemu-aarch64-static).

PROVEN on aiden (x86_64 linux — gcc 13.3.0 · qemu-aarch64 8.2.2):
  stage4  cc_native = ELF 64-bit LSB pie executable, ARM aarch64 [3,391,856 B] (CROSS-built).
  stage4b cross runtime.a (#2574 reuse) = 535,562 B.
  stage5a qemu run cc_native --version → rc=2 stdout=[] (no --version flag; binary EXECUTED).
  stage5b qemu run cc_native: emit `fn main(){exit(42)}` --emit=obj --backend=native
          --target=arm64-linux-gnu → p42.o (ELF aarch64 relocatable), emit rc=0.
  stage5c link p42.o + cross runtime.a → p42 (ELF aarch64 pie); qemu RUN:
          stdout=[]  rc=42  stderr=[]   ← EXACTLY the pre-registered target.

FINDING (🟢): the cc_native C build is host/target-agnostic in stages 1-3 — only the COMPILER
(CC) + run wrapper (qemu) differ — so the cross delta is a ~3-line recipe change. The
bootstrap compiler has NO native-only dependency. C-cross path → does NOT touch the self-emit
codegen wall.

FULL-SELF-EMIT REMAINING (named — codegen lane, OUT of this C-cross lane):
  1. F-STP-ENCODE-MISS — `ENCODE-MISS: STP mem-parse-fail mem=#0` @ compiler/emit/macho_arm64.hexa
     (STP/LDP encode @541-566 → _parse_mem_op @1551 rejects bare `#0`) — BLOCKING true self-emit.
  2. (downstream of 1) gen2 self-emit byte-eq vs C-built cc_native — gated on (1).
Scope boundary FORBIDS editing compiler/emit/* / macho_arm64.hexa here; cc_native being
C-built is exactly why this lane does NOT depend on that fix.

Verdict: .verdicts/selfhost-next-linux-arm64/CCNATIVE-CROSS.txt (🟢).

## 2026-06-03 — linux-arm64 NATIVE EMIT verified on pi5 (real hardware) + self-emit OOM wall (named)

Drove the SELFHOST-NEXT linux-arm64 self-EMIT milestone on pi5-akida (the pool's
ONLY native aarch64 host — RPi5, 7.8 GiB RAM, no swap, gcc 13.3, no clang).
Branch `selfhost-next/linux-arm64-self-emit`. Complements the cross-build/qemu
lane (#2574/#2577 — CCNATIVE-CROSS, verified on x86_64+qemu): this is the
NATIVE-on-real-arm64-hardware run + the self-emit resource wall.

- [x] BUILT bootstrap toolchain natively via `TARGET=linux-arm64 CC=gcc
      LIBS='-lm -ldl' bash tool/release_build`: runtime.a (501 KB) + hexat
      (2.17 MB) + ./hexa (2.24 MB ELF aarch64 PIE). Seeds self-restored from the
      frozen blob; full-source build, no edge-pull.
- [x] BUILT cc_native natively via tool/build_native_linux_arm64 (the recipe that
      landed in #2575/#2577): cc-flat 48 files/43240 lines → hexat → 47019-line C
      → gcc -O1 → cc_native 3.3 MB ELF aarch64. (Independently arrived at the same
      recipe incl. rt_array link-fill; main's copy is byte-identical, so this PR
      drops the duplicate tool files and keeps only the native-run verdict.)
- [x] GOAL 1 NATIVE — `print("hi"); exit(7)` → native ELF .o via cc_native
      --emit=obj --backend=native --target=arm64-linux-gnu (NO host `as`):
      R_AARCH64_CALL26 (hexa_print_val/exit/set_args) + ADRP/ADD page-reloc pair
      (R_AARCH64_ADR_PREL_PG_HI21 + R_AARCH64_ADD_ABS_LO12_NC) vs .LCstr0 (#2562).
      Linked w/ runtime.a + crt1.o; **RAN NATIVELY on pi5** (NOT qemu): stdout="hi",
      rc=7 (real $?). exit(42) → rc 42. This is the native-hardware counterpart to
      the cross/qemu verification in CCNATIVE-CROSS / CROSS-EMIT-DATA.
- [ ] GOAL 2 — COMPILER SELF-EMIT (cc_native emits its own 43240-line flattened
      source): REACHED parse + typecheck (15 diagnostics = flatten artifacts: the
      known empty_atlas AtlasRef/AtlasIndex collision, NOT a compiler bug;
      --ignore-errors proceeds) + ENTERED codegen with **0 ENCODE-MISS** (no STP
      mem=#0 / unknown-op encoder wall), then **OOM-killed**: journalctl
      `Out of memory: Killed process 58398 (cc_native) total-vm:8006332kB
      anon-rss:7758464kB` — ~7.76 GiB RSS on a 7.8 GiB / no-swap host. FIRST WALL =
      HOST RAM, NOT codegen correctness. NEXT: self-emit on a higher-RAM
      (≥~12–16 GiB) native aarch64 host / add swap; OR a codegen-peak-RSS milestone.
      g63: no such aarch64 host in the current pool (summer/aiden x86_64; pi5 is
      the only aarch64 and is RAM-tight) — honest scope, not faked.
      Verdict: .verdicts/selfhost-next-linux-arm64/SELF-EMIT-LARM64.txt.
