# gpu — HANDOFF

> Handoff brief for the next session/agent picking up the hexa-native
> GPU kernel effort. Read `README.md` + `design.md` first — this file
> is "what to do next" plus the honest performance framing that the
> work must not violate.

## State (2026-05-19)

- **DESIGN PHASE — zero implementation.**
- Decision 1 LOCKED — kernel source format = `@gpu` annotation on
  ordinary `.hexa` files; no `.hxk` extension. (`design.md` D1)
- Decision 2 LOCKED — directory = `hexa-lang/gpu/`. (`design.md` D2)
- Existing scaffold — `self/native/gpu_codegen_stub.c` is the `@gpu`
  codegen skeleton to build on.

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

1. **Spec the `@gpu` subset** — which hexa constructs are legal inside
   a `@gpu fn`: thread/block index intrinsics, no recursion, no host
   heap allocation, bounded loops. Write it as `gpu/SPEC.md`.
2. **Real codegen for one kernel** — grow `self/native/gpu_codegen_stub.c`
   from skeleton to a working `@gpu` → CUDA C emitter for one kernel.
3. **Port + verify one existing kernel** — reproduce e.g.
   `self/native/hxcuda_fused.cu` as a `@gpu fn`, verify byte-eq
   output against the hand-written `.cu` (oracle).
4. **Benchmark vs torch.compile** — once a fused `@gpu` kernel exists,
   measure against torch.compile on the same A100 workload.

## Open items

- **No honest PyTorch comparison exists.** The prior 2.95× was
  retracted (unit mismatch — see Benchmark target above). A real perf
  gate needs a per-step PyTorch baseline (eager AND torch.compile) at
  matched T / batch / precision — one A100 dispatch, when `@gpu` work
  is far enough along to warrant it.

## Cross-references

- `gpu/README.md` · `gpu/design.md` — what this is + decision ledger
- `self/native/gpu_codegen_stub.c` — `@gpu` codegen skeleton
- `self/forge/PLAN.md` — GPU substrate roadmap
- `stdlib/flame/README.md` — "honest floor" / cuBLAS roofline framing
