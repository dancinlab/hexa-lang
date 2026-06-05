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
- [ ] D1 — gaps found during D0, filed as follow-on work:
      (a) `hexa build --target=nvptx…` end-to-end driver is GATED in the
          bootstrap binary (`_build_nvptx_emit_driver` returns 1 with
          `[nvptx] GATED RFC071-P3-PathB`); the real codegen
          `codegen_emit_ptx_for_sm` is NOT linked into Stage-1 bootstrap, so
          local `hexa build` of a kernel cannot yet emit PTX. (RFC 071 P3 Path B.)
      (b) `gpu_shared_f64` / `gpu_shared_add` / `gpu_shared_get` used by the
          qforge `@phase("parse_only")` reference kernels are NOT real codegen
          intrinsics — the real shared-memory form is `@shared let t: [f64; N]`
          (gpu/SPEC.md §6). Cookbook uses the real form; flagged the divergence.
      (c) `gpu_tf32_round` (qforge mixprec kernel) is likewise not a codegen
          intrinsic — TF32 is host-side cuBLAS in that harness, not device PTX.
      (d) FP64 `exp()` intrinsic underflow bug below x≈−745 (qforge a2f d6 note)
          — kernel-side guard documented; codegen fix is a separate inbox item.
- [ ] D2 — once D1(a) lands (RFC 071 P3 driver wiring), re-run the four
      cookbook examples through `hexa build --target=nvptx64-nvidia-cuda-sm80`
      and flip each example's "build-verified" tag from pending → confirmed.
