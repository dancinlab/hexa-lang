<!-- @canonical: ~/core/canon/domains/compute/gpgpu/gpgpu.md -->
<!-- @extracted: 2026-05-08 -->
<!-- @snapshot_policy: 6-month-stale upstream of canon, per CLAUDE.md canon_pointer -->
<!-- gold-standard: shared/harness/sample.md -->
---
domain: chip-gpgpu-n6
requires:
  - to: chip-architecture
  - to: chip-isa-n6
  - to: chip-accel
  - to: compiler-os
---

<!-- @own(sections=[WHY, COMPARE, REQUIRES, STRUCT, FLOW, VERIFY, EVOLVE], strict=false, order=sequential, prefix="§") -->

# GPGPU n=6 — vendor-agnostic programming model verb (HEXA-GPGPU)

> **Verb group**: accelerator. **Sister verbs**: `npu_n6/`, `pim/`,
> `photonic/`. **Distinction**: the other accelerator verbs are silicon
> blocks (NPU MAC array, PIM in-memory unit, photonic optical engine).
> **GPGPU is a programming model** that runs on top of GPU silicon —
> the verb here is the *projection layer*, not a chip block.
>
> **Canon SSOT**: `~/core/canon/domains/compute/gpgpu/gpgpu.md`. This
> file is a 6-month snapshot; treat canon as authoritative.

## §1 WHY (n=6 invariant kernel for 6 ecosystems)

GPU silicon today divides into 6 ecosystems — NVIDIA (CUDA), AMD (HIP),
Intel/Khronos (SYCL), Khronos legacy (OpenCL), Apple (Metal), W3C
(WebGPU). Each ships a different host API + kernel language + IR. The
**hardware they target is structurally similar**: a hierarchical SIMT
executor with a 4-tier memory hierarchy and a barrier sync model. **The
programming models diverge much more than the silicon does.**

When the projection is fixed by **n=6 arithmetic derivation**, three
forms of waste disappear:

1. **Re-port collapse**: σ(6)=12 source-axes × τ(6)=4 lifecycle stages =
   J₂=48 cells projected onto 6 ecosystems → kernel written once, projected
   N times mechanically — no rewrite. ← σ(6)=12, τ(6)=4
2. **IR substrate consolidation**: SPIR-V (Khronos) + PTX (NVIDIA) +
   AIR (Apple) + WGSL (W3C) lower into 2 substrates (SPIR-V ‖ PTX) with
   per-vendor lowering. φ=2 IR axis is exhaustive. ← φ(6)=2
3. **AI-native kernel synthesis**: with the 6 invariant axes named, "one
   utterance → kernel-on-N-targets" becomes mechanical; the target search
   space is 6, not 6× per-vendor freedom. ← OEIS A000005

| Effect | Status quo | After HEXA-GPGPU projection | Felt change |
|---|---|---|---|
| Port surface | per-ecosystem rewrite (×6) | source-once, project-6 | 6× developer headcount equivalent |
| Tooling | 6 toolchains (profiler/debugger/sanitizer ×6) | 1 IR audit, N codegen tests | profiler/debugger reusable |
| IR substrate | PTX ‖ AMDGCN ‖ SPIR-V ‖ AIR ‖ WGSL → Tint | SPIR-V ‖ PTX (φ=2 substrate) | 1 IR audit, N backends |
| Talent | per-ecosystem apprenticeship | model-shaped | hiring pool union |
| Library reuse | cuBLAS ‖ rocBLAS ‖ oneMKL ‖ MPS ‖ ... | 1 BLAS façade, 6 backends | written once |
| Spec churn | 6 release calendars | 1 rev table, 6 rows | 1 changelog |

**One-sentence summary**: every shipped GPGPU model is a projection of a
single invariant kernel + 4-tier memory hierarchy + barrier set; naming
the kernel separates *what the program means* from *which vendor runs it*.

## §2 COMPARE (the n=6 projection)

| # | Model | Vendor | Latest | Date | Kernel lang | IR | Memory | Sync |
|---|-------|--------|--------|------|-------------|-----|---------|------|
| 1 | CUDA | NVIDIA | 13.2 | 2026-03-04 | CUDA C++ | PTX → SASS | 6-tier (CC≥9.0 cluster) | `__syncthreads`, cluster sync |
| 2 | HIP/ROCm | AMD | 7.2.53211 | 2026 | HIP C++ | LLVM → AMDGCN | 4-tier | `__syncthreads` |
| 3 | SYCL | Khronos | 2020 rev 11 | 2025-11-07 | SYCL C++ (single-source) | SPIR-V | 4-tier | `nd_item::barrier` |
| 4 | OpenCL | Khronos | 3.1.0 | 2026-05-05 | OpenCL C / C++ | SPIR-V | 4-tier | `barrier` |
| 5 | Metal | Apple | 4 (MSL 4) | 2025-10-23 | MSL (C++14) | AIR | 4-tier + tensor | `threadgroup_barrier` |
| 6 | WebGPU | W3C | CR Draft (v2 dev) | 2026 | WGSL | WGSL→SPIR-V/MSL/HLSL | 4-tier | `workgroupBarrier` |

