# gpu — HANDOFF

> Handoff brief for the next session/agent picking up the hexa-native
> GPU kernel effort. Read `README.md` + `design.md` first — this file
> is "what to do next" plus the honest performance framing that the
> work must not violate.

## State (2026-05-20)

- **SPEC LANDED · 055-P1 + 055-P2 codegen LANDED + measured PASS on a real GPU.**
- Decision 1 LOCKED — kernel source format = `@gpu` annotation on
  ordinary `.hexa` files; no `.hxk` extension. (`design.md` D1)
- Decision 2 LOCKED — directory = `hexa-lang/gpu/`. (`design.md` D2)
- Decision 3 LOCKED — `gpu/SPEC.md` is the `@gpu` subset SSOT; RFC 055
  §6 references it. (`design.md` D3)
- Decision 4 LOCKED — 055-P2 scope = the naive GEMM emitter + a measured
  GPU fire; the MIR-partition / `gpu_launch` lowering / cubin embed are
  055-P3 (productization). (`design.md` D4)
- **`gpu/SPEC.md` written** — the full `@gpu` subset: `@gpu_kernel` /
  `@gpu_device` attributes, type allowlist, statement allowlist /
  denylist, thread-index + sync intrinsics, `@shared` memory, the
  `gpu_launch` ABI, FP64-first scope, the `GPU0N` strict-lint codes.
- **RFC 055 is the codegen implementation** — `hexa-src → NVPTX`. It
  consumes `gpu/SPEC.md`. Status: `055-P0` (PTX emit pass) → `055-P1`
  (vec-add `@gpu_kernel` + GPU0N validator) → **`055-P2` (naive FP64
  GEMM `@gpu_kernel`) — LANDED 2026-05-20**.
- **GPU fire — full falsifier battery measured PASS** on an NVIDIA RTX
  5070 (sm_120 · driver 580.126.09), $0 on the wilson-pool GPU host
  `ubu-2`: `F-RFC055-PTX-EMIT` · `-NUMERIC-EQ` (vec-add `max|Δ|=0`) ·
  `-GEMM-FEASIBLE` (GEMM `max|Δ|=0`) · `-LAUNCH-ABI` · `-NO-LLVM` ·
  `-CPU-CODEGEN-UNTOUCHED` — all PASS. Evidence:
  `state/rfc055_p2_2026_05_20/result.json`. Reproduce:
  `tool/dispatch_r055_p2_gemm.sh [gpu-ssh-host]`.
- **What's left — 055-P3 (productization):** the codegen is hand-emitted
  (`emit_ptx_{vec_add,gemm}_module`) and fired via a dispatch script; it
  is NOT yet wired into the main compile pipeline. 055-P3 = the MIR
  partition routing a real `@gpu_*` FnDecl → `codegen_nvptx_sm*`, the
  `gpu_launch(...)` host-side lowering, the cubin `.rodata` `LSection`
  embed, and the tiled `@shared`+`gpu_barrier()` GEMM (055-P2-tiled).
- Existing scaffold — `self/native/gpu_codegen_stub.c` is the rt#45
  `@gpu` codegen skeleton; superseded by RFC 055's `nvptx_target.hexa`.

## Goal

Author forge's GPU compute kernels in hexa (`@gpu fn ...`); the
compiler emits per-backend device code (CUDA first, Metal / ROCm
later). Replaces the hand-written `self/native/hxcuda_*.cu`.

## Performance framing — READ THIS, it is the honesty guard

The roadmap phrase is **"match cuBLAS → exceed cuBLAS"**. Be precise
about what each half means, or the claim trips hexa-lang `g3`/`g4`
(honesty obligation) and flame's "honest floor":

- **"match cuBLAS"** — a single `@gpu` GEMM kernel reaching cuBLAS
  Dgemm throughput. cuBLAS sits at the hardware roofline; matching is
  the realistic ceiling for a *single* dense GEMM. flame already
  CALLS cuBLAS here — matching, not beating.
