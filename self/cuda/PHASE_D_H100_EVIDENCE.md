# RFC 040 Phase D — `runtime_cuda.c` real-H100 verification evidence

> Branch `phase-d-cublas-h100`. Lands the RFC 040 Phase A/B cuBLAS
> `Dgemm` implementation (`self/cuda/runtime_cuda.c`) with real-hardware
> compile + numerical-equivalence evidence from an actual NVIDIA H100.
>
> This branch does **not** modify `self/runtime.c` — that file has
> in-flight uncommitted Phase B/C work from a concurrent agent and must
> not be entangled. `runtime_cuda.c` is a standalone TU: it provides the
> `_hx_cuda_*` symbols that `self/runtime.c` forward-declares under
> `#ifdef HEXA_CUDA`, and links against `-lcublas -lcudart`. The
> integration is the link line; the proof is that this TU compiles
> cleanly against real CUDA headers and the cuBLAS Dgemm it emits is
> numerically equivalent to the CPU oracle within a measured bound.

## Build (HEXA_CUDA configuration)

```bash
# C build (the real hexa-lang path — runtime.c compiles this as C):
gcc -O2 -std=gnu11 -DHEXA_CUDA -c self/cuda/runtime_cuda.c \
    -I/usr/local/cuda/include -o runtime_cuda.o
# link alongside the hexa runtime:
#   ... runtime.o runtime_cuda.o -L/usr/local/cuda/lib64 -lcublas -lcudart
```

## Real-H100 evidence (2026-05-16)

Hardware: **NVIDIA H100 80GB HBM3 (SXM, compute capability 9.0)**,
driver 580.126.20, CUDA toolkit 12.4, image
`nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04` (vast.ai).

### Compile

- **gcc (v1, H100 NVL)**: `gcc -c runtime_cuda.c` → `OBJ_RC=0`,
  8008-byte `.o`, unmangled C symbols `_hx_cuda_*` (T) +
  `cublasCreate_v2`/`cublasDgemm_v2` (U). This is the exact linkage the
  real hexa-lang `-DHEXA_CUDA` build uses.
- **nvcc (live H100 SXM)**: `nvcc -x cu -c runtime_cuda.c` →
  `RUNTIME_CUDA_RC=0`, 10664-byte `.o`, all 6 `_hx_cuda_*` defined +
  `cublasCreate_v2`/`cublasDgemm_v2`/`cudaMalloc` external-resolved.

### cuBLAS Dgemm numerical equivalence (same row-major→col-major trick as this TU)

| shape | GFLOP/s | max rel Δ vs CPU ikj |
|---|---|---|
| 64³ | 58.6 | 1.82e-12 |
| 256³ | 3 714 | 1.41e-11 |
| 512³ | 29 148 | 2.12e-10 |
| 768³ | 35 440 | 4.67e-10 |
| 1024³ | **51 244** | 1.09e-10 |
| 768×3072×768 | 43 651 | 7.17e-10 |
| 768×768×3072 | 48 467 | **1.905e-9** |

- Peak **51.24 TFLOPS FP64** (76% of H100 SXM ~67 TFLOPS theoretical
  on stock cuBLAS Dgemm).
- **TOL_MATMUL** (RFC 040 §"Honest caveats"): 6/7 shapes within the
  proposed `1e-9` relative. The reduction-heavy `768×768×3072` shape
  measured `1.905e-9` — the deeper K-reduction means more fp
  non-associativity between cuBLAS's tiled order and the CPU `ikj`
  order, exactly the predicted mechanism. **Measurement-calibrated
  bound: `TOL_MATMUL ≈ 2e-9` relative** for f64 cuBLAS Dgemm on H100.
  Measured and named, not asserted by hope; bit-equality not claimed.

Full anima-side artifacts + result.json:
`dancinlab/anima` `state/hexad_gpu_fire_2026_05_16/` +
`docs/anima_rfc040_phase_d_h100_cublas_2026_05_16.md` (commit 27e96e348).

## Residual (Phase E)

- A full `-DHEXA_CUDA` hexa toolchain rebuild + the RFC 040 falsifier
  battery (`F-GPU-040-*`) running compiled-native on a GPU box.
- `self/runtime.c` integration is left to the concurrent Phase B/C
  agent (do not entangle); when their work lands, the link line above
  wires `runtime_cuda.o` into the `#ifdef HEXA_CUDA` build.