**Cross-cutting (φ=2 IR substrate, not in the 6)**: SPIR-V (Khronos
common IR; consumed by SYCL, OpenCL, WebGPU-via-Tint, and as a HIP/Metal
inter-translation target), PTX (NVIDIA virtual ISA; consumed by CUDA and
SYCL/DPC++ NV path).

### §2.1 Coverage matrix

| Model | NVIDIA | AMD | Intel | Apple | mobile | browser | CPU |
|-------|:------:|:---:|:-----:|:-----:|:------:|:-------:|:---:|
| CUDA  | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| HIP   | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| SYCL  | ✓ | ✓ | ✓ | △ | △ | ✗ | ✓ |
| OpenCL | ✓ | ✓ | ✓ | △ | ✓ | ✗ | ✓ |
| Metal | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ | ✗ |
| WebGPU | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | △ |

**Read this matrix as**: SYCL is the widest portable substrate excluding
the browser; WebGPU is the widest *including* the browser; CUDA and
Metal are the two non-portable end-points.

## §3 REQUIRES

| Dependency | Direction | Why |
|---|---|---|
| `chip-architecture` | upstream | SIMT/SIMD silicon, SM/CU/EU definitions |
| `chip-isa-n6` | upstream | n=6 ISA for hexa-chip-native GPU instruction projection |
| `chip-accel` | sibling | accelerator group umbrella |
| `compiler-os` | downstream | LLVM / SPIR-V / PTX lowering, JIT, sanitizer |
| `chip-interconnect` | adjacent | host-device bandwidth (PCIe/CXL/NVLink) |
| `chip-hbm` | adjacent | global-memory bandwidth budget |
| `chip-thermal-power` | adjacent | per-kernel power, occupancy tuning |

## §4 STRUCT (n=6 invariant axes)

The invariant kernel = **6 axes that every kernel launch turns**:

| # | Axis | What it controls | n=6 role |
|---|------|------------------|----------|
| 1 | **grid shape** | total work-item count, 1D/2D/3D | σ direction |
| 2 | **workgroup size** | co-scheduled thread count, shared memory + barrier domain | σ subdivision |
| 3 | **memory tier** | which of 4 tiers a buffer lives in | τ-tier (4 tiers) |
| 4 | **barrier scope** | which set of threads sync | τ-stage |
| 5 | **launch dependency** | command-queue DAG, event/fence | τ-DAG |
| 6 | **sub-group width** | SIMD lane width inside workgroup | n=6 lane |

**These 6 axes are the contract surface** — exactly n=6.

### §4.1 Memory hierarchy (τ(6)=4 tiers)

| Tier | Scope | Latency (cycles) | Bandwidth (typical 2026) |
|------|-------|------------------|---------------------------|
| 0 — register / private | per-thread | 1 | per-lane |
| 1 — group / shared | per-workgroup | ~20 | TB/s aggregate, ≤256KB SRAM (Blackwell B200) |
| 2 — device / global | per-device | 200–600 | 3–8 TB/s (HBM3E) |
| 3 — constant / uniform | per-device, RO | ~5 (cached) | cache-hit dependent |

τ=4 tiers exactly. Plus host-device substrate (NVLink5: up to 1800 GB/s,
PCIe Gen6, CXL).

### §4.2 Lifecycle (τ(6)=4 stages × φ(6)=2 modes)

```
   τ stages           φ modes
   ──────────         ──────
   1. compile         digital (compute pipeline)
   2. enqueue         analog  (graphics/raster pipeline)
   3. dispatch
   4. retire
```

τ × φ = 8 lifecycle×mode cells. GPGPU exercises (compile/enqueue/
dispatch/retire) × digital. Metal 4 + WebGPU exercise compute+graphics
interop (both modes).

### §4.3 J₂=48 projection

```
σ(6) · φ(6) = n · τ(6) = J₂
   12    ·  2  =  6  ·   8 = J₂′ = 96  (compute axes)
   12    ·  2  =  6  ·   4 = J₂  = 48  (programming-model cells)
   12    ·  2  =      24       = J₂_hexa-chip  (parent invariant)
```

GPGPU-specific J₂′ = 6 vendors × 4 lifecycle stages × 2 modes = **48** —
extends the parent J₂=24 lattice by the 2-mode (compute/graphics) bit
that other accelerator verbs collapse.

| Symbol | Value | Role | GPGPU projection |
|---|---|---|---|
| σ(6) | 12 | sigma — cardinality bin | 6 vendors × 2 IR substrates (SPIR-V, PTX) |
| τ(6) | 4 | tau — state quartet | compile / enqueue / dispatch / retire |
| φ(6) | 2 | phi — verdict bit | digital (compute) / analog (graphics interop) |
| J₂ | 24 | parent ceiling | 24 (vendor × lifecycle × mode) — for hexa-chip parity |
| J₂′ | 48 | extended ceiling | 6 × 4 × 2 — GPGPU-specific |

