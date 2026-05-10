# GPGPU n=6 (HEXA-GPGPU) — Programming-Model Projection Spec  v0.1

> Companion to `gpgpu_n6/chip-gpgpu-n6.md` (vision spec). Phase F iter 1
> projection-spec sheet — programming-model surface for vendor-agnostic
> GPGPU verb. **This is not a foundry-pitch silicon datasheet** like
> `npu_n6/doc/datasheet_npu_n6.md` — GPGPU is a software programming model.
>
> Status: **paper design, projection-layer skeleton**. Phase F iter 2
> implements one host-side primitive (`hal::compute::parallel::dispatch`)
> in stdlib/hal as the first hexa-native consumer.

## 0. Scope and conformance

| field | value |
|:------|:------|
| product class | GPGPU programming-model projection layer (vendor-agnostic) |
| target spec | source-once, project-6 (CUDA / HIP / SYCL / OpenCL / Metal / WebGPU) |
| n=6 anchors | σ(6)=12 (6 vendors × 2 IR substrates) · τ(6)=4 lifecycle · φ(6)=2 mode · J₂′=48 |
| falsifier | F-CHIP-5 (.roadmap §F.4); 6-axis projection sufficiency |
| scope at v0.1 | spec + projection table; no host-side runtime impl yet |
| out of scope | per-vendor optimisation (occupancy, register pressure, register-spill avoidance — left to vendor compiler) |
| canonical SSOT | `~/core/canon/domains/compute/gpgpu/gpgpu.md` |

## 1. Top-level interface (vendor-agnostic kernel descriptor)

```
              ┌──────────────────────────────────────────────────┐
              │ hexa-native kernel descriptor                     │
              │   axis 1: grid_shape    (u32, u32, u32)           │
              │   axis 2: workgroup     (u32, u32, u32)           │
              │   axis 3: mem_tier_map  [(buffer_id, Tier)]       │
              │   axis 4: barrier_scope BarrierScope              │
              │   axis 5: launch_dep    [event_id] -> event_id    │
              │   axis 6: subgroup_w    u8 (32 ‖ 64, queryable)   │
              │   kernel_body: bytes (SPIR-V ‖ PTX)               │
              └──────────────────────┬───────────────────────────┘
                                     │ projection (one-of-six)
        ┌──────────┬──────────┬──────┴──────┬──────────┬──────────┬──────────┐
       CUDA       HIP        SYCL       OpenCL      Metal     WebGPU
     <<<grid,    hipLaunch  parallel_  clEnqueue  MTLCompute  GPUComputePass
       block>>>  KernelGGL  for(...)   NDRange    Encoder    EncoderDispatch
```

## 2. Memory tier table (τ(6)=4)

| Tier | Vendor names (concept rosetta) | Latency (cyc) | BW (typical 2026) | Backing silicon |
|------|--------------------------------|---------------|--------------------|------------------|
| 0 | CUDA `register` ‖ HIP `register` ‖ SYCL `private` ‖ OpenCL `private` ‖ Metal `thread` ‖ WGSL `private` | 1 | per-lane | SM register file (per-thread alloc, spill to local) |
| 1 | CUDA `__shared__` ‖ HIP `__shared__` ‖ SYCL `local` ‖ OpenCL `local` ‖ Metal `threadgroup` ‖ WGSL `workgroup` | ~20 | TB/s aggregate | on-chip SRAM (≤ 256 KB Blackwell B200, ≤ 228 KB H100) |
| 2 | CUDA `global` ‖ HIP `global` ‖ SYCL `global` ‖ OpenCL `global` ‖ Metal `device` ‖ WGSL `storage` | 200–600 | 3–8 TB/s | HBM3E (HBM4 ramp 2026-Q3) |
| 3 | CUDA `__constant__` ‖ HIP `__constant__` ‖ SYCL `constant` ‖ OpenCL `constant` ‖ Metal `constant` ‖ WGSL `uniform` | ~5 (cached) | cache-hit dependent | constant cache (~64 KB) |

**Substrate (host-device, not a tier)**: PCIe Gen5/6, CXL 3.x, NVLink5
(up to 1800 GB/s, 2026), Infinity Fabric, UltraEthernet — see
`chip-interconnect`.

## 3. IR substrate (φ(6)=2)

| Substrate | Consumed by | Authority | Status (2026-05-08) |
|-----------|-------------|-----------|----------------------|
| SPIR-V | SYCL, OpenCL, WebGPU (via Tint), HIP (via translator), Metal (via translator) | Khronos | active, multiple revs/year |
| PTX | CUDA, SYCL/DPC++ NV path | NVIDIA | active, in lock-step with CUDA toolkit (PTX 8.5 with CUDA 13) |

