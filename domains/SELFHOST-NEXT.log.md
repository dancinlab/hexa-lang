# SELFHOST-NEXT — log

Append-only history sister of `SELFHOST-NEXT.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

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
