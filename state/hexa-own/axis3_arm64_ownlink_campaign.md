# axis-③ arm64 own-link campaign (workflow wf_cc46efe5-188 · 정답지 research)

SSOT for the AArch64 own-link campaign — mirror the proven x86_64 in-process own-start
(`compiler/emit/elf_x86_64.hexa`) for arm64-linux, so `hexa build --target=arm64-linux-gnu
--linker=hexa` produces a static ET_EXEC with ZERO binutils. Researched by a 4-reader
workflow (x86_64 template · arm64 current · aarch64 ELF reference · target routing).

## Gap (confirmed)
The AArch64 half of axis-③ is exactly one-sided: the tree has a working relocatable-object
emitter (`compiler/emit/elf_arm64.hexa` — `serialize_elf_arm64` stamps ELF_ET_REL +
e_machine=ELF_EM_AARCH64=0xb7 at :202-203, emits only CALL26/ADR_PREL_PG_HI21/ADD_ABS_LO12_NC,
pre-resolves intra-fn imm26/imm19 at pack time) and `compiler/main.hexa` already produces that
.o natively for `--target=arm64-linux-gnu` (:1041-1059). What is entirely missing is the EXEC
side: no `serialize_elf_exec_arm64` (ET_EXEC/PT_LOAD/e_entry), no arm64 `_start` stub, no
aarch64 reloc APPLICATION at final vaddr, no `link_elf_arm64_ownstart`. So arm64-linux satisfies
the COMPILE half but the LINK half still forks system ld+crt1+-lc+/lib/ld-linux-aarch64.so.1
(`compiler/main.hexa:1225-1236`); `--linker=hexa` hits the else-warning at :1323 and falls back.
`compiler/link/hexa_ld.hexa` cannot help — its ELF image builder hard-codes e_machine=EM_X86_64=0x3E
at all three sites (:504,:1063,:1392) and only CLASSIFIES aarch64 GOT relocs (:813-818).

## Campaign shape (MIRROR)
The arm64 own-link is a structural port of the proven x86_64 in-process own-start stack in
`elf_x86_64.hexa`: `link_elf_x86_64_ownstart` (:1849, no-runtime.a) → `link_elf_x86_64_ownstart_ar`
(:3208, runtime.a member-pull) → `serialize_elf_exec_x86_64` (:3510) / `_2seg` (:3579) →
`parse_elf_x86_obj` (:3826) / `parse_ar_archive` (:4143). Each x86 piece gets an aarch64 twin;
the divergences are the aarch64-specific reloc math + _start ABI + page-align.

## RUNG-1 (first · this session) — trivial main → static AArch64 ET_EXEC, exit 42, ZERO binutils
Own-link `fn main()->Int{return 42}` in-process (no ld/as/crt1/-lc/dynamic-linker), prove exit 42
— the exact mirror of the x86_64 no-runtime.a own-start rung (`link_elf_x86_64_ownstart`,
elf_x86_64.hexa:1849 called with `[]` runtime_defs). No runtime.a / no archive extraction (rung-2);
only the _start-stub's `bl main` CALL26 + any residual intra-object ADRP/ADD resolved at final vaddr.

### Files
- `compiler/emit/elf_arm64.hexa` — NEW `serialize_elf_exec_arm64(text)` mirroring
  `serialize_elf_exec_x86_64` (elf_x86_64.hexa:3510): e_type=ET_EXEC=2, e_machine=0xb7, single
  R+X PT_LOAD at vaddr 0x400000 with **p_align=0x10000** (64KB-page-safe · diverges from x86 0x1000),
  e_entry=vaddr of the prepended _start.
