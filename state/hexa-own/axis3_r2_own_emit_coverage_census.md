# Axis-③ own-emit x86_64 COMPILE coverage census (③-R2)

**HEAD:** origin/main `ed599aa6b` (#4721 HEXA_LINK_HEXA opt-in own-link) + #4724. Read-only census — the ENCODE-MISS worklist the axis-③ round-1 plan promised.

## Mechanism defining the gap
x86_64 own-emit COMPILE path: codegen `x86_64_linux.hexa` (MIR→LIR) → walker `_pack_fn_x86` (elf_x86_64.hexa:1347) → per-insn `encode_x86_64_insn`. **The walker is SILENT on any op the encoder can't encode**: encoder falls through to `return []` (elf_x86_64.hexa:718), walker appends zero bytes with NO diagnostic (:1446-1449, documented :1194). Worse than the arm64 mirror which prints `ENCODE-MISS` (macho_arm64.hexa:713). → an unsupported op = **silently corrupt text**, not a build error. This is the exact failure the round-1 plan named (`ENCODE-MISS == 0` gate).

## covered_constructs (encoder handles)
Integer-only subset: mov/add/sub/cmp (r32 + r64/REX.W + imm), push/pop, lea (incl RIP-relative → R_X86_64_PC32, :1213/1419), call/jmp/jcc (REL8/REL32 + PLT32), ret, syscall, nop/pause/mfence, cqo, idiv (64-bit), test (64-bit), movzx, setcc (e/ne/l/ge/le/g). Memory operands DO work (`_ex86_parse_mem`:234, `_ex86_modrm_mem`:283 → `[rbp-8]`). Reloc kinds 64/PC32/PLT32.

## gap_constructs — codegen EMITS, encoder DROPS silently (→ 718 return [])
x86_64_linux.hexa emission counts:
- **imul** 21× (index scaling, struct offsets) — absent → silent drop.
- **bitwise** and 158× / or 32× / xor 10× — absent (xor = zeroing idiom + bool logic).
- **shifts** shl/shr/sar 6× each — absent.
- **neg/not** (unary), **movsx** — absent.
- **entire SSE float family**: addsd/subsd/mulsd/divsd/movsd/cvtsi2sd/cvttsd2si/comisd — **no xmm register table, no SSE opcode at all**. Any float program → silent corrupt text.

## C-transpile contrast
self/native/hexa_cc.c = 28,482 LOC (full runtime+ops via host C). The own x86_64 encoder = ~700-line integer subset (elf_x86_64.hexa:322-718). Delta the own path does NOT handle: integer multiply, all bitwise/shift, all floating-point (load-bearing) + downstream (exceptions/setjmp, va_list, large structs, closures).

## known walls surveyed (not re-derived)
- try/catch setjmp native lane — KNOWN defect (memory project_hexa_native_trycatch_setjmp_defect). Noted, not re-investigated.
- axis-③ round-1 (`as`-kill) crossemit smoke = hand-built freestanding `_start` fixture (stdout=="hi" rc==7, tool/selfhost_crossemit_smoke.sh:40/278) — a minimal integer program never exercising imul/shift/float; the round-1 doc flags "extended real-corpus measurement genuinely needed" → THIS census is that gap list.
- `--linker=hexa` for x86_64 = unwired stub (main.hexa:1181 warns + falls back to system ld); tool/hexa_ld.hexa rejects non-Mach-O-arm64 (:262-269) — the LINK-half gap (separate from this COMPILE census).
- x86 cmp-immediate codegen bug (state/hexa-own/x86_cmp_immediate_fix_design_fable.md, x86_64_linux.hexa:4036 setcc path) — live codegen correctness blocker on strtod-tail flip; same x86 leg.

## default_flip_readiness
**~0–5%** of real programs compile cleanly via own-emit x86_64 today. Compiler self-build + stdlib + every shipping-smoke program use imul and/or bitwise/shift (indexing, hashing, struct layout) + floats (runtime, math) — all silently ENCODE-MISS. Only trivial int-add/sub/branch/call programs (the "hi"/rc=7 fixture class) round-trip. Blocker order any real program hits: (1) imul (2) bitwise and/or/xor (3) shifts (4) SSE float (5) neg/not/movsx.

## top_leverage_gaps (ranked)
1. **imul** (IMUL r64,r64 + r64,imm) — highest: multiply on every index/offset path; smallest unblock.
2. **bitwise and/or/xor** (+ xor r,r zeroing) — 200× emitted; pervasive.
3. **shifts shl/shr/sar** (imm8 + CL) — hashing/bit-twiddle/pow2 scaling.
4. **SSE float family** (+ xmm reg table) — largest new subsystem; gates all float/math + runtime.
5. **neg/not/movsx** — completes integer-ALU parity with the `as` route.
Cross-cutting safety fix: **make x86_64 encode-miss LOUD** (mirror macho_arm64.hexa:713 at elf_x86_64.hexa:718) so the census gate can fail instead of shipping corrupt text.

## round3_name
**③-R2a: x86_64 encoder integer-ALU completion** — IMUL + bitwise(and/or/xor) + shifts(shl/shr/sar) + neg/not/movsx, with a loud ENCODE-MISS abort. (SSE-float = ③-R2b follow-on, separate xmm-operand surface.) Measurement gate = ENCODE-MISS==0 self-emit census on aiden/summer.

## depletion_verdict: NOT depleted
The own-emit x86_64 COMPILE path is far from default-flippable, but the blocker is a concrete enumerable encoder-coverage backlog (integer-ALU round + SSE round), NOT an architectural wall. The one deep track is downstream (dynamic-link leaves for CUDA/dlopen, round-1 §4); the LINK half (ELF hexa_ld) is separate.
