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

### Benchmark target = torch.compile, NOT eager

flame's current headline (2.95x, d768·12L, A100) is vs PyTorch
**eager**. Eager carries Python dispatch overhead that
torch.compile / TorchInductor also removes. For `@gpu` fused-kernel
work the honest comparison is **vs torch.compile** — because
torch.compile *also* fuses. Beating only eager proves nothing a
fused kernel should claim credit for.

- Gate it: `@gpu` fused-path wall ≤ torch.compile wall — same
  workload, same A100, same dtype.
- torch.compile is currently UNMEASURED (see Open items) — that
  measurement is a prerequisite for any `@gpu` perf gate.

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

- **torch.compile baseline UNMEASURED.** flame docs only hold PyTorch
  eager (336.85 s · d768·12L · A100). A `@gpu` perf gate needs the
  torch.compile number — one A100 dispatch, ~$5-20. Decision pending
  (fire-gate: measure vs resolve-analytically).

## Cross-references

- `gpu/README.md` · `gpu/design.md` — what this is + decision ledger
- `self/native/gpu_codegen_stub.c` — `@gpu` codegen skeleton
- `self/forge/PLAN.md` — GPU substrate roadmap
- `stdlib/flame/README.md` — "honest floor" / cuBLAS roofline framing
