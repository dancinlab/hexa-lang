# runtime-gap r6 — immutable let-bound-literal const-prop (closes `% M` named-const)

## Wall being broken (r5b honest residual)

R5b (#4055) closed `%`/`/` by a COMPILE-TIME **literal** divisor (`% 1000000007`) via
gcc's signed magic-reciprocal. Its own measure (state/unbox-native-r5/r5b_RESULT.txt)
recorded the residual:

```
[k1] on: hexa_mod=1 ...                         # k1 = `% M`, M = let M=1000000007
Gate6: ⚠ magic constant NOT found in ON k1 asm  # `% M` stayed a call hexa_mod
[k4] on: hexa_mod=0 ...                          # k4 = `% 3`,`% 5` literals → magic fired
```

k1's `% M` divisor is a **named local** (`let M = 1000000007`), not a `const_int`
operand, so the r5b gate `_x86_binop_div_const_ok` short-circuited on
`s.args[1].kind != "const_int"` → `% M` stayed boxed (`call hexa_mod`). k1's 2.35×
in r5b came only from R1 unboxing the `s + i*1009` arith (hexa_add/mul/cmp → 0); the
`%` itself was still a runtime call.

## Where const-prop was broken

`let M = 1000000007` lowers (compiler/lower/hir_to_mir.hexa:1608) to
`STMT_ASSIGN op="let" dst=M args=[const_int 1000000007]`. The optimizer does NOT
copy-prop it into the use site: `compiler/optimize/const_fold.hexa:86` only folds a
binop when **both** operands are already `const_int` — a `local` divisor is never
folded, and there is no copy-prop pass. So at codegen the `% M` binop carries
`args[1].kind == "local"` (id 0 = M), and the r5b literal-only gate missed it.

## Fix — SCCP-style single-assignment int-literal copy-prop (default-OFF, byte-neutral)

Reference: gcc/LLVM **SCCP** (sparse conditional constant propagation) / copy-prop of
an immutable single-assignment binding. Restricted to compile-time int literals;
reassigned `var`/`let mut` excluded (soundness).

`compiler/codegen/x86_64_linux.hexa`:

1. **const lattice** in `X86RegMap` (`local_const_ok`/`local_const_val`), built in
   `_x86_64_assign_regs` ONLY when `_unbox_native_enabled()` (same firewall as the r5
   `local_type` array → OFF leaves both `[]`, never consulted → byte-eq NEUTRAL).
   Two passes over `mf.blocks`:
   - pass 1: `wcount[id]` = # statements whose `dst.id == id`.
   - pass 2: record `(ok=1, val)` for an id with `wcount==1` whose single writer is
     `STMT_ASSIGN op="let" args=[const_int]`. **SOUNDNESS**: a reassigned `let mut`
     gets a 2nd dst-write (`op="assign"`, hir_to_mir in-place mutation) → `wcount>1`
     → excluded. `_miss_local()` sentinel dsts (id<0) never index the arrays.

2. **operand helpers** `_x86_operand_is_const_int` / `_x86_operand_const_int_val`:
   true/value for a `const_int` literal OR a `local` proven const by the lattice.

3. **gate + emit** `_x86_binop_div_const_ok` and the magicdiv emit now use the
   helpers for the divisor → the r5b magic-reciprocal helper (`_x86_magic_M/shift`)
   fires UNMODIFIED for `% M`. The divisor value `d` is identical to the literal
   case, so M + shift are byte-for-byte gcc/clang -O2's (0x89705F3112A28FE5, sar 29
   for d=1000000007), exactly as r5b already validated.

No new builtin / `@attr` / keyword; frozen blob 151c52c8 untouched. Gate is the
existing `HEXA_UNBOX_NATIVE=1` (r1/r5b reuse, default-OFF).

## Gates (aiden, foreground)

1. OFF byteeq gen-equivalent: patched flag-OFF `.o` == origin/main baseline `.o`
   (same cwd, DWARF comp-dir avoidance). BLOCKING.
2. Lever: k1 ON `hexa_mod` count **0** (was 1 in r5b) + magic `movabs` constant
   present in k1 ON asm (== gcc `0x89705F3112A28FE5`).
3. Ratio: taskset median-5, k1 ON/OFF below the r5b 0.426 baseline (`% M` call gone).
4. Parity: k1 output OFF == ON, bit-identical. Soundness kernel k5 (`let mut D`
   reassigned divisor) MUST stay boxed (hexa_mod>0, no magic) AND parity-correct.
5. Smoke: hexa --version + hello + exit42 under the flag.

## Verdict — GO (measured, summer, x86_64-linux; full RESULT in ./RESULT.txt)

SRC=c55cf81d BASE=622d1b6f. Patched aprime_cc build 1:03.74 (compiles clean).

- Gate1 OFF byteeq (BLOCKING) = PASS — k1/k4/k5 patched-flag-OFF .o == origin/main
  baseline .o, same cwd (k1 sha e48ff9cb, k4 daef1550, k5 bd07b31a). OFF byte-eq NEUTRAL.
- Gate2 lever — k1 ON hexa_mod 1->0 (was 1 in r5b) + magic_const 0->1. const-prop FIRED.
- Gate6 magic ref-match — ON k1 carries movabs 0x89705f3112a28fe5 (-8543223828751151131)
  + sar 29 (0x1d) + imul ...,1000000007 — byte-identical to gcc/clang -O2 for % 1000000007
  (M = let M=1000000007 = L0, const-prop'd into the magicdiv).
- Gate3 ratio = k1 ON/OFF 0.338 (1.30->0.44 s, ~2.95x) — BELOW the r5b 0.426 baseline
  (residual call hexa_mod gone). k4 0.241; k5 0.436.
- Gate4 parity (BLOCKING) = OK — k1 840001701 OFF==ON; k4 -66666664; k5 1.
- SOUNDNESS (k5 = let mut D reassigned divisor) = correctly EXCLUDED — k5 ON hexa_mod=1
  (stays BOXED), magic_const=0, parity OK. dst-count>1 firewall drops reassigned divisors.
- Gate5 smoke = hello rc=0, exit42 rc=42 (HEXA_UNBOX_NATIVE=1).

-> GO (PR merge candidate). x86_64-only change (compiler/codegen/x86_64_linux.hexa);
arm64/darwin codegen untouched -> byte-eq by construction. Coordinator merge gate =
full 3-target byteeq + ship smoke. Default-OFF (HEXA_UNBOX_NATIVE), release-safe.