- `compiler/emit/elf_arm64.hexa` — NEW arm64 `_start` stub mirroring the x86 23-byte stub
  (elf_x86_64.hexa:1556-1599): `ldr x0,[sp]` (argc); `add x1,sp,#8` (argv); `bl main` (CALL26,
  patched to main vaddr); `mov x0,x1` (exit code = main's HexaVal payload); `movz x8,#93`
  (__NR_exit); `svc #0` — syscall convention confirmed vs self/native/alloc_syscall_arm64-linux.s:87-88.
- `compiler/emit/elf_arm64.hexa` — NEW `link_elf_arm64_ownstart(objs, out_path, main_name, runtime_defs)`
  mirroring elf_x86_64.hexa:1849, with a minimal aarch64 reloc applicator: CALL26 imm26=(S+A-P)>>2
  into bits[25:0]; ADR_PREL_PG_HI21 / ADD_ABS_LO12_NC page-pair recomputed from section base
  (NOT trusting the elf_arm64.hexa:673-684 pre-patch).
- `compiler/main.hexa` — NEW `elf_obj_arm64_holder/elf_obj_arm64_ready` mirroring :837-838, populated
  at the arm64 emit site (:1041-1059, alongside the :1087-1088 x86 pattern), and a new dispatch arm at
  :1242 `else if target=="arm64-linux-gnu" && elf_obj_arm64_ready { link_elf_arm64_ownstart(...) }`
  replacing the :1323 warning-and-fallback.

### Steps
1. Add `serialize_elf_exec_arm64(text)` by cloning `serialize_elf_exec_x86_64` (:3510), flip
   e_machine 0x3E→0xb7, keep ET_EXEC + single PT_LOAD@0x400000 but p_align=0x10000; leave a _2seg
   data variant for rung-2.
2. Emit the fixed arm64 `_start` byte sequence, recording the `bl` word offset so CALL26 to main
   can be patched — mirror of the x86 intra-stub rel32 patch (:1556).
3. Write `link_elf_arm64_ownstart`: prepend the _start stub to .text, compute PT_LOAD vaddr layout,
   resolve the stub's CALL26 to main_name + any residual ADRP/ADD from section base, call
   `serialize_elf_exec_arm64`, write out_path. Model control flow on :1849.
4. In `compiler/main.hexa`, populate holder/ready at the arm64 native-emit branch (:1041-1059) as x86
   does at :1087-1088, then add the in-process dispatch arm at :1242 calling `link_elf_arm64_ownstart`
   with `[]` runtime_defs — deleting the fall-through warning at :1323.
5. Assert opt-in/byteeq-neutrality: the new arm fires only under `--linker=hexa` AND
   target==arm64-linux-gnu; the default still hits the system-ld recipe (:1225-1236) unchanged →
   x86_64/arm64/darwin byteeq stays bit-identical.

### Verify
Pool host aiden (x86_64-linux self-hosted; cross-emit of arm64 .o from Linux-x86_64 is sanctioned
per #4483 which gated OUT darwin, not x86-linux). Command: build `fn main()->Int{return 42}` with
`aprime _drv.hexa --backend=native --emit=exec --linker=hexa --target=arm64-linux-gnu -o /tmp/a42`,
then `qemu-aarch64-static /tmp/a42; echo rc=$?`. Expected rc=42; readelf-equivalent confirms
e_type=ET_EXEC + e_machine=0xb7 + single PT_LOAD, no PT_INTERP; assert NO ld/as/crt1 forked.
Release-integrity: run byteeq 3-target in the SAME PR — opt-in path ⇒ all three bit-identical GREEN.
If aiden lacks qemu-user, fall back to a github-hosted arm64 cloud runner per CI discipline.

### Risks (aarch64-specific · SILENT-fail hazards)
- **ADRP page math**: Page(S+A)-Page(P), 21-bit split across immlo[30:29]+immhi[23:5] is easy to
  mis-pack and fails SILENTLY (wrong address, no link error). Unit-check the bit layout vs a
  known-good aarch64 ADRP encoding before trusting the linked exec.
- **argc source**: at aarch64 Linux entry x0 is 0/undefined — argc MUST come from `[sp]`, argv from
  sp+8. Reading argc from x0 → garbage-argc crash.
- **exit ABI**: __NR_exit=93 (not x86 60), exit code in x1 (not rdx), svc #0 with x8 (not eax). One
  wrong constant → wrong exit code masquerading as a codegen bug.
- **double-apply**: elf_arm64.hexa Pass-2 (:673-684) already pre-patches cross-object BL in the .o;
  recomputing (S+A-P)>>2 on an already-patched word double-applies. Resolve from section base/addend.
- **64KB-page kernels**: p_align=0x1000 (x86 habit) can make the ET_EXEC unloadable on 64KB-page
  aarch64 (some Graviton). Use 0x10000.
- **verify substrate**: NO arm64 self-hosted host — smoke runs under qemu-aarch64-static on an x86
  pool host or a cloud arm64 runner; qemu fidelity must be sanity-checked vs real hardware before flip.

## ⚠️ MEASURED FINDING (aiden · rung-1 "reloc-free" assumption FALSIFIED)
The rung-1 scope ("a trivial `fn main()->Int{return 42}` is reloc-free") is FALSIFIED by measurement.
aiden readelf of the cross-emitted arm64 `.o`: `main` carries ONE reloc —
`R_AARCH64_CALL26 → hexa_set_args + 0` (an UNDEFINED runtime extern). Disasm:
`stp x29,x30,[sp,#-16]!; mov x29,sp; bl hexa_set_args; mov x0,#0; mov x1,#42; ldp; ret` — the
codegen unconditionally emits `bl hexa_set_args` at every main's prologue (argc/argv capture), so
NO real hexa program is reloc-free. (The return `mov x0,#0; mov x1,#42` confirms the HexaVal pair
tag=0/payload=42 → exit code = x1 = 42, validating the stub's `mov x0,x1`.)

Consequence: the x86 own-start rung-1 likewise routes an UND-bearing program through the runtime.a
variant `link_elf_x86_64_ownstart_ar` (main.hexa dispatch: `_prog_has_und && rt_a → _ar`). So the
REAL minimal arm64 rung is **runtime.a-aware** — it must (1) resolve `hexa_set_args` (+ its transitive
runtime.a members) from an **arm64 runtime.a** (which does not exist yet → depends on rung-4 target-
runtime plumbing), and (2) apply the full reloc set (CALL26 to pulled members + their ADRP/ADD/ABS64).

Status of the rung-1 implementation (committed feat/axis3-arm64-ownlink-rung1 @ 4dc1cce8a, VERIFIED
compiles + dispatches on aiden, fail-loud correct — NO silent miscompile): `serialize_elf_exec_arm64`
+ the verified 24-byte `_start` stub + the CALL26 patch + the dispatch wiring are all correct and
REUSABLE for the runtime.a-aware rung. The leg currently refuses (rc=3) any real program because all
carry the `hexa_set_args` UND — so it is HELD (not PR'd) until it can link something.

REVISED rung ladder: the real next rung = **runtime.a-aware own-link** (rung-2 below) which itself
needs **an arm64 runtime.a** (rung-4). i.e. rung-4 (arm64 runtime.a cross-build) is a PREREQUISITE of
a working arm64 own-link, not a follow-on. Recommended order: rung-4 (cross-build build/runtime.arm64-
linux-gnu.a) → rung-2 (parse_ar_arm64 + archive_extract + full CALL26/ADRP/ADD/ABS64 applicator) →
verify qemu exit 42 → PR. This is a large multi-file port (mirror elf_x86_64.hexa:3208/3826/4143/4297).

## ✅ rung-4 FEASIBILITY PROVEN (aiden · measured)
`runtime.c` (the emitted C substrate) cross-compiles CLEANLY for arm64:
`aarch64-linux-gnu-gcc -c -O2 -D_GNU_SOURCE -DHEXA_ZEROC_OWN_START -I self self/runtime.c` → 0 errors
(only benign `no_builtin`/`weak_import` attribute-ignored warnings) → `rt_arm64.o` = ELF64 ARM aarch64
relocatable (584KB) with `hexa_set_args` DEFINED (`T`). So an arm64 runtime.a is buildable by cross-
compiling runtime.c + the arm64 native seeds (runtime_hi_arm64-linux.s etc.) + `aarch64-linux-gnu-ar`.
(Building runtime.a via a C cross-compiler is BUILD-time — sanctioned, exactly like the x86 runtime.a
is built with clang; the arm64 own-LINK via hexa_ld is what makes USING hexa clang-free.) rung-4 is
therefore a mechanical stage_resolve_runtime_a cross-TARGET extension, NOT a research risk.

## Remaining = rung-2 (the archive-aware arm64 linker port · the large careful effort)
With rung-1 (serialize + stub + CALL26 + wiring) landed & verified and rung-4 proven feasible, the SOLE
remaining piece for a WORKING arm64 exit-42 own-link is rung-2: mirror the x86 archive-aware own-link —
`parse_elf_arm64_obj` (mirror elf_x86_64.hexa:3826), `parse_ar_archive` (:4143), `archive_extract_fixpoint`
(:4297), `link_elf_arm64_ownstart_ar` (:3208) + a FULL aarch64 reloc applicator (CALL26 + ADR_PREL_PG_HI21/
ADD_ABS_LO12_NC page-pair + ABS64 + JUMP26 for every reloc in the pulled runtime.a members). This is a
large, error-prone multi-file port (the ADRP page-math + per-type bit-packing are silent-fail hazards
requiring reference-match + qemu verification of each) — a focused multi-session engineering effort, NOT
a tail-of-session rush (measure-not-LLM + release-integrity forbid merging an unverified reloc applicator).
Recommended: rung-4 (cross-build build/runtime.arm64-linux-gnu.a) first as a completable deliverable, then
rung-2 with the runtime.arm64.a as the qemu-verifiable link target.

## Subsequent rungs (not this session)
- **Rung-2** runtime.a-aware own-link: port `link_elf_arm64_ownstart_ar` (:3208) + `parse_elf_arm64_obj`
  (:3826) + `parse_ar_archive` (:4143) + `archive_extract_fixpoint` (:4297) + `serialize_elf_exec_arm64_2seg`
  (:3579, second R+W PT_LOAD) — real program pulling runtime.a members, exit+stdout smoke.
- **Rung-3** full reloc applicator: ABS64(257) init_array ptrs, JUMP26(282) tail-calls, ABS32(258),
  LD_PREL_LO19; bit-exact patchers with unit vectors; static GOT only if runtime.arm64.a census shows
  real ADR_GOT_PAGE(311)/LD64_GOT_LO12_NC(312) demand.
- **Rung-4** target-runtime plumbing: EM_AARCH64 branch in `_runtime_a_arch_ok` (self/main.hexa:1733),
  HEXA_PREBUILT_RUNTIME_ARM64_LINUX (:1716), arm64 in `_cross_aprime_target` (:2895), cross-emit
  build/runtime.arm64-linux-gnu.a in stage_resolve_runtime_a + install.sh.
- **Rung-5** wire the 3 own-link gate sites (opt-in): cmd_run HEXA_LINK_HEXA (:4705),
  HEXA_BUILD_NATIVE_CROSS (:3694), default-flip (:3599) with a Linuxaarch64/Linuxarm64 uname arm.
- **Rung-6** measured default-ON flip: byteeq 3-target GREEN + native-arm64-host (Graviton) self-host +
  install smoke GREEN. Never promote on cross-emit/qemu alone.
- **Rung-7** in-process darwin-arm64 own-link: `link_macho_arm64_ownstart` to retire the external
  $HEXA_LD fork (main.hexa:1319-1321) — closes the last non-in-process own-link leg.

## Open questions (Fable · mostly rung-2+)
- runtime.arm64.a reloc census: any R_AARCH64_ADR_GOT_PAGE(311)/LD64_GOT_LO12_NC(312) forcing a
  synthesized GOT for a static ET_EXEC, or ABS64(257) init_array / JUMP26(282) the linker must apply?
  Run nm/readelf over a native-built runtime.arm64.a before committing rung-2's applicator scope.
- Page-size policy: 4KB vs 64KB PT_LOAD align — pick max-safe (0x10000) or probe?
- _start handoff: mirror x86's _hx_start_c OWN_START suppression (init_array/atexit, :1903-1948) now,
  or ship the trivial hand-stub for rung-1/2 and defer C-runtime-init handoff?
- Verify oracle: is qemu-aarch64-static acceptable for byteeq/smoke given no arm64 self-hosted host,
  or does release-integrity mandate a real cloud-arm64 (Graviton) run before default-ON?
- Pre-patch interaction: the .o pre-patches cross-object BL in place (:673-684) — confirm the
  applicator must ignore pre-patched bytes and recompute from the recorded CALL26 addend/section-base.

## Note
The x86_64-template reader in the research workflow returned a placeholder (empty); the x86_64 anchor
lines above were recovered from the arm64-current reader's cross-references. Re-read elf_x86_64.hexa
directly when implementing each mirrored piece.
