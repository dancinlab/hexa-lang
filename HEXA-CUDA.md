@title: 🟩 HEXA-CUDA — "just write CUDA in hexa" cookbook

@goal: A user-facing cookbook for writing hand-authored GPU kernels directly
in `.hexa` via the `@gpu_kernel` → NVPTX path (RFC 055 / gpu/SPEC.md),
contrasted with the auto-fusion flame/forge path. Grounded in the REAL
intrinsic/launch surface the compiler supports today — honest gaps marked.

## milestones

- [x] D0 — surface inventory: honest "what device intrinsics / launch forms
      hexa supports TODAY" matrix (thread/block/grid index, barrier, atomics,
      warp shuffle, WMMA, shared mem, gpu_launch). DONE — see the matrix in
      docs/hexa-cuda-cookbook.md §3 and the summary in HEXA-CUDA.log.md.
- [x] D4 — cookbook authored at docs/hexa-cuda-cookbook.md with runnable
      example kernels using ONLY verified-real syntax: vector-add, SAXPY,
      parallel reduction, tiled matmul. DONE (build-verified: pending — see D1).
- [x] D1(a) — DONE (un-gate landed, branch domain/hexa-cuda-nvptx-ungate):
      `hexa build --target=nvptx…` driver was GATED in the bootstrap binary
      (`_build_nvptx_emit_driver` at self/main.hexa:2404 returned 1 with
      `[nvptx] GATED RFC071-P3-PathB`). The gate reason ("compiler bodies NOT
      linked / 6 undefined symbols") was STALE — self/main.hexa already
      imports all 7 pipeline modules (lines 10-16), so `codegen_emit_ptx_for_sm`
      + lex/parse/lower/lower_hir/static_atlas were already in scope. Replaced
      the gate body with the inline lex→parse→lower→lower_hir→
      codegen_emit_ptx_for_sm pipeline (1:1 mirror of the verified spec sibling
      compiler/cli/build_nvptx.hexa). +50/-6, single file, OFF-safe (reached
      only from the nvptx dispatch branch; default build byte-identical).
      Verdict: .verdicts/hexa-cuda/F-HEXACUDA-NVPTX-UNGATE.txt (GREEN).
- [ ] D1(b/c/d) — remaining gaps found during D0, filed as follow-on work:
      (b) `gpu_shared_f64` / `gpu_shared_add` / `gpu_shared_get` used by the
          qforge `@phase("parse_only")` reference kernels are NOT real codegen
          intrinsics — the real shared-memory form is `@shared let t: [f64; N]`
          (gpu/SPEC.md §6). Cookbook uses the real form; flagged the divergence.
      (c) `gpu_tf32_round` (qforge mixprec kernel) is likewise not a codegen
          intrinsic — TF32 is host-side cuBLAS in that harness, not device PTX.
      (d) FP64 `exp()` intrinsic underflow bug below x≈−745 (qforge a2f d6 note)
          — kernel-side guard documented; codegen fix is a separate inbox item.
- [x] D2 — DONE (driver un-gated, emit verified). `hexa build --target=nvptx`
      now emits SOURCE-DERIVED PTX end-to-end: the cookbook vec-add @gpu_kernel
      compiles to a 59-line PTX with `.visible .entry vec_add` (source kernel
      name, not the hand-MIR `vadd` fallback), `.target sm_90`, `.version 7.8`,
      4× `.param .u64`, and real index-math + bounds-check + ld/st.global.f64
      + ret. Verified via a standalone harness running the IDENTICAL inline
      pipeline (the stale local Jun-1 hexa hangs flattening full self/main.hexa
      on macOS, so the live `hexa build` path is re-verified on a fresh
      bootstrap / CUDA host). ptxas-clean + device run = PENDING (no local
      ptxas/CUDA toolkit; codegen is the RFC 055 §7 RTX-5070-validated entry).
      Per-example "build-verified" tags: vec-add CONFIRMED (emit); SAXPY /
      reduce / matmul re-emit + ptxas on a CUDA host = deferred follow-up.

## adoption — steer devs to `.hexa` GPU kernels over py/.cu (the funnel)

Capability exists (D0-D4); ADOPTION = remove every reason a dev falls back to
py/.cu: "blank page" · "porting effort" · "don't see the hexa path" · "editor
doesn't help". Levers D6-D9 attack each. (Branch domain/hexa-cuda-adoption-dx;
verdict .verdicts/hexa-cuda/F-HEXACUDA-ADOPTION-DX.txt.)

- [x] D6 — scaffolding: `hexa new gpu-kernel <name>` one-command @gpu_kernel
      skeleton (cmd_new + _new_gpu_kernel_template in self/main.hexa; `new`
      dispatch branch + top-level catalog + core_commands() SSOT row). Emits a
      minimal *compiling* vec-add kernel (REAL intrinsics) + host launch shape +
      build hint. Generated kernel output parse-checks clean. WIRED into the CLI
      (build-verify of the full self/main.hexa self-build pending — stale local
      oracle hangs flattening main.hexa).
- [x] D7 — porting guide: docs/hexa-cuda-porting-guide.md — line-by-line
      `.cu → .hexa` for vec-add / SAXPY / parallel reduction / tiled matmul +
      the full CUDA→hexa intrinsic mapping table (threadIdx.x→gpu_thread_id_x,
      __syncthreads→gpu_barrier, __shared__→@shared let, atomicAdd→gpu_atomic_add,
      __shfl_*→gpu_warp_shuffle_*, wmma→gpu_wmma_*, <<<>>>→gpu_launch) +
      10-step translation checklist. Cross-linked both ways with the cookbook.
- [x] D8 — nudge-lint: tool/lint_cu_nudge.hexa — report-only, NEVER-blocking
      advisory (exits 0) that scans for hand-written `.cu` + nvcc build steps and
      emits "this can be a @gpu_kernel — see the cookbook". Nudge fires correctly
      on a fixture. STANDALONE tool + documented integration points (pre-commit /
      build wrapper / future in-compiler .cu-FFI hook behind HEXA_CU_NUDGE=1) —
      NOT wired into `hexa build` (no user-facing .cu FFI/link path exists in the
      compiler today to hook; the advisory() string is the canonical message
      when one lands).
- [x] D9 — LSP/DX: self/lsp.hexa extended with @gpu_kernel intrinsic completion +
      hover for the 29 gpu/SPEC.md §5 intrinsics (get_gpu_intrinsics SSOT →
      handle_completion + handle_hover + all_global_names; gpu_intrinsics_export
      + `hexa-lsp gpu-intrinsics` CLI verb). Machine-readable artifact checked in
      at gpu/gpu_intrinsics.lsp.json (29 items, validated). self/lsp.hexa
      parse-checks clean; in-tree bin/hexa-lsp rebuild build-verify pending (fresh
      worktree lacks the bootstrap self/native/hexat artifact).
