# HEXA-CUDA — step log (append-only)

## 2026-06-06 — D0 surface inventory + D4 cookbook authored

### D0 — device-intrinsic support matrix (ground-truth, read from compiler)

Sources audited:
- `gpu/SPEC.md` — the `@gpu` subset SSOT (attributes, type allowlist, intrinsics,
  shared-mem model, launch ABI, `GPU0N` lint codes).
- `compiler/codegen/nvptx_target.hexa` — the RFC 055 hexa→PTX codegen (the
  authoritative list of intrinsics that actually LOWER to PTX).
- `self/parser.hexa` (`@shared`), `self/main.hexa` (`@gpu_kernel` discovery +
  `--target=nvptx…` dispatch), `self/codegen.hexa` (host-side `gpu_launch` lowering).
- 6 real reference kernels in `stdlib/qforge/nvptx_*_kernel.hexa`.

Intrinsics that REALLY lower (op-table in nvptx_target.hexa):
- Thread/block/grid index, all 3 axes: `gpu_thread_id_{x,y,z}`,
  `gpu_block_id_{x,y,z}`, `gpu_block_dim_{x,y,z}`, `gpu_grid_dim_{x,y,z}` → `%tid/%ctaid/%ntid/%nctaid`.
- `gpu_global_thread_id_{x,y,z}` — fused `ctaid*ntid+tid` convenience.
- `gpu_barrier()` → `bar.sync 0`.
- Atomics: `gpu_atomic_add / gpu_atomic_min / gpu_atomic_max / gpu_atomic_cas`
  (f64, return old value) → `atom.*`.
- Warp shuffles: `gpu_warp_shuffle / _down / _up / _xor` → `shfl.sync.*.b32`
  (f64 decomposed into two .b32 halves).
- Tensor-core: `gpu_wmma_load_a / _load_b / _mma / _store_c` → `wmma.*` (f16/bf16/f32).
- Shared memory: `@shared let t: [T; N]` annotation (NOT a function) → `.shared` bank.
- Host launch: `gpu_launch(kernel, gx,gy,gz, bx,by,bz, args…)` → `_hx_cuda_launch_kernel`.

GAPS found (→ D1):
- (a) `hexa build --target=nvptx64-nvidia-cuda-sm{80,90,120}` is recognised by the
  CLI but the emit-driver `_build_nvptx_emit_driver` in the BOOTSTRAP binary returns
  1 with `[nvptx] GATED RFC071-P3-PathB` — `codegen_emit_ptx_for_sm` is not linked
  into Stage-1 bootstrap (RFC 071 P3 Path B). So local `hexa build` of a kernel does
  NOT yet emit PTX. The codegen itself was validated on an RTX 5070 via the RFC 055
  §7 falsifier battery (gpu/SPEC.md §10), so the lowering is real — only the
  user-facing driver wiring is pending.
- (b) `gpu_shared_f64 / gpu_shared_add / gpu_shared_get` appear in the qforge
  `@phase("parse_only")` reference kernels but are NOT codegen intrinsics. Real
  shared-mem = `@shared let` (gpu/SPEC.md §6). Cookbook uses the real form.
- (c) `gpu_tf32_round` (qforge mixprec) is not a codegen intrinsic — TF32 there is
  host cuBLAS, not device PTX.
- (d) f64 `exp()` intrinsic underflows wrong below x≈−745 (qforge a2f d6 note) —
  kernel-side guard documented; codegen fix is a separate inbox item.

### D4 — cookbook

Authored `docs/hexa-cuda-cookbook.md`: vector-add, SAXPY, parallel reduction
(two-stage, `@shared` + tree reduce + `gpu_barrier`), tiled FP64 matmul
(`@shared` tiles + barrier). Each example: kernel source (real syntax only) +
host launch shape (`gpu_launch`) + build command + honest build-verified tag.

Build-verified status: ALL examples = "pending" (blocked on D1(a) driver wiring).
The kernel SYNTAX is real (matches the 6 qforge reference kernels + gpu/SPEC.md +
the codegen op-table). The end-to-end `hexa build → PTX → ptxas → run` is what is
pending. Local `hexa` is also a stale oracle (memory: project_local_hexa_stale_oracle),
so even after D1(a) lands, re-verify on a fresh toolchain (D2).
