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

---

## 2026-06-06 — D1(a) + D2 DONE: `hexa build --target=nvptx` un-gated

Branch `domain/hexa-cuda-nvptx-ungate` (off origin/main f5eee160d).

**Gate found** at `self/main.hexa:2404` — `_build_nvptx_emit_driver` printed
`[nvptx] GATED RFC071-P3-PathB` + `return 1`. Reached from `cmd_build`'s nvptx
dispatch branch (`target == nvptx64-nvidia-cuda-sm{80,90,120}` → `sm_{NN}` →
`_build_nvptx_emit_driver(src, sm)` → `exit(rc)`).

**The gate was STALE.** Its stated reason ("compiler/ module bodies NOT linked
by bootstrap Stage 1 → 6 undefined symbols") no longer holds: `self/main.hexa`
lines 10-16 already `use` all 7 pipeline modules (lexer, parser, ast_to_hir,
hir_to_mir, static_index, mir, nvptx_target). The real, RTX-5070-validated
`codegen_emit_ptx_for_sm` (RFC 055 §7) was fenced off, not missing.

**Wiring** (+50/-6, single file `self/main.hexa`): replaced the gate body with
the inline `read → lex → parse → static_atlas → lower → lower_hir →
codegen_emit_ptx_for_sm → write_file(src+".ptx")` pipeline — a 1:1 mirror of the
verified spec sibling `compiler/cli/build_nvptx.hexa::build_nvptx_emit_driver`.
Inline (not a `use` of that sibling) to avoid duplicate struct defs, exactly as
the in-file docstring (self/main.hexa:2356-2382) prescribes. Refuses loudly when
no `@gpu_kernel` MFunc is present. wipe_guard OK (6-line delete << 50).

**OFF-safe / no regression**: the fn has exactly one caller — the nvptx dispatch
branch, guarded by `if len(_nvptx_sm) > 0` (true only for the 3 nvptx target
strings). Normal `hexa build foo.hexa` never enters it → byte-identical.
`hexa run hello.hexa` → exit 0, correct output. `hexa parse self/main.hexa` → OK.

**Emit verified**: a standalone harness running the IDENTICAL inline pipeline on
the cookbook vec-add `@gpu_kernel` emitted a 59-line **source-derived** PTX:
`.version 7.8` / `.target sm_90` / `.address_size 64` / `.visible .entry vec_add`
(source name, NOT the hand-MIR `vadd` fallback) / 4× `.param .u64` / `%ctaid.x`
`%ntid.x` `%tid.x` index math / `setp.lt.s64` bounds check / 2× `ld.global.f64`
/ `add.f64` / `st.global.f64` / `ret`. The harness substitutes for the live
`hexa build` run because the stale local Jun-1 `hexa` hangs flattening the full
`self/main.hexa` on macOS (project_compiler_selfbuild_blockers); it exercises
the same pipeline the edited driver now uses.

**Deferred**: `ptxas -arch=sm_90 vecadd.hexa.ptx` + device run — no local
ptxas/CUDA toolkit on this macOS host; GPU rental out-of-scope for the un-gate.
SAXPY / reduce / matmul re-emit on a CUDA host = follow-up.

Verdict: `.verdicts/hexa-cuda/F-HEXACUDA-NVPTX-UNGATE.txt` (GREEN).

## 2026-06-06 — D2 SILICON-VALIDATED on a real H100 (ptxas + device run)

Closed the two residuals the #2799 un-gate left open (ptxas-clean + device
run). On a vast H100 80GB HBM3 pod (sm_90, CUDA 12.6.2-devel):

1. **Fresh build** — `bash tool/release_build` (Stage 0/1/2 self-host) built
   `./hexa` 0.1.0-dispatch from branch source (NOT the stale macOS oracle).
2. **Emit** — `hexa build {vecadd,saxpy}.hexa --target=nvptx64-nvidia-cuda-sm90`
   → source-derived PTX (`.visible .entry vec_add`/`saxpy`, `.target sm_90`).
3. **ptxas** — `ptxas -arch=sm_90` → exit 0, EMPTY stderr (CLEAN), both kernels.
4. **Device run** — CUDA Driver API (cuModuleLoad → cuLaunchKernel) on the H100:
   maxerr 0.000e+00, 0 mismatches / 2^20 f64 elements vs CPU ref, both kernels.

D2 fully silicon-PROVEN: .hexa @gpu_kernel → hexa build → PTX → ptxas cubin →
driver-API launch → bit-exact. Pod destroyed (leak 0; only rtsc-anchor remains).

Harness + PTX artifacts: `tools/hexa-cuda-validate/`.
Verdict: `.verdicts/hexa-cuda/F-HEXACUDA-PTXAS-DEVICE.txt` (🟢 GREEN).
