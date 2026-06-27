# r2d — k3_arrmap address-gen strength reduction (HEXA_UNBOX_ARRAY_NATIVE)

Branch `perf/codegen-unbox-array-r2d` off `origin/main` (r2c #4080 already in main).
default-OFF, byteeq-safe firewall (all changes inside the `HEXA_UNBOX_ARRAY_NATIVE=1`
flag-gated arru emit path; OFF path byte-identical by construction).

## Goal / context

r2c landed native array element load/store (call-elimination + inline descriptor walk)
and measured **2.7×** vs gcc -O2 (roofline **26.9×**). The all-closure synthesis
(`project_hexa_runtime_gap_allclosure`) named the 26.9× → 2.7× residual the largest
remaining headroom. r2d pushes the per-statement layer to its clean ceiling and
captures, with numbers, exactly which residual components need out-of-scope
infrastructure.

## Diagnosis (measure-first, source + asm)

The r2c arru get/set emit (per `arr[i]` access) is, with the HexaArr LAYOUT
(`array_core.hexa:17` — payload word = HexaArr*; `{items*@0, len@8, cap@16}`; element
stride = sizeof(HexaVal) = **16**, tag@+0 payload@+8):

```
mov  r10, [rbp-X]        ; container payload reload   (SPILL ⓑ)
mov  rax, [rbp-Y]        ; idx payload reload         (SPILL ⓑ)
mov  r11, [r10+8]        ; len                        (BOUNDS ⓒ)
cmp  rax, r11            ; bounds                     (BOUNDS ⓒ)
jae  .Larru_slowN        ; OOB -> runtime             (BOUNDS ⓒ)
mov  r11, [r10+0]        ; items*
imul rax, rax, 16        ; idx * sizeof(HexaVal)=16   (ADDR-GEN — r2d target)
add  r11, rax            ; &items[idx]
mov  dst, [r11+8]        ; element payload @+8        (STRIDE-16 ⓐ)
... dst tag store + writeback (SPILL ⓑ)
```

gcc -O2 of the identical kernel: register-resident pointer walk (`mov (%rsi),%rax` …
`add $8,%rsi`), **stride-8** raw i64 (no tag eightbyte), **no bounds check** (induction
var provably in range), `2*a+1` folded to `lea`, no per-access reloads.

The honest 2.7× residual decomposes into:
- **ⓐ stride-16 HexaVal element traffic** — items[] stores full 16B HexaVal; gcc stores
  raw 8B i64. 2× element memory traffic.
- **ⓑ per-iteration spill reload** — container/idx reloaded from stack each access, dst
  spilled back (no cross-statement register allocation in the boxed model).
- **ⓒ kept bounds-check** — cmp+jae per access (r2c deliberately kept it).
- **addr-gen `imul rax,16`** — 3-cycle imul on the address dependency chain.

## Lever feasibility (reference-matched)

| lever | what | feasible byteeq-safe here? |
|-------|------|----------------------------|
| ⓐ unboxed-element pack | items[] 16B HexaVal → packed 8B i64/i32 | **NO** — broad runtime layout: `hexa_index_get/set`, push, grow, and EVERY array consumer assume 16B HexaVal elements; the boxed slow-path co-resident in the same array would read 8B-packed wrong. = a parallel typed-array representation (the `farr` path), not a per-statement codegen tweak. OUT of scope. |
| ② bounds-check elision | drop cmp+jae when idx provably in `[0,len)` | **NO at this layer** — needs induction-variable range analysis. MIR has `Block{preds,succs}` so loops are *recoverable*, but there is **no loop-opt infra** (grep: no induction/LICM/invariant/backedge analysis) and the per-statement codegen has no loop context wired. = a new MIR analysis pass, high silent-OOB-miscompile risk. Separate round. |
| ③ container base reg-hoist | keep base/items*/len in a reg across the loop | **NO at this layer** — needs cross-statement register allocation / LICM. The boxed model's defining property is *no cross-op register allocation* (every value lives in a stack slot; r10/r11/rax freely clobbered per statement). = the same loop-opt/regalloc infra as ②. |
| **r2d: imul→shl** | `imul rax,16` → `shl rax,4` (2^k stride) | **YES** — bit-exact (×16 == <<4), gcc -O2 reference-matched (gcc scales 2^k strides with shl/lea, never imul), flag-gated (OFF byte-identical), reuses the proven `_x86_instr2("shl",reg,imm)` form already shipped by the merged magic-division path (`shr rax,63`/`sar rdx,sh`). 3c→1c on the addr-gen dependency chain. |

SIB-folded addressing (`mov dst,[r11+rax*8+8]`) was considered but `_x86_op_mem(base,offset)`
supports only base+disp (no index*scale); adding a SIB operand form touches the asm + ELF
operand renderers (broader, риск) — deferred.

## Change

`compiler/codegen/x86_64_linux.hexa` — `_x86_emit_arru_get` + `_x86_emit_arru_set`:
`imul rax, rax, 16` → `shl rax, 4`. Comment headers updated. No new builtin/@attr/keyword
(frozen blob 151c52c8 safe). ~6 effective LOC.

## Gates (state/unbox-native-r2d/measure_r2d.sh — OOM-safe sequential single-aprime)

- **Gate1** OFF byteeq: patched-OFF .text == baseline-OFF .text (3-target lands via CI).
- **Gate2** lever fired: patched ON asm has `shl …,4`, no `imul …16`; baseline ON has imul.
- **Gate3a** native/boxed = patched ON/OFF (reproduce r2c ~0.37 = 2.7×).
- **Gate3b** LEVER = patched ON / baseline ON (shl vs imul; <1.0 = r2d win over r2c).
- **Gate3c** roofline = patched ON / gcc -O2 (the residual gap).
- **Gate4** parity: patched ON == OFF == baseline ON (i64 bit-exact).
- **DISASM** inner-loop component compare hexa-ON vs gcc -O2.

## Honest expectation

The kernel is load-bound (5 loads/access, 64KB L2-resident array). imul→shl shaves
latency only on the addr-gen dependency chain, so the measured Gate3b delta is expected
**small** (possibly within median-5 noise). That is the honest per-statement-layer
ceiling: the bulk of the 2.7× residual (ⓐ stride-16 + ⓑ no-regalloc reloads) is
architectural and needs the packed-typed-array runtime representation (ⓐ) or a loop
optimizer / register allocator (ⓑⓒ) — neither a byteeq-safe per-statement tweak. r2d
captures that wall with numbers rather than asserting it.

Build/measure = aiden (mini = git/gh only). Verdict + ratios harvested to
`~/r2d_RESULT.txt`. NO self-merge (coordinator decides).
