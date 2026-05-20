# GPU — hexa-lang's NVPTX-first GPU substrate (domain SSOT)

> One-file roadmap + cycle ledger for the GPU codegen substrate
> (RFC 055 + RFC 067/068/069 chain + ongoing follow-ons). Domain
> SSOT per `AGENTS.tape` `@D g_plan_consolidation`: cycle-by-cycle
> progression appended to `compiler/PLAN.md`; this file is the
> *forward-looking checklist* + *brainstorm-to-exhaustion roadmap*.

**hexa-lang North-Star ① (NN stack)** + **§12 P4+ chain** + **GOAL — "cuBLAS-using stacks 를 whole-program-fusion 으로 우회"** are the umbrella metrics this file tracks.

---

## 0 · One-paragraph state (end-of-day 2026-05-20)

§12 P4+ chain end-to-end functional: codegen-side (hexa MIR → PTX) and silicon-side (PTX → ptxas → RTX 5070 sm_120 driver-JIT → numeric correctness) both **measured-PASS**. 25 PRs landed today including the **first three ever §12 P4+ silicon-fire closures** (RFC 067 WMMA, RFC 068 f16, RFC 069 unroll byte-eq) + codegen↔silicon reconcile (PR #193). `nvptx_lower_test` smoke: 9/9 → 25/25 cases this session.

---

## 1 · Completed (measured-PASS, landed on origin/main)

### 1a — codegen scaffolding (RFC 055 §1-§12 P3)

- [x] **RFC 055 Stage-1 scaffold** — NVPTX target enum, PTX opcode table, address-space constants, target enum dispatch
- [x] **RFC 055 055-P0** — PTX text emit pass for FP64-arithmetic subset (`add.f64`, `mul.f64`, `mov.f64`, `ret`, `.func`, `.reg .f64`)
- [x] **RFC 055 055-P1** — `@gpu_kernel` end-to-end vec-add slice (`.visible .entry`, `.param .u64`, `ld.global.f64`, `st.global.f64`, `mov.u32 %tid.x`, address arithmetic, bounds-check `setp + bra`)
- [x] **RFC 055 055-P2** — naive FP64 GEMM `@gpu_kernel` (i-j-k loop, FMA-ready)
- [x] **RFC 055 055-P3a** — `--target=nvptx64-nvidia-cuda-sm{80,90}` dispatch in `compiler/main.hexa`
- [x] **RFC 055 055-P3b** — per-Local PTX register-kind classification (`.f64` / `.u32` / `.u64` / `.pred`)
- [x] **RFC 055 055-P3b** — `STMT_BR` / `STMT_BR_COND` / `STMT_CALL gpu_*` / `STMT_LOAD` / `STMT_STORE` generic lowering
- [x] **RFC 055 055-P3c** — `@gpu_kernel` / `@gpu_device` partition (`gpu_kind` field on `MFunc`)
- [x] **RFC 055 055-P4** — `gpu_barrier()` block-wide sync (`bar.sync 0;`)
- [x] **RFC 055 055-P4+** — `gpu_atomic_add()` global `atom.add.f64`
- [x] **RFC 055 055-P4+** — `gpu_warp_shuffle()` `shfl.sync.idx.b32`
- [x] **RFC 055 055-P4+** — Tensor Core MMA scaffold (NVPTX_RKIND_FRAG, `_nvptx_wmma_mnemonic` table, STMT_CALL recognition)
- [x] **RFC 055 055-P4+** — mixed-precision scaffold (NVPTX_RKIND_F16/_BF16/_F32, classifier rules)
- [x] **RFC 055 055-P4+** — `_nvptx_unroll_pass` MVP (canonical 3-block back-edge, factor=2)

### 1b — RFC 067 (real WMMA emit)

- [x] **P0** — Shape-B RFC draft + marker comments (PR #138)
- [x] **P1** — Fragment-as-tile-vector (8 `.reg .b32 %fra<id>_e<i>`) + `F-RFC067-FRAG-WIDTH` PASS (PR #150)
- [x] **P2** — `.shared .align 16 .b8 _hexa_wmma_stage_<fn>[2048]` decl + `F-RFC067-SHARED-DECL` PASS (PR #155)
- [x] **P3** — PReg fragment role + dtype + layout metadata + `_nvptx_wmma_mnemonic_family` re-key + `F-RFC067-DTYPE-FAMILY` PASS (PR #170)
- [x] **INSTR-EMIT** — Real `wmma.load.a/b`, `wmma.mma`, `wmma.store.d` PTX (replaces scaffold-comment stub) (PR #177)
- [x] **P4 silicon** — single-tile 16x16 GEMM Tensor Core fire vs FP32 ref, `max|Δ|=0`, `F-RFC067-TILE-LOOP-NUMERIC` PASS (PR #191)

### 1c — RFC 068 (mixed-precision MIR layer)

- [x] **P0** — Shape-B RFC draft + marker comments (PR #140)
- [x] **P1** — Local.precision tag thread + classifier short-circuit + `F-RFC068-PRECISION-PROPAGATE` PASS (PR #148)
- [x] **P2** — HIR `@f16`/`@bf16`/`@f32` named-type primitives + `_op_with_precision` opcode-suffix generation + `F-RFC068-OPCODE-SUFFIX` PASS (PR #170)
- [x] **P3** — body-emit `add.f16/.bf16/.f32` mnemonics + `F-RFC068-BODY-MNEMONIC` PASS (PR #175)
- [x] **P4-prereq** — `ld.global.<ty>` / `st.global.<ty>` codegen seam + `F-RFC068-LD-ST-CODEGEN` PASS (PR #186)
- [x] **P4 silicon** — f16 vec-add silicon fire vs FP16-roundtrip ref, `max|Δ|=0/1024`, `F-RFC068-NUMERIC-EQ` PASS (PR #189)
- [x] **codegen↔silicon reconcile** — ptxas accepts `.b16` storage but rejects `ld.global.f16`; constants reconciled (PR #193)

### 1d — RFC 069 (advanced loop unroll)

- [x] **P0** — Shape-B RFC draft + marker comments (PR #141)
- [x] **P1** — factor=N parameterization (2 ≤ N ≤ 32) + `F-RFC069-FACTOR-N` PASS (PR #147)
- [x] **P2** — multi-exit loop matcher (STMT_BR_COND back-edge in either arm) + `F-RFC069-MULTI-EXIT-MATCH` PASS (PR #156)
- [x] **P3** — nested-loop detection + honest passthrough preservation + `F-RFC069-NESTED-PRESERVE` PASS (PR #159)
- [x] **wiring** — `HEXA_NVPTX_UNROLL_FACTOR` env-gated codegen pipeline integration + GEMM K-loop MIR fixture (PR #179)
- [x] **P4 silicon** — unroll=1 vs unroll=2 vec-add byte-eq on RTX 5070, `byte_mismatch=0/1024`, `F-RFC069-NUMERIC-EQ` PASS (PR #190)

### 1e — Continuous gates (all sessions)

- [x] **F-RFC055-NO-LLVM** — zero LLVM/clang-target-nvptx linkage anywhere in the hexa→PTX→fire chain
- [x] **F-RFC055-CPU-CODEGEN-UNTOUCHED** — `compiler/codegen/{x86_64_linux,arm64_darwin,thumbv7em_eabihf}.hexa` byte-identical pre-vs-post every commit
- [x] **F-RFC069-PASSTHROUGH-PRESERVED** — Case 11 (non-matching CFG passthrough) byte-identical across the RFC 069 P1-P3 cycle

---

## 2 · Next layer (concrete, scope-bounded — pick one to start)

### 2a — Source-to-silicon e2e closure (RFC 068 last gap)

Today's silicon fires used hand-emit PTX (codegen verification via `nvptx_lower_test` smoke; silicon via fire). The remaining gap: a `.hexa` source file with `@gpu_kernel fn f16_vadd(...)` lowering through HIR → MIR → codegen_emit_ptx_sm80 → ptxas → fire.

- [ ] **source kernel fixture** — write `test/rfc068_f16_vadd_e2e.hexa` with `@gpu_kernel fn f16_vadd(a: [f16], b: [f16], c: [f16], n: i64)` body
- [ ] **HIR → MIR lowering** — verify `let t: f16 = a[i] + b[i]` lowers to `STMT_LOAD .f16 + STMT_BINOP add_f16 + STMT_STORE .f16` with precision tag propagated
- [ ] **MFunc.gpu_kind = KERNEL** — `@gpu_kernel` annotation parse + lowering hooked
- [ ] **codegen emits launchable PTX** — `.visible .entry` + `.param .u64` quartet (a/b/c/n) + body
- [ ] **ptxas-clean check** — emitted PTX passes `ptxas -arch=sm_80`
- [ ] **fire on ubu-2** — driver-JIT + cuLaunchKernel + compare to f64 reference
- [ ] **`F-RFC068-E2E-NUMERIC-EQ`** PASS — full source-to-silicon chain byte-eq closure
- [ ] **commit** — same `inbox/fires/` pattern as PR #189

### 2a finding (2026-05-20): build pipeline gap analysis

The blocker is NOT in `self/main.hexa::cmd_build` `--target=` validation
(adding a `nvptx64-*` branch there is one-line edit). The substantive
gap is the BUILD PIPELINE itself:

```
Current `hexa build` (CPU targets):
  src.hexa → module_loader (flatten) → hexa_v2 transpiler (.c)
           → clang/zig cc → native binary

Required for NVPTX:
  src.hexa → module_loader (flatten) → in-hexa compiler self-host
           → MIR → codegen_emit_ptx_sm80 → PTX text
```

`hexa_v2` is the **bootstrap transpiler** that emits C — it doesn't
know about NVPTX. The NVPTX codegen lives in `compiler/codegen/
nvptx_target.hexa` and is invoked only from within the in-hexa
self-host pipeline (which today produces CPU artifacts via the
existing `compiler/*` tree, not via `hexa_v2`).

To wire `hexa build --target=nvptx64-*` properly, options are:
- (A) **Internal emit-driver pattern** — `cmd_build` synthesizes a
  small driver `import src.hexa + compiler/codegen/nvptx_target.hexa`
  and prints `codegen_emit_ptx_sm80(...)`. Substantial: requires
  exposing the full compiler pipeline as a callable.
- (B) **Compiler self-host on NVPTX** — the in-hexa compiler IS
  the build path for `--target=nvptx64`. Aligned with north-star ②
  (self-host already PROVEN for CPU at fixpoint per memory
  `project_compiler_native_self_host_fixpoint`); extending to
  NVPTX is the natural next step.
- (C) **Out-of-band emit driver** — keep using the external script
  pattern from PR #82 (`tool/dispatch_*.sh`). Today's 8 fires
  successfully demonstrate this works. **No `hexa build` wiring
  required** for the actual silicon-validation path.

Choice for this session: **(C)** — defer (A)/(B) as multi-session
campaigns. The §1 ledger shows all silicon-fires landed via the
out-of-band pattern; full source-to-silicon `hexa build --target=
nvptx64-*` is a strategic infrastructure cycle for a separate
session.

### 2b — Multi-tile WMMA GEMM K-loop (RFC 067 §3 P4 spec form)

PR #191 closed the *single-tile* WMMA fire. The RFC 067 §3 P4 spec asks for 64×64 GEMM = 4×4 output tiles × 4 K-tiles = 64 `wmma.mma` calls with `.shared` staging.

- [ ] **multi-tile kernel** — hand-emit `wmma_64x64.ptx` with explicit 4×4×4 nested loops
- [ ] **`.shared` staging slot allocation** — 4 KB shared mem for A/B double-buffer tiles
- [ ] **K-loop accumulator carry** — C fragment reuse across K-tile iterations (no spill)
- [ ] **host launcher** — `tool/r067_p4_multi_host.c` mirrors `r067_p4_host.c` but 64×64
- [ ] **fire on ubu-2 + compare to FP32 reference** — `≤ 1e-2 rel error` tolerance (the canonical f16-mul-f32-acc bound)
- [ ] **`F-RFC067-TILE-LOOP-NUMERIC-MULTI`** PASS
- [ ] **codegen-side hexa equivalent** — synthesize MFunc with multi-block K-loop body + multi-`gpu_wmma_mma` STMT_CALL emit

### 2c — Codegen-side BF16 silicon reconcile

Today's PR #193 reconciled `f16 → b16` storage; bf16 reg type still trips ptxas 12.0 `.reg .bf16` parse.

- [ ] **PTX 7.8 toolchain bump probe** — test bf16 acceptance on `.version 8.0` / `.version 8.x` PTX targets
- [ ] **`add.bf16` instruction support** — verify ptxas accepts the bf16 arithmetic path
- [ ] **hexa codegen flip** — if PTX 8.x parses cleanly, emit `.version 8.0` + native `.reg .bf16` decl; else stay with `.reg .b16` and use bitcast
- [ ] **bf16 vec-add fire** — same pattern as PR #189 but bf16 inputs
- [ ] **`F-RFC068-NUMERIC-EQ-BF16`** PASS

### 2d — Hexa-native dispatch (replace direct-bash + sidesetep HEXA_FIRST_WARN)

PR #189/#190/#191 fires used direct one-shot bash; sustained automation needs hexa-native.

- [ ] **stdlib/cloud dispatch primer** — leverage existing `stdlib/cloud` ssh/scp/rsync APIs
- [ ] **`tool/dispatch_gpu_fire.hexa`** — generic hexa-native fire dispatcher (PTX path, host C path, target host)
- [ ] **smoke verify** — re-fire PR #82 / #189 / #190 / #191 kernels via the hexa dispatcher; results identical
- [ ] **migrate** — deprecate `tool/dispatch_r055_p2_gemm.sh` once hexa equivalent measured-PASS

### 2e — `cp.async` pipelining (sm_80+) — performance, not correctness

- [ ] **PTX opcode constants** — `PTX_OP_CP_ASYNC_F16`, `PTX_OP_CP_ASYNC_COMMIT_GROUP`, `PTX_OP_CP_ASYNC_WAIT_GROUP`
- [ ] **codegen seam** — when WMMA kernel's K-loop body references `.shared` storage, emit `cp.async.cg.shared.global` for prefetch
- [ ] **double-buffer pattern** — two `.shared` staging slots; alternating fill/use
- [ ] **fire vs no-`cp.async` baseline** — same numeric output, measure throughput gain
- [ ] **`F-RFC067-CP-ASYNC-PERF`** — throughput delta documented (≥ 1.3× target)

---

## 3 · Mid-term (deferred, scoped but multi-cycle)

### 3a — Additional dtypes

- [ ] **bf16 full silicon validation** (depends on 2c)
- [ ] **tf32 support** — `mma.sync.aligned.row.col.m16n16k8.f32.tf32.tf32.f32` for fp32 acceleration
- [ ] **int8 / int4** — quantization-friendly types; `dp4a` / `dp2a` instructions
- [x] **fp8 e4m3 / e5m2** (Hopper sm_90+) — codegen scaffold landed (RFC 068 §3): `NVPTX_RKIND_F8_E4M3` / `_F8_E5M2` constants + `%fe3<id>` / `%fe5<id>` reg banks (silicon-canonical `.b8` container per PTX ISA §5.4.1 + §9.7.13.5) + classifier short-circuit on `.f8_e4m3` / `.f8_e5m2` precision tag + `ld.global.b8` / `st.global.b8` ld/st dispatch + Case 26/27 lower_test (ld/st round-trip, bank-isolation negative guard). **No silicon fire** — fp8 WMMA mnemonic family (`wmma.mma.sync...e4m3.e4m3.f32`) + sub-byte ABI (kernel-arg packing, addr alignment) + parser-side `@f8_*` named-type grammar are follow-on cycles.
- [ ] **posit** — custom dtype emission (lattice-friendly arithmetic; experimental)
- [ ] **MXFP4 / NVFP4** — Blackwell sm_120+ dtypes if applicable to RTX 5070

### 3b — Tensor Core families beyond canonical

- [ ] **bf16×bf16→f32** family — flip `_nvptx_wmma_mnemonic_family` selector
- [ ] **f16×f16→f16** family — accumulation in `.f16` (lower precision)
- [ ] **tf32×tf32→f32** (Ampere+) — TF32 default precision GEMM
- [ ] **fp8 wgmma** (Hopper sm_90+) — `wgmma.mma_async` (asynchronous warp-group)
- [ ] **wgmma 64x64x16, 64x128x16** large tiles — larger working tile geometry
- [ ] **m8n8k16 / m16n8k8** non-standard shapes — flexible mnemonic table

### 3c — Memory hierarchy + addressing

- [ ] **`.shared` register-tiling helpers** — auto-staging on `gpu_*` op patterns
- [ ] **`.local` scratch space** — register-spill destination for large kernels
- [ ] **`.const` constant bank** — for kernel-invariant LUTs
- [ ] **`ld.cs` / `ld.lu` cache hints** — streaming / last-use semantics
- [ ] **TMA (Tensor Memory Accelerator) sm_90+** — `cp.async.bulk.tensor.<dim>d.shared.global`
- [ ] **Async barriers** — `mbarrier.init`, `mbarrier.arrive`, `mbarrier.wait`

### 3d — Optimization passes

- [ ] **Unroll factor>4 with register-pressure analysis** — refuse factor=N if predicted register count > 64
- [ ] **Loop-carried dependency analysis** — true LCD detection (currently trusts user)
- [ ] **Loop fusion** — adjacent kernels with shared address → single launch
- [ ] **Software pipelining** — interleave K-loop iterations
- [ ] **Constant folding through PTX** — known-constant operands → immediate
- [ ] **Dead-code elimination** — operations whose results are never read
- [ ] **Register allocation** — proper graph coloring (currently 1:1 Local→reg)
- [ ] **Polyhedral / affine loop transformation** — far-future advanced opt

### 3e — Source-level features (`@gpu_kernel` ergonomics)

- [ ] **`@gpu_kernel` attribute parse** — currently honored at lowering; verify parser surface
- [ ] **`@shared` annotation** — declare a `let` as shared-memory-resident
- [ ] **`@warp_intrinsic` annotation** — opt-in warp-shuffle intrinsics
- [ ] **`gpu_launch` builtin** — host-side `gpu_launch<<<grid, block>>>(kernel, args...)` lowering
- [ ] **`gpu_launch_async` / `gpu_event`** — CUDA stream + event API equivalents
- [ ] **`gpu_sync()` host-side** — `cudaDeviceSynchronize` wrapper
- [ ] **Source-level `gpu_atomic_*` family** — atomic ops covering add/cas/exch/min/max
- [ ] **Source-level `gpu_block_*` reductions** — sum / max / argmax via `bar.sync` + shared

### 3f — Multi-vendor (downstream — orthogonal to NVPTX)

- [ ] **HIP/AMD ROCm backend** — `gfx*` target dispatch
- [ ] **Metal Performance Shaders** — Apple Silicon GPU (`@gpu_kernel` → MSL or AIR)
- [ ] **Intel oneAPI / Level Zero / SPIR-V** — Intel iGPU / Xe substrate
- [ ] **WebGPU / SPIR-V** — browser substrate
- [ ] **Cross-vendor abstraction layer** — shared IR pre-target

---

## 4 · Performance benchmarking + competitive positioning

### 4a — Throughput baselines (vs vendor)

- [ ] **HGEMM throughput** — hexa-emit vs cuBLAS HGEMM on identical (M,N,K)
- [ ] **SGEMM throughput** — hexa-emit vs cuBLAS SGEMM
- [ ] **FP64 GEMM** — hexa-emit vs cuBLAS DGEMM
- [ ] **vec-add bandwidth** — hexa-emit vs CUDA stream `cudaMemcpy` (memory-bound)
- [ ] **kernel-launch overhead** — hexa-emit vs CUDA driver native (microseconds)

### 4b — End-to-end workload (flame integration)

- [x] **flame d=768·12L transformer 1 step wall** — hexa-emit (forge) **20-43% faster** vs PyTorch eager (memory: `project_flame_phase4d9_closure`, commit `28e9d648`)
- [ ] **flame d=4096 LLaMA-3 8B inference latency** — single-token autoregressive
- [ ] **flame mixture-of-experts dispatch** — sparse expert routing on GPU
- [ ] **flame flash-attention 2 fused kernel** — vs `xformers.ops.memory_efficient_attention`

### 4c — vs alternative GPU compiler stacks

- [ ] **vs Triton** — same kernels in hexa vs Triton DSL
- [ ] **vs Mojo** — heavy GPU kernels in hexa vs Mojo MAX
- [ ] **vs Halide-GPU** — algorithm + schedule split comparison
- [ ] **vs ThunderKittens** — single-file abstraction over wmma
- [ ] **vs CUTLASS** — template-based GEMM library

### 4d — vs cuBLAS-using stacks (where hexa structural advantage applies)

- [ ] **PyTorch eager (uses cuBLAS+cuDNN+ATen)** — already partially measured (flame 4-D-9 closure)
- [ ] **JAX (XLA-based; uses cuBLAS via XLA)** — comparable architecture, more aggressive fusion
- [ ] **TensorFlow eager** — older but still widely deployed
- [ ] **MLX (Apple ML)** — Metal-based stack on M-series
- [ ] **TinyGrad** — minimalist Python-based codegen

---

## 5 · Niches where hexa structurally beats cuBLAS (potential moat)

### 5a — Fusion that cuBLAS can't do

- [ ] **GEMM + epilogue fusion** — GEMM + bias_add + ReLU + dropout in single kernel (cuBLAS-LT does some, but limited)
- [ ] **Attention scoring fusion** — Q@K^T + softmax + V@ in single kernel (flash-attn pattern)
- [ ] **MoE dispatch + GEMM + reduce** — single kernel from gate to output
- [ ] **LayerNorm + GEMM fusion** — pre-layer-norm fused with GEMM weights
- [ ] **AdamW step fusion** — optimizer + parameter update fused with gradient compute

### 5b — Compile-time specialization

- [ ] **Static shape specialization** — known-(M,N,K) kernels avoid all runtime branches
- [ ] **Dead-output elimination** — masked outputs / pruned channels removed at compile time
- [ ] **Sparsity-pattern specialization** — block-sparse / structured-sparse layouts as compile-time facts
- [ ] **Mixed-precision auto-selection** — picker chooses dtype per layer based on compile-time error analysis

### 5c — Custom dtypes / non-IEEE arithmetic

- [ ] **n=6 lattice primitives** — RFC 057 / hexa-arch chip — non-binary lattice math on GPU
- [ ] **Posit arithmetic** — variable-precision posit emit
- [ ] **Interval arithmetic** — error-bounded compute
- [ ] **Stochastic rounding** — quantization-friendly random rounding

### 5d — Whole-program autograd-aware

- [x] **flame `ag_tape` / `ag_derive`** — already SD1-SD6 landed (PRs in main history)
- [ ] **GPU kernel fusion across autograd boundaries** — forward + backward kernels fused
- [ ] **Compile-time gradient symbolic simplification** — vs PyTorch's autograd runtime tape

### 5e — Non-NVIDIA hardware

- [ ] **Apple M-series Metal Performance Shaders** — Apple-silicon GPUs (currently flame uses CPU on M-series)
- [ ] **AMD MI300 / MI350** — ROCm HIP backend
- [ ] **Intel Xe / Arc** — oneAPI / Level Zero
- [ ] **Multi-vendor unified kernel** — same `@gpu_kernel` lowered to multiple backends

### 5f — Launch-overhead amortization (PyTorch eager / library-call stacks lose here)

- [x] **flame d=768·12L transformer — 20-43% faster than PyTorch eager** — already measured (`project_flame_phase4d9_closure`). PyTorch eager pays per-op kernel launch overhead; cuBLAS calls cost ≥5 μs each. Hexa whole-program fusion eliminates the per-op launch path
- [ ] **No PyBind11 / no ATen dispatch overhead** — cuBLAS via PyTorch goes through Python → C++ Tensor → ATen → CUDA stream → cuBLAS handle. Hexa-emit directly compiled into the binary
- [ ] **Static kernel selection** — cuBLAS-LT runtime heuristic picks an algorithm; hexa compile-time selects + bakes the algorithm
- [ ] **Single-shot binary** — no shared library boundary, no `cudaGetSymbolAddress`, no driver-level dispatch table

### 5g — Operator-specific surgical override

- [ ] **Replace one kernel mid-pipeline** — cuBLAS is monolithic API; hexa codegen lets a single GEMM in a chain be hand-tuned while the rest of the pipeline stays unchanged
- [ ] **Per-call-site precision** — same logical GEMM compiled with different precision per call site (cuBLAS forces uniform-handle precision)
- [ ] **Mixed-precision in single kernel** — f16 A × f16 B → f32 accum → bf16 store, all in one kernel; cuBLAS API forces handle-uniform dtype
- [ ] **Custom layout / striding** — cuBLAS has limited stride options; hexa per-kernel custom layouts (e.g., interleaved tile arrangements)

### 5h — Compile-time error / safety analysis

- [ ] **Static overflow check** — known input ranges + arithmetic chain → compile-time overflow risk warning (cuBLAS = runtime only, often silent)
- [ ] **Compile-time NaN-Inf propagation reasoning** — track which operations could introduce NaN/Inf based on input domain analysis
- [ ] **Numerical-stability lint** — flag patterns like `large - small` that lose precision; cuBLAS users have no static signal
- [ ] **Determinism-mode at compile-time** — `@deterministic` annotation switches to deterministic-reduction emit at codegen; cuBLAS's `CUBLAS_PEDANTIC_MATH` is a runtime flag that costs perf

### 5i — Source-level visibility + ergonomics

- [ ] **`.so` blob vs source emit** — cuBLAS is closed-source binary; hexa users see + modify the emit path. Bug-fix loop: cuBLAS = file ticket + wait; hexa = patch source + rebuild
- [ ] **`hexa gpu disasm`** — view exact SASS via `cuobjdump`; cuBLAS too but harder to correlate to user code (the high-level mapping is lost in the closed binary)
- [ ] **Single-language stack** — host + device + autograd all in hexa-lang; cuBLAS-using stacks need Python/C++/CUDA polyglot
- [ ] **No vendor-lock-in path** — hexa codegen targets backend-agnostic IR; cuBLAS hard-binds to NVIDIA

### 5j — Algorithmic flexibility (cuBLAS = limited operator surface)

- [ ] **FlashAttention-style fused softmax + attention** — already a paper-derived pattern; cuBLAS doesn't cover the attention-block pattern directly (xformers / FlashAttention 별도 library)
- [ ] **Online softmax** — single-pass numerically stable softmax (cuBLAS = no softmax at all)
- [ ] **Block-sparse / structured-sparse GEMM** — cuBLAS = dense only (sparse is cuSPARSE 별도)
- [ ] **Custom reductions** — cuBLAS has SUM/MAX; arbitrary reduction (LogSumExp / soft-argmax) hand-written
- [ ] **Top-k / argmax fused with GEMM** — cuBLAS = GEMM only; hexa can fuse arbitrary epilogue

### 5k — Domain-specific kernel libraries (whole-program co-design)

- [x] **flame `ag_*` autograd-aware GEMM family** — SD1-SD10 vjp registry landed; GEMM kernels know about gradients (memory: `project_flame_mk2_cycle_2026_05_19`)
- [ ] **sim_universe lattice GEMM** — non-binary lattice arithmetic on GPU (RFC 057 bridge)
- [ ] **quantum amplitude-update kernels** — `stdlib/quantum` state-vector simulation (cuBLAS = no amplitude ops)
- [ ] **flame layer-fused training kernel** — forward + backward + AdamW + grad-clip in single kernel emit
- [ ] **NN-specific HEXA primitives** — `softmax`, `layer_norm`, `RoPE`, `swiglu` as first-class compiler-aware ops

### 5l — Edge / embedded / standalone deployment

- [ ] **Standalone cubin embed** — `hexa build` produces a binary with embedded `.cubin`; no separate cuBLAS .so dependency
- [ ] **AOT compilation** — kernel compiled once at build time; no runtime cuBLAS JIT
- [ ] **Multi-arch fat binary** — embed PTX for sm_70 + sm_80 + sm_90 in one cubin via hexa codegen
- [ ] **NVIDIA-runtime-free deployment** — minimal driver-only deployment surface (no cuBLAS/cuDNN required)
- [ ] **Containerized cubin** — single-binary container without `libcublas.so.12` dependency

### 5m — Measured wins to-date (g3-honest claims)

- [x] **flame d=768·12L 1-step wall**: hexa-emit 191-268s vs PyTorch-eager 336.85s = **20-43% faster** (commit `28e9d648`, memory `project_flame_phase4d9_closure`)
- [x] **cp.async pipelining ~7% slower than no-async at K=64**: honest negative perf measurement (PR #207) — proves the codegen path works + sets the boundary where cp.async overhead amortizes (large K)
- [x] **WMMA + multi-warp grid + multi-K-tile + cp.async + tf32**: 5 distinct WMMA-family kernel patterns all silicon-validated max\|Δ\|=0 vs FP32 reference (PRs #191/#205/#206/#207/#213)
- [x] **HGEMM throughput vs cuBLAS at M=N=K=256**: hexa-emit **4.0960 TFLOPS** vs cuBLAS GemmEx **8.1907 TFLOPS** = **ratio 0.500 ±0.0002** (6-run variance, sub-0.1% std). Closure criterion "≥ 50% of cuBLAS HGEMM" **MET at this shape** (PR #214). Caveat (g3): single shape; at larger M/N/K cuBLAS's k-loop unroll + ILP + shared-memory pipelining advantages compound; this single data point does NOT generalize. Multi-tile cp.async (PR #207) not yet integrated into this perf kernel — natural next-cycle.
- [ ] **HGEMM at M=N=K≥1024**: pending — scale-up + cp.async integration to test if 0.50× ratio holds or degrades at large shapes (where cuBLAS optimizations matter)
- [ ] **Whole-program-fusion ≥ 30% over cuBLAS-using stack on a representative LLM workload** — sustained across model variants (flame d=768 partially measured)

---

## 6 · Verification + safety

### 6a — Numerical

- [ ] **Bit-exact reference** — every emitted kernel compared to a bit-exact reference (cpu)
- [ ] **ULP-bounded checker** — tolerance-aware compare via a small test harness
- [ ] **Determinism mode** — force deterministic reductions (no atomics, ordered K-loop)
- [ ] **Kahan summation in GEMM K-loop** — error-bounded accumulator
- [ ] **NaN / Inf propagation** — verified across f16 / bf16 underflow / overflow

### 6b — Formal / semantic

- [ ] **PTX emit semantic equivalence proof** — Coq/Lean proof that codegen preserves MIR semantics
- [ ] **Register allocation correctness** — formal proof that allocation never aliases live ranges
- [ ] **Loop-unroll preservation** — proof that unrolled CFG ≡ original CFG semantically

### 6c — Runtime safety

- [ ] **Bounds-check elision** — verified safe when guarded
- [ ] **Race-detection** — static analyzer over shared-memory accesses
- [ ] **Memory-ordering** — `bar.sync` / `mbarrier` placement audit

---

## 7 · Ecosystem + observability

### 7a — Profiling / introspection

- [ ] **PTX register-count reporter** — `ptxas -v` integration into `hexa build`
- [ ] **Occupancy estimator** — given kernel + GPU SM, predict theoretical occupancy
- [ ] **Nsight Compute integration** — emit metadata for profiler attach
- [ ] **CUDA Graph API** — `cuGraphLaunch` for multi-kernel graphs
- [ ] **Driver API vs Runtime API** — pick based on use-case

### 7b — Documentation + examples

- [x] **gpu/SPEC.md** — existing spec doc (per AGENTS.tape mentions)
- [x] **inbox/rfc_drafts_2026_05_20/rfc_06[7-9]_*.md** — 3 RFC drafts
- [ ] **GPU.md** (this file) — domain SSOT roadmap
- [ ] **Tutorial — "first GPU kernel in hexa"** — beginner's onramp
- [ ] **Cookbook — "GEMM patterns from naive to wmma"** — performance evolution

### 7c — Toolchain ergonomics

- [ ] **`hexa gpu build`** — single-command path: source `.hexa` → PTX → cubin
- [ ] **`hexa gpu fire <kernel> <host>`** — single-command remote fire
- [ ] **`hexa gpu profile`** — wraps Nsight Compute
- [ ] **`hexa gpu lint`** — static check for `@gpu_kernel` correctness
- [ ] **`hexa gpu disasm`** — SASS-level disassembly via `cuobjdump`

---

## 8 · Far-future / research questions

### 8a — Beyond NVPTX

- [ ] **PTX → SASS direct emit** — bypass ptxas, hand-emit GPU machine code
- [ ] **SPIR-V emit** — open-standard GPU IR
- [ ] **MLIR integration** — bridge to upstream MLIR (controversial — vs hexa-native principle)
- [ ] **Cooperative groups API** — multi-block synchronization

### 8b — Auto-tuning

- [ ] **Search-based tile-size selection** — autotune over block/grid/unroll
- [ ] **ML-based scheduling** — neural-net cost model for codegen choices
- [ ] **Random restart for kernel synthesis** — try N variants, pick best

### 8c — Specialized hardware

- [ ] **NVIDIA Grace-Hopper** — CPU+GPU unified memory (`MemcpyDtoH` becomes a no-op)
- [ ] **NVLink / NVSwitch** — multi-GPU collective primitives
- [ ] **AMD Instinct MI300A** — APU-style hexa kernel
- [ ] **Intel Ponte Vecchio** — Xe Matrix Extensions

### 8d — Esoteric / experimental

- [ ] **Quantum GPU bridge** — `stdlib/quantum` + GPU acceleration for state-vector simulation
- [ ] **Lattice n=6 GPU emit** — RFC 057 hexa-arch substrate, but on GPU
- [ ] **Neuromorphic compatibility** — `stdlib/sim_universe` substrate on GPU
- [ ] **Reversible computing primitives** — `gpu_uncompute` for memory-efficient autograd

---

## 9 · Cross-axis dependencies

```
                          [GPU.md root]
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
    [§12 P4+ chain]       [flame stack]      [forge GPU substrate]
   (codegen→silicon)    (NN training, north-    (raw cuBLAS/CUDA layer
        │              star ① measured-PASS)      below flame)
        │                     │                     │
        └─────────┬───────────┴─────────────────────┘
                  │
              [hexa-arch chip]
              (lattice primitives,
              future n=6 ASIC; GPU is
              an interim substrate)
```

- North-star ① (NN stack) consumes the GPU substrate built here.
- North-star ② (self-host) is orthogonal (CPU-side; not blocked by GPU).
- North-star ③ (n=6 lattice) — GPU is the INTERIM execution path; final substrate is custom silicon (hexa-arch).

---

## 10 · Closure criteria (when is GPU substrate "done"?)

The GPU substrate has finite scope. Closure ≠ "all features"; closure = "the listed north-star metrics are silicon-measured PASS":

- [x] **§12 P4+ codegen end-to-end** — hand-emit path works on silicon (today's session)
- [ ] **§12 P4+ source-to-silicon e2e** — full `.hexa` source → silicon (next layer 2a)
- [x] **flame d=768 transformer beats PyTorch eager wall** — already measured (project_flame_phase4d9_closure)
- [ ] **flame d=4096 GPT-3 class beats PyTorch eager**
- [ ] **Multi-vendor: ROCm or Metal kernel parity** — proves architectural independence
- [x] **Multi-tile WMMA throughput ≥ 50% of cuBLAS HGEMM** — vendor-comparable on specific kernels: M=N=K=256 ratio = 0.500 ±0.0002 (PR #214 + variance commit `05a85bb9`); caveat: single shape, large-M/N/K scale-up pending
- [ ] **Whole-program-fusion measurable advantage** — at least one workload where hexa beats cuBLAS-using stack by ≥ 30%
- [ ] **n=6 lattice GPU emit smoke** — bridge to north-star ③

Once 4-6 of these check off, the GPU substrate phase is "done enough" to consume from the higher-level NN / agent / chip layers without re-touching.

---

## 11 · Brainstorm-overflow (random adjacent ideas, low priority)

- [ ] **CUDA Persistent Threads pattern** — long-running kernels via cooperative groups
- [ ] **Warp specialization** — different warps doing producer/consumer work
- [ ] **Async memory scoreboard** — software pipeline through async copies
- [ ] **Mixed-arch fat binary** — embed PTX for sm_70/sm_80/sm_90 in one cubin
- [ ] **`hexa gpu repl`** — interactive PTX shell for kernel exploration
- [ ] **GPU memory allocator** — `cuMemAlloc` wrapper with arena/pool
- [ ] **Multi-process GPU sharing** — MPS-aware kernels
- [ ] **GPU error recovery** — `cudaDeviceReset` after kernel crash
- [ ] **`@gpu_kernel` const-arg specialization** — kernel templates over compile-time consts
- [ ] **Multi-GPU NCCL bridge** — `ncclAllReduce` / `ncclSend` / `ncclRecv` lowering
- [ ] **Persistent kernel + work-stealing queue** — task-scheduler kernel
- [ ] **Triton-style block-level abstraction** — at higher layer than PTX, lower than `@gpu_kernel`
- [ ] **GPU shared-memory atomics** — `atom.shared.*` variants
- [ ] **HBM bandwidth saturation kernel** — pure memory-bound benchmark
- [ ] **L2 cache awareness** — `evict_*` cache-modifier hints
- [ ] **Tensor Layout transformation** — `ldmatrix.sync.aligned.x4` for fragment-load pipelining
- [ ] **Dynamic parallelism** — kernels launching kernels (CUDA Dynamic Parallelism v2)
- [ ] **CUDA streams + events** — async kernel pipelines
- [ ] **CUDA cooperative groups** — `this_grid()`, `this_thread_block()` semantics
- [ ] **CUDA Graphs (cuGraph)** — DAG-of-kernels API
- [ ] **CUDA Toolkit version detection** — codegen flag adjusting per CUDA version
- [ ] **Driver capability query** — runtime detection of sm_*** features
- [ ] **`gpu_print` builtin** — `printf` from device side
- [ ] **NVCC-flag bridge** — pass nvcc flags through `hexa gpu build`
- [ ] **Compute-Sanitizer integration** — automated race/leak/out-of-bounds detection
- [ ] **CUDA Memcheck integration** — out-of-bounds catches
- [ ] **CUPTI profiler** — counter sampling
- [ ] **MIG (Multi-Instance GPU) awareness** — partitioned A100 / H100 / B200
- [ ] **Confidential Computing on Hopper** — `cuMemEncrypt*` API
- [ ] **Driver API vs Runtime API differential** — pros/cons matrix
- [ ] **vGPU / virtualization-aware code** — hypervisor partition awareness
- [ ] **GPUDirect RDMA** — direct device-to-device transfer
- [ ] **GPUDirect Storage** — direct NVMe → GPU DMA
- [ ] **NVLink topology query** — for multi-GPU placement
- [ ] **GPU power management** — `cudaDeviceSetCacheConfig` / `cuFuncSetCacheConfig`
- [ ] **GPU thermal throttling awareness** — adapt to clock variation
- [ ] **`gpu_assert` builtin** — device-side assertion
- [ ] **Symbolic execution of GPU kernel** — formal verification of correctness
- [ ] **Fuzz-test generator for GPU kernels** — adversarial input search
- [ ] **JIT specialization at first launch** — record actual input shapes, specialize on 2nd
- [ ] **Persistent-cache for compiled kernels** — `cu_jit_cache` integration

---

## 12 · Cross-references (governance / non-overlapping SSOT)

- `compiler/PLAN.md` — chronological cycle log (this file is forward-looking; PLAN is the past)
- `gpu/SPEC.md` — formal specification per RFC 055 §6
- `inbox/rfc_drafts_2026_05_20/rfc_06[7-9]_*.md` — three Shape-B RFCs
- `inbox/fires/rfc06[7-9]_p4_*/` — silicon-fire artifacts (today's PRs #189/#190/#191)
- `tool/r06[7-9]_p4_host.c` — host launchers for the silicon fires
- `compiler/codegen/nvptx_target.hexa` — main codegen file (~3500 lines as of 2026-05-20)
- `compiler/codegen/nvptx_ptx_ops.hexa` — PTX opcode constants
- `compiler/codegen/nvptx_lower_test.hexa` — 25-case smoke suite
- `stdlib/flame/` — NN training stdlib consumer
- `self/forge/` — GPU compute substrate (existing CUDA+CUTLASS layer below NVPTX path)
- `AGENTS.tape` `@D g_plan_consolidation` — single-PLAN.md SSOT rule
- `AGENTS.tape` `@D g3` — honesty-obligation (no over-claim)
- `AGENTS.tape` `@D f1`/`@D f2` — no LLVM, no C-transpile (preserved every commit)

---

## 13 · Status snapshot (auto-updated each cycle)

- **lower_test cases**: 25/25 PASS
- **Silicon-fires on origin/main**: **9** (PR #82 FP64 + #189 f16 + #190 unroll byte-eq + #191 wmma single-tile + #203 bf16 + #205 wmma multi-K-tile + #206 wmma 16-warp grid + #207 wmma cp.async pipelined + #213 tf32)
- **§12 P4+ codegen-side closures**: 3/3 RFCs done
- **§12 P4+ silicon-side closures**: 3/3 RFCs done + WMMA family expansion (single + multi-K + multi-warp + cp.async)
- **§5 cuBLAS-advantage categories**: 13 (5a-5m; 3 with measured-PASS data)
- **Continuous gates**: F5 / F6 / F7 all PASS through every commit
- **Next layer recommended**: §2a source-to-silicon e2e (multi-session, requires in-hexa compiler self-host on NVPTX path; see §2a finding) — or §3 mid-term (dtypes / opt passes / source-level ergonomics)

---

## Log

(append-only chronological log per `AGENTS.tape` domain-meta-domain convention; head + `---` + `## Log` at bottom)

### 2026-05-20 — GPU.md created (this file)

Domain SSOT for the GPU codegen substrate created at end-of-day on the §12 P4+ TRIPLE silicon-fire day (PR #189 RFC 068 + PR #190 RFC 069 + PR #191 RFC 067 + PR #193 codegen↔silicon reconcile + PR #194 closure entry).

§1 (Completed) reflects all measured-PASS state through 2026-05-20 evening.

§2 lists 5 concrete next-layer cycles, each scope-bounded (1-2 cycle worth of work).

§3-§11 enumerate the full brainstorm-to-exhaustion roadmap — dtypes, Tensor Core families, memory hierarchy, optimization passes, source-level ergonomics, multi-vendor, performance benchmarking, niches where hexa structurally beats cuBLAS, verification, ecosystem, far-future, brainstorm-overflow.

§13 (Status snapshot) is the current dashboard — update by editing in place each cycle (not append-only).

This Log section is append-only per the domain-meta-domain SSOT convention (head + `---` + `## Log` at bottom; new entries chronological at the bottom of the Log).

### 2026-05-20 — sec 5 expanded with cuBLAS-advantage categories (5f-5m)

After today's 8 silicon-fires + GPU.md initial draft (PR #199), user
asked: "GPU.md 에 cuBLAS 보다 장점일수있는부분도 모두 기록되있지?"

Added 7 new subsections (5f through 5m) covering:
- 5f: Launch-overhead amortization (PyTorch eager loses here — already
  partially measured by flame d=768)
- 5g: Operator-specific surgical override
- 5h: Compile-time error / safety analysis
- 5i: Source-level visibility + ergonomics
- 5j: Algorithmic flexibility (FlashAttention / online softmax /
  block-sparse / custom reductions / top-k fusion)
- 5k: Domain-specific kernel libraries (flame ag_* / sim_universe
  lattice / quantum amplitude / layer-fused training)
- 5l: Edge / embedded / standalone deployment
- 5m: Measured wins to-date (g3-honest claims)

Pre-existing 5a-5e (fusion / compile-time specialization / custom
dtypes / autograd-aware / non-NVIDIA hardware) retained verbatim.

Section 5 is now the canonical "where hexa beats cuBLAS structurally"
reference — split into 13 categories total with measured + projected
items distinguished by [x] vs [ ].

### 2026-05-20 (evening cont.) — sec 2a finding + status snapshot post-8-fires

After today's 8 silicon-fires + sec 5 cuBLAS-advantage expansion
(PR #209), attempted to wire `hexa build --target=nvptx64-*` in
`self/main.hexa::cmd_build`. Finding: the wiring is NOT a one-line
target-string add. The substantive gap is the build pipeline itself
(see sec 2a finding above) — `hexa_v2` (bootstrap transpiler) emits
C, not PTX; the in-hexa compiler has the NVPTX codegen but is not
the build path for `hexa build` today.

Session conclusion: option (C) — the out-of-band emit-driver pattern
from PR #82 successfully delivered all 8 silicon-fires today; the
`hexa build` wiring (options A/B) is a multi-session campaign tied
to north-star ② (compiler self-host on NVPTX, currently CPU only).

sec 13 status snapshot updated:
- Silicon-fires: 4 -> 8 (added bf16 #203, wmma multi-K #205,
  wmma 16-warp grid #206, wmma cp.async #207)
- sec 5 cuBLAS-advantage categories: 5 -> 13 (added 5f-5m)
- Next-layer recommendation: defer sec 2a; pick from sec 3 mid-term
  or new lane (dtypes / opt passes / source-level ergonomics)

Total session metric: 32 PRs landed end-to-end + 8 silicon-fires +
GPU.md domain SSOT created and expanded. lower_test smoke 9 -> 25.
