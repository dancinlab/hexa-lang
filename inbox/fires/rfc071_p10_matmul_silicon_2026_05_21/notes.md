# RFC 071 P10 — NVPTX source-to-silicon matmul fire (2026-05-22)

## Verdict
**BLOCKED** — F-RFC071-NVPTX-MATMUL-SOURCE-TO-SILICON-NUMERIC-EQ = FAIL.

## Root cause
N100 (gpu_matmul HIR→MIR synthesis) + N86 (NVPTX matmul codegen) are **not on main HEAD `85150013`**.

- N100 lives at orphan commit `fcb72487` (2026-05-21 23:54:00) — `compiler/lower/hir_to_mir.hexa` (+gpu_matmul intercept), `compiler/check/bind.hexa` (+name registration), `compiler/codegen/nvptx_p10_matmul_test.hexa` (+fixture).
- N86 lives at orphan commits `cff2ebc9` (2026-05-21 23:53:53) and `6b2b10c0` (22:58:59) — `compiler/codegen/nvptx_target.hexa` (+3 shape recognisers `_nvptx_mfunc_is_matmul{,_NT_a,_NT_b}_shape` + 3 emit-body fns).
- The only code commit that *did* land on main is the docs-only `ab81ea39` (GPU.md +2 lines). The code-bearing commits never reached main.
- The fixture file was then explicitly DELETED on main by `c39afbbe` (2026-05-22 00:02:39, "project.tape SSOT").

This is the same "deploy-regen wipe" / "worktree merge silent file-drop" pattern documented in memory (`feedback_runtime_c_deploy_regen_wipe`, `feedback_worktree_merge_silent_filedrop`).

## What the task assumed vs. reality
The task brief said *"N100 wired gpu_matmul builtin → HIR→MIR STMT_BINOP("matmul") synthesis (commit fcb72487)"* and *"N86 NVPTX matmul codegen restored on main (commit cff2ebc9)"* and *"Driver path should now work end-to-end."* All three assumptions are FALSIFIED on current main:

```
$ grep -c gpu_matmul compiler/lower/hir_to_mir.hexa compiler/check/bind.hexa  # → 0 0
$ grep -c _nvptx_mfunc_is_matmul compiler/codegen/nvptx_target.hexa            # → 0
$ ls compiler/codegen/nvptx_p10_matmul_test.hexa                               # → ENOENT
```

## What we executed end-to-end anyway (positive findings)
1. Restored fixture from `git show fcb72487:compiler/codegen/nvptx_p10_matmul_test.hexa` (test artifact, not compiler source).
2. `hexa parse compiler/codegen/nvptx_p10_matmul_test.hexa` → PASS.
3. Rebuilt driver: `hexa build self/main.hexa -o /tmp/hexa_n108_driver` → PASS in 7.8s. The driver-level NVPTX target-string dispatch on `self/main.hexa:1932-1941` IS wired on main; only the codegen body is wiped.
4. `/tmp/hexa_n108_driver build <fixture> --target=nvptx64-nvidia-cuda-sm80` → PASS (PTX written, phase tag `P3-PATH-B`).
5. `ptxas --gpu-name sm_80` → PASS, 4 regs, 400 B cmem[0], 0 stack.
6. ubu-2 RTX 5070 driver-JIT (sm_120, sm_80→sm_120 forward-compat) → cuModuleLoadDataEx PASS after correcting the JIT-opts shape to the canonical 5-opt pattern (per `inbox/fires/rfc067_pP_hexa_sgemm_ldmatrix_cpasync_2026_05_21/host.c`).
7. `cuLaunchKernel(matmul_kernel, grid=(4,4,1), block=(32,1,1))` → PASS, kernel completed.

## Why numeric-eq FAILED
The emitted PTX `matmul_kernel` body is functionally empty:

```ptx
.visible .entry matmul_kernel (...) {
    .reg .u32 %r3, %r4, %r5;
    .reg .f64 %fd6;
$L_0:
    ld.param.u32 %r3, [matmul_kernel_param_3];  // M
    ld.param.u32 %r4, [matmul_kernel_param_4];  // N
    ld.param.u32 %r5, [matmul_kernel_param_5];  // K
    // RFC 055 055-P0 - unsupported call: gpu_matmul
    ret;
}
```

The diagnostic comment `unsupported call: gpu_matmul` is precisely the codegen falling through to the generic STMT_CALL emit because neither (a) the HIR→MIR intercept synthesised STMT_BINOP("matmul") (N100 missing) nor (b) the codegen would recognise such a shape if it existed (N86 missing).

Result: all 4096 cells of c remain 0 (the cuMemsetD32 zero-init survives untouched). CPU reference is non-zero (LCG-fill product). `max_abs = 9.77`, `byte_mismatch = 4096/4096`.

## PTX substring audit (F-RFC071-NVPTX-MATMUL-EMIT-SUBSTRING)
- found: `.visible .entry matmul_kernel` (1/5)
- missing: `wmma.load.a`, `wmma.load.b`, `wmma.mma.sync.aligned.row.col.m16n16k16.f32.f16.f16.f32`, `wmma.store.d` (4/5)

## Falsifier honesty (@D g3)
The task's "honest scope" anticipated each branch I observed: "If PTX emit lacks substrings (N100's gpu_matmul synthesis lookup mismatch), document precisely." Done. The constraint `DO NOT touch compiler source — pure rebuild + fire cycle` correctly prevented me from sneaking in a cherry-pick to fake the closure.

## Artifacts in this dir
- `matmul_kernel.sm_80.ptx` — emitted PTX (sm_80, 791 B, 25 lines).
- `matmul_kernel.sm_120.ptx` — same emitter, sm_120 target (also fired, same body).
- `host_matmul.c` — silicon-fire harness (CUDA driver API, FP16-input FP32-acc matmul + CPU FP32 reference + 4-ULP gate).
- `fire.log` — captured stdout/stderr from ubu-2 fire.
- `result.json` — machine-readable verdict + metrics + wipe-chain.

## Remediation path (out of scope for this cycle)
1. Open recovery PR cherry-picking `cff2ebc9` (nvptx_target.hexa N86) + `fcb72487` (hir_to_mir + bind + fixture N100).
2. Or rewrite from scratch using the GPU.md §1f N86 spec + the WMMA m16n16k16 mnemonic table already on main (`compiler/codegen/nvptx_target.hexa:621, 1540, 1550, 1561`).
3. Re-fire this exact harness; expected outcome on closure: max_abs < 4 ULP × max_ref ≈ 4 × 1.2e-7 × max(|h_ref|) ~ 4e-6 absolute at M=N=K=64.
