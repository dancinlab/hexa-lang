# axis-③ R2c — x86_64 own-emit encoder-gap census + ENCODE-MISS==0 harness

**Lane:** ③ (no clang) — native own object-emit endgame (source→own-IR→native, `hexa_ld`, no external C compiler).
**Round:** ③-R2c. Predecessors landed: **R2a** #4733 (int-ALU: imul / and·or·xor / shl·shr·sar / neg·not / movsxd) · **R2b** #4740 (SSE scalar-double: movq / movsd / addsd·subsd·mulsd·divsd / comisd·ucomisd / cvtsi2sd·cvttsd2si + movabs imm64).
**Base:** origin/main @ `31194bf07`.
**Method:** cross-reference every LIR op the x86_64 codegen (`compiler/codegen/x86_64_linux.hexa`) EMITS — extracted from the `_x86_instr{1,2,n}(...)` call sites + the two dynamic `_scc`/`set`+suffix builders — against the two coupling gates that turn a LIR op into bytes:
  1. `_lir_op_uppercase_x86` (elf_x86_64.hexa:2541) — lowercase LIR op → encoder op-string; an unmapped op returns its **bare** name.
  2. `encode_x86_64_insn` (elf_x86_64.hexa:359) — op-string + operand shapes → bytes; anything unmatched hits the loud `eprintln("ENCODE-MISS (x86_64): …")` + `return []` (elf_x86_64.hexa:1026).

A LIR op is a **DROP** (loud ENCODE-MISS → zero-length → corrupt/absent machine code) iff neither gate has a rule for it in the operand shape the codegen emits.

---

## Emitted-op inventory (definitive)

The codegen emits **34** distinct machine-op strings. Source of truth = `_x86_instr*` first-arg literals (33) + the two dynamic builders (`_scc`, `"set"+suf`).

Handled today (R2a/R2b + earlier cycles) — encode + map both present:
`mov`·`mov`(mem)·`movq`·`add`·`sub`·`imul`·`idiv`·`cqo`·`test`·`xor`·`and`·`or`·`shl`·`shr`·`sar`·`lea`·`push`·`pop`·`call`·`jmp`·`nop`·`syscall`·`ret`·`label`·`movzx`·`cvtsi2sd`·`cvttsd2si`·`comisd`·`sete`·`setne`·`setl`·`setle`·`setg`·`setge`·`je`/`jz`·`jne`/`jnz`·`jl`·`jge`·`jle`·`jg`.

**Still DROPPED to loud ENCODE-MISS (the R2c gap):** `ja`·`jae` · `seta`·`setae`·`setb`·`setbe` · `cmove`.

---

## RANKED remaining-gap list (ops emitted but encoder DROPS)

### R1 — HIGH — unsigned/float conditional branches `ja` / `jae` (+ symmetry `jb`/`jbe`)
- **Emitted:** 6 sites. `jae`→slow-path on array-bounds checks (x86_64_linux.hexa:1917, 1955, 1990, 2031); `ja`→signed-overflow trap on add/imul (4806, 4862). All are `_x86_instr1("ja"|"jae", _x86_op_label(...))` — **branch-to-label**.
- **Double-broken:**
  1. `_lir_op_uppercase_x86` jcc map (elf_x86_64.hexa:2555–2560) covers only je/jz/jne/jnz/jl/jge/jle/jg → `ja`/`jae` fall through to `return op` (bare `"ja"`) → ENCODE-MISS.
  2. The `_pack_fn_x86` `is_cc` label-branch recognizer (elf_x86_64.hexa:2691–2694) also omits ja/jae, so the branch is never even given a REL8 placeholder/patch — it drops into the default dispatch and mis-emits.
- **Impact:** every emitted array index (bounds slow-path) + every checked add/imul on the own-emit path emits corrupt/zero bytes. This is the single most-reached gap.
- **Fix (next round):** encoder REL8 rules `JA_REL8`=0x77 · `JAE_REL8`=0x73 · `JB_REL8`=0x72 · `JBE_REL8`=0x76 (mirrors the existing JL_REL8/JG_REL8 block at elf_x86_64.hexa:472–477); add `ja/jae/jb/jbe` to the uppercase map **and** to the `is_cc` list at 2691.

