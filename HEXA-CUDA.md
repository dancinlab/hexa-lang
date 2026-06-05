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
- [x] D2 — DONE + SILICON-VALIDATED on a real H100 (sm_90). `hexa build
      --target=nvptx` emits SOURCE-DERIVED PTX end-to-end (`.visible .entry
      vec_add`/`saxpy`, `.target sm_90`, `.version 7.8`, 4× `.param .u64`, real
      index-math + bounds-check + ld/st.global.f64 + ret). Both cookbook
      vec-add AND SAXPY @gpu_kernel were re-emitted by a FRESH self-host-built
      `hexa` (`tool/release_build`, Stage 0/1/2) on an H100 80GB HBM3 pod, then:
        · `ptxas -arch=sm_90` → exit 0, EMPTY stderr (CLEAN) — both kernels.
        · device run via the CUDA Driver API (cuModuleLoad → cuLaunchKernel,
          grid=ceil(2^20/256), block=256) → maxerr 0.000e+00, 0 mismatches
          over 1,048,576 f64 elements vs CPU reference — both kernels.
      D2 is fully silicon-PROVEN: .hexa @gpu_kernel → hexa build → PTX → ptxas
      cubin → driver-API launch → bit-exact result, no .cu / nvcc.
      Verdict (verbatim ptxas + device output): .verdicts/hexa-cuda/
      F-HEXACUDA-PTXAS-DEVICE.txt. Harness + PTX artifacts in
      tools/hexa-cuda-validate/.
