# N164 — RFC 071 P11 natural-loop matmul source-to-silicon re-validation

**Date:** 2026-05-22
**Verdict:** BLOCKED — N143 auto-synth matcher silent-wiped from origin/main.
**Falsifier:** F-RFC071-NVPTX-MATMUL-NATURAL-LOOP-SOURCE-TO-SILICON — NOT closed.

## TL;DR

The task premise — *"N143 is now restored on origin/main (matmul auto-synth
matcher present, verified count 19 in hir_to_mir.hexa)"* — is **FALSE**. The
"count 19" is the number of `matmul` string occurrences (the surviving N100
`gpu_matmul()` builtin path), **not** the natural-loop matcher. The actual
auto-synth matcher `_hir_is_nested_matmul_body` has grep count **0** on both
local HEAD and `origin/main`.

## Wipe diagnosis (measured, not inferred)

| commit | effect on `hir_to_mir.hexa` |
|---|---|
| `4c93b550` feat: nested-loop matmul auto-synth (N143) | **+382 L** — adds matcher |
| `e8c2dc1c` wip: dfflibmap sky130 reset-flop variants + compiler/stdlib follow-on | **−382 L** — wipes matcher (also −482 L from `mir_test.hexa`) |

`git merge-base --is-ancestor e8c2dc1c origin/main` → **YES**. So N143 was added,
then a later "wip" commit authored from a stale base re-flattened the file and
dropped it. This is the compiler-source variant of the documented
`feedback_runtime_c_deploy_regen_wipe` / `worktree_merge_silent_filedrop` hazard.

Wiped symbols: `_hir_has_gpu_kernel_annotation`, `_hir_param_name`,
`_hir_is_for_idx_let`, `_hir_is_for_it_let`, `_hir_is_desugared_for_block`,
`_hir_desugared_for_while_body`, `_hir_is_nested_matmul_body`,
`_hir_rhs_contains_mul_of_two_indexes`, `_synthesize_matmul_skeleton`, and the
`_lower_fn` auto-synth call-site + `mir_test.hexa` case (g).

## What IS intact (measured)

- **N128 NVPTX codegen**: `_nvptx_mfunc_is_matmul_shape` + all `_nvptx_emit_matmul_*`
  present (56 refs, 49 wmma refs in `compiler/codegen/nvptx_target.hexa`).
- **N100 `gpu_matmul()` builtin path**: callee dispatch survives at
  `hir_to_mir.hexa:1169`.

## Decisive measurement (the two-PTX contrast)

Both compiled from source through the SAME `_build_nvptx_emit_driver`
(`hexa build <src> --target=nvptx64-nvidia-cuda-sm80`):

| source | wmma | .reg .f64 | bra | verdict |
|---|---|---|---|---|
| **natural triple-loop** (`matmul_naive`, P11 fixture) | **0** | 22 | 12 | scalar loop — auto-synth did NOT fire |
| **`gpu_matmul()` builtin** (`matmul_kernel`, P10 fixture) | **4** | 0 | 2 | full WMMA — N128 path fires |

The kernel entry header `.visible .entry matmul_naive` IS emitted (generic
MIR-walk codegen), but the body is a literal f64-register scalar loop. The
builtin control proves everything downstream of HIR→MIR (codegen, ptxas-ready
WMMA emit) already works — the **only** missing piece is the N143 matcher.

## Exact failing predicate

`lower_hir(hmodule)` no longer rewrites the desugared triple-nested-for HIR into
the synthetic `STMT_LOAD + STMT_LOAD + STMT_BINOP("matmul") + STMT_STORE` MIR
skeleton (because `_hir_is_nested_matmul_body` + `_synthesize_matmul_skeleton`
+ the `_lower_fn` call-site are deleted). So `_nvptx_mfunc_is_matmul_shape(mfn)`
returns false for `matmul_naive`, and `codegen_emit_ptx_for_sm` falls through to
the generic scalar nested-while → PTX path.

## Exact source shape that parses (N143-accepted, ready for restoration)

```
@gpu_kernel
fn matmul_naive(a: [f16], b: [f16], c: [f32], M: i32, N: i32, K: i32) {
    for i in 0..M {
        for j in 0..N {
            var sum = 0.0          // UNTYPED — `var sum: f32 = 0.0` is rejected
            for k in 0..K {        // by the parser (N153: unexpected Colon)
                sum += a[i * K + k] * b[k * N + j]
            }
            c[i * N + j] = sum
        }
    }
}
```

Parse-gate: `OK ... parses cleanly` rc=0. This is exactly the form
`mir_test.hexa::_build_case_g` (from `4c93b550`) hand-builds, so the matcher will
accept it once restored.

## Why ubu-1 was NOT fired (@D g3 honesty)

Firing the scalar-loop PTX on ubu-1 would likely pass numerically — it's a
correct (slow) scalar matmul — but it would **not** exercise the natural-loop →
WMMA auto-synth path that this falsifier targets. A green PASS would be
misleading. The harness `host_matmul.c` (kernel name `matmul_naive`) is staged
and ready to fire the instant N143 is restored.

## Recommendation to parent

Restore N143 by cherry-picking the `hir_to_mir.hexa` + `mir_test.hexa` hunks of
commit `4c93b550` onto current `main` (re-add the 8 helper fns + `_lower_fn`
call-site + mir_test case g). Then re-emit THIS fixture: WMMA should appear, and
`host_matmul.c` fires on ubu-1 for the numeric ≤4 ULP closure. Everything
downstream of HIR→MIR is proven working by the builtin control this cycle.

## Artifacts

- `nvptx_p11_matmul_natural_test.hexa` — adjusted fixture (also at
  `compiler/codegen/nvptx_p11_matmul_natural_test.hexa`), parse-gate PASS.
- `matmul_naive.sm_80.NATURAL_NO_WMMA.ptx` — emitted scalar-loop PTX (failing evidence).
- `matmul_kernel.sm_80.BUILTIN_CONTROL_WMMA.ptx` — builtin control (N128 intact).
- `host_matmul.c` — ubu-1 fire harness (staged, not fired).
- `fire.log`, `result.json`.