### R2 — HIGH — unsigned/float setcc `seta` / `setae` (+ `setb` / `setbe`)
- **Emitted:** float compares (`__hx_payload_flt/fgt/fle/fge`) emit `comisd`+`seta`/`setae` (x86_64_linux.hexa:4373–4380); unsigned-int compares (`__hx_payload_ult/ule`) emit `setb`/`setbe` (4222–4223, 4230). All `_x86_instr1(_scc, _x86_op_reg("al"))`.
- **Broken:** the encoder SETcc block (elf_x86_64.hexa:740–759) and the `_x86_setcc_suffix`/uppercase map (elf_x86_64.hexa:2562–2567) cover only the **signed** set e/ne/l/le/g/ge. `seta/setae/setb/setbe` are unmapped → bare → ENCODE-MISS.
- **Impact:** all floating-point `< <= > >=` comparisons and unsigned integer `< <=` emit zero bytes → the `al` predicate is never set → wrong `movzx` result.
- **Fix (next round):** extend the SETcc opcode table with `SETA`=0x0F 0x97 · `SETAE`=0x0F 0x93 · `SETB`=0x0F 0x92 · `SETBE`=0x0F 0x96 (same ModR/M+REX pattern as the signed six); add `seta/setae/setb/setbe` map entries.

### R3 — MED — conditional move `cmove` (+ symmetry `cmovne`)
- **Emitted:** 1 site — `__hx_to_double` tag-select (`cmp rax,#1` + `cmove r10, r11`, x86_64_linux.hexa:4411–4413). `_x86_instr2("cmove", r10, r11)`.
- **Broken:** no `cmove` in the uppercase map or encoder → ENCODE-MISS.
- **Impact:** every int→double coercion (`__hx_to_double`) mis-emits its tag-select → wrong double bits when the source is already a FLOAT.
- **Fix (next round):** `CMOVE64` = REX.W 0F 44 /r (reg=DEST, rm=SRC — like IMUL64's reg-is-dest form); add `CMOVNE64`=0F 45 for symmetry; map `cmove/cmovne`.

**Gap closure:** R1+R2+R3 = **9 new op-strings** (ja·jae·jb·jbe / seta·setae·setb·setbe / cmove·cmovne — jb/jbe/cmovne are additive-for-symmetry, not emitted today). After these land the codegen's **emitted** op-set is fully encodable → ENCODE-MISS should measure **0**.

---

## Correctness gaps — NOT ENCODE-MISS (encoder returns bytes, but WRONG)

These do not trip the loud miss (the ENCODE-MISS==0 census would pass) yet silently emit incorrect machine code. Flagged for a follow rung; **more dangerous than a loud drop** because they are invisible to the stderr census.

- **C1 — `cmp` is width-frozen to 32-bit.** `_lir_op_uppercase_x86` maps `cmp`→`"CMP"` **unconditionally** (elf_x86_64.hexa:2592, explicit `// r32 only for now (cycle-30 widens)` TODO). The codegen emits `cmp` on 64-bit regs/imm at 8 sites (rax/r10/r11: x86_64_linux.hexa:1915, 1953, 1988, 2029, 4181, 4195, 4228, 4411). The encoder's `CMP r32,r32` (0x39) / `CMP r32,imm` (0x81 /7) forms emit **no REX.W** → only the low 32 bits are compared → wrong flags for pointers / full-range i64. (The two genuinely-32-bit `cmp eax,#imm` sites at 4804/4860 are correct.) Fix: `CMP64` width dispatch (REX.W + 39 /r, REX.W + 81 /7 id), mirroring ADD/SUB's is64 branch.
- **C2 — 32-bit sub-registers `r10d`/`r11d` mis-dispatch to MOV64.** `is64` keys on the first char being `r`/`R` (elf_x86_64.hexa:2583), so `mov r10d, [mem]` (intended 32-bit zero-extending load) is treated as 64-bit MOV64 (REX.W 8B) → reads **8 bytes** and skips the zero-extend → wrong value. Sites: `mov r10d,[…]` loads (x86_64_linux.hexa:4473 arr->len, 4968 ptr_load32) and `mov […],r11d` va_list stores (4765, 4773). Fix: detect an `r??d` suffix in the width probe and force the 32-bit form.

---

## Falsified gap-candidates (checked, NOT emitted → not a gap today)

- **cvtss2sd / cvtsd2ss (single↔double):** NOT emitted — the hexa float path is all f64/double (only cvtsi2sd/cvttsd2si/comisd appear). No f32↔f64 scalar convert in codegen.
- **movaps / movsd-mem xmm spill-reload:** NOT emitted — there is no scalar spill-to-stack emitter today (the encoder's `MOVSD` reg-reg rule is additive/dead per its own comment). No gap yet; becomes relevant only if a future register allocator spills xmm.
- **rep movs / rep stos (inline memcpy/memset):** NOT emitted — bulk copy goes through a `call` to the runtime, not inline string ops.
- **lea with SIB index*scale:** NOT emitted — `_lir_operand_str_x86` only ever produces `[base]` / `[base ± disp]` (no index/scale token), and data-symbol address materialization uses the RIP-relative `lea` path (elf_x86_64.hexa:2726). `LEA64 [base+disp]` covers every emitted form.
- **True 8-bit `mov [mem], al` byte store:** NOT emitted — byte results flow al→movzx→r32/r64; byte-granular array writes go through runtime calls. (The only `al`/`cl`/`sil` uses are movzx sources, setcc dests, and the shift-count `cl`, all handled.)

---

## ③-R2c measurement — ENCODE-MISS==0 census (aiden, x86_64-linux)

The existing `scripts/scratch/rt_native/byteeq_x86.sh` **already** performs the exact substrate this census needs: it flattens the whole compiler self-source (`compiler/main.hexa` + transitive imports, embedded.gen.hexa stubbed) into `/tmp/flat_x86.hexa` and emits it to an x86_64-linux relocatable object via `aprime_cc --emit=obj --target=x86_64-linux-gnu`, capturing emit stderr to `/tmp/emit3.log` and **already greps `ENCODE-MISS`**. R2c is a thin census wrapper on that path — no new harness file required.

### Exact command (run on aiden — x86_64 linux, in a fresh worktree at the round-under-test HEAD)

```bash
# 0. build the compile driver (C-transpile-built aprime_cc drives the native emit path).
#    (already produced by the standard selfhost build; AP defaults to build/aprime_cc)
export AP=build/aprime_cc

# 1. flatten + emit the full compiler self-source to an x86_64-linux object,
#    forcing the native own-emit backend, capturing emit stderr.
bash scripts/scratch/rt_native/byteeq_x86.sh          # emits g3x.o + g4x.o, logs → /tmp/emit{3,4}.log
#    (byteeq_x86.sh invokes: "$AP" _drv.hexa --emit=obj --target=x86_64-linux-gnu -o /tmp/g3x.o /tmp/flat_x86.hexa)
#    For an explicit native-backend census add --backend=native to that invocation.

# 2. census: count loud ENCODE-MISS lines over the whole self-source emit.
MISS=$(grep -c "ENCODE-MISS (x86_64):" /tmp/emit3.log || true)
echo "ENCODE-MISS count = $MISS"
#    optional breakdown of which ops still drop:
grep -oE "ENCODE-MISS \(x86_64\): [A-Za-z0-9_]+ nargs=[0-9]+" /tmp/emit3.log | sort | uniq -c | sort -rn
```

### PASS criterion

- **PRIMARY:** `grep -c "ENCODE-MISS (x86_64):" /tmp/emit3.log` **== 0** — the full compiler self-source lowers with zero dropped ops on the x86_64 own-emit path.
- **CONJOINT (already asserted by byteeq_x86.sh):** `BYTEEQ_OK` — `cmp /tmp/g3x.o /tmp/g4x.o` byte-identical (gen3≡gen4 self-reproduction). ENCODE-MISS==0 without byteeq is insufficient (a wrong-but-deterministic encoding still reproduces).
- **NOTE (advisory, not gated by the stderr census):** ENCODE-MISS==0 does **not** prove correctness — the C1/C2 correctness gaps above emit *bytes* and are invisible here. The honest DONE bar for the own-emit x86_64 backend is ENCODE-MISS==0 **AND** byteeq **AND** the emitted object runs correctly (execute the linked exec + diff output vs the C-transpile gen), which is the follow-on to a clean R2c.

### Where this runs

aiden / summer (x86_64-linux self-hosted pool hosts; mini = git/gh/read only, never build). Do not run on mini. Pool currently loaded — schedule after the current build drains, or gate via a PR that adds the `MISS==0` assertion to `byteeq_x86.sh`'s tail as a standing check.

---

## round_next

Encoder round **③-R2d** — close R1 (ja/jae/jb/jbe REL8 + is_cc list) + R2 (seta/setae/setb/setbe) + R3 (cmove/cmovne) in one byte-neutral encoder PR (shipping compiler is C-transpile-built, so these bytes are dead until own-emit default-flips → byteeq-safe). Then run the **ENCODE-MISS==0 census** command above on aiden as the R2d verification gate; on `MISS==0 && BYTEEQ_OK`, advance to the correctness follow (C1 CMP64 width + C2 r??d sub-register), then the run-correctness exec-diff. If a subsequent census run already shows `MISS==0` on the current op-set, skip straight to the census-as-gate + correctness rungs.
