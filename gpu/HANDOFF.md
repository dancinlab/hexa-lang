# gpu — HANDOFF

> Handoff brief for the next session/agent picking up the hexa-native
> GPU kernel effort. Read `README.md` + `design.md` first — this file
> is "what to do next" plus the honest performance framing that the
> work must not violate.

## State (2026-05-19)

- **SPEC LANDED · codegen in progress under RFC 055.**
- Decision 1 LOCKED — kernel source format = `@gpu` annotation on
  ordinary `.hexa` files; no `.hxk` extension. (`design.md` D1)
- Decision 2 LOCKED — directory = `hexa-lang/gpu/`. (`design.md` D2)
- Decision 3 LOCKED — `gpu/SPEC.md` is the `@gpu` subset SSOT; RFC 055
  §6 references it. (`design.md` D3)
- **`gpu/SPEC.md` written** — the full `@gpu` subset: `@gpu_kernel` /
  `@gpu_device` attributes, type allowlist, statement allowlist /
  denylist, thread-index + sync intrinsics, `@shared` memory, the
  `gpu_launch` ABI, FP64-first scope, the `GPU0N` strict-lint codes.
- **RFC 055 is the codegen implementation** — `hexa-src → NVPTX`. It
  consumes `gpu/SPEC.md`. Status: `055-P0` PTX text emit pass landed
  (`compiler/codegen/nvptx_target.hexa` — FP64 arithmetic subset emits
  real PTX); not yet wired into main target dispatch.
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
2. **`@gpu_kernel` attribute parse + strict-lint** — wire the `GPU0N`
   validation pass (`gpu/SPEC.md` §9) into the compiler frontend; emit
   the `GPU01`–`GPU07` diagnostics. This is RFC 055 phase **055-P1**.
3. **FP64 vector-add end-to-end** — a `@gpu_kernel` `c[i]=a[i]+b[i]`
   compiles through the NVPTX target, `ptxas`-assembles to a `cubin`,
   launches via `gpu_launch`, byte-eq vs the CPU hexa reference
   (F-RFC055-PTX-EMIT, -NUMERIC-EQ, -LAUNCH-ABI). RFC 055 **055-P1**.
4. **FP64 GEMM `@gpu_kernel`** — naive / tiled, `@shared` + `gpu_barrier`;
   correctness gate vs CPU hexa GEMM (F-RFC055-GEMM-FEASIBLE). Perf vs
   cuBLAS is an honest measurement, **not** a gate. RFC 055 **055-P2**.
5. **Benchmark vs torch.compile** — once a fused `@gpu` kernel exists,
   measure per-step wall vs torch.compile on the same A100 workload at
   matched T / batch / precision (see the honesty guard below).

Steps 2–4 are the RFC 055 phasing — `gpu/` (this directory) owns the
*spec*; RFC 055 owns the *codegen implementation*.

## Open items

- **No honest PyTorch comparison exists.** The prior 2.95× was
  retracted (unit mismatch — see Benchmark target above). A real perf
  gate needs a per-step PyTorch baseline (eager AND torch.compile) at
  matched T / batch / precision — one A100 dispatch, when `@gpu` work
  is far enough along to warrant it.

## Cross-references

- `gpu/README.md` · `gpu/design.md` — what this is + decision ledger
- `gpu/SPEC.md` — the `@gpu` subset SSOT (Decision 3)
- `inbox/rfc_drafts_2026_05_12/rfc_055_hexa_nvptx_codegen_backend.md` —
  the NVPTX codegen implementation (consumes `gpu/SPEC.md`); 055-P0
  landed, 055-P1/P2 = steps 2–4 above
- `self/native/gpu_codegen_stub.c` — rt#45 `@gpu` codegen skeleton
- `self/forge/PLAN.md` — GPU substrate roadmap
- `stdlib/flame/README.md` — "honest floor" / cuBLAS roofline framing
