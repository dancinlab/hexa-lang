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

## 🧱 rung-2 SCOPE MEASURED (aiden · captured numbers — a full aarch64 static linker)
Attempted to scope the rung-2 reloc applicator by measuring the actual runtime object's relocs + UNDs
(NOT a pre-emptive defer — measured with `readelf -r`/`nm`):
- **8263 relocs across 12 R_AARCH64 types**: ADR_PREL_PG_HI21 (1998) · CALL26 (1834) · ADD_ABS_LO12 (1586)
  · PREL32 (1035) · LDST64_ABS_LO12 (503) · **LD64_GOT_LO12 (463) + ADR_GOT_PAGE (463) = 926 GOT relocs**
  · JUMP26 (197) · LDST32 (141) · LDST128 (22) · ABS64 (20) · LDST8 (1).
- **23 UND symbols** incl. libc (`__libc_calloc/free`, `memcpy/memset/memmove`, `strlen`, `strtod`, `abort`,
  `getc`, `regcomp/regexec/regfree`, `__stack_chk_fail/guard`, `__fdelt_chk`, `__longjmp_chk`) + the arm64
  native-seed symbols (`rt_array_*_native`, `rt_map_*_native`) that are NOT ported/linked for arm64 yet.

VERDICT (measured, not judged): a working arm64 own-link requires a FULL aarch64 static linker —
**GOT synthesis** (926 GOT relocs demand a real GOT, unlike rung-1's assumption of static-non-PIE), a
**12-type reloc applicator** (each type's bit-packing is a distinct silent-fail hazard), AND an arm64
runtime.a whose members carry own-syscall shims for the 23 libc/native UNDs (many arm64 native seeds —
mem/str/array/map — not yet ported). This is a large MULTI-PART campaign (linker + GOT + arm64 native
runtime shims), decisively NOT session-completable, and rushing it would ship a silent-miscompiling
linker (violates measure-not-LLM + release-integrity). The x86 own-link tames this via a PER-FUNCTION
runtime.a + selective `archive_extract_fixpoint` (pulls only a symbol's closure, not the whole 8263-reloc
blob) + the full x86 native-seed set — so the arm64 campaign must port BOTH the archive linker (rung-2)
AND the arm64 native-seed runtime (rung-4-extended), across many focused rounds with per-round qemu verify.

## 🗺️ RUNG-2 IMPLEMENTATION PLAN (workflow wf_3521d199-82f · reference-matched · IN PROGRESS)
VERDICT: a working arm64 exit-42 own-link IS achievable — a faithful retype of the already-GREEN
5493-line x86 own-link stack (link_elf_x86_64_ownstart :1849 + archive_extract_fixpoint :4297 + GOT
synth + CRT1-HANDOFF). Reloc math is FULLY spec'd + 12-unit-vectored (the bit masks already exist,
proven, in the Mach-O arm64 patcher tool/hexa_ld.hexa:1601-1746 + the CALL26 stub elf_arm64.hexa:868)
— the ELF port REUSES them verbatim. ~3-5 focused rounds. HARD PRECONDITION (S0, VERIFIED): branch
from origin/main (5493-line elf_x86_64.hexa), NOT the stale fix/install-bare-cuda-pip 1739-line copy.

MINIMAL FIRST-WORKING (Round-1, dynamic crt_handoff): reuse the x86 CRT1-HANDOFF — when the residual-UND
census (n_dyn>0) finds genuine libc UND, pull sysroot crt1.o, make ITS _start the entry, emit a dynamic
glibc aarch64 ET_EXEC. Proves parser+extractor+applicator+GOT+2-seg (ZERO binutils; uses system crt1.o
+libc.so — not yet fully clang-free). Round-2 drains residual to ∅ (ar the arm64 array/map/alloc seeds
+ hxlcl_ alias) → census []→ crt_handoff false → PURE own-start static ET_EXEC (no PT_INTERP/crt1) =
the true no-crt exit-42. (rt_array_*_native/rt_map_*_native UNDs resolve once those seed .o's are ar'd.)

Ordered steps (file · x86 anchor · verify):
- **S0** branch from origin/main (VERIFIED: 5493 lines · fixpoint@4297 · parse@3826 · ar@4143).
- **S1** ✅ DONE constants — elf_arm64.hexa:62: PREL32=261, LDST8/16/32/64/128=278/284/285/286/299,
  ADR_GOT_PAGE=311, LD64_GOT_LO12_NC=312, _elf_arm64_kind_is_got. (psABI + link/hexa_ld.hexa:692-697.)
- **S2** runtime.arm64-linux-gnu.a (rung-4) — 2 shell diffs to tool/stage_resolve_runtime_a: (a) :63
  RA=${HEXA_RUNTIME_A_OUT:-.../runtime.a}; (b) ar rcs → "${AR:-ar}" rcs (:3283/3254/3263/3291). Run
  CC=aarch64-linux-gnu-gcc AR=aarch64-linux-gnu-ar TARGET=linux-arm64 CFLAGS+=' -fno-stack-protector'.
  Verify: nm shows all rt_*_native + own _start defined; per-family seed echoes present; member EM_AARCH64.
- **S3** parse_elf_arm64_obj (clone parse_elf_x86_obj, 2 deltas: e_machine 0x3e→0xb7 + ElfArm64Obj 8-field,
  drop SHT_INIT_ARRAY slot-6/aligns) + REUSE parse_ar_archive verbatim + archive_extract_fixpoint_arm64
  (s/ElfX86Obj/ElfArm64Obj/, floor-pull #4871 carries verbatim). Anchors :3826/:4143/:4297/:4370-4443.
- **S4** _apply_arm64_reloc + _aa_page/_aa_u32/_aa_put32/_aa_put64/_aa_ldst_scale (12 types · masks VERBATIM
  from tool/hexa_ld.hexa:1601-1636/1730-1746). CRITICAL: page delta = (Page(base+A)-Page(P))/0x1000 integer
  DIVIDE not >> (Q4); site_seg dispatch (1=text/3=rodata/4=data); ABS64/PREL32 raw bytes; G≠S for 311/312;
  LDST assert (S+A)&((1<<scale)-1)==0; branch on TYPE not instr bits; rc 0/1-unhandled/2-range. Full code
  in the piece-1 workflow result (task w608xhoul).
- **S5** GOT synth in link_elf_arm64 — fix @GOTPAGE→311/@GOTPAGEOFF→312 (:102-104) + emit LDR base word;
  collect got_syms by DISTINCT name over 311/312; alloc n_got*8 at data tail; patch G=data_base+off+slot*8
  (ADRP Page uses 0x1000 not p_align); fill slot = sym final vaddr (truly-undef → rc3). Anchors :2285/2603/2914/3064.
- **S6** serialize_elf_exec_arm64 (phnum=2: R+X text + R+W data+GOT · code_off=176 · data page-aligned 0x10000)
  + link_elf_arm64 + link_elf_arm64_ownstart w/ crt_handoff census. Anchors :730/:1109/:1849. NEW = aarch64
  own _start stub (Q1, BLOCKING — Fable byte-spec).
- **S7** driver wiring — opt-in --linker=hexa for aarch64 only; default bit-identical (byteeq-neutral).
- **S8** aiden qemu-aarch64-static exit-42 (see gate) — Round-1 dynamic, Round-2 pure static.

AIDEN VERIFY GATE: git checkout -b arm64-ownlink origin/main; build runtime.arm64.a (S2 env); build hexa;
`HEXA_LD_SYSROOT=/usr/aarch64-linux-gnu/lib hexa build --target=aarch64-linux-gnu --linker=hexa -o /tmp/exit42
exit42.hexa`; `qemu-aarch64-static /tmp/exit42; echo rc=$?` → rc=42. readelf: ET_EXEC/AArch64/ELF64;
R-1 PT_LOAD×2+PT_INTERP, R-2 PT_LOAD×2 no PT_INTERP/PT_DYNAMIC; -r zero unresolved. BYTEEQ-3-target with
--linker=hexa OFF → default gen3 sha256 bit-identical (opt-in fns unreferenced).

BLOCKING open questions (Fable / measure-first):
- Q1 own-start stub bytes (aarch64: sp→x0/x1, optional envp→_hxlcl_environ, bl main, mov x8,#94/svc#0, rc=x0).
- Q2 crt1.o handoff: does sysroot crt1.o parse + exit clean under qemu? PIE Scrt1.o carries RELATIVE/GLOB_DAT
  (1025/1027 — outside the 12); Round-1 likely needs -no-pie crt1.o.
- Q3 ✅ ANSWERED (my earlier readelf histogram = the 12 types · no MOVW/CONDBR/TLS surprises).
- Q4 (silent-miscompile #1) hexa `>>` sign-extend vs zero-fill — confirm empirically; use DIVIDE for page deltas.
- Q5 GOT name-dedup collision (two STB_LOCAL g<id> same name → one slot) — key by (member,name) if unsafe.
- Q6 alignment: ElfArm64Obj drops rodata/data_align — pad pools to 16 or extend struct; census .init_array.

## ✅ S2/rung-4 MEASURED (aiden) — arm64 native seeds ALL EXIST + assemble
Big positive vs the workflow's assumption that arm64 native seeds need porting: they are ALREADY
in-tree and assemble cleanly for TARGET=linux-arm64. The cross-build assembled every seed:
runtime_hi_arm64-linux.s (15 rt_str_*), array_core_arm64-linux.s (6 rt_array_*_native),
map_core_arm64-linux.s (4 rt_map_*_native), intern (2), fs (2), num_float, float_parse_exact, num,
valop_core_arm64-linux.s (10/10 incl cmp+div/mod), alloc_syscall_arm64-linux.s (122 syms incl own
_start). Only 2 optional seeds fail-soft to C libc (float_parse_hexinfnan tail, regex). So the
rt_array_*_native/rt_map_*_native UNDs seen earlier are NOT gaps — they resolve the instant those
seed .o's are ar'd in (which the S2 recipe does). rung-4 is therefore highly feasible. Build-harness
note: the seeds-present branch needs a regenerated self/runtime.c (gitignored); a fresh checkout hits
the EDGE_ASSET/frozen-seed branch, so the cross-build must run after the emitter regen (release_build/
build_aprime does this) or with self/runtime.c copied in.

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

## Rung-2 OUTCOME — MEASURED (aiden aarch64-linux-gnu cross + qemu · 2026-07-12)

**Rung-2 static own-link linker = DEMONSTRATED CORRECT.** `link_elf_arm64_ownstart_ar` reads
runtime.arm64.a → `archive_extract_fixpoint_arm64` → def-map → GOT synth → `_apply_arm64_reloc` →
`serialize_elf_exec_arm64_2seg`, reaching reloc-apply and correctly identifying the genuine residual
libc floor. Three build/emitter fixes landed to get here (all opt-in `--linker=hexa`, default-OFF,
byteeq-neutral for the 3 shipped targets):
- **4ce846945** — cross-archive arch-contamination: `stage_resolve_runtime_a` S2 arch-guard purges
  build/*_native.o whose e_machine ≠ TARGET (13 seed helpers cached on file-existence only, so a
  host-x86 build left x86 seeds that a `linux-arm64` cross-stage ar'd in); + `emit_cross_arch` tripwire
  now checks EVERY member not head -1. convergence axis3-arm64-cross-archive-arch-contamination.
- **6c525868f** — asm-text @PAGE gap: `compiler/emit/asm.hexa` `_fmt_label` translates Mach-O
  `@PAGE`/`@PAGEOFF`/`@GOTPAGE`/`@GOTPAGEOFF` → GNU-as ELF `:lo12:`/`:got:`/bare-adrp for arm64-linux
  (the aprime arm64 asm emitter emitted Mach-O page-addressing regardless of target OS → GNU-as
  rejected the regenerated arm64-linux native seeds). convergence asm-hexa-1. The 2 seeds (regex_rt,
  float_parse_hexinfnan) now assemble + ar in → arm64 seed T-defs = 217 = x86 parity.

**The measured wall = a precise 6-symbol residual libc floor**, NOT the linker. runtime.o (the big C
runtime member, pulled transitively by `hexa_set_args` which every own-`_start` references) imports
from libc: **`__libc_calloc  __libc_free  abort  getc  longjmp  strtod`** (x86's floor = same 6 minus
longjmp; `main` supplied by the program obj). x86 own-link resolves these via its **Road A
dynamic-link** path (`_ld_read_libc_dynsym` elf_x86_64.hexa:1765 → PLT+GOT+`.dynsym`+`.rela`+
`DT_NEEDED libc.so.6`+`PT_INTERP` → dynamic ET_EXEC). arm64 own-link is static-only → hard-errors
`undefined symbol 'strtod' (reloc 283=CALL26)` rc=3. This is a LINKER-CAPABILITY divergence (x86 has
Road A, arm64 does not), quarantined from the linker verdict per infra-wall-noneval — both arches pull
runtime.o identically; the linker is innocent (its 3rd measured innocence this campaign).

**Rung-3 = Road A dynamic-link for arm64** (Fable designing the AArch64 PLT/dynsym/DT_NEEDED port,
reference-matching x86's mechanism 1:1) → produces a working dynamic AArch64 ET_EXEC resolving the
6 floor syms from libc.so.6 → exit42 qemu rc=42. Alternative under Fable review: native-port the 6
floor leaves (abort=SIGABRT svc, getc=read(2), __libc_calloc/free=arena alias, longjmp=native ABI,
strtod=hard) for pure-static — hybrid vs full-Road-A to be recommended. NB: x86 itself uses Road A
(not pure-static) for the floor, so "pure-static arm64" was always going to hit this wall.

## Rung-3 RESULT — Road A dynamic-link IMPLEMENTED + VERIFIED WORKING (aiden qemu · 2026-07-12)

**arm64 own-link (--linker=hexa) now produces a WORKING dynamic AArch64 ET_EXEC.** Full Road A
dynamic-link (Fable-designed, 1:1 mirror of link_elf_x86_64_ownstart's GLOB_DAT-only mechanism)
landed as S1-S6 in link_elf_arm64_ownstart_ar + serialize_elf_exec_arm64_dyn:
- **crt_handoff gate** (residual-libc-UND census >0) → prepend crt1.o, suppress hand stub, entry =
  crt1 `_start`. Census EXACT: `n_dyn=7` = {__libc_start_main abort strtod longjmp __libc_free getc
  __libc_calloc} (the measured 6-sym floor + crt1's __libc_start_main).
- **12-byte AArch64 veneers** (adrp x16/ldr x16/br x16) per dyn sym + GLOB_DAT `.rela.dyn` + DT_HASH +
  `_DYNAMIC` (DT_NEEDED libc.so.6) + PT_INTERP `/lib/ld-linux-aarch64.so.1`, 4 phdrs, code_off=288.
- **Verified (qemu-aarch64 -L sysroot)**: BIN OK 519KB · PT_INTERP + DT_NEEDED libc.so.6 present · ld.so
  loads + resolves all 7 GLOB_DAT floor syms · `main` RUNS (`print("MAIN-RAN")` prints) · exits cleanly.

**2 bugs measured+fixed en route** (measure→root-cause→fix, both convergence-recorded):
- asm @PAGE→ELF :lo12: emitter gap (asm-hexa-1) — regenerated the 2 arm64-linux seeds (8062a2f87).
- **bss_vaddr_base misalignment** (elf-arm64-hexa-1, corrected): the appended dyn blobs (interp 27B odd)
  left `len(data_bytes)` unaligned → an odd bss_vaddr_base → a `.bss` section-symbol LDST64 rc=2. Fix:
  16-align data_bytes before bss_vaddr_base (0afd3c7b5). DIAG measured S=4713587(odd)+A=0, readelf
  confirmed member0=runtime.o sec4=.bss(align16).

**Remaining gap — rc=0 not 42 (SHARED with x86, NOT an arm64 defect)**: the crt1-handoff dynamic path
exits 0 instead of main's `return 42`. **Measured-identical on the x86 own-link reference (rc=0)** — so
arm64 rung-3 has EXACT behavior parity with the shipped x86 mechanism. main RUNS (print works); only the
return-value→exit-code propagation is dropped (a runtime-main-ABI / __libc_start_main-contract detail
shared by both arches). Fable investigating the root cause (arm64-only wrapper vs shared codegen main-
lowering). This is a follow-on rung, quarantined from the rung-3 linker verdict per infra-wall-noneval:
the LINKER + dynamic-link mechanism is verified working at x86 parity.

## Note
The x86_64-template reader in the research workflow returned a placeholder (empty); the x86_64 anchor
lines above were recovered from the arm64-current reader's cross-references. Re-read elf_x86_64.hexa
directly when implementing each mirrored piece.
