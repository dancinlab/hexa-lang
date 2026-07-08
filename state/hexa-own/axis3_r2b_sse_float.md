# Axis-③ own-emit x86_64 R2b — SSE scalar-double float family

**Round:** ③-R2b (follow-on to ③-R2a #4733 integer-ALU completion).
**File:** `compiler/emit/elf_x86_64.hexa` (`encode_x86_64_insn` + `_lir_op_uppercase_x86` + new `_ex86_xmm`).
**Byte-class:** byte-neutral for the shipping compiler (built via C-transpile, not this walker) → PR-CI byteeq 3-target authoritative. Only `--backend=native`/own-emit exercises these bytes.

## What landed
Closes the "entire SSE float family" gap the R2 census (`axis3_r2_own_emit_coverage_census.md` §gap_constructs) named as the largest remaining hole — any float program previously silently ENCODE-MISSed.

1. **xmm register table** `_ex86_xmm(s) -> 0..15` (xmm0..xmm15; -1 on a GP token so the mixed-operand ops disambiguate).
2. **SSE ops** in `encode_x86_64_insn`, reference-matched to Intel SDM Vol 2 (scalar double, SSE2). Encoding order = `[mandatory prefix F2/66] [REX] [0F] [opcode] [ModR/M]` (mandatory prefix precedes REX, SDM §2.2.1):

   | op | mnemonic | encoding | example bytes |
   |----|----------|----------|---------------|
   | GP→xmm | `movq xmm, r64` | `66 REX.W 0F 6E /r` | `movq xmm0,r10` → 66 49 0f 6e c2 |
   | xmm→GP | `movq r64, xmm` | `66 REX.W 0F 7E /r` | `movq r10,xmm0` → 66 49 0f 7e c2 |
   | `movsd` | xmm1,xmm2 | `F2 0F 10 /r` | 66→ f2 0f 10 c1 |
   | `addsd` | | `F2 0F 58 /r` | f2 0f 58 c1 |
   | `subsd` | | `F2 0F 5C /r` | f2 0f 5c c1 |
   | `mulsd` | | `F2 0F 59 /r` | f2 0f 59 c1 |
   | `divsd` | | `F2 0F 5E /r` | f2 0f 5e c1 |
   | `comisd` | | `66 0F 2F /r` | 66 0f 2f c1 |
   | `ucomisd` | | `66 0F 2E /r` | 66 0f 2e c1 |
   | `cvtsi2sd` | xmm,r64 | `F2 REX.W 0F 2A /r` | f2 49 0f 2a c2 |
   | `cvttsd2si` | r64,xmm | `F2 REX.W 0F 2C /r` | f2 4c 0f 2c d0 |

   REX only when an xmm index ≥ 8 (REX.R for reg / REX.B for rm); cvt* + movq always carry REX.W (64-bit GP side).

3. **`movabs` imm64 fold** (the gap R2a flagged): `MOV64 r64, #imm` used `C7 /0 id` (7 B) which **sign-extends a 32-bit immediate** — a value outside signed-imm32 `[-2^31, 2^31-1]` was silently truncated. Now those emit `movabs r64, imm64` = `REX.W B8+rd io` (10 B). **Byte-neutral** for every value that fits signed-imm32 (keeps the canonical C7 form the golden tests pin); only large constants (pointers, raw float payloads) — previously wrong bytes — take the new path.

4. **Mnemonic mapping**: `_lir_op_uppercase_x86` maps lowercase codegen mnemonics (`movq`/`movsd`/`addsd`/…/`cvttsd2si`) → uppercase encoder op-strings. Width-fixed (F2/66 0F opcode implies operand size) so no `is64` dispatch.

## Reference-match note (task-list vs actual codegen emit)
The task op-list named `movsd` but the codegen (`x86_64_linux.hexa` `__hx_payload_f*` / `__hx_to_double` / `f2i` / `i2f`) actually emits **`movq`** (14×) for the GP↔xmm payload ingress/egress, plus `addsd/subsd/mulsd/divsd` (via `_fop`), `comisd` (1×), `cvtsi2sd` (2×), `cvttsd2si` (1×). `movq` was the load-bearing omission — without it the whole float path still ENCODE-MISSes — so it was added as the critical piece; `movsd`/`ucomisd` added for completeness (canonical scalar move + unordered compare) though no codegen emitter uses them today (mem forms fall through to the loud ENCODE-MISS).

## Verification
- Byte-golden harness: `compiler/test/macho_p0_corpus/run_F_P2_X86_SSE.hexa` — 17 cases (incl. REX.R xmm8 extension + movabs 2^32 / -2^32 + the `#60` C7-neutral proof), each with hand-derived SDM expected bytes. Pure byte-check (no remote host).
- Neutrality: PR-CI byteeq 3-target (own-emit path is opt-in, shipping = C-transpile).

## round_next = ③-R2c
`ENCODE-MISS == 0` self-emit census on aiden — real float-corpus compile via `--backend=native --emit=obj`, cross-check the emitted `.o` against `objdump`/`as` on aiden (measurement gate the R2 census promised). This is where execution-level correctness (vs the internal-consistency byte-golden) gets proven.