## §5 FLOW

A vendor-agnostic kernel launch projected onto each of the 6 models. See
canon `compute/gpgpu/gpgpu.md §5.1` for full per-vendor source code
(vector add, N=2²⁰, fp32). hexa-chip side records only the projection
DAG:

```
              ┌──────────────────────────┐
              │ vendor-agnostic kernel    │
              │   axes 1–6 (§4)           │
              └────────────┬─────────────┘
                           │  projection
        ┌──────┬──────┬────┴────┬──────┬──────┬──────┐
       CUDA   HIP    SYCL   OpenCL  Metal  WebGPU
        │      │      │        │      │      │
       PTX  AMDGCN  SPIR-V  SPIR-V   AIR    WGSL
        │      │      │        │      │      │
        ▼      ▼      ▼        ▼      ▼      ▼
       NVIDIA AMD    Intel/AMD/NV    Apple   Browser/native
```

**Read this as**: one source kernel, six target IRs, six native
ecosystems. The projection is finite and mechanical; it is not a
compiler optimisation problem, it is a syntactic rewrite parametrised
by axes 1–6.

## §6 VERIFY (falsifiers)

- **F-CHIP-5 — GPGPU n=6 projection sufficiency**: every kernel launch
  in any of the 6 ecosystems is fully specified by axes 1–6 (§4) plus
  the kernel body. *Disprove* by exhibiting a kernel launch that
  requires a 7th axis.
- **F-CHIP-5a — Memory-tier 4-tier minimality**: every persistent
  buffer in any of the 6 models lives in exactly one of the τ=4 tiers
  (§4.1). *Disprove* by exhibiting a tier (e.g., Metal 4 tensor-typed,
  WebGPU storage-RO-flag) that needs a 5th tier rather than parameterising
  one of the 4.
- **F-CHIP-5b — IR substrate sufficiency (φ=2)**: every kernel lowers
  to SPIR-V or PTX; the two together cover all 6 backends. *Disprove*
  by exhibiting a kernel that lowers to neither without lossy rewrite.
- **F-CHIP-5c — Concept rosetta completeness**: every concept used in
  any of the 6 models maps to exactly one row of canon §2.2. *Disprove*
  by exhibiting a model concept that does not project onto canon §2.2.

F-CHIP-5 joins F-CHIP-1/2/3/4 in `.roadmap.hexa_chip §A.4`.

## §7 EVOLVE

### §7.1 Tensor-typed memory (Metal 4, CUDA TMA, WGSL future)

Metal 4 introduced tensors as first-class types in the API and shading
language. CUDA Hopper introduced TMA + async-bulk-copy. WGSL has tensor
extensions in flight. The τ=4 memory model may extend to a 5th *tile*
tier (a typed view over group memory). **Currently parameterised as a
view, not a 5th tier — falsifier F-CHIP-5a tracks this.**

### §7.2 Cluster / multi-CTA sync (CUDA CC≥9.0, AMD analogues)

Hopper's thread-block clusters share distributed shared memory; AMD
CDNA3+ has analogous cooperative scheduling. Axis 4 (barrier scope)
already enumerates cluster sync; production confirmation pending across
vendors.

### §7.3 Heterogeneous + neural integration

Metal 4 inlines NN inference into shaders. CUDA + Tensor Cores collapse
GEMM into kernel intrinsics. SYCL rev 11's `khr_default_context` reduces
multi-device context overhead. The programming-model boundary is *expanding*
into ML graph execution — historically above the programming model.

### §7.4 Browser as the seventh ecosystem

WebGPU is now in all four major browsers (Safari 26 / Chrome / Edge /
Firefox). The browser is the only target with a *sandboxed* execution
model — no raw pointers, bounded resource handles, validation-by-
construction. This constrains the projection layer as a lower-bound on
portability.

### §7.5 Open questions (deferred)

1. **Vulkan Compute** — 7th first-class ecosystem or SPIR-V-deployment
   profile? Current SSOT: latter. Revisit if a Vulkan-native SoC ships.
2. **Mojo / Triton / Pallas** — peer DSL layer (above the 6) or part of
   this verb? Current decision: peer (`compiler-os` axis or future
   `kernel-dsl` verb).
3. **Tensor cores / matrix engines** — 7th axis (5th tier + new barrier)
   or extension of axis 6 (sub-group)? Defer until Metal 4 + CUDA 13
   production telemetry stabilises (~2026-Q4).
4. **Hexa-native GPGPU runtime** — when stdlib/hal v0.3+ adds
   `hal::compute::parallel`, the host-side primitives (kernel launch,
   buffer alloc, queue, sync) become hexa-native; the kernel language
   stays vendor (or projected-to-vendor). Tracks .roadmap.hexa_chip §F.

## §8 References

Canon SSOT: `~/core/canon/domains/compute/gpgpu/gpgpu.md` (§8 has full
web-search citations for spec versions). Snapshot date: 2026-05-08.