- **"exceed cuBLAS"** — does NOT mean a faster GEMM kernel (roofline,
  impossible). It means beating a *sequence of cuBLAS library calls*
  by FUSING them into one kernel — eliminating the GEMM-epilogue
  memory round-trips. This is exactly what flash-attention did over
  naive attention. Achievable and honest. Any "exceed cuBLAS" claim
  must name the fused op sequence it beats.

### Benchmark target — measure honestly, same units

**CORRECTION 2026-05-19**: flame's prior "2.95x faster than PyTorch
eager" headline was a unit mismatch (flame 1-step wall ÷ PyTorch
2500-step run wall) and is RETRACTED. flame has NO measured
PyTorch-speedup. See `stdlib/flame/PERF.md` "GPU dispatch path".

For `@gpu` fused-kernel perf work:

- Always compare PER-STEP wall to PER-STEP wall, same T / batch /
  precision. flame runs FP64; PyTorch baselines are bf16 autocast —
  match precision or state the gap explicitly.
- The honest opponent is **torch.compile**, not eager — torch.compile
  also fuses; beating only eager proves nothing.
- flame d768·12L FP64 is currently ~3 orders of magnitude slower per
  step than PyTorch eager. "match cuBLAS → exceed cuBLAS" is a long
  road from here — set gates against measured per-step walls only.

## Next steps (suggested order)

1. ~~**Spec the `@gpu` subset**~~ — **DONE**: `gpu/SPEC.md` (Decision 3).
2. ~~**`@gpu_kernel` attribute parse + strict-lint**~~ — **DONE** (055-P1):
   the `GPU0N` decision table (`nvptx_validate_gpu_subset`) + `@gpu_*`
   attribute recognition, in `compiler/codegen/nvptx_target.hexa`.
3. ~~**FP64 vector-add end-to-end**~~ — **DONE** (055-P2 fire, 2026-05-20):
   `emit_ptx_vec_add_module` PTX, fired on a real GPU — F-RFC055-PTX-EMIT,
   -NUMERIC-EQ (`max|Δ|=0`), -LAUNCH-ABI all PASS.
4. ~~**FP64 GEMM `@gpu_kernel`**~~ — **DONE** (055-P2, 2026-05-20):
   `emit_ptx_gemm_module` — naive (one thread / C element), real PTX
   contraction loop, `fma.rn.f64`. F-RFC055-GEMM-FEASIBLE PASS
   (`max|Δ|=0` vs CPU reference, RTX 5070).
5. **055-P3 — wire into the compile pipeline.** The codegen is currently
   hand-emitted + fired via `tool/dispatch_r055_p2_gemm.sh`. 055-P3: the
   MIR partition routing a real `@gpu_*` FnDecl → `codegen_nvptx_sm*`;
   the `gpu_launch(...)` host-side lowering → `_hx_cuda_launch_kernel`;
   the cubin `.rodata` `LSection` embed; the tiled `@shared` +
   `gpu_barrier()` GEMM (055-P2-tiled).
6. **Benchmark vs torch.compile** — once a *fused* `@gpu` kernel exists,
   measure per-step wall vs torch.compile at matched T / batch /
   precision (see the honesty guard above). Not before 055-P3.

`gpu/` (this directory) owns the *spec*; RFC 055 owns the *codegen
implementation*.

## Open items

- **No honest PyTorch comparison exists.** The prior 2.95× was
  retracted (unit mismatch — see Benchmark target above). A real perf
  gate needs a per-step PyTorch baseline (eager AND torch.compile) at
  matched T / batch / precision — one A100 dispatch, when `@gpu` work
  is far enough along to warrant it.

## Cross-references

- `gpu/README.md` · `gpu/design.md` — what this is + decision ledger
- `gpu/SPEC.md` — the `@gpu` subset SSOT (Decision 3)
- `docs/rfc/rfc_drafts_2026_05_12/rfc_055_hexa_nvptx_codegen_backend.md` —
  the NVPTX codegen implementation (consumes `gpu/SPEC.md`); 055-P0
  landed, 055-P1/P2 = steps 2–4 above
- `self/native/gpu_codegen_stub.c` — rt#45 `@gpu` codegen skeleton
- `self/forge/PLAN.md` — GPU substrate roadmap
- `stdlib/flame/README.md` — "honest floor" / cuBLAS roofline framing
