# codegen-quality probe — hexa native-emit vs gcc -O2

**Question:** does hexa's no-LLVM native-emit produce code as fast as the equivalent C
compiled with `gcc -O2`?
**Verdict: NO — not parity.** Measured gap **2.9×–23×** slower (geomean ≈ **8.6×**) on
general scalar/integer/array kernels. **Codegen campaign JUSTIFIED.**

- host: aiden (Zen4 B650M, x86_64-linux), hexa v0.315.0, gcc 13.3.0
- hexa native path: `aprime_cc _drv.hexa --emit=obj --target=x86_64-linux-gnu`
  (with `HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1`) → linked with gcc-as-linker
  (kernel machine code is 100% aprime native-emit; gcc only supplies crt/libc/libgcc).
  This is the **real shipped native-emit codegen** — confirmed by disassembling the binary.
- C path: `gcc -O2`.
- metric: CPU User+Sys seconds, **median-of-5**, `taskset -c 3` pinned, **output-parity-gated**
  (every kernel's hexa output == C output, all PARITY=OK).
- CPU-only `runtime.a.cpubak` used for linking — aiden's default `runtime.a` is CUDA-linked
  (undefined `cudaMalloc`/`__popcountdi2` under bare `ld`); this is a packaging note, not a
  codegen factor (kernel code identical either way).

## Results (lower ratio = closer to gcc)

| kernel | what | hexa s | gcc -O2 s | ratio | parity |
|--------|------|-------:|----------:|------:|:------:|
| k1_sum     | scalar reduce `(s+i*1009)%M`, N=2e8        | 1.26 | 0.44 |  **2.86×** | OK |
| k2_collatz | branchy int (collatz steps 1..3e6)         | 4.26 | 0.34 | **12.53×** | OK |
| k3_arrmap  | array in-place map, 2000 passes × 1e5       | 3.02 | 0.13 | **23.23×** | OK |
| k4_branch  | branch-heavy modulo accumulate, N=1e8       | 1.91 | 0.15 | **12.73×** | OK |
| k5_fncall  | small fn called N=1e8 times                 | 0.97 | 0.22 |  **4.41×** | OK |

geomean ratio ≈ 8.6×. hexa is slower on **every** kernel; no kernel reached parity (±10%).

## Root cause (assembly-level, reference = gcc -O2 output)

hexa native-emit uses a **boxed `HexaVal` tag-dispatch model**: every scalar operation is a
**runtime function call**, with the value's type tag carried in a stack slot, no cross-op
register allocation, no unboxed `i64`, and no loop optimization. `HEXA_INLINE_INT_BOX=1` did
**NOT** change this (still 5–7 calls/iter — flag is a no-op in this build's obj path).

Per-iteration hexa loop body is a chain of leaf calls:
`hexa_cmp_lt` (loop test), `hexa_mul`, `hexa_add_slow`, `hexa_mod`, plus
`hexa_index_get`/`hexa_index_set` for array access. (Absolute times are modest only because
these are tiny, perfectly branch-predicted leaf calls ~5–6 cyc each — but it is still
~25–50 cyc/iter of pure dispatch overhead that gcc does not pay.)

**Biggest gap — k3_arrmap (23×), first divergence = array element access + modulo:**
- HEXA inner loop = **7 boxed runtime calls per element**:
  `hexa_cmp_lt → hexa_index_get → hexa_mul → hexa_add_slow → hexa_mod → hexa_index_set → hexa_add_slow`.
  Each `hexa_index_get/set` is a call doing bounds-check + tag unbox/box; each arith op is a call.
- GCC -O2 inner loop = **0 calls**: element kept in a register via raw pointer-walk
  (`mov (%rsi),%rax` … `mov %rcx,-0x8(%rsi)`, `add $0x8,%rsi`), `2*a+1` folded into
  `lea 0x1(%rax,%rax,1)`, and `%1000000007` strength-reduced to a magic-reciprocal
  `imul $0x89705f3112a28fe5` (no idiv). ~10 register instructions, no bounds checks.

So the gap is **not** algorithmic — identical work — it is purely
boxing + call-per-op + missing register allocation + missing loop strength-reduction/
magic-division on the hexa side.

Why the spread (2.9× → 23×): the gap widens exactly where gcc's optimizer wins most —
bounds-check elimination + register-resident pointer walks (arrays, k3) and tight modulo
loops (k2/k4). k1_sum is "only" 2.9× because even gcc still pays a magic-multiply per iter,
narrowing the relative margin.

## Scope / honesty caveats

- This measures hexa's **general dynamically-typed scalar/array codegen** — the idiomatic
  `let mut s = 0` path. It is the boxed `HexaVal` path.
- hexa's **hand-tuned numeric kernels are separate and already competitive**: `farr` float
  arrays + GEMM reach BLIS/cuBLAS parity (per CLAUDE.md / memory) via a dedicated *unboxed*
  intrinsic path. That path is not what general user code lowers through; this probe shows the
  general path has a large, real codegen gap.

## Campaign justification & lever

**JUSTIFIED.** The single highest-value codegen lever:
**static-type-inference-driven unboxing** of scalar/array locals whose type is statically
known (the overwhelming majority of hot loops). Concretely:
1. infer `i64`/`f64` for monomorphic locals → keep payload in registers, drop the tag-slot
   stores/reloads;
2. lower `+ - * / % < ==` on inferred-int operands to inline `add/imul/idiv/cmp` (or
   magic-multiply for constant modulus/division) instead of `call hexa_*`;
3. lower `a[i]` on a known native array to a register pointer-walk with hoisted/elided bounds
   checks instead of `call hexa_index_get/set`.

The unboxed numeric machinery already exists for `farr`; extending tag-inference + unboxed
lowering to general scalar/integer loops should close most of the 3–23× (the work is
identical — only boxing/calling-convention differs). Expected biggest win on array + tight
modulo loops (k2/k3/k4).

— raw self-harvest: `aiden:~/codegen_probe_RESULT.txt` (reboot-proof, includes full disasm).

---

## RE-BASELINE (2026-06-27) — component attribution from the REAL native asm

**Why re-baseline:** the earlier `codegen-quality-probe-verdict` prose predicted boxed call-sites
(`hexa_truthy`, `hexa_index_get`, …) but a separate per-op unboxing probe found some predicted
calls **absent from the actual native asm** of a given kernel (e.g. `k4_branch` `hexa_truthy`=0).
So we re-disassembled the **real shipped aprime native-emit asm** of all 5 probe kernels and did
an *actual* call + spill/reload census, attributing each gap to its dominant component. Measure
only, no code change. Host aiden (origin/main sha `faf2dd8d`, aprime_cc fresh build, CPU
`runtime.a` 1.0MB), median-of-5 `taskset -c 3`, output-parity-gated. Raw:
`aiden:~/rebaseline_RESULT.txt` + `~/rebaseline_SPILL.txt`.

### Method note — aprime emits **Intel-syntax** (`mov [rbp-N], reg`)
The native backend emits `.intel_syntax noprefix`. The first spill census (AT&T regex
`-N(%rbp)`) returned **0 spills — a false negative**; corrected against the actual Intel form
`mov [rbp - N], reg` (store) / `mov reg, [rbp - N]` (reload) the spill traffic is large. Every
boxed `HexaVal` value carries an explicit **tag-slot** store/reload (`# store tag L4` /
`# … from tag-slot`). gcc `-S` reference is AT&T (counted separately).

### Re-measured ratios (consistent with the original probe)
| kernel | hexa s | gcc s | ratio | parity |
|--------|-------:|------:|------:|:------:|
| k1_sum     | 1.51 | 0.45 |  **3.36×** | OK |
| k2_collatz | 6.13 | 0.46 | **13.33×** | OK |
| k3_arrmap  | 3.49 | 0.13 | **26.85×** | OK |
| k4_branch  | 1.10 | 0.04 | **27.50×** | OK |
| k5_fncall  | 1.02 | 0.22 |  **4.64×** | OK |

(k4 is higher than the original 12.7× because this re-baseline k4 is a purer 3-way `i%3 / i%5`
branch-modulo loop; the gap *direction* and dominant component are unchanged.)

### Component census — actual native asm (per kernel)
`call hexa_*` = boxing/tag-dispatch runtime calls; `tag-slot` = 16B `{tag,payload}` store+reload;
`idiv/imul` = division-strength-reduction signal. gcc reference is fully register-resident
(**stack-store = stack-reload = 0** on every kernel).

| kernel | hexa boxed `call hexa_*` (whole-fn) | tag-slot store / reload (whole-fn) | hot-bb per-iter: calls / store / reload | hexa idiv / imul | gcc -O2: call / store / reload / imul |
|--------|:---:|:---:|:---:|:---:|:---:|
| **k1_sum**     | 5 (`cmp_lt,mul,add_slow×2,mod`)                       | 12 / 12 | 4 / 10 / 14 | 0 / 0 | 1 / 0 / 0 / 2 |
| **k2_collatz** | 10 (`cmp_lt,eq×2,truthy,mul,add_slow×4,mod,div`)      | 21 / 20 | 2 / 2 / 3¹ | 0 / 0 | 1 / 0 / 0 / 0 |
| **k3_arrmap**  | 17 (`index_get×2,index_set,mul,add_slow×6,mod×2,cmp_lt×4,array_new/push`) | 32 / 36 | 6 / 13 / 23 | 0 / 0 | 2 / 0 / 0 / 4 |
| **k4_branch**  | 8 (`cmp_lt,eq×2,sub,add_slow×3,mod×2`)                | 17 / 18 | 2 / 3 / 3¹ | 0 / 0 | 1 / 0 / 0 / 2 |
| **k5_fncall**  | 6 (`cmp_lt,mul,add_slow×3,mod`) + cross-fn call       | 14 / 14 | 3 / 9 / 11 | 0 / 0 | 1 / 0 / 0 / 2 |

¹ k2/k4 hot-bb count undercounts per-iteration because their loop body is **split across several
basic blocks** by the `if`/`while` branch (the densest single bb shows 2 calls; whole-fn totals
above capture the real per-iteration load). k1/k3/k5 have a single straight-line body bb.

### DOMINANT-COMPONENT verdict (per kernel, from the counts above)
The hot-loop disasm shows boxing call and spill are **the same cost, not two levers**: every
boxed call result is *immediately spilled to a 16B tag slot then reloaded as the next call's
arg* — e.g. k3 inner loop literally is
`call hexa_index_get → mov %rax,-0x148(%rbp) → mov -0x148(%rbp),%rdi → call hexa_mul →
mov %rax,-0x150(%rbp) → mov -0x150(%rbp),%rdi → call hexa_add_slow → …`. The spill/reload IS the
boxed calling convention's argument plumbing.

| kernel | gap | **dominant component** | secondary | ⓒ strength-reduction? |
|--------|----:|------------------------|-----------|------------------------|
| **k1_sum**     |  3.4× | **ⓐ per-op boxing call** (5 calls/iter, all arith boxed) — incl. `% M` still `call hexa_mod` | ⓑ tag-slot spill (10st/14rl) coupled to the calls | only ⓒ residual: gcc magic-`imul ×2`, hexa idiv=0 but `mod` is a *call* not idiv → the boxed-call subsumes it |
| **k2_collatz** | 13.3× | **ⓐ per-op boxing call** (10 boxed/iter incl. `eq, truthy, div, mod`) | ⓑ spill (21/20) coupled; branch-split | div/mod are boxed calls (`hexa_div`/`hexa_mod`), not idiv — ⓒ folded into ⓐ |
| **k3_arrmap**  | 26.9× | **ⓐ per-op boxing call** — `hexa_index_get/set` (array access is a CALL w/ bounds-check+box) + 6×`add_slow`+`mul`+`mod` | ⓑ spill **heaviest** here (13st/23rl per iter, 75 reloads whole-fn) — value chained slot→slot between every call | gcc strength-reduces `%M` to magic-`imul ×4` + raw pointer-walk; hexa pays neither |
| **k4_branch**  | 27.5× | **ⓐ per-op boxing call** (`eq, mod×2, add_slow×3, sub, cmp_lt`) | ⓑ spill (17/18) coupled + branch mispredict on boxed bool | `% 3`/`% 5` are `hexa_mod` calls; gcc uses magic-`imul ×2` |
| **k5_fncall**  |  4.6× | **ⓐ per-op boxing call** + boxed cross-fn call (HexaVal arg/ret ABI) | ⓑ spill (9st/11rl) — args/ret marshalled through slots | `%M` boxed call; gcc inlines `f` + magic-`imul` |

**Headline: ⓐ per-op boxing (`call hexa_*` with tag-dispatch) is the DOMINANT component of ALL
5 kernels.** ⓑ spill/reload is real and large (k3 worst at 75 whole-fn reloads) but is **not an
independent reg-alloc problem** — it is the boxed calling convention's own arg/result plumbing
(spill-before-call, reload-after-call). ⓒ strength-reduction (magic-division) is **not even
reachable** on the hexa side: there is **no `idiv` to strength-reduce** — `%`/`/` are *boxed
calls* (`hexa_mod`/`hexa_div`), so magic-reciprocal only becomes relevant *after* unboxing
lowers `%`/`/` to a native `idiv` in the first place.

### What this grounds for the reg-alloc decision
- A **standalone linear-scan reg-allocator** (keeping `{tag,payload}` in registers across ops
  *without* unboxing) would remove the ⓑ spill traffic but **leave every `call hexa_*` in place**
  — the calls still need their args in `rdi/rsi/rdx`, and the boxed dispatch still runs. Estimated
  ceiling: it closes the *spill* fraction only, **not the call fraction**, which is dominant.
  Spill and call are coupled, so reg-alloc-without-unboxing buys a fraction of one already-second
  component.
- **Unboxing (the R5 mechanism) closes ⓐ AND ⓑ together**: when `+ - * < ==` lower to inline
  `add/imul/cmp` on GPRs (R5, already PROVEN release-safe), the value *stays in a register*, so
  the spill-before-call / reload-after-call plumbing **disappears with the call**. The census
  shows the two costs are one — so unboxing is strictly the higher-leverage lever, and a separate
  reg-alloc pass is **not** the dominant-component closer for any of the 5 kernels.
- **Priority order grounded by counts:** (1) **scalar BinOp unbox** (R5, done OFF-safe) — kills
  the `add_slow/mul/cmp/sub/eq` calls + their slots, dominant in k1/k4/k5; (2) **array-element
  unbox** (r2) — kills `hexa_index_get/set` + the heaviest spill chain, dominant in k3 (26.9×);
  (3) **`%`/`/` unbox → idiv → magic-reciprocal** (r4) — *only here* does ⓒ become relevant, and
  only after `mod`/`div` are native; needed for the still-`%`-bound k1/k2/k4 tails. A dedicated
  linear-scan reg-alloc is a **distant 4th** — it addresses only the coupled spill fraction that
  unboxing already removes for free.