**Cross-translation matrix** (which IR can lower to which target):

| from \ to | CUDA(SASS) | AMDGCN | Intel(L0) | Apple(AIR) | WGSL | x86 (CPU) |
|-----------|:---:|:---:|:---:|:---:|:---:|:---:|
| SPIR-V    | △ (via PTX or LLVM) | ✓ | ✓ | △ (via translator) | ✓ (Tint reverse) | ✓ |
| PTX       | ✓ | △ (via HIP) | △ | ✗ | ✗ | △ (Pocl/clang) |

✓ = first-class production path. △ = working but not first-class. ✗ =
not supported.

## 4. Lifecycle (τ(6)=4 stages × φ(6)=2 modes)

| Stage | Digital (compute) cost model | Analog (graphics-interop) cost model |
|-------|------------------------------|----------------------------------------|
| 1. compile | source → IR (offline ‖ JIT) | shader compilation incl. raster state |
| 2. enqueue | command-queue insert (host) | render-pass + compute-pass interleave |
| 3. dispatch | device executor consumes | rasteriser + compute units in parallel |
| 4. retire | event/fence signal back to host | swapchain present + compute readback |

φ=2 modes: most GPGPU programs exercise digital only. Metal 4 + WebGPU
exercise both (compute writes a texture, rasteriser reads same frame).

## 5. n=6 invariant lattice projection

```
σ(6) · φ(6)         = n · τ(6) · φ(6) ?
   12   ·  2  = 24    =  6 ·   4   ·  ?
                                    = J₂  = 24 (parent hexa-chip)
                                    = J₂′ = 48 (GPGPU-extended)
```

J₂ = 24 cells (vendor × stage) — parent invariant, used for hexa-chip
falsifier ledger.

J₂′ = 48 cells (vendor × stage × mode) — GPGPU extension, used for
F-CHIP-5 / 5a / 5b / 5c falsifier coverage.

## 6. Safety / quality (paper design)

| concern | mitigation | verify hook |
|---------|-----------|-------------|
| out-of-bounds buffer access | bounds-check at projection layer (all 6 vendors enforce; WGSL strongest) | F-CHIP-5a |
| race on group memory | barrier scope = workgroup mandatory after write/before read | F-CHIP-5 |
| host-device pointer aliasing | unified memory only via explicit policy; default = explicit copy | F-CHIP-5b |
| sub-group divergence | guard at axis 6; emit warning if subgroup_w not queried | F-CHIP-5c |
| validation-by-construction (browser) | WebGPU mandates; projection layer must respect lower-bound | §7.4 canon |

## 7. ASCII block diagram (projection layer)

```
   hexa source
        │
        ▼
┌──────────────────────┐
│ hal::compute::parallel│    axis 1–6 + kernel body (SPIR-V or PTX bytes)
│   .dispatch(KernelDescriptor)│
└──────────┬───────────┘
           │ select backend by env / build flag
   ┌───────┼────────────────────────────┐
   ▼       ▼            ▼               ▼
 CUDA    HIP-AMD     SYCL/oneAPI     Metal/WebGPU
 driver  driver      runtime         OS bindings
   │       │            │               │
   ▼       ▼            ▼               ▼
 CUDA/    AMD          Intel/AMD/NV    Apple Silicon /
 NVIDIA   GPU          GPU             Browser GPU
```

## 8. BOM / footprint (programming-model verb — software only)

| Component | Source / dependency | Notes |
|-----------|---------------------|-------|
| projection layer | hexa-lang stdlib/hal v0.3+ (`hal::compute::parallel`) | Phase F iter 2 deliverable |
| SPIR-V toolchain | spirv-tools (Khronos), upstream | required for SYCL / OpenCL / WebGPU paths |
| PTX toolchain | LLVM nvptx backend ‖ NVCC | required for CUDA path |
| HIP runtime | ROCm 7.x | required for AMD path |
| Metal runtime | Xcode SDK 16+ | macOS / iOS only |
| WebGPU runtime | Dawn (Chrome) ‖ wgpu (Firefox) ‖ Tint (translator) | browser + native |

**No silicon BOM** — this verb has no GDSII / die / package / board.
Silicon dependencies are upstream (NPU/PIM/photonic for hexa-native
acceleration; commodity GPU for vendor backends).

## 9. References

Canon SSOT: `~/core/canon/domains/compute/gpgpu/gpgpu.md` §8 (web-search
citations 2026-05-08). Vision spec: `gpgpu_n6/chip-gpgpu-n6.md`.
Verify: `gpgpu_n6/verify_chip-gpgpu-n6.hexa`. Roadmap: `.roadmap.hexa_chip
§F`.
