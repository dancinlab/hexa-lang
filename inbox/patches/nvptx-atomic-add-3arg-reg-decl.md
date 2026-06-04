# nvptx gpu_atomic_add(base, idx, val) — address temp `%rd_idxs_addr` not declared

**Surfaced by**: QFORGE M35 2D α²F BZ-sum kernel (`qforge_a2f_bzsum2d`).

## Symptom (ptxas 12.4, sm_90 PTX → sm_120 JIT)

A kernel using the 3-arg atomic form `let _old = gpu_atomic_add(a2f, j, acc)`
emits, in `compiler/codegen/nvptx_target.hexa` (the `s.op == "gpu_atomic_add"
&& len(s.args) >= 3` arm, ~line 1236):

```ptx
    mul.lo.s64 %rd_idxs_addr, %rd26, 8;        // atomic_add byte off = idx * 8
    add.s64    %rd_idxs_addr, %rd_idxs_addr, %rd6;
    atom.global.add.f64 %fd110, [%rd_idxs_addr], %fd62;
```

but `%rd_idxs_addr` is **never declared** with a `.reg .u64 %rd_idxs_addr;`
directive in the function's register-declaration block. ptxas rejects:

```
error : Unknown symbol '%rd_idxs_addr'
error : Arguments mismatch for instruction 'mul.lo'
error : Illegal operand type to instruction 'atom'
```

## Root cause

The 3-arg atomic-add lowering reuses a FIXED register name `%rd_idxs_addr` for
the computed address (same name the IndexSet/store path uses) but does NOT add
it to the `.reg` declaration set the way the IndexSet store path does. The
store path (`st.global.f64 [%rd_idxs_addr], ...`) works because IT declares the
reg; the atomic path borrows the name without the declaration.

## Fix

In the `gpu_atomic_add` 3-arg arm, either (a) emit a fresh SSA-numbered reg
(e.g. `%rd_atom_addr_<dst.id>`) and add it to the declared set, or (b) ensure
`%rd_idxs_addr` is unconditionally declared whenever any atomic/index-set path
is taken. The store path already declares it; mirror that declaration in the
atomic arm. (The 1-arg `gpu_atomic_add(addr, v)` form is unaffected — it takes a
pre-computed address.)

## Workaround in place (measurement only)

A 1-line `.reg .u64 %rd_idxs_addr;` inserted into the emitted PTX
(`build_m35/k2d_patched.ptx`) makes it ptxas-clean; the 2D kernel then JITs and
runs correctly (parity rel ≤ 1e-5, 27–42× CPU speedup). The kernel SOURCE
(`stdlib/qforge/nvptx_a2f_kernel2d.hexa`) is correct — only the codegen
declaration is missing.
