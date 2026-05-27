# gpu — hexa-native GPU kernels

> Design directory for authoring forge's GPU compute kernels in
> **hexa itself**, via the `@gpu` annotation, instead of hand-written
> CUDA `.cu` / Metal `.metal`.
>
> Status: **055-P2 LANDED (2026-05-20)** — the NVPTX codegen (RFC 055)
> hand-emits a FP64 vec-add and a naive FP64 GEMM `@gpu_kernel`; the
> RFC 055 §7 falsifier battery is **measured PASS on a real NVIDIA GPU**
> (RTX 5070). The codegen is not yet wired into the main compile
> pipeline — that is 055-P3 (`HANDOFF.md`). The kernel source format is
> decided (`design.md` Decision 1 — `@gpu` annotation on ordinary
> `.hexa` files). This directory holds the design / spec; the codegen
> implementation lives in `compiler/codegen/nvptx_*.hexa`.
>
> Scope note: this is a **design / spec** directory. The GPU
> *runtime* code stays under `self/` (`self/native/`, `self/cuda/`,
> `self/forge/`).

## What

forge (the GPU compute substrate) today runs hand-written, vendor-
locked kernels:

- `self/native/hxcuda_conv1d.cu` · `hxcuda_fused.cu` · `hxcuda_stft.cu`
  · `hxqwen14b_cuda.cu` · `lora_cuda.cu` — CUDA
- `self/native/hxmetal_kernels.metal` — Metal
- `self/native/gpu_codegen_stub.c` — the existing `@gpu` codegen skeleton

This directory designs the path to writing those kernels in hexa — as
`@gpu fn ...` blocks inside ordinary `.hexa` files — and letting the
compiler emit the per-backend device code.

## Why

- `HEXA-NATIVE-ONLY.md` — hexa-lang is self-hosted. Hand-written CUDA
  is the current carve-out, not the architecture. This closes it.
- Backend-neutral — one kernel source emitted to CUDA / Metal / ROCm,
  instead of maintaining parallel `.cu` + `.metal` copies by hand.
- Roadmap context — forge's "match cuBLAS → exceed cuBLAS" path needs
  custom fused kernels; authoring them hexa-native (not hand-CUDA) is
  the prerequisite. See `self/forge/PLAN.md`.

## Format (decided)

GPU kernels are `@gpu fn ...` blocks inside ordinary `.hexa` files —
**no new file extension**. This rides hexa's existing attribute
machinery and mirrors how CUDA (`__global__`) and Triton
(`@triton.jit`) do it. Full rationale + the rejected `.hxk`-extension
alternative: `design.md` Decision 1.

## Layout

```
gpu/
  README.md   this file — what this is + honest status
  design.md   decision ledger — Decision 1 (format) · Decision 2 (dir name)
  HANDOFF.md  next-steps brief + the honest performance framing
```
