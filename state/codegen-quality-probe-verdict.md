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
